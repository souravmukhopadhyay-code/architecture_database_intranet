-- =============================================================================
-- 06c_academic_operations.sql — day-to-day academic operations
--   (schemas: academic, exam, org; uses the wf approval engine from 06b)
--
--   CREDIT LOAD            credit_load_rule (min / max credits per term of a
--                          curriculum), credit_overload_approval → enforced on
--                          course registration; academic.v_credit_load [09]
--   LEAVE                  attendance_leave (duty / medical leave) approved
--                          through the ATTENDANCE_LEAVE chain; an approved leave
--                          day counts in attendance as its leave type says
--   PROJECTS & INTERNSHIPS supervised_work ─< supervised_work_guide, internship
--                          (UG / PG projects, dissertations, internships)
--   RANKS & PRIZES         exam.prize ─< exam.prize_award; rank list derived
--                          (exam.v_rank_list [09])
--   RELATIVE GRADING       relative_grade_cutoff (grade_scale.is_relative)
--   MENTORING              mentoring_meeting (on people.student_mentor)
--   CLASS REPRESENTATIVES  section_representative
--   TIMETABLE INPUTS       org.room_facility, course_room_requirement (checked
--                          on every timetable entry, with room capacity),
--                          faculty_course_preference
--   QUESTION BANK          exam.question_bank_item ─< exam.question_paper_item
--                          (CO / Bloom-tagged questions; paper blueprint [09])
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = academic, exam, org, people, wf, ref, public;

-- ################################################################ CREDIT LOAD ##

-- Minimum / maximum credits a student may register in one term of a
-- curriculum. term_no NULL = the default for every term without its own rule.
-- The maximum is enforced on registration (an approved overload lifts it for
-- one student and term); the minimum is reported (academic.v_credit_load).
CREATE TABLE academic.credit_load_rule (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  curriculum_id  uuid NOT NULL REFERENCES academic.curriculum(id) ON DELETE CASCADE,
  term_no        smallint CHECK (term_no >= 1),
  min_credits    numeric(5,1) CHECK (min_credits >= 0),
  max_credits    numeric(5,1) CHECK (max_credits > 0),
  CHECK (num_nonnulls(min_credits, max_credits) >= 1),
  CHECK (min_credits IS NULL OR max_credits IS NULL OR min_credits <= max_credits),
  UNIQUE NULLS NOT DISTINCT (curriculum_id, term_no)
);
CREATE TRIGGER trg_credit_load_rule_freeze BEFORE INSERT OR UPDATE OR DELETE ON academic.credit_load_rule
  FOR EACH ROW EXECUTE FUNCTION academic.guard_curriculum_edit();

-- An approved credit overload for one student in one term.
CREATE TABLE academic.credit_overload_approval (
  student_enrollment_id    uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  academic_term_id         uuid NOT NULL REFERENCES academic.academic_term(id),
  max_credits              numeric(5,1) NOT NULL CHECK (max_credits > 0),
  reason                   text NOT NULL CHECK (btrim(reason) <> ''),
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  approved_at              timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (student_enrollment_id, academic_term_id)
);

-- A counted registration may not take the student's credits in that term
-- above the applicable maximum.
CREATE OR REPLACE FUNCTION academic.course_registration_credit_load()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_term uuid; v_credits numeric; v_max numeric; v_used numeric;
BEGIN
  IF NOT (SELECT is_counted FROM ref.registration_status WHERE id = NEW.registration_status_id) THEN
    RETURN NEW;
  END IF;
  SELECT o.academic_term_id, c.credits INTO v_term, v_credits
  FROM academic.course_offering o JOIN academic.course c ON c.id = o.course_id WHERE o.id = NEW.course_offering_id;
  SELECT COALESCE(ov.max_credits, rule.max_credits) INTO v_max
  FROM academic.student_enrollment e
  JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
  LEFT JOIN LATERAL (SELECT r.max_credits FROM academic.credit_load_rule r
                     WHERE r.curriculum_id = bc.curriculum_id
                       AND (r.term_no = academic.enrollment_term_no(e.id, v_term) OR r.term_no IS NULL)
                     ORDER BY r.term_no NULLS LAST LIMIT 1) rule ON true
  LEFT JOIN academic.credit_overload_approval ov ON ov.student_enrollment_id = e.id AND ov.academic_term_id = v_term
  WHERE e.id = NEW.student_enrollment_id;
  IF v_max IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT COALESCE(sum(c.credits), 0) INTO v_used
  FROM academic.course_registration r
  JOIN ref.registration_status rs ON rs.id = r.registration_status_id AND rs.is_counted
  JOIN academic.course_offering o ON o.id = r.course_offering_id AND o.academic_term_id = v_term
  JOIN academic.course c          ON c.id = o.course_id
  WHERE r.student_enrollment_id = NEW.student_enrollment_id AND r.id <> NEW.id;
  IF v_used + v_credits > v_max THEN
    RAISE EXCEPTION 'course_registration: % credits this term would exceed the maximum of % (an overload needs approval)',
      v_used + v_credits, v_max USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_course_registration_credit_load BEFORE INSERT OR UPDATE OF registration_status_id, course_offering_id
  ON academic.course_registration FOR EACH ROW EXECUTE FUNCTION academic.course_registration_credit_load();

