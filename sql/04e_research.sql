-- =============================================================================
-- 04e_research.sql — Doctoral and research degrees (schema: research)
--
-- A research scholar is an ordinary student with an ordinary enrollment in a
-- programme of level DOCTORAL (or any programme with a dissertation). Coursework
-- is the programme's curriculum (registrations, results, credits — nothing
-- special). What is specific to research degrees lives here:
--
--   supervision_norm          max scholars per designation (UGC: Prof 8 / Assoc 6 / Asst 4)
--   supervisor_allocation     supervisor / co-supervisor (may be external) over time
--   advisory_committee ─< advisory_committee_member   (RAC / DC: one chair)
--   progress_review           the committee's periodic (six-monthly) review
--   thesis                    topic → synopsis → submission → evaluation → viva
--   thesis_examiner           internal / external examiners and their reports
--   viva                      the open defence and its outcome
--
-- The degree itself is conferred through academic.award_rule / student_award
-- (award type DOCTORATE); for a DOCTORAL programme the database additionally
-- requires an accepted viva before the award.
-- Derived (09_views_functions.sql): research.v_scholar_status.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = research, academic, people, org, ref, public;

-- Maximum number of doctoral scholars a designation may supervise as principal
-- supervisor at one time (POLICY: seeded with the UGC 2022 regulation figures).
CREATE TABLE research.supervision_norm (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  designation_id  smallint NOT NULL REFERENCES people.designation(id),
  max_scholars    smallint NOT NULL CHECK (max_scholars >= 0),
  valid           daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT supervision_norm_one_at_a_time EXCLUDE USING gist (designation_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('research.supervision_norm');

-- Who supervises a scholar, in which role, over time. The supervisor is an
-- employee; a co-supervisor may be an external person (a people.person who is
-- not an employee — from industry or another university). One principal
-- supervisor at a time; the norm for the supervisor's designation is enforced.
CREATE TABLE research.supervisor_allocation (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id    uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  supervisor_role_id       smallint NOT NULL REFERENCES ref.supervisor_role(id),
  employee_id              uuid REFERENCES people.employee(id),
  external_person_id       uuid REFERENCES people.person(id),
  valid                    daterange NOT NULL DEFAULT daterange(current_date, NULL),
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT supervisor_allocation_no_duplicate EXCLUDE USING gist (
    student_enrollment_id WITH =, (COALESCE(employee_id, external_person_id)) WITH =, valid WITH &&)
);
CREATE INDEX supervisor_allocation_employee_idx ON research.supervisor_allocation(employee_id);
SELECT util.attach_updated_at('research.supervisor_allocation');

CREATE OR REPLACE FUNCTION research.supervisor_allocation_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_role record; v_max int; v_designation text; v_active int;
BEGIN
  SELECT code, is_principal, allows_external INTO v_role FROM ref.supervisor_role WHERE id = NEW.supervisor_role_id;
  IF NEW.external_person_id IS NOT NULL THEN
    IF NOT v_role.allows_external THEN
      RAISE EXCEPTION 'supervisor_allocation: role % must be held by an employee', v_role.code USING ERRCODE = 'check_violation';
    END IF;
    IF EXISTS (SELECT 1 FROM people.employee WHERE person_id = NEW.external_person_id) THEN
      RAISE EXCEPTION 'supervisor_allocation: that person is an employee — allocate them by employee_id' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF v_role.is_principal THEN
    IF EXISTS (SELECT 1 FROM research.supervisor_allocation sa JOIN ref.supervisor_role r ON r.id = sa.supervisor_role_id AND r.is_principal
               WHERE sa.student_enrollment_id = NEW.student_enrollment_id AND sa.id <> NEW.id AND sa.valid && NEW.valid) THEN
      RAISE EXCEPTION 'supervisor_allocation: the scholar already has a principal supervisor in this period' USING ERRCODE = 'exclusion_violation';
    END IF;
    -- supervision norm for the supervisor's current designation (doctoral scholars only)
    SELECT n.max_scholars, d.code INTO v_max, v_designation
    FROM people.employee_assignment ea
    JOIN people.designation d ON d.id = ea.designation_id
    JOIN research.supervision_norm n ON n.designation_id = d.id AND n.valid @> lower(NEW.valid)
    WHERE ea.employee_id = NEW.employee_id AND ea.is_primary AND ea.valid @> lower(NEW.valid);
    IF v_max IS NOT NULL THEN
      SELECT count(*) INTO v_active
      FROM research.supervisor_allocation sa
      JOIN ref.supervisor_role r          ON r.id = sa.supervisor_role_id AND r.is_principal
      JOIN academic.student_enrollment e  ON e.id = sa.student_enrollment_id
      JOIN academic.batch b               ON b.id = e.batch_id
      JOIN academic.program p             ON p.id = b.program_id
      JOIN ref.program_level pl           ON pl.id = p.program_level_id AND pl.code = 'DOCTORAL'
      WHERE sa.employee_id = NEW.employee_id AND sa.id <> NEW.id AND sa.valid && NEW.valid;
      IF v_active >= v_max AND EXISTS (
           SELECT 1 FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id
           JOIN academic.program p ON p.id = b.program_id JOIN ref.program_level pl ON pl.id = p.program_level_id AND pl.code = 'DOCTORAL'
           WHERE e.id = NEW.student_enrollment_id) THEN
        RAISE EXCEPTION 'supervisor_allocation: a % may supervise at most % doctoral scholar(s) (already %)', v_designation, v_max, v_active
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_supervisor_allocation_validate BEFORE INSERT OR UPDATE ON research.supervisor_allocation
  FOR EACH ROW EXECUTE FUNCTION research.supervisor_allocation_validate();

-- The Research Advisory / Doctoral Committee of a scholar (one per enrollment)
-- and its dated members: exactly one chair at a time; members are employees or
-- external experts.
CREATE TABLE research.advisory_committee (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id    uuid NOT NULL UNIQUE REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  constituted_on           date NOT NULL DEFAULT current_date,
  approved_by_employee_id  uuid NOT NULL REFERENCES people.employee(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('research.advisory_committee');

CREATE TABLE research.advisory_committee_member (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advisory_committee_id  uuid NOT NULL REFERENCES research.advisory_committee(id) ON DELETE CASCADE,
  committee_role_id      smallint NOT NULL REFERENCES ref.committee_role(id),
  employee_id            uuid REFERENCES people.employee(id),
  external_person_id     uuid REFERENCES people.person(id),
  valid                  daterange NOT NULL DEFAULT daterange(current_date, NULL),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT advisory_committee_member_no_duplicate EXCLUDE USING gist (
    advisory_committee_id WITH =, (COALESCE(employee_id, external_person_id)) WITH =, valid WITH &&)
);

CREATE OR REPLACE FUNCTION research.advisory_committee_member_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT is_chair FROM ref.committee_role WHERE id = NEW.committee_role_id) AND EXISTS (
       SELECT 1 FROM research.advisory_committee_member m JOIN ref.committee_role r ON r.id = m.committee_role_id AND r.is_chair
       WHERE m.advisory_committee_id = NEW.advisory_committee_id AND m.id <> NEW.id AND m.valid && NEW.valid) THEN
    RAISE EXCEPTION 'advisory_committee_member: the committee already has a chair in this period' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_advisory_committee_member_validate BEFORE INSERT OR UPDATE ON research.advisory_committee_member
  FOR EACH ROW EXECUTE FUNCTION research.advisory_committee_member_validate();

-- A periodic progress review by the committee (numbered per scholar).
CREATE TABLE research.progress_review (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id       uuid NOT NULL REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  review_no                   smallint NOT NULL CHECK (review_no >= 1),
  held_on                     date NOT NULL,
  progress_review_outcome_id  smallint NOT NULL REFERENCES ref.progress_review_outcome(id),
  remarks                     text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_enrollment_id, review_no)
);

CREATE OR REPLACE FUNCTION research.progress_review_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM research.advisory_committee WHERE student_enrollment_id = NEW.student_enrollment_id
                                                              AND constituted_on <= NEW.held_on) THEN
    RAISE EXCEPTION 'progress_review: the scholar has no advisory committee constituted by %', NEW.held_on USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_progress_review_validate BEFORE INSERT OR UPDATE ON research.progress_review
  FOR EACH ROW EXECUTE FUNCTION research.progress_review_validate();

-- The thesis of a scholar: title, milestone dates in order, status, plagiarism
-- similarity, the files. Submission needs a principal supervisor on that date.
CREATE TABLE research.thesis (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_enrollment_id     uuid NOT NULL UNIQUE REFERENCES academic.student_enrollment(id) ON DELETE CASCADE,
  title                     text NOT NULL CHECK (btrim(title) <> ''),
  thesis_status_id          smallint NOT NULL REFERENCES ref.thesis_status(id),
  topic_approved_on         date,
  synopsis_submitted_on     date,
  synopsis_approved_on      date,
  thesis_submitted_on       date,
  similarity_pct            numeric(5,2) CHECK (similarity_pct BETWEEN 0 AND 100),   -- plagiarism check result
  synopsis_file_id          uuid REFERENCES people.file_object(id),
  thesis_file_id            uuid REFERENCES people.file_object(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (synopsis_submitted_on IS NULL OR topic_approved_on IS NULL OR synopsis_submitted_on >= topic_approved_on),
  CHECK (synopsis_approved_on  IS NULL OR synopsis_submitted_on IS NOT NULL AND synopsis_approved_on >= synopsis_submitted_on),
  CHECK (thesis_submitted_on   IS NULL OR synopsis_submitted_on IS NULL OR thesis_submitted_on >= synopsis_submitted_on)
);
SELECT util.attach_updated_at('research.thesis');

CREATE OR REPLACE FUNCTION research.thesis_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.thesis_submitted_on IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM research.supervisor_allocation sa JOIN ref.supervisor_role r ON r.id = sa.supervisor_role_id AND r.is_principal
       WHERE sa.student_enrollment_id = NEW.student_enrollment_id AND sa.valid @> NEW.thesis_submitted_on) THEN
    RAISE EXCEPTION 'thesis: no principal supervisor allocated on the submission date' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_thesis_validate BEFORE INSERT OR UPDATE ON research.thesis
  FOR EACH ROW EXECUTE FUNCTION research.thesis_validate();

-- Examiners of a thesis: internal (an employee) or external (a person from
-- another institution). Nobody who supervised the scholar may examine. Report
-- and recommendation are recorded when received.
CREATE TABLE research.thesis_examiner (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thesis_id                   uuid NOT NULL REFERENCES research.thesis(id) ON DELETE CASCADE,
  thesis_examiner_role_id     smallint NOT NULL REFERENCES ref.thesis_examiner_role(id),
  employee_id                 uuid REFERENCES people.employee(id),
  external_person_id          uuid REFERENCES people.person(id),
  appointed_on                date NOT NULL DEFAULT current_date,
  report_received_on          date,
  examiner_recommendation_id  smallint REFERENCES ref.examiner_recommendation(id),
  report_file_id              uuid REFERENCES people.file_object(id),
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(employee_id, external_person_id) = 1),
  CHECK ((report_received_on IS NULL) = (examiner_recommendation_id IS NULL)),
  CHECK (report_received_on IS NULL OR report_received_on >= appointed_on),
  UNIQUE (thesis_id, employee_id),
  UNIQUE (thesis_id, external_person_id)
);
SELECT util.attach_updated_at('research.thesis_examiner');

