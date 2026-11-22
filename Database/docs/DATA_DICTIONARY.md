# DiaMate data dictionary

Generated from the installed database (PostgreSQL 18.6) on 2026-09-29. Do not edit by hand: run `tools/make_docs.py`.

Schema **public** = application (what the backend uses). Schema **research** = merged open datasets (read-only reference / training data).

## Contents

- **public tables:** [activity_logs](#publicactivity_logs), [ai_conversations](#publicai_conversations), [ai_messages](#publicai_messages), [alerts](#publicalerts), [audit_logs](#publicaudit_logs), [care_relationships](#publiccare_relationships), [clinician_profiles](#publicclinician_profiles), [csv_imports](#publiccsv_imports), [device_tokens](#publicdevice_tokens), [food_catalog](#publicfood_catalog), [glucose_logs](#publicglucose_logs), [insulin_logs](#publicinsulin_logs), [lab_results](#publiclab_results), [meal_log_items](#publicmeal_log_items), [meal_logs](#publicmeal_logs), [medication_intakes](#publicmedication_intakes), [medications](#publicmedications), [notifications](#publicnotifications), [password_reset_tokens](#publicpassword_reset_tokens), [patient_profiles](#publicpatient_profiles), [recommendations](#publicrecommendations), [refresh_tokens](#publicrefresh_tokens), [reminder_events](#publicreminder_events), [reminders](#publicreminders), [reports](#publicreports), [symptom_logs](#publicsymptom_logs), [treatment_plans](#publictreatment_plans), [user_settings](#publicuser_settings), [users](#publicusers), [wearable_samples](#publicwearable_samples)
- **public views:** [v_care_team](#publicv_care_team), [v_glucose_14d](#publicv_glucose_14d), [v_glucose_daily](#publicv_glucose_daily), [v_latest_glucose](#publicv_latest_glucose), [v_logbook](#publicv_logbook), [v_patient_overview](#publicv_patient_overview), [v_reminder_adherence_30d](#publicv_reminder_adherence_30d)
- **research tables:** [activity](#researchactivity), [brfss_survey](#researchbrfss_survey), [food_classes](#researchfood_classes), [food_images](#researchfood_images), [glucose_readings](#researchglucose_readings), [insulin_doses](#researchinsulin_doses), [ketones](#researchketones), [meal_items](#researchmeal_items), [meals](#researchmeals), [oral_medications](#researchoral_medications), [patients](#researchpatients), [records](#researchrecords), [sources](#researchsources), [timeline](#researchtimeline)

## Schema `public`

<a id="publicactivity_logs"></a>
### public.activity_logs (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `activity_type` | varchar(50) | NO |  |  |
| `started_at` | timestamptz | NO |  |  |
| `duration_minutes` | numeric(6,1) | yes |  |  |
| `steps` | integer | yes |  |  |
| `avg_heart_rate` | smallint | yes |  |  |
| `calories_kcal` | numeric(7,1) | yes |  |  |
| `intensity` | varchar(10) | yes |  |  |
| `source` | varchar(20) | NO | 'MANUAL'::character varying |  |
| `notes` | text | yes |  |  |
| `client_uuid` | uuid | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(((avg_heart_rate >= 20) AND (avg_heart_rate <= 260)))`
- **Check:** `((calories_kcal >= (0)))`
- **Check:** `((duration_minutes > (0)))`
- **Check:** `(intensity IN ('LOW', 'MODERATE', 'HIGH'))`
- **Check:** `(source IN ('MANUAL', 'WEARABLE', 'IMPORT'))`
- **Check:** `((steps >= 0))`
- **Index:** `INDEX ix_activity_logs_patient_time ON public.activity_logs USING btree (patient_id, started_at DESC)`
- **Index:** `UNIQUE INDEX ux_activity_logs_client ON public.activity_logs USING btree (patient_id, client_uuid) WHERE (client_uuid IS NOT NULL)`

<a id="publicai_conversations"></a>
### public.ai_conversations (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `title` | varchar(150) | yes |  |  |
| `channel` | varchar(5) | NO | 'TEXT'::character varying |  |
| `started_at` | timestamptz | NO | now() |  |
| `ended_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(channel IN ('TEXT', 'VOICE'))`
- **Index:** `INDEX ix_ai_conversations_patient ON public.ai_conversations USING btree (patient_id, started_at DESC)`

<a id="publicai_messages"></a>
### public.ai_messages (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `conversation_id` | bigint | NO |  |  |
| `sender` | varchar(10) | NO |  |  |
| `content` | text | NO |  |  |
| `intent` | varchar(30) | yes |  | LOG_GLUCOSE, LOG_INSULIN, LOG_MEAL, UNKNOWN ... (Dia NLP service) |
| `extracted_value` | numeric(10,2) | yes |  |  |
| `created_entity_type` | varchar(30) | yes |  | e.g. GLUCOSE_LOG |
| `created_entity_id` | bigint | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE`
- **Check:** `(sender IN ('USER', 'ASSISTANT', 'SYSTEM'))`
- **Index:** `INDEX ix_ai_messages_conversation ON public.ai_messages USING btree (conversation_id, created_at)`

<a id="publicalerts"></a>
### public.alerts (table)

Hypo / hyperglycemia and missed-dose alerts (thresholds live in patient_profiles).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `alert_type` | varchar(20) | NO |  |  |
| `severity` | varchar(10) | NO |  |  |
| `glucose_log_id` | bigint | yes |  |  |
| `reminder_event_id` | bigint | yes |  |  |
| `value_mgdl` | numeric(5,1) | yes |  |  |
| `message` | varchar(500) | NO |  |  |
| `triggered_at` | timestamptz | NO | now() |  |
| `status` | varchar(15) | NO | 'OPEN'::character varying |  |
| `acknowledged_by` | bigint | yes |  |  |
| `acknowledged_at` | timestamptz | yes |  |  |
| `resolved_at` | timestamptz | yes |  |  |
| `follow_up_due_at` | timestamptz | yes |  | "follow-up prompt after an abnormal reading" |
| `follow_up_completed_at` | timestamptz | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(acknowledged_by) REFERENCES users(id) ON DELETE SET NULL`
- **Foreign key:** `(glucose_log_id) REFERENCES glucose_logs(id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(reminder_event_id) REFERENCES reminder_events(id) ON DELETE SET NULL`
- **Check:** `(alert_type IN ('URGENT_LOW', 'LOW', 'HIGH', 'URGENT_HIGH', 'RAPID_RISE', 'RAPID_FALL', 'MISSED_DOSE', 'NO_DATA', 'PREDICTIVE_LOW'))`
- **Check:** `(severity IN ('INFO', 'WARNING', 'CRITICAL'))`
- **Check:** `(status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'DISMISSED'))`
- **Index:** `INDEX ix_alerts_open ON public.alerts USING btree (patient_id) WHERE ((status)::text = 'OPEN'::text)`
- **Index:** `INDEX ix_alerts_patient_time ON public.alerts USING btree (patient_id, triggered_at DESC)`

<a id="publicaudit_logs"></a>
### public.audit_logs (table)

Append-only audit trail (UPDATE/DELETE/TRUNCATE are rejected by trigger, except detaching a deleted user).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `user_id` | bigint | yes |  | who acted |
| `patient_id` | bigint | yes |  | whose data was touched (no FK: history must outlive the patient row) |
| `action` | varchar(60) | NO |  | LOGIN, LOGIN_FAILED, VIEW_PATIENT_DATA, SHARE_GRANTED, EXPORT_REPORT ... |
| `entity_type` | varchar(60) | yes |  |  |
| `entity_id` | varchar(64) | yes |  |  |
| `ip_address` | varchar(45) | yes |  |  |
| `user_agent` | varchar(255) | yes |  |  |
| `success` | boolean | NO | true |  |
| `details` | jsonb | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE SET NULL`
- **Index:** `INDEX ix_audit_logs_action_time ON public.audit_logs USING btree (action, created_at DESC)`
- **Index:** `INDEX ix_audit_logs_patient_time ON public.audit_logs USING btree (patient_id, created_at DESC)`
- **Index:** `INDEX ix_audit_logs_user_time ON public.audit_logs USING btree (user_id, created_at DESC)`

<a id="publiccare_relationships"></a>
### public.care_relationships (table)

Patient-controlled sharing (POST /share, DELETE /revoke). Per-permission flags; see fn_can_access().

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `member_id` | bigint | NO |  |  |
| `member_role` | varchar(20) | NO |  |  |
| `status` | varchar(20) | NO | 'PENDING'::character varying |  |
| `can_view_glucose` | boolean | NO | true |  |
| `can_view_meals` | boolean | NO | true |  |
| `can_view_medications` | boolean | NO | true |  |
| `can_view_activity` | boolean | NO | true |  |
| `can_view_reports` | boolean | NO | true |  |
| `can_receive_alerts` | boolean | NO | true |  |
| `can_add_recommendations` | boolean | NO | false | clinicians only in practice |
| `invited_by` | bigint | yes |  |  |
| `invited_at` | timestamptz | NO | now() |  |
| `responded_at` | timestamptz | yes |  |  |
| `revoked_at` | timestamptz | yes |  |  |
| `expires_at` | timestamptz | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(invited_by) REFERENCES users(id) ON DELETE SET NULL`
- **Foreign key:** `(member_id) REFERENCES users(id) ON DELETE CASCADE`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(member_role IN ('CLINICIAN', 'CAREGIVER'))`
- **Check:** `(status IN ('PENDING', 'ACTIVE', 'REVOKED', 'DECLINED'))`
- **Check:** `((patient_id <> member_id))`
- **Index:** `INDEX ix_care_member ON public.care_relationships USING btree (member_id, status)`
- **Index:** `INDEX ix_care_patient ON public.care_relationships USING btree (patient_id, status)`
- **Index:** `UNIQUE INDEX ux_care_open_pair ON public.care_relationships USING btree (patient_id, member_id) WHERE ((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying])::text[]))`

<a id="publicclinician_profiles"></a>
### public.clinician_profiles (table)

DOCTOR table of the report: one row per clinician user.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `user_id` | bigint | NO |  |  |
| `specialization` | varchar(100) | NO | 'General'::character varying |  |
| `hospital_name` | varchar(150) | yes |  |  |
| `license_number` | varchar(50) | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(user_id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`

<a id="publiccsv_imports"></a>
### public.csv_imports (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `uploaded_by` | bigint | yes |  |  |
| `filename` | varchar(255) | NO |  |  |
| `file_format` | varchar(15) | NO | 'GENERIC_CSV'::character varying |  |
| `rows_total` | integer | NO | 0 |  |
| `rows_imported` | integer | NO | 0 |  |
| `rows_rejected` | integer | NO | 0 |  |
| `status` | varchar(12) | NO | 'PENDING'::character varying |  |
| `error_summary` | text | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `completed_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(uploaded_by) REFERENCES users(id) ON DELETE SET NULL`
- **Check:** `(file_format IN ('LIBRE', 'DEXCOM', 'MEDTRONIC', 'GENERIC_CSV', 'OTHER'))`
- **Check:** `((rows_imported >= 0))`
- **Check:** `((rows_rejected >= 0))`
- **Check:** `((rows_total >= 0))`
- **Check:** `(status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'))`
- **Index:** `INDEX ix_csv_imports_patient ON public.csv_imports USING btree (patient_id, created_at DESC)`

<a id="publicdevice_tokens"></a>
### public.device_tokens (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `user_id` | bigint | NO |  |  |
| `token` | varchar(512) | NO |  | Firebase Cloud Messaging registration token |
| `platform` | varchar(10) | NO |  |  |
| `is_active` | boolean | NO | true |  |
| `last_seen_at` | timestamptz | NO | now() |  |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`
- **Unique:** `(token)`
- **Check:** `(platform IN ('ANDROID', 'IOS', 'WEB'))`
- **Index:** `UNIQUE INDEX device_tokens_token_key ON public.device_tokens USING btree (token)`
- **Index:** `INDEX ix_device_tokens_user ON public.device_tokens USING btree (user_id) WHERE is_active`

<a id="publicfood_catalog"></a>
### public.food_catalog (table)

Foods known to the app / the photo-recognition model with per-100 g nutrition. Seeded from Food-101 with ROUGH ESTIMATES (is_verified = false).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `name` | varchar(100) | NO |  | machine name, e.g. apple_pie (= Food-101 class name) |
| `display_name` | varchar(150) | NO |  |  |
| `kcal_per_100g` | numeric(6,1) | yes |  |  |
| `carbs_g_per_100g` | numeric(5,1) | yes |  |  |
| `default_serving_g` | numeric(6,1) | yes |  |  |
| `nutrition_source` | varchar(100) | NO | 'unknown'::character varying |  |
| `is_verified` | boolean | NO | false | false = rough estimate, do not use for dosing decisions |
| `research_class_id` | integer | yes |  | research.food_classes.class_id (photo model label) |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Unique:** `(name)`
- **Index:** `UNIQUE INDEX food_catalog_name_key ON public.food_catalog USING btree (name)`

<a id="publicglucose_logs"></a>
### public.glucose_logs (table)

Glucose readings (planned Glucose table of the report). Always mg/dL. CGM data can produce many rows per day: query with the (patient_id, measurement_time) index.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `glucose_value` | integer | NO |  | mg/dL (report: INT, app validates 0-500) |
| `measurement_time` | timestamptz | NO |  |  |
| `meal_context` | varchar(20) | yes |  |  |
| `source` | varchar(20) | NO | 'MANUAL'::character varying |  |
| `notes` | text | yes |  |  |
| `entered_by` | bigint | yes |  |  |
| `client_uuid` | uuid | yes |  | generated by the mobile app: idempotent offline sync |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  | soft delete (sync) |

- **Primary key:** `(id)`
- **Foreign key:** `(entered_by) REFERENCES users(id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(((glucose_value >= 10) AND (glucose_value <= 600)))`
- **Check:** `(meal_context IN ('FASTING', 'BEFORE_MEAL', 'AFTER_MEAL', 'BEDTIME', 'EXERCISE', 'OTHER'))`
- **Check:** `(source IN ('MANUAL', 'METER', 'CGM', 'CSV_IMPORT', 'AI_ASSISTANT', 'WEARABLE'))`
- **Index:** `INDEX ix_glucose_logs_patient_time ON public.glucose_logs USING btree (patient_id, measurement_time DESC)`
- **Index:** `UNIQUE INDEX ux_glucose_logs_client ON public.glucose_logs USING btree (patient_id, client_uuid) WHERE (client_uuid IS NOT NULL)`

<a id="publicinsulin_logs"></a>
### public.insulin_logs (table)

Insulin doses in units (report HEALTH_DATA.insulin_dose, INT there, numeric here to allow 0.5 U steps).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `dose_units` | numeric(6,2) | NO |  |  |
| `insulin_type` | varchar(20) | NO | 'OTHER'::character varying |  |
| `delivery_method` | varchar(20) | NO | 'OTHER'::character varying |  |
| `product_name` | varchar(100) | yes |  |  |
| `administered_at` | timestamptz | NO |  |  |
| `meal_log_id` | bigint | yes |  |  |
| `source` | varchar(20) | NO | 'MANUAL'::character varying |  |
| `notes` | text | yes |  |  |
| `entered_by` | bigint | yes |  |  |
| `client_uuid` | uuid | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(entered_by) REFERENCES users(id) ON DELETE SET NULL`
- **Foreign key:** `(meal_log_id) REFERENCES meal_logs(id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(delivery_method IN ('PEN', 'SYRINGE', 'PUMP_BOLUS', 'PUMP_BASAL', 'OTHER'))`
- **Check:** `(((dose_units > (0)) AND (dose_units <= (300))))`
- **Check:** `(insulin_type IN ('RAPID', 'SHORT', 'INTERMEDIATE', 'LONG', 'MIXED', 'OTHER'))`
- **Check:** `(source IN ('MANUAL', 'PUMP', 'AI_ASSISTANT', 'IMPORT'))`
- **Index:** `INDEX ix_insulin_logs_patient_time ON public.insulin_logs USING btree (patient_id, administered_at DESC)`
- **Index:** `UNIQUE INDEX ux_insulin_logs_client ON public.insulin_logs USING btree (patient_id, client_uuid) WHERE (client_uuid IS NOT NULL)`

<a id="publiclab_results"></a>
### public.lab_results (table)

Laboratory values entered by the patient or a clinician: HbA1c, fasting / post-meal glucose, blood ketones.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `test_type` | varchar(30) | NO |  |  |
| `value` | numeric(8,2) | NO |  |  |
| `unit` | varchar(20) | NO |  | '%' (HbA1c, NGSP), 'mg/dL', 'mmol/L' |
| `taken_at` | timestamptz | NO |  |  |
| `source` | varchar(20) | NO | 'MANUAL'::character varying |  |
| `entered_by` | bigint | yes |  |  |
| `notes` | text | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(entered_by) REFERENCES users(id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(source IN ('MANUAL', 'CLINICIAN', 'LAB_IMPORT'))`
- **Check:** `(test_type IN ('HBA1C', 'FASTING_GLUCOSE', 'POSTPRANDIAL_GLUCOSE_2H', 'BLOOD_KETONE', 'OTHER'))`
- **Check:** `((value >= (0)))`
- **Index:** `INDEX ix_lab_results_patient_type_time ON public.lab_results USING btree (patient_id, test_type, taken_at DESC)`

<a id="publicmeal_log_items"></a>
### public.meal_log_items (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `meal_log_id` | bigint | NO |  |  |
| `food_catalog_id` | bigint | yes |  |  |
| `food_name` | varchar(150) | NO |  |  |
| `amount_g` | numeric(7,1) | yes |  |  |
| `carbs_g` | numeric(6,1) | yes |  |  |
| `calories_kcal` | numeric(7,1) | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(food_catalog_id) REFERENCES food_catalog(id) ON DELETE SET NULL`
- **Foreign key:** `(meal_log_id) REFERENCES meal_logs(id) ON DELETE CASCADE`
- **Check:** `((amount_g >= (0)))`
- **Check:** `((calories_kcal >= (0)))`
- **Check:** `((carbs_g >= (0)))`
- **Index:** `INDEX ix_meal_log_items_meal ON public.meal_log_items USING btree (meal_log_id)`

<a id="publicmeal_logs"></a>
### public.meal_logs (table)

Meals with carbohydrate intake (Breakfast / Lunch / Dinner / Snack). AI photo entries keep the model confidence.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `meal_type` | varchar(20) | NO |  |  |
| `eaten_at` | timestamptz | NO |  |  |
| `description` | text | yes |  |  |
| `carbs_g` | numeric(6,1) | yes |  |  |
| `calories_kcal` | numeric(7,1) | yes |  |  |
| `protein_g` | numeric(6,1) | yes |  |  |
| `fat_g` | numeric(6,1) | yes |  |  |
| `source` | varchar(20) | NO | 'MANUAL'::character varying |  |
| `photo_url` | text | yes |  |  |
| `ai_confidence` | numeric(4,3) | yes |  |  |
| `notes` | text | yes |  |  |
| `client_uuid` | uuid | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(((ai_confidence >= (0)) AND (ai_confidence <= (1))))`
- **Check:** `(((calories_kcal >= (0)) AND (calories_kcal <= (10000))))`
- **Check:** `(((carbs_g >= (0)) AND (carbs_g <= (1000))))`
- **Check:** `((fat_g >= (0)))`
- **Check:** `(meal_type IN ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'OTHER'))`
- **Check:** `((protein_g >= (0)))`
- **Check:** `(source IN ('MANUAL', 'AI_ASSISTANT', 'AI_PHOTO', 'IMPORT'))`
- **Index:** `INDEX ix_meal_logs_patient_time ON public.meal_logs USING btree (patient_id, eaten_at DESC)`
- **Index:** `UNIQUE INDEX ux_meal_logs_client ON public.meal_logs USING btree (patient_id, client_uuid) WHERE (client_uuid IS NOT NULL)`

<a id="publicmedication_intakes"></a>
### public.medication_intakes (table)

History of non-insulin medicine doses taken (insulin doses go to insulin_logs).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `medication_id` | bigint | yes |  |  |
| `medication_name` | varchar(100) | NO |  |  |
| `dose_text` | varchar(50) | yes |  |  |
| `taken_at` | timestamptz | NO |  |  |
| `status` | varchar(10) | NO | 'TAKEN'::character varying |  |
| `reminder_event_id` | bigint | yes |  |  |
| `notes` | text | yes |  |  |
| `client_uuid` | uuid | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(medication_id) REFERENCES medications(id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(reminder_event_id) REFERENCES reminder_events(id) ON DELETE SET NULL`
- **Check:** `(status IN ('TAKEN', 'MISSED', 'SKIPPED'))`
- **Index:** `INDEX ix_medication_intakes_patient_time ON public.medication_intakes USING btree (patient_id, taken_at DESC)`
- **Index:** `UNIQUE INDEX ux_medication_intakes_client ON public.medication_intakes USING btree (patient_id, client_uuid) WHERE (client_uuid IS NOT NULL)`

<a id="publicmedications"></a>
### public.medications (table)

The patient's regular medication list (insulin and oral agents).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `name` | varchar(100) | NO |  |  |
| `medication_type` | varchar(20) | NO | 'OTHER'::character varying |  |
| `dosage` | varchar(50) | yes |  | text as in the report, e.g. '500 mg' or '10 units' |
| `dose_amount` | numeric(8,2) | yes |  |  |
| `dose_unit` | varchar(20) | yes |  |  |
| `frequency_text` | varchar(100) | yes |  |  |
| `instructions` | text | yes |  |  |
| `prescribed_by` | bigint | yes |  |  |
| `start_date` | date | yes |  |  |
| `end_date` | date | yes |  |  |
| `is_active` | boolean | NO | true |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(prescribed_by) REFERENCES clinician_profiles(user_id) ON DELETE SET NULL`
- **Check:** `((dose_amount > (0)))`
- **Check:** `(medication_type IN ('INSULIN', 'ORAL', 'INJECTABLE_OTHER', 'SUPPLEMENT', 'OTHER'))`
- **Index:** `INDEX ix_medications_patient ON public.medications USING btree (patient_id, is_active)`

<a id="publicnotifications"></a>
### public.notifications (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `recipient_id` | bigint | NO |  |  |
| `alert_id` | bigint | yes |  |  |
| `reminder_event_id` | bigint | yes |  |  |
| `notification_type` | varchar(20) | NO |  |  |
| `title` | varchar(150) | NO |  |  |
| `body` | text | yes |  |  |
| `channel` | varchar(10) | NO | 'IN_APP'::character varying |  |
| `status` | varchar(10) | NO | 'PENDING'::character varying |  |
| `error_message` | varchar(500) | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `sent_at` | timestamptz | yes |  |  |
| `read_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(alert_id) REFERENCES alerts(id) ON DELETE SET NULL`
- **Foreign key:** `(recipient_id) REFERENCES users(id) ON DELETE CASCADE`
- **Foreign key:** `(reminder_event_id) REFERENCES reminder_events(id) ON DELETE SET NULL`
- **Check:** `(channel IN ('PUSH', 'EMAIL', 'IN_APP'))`
- **Check:** `(notification_type IN ('ALERT', 'REMINDER', 'SHARE_INVITE', 'RECOMMENDATION', 'REPORT_READY', 'SYSTEM'))`
- **Check:** `(status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'READ'))`
- **Index:** `INDEX ix_notifications_pending ON public.notifications USING btree (created_at) WHERE ((status)::text = 'PENDING'::text)`
- **Index:** `INDEX ix_notifications_recipient ON public.notifications USING btree (recipient_id, created_at DESC)`

<a id="publicpassword_reset_tokens"></a>
### public.password_reset_tokens (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `user_id` | bigint | NO |  |  |
| `token_hash` | varchar(128) | NO |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `expires_at` | timestamptz | NO |  |  |
| `used_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`
- **Unique:** `(token_hash)`
- **Index:** `INDEX ix_password_reset_user ON public.password_reset_tokens USING btree (user_id)`
- **Index:** `UNIQUE INDEX password_reset_tokens_token_hash_key ON public.password_reset_tokens USING btree (token_hash)`

<a id="publicpatient_profiles"></a>
### public.patient_profiles (table)

PATIENT table of the report: one row per patient user (diabetes type, targets, alert thresholds).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `user_id` | bigint | NO |  |  |
| `diabetes_type` | varchar(20) | NO |  |  |
| `date_of_birth` | date | yes |  |  |
| `sex` | varchar(10) | yes |  |  |
| `height_cm` | numeric(5,1) | yes |  |  |
| `weight_kg` | numeric(5,1) | yes |  |  |
| `diagnosis_year` | smallint | yes |  |  |
| `therapy_type` | varchar(20) | yes |  |  |
| `target_min_mgdl` | smallint | NO | 70 | time-in-range window |
| `target_max_mgdl` | smallint | NO | 180 |  |
| `hypo_threshold_mgdl` | smallint | NO | 70 | alert when glucose <= this  (report: <= 70) |
| `hyper_threshold_mgdl` | smallint | NO | 180 | alert when glucose >= this  (report: >= 180) |
| `urgent_low_mgdl` | smallint | NO | 54 | emergency alert |
| `urgent_high_mgdl` | smallint | NO | 250 |  |
| `emergency_contact_name` | varchar(100) | yes |  |  |
| `emergency_contact_phone` | varchar(30) | yes |  |  |
| `research_patient_id` | varchar(30) | yes |  | provenance of demo patients (research.patients.patient_id) |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(user_id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`
- **Check:** `(((urgent_low_mgdl <= hypo_threshold_mgdl) AND (hypo_threshold_mgdl < hyper_threshold_mgdl) AND (hyper_threshold_mgdl <= urgent_high_mgdl)))`
- **Check:** `((target_min_mgdl < target_max_mgdl))`
- **Check:** `(diabetes_type IN ('TYPE_1', 'TYPE_2', 'GESTATIONAL', 'OTHER'))`
- **Check:** `(((diagnosis_year >= 1900) AND (diagnosis_year <= 2100)))`
- **Check:** `(((height_cm >= (30)) AND (height_cm <= (260))))`
- **Check:** `(sex IN ('FEMALE', 'MALE', 'OTHER'))`
- **Check:** `(therapy_type IN ('MDI', 'PUMP', 'ORAL', 'DIET', 'MIXED', 'OTHER'))`
- **Check:** `(((weight_kg >= (2)) AND (weight_kg <= (500))))`

<a id="publicrecommendations"></a>
### public.recommendations (table)

Clinician feedback / suggestions to a patient (UC-15). DiaMate is not a diagnostic tool: text is advisory.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `clinician_id` | bigint | NO |  |  |
| `message` | text | NO |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `read_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(clinician_id) REFERENCES clinician_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Index:** `INDEX ix_recommendations_patient ON public.recommendations USING btree (patient_id, created_at DESC)`

<a id="publicrefresh_tokens"></a>
### public.refresh_tokens (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `user_id` | bigint | NO |  |  |
| `token_hash` | varchar(128) | NO |  | store a hash, never the token |
| `issued_at` | timestamptz | NO | now() |  |
| `expires_at` | timestamptz | NO |  |  |
| `revoked_at` | timestamptz | yes |  |  |
| `user_agent` | varchar(255) | yes |  |  |
| `ip_address` | varchar(45) | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`
- **Unique:** `(token_hash)`
- **Index:** `INDEX ix_refresh_tokens_user ON public.refresh_tokens USING btree (user_id)`
- **Index:** `UNIQUE INDEX refresh_tokens_token_hash_key ON public.refresh_tokens USING btree (token_hash)`

<a id="publicreminder_events"></a>
### public.reminder_events (table)

One row per due reminder occurrence: PENDING -> SENT -> TAKEN / MISSED (missed-dose tracking and adherence).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `reminder_id` | bigint | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `scheduled_for` | timestamptz | NO |  |  |
| `status` | varchar(10) | NO | 'PENDING'::character varying |  |
| `sent_at` | timestamptz | yes |  |  |
| `acknowledged_at` | timestamptz | yes |  |  |
| `snoozed_until` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(reminder_id) REFERENCES reminders(id) ON DELETE CASCADE`
- **Unique:** `(reminder_id, scheduled_for)`
- **Check:** `(status IN ('PENDING', 'SENT', 'TAKEN', 'MISSED', 'SNOOZED', 'SKIPPED'))`
- **Index:** `INDEX ix_reminder_events_patient_time ON public.reminder_events USING btree (patient_id, scheduled_for DESC)`
- **Index:** `INDEX ix_reminder_events_pending ON public.reminder_events USING btree (scheduled_for) WHERE ((status)::text = ANY ((ARRAY['PENDING'::character varying, 'SENT'::character varying, 'SNOOZED'::character varying])::text[]))`
- **Index:** `UNIQUE INDEX ux_reminder_event ON public.reminder_events USING btree (reminder_id, scheduled_for)`

<a id="publicreminders"></a>
### public.reminders (table)

Reminder definitions (planned Reminder table of the report). Occurrences and missed-dose flow: reminder_events.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `medication_id` | bigint | yes |  |  |
| `reminder_type` | varchar(20) | NO | 'MEDICATION'::character varying |  |
| `medication_name` | varchar(100) | yes |  | report Reminder.medication_name |
| `dosage` | varchar(50) | yes |  | report Reminder.dosage |
| `message` | varchar(255) | yes |  |  |
| `scheduled_time` | time without time zone | NO |  | local time of day in `timezone` |
| `days_of_week` | varchar(27) | NO | 'MON,TUE,WED,THU,FRI,SAT,SUN'::character varying |  |
| `timezone` | varchar(50) | NO | 'UTC'::character varying |  |
| `is_active` | boolean | NO | true |  |
| `missed_count` | integer | NO | 0 |  |
| `last_triggered_at` | timestamptz | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(medication_id) REFERENCES medications(id) ON DELETE CASCADE`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `((missed_count >= 0))`
- **Check:** `(reminder_type IN ('MEDICATION', 'GLUCOSE_CHECK', 'MEAL', 'APPOINTMENT', 'OTHER'))`
- **Index:** `INDEX ix_reminders_due ON public.reminders USING btree (scheduled_time) WHERE is_active`
- **Index:** `INDEX ix_reminders_patient ON public.reminders USING btree (patient_id, is_active)`

<a id="publicreports"></a>
### public.reports (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `requested_by` | bigint | yes |  |  |
| `report_type` | varchar(10) | NO |  |  |
| `format` | varchar(5) | NO | 'PDF'::character varying |  |
| `period_start` | timestamptz | NO |  |  |
| `period_end` | timestamptz | NO |  |  |
| `status` | varchar(10) | NO | 'PENDING'::character varying |  |
| `file_path` | varchar(500) | yes |  |  |
| `file_size_bytes` | bigint | yes |  |  |
| `summary` | jsonb | yes |  | statistics snapshot (see fn_glucose_summary) |
| `created_at` | timestamptz | NO | now() |  |
| `generated_at` | timestamptz | yes |  |  |
| `expires_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Foreign key:** `(requested_by) REFERENCES users(id) ON DELETE SET NULL`
- **Check:** `((period_end > period_start))`
- **Check:** `((file_size_bytes >= 0))`
- **Check:** `(format IN ('PDF', 'CSV'))`
- **Check:** `(report_type IN ('DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM'))`
- **Check:** `(status IN ('PENDING', 'READY', 'FAILED'))`
- **Index:** `INDEX ix_reports_patient ON public.reports USING btree (patient_id, created_at DESC)`

<a id="publicsymptom_logs"></a>
### public.symptom_logs (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `symptom_type` | varchar(40) | NO |  |  |
| `severity` | smallint | NO |  |  |
| `occurred_at` | timestamptz | NO |  |  |
| `notes` | text | yes |  |  |
| `client_uuid` | uuid | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |
| `deleted_at` | timestamptz | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(((severity >= 1) AND (severity <= 5)))`
- **Check:** `(symptom_type IN ('DIZZINESS', 'SHAKING', 'SWEATING', 'HUNGER', 'FATIGUE', 'THIRST', 'FREQUENT_URINATION', 'BLURRED_VISION', 'NAUSEA', 'HEADACHE', 'OTHER'))`
- **Index:** `INDEX ix_symptom_logs_patient_time ON public.symptom_logs USING btree (patient_id, occurred_at DESC)`

<a id="publictreatment_plans"></a>
### public.treatment_plans (table)

TREATMENT_PLAN table of the report.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `clinician_id` | bigint | yes |  |  |
| `target_glucose_min` | smallint | yes |  | report: target_glucose '90-130 mg/dL' |
| `target_glucose_max` | smallint | yes |  |  |
| `prescribed_insulin` | varchar(200) | yes |  | report: prescribed_insulin (type and dosage, free text) |
| `notes` | text | yes |  |  |
| `start_date` | date | NO | CURRENT_DATE |  |
| `end_date` | date | yes |  |  |
| `is_active` | boolean | NO | true |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Foreign key:** `(clinician_id) REFERENCES clinician_profiles(user_id) ON DELETE SET NULL`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Check:** `(((end_date IS NULL) OR (end_date >= start_date)))`
- **Check:** `(((target_glucose_min IS NULL) OR (target_glucose_max IS NULL) OR (target_glucose_min < target_glucose_max)))`
- **Check:** `(((target_glucose_max >= 40) AND (target_glucose_max <= 400)))`
- **Check:** `(((target_glucose_min >= 40) AND (target_glucose_min <= 400)))`
- **Index:** `INDEX ix_treatment_plans_patient ON public.treatment_plans USING btree (patient_id, is_active)`

<a id="publicuser_settings"></a>
### public.user_settings (table)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `user_id` | bigint | NO |  |  |
| `language` | varchar(10) | NO | 'en'::character varying |  |
| `glucose_unit` | varchar(10) | NO | 'MG_DL'::character varying |  |
| `font_scale` | numeric(3,2) | NO | 1.00 | WCAG: large fonts |
| `high_contrast` | boolean | NO | false |  |
| `voice_input_enabled` | boolean | NO | true |  |
| `push_enabled` | boolean | NO | true |  |
| `email_reports_enabled` | boolean | NO | false |  |
| `timezone` | varchar(50) | NO | 'UTC'::character varying |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(user_id)`
- **Foreign key:** `(user_id) REFERENCES users(id) ON DELETE CASCADE`
- **Check:** `(((font_scale >= 0.80) AND (font_scale <= 2.50)))`
- **Check:** `(glucose_unit IN ('MG_DL', 'MMOL_L'))`

<a id="publicusers"></a>
### public.users (table)

Every account (patient, clinician, caregiver, admin). Role-specific data lives in the *_profiles tables.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `email` | varchar(150) | NO |  |  |
| `password_hash` | varchar(255) | NO |  | bcrypt ($2a$/$2b$), written by the backend only |
| `role` | varchar(20) | NO |  |  |
| `full_name` | varchar(100) | NO |  |  |
| `phone` | varchar(30) | yes |  |  |
| `is_active` | boolean | NO | true | false = deactivated (soft delete); never hard-delete health data owners |
| `is_demo` | boolean | NO | false | true for the seeded demo accounts |
| `email_verified` | boolean | NO | false |  |
| `two_factor_enabled` | boolean | NO | false |  |
| `two_factor_secret` | varchar(255) | yes |  | TOTP secret, encrypted by the backend |
| `failed_login_attempts` | integer | NO | 0 |  |
| `locked_until` | timestamptz | yes |  |  |
| `last_login_at` | timestamptz | yes |  |  |
| `created_at` | timestamptz | NO | now() |  |
| `updated_at` | timestamptz | NO | now() |  |

- **Primary key:** `(id)`
- **Check:** `((failed_login_attempts >= 0))`
- **Check:** `(role IN ('PATIENT', 'CLINICIAN', 'CAREGIVER', 'ADMIN'))`
- **Index:** `INDEX ix_users_role ON public.users USING btree (role)`
- **Index:** `UNIQUE INDEX ux_users_email_lower ON public.users USING btree (lower((email)::text))`

<a id="publicwearable_samples"></a>
### public.wearable_samples (table)

Wearable integration data (Fitbit-style 5-minute samples).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | bigint | NO |  |  |
| `sample_time` | timestamptz | NO |  |  |
| `heart_rate_bpm` | smallint | yes |  |  |
| `steps` | integer | yes |  |  |
| `calories_kcal` | numeric(8,3) | yes |  |  |
| `source` | varchar(30) | NO | 'WEARABLE'::character varying |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES patient_profiles(user_id) ON DELETE CASCADE`
- **Unique:** `(patient_id, sample_time)`
- **Check:** `((calories_kcal >= (0)))`
- **Check:** `(((heart_rate_bpm >= 20) AND (heart_rate_bpm <= 260)))`
- **Check:** `((steps >= 0))`
- **Index:** `UNIQUE INDEX ux_wearable_patient_time ON public.wearable_samples USING btree (patient_id, sample_time)`

<a id="publicv_care_team"></a>
### public.v_care_team (view)

Sharing list for both directions: a patient's care team, or a clinician's / caregiver's patients.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `relationship_id` | bigint | yes |  |  |
| `patient_id` | bigint | yes |  |  |
| `patient_name` | varchar(100) | yes |  |  |
| `member_id` | bigint | yes |  |  |
| `member_name` | varchar(100) | yes |  |  |
| `member_email` | varchar(150) | yes |  |  |
| `member_role` | varchar(20) | yes |  |  |
| `status` | varchar(20) | yes |  |  |
| `can_view_glucose` | boolean | yes |  |  |
| `can_view_meals` | boolean | yes |  |  |
| `can_view_medications` | boolean | yes |  |  |
| `can_view_activity` | boolean | yes |  |  |
| `can_view_reports` | boolean | yes |  |  |
| `can_receive_alerts` | boolean | yes |  |  |
| `can_add_recommendations` | boolean | yes |  |  |
| `invited_at` | timestamptz | yes |  |  |
| `responded_at` | timestamptz | yes |  |  |
| `expires_at` | timestamptz | yes |  |  |

<a id="publicv_glucose_14d"></a>
### public.v_glucose_14d (view)

14-day CGM metrics (mean, GMI, CV, TIR/TBR/TAR) for every patient. Filter by patient_id to keep it cheap.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `n_readings` | bigint | yes |  |  |
| `mean_mgdl` | numeric | yes |  |  |
| `sd_mgdl` | numeric | yes |  |  |
| `cv_pct` | numeric | yes |  |  |
| `gmi_pct` | numeric | yes |  |  |
| `min_mgdl` | integer | yes |  |  |
| `max_mgdl` | integer | yes |  |  |
| `tir_pct` | numeric | yes |  |  |
| `tbr_pct` | numeric | yes |  |  |
| `tbr_severe_pct` | numeric | yes |  |  |
| `tar_pct` | numeric | yes |  |  |
| `tar_severe_pct` | numeric | yes |  |  |

<a id="publicv_glucose_daily"></a>
### public.v_glucose_daily (view)

Daily glucose statistics per patient (day in the user's time zone). Always filter by patient_id.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `day` | date | yes |  |  |
| `n_readings` | bigint | yes |  |  |
| `mean_mgdl` | numeric | yes |  |  |
| `min_mgdl` | integer | yes |  |  |
| `max_mgdl` | integer | yes |  |  |
| `sd_mgdl` | numeric | yes |  |  |
| `tir_pct` | numeric | yes |  |  |
| `tbr_pct` | numeric | yes |  |  |
| `tar_pct` | numeric | yes |  |  |

<a id="publicv_latest_glucose"></a>
### public.v_latest_glucose (view)

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `glucose_log_id` | bigint | yes |  |  |
| `glucose_value` | integer | yes |  |  |
| `measurement_time` | timestamptz | yes |  |  |
| `source` | varchar(20) | yes |  |  |

<a id="publicv_logbook"></a>
### public.v_logbook (view)

Union of all patient log tables ordered by event_time (ORDER BY is left to the query).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `event_time` | timestamptz | yes |  |  |
| `event_type` | text | yes |  |  |
| `ref_id` | bigint | yes |  |  |
| `title` | text | yes |  |  |
| `detail` | varchar | yes |  |  |
| `value` | numeric | yes |  |  |

<a id="publicv_patient_overview"></a>
### public.v_patient_overview (view)

One row per patient: profile, BMI, latest glucose, open alert count (dashboard header).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `email` | varchar(150) | yes |  |  |
| `full_name` | varchar(100) | yes |  |  |
| `is_active` | boolean | yes |  |  |
| `is_demo` | boolean | yes |  |  |
| `diabetes_type` | varchar(20) | yes |  |  |
| `therapy_type` | varchar(20) | yes |  |  |
| `sex` | varchar(10) | yes |  |  |
| `age_years` | integer | yes |  |  |
| `height_cm` | numeric(5,1) | yes |  |  |
| `weight_kg` | numeric(5,1) | yes |  |  |
| `bmi` | numeric | yes |  |  |
| `target_min_mgdl` | smallint | yes |  |  |
| `target_max_mgdl` | smallint | yes |  |  |
| `hypo_threshold_mgdl` | smallint | yes |  |  |
| `hyper_threshold_mgdl` | smallint | yes |  |  |
| `last_glucose_mgdl` | integer | yes |  |  |
| `last_glucose_at` | timestamptz | yes |  |  |
| `open_alerts` | bigint | yes |  |  |

<a id="publicv_reminder_adherence_30d"></a>
### public.v_reminder_adherence_30d (view)

Medication adherence: share of due reminders that were taken in the last 30 days.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | bigint | yes |  |  |
| `taken` | bigint | yes |  |  |
| `missed` | bigint | yes |  |  |
| `due` | bigint | yes |  |  |
| `adherence_pct` | numeric | yes |  |  |

## Schema `research`

<a id="researchactivity"></a>
### research.activity (table)

Heart rate, steps, calories, activity type (UC_HT_T1DM, BrisT1D, HUPA_UCM).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `heart_rate_bpm` | float8 | yes |  |  |
| `steps_5min` | float8 | yes |  |  |
| `source` | text | NO |  |  |
| `calories_kcal` | float8 | yes |  |  |
| `activity_type` | text | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Index:** `INDEX ix_activity_patient_id_timestamp ON research.activity USING btree (patient_id, "timestamp")`

<a id="researchbrfss_survey"></a>
### research.brfss_survey (table)

BRFSS 2015 health-indicator survey (253,680 respondents). Cross-sectional risk data, not a time series.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `survey_id` | integer | NO |  |  |
| `diabetes_012` | integer | yes |  |  |
| `diabetes_binary` | integer | yes |  |  |
| `high_bp` | integer | yes |  |  |
| `high_chol` | integer | yes |  |  |
| `chol_check` | integer | yes |  |  |
| `bmi` | integer | yes |  |  |
| `smoker` | integer | yes |  |  |
| `stroke` | integer | yes |  |  |
| `heart_disease_or_attack` | integer | yes |  |  |
| `phys_activity` | integer | yes |  |  |
| `fruits` | integer | yes |  |  |
| `veggies` | integer | yes |  |  |
| `heavy_alcohol` | integer | yes |  |  |
| `any_healthcare` | integer | yes |  |  |
| `no_doc_because_cost` | integer | yes |  |  |
| `general_health_1_5` | integer | yes |  |  |
| `mental_health_bad_days` | integer | yes |  |  |
| `physical_health_bad_days` | integer | yes |  |  |
| `diff_walking` | integer | yes |  |  |
| `sex_male` | integer | yes |  |  |
| `age_group_1_13` | integer | yes |  |  |
| `education_1_6` | integer | yes |  |  |
| `income_1_8` | integer | yes |  |  |

- **Primary key:** `(survey_id)`
- **Index:** `INDEX ix_brfss_survey_diabetes_012 ON research.brfss_survey USING btree (diabetes_012)`

<a id="researchfood_classes"></a>
### research.food_classes (table)

Food-101 class table (101 classes). *_est nutrition columns are rough estimates, verify before use.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `class_id` | integer | NO |  |  |
| `class_name` | text | NO |  |  |
| `display_name` | text | yes |  |  |
| `n_train_images` | integer | yes |  |  |
| `n_validation_images` | integer | yes |  |  |
| `kcal_per_100g_est` | integer | yes |  |  |
| `carbs_g_per_100g_est` | integer | yes |  | ROUGH ESTIMATE from general nutrition knowledge, not measured. |
| `typical_serving_g_est` | integer | yes |  |  |
| `carbs_g_per_serving_est` | float8 | yes |  |  |
| `nutrition_source` | text | yes |  |  |

- **Primary key:** `(class_id)`

<a id="researchfood_images"></a>
### research.food_images (table)

Food-101 image index (relative paths, images stay on disk).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `image_id` | integer | NO |  |  |
| `class_id` | integer | yes |  |  |
| `split` | text | NO |  |  |
| `relative_path` | text | NO |  |  |

- **Primary key:** `(image_id)`
- **Foreign key:** `(class_id) REFERENCES research.food_classes(class_id)`
- **Index:** `INDEX ix_food_images_class_id ON research.food_images USING btree (class_id)`

<a id="researchglucose_readings"></a>
### research.glucose_readings (table)

All glucose readings in mg/dL. reading_type = CGM or CBG_fingerstick. quality_flag marks suspicious values (nothing was deleted).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `glucose_mgdl` | float8 | NO |  |  |
| `reading_type` | text | NO |  |  |
| `source` | text | NO |  |  |
| `quality_flag` | text | yes |  | empty = ok; sensor_floor = CGM <= 40 mg/dL (sensor clips); implausible_value = CBG > 600 or < 20, CGM > 520. |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`
- **Index:** `INDEX ix_glucose_readings_patient_id_timestamp ON research.glucose_readings USING btree (patient_id, "timestamp")`

<a id="researchinsulin_doses"></a>
### research.insulin_doses (table)

Insulin events: subcutaneous, pump bolus / basal rate, intravenous, or BrisT1D total per 5 min.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `route` | text | NO |  |  |
| `kind` | text | NO |  |  |
| `product` | text | yes |  |  |
| `dose_iu` | float8 | yes |  |  |
| `rate_iu_per_h` | float8 | yes |  | Pump basal rate in U/h (UC_HT / HUPA basal per 5 min converted x12). |
| `raw_text` | text | yes |  |  |
| `source` | text | NO |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`
- **Index:** `INDEX ix_insulin_doses_patient_id_timestamp ON research.insulin_doses USING btree (patient_id, "timestamp")`

<a id="researchketones"></a>
### research.ketones (table)

Blood ketone measurements (Shanghai).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `ketone_mmol_l` | float8 | yes |  |  |
| `source` | text | NO |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`

<a id="researchmeal_items"></a>
### research.meal_items (table)

Shanghai meal descriptions split into food_name / amount / unit (g or ml).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `meal_id` | text | NO |  |  |
| `patient_id` | text | NO |  |  |
| `food_name` | text | NO |  |  |
| `amount` | float8 | yes |  |  |
| `unit` | text | yes |  |  |
| `raw_text` | text | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(meal_id) REFERENCES research.meals(meal_id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Index:** `INDEX ix_meal_items_meal_id ON research.meal_items USING btree (meal_id)`

<a id="researchmeals"></a>
### research.meals (table)

Meals. Shanghai: text description only; UC_HT / BrisT1D / HUPA_UCM: carbs_g.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `meal_id` | text | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `is_recorded` | boolean | yes |  |  |
| `description_en` | text | yes |  |  |
| `carbs_g` | float8 | yes |  |  |
| `kcal` | float8 | yes |  |  |
| `source` | text | NO |  |  |

- **Primary key:** `(meal_id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`
- **Index:** `INDEX ix_meals_patient_id_timestamp ON research.meals USING btree (patient_id, "timestamp")`

<a id="researchoral_medications"></a>
### research.oral_medications (table)

Non-insulin glucose-lowering drugs, one row per drug, dose_mg.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `drug` | text | yes |  |  |
| `dose_mg` | float8 | yes |  | Dose in mg, converted from the unit written in the source. Shanghai voglibose entries written as 0.1 / 0.2 / 0.4 g (= 100-400 mg) are almost certainly unit typos in the source (usual dose 0.2 mg): do not use them as real doses. |
| `raw_text` | text | yes |  |  |
| `source` | text | NO |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`
- **Index:** `INDEX ix_oral_medications_patient_id_timestamp ON research.oral_medications USING btree (patient_id, "timestamp")`

<a id="researchpatients"></a>
### research.patients (table)

One row per person from the merged open datasets (166): source, diabetes type, sex, age. NOT application users.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `patient_id` | text | NO |  |  |
| `source` | text | NO |  |  |
| `diabetes_type` | text | NO |  |  |
| `sex` | text | yes |  |  |
| `age_years` | float8 | yes |  |  |
| `time_basis` | text | NO |  | real = true calendar dates; relative_anchor_2000-01-01 = BrisT1D (no dates in the source, timeline starts 2000-01-01). |
| `n_records` | integer | NO |  |  |

- **Primary key:** `(patient_id)`

<a id="researchrecords"></a>
### research.records (table)

One row per recording period: clinical and lab summary (Shanghai patients can have several records).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `record_id` | text | NO |  |  |
| `patient_id` | text | NO |  |  |
| `source` | text | NO |  |  |
| `diabetes_type` | text | NO |  |  |
| `time_basis` | text | NO |  |  |
| `sex` | text | yes |  |  |
| `age_years` | float8 | yes |  |  |
| `height_m` | float8 | yes |  |  |
| `weight_kg` | float8 | yes |  |  |
| `bmi` | float8 | yes |  |  |
| `diabetes_duration_years` | float8 | yes |  |  |
| `hba1c_mmol_mol` | float8 | yes |  |  |
| `hba1c_pct` | float8 | yes |  |  |
| `fasting_glucose_mgdl` | float8 | yes |  |  |
| `postprandial_2h_glucose_mgdl` | float8 | yes |  |  |
| `hypoglycemia_history` | text | yes |  |  |
| `hypoglycemic_agents` | text | yes |  |  |
| `comorbidities` | text | yes |  |  |

- **Primary key:** `(record_id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Index:** `INDEX ix_records_patient_id ON research.records USING btree (patient_id)`

<a id="researchsources"></a>
### research.sources (table)

Citation and licence notes for every source dataset.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `source` | text | NO |  |  |
| `citation` | text | yes |  |  |
| `licence_note` | text | yes |  |  |

- **Primary key:** `(source)`

<a id="researchtimeline"></a>
### research.timeline (table)

Flat convenience table: one row per patient/timestamp with glucose, meal, insulin, oral drug and activity side by side.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `id` | bigint (identity) | NO |  |  |
| `patient_id` | text | NO |  |  |
| `record_id` | text | NO |  |  |
| `source` | text | NO |  |  |
| `diabetes_type` | text | NO |  |  |
| `time_basis` | text | NO |  |  |
| `timestamp` | timestamp | NO |  |  |
| `cgm_mgdl` | float8 | yes |  |  |
| `cgm_flag` | text | yes |  |  |
| `cbg_fingerstick_mgdl` | float8 | yes |  |  |
| `cbg_flag` | text | yes |  |  |
| `meal_recorded` | boolean | yes |  |  |
| `carbs_g` | float8 | yes |  |  |
| `meal_text` | text | yes |  |  |
| `sc_insulin_iu` | float8 | yes |  |  |
| `sc_insulin_product` | text | yes |  |  |
| `pump_bolus_iu` | float8 | yes |  |  |
| `pump_basal_iu_per_h` | float8 | yes |  |  |
| `iv_insulin_iu` | float8 | yes |  |  |
| `insulin_iu_5min_total` | float8 | yes |  |  |
| `oral_drugs` | text | yes |  |  |
| `heart_rate_bpm` | float8 | yes |  |  |
| `steps_5min` | float8 | yes |  |  |
| `calories_kcal` | float8 | yes |  |  |
| `activity_type` | text | yes |  |  |

- **Primary key:** `(id)`
- **Foreign key:** `(patient_id) REFERENCES research.patients(patient_id)`
- **Foreign key:** `(record_id) REFERENCES research.records(record_id)`
- **Index:** `INDEX ix_timeline_patient_id_timestamp ON research.timeline USING btree (patient_id, "timestamp")`
- **Index:** `INDEX ix_timeline_source ON research.timeline USING btree (source)`

## Functions

| Function | Arguments | Returns | Description |
|---|---|---|---|
| `demo_import_research_patient` | `p_user_id bigint, p_research_id text, p_days integer DEFAULT 90, p_shift boolean DEFAULT true` | `jsonb` | Demo/dev helper: copies recent research.* data of one open-dataset patient into a patient user's log tables. |
| `fn_can_access` | `p_viewer bigint, p_patient bigint, p_permission text DEFAULT 'glucose'::text` | `boolean` | Authorisation helper: patient itself, or clinician/caregiver with an ACTIVE care relationship that grants the permission. |
| `fn_glucose_alert_type` | `p_patient bigint, p_value numeric` | `text` | Returns URGENT_LOW / LOW / HIGH / URGENT_HIGH or NULL for a reading. Alert creation itself is left to the backend. |
| `fn_glucose_stats` | `p_patient bigint, p_from timestamp with time zone, p_to timestamp with time zone` | `TABLE(n_readings bigint, mean_mgdl numeric, sd_mgdl numeric, cv_pct numeric, gmi_pct numeric, min_mgdl integer, max_mgdl integer, tir_pct numeric, tbr_pct numeric, tbr_severe_pct numeric, tar_pct numeric, tar_severe_pct numeric)` | Mean, SD, CV, GMI, min/max and time in/below/above range for one patient and period. |
| `fn_glucose_summary` | `p_patient bigint, p_from timestamp with time zone, p_to timestamp with time zone` | `jsonb` | fn_glucose_stats as jsonb: store it in reports.summary. |
