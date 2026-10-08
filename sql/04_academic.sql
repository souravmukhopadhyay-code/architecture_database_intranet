-- =============================================================================
-- 04_academic.sql — Academic structure, curriculum and delivery (schema: academic)
--
-- STRUCTURE
--   org_unit (academic dept/school) ─< program ─< specialization
--   academic_year ─< academic_term  (term_cycle: ODD / EVEN / ANNUAL / PROF_YEAR)
--   program × admission academic_year = batch  ("B.Tech CSE, batch 2026")
--   student ─< student_enrollment (batch, over time) ─< student_specialization
--
-- REGULATION (reusable rule sets)
--   grade_scale ─< grade_band                  (e.g. 10-point: O/A+/A/…/F)
--   evaluation_scheme ─< evaluation_component  (scheme of examination: internal
--                                               30%, mid-term 20%, end-term 50%…)
--                     ─< evaluation_component_group ("best 2 of 3 tests")
--                     ─< evaluation_part_rule  (internal / external pass minimums)
-- CURRICULUM (what is taught — the scheme of studies, as data)
--   course ─< course_component_hours (L-T-P), course_prerequisite
--   program ─< curriculum (versioned) ─< curriculum_course      (fixed courses per term)
--                                     ─< elective_basket ─< elective_basket_course
--   batch ── batch_curriculum ──> curriculum  (which version this intake follows)
--
-- DELIVERY (who teaches whom, where, when — per term)
--   course ─< course_offering (course running in a term, taught by a department)
--   batch × term ─< section ─< section_student
--   student_enrollment × course_offering = course_registration
--   course_offering ─< teaching_assignment (faculty × section × L/T/P)
--   time_slot, org.room, faculty_unavailability  → timetable_entry  (DB rejects clashes;
--                                                  weekly, fortnightly or every N weeks)
--   timetable_entry ─< class_session (dated class) ─< attendance
--
-- Derived, never stored (see 09_views_functions.sql): batch year, programme
-- duration in years, home department, current term, a registration's
-- evaluation scheme, class-session times/faculty, attendance percentage.
-- Examination (registration, date sheet, seating, marks, results) is in
-- 04b_exam.sql; NEP 2020 flexibility (multiple entry/exit, credit transfer,
-- MOOCs, minors/honours, course equivalence) is in 04c_academic_flexibility.sql;
-- the student lifecycle (term registration, promotion, breaks, transfers),
-- academic calendar, elective allotment, syllabus & outcomes, workload and
-- feedback are in 04d_student_lifecycle.sql; doctoral research in
-- 04e_research.sql; question papers, certificates and convocation in
-- 04f_exam_papers_certificates.sql; fees belong to the Finance module.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = academic, people, org, ref, public;

-- ------------------------------------------------------------------- program --
CREATE TABLE academic.program (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                       citext NOT NULL UNIQUE CHECK (code ~ '^[A-Za-z0-9_-]{2,32}$'),
  name                       text   NOT NULL UNIQUE CHECK (btrim(name) <> ''),
  short_name                 citext UNIQUE,
  program_level_id           smallint NOT NULL REFERENCES ref.program_level(id),
  academic_calendar_type_id  smallint NOT NULL REFERENCES ref.academic_calendar_type(id),
  offering_org_unit_id       uuid NOT NULL REFERENCES org.org_unit(id),   -- department / school that runs it
  delivery_mode_id           smallint NOT NULL REFERENCES ref.delivery_mode(id),   -- regular / part-time / distance / online
  medium_language_id         smallint REFERENCES ref.language(id),               -- medium of instruction (NULL = not fixed)
  duration_terms             smallint NOT NULL CHECK (duration_terms BETWEEN 1 AND 20),
  min_credits                smallint CHECK (min_credits > 0),
  max_credits                smallint CHECK (max_credits > 0),
  is_active                  boolean NOT NULL DEFAULT true,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  CHECK (min_credits IS NULL OR max_credits IS NULL OR min_credits <= max_credits)
);
CREATE INDEX program_offering_unit_idx ON academic.program(offering_org_unit_id);
SELECT util.attach_updated_at('academic.program');

-- offering unit must be on the academic side of the tree
CREATE OR REPLACE FUNCTION academic.program_validate_unit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM org.org_unit u JOIN ref.org_unit_type t ON t.id = u.org_unit_type_id
                 WHERE u.id = NEW.offering_org_unit_id AND t.is_academic) THEN
    RAISE EXCEPTION 'program %: offering unit must be an academic unit', NEW.code
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_program_validate_unit
  BEFORE INSERT OR UPDATE OF offering_org_unit_id ON academic.program
  FOR EACH ROW EXECUTE FUNCTION academic.program_validate_unit();

-- ------------------------------------------------------------ specialization --
CREATE TABLE academic.specialization (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id  uuid NOT NULL REFERENCES academic.program(id) ON DELETE CASCADE,
  code        citext NOT NULL CHECK (code ~ '^[A-Za-z0-9_-]{1,32}$'),
  name        text   NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, code),
  UNIQUE (program_id, name)
);
SELECT util.attach_updated_at('academic.specialization');

-- ------------------------------------------------------- program_coordinator --
CREATE TABLE academic.program_coordinator (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id   uuid NOT NULL REFERENCES academic.program(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES people.employee(id),
  valid        daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT program_coordinator_single EXCLUDE USING gist (program_id WITH =, valid WITH &&)
);
CREATE INDEX program_coordinator_employee_idx ON academic.program_coordinator(employee_id);
SELECT util.attach_updated_at('academic.program_coordinator');

-- ============================================================ academic calendar ==
-- Academic years never overlap (e.g. 2026-27 = [2026-07-01, 2027-07-01)).
CREATE TABLE academic.academic_year (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        citext NOT NULL UNIQUE CHECK (code ~ '^[0-9]{4}-[0-9]{2}$'),
  period      daterange NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period)),
  CONSTRAINT academic_year_no_overlap EXCLUDE USING gist (period WITH &&)
);
SELECT util.attach_updated_at('academic.academic_year');

-- A concrete term = academic year × term cycle, e.g. "2026-27 ODD semester".
CREATE TABLE academic.academic_term (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id  uuid NOT NULL REFERENCES academic.academic_year(id),
  term_cycle_id     smallint NOT NULL REFERENCES ref.term_cycle(id),
  period            daterange NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period)),
  UNIQUE (academic_year_id, term_cycle_id)
);
SELECT util.attach_updated_at('academic.academic_term');

-- term must lie inside its year and not overlap another term of the same calendar type
CREATE OR REPLACE FUNCTION academic.academic_term_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cal smallint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.academic_year y
                 WHERE y.id = NEW.academic_year_id AND NEW.period <@ y.period) THEN
    RAISE EXCEPTION 'academic_term: period % is outside its academic year', NEW.period
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT academic_calendar_type_id INTO v_cal FROM ref.term_cycle WHERE id = NEW.term_cycle_id;
  IF EXISTS (SELECT 1 FROM academic.academic_term t JOIN ref.term_cycle c ON c.id = t.term_cycle_id
             WHERE c.academic_calendar_type_id = v_cal AND t.id <> NEW.id AND t.period && NEW.period) THEN
    RAISE EXCEPTION 'academic_term: period % overlaps another term of the same calendar type', NEW.period
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_academic_term_validate
  BEFORE INSERT OR UPDATE ON academic.academic_term
  FOR EACH ROW EXECUTE FUNCTION academic.academic_term_validate();

-- ===================================================================== batch ==
-- A batch = one programme's intake in one admission academic year.
-- "Batch year" is derived from the admission year (academic.v_batch).
CREATE TABLE academic.batch (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id          uuid NOT NULL REFERENCES academic.program(id),
  admission_year_id   uuid NOT NULL REFERENCES academic.academic_year(id),
  intake_capacity     int CHECK (intake_capacity >= 0),
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, admission_year_id)
);
SELECT util.attach_updated_at('academic.batch');

-- Supporting documents per batch (approvals, scheme of studies …).
-- Official paperwork for ONE intake — e.g. the regulator/council letter
-- approving this batch's seats, or a circular that applies only to this batch.
-- NOT the scheme of studies: that is structured data (academic.curriculum,
-- linked through academic.batch_curriculum), never a PDF copy of it.
CREATE TABLE academic.batch_document (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id                uuid NOT NULL REFERENCES academic.batch(id) ON DELETE CASCADE,
  batch_document_type_id  smallint NOT NULL REFERENCES ref.batch_document_type(id),
  file_object_id          uuid NOT NULL UNIQUE REFERENCES people.file_object(id),
  title                   text NOT NULL,
  reference_no            text,                      -- letter / circular number
  issued_on               date,
  created_at              timestamptz NOT NULL DEFAULT now()
);

-- Specializations offered to a batch and from which term students choose them.
CREATE TABLE academic.batch_specialization (
  batch_id           uuid NOT NULL REFERENCES academic.batch(id) ON DELETE CASCADE,
  specialization_id  uuid NOT NULL REFERENCES academic.specialization(id),
  from_term_no       smallint NOT NULL DEFAULT 1 CHECK (from_term_no >= 1),
  PRIMARY KEY (batch_id, specialization_id)
);