CREATE OR REPLACE FUNCTION research.thesis_examiner_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_external boolean; v_enrollment uuid; v_person uuid;
BEGIN
  SELECT is_external INTO v_external FROM ref.thesis_examiner_role WHERE id = NEW.thesis_examiner_role_id;
  IF v_external AND NEW.employee_id IS NOT NULL THEN
    RAISE EXCEPTION 'thesis_examiner: an external examiner cannot be an employee' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_external AND NEW.employee_id IS NULL THEN
    RAISE EXCEPTION 'thesis_examiner: an internal examiner must be an employee' USING ERRCODE = 'check_violation';
  END IF;
  SELECT student_enrollment_id INTO v_enrollment FROM research.thesis WHERE id = NEW.thesis_id;
  v_person := COALESCE(NEW.external_person_id, (SELECT person_id FROM people.employee WHERE id = NEW.employee_id));
  IF EXISTS (SELECT 1 FROM research.supervisor_allocation sa
             WHERE sa.student_enrollment_id = v_enrollment
               AND COALESCE(sa.external_person_id, (SELECT person_id FROM people.employee WHERE id = sa.employee_id)) = v_person) THEN
    RAISE EXCEPTION 'thesis_examiner: a supervisor or co-supervisor of the scholar cannot examine the thesis' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_thesis_examiner_validate BEFORE INSERT OR UPDATE ON research.thesis_examiner
  FOR EACH ROW EXECUTE FUNCTION research.thesis_examiner_validate();