-- ###################################################################### LEAVE ##

-- A student's duty / medical leave for a period, decided through the
-- ATTENDANCE_LEAVE approval chain (e.g. the HOD of the programme's
-- department). Once the round is complete, every class the student was not
-- marked present in during the period counts with the leave type's attendance
-- status (ON_DUTY counts as present; MEDICAL_LEAVE is recorded, not counted —
-- a shortage is then a condonation matter). Marks themselves are never edited.
-- The reason is often health data: registered, anonymised on erasure, hidden
-- from analytics.
CREATE TABLE academic.attendance_leave (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id  uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  leave_type_id          smallint NOT NULL REFERENCES ref.leave_type(id),
  period                 daterange NOT NULL,
  reason                 text NOT NULL CHECK (btrim(reason) <> ''),
  document_file_id       uuid REFERENCES people.file_object(id),
  instance_id            uuid NOT NULL UNIQUE REFERENCES wf.approval_instance(id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period))
);
CREATE INDEX attendance_leave_enrollment_idx ON academic.attendance_leave(student_enrollment_id);

CREATE OR REPLACE FUNCTION academic.attendance_leave_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'attendance_leave: a leave request is never edited; withdraw it and apply again' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (SELECT needs_document FROM ref.leave_type WHERE id = NEW.leave_type_id) AND NEW.document_file_id IS NULL THEN
    RAISE EXCEPTION 'attendance_leave: this leave type needs a supporting document' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM wf.approval_instance i
                 JOIN wf.approval_document_type dt ON dt.id = i.document_type_id AND dt.code = 'ATTENDANCE_LEAVE'
                 JOIN academic.student_enrollment e ON e.id = NEW.student_enrollment_id
                 JOIN academic.batch b ON b.id = e.batch_id
                 JOIN academic.program p ON p.id = b.program_id
                 WHERE i.id = NEW.instance_id AND i.owner_org_unit_id = p.offering_org_unit_id) THEN
    RAISE EXCEPTION 'attendance_leave: the round is not an ATTENDANCE_LEAVE round of the student''s department' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.attendance_leave al
             JOIN wf.v_instance_state s ON s.instance_id = al.instance_id AND s.status IN ('IN_PROGRESS', 'APPROVED', 'SIGNED')
             WHERE al.student_enrollment_id = NEW.student_enrollment_id AND al.period && NEW.period) THEN
    RAISE EXCEPTION 'attendance_leave: an overlapping leave is already pending or approved' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_attendance_leave_validate BEFORE INSERT OR UPDATE OR DELETE ON academic.attendance_leave
  FOR EACH ROW EXECUTE FUNCTION academic.attendance_leave_validate();

-- ###################################################### PROJECTS & INTERNSHIPS ##

-- A project, dissertation or internship a student does as a course
-- (a registration whose curriculum category requires supervision).
CREATE TABLE academic.supervised_work (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_registration_id  uuid NOT NULL UNIQUE REFERENCES academic.course_registration(id) ON DELETE CASCADE,
  title                   text NOT NULL CHECK (btrim(title) <> ''),
  synopsis                text,
  report_file_id          uuid REFERENCES people.file_object(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('academic.supervised_work');

CREATE OR REPLACE FUNCTION academic.supervised_work_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.v_registration_scheme rs JOIN ref.course_category cc ON cc.id = rs.course_category_id
                 WHERE rs.course_registration_id = NEW.course_registration_id AND cc.requires_supervision) THEN
    RAISE EXCEPTION 'supervised_work: the course is not a project / internship / dissertation course' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_supervised_work_validate BEFORE INSERT OR UPDATE OF course_registration_id ON academic.supervised_work
  FOR EACH ROW EXECUTE FUNCTION academic.supervised_work_validate();

-- Guides of a supervised work over time (roles as for doctoral supervision):
-- one principal guide at a time, always an employee; an external co-guide
-- (industry, another university) is a person.
CREATE TABLE academic.supervised_work_guide (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervised_work_id  uuid NOT NULL REFERENCES academic.supervised_work(id) ON DELETE CASCADE,
  supervisor_role_id  smallint NOT NULL REFERENCES ref.supervisor_role(id),
  employee_id         uuid REFERENCES people.employee(id),
  external_person_id  uuid REFERENCES people.person(id),
  valid               daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid))
);
CREATE INDEX supervised_work_guide_work_idx ON academic.supervised_work_guide(supervised_work_id);
CREATE INDEX supervised_work_guide_employee_idx ON academic.supervised_work_guide(employee_id);

