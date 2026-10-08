-- =============================================================================
-- 04d_student_lifecycle.sql — Student lifecycle, academic calendar, programme
-- attributes, curriculum content & outcomes, workload, feedback (schema: academic)
--
--   ACADEMIC CALENDAR
--     calendar_event                 holidays, vacations, registration / add-drop
--                                    windows, exam periods, result dates — per
--                                    year or term, university-wide or per unit
--                                    → academic.is_working_day(); timetable-generated
--                                      class sessions on a holiday are rejected
--   PROGRAMME ATTRIBUTES & APPROVALS
--     program.delivery_mode / medium_language              (04_academic.sql)
--     program_approval               regulator (UGC / AICTE / NMC …) approval with
--                                    seats and validity — a batch cannot exceed it
--     program_accreditation          NAAC (institution) / NBA (programme) grade
--   STUDENT LIFECYCLE
--     promotion_rule                 per curriculum checkpoint: backlog allowed to move up
--     curriculum.max_duration_years / max_attempts_per_course  (04_academic.sql)
--     term_registration              a student on the rolls of a term, with the
--                                    programme term number, and the end-of-term
--                                    ACADEMIC STANDING (promoted / with backlog / detained)
--     study_break                    dated break in study (medical, personal,
--                                    suspension …) — the term count pauses
--     student_enrollment.end_reason  (04_academic.sql) award / programme change /
--                                    migration / withdrawal / expulsion …
--     program_transfer               an enrollment that continues in another programme
--   ELECTIVE ALLOTMENT
--     elective_preference            a student's ranked choices in a basket
--                                    → academic.allot_electives() (merit order)
--     offering_seat_quota            seats of an offering capped per programme /
--                                    school (cross-school electives)
--   CURRICULUM CONTENT & OUTCOMES (NBA / NAAC outcome-based education)
--     course_syllabus ─< syllabus_unit, course_outcome (CO)
--     program_outcome (PO / PSO) ─< co_po_mapping
--     lesson_plan_item (per teaching assignment) ─< class_session_topic
--   FACULTY WORKLOAD
--     workload_norm                  hours / week per designation → v_faculty_workload [09]
--   DIVISION / CLASS
--     division_band                  CGPA → First class with distinction … → exam.v_division [09]
--   STUDENT FEEDBACK (anonymous by construction)
--     feedback_questionnaire ─< feedback_question; feedback_cycle (term × window)
--     feedback_submission            proves one submission per registration — the
--                                    ONLY student link, never joined to responses
--     feedback_response              cycle × teaching assignment × question — no student
--
-- Derived, never stored (09_views_functions.sql): the current term (from the
-- term registration where one exists), backlog, promotion eligibility,
-- syllabus coverage, faculty workload, division, feedback summary.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = academic, people, org, ref, public;

-- ######################################################## ACADEMIC CALENDAR ##

-- One dated event of the academic calendar. Scoped to a year (and optionally a
-- term of that year) and, optionally, to an org unit and everything under it
-- (NULL = the whole university). Non-working types (holiday, vacation) are what
-- academic.is_working_day() reads.
CREATE TABLE academic.calendar_event (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id        uuid NOT NULL REFERENCES academic.academic_year(id) ON DELETE CASCADE,
  academic_term_id        uuid REFERENCES academic.academic_term(id) ON DELETE CASCADE,
  calendar_event_type_id  smallint NOT NULL REFERENCES ref.calendar_event_type(id),
  org_unit_id             uuid REFERENCES org.org_unit(id),          -- NULL = university-wide
  name                    text NOT NULL CHECK (btrim(name) <> ''),
  period                  daterange NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period))
);
CREATE INDEX calendar_event_period_idx ON academic.calendar_event USING gist (period);
CREATE INDEX calendar_event_year_idx   ON academic.calendar_event(academic_year_id);
SELECT util.attach_updated_at('academic.calendar_event');

CREATE OR REPLACE FUNCTION academic.calendar_event_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_year_period daterange; v_term_year uuid;
BEGIN
  SELECT period INTO v_year_period FROM academic.academic_year WHERE id = NEW.academic_year_id;
  IF NOT (v_year_period @> NEW.period) THEN
    RAISE EXCEPTION 'calendar_event: % is outside the academic year %', NEW.period, v_year_period USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.academic_term_id IS NOT NULL THEN
    SELECT academic_year_id INTO v_term_year FROM academic.academic_term WHERE id = NEW.academic_term_id;
    IF v_term_year <> NEW.academic_year_id THEN
      RAISE EXCEPTION 'calendar_event: the term belongs to another academic year' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_calendar_event_validate BEFORE INSERT OR UPDATE ON academic.calendar_event
  FOR EACH ROW EXECUTE FUNCTION academic.calendar_event_validate();

-- Is p_date a working day for p_org_unit? False when a non-working calendar
-- event covers the date university-wide or for the unit / any of its ancestors.
CREATE OR REPLACE FUNCTION academic.is_working_day(p_date date, p_org_unit uuid DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$   -- plpgsql: org.ancestors() is created in 09_views_functions.sql
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM academic.calendar_event ce
    JOIN ref.calendar_event_type t ON t.id = ce.calendar_event_type_id AND t.is_non_working
    WHERE ce.period @> p_date
      AND (ce.org_unit_id IS NULL
           OR (p_org_unit IS NOT NULL AND ce.org_unit_id IN (SELECT org_unit_id FROM org.ancestors(p_org_unit)))));
END $$;

