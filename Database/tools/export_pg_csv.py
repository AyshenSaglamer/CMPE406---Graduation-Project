#!/usr/bin/env python3
"""Exports the tables that only exist inside DiaMate_dataset.db (timeline, sources) to CSV for the PostgreSQL load.
usage (from Database/): python3 tools/export_pg_csv.py ../Dataset/DiaMate_dataset.db data
"""
import os, sqlite3, sys
import pandas as pd

db, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
con = sqlite3.connect(db)
for t in ("timeline", "sources"):
    df = pd.read_sql(f"select * from {t}", con)
    if "meal_recorded" in df:                       # SQLite integer 1/0 with NULLs is read back as float 1.0 -> keep integers
        df["meal_recorded"] = df["meal_recorded"].astype("Int8")
    df.to_csv(os.path.join(out, t + ".csv"), index=False, encoding="utf-8")
    print(t, len(df))