CREATE OR REPLACE FUNCTION academic.batch_specialization_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ok boolean;
BEGIN
  SELECT s.program_id = b.program_id AND NEW.from_term_no <= p.duration_terms INTO v_ok
  FROM academic.batch b
  JOIN academic.program p ON p.id = b.program_id
  JOIN academic.specialization s ON s.id = NEW.specialization_id
  WHERE b.id = NEW.batch_id;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'batch_specialization: specialization must belong to the batch''s programme and start within its duration'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_batch_specialization_validate
  BEFORE INSERT OR UPDATE ON academic.batch_specialization
  FOR EACH ROW EXECUTE FUNCTION academic.batch_specialization_validate();

-- ======================================================== student enrollment ==
-- A student is in exactly one batch at a time. Programme change, lateral
-- entry or re-admission = close the old row, open a new one.
CREATE TABLE academic.student_enrollment (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id     uuid NOT NULL REFERENCES people.student(id) ON DELETE CASCADE,
  batch_id       uuid NOT NULL REFERENCES academic.batch(id),
  entry_term_no  smallint NOT NULL DEFAULT 1 CHECK (entry_term_no >= 1),   -- >1 = lateral entry
  valid          daterange NOT NULL DEFAULT daterange(current_date, NULL),
  end_reason_id  smallint REFERENCES ref.enrollment_end_reason(id),        -- why it ended: award / programme change / migration / withdrawal ...
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT student_enrollment_end_reason CHECK (upper_inf(valid) = (end_reason_id IS NULL)),   -- a closed enrollment always says why
  CONSTRAINT student_enrollment_one_active EXCLUDE USING gist (student_id WITH =, valid WITH &&)
);
CREATE INDEX student_enrollment_batch_idx ON academic.student_enrollment(batch_id);
SELECT util.attach_updated_at('academic.student_enrollment');

CREATE OR REPLACE FUNCTION academic.student_enrollment_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.entry_term_no > (SELECT p.duration_terms FROM academic.batch b
                          JOIN academic.program p ON p.id = b.program_id WHERE b.id = NEW.batch_id) THEN
    RAISE EXCEPTION 'student_enrollment: entry term % exceeds programme duration', NEW.entry_term_no
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_student_enrollment_validate
  BEFORE INSERT OR UPDATE OF batch_id, entry_term_no ON academic.student_enrollment
  FOR EACH ROW EXECUTE FUNCTION academic.student_enrollment_validate();

-- Specialization chosen within an enrollment (one at a time; must be offered to the batch).
CREATE TABLE academic.student_specialization (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  specialization_id      uuid NOT NULL REFERENCES academic.specialization(id),
  valid                  daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT student_specialization_one_active
    EXCLUDE USING gist (student_enrollment_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('academic.student_specialization');

CREATE OR REPLACE FUNCTION academic.student_specialization_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.student_enrollment e
                 JOIN academic.batch_specialization bs ON bs.batch_id = e.batch_id
                 WHERE e.id = NEW.student_enrollment_id AND bs.specialization_id = NEW.specialization_id) THEN
    RAISE EXCEPTION 'student_specialization: specialization is not offered to the student''s batch'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_student_specialization_validate
  BEFORE INSERT OR UPDATE ON academic.student_specialization
  FOR EACH ROW EXECUTE FUNCTION academic.student_specialization_validate();

-- #############################################################################
-- REGULATION — grade scales and evaluation schemes (reusable rule sets)
-- #############################################################################

-- A grading scale, e.g. UGC 10-point CBCS. A new policy = a new scale; a band
-- that a published result points at can never be edited (see 04b_exam.sql).
CREATE TABLE academic.grade_scale (
  id               smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code             citext NOT NULL UNIQUE,
  name             text   NOT NULL,
  max_grade_point  numeric(4,2) NOT NULL CHECK (max_grade_point > 0),
  pct_conversion_factor numeric(5,2) CHECK (pct_conversion_factor > 0),   -- equivalent % = CGPA x factor (UGC: 10 on a 10-point scale); NULL = no conversion
  is_relative      boolean NOT NULL DEFAULT false,         -- relative grading: pass bands by percentile of the cohort (academic.relative_grade_cutoff)
  relative_min_cohort smallint CHECK (relative_min_cohort > 1),   -- below this many passing students, fall back to the absolute bands
  CHECK (NOT is_relative OR relative_min_cohort IS NOT NULL),
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('academic.grade_scale');

-- Percentage band → letter + grade point. Bands of one scale never overlap.
CREATE TABLE academic.grade_band (
  id              int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  grade_scale_id  smallint NOT NULL REFERENCES academic.grade_scale(id) ON DELETE CASCADE,
  grade_letter    citext NOT NULL,
  pct_range       numrange NOT NULL,              -- e.g. [90,100]
  grade_point     numeric(4,2) NOT NULL CHECK (grade_point >= 0),
  is_pass         boolean NOT NULL,
  UNIQUE (grade_scale_id, grade_letter),
  CHECK (NOT isempty(pct_range) AND lower(pct_range) >= 0 AND upper(pct_range) <= 100),
  CONSTRAINT grade_band_no_overlap EXCLUDE USING gist (grade_scale_id WITH =, pct_range WITH &&)
);

-- The scheme of examination for a course: which components, what weightage,
-- and HOW the result is computed. Every rule below is data, read by
-- exam.v_provisional_result, so a regulation change is a new scheme row, not code:
--   * min_aggregate_pct       overall pass mark
--   * max_internal_lead_pct   internal % may exceed external % by at most this;
--                             the excess is moderated away (common university rule)
--   * round_to_step/round_up  final rounding (e.g. step 1, round up: 54.2 -> 55)
--   * evaluation_part_rule    separate pass minimums for internal / external parts
--   * evaluation_component_group  "best N of M" (e.g. best 2 of 3 class tests)
-- Reusable — many courses share "Theory 30/20/50" or "Lab 60/40".
CREATE TABLE academic.evaluation_scheme (
  id                     int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code                   citext NOT NULL UNIQUE,
  name                   text   NOT NULL,
  min_aggregate_pct      numeric(5,2) NOT NULL CHECK (min_aggregate_pct BETWEEN 0 AND 100),  -- overall pass mark
  max_internal_lead_pct  numeric(5,2) CHECK (max_internal_lead_pct BETWEEN 0 AND 100),       -- NULL = no cap
  round_to_step          numeric(4,2) CHECK (round_to_step > 0),                              -- NULL = 2 decimals, no rounding
  round_up               boolean NOT NULL DEFAULT false,
  is_active              boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT round_up OR round_to_step IS NOT NULL)
);
SELECT util.attach_updated_at('academic.evaluation_scheme');

-- "Best N of M": the components of a group are alternatives of which only the
-- best best_of (by percentage scored) count. Every component in a group has
-- the same weight_pct — the weight of ONE counted component — so the group
-- contributes best_of x weight_pct to the scheme's 100%.
CREATE TABLE academic.evaluation_component_group (
  id                    int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  evaluation_scheme_id  int NOT NULL REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE,
  name                  text NOT NULL,                 -- "Class tests"
  best_of               smallint NOT NULL CHECK (best_of >= 1),
  UNIQUE (evaluation_scheme_id, name),
  UNIQUE (id, evaluation_scheme_id)                    -- target of the composite FK below
);

CREATE TABLE academic.evaluation_component (
  id                    int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  evaluation_scheme_id  int NOT NULL REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE,
  assessment_type_id    smallint NOT NULL REFERENCES ref.assessment_type(id),   -- also decides internal / external part
  name                  text NOT NULL,                  -- "Quiz 1", "End-term theory"
  weight_pct            numeric(5,2) NOT NULL CHECK (weight_pct > 0 AND weight_pct <= 100),
  max_marks             numeric(6,2) NOT NULL CHECK (max_marks > 0),
  min_pass_marks        numeric(6,2) CHECK (min_pass_marks >= 0),   -- component-level pass rule, if any
  component_group_id    int,                                         -- member of a "best N of M" group
  UNIQUE (evaluation_scheme_id, name),
  CHECK (min_pass_marks IS NULL OR min_pass_marks <= max_marks),
  -- a group of the SAME scheme only
  FOREIGN KEY (component_group_id, evaluation_scheme_id)
    REFERENCES academic.evaluation_component_group(id, evaluation_scheme_id) ON DELETE CASCADE
);
CREATE INDEX evaluation_component_group_idx ON academic.evaluation_component(component_group_id);

-- Separate pass minimums per part of the scheme: e.g. at least 40% in the
-- external (end-term) part, over and above the aggregate pass mark.
-- Part % = the part's weighted score / its weight, on the marks as awarded.
CREATE TABLE academic.evaluation_part_rule (
  evaluation_scheme_id  int NOT NULL REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE,
  evaluation_part_id    smallint NOT NULL REFERENCES ref.evaluation_part(id),
  min_pass_pct          numeric(5,2) NOT NULL CHECK (min_pass_pct BETWEEN 0 AND 100),
  PRIMARY KEY (evaluation_scheme_id, evaluation_part_id)
);

-- A scheduled-exam component (mid-term, end-term…) appears at most once per
-- scheme, so an answer script maps to exactly one component.
CREATE OR REPLACE FUNCTION academic.evaluation_component_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT is_scheduled_exam FROM ref.assessment_type WHERE id = NEW.assessment_type_id)
     AND EXISTS (SELECT 1 FROM academic.evaluation_component
                 WHERE evaluation_scheme_id = NEW.evaluation_scheme_id
                   AND assessment_type_id = NEW.assessment_type_id AND id <> NEW.id) THEN
    RAISE EXCEPTION 'evaluation_component: scheme % already has a component of this scheduled-exam type',
      NEW.evaluation_scheme_id USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_evaluation_component_validate
  BEFORE INSERT OR UPDATE ON academic.evaluation_component
  FOR EACH ROW EXECUTE FUNCTION academic.evaluation_component_validate();

