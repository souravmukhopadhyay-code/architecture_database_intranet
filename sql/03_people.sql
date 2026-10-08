-- =============================================================================
-- 03_people.sql — Persons, employees, students, guardians (schemas: people, pii)
--                 + org.appointment (needs people.employee)
--
-- people.person is the ONE human entity. Employee / student / guardian /
-- nominee are roles a person plays, never separate copies of name/contact data.
--
-- Anything that identifies or profiles a person beyond their name lives in the
-- restricted `pii` schema (DPDP: access control + inventory in privacy.data_element).
-- Multi-valued facts (emails, phones, addresses, documents, photos) are 4NF
-- child tables; "current" values are derived via validity ranges, never copied.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = people, pii, org, ref, public;

-- ---------------------------------------------------------------- file_object --
-- Shared metadata for stored binaries (photos, consent evidence, notices ...).
CREATE TABLE people.file_object (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  storage_backend_id smallint NOT NULL REFERENCES ref.storage_backend(id),
  object_key         text NOT NULL,
  mime_type          text NOT NULL CHECK (mime_type ~ '^[a-z]+/[A-Za-z0-9.+-]+$'),
  byte_size          bigint NOT NULL CHECK (byte_size >= 0),
  sha256             bytea  NOT NULL CHECK (octet_length(sha256) = 32),
  uploaded_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (storage_backend_id, object_key)
);