-- A timetable-generated class session cannot fall on a holiday of the offering
-- department (extra / make-up classes, which carry their own time, may).
CREATE OR REPLACE FUNCTION academic.class_session_working_day()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_unit uuid;
BEGIN
  IF NEW.timetable_entry_id IS NOT NULL THEN
    SELECT o.offering_org_unit_id INTO v_unit
    FROM academic.timetable_entry te
    JOIN academic.teaching_assignment ta ON ta.id = te.teaching_assignment_id
    JOIN academic.course_offering o      ON o.id = ta.course_offering_id
    WHERE te.id = NEW.timetable_entry_id;
    IF NOT academic.is_working_day(NEW.session_date, v_unit) THEN
      RAISE EXCEPTION 'class_session: % is not a working day (academic calendar)', NEW.session_date USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_class_session_working_day BEFORE INSERT OR UPDATE OF session_date, timetable_entry_id ON academic.class_session
  FOR EACH ROW EXECUTE FUNCTION academic.class_session_working_day();

-- ############################################ PROGRAMME APPROVAL & ACCREDITATION ##

-- Approval of a programme by a regulator (UGC, AICTE, NMC, PCI …): letter
-- number, sanctioned seats, validity. One approval per body at a time. A batch
-- of the programme cannot be opened with more seats than approved (trigger on
-- academic.batch). The letter itself may be attached as a file.
CREATE TABLE academic.program_approval (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id          uuid NOT NULL REFERENCES academic.program(id) ON DELETE CASCADE,
  regulatory_body_id  smallint NOT NULL REFERENCES ref.regulatory_body(id),
  reference_no        text NOT NULL,
  approved_seats      int CHECK (approved_seats >= 0),            -- NULL = approval without an intake figure
  valid               daterange NOT NULL,
  file_object_id      uuid REFERENCES people.file_object(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT program_approval_one_at_a_time EXCLUDE USING gist (program_id WITH =, regulatory_body_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('academic.program_approval');

-- intake_capacity of a batch ≤ every regulator's approved seats valid when the
-- admission year starts (no approval on record = nothing to check).
CREATE OR REPLACE FUNCTION academic.batch_intake_within_approval()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_min int; v_body text;
BEGIN
  IF NEW.intake_capacity IS NULL THEN RETURN NEW; END IF;
  SELECT pa.approved_seats, rb.code INTO v_min, v_body
  FROM academic.program_approval pa
  JOIN ref.regulatory_body rb    ON rb.id = pa.regulatory_body_id
  JOIN academic.academic_year y  ON y.id = NEW.admission_year_id
  WHERE pa.program_id = NEW.program_id AND pa.approved_seats IS NOT NULL AND pa.valid @> lower(y.period)
  ORDER BY pa.approved_seats LIMIT 1;
  IF v_min IS NOT NULL AND NEW.intake_capacity > v_min THEN
    RAISE EXCEPTION 'batch: intake % exceeds the % seats approved by %', NEW.intake_capacity, v_min, v_body USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_batch_intake_within_approval BEFORE INSERT OR UPDATE OF intake_capacity, program_id, admission_year_id ON academic.batch
  FOR EACH ROW EXECUTE FUNCTION academic.batch_intake_within_approval();

-- Accreditation: NAAC grades the institution (an org unit), NBA accredits a
-- programme — exactly one of the two targets. One accreditation per target and
-- body at a time.
CREATE TABLE academic.program_accreditation (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id             uuid REFERENCES academic.program(id) ON DELETE CASCADE,
  org_unit_id            uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  accreditation_body_id  smallint NOT NULL REFERENCES ref.accreditation_body(id),
  grade                  text NOT NULL,                       -- 'A++', 'Accredited (6 years)'
  score                  numeric(5,2) CHECK (score >= 0),     -- CGPA / points, if the body gives one
  reference_no           text,
  valid                  daterange NOT NULL,
  file_object_id         uuid REFERENCES people.file_object(id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(program_id, org_unit_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT program_accreditation_one_at_a_time EXCLUDE USING gist (
    (COALESCE(program_id, org_unit_id)) WITH =, accreditation_body_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('academic.program_accreditation');

-- ######################################################### STUDENT LIFECYCLE ##

-- Promotion checkpoint of a curriculum: after term N a student may move up
-- carrying at most this much backlog (credits and / or courses). No row for a
-- term = no cap at that point (only the standing's own allows_backlog rule).
CREATE TABLE academic.promotion_rule (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id        uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  after_term_no        smallint NOT NULL CHECK (after_term_no >= 1),
  max_backlog_credits  numeric(5,1) NOT NULL CHECK (max_backlog_credits >= 0),
  max_backlog_courses  smallint CHECK (max_backlog_courses >= 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (curriculum_id, after_term_no)
);
SELECT util.attach_updated_at('academic.promotion_rule');

CREATE OR REPLACE FUNCTION academic.promotion_rule_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.after_term_no > (SELECT p.duration_terms FROM academic.curriculum c JOIN academic.program p ON p.id = c.program_id
                          WHERE c.id = NEW.curriculum_id) THEN
    RAISE EXCEPTION 'promotion_rule: term % is beyond the programme duration', NEW.after_term_no USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_promotion_rule_validate BEFORE INSERT OR UPDATE ON academic.promotion_rule
  FOR EACH ROW EXECUTE FUNCTION academic.promotion_rule_validate();

-- A dated break in study (medical, personal, disciplinary suspension …), on
-- one enrollment, approved. The term count pauses: a term fully inside a break
-- is not counted, and no term registration is accepted into a term that starts
-- inside a break. reason is often health data (registered, anonymised on erasure).
CREATE TABLE academic.study_break (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id    uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  study_break_type_id      smallint NOT NULL REFERENCES ref.study_break_type(id),
  period                   daterange NOT NULL,                 -- upper NULL = open-ended
  reason                   text,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_on              date NOT NULL DEFAULT current_date,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period)),
  CONSTRAINT study_break_no_overlap EXCLUDE USING gist (student_enrollment_id WITH =, period WITH &&)
);
SELECT util.attach_updated_at('academic.study_break');

CREATE OR REPLACE FUNCTION academic.study_break_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_valid daterange;
BEGIN
  SELECT valid INTO v_valid FROM academic.student_enrollment WHERE id = NEW.student_enrollment_id;
  IF NOT (v_valid @> lower(NEW.period)) THEN
    RAISE EXCEPTION 'study_break: must start while the enrollment % is active', v_valid USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_study_break_validate BEFORE INSERT OR UPDATE ON academic.study_break
  FOR EACH ROW EXECUTE FUNCTION academic.study_break_validate();

-- A student on the rolls of one academic term, for one programme term number
-- (semester). This is the authoritative "which semester is this student in"
-- whenever it exists (academic.enrollment_term_no reads it first); without it
-- the term is derived from dates. At the end of the term the ACADEMIC STANDING
-- is decided: promoted, promoted with backlog, or detained — the database
-- checks the decision against the backlog and the curriculum's promotion rule.
CREATE TABLE academic.term_registration (
  id                               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id            uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  academic_term_id                 uuid NOT NULL REFERENCES academic.academic_term(id),
  term_no                          smallint NOT NULL CHECK (term_no >= 1),
  term_registration_status_id      smallint NOT NULL REFERENCES ref.term_registration_status(id),
  registered_at                    timestamptz NOT NULL DEFAULT now(),
  registered_by_employee_id        uuid REFERENCES people.employee(id),     -- NULL = self-service
  academic_standing_id             smallint REFERENCES ref.academic_standing(id),
  standing_decided_by_employee_id  uuid REFERENCES people.employee(id),
  standing_decided_at              timestamptz,
  standing_note                    text,
  created_at                       timestamptz NOT NULL DEFAULT now(),
  updated_at                       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_enrollment_id, academic_term_id),
  CHECK ((academic_standing_id IS NULL) = (standing_decided_by_employee_id IS NULL)
     AND (academic_standing_id IS NULL) = (standing_decided_at IS NULL))
);
CREATE INDEX term_registration_term_idx ON academic.term_registration(academic_term_id);
SELECT util.attach_updated_at('academic.term_registration');

CREATE OR REPLACE FUNCTION academic.term_registration_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_e record; v_t record; v_expected int; v_root_start date;
        v_max_years numeric; v_standing record; v_backlog record; v_rule record; v_counted boolean;
BEGIN
  SELECT e.entry_term_no, e.valid, p.duration_terms, p.academic_calendar_type_id AS cal, p.code AS program_code,
         c.max_duration_years, c.id AS curriculum_id
    INTO v_e
  FROM academic.student_enrollment e
  JOIN academic.batch b   ON b.id = e.batch_id
  JOIN academic.program p ON p.id = b.program_id
  LEFT JOIN academic.batch_curriculum bc ON bc.batch_id = b.id
  LEFT JOIN academic.curriculum c        ON c.id = bc.curriculum_id
  WHERE e.id = NEW.student_enrollment_id;
  SELECT t.period, c.academic_calendar_type_id AS cal INTO v_t
  FROM academic.academic_term t JOIN ref.term_cycle c ON c.id = t.term_cycle_id WHERE t.id = NEW.academic_term_id;
  SELECT is_counted INTO v_counted FROM ref.term_registration_status WHERE id = NEW.term_registration_status_id;

  IF v_t.cal <> v_e.cal THEN
    RAISE EXCEPTION 'term_registration: the term is of another calendar type than programme %', v_e.program_code USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (v_e.valid && v_t.period) THEN
    RAISE EXCEPTION 'term_registration: the enrollment is not active during the term' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.term_no > v_e.duration_terms THEN
    RAISE EXCEPTION 'term_registration: term % is beyond the programme duration (%)', NEW.term_no, v_e.duration_terms USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.study_break sb
             WHERE sb.student_enrollment_id = NEW.student_enrollment_id AND sb.period @> lower(v_t.period)) THEN
    RAISE EXCEPTION 'term_registration: the student is on a break in study when the term starts' USING ERRCODE = 'check_violation';
  END IF;
  -- maximum duration, counted from the first enrollment of the lineage (re-entry / transfer)
  IF v_e.max_duration_years IS NOT NULL THEN
    SELECT min(lower(e2.valid)) INTO v_root_start
    FROM academic.v_enrollment_lineage lin JOIN academic.student_enrollment e2 ON e2.id = lin.ancestor_enrollment_id
    WHERE lin.student_enrollment_id = NEW.student_enrollment_id;
    IF lower(v_t.period) >= (v_root_start + make_interval(months => (v_e.max_duration_years * 12)::int))::date THEN
      RAISE EXCEPTION 'term_registration: beyond the maximum programme duration of % years (from %)', v_e.max_duration_years, v_root_start
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  -- sequencing: the term number must be the one the enrollment is due for —
  -- academic.enrollment_term_no(): last registered term + 1 if promoted, the
  -- same term again if detained, otherwise derived from entry term and dates.
  -- (Terms spent on a break are skipped there.) A term number never changes
  -- once registered: cancel and register again.
  IF v_counted AND (TG_OP = 'INSERT' OR NEW.term_no IS DISTINCT FROM OLD.term_no OR NEW.academic_term_id IS DISTINCT FROM OLD.academic_term_id) THEN
    v_expected := academic.enrollment_term_no(NEW.student_enrollment_id, NEW.academic_term_id);
    IF NEW.term_no <> v_expected THEN
      RAISE EXCEPTION 'term_registration: expected term % for this student (got %)', v_expected, NEW.term_no USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  -- academic standing: checked against backlog and the promotion rule
  IF NEW.academic_standing_id IS NOT NULL THEN
    IF lower(v_t.period) > current_date THEN
      RAISE EXCEPTION 'term_registration: standing cannot be decided before the term starts' USING ERRCODE = 'check_violation';
    END IF;
    SELECT * INTO v_standing FROM ref.academic_standing WHERE id = NEW.academic_standing_id;
    IF v_standing.is_promoted THEN
      SELECT COALESCE(sum(credits), 0) AS credits, count(*) AS courses INTO v_backlog
      FROM academic.v_backlog bl WHERE bl.student_enrollment_id = NEW.student_enrollment_id AND bl.term_no <= NEW.term_no;
      IF NOT v_standing.allows_backlog AND v_backlog.courses > 0 THEN
        RAISE EXCEPTION 'term_registration: cannot be % with a backlog of % course(s) / % credits', v_standing.code, v_backlog.courses, v_backlog.credits
          USING ERRCODE = 'check_violation';
      END IF;
      SELECT * INTO v_rule FROM academic.promotion_rule WHERE curriculum_id = v_e.curriculum_id AND after_term_no = NEW.term_no;
      IF FOUND AND (v_backlog.credits > v_rule.max_backlog_credits
                    OR (v_rule.max_backlog_courses IS NOT NULL AND v_backlog.courses > v_rule.max_backlog_courses)) THEN
        RAISE EXCEPTION 'term_registration: backlog of % credits / % course(s) exceeds the promotion rule after term % (max % credits%)',
          v_backlog.credits, v_backlog.courses, NEW.term_no, v_rule.max_backlog_credits,
          COALESCE(' / ' || v_rule.max_backlog_courses || ' courses', '') USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_term_registration_validate BEFORE INSERT OR UPDATE ON academic.term_registration
  FOR EACH ROW EXECUTE FUNCTION academic.term_registration_validate();

-- A student continuing in another programme: the old enrollment ends with
-- reason PROGRAM_CHANGE, the new one starts on or after that date, same
-- student, different programme. Earlier credits follow through
-- academic.v_enrollment_lineage; which of them satisfy the new curriculum is a
-- matter of course_equivalence, never a copied result.
CREATE TABLE academic.program_transfer (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_enrollment_id       uuid NOT NULL UNIQUE REFERENCES academic.student_enrollment(id),
  to_enrollment_id         uuid NOT NULL UNIQUE REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_on              date NOT NULL DEFAULT current_date,
  reason                   text,
  body_resolution_id       uuid REFERENCES academic.body_resolution(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (from_enrollment_id <> to_enrollment_id)
);

CREATE OR REPLACE FUNCTION academic.program_transfer_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_from record; v_to record;
BEGIN
  SELECT e.student_id, e.valid, b.program_id, r.code AS end_reason INTO v_from
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id
  LEFT JOIN ref.enrollment_end_reason r ON r.id = e.end_reason_id
  WHERE e.id = NEW.from_enrollment_id;
  SELECT e.student_id, e.valid, b.program_id INTO v_to
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id WHERE e.id = NEW.to_enrollment_id;
  IF v_from.student_id <> v_to.student_id THEN
    RAISE EXCEPTION 'program_transfer: both enrollments must belong to the same student' USING ERRCODE = 'check_violation';
  END IF;
  IF v_from.end_reason IS DISTINCT FROM 'PROGRAM_CHANGE' THEN
    RAISE EXCEPTION 'program_transfer: the earlier enrollment must be closed with reason PROGRAM_CHANGE (is %)', COALESCE(v_from.end_reason, 'still open')
      USING ERRCODE = 'check_violation';
  END IF;
  IF v_from.program_id = v_to.program_id THEN
    RAISE EXCEPTION 'program_transfer: the new enrollment is in the same programme' USING ERRCODE = 'check_violation';
  END IF;
  IF lower(v_to.valid) < upper(v_from.valid) THEN
    RAISE EXCEPTION 'program_transfer: the new enrollment starts before the earlier one ends' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_program_transfer_validate BEFORE INSERT OR UPDATE ON academic.program_transfer
  FOR EACH ROW EXECUTE FUNCTION academic.program_transfer_validate();

-- ######################################################## ELECTIVE ALLOTMENT ##

-- A student's ranked choices in an elective basket for a term. The basket must
-- be in the student's curriculum, for the student's own term, and the course
-- in the basket. Allotment itself is academic.allot_electives(basket, term):
-- merit order (CGPA, then enrollment number), first available preference,
-- writing ordinary course_registration rows (seat limits still enforced there).
CREATE TABLE academic.elective_preference (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  elective_basket_id     uuid NOT NULL REFERENCES academic.elective_basket(id) ON DELETE CASCADE,
  academic_term_id       uuid NOT NULL REFERENCES academic.academic_term(id),
  course_id              uuid NOT NULL REFERENCES academic.course(id),
  priority               smallint NOT NULL CHECK (priority >= 1),
  submitted_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_enrollment_id, elective_basket_id, academic_term_id, priority),
  UNIQUE (student_enrollment_id, elective_basket_id, academic_term_id, course_id)
);

CREATE OR REPLACE FUNCTION academic.elective_preference_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_basket record; v_curriculum uuid; v_term_no int;
BEGIN
  SELECT curriculum_id, term_no, code INTO v_basket FROM academic.elective_basket WHERE id = NEW.elective_basket_id;
  SELECT bc.curriculum_id INTO v_curriculum
  FROM academic.student_enrollment e JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
  WHERE e.id = NEW.student_enrollment_id;
  IF v_curriculum IS DISTINCT FROM v_basket.curriculum_id THEN
    RAISE EXCEPTION 'elective_preference: basket % is not in the student''s curriculum', v_basket.code USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM academic.elective_basket_course WHERE elective_basket_id = NEW.elective_basket_id AND course_id = NEW.course_id) THEN
    RAISE EXCEPTION 'elective_preference: the course is not offered in basket %', v_basket.code USING ERRCODE = 'check_violation';
  END IF;
  v_term_no := academic.enrollment_term_no(NEW.student_enrollment_id, NEW.academic_term_id);
  IF v_term_no <> v_basket.term_no THEN
    RAISE EXCEPTION 'elective_preference: basket % is for term %, the student is in term %', v_basket.code, v_basket.term_no, v_term_no
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_elective_preference_validate BEFORE INSERT OR UPDATE ON academic.elective_preference
  FOR EACH ROW EXECUTE FUNCTION academic.elective_preference_validate();

-- Allot a basket's electives for a term from the submitted preferences, in
-- merit order (CGPA descending, no CGPA last, then enrollment number), giving
-- each student their highest-ranked preference that still has a seat, until the
-- basket's courses_to_choose is met. Registrations already held from the basket
-- count. Returns the number of new registrations. Safe to re-run.
CREATE OR REPLACE FUNCTION academic.allot_electives(p_basket uuid, p_term uuid)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_count int := 0; v_choose int; v_done int; r record; p record;
BEGIN
  SELECT courses_to_choose INTO v_choose FROM academic.elective_basket WHERE id = p_basket;
  IF v_choose IS NULL THEN
    RAISE EXCEPTION 'allot_electives: unknown basket %', p_basket USING ERRCODE = 'no_data_found';
  END IF;
  FOR r IN
    SELECT DISTINCT ep.student_enrollment_id, cg.cgpa, st.enrollment_no
    FROM academic.elective_preference ep
    JOIN academic.student_enrollment e ON e.id = ep.student_enrollment_id
    JOIN people.student st             ON st.id = e.student_id
    LEFT JOIN exam.v_cgpa cg           ON cg.student_enrollment_id = e.id
    WHERE ep.elective_basket_id = p_basket AND ep.academic_term_id = p_term
    ORDER BY cg.cgpa DESC NULLS LAST, st.enrollment_no
  LOOP
    SELECT count(*) INTO v_done
    FROM academic.course_registration cr
    JOIN academic.course_offering o          ON o.id = cr.course_offering_id AND o.academic_term_id = p_term
    JOIN academic.elective_basket_course ebc ON ebc.course_id = o.course_id AND ebc.elective_basket_id = p_basket
    JOIN ref.registration_status s           ON s.id = cr.registration_status_id AND s.is_counted
    WHERE cr.student_enrollment_id = r.student_enrollment_id;
    FOR p IN
      SELECT o.id AS offering_id
      FROM academic.elective_preference ep
      JOIN academic.course_offering o ON o.course_id = ep.course_id AND o.academic_term_id = p_term
      WHERE ep.student_enrollment_id = r.student_enrollment_id AND ep.elective_basket_id = p_basket AND ep.academic_term_id = p_term
      ORDER BY ep.priority
    LOOP
      EXIT WHEN v_done >= v_choose;
      BEGIN
        INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
        VALUES (r.student_enrollment_id, p.offering_id, ref.id_of('registration_status', 'REGISTERED'));
        v_done := v_done + 1; v_count := v_count + 1;
      EXCEPTION
        WHEN unique_violation THEN v_done := v_done + 1;            -- already registered for this preference
        WHEN check_violation OR exclusion_violation THEN NULL;      -- seat limit or ineligible: next preference
      END;
    END LOOP;
  END LOOP;
  RETURN v_count;
END $$;

-- ###################################################### OFFERING SEAT QUOTAS ##

-- Seats of an offering reserved as a CEILING for one group of students: those
-- of a programme, or those whose programme sits under an org unit (a school,
-- a department). "At most 20 seats of this elective for School of Engineering
-- students." The offering's intake_limit still caps the whole class, so a
-- ceiling for one group is a floor for everyone else (60 seats, at most 40 for
-- Engineering = at least 20 for the rest). A student matches the programme
-- quota first, then the nearest unit quota up the org tree; students matching
-- no quota are limited only by intake_limit.
CREATE TABLE academic.offering_seat_quota (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_offering_id  uuid NOT NULL REFERENCES academic.course_offering(id) ON DELETE CASCADE,
  program_id          uuid REFERENCES academic.program(id) ON DELETE CASCADE,
  org_unit_id         uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  max_seats           smallint NOT NULL CHECK (max_seats >= 0),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(program_id, org_unit_id) = 1),
  UNIQUE (course_offering_id, program_id),
  UNIQUE (course_offering_id, org_unit_id)
);
SELECT util.attach_updated_at('academic.offering_seat_quota');
CREATE TRIGGER trg_offering_seat_quota_academic_unit BEFORE INSERT OR UPDATE OF org_unit_id ON academic.offering_seat_quota
  FOR EACH ROW WHEN (NEW.org_unit_id IS NOT NULL) EXECUTE FUNCTION academic.require_academic_unit('org_unit_id');

-- The quota that applies to a student for an offering: their programme's
-- quota, else the nearest org-unit quota above their programme's unit.
CREATE OR REPLACE FUNCTION academic.offering_quota_for(p_offering uuid, p_enrollment uuid)
RETURNS uuid LANGUAGE plpgsql STABLE AS $$   -- plpgsql: org.ancestors() is created in 09_views_functions.sql
DECLARE v_program uuid; v_unit uuid; v_quota uuid;
BEGIN
  SELECT p.id, p.offering_org_unit_id INTO v_program, v_unit
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id JOIN academic.program p ON p.id = b.program_id
  WHERE e.id = p_enrollment;
  SELECT q.id INTO v_quota FROM academic.offering_seat_quota q
  WHERE q.course_offering_id = p_offering AND q.program_id = v_program;
  IF v_quota IS NULL THEN
    SELECT q.id INTO v_quota
    FROM org.ancestors(v_unit) a JOIN academic.offering_seat_quota q ON q.org_unit_id = a.org_unit_id
    WHERE q.course_offering_id = p_offering
    ORDER BY a.depth LIMIT 1;
  END IF;
  RETURN v_quota;
END $$;

-- Registration: the student's quota, if any, must have a seat left.
CREATE OR REPLACE FUNCTION academic.course_registration_validate_quota()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_quota uuid; v_max int; v_used int;
BEGIN
  IF NOT (SELECT is_counted FROM ref.registration_status WHERE id = NEW.registration_status_id) THEN RETURN NEW; END IF;
  v_quota := academic.offering_quota_for(NEW.course_offering_id, NEW.student_enrollment_id);
  IF v_quota IS NULL THEN RETURN NEW; END IF;
  SELECT max_seats INTO v_max FROM academic.offering_seat_quota WHERE id = v_quota;
  SELECT count(*) INTO v_used
  FROM academic.course_registration r
  JOIN ref.registration_status s ON s.id = r.registration_status_id AND s.is_counted
  WHERE r.course_offering_id = NEW.course_offering_id AND r.id <> NEW.id
    AND academic.offering_quota_for(NEW.course_offering_id, r.student_enrollment_id) = v_quota;
  IF v_used >= v_max THEN
    RAISE EXCEPTION 'course_registration: the % seat(s) of this offering for the student''s programme / school are taken', v_max
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_registration_validate_quota BEFORE INSERT OR UPDATE ON academic.course_registration
  FOR EACH ROW EXECUTE FUNCTION academic.course_registration_validate_quota();

-- ############################################# CURRICULUM CONTENT & OUTCOMES ##

-- A versioned syllabus of a course (the Board of Studies approves a new
-- version; one version is current at a time). Units, contact hours and course
-- outcomes hang off the version, so a change of syllabus never rewrites what an
-- earlier batch was taught.
CREATE TABLE academic.course_syllabus (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id                uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  version                  citext NOT NULL,                         -- 'v1', 'R2024'
  approved_by_employee_id  uuid REFERENCES people.employee(id),
  approved_on              date,
  body_resolution_id       uuid REFERENCES academic.body_resolution(id),
  valid                    daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, version),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT course_syllabus_one_current EXCLUDE USING gist (course_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('academic.course_syllabus');

CREATE TABLE academic.syllabus_unit (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_syllabus_id  uuid NOT NULL REFERENCES academic.course_syllabus(id) ON DELETE CASCADE,
  unit_no             smallint NOT NULL CHECK (unit_no >= 1),
  title               text NOT NULL CHECK (btrim(title) <> ''),
  content             text,
  contact_hours       numeric(5,1) CHECK (contact_hours >= 0),
  UNIQUE (course_syllabus_id, unit_no)
);

-- Course outcome ("CO1: apply …") with its Bloom's level.
CREATE TABLE academic.course_outcome (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_syllabus_id  uuid NOT NULL REFERENCES academic.course_syllabus(id) ON DELETE CASCADE,
  code                citext NOT NULL CHECK (code ~ '^[A-Za-z0-9_-]{1,16}$'),   -- CO1
  statement           text NOT NULL CHECK (btrim(statement) <> ''),
  bloom_level_id      smallint REFERENCES ref.bloom_level(id),
  UNIQUE (course_syllabus_id, code)
);

-- Programme outcome (PO) or programme-specific outcome (PSO) of a programme.
CREATE TABLE academic.program_outcome (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id               uuid NOT NULL REFERENCES academic.program(id) ON DELETE CASCADE,
  program_outcome_type_id  smallint NOT NULL REFERENCES ref.program_outcome_type(id),
  code                     citext NOT NULL CHECK (code ~ '^[A-Za-z0-9_-]{1,16}$'),   -- PO1, PSO2
  statement                text NOT NULL CHECK (btrim(statement) <> ''),
  is_active                boolean NOT NULL DEFAULT true,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, code)
);
SELECT util.attach_updated_at('academic.program_outcome');

-- CO ↔ PO mapping with strength 1 (low) … 3 (high); the course must be part of
-- that programme (in one of its curricula) for the mapping to mean anything.
CREATE TABLE academic.co_po_mapping (
  course_outcome_id   uuid NOT NULL REFERENCES academic.course_outcome(id) ON DELETE CASCADE,
  program_outcome_id  uuid NOT NULL REFERENCES academic.program_outcome(id) ON DELETE CASCADE,
  strength            smallint NOT NULL CHECK (strength BETWEEN 1 AND 3),
  PRIMARY KEY (course_outcome_id, program_outcome_id)
);

CREATE OR REPLACE FUNCTION academic.co_po_mapping_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_course uuid; v_program uuid;
BEGIN
  SELECT cs.course_id INTO v_course FROM academic.course_outcome co JOIN academic.course_syllabus cs ON cs.id = co.course_syllabus_id
  WHERE co.id = NEW.course_outcome_id;
  SELECT program_id INTO v_program FROM academic.program_outcome WHERE id = NEW.program_outcome_id;
  IF NOT EXISTS (SELECT 1 FROM academic.v_curriculum_item ci JOIN academic.curriculum c ON c.id = ci.curriculum_id
                 WHERE c.program_id = v_program AND ci.course_id = v_course)
     AND NOT EXISTS (SELECT 1 FROM academic.track_course tc JOIN academic.track t ON t.id = tc.track_id
                     WHERE t.program_id = v_program AND tc.course_id = v_course) THEN
    RAISE EXCEPTION 'co_po_mapping: the course is not part of that programme''s curricula' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_co_po_mapping_validate BEFORE INSERT OR UPDATE ON academic.co_po_mapping
  FOR EACH ROW EXECUTE FUNCTION academic.co_po_mapping_validate();

-- The lesson plan of one teaching assignment: ordered topics, each optionally
-- tied to a syllabus unit of the course, with planned hours.
CREATE TABLE academic.lesson_plan_item (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teaching_assignment_id  uuid NOT NULL REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE,
  seq                     smallint NOT NULL CHECK (seq >= 1),
  syllabus_unit_id        uuid REFERENCES academic.syllabus_unit(id),
  topic                   text NOT NULL CHECK (btrim(topic) <> ''),
  planned_hours           numeric(4,1) NOT NULL DEFAULT 1 CHECK (planned_hours > 0),
  planned_week            smallint CHECK (planned_week >= 1),
  UNIQUE (teaching_assignment_id, seq)
);

CREATE OR REPLACE FUNCTION academic.lesson_plan_item_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.syllabus_unit_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.syllabus_unit su
       JOIN academic.course_syllabus cs   ON cs.id = su.course_syllabus_id
       JOIN academic.teaching_assignment ta ON ta.id = NEW.teaching_assignment_id
       JOIN academic.course_offering o      ON o.id = ta.course_offering_id AND o.course_id = cs.course_id
       WHERE su.id = NEW.syllabus_unit_id) THEN
    RAISE EXCEPTION 'lesson_plan_item: the syllabus unit belongs to another course' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_lesson_plan_item_validate BEFORE INSERT OR UPDATE ON academic.lesson_plan_item
  FOR EACH ROW EXECUTE FUNCTION academic.lesson_plan_item_validate();

-- What was actually covered in a class session (the course file), optionally
-- tied to the lesson plan item it delivers.
CREATE TABLE academic.class_session_topic (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id     uuid NOT NULL REFERENCES academic.class_session(id) ON DELETE CASCADE,
  lesson_plan_item_id  uuid REFERENCES academic.lesson_plan_item(id) ON DELETE SET NULL,
  topic                text NOT NULL CHECK (btrim(topic) <> ''),
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX class_session_topic_session_idx ON academic.class_session_topic(class_session_id);

CREATE OR REPLACE FUNCTION academic.class_session_topic_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ta uuid;
BEGIN
  IF NEW.lesson_plan_item_id IS NOT NULL THEN
    SELECT COALESCE(cs.teaching_assignment_id, te.teaching_assignment_id) INTO v_ta
    FROM academic.class_session cs LEFT JOIN academic.timetable_entry te ON te.id = cs.timetable_entry_id
    WHERE cs.id = NEW.class_session_id;
    IF (SELECT teaching_assignment_id FROM academic.lesson_plan_item WHERE id = NEW.lesson_plan_item_id) <> v_ta THEN
      RAISE EXCEPTION 'class_session_topic: the lesson plan item belongs to another teaching assignment' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_class_session_topic_validate BEFORE INSERT OR UPDATE ON academic.class_session_topic
  FOR EACH ROW EXECUTE FUNCTION academic.class_session_topic_validate();

-- ######################################################### FACULTY WORKLOAD ##

-- Teaching hours per week expected of a designation (UGC norms: Professor 14,
-- Associate 14, Assistant 16 …), dated. Actual load is derived from the
-- timetable (academic.v_faculty_workload).
CREATE TABLE academic.workload_norm (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  designation_id       smallint NOT NULL REFERENCES people.designation(id),
  min_hours_per_week   numeric(4,1) CHECK (min_hours_per_week >= 0),
  max_hours_per_week   numeric(4,1) CHECK (max_hours_per_week >= 0),
  valid                daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(min_hours_per_week, max_hours_per_week) >= 1),
  CHECK (min_hours_per_week IS NULL OR max_hours_per_week IS NULL OR min_hours_per_week <= max_hours_per_week),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT workload_norm_one_at_a_time EXCLUDE USING gist (designation_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('academic.workload_norm');

-- ########################################################### DIVISION / CLASS ##

-- Division (class) awarded on a grade scale by CGPA range: First class with
-- distinction, First, Second, Pass … Read by exam.v_division.
CREATE TABLE academic.division_band (
  id              int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  grade_scale_id  smallint NOT NULL REFERENCES academic.grade_scale(id) ON DELETE CASCADE,
  code            citext NOT NULL,
  label           text NOT NULL,
  cgpa_range      numrange NOT NULL,
  UNIQUE (grade_scale_id, code),
  CHECK (NOT isempty(cgpa_range) AND lower(cgpa_range) >= 0),
  CONSTRAINT division_band_no_overlap EXCLUDE USING gist (grade_scale_id WITH =, cgpa_range WITH &&)
);

-- ########################################################## STUDENT FEEDBACK ##

-- A reusable questionnaire and its questions (rating on a 1..max scale, or free text).
CREATE TABLE academic.feedback_questionnaire (
  id          smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code        citext NOT NULL UNIQUE,
  name        text NOT NULL,
  max_rating  smallint NOT NULL DEFAULT 5 CHECK (max_rating BETWEEN 2 AND 10),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('academic.feedback_questionnaire');

CREATE TABLE academic.feedback_question (
  id                         int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  feedback_questionnaire_id  smallint NOT NULL REFERENCES academic.feedback_questionnaire(id) ON DELETE CASCADE,
  seq                        smallint NOT NULL CHECK (seq >= 1),
  question                   text NOT NULL CHECK (btrim(question) <> ''),
  is_free_text               boolean NOT NULL DEFAULT false,
  UNIQUE (feedback_questionnaire_id, seq)
);

-- A feedback round: one questionnaire, one term, a submission window.
CREATE TABLE academic.feedback_cycle (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_term_id           uuid NOT NULL REFERENCES academic.academic_term(id),
  feedback_questionnaire_id  smallint NOT NULL REFERENCES academic.feedback_questionnaire(id),
  name                       text NOT NULL,
  submission_window          tstzrange NOT NULL,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_term_id, name),
  CHECK (NOT isempty(submission_window) AND NOT lower_inf(submission_window) AND NOT upper_inf(submission_window))
);
SELECT util.attach_updated_at('academic.feedback_cycle');

-- The only place a student is linked to feedback: proof that this course
-- registration has submitted in this cycle (one submission each). It is never
-- joined to the responses, so feedback stays anonymous by construction.
CREATE TABLE academic.feedback_submission (
  feedback_cycle_id       uuid NOT NULL REFERENCES academic.feedback_cycle(id) ON DELETE CASCADE,
  course_registration_id  uuid NOT NULL REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  submitted_at            timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (feedback_cycle_id, course_registration_id)
);

CREATE OR REPLACE FUNCTION academic.feedback_submission_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cycle record;
BEGIN
  SELECT academic_term_id, submission_window INTO v_cycle FROM academic.feedback_cycle WHERE id = NEW.feedback_cycle_id;
  IF NOT (v_cycle.submission_window @> NEW.submitted_at) THEN
    RAISE EXCEPTION 'feedback_submission: outside the feedback window %', v_cycle.submission_window USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT o.academic_term_id FROM academic.course_registration r JOIN academic.course_offering o ON o.id = r.course_offering_id
      WHERE r.id = NEW.course_registration_id) <> v_cycle.academic_term_id THEN
    RAISE EXCEPTION 'feedback_submission: the registration is not in the cycle''s term' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_feedback_submission_validate BEFORE INSERT OR UPDATE ON academic.feedback_submission
  FOR EACH ROW EXECUTE FUNCTION academic.feedback_submission_validate();

-- One answer: cycle × teaching assignment (the class and teacher being rated)
-- × question. A rating for rating questions, a comment for free-text ones.
-- Deliberately no student column.
CREATE TABLE academic.feedback_response (
  id                      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  feedback_cycle_id       uuid NOT NULL REFERENCES academic.feedback_cycle(id) ON DELETE CASCADE,
  teaching_assignment_id  uuid NOT NULL REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE,
  feedback_question_id    int NOT NULL REFERENCES academic.feedback_question(id),
  rating                  smallint CHECK (rating >= 1),
  comment                 text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(rating, comment) = 1)
);
CREATE INDEX feedback_response_ta_idx ON academic.feedback_response(feedback_cycle_id, teaching_assignment_id);

CREATE OR REPLACE FUNCTION academic.feedback_response_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cycle record; v_q record; v_ta_term uuid;
BEGIN
  SELECT c.academic_term_id, c.feedback_questionnaire_id, q.max_rating INTO v_cycle
  FROM academic.feedback_cycle c JOIN academic.feedback_questionnaire q ON q.id = c.feedback_questionnaire_id
  WHERE c.id = NEW.feedback_cycle_id;
  SELECT feedback_questionnaire_id, is_free_text INTO v_q FROM academic.feedback_question WHERE id = NEW.feedback_question_id;
  IF v_q.feedback_questionnaire_id <> v_cycle.feedback_questionnaire_id THEN
    RAISE EXCEPTION 'feedback_response: the question is not in this cycle''s questionnaire' USING ERRCODE = 'check_violation';
  END IF;
  IF v_q.is_free_text <> (NEW.comment IS NOT NULL) THEN
    RAISE EXCEPTION 'feedback_response: a free-text question takes a comment, a rating question a rating' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.rating IS NOT NULL AND NEW.rating > v_cycle.max_rating THEN
    RAISE EXCEPTION 'feedback_response: rating % above the questionnaire maximum %', NEW.rating, v_cycle.max_rating USING ERRCODE = 'check_violation';
  END IF;
  SELECT o.academic_term_id INTO v_ta_term
  FROM academic.teaching_assignment ta JOIN academic.course_offering o ON o.id = ta.course_offering_id WHERE ta.id = NEW.teaching_assignment_id;
  IF v_ta_term <> v_cycle.academic_term_id THEN
    RAISE EXCEPTION 'feedback_response: the teaching assignment is not in the cycle''s term' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_feedback_response_validate BEFORE INSERT OR UPDATE ON academic.feedback_response
  FOR EACH ROW EXECUTE FUNCTION academic.feedback_response_validate();