CREATE OR REPLACE FUNCTION academic.supervised_work_guide_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_role record;
BEGIN
  SELECT is_principal, allows_external INTO v_role FROM ref.supervisor_role WHERE id = NEW.supervisor_role_id;
  IF NEW.external_person_id IS NOT NULL AND NOT v_role.allows_external THEN
    RAISE EXCEPTION 'supervised_work_guide: this guide role must be held by an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF v_role.allows_external AND EXISTS (SELECT 1 FROM people.employee WHERE person_id = NEW.external_person_id) THEN
    RAISE EXCEPTION 'supervised_work_guide: an external co-guide cannot be an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF v_role.is_principal AND EXISTS (
       SELECT 1 FROM academic.supervised_work_guide g JOIN ref.supervisor_role r ON r.id = g.supervisor_role_id AND r.is_principal
       WHERE g.supervised_work_id = NEW.supervised_work_id AND g.id <> NEW.id AND g.valid && NEW.valid) THEN
    RAISE EXCEPTION 'supervised_work_guide: the work already has a principal guide in this period' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_supervised_work_guide_validate BEFORE INSERT OR UPDATE ON academic.supervised_work_guide
  FOR EACH ROW EXECUTE FUNCTION academic.supervised_work_guide_validate();

-- The placement details of an internship (a subtype of supervised work).
CREATE TABLE academic.internship (
  supervised_work_id               uuid PRIMARY KEY REFERENCES academic.supervised_work(id) ON DELETE CASCADE,
  organisation_name                text NOT NULL CHECK (btrim(organisation_name) <> ''),
  city_id                          int REFERENCES ref.city(id),
  period                           daterange NOT NULL,
  industry_mentor_person_id        uuid REFERENCES people.person(id),
  offer_letter_file_id             uuid REFERENCES people.file_object(id),
  completion_certificate_file_id   uuid REFERENCES people.file_object(id),
  created_at                       timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period))
);

CREATE OR REPLACE FUNCTION academic.internship_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.supervised_work w
                 JOIN academic.v_registration_scheme rs ON rs.course_registration_id = w.course_registration_id
                 JOIN ref.course_category cc ON cc.id = rs.course_category_id
                 WHERE w.id = NEW.supervised_work_id AND cc.code IN ('INTERNSHIP', 'IACP')) THEN
    RAISE EXCEPTION 'internship: the supervised work is not an internship course' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee WHERE person_id = NEW.industry_mentor_person_id) THEN
    RAISE EXCEPTION 'internship: the industry mentor is from the host organisation, not an employee' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_internship_validate BEFORE INSERT OR UPDATE ON academic.internship
  FOR EACH ROW EXECUTE FUNCTION academic.internship_validate();

-- ############################################################# RANKS & PRIZES ##

-- A medal or prize the university awards: for a programme (or university-
-- wide), optionally tied to a position in the programme's rank list
-- (rank_position 1 = the topper, whose rank is derived — exam.v_rank_list).
CREATE TABLE exam.prize (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code            citext NOT NULL UNIQUE,
  name            text NOT NULL,                        -- "Chancellor's Gold Medal — B.Tech CSE"
  prize_type_id   smallint NOT NULL REFERENCES ref.prize_type(id),
  program_id      uuid REFERENCES academic.program(id),
  rank_position   smallint CHECK (rank_position >= 1),
  sponsor         text,                                 -- endowment / sponsor
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (rank_position IS NULL OR program_id IS NOT NULL)
);

-- A prize awarded to a student (a graduating enrollment), at a convocation.
-- A rank-tied prize goes only to the student holding that rank, once per batch.
CREATE TABLE exam.prize_award (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prize_id                 uuid NOT NULL REFERENCES exam.prize(id),
  student_enrollment_id    uuid NOT NULL REFERENCES academic.student_enrollment(id),
  convocation_id           uuid REFERENCES exam.convocation(id),
  awarded_on               date NOT NULL,
  citation                 text,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (prize_id, student_enrollment_id)
);

