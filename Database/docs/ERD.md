# DiaMate entity-relationship diagrams

Mermaid diagrams (GitHub, VS Code, Obsidian and many other tools render them). Generated from the foreign keys of the installed database.

## Accounts, roles and sharing

```mermaid
erDiagram
    care_relationships {
        bigint id PK
        bigint patient_id FK
        bigint member_id FK
        varchar member_role
        varchar status
        boolean can_view_glucose
        boolean can_view_meals
        boolean can_view_medications
        boolean can_view_activity
        boolean can_view_reports
        boolean can_receive_alerts
        boolean can_add_recommendations
        bigint invited_by FK
        timestamptz invited_at
        timestamptz responded_at
        timestamptz revoked_at
        timestamptz expires_at
        timestamptz created_at
        timestamptz updated_at
    }
    clinician_profiles {
        bigint user_id PK
        varchar specialization
        varchar hospital_name
        varchar license_number
        timestamptz created_at
        timestamptz updated_at
    }
    device_tokens {
        bigint id PK
        bigint user_id FK
        varchar token
        varchar platform
        boolean is_active
        timestamptz last_seen_at
        timestamptz created_at
    }
    password_reset_tokens {
        bigint id PK
        bigint user_id FK
        varchar token_hash
        timestamptz created_at
        timestamptz expires_at
        timestamptz used_at
    }
    patient_profiles {
        bigint user_id PK
        varchar diabetes_type
        date date_of_birth
        varchar sex
        numeric height_cm
        numeric weight_kg
        smallint diagnosis_year
        varchar therapy_type
        smallint target_min_mgdl
        smallint target_max_mgdl
        smallint hypo_threshold_mgdl
        smallint hyper_threshold_mgdl
        smallint urgent_low_mgdl
        smallint urgent_high_mgdl
        varchar emergency_contact_name
        varchar emergency_contact_phone
        varchar research_patient_id
        timestamptz created_at
        timestamptz updated_at
    }
    refresh_tokens {
        bigint id PK
        bigint user_id FK
        varchar token_hash
        timestamptz issued_at
        timestamptz expires_at
        timestamptz revoked_at
        varchar user_agent
        varchar ip_address
    }
    treatment_plans {
        bigint id PK
        bigint patient_id FK
        bigint clinician_id FK
        smallint target_glucose_min
        smallint target_glucose_max
        varchar prescribed_insulin
        text notes
        date start_date
        date end_date
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    user_settings {
        bigint user_id PK
        varchar language
        varchar glucose_unit
        numeric font_scale
        boolean high_contrast
        boolean voice_input_enabled
        boolean push_enabled
        boolean email_reports_enabled
        varchar timezone
        timestamptz updated_at
    }
    users {
        bigint id PK
        varchar email
        varchar password_hash
        varchar role
        varchar full_name
        varchar phone
        boolean is_active
        boolean is_demo
        boolean email_verified
        boolean two_factor_enabled
        varchar two_factor_secret
        integer failed_login_attempts
        timestamptz locked_until
        timestamptz last_login_at
        timestamptz created_at
        timestamptz updated_at
    }
    users ||--o{ care_relationships : "invited_by"
    users ||--o{ care_relationships : "member_id"
    patient_profiles ||--o{ care_relationships : "patient_id"
    users ||--o{ clinician_profiles : "user_id"
    users ||--o{ device_tokens : "user_id"
    users ||--o{ password_reset_tokens : "user_id"
    users ||--o{ patient_profiles : "user_id"
    users ||--o{ refresh_tokens : "user_id"
    clinician_profiles ||--o{ treatment_plans : "clinician_id"
    patient_profiles ||--o{ treatment_plans : "patient_id"
    users ||--o{ user_settings : "user_id"
```

## Daily logs

