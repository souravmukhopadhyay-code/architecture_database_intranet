-- =============================================================================
-- 04b_exam.sql — Examination: scheme → eligibility → registration → planning
--                → conduct → evaluation → results → post-result (schema: exam)
--
-- The SCHEME of examination itself (evaluation_scheme / evaluation_component)
-- and the GRADE SCALE live in `academic` (they are academic regulations,
-- attached to the curriculum). This schema is the exam cell's operational
-- record, kept separate as a security boundary: marks, answer-script codes and
-- unfair-means cases are among the most sensitive data a university holds.
--
--   1. ELIGIBILITY & REGISTRATION
--      exam_session (per term: mid-term / end-term / supplementary)
--      eligibility_hold, attendance_condonation   → exam.is_eligible()  [09]
--      exam_registration  (course_registration × session × attempt type:
--                          regular / backlog / improvement / supplementary)
--   2. PLANNING & CONDUCT
--      exam_schedule (date sheet — DB rejects a student's clashing papers)
--      exam_room ─< seat_allocation, invigilation_duty
--      examiner_panel (internal + external examiners of a practical / viva)
--      exam_attendance, ufm_case (unfair means)
--      hall ticket = derived view exam.v_hall_ticket                      [09]
--   3. EVALUATION & RESULTS
--      answer_script (anonymous dummy code) ─< evaluator_assignment ─< script_mark
--      component_mark (internals / practicals / viva — non-script components)
--      grace_policy ─< grace_award, result_moderation (board adjustment per course)
--      result_publication ─< course_result (frozen once published)
--      marksheet (issued document register); SGPA / CGPA derived          [09]
--   4. POST-RESULT
--      revaluation_request → a new evaluation round → a REVISED publication
--      supplementary = an exam_session of type SUPPLEMENTARY + attempt type
--   5. QUESTION PAPERS, ATTEMPT LIMIT, CERTIFICATES & CONVOCATION
--      see 04f_exam_papers_certificates.sql (paper_setter_assignment, question_paper,
--      convocation, certificate; curriculum.max_attempts_per_course enforced)
--
-- Derived logic (eligibility, attendance %, effective marks, clash checks,
-- SGPA/CGPA, hall tickets) lives in 09_views_functions.sql; the triggers here
-- call those functions at run time.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = exam, academic, people, org, ref, public;

-- #############################################################################
-- 1. ELIGIBILITY & REGISTRATION
-- #############################################################################

CREATE TABLE exam.exam_session (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_term_id      uuid NOT NULL REFERENCES academic.academic_term(id),
  exam_session_type_id  smallint NOT NULL REFERENCES ref.exam_session_type(id),
  name                  text NOT NULL,                 -- "End-Term Examination, Dec 2026"
  period                daterange NOT NULL,            -- exam days
  registration_window   daterange,                     -- when students/admins may register
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_term_id, name),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period))
);
SELECT util.attach_updated_at('exam.exam_session');

-- A hold blocks exam eligibility (disciplinary, fee dues flagged by Finance,
-- administrative). course_offering_id NULL = every course that term.
CREATE TABLE exam.eligibility_hold (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id                uuid NOT NULL REFERENCES people.student(id) ON DELETE CASCADE,
  academic_term_id          uuid NOT NULL REFERENCES academic.academic_term(id),
  course_offering_id        uuid REFERENCES academic.course_offering(id),
  exam_hold_type_id         smallint NOT NULL REFERENCES ref.exam_hold_type(id),
  reason                    text NOT NULL,
  placed_by_employee_id     uuid REFERENCES people.employee(id),
  placed_at                 timestamptz NOT NULL DEFAULT now(),
  released_at               timestamptz,
  released_by_employee_id   uuid REFERENCES people.employee(id),
  CHECK (released_at IS NULL OR released_at >= placed_at),
  CHECK ((released_at IS NULL) = (released_by_employee_id IS NULL))
);
CREATE INDEX eligibility_hold_student_idx ON exam.eligibility_hold(student_id, academic_term_id);

-- An approved exception for an attendance shortage (medical, sports, NCC …).
CREATE TABLE exam.attendance_condonation (
  course_registration_id   uuid PRIMARY KEY REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  reason                   text NOT NULL,
  approved_at              timestamptz NOT NULL DEFAULT now()
);

-- A student sitting a course's exams in a session, as a given attempt type.
-- Backlog / improvement / supplementary attempts reference the ORIGINAL course
-- registration (from an earlier term) — the attempt number is derived.
CREATE TABLE exam.exam_registration (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id         uuid NOT NULL REFERENCES exam.exam_session(id),
  course_registration_id  uuid NOT NULL REFERENCES academic.course_registration(id),
  exam_attempt_type_id    smallint NOT NULL REFERENCES ref.exam_attempt_type(id),
  registered_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exam_session_id, course_registration_id)
);
CREATE INDEX exam_registration_course_reg_idx ON exam.exam_registration(course_registration_id);