CREATE OR REPLACE FUNCTION exam.prize_award_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_prize record; v_batch uuid; v_program uuid;
BEGIN
  SELECT * INTO v_prize FROM exam.prize WHERE id = NEW.prize_id;
  SELECT e.batch_id, b.program_id INTO v_batch, v_program
  FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id WHERE e.id = NEW.student_enrollment_id;
  IF v_prize.program_id IS NOT NULL AND v_prize.program_id <> v_program THEN
    RAISE EXCEPTION 'prize_award: the prize is for another programme' USING ERRCODE = 'check_violation';
  END IF;
  IF v_prize.rank_position IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM exam.v_rank_list rl WHERE rl.student_enrollment_id = NEW.student_enrollment_id
                     AND rl.rank = v_prize.rank_position) THEN
      RAISE EXCEPTION 'prize_award: the prize goes to rank %, and this student does not hold it', v_prize.rank_position
        USING ERRCODE = 'check_violation';
    END IF;
    IF EXISTS (SELECT 1 FROM exam.prize_award pa JOIN academic.student_enrollment e ON e.id = pa.student_enrollment_id
               WHERE pa.prize_id = NEW.prize_id AND e.batch_id = v_batch AND pa.id <> NEW.id) THEN
      RAISE EXCEPTION 'prize_award: this prize has already been awarded for the batch' USING ERRCODE = 'unique_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_prize_award_validate BEFORE INSERT OR UPDATE ON exam.prize_award
  FOR EACH ROW EXECUTE FUNCTION exam.prize_award_validate();

-- ########################################################### RELATIVE GRADING ##

-- On a RELATIVE grade scale, a passing student gets the highest band whose
-- cutoff their percentile (within the course offering × exam session cohort
-- of passing students) reaches; failing students and small cohorts use the
-- absolute percentage bands (exam.v_provisional_result [09]).
CREATE TABLE academic.relative_grade_cutoff (
  grade_band_id   int PRIMARY KEY REFERENCES academic.grade_band(id) ON DELETE CASCADE,
  min_percentile  numeric(5,2) NOT NULL CHECK (min_percentile BETWEEN 0 AND 100)
);

CREATE OR REPLACE FUNCTION academic.relative_grade_cutoff_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.grade_band gb JOIN academic.grade_scale gs ON gs.id = gb.grade_scale_id
                 WHERE gb.id = NEW.grade_band_id AND gs.is_relative AND gb.is_pass) THEN
    RAISE EXCEPTION 'relative_grade_cutoff: only a passing band of a relative grade scale takes a percentile cutoff'
      USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.relative_grade_cutoff rc
             JOIN academic.grade_band a ON a.id = rc.grade_band_id
             JOIN academic.grade_band b ON b.id = NEW.grade_band_id
             WHERE a.grade_scale_id = b.grade_scale_id AND rc.grade_band_id <> NEW.grade_band_id
               AND rc.min_percentile = NEW.min_percentile) THEN
    RAISE EXCEPTION 'relative_grade_cutoff: two bands of the scale share the same cutoff' USING ERRCODE = 'unique_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_relative_grade_cutoff_validate BEFORE INSERT OR UPDATE ON academic.relative_grade_cutoff
  FOR EACH ROW EXECUTE FUNCTION academic.relative_grade_cutoff_validate();

-- ################################################################## MENTORING ##

-- A mentor–mentee meeting, recorded by the mentor while the mentorship is
-- current. concern_flag marks a student needing attention. The notes can hold
-- sensitive personal matters: registered for anonymisation on erasure and
-- hidden from analytics.
CREATE TABLE academic.mentoring_meeting (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_mentor_id  uuid NOT NULL REFERENCES people.student_mentor(id) ON DELETE CASCADE,
  met_on             date NOT NULL,
  meeting_mode_id    smallint NOT NULL REFERENCES ref.meeting_mode(id),
  summary            text NOT NULL CHECK (btrim(summary) <> ''),
  action_points      text,
  follow_up_on       date,
  concern_flag       boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (follow_up_on IS NULL OR follow_up_on >= met_on)
);
CREATE INDEX mentoring_meeting_mentor_idx ON academic.mentoring_meeting(student_mentor_id);

CREATE OR REPLACE FUNCTION academic.mentoring_meeting_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM people.student_mentor WHERE id = NEW.student_mentor_id AND valid @> NEW.met_on) THEN
    RAISE EXCEPTION 'mentoring_meeting: % is outside this mentorship', NEW.met_on USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_mentoring_meeting_validate BEFORE INSERT OR UPDATE ON academic.mentoring_meeting
  FOR EACH ROW EXECUTE FUNCTION academic.mentoring_meeting_validate();