-- The viva voce (open defence): only after the thesis is submitted and every
-- examiner's report is in with none recommending rejection.
CREATE TABLE research.viva (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thesis_id                   uuid NOT NULL UNIQUE REFERENCES research.thesis(id) ON DELETE CASCADE,
  held_on                     date NOT NULL,
  start_time                  time,                              -- required when a room is booked (the room hold)
  end_time                    time,
  room_id                     uuid REFERENCES org.room(id),
  examiner_recommendation_id  smallint NOT NULL REFERENCES ref.examiner_recommendation(id),   -- outcome
  remarks                     text,
  approved_by_employee_id     uuid NOT NULL REFERENCES people.employee(id),
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  CHECK ((start_time IS NULL) = (end_time IS NULL) AND (end_time IS NULL OR end_time > start_time)),
  CHECK (room_id IS NULL OR start_time IS NOT NULL)
);
SELECT util.attach_updated_at('research.viva');

CREATE OR REPLACE FUNCTION research.viva_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_submitted date; v_pending int; v_blocking int; v_examiners int;
BEGIN
  SELECT thesis_submitted_on INTO v_submitted FROM research.thesis WHERE id = NEW.thesis_id;
  IF v_submitted IS NULL OR NEW.held_on < v_submitted THEN
    RAISE EXCEPTION 'viva: the thesis has not been submitted before the viva date' USING ERRCODE = 'check_violation';
  END IF;
  SELECT count(*), count(*) FILTER (WHERE te.report_received_on IS NULL), count(*) FILTER (WHERE er.blocks_viva)
    INTO v_examiners, v_pending, v_blocking
  FROM research.thesis_examiner te LEFT JOIN ref.examiner_recommendation er ON er.id = te.examiner_recommendation_id
  WHERE te.thesis_id = NEW.thesis_id;
  IF v_examiners = 0 OR v_pending > 0 THEN
    RAISE EXCEPTION 'viva: % examiner report(s) still pending (% appointed)', v_pending, v_examiners USING ERRCODE = 'check_violation';
  END IF;
  IF v_blocking > 0 THEN
    RAISE EXCEPTION 'viva: an examiner recommended rejection — the thesis must be revised and re-examined first' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_viva_validate BEFORE INSERT OR UPDATE ON research.viva
  FOR EACH ROW EXECUTE FUNCTION research.viva_validate();

-- A doctoral degree is conferred only after an accepted viva (in addition to
-- the credit / required-course checks academic.student_award already makes).
CREATE OR REPLACE FUNCTION research.student_award_requires_viva()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM academic.student_enrollment e JOIN academic.batch b ON b.id = e.batch_id
             JOIN academic.program p ON p.id = b.program_id JOIN ref.program_level pl ON pl.id = p.program_level_id AND pl.code = 'DOCTORAL'
             WHERE e.id = NEW.student_enrollment_id)
     AND NOT EXISTS (SELECT 1 FROM research.viva v JOIN research.thesis t ON t.id = v.thesis_id
                     JOIN ref.examiner_recommendation er ON er.id = v.examiner_recommendation_id AND er.is_accept
                     WHERE t.student_enrollment_id = NEW.student_enrollment_id AND v.held_on <= NEW.conferred_on) THEN
    RAISE EXCEPTION 'student_award: a doctoral degree needs an accepted viva before %', NEW.conferred_on USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_student_award_requires_viva BEFORE INSERT OR UPDATE ON academic.student_award
  FOR EACH ROW EXECUTE FUNCTION research.student_award_requires_viva();