-- Weightages of a scheme must total exactly 100 — checked at COMMIT so the
-- components can be entered one by one inside a transaction. A "best N of M"
-- group counts best_of x its (equal) component weight and must have at least
-- best_of components.
CREATE OR REPLACE FUNCTION academic.evaluation_scheme_weights_check()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_scheme int := COALESCE(NEW.evaluation_scheme_id, OLD.evaluation_scheme_id);
        v_sum numeric; v_group text;
BEGIN
  SELECT g.name INTO v_group
  FROM academic.evaluation_component_group g
  LEFT JOIN academic.evaluation_component c ON c.component_group_id = g.id
  WHERE g.evaluation_scheme_id = v_scheme
  GROUP BY g.id, g.name, g.best_of
  HAVING count(c.id) < g.best_of OR count(DISTINCT c.weight_pct) > 1
  LIMIT 1;
  IF v_group IS NOT NULL THEN
    RAISE EXCEPTION 'evaluation_scheme %: group "%" needs at least best_of components, all of equal weight', v_scheme, v_group
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT sum(w) INTO v_sum FROM (
    SELECT weight_pct AS w FROM academic.evaluation_component
    WHERE evaluation_scheme_id = v_scheme AND component_group_id IS NULL
    UNION ALL
    SELECT g.best_of * max(c.weight_pct) FROM academic.evaluation_component_group g
    JOIN academic.evaluation_component c ON c.component_group_id = g.id
    WHERE g.evaluation_scheme_id = v_scheme GROUP BY g.id, g.best_of) x;
  IF v_sum IS NOT NULL AND v_sum <> 100 THEN
    RAISE EXCEPTION 'evaluation_scheme %: component weights total %, must be 100', v_scheme, v_sum
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER trg_evaluation_scheme_weights
  AFTER INSERT OR UPDATE OR DELETE ON academic.evaluation_component
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION academic.evaluation_scheme_weights_check();
CREATE CONSTRAINT TRIGGER trg_evaluation_group_weights
  AFTER INSERT OR UPDATE OR DELETE ON academic.evaluation_component_group
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION academic.evaluation_scheme_weights_check();

-- #############################################################################
-- CURRICULUM — the scheme of studies as data
-- #############################################################################

-- Reusable guard: a column must point at an academic org unit.
CREATE OR REPLACE FUNCTION academic.require_academic_unit()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_unit uuid := (to_jsonb(NEW) ->> TG_ARGV[0])::uuid;
BEGIN
  IF v_unit IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM org.org_unit u JOIN ref.org_unit_type t ON t.id = u.org_unit_type_id
       WHERE u.id = v_unit AND t.is_academic) THEN
    RAISE EXCEPTION '%.%: % must be an academic org unit', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_ARGV[0]
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

-- A course in the catalogue, owned by one academic department (course ↔
-- department mapping: the owner designs it; any academic department may teach
-- an offering of it — see course_offering).
CREATE TABLE academic.course (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code               citext NOT NULL UNIQUE CHECK (code ~ '^[A-Za-z0-9_-]{2,32}$'),
  title              text   NOT NULL CHECK (btrim(title) <> ''),
  owner_org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  credits            numeric(4,1) NOT NULL CHECK (credits >= 0),   -- regulator-defined, not always L+T+P/2
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX course_owner_idx ON academic.course(owner_org_unit_id);
SELECT util.attach_updated_at('academic.course');
CREATE TRIGGER trg_course_academic_unit BEFORE INSERT OR UPDATE OF owner_org_unit_id ON academic.course
  FOR EACH ROW EXECUTE FUNCTION academic.require_academic_unit('owner_org_unit_id');

-- Weekly contact hours per delivery component: the L-T-P structure (3-1-2).
CREATE TABLE academic.course_component_hours (
  course_id              uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  delivery_component_id  smallint NOT NULL REFERENCES ref.delivery_component(id),
  hours_per_week         numeric(4,1) NOT NULL CHECK (hours_per_week > 0),
  PRIMARY KEY (course_id, delivery_component_id)
);

CREATE TABLE academic.course_prerequisite (
  course_id               uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  prerequisite_course_id  uuid NOT NULL REFERENCES academic.course(id),
  PRIMARY KEY (course_id, prerequisite_course_id),
  CHECK (course_id <> prerequisite_course_id)
);

CREATE OR REPLACE FUNCTION academic.course_prerequisite_no_cycle()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    WITH RECURSIVE req AS (
      SELECT prerequisite_course_id AS c FROM academic.course_prerequisite WHERE course_id = NEW.prerequisite_course_id
      UNION
      SELECT p.prerequisite_course_id FROM academic.course_prerequisite p JOIN req ON p.course_id = req.c)
    SELECT 1 FROM req WHERE c = NEW.course_id) THEN
    RAISE EXCEPTION 'course_prerequisite: % -> % would create a prerequisite cycle',
      NEW.course_id, NEW.prerequisite_course_id USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_prerequisite_no_cycle BEFORE INSERT OR UPDATE ON academic.course_prerequisite
  FOR EACH ROW EXECUTE FUNCTION academic.course_prerequisite_no_cycle();

-- A versioned scheme of studies for a programme ("B.Tech CSE — 2024 regulations"),
-- carrying the regulations every batch following it is bound by.
CREATE TABLE academic.curriculum (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id                uuid NOT NULL REFERENCES academic.program(id),
  code                      citext NOT NULL,                  -- e.g. 'R2024'
  name                      text   NOT NULL,
  grade_scale_id            smallint NOT NULL REFERENCES academic.grade_scale(id),
  attendance_threshold_pct  numeric(5,2) NOT NULL CHECK (attendance_threshold_pct BETWEEN 0 AND 100),
  max_transfer_credit_pct   numeric(5,2) CHECK (max_transfer_credit_pct BETWEEN 0 AND 100),  -- cap on MOOC / ABC credits as % of the programme's min_credits; NULL = no cap
  max_duration_years        numeric(3,1) CHECK (max_duration_years > 0),   -- UGC "N + 2": no term registration after this (NULL = no limit)
  max_attempts_per_course   smallint CHECK (max_attempts_per_course > 0), -- exam attempts per course registration (NULL = no limit)
  allows_internal_marks_revision boolean NOT NULL DEFAULT false,         -- published internal marks may be revised through an approved request
  is_active                 boolean NOT NULL DEFAULT true,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, code)
);
SELECT util.attach_updated_at('academic.curriculum');

-- A PATHWAY is an alternative course set inside one curriculum, chosen by the
-- student from a term on — e.g. from term 7 "Honours" (internship + extra
-- courses) or "Honours with Research" (dissertation). Items and award rules
-- without a pathway are common to every student of the curriculum.
CREATE TABLE academic.curriculum_pathway (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id  uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  code           citext NOT NULL,                   -- 'HONS', 'HONS-RES'
  name           text NOT NULL,
  from_term_no   smallint NOT NULL CHECK (from_term_no >= 1),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (curriculum_id, code),
  UNIQUE (id, curriculum_id)                        -- target of composite FKs (same curriculum)
);
SELECT util.attach_updated_at('academic.curriculum_pathway');

-- A RESULT GROUP makes several curriculum courses pass or fail as ONE result —
-- SGT's "Theory / Practical: result combined": the theory and practical
-- courses of a subject are evaluated separately, but the student passes only
-- on the credit-weighted combined percentage (exam.v_result_group_outcome).
CREATE TABLE academic.result_group (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id  uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  code           citext NOT NULL,
  name           text NOT NULL,
  min_pass_pct   numeric(5,2) NOT NULL CHECK (min_pass_pct BETWEEN 0 AND 100),
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (curriculum_id, code),
  UNIQUE (id, curriculum_id)
);

-- A fixed (non-elective) course in a given term of the curriculum. Optional
-- specialization_id = only students of that specialization take it; optional
-- pathway_id = only students on that pathway; optional result_group_id = its
-- result is combined with the other courses of the group.
CREATE TABLE academic.curriculum_course (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id         uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  term_no               smallint NOT NULL CHECK (term_no >= 1),
  course_id             uuid NOT NULL REFERENCES academic.course(id),
  course_category_id    smallint NOT NULL REFERENCES ref.course_category(id),
  evaluation_scheme_id  int NOT NULL REFERENCES academic.evaluation_scheme(id),
  specialization_id     uuid REFERENCES academic.specialization(id),
  pathway_id            uuid,
  result_group_id       uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id),
  FOREIGN KEY (result_group_id, curriculum_id) REFERENCES academic.result_group(id, curriculum_id)
);
SELECT util.attach_updated_at('academic.curriculum_course');

