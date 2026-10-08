-- =============================================================================
-- 04f_exam_papers_certificates.sql — Question papers, attempt limits,
-- certificates and convocation (schema: exam)
--
--   QUESTION PAPER LIFECYCLE (before the date sheet exists)
--     paper_setter_assignment   setter / moderator per session × offering × exam
--                               type — an employee or an external examiner
--     question_paper            a set (A / B …) with its confidential file:
--                               draft → submitted → moderated → approved → printed → used
--     exam_schedule.question_paper_id   which approved set the paper used
--   ATTEMPT LIMIT
--     curriculum.max_attempts_per_course enforced on exam_registration
--   CERTIFICATES & CONVOCATION
--     convocation               the ceremony a degree is conferred at
--     certificate               register of issued documents: transcript,
--                               provisional / degree certificate, migration,
--                               character, bonafide … with serial and a public
--                               verification code (NAD / DigiLocker reference)
--
-- Marksheets stay in exam.marksheet (04b); division is derived (exam.v_division [09]).
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = exam, academic, people, org, ref, public;

-- ##################################################### QUESTION PAPER LIFECYCLE ##

-- Who sets / moderates the paper of a scheduled component of an offering in a
-- session. Keyed on the same triple as exam_schedule so papers can be prepared
-- before the date sheet exists. Setter and moderator must be different people.
CREATE TABLE exam.paper_setter_assignment (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id           uuid NOT NULL REFERENCES exam.exam_session(id) ON DELETE CASCADE,
  course_offering_id        uuid NOT NULL REFERENCES academic.course_offering(id),
  assessment_type_id        smallint NOT NULL REFERENCES ref.assessment_type(id),
  paper_setter_role_id      smallint NOT NULL REFERENCES ref.paper_setter_role(id),
  employee_id               uuid REFERENCES people.employee(id),
  external_person_id        uuid REFERENCES people.person(id),
  due_on                    date,
  appointed_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  UNIQUE (exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id)
);
SELECT util.attach_updated_at('exam.paper_setter_assignment');

CREATE OR REPLACE FUNCTION exam.paper_setter_assignment_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_person uuid;
BEGIN
  IF NOT (SELECT is_scheduled_exam FROM ref.assessment_type WHERE id = NEW.assessment_type_id) THEN
    RAISE EXCEPTION 'paper_setter_assignment: this assessment type has no question paper' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT academic_term_id FROM exam.exam_session WHERE id = NEW.exam_session_id) <>
     (SELECT academic_term_id FROM academic.course_offering WHERE id = NEW.course_offering_id)
     AND (SELECT lower(t.period) FROM exam.exam_session s JOIN academic.academic_term t ON t.id = s.academic_term_id WHERE s.id = NEW.exam_session_id) <
         (SELECT lower(t.period) FROM academic.course_offering o JOIN academic.academic_term t ON t.id = o.academic_term_id WHERE o.id = NEW.course_offering_id) THEN
    RAISE EXCEPTION 'paper_setter_assignment: the session is before the course offering' USING ERRCODE = 'check_violation';
  END IF;
  v_person := COALESCE(NEW.external_person_id, (SELECT person_id FROM people.employee WHERE id = NEW.employee_id));
  IF EXISTS (SELECT 1 FROM exam.paper_setter_assignment a
             WHERE a.exam_session_id = NEW.exam_session_id AND a.course_offering_id = NEW.course_offering_id
               AND a.assessment_type_id = NEW.assessment_type_id AND a.id <> NEW.id
               AND COALESCE(a.external_person_id, (SELECT person_id FROM people.employee WHERE id = a.employee_id)) = v_person) THEN
    RAISE EXCEPTION 'paper_setter_assignment: the same person cannot both set and moderate the paper' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_paper_setter_assignment_validate BEFORE INSERT OR UPDATE ON exam.paper_setter_assignment
  FOR EACH ROW EXECUTE FUNCTION exam.paper_setter_assignment_validate();

