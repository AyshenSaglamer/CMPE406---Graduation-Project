-- DiaMate research schema: load the CSV files with psql \copy
-- data_dir = the project root that contains Dataset/unified/ and Database/data/
\set ON_ERROR_STOP on
\encoding UTF8
\if :{?data_dir}
\else
\echo ERROR: run with  psql -v data_dir=/path/to/project_root  ...
\quit
\endif
\echo Loading research.patients ...
\set f_patients :data_dir '/Dataset/unified/patients.csv'
\set cp '\\copy research.patients (patient_id, source, diabetes_type, sex, age_years, time_basis, n_records) FROM ' :'f_patients' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.records ...
\set f_records :data_dir '/Dataset/unified/records.csv'
\set cp '\\copy research.records (record_id, patient_id, source, diabetes_type, time_basis, sex, age_years, height_m, weight_kg, bmi, diabetes_duration_years, hba1c_mmol_mol, hba1c_pct, fasting_glucose_mgdl, postprandial_2h_glucose_mgdl, hypoglycemia_history, hypoglycemic_agents, comorbidities) FROM ' :'f_records' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.glucose_readings ...
\set f_glucose_readings :data_dir '/Dataset/unified/glucose_readings.csv'
\set cp '\\copy research.glucose_readings (patient_id, record_id, timestamp, glucose_mgdl, reading_type, source, quality_flag) FROM ' :'f_glucose_readings' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.meals ...
\set f_meals :data_dir '/Dataset/unified/meals.csv'
\set cp '\\copy research.meals (meal_id, patient_id, record_id, timestamp, is_recorded, description_en, carbs_g, kcal, source) FROM ' :'f_meals' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.meal_items ...
\set f_meal_items :data_dir '/Dataset/unified/meal_items.csv'
\set cp '\\copy research.meal_items (meal_id, patient_id, food_name, amount, unit, raw_text) FROM ' :'f_meal_items' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.insulin_doses ...
\set f_insulin_doses :data_dir '/Dataset/unified/insulin_doses.csv'
\set cp '\\copy research.insulin_doses (patient_id, record_id, timestamp, route, kind, product, dose_iu, rate_iu_per_h, raw_text, source) FROM ' :'f_insulin_doses' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.oral_medications ...
\set f_oral_medications :data_dir '/Dataset/unified/oral_medications.csv'
\set cp '\\copy research.oral_medications (patient_id, record_id, timestamp, drug, dose_mg, raw_text, source) FROM ' :'f_oral_medications' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.activity ...
\set f_activity :data_dir '/Dataset/unified/activity.csv'
\set cp '\\copy research.activity (patient_id, timestamp, heart_rate_bpm, steps_5min, source, calories_kcal, activity_type) FROM ' :'f_activity' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.ketones ...
\set f_ketones :data_dir '/Dataset/unified/ketones.csv'
\set cp '\\copy research.ketones (patient_id, record_id, timestamp, ketone_mmol_l, source) FROM ' :'f_ketones' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.timeline ...
\set f_timeline :data_dir '/Database/data/timeline.csv'
\set cp '\\copy research.timeline (patient_id, record_id, source, diabetes_type, time_basis, timestamp, cgm_mgdl, cgm_flag, cbg_fingerstick_mgdl, cbg_flag, meal_recorded, carbs_g, meal_text, sc_insulin_iu, sc_insulin_product, pump_bolus_iu, pump_basal_iu_per_h, iv_insulin_iu, insulin_iu_5min_total, oral_drugs, heart_rate_bpm, steps_5min, calories_kcal, activity_type) FROM ' :'f_timeline' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.sources ...
\set f_sources :data_dir '/Database/data/sources.csv'
\set cp '\\copy research.sources (source, citation, licence_note) FROM ' :'f_sources' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.brfss_survey ...
\set f_brfss_survey :data_dir '/Dataset/unified/brfss_survey.csv'
\set cp '\\copy research.brfss_survey (survey_id, diabetes_012, diabetes_binary, high_bp, high_chol, chol_check, bmi, smoker, stroke, heart_disease_or_attack, phys_activity, fruits, veggies, heavy_alcohol, any_healthcare, no_doc_because_cost, general_health_1_5, mental_health_bad_days, physical_health_bad_days, diff_walking, sex_male, age_group_1_13, education_1_6, income_1_8) FROM ' :'f_brfss_survey' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.food_classes ...
\set f_food_classes :data_dir '/Dataset/unified/food_classes.csv'
\set cp '\\copy research.food_classes (class_id, class_name, display_name, n_train_images, n_validation_images, kcal_per_100g_est, carbs_g_per_100g_est, typical_serving_g_est, carbs_g_per_serving_est, nutrition_source) FROM ' :'f_food_classes' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
\echo Loading research.food_images ...
\set f_food_images :data_dir '/Dataset/unified/food_images.csv'
\set cp '\\copy research.food_images (image_id, class_id, split, relative_path) FROM ' :'f_food_images' ' WITH (FORMAT csv, HEADER true, ENCODING ''UTF8'')'
:cp