CREATE OR REPLACE FUNCTION exam.exam_registration_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_attempt text; v_needs_eligibility boolean; v_offering_term date; v_session_term date;
BEGIN
  SELECT code, requires_eligibility INTO v_attempt, v_needs_eligibility
  FROM ref.exam_attempt_type WHERE id = NEW.exam_attempt_type_id;

  SELECT lower(t.period) INTO v_offering_term
  FROM academic.course_registration r
  JOIN academic.course_offering o ON o.id = r.course_offering_id
  JOIN academic.academic_term t ON t.id = o.academic_term_id
  WHERE r.id = NEW.course_registration_id;
  SELECT lower(t.period) INTO v_session_term
  FROM exam.exam_session s JOIN academic.academic_term t ON t.id = s.academic_term_id
  WHERE s.id = NEW.exam_session_id;

  IF v_attempt = 'REGULAR' AND v_offering_term <> v_session_term THEN
    RAISE EXCEPTION 'exam_registration: a REGULAR attempt must be in the course''s own term' USING ERRCODE = 'check_violation';
  ELSIF v_attempt <> 'REGULAR' AND v_offering_term > v_session_term THEN
    RAISE EXCEPTION 'exam_registration: cannot re-attempt a course before it was taught' USING ERRCODE = 'check_violation';
  END IF;
  IF v_needs_eligibility AND NOT exam.is_eligible(NEW.course_registration_id) THEN
    RAISE EXCEPTION 'exam_registration: student is not eligible (attendance shortage or an active hold)'
      USING ERRCODE = 'check_violation';
  END IF;
  IF exam.registration_has_clash(NEW.course_registration_id, NEW.exam_session_id) THEN
    RAISE EXCEPTION 'exam_registration: this paper clashes with another paper the student is sitting'
      USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_registration_validate BEFORE INSERT OR UPDATE ON exam.exam_registration
  FOR EACH ROW EXECUTE FUNCTION exam.exam_registration_validate();

-- #############################################################################
-- 2. PLANNING & CONDUCT
-- #############################################################################

-- The date sheet: one row per (session, course offering, scheduled component).
CREATE TABLE exam.exam_schedule (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id     uuid NOT NULL REFERENCES exam.exam_session(id) ON DELETE CASCADE,
  course_offering_id  uuid NOT NULL REFERENCES academic.course_offering(id),
  assessment_type_id  smallint NOT NULL REFERENCES ref.assessment_type(id),
  exam_date           date NOT NULL,
  start_time          time NOT NULL,
  end_time            time NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (end_time > start_time),
  UNIQUE (exam_session_id, course_offering_id, assessment_type_id)
);
CREATE INDEX exam_schedule_date_idx ON exam.exam_schedule(exam_date);
SELECT util.attach_updated_at('exam.exam_schedule');

CREATE OR REPLACE FUNCTION exam.exam_schedule_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT (SELECT is_scheduled_exam FROM ref.assessment_type WHERE id = NEW.assessment_type_id) THEN
    RAISE EXCEPTION 'exam_schedule: this assessment type is continuous evaluation, not a scheduled exam'
      USING ERRCODE = 'check_violation';
  END IF;
  IF NOT ((SELECT period FROM exam.exam_session WHERE id = NEW.exam_session_id) @> NEW.exam_date) THEN
    RAISE EXCEPTION 'exam_schedule: % is outside the exam session', NEW.exam_date USING ERRCODE = 'check_violation';
  END IF;
  IF exam.schedule_has_clash(NEW.id, NEW.exam_session_id, NEW.course_offering_id,
                              NEW.exam_date, NEW.start_time, NEW.end_time) THEN
    RAISE EXCEPTION 'exam_schedule: a student sitting this paper has another paper at the same time'
      USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_schedule_validate BEFORE INSERT OR UPDATE ON exam.exam_schedule
  FOR EACH ROW EXECUTE FUNCTION exam.exam_schedule_validate();

-- Rooms used for a paper (a large hall can host several concurrent papers).
CREATE TABLE exam.exam_room (
  exam_schedule_id  uuid NOT NULL REFERENCES exam.exam_schedule(id) ON DELETE CASCADE,
  room_id           uuid NOT NULL REFERENCES org.room(id),
  PRIMARY KEY (exam_schedule_id, room_id)
);

CREATE OR REPLACE FUNCTION exam.exam_room_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT exam_capacity FROM org.room WHERE id = NEW.room_id) IS NULL THEN
    RAISE EXCEPTION 'exam_room: room is not set up as an exam venue (no exam_capacity)' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_room_validate BEFORE INSERT OR UPDATE ON exam.exam_room
  FOR EACH ROW EXECUTE FUNCTION exam.exam_room_validate();