-- A question-paper set. The file is confidential (app-encrypted at rest, table
-- hidden from analytics). Status is a lookup whose flags say what must already
-- be on the row: moderated → a moderator; approved → an approver.
CREATE TABLE exam.question_paper (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_session_id               uuid NOT NULL REFERENCES exam.exam_session(id) ON DELETE CASCADE,
  course_offering_id            uuid NOT NULL REFERENCES academic.course_offering(id),
  assessment_type_id            smallint NOT NULL REFERENCES ref.assessment_type(id),
  set_code                      citext NOT NULL DEFAULT 'A',
  question_paper_status_id      smallint NOT NULL REFERENCES ref.question_paper_status(id),
  submitted_by_assignment_id    uuid REFERENCES exam.paper_setter_assignment(id),
  submitted_at                  timestamptz,
  moderated_by_assignment_id    uuid REFERENCES exam.paper_setter_assignment(id),
  moderated_at                  timestamptz,
  approved_by_employee_id       uuid REFERENCES people.employee(id),
  approved_at                   timestamptz,
  max_marks                     numeric(6,2) CHECK (max_marks > 0),
  duration_minutes              smallint CHECK (duration_minutes > 0),
  file_object_id                uuid REFERENCES people.file_object(id),
  created_at                    timestamptz NOT NULL DEFAULT now(),
  updated_at                    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exam_session_id, course_offering_id, assessment_type_id, set_code),
  CHECK ((submitted_by_assignment_id IS NULL) = (submitted_at IS NULL)),
  CHECK ((moderated_by_assignment_id IS NULL) = (moderated_at IS NULL)),
  CHECK ((approved_by_employee_id IS NULL) = (approved_at IS NULL))
);
SELECT util.attach_updated_at('exam.question_paper');

CREATE OR REPLACE FUNCTION exam.question_paper_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status record; v_a record;
BEGIN
  SELECT code, is_moderated, is_approved INTO v_status FROM ref.question_paper_status WHERE id = NEW.question_paper_status_id;
  IF NEW.submitted_by_assignment_id IS NOT NULL THEN
    SELECT a.*, r.code AS role INTO v_a FROM exam.paper_setter_assignment a JOIN ref.paper_setter_role r ON r.id = a.paper_setter_role_id
    WHERE a.id = NEW.submitted_by_assignment_id;
    IF v_a.role <> 'SETTER' OR v_a.exam_session_id <> NEW.exam_session_id OR v_a.course_offering_id <> NEW.course_offering_id
       OR v_a.assessment_type_id <> NEW.assessment_type_id THEN
      RAISE EXCEPTION 'question_paper: submitted_by must be the SETTER assignment of this paper' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.moderated_by_assignment_id IS NOT NULL THEN
    SELECT a.*, r.code AS role INTO v_a FROM exam.paper_setter_assignment a JOIN ref.paper_setter_role r ON r.id = a.paper_setter_role_id
    WHERE a.id = NEW.moderated_by_assignment_id;
    IF v_a.role <> 'MODERATOR' OR v_a.exam_session_id <> NEW.exam_session_id OR v_a.course_offering_id <> NEW.course_offering_id
       OR v_a.assessment_type_id <> NEW.assessment_type_id THEN
      RAISE EXCEPTION 'question_paper: moderated_by must be the MODERATOR assignment of this paper' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF v_status.is_moderated AND (NEW.submitted_by_assignment_id IS NULL OR NEW.moderated_by_assignment_id IS NULL) THEN
    RAISE EXCEPTION 'question_paper: status % needs a submitted and moderated paper', v_status.code USING ERRCODE = 'check_violation';
  END IF;
  IF v_status.is_approved AND NEW.approved_by_employee_id IS NULL THEN
    RAISE EXCEPTION 'question_paper: status % needs the approver', v_status.code USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_question_paper_validate BEFORE INSERT OR UPDATE ON exam.question_paper
  FOR EACH ROW EXECUTE FUNCTION exam.question_paper_validate();

