-- =============================================================================
-- 05_iam.sql — Identity & access management: accounts, passwords, MFA,
--              devices, sessions, lockouts, authentication events (schema: iam)
--
-- Login identifiers:
--   * username (= UID / employee code / enrollment no.)  -> iam.user_account.username
--   * email  -> pii.person_email (verified + is_login_enabled) -> person -> account
-- No duplicated "login identifier" table: email already has a global UNIQUE.
--
-- Secrets are never stored in clear: passwords use Django's hasher string,
-- tokens/OTPs/recovery codes are SHA-256/HMAC hashes, TOTP secrets are
-- envelope-encrypted by the application.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = iam, pii, people, ref, public;

-- ---------------------------------------------------------------- user_account --
-- Django: AUTH_USER_MODEL = iam.UserAccount (AbstractBaseUser with
-- last_login = None — last login is derived from iam.auth_event).
CREATE TABLE iam.user_account (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id          uuid NOT NULL UNIQUE REFERENCES people.person(id),
  username           citext NOT NULL UNIQUE CHECK (username ~ '^[A-Za-z0-9._-]{3,64}$'),
  password           varchar(255) NOT NULL,     -- Django hasher string ('!' prefix = unusable)
  account_status_id  smallint NOT NULL REFERENCES ref.account_status(id),
  is_superuser       boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('iam.user_account');

-- ------------------------------------------------------------ password_history --
-- Previous hashes only (the current one is user_account.password) — reuse policy.
CREATE TABLE iam.password_history (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id     uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  password_hash  varchar(255) NOT NULL,
  set_at         timestamptz NOT NULL,
  replaced_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (replaced_at >= set_at)
);
CREATE INDEX password_history_account_idx ON iam.password_history(account_id, replaced_at DESC);

-- --------------------------------------------------------- password_reset_token --
CREATE TABLE iam.password_reset_token (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id    uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  token_hash    bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  requested_ip  inet,
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL,
  used_at       timestamptz,
  CHECK (expires_at > created_at),
  CHECK (used_at IS NULL OR used_at >= created_at)
);
CREATE INDEX password_reset_token_account_idx ON iam.password_reset_token(account_id);

-- =================================================================== MFA ======
-- Class-table inheritance: mfa_factor (common) + one subtype table per factor
-- kind. A trigger guarantees the subtype row matches the factor's type.
CREATE TABLE iam.mfa_factor (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id          uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  mfa_factor_type_id  smallint NOT NULL REFERENCES ref.mfa_factor_type(id),
  label               text NOT NULL DEFAULT '',
  is_default          boolean NOT NULL DEFAULT false,
  confirmed_at        timestamptz,              -- NULL = enrolment not completed
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT is_default OR confirmed_at IS NOT NULL)
);
CREATE INDEX mfa_factor_account_idx ON iam.mfa_factor(account_id);
CREATE UNIQUE INDEX mfa_factor_one_default_uq ON iam.mfa_factor(account_id) WHERE is_default;
SELECT util.attach_updated_at('iam.mfa_factor');

CREATE TABLE iam.mfa_totp (
  factor_id          uuid PRIMARY KEY REFERENCES iam.mfa_factor(id) ON DELETE CASCADE,
  secret_ciphertext  bytea NOT NULL,
  digits             smallint NOT NULL DEFAULT 6  CHECK (digits IN (6, 8)),
  period_seconds     smallint NOT NULL DEFAULT 30 CHECK (period_seconds BETWEEN 15 AND 120)
);

CREATE TABLE iam.mfa_webauthn (
  factor_id      uuid PRIMARY KEY REFERENCES iam.mfa_factor(id) ON DELETE CASCADE,
  credential_id  bytea NOT NULL UNIQUE,
  public_key     bytea NOT NULL,
  aaguid         uuid,
  sign_count     bigint NOT NULL DEFAULT 0 CHECK (sign_count >= 0)
);

