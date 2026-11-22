-- DiaMate research schema: the merged open datasets (generated from the CSV files by tools/generate_research_sql.py)
-- Nothing in the application depends on writing to this schema; treat it as read-only reference / seed data.
CREATE SCHEMA IF NOT EXISTS research;

CREATE TABLE research.patients (
    patient_id text PRIMARY KEY,
    source text NOT NULL,
    diabetes_type text NOT NULL,
    sex text,
    age_years double precision,
    time_basis text NOT NULL,
    n_records integer NOT NULL
);

COMMENT ON TABLE research.patients IS 'One row per person from the merged open datasets (166): source, diabetes type, sex, age. NOT application users.';

COMMENT ON COLUMN research.patients.time_basis IS 'real = true calendar dates; relative_anchor_2000-01-01 = BrisT1D (no dates in the source, timeline starts 2000-01-01).';

CREATE TABLE research.records (
    record_id text PRIMARY KEY,
    patient_id text NOT NULL,
    source text NOT NULL,
    diabetes_type text NOT NULL,
    time_basis text NOT NULL,
    sex text,
    age_years double precision,
    height_m double precision,
    weight_kg double precision,
    bmi double precision,
    diabetes_duration_years double precision,
    hba1c_mmol_mol double precision,
    hba1c_pct double precision,
    fasting_glucose_mgdl double precision,
    postprandial_2h_glucose_mgdl double precision,
    hypoglycemia_history text,
    hypoglycemic_agents text,
    comorbidities text
);

COMMENT ON TABLE research.records IS 'One row per recording period: clinical and lab summary (Shanghai patients can have several records).';

CREATE TABLE research.glucose_readings (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    timestamp timestamp NOT NULL,
    glucose_mgdl double precision NOT NULL,
    reading_type text NOT NULL,
    source text NOT NULL,
    quality_flag text
);

COMMENT ON TABLE research.glucose_readings IS 'All glucose readings in mg/dL. reading_type = CGM or CBG_fingerstick. quality_flag marks suspicious values (nothing was deleted).';

COMMENT ON COLUMN research.glucose_readings.quality_flag IS 'empty = ok; sensor_floor = CGM <= 40 mg/dL (sensor clips); implausible_value = CBG > 600 or < 20, CGM > 520.';

CREATE TABLE research.meals (
    meal_id text PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    timestamp timestamp NOT NULL,
    is_recorded boolean,
    description_en text,
    carbs_g double precision,
    kcal double precision,
    source text NOT NULL
);

COMMENT ON TABLE research.meals IS 'Meals. Shanghai: text description only; UC_HT / BrisT1D / HUPA_UCM: carbs_g.';

CREATE TABLE research.meal_items (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    meal_id text NOT NULL,
    patient_id text NOT NULL,
    food_name text NOT NULL,
    amount double precision,
    unit text,
    raw_text text
);

COMMENT ON TABLE research.meal_items IS 'Shanghai meal descriptions split into food_name / amount / unit (g or ml).';

CREATE TABLE research.insulin_doses (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    timestamp timestamp NOT NULL,
    route text NOT NULL,
    kind text NOT NULL,
    product text,
    dose_iu double precision,
    rate_iu_per_h double precision,
    raw_text text,
    source text NOT NULL
);

COMMENT ON TABLE research.insulin_doses IS 'Insulin events: subcutaneous, pump bolus / basal rate, intravenous, or BrisT1D total per 5 min.';

COMMENT ON COLUMN research.insulin_doses.rate_iu_per_h IS 'Pump basal rate in U/h (UC_HT / HUPA basal per 5 min converted x12).';

CREATE TABLE research.oral_medications (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    timestamp timestamp NOT NULL,
    drug text,
    dose_mg double precision,
    raw_text text,
    source text NOT NULL
);

COMMENT ON TABLE research.oral_medications IS 'Non-insulin glucose-lowering drugs, one row per drug, dose_mg.';