-- Which approved set the paper on the date sheet used.
ALTER TABLE exam.exam_schedule ADD COLUMN question_paper_id uuid REFERENCES exam.question_paper(id);

CREATE OR REPLACE FUNCTION exam.exam_schedule_paper_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_qp record;
BEGIN
  IF NEW.question_paper_id IS NOT NULL THEN
    SELECT qp.exam_session_id, qp.course_offering_id, qp.assessment_type_id, st.is_approved INTO v_qp
    FROM exam.question_paper qp JOIN ref.question_paper_status st ON st.id = qp.question_paper_status_id
    WHERE qp.id = NEW.question_paper_id;
    IF v_qp.exam_session_id <> NEW.exam_session_id OR v_qp.course_offering_id <> NEW.course_offering_id
       OR v_qp.assessment_type_id <> NEW.assessment_type_id THEN
      RAISE EXCEPTION 'exam_schedule: the question paper is for another session, course or exam type' USING ERRCODE = 'check_violation';
    END IF;
    IF NOT v_qp.is_approved THEN
      RAISE EXCEPTION 'exam_schedule: only an approved question paper can be used' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_schedule_paper_validate BEFORE INSERT OR UPDATE OF question_paper_id ON exam.exam_schedule
  FOR EACH ROW EXECUTE FUNCTION exam.exam_schedule_paper_validate();

-- ############################################################# ATTEMPT LIMIT ##

-- curriculum.max_attempts_per_course: no further exam registration once the
-- course registration has used up its attempts. academic.attempt_allowance
-- additionally caps each attempt type (e.g. 2 backlog, 1 golden, 1 mercy chance).
CREATE OR REPLACE FUNCTION exam.exam_registration_attempt_limit()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_max int; v_used int; v_curriculum uuid; v_type_max int;
BEGIN
  SELECT c.max_attempts_per_course, c.id INTO v_max, v_curriculum
  FROM academic.course_registration r
  JOIN academic.student_enrollment e ON e.id = r.student_enrollment_id
  JOIN academic.batch_curriculum bc  ON bc.batch_id = e.batch_id
  JOIN academic.curriculum c         ON c.id = bc.curriculum_id
  WHERE r.id = NEW.course_registration_id;
  IF v_max IS NOT NULL THEN
    SELECT count(*) INTO v_used FROM exam.exam_registration WHERE course_registration_id = NEW.course_registration_id AND id <> NEW.id;
    IF v_used >= v_max THEN
      RAISE EXCEPTION 'exam_registration: the maximum of % attempt(s) for this course has been used', v_max USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  SELECT max_attempts INTO v_type_max FROM academic.attempt_allowance
  WHERE curriculum_id = v_curriculum AND exam_attempt_type_id = NEW.exam_attempt_type_id;
  IF v_type_max IS NOT NULL AND
     (SELECT count(*) FROM exam.exam_registration
      WHERE course_registration_id = NEW.course_registration_id AND exam_attempt_type_id = NEW.exam_attempt_type_id
        AND id <> NEW.id) >= v_type_max THEN
    RAISE EXCEPTION 'exam_registration: all % chance(s) of this attempt type have been used', v_type_max
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_exam_registration_attempt_limit BEFORE INSERT ON exam.exam_registration
  FOR EACH ROW EXECUTE FUNCTION exam.exam_registration_attempt_limit();

-- ################################################## CERTIFICATES & CONVOCATION ##