-- ###################################################### CLASS REPRESENTATIVES ##

-- A student holding a role in their section for the term (class
-- representative, deputy …): one holder per role, one role per student.
CREATE TABLE academic.section_representative (
  section_id                uuid NOT NULL REFERENCES academic.section(id) ON DELETE CASCADE,
  section_role_id           smallint NOT NULL REFERENCES ref.section_role(id),
  student_enrollment_id     uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  appointed_by_employee_id  uuid REFERENCES people.employee(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (section_id, section_role_id),
  UNIQUE (section_id, student_enrollment_id)
);

CREATE OR REPLACE FUNCTION academic.section_representative_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM academic.section_student
                 WHERE section_id = NEW.section_id AND student_enrollment_id = NEW.student_enrollment_id) THEN
    RAISE EXCEPTION 'section_representative: the student is not in this section' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_section_representative_validate BEFORE INSERT OR UPDATE ON academic.section_representative
  FOR EACH ROW EXECUTE FUNCTION academic.section_representative_validate();

-- ########################################################### TIMETABLE INPUTS ##

-- What a room has (projector, smart board, computers, wheelchair access …).
CREATE TABLE org.room_facility (
  room_id          uuid NOT NULL REFERENCES org.room(id) ON DELETE CASCADE,
  room_feature_id  smallint NOT NULL REFERENCES ref.room_feature(id),
  quantity         smallint NOT NULL DEFAULT 1 CHECK (quantity > 0),
  PRIMARY KEY (room_id, room_feature_id)
);

-- What a course component needs from its room: a room type (a lab for the
-- practical) and / or features (computers, projector). The timetable solver
-- reads it; the database rejects a timetable entry in a room that does not
-- meet it.
CREATE TABLE academic.course_room_requirement (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id              uuid NOT NULL REFERENCES academic.course(id) ON DELETE CASCADE,
  delivery_component_id  smallint NOT NULL REFERENCES ref.delivery_component(id),
  room_type_id           smallint REFERENCES ref.room_type(id),
  room_feature_id        smallint REFERENCES ref.room_feature(id),
  CHECK (num_nonnulls(room_type_id, room_feature_id) = 1),
  UNIQUE NULLS NOT DISTINCT (course_id, delivery_component_id, room_type_id, room_feature_id)
);

-- A timetabled class must fit its room: enough seats for the class roster,
-- and the room type / features its course component requires.
CREATE OR REPLACE FUNCTION academic.timetable_entry_room_check()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_course uuid; v_component smallint; v_roster int; v_capacity int; v_room_type smallint;
BEGIN
  SELECT o.course_id, ta.delivery_component_id INTO v_course, v_component
  FROM academic.teaching_assignment ta JOIN academic.course_offering o ON o.id = ta.course_offering_id
  WHERE ta.id = NEW.teaching_assignment_id;
  SELECT capacity, room_type_id INTO v_capacity, v_room_type FROM org.room WHERE id = NEW.room_id;
  SELECT count(*) INTO v_roster FROM academic.v_assignment_student WHERE teaching_assignment_id = NEW.teaching_assignment_id;
  IF v_roster > v_capacity THEN
    RAISE EXCEPTION 'timetable_entry: % students in the class, the room seats %', v_roster, v_capacity USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM academic.course_room_requirement q
             WHERE q.course_id = v_course AND q.delivery_component_id = v_component
               AND ((q.room_type_id IS NOT NULL AND q.room_type_id <> v_room_type)
                 OR (q.room_feature_id IS NOT NULL AND NOT EXISTS (
                       SELECT 1 FROM org.room_facility f WHERE f.room_id = NEW.room_id AND f.room_feature_id = q.room_feature_id)))) THEN
    RAISE EXCEPTION 'timetable_entry: the room does not meet the course''s room requirements' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_timetable_entry_room_check BEFORE INSERT OR UPDATE OF room_id, teaching_assignment_id ON academic.timetable_entry
  FOR EACH ROW EXECUTE FUNCTION academic.timetable_entry_room_check();

-- A teaching employee's ranked course preferences for a term — input to
-- faculty allocation (academic.v_faculty_preference_status [09]).
CREATE TABLE academic.faculty_course_preference (
  academic_term_id  uuid NOT NULL REFERENCES academic.academic_term(id),
  employee_id       uuid NOT NULL REFERENCES people.employee(id) ON DELETE CASCADE,
  course_id         uuid NOT NULL REFERENCES academic.course(id),
  preference_rank   smallint NOT NULL CHECK (preference_rank BETWEEN 1 AND 20),
  remarks           text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (academic_term_id, employee_id, course_id),
  UNIQUE (academic_term_id, employee_id, preference_rank)
);

