-- V6: activity logs may come from the AI assistant (Dia), like glucose, insulin and meal logs.
--
-- The Database/sql package allowed only MANUAL / WEARABLE / IMPORT in activity_logs.source, so an activity the
-- patient confirmed in the assistant had to be saved as MANUAL and its origin was lost. The other log tables
-- already allow AI_ASSISTANT. The rule only gets wider: every existing row stays valid.

ALTER TABLE activity_logs DROP CONSTRAINT activity_logs_source_check;

ALTER TABLE activity_logs ADD CONSTRAINT activity_logs_source_check
    CHECK (source IN ('MANUAL', 'WEARABLE', 'IMPORT', 'AI_ASSISTANT'));