-- Seating plan. The seat must be free across every paper sitting in that
-- room at that time, and the room's exam capacity is never exceeded.
CREATE TABLE exam.seat_allocation (
  exam_schedule_id      uuid NOT NULL,
  exam_registration_id  uuid NOT NULL REFERENCES exam.exam_registration(id) ON DELETE CASCADE,
  room_id               uuid NOT NULL,
  seat_no               citext NOT NULL,
  PRIMARY KEY (exam_schedule_id, exam_registration_id),
  FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION exam.registration_matches_schedule(p_exam_registration uuid, p_exam_schedule uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM exam.exam_registration er
    JOIN academic.course_registration r ON r.id = er.course_registration_id
    JOIN exam.exam_schedule s ON s.id = p_exam_schedule
    WHERE er.id = p_exam_registration
      AND er.exam_session_id = s.exam_session_id
      AND r.course_offering_id = s.course_offering_id);
$$;

CREATE OR REPLACE FUNCTION exam.seat_allocation_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_date date; v_start time; v_end time; v_capacity smallint;
BEGIN
  IF NOT exam.registration_matches_schedule(NEW.exam_registration_id, NEW.exam_schedule_id) THEN
    RAISE EXCEPTION 'seat_allocation: student is not registered for this paper' USING ERRCODE = 'check_violation';
  END IF;
  SELECT exam_date, start_time, end_time INTO v_date, v_start, v_end FROM exam.exam_schedule WHERE id = NEW.exam_schedule_id;
  SELECT exam_capacity INTO v_capacity FROM org.room WHERE id = NEW.room_id;

  IF EXISTS (SELECT 1 FROM exam.seat_allocation sa JOIN exam.exam_schedule s ON s.id = sa.exam_schedule_id
             WHERE sa.room_id = NEW.room_id AND sa.seat_no = NEW.seat_no
               AND s.exam_date = v_date AND s.start_time < v_end AND v_start < s.end_time
               AND NOT (sa.exam_schedule_id = NEW.exam_schedule_id AND sa.exam_registration_id = NEW.exam_registration_id)) THEN
    RAISE EXCEPTION 'seat_allocation: seat % in this room is already taken at this time', NEW.seat_no USING ERRCODE = 'unique_violation';
  END IF;
  IF (SELECT count(*) FROM exam.seat_allocation sa JOIN exam.exam_schedule s ON s.id = sa.exam_schedule_id
      WHERE sa.room_id = NEW.room_id AND s.exam_date = v_date AND s.start_time < v_end AND v_start < s.end_time
        AND NOT (sa.exam_schedule_id = NEW.exam_schedule_id AND sa.exam_registration_id = NEW.exam_registration_id))
     >= v_capacity THEN
    RAISE EXCEPTION 'seat_allocation: room exam capacity (%) is full at this time', v_capacity USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_seat_allocation_validate BEFORE INSERT OR UPDATE ON exam.seat_allocation
  FOR EACH ROW EXECUTE FUNCTION exam.seat_allocation_validate();

-- Invigilator duty in a room for a paper; one chief invigilator per room and
-- paper; nobody is on duty in two different rooms at overlapping times.
CREATE TABLE exam.invigilation_duty (
  exam_schedule_id  uuid NOT NULL,
  room_id           uuid NOT NULL,
  employee_id       uuid NOT NULL REFERENCES people.employee(id),
  is_chief          boolean NOT NULL DEFAULT false,
  PRIMARY KEY (exam_schedule_id, room_id, employee_id),
  FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX invigilation_one_chief_uq ON exam.invigilation_duty(exam_schedule_id, room_id) WHERE is_chief;

CREATE OR REPLACE FUNCTION exam.invigilation_duty_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_date date; v_start time; v_end time;
BEGIN
  SELECT exam_date, start_time, end_time INTO v_date, v_start, v_end FROM exam.exam_schedule WHERE id = NEW.exam_schedule_id;
  IF EXISTS (SELECT 1 FROM exam.invigilation_duty d JOIN exam.exam_schedule s ON s.id = d.exam_schedule_id
             WHERE d.employee_id = NEW.employee_id AND d.room_id <> NEW.room_id
               AND s.exam_date = v_date AND s.start_time < v_end AND v_start < s.end_time) THEN
    RAISE EXCEPTION 'invigilation_duty: invigilator already has duty in another room at this time'
      USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_invigilation_duty_validate BEFORE INSERT OR UPDATE ON exam.invigilation_duty
  FOR EACH ROW EXECUTE FUNCTION exam.invigilation_duty_validate();

-- The examiners of a DIRECTLY-MARKED scheduled paper — an end-term practical
-- (ETP), a dissertation / internship viva — where marks come from the panel,
-- not from anonymous answer scripts. Internal examiner = an employee;
-- external examiner = a person from outside (no employee record), as for
-- thesis examiners. The panel's internal members enter the marks
-- (exam.component_mark); an assessment type that requires an external
-- examiner accepts no marks until one is on the panel.
CREATE TABLE exam.examiner_panel (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_schedule_id          uuid NOT NULL REFERENCES exam.exam_schedule(id) ON DELETE CASCADE,
  examiner_role_id          smallint NOT NULL REFERENCES ref.examiner_role(id),
  employee_id               uuid REFERENCES people.employee(id),
  external_person_id        uuid REFERENCES people.person(id),
  appointed_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  UNIQUE (exam_schedule_id, employee_id),
  UNIQUE (exam_schedule_id, external_person_id)
);
CREATE INDEX examiner_panel_employee_idx ON exam.examiner_panel(employee_id);

CREATE OR REPLACE FUNCTION exam.examiner_panel_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_external boolean;
BEGIN
  IF (SELECT t.uses_answer_scripts FROM exam.exam_schedule s JOIN ref.assessment_type t ON t.id = s.assessment_type_id
      WHERE s.id = NEW.exam_schedule_id) THEN
    RAISE EXCEPTION 'examiner_panel: this paper is marked through anonymous answer scripts, not by a panel' USING ERRCODE = 'check_violation';
  END IF;
  SELECT is_external INTO v_external FROM ref.examiner_role WHERE id = NEW.examiner_role_id;
  IF v_external AND (NEW.employee_id IS NOT NULL
                     OR EXISTS (SELECT 1 FROM people.employee WHERE person_id = NEW.external_person_id)) THEN
    RAISE EXCEPTION 'examiner_panel: an external examiner cannot be an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_external AND NEW.employee_id IS NULL THEN
    RAISE EXCEPTION 'examiner_panel: an internal examiner must be an employee' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_examiner_panel_validate BEFORE INSERT OR UPDATE ON exam.examiner_panel
  FOR EACH ROW EXECUTE FUNCTION exam.examiner_panel_validate();

-- Present / absent / booked for unfair means, per student per paper.
CREATE TABLE exam.exam_attendance (
  exam_schedule_id           uuid NOT NULL REFERENCES exam.exam_schedule(id) ON DELETE CASCADE,
  exam_registration_id       uuid NOT NULL REFERENCES exam.exam_registration(id) ON DELETE CASCADE,
  exam_attendance_status_id  smallint NOT NULL REFERENCES ref.exam_attendance_status(id),
  marked_by_employee_id      uuid REFERENCES people.employee(id),
  marked_at                  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (exam_schedule_id, exam_registration_id)
);

-- Unfair-means (malpractice) case: reported in the hall, decided by a committee.
CREATE TABLE exam.ufm_case (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_schedule_id         uuid NOT NULL REFERENCES exam.exam_schedule(id),
  exam_registration_id     uuid NOT NULL REFERENCES exam.exam_registration(id),
  reported_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  reported_at              timestamptz NOT NULL DEFAULT now(),
  description              text NOT NULL,
  ufm_case_status_id       smallint NOT NULL REFERENCES ref.ufm_case_status(id),
  ufm_penalty_id           smallint REFERENCES ref.ufm_penalty(id),
  decided_by_employee_id   uuid REFERENCES people.employee(id),
  decided_at               timestamptz,
  CHECK ((decided_at IS NULL) = (decided_by_employee_id IS NULL)),
  CHECK (ufm_penalty_id IS NULL OR decided_at IS NOT NULL)
);
CREATE INDEX ufm_case_registration_idx ON exam.ufm_case(exam_registration_id);

CREATE OR REPLACE FUNCTION exam.schedule_registration_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT exam.registration_matches_schedule(NEW.exam_registration_id, NEW.exam_schedule_id) THEN
    RAISE EXCEPTION '%: student is not registered for this paper', TG_TABLE_NAME USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_attendance_validate BEFORE INSERT OR UPDATE ON exam.exam_attendance
  FOR EACH ROW EXECUTE FUNCTION exam.schedule_registration_validate();
CREATE TRIGGER trg_ufm_case_validate BEFORE INSERT OR UPDATE ON exam.ufm_case
  FOR EACH ROW EXECUTE FUNCTION exam.schedule_registration_validate();

-- #############################################################################
-- 3. EVALUATION & RESULTS
-- #############################################################################

-- A written answer script, identified to evaluators only by a random dummy
-- code. The code ↔ student link lives here and nowhere else, and this table is
-- withheld from analytics. A script exists only if the student was not absent.
CREATE TABLE exam.answer_script (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_schedule_id      uuid NOT NULL REFERENCES exam.exam_schedule(id),
  exam_registration_id  uuid NOT NULL REFERENCES exam.exam_registration(id),
  dummy_code            citext NOT NULL UNIQUE,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exam_schedule_id, exam_registration_id)
);

CREATE OR REPLACE FUNCTION exam.answer_script_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT (SELECT t.uses_answer_scripts FROM exam.exam_schedule s JOIN ref.assessment_type t ON t.id = s.assessment_type_id
          WHERE s.id = NEW.exam_schedule_id) THEN
    RAISE EXCEPTION 'answer_script: this paper is marked directly by its examiner panel' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT exam.registration_matches_schedule(NEW.exam_registration_id, NEW.exam_schedule_id) THEN
    RAISE EXCEPTION 'answer_script: student is not registered for this paper' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM exam.exam_attendance a JOIN ref.exam_attendance_status st ON st.id = a.exam_attendance_status_id
                 WHERE a.exam_schedule_id = NEW.exam_schedule_id AND a.exam_registration_id = NEW.exam_registration_id
                   AND st.code <> 'ABSENT') THEN
    RAISE EXCEPTION 'answer_script: the student was not marked present for this paper' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_answer_script_validate BEFORE INSERT OR UPDATE ON exam.answer_script
  FOR EACH ROW EXECUTE FUNCTION exam.answer_script_validate();