-- "Choose N of these courses in term T" — electives as an explicit basket.
CREATE TABLE academic.elective_basket (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id       uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  code                citext NOT NULL,                       -- 'PE-1', 'OE-2'
  name                text   NOT NULL,
  term_no             smallint NOT NULL CHECK (term_no >= 1),
  course_category_id  smallint NOT NULL REFERENCES ref.course_category(id),
  courses_to_choose   smallint NOT NULL CHECK (courses_to_choose >= 1),
  specialization_id   uuid REFERENCES academic.specialization(id),
  pathway_id          uuid,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (curriculum_id, code),
  FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id)
);
SELECT util.attach_updated_at('academic.elective_basket');

CREATE TABLE academic.elective_basket_course (
  elective_basket_id    uuid NOT NULL REFERENCES academic.elective_basket(id) ON DELETE CASCADE,
  course_id             uuid NOT NULL REFERENCES academic.course(id),
  evaluation_scheme_id  int  NOT NULL REFERENCES academic.evaluation_scheme(id),
  PRIMARY KEY (elective_basket_id, course_id)
);

-- Guards on curriculum items: term within the programme's duration (and not
-- before its pathway starts), the specialization belongs to the programme,
-- fixed courses use a non-elective category and baskets an elective one, and a
-- course appears ONCE per curriculum — once common, or once per pathway — so a
-- student's scheme is never ambiguous.
CREATE OR REPLACE FUNCTION academic.curriculum_item_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_curriculum uuid; v_term smallint; v_spec uuid; v_category smallint; v_course uuid;
  v_program uuid; v_duration smallint; v_is_elective boolean;
  v_self_fixed uuid; v_self_basket uuid; v_pathway uuid;
BEGIN
  IF TG_TABLE_NAME = 'elective_basket_course' THEN
    SELECT b.curriculum_id, b.term_no, b.specialization_id, b.course_category_id, b.pathway_id
      INTO v_curriculum, v_term, v_spec, v_category, v_pathway
    FROM academic.elective_basket b WHERE b.id = NEW.elective_basket_id;
    v_course := NEW.course_id;
    v_self_basket := NEW.elective_basket_id;
  ELSIF TG_TABLE_NAME = 'elective_basket' THEN
    v_curriculum := NEW.curriculum_id; v_term := NEW.term_no; v_spec := NEW.specialization_id;
    v_category := NEW.course_category_id; v_pathway := NEW.pathway_id;
  ELSE
    v_curriculum := NEW.curriculum_id; v_term := NEW.term_no; v_spec := NEW.specialization_id;
    v_category := NEW.course_category_id; v_course := NEW.course_id;
    v_self_fixed := NEW.id; v_pathway := NEW.pathway_id;
  END IF;

  IF v_pathway IS NOT NULL AND v_term < (SELECT from_term_no FROM academic.curriculum_pathway WHERE id = v_pathway) THEN
    RAISE EXCEPTION '%: term % is before the pathway starts', TG_TABLE_NAME, v_term USING ERRCODE = 'check_violation';
  END IF;

  SELECT c.program_id, p.duration_terms INTO v_program, v_duration
  FROM academic.curriculum c JOIN academic.program p ON p.id = c.program_id WHERE c.id = v_curriculum;
  IF v_term > v_duration THEN
    RAISE EXCEPTION '%: term % is beyond the programme duration (% terms)', TG_TABLE_NAME, v_term, v_duration
      USING ERRCODE = 'check_violation';
  END IF;
  IF v_spec IS NOT NULL AND NOT EXISTS (SELECT 1 FROM academic.specialization
                                        WHERE id = v_spec AND program_id = v_program) THEN
    RAISE EXCEPTION '%: specialization does not belong to the curriculum''s programme', TG_TABLE_NAME
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_TABLE_NAME <> 'elective_basket_course' THEN
    SELECT is_elective INTO v_is_elective FROM ref.course_category WHERE id = v_category;
    IF TG_TABLE_NAME = 'curriculum_course' AND v_is_elective THEN
      RAISE EXCEPTION 'curriculum_course: elective categories belong in an elective_basket'
        USING ERRCODE = 'check_violation';
    ELSIF TG_TABLE_NAME = 'elective_basket' AND NOT v_is_elective THEN
      RAISE EXCEPTION 'elective_basket: category must be an elective category'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- same course twice is a clash unless both sit on DIFFERENT pathways
  IF v_course IS NOT NULL AND (
       EXISTS (SELECT 1 FROM academic.curriculum_course cc
               WHERE cc.curriculum_id = v_curriculum AND cc.course_id = v_course
                 AND cc.id IS DISTINCT FROM v_self_fixed
                 AND (cc.pathway_id IS NULL OR v_pathway IS NULL OR cc.pathway_id = v_pathway))
    OR EXISTS (SELECT 1 FROM academic.elective_basket_course bc
               JOIN academic.elective_basket b ON b.id = bc.elective_basket_id
               WHERE b.curriculum_id = v_curriculum AND bc.course_id = v_course
                 AND bc.elective_basket_id IS DISTINCT FROM v_self_basket
                 AND (b.pathway_id IS NULL OR v_pathway IS NULL OR b.pathway_id = v_pathway))) THEN
    RAISE EXCEPTION '%: course already appears in this curriculum (for this pathway)', TG_TABLE_NAME
      USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_curriculum_course_validate BEFORE INSERT OR UPDATE ON academic.curriculum_course
  FOR EACH ROW EXECUTE FUNCTION academic.curriculum_item_validate();
CREATE TRIGGER trg_elective_basket_validate BEFORE INSERT OR UPDATE ON academic.elective_basket
  FOR EACH ROW EXECUTE FUNCTION academic.curriculum_item_validate();
CREATE TRIGGER trg_elective_basket_course_validate BEFORE INSERT OR UPDATE ON academic.elective_basket_course
  FOR EACH ROW EXECUTE FUNCTION academic.curriculum_item_validate();

-- Which curriculum version an intake follows. A separate 1:1 table (not a
-- column on batch) so the programme is never stored twice in one row.
CREATE TABLE academic.batch_curriculum (
  batch_id       uuid PRIMARY KEY REFERENCES academic.batch(id) ON DELETE CASCADE,
  curriculum_id  uuid NOT NULL REFERENCES academic.curriculum(id),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION academic.batch_curriculum_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT program_id FROM academic.batch WHERE id = NEW.batch_id)
     IS DISTINCT FROM (SELECT program_id FROM academic.curriculum WHERE id = NEW.curriculum_id) THEN
    RAISE EXCEPTION 'batch_curriculum: curriculum belongs to a different programme than the batch'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_batch_curriculum_validate BEFORE INSERT OR UPDATE ON academic.batch_curriculum
  FOR EACH ROW EXECUTE FUNCTION academic.batch_curriculum_validate();

-- A student's pathway choice (one at a time), from the curriculum their batch
-- follows. Registration and award eligibility follow the pathway.
CREATE TABLE academic.student_pathway (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  curriculum_pathway_id  uuid NOT NULL REFERENCES academic.curriculum_pathway(id),
  valid                  daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT student_pathway_one_active EXCLUDE USING gist (student_enrollment_id WITH =, valid WITH &&)
);
CREATE INDEX student_pathway_pathway_idx ON academic.student_pathway(curriculum_pathway_id);
SELECT util.attach_updated_at('academic.student_pathway');

CREATE OR REPLACE FUNCTION academic.student_pathway_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.student_enrollment e
                 JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
                 JOIN academic.curriculum_pathway cp ON cp.curriculum_id = bc.curriculum_id
                 WHERE e.id = NEW.student_enrollment_id AND cp.id = NEW.curriculum_pathway_id) THEN
    RAISE EXCEPTION 'student_pathway: the pathway is not in the student''s curriculum' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_student_pathway_validate BEFORE INSERT OR UPDATE ON academic.student_pathway
  FOR EACH ROW EXECUTE FUNCTION academic.student_pathway_validate();

-- The pathway an enrollment is on during a period (NULL = none chosen).
CREATE OR REPLACE FUNCTION academic.enrollment_pathway(p_enrollment uuid, p_period daterange)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT curriculum_pathway_id FROM academic.student_pathway
  WHERE student_enrollment_id = p_enrollment AND valid && p_period
  ORDER BY lower(valid) DESC LIMIT 1;
$$;

-- Reappear chances per attempt type, on top of the overall
-- curriculum.max_attempts_per_course: e.g. SGT "two usual + 1 golden + mercy"
-- = BACKLOG 2, GOLDEN_CHANCE 1, MERCY_CHANCE 1. No row = no separate limit
-- for that attempt type. Enforced on exam registration (04f).
CREATE TABLE academic.attempt_allowance (
  curriculum_id         uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  exam_attempt_type_id  smallint NOT NULL REFERENCES ref.exam_attempt_type(id),
  max_attempts          smallint NOT NULL CHECK (max_attempts >= 0),
  PRIMARY KEY (curriculum_id, exam_attempt_type_id)
);

-- The code a regulator (council) knows a course by — the SOE's "Council Code".
-- A course may carry one code per regulator; a regulator's code is unique.
CREATE TABLE academic.course_regulator_code (
  course_id           uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  regulatory_body_id  smallint NOT NULL REFERENCES ref.regulatory_body(id),
  code                citext NOT NULL,
  PRIMARY KEY (course_id, regulatory_body_id),
  UNIQUE (regulatory_body_id, code)
);