-- OTP delivered over an email or phone of the account's own person.
CREATE TABLE iam.mfa_otp_channel (
  factor_id        uuid PRIMARY KEY REFERENCES iam.mfa_factor(id) ON DELETE CASCADE,
  person_email_id  uuid REFERENCES pii.person_email(id) ON DELETE CASCADE,
  person_phone_id  uuid REFERENCES pii.person_phone(id) ON DELETE CASCADE,
  CHECK (num_nonnulls(person_email_id, person_phone_id) = 1)
);

-- Validates: subtype matches factor type; OTP target belongs to account's person.
CREATE OR REPLACE FUNCTION iam.mfa_subtype_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_type_code  text;
  v_person_id  uuid;
  v_ok         boolean;
BEGIN
  SELECT t.code, a.person_id INTO v_type_code, v_person_id
  FROM iam.mfa_factor f
  JOIN ref.mfa_factor_type t ON t.id = f.mfa_factor_type_id
  JOIN iam.user_account a ON a.id = f.account_id
  WHERE f.id = NEW.factor_id;

  IF NOT (v_type_code = ANY (TG_ARGV)) THEN
    RAISE EXCEPTION '%: factor % has type %, expected one of %',
      TG_TABLE_NAME, NEW.factor_id, v_type_code, TG_ARGV USING ERRCODE = 'check_violation';
  END IF;

  IF TG_TABLE_NAME = 'mfa_otp_channel' THEN
    SELECT EXISTS (SELECT 1 FROM pii.person_email WHERE id = NEW.person_email_id AND person_id = v_person_id)
        OR EXISTS (SELECT 1 FROM pii.person_phone WHERE id = NEW.person_phone_id AND person_id = v_person_id)
      INTO v_ok;
    IF NOT v_ok THEN
      RAISE EXCEPTION 'mfa_otp_channel: contact does not belong to the account''s person'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_mfa_totp_validate BEFORE INSERT OR UPDATE ON iam.mfa_totp
  FOR EACH ROW EXECUTE FUNCTION iam.mfa_subtype_validate('TOTP');
CREATE TRIGGER trg_mfa_webauthn_validate BEFORE INSERT OR UPDATE ON iam.mfa_webauthn
  FOR EACH ROW EXECUTE FUNCTION iam.mfa_subtype_validate('WEBAUTHN');
CREATE TRIGGER trg_mfa_otp_channel_validate BEFORE INSERT OR UPDATE ON iam.mfa_otp_channel
  FOR EACH ROW EXECUTE FUNCTION iam.mfa_subtype_validate('EMAIL_OTP', 'SMS_OTP');

CREATE TABLE iam.mfa_recovery_code (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id  uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  code_hash   bytea NOT NULL CHECK (octet_length(code_hash) = 32),
  created_at  timestamptz NOT NULL DEFAULT now(),
  used_at     timestamptz,
  UNIQUE (account_id, code_hash)
);

-- One-time codes: MFA login step, step-up, email/phone verification, reset.
CREATE TABLE iam.otp_challenge (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       uuid REFERENCES iam.user_account(id) ON DELETE CASCADE,
  otp_purpose_id   smallint NOT NULL REFERENCES ref.otp_purpose(id),
  mfa_factor_id    uuid REFERENCES iam.mfa_factor(id)      ON DELETE CASCADE,
  person_email_id  uuid REFERENCES pii.person_email(id)    ON DELETE CASCADE,
  person_phone_id  uuid REFERENCES pii.person_phone(id)    ON DELETE CASCADE,
  code_hash        bytea NOT NULL CHECK (octet_length(code_hash) = 32),
  attempt_count    smallint NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL,
  consumed_at      timestamptz,
  CHECK (num_nonnulls(mfa_factor_id, person_email_id, person_phone_id) = 1),
  CHECK (expires_at > created_at)
);
CREATE INDEX otp_challenge_account_idx ON iam.otp_challenge(account_id, created_at DESC);

