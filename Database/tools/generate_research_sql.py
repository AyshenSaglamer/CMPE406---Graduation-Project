#!/usr/bin/env python3
"""
Generates the SQL for the `research` schema (the merged open datasets) from the CSV files.

usage: generate_research_sql.py <project_root> <sql_out_dir>      (run from Database/:  python3 tools/generate_research_sql.py .. sql)

<project_root> = the 'Graduate Project' folder. It must contain  Dataset/unified/*.csv  and  Database/data/timeline.csv, sources.csv
(the last two come from tools/export_pg_csv.py). Column types are inferred from the CSVs, so the schema always matches the data.
Writes 02_research_schema.sql, 03_research_load.sql, 04_research_keys_indexes.sql, 05_research_verify.sql and expected_rows.json.
The load script takes the folder from the psql variable data_dir (the project root):  psql -v data_dir="/path/to/Graduate Project" ...
"""
import json, os, sys
import pandas as pd

ROOT, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
S = "research"

TABLES = [  # (table, csv path relative to dataset root, has generated id column)
    ("patients", "Dataset/unified/patients.csv", False), ("records", "Dataset/unified/records.csv", False),
    ("glucose_readings", "Dataset/unified/glucose_readings.csv", True), ("meals", "Dataset/unified/meals.csv", False),
    ("meal_items", "Dataset/unified/meal_items.csv", True), ("insulin_doses", "Dataset/unified/insulin_doses.csv", True),
    ("oral_medications", "Dataset/unified/oral_medications.csv", True), ("activity", "Dataset/unified/activity.csv", True),
    ("ketones", "Dataset/unified/ketones.csv", True), ("timeline", "Database/data/timeline.csv", True),
    ("sources", "Database/data/sources.csv", False), ("brfss_survey", "Dataset/unified/brfss_survey.csv", False),
    ("food_classes", "Dataset/unified/food_classes.csv", False), ("food_images", "Dataset/unified/food_images.csv", False),
]
PK = {"patients": "patient_id", "records": "record_id", "meals": "meal_id", "brfss_survey": "survey_id",
      "food_classes": "class_id", "food_images": "image_id", "sources": "source"}
BOOL = {"is_recorded", "meal_recorded"}
NOTNULL = {"patient_id", "record_id", "timestamp", "source", "glucose_mgdl", "reading_type", "meal_id", "food_name",
           "diabetes_type", "time_basis", "route", "kind", "n_records", "class_name", "split", "relative_path"}
COMMENT = {
    "patients": "One row per person from the merged open datasets (166): source, diabetes type, sex, age. NOT application users.",
    "records": "One row per recording period: clinical and lab summary (Shanghai patients can have several records).",
    "glucose_readings": "All glucose readings in mg/dL. reading_type = CGM or CBG_fingerstick. quality_flag marks suspicious values (nothing was deleted).",
    "meals": "Meals. Shanghai: text description only; UC_HT / BrisT1D / HUPA_UCM: carbs_g.",
    "meal_items": "Shanghai meal descriptions split into food_name / amount / unit (g or ml).",
    "insulin_doses": "Insulin events: subcutaneous, pump bolus / basal rate, intravenous, or BrisT1D total per 5 min.",
    "oral_medications": "Non-insulin glucose-lowering drugs, one row per drug, dose_mg.",
    "activity": "Heart rate, steps, calories, activity type (UC_HT_T1DM, BrisT1D, HUPA_UCM).",
    "ketones": "Blood ketone measurements (Shanghai).",
    "timeline": "Flat convenience table: one row per patient/timestamp with glucose, meal, insulin, oral drug and activity side by side.",
    "sources": "Citation and licence notes for every source dataset.",
    "brfss_survey": "BRFSS 2015 health-indicator survey (253,680 respondents). Cross-sectional risk data, not a time series.",
    "food_classes": "Food-101 class table (101 classes). *_est nutrition columns are rough estimates, verify before use.",
    "food_images": "Food-101 image index (relative paths, images stay on disk).",
}
COLCOMMENT = {
    ("patients", "time_basis"): "real = true calendar dates; relative_anchor_2000-01-01 = BrisT1D (no dates in the source, timeline starts 2000-01-01).",
    ("glucose_readings", "quality_flag"): "empty = ok; sensor_floor = CGM <= 40 mg/dL (sensor clips); implausible_value = CBG > 600 or < 20, CGM > 520.",
    ("insulin_doses", "rate_iu_per_h"): "Pump basal rate in U/h (UC_HT / HUPA basal per 5 min converted x12).",
    ("food_classes", "carbs_g_per_100g_est"): "ROUGH ESTIMATE from general nutrition knowledge, not measured.",
    ("oral_medications", "dose_mg"): "Dose in mg, converted from the unit written in the source. Shanghai voglibose entries written as 0.1 / 0.2 / 0.4 g (= 100-400 mg) are almost certainly unit typos in the source (usual dose 0.2 mg): do not use them as real doses.",
}