-- A course that CONTINUES an earlier one across terms (Dissertation II
-- continues Dissertation I; a year-long course split in two halves). A student
-- may register for the continuation only after registering the earlier part
-- in an earlier term. Chains never loop.
CREATE TABLE academic.course_continuation (
  course_id            uuid PRIMARY KEY REFERENCES academic.course(id) ON DELETE CASCADE,
  continues_course_id  uuid NOT NULL REFERENCES academic.course(id),
  CHECK (course_id <> continues_course_id)
);

CREATE OR REPLACE FUNCTION academic.course_continuation_no_cycle()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    WITH RECURSIVE up AS (
      SELECT continues_course_id AS c FROM academic.course_continuation WHERE course_id = NEW.continues_course_id
      UNION
      SELECT cc.continues_course_id FROM academic.course_continuation cc JOIN up ON cc.course_id = up.c)
    SELECT 1 FROM up WHERE c = NEW.course_id) THEN
    RAISE EXCEPTION 'course_continuation: would create a loop' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_continuation_no_cycle BEFORE INSERT OR UPDATE ON academic.course_continuation
  FOR EACH ROW EXECUTE FUNCTION academic.course_continuation_no_cycle();

-- #############################################################################
-- DELIVERY — offerings, sections, registrations, faculty assignment
-- #############################################################################

-- A course running in a specific term, taught by a department that may differ
-- from the owner (e.g. Mathematics teaches "Engineering Maths" owned by SET).
CREATE TABLE academic.course_offering (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id             uuid NOT NULL REFERENCES academic.course(id),
  academic_term_id      uuid NOT NULL REFERENCES academic.academic_term(id),
  offering_org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  intake_limit          smallint CHECK (intake_limit > 0),     -- for electives; NULL = no cap
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, academic_term_id)
);
SELECT util.attach_updated_at('academic.course_offering');
CREATE TRIGGER trg_course_offering_academic_unit BEFORE INSERT OR UPDATE OF offering_org_unit_id ON academic.course_offering
  FOR EACH ROW EXECUTE FUNCTION academic.require_academic_unit('offering_org_unit_id');

-- A class section of a batch in a term (A, B, C…).
CREATE TABLE academic.section (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id          uuid NOT NULL REFERENCES academic.batch(id),
  academic_term_id  uuid NOT NULL REFERENCES academic.academic_term(id),
  code              citext NOT NULL,
  capacity          smallint NOT NULL CHECK (capacity > 0),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (batch_id, academic_term_id, code)
);
SELECT util.attach_updated_at('academic.section');

-- A student's section for a term: the enrollment must be in the section's
-- batch, one section per term, and the section may not exceed capacity.
CREATE TABLE academic.section_student (
  section_id             uuid NOT NULL REFERENCES academic.section(id) ON DELETE CASCADE,
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  created_at             timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (section_id, student_enrollment_id)
);
CREATE INDEX section_student_enrollment_idx ON academic.section_student(student_enrollment_id);

CREATE OR REPLACE FUNCTION academic.section_student_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_batch uuid; v_term uuid; v_capacity smallint;
BEGIN
  SELECT batch_id, academic_term_id, capacity INTO v_batch, v_term, v_capacity
  FROM academic.section WHERE id = NEW.section_id;
  IF (SELECT batch_id FROM academic.student_enrollment WHERE id = NEW.student_enrollment_id) <> v_batch THEN
    RAISE EXCEPTION 'section_student: student is not enrolled in this section''s batch' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.section_student ss JOIN academic.section s ON s.id = ss.section_id
             WHERE ss.student_enrollment_id = NEW.student_enrollment_id AND s.academic_term_id = v_term
               AND ss.section_id <> NEW.section_id) THEN
    RAISE EXCEPTION 'section_student: student already has a section this term' USING ERRCODE = 'unique_violation';
  END IF;
  IF (SELECT count(*) FROM academic.section_student WHERE section_id = NEW.section_id) >= v_capacity THEN
    RAISE EXCEPTION 'section_student: section is full (capacity %)', v_capacity USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_section_student_validate BEFORE INSERT OR UPDATE ON academic.section_student
  FOR EACH ROW EXECUTE FUNCTION academic.section_student_validate();

-- A student taking a course offering. Core courses are registered for the
-- whole batch; electives are chosen. The course must be in the student's
-- curriculum (fixed or in a basket), be an approved EQUIVALENT of a
-- curriculum course (a backlog student after a curriculum change), or belong
-- to a minor / honours track the student is on — which is also how the
-- registration's evaluation scheme and category are derived (never copied here).
CREATE TABLE academic.course_registration (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id   uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  course_offering_id      uuid NOT NULL REFERENCES academic.course_offering(id),
  registration_status_id  smallint NOT NULL REFERENCES ref.registration_status(id),
  registered_at           timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_enrollment_id, course_offering_id)
);
CREATE INDEX course_registration_offering_idx ON academic.course_registration(course_offering_id);
SELECT util.attach_updated_at('academic.course_registration');

CREATE OR REPLACE FUNCTION academic.course_registration_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_curriculum uuid; v_course uuid; v_limit smallint; v_term_period daterange; v_pathway uuid; v_earlier uuid;
BEGIN
  SELECT bc.curriculum_id INTO v_curriculum
  FROM academic.student_enrollment e JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
  WHERE e.id = NEW.student_enrollment_id;
  SELECT o.course_id, o.intake_limit, t.period INTO v_course, v_limit, v_term_period
  FROM academic.course_offering o JOIN academic.academic_term t ON t.id = o.academic_term_id
  WHERE o.id = NEW.course_offering_id;

  IF v_curriculum IS NULL THEN
    RAISE EXCEPTION 'course_registration: the student''s batch has no curriculum assigned' USING ERRCODE = 'check_violation';
  END IF;
  v_pathway := academic.enrollment_pathway(NEW.student_enrollment_id, v_term_period);
  -- a curriculum item common to all, or on the student's pathway
  IF NOT EXISTS (SELECT 1 FROM academic.v_curriculum_item WHERE curriculum_id = v_curriculum AND course_id = v_course
                   AND (pathway_id IS NULL OR pathway_id = v_pathway))
     -- an approved equivalent of a course in the curriculum
     AND NOT EXISTS (SELECT 1 FROM academic.course_equivalence ce
                     JOIN academic.v_curriculum_item ci ON ci.curriculum_id = v_curriculum AND ci.course_id = ce.course_id
                     WHERE ce.equivalent_course_id = v_course AND (ci.pathway_id IS NULL OR ci.pathway_id = v_pathway))
     -- a course of a minor / honours track the student is on during that term
     AND NOT EXISTS (SELECT 1 FROM academic.student_track st
                     JOIN academic.track_course tc ON tc.track_id = st.track_id
                     WHERE st.student_enrollment_id = NEW.student_enrollment_id AND tc.course_id = v_course
                       AND st.valid && v_term_period) THEN
    RAISE EXCEPTION 'course_registration: course is not in the student''s curriculum (or pathway), an approved equivalent, or a course of their track'
      USING ERRCODE = 'check_violation';
  END IF;
  -- a continuing course needs its earlier part registered in an earlier term
  SELECT continues_course_id INTO v_earlier FROM academic.course_continuation WHERE course_id = v_course;
  IF v_earlier IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.course_registration r
       JOIN academic.course_offering o ON o.id = r.course_offering_id AND o.course_id = v_earlier
       JOIN academic.academic_term t   ON t.id = o.academic_term_id
       JOIN academic.v_enrollment_lineage lin ON lin.ancestor_enrollment_id = r.student_enrollment_id
       WHERE lin.student_enrollment_id = NEW.student_enrollment_id AND lower(t.period) < lower(v_term_period)) THEN
    RAISE EXCEPTION 'course_registration: this course continues an earlier course the student has not taken yet'
      USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' AND v_limit IS NOT NULL AND
     (SELECT count(*) FROM academic.course_registration r JOIN ref.registration_status s ON s.id = r.registration_status_id
      WHERE r.course_offering_id = NEW.course_offering_id AND s.is_counted) >= v_limit THEN
    RAISE EXCEPTION 'course_registration: offering is full (intake limit %)', v_limit USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_registration_validate BEFORE INSERT OR UPDATE OF student_enrollment_id, course_offering_id
  ON academic.course_registration FOR EACH ROW EXECUTE FUNCTION academic.course_registration_validate();

-- #############################################################################
-- CLASS GROUPS — lab batches and elective groups inside a course offering
-- #############################################################################

-- A teaching group smaller than a section, or cutting across sections:
--   * a lab / tutorial batch of one section  (parent_section_id set):
--       section A → batches A1, A2, each with its own teacher and lab slot
--   * an elective / open-course group across batches (parent_section_id NULL):
--       120 students from several batches choose ML → "ML-G1", "ML-G2"
-- delivery_component_id NULL = the group is used for every component of the
-- course; otherwise only for that one (e.g. lab batches for PRACTICAL only).
CREATE TABLE academic.class_group (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_offering_id     uuid NOT NULL REFERENCES academic.course_offering(id) ON DELETE CASCADE,
  code                   citext NOT NULL,                  -- 'A1', 'ML-G1'
  parent_section_id      uuid REFERENCES academic.section(id),
  delivery_component_id  smallint REFERENCES ref.delivery_component(id),
  capacity               smallint NOT NULL CHECK (capacity > 0),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_offering_id, code)
);
CREATE INDEX class_group_parent_section_idx ON academic.class_group(parent_section_id);
SELECT util.attach_updated_at('academic.class_group');

