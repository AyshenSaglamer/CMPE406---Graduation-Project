-- V3: remove the 1900-01-01 lower bound on users.date_of_birth (added in V2).
-- The backend already requires a past date and a minimum age of 16; the extra database limit was not needed.
-- V2 is not edited because it may already be applied (shared Neon database); a new version removes the constraint.

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_date_of_birth_check;
