-- =============================================================================
-- 04c_academic_flexibility.sql — NEP 2020 / UGC flexibility (schema: academic)
--
--   COURSE EQUIVALENCE
--     course_equivalence            "course B counts as course A" (Board of Studies)
--   MULTIPLE ENTRY & EXIT
--     award_rule ─< award_rule_course   what a curriculum lets a student leave
--                                       with (UG certificate after year 1,
--                                       diploma after year 2, degree, honours)
--     student_award                     the award conferred when an enrollment ends
--     enrollment_reentry                a later enrollment resuming from that exit
--   CREDIT TRANSFER (Academic Bank of Credits, MOOCs / SWAYAM / NPTEL)
--     external_provider ─< external_course ─< external_course_mapping
--     credit_transfer                   a student's external credits, approved
--   MINORS & HONOURS
--     track ─< track_course             a minor (another discipline) or an
--     student_track                     honours track (own programme)
--
-- The student's APAAR / ABC ID is a personal identifier and lives in
-- pii.person_identity_document (type APAAR_ID), never here.
-- Derived, never stored (09_views_functions.sql): enrollment lineage across
-- re-entry, the credit ledger, course completion (passed / equivalent /
-- transferred), award eligibility, track progress, CGPA.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = academic, people, org, ref, public;

-- ######################################################## COURSE EQUIVALENCE ##

-- "equivalent_course_id counts as course_id": passing the equivalent satisfies
-- the course — for a backlog student whose old course is no longer offered
-- (old course ← new course), and for credits earned before a curriculum change
-- (new course ← old course). Directional and one hop, so each direction is an
-- explicit, approved row.
CREATE TABLE academic.course_equivalence (
  course_id                uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  equivalent_course_id     uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_on              date NOT NULL DEFAULT current_date,
  body_resolution_id       uuid REFERENCES academic.body_resolution(id),   -- the Board of Studies / Academic Council resolution
  PRIMARY KEY (course_id, equivalent_course_id),
  CHECK (course_id <> equivalent_course_id)
);
CREATE INDEX course_equivalence_equivalent_idx ON academic.course_equivalence(equivalent_course_id);

-- ##################################################### MULTIPLE ENTRY & EXIT ##

-- What a curriculum lets a student leave with, and when: e.g. UG Certificate
-- after term 2 with 40 credits, UG Diploma after term 4 with 80, the degree
-- after the final term. reentry_within_years = how long a student who left
-- with this award may come back and continue (NULL = no re-entry, e.g. the
-- final degree).
CREATE TABLE academic.award_rule (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id         uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  award_type_id         smallint NOT NULL REFERENCES ref.award_type(id),
  award_title           text NOT NULL,                       -- "UG Certificate in Computer Science"
  after_term_no         smallint NOT NULL CHECK (after_term_no >= 1),
  min_credits           numeric(5,1) NOT NULL CHECK (min_credits > 0),
  reentry_within_years  smallint CHECK (reentry_within_years > 0),
  pathway_id            uuid,                                -- award only for students on this pathway (Honours vs Honours with Research)
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (curriculum_id, award_type_id),
  FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id)
);
SELECT util.attach_updated_at('academic.award_rule');

CREATE OR REPLACE FUNCTION academic.award_rule_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.after_term_no > (SELECT p.duration_terms FROM academic.curriculum c JOIN academic.program p ON p.id = c.program_id
                          WHERE c.id = NEW.curriculum_id) THEN
    RAISE EXCEPTION 'award_rule: term % is beyond the programme duration', NEW.after_term_no USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_award_rule_validate BEFORE INSERT OR UPDATE ON academic.award_rule
  FOR EACH ROW EXECUTE FUNCTION academic.award_rule_validate();

-- Courses that must be completed for the award (e.g. the 4-credit vocational
-- summer internship NEP requires for a UG certificate exit).
CREATE TABLE academic.award_rule_course (
  award_rule_id  uuid NOT NULL REFERENCES academic.award_rule(id) ON DELETE CASCADE,
  course_id      uuid NOT NULL REFERENCES academic.course(id),
  PRIMARY KEY (award_rule_id, course_id)
);