CREATE TABLE exam.convocation (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year_id  uuid NOT NULL REFERENCES academic.academic_year(id),
  name              text NOT NULL,                              -- "12th Convocation"
  held_on           date NOT NULL,
  start_time        time,                                        -- NULL = the venue is held for the whole day
  end_time          time,
  room_id           uuid REFERENCES org.room(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (academic_year_id, name),
  CHECK ((start_time IS NULL) = (end_time IS NULL) AND (end_time IS NULL OR end_time > start_time))
);
SELECT util.attach_updated_at('exam.convocation');

-- Register of issued certificates. The content is derived (results, award);
-- only the issue of the legal document is recorded: serial, public
-- verification code, NAD / DigiLocker reference, file. Rules come from the
-- type: needs an award (degree / provisional), needs a closed enrollment
-- (migration), single original per enrollment (duplicates and re-issues after
-- cancellation are separate rows).
CREATE TABLE exam.certificate (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id),
  certificate_type_id    smallint NOT NULL REFERENCES ref.certificate_type(id),
  serial_no              citext NOT NULL UNIQUE,
  verification_code      citext NOT NULL UNIQUE,                -- printed / QR; public verification
  student_award_id       uuid REFERENCES academic.student_award(id),
  convocation_id         uuid REFERENCES exam.convocation(id),
  is_duplicate           boolean NOT NULL DEFAULT false,
  issued_on              date NOT NULL DEFAULT current_date,
  issued_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  nad_reference          citext UNIQUE,                         -- National Academic Depository / DigiLocker id
  file_object_id         uuid REFERENCES people.file_object(id),
  cancelled_at           timestamptz,
  cancel_reason          text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK ((cancelled_at IS NULL) = (cancel_reason IS NULL))
);
CREATE INDEX certificate_enrollment_idx ON exam.certificate(student_enrollment_id);
SELECT util.attach_updated_at('exam.certificate');

CREATE OR REPLACE FUNCTION exam.certificate_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_type record; v_valid daterange;
BEGIN
  SELECT * INTO v_type FROM ref.certificate_type WHERE id = NEW.certificate_type_id;
  SELECT valid INTO v_valid FROM academic.student_enrollment WHERE id = NEW.student_enrollment_id;
  IF v_type.requires_award THEN
    IF NEW.student_award_id IS NULL THEN
      RAISE EXCEPTION 'certificate: a % is issued against a conferred award', v_type.code USING ERRCODE = 'check_violation';
    END IF;
    IF (SELECT student_enrollment_id FROM academic.student_award WHERE id = NEW.student_award_id) <> NEW.student_enrollment_id THEN
      RAISE EXCEPTION 'certificate: the award belongs to another enrollment' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.convocation_id IS NOT NULL THEN
    RAISE EXCEPTION 'certificate: only an award certificate is conferred at a convocation' USING ERRCODE = 'check_violation';
  END IF;
  IF v_type.requires_closed_enrollment AND upper_inf(v_valid) THEN
    RAISE EXCEPTION 'certificate: a % needs a closed enrollment', v_type.code USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.is_duplicate THEN
    IF NOT EXISTS (SELECT 1 FROM exam.certificate c WHERE c.student_enrollment_id = NEW.student_enrollment_id
                   AND c.certificate_type_id = NEW.certificate_type_id AND NOT c.is_duplicate AND c.id <> NEW.id) THEN
      RAISE EXCEPTION 'certificate: no original % to duplicate', v_type.code USING ERRCODE = 'check_violation';
    END IF;
  ELSIF v_type.is_single_issue AND NEW.cancelled_at IS NULL AND EXISTS (
        SELECT 1 FROM exam.certificate c WHERE c.student_enrollment_id = NEW.student_enrollment_id
        AND c.certificate_type_id = NEW.certificate_type_id AND NOT c.is_duplicate AND c.cancelled_at IS NULL AND c.id <> NEW.id) THEN
    RAISE EXCEPTION 'certificate: an original % has already been issued (issue a duplicate, or cancel it first)', v_type.code
      USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_certificate_validate BEFORE INSERT OR UPDATE ON exam.certificate
  FOR EACH ROW EXECUTE FUNCTION exam.certificate_validate();