-- Who evaluates a script in each round (first evaluation, moderation,
-- revaluation). A later round must go to a different evaluator.
CREATE TABLE exam.evaluator_assignment (
  answer_script_id     uuid NOT NULL REFERENCES exam.answer_script(id) ON DELETE CASCADE,
  evaluation_round_id  smallint NOT NULL REFERENCES ref.evaluation_round(id),
  employee_id          uuid NOT NULL REFERENCES people.employee(id),
  assigned_at          timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (answer_script_id, evaluation_round_id)
);
CREATE INDEX evaluator_assignment_employee_idx ON exam.evaluator_assignment(employee_id);

CREATE OR REPLACE FUNCTION exam.evaluator_assignment_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM exam.evaluator_assignment
             WHERE answer_script_id = NEW.answer_script_id AND employee_id = NEW.employee_id
               AND evaluation_round_id <> NEW.evaluation_round_id) THEN
    RAISE EXCEPTION 'evaluator_assignment: the same evaluator cannot evaluate a script in two rounds'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_evaluator_assignment_validate BEFORE INSERT OR UPDATE ON exam.evaluator_assignment
  FOR EACH ROW EXECUTE FUNCTION exam.evaluator_assignment_validate();

-- The marks an evaluator gave a script in a round. Only an assigned round can
-- carry a mark (composite FK); the mark that counts is the highest-precedence
-- round present (exam.v_effective_script_mark) — never overwritten in place.
CREATE TABLE exam.script_mark (
  answer_script_id     uuid NOT NULL,
  evaluation_round_id  smallint NOT NULL,
  marks                numeric(6,2) NOT NULL CHECK (marks >= 0),
  note                 text,                          -- moderation / revaluation remark
  entered_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (answer_script_id, evaluation_round_id),
  FOREIGN KEY (answer_script_id, evaluation_round_id)
    REFERENCES exam.evaluator_assignment(answer_script_id, evaluation_round_id)
);