COMMENT ON COLUMN research.oral_medications.dose_mg IS 'Dose in mg, converted from the unit written in the source. Shanghai voglibose entries written as 0.1 / 0.2 / 0.4 g (= 100-400 mg) are almost certainly unit typos in the source (usual dose 0.2 mg): do not use them as real doses.';

CREATE TABLE research.activity (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    timestamp timestamp NOT NULL,
    heart_rate_bpm double precision,
    steps_5min double precision,
    source text NOT NULL,
    calories_kcal double precision,
    activity_type text
);

COMMENT ON TABLE research.activity IS 'Heart rate, steps, calories, activity type (UC_HT_T1DM, BrisT1D, HUPA_UCM).';

CREATE TABLE research.ketones (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    timestamp timestamp NOT NULL,
    ketone_mmol_l double precision,
    source text NOT NULL
);

COMMENT ON TABLE research.ketones IS 'Blood ketone measurements (Shanghai).';

CREATE TABLE research.timeline (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL,
    record_id text NOT NULL,
    source text NOT NULL,
    diabetes_type text NOT NULL,
    time_basis text NOT NULL,
    timestamp timestamp NOT NULL,
    cgm_mgdl double precision,
    cgm_flag text,
    cbg_fingerstick_mgdl double precision,
    cbg_flag text,
    meal_recorded boolean,
    carbs_g double precision,
    meal_text text,
    sc_insulin_iu double precision,
    sc_insulin_product text,
    pump_bolus_iu double precision,
    pump_basal_iu_per_h double precision,
    iv_insulin_iu double precision,
    insulin_iu_5min_total double precision,
    oral_drugs text,
    heart_rate_bpm double precision,
    steps_5min double precision,
    calories_kcal double precision,
    activity_type text
);

COMMENT ON TABLE research.timeline IS 'Flat convenience table: one row per patient/timestamp with glucose, meal, insulin, oral drug and activity side by side.';

CREATE TABLE research.sources (
    source text PRIMARY KEY,
    citation text,
    licence_note text
);

COMMENT ON TABLE research.sources IS 'Citation and licence notes for every source dataset.';

CREATE TABLE research.brfss_survey (
    survey_id integer PRIMARY KEY,
    diabetes_012 integer,
    diabetes_binary integer,
    high_bp integer,
    high_chol integer,
    chol_check integer,
    bmi integer,
    smoker integer,
    stroke integer,
    heart_disease_or_attack integer,
    phys_activity integer,
    fruits integer,
    veggies integer,
    heavy_alcohol integer,
    any_healthcare integer,
    no_doc_because_cost integer,
    general_health_1_5 integer,
    mental_health_bad_days integer,
    physical_health_bad_days integer,
    diff_walking integer,
    sex_male integer,
    age_group_1_13 integer,
    education_1_6 integer,
    income_1_8 integer
);

COMMENT ON TABLE research.brfss_survey IS 'BRFSS 2015 health-indicator survey (253,680 respondents). Cross-sectional risk data, not a time series.';

CREATE TABLE research.food_classes (
    class_id integer PRIMARY KEY,
    class_name text NOT NULL,
    display_name text,
    n_train_images integer,
    n_validation_images integer,
    kcal_per_100g_est integer,
    carbs_g_per_100g_est integer,
    typical_serving_g_est integer,
    carbs_g_per_serving_est double precision,
    nutrition_source text
);

COMMENT ON TABLE research.food_classes IS 'Food-101 class table (101 classes). *_est nutrition columns are rough estimates, verify before use.';

COMMENT ON COLUMN research.food_classes.carbs_g_per_100g_est IS 'ROUGH ESTIMATE from general nutrition knowledge, not measured.';

CREATE TABLE research.food_images (
    image_id integer PRIMARY KEY,
    class_id integer,
    split text NOT NULL,
    relative_path text NOT NULL
);

COMMENT ON TABLE research.food_images IS 'Food-101 image index (relative paths, images stay on disk).';