CREATE OR REPLACE FUNCTION academic.faculty_course_preference_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM people.employee e JOIN ref.employee_category c ON c.id = e.employee_category_id
                 WHERE e.id = NEW.employee_id AND c.code = 'TEACHING') THEN
    RAISE EXCEPTION 'faculty_course_preference: only teaching staff state course preferences' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_faculty_course_preference_validate BEFORE INSERT OR UPDATE ON academic.faculty_course_preference
  FOR EACH ROW EXECUTE FUNCTION academic.faculty_course_preference_validate();

-- ############################################################## QUESTION BANK ##

-- A reusable question for a course, tagged with its course outcome, Bloom
-- level, difficulty and type. Confidential (hidden from analytics). Reviewed
-- by a second person before it can be used in a paper.
CREATE TABLE exam.question_bank_item (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id                 uuid NOT NULL REFERENCES academic.course(id),
  course_outcome_id         uuid REFERENCES academic.course_outcome(id),
  bloom_level_id            smallint REFERENCES ref.bloom_level(id),
  question_difficulty_id    smallint NOT NULL REFERENCES ref.question_difficulty(id),
  question_type_id          smallint NOT NULL REFERENCES ref.question_type(id),
  question_text             text NOT NULL CHECK (btrim(question_text) <> ''),
  marks                     numeric(5,2) NOT NULL CHECK (marks > 0),
  created_by_employee_id    uuid NOT NULL REFERENCES people.employee(id),
  reviewed_by_employee_id   uuid REFERENCES people.employee(id),
  reviewed_at               timestamptz,
  is_active                 boolean NOT NULL DEFAULT true,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK ((reviewed_by_employee_id IS NULL) = (reviewed_at IS NULL)),
  CHECK (reviewed_by_employee_id IS DISTINCT FROM created_by_employee_id)
);
CREATE INDEX question_bank_item_course_idx ON exam.question_bank_item(course_id);
SELECT util.attach_updated_at('exam.question_bank_item');

CREATE OR REPLACE FUNCTION exam.question_bank_item_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.course_outcome_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.course_outcome co JOIN academic.course_syllabus cs ON cs.id = co.course_syllabus_id
       WHERE co.id = NEW.course_outcome_id AND cs.course_id = NEW.course_id) THEN
    RAISE EXCEPTION 'question_bank_item: the course outcome belongs to another course' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_question_bank_item_validate BEFORE INSERT OR UPDATE ON exam.question_bank_item
  FOR EACH ROW EXECUTE FUNCTION exam.question_bank_item_validate();

-- The questions of a question paper, drawn from the bank (reviewed, active,
-- same course), fixed once the paper is approved. Enables the paper's CO /
-- Bloom blueprint (exam.v_question_paper_blueprint [09]).
CREATE TABLE exam.question_paper_item (
  question_paper_id      uuid NOT NULL REFERENCES exam.question_paper(id) ON DELETE CASCADE,
  question_no            citext NOT NULL,                 -- '1', '2a'
  question_bank_item_id  uuid NOT NULL REFERENCES exam.question_bank_item(id),
  marks                  numeric(5,2) NOT NULL CHECK (marks > 0),
  PRIMARY KEY (question_paper_id, question_no),
  UNIQUE (question_paper_id, question_bank_item_id)
);

CREATE OR REPLACE FUNCTION exam.question_paper_item_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_paper record; v_item record;
BEGIN
  SELECT qp.approved_at, o.course_id INTO v_paper
  FROM exam.question_paper qp JOIN academic.course_offering o ON o.id = qp.course_offering_id
  WHERE qp.id = COALESCE(NEW.question_paper_id, OLD.question_paper_id);
  IF v_paper.approved_at IS NOT NULL THEN
    RAISE EXCEPTION 'question_paper_item: the paper is approved; its questions are fixed' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  SELECT course_id, reviewed_at, is_active INTO v_item FROM exam.question_bank_item WHERE id = NEW.question_bank_item_id;
  IF v_item.course_id <> v_paper.course_id THEN
    RAISE EXCEPTION 'question_paper_item: the question belongs to another course' USING ERRCODE = 'check_violation';
  END IF;
  IF v_item.reviewed_at IS NULL OR NOT v_item.is_active THEN
    RAISE EXCEPTION 'question_paper_item: only reviewed, active bank questions can be used' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_question_paper_item_validate BEFORE INSERT OR UPDATE OR DELETE ON exam.question_paper_item
  FOR EACH ROW EXECUTE FUNCTION exam.question_paper_item_validate();