CREATE OR REPLACE FUNCTION academic.class_group_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.parent_section_id IS NOT NULL AND
     (SELECT academic_term_id FROM academic.section WHERE id = NEW.parent_section_id) <>
     (SELECT academic_term_id FROM academic.course_offering WHERE id = NEW.course_offering_id) THEN
    RAISE EXCEPTION 'class_group: parent section and offering are in different terms' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.delivery_component_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.course_component_hours h JOIN academic.course_offering o ON o.course_id = h.course_id
       WHERE o.id = NEW.course_offering_id AND h.delivery_component_id = NEW.delivery_component_id) THEN
    RAISE EXCEPTION 'class_group: the course has no hours for this delivery component' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_class_group_validate BEFORE INSERT OR UPDATE ON academic.class_group
  FOR EACH ROW EXECUTE FUNCTION academic.class_group_validate();

-- A registered student placed in a class group. Must be registered for the
-- group's offering, in the parent section (for a section's batch), within
-- capacity, and in only ONE group per offering for the same component.
CREATE TABLE academic.class_group_member (
  class_group_id          uuid NOT NULL REFERENCES academic.class_group(id) ON DELETE CASCADE,
  course_registration_id  uuid NOT NULL REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  created_at              timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (class_group_id, course_registration_id)
);
CREATE INDEX class_group_member_registration_idx ON academic.class_group_member(course_registration_id);

CREATE OR REPLACE FUNCTION academic.class_group_member_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_offering uuid; v_parent uuid; v_component smallint; v_capacity smallint;
BEGIN
  SELECT course_offering_id, parent_section_id, delivery_component_id, capacity
    INTO v_offering, v_parent, v_component, v_capacity
  FROM academic.class_group WHERE id = NEW.class_group_id;

  IF (SELECT course_offering_id FROM academic.course_registration WHERE id = NEW.course_registration_id) <> v_offering THEN
    RAISE EXCEPTION 'class_group_member: student is not registered for this group''s course offering' USING ERRCODE = 'check_violation';
  END IF;
  IF v_parent IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.course_registration r
       JOIN academic.section_student ss ON ss.student_enrollment_id = r.student_enrollment_id
       WHERE r.id = NEW.course_registration_id AND ss.section_id = v_parent) THEN
    RAISE EXCEPTION 'class_group_member: student is not in this batch''s parent section' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.class_group_member m JOIN academic.class_group g ON g.id = m.class_group_id
             WHERE m.course_registration_id = NEW.course_registration_id AND g.id <> NEW.class_group_id
               AND g.course_offering_id = v_offering
               AND (g.delivery_component_id IS NULL OR v_component IS NULL OR g.delivery_component_id = v_component)) THEN
    RAISE EXCEPTION 'class_group_member: student is already in another group of this course for the same component'
      USING ERRCODE = 'unique_violation';
  END IF;
  IF (SELECT count(*) FROM academic.class_group_member
      WHERE class_group_id = NEW.class_group_id AND course_registration_id <> NEW.course_registration_id) >= v_capacity THEN
    RAISE EXCEPTION 'class_group_member: group is full (capacity %)', v_capacity USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_class_group_member_validate BEFORE INSERT OR UPDATE ON academic.class_group_member
  FOR EACH ROW EXECUTE FUNCTION academic.class_group_member_validate();

-- Adding a student to a group that is already timetabled must not give that
-- student two classes at once (the group's slots vs. everything else they attend).
CREATE OR REPLACE FUNCTION academic.class_group_member_clash_check()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_enrollment uuid;
BEGIN
  SELECT student_enrollment_id INTO v_enrollment FROM academic.course_registration WHERE id = NEW.course_registration_id;
  IF EXISTS (
    SELECT 1
    FROM academic.teaching_assignment ta_g
    JOIN academic.timetable_entry te_g ON te_g.teaching_assignment_id = ta_g.id
    JOIN academic.time_slot s_g        ON s_g.id = te_g.time_slot_id
    JOIN academic.v_assignment_student other ON other.student_enrollment_id = v_enrollment
    JOIN academic.teaching_assignment ta_o ON ta_o.id = other.teaching_assignment_id
    JOIN academic.timetable_entry te_o ON te_o.teaching_assignment_id = ta_o.id
    JOIN academic.time_slot s_o        ON s_o.id = te_o.time_slot_id
    WHERE ta_g.class_group_id = NEW.class_group_id
      AND ta_o.id <> ta_g.id
      AND NOT (ta_o.course_offering_id = ta_g.course_offering_id
               AND ta_o.delivery_component_id = ta_g.delivery_component_id
               AND ta_o.class_group_id IS NOT DISTINCT FROM ta_g.class_group_id
               AND ta_o.section_id IS NOT DISTINCT FROM ta_g.section_id)
      AND s_o.day_of_week = s_g.day_of_week AND s_o.start_time < s_g.end_time AND s_g.start_time < s_o.end_time
      AND te_o.valid && te_g.valid
      AND academic.week_patterns_meet(lower(te_o.valid), te_o.repeat_every_weeks, lower(te_g.valid), te_g.repeat_every_weeks)) THEN
    RAISE EXCEPTION 'class_group_member: this group''s timetable clashes with another class the student attends'
      USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_class_group_member_clash AFTER INSERT OR UPDATE ON academic.class_group_member
  FOR EACH ROW EXECUTE FUNCTION academic.class_group_member_clash_check();

-- Faculty ↔ course ↔ class assignment, per delivery component (who takes the
-- lecture, who takes the lab). The "class" is one of:
--   * a SECTION      → section-wise teaching: each section of a course can
--                      have its own teacher for each component
--   * a CLASS GROUP  → a lab batch of a section, or an elective group
--   * neither (both NULL) → one combined class for all registered students
-- One PRIMARY faculty per (offering, class, component) at a time; co-faculty
-- allowed. Gaps (registered students with no teacher) → academic.v_teaching_gap.
CREATE TABLE academic.teaching_assignment (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_offering_id     uuid NOT NULL REFERENCES academic.course_offering(id) ON DELETE CASCADE,
  section_id             uuid REFERENCES academic.section(id),
  class_group_id         uuid REFERENCES academic.class_group(id) ON DELETE CASCADE,
  employee_id            uuid NOT NULL REFERENCES people.employee(id),
  delivery_component_id  smallint NOT NULL REFERENCES ref.delivery_component(id),
  is_primary             boolean NOT NULL DEFAULT true,
  valid                  daterange NOT NULL,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT teaching_assignment_one_target CHECK (num_nonnulls(section_id, class_group_id) <= 1),
  CONSTRAINT teaching_assignment_one_primary EXCLUDE USING gist (
    course_offering_id WITH =,
    (COALESCE(class_group_id, section_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =,
    delivery_component_id WITH =, valid WITH &&) WHERE (is_primary),
  CONSTRAINT teaching_assignment_no_duplicate EXCLUDE USING gist (
    course_offering_id WITH =,
    (COALESCE(class_group_id, section_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =,
    delivery_component_id WITH =, employee_id WITH =, valid WITH &&)
);
CREATE INDEX teaching_assignment_employee_idx ON academic.teaching_assignment(employee_id);
CREATE INDEX teaching_assignment_group_idx ON academic.teaching_assignment(class_group_id);
SELECT util.attach_updated_at('academic.teaching_assignment');

CREATE OR REPLACE FUNCTION academic.teaching_assignment_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_term uuid; v_period daterange; v_g_offering uuid; v_g_component smallint;
BEGIN
  SELECT o.academic_term_id, t.period INTO v_term, v_period
  FROM academic.course_offering o JOIN academic.academic_term t ON t.id = o.academic_term_id
  WHERE o.id = NEW.course_offering_id;
  IF NEW.section_id IS NOT NULL AND (SELECT academic_term_id FROM academic.section WHERE id = NEW.section_id) <> v_term THEN
    RAISE EXCEPTION 'teaching_assignment: section and offering are in different terms' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.class_group_id IS NOT NULL THEN
    SELECT course_offering_id, delivery_component_id INTO v_g_offering, v_g_component
    FROM academic.class_group WHERE id = NEW.class_group_id;
    IF v_g_offering <> NEW.course_offering_id THEN
      RAISE EXCEPTION 'teaching_assignment: class group belongs to a different course offering' USING ERRCODE = 'check_violation';
    END IF;
    IF v_g_component IS NOT NULL AND v_g_component <> NEW.delivery_component_id THEN
      RAISE EXCEPTION 'teaching_assignment: class group is for a different delivery component' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NOT (NEW.valid <@ v_period) THEN
    RAISE EXCEPTION 'teaching_assignment: validity % is outside the term %', NEW.valid, v_period USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM academic.course_component_hours h JOIN academic.course_offering o ON o.course_id = h.course_id
                 WHERE o.id = NEW.course_offering_id AND h.delivery_component_id = NEW.delivery_component_id) THEN
    RAISE EXCEPTION 'teaching_assignment: the course has no hours for this delivery component' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_teaching_assignment_validate BEFORE INSERT OR UPDATE ON academic.teaching_assignment
  FOR EACH ROW EXECUTE FUNCTION academic.teaching_assignment_validate();

-- #############################################################################
-- TIMETABLE — inputs for the Django solver, and its clash-free output
-- #############################################################################

-- Alternate-week classes: an entry repeats every N weeks, counted from the
-- week its validity starts (N = 1 weekly, 2 fortnightly …). Two patterns can
-- put classes in the same week iff their start weeks differ by a multiple of
-- gcd(N1, N2) — e.g. batch A1 fortnightly from week 1 and A2 fortnightly
-- from week 2 never meet, so they may share a lab, a teacher or a slot.
CREATE OR REPLACE FUNCTION academic.week_patterns_meet(a_from date, a_every smallint, b_from date, b_every smallint)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT ((date_trunc('week', a_from)::date - date_trunc('week', b_from)::date) / 7) % gcd(a_every::int, b_every::int) = 0
$$;

-- Does a date fall on an occurrence week of a pattern starting at p_from?
CREATE OR REPLACE FUNCTION academic.is_pattern_week(p_from date, p_every smallint, p_date date)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT ((date_trunc('week', p_date)::date - date_trunc('week', p_from)::date) / 7) % p_every = 0
$$;

-- Reusable weekly slot template (Mon 09:00–09:55 …). ISO weekday 1 = Monday.
CREATE TABLE academic.time_slot (
  id           smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code         citext NOT NULL UNIQUE,
  day_of_week  smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time   time NOT NULL,
  end_time     time NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  CHECK (end_time > start_time),
  UNIQUE (day_of_week, start_time, end_time)
);

-- When a faculty member cannot be scheduled (research day, admin duty…).
CREATE TABLE academic.faculty_unavailability (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id  uuid NOT NULL REFERENCES people.employee(id) ON DELETE CASCADE,
  day_of_week  smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time   time NOT NULL,
  end_time     time NOT NULL,
  valid        daterange NOT NULL,
  reason       text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (end_time > start_time),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid))
);
CREATE INDEX faculty_unavailability_employee_idx ON academic.faculty_unavailability(employee_id);

-- One weekly timetable cell: a teaching assignment in a slot and a room, for
-- a date range inside the assignment. The database rejects any room or
-- faculty double-booking, a section (or one of its batches) having two
-- classes at once, any student who would attend two classes at once (elective
-- groups / combined classes, checked by roster), and any slot the faculty
-- marked unavailable. Co-teachers of the very same class (same offering,
-- component and section/group) may share the slot and room; two different
-- batches of one section may run in parallel; entries on alternate weeks
-- (repeat_every_weeks) that never fall in the same week do not clash.
CREATE TABLE academic.timetable_entry (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teaching_assignment_id  uuid NOT NULL REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE,
  time_slot_id            smallint NOT NULL REFERENCES academic.time_slot(id),
  room_id                 uuid NOT NULL REFERENCES org.room(id),
  repeat_every_weeks      smallint NOT NULL DEFAULT 1 CHECK (repeat_every_weeks BETWEEN 1 AND 4),  -- 2 = fortnightly, from the week valid starts
  valid                   daterange NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid))
);
CREATE INDEX timetable_entry_assignment_idx ON academic.timetable_entry(teaching_assignment_id);
CREATE INDEX timetable_entry_room_idx ON academic.timetable_entry(room_id);
SELECT util.attach_updated_at('academic.timetable_entry');