ddl, load, cols_of = [], [], {}
for t, path, has_id in TABLES:
    d = pd.read_csv(os.path.join(ROOT, path), keep_default_na=False, na_values=[""], low_memory=False)
    cols, defs = list(d.columns), []
    for c in cols:
        s = d[c]
        if c == "timestamp":
            typ = "timestamp"
        elif c in BOOL:
            typ = "boolean"
        elif pd.api.types.is_integer_dtype(s):
            typ = "integer"
        elif pd.api.types.is_float_dtype(s):
            typ = "double precision"
        else:
            typ = "text"
        pk = " PRIMARY KEY" if PK.get(t) == c else ""
        nn = " NOT NULL" if (c in NOTNULL and not pk and s.notna().all()) else ""
        defs.append(f"    {c} {typ}{nn}{pk}")
    if has_id:
        defs.insert(0, "    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY")
    ddl.append(f"CREATE TABLE {S}.{t} (\n" + ",\n".join(defs) + "\n);\n")
    ddl.append(f"COMMENT ON TABLE {S}.{t} IS '{COMMENT[t]}';\n")
    for (tt, cc), txt in COLCOMMENT.items():
        if tt == t and cc in cols:
            ddl.append(f"COMMENT ON COLUMN {S}.{t}.{cc} IS '{txt}';\n")
    var = "f_" + t
    load.append(f"\\echo Loading {S}.{t} ...\n\\set {var} :data_dir '/{path}'\n"
                f"\\set cp '\\\\copy {S}.{t} ({', '.join(cols)}) FROM ' :'{var}' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'\n:cp\n")
    cols_of[t] = (cols, len(d))

open(os.path.join(OUT, "02_research_schema.sql"), "w").write(
    "-- DiaMate research schema: the merged open datasets (generated from the CSV files by tools/generate_research_sql.py)\n"
    "-- Nothing in the application depends on writing to this schema; treat it as read-only reference / seed data.\n"
    f"CREATE SCHEMA IF NOT EXISTS {S};\n\n" + "\n".join(ddl))

post = ["-- DiaMate research schema: foreign keys and indexes (run after loading)\n"]
fk = [("records", "patient_id", "patients(patient_id)"),
      ("glucose_readings", "patient_id", "patients(patient_id)"), ("glucose_readings", "record_id", "records(record_id)"),
      ("meals", "patient_id", "patients(patient_id)"), ("meals", "record_id", "records(record_id)"),
      ("meal_items", "meal_id", "meals(meal_id)"), ("meal_items", "patient_id", "patients(patient_id)"),
      ("insulin_doses", "patient_id", "patients(patient_id)"), ("insulin_doses", "record_id", "records(record_id)"),
      ("oral_medications", "patient_id", "patients(patient_id)"), ("oral_medications", "record_id", "records(record_id)"),
      ("activity", "patient_id", "patients(patient_id)"),
      ("ketones", "patient_id", "patients(patient_id)"), ("ketones", "record_id", "records(record_id)"),
      ("timeline", "patient_id", "patients(patient_id)"), ("timeline", "record_id", "records(record_id)"),
      ("food_images", "class_id", "food_classes(class_id)")]
for t, c, ref in fk:
    post.append(f"ALTER TABLE {S}.{t} ADD CONSTRAINT fk_{t}_{c} FOREIGN KEY ({c}) REFERENCES {S}.{ref};\n")
for t, c in [("glucose_readings", "patient_id, timestamp"), ("meals", "patient_id, timestamp"), ("insulin_doses", "patient_id, timestamp"),
             ("oral_medications", "patient_id, timestamp"), ("activity", "patient_id, timestamp"), ("timeline", "patient_id, timestamp"),
             ("timeline", "source"), ("records", "patient_id"), ("meal_items", "meal_id"), ("food_images", "class_id"),
             ("brfss_survey", "diabetes_012")]:
    post.append(f"CREATE INDEX ix_{t}_{c.replace(', ', '_')} ON {S}.{t} ({c});\n")
post.append(f"ANALYZE;\n")
open(os.path.join(OUT, "04_research_keys_indexes.sql"), "w").write("".join(post))

open(os.path.join(OUT, "03_research_load.sql"), "w").write(
    "-- DiaMate research schema: load the CSV files with psql \\copy\n"
    "-- data_dir = the project root that contains Dataset/unified/ and Database/data/\n"
    "\\set ON_ERROR_STOP on\n\\encoding UTF8\n\\if :{?data_dir}\n\\else\n\\echo ERROR: run with  psql -v data_dir=/path/to/project_root  ...\n\\quit\n\\endif\n" + "".join(load))
json.dump({t: n for t, (c, n) in cols_of.items()}, open(os.path.join(OUT, "expected_rows.json"), "w"), indent=1)

vals = ",\n        ".join(f"('{t}', {n})" for t, (c, n) in cols_of.items())
open(os.path.join(OUT, "05_research_verify.sql"), "w").write(f"""-- DiaMate research schema: the row counts must match the CSV files (generated, do not edit)
\\set ON_ERROR_STOP on
\\echo
\\echo === research schema: row count check ===
DO $$
DECLARE
    r record; n bigint; bad text := '';
BEGIN
    FOR r IN SELECT * FROM (VALUES
        {vals}
    ) AS v(tbl, expected) LOOP
        EXECUTE format('SELECT count(*) FROM research.%I', r.tbl) INTO n;
        IF n <> r.expected THEN bad := bad || format(' %s(%s, expected %s)', r.tbl, n, r.expected); END IF;
    END LOOP;
    IF bad <> '' THEN RAISE EXCEPTION 'research row counts differ:%', bad; END IF;
    RAISE NOTICE 'research schema: all {len(cols_of)} tables match the CSV row counts';
END $$;
-- no orphans (the foreign keys guarantee it; this is a readable double check)
SELECT (SELECT count(*) FROM research.glucose_readings g WHERE NOT EXISTS (SELECT 1 FROM research.patients p WHERE p.patient_id = g.patient_id)) AS orphan_glucose,
       (SELECT count(*) FROM research.meal_items i WHERE NOT EXISTS (SELECT 1 FROM research.meals m WHERE m.meal_id = i.meal_id)) AS orphan_meal_items,
       (SELECT count(*) FROM research.food_images f WHERE NOT EXISTS (SELECT 1 FROM research.food_classes c WHERE c.class_id = f.class_id)) AS orphan_food_images;
""")
print({t: n for t, (c, n) in cols_of.items()})