-- ============================================================ devices/sessions ==
CREATE TABLE iam.user_device (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id        uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  fingerprint_hash  bytea NOT NULL CHECK (octet_length(fingerprint_hash) = 32),
  name              text,
  user_agent        text,
  first_seen_at     timestamptz NOT NULL DEFAULT now(),
  trusted_until     timestamptz,                 -- "remember this device" for MFA
  UNIQUE (account_id, fingerprint_hash)
);

-- Refresh-token sessions with rotation. Every refresh inserts a new row in the
-- same family and revokes the previous one; presenting a revoked token of a
-- family = token theft => revoke the whole family.
CREATE TABLE iam.user_session (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id                uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  device_id                 uuid REFERENCES iam.user_device(id) ON DELETE SET NULL,
  family_id                 uuid NOT NULL,
  refresh_token_hash        bytea NOT NULL UNIQUE CHECK (octet_length(refresh_token_hash) = 32),
  ip                        inet,
  mfa_verified_at           timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  expires_at                timestamptz NOT NULL,
  revoked_at                timestamptz,
  session_revoke_reason_id  smallint REFERENCES ref.session_revoke_reason(id),
  CHECK (expires_at > created_at),
  CHECK ((revoked_at IS NULL) = (session_revoke_reason_id IS NULL))
);
CREATE INDEX user_session_account_active_idx ON iam.user_session(account_id) WHERE revoked_at IS NULL;
CREATE INDEX user_session_family_idx ON iam.user_session(family_id);
-- at most one live token per family (rotation invariant)
CREATE UNIQUE INDEX user_session_family_one_active_uq ON iam.user_session(family_id) WHERE revoked_at IS NULL;

-- ------------------------------------------------------------ account_lockout --
CREATE TABLE iam.account_lockout (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id              uuid NOT NULL REFERENCES iam.user_account(id) ON DELETE CASCADE,
  lockout_reason_id       smallint NOT NULL REFERENCES ref.lockout_reason(id),
  period                  tstzrange NOT NULL,  -- [locked_at, locked_until) ; upper NULL = until released
  released_at             timestamptz,
  released_by_account_id  uuid REFERENCES iam.user_account(id),
  CHECK (NOT isempty(period) AND NOT lower_inf(period)),
  CHECK (released_at IS NULL OR released_at >= lower(period)),
  CONSTRAINT account_lockout_no_overlap EXCLUDE USING gist (account_id WITH =, period WITH &&)
);

-- ---------------------------------------------------------------- auth_event --
-- Append-only authentication log, partitioned by month. The attempted
-- identifier is stored only as a keyed HMAC (DPDP: no raw identifiers of
-- unknown/failed principals).
CREATE TABLE iam.auth_event (
  id                      bigint GENERATED ALWAYS AS IDENTITY,
  occurred_at             timestamptz NOT NULL DEFAULT now(),
  account_id              uuid REFERENCES iam.user_account(id) ON DELETE SET NULL,
  auth_event_type_id      smallint NOT NULL REFERENCES ref.auth_event_type(id),
  auth_failure_reason_id  smallint REFERENCES ref.auth_failure_reason(id),
  identifier_hmac         bytea CHECK (octet_length(identifier_hmac) = 32),
  session_id              uuid REFERENCES iam.user_session(id) ON DELETE SET NULL,
  mfa_factor_id           uuid REFERENCES iam.mfa_factor(id) ON DELETE SET NULL,
  ip                      inet,
  user_agent              text,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE INDEX auth_event_account_idx ON iam.auth_event(account_id, occurred_at DESC);
CREATE INDEX auth_event_identifier_idx ON iam.auth_event(identifier_hmac, occurred_at DESC);
CREATE TABLE iam.auth_event_default PARTITION OF iam.auth_event DEFAULT;
SELECT util.create_monthly_partitions('iam.auth_event', current_date, 13);