CREATE OR REPLACE FUNCTION academic.timetable_entry_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_employee uuid; v_section uuid; v_group uuid; v_eff_section uuid;
  v_offering uuid; v_component smallint; v_valid daterange;
  v_day smallint; v_start time; v_end time;
BEGIN
  SELECT ta.employee_id, ta.section_id, ta.class_group_id, COALESCE(ta.section_id, g.parent_section_id),
         ta.course_offering_id, ta.delivery_component_id, ta.valid
    INTO v_employee, v_section, v_group, v_eff_section, v_offering, v_component, v_valid
  FROM academic.teaching_assignment ta
  LEFT JOIN academic.class_group g ON g.id = ta.class_group_id
  WHERE ta.id = NEW.teaching_assignment_id;
  SELECT day_of_week, start_time, end_time INTO v_day, v_start, v_end
  FROM academic.time_slot WHERE id = NEW.time_slot_id;

  IF NOT (NEW.valid <@ v_valid) THEN
    RAISE EXCEPTION 'timetable_entry: validity % is outside the teaching assignment %', NEW.valid, v_valid
      USING ERRCODE = 'check_violation';
  END IF;

  -- Every other entry overlapping in weekday, clock time and date range.
  -- same_class = co-teaching the very same class (same offering, component and
  -- section/group) — the only case where sharing a room or students is fine.
  CREATE TEMP TABLE IF NOT EXISTS tt_overlap (
    teaching_assignment_id uuid, room_id uuid, employee_id uuid,
    group_id uuid, eff_section_id uuid, same_class boolean) ON COMMIT DROP;
  DELETE FROM tt_overlap;
  INSERT INTO tt_overlap
  SELECT ta.id, te.room_id, ta.employee_id, ta.class_group_id, COALESCE(ta.section_id, g.parent_section_id),
         (ta.course_offering_id = v_offering AND ta.delivery_component_id = v_component
          AND ta.section_id IS NOT DISTINCT FROM v_section AND ta.class_group_id IS NOT DISTINCT FROM v_group)
  FROM academic.timetable_entry te
  JOIN academic.time_slot s ON s.id = te.time_slot_id
  JOIN academic.teaching_assignment ta ON ta.id = te.teaching_assignment_id
  LEFT JOIN academic.class_group g ON g.id = ta.class_group_id
  WHERE te.id <> NEW.id AND s.day_of_week = v_day
    AND s.start_time < v_end AND v_start < s.end_time
    AND te.valid && NEW.valid
    AND academic.week_patterns_meet(lower(te.valid), te.repeat_every_weeks, lower(NEW.valid), NEW.repeat_every_weeks);

  IF EXISTS (SELECT 1 FROM tt_overlap WHERE employee_id = v_employee) THEN
    RAISE EXCEPTION 'timetable clash: faculty is already teaching in this slot' USING ERRCODE = 'exclusion_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM tt_overlap WHERE room_id = NEW.room_id AND NOT same_class) THEN
    RAISE EXCEPTION 'timetable clash: room is already booked in this slot' USING ERRCODE = 'exclusion_violation';
  END IF;
  -- Structural: same section, or a section's batch against a whole-section
  -- class. Two DIFFERENT batches of one section may run in parallel (A1 in
  -- lab 1 while A2 is in lab 2) — that is the point of batches.
  IF v_eff_section IS NOT NULL AND EXISTS (
       SELECT 1 FROM tt_overlap
       WHERE eff_section_id = v_eff_section AND NOT same_class
         AND NOT (group_id IS NOT NULL AND v_group IS NOT NULL AND group_id <> v_group)) THEN
    RAISE EXCEPTION 'timetable clash: section already has a class in this slot' USING ERRCODE = 'exclusion_violation';
  END IF;
  -- By membership: any student who attends both classes (elective groups and
  -- combined classes cut across sections, so only the rosters can tell).
  IF EXISTS (SELECT 1 FROM tt_overlap o
             JOIN academic.v_assignment_student a ON a.teaching_assignment_id = o.teaching_assignment_id
             JOIN academic.v_assignment_student b ON b.student_enrollment_id = a.student_enrollment_id
                                                  AND b.teaching_assignment_id = NEW.teaching_assignment_id
             WHERE NOT o.same_class) THEN
    RAISE EXCEPTION 'timetable clash: a student in this class already has another class in this slot'
      USING ERRCODE = 'exclusion_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.faculty_unavailability fu
             WHERE fu.employee_id = v_employee AND fu.day_of_week = v_day
               AND fu.start_time < v_end AND v_start < fu.end_time AND fu.valid && NEW.valid) THEN
    RAISE EXCEPTION 'timetable clash: faculty has marked this slot unavailable' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_timetable_entry_validate BEFORE INSERT OR UPDATE ON academic.timetable_entry
  FOR EACH ROW EXECUTE FUNCTION academic.timetable_entry_validate();

-- #############################################################################
-- CLASS SESSIONS & ATTENDANCE — per lecture/lab occurrence
-- #############################################################################

-- A dated class. Either generated from a timetable entry (time, room and
-- faculty come from the entry — not copied), or an extra/make-up class with
-- its own assignment, time and room. Exactly one of the two shapes.
CREATE TABLE academic.class_session (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  timetable_entry_id        uuid REFERENCES academic.timetable_entry(id) ON DELETE CASCADE,
  teaching_assignment_id    uuid REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE,
  session_date              date NOT NULL,
  start_time                time,
  end_time                  time,
  room_id                   uuid REFERENCES org.room(id),
  class_session_status_id   smallint NOT NULL REFERENCES ref.class_session_status(id),
  substitute_employee_id    uuid REFERENCES people.employee(id),     -- who actually took it, if not the assigned faculty
  note                      text,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT class_session_shape CHECK (
       (timetable_entry_id IS NOT NULL AND teaching_assignment_id IS NULL
        AND start_time IS NULL AND end_time IS NULL AND room_id IS NULL)
    OR (timetable_entry_id IS NULL AND teaching_assignment_id IS NOT NULL
        AND start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)),
  UNIQUE (timetable_entry_id, session_date)
);
CREATE INDEX class_session_assignment_idx ON academic.class_session(teaching_assignment_id);
SELECT util.attach_updated_at('academic.class_session');