-- ########################################################## CO / PO ATTAINMENT ##

-- The attainment policy (NBA-style): a student attains a course outcome at
-- student_target_pct of its marks; a course attains the outcome at level 1 /
-- 2 / 3 when that share of students reach it. program_id NULL = the
-- university default; a programme may set its own.
CREATE TABLE academic.attainment_policy (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id          uuid REFERENCES academic.program(id) ON DELETE CASCADE,
  student_target_pct  numeric(5,2) NOT NULL CHECK (student_target_pct BETWEEN 0 AND 100),
  level1_pct          numeric(5,2) NOT NULL,
  level2_pct          numeric(5,2) NOT NULL,
  level3_pct          numeric(5,2) NOT NULL,
  CHECK (0 < level1_pct AND level1_pct < level2_pct AND level2_pct < level3_pct AND level3_pct <= 100),
  UNIQUE NULLS NOT DISTINCT (program_id)
);

-- Which course outcomes an internal / continuous component assesses (for a
-- given course, since the outcome belongs to the course): its marks then count
-- toward those outcomes' attainment alongside question-wise exam marks.
CREATE TABLE academic.evaluation_component_outcome (
  evaluation_component_id  int NOT NULL REFERENCES academic.evaluation_component(id) ON DELETE CASCADE,
  course_outcome_id        uuid NOT NULL REFERENCES academic.course_outcome(id) ON DELETE CASCADE,
  PRIMARY KEY (evaluation_component_id, course_outcome_id)
);

CREATE OR REPLACE FUNCTION academic.evaluation_component_outcome_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT t.uses_answer_scripts FROM academic.evaluation_component ec JOIN ref.assessment_type t ON t.id = ec.assessment_type_id
      WHERE ec.id = NEW.evaluation_component_id) THEN
    RAISE EXCEPTION 'evaluation_component_outcome: a script-marked exam is measured question by question (exam.question_mark), not as a whole'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_evaluation_component_outcome_validate BEFORE INSERT OR UPDATE ON academic.evaluation_component_outcome
  FOR EACH ROW EXECUTE FUNCTION academic.evaluation_component_outcome_validate();

-- Marks per question of the paper a student actually sat (the set on the date
-- sheet), each question tied to a course outcome through the question bank.
-- The basis of CO attainment. They never exceed the evaluated script mark in
-- total; they may be entered after the result (OBE analysis) but not changed.
CREATE TABLE exam.question_mark (
  exam_registration_id    uuid NOT NULL REFERENCES exam.exam_registration(id) ON DELETE CASCADE,
  question_paper_id       uuid NOT NULL,
  question_no             citext NOT NULL,
  marks                   numeric(5,2) NOT NULL CHECK (marks >= 0),
  entered_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  entered_at              timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (exam_registration_id, question_paper_id, question_no),
  FOREIGN KEY (question_paper_id, question_no) REFERENCES exam.question_paper_item(question_paper_id, question_no)
);

CREATE OR REPLACE FUNCTION exam.question_mark_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_row exam.question_mark := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END; v_max numeric; v_script numeric;
BEGIN
  IF TG_OP <> 'INSERT' AND EXISTS (SELECT 1 FROM exam.course_result WHERE exam_registration_id = OLD.exam_registration_id) THEN
    RAISE EXCEPTION 'question_mark: a result of this attempt is published; question marks are locked' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  SELECT marks INTO v_max FROM exam.question_paper_item WHERE question_paper_id = NEW.question_paper_id AND question_no = NEW.question_no;
  IF NEW.marks > v_max THEN
    RAISE EXCEPTION 'question_mark: % exceeds the question''s % marks', NEW.marks, v_max USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM exam.exam_schedule s
                 WHERE s.question_paper_id = NEW.question_paper_id
                   AND exam.registration_matches_schedule(NEW.exam_registration_id, s.id)) THEN
    RAISE EXCEPTION 'question_mark: the student did not sit this question paper' USING ERRCODE = 'check_violation';
  END IF;
  SELECT esm.marks INTO v_script
  FROM exam.exam_schedule s
  JOIN exam.answer_script a ON a.exam_schedule_id = s.id AND a.exam_registration_id = NEW.exam_registration_id
  JOIN exam.v_effective_script_mark esm ON esm.answer_script_id = a.id
  WHERE s.question_paper_id = NEW.question_paper_id;
  IF v_script IS NOT NULL AND NEW.marks + (SELECT COALESCE(sum(marks), 0) FROM exam.question_mark
                                           WHERE exam_registration_id = NEW.exam_registration_id AND question_paper_id = NEW.question_paper_id
                                             AND question_no <> NEW.question_no) > v_script THEN
    RAISE EXCEPTION 'question_mark: the question marks would total more than the script''s % marks', v_script USING ERRCODE = 'check_violation';
  END IF;
  RETURN v_row;