```mermaid
erDiagram
    activity_logs {
        bigint id PK
        bigint patient_id FK
        varchar activity_type
        timestamptz started_at
        numeric duration_minutes
        integer steps
        smallint avg_heart_rate
        numeric calories_kcal
        varchar intensity
        varchar source
        text notes
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    food_catalog {
        bigint id PK
        varchar name
        varchar display_name
        numeric kcal_per_100g
        numeric carbs_g_per_100g
        numeric default_serving_g
        varchar nutrition_source
        boolean is_verified
        integer research_class_id
        timestamptz created_at
    }
    glucose_logs {
        bigint id PK
        bigint patient_id FK
        integer glucose_value
        timestamptz measurement_time
        varchar meal_context
        varchar source
        text notes
        bigint entered_by FK
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    insulin_logs {
        bigint id PK
        bigint patient_id FK
        numeric dose_units
        varchar insulin_type
        varchar delivery_method
        varchar product_name
        timestamptz administered_at
        bigint meal_log_id FK
        varchar source
        text notes
        bigint entered_by FK
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    lab_results {
        bigint id PK
        bigint patient_id FK
        varchar test_type
        numeric value
        varchar unit
        timestamptz taken_at
        varchar source
        bigint entered_by FK
        text notes
        timestamptz created_at
        timestamptz updated_at
    }
    meal_log_items {
        bigint id PK
        bigint meal_log_id FK
        bigint food_catalog_id FK
        varchar food_name
        numeric amount_g
        numeric carbs_g
        numeric calories_kcal
        timestamptz created_at
    }
    meal_logs {
        bigint id PK
        bigint patient_id FK
        varchar meal_type
        timestamptz eaten_at
        text description
        numeric carbs_g
        numeric calories_kcal
        numeric protein_g
        numeric fat_g
        varchar source
        text photo_url
        numeric ai_confidence
        text notes
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    patient_profiles {
        bigint user_id PK
        varchar diabetes_type
        date date_of_birth
        varchar sex
        numeric height_cm
        numeric weight_kg
        smallint diagnosis_year
        varchar therapy_type
        smallint target_min_mgdl
        smallint target_max_mgdl
        smallint hypo_threshold_mgdl
        smallint hyper_threshold_mgdl
        smallint urgent_low_mgdl
        smallint urgent_high_mgdl
        varchar emergency_contact_name
        varchar emergency_contact_phone
        varchar research_patient_id
        timestamptz created_at
        timestamptz updated_at
    }
    symptom_logs {
        bigint id PK
        bigint patient_id FK
        varchar symptom_type
        smallint severity
        timestamptz occurred_at
        text notes
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    wearable_samples {
        bigint id PK
        bigint patient_id FK
        timestamptz sample_time
        smallint heart_rate_bpm
        integer steps
        numeric calories_kcal
        varchar source
    }
    patient_profiles ||--o{ activity_logs : "patient_id"
    patient_profiles ||--o{ glucose_logs : "patient_id"
    meal_logs ||--o{ insulin_logs : "meal_log_id"
    patient_profiles ||--o{ insulin_logs : "patient_id"
    patient_profiles ||--o{ lab_results : "patient_id"
    food_catalog ||--o{ meal_log_items : "food_catalog_id"
    meal_logs ||--o{ meal_log_items : "meal_log_id"
    patient_profiles ||--o{ meal_logs : "patient_id"
    patient_profiles ||--o{ symptom_logs : "patient_id"
    patient_profiles ||--o{ wearable_samples : "patient_id"
```

## Medication, reminders, alerts

```mermaid
erDiagram
    alerts {
        bigint id PK
        bigint patient_id FK
        varchar alert_type
        varchar severity
        bigint glucose_log_id FK
        bigint reminder_event_id FK
        numeric value_mgdl
        varchar message
        timestamptz triggered_at
        varchar status
        bigint acknowledged_by FK
        timestamptz acknowledged_at
        timestamptz resolved_at
        timestamptz follow_up_due_at
        timestamptz follow_up_completed_at
        timestamptz created_at
    }
    clinician_profiles {
        bigint user_id PK
        varchar specialization
        varchar hospital_name
        varchar license_number
        timestamptz created_at
        timestamptz updated_at
    }
    medication_intakes {
        bigint id PK
        bigint patient_id FK
        bigint medication_id FK
        varchar medication_name
        varchar dose_text
        timestamptz taken_at
        varchar status
        bigint reminder_event_id FK
        text notes
        uuid client_uuid
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    medications {
        bigint id PK
        bigint patient_id FK
        varchar name
        varchar medication_type
        varchar dosage
        numeric dose_amount
        varchar dose_unit
        varchar frequency_text
        text instructions
        bigint prescribed_by FK
        date start_date
        date end_date
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    notifications {
        bigint id PK
        bigint recipient_id FK
        bigint alert_id FK
        bigint reminder_event_id FK
        varchar notification_type
        varchar title
        text body
        varchar channel
        varchar status
        varchar error_message
        timestamptz created_at
        timestamptz sent_at
        timestamptz read_at
    }
    patient_profiles {
        bigint user_id PK
        varchar diabetes_type
        date date_of_birth
        varchar sex
        numeric height_cm
        numeric weight_kg
        smallint diagnosis_year
        varchar therapy_type
        smallint target_min_mgdl
        smallint target_max_mgdl
        smallint hypo_threshold_mgdl
        smallint hyper_threshold_mgdl
        smallint urgent_low_mgdl
        smallint urgent_high_mgdl
        varchar emergency_contact_name
        varchar emergency_contact_phone
        varchar research_patient_id
        timestamptz created_at
        timestamptz updated_at
    }
    recommendations {
        bigint id PK
        bigint patient_id FK
        bigint clinician_id FK
        text message
        timestamptz created_at
        timestamptz read_at
    }
    reminder_events {
        bigint id PK
        bigint reminder_id FK
        bigint patient_id FK
        timestamptz scheduled_for
        varchar status
        timestamptz sent_at
        timestamptz acknowledged_at
        timestamptz snoozed_until
    }
    reminders {
        bigint id PK
        bigint patient_id FK
        bigint medication_id FK
        varchar reminder_type
        varchar medication_name
        varchar dosage
        varchar message
        time_without_time_zone scheduled_time
        varchar days_of_week
        varchar timezone
        boolean is_active
        integer missed_count
        timestamptz last_triggered_at
        timestamptz created_at
        timestamptz updated_at
    }
    users {
        bigint id PK
        varchar email
        varchar password_hash
        varchar role
        varchar full_name
        varchar phone
        boolean is_active
        boolean is_demo
        boolean email_verified
        boolean two_factor_enabled
        varchar two_factor_secret
        integer failed_login_attempts
        timestamptz locked_until
        timestamptz last_login_at
        timestamptz created_at
        timestamptz updated_at
    }
    users ||--o{ alerts : "acknowledged_by"
    patient_profiles ||--o{ alerts : "patient_id"
    reminder_events ||--o{ alerts : "reminder_event_id"
    users ||--o{ clinician_profiles : "user_id"
    medications ||--o{ medication_intakes : "medication_id"
    patient_profiles ||--o{ medication_intakes : "patient_id"
    reminder_events ||--o{ medication_intakes : "reminder_event_id"
    patient_profiles ||--o{ medications : "patient_id"
    clinician_profiles ||--o{ medications : "prescribed_by"
    alerts ||--o{ notifications : "alert_id"
    users ||--o{ notifications : "recipient_id"
    reminder_events ||--o{ notifications : "reminder_event_id"
    users ||--o{ patient_profiles : "user_id"
    clinician_profiles ||--o{ recommendations : "clinician_id"
    patient_profiles ||--o{ recommendations : "patient_id"
    patient_profiles ||--o{ reminder_events : "patient_id"
    reminders ||--o{ reminder_events : "reminder_id"
    medications ||--o{ reminders : "medication_id"
    patient_profiles ||--o{ reminders : "patient_id"
```