-- --------------------------------------------------------------------- person --
CREATE TABLE people.person (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name      text NOT NULL CHECK (btrim(first_name) <> ''),
  middle_name     text,
  last_name       text,
  preferred_name  text,
  gender_id       smallint REFERENCES ref.gender(id),   -- optional (data minimisation)
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX person_name_idx ON people.person (lower(first_name), lower(last_name));
SELECT util.attach_updated_at('people.person');

-- ------------------------------------------------------------- person_profile --
-- 1:1 vertical split of sensitive demographics (access control, not normalisation).
CREATE TABLE pii.person_profile (
  person_id               uuid PRIMARY KEY REFERENCES people.person(id) ON DELETE CASCADE,
  date_of_birth           date CHECK (date_of_birth > DATE '1900-01-01'),
  blood_group_id          smallint REFERENCES ref.blood_group(id),
  nationality_country_id  smallint REFERENCES ref.country(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('pii.person_profile');

-- --------------------------------------------------------------- person_email --
-- Global uniqueness makes "login by email" deterministic. Only verified,
-- login-enabled addresses can be used to sign in.
CREATE TABLE pii.person_email (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id           uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  email               citext NOT NULL UNIQUE
                        CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' AND length(email) <= 254),
  contact_purpose_id  smallint NOT NULL REFERENCES ref.contact_purpose(id),
  is_primary          boolean NOT NULL DEFAULT false,
  is_login_enabled    boolean NOT NULL DEFAULT false,
  verified_at         timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT person_email_login_requires_verified
    CHECK (NOT is_login_enabled OR verified_at IS NOT NULL),
  UNIQUE (id, person_id)                   -- target for composite FKs (MFA channel)
);
CREATE INDEX person_email_person_idx ON pii.person_email(person_id);
CREATE UNIQUE INDEX person_email_one_primary_uq ON pii.person_email(person_id) WHERE is_primary;
SELECT util.attach_updated_at('pii.person_email');

-- --------------------------------------------------------------- person_phone --
CREATE TABLE pii.person_phone (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id           uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  e164                varchar(16) NOT NULL CHECK (e164 ~ '^\+[1-9][0-9]{6,14}$'),
  contact_purpose_id  smallint NOT NULL REFERENCES ref.contact_purpose(id),
  is_primary          boolean NOT NULL DEFAULT false,
  verified_at         timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (person_id, e164),                -- family members may share a number
  UNIQUE (id, person_id)
);
CREATE UNIQUE INDEX person_phone_one_primary_uq ON pii.person_phone(person_id) WHERE is_primary;
CREATE INDEX person_phone_e164_idx ON pii.person_phone(e164);
SELECT util.attach_updated_at('pii.person_phone');

-- -------------------------------------------------------------------- address --
-- State and country are reached through city (no transitive dependency stored).
CREATE TABLE pii.address (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  line1        text NOT NULL CHECK (btrim(line1) <> ''),
  line2        text,
  locality     text,
  city_id      int  NOT NULL REFERENCES ref.city(id),
  postal_code  varchar(12) NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('pii.address');

-- A person has at most one address of each type at any point in time.
CREATE TABLE pii.person_address (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id        uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  address_id       uuid NOT NULL REFERENCES pii.address(id),
  address_type_id  smallint NOT NULL REFERENCES ref.address_type(id),
  valid            daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT person_address_no_overlap
    EXCLUDE USING gist (person_id WITH =, address_type_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('pii.person_address');

-- ---------------------------------------------------- person_identity_document --
-- Collect only when a purpose requires it (DPDP data minimisation). The number
-- is envelope-encrypted by the application (KMS); number_hmac is a keyed blind
-- index for exact-match lookup / de-duplication. Never store full Aadhaar.
CREATE TABLE pii.person_identity_document (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id            uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  id_document_type_id  smallint NOT NULL REFERENCES ref.id_document_type(id),
  number_ciphertext    bytea NOT NULL,
  number_hmac          bytea NOT NULL CHECK (octet_length(number_hmac) = 32),
  number_last4         varchar(4) NOT NULL,
  expires_on           date,                        -- validity of the document itself (driving licence, passport)
  verified_at          timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (person_id, id_document_type_id),
  UNIQUE (id_document_type_id, number_hmac)
);
SELECT util.attach_updated_at('pii.person_identity_document');

-- --------------------------------------------------------------- person_photo --
CREATE TABLE pii.person_photo (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id       uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  file_object_id  uuid NOT NULL UNIQUE REFERENCES people.file_object(id),
  valid           tstzrange NOT NULL DEFAULT tstzrange(now(), NULL),
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT person_photo_one_current
    EXCLUDE USING gist (person_id WITH =, valid WITH &&)
);

-- -------------------------------------------------------- person_relationship --
-- Parents / guardians / emergency contacts: "related_person is <type> of person".
CREATE TABLE people.person_relationship (
  person_id             uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  related_person_id     uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  relationship_type_id  smallint NOT NULL REFERENCES ref.relationship_type(id),
  is_guardian           boolean NOT NULL DEFAULT false,
  is_emergency_contact  boolean NOT NULL DEFAULT false,
  is_primary_contact    boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (person_id, related_person_id, relationship_type_id),
  CHECK (person_id <> related_person_id)
);
CREATE INDEX person_relationship_related_idx ON people.person_relationship(related_person_id);
CREATE UNIQUE INDEX person_relationship_one_primary_uq
  ON people.person_relationship(person_id) WHERE is_primary_contact;
SELECT util.attach_updated_at('people.person_relationship');

-- ----------------------------------------------------------------- designation --
-- Master list replacing the old free-text designation string.
CREATE TABLE people.designation (
  id                    smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code                  citext NOT NULL UNIQUE,
  title                 text   NOT NULL UNIQUE,
  employee_category_id  smallint REFERENCES ref.employee_category(id),  -- NULL = any
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('people.designation');

-- -------------------------------------------------------------------- employee --
CREATE TABLE people.employee (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id             uuid NOT NULL UNIQUE REFERENCES people.person(id),
  employee_code         citext NOT NULL UNIQUE CHECK (employee_code ~ '^[A-Za-z0-9_-]{3,32}$'),
  employee_category_id  smallint NOT NULL REFERENCES ref.employee_category(id),
  employment_type_id    smallint NOT NULL REFERENCES ref.employment_type(id),
  employment_status_id  smallint NOT NULL REFERENCES ref.employment_status(id),
  grade_id              smallint REFERENCES ref.grade(id),
  joined_on             date NOT NULL,
  separated_on          date,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CHECK (separated_on IS NULL OR separated_on >= joined_on)
);
SELECT util.attach_updated_at('people.employee');

-- --------------------------------------------------------- employee_assignment --
-- Where an employee works, in what designation, function and job role.
-- Exactly one PRIMARY assignment at any time (DB-enforced); any number of
-- secondary ones. The employee's school is DERIVED by walking up org_unit
-- (never stored). function/role are optional: not every posting needs both.
CREATE TABLE people.employee_assignment (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id     uuid NOT NULL REFERENCES people.employee(id) ON DELETE CASCADE,
  org_unit_id     uuid NOT NULL REFERENCES org.org_unit(id),
  designation_id  smallint NOT NULL REFERENCES people.designation(id),
  job_function_id smallint REFERENCES ref.job_function(id),
  job_role_id     smallint REFERENCES ref.job_role(id),
  is_primary      boolean NOT NULL DEFAULT false,
  valid           daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT employee_assignment_one_primary
    EXCLUDE USING gist (employee_id WITH =, valid WITH &&) WHERE (is_primary),
  CONSTRAINT employee_assignment_no_duplicate
    EXCLUDE USING gist (employee_id WITH =, org_unit_id WITH =, designation_id WITH =, valid WITH &&)
);
CREATE INDEX employee_assignment_unit_idx ON people.employee_assignment(org_unit_id);
CREATE INDEX employee_assignment_function_idx ON people.employee_assignment(job_function_id);
CREATE INDEX employee_assignment_role_idx ON people.employee_assignment(job_role_id);
SELECT util.attach_updated_at('people.employee_assignment');

-- -------------------------------------------------------- employee_reporting_line --
-- Reporting manager (line manager) and reviewing manager (appraisal /
-- skip-level) over time. The two can be different people (matrix org).
-- One active manager of each type at a time; a chain cannot loop back on itself.
CREATE TABLE people.employee_reporting_line (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id              uuid NOT NULL REFERENCES people.employee(id) ON DELETE CASCADE,
  manager_employee_id      uuid NOT NULL REFERENCES people.employee(id),
  reporting_line_type_id   smallint NOT NULL REFERENCES ref.reporting_line_type(id),
  valid                    daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (employee_id <> manager_employee_id),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT employee_reporting_line_one_active
    EXCLUDE USING gist (employee_id WITH =, reporting_line_type_id WITH =, valid WITH &&)
);
CREATE INDEX employee_reporting_line_manager_idx ON people.employee_reporting_line(manager_employee_id, reporting_line_type_id);
SELECT util.attach_updated_at('people.employee_reporting_line');

-- No employee may end up (transitively, through the same reporting_line_type)
-- reporting to themselves. Checked against chains active TODAY — a rare
-- future-dated edge case across non-overlapping periods is not caught here.
CREATE OR REPLACE FUNCTION people.employee_reporting_line_no_cycle()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cycle boolean;
BEGIN
  WITH RECURSIVE up AS (
    SELECT manager_employee_id AS emp_id
    FROM people.employee_reporting_line
    WHERE employee_id = NEW.manager_employee_id
      AND reporting_line_type_id = NEW.reporting_line_type_id
      AND valid @> current_date
    UNION ALL
    SELECT l.manager_employee_id
    FROM people.employee_reporting_line l JOIN up ON l.employee_id = up.emp_id
    WHERE l.reporting_line_type_id = NEW.reporting_line_type_id AND l.valid @> current_date
  )
  SELECT EXISTS (SELECT 1 FROM up WHERE emp_id = NEW.employee_id) INTO v_cycle;
  IF v_cycle THEN
    RAISE EXCEPTION 'employee_reporting_line: % reporting to % would create a reporting-chain cycle',
      NEW.employee_id, NEW.manager_employee_id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_employee_reporting_line_no_cycle
  BEFORE INSERT OR UPDATE OF employee_id, manager_employee_id, reporting_line_type_id ON people.employee_reporting_line
  FOR EACH ROW EXECUTE FUNCTION people.employee_reporting_line_no_cycle();

-- --------------------------------------------------------------------- student --
CREATE TABLE people.student (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id          uuid NOT NULL UNIQUE REFERENCES people.person(id),
  enrollment_no      citext NOT NULL UNIQUE,
  registration_no    citext UNIQUE,
  student_status_id  smallint NOT NULL REFERENCES ref.student_status(id),
  admitted_on        date NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('people.student');

-- A student's programme, batch and therefore home department come from
-- academic.student_enrollment (04_academic.sql) — not stored here.

CREATE TABLE people.student_mentor (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   uuid NOT NULL REFERENCES people.student(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES people.employee(id),
  valid        daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT student_mentor_one_current
    EXCLUDE USING gist (student_id WITH =, valid WITH &&)
);
CREATE INDEX student_mentor_employee_idx ON people.student_mentor(employee_id);
SELECT util.attach_updated_at('people.student_mentor');

-- ============================================================ org.appointment ==
-- Who holds a leadership position of a unit. One holder per (unit, position)
-- at any time — replaces headOfFaculty / headOfDepartment columns.
CREATE TABLE org.appointment (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id       uuid NOT NULL REFERENCES org.org_unit(id),
  position_type_id  smallint NOT NULL REFERENCES org.position_type(id),
  employee_id       uuid NOT NULL REFERENCES people.employee(id),
  valid             daterange NOT NULL DEFAULT daterange(current_date, NULL),
  order_reference   text,                      -- office order / notification no.
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT appointment_single_holder
    EXCLUDE USING gist (org_unit_id WITH =, position_type_id WITH =, valid WITH &&)
);
CREATE INDEX appointment_employee_idx ON org.appointment(employee_id);
SELECT util.attach_updated_at('org.appointment');

CREATE OR REPLACE FUNCTION org.appointment_validate_position()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM org.position_type_unit_type ptu
    JOIN org.org_unit u ON u.org_unit_type_id = ptu.org_unit_type_id
    WHERE u.id = NEW.org_unit_id AND ptu.position_type_id = NEW.position_type_id) THEN
    RAISE EXCEPTION 'position % is not defined for the type of org_unit %',
      NEW.position_type_id, NEW.org_unit_id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_appointment_validate_position
  BEFORE INSERT OR UPDATE OF org_unit_id, position_type_id ON org.appointment
  FOR EACH ROW EXECUTE FUNCTION org.appointment_validate_position();