-- Marks for components that are not answer scripts: internals, assignments,
-- quizzes, practicals, viva. exam_registration_id = the attempt the mark
-- belongs to (NULL for continuous internal marks carried across attempts).
CREATE TABLE exam.component_mark (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_registration_id   uuid NOT NULL REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  evaluation_component_id  int  NOT NULL REFERENCES academic.evaluation_component(id),
  exam_registration_id     uuid REFERENCES exam.exam_registration(id),
  marks                    numeric(6,2) CHECK (marks >= 0),
  is_absent                boolean NOT NULL DEFAULT false,
  entered_by_employee_id   uuid NOT NULL REFERENCES people.employee(id),
  entered_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (is_absent = (marks IS NULL)),
  CONSTRAINT component_mark_once UNIQUE NULLS NOT DISTINCT (course_registration_id, evaluation_component_id, exam_registration_id)
);

CREATE OR REPLACE FUNCTION exam.component_mark_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_scheme int; v_max numeric; v_scheduled boolean; v_scripts boolean; v_needs_external boolean;
        v_comp_scheme int; v_type smallint; v_schedule uuid;
BEGIN
  v_scheme := academic.registration_scheme_id(NEW.course_registration_id);
  SELECT c.evaluation_scheme_id, c.max_marks, t.is_scheduled_exam, t.uses_answer_scripts, t.requires_external_examiner, t.id
    INTO v_comp_scheme, v_max, v_scheduled, v_scripts, v_needs_external, v_type
  FROM academic.evaluation_component c JOIN ref.assessment_type t ON t.id = c.assessment_type_id
  WHERE c.id = NEW.evaluation_component_id;

  IF v_comp_scheme IS DISTINCT FROM v_scheme THEN
    RAISE EXCEPTION 'component_mark: component is not part of this course''s scheme of examination' USING ERRCODE = 'check_violation';
  END IF;
  IF v_scripts THEN
    RAISE EXCEPTION 'component_mark: scheduled-exam marks come from answer scripts, not direct entry' USING ERRCODE = 'check_violation';
  END IF;
  -- a scheduled but directly-marked paper (practical exam, viva): marks belong
  -- to one attempt, are entered by an internal member of that paper's panel,
  -- and need an external examiner on the panel when the type requires one
  IF v_scheduled THEN
    IF NEW.exam_registration_id IS NULL THEN
      RAISE EXCEPTION 'component_mark: marks of a scheduled practical / viva belong to an exam attempt' USING ERRCODE = 'check_violation';
    END IF;
    SELECT s.id INTO v_schedule
    FROM exam.exam_registration er
    JOIN academic.course_registration r ON r.id = er.course_registration_id
    JOIN exam.exam_schedule s ON s.exam_session_id = er.exam_session_id AND s.course_offering_id = r.course_offering_id
                             AND s.assessment_type_id = v_type
    WHERE er.id = NEW.exam_registration_id;
    IF v_schedule IS NULL THEN
      RAISE EXCEPTION 'component_mark: this practical / viva is not on the date sheet of the attempt''s session' USING ERRCODE = 'check_violation';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM exam.examiner_panel ep WHERE ep.exam_schedule_id = v_schedule
                     AND ep.employee_id = NEW.entered_by_employee_id) THEN
      RAISE EXCEPTION 'component_mark: only an examiner on this paper''s panel may enter its marks' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF v_needs_external AND NOT EXISTS (SELECT 1 FROM exam.examiner_panel ep JOIN ref.examiner_role er ON er.id = ep.examiner_role_id
                                        WHERE ep.exam_schedule_id = v_schedule AND er.is_external) THEN
      RAISE EXCEPTION 'component_mark: this paper needs an external examiner on its panel before marks are entered' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.marks > v_max THEN
    RAISE EXCEPTION 'component_mark: % exceeds the maximum of %', NEW.marks, v_max USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.exam_registration_id IS NOT NULL AND
     (SELECT course_registration_id FROM exam.exam_registration WHERE id = NEW.exam_registration_id) <> NEW.course_registration_id THEN
    RAISE EXCEPTION 'component_mark: exam attempt belongs to a different course registration' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_component_mark_validate BEFORE INSERT OR UPDATE ON exam.component_mark
  FOR EACH ROW EXECUTE FUNCTION exam.component_mark_validate();