## Reports, imports, AI assistant, audit

```mermaid
erDiagram
    ai_conversations {
        bigint id PK
        bigint patient_id FK
        varchar title
        varchar channel
        timestamptz started_at
        timestamptz ended_at
    }
    ai_messages {
        bigint id PK
        bigint conversation_id FK
        varchar sender
        text content
        varchar intent
        numeric extracted_value
        varchar created_entity_type
        bigint created_entity_id
        timestamptz created_at
    }
    audit_logs {
        bigint id PK
        bigint user_id FK
        bigint patient_id
        varchar action
        varchar entity_type
        varchar entity_id
        varchar ip_address
        varchar user_agent
        boolean success
        jsonb details
        timestamptz created_at
    }
    csv_imports {
        bigint id PK
        bigint patient_id FK
        bigint uploaded_by FK
        varchar filename
        varchar file_format
        integer rows_total
        integer rows_imported
        integer rows_rejected
        varchar status
        text error_summary
        timestamptz created_at
        timestamptz completed_at
    }
    patient_profiles {
        bigint user_id PK
        varchar diabetes_type
        date date_of_birth
        varchar sex
        numeric height_cm
        numeric weight_kg
        smallint diagnosis_year
        varchar therapy_type
        smallint target_min_mgdl
        smallint target_max_mgdl
        smallint hypo_threshold_mgdl
        smallint hyper_threshold_mgdl
        smallint urgent_low_mgdl
        smallint urgent_high_mgdl
        varchar emergency_contact_name
        varchar emergency_contact_phone
        varchar research_patient_id
        timestamptz created_at
        timestamptz updated_at
    }
    reports {
        bigint id PK
        bigint patient_id FK
        bigint requested_by FK
        varchar report_type
        varchar format
        timestamptz period_start
        timestamptz period_end
        varchar status
        varchar file_path
        bigint file_size_bytes
        jsonb summary
        timestamptz created_at
        timestamptz generated_at
        timestamptz expires_at
    }
    users {
        bigint id PK
        varchar email
        varchar password_hash
        varchar role
        varchar full_name
        varchar phone
        boolean is_active
        boolean is_demo
        boolean email_verified
        boolean two_factor_enabled
        varchar two_factor_secret
        integer failed_login_attempts
        timestamptz locked_until
        timestamptz last_login_at
        timestamptz created_at
        timestamptz updated_at
    }
    patient_profiles ||--o{ ai_conversations : "patient_id"
    ai_conversations ||--o{ ai_messages : "conversation_id"
    users ||--o{ audit_logs : "user_id"
    patient_profiles ||--o{ csv_imports : "patient_id"
    users ||--o{ csv_imports : "uploaded_by"
    users ||--o{ patient_profiles : "user_id"
    patient_profiles ||--o{ reports : "patient_id"
    users ||--o{ reports : "requested_by"
```