END $$;
CREATE TRIGGER trg_question_mark_validate BEFORE INSERT OR UPDATE OR DELETE ON exam.question_mark
  FOR EACH ROW EXECUTE FUNCTION exam.question_mark_validate();

-- ######################################################## DISCIPLINARY CASES ##

-- A student misconduct case outside the exam hall (unfair means in an exam
-- stays exam.ufm_case): what happened, who reported it, the committee that
-- heard it (an academic body of type DISCIPLINARY_COMMITTEE), the decision and
-- penalty. A suspension must be served as the student's DISCIPLINARY_SUSPENSION
-- study break, linked here. Closed cases are final. The narrative is sensitive:
-- anonymised on erasure (the decision is a retained record) and hidden from analytics.
CREATE TABLE academic.disciplinary_case (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id                uuid NOT NULL REFERENCES people.student(id) ON DELETE CASCADE,
  misconduct_type_id        smallint NOT NULL REFERENCES ref.misconduct_type(id),
  occurred_on               date NOT NULL,
  reported_on               date NOT NULL DEFAULT current_date,
  reported_by_employee_id   uuid NOT NULL REFERENCES people.employee(id),
  description               text NOT NULL CHECK (btrim(description) <> ''),
  academic_body_id          uuid REFERENCES academic.academic_body(id),
  disciplinary_status_id    smallint NOT NULL REFERENCES ref.disciplinary_status(id),
  decided_on                date,
  decision                  text,
  disciplinary_penalty_id   smallint REFERENCES ref.disciplinary_penalty(id),
  study_break_id            uuid UNIQUE REFERENCES academic.study_break(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (reported_on >= occurred_on),
  CHECK (decided_on IS NULL OR decided_on >= reported_on)
);
CREATE INDEX disciplinary_case_student_idx ON academic.disciplinary_case(student_id);
SELECT util.attach_updated_at('academic.disciplinary_case');

CREATE OR REPLACE FUNCTION academic.disciplinary_case_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status record; v_suspension boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND (SELECT is_terminal FROM ref.disciplinary_status WHERE id = OLD.disciplinary_status_id) THEN
    RAISE EXCEPTION 'disciplinary_case: the case is closed' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT is_decided INTO v_status FROM ref.disciplinary_status WHERE id = NEW.disciplinary_status_id;
  IF v_status.is_decided AND (NEW.decided_on IS NULL OR COALESCE(btrim(NEW.decision), '') = '') THEN
    RAISE EXCEPTION 'disciplinary_case: a decided case needs the decision and its date' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_status.is_decided AND (NEW.decided_on IS NOT NULL OR NEW.disciplinary_penalty_id IS NOT NULL) THEN
    RAISE EXCEPTION 'disciplinary_case: no decision or penalty before the case is decided' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.academic_body_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM academic.academic_body b JOIN ref.academic_body_type t ON t.id = b.academic_body_type_id
       WHERE b.id = NEW.academic_body_id AND t.code = 'DISCIPLINARY_COMMITTEE') THEN
    RAISE EXCEPTION 'disciplinary_case: the case must be heard by a disciplinary committee' USING ERRCODE = 'check_violation';
  END IF;
  SELECT requires_suspension INTO v_suspension FROM ref.disciplinary_penalty WHERE id = NEW.disciplinary_penalty_id;
  IF COALESCE(v_suspension, false) AND NOT EXISTS (
       SELECT 1 FROM academic.study_break sb
       JOIN ref.study_break_type bt ON bt.id = sb.study_break_type_id AND bt.code = 'DISCIPLINARY_SUSPENSION'
       JOIN academic.student_enrollment e ON e.id = sb.student_enrollment_id AND e.student_id = NEW.student_id
       WHERE sb.id = NEW.study_break_id) THEN
    RAISE EXCEPTION 'disciplinary_case: a suspension must be recorded as the student''s disciplinary-suspension study break'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_disciplinary_case_validate BEFORE INSERT OR UPDATE ON academic.disciplinary_case
  FOR EACH ROW EXECUTE FUNCTION academic.disciplinary_case_validate();
