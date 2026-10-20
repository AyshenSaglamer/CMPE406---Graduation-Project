-- V7: who resolved an alert.
--
-- alerts already records who handled an alert first (acknowledged_by / acknowledged_at) and when it was resolved
-- (resolved_at), but not who resolved it: when a caregiver acknowledges and the doctor resolves later, the doctor's
-- name was lost. Nullable, like acknowledged_by: older and still open alerts have no value.

ALTER TABLE alerts
    ADD COLUMN resolved_by bigint REFERENCES users (id) ON DELETE SET NULL;