## Research schema (open datasets)

```mermaid
erDiagram
    activity {
        bigint id PK
        text patient_id FK
        timestamp timestamp
        float8 heart_rate_bpm
        float8 steps_5min
        text source
        float8 calories_kcal
        text activity_type
    }
    brfss_survey {
        integer survey_id PK
        integer diabetes_012
        integer diabetes_binary
        integer high_bp
        integer high_chol
        integer chol_check
        integer bmi
        integer smoker
        integer stroke
        integer heart_disease_or_attack
        integer phys_activity
        integer fruits
        integer veggies
        integer heavy_alcohol
        integer any_healthcare
        integer no_doc_because_cost
        integer general_health_1_5
        integer mental_health_bad_days
        integer physical_health_bad_days
        integer diff_walking
        integer sex_male
        integer age_group_1_13
        integer education_1_6
        integer income_1_8
    }
    food_classes {
        integer class_id PK
        text class_name
        text display_name
        integer n_train_images
        integer n_validation_images
        integer kcal_per_100g_est
        integer carbs_g_per_100g_est
        integer typical_serving_g_est
        float8 carbs_g_per_serving_est
        text nutrition_source
    }
    food_images {
        integer image_id PK
        integer class_id FK
        text split
        text relative_path
    }
    glucose_readings {
        bigint id PK
        text patient_id FK
        text record_id FK
        timestamp timestamp
        float8 glucose_mgdl
        text reading_type
        text source
        text quality_flag
    }
    insulin_doses {
        bigint id PK
        text patient_id FK
        text record_id FK
        timestamp timestamp
        text route
        text kind
        text product
        float8 dose_iu
        float8 rate_iu_per_h
        text raw_text
        text source
    }
    ketones {
        bigint id PK
        text patient_id FK
        text record_id FK
        timestamp timestamp
        float8 ketone_mmol_l
        text source
    }
    meal_items {
        bigint id PK
        text meal_id FK
        text patient_id FK
        text food_name
        float8 amount
        text unit
        text raw_text
    }
    meals {
        text meal_id PK
        text patient_id FK
        text record_id FK
        timestamp timestamp
        boolean is_recorded
        text description_en
        float8 carbs_g
        float8 kcal
        text source
    }
    oral_medications {
        bigint id PK
        text patient_id FK
        text record_id FK
        timestamp timestamp
        text drug
        float8 dose_mg
        text raw_text
        text source
    }
    patients {
        text patient_id PK
        text source
        text diabetes_type
        text sex
        float8 age_years
        text time_basis
        integer n_records
    }
    records {
        text record_id PK
        text patient_id FK
        text source
        text diabetes_type
        text time_basis
        text sex
        float8 age_years
        float8 height_m
        float8 weight_kg
        float8 bmi
        float8 diabetes_duration_years
        float8 hba1c_mmol_mol
        float8 hba1c_pct
        float8 fasting_glucose_mgdl
        float8 postprandial_2h_glucose_mgdl
        text hypoglycemia_history
        text hypoglycemic_agents
        text comorbidities
    }
    sources {
        text source PK
        text citation
        text licence_note
    }
    timeline {
        bigint id PK
        text patient_id FK
        text record_id FK
        text source
        text diabetes_type
        text time_basis
        timestamp timestamp
        float8 cgm_mgdl
        text cgm_flag
        float8 cbg_fingerstick_mgdl
        text cbg_flag
        boolean meal_recorded
        float8 carbs_g
        text meal_text
        float8 sc_insulin_iu
        text sc_insulin_product
        float8 pump_bolus_iu
        float8 pump_basal_iu_per_h
        float8 iv_insulin_iu
        float8 insulin_iu_5min_total
        text oral_drugs
        float8 heart_rate_bpm
        float8 steps_5min
        float8 calories_kcal
        text activity_type
    }
    patients ||--o{ activity : "patient_id"
    food_classes ||--o{ food_images : "class_id"
    patients ||--o{ glucose_readings : "patient_id"
    records ||--o{ glucose_readings : "record_id"
    patients ||--o{ insulin_doses : "patient_id"
    records ||--o{ insulin_doses : "record_id"
    patients ||--o{ ketones : "patient_id"
    records ||--o{ ketones : "record_id"
    meals ||--o{ meal_items : "meal_id"
    patients ||--o{ meal_items : "patient_id"
    patients ||--o{ meals : "patient_id"
    records ||--o{ meals : "record_id"
    patients ||--o{ oral_medications : "patient_id"
    records ||--o{ oral_medications : "record_id"
    patients ||--o{ records : "patient_id"
    patients ||--o{ timeline : "patient_id"
    records ||--o{ timeline : "record_id"
```

