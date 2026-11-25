-- V11: login sessions, for refresh tokens and logout (SECURITY.md S-C).
--
-- Every successful login opens one session (one device). The access token (JWT, short-lived) carries the session id
-- in its "sid" claim and is accepted only while the session is open, so a logout ends the access token at once too,
-- not only when it expires. The refresh token is a random value that the app keeps; only its SHA-256 hash is stored
-- here, so a database leak gives no usable token.
--
-- Rotation: every POST /auth/refresh replaces refresh_token_hash with a new one and keeps the previous hash. A
-- refresh token that is used a second time (previous_token_hash matches) means it was copied: the session is closed
-- (revoke_reason REUSED) and both the thief and the app have to log in again.
--
-- Default privileges (Database/sql/10_grants.sql) give diamate_app SELECT/INSERT/UPDATE/DELETE on this new table.

CREATE TABLE auth_sessions (
    id                  uuid         PRIMARY KEY,
    user_id             bigint       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    refresh_token_hash  varchar(64)  NOT NULL,
    previous_token_hash varchar(64),
    created_at          timestamptz  NOT NULL DEFAULT now(),
    last_refreshed_at   timestamptz,
    expires_at          timestamptz  NOT NULL,
    revoked_at          timestamptz,
    revoke_reason       varchar(20),
    CONSTRAINT ck_auth_sessions_revoke_reason
        CHECK (revoke_reason IS NULL OR revoke_reason IN ('LOGOUT', 'REUSED', 'ACCOUNT_DISABLED')),
    CONSTRAINT ck_auth_sessions_revoked_together
        CHECK ((revoked_at IS NULL) = (revoke_reason IS NULL))
);

CREATE UNIQUE INDEX ux_auth_sessions_refresh_token_hash ON auth_sessions (refresh_token_hash);
CREATE INDEX ix_auth_sessions_previous_token_hash ON auth_sessions (previous_token_hash)
    WHERE previous_token_hash IS NOT NULL;
CREATE INDEX ix_auth_sessions_user ON auth_sessions (user_id);

COMMENT ON TABLE auth_sessions IS 'one row per login (device): refresh token rotation and logout';
COMMENT ON COLUMN auth_sessions.refresh_token_hash IS 'SHA-256 (hex) of the current refresh token; the token itself is never stored';
COMMENT ON COLUMN auth_sessions.previous_token_hash IS 'hash of the refresh token before the last rotation, to detect reuse';