CREATE OR REPLACE FUNCTION exam.script_mark_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_max numeric;
BEGIN
  SELECT c.max_marks INTO v_max
  FROM exam.answer_script a
  JOIN exam.exam_schedule s ON s.id = a.exam_schedule_id
  JOIN exam.exam_registration er ON er.id = a.exam_registration_id
  JOIN academic.evaluation_component c
    ON c.evaluation_scheme_id = academic.registration_scheme_id(er.course_registration_id)
   AND c.assessment_type_id = s.assessment_type_id
  WHERE a.id = NEW.answer_script_id;
  IF v_max IS NULL THEN
    RAISE EXCEPTION 'script_mark: the course''s scheme has no component for this paper' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.marks > v_max THEN
    RAISE EXCEPTION 'script_mark: % exceeds the maximum of %', NEW.marks, v_max USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_script_mark_validate BEFORE INSERT OR UPDATE ON exam.script_mark
  FOR EACH ROW EXECUTE FUNCTION exam.script_mark_validate();

-- Once a result is published, the marks behind it are locked. Corrections go
-- through revaluation (a NEW evaluation round) and a revised publication.
CREATE OR REPLACE FUNCTION exam.lock_published_marks()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_locked boolean;
BEGIN
  IF TG_TABLE_NAME = 'script_mark' THEN
    SELECT EXISTS (SELECT 1 FROM exam.answer_script a JOIN exam.course_result cr ON cr.exam_registration_id = a.exam_registration_id
                   WHERE a.id = OLD.answer_script_id) INTO v_locked;
  ELSE
    SELECT EXISTS (SELECT 1 FROM exam.exam_registration er JOIN exam.course_result cr ON cr.exam_registration_id = er.id
                   WHERE er.course_registration_id = OLD.course_registration_id
                     AND (OLD.exam_registration_id IS NULL OR er.id = OLD.exam_registration_id)) INTO v_locked;
  END IF;
  IF v_locked THEN
    RAISE EXCEPTION '%: marks are locked — a result based on them has been published; use revaluation', TG_TABLE_NAME
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER trg_script_mark_lock BEFORE UPDATE OR DELETE ON exam.script_mark
  FOR EACH ROW EXECUTE FUNCTION exam.lock_published_marks();