CREATE OR REPLACE FUNCTION academic.class_session_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_day smallint; v_valid daterange; v_every smallint;
BEGIN
  IF NEW.timetable_entry_id IS NOT NULL THEN
    SELECT s.day_of_week, te.valid, te.repeat_every_weeks INTO v_day, v_valid, v_every
    FROM academic.timetable_entry te JOIN academic.time_slot s ON s.id = te.time_slot_id
    WHERE te.id = NEW.timetable_entry_id;
    IF extract(isodow FROM NEW.session_date) <> v_day OR NOT (v_valid @> NEW.session_date) THEN
      RAISE EXCEPTION 'class_session: % does not fall on this timetable entry''s weekday/date range', NEW.session_date
        USING ERRCODE = 'check_violation';
    END IF;
    IF NOT academic.is_pattern_week(lower(v_valid), v_every, NEW.session_date) THEN
      RAISE EXCEPTION 'class_session: % is an off week for this class (it runs every % weeks)', NEW.session_date, v_every
        USING ERRCODE = 'check_violation';
    END IF;
  ELSE
    SELECT valid INTO v_valid FROM academic.teaching_assignment WHERE id = NEW.teaching_assignment_id;
    IF NOT (v_valid @> NEW.session_date) THEN
      RAISE EXCEPTION 'class_session: % is outside the teaching assignment', NEW.session_date USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_class_session_validate BEFORE INSERT OR UPDATE ON academic.class_session
  FOR EACH ROW EXECUTE FUNCTION academic.class_session_validate();

-- One mark per student per class session. The registration must be for the
-- session's course offering and the student must belong to the class it was
-- for (the section, the lab batch / elective group, or — for a combined class —
-- any registered student); attendance on a cancelled class is rejected.
CREATE TABLE academic.attendance (
  class_session_id         uuid NOT NULL REFERENCES academic.class_session(id) ON DELETE CASCADE,
  course_registration_id   uuid NOT NULL REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  attendance_status_id     smallint NOT NULL REFERENCES ref.attendance_status(id),
  marked_by_employee_id    uuid REFERENCES people.employee(id),
  marked_at                timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (class_session_id, course_registration_id)
);
CREATE INDEX attendance_registration_idx ON academic.attendance(course_registration_id);

CREATE OR REPLACE FUNCTION academic.attendance_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_assignment uuid; v_offering uuid; v_held boolean;
BEGIN
  SELECT ta.id, ta.course_offering_id, st.counts_as_held
    INTO v_assignment, v_offering, v_held
  FROM academic.class_session cs
  LEFT JOIN academic.timetable_entry te ON te.id = cs.timetable_entry_id
  JOIN academic.teaching_assignment ta ON ta.id = COALESCE(cs.teaching_assignment_id, te.teaching_assignment_id)
  JOIN ref.class_session_status st ON st.id = cs.class_session_status_id
  WHERE cs.id = NEW.class_session_id;

  IF NOT v_held THEN
    RAISE EXCEPTION 'attendance: the class session was not held' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT course_offering_id FROM academic.course_registration WHERE id = NEW.course_registration_id) <> v_offering THEN
    RAISE EXCEPTION 'attendance: student is not registered for this course offering' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM academic.v_assignment_student
                 WHERE teaching_assignment_id = v_assignment AND course_registration_id = NEW.course_registration_id) THEN
    RAISE EXCEPTION 'attendance: student is not in the section / group this class was for' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_attendance_validate BEFORE INSERT OR UPDATE ON academic.attendance
  FOR EACH ROW EXECUTE FUNCTION academic.attendance_validate();

-- #############################################################################
-- ACADEMIC BODIES — Board of Studies, Academic Council, committees
-- #############################################################################

-- A statutory / academic body of an org unit: the Board of Studies of a
-- department, the Faculty Board of a school, the Academic Council of the
-- university, the examination / disciplinary / moderation committees.
-- quorum = members who must attend for its resolutions to be valid.
CREATE TABLE academic.academic_body (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_body_type_id  smallint NOT NULL REFERENCES ref.academic_body_type(id),
  org_unit_id            uuid NOT NULL REFERENCES org.org_unit(id),
  name                   text NOT NULL,
  quorum                 smallint NOT NULL DEFAULT 1 CHECK (quorum >= 1),
  is_active              boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_body_type_id, org_unit_id)
);

-- Members over time: employees, or external experts (a person who is not an
-- employee). One chair at a time, and the chair is an employee.
CREATE TABLE academic.academic_body_member (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_body_id    uuid NOT NULL REFERENCES academic.academic_body(id) ON DELETE CASCADE,
  committee_role_id   smallint NOT NULL REFERENCES ref.committee_role(id),
  employee_id         uuid REFERENCES people.employee(id),
  external_person_id  uuid REFERENCES people.person(id),
  valid               daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid))
);
CREATE INDEX academic_body_member_body_idx ON academic.academic_body_member(academic_body_id);

CREATE OR REPLACE FUNCTION academic.academic_body_member_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_chair boolean; v_person uuid;
BEGIN
  SELECT is_chair INTO v_chair FROM ref.committee_role WHERE id = NEW.committee_role_id;
  IF v_chair AND NEW.employee_id IS NULL THEN
    RAISE EXCEPTION 'academic_body_member: the chair must be an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.external_person_id IS NOT NULL AND EXISTS (SELECT 1 FROM people.employee WHERE person_id = NEW.external_person_id) THEN
    RAISE EXCEPTION 'academic_body_member: an external member cannot be an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF v_chair AND EXISTS (SELECT 1 FROM academic.academic_body_member m JOIN ref.committee_role r ON r.id = m.committee_role_id AND r.is_chair
                         WHERE m.academic_body_id = NEW.academic_body_id AND m.id <> NEW.id AND m.valid && NEW.valid) THEN
    RAISE EXCEPTION 'academic_body_member: the body already has a chair in this period' USING ERRCODE = 'exclusion_violation';
  END IF;
  v_person := COALESCE(NEW.external_person_id, (SELECT person_id FROM people.employee WHERE id = NEW.employee_id));
  IF EXISTS (SELECT 1 FROM academic.academic_body_member m
             WHERE m.academic_body_id = NEW.academic_body_id AND m.id <> NEW.id AND m.valid && NEW.valid
               AND COALESCE(m.external_person_id, (SELECT person_id FROM people.employee WHERE id = m.employee_id)) = v_person) THEN
    RAISE EXCEPTION 'academic_body_member: already a member in this period' USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_academic_body_member_validate BEFORE INSERT OR UPDATE ON academic.academic_body_member
  FOR EACH ROW EXECUTE FUNCTION academic.academic_body_member_validate();

-- A meeting of a body, with its minutes, and who attended.
CREATE TABLE academic.body_meeting (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_body_id  uuid NOT NULL REFERENCES academic.academic_body(id),
  meeting_no        citext NOT NULL,                     -- 'BoS-CSE/2026/03'
  held_on           date NOT NULL,
  minutes_file_id   uuid REFERENCES people.file_object(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_body_id, meeting_no)
);

CREATE TABLE academic.body_meeting_attendee (
  body_meeting_id          uuid NOT NULL REFERENCES academic.body_meeting(id) ON DELETE CASCADE,
  academic_body_member_id  uuid NOT NULL REFERENCES academic.academic_body_member(id),
  PRIMARY KEY (body_meeting_id, academic_body_member_id)
);

CREATE OR REPLACE FUNCTION academic.body_meeting_attendee_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.body_meeting bm JOIN academic.academic_body_member m ON m.academic_body_id = bm.academic_body_id
                 WHERE bm.id = NEW.body_meeting_id AND m.id = NEW.academic_body_member_id AND m.valid @> bm.held_on) THEN
    RAISE EXCEPTION 'body_meeting_attendee: not a member of this body on the meeting date' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_body_meeting_attendee_validate BEFORE INSERT OR UPDATE ON academic.body_meeting_attendee
  FOR EACH ROW EXECUTE FUNCTION academic.body_meeting_attendee_validate();

-- A resolution passed at a meeting — valid only if the meeting had its
-- quorum. Approvals elsewhere (course equivalence, MOOC mapping, syllabus,
-- programme transfer) reference the resolution instead of quoting it as text.
CREATE TABLE academic.body_resolution (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  body_meeting_id  uuid NOT NULL REFERENCES academic.body_meeting(id),
  resolution_no    citext NOT NULL,                       -- 'R-7'
  subject          text NOT NULL CHECK (btrim(subject) <> ''),
  decision         text NOT NULL CHECK (btrim(decision) <> ''),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (body_meeting_id, resolution_no)
);

CREATE OR REPLACE FUNCTION academic.body_resolution_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_quorum smallint; v_present int;
BEGIN
  SELECT b.quorum INTO v_quorum FROM academic.body_meeting bm JOIN academic.academic_body b ON b.id = bm.academic_body_id
  WHERE bm.id = NEW.body_meeting_id;
  SELECT count(*) INTO v_present FROM academic.body_meeting_attendee WHERE body_meeting_id = NEW.body_meeting_id;
  IF v_present < v_quorum THEN
    RAISE EXCEPTION 'body_resolution: the meeting had % member(s) present, the quorum is %', v_present, v_quorum
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_body_resolution_validate BEFORE INSERT OR UPDATE ON academic.body_resolution
  FOR EACH ROW EXECUTE FUNCTION academic.body_resolution_validate();