-- The award conferred when an enrollment ends — an exit certificate/diploma or
-- the final degree. The enrollment must already be closed on conferred_on
-- (upper bound of its validity), the rule must be from the student's own
-- curriculum, and the student must be eligible (academic.v_award_eligibility:
-- credits earned across re-entries + required courses completed).
CREATE TABLE academic.student_award (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id    uuid NOT NULL UNIQUE REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  award_rule_id            uuid NOT NULL REFERENCES academic.award_rule(id),
  conferred_on             date NOT NULL,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION academic.student_award_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_valid daterange; v_elig record;
BEGIN
  SELECT e.valid INTO v_valid FROM academic.student_enrollment e WHERE e.id = NEW.student_enrollment_id;
  IF NOT EXISTS (SELECT 1 FROM academic.student_enrollment e
                 JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
                 JOIN academic.award_rule ar ON ar.curriculum_id = bc.curriculum_id
                 WHERE e.id = NEW.student_enrollment_id AND ar.id = NEW.award_rule_id) THEN
    RAISE EXCEPTION 'student_award: the award rule is not from the student''s curriculum' USING ERRCODE = 'check_violation';
  END IF;
  IF upper(v_valid) IS DISTINCT FROM NEW.conferred_on THEN
    RAISE EXCEPTION 'student_award: close the enrollment on the award date first (enrollment ends %, award on %)',
      upper(v_valid), NEW.conferred_on USING ERRCODE = 'check_violation';
  END IF;
  SELECT credits_earned, min_credits, required_courses_missing, is_eligible INTO v_elig
  FROM academic.v_award_eligibility
  WHERE student_enrollment_id = NEW.student_enrollment_id AND award_rule_id = NEW.award_rule_id;
  IF NOT v_elig.is_eligible THEN
    RAISE EXCEPTION 'student_award: not eligible — % of % credits earned, % required course(s) missing',
      v_elig.credits_earned, v_elig.min_credits, v_elig.required_courses_missing USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_student_award_validate BEFORE INSERT OR UPDATE ON academic.student_award
  FOR EACH ROW EXECUTE FUNCTION academic.student_award_validate();

-- A new enrollment that resumes a programme after an exit: same student, same
-- programme, starting after the exit and within the award's re-entry window,
-- entering the term after the exit point. Credits and completed courses of the
-- earlier enrollment carry forward through academic.v_enrollment_lineage.
CREATE TABLE academic.enrollment_reentry (
  student_enrollment_id    uuid PRIMARY KEY REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  student_award_id         uuid NOT NULL UNIQUE REFERENCES academic.student_award(id),
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION academic.enrollment_reentry_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_new record; v_old record;
BEGIN
  SELECT e.student_id, lower(e.valid) AS starts_on, e.entry_term_no, b.program_id INTO v_new
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id
  WHERE e.id = NEW.student_enrollment_id;
  SELECT e.student_id, b.program_id, sa.conferred_on, ar.after_term_no, ar.reentry_within_years INTO v_old
  FROM academic.student_award sa
  JOIN academic.award_rule ar         ON ar.id = sa.award_rule_id
  JOIN academic.student_enrollment e  ON e.id = sa.student_enrollment_id
  JOIN academic.batch b               ON b.id = e.batch_id
  WHERE sa.id = NEW.student_award_id;

  IF v_new.student_id <> v_old.student_id OR v_new.program_id <> v_old.program_id THEN
    RAISE EXCEPTION 'enrollment_reentry: re-entry must be the same student into the same programme' USING ERRCODE = 'check_violation';
  END IF;
  IF v_old.reentry_within_years IS NULL THEN
    RAISE EXCEPTION 'enrollment_reentry: this award does not allow re-entry' USING ERRCODE = 'check_violation';
  END IF;
  IF v_new.starts_on < v_old.conferred_on
     OR v_new.starts_on >= v_old.conferred_on + make_interval(years => v_old.reentry_within_years) THEN
    RAISE EXCEPTION 'enrollment_reentry: must start after the exit and within % year(s) of it', v_old.reentry_within_years
      USING ERRCODE = 'check_violation';
  END IF;
  IF v_new.entry_term_no <> v_old.after_term_no + 1 THEN
    RAISE EXCEPTION 'enrollment_reentry: must enter term % (the term after the exit point), not %',
      v_old.after_term_no + 1, v_new.entry_term_no USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_enrollment_reentry_validate BEFORE INSERT OR UPDATE ON academic.enrollment_reentry
  FOR EACH ROW EXECUTE FUNCTION academic.enrollment_reentry_validate();

-- ######################################################### CREDIT TRANSFER ##

-- Where external credits come from: another university, a MOOC platform
-- (SWAYAM, NPTEL), an industry certification body.
CREATE TABLE academic.external_provider (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                       citext NOT NULL UNIQUE,
  name                       text NOT NULL,
  external_provider_type_id  smallint NOT NULL REFERENCES ref.external_provider_type(id),
  country_id                 smallint REFERENCES ref.country(id),
  aishe_code                 citext UNIQUE,                    -- Indian HEIs
  is_active                  boolean NOT NULL DEFAULT true,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('academic.external_provider');

CREATE TABLE academic.external_course (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_provider_id  uuid NOT NULL REFERENCES academic.external_provider(id),
  code                  citext NOT NULL,                      -- 'noc26-cs45'
  title                 text NOT NULL,
  credits               numeric(4,1) NOT NULL CHECK (credits > 0),
  duration_weeks        smallint CHECK (duration_weeks > 0),
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (external_provider_id, code)
);
SELECT util.attach_updated_at('academic.external_course');

-- How an external course counts here, approved by the Board of Studies for a
-- period: as a specific internal course (it replaces that course), or as
-- credits in a course category (e.g. an open elective). One mapping at a time.
CREATE TABLE academic.external_course_mapping (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_course_id       uuid NOT NULL REFERENCES academic.external_course(id) ON DELETE CASCADE,
  course_id                uuid REFERENCES academic.course(id),
  course_category_id       smallint REFERENCES ref.course_category(id),
  valid                    daterange NOT NULL,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  body_resolution_id       uuid REFERENCES academic.body_resolution(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(course_id, course_category_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT external_course_mapping_one_at_a_time EXCLUDE USING gist (external_course_id WITH =, valid WITH &&)
);

-- External credits a student asks to transfer in (from the ABC, a MOOC
-- certificate, another university). Credits are the external course's;
-- grade_point is converted to the student's grade scale (NULL = credit only,
-- not counted in CGPA). On acceptance the database checks: a mapping valid on
-- the completion date, the mapped course / category is in the student's
-- curriculum, and the curriculum's cap on transferred credits.
CREATE TABLE academic.credit_transfer (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id      uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  external_course_id         uuid NOT NULL REFERENCES academic.external_course(id),
  completed_on               date NOT NULL,
  grade_point                numeric(4,2) CHECK (grade_point >= 0),
  abc_reference              citext UNIQUE,                    -- ABC / APAAR credit transaction id
  certificate_file_id        uuid UNIQUE REFERENCES people.file_object(id),
  credit_transfer_status_id  smallint NOT NULL REFERENCES ref.credit_transfer_status(id),
  decided_by_employee_id     uuid REFERENCES people.employee(id),
  decided_at                 timestamptz,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_enrollment_id, external_course_id),
  CHECK ((decided_at IS NULL) = (decided_by_employee_id IS NULL))
);
SELECT util.attach_updated_at('academic.credit_transfer');

CREATE OR REPLACE FUNCTION academic.credit_transfer_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_curriculum uuid; v_max_gp numeric; v_cap_pct numeric; v_min_credits numeric;
        v_credits numeric; v_map record; v_used numeric;
BEGIN
  SELECT c.id, gs.max_grade_point, c.max_transfer_credit_pct, p.min_credits
    INTO v_curriculum, v_max_gp, v_cap_pct, v_min_credits
  FROM academic.student_enrollment e
  JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
  JOIN academic.curriculum c        ON c.id = bc.curriculum_id
  JOIN academic.program p           ON p.id = c.program_id
  JOIN academic.grade_scale gs      ON gs.id = c.grade_scale_id
  WHERE e.id = NEW.student_enrollment_id;
  IF v_curriculum IS NULL THEN
    RAISE EXCEPTION 'credit_transfer: the student''s batch has no curriculum assigned' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.grade_point > v_max_gp THEN
    RAISE EXCEPTION 'credit_transfer: grade point % exceeds the scale maximum %', NEW.grade_point, v_max_gp
      USING ERRCODE = 'check_violation';
  END IF;

  IF (SELECT is_accepted FROM ref.credit_transfer_status WHERE id = NEW.credit_transfer_status_id) THEN
    IF NEW.decided_by_employee_id IS NULL THEN
      RAISE EXCEPTION 'credit_transfer: an accepted transfer needs the approver' USING ERRCODE = 'check_violation';
    END IF;
    SELECT m.course_id, m.course_category_id INTO v_map
    FROM academic.external_course_mapping m
    WHERE m.external_course_id = NEW.external_course_id AND m.valid @> NEW.completed_on;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'credit_transfer: no approved mapping for this external course on %', NEW.completed_on
        USING ERRCODE = 'check_violation';
    END IF;
    IF v_map.course_id IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM academic.v_curriculum_item WHERE curriculum_id = v_curriculum AND course_id = v_map.course_id) THEN
      RAISE EXCEPTION 'credit_transfer: the mapped course is not in the student''s curriculum' USING ERRCODE = 'check_violation';
    END IF;
    IF v_map.course_category_id IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM academic.v_curriculum_item WHERE curriculum_id = v_curriculum AND course_category_id = v_map.course_category_id) THEN
      RAISE EXCEPTION 'credit_transfer: the student''s curriculum has no courses of the mapped category' USING ERRCODE = 'check_violation';
    END IF;
    IF v_cap_pct IS NOT NULL AND v_min_credits IS NOT NULL THEN
      SELECT credits INTO v_credits FROM academic.external_course WHERE id = NEW.external_course_id;
      SELECT COALESCE(sum(ec.credits), 0) INTO v_used
      FROM academic.credit_transfer ct
      JOIN ref.credit_transfer_status s ON s.id = ct.credit_transfer_status_id AND s.is_accepted
      JOIN academic.external_course ec  ON ec.id = ct.external_course_id
      WHERE ct.student_enrollment_id = NEW.student_enrollment_id AND ct.id <> NEW.id;
      IF v_used + v_credits > v_cap_pct / 100 * v_min_credits THEN
        RAISE EXCEPTION 'credit_transfer: % transferred credits would exceed the cap of % (% %% of % programme credits)',
          v_used + v_credits, round(v_cap_pct / 100 * v_min_credits, 1), v_cap_pct, v_min_credits USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_credit_transfer_validate BEFORE INSERT OR UPDATE ON academic.credit_transfer
  FOR EACH ROW EXECUTE FUNCTION academic.credit_transfer_validate();

-- ######################################################### MINORS & HONOURS ##

-- An additional credential on top of the programme: a MINOR (a second
-- discipline, offered by another department, open to other programmes) or an
-- HONOURS track (deeper study in the student's own programme). Whether its
-- courses count in the CGPA is a per-track rule.
CREATE TABLE academic.track (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  citext NOT NULL UNIQUE,
  name                  text NOT NULL,                       -- "Minor in Business Analytics"
  track_type_id         smallint NOT NULL REFERENCES ref.track_type(id),
  offering_org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  program_id            uuid REFERENCES academic.program(id), -- honours: the programme it belongs to
  min_credits           numeric(5,1) NOT NULL CHECK (min_credits > 0),
  min_cgpa_to_join      numeric(4,2) CHECK (min_cgpa_to_join >= 0),
  counts_in_cgpa        boolean NOT NULL DEFAULT false,
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('academic.track');
CREATE TRIGGER trg_track_academic_unit BEFORE INSERT OR UPDATE OF offering_org_unit_id ON academic.track
  FOR EACH ROW EXECUTE FUNCTION academic.require_academic_unit('offering_org_unit_id');

CREATE OR REPLACE FUNCTION academic.track_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT requires_own_program FROM ref.track_type WHERE id = NEW.track_type_id) <> (NEW.program_id IS NOT NULL) THEN
    RAISE EXCEPTION 'track %: an honours track belongs to one programme; a minor is open to other programmes (no programme)', NEW.code
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_track_validate BEFORE INSERT OR UPDATE ON academic.track
  FOR EACH ROW EXECUTE FUNCTION academic.track_validate();

-- The courses of a track, each with its category and scheme of examination
-- (a track course is outside the curriculum, so it carries its own).
CREATE TABLE academic.track_course (
  track_id              uuid NOT NULL REFERENCES academic.track(id) ON DELETE CASCADE,
  course_id             uuid NOT NULL REFERENCES academic.course(id),
  course_category_id    smallint NOT NULL REFERENCES ref.course_category(id),
  evaluation_scheme_id  int NOT NULL REFERENCES academic.evaluation_scheme(id),
  PRIMARY KEY (track_id, course_id)
);

-- A student on a track. Honours: own programme only. Minor: a department other
-- than the one running the student's programme. At most one active track of
-- each type, and the track's CGPA entry bar applies when joining.
CREATE TABLE academic.student_track (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  track_id               uuid NOT NULL REFERENCES academic.track(id),
  valid                  daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT student_track_no_overlap EXCLUDE USING gist (student_enrollment_id WITH =, track_id WITH =, valid WITH &&)
);
CREATE INDEX student_track_track_idx ON academic.student_track(track_id);
SELECT util.attach_updated_at('academic.student_track');

CREATE OR REPLACE FUNCTION academic.student_track_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_track record; v_program uuid; v_program_unit uuid; v_cgpa numeric;
BEGIN
  SELECT t.*, tt.code AS type_code INTO v_track
  FROM academic.track t JOIN ref.track_type tt ON tt.id = t.track_type_id WHERE t.id = NEW.track_id;
  SELECT p.id, p.offering_org_unit_id INTO v_program, v_program_unit
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id JOIN academic.program p ON p.id = b.program_id
  WHERE e.id = NEW.student_enrollment_id;

  IF v_track.program_id IS NOT NULL AND v_track.program_id <> v_program THEN
    RAISE EXCEPTION 'student_track: % is for another programme', v_track.code USING ERRCODE = 'check_violation';
  END IF;
  IF v_track.program_id IS NULL AND v_track.offering_org_unit_id = v_program_unit THEN
    RAISE EXCEPTION 'student_track: a minor must be in a discipline other than the student''s own programme' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.student_track st JOIN academic.track t ON t.id = st.track_id
             WHERE st.student_enrollment_id = NEW.student_enrollment_id AND st.id <> NEW.id
               AND t.track_type_id = v_track.track_type_id AND st.valid && NEW.valid) THEN
    RAISE EXCEPTION 'student_track: already on a % track in this period', v_track.type_code USING ERRCODE = 'unique_violation';
  END IF;
  IF TG_OP = 'INSERT' AND v_track.min_cgpa_to_join IS NOT NULL THEN
    SELECT cgpa INTO v_cgpa FROM exam.v_cgpa WHERE student_enrollment_id = NEW.student_enrollment_id;
    IF v_cgpa IS NULL OR v_cgpa < v_track.min_cgpa_to_join THEN
      RAISE EXCEPTION 'student_track: CGPA % is below the % entry bar of %', COALESCE(v_cgpa::text, '(none yet)'),
        v_track.code, v_track.min_cgpa_to_join USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_student_track_validate BEFORE INSERT OR UPDATE ON academic.student_track
  FOR EACH ROW EXECUTE FUNCTION academic.student_track_validate();