CREATE TRIGGER trg_component_mark_lock BEFORE UPDATE OR DELETE ON exam.component_mark
  FOR EACH ROW EXECUTE FUNCTION exam.lock_published_marks();

-- Grace-marks policy (e.g. "up to 5 marks in at most 2 courses per session").
CREATE TABLE exam.grace_policy (
  id                       smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code                     citext NOT NULL UNIQUE,
  name                     text NOT NULL,
  max_marks_per_course     numeric(5,2) NOT NULL CHECK (max_marks_per_course > 0),
  max_courses_per_session  smallint NOT NULL CHECK (max_courses_per_session > 0),
  is_active                boolean NOT NULL DEFAULT true
);

CREATE TABLE exam.grace_award (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_registration_id     uuid NOT NULL UNIQUE REFERENCES exam.exam_registration(id) ON DELETE CASCADE,
  grace_policy_id          smallint NOT NULL REFERENCES exam.grace_policy(id),
  marks                    numeric(5,2) NOT NULL CHECK (marks > 0),
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_at              timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION exam.grace_award_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_max_marks numeric; v_max_courses smallint; v_session uuid; v_enrollment uuid;
BEGIN
  SELECT max_marks_per_course, max_courses_per_session INTO v_max_marks, v_max_courses
  FROM exam.grace_policy WHERE id = NEW.grace_policy_id;
  IF NEW.marks > v_max_marks THEN
    RAISE EXCEPTION 'grace_award: % exceeds the policy limit of % per course', NEW.marks, v_max_marks USING ERRCODE = 'check_violation';
  END IF;
  SELECT er.exam_session_id, r.student_enrollment_id INTO v_session, v_enrollment
  FROM exam.exam_registration er JOIN academic.course_registration r ON r.id = er.course_registration_id
  WHERE er.id = NEW.exam_registration_id;
  IF (SELECT count(*) FROM exam.grace_award g
      JOIN exam.exam_registration er ON er.id = g.exam_registration_id
      JOIN academic.course_registration r ON r.id = er.course_registration_id
      WHERE er.exam_session_id = v_session AND r.student_enrollment_id = v_enrollment AND g.id <> NEW.id)
     >= v_max_courses THEN
    RAISE EXCEPTION 'grace_award: student already has grace in % course(s) this session', v_max_courses USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_grace_award_validate BEFORE INSERT OR UPDATE ON exam.grace_award
  FOR EACH ROW EXECUTE FUNCTION exam.grace_award_validate();

-- Result moderation decided by the examination board for one course in one
-- session: add_pct percentage points added to (or, if negative, taken from)
-- every attempt's total before rounding, capped to 0..100. Recorded as data
-- with its reason and approver, applied by exam.v_provisional_result, and
-- frozen once any result of that course in that session is published.
CREATE TABLE exam.result_moderation (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id          uuid NOT NULL REFERENCES exam.exam_session(id),
  course_offering_id       uuid NOT NULL REFERENCES academic.course_offering(id),
  add_pct                  numeric(5,2) NOT NULL CHECK (add_pct <> 0 AND add_pct BETWEEN -20 AND 20),
  reason                   text NOT NULL,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exam_session_id, course_offering_id)
);

CREATE OR REPLACE FUNCTION exam.result_moderation_lock()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_row exam.result_moderation := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
BEGIN
  IF EXISTS (SELECT 1 FROM exam.course_result cr
             JOIN exam.exam_registration er      ON er.id = cr.exam_registration_id
             JOIN academic.course_registration r ON r.id = er.course_registration_id
             WHERE er.exam_session_id = v_row.exam_session_id AND r.course_offering_id = v_row.course_offering_id) THEN
    RAISE EXCEPTION 'result_moderation: results of this course in this session are already published' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN v_row;
END $$;
CREATE TRIGGER trg_result_moderation_lock BEFORE INSERT OR UPDATE OR DELETE ON exam.result_moderation
  FOR EACH ROW EXECUTE FUNCTION exam.result_moderation_lock();

-- A result publication event (original, revised after revaluation,
-- supplementary). Results hang off the publication that released them.
CREATE TABLE exam.result_publication (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id           uuid NOT NULL REFERENCES exam.exam_session(id),
  publication_type_id       smallint NOT NULL REFERENCES ref.publication_type(id),
  published_at              timestamptz NOT NULL DEFAULT now(),
  published_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  note                      text
);

-- A published course result. The ONE deliberate stored-derived value in this
-- database: total_pct is the official figure of record at publication time.
-- Rows are immutable (a correction = a new, revised publication), and the
-- grade band they point to can never be edited afterwards.
CREATE TABLE exam.course_result (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  result_publication_id  uuid NOT NULL REFERENCES exam.result_publication(id),
  exam_registration_id   uuid NOT NULL REFERENCES exam.exam_registration(id),
  total_pct              numeric(5,2) NOT NULL CHECK (total_pct BETWEEN 0 AND 100),
  grade_band_id          int NOT NULL REFERENCES academic.grade_band(id),
  result_status_id       smallint NOT NULL REFERENCES ref.result_status(id),
  UNIQUE (result_publication_id, exam_registration_id)
);
CREATE INDEX course_result_registration_idx ON exam.course_result(exam_registration_id);

CREATE OR REPLACE FUNCTION exam.course_result_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'course_result: published results are immutable; publish a revised result instead'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (SELECT exam_session_id FROM exam.result_publication WHERE id = NEW.result_publication_id) <>
     (SELECT exam_session_id FROM exam.exam_registration WHERE id = NEW.exam_registration_id) THEN
    RAISE EXCEPTION 'course_result: the publication and the exam attempt belong to different sessions'
      USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT grade_scale_id FROM academic.grade_band WHERE id = NEW.grade_band_id) <>
     (SELECT c.grade_scale_id FROM exam.exam_registration er
      JOIN academic.course_registration r ON r.id = er.course_registration_id
      JOIN academic.student_enrollment e ON e.id = r.student_enrollment_id
      JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
      JOIN academic.curriculum c ON c.id = bc.curriculum_id
      WHERE er.id = NEW.exam_registration_id) THEN
    RAISE EXCEPTION 'course_result: grade band is not from the student''s curriculum grade scale' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_result_validate BEFORE INSERT OR UPDATE OR DELETE ON exam.course_result
  FOR EACH ROW EXECUTE FUNCTION exam.course_result_validate();

CREATE OR REPLACE FUNCTION exam.protect_used_grade_band()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM exam.course_result WHERE grade_band_id = OLD.id) THEN
    RAISE EXCEPTION 'grade_band %: used by published results — create a new grade scale instead', OLD.grade_letter
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER trg_grade_band_protect BEFORE UPDATE OR DELETE ON academic.grade_band
  FOR EACH ROW EXECUTE FUNCTION exam.protect_used_grade_band();

-- Register of issued marksheets (the legal document). Content is derived from
-- published results; this table records the serial number and the issue.
CREATE TABLE exam.marksheet (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id   uuid NOT NULL REFERENCES academic.student_enrollment(id),
  exam_session_id         uuid NOT NULL REFERENCES exam.exam_session(id),
  serial_no               citext NOT NULL UNIQUE,
  is_duplicate            boolean NOT NULL DEFAULT false,    -- re-issue after loss
  issued_by_employee_id   uuid NOT NULL REFERENCES people.employee(id),
  issued_at               timestamptz NOT NULL DEFAULT now(),
  file_object_id          uuid REFERENCES people.file_object(id)
);
CREATE INDEX marksheet_enrollment_idx ON exam.marksheet(student_enrollment_id);
CREATE UNIQUE INDEX marksheet_one_original_uq ON exam.marksheet(student_enrollment_id, exam_session_id) WHERE NOT is_duplicate;

-- #############################################################################
-- 4. POST-RESULT — revaluation / rechecking
-- #############################################################################

-- A student's request to recheck / revaluate a script, allowed only after a
-- result for that attempt is published. The outcome is a new evaluation
-- round on the script (never an edit), followed by a REVISED publication.
CREATE TABLE exam.revaluation_request (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  answer_script_id       uuid NOT NULL REFERENCES exam.answer_script(id),
  revaluation_type_id    smallint NOT NULL REFERENCES ref.revaluation_type(id),
  revaluation_status_id  smallint NOT NULL REFERENCES ref.revaluation_status(id),
  requested_at           timestamptz NOT NULL DEFAULT now(),
  closed_at              timestamptz,
  UNIQUE (answer_script_id, revaluation_type_id),
  CHECK (closed_at IS NULL OR closed_at >= requested_at)
);

CREATE OR REPLACE FUNCTION exam.revaluation_request_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM exam.answer_script a JOIN exam.course_result cr ON cr.exam_registration_id = a.exam_registration_id
                 WHERE a.id = NEW.answer_script_id) THEN
    RAISE EXCEPTION 'revaluation_request: no published result for this paper yet' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_revaluation_request_validate BEFORE INSERT ON exam.revaluation_request
  FOR EACH ROW EXECUTE FUNCTION exam.revaluation_request_validate();
