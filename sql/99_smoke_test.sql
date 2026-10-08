-- =============================================================================
-- 99_smoke_test.sql — End-to-end scenario + negative constraint tests.
-- Runs inside a transaction that is ROLLED BACK (leaves the DB untouched).
--   psql -v ON_ERROR_STOP=1 -f 99_smoke_test.sql
-- Every check prints PASS; the first failure aborts with "FAIL: ...".
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

\set QUIET on
BEGIN;
SET LOCAL client_min_messages = notice;

-- deterministic ids for readability: u('ALICE') is always the same uuid
CREATE FUNCTION pg_temp.u(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5(k)::uuid $$;

CREATE FUNCTION pg_temp.ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF COALESCE(c, false) THEN RAISE NOTICE 'PASS  %', msg;
  ELSE RAISE EXCEPTION 'FAIL: %', msg; END IF;
END $$;

CREATE FUNCTION pg_temp.rejects(q text, msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE q;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'PASS  rejected: % (%)', msg, left(SQLERRM, 90);
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL: expected rejection: %', msg;
END $$;

CREATE FUNCTION pg_temp.lk(t text, c text) RETURNS int LANGUAGE sql STABLE AS $$ SELECT ref.id_of(t, c) $$;

-- ============================================================ org structure ==
INSERT INTO org.org_unit (id, org_unit_type_id, parent_id, code, name) VALUES
 (pg_temp.u('SGTU'), pg_temp.lk('org_unit_type','UNIVERSITY'),         NULL,              'SGTU', 'SGT University'),
 (pg_temp.u('SET'),  pg_temp.lk('org_unit_type','SCHOOL'),             pg_temp.u('SGTU'), 'SET',  'School of Engineering & Technology'),
 (pg_temp.u('CSE'),  pg_temp.lk('org_unit_type','DEPARTMENT'),         pg_temp.u('SET'),  'CSE',  'Computer Science & Engineering'),
 (pg_temp.u('SOM'),  pg_temp.lk('org_unit_type','SCHOOL'),             pg_temp.u('SGTU'), 'SOM',  'School of Management'),
 (pg_temp.u('MBA'),  pg_temp.lk('org_unit_type','DEPARTMENT'),         pg_temp.u('SOM'),  'MBA',  'Department of Management'),
 (pg_temp.u('HR'),   pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('SGTU'), 'HR',   'Human Resources'),
 (pg_temp.u('HR-S1'),pg_temp.lk('org_unit_type','SECTION'),            pg_temp.u('HR'),   'HR-S1','Recruitment Cell'),
 (pg_temp.u('HR-S2'),pg_temp.lk('org_unit_type','SECTION'),            pg_temp.u('HR-S1'),'HR-S2','Onboarding Desk');

SELECT pg_temp.ok((SELECT count(*) = 8 FROM org.v_org_unit_tree), 'org tree view returns all 8 units');
SELECT pg_temp.ok(org.nearest_of_type(pg_temp.u('CSE'), 'SCHOOL') = pg_temp.u('SET'), 'school of CSE derived as SET');

SELECT pg_temp.rejects($q$INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name)
  VALUES (ref.id_of('org_unit_type','DEPARTMENT'), md5('SGTU')::uuid, 'BAD1', 'Dept directly under university')$q$,
  'department directly under university (type rule)');
SELECT pg_temp.rejects($q$UPDATE org.org_unit SET parent_id = md5('HR-S2')::uuid WHERE code = 'HR-S1'$q$,
  'org tree cycle');
SELECT pg_temp.rejects($q$INSERT INTO org.org_unit (org_unit_type_id, code, name)
  VALUES (ref.id_of('org_unit_type','UNIVERSITY'), 'ROOT2', 'Second root')$q$, 'second root unit');

-- ================================================================== people ==
INSERT INTO people.person (id, first_name, last_name) VALUES
 (pg_temp.u('ALICE'), 'Alice', 'Sharma'),   -- professor, HOD CSE
 (pg_temp.u('BOB'),   'Bob',   'Verma'),    -- HR manager
 (pg_temp.u('CAROL'), 'Carol', 'Singh'),    -- student (minor)
 (pg_temp.u('DAVE'),  'Dave',  'Singh'),    -- Carol's father
 (pg_temp.u('EVE'),   'Eve',   'Kapoor');   -- staff given explicit roles

INSERT INTO pii.person_profile (person_id, date_of_birth) VALUES
 (pg_temp.u('ALICE'), '1980-05-01'), (pg_temp.u('CAROL'), (current_date - interval '17 years')::date);
SELECT pg_temp.ok((SELECT is_minor FROM pii.v_person_age WHERE person_id = pg_temp.u('CAROL')), 'Carol derived as minor');
SELECT pg_temp.ok(NOT (SELECT is_minor FROM pii.v_person_age WHERE person_id = pg_temp.u('ALICE')), 'Alice derived as adult');

INSERT INTO pii.person_email (id, person_id, email, contact_purpose_id, is_primary, is_login_enabled, verified_at) VALUES
 (pg_temp.u('ALICE-MAIL'), pg_temp.u('ALICE'), 'alice@sgtuniversity.org', pg_temp.lk('contact_purpose','OFFICIAL'), true, true, now()),
 (pg_temp.u('BOB-MAIL'),   pg_temp.u('BOB'),   'bob@sgtuniversity.org',   pg_temp.lk('contact_purpose','OFFICIAL'), true, true, now());
SELECT pg_temp.rejects($q$INSERT INTO pii.person_email (person_id, email, contact_purpose_id)
  VALUES (md5('EVE')::uuid, 'ALICE@sgtuniversity.org', ref.id_of('contact_purpose','OFFICIAL'))$q$,
  'duplicate email (case-insensitive)');
SELECT pg_temp.rejects($q$INSERT INTO pii.person_email (person_id, email, contact_purpose_id, is_login_enabled)
  VALUES (md5('EVE')::uuid, 'eve@sgtuniversity.org', ref.id_of('contact_purpose','OFFICIAL'), true)$q$,
  'login-enabled email that is not verified');

INSERT INTO people.person_relationship (person_id, related_person_id, relationship_type_id, is_guardian, is_primary_contact)
VALUES (pg_temp.u('CAROL'), pg_temp.u('DAVE'), pg_temp.lk('relationship_type','FATHER'), true, true);

INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on) VALUES
 (pg_temp.u('E-ALICE'), pg_temp.u('ALICE'), 'E1001', pg_temp.lk('employee_category','TEACHING'),     pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2015-07-01'),
 (pg_temp.u('E-BOB'),   pg_temp.u('BOB'),   'E1002', pg_temp.lk('employee_category','NON_TEACHING'), pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2018-01-15'),
 (pg_temp.u('E-EVE'),   pg_temp.u('EVE'),   'E1003', pg_temp.lk('employee_category','NON_TEACHING'), pg_temp.lk('employment_type','CONTRACT'),  pg_temp.lk('employment_status','ACTIVE'), '2024-03-01');

INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid) VALUES
 (pg_temp.u('E-ALICE'), pg_temp.u('CSE'), (SELECT id FROM people.designation WHERE code='PROFESSOR'),       true, daterange('2015-07-01', NULL)),
 (pg_temp.u('E-BOB'),   pg_temp.u('HR'),  (SELECT id FROM people.designation WHERE code='HR_MANAGER'),      true, daterange('2018-01-15', NULL)),
 (pg_temp.u('E-EVE'),   pg_temp.u('HR-S1'),(SELECT id FROM people.designation WHERE code='HR_EXECUTIVE'),   true, daterange('2024-03-01', NULL));
UPDATE people.employee_assignment
  SET job_function_id = pg_temp.lk('job_function','HUMAN_RESOURCES'), job_role_id = pg_temp.lk('job_role','RECRUITMENT')
  WHERE employee_id = pg_temp.u('E-EVE') AND is_primary;
SELECT pg_temp.rejects($q$INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid)
  VALUES (md5('E-ALICE')::uuid, md5('MBA')::uuid, (SELECT id FROM people.designation WHERE code='PROFESSOR'), true, daterange('2020-01-01', NULL))$q$,
  'second overlapping PRIMARY assignment');
-- a secondary (non-primary) concurrent assignment is fine
INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid)
VALUES (pg_temp.u('E-ALICE'), pg_temp.u('MBA'), (SELECT id FROM people.designation WHERE code='ASSOCIATE_PROFESSOR'), false, daterange('2020-01-01','2021-01-01'));
SELECT pg_temp.ok((SELECT school_org_unit_id FROM people.v_employee_current WHERE employee_id = pg_temp.u('E-ALICE')) = pg_temp.u('SET'),
  'employee current view derives school SET for Alice');

INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
VALUES (pg_temp.u('CSE'), (SELECT id FROM org.position_type WHERE code='HEAD'), pg_temp.u('E-ALICE'), daterange('2022-01-01', NULL));
SELECT pg_temp.rejects($q$INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
  VALUES (md5('CSE')::uuid, (SELECT id FROM org.position_type WHERE code='HEAD'), md5('E-BOB')::uuid, daterange('2023-01-01', NULL))$q$,
  'two concurrent HEADs of one unit');
SELECT pg_temp.rejects($q$INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id)
  VALUES (md5('CSE')::uuid, (SELECT id FROM org.position_type WHERE code='DEAN'), md5('E-BOB')::uuid)$q$,
  'DEAN position on a department');

-- ================================================== reporting / reviewing manager ==
-- Eve (HR Executive) reports to Bob (HR Manager) day-to-day, but her
-- appraisal reviewer is Alice — reporting and reviewing lines can differ.
INSERT INTO people.employee_reporting_line (employee_id, manager_employee_id, reporting_line_type_id, valid) VALUES
 (pg_temp.u('E-EVE'), pg_temp.u('E-BOB'),   pg_temp.lk('reporting_line_type','REPORTING'), daterange('2024-03-01', NULL)),
 (pg_temp.u('E-EVE'), pg_temp.u('E-ALICE'), pg_temp.lk('reporting_line_type','REVIEWING'), daterange('2024-03-01', NULL));
SELECT pg_temp.ok((SELECT reporting_manager_employee_id = pg_temp.u('E-BOB') AND reviewing_manager_employee_id = pg_temp.u('E-ALICE')
                          AND job_function_code = 'HUMAN_RESOURCES' AND job_role_code = 'RECRUITMENT'
                   FROM people.v_employee_current WHERE employee_id = pg_temp.u('E-EVE')),
  'reporting manager, reviewing manager, function and role all derived for Eve');
SELECT pg_temp.rejects($q$INSERT INTO people.employee_reporting_line (employee_id, manager_employee_id, reporting_line_type_id)
  VALUES (md5('E-EVE')::uuid, md5('E-EVE')::uuid, ref.id_of('reporting_line_type','REPORTING'))$q$, 'employee cannot report to themselves');
SELECT pg_temp.rejects($q$INSERT INTO people.employee_reporting_line (employee_id, manager_employee_id, reporting_line_type_id)
  VALUES (md5('E-EVE')::uuid, md5('E-ALICE')::uuid, ref.id_of('reporting_line_type','REPORTING'))$q$,
  'a second concurrent reporting manager for the same employee');
SELECT pg_temp.rejects($q$INSERT INTO people.employee_reporting_line (employee_id, manager_employee_id, reporting_line_type_id)
  VALUES (md5('E-BOB')::uuid, md5('E-EVE')::uuid, ref.id_of('reporting_line_type','REPORTING'))$q$,
  'Bob reporting to Eve would create a reporting-chain cycle (Eve already reports to Bob)');

INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
VALUES (pg_temp.u('S-CAROL'), pg_temp.u('CAROL'), 'SGT2026CSE001', pg_temp.lk('student_status','ACTIVE'), '2026-08-01');
INSERT INTO people.student_mentor (student_id, employee_id, valid) VALUES (pg_temp.u('S-CAROL'), pg_temp.u('E-ALICE'), daterange('2026-08-01', NULL));
SELECT pg_temp.rejects($q$INSERT INTO people.student_mentor (student_id, employee_id, valid)
  VALUES (md5('S-CAROL')::uuid, md5('E-BOB')::uuid, daterange('2026-09-01', NULL))$q$, 'two concurrent mentors');

-- ============================================ programmes, calendar, batches ==
INSERT INTO academic.program (id, code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id,
                              delivery_mode_id, duration_terms, min_credits, max_credits) VALUES
 (pg_temp.u('P-BTECH'), 'BTECH-CSE', 'B.Tech Computer Science & Engineering', pg_temp.lk('program_level','UG'),
  pg_temp.lk('academic_calendar_type','SEMESTER'), pg_temp.u('CSE'), pg_temp.lk('delivery_mode','REGULAR'), 8, 160, 180),
 (pg_temp.u('P-MBA'), 'MBA', 'Master of Business Administration', pg_temp.lk('program_level','PG'),
  pg_temp.lk('academic_calendar_type','SEMESTER'), pg_temp.u('MBA'), pg_temp.lk('delivery_mode','REGULAR'), 4, NULL, NULL);
SELECT pg_temp.ok((SELECT duration_years = 4.0 AND school_org_unit_id = pg_temp.u('SET') FROM academic.v_program WHERE program_id = pg_temp.u('P-BTECH')),
  'programme duration in years and school are derived');
SELECT pg_temp.rejects($q$INSERT INTO academic.program (code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id, delivery_mode_id, duration_terms)
  VALUES ('BAD-P', 'Programme run by HR', ref.id_of('program_level','UG'), ref.id_of('academic_calendar_type','SEMESTER'), md5('HR')::uuid, ref.id_of('delivery_mode','REGULAR'), 8)$q$,
  'programme offered by a non-academic unit');
SELECT pg_temp.rejects($q$INSERT INTO academic.program (code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id, delivery_mode_id, duration_terms, min_credits, max_credits)
  VALUES ('BAD-C', 'Bad credits', ref.id_of('program_level','UG'), ref.id_of('academic_calendar_type','SEMESTER'), md5('CSE')::uuid, ref.id_of('delivery_mode','REGULAR'), 8, 200, 100)$q$,
  'min credits greater than max credits');

INSERT INTO academic.specialization (id, program_id, code, name) VALUES
 (pg_temp.u('SP-AI'), pg_temp.u('P-BTECH'), 'AI', 'Artificial Intelligence'),
 (pg_temp.u('SP-DS'), pg_temp.u('P-BTECH'), 'DS', 'Data Science'),
 (pg_temp.u('SP-FIN'), pg_temp.u('P-MBA'), 'FIN', 'Finance');

INSERT INTO academic.program_coordinator (program_id, employee_id) VALUES (pg_temp.u('P-BTECH'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO academic.program_coordinator (program_id, employee_id)
  VALUES (md5('P-BTECH')::uuid, md5('E-BOB')::uuid)$q$, 'two concurrent programme coordinators');

-- calendar relative to today so the test never goes stale:
--   year A = [today-400, today-35)  terms A-ODD [-385,-230)  A-EVEN [-200,-60)
--   year B = [today-35,  today+330) term  B-ODD [-30, +120)
INSERT INTO academic.academic_year (id, code, period) VALUES
 (pg_temp.u('Y-A'), '2025-26', daterange(current_date - 400, current_date - 35)),
 (pg_temp.u('Y-B'), '2026-27', daterange(current_date - 35,  current_date + 330));
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_year (code, period)
  VALUES ('2027-28', daterange(current_date + 300, current_date + 600))$q$, 'overlapping academic years');

INSERT INTO academic.academic_term (academic_year_id, term_cycle_id, period) VALUES
 (pg_temp.u('Y-A'), pg_temp.lk('term_cycle','ODD'),  daterange(current_date - 385, current_date - 230)),
 (pg_temp.u('Y-A'), pg_temp.lk('term_cycle','EVEN'), daterange(current_date - 200, current_date - 60)),
 (pg_temp.u('Y-B'), pg_temp.lk('term_cycle','ODD'),  daterange(current_date - 30,  current_date + 120));
-- an ANNUAL-calendar term may overlap semester terms (different calendar type)
INSERT INTO academic.academic_term (academic_year_id, term_cycle_id, period)
VALUES (pg_temp.u('Y-B'), pg_temp.lk('term_cycle','ANNUAL'), daterange(current_date - 30, current_date + 300));
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_term (academic_year_id, term_cycle_id, period)
  VALUES (md5('Y-B')::uuid, ref.id_of('term_cycle','EVEN'), daterange(current_date + 100, current_date + 250))$q$,
  'overlapping semester terms');
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_term (academic_year_id, term_cycle_id, period)
  VALUES (md5('Y-A')::uuid, ref.id_of('term_cycle','ANNUAL'), daterange(current_date - 390, current_date))$q$,
  'term outside its academic year');
SELECT pg_temp.ok((SELECT count(*) = 2 FROM academic.v_current_term), 'current terms (semester + annual) derived');

INSERT INTO academic.batch (id, program_id, admission_year_id, intake_capacity) VALUES
 (pg_temp.u('B-2025'), pg_temp.u('P-BTECH'), pg_temp.u('Y-A'), 120),
 (pg_temp.u('B-2026'), pg_temp.u('P-BTECH'), pg_temp.u('Y-B'), 120);
SELECT pg_temp.rejects($q$INSERT INTO academic.batch (program_id, admission_year_id) VALUES (md5('P-BTECH')::uuid, md5('Y-B')::uuid)$q$,
  'duplicate batch (programme + admission year)');
SELECT pg_temp.ok((SELECT batch_year = extract(year FROM current_date - 35)::int FROM academic.v_batch WHERE batch_id = pg_temp.u('B-2026')),
  'batch year derived from admission year');

INSERT INTO academic.batch_specialization (batch_id, specialization_id, from_term_no)
VALUES (pg_temp.u('B-2026'), pg_temp.u('SP-AI'), 5);
SELECT pg_temp.rejects($q$INSERT INTO academic.batch_specialization (batch_id, specialization_id)
  VALUES (md5('B-2026')::uuid, md5('SP-FIN')::uuid)$q$, 'batch offered a specialization of another programme');
SELECT pg_temp.rejects($q$INSERT INTO academic.batch_specialization (batch_id, specialization_id, from_term_no)
  VALUES (md5('B-2026')::uuid, md5('SP-DS')::uuid, 9)$q$, 'specialization starting after programme ends');

-- Carol joins the 2026 batch mid-way through its first term; Grace is in the 2025 batch
INSERT INTO academic.student_enrollment (id, student_id, batch_id, valid)
VALUES (pg_temp.u('EN-CAROL'), pg_temp.u('S-CAROL'), pg_temp.u('B-2026'), daterange(current_date - 20, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.student_enrollment (student_id, batch_id, valid)
  VALUES (md5('S-CAROL')::uuid, md5('B-2025')::uuid, daterange(current_date - 5, NULL))$q$, 'two active enrollments');
SELECT pg_temp.rejects($q$UPDATE academic.student_enrollment SET entry_term_no = 9 WHERE id = md5('EN-CAROL')::uuid$q$,
  'entry term beyond programme duration');

INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('GRACE'), 'Grace');
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
VALUES (pg_temp.u('S-GRACE'), pg_temp.u('GRACE'), 'SGT2025CSE042', pg_temp.lk('student_status','ACTIVE'), current_date - 390);
INSERT INTO academic.student_enrollment (student_id, batch_id, valid)
VALUES (pg_temp.u('S-GRACE'), pg_temp.u('B-2025'), daterange(current_date - 390, NULL));

INSERT INTO academic.student_specialization (student_enrollment_id, specialization_id)
VALUES (pg_temp.u('EN-CAROL'), pg_temp.u('SP-AI'));
SELECT pg_temp.rejects($q$INSERT INTO academic.student_specialization (student_enrollment_id, specialization_id, valid)
  VALUES (md5('EN-CAROL')::uuid, md5('SP-DS')::uuid, daterange(current_date + 400, NULL))$q$,
  'specialization not offered to the student''s batch');

SELECT pg_temp.ok((SELECT home_org_unit_id = pg_temp.u('CSE') AND school_org_unit_id = pg_temp.u('SET')
                          AND batch_id = pg_temp.u('B-2026') AND current_term_no = 1
                   FROM people.v_student_current WHERE student_id = pg_temp.u('S-CAROL')),
  'student home dept/school derived from programme; mid-term joiner is in term 1');
SELECT pg_temp.ok((SELECT current_term_no = 3 FROM academic.v_student_enrollment_current WHERE student_id = pg_temp.u('S-GRACE')),
  '2025 batch student is in term 3 (odd, even, odd)');
SELECT pg_temp.ok((SELECT specialization_id = pg_temp.u('SP-AI') FROM academic.v_student_enrollment_current WHERE student_id = pg_temp.u('S-CAROL')),
  'current specialization derived');

-- ================================= curriculum, delivery, attendance, exams ==
CREATE FUNCTION pg_temp.term(y text, c text) RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM academic.academic_term WHERE academic_year_id = md5(y)::uuid AND term_cycle_id = ref.id_of('term_cycle', c) $$;
-- n-th given ISO weekday on/after a date
CREATE FUNCTION pg_temp.nth_dow(p_from date, p_dow int, n int) RETURNS date LANGUAGE sql IMMUTABLE AS $$
  SELECT p_from + ((p_dow - extract(isodow FROM p_from)::int + 7) % 7) + 7 * (n - 1) $$;

-- more people: Frank (faculty), Heidi (2026 batch student)
INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('FRANK'), 'Frank'), (pg_temp.u('HEIDI'), 'Heidi');
INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on)
VALUES (pg_temp.u('E-FRANK'), pg_temp.u('FRANK'), 'E1004', pg_temp.lk('employee_category','TEACHING'),
        pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2019-07-01');
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
VALUES (pg_temp.u('S-HEIDI'), pg_temp.u('HEIDI'), 'SGT2026CSE002', pg_temp.lk('student_status','ACTIVE'), current_date - 20);
INSERT INTO academic.student_enrollment (id, student_id, batch_id, valid)
VALUES (pg_temp.u('EN-HEIDI'), pg_temp.u('S-HEIDI'), pg_temp.u('B-2026'), daterange(current_date - 20, NULL));

-- ---- scheme of examination ----
INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct) VALUES
 (9001, 'THEORY_30_20_50', 'Theory: internal 30 / mid 20 / end 50', 40),
 (9002, 'LAB_60_40', 'Lab: continuous 60 / practical 40', 40);
INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, min_pass_marks) VALUES
 (9001, pg_temp.lk('assessment_type','INTERNAL'), 'Internal assessment', 30, 30, NULL),
 (9001, pg_temp.lk('assessment_type','MID_TERM'), 'Mid-term exam', 20, 50, NULL),
 (9001, pg_temp.lk('assessment_type','END_TERM'), 'End-term exam', 50, 100, 35),
 (9002, pg_temp.lk('assessment_type','LAB_RECORD'), 'Continuous lab', 60, 60, NULL),
 (9002, pg_temp.lk('assessment_type','PRACTICAL'), 'Practical exam', 40, 40, NULL);
SET CONSTRAINTS academic.trg_evaluation_scheme_weights IMMEDIATE;
SET CONSTRAINTS academic.trg_evaluation_scheme_weights DEFERRED;
SELECT pg_temp.ok(true, 'schemes of examination total 100%');
SELECT pg_temp.rejects($q$
  INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct) VALUES (9003, 'BAD', 'Bad', 40);
  INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks)
    VALUES (9003, ref.id_of('assessment_type','END_TERM'), 'End', 60, 100);
  SET CONSTRAINTS academic.trg_evaluation_scheme_weights IMMEDIATE$q$, 'scheme weights not totalling 100%');
SELECT pg_temp.rejects($q$INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks)
  VALUES (9001, ref.id_of('assessment_type','END_TERM'), 'Second end-term', 10, 100)$q$, 'two end-term components in one scheme');

-- ---- course catalogue ----
INSERT INTO academic.course (id, code, title, owner_org_unit_id, credits) VALUES
 (pg_temp.u('C-CS101'), 'CS101', 'Programming Fundamentals', pg_temp.u('CSE'), 4),
 (pg_temp.u('C-CS102'), 'CS102', 'Programming Lab',          pg_temp.u('CSE'), 1),
 (pg_temp.u('C-CS201'), 'CS201', 'Machine Learning',         pg_temp.u('CSE'), 3),
 (pg_temp.u('C-MB101'), 'MB101', 'Principles of Management', pg_temp.u('MBA'), 3);
INSERT INTO academic.course_component_hours (course_id, delivery_component_id, hours_per_week) VALUES
 (pg_temp.u('C-CS101'), pg_temp.lk('delivery_component','LECTURE'), 3),
 (pg_temp.u('C-CS101'), pg_temp.lk('delivery_component','TUTORIAL'), 1),
 (pg_temp.u('C-CS102'), pg_temp.lk('delivery_component','PRACTICAL'), 2),
 (pg_temp.u('C-CS201'), pg_temp.lk('delivery_component','LECTURE'), 3);
SELECT pg_temp.rejects($q$INSERT INTO academic.course (code, title, owner_org_unit_id, credits)
  VALUES ('HR101', 'HR course', md5('HR')::uuid, 2)$q$, 'course owned by a non-academic unit');
INSERT INTO academic.course_prerequisite (course_id, prerequisite_course_id) VALUES (pg_temp.u('C-CS201'), pg_temp.u('C-CS101'));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_prerequisite (course_id, prerequisite_course_id)
  VALUES (md5('C-CS101')::uuid, md5('C-CS201')::uuid)$q$, 'prerequisite cycle');

-- ---- curriculum (scheme of studies) ----
INSERT INTO academic.curriculum (id, program_id, code, name, grade_scale_id, attendance_threshold_pct) VALUES
 (pg_temp.u('CUR-BT'),  pg_temp.u('P-BTECH'), 'R2024', 'B.Tech CSE 2024 regulations', (SELECT id FROM academic.grade_scale WHERE code='UGC_10'), 75),
 (pg_temp.u('CUR-MBA'), pg_temp.u('P-MBA'),   'R2024', 'MBA 2024 regulations',        (SELECT id FROM academic.grade_scale WHERE code='UGC_10'), 75);
INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id) VALUES
 (pg_temp.u('CUR-BT'), 1, pg_temp.u('C-CS101'), pg_temp.lk('course_category','CORE'), 9001),
 (pg_temp.u('CUR-BT'), 1, pg_temp.u('C-CS102'), pg_temp.lk('course_category','LAB'),  9002);
INSERT INTO academic.elective_basket (id, curriculum_id, code, name, term_no, course_category_id, courses_to_choose)
VALUES (pg_temp.u('PE1'), pg_temp.u('CUR-BT'), 'PE-1', 'Programme elective 1', 1, pg_temp.lk('course_category','DISCIPLINE_ELECTIVE'), 1);
INSERT INTO academic.elective_basket_course (elective_basket_id, course_id, evaluation_scheme_id)
VALUES (pg_temp.u('PE1'), pg_temp.u('C-CS201'), 9001);
SELECT pg_temp.rejects($q$INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id)
  VALUES (md5('CUR-BT')::uuid, 9, md5('C-MB101')::uuid, ref.id_of('course_category','CORE'), 9001)$q$, 'curriculum term beyond programme duration');
SELECT pg_temp.rejects($q$INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id)
  VALUES (md5('CUR-BT')::uuid, 2, md5('C-MB101')::uuid, ref.id_of('course_category','OPEN_ELECTIVE'), 9001)$q$, 'elective category used as a fixed course');
SELECT pg_temp.rejects($q$INSERT INTO academic.elective_basket_course (elective_basket_id, course_id, evaluation_scheme_id)
  VALUES (md5('PE1')::uuid, md5('C-CS101')::uuid, 9001)$q$, 'same course twice in one curriculum');
INSERT INTO academic.batch_curriculum (batch_id, curriculum_id) VALUES (pg_temp.u('B-2026'), pg_temp.u('CUR-BT'));
SELECT pg_temp.rejects($q$INSERT INTO academic.batch_curriculum (batch_id, curriculum_id)
  VALUES (md5('B-2025')::uuid, md5('CUR-MBA')::uuid)$q$, 'batch following another programme''s curriculum');

-- ---- offerings, sections, registrations ----
INSERT INTO academic.course_offering (id, course_id, academic_term_id, offering_org_unit_id, intake_limit) VALUES
 (pg_temp.u('O-CS101'), pg_temp.u('C-CS101'), pg_temp.term('Y-B','ODD'), pg_temp.u('CSE'), NULL),
 (pg_temp.u('O-CS102'), pg_temp.u('C-CS102'), pg_temp.term('Y-B','ODD'), pg_temp.u('CSE'), NULL),
 (pg_temp.u('O-CS201'), pg_temp.u('C-CS201'), pg_temp.term('Y-B','ODD'), pg_temp.u('CSE'), 1),
 (pg_temp.u('O-MB101'), pg_temp.u('C-MB101'), pg_temp.term('Y-B','ODD'), pg_temp.u('MBA'), NULL);
SELECT pg_temp.rejects($q$INSERT INTO academic.course_offering (course_id, academic_term_id, offering_org_unit_id)
  VALUES (md5('C-CS101')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-A')::uuid LIMIT 1), md5('HR')::uuid)$q$,
  'course offered by a non-academic unit');

INSERT INTO academic.section (id, batch_id, academic_term_id, code, capacity) VALUES
 (pg_temp.u('SEC-A'), pg_temp.u('B-2026'), pg_temp.term('Y-B','ODD'), 'A', 1),
 (pg_temp.u('SEC-B'), pg_temp.u('B-2026'), pg_temp.term('Y-B','ODD'), 'B', 5);
INSERT INTO academic.section_student (section_id, student_enrollment_id) VALUES (pg_temp.u('SEC-A'), pg_temp.u('EN-CAROL'));
SELECT pg_temp.rejects($q$INSERT INTO academic.section_student (section_id, student_enrollment_id)
  VALUES (md5('SEC-A')::uuid, md5('EN-HEIDI')::uuid)$q$, 'section over capacity');
INSERT INTO academic.section_student (section_id, student_enrollment_id) VALUES (pg_temp.u('SEC-B'), pg_temp.u('EN-HEIDI'));
SELECT pg_temp.rejects($q$INSERT INTO academic.section_student (section_id, student_enrollment_id)
  VALUES (md5('SEC-B')::uuid, md5('EN-CAROL')::uuid)$q$, 'two sections in one term');
SELECT pg_temp.rejects($q$INSERT INTO academic.section_student (section_id, student_enrollment_id)
  VALUES (md5('SEC-B')::uuid, (SELECT id FROM academic.student_enrollment WHERE student_id = md5('S-GRACE')::uuid))$q$,
  'student from another batch in the section');

INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id) VALUES
 (pg_temp.u('R-C-101'), pg_temp.u('EN-CAROL'), pg_temp.u('O-CS101'), pg_temp.lk('registration_status','REGISTERED')),
 (pg_temp.u('R-C-102'), pg_temp.u('EN-CAROL'), pg_temp.u('O-CS102'), pg_temp.lk('registration_status','REGISTERED')),
 (pg_temp.u('R-C-201'), pg_temp.u('EN-CAROL'), pg_temp.u('O-CS201'), pg_temp.lk('registration_status','REGISTERED')),
 (pg_temp.u('R-H-101'), pg_temp.u('EN-HEIDI'), pg_temp.u('O-CS101'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-HEIDI')::uuid, md5('O-CS201')::uuid, ref.id_of('registration_status','REGISTERED'))$q$, 'elective over its intake limit');
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-CAROL')::uuid, md5('O-MB101')::uuid, ref.id_of('registration_status','REGISTERED'))$q$, 'course outside the student''s curriculum');
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES ((SELECT id FROM academic.student_enrollment WHERE student_id = md5('S-GRACE')::uuid), md5('O-CS101')::uuid,
          ref.id_of('registration_status','REGISTERED'))$q$, 'registration when the batch has no curriculum');
SELECT pg_temp.ok((SELECT evaluation_scheme_id = 9001 AND term_no = 1 FROM academic.v_registration_scheme WHERE course_registration_id = pg_temp.u('R-C-201')),
  'elective registration derives its scheme of examination from the basket');

-- ---- faculty assignment ----
INSERT INTO academic.teaching_assignment (id, course_offering_id, section_id, employee_id, delivery_component_id, is_primary, valid) VALUES
 (pg_temp.u('TA-A-L'),   pg_temp.u('O-CS101'), pg_temp.u('SEC-A'), pg_temp.u('E-ALICE'), pg_temp.lk('delivery_component','LECTURE'),   true,
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))),
 (pg_temp.u('TA-F-Lco'), pg_temp.u('O-CS101'), pg_temp.u('SEC-A'), pg_temp.u('E-FRANK'), pg_temp.lk('delivery_component','LECTURE'),   false,
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))),
 (pg_temp.u('TA-A-P'),   pg_temp.u('O-CS102'), pg_temp.u('SEC-A'), pg_temp.u('E-ALICE'), pg_temp.lk('delivery_component','PRACTICAL'), true,
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))),
 (pg_temp.u('TA-F-TA'),  pg_temp.u('O-CS101'), pg_temp.u('SEC-A'), pg_temp.u('E-FRANK'), pg_temp.lk('delivery_component','TUTORIAL'),  true,
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))),
 (pg_temp.u('TA-F-TB'),  pg_temp.u('O-CS101'), pg_temp.u('SEC-B'), pg_temp.u('E-FRANK'), pg_temp.lk('delivery_component','TUTORIAL'),  true,
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, section_id, employee_id, delivery_component_id, is_primary, valid)
  VALUES (md5('O-CS101')::uuid, md5('SEC-A')::uuid, md5('E-BOB')::uuid, ref.id_of('delivery_component','LECTURE'), true,
          (SELECT period FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')))$q$,
  'two primary faculty for the same class');
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, section_id, employee_id, delivery_component_id, valid)
  VALUES (md5('O-CS101')::uuid, md5('SEC-B')::uuid, md5('E-ALICE')::uuid, ref.id_of('delivery_component','PRACTICAL'),
          (SELECT period FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')))$q$,
  'assignment for a component the course has no hours for');
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, section_id, employee_id, delivery_component_id, valid)
  VALUES (md5('O-CS101')::uuid, md5('SEC-B')::uuid, md5('E-ALICE')::uuid, ref.id_of('delivery_component','LECTURE'),
          daterange(current_date - 400, current_date - 300))$q$, 'assignment dated outside its term');

-- ---- timetable ----
INSERT INTO academic.time_slot (id, code, day_of_week, start_time, end_time) VALUES
 (901, 'MON-1', 1, '09:00', '10:00'), (902, 'MON-1H', 1, '09:30', '10:30'),
 (903, 'TUE-1', 2, '09:00', '10:00'), (904, 'WED-1', 3, '09:00', '10:00');
INSERT INTO org.campus (id, code, name) VALUES (pg_temp.u('CAMPUS'), 'MAIN', 'Main campus');
INSERT INTO org.building (id, campus_id, code, name, building_kind_id) VALUES (pg_temp.u('BLDG'), pg_temp.u('CAMPUS'), 'A', 'Block A', pg_temp.lk('building_kind','BUILDING'));
INSERT INTO org.room (id, building_id, code, room_type_id, capacity, exam_capacity) VALUES
 (pg_temp.u('R101'), pg_temp.u('BLDG'), 'A-101', pg_temp.lk('room_type','CLASSROOM'), 60, 2),
 (pg_temp.u('R102'), pg_temp.u('BLDG'), 'A-102', pg_temp.lk('room_type','LAB'), 30, NULL),
 (pg_temp.u('R103'), pg_temp.u('BLDG'), 'A-103', pg_temp.lk('room_type','CLASSROOM'), 60, 40);
INSERT INTO academic.faculty_unavailability (employee_id, day_of_week, start_time, end_time, valid, reason)
VALUES (pg_temp.u('E-FRANK'), 3, '08:00', '12:00', daterange(current_date - 60, NULL), 'Research day');

INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid)
SELECT pg_temp.u(v.k), pg_temp.u(v.ta), v.slot, pg_temp.u(v.room), (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))
FROM (VALUES ('TT-L', 'TA-A-L', 901, 'R101'),      -- Mon 9-10 lecture, sec A, Alice
             ('TT-Lco', 'TA-F-Lco', 901, 'R101'),  -- co-faculty in the same class: allowed
             ('TT-P', 'TA-A-P', 903, 'R102')       -- Tue 9-10 lab, sec A, Alice
     ) v(k, ta, slot, room);
SELECT pg_temp.ok(true, 'co-faculty may share the same class slot and room');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-F-TB')::uuid, 902, md5('R103')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-F-TB')::uuid))$q$,
  'timetable: faculty double-booked (overlapping slot)');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-F-TB')::uuid, 903, md5('R102')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-F-TB')::uuid))$q$,
  'timetable: room double-booked');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-F-TA')::uuid, 903, md5('R103')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-F-TA')::uuid))$q$,
  'timetable: section double-booked');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-F-TB')::uuid, 904, md5('R103')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-F-TB')::uuid))$q$,
  'timetable: faculty marked the slot unavailable');

-- ---- class groups: lab/tutorial batches & elective groups ----
INSERT INTO academic.time_slot (id, code, day_of_week, start_time, end_time) VALUES
 (905, 'THU-1', 4, '09:00', '10:00'), (906, 'FRI-1', 5, '09:00', '10:00');

-- section-wise teaching exists before any groups: Heidi (sec B) has no lecturer yet
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM academic.v_teaching_gap
                          WHERE course_registration_id = pg_temp.u('R-H-101') AND section_id = pg_temp.u('SEC-B')
                            AND delivery_component_id = pg_temp.lk('delivery_component','LECTURE')),
  'teaching gap: sec B students have no CS101 lecturer yet');
SELECT pg_temp.ok((SELECT count(*) = 2 AND bool_and(taught_as = 'SECTION')
                   FROM academic.v_section_teaching
                   WHERE section_id = pg_temp.u('SEC-A') AND course_offering_id = pg_temp.u('O-CS101')
                     AND delivery_component_id = pg_temp.lk('delivery_component','LECTURE')),
  'section-wise teaching: sec A CS101 lecture = Alice (primary) + Frank (co-faculty)');

-- two tutorial batches of section B
INSERT INTO academic.class_group (id, course_offering_id, code, parent_section_id, delivery_component_id, capacity) VALUES
 (pg_temp.u('TB1'), pg_temp.u('O-CS101'), 'B1', pg_temp.u('SEC-B'), pg_temp.lk('delivery_component','TUTORIAL'), 1),
 (pg_temp.u('TB2'), pg_temp.u('O-CS101'), 'B2', pg_temp.u('SEC-B'), pg_temp.lk('delivery_component','TUTORIAL'), 1);
SELECT pg_temp.rejects($q$INSERT INTO academic.class_group (course_offering_id, code, parent_section_id, delivery_component_id, capacity)
  VALUES (md5('O-CS101')::uuid, 'BX', md5('SEC-B')::uuid, ref.id_of('delivery_component','PRACTICAL'), 10)$q$,
  'class group for a component the course has no hours for');
INSERT INTO academic.class_group_member (class_group_id, course_registration_id) VALUES (pg_temp.u('TB1'), pg_temp.u('R-H-101'));
SELECT pg_temp.rejects($q$INSERT INTO academic.class_group_member (class_group_id, course_registration_id)
  VALUES (md5('TB1')::uuid, md5('R-C-101')::uuid)$q$, 'batch member from another section');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_group_member (class_group_id, course_registration_id)
  VALUES (md5('TB2')::uuid, md5('R-H-101')::uuid)$q$, 'student in two batches of the same course component');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_group_member (class_group_id, course_registration_id)
  VALUES (md5('TB1')::uuid, md5('R-C-102')::uuid)$q$, 'batch member not registered for the batch''s course');

INSERT INTO academic.teaching_assignment (id, course_offering_id, class_group_id, employee_id, delivery_component_id, valid) VALUES
 (pg_temp.u('TA-TB1'), pg_temp.u('O-CS101'), pg_temp.u('TB1'), pg_temp.u('E-FRANK'), pg_temp.lk('delivery_component','TUTORIAL'),
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))),
 (pg_temp.u('TA-TB2'), pg_temp.u('O-CS101'), pg_temp.u('TB2'), pg_temp.u('E-BOB'),   pg_temp.lk('delivery_component','TUTORIAL'),
  (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, section_id, class_group_id, employee_id, delivery_component_id, valid)
  VALUES (md5('O-CS101')::uuid, md5('SEC-B')::uuid, md5('TB1')::uuid, md5('E-ALICE')::uuid, ref.id_of('delivery_component','TUTORIAL'),
          (SELECT period FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')))$q$,
  'assignment targeting both a section and a class group');
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, class_group_id, employee_id, delivery_component_id, valid)
  VALUES (md5('O-CS101')::uuid, md5('TB1')::uuid, md5('E-ALICE')::uuid, ref.id_of('delivery_component','LECTURE'),
          (SELECT period FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')))$q$,
  'tutorial batch assigned a lecture');
SELECT pg_temp.rejects($q$INSERT INTO academic.teaching_assignment (course_offering_id, class_group_id, employee_id, delivery_component_id, valid)
  VALUES (md5('O-CS101')::uuid, md5('TB1')::uuid, md5('E-ALICE')::uuid, ref.id_of('delivery_component','TUTORIAL'),
          (SELECT period FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')))$q$,
  'two primary faculty for the same batch');

-- both batches of section B in parallel on Thursday: allowed
INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid)
SELECT pg_temp.u(v.k), pg_temp.u(v.ta), 905, pg_temp.u(v.room), (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))
FROM (VALUES ('TT-TB1', 'TA-TB1', 'R101')) v(k, ta, room);
INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid)
SELECT pg_temp.u('TT-TB2'), pg_temp.u('TA-TB2'), 905, pg_temp.u('R103'), (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'));
SELECT pg_temp.ok(true, 'two batches of one section may run in parallel');

-- section-wise lecturer for section B closes Heidi's gap ...
INSERT INTO academic.teaching_assignment (id, course_offering_id, section_id, employee_id, delivery_component_id, valid)
VALUES (pg_temp.u('TA-E-LB'), pg_temp.u('O-CS101'), pg_temp.u('SEC-B'), pg_temp.u('E-EVE'), pg_temp.lk('delivery_component','LECTURE'),
        (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM academic.v_teaching_gap WHERE course_registration_id = pg_temp.u('R-H-101')),
  'section B lecturer assigned: Heidi has a teacher for every CS101 component');
SELECT pg_temp.ok((SELECT string_agg(taught_as || ':' || COALESCE(class_group_code, '-'), ',' ORDER BY taught_as, class_group_code)
                   FROM academic.v_section_teaching
                   WHERE section_id = pg_temp.u('SEC-B') AND course_offering_id = pg_temp.u('O-CS101'))
                  = 'CLASS_GROUP:B1,CLASS_GROUP:B2,SECTION:-,SECTION:-',
  'section-wise teaching sheet for sec B: lecture to the section, tutorial to the section and to batches B1/B2');
-- ... but the whole section cannot have a lecture while its batch has a tutorial
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-E-LB')::uuid, 905, md5('R102')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-E-LB')::uuid))$q$,
  'timetable: section lecture clashes with its own batch');

-- elective group across batches (no parent section)
INSERT INTO academic.class_group (id, course_offering_id, code, capacity)
VALUES (pg_temp.u('EG1'), pg_temp.u('O-CS201'), 'ML-G1', 60);
INSERT INTO academic.teaching_assignment (id, course_offering_id, class_group_id, employee_id, delivery_component_id, valid)
VALUES (pg_temp.u('TA-EG1'), pg_temp.u('O-CS201'), pg_temp.u('EG1'), pg_temp.u('E-BOB'), pg_temp.lk('delivery_component','LECTURE'),
        (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid)
VALUES (pg_temp.u('TT-EG1'), pg_temp.u('TA-EG1'), 903, pg_temp.u('R103'),
        (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
SELECT pg_temp.rejects($q$INSERT INTO academic.class_group_member (class_group_id, course_registration_id)
  VALUES (md5('EG1')::uuid, md5('R-C-201')::uuid)$q$, 'joining an elective group whose slot clashes with the student''s lab');
UPDATE academic.timetable_entry SET time_slot_id = 906 WHERE id = pg_temp.u('TT-EG1');
INSERT INTO academic.class_group_member (class_group_id, course_registration_id) VALUES (pg_temp.u('EG1'), pg_temp.u('R-C-201'));
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-EG1')::uuid, 901, md5('R103')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-EG1')::uuid))$q$,
  'timetable: elective group slot clashes with a member''s section lecture');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM academic.v_teaching_gap),
  'no teaching gaps: every registered student has a primary teacher for every component');
SELECT pg_temp.ok((SELECT count(*) = 4 FROM academic.v_student_timetable WHERE student_enrollment_id = pg_temp.u('EN-CAROL'))
              AND (SELECT count(*) = 1 FROM academic.v_student_timetable WHERE student_enrollment_id = pg_temp.u('EN-HEIDI')),
  'student timetable follows section, batch and elective-group rosters');

-- batch class session: only batch members can be marked
INSERT INTO academic.class_session (id, timetable_entry_id, session_date, class_session_status_id)
VALUES (pg_temp.u('CS-TB1'), pg_temp.u('TT-TB1'),
        pg_temp.nth_dow(lower((SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))), 4, 1),
        pg_temp.lk('class_session_status','HELD'));
INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id, marked_by_employee_id)
VALUES (pg_temp.u('CS-TB1'), pg_temp.u('R-H-101'), pg_temp.lk('attendance_status','PRESENT'), pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id)
  VALUES (md5('CS-TB1')::uuid, md5('R-C-101')::uuid, ref.id_of('attendance_status','PRESENT'))$q$, 'attendance for a student not in that batch');
SELECT pg_temp.ok((SELECT sessions_held = 1 AND attendance_pct = 100 FROM academic.v_attendance_summary
                   WHERE course_registration_id = pg_temp.u('R-H-101')),
  'batch sessions count toward the member''s course attendance');

-- ---- class sessions & attendance ----
-- four Monday lectures (Carol attends 3) and two Tuesday labs (Carol attends none)
INSERT INTO academic.class_session (id, timetable_entry_id, session_date, class_session_status_id)
SELECT pg_temp.u('CS-L' || n), pg_temp.u('TT-L'),
       pg_temp.nth_dow(lower((SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))), 1, n),
       pg_temp.lk('class_session_status','HELD')
FROM generate_series(1, 4) n;
INSERT INTO academic.class_session (id, timetable_entry_id, session_date, class_session_status_id)
SELECT pg_temp.u('CS-P' || n), pg_temp.u('TT-P'),
       pg_temp.nth_dow(lower((SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))), 2, n),
       pg_temp.lk('class_session_status','HELD')
FROM generate_series(1, 2) n;
INSERT INTO academic.class_session (id, timetable_entry_id, session_date, class_session_status_id)
VALUES (pg_temp.u('CS-L-CANCEL'), pg_temp.u('TT-L'),
        pg_temp.nth_dow(lower((SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))), 1, 5),
        pg_temp.lk('class_session_status','CANCELLED'));
SELECT pg_temp.rejects($q$INSERT INTO academic.class_session (timetable_entry_id, session_date, class_session_status_id)
  VALUES (md5('TT-L')::uuid, (SELECT session_date + 1 FROM academic.class_session WHERE id = md5('CS-L1')::uuid),
          ref.id_of('class_session_status','HELD'))$q$, 'class session on the wrong weekday for its timetable slot');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_session (timetable_entry_id, session_date, start_time, class_session_status_id)
  VALUES (md5('TT-L')::uuid, (SELECT session_date + 7 FROM academic.class_session WHERE id = md5('CS-L4')::uuid), '09:00',
          ref.id_of('class_session_status','HELD'))$q$, 'class session mixing timetable and extra-class shapes');

INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id, marked_by_employee_id)
SELECT pg_temp.u('CS-L' || n), pg_temp.u('R-C-101'),
       CASE WHEN n = 4 THEN pg_temp.lk('attendance_status','ABSENT') ELSE pg_temp.lk('attendance_status','PRESENT') END, pg_temp.u('E-ALICE')
FROM generate_series(1, 4) n;
SELECT pg_temp.rejects($q$INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id)
  VALUES (md5('CS-L1')::uuid, md5('R-H-101')::uuid, ref.id_of('attendance_status','PRESENT'))$q$, 'attendance for a student not in that section');
SELECT pg_temp.rejects($q$INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id)
  VALUES (md5('CS-L-CANCEL')::uuid, md5('R-C-101')::uuid, ref.id_of('attendance_status','PRESENT'))$q$, 'attendance on a cancelled class');
SELECT pg_temp.rejects($q$INSERT INTO academic.attendance (class_session_id, course_registration_id, attendance_status_id)
  VALUES (md5('CS-P1')::uuid, md5('R-C-101')::uuid, ref.id_of('attendance_status','PRESENT'))$q$, 'attendance against the wrong course');
SELECT pg_temp.ok((SELECT sessions_held = 4 AND sessions_attended = 3 AND attendance_pct = 75.00
                   FROM academic.v_attendance_summary WHERE course_registration_id = pg_temp.u('R-C-101')),
  'attendance % derived per course (3 of 4 held classes = 75%)');
SELECT pg_temp.ok((SELECT sessions_held = 2 AND attendance_pct = 0 FROM academic.v_attendance_summary WHERE course_registration_id = pg_temp.u('R-C-102')),
  'unmarked held classes count as absent');

-- ================================================================ exams ====
INSERT INTO exam.exam_session (id, academic_term_id, exam_session_type_id, name, period) VALUES
 (pg_temp.u('XS-END'), pg_temp.term('Y-B','ODD'), pg_temp.lk('exam_session_type','END_TERM'), 'End-term', daterange(current_date + 100, current_date + 115));

-- eligibility
SELECT pg_temp.ok(exam.is_eligible(pg_temp.u('R-C-101')), '75% attendance meets a 75% threshold');
SELECT pg_temp.ok(NOT exam.is_eligible(pg_temp.u('R-C-102')), 'attendance shortage makes a student ineligible');
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id) VALUES
 (pg_temp.u('ER-C-101'), pg_temp.u('XS-END'), pg_temp.u('R-C-101'), pg_temp.lk('exam_attempt_type','REGULAR')),
 (pg_temp.u('ER-H-101'), pg_temp.u('XS-END'), pg_temp.u('R-H-101'), pg_temp.lk('exam_attempt_type','REGULAR'));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
  VALUES (md5('XS-END')::uuid, md5('R-C-102')::uuid, ref.id_of('exam_attempt_type','REGULAR'))$q$, 'exam registration while short of attendance');
INSERT INTO exam.attendance_condonation (course_registration_id, approved_by_employee_id, reason)
VALUES (pg_temp.u('R-C-102'), pg_temp.u('E-ALICE'), 'Hospitalised — medical certificate');
SELECT pg_temp.ok(exam.is_eligible(pg_temp.u('R-C-102')), 'condonation restores eligibility');

INSERT INTO exam.eligibility_hold (id, student_id, academic_term_id, course_offering_id, exam_hold_type_id, reason, placed_by_employee_id)
VALUES (pg_temp.u('HOLD-1'), pg_temp.u('S-CAROL'), pg_temp.term('Y-B','ODD'), pg_temp.u('O-CS201'),
        pg_temp.lk('exam_hold_type','ADMINISTRATIVE'), 'Pending lab clearance', pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
  VALUES (md5('XS-END')::uuid, md5('R-C-201')::uuid, ref.id_of('exam_attempt_type','REGULAR'))$q$, 'exam registration while on hold');
UPDATE exam.eligibility_hold SET released_at = now(), released_by_employee_id = pg_temp.u('E-ALICE') WHERE id = pg_temp.u('HOLD-1');
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('ER-C-201'), pg_temp.u('XS-END'), pg_temp.u('R-C-201'), pg_temp.lk('exam_attempt_type','REGULAR'));
SELECT pg_temp.ok(true, 'released hold allows registration');

-- date sheet. The paper is on a Saturday (the first one from day 101, inside the session window): the term's
-- classes run Monday to Friday in the same rooms, and an exam on a class weekday would correctly displace
-- those classes, making the timetable checks below depend on the day the tests are run.
INSERT INTO exam.exam_schedule (id, exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
VALUES (pg_temp.u('SCH-101'), pg_temp.u('XS-END'), pg_temp.u('O-CS101'), pg_temp.lk('assessment_type','END_TERM'), pg_temp.nth_dow(current_date + 101, 6, 1), '09:00', '12:00');
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_schedule (exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
  VALUES (md5('XS-END')::uuid, md5('O-CS201')::uuid, ref.id_of('assessment_type','END_TERM'), pg_temp.nth_dow(current_date + 101, 6, 1), '10:00', '13:00')$q$,
  'date sheet: a student''s two papers at the same time');
INSERT INTO exam.exam_schedule (id, exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
VALUES (pg_temp.u('SCH-201'), pg_temp.u('XS-END'), pg_temp.u('O-CS201'), pg_temp.lk('assessment_type','END_TERM'), pg_temp.nth_dow(current_date + 101, 6, 2), '09:00', '12:00');   -- the Saturday after
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_schedule (exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
  VALUES (md5('XS-END')::uuid, md5('O-CS101')::uuid, ref.id_of('assessment_type','INTERNAL'), current_date + 104, '09:00', '10:00')$q$,
  'scheduling a continuous-assessment component as an exam');
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_schedule (exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
  VALUES (md5('XS-END')::uuid, md5('O-CS102')::uuid, ref.id_of('assessment_type','END_TERM'), current_date + 200, '09:00', '10:00')$q$,
  'paper dated outside the exam session');

-- rooms, seating, invigilation
INSERT INTO exam.exam_room (exam_schedule_id, room_id) VALUES (pg_temp.u('SCH-101'), pg_temp.u('R101')), (pg_temp.u('SCH-101'), pg_temp.u('R103'));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_room (exam_schedule_id, room_id) VALUES (md5('SCH-101')::uuid, md5('R102')::uuid)$q$,
  'exam in a room that is not an exam venue');
INSERT INTO exam.seat_allocation (exam_schedule_id, exam_registration_id, room_id, seat_no)
VALUES (pg_temp.u('SCH-101'), pg_temp.u('ER-C-101'), pg_temp.u('R101'), '1');
SELECT pg_temp.rejects($q$INSERT INTO exam.seat_allocation (exam_schedule_id, exam_registration_id, room_id, seat_no)
  VALUES (md5('SCH-101')::uuid, md5('ER-H-101')::uuid, md5('R101')::uuid, '1')$q$, 'two students in one seat');
INSERT INTO exam.seat_allocation (exam_schedule_id, exam_registration_id, room_id, seat_no)
VALUES (pg_temp.u('SCH-101'), pg_temp.u('ER-H-101'), pg_temp.u('R101'), '2');
SELECT pg_temp.rejects($q$INSERT INTO exam.seat_allocation (exam_schedule_id, exam_registration_id, room_id, seat_no)
  VALUES (md5('SCH-101')::uuid, md5('ER-C-201')::uuid, md5('R103')::uuid, '5')$q$, 'seating a student for a paper they did not register for');
SELECT pg_temp.ok((SELECT seat_no = '1' AND room_id = pg_temp.u('R101') FROM exam.v_hall_ticket
                   WHERE exam_registration_id = pg_temp.u('ER-C-101') AND exam_schedule_id = pg_temp.u('SCH-101')),
  'hall ticket derived with room and seat');
INSERT INTO exam.invigilation_duty (exam_schedule_id, room_id, employee_id, is_chief)
VALUES (pg_temp.u('SCH-101'), pg_temp.u('R101'), pg_temp.u('E-FRANK'), true);
SELECT pg_temp.rejects($q$INSERT INTO exam.invigilation_duty (exam_schedule_id, room_id, employee_id, is_chief)
  VALUES (md5('SCH-101')::uuid, md5('R101')::uuid, md5('E-BOB')::uuid, true)$q$, 'two chief invigilators in one room');
SELECT pg_temp.rejects($q$INSERT INTO exam.invigilation_duty (exam_schedule_id, room_id, employee_id)
  VALUES (md5('SCH-101')::uuid, md5('R103')::uuid, md5('E-FRANK')::uuid)$q$, 'invigilator in two rooms at once');

-- conduct
INSERT INTO exam.exam_attendance (exam_schedule_id, exam_registration_id, exam_attendance_status_id, marked_by_employee_id) VALUES
 (pg_temp.u('SCH-101'), pg_temp.u('ER-C-101'), pg_temp.lk('exam_attendance_status','PRESENT'), pg_temp.u('E-FRANK')),
 (pg_temp.u('SCH-101'), pg_temp.u('ER-H-101'), pg_temp.lk('exam_attendance_status','ABSENT'),  pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO exam.ufm_case (exam_schedule_id, exam_registration_id, reported_by_employee_id, description, ufm_case_status_id, ufm_penalty_id)
  VALUES (md5('SCH-101')::uuid, md5('ER-C-101')::uuid, md5('E-FRANK')::uuid, 'x', ref.id_of('ufm_case_status','REPORTED'), ref.id_of('ufm_penalty','WARNING'))$q$,
  'unfair-means penalty without a decision');

-- evaluation
INSERT INTO exam.answer_script (id, exam_schedule_id, exam_registration_id, dummy_code)
VALUES (pg_temp.u('AS-C'), pg_temp.u('SCH-101'), pg_temp.u('ER-C-101'), 'D-7F3K');
SELECT pg_temp.rejects($q$INSERT INTO exam.answer_script (exam_schedule_id, exam_registration_id, dummy_code)
  VALUES (md5('SCH-101')::uuid, md5('ER-H-101')::uuid, 'D-XXXX')$q$, 'answer script for an absent student');
INSERT INTO exam.evaluator_assignment (answer_script_id, evaluation_round_id, employee_id) VALUES
 (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','FIRST'), pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO exam.evaluator_assignment (answer_script_id, evaluation_round_id, employee_id)
  VALUES (md5('AS-C')::uuid, ref.id_of('evaluation_round','MODERATION'), md5('E-FRANK')::uuid)$q$, 'same evaluator for first evaluation and moderation');
INSERT INTO exam.evaluator_assignment (answer_script_id, evaluation_round_id, employee_id) VALUES
 (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','MODERATION'), pg_temp.u('E-ALICE'));
INSERT INTO exam.script_mark (answer_script_id, evaluation_round_id, marks) VALUES (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','FIRST'), 70);
SELECT pg_temp.rejects($q$INSERT INTO exam.script_mark (answer_script_id, evaluation_round_id, marks)
  VALUES (md5('AS-C')::uuid, ref.id_of('evaluation_round','REVALUATION'), 80)$q$, 'mark for an evaluation round nobody was assigned');
SELECT pg_temp.rejects($q$UPDATE exam.script_mark SET marks = 150 WHERE answer_script_id = md5('AS-C')::uuid$q$, 'script mark above the maximum');
INSERT INTO exam.script_mark (answer_script_id, evaluation_round_id, marks, note) VALUES (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','MODERATION'), 72, 'Q4 under-marked');
SELECT pg_temp.ok((SELECT marks = 72 AND evaluation_round = 'MODERATION' FROM exam.v_effective_script_mark WHERE answer_script_id = pg_temp.u('AS-C')),
  'moderated mark supersedes first evaluation (no overwrite)');

INSERT INTO exam.component_mark (id, course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
VALUES (pg_temp.u('CM-INT'), pg_temp.u('R-C-101'), (SELECT id FROM academic.evaluation_component WHERE evaluation_scheme_id = 9001 AND name = 'Internal assessment'), 25, pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
  VALUES (md5('R-C-101')::uuid, (SELECT id FROM academic.evaluation_component WHERE evaluation_scheme_id = 9001 AND name = 'Mid-term exam'), 40, md5('E-ALICE')::uuid)$q$,
  'direct entry for a scheduled-exam component');
SELECT pg_temp.rejects($q$INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
  VALUES (md5('R-C-101')::uuid, (SELECT id FROM academic.evaluation_component WHERE evaluation_scheme_id = 9002 AND name = 'Continuous lab'), 40, md5('E-ALICE')::uuid)$q$,
  'marks for a component outside the course''s scheme');

SET LOCAL app.account_id = 'ff000000-0000-0000-0000-000000000002';
UPDATE exam.component_mark SET marks = 26 WHERE id = pg_temp.u('CM-INT');
SELECT pg_temp.ok((SELECT c.old_value = '25.00' AND c.new_value = '26.00'
                   FROM audit.audit_event e JOIN audit.audit_change c ON c.audit_event_id = e.id AND c.occurred_at = e.occurred_at
                   WHERE e.entity_table = 'component_mark' AND c.column_name = 'marks' ORDER BY e.id DESC LIMIT 1),
  'mark changes are visible in the audit trail (retained record, not redacted)');

-- grace, provisional result, publication
INSERT INTO exam.grace_policy (id, code, name, max_marks_per_course, max_courses_per_session) VALUES (901, 'G5x1', 'Up to 5 marks in 1 course', 5, 1);
SELECT pg_temp.rejects($q$INSERT INTO exam.grace_award (exam_registration_id, grace_policy_id, marks, approved_by_employee_id)
  VALUES (md5('ER-C-101')::uuid, 901, 6, md5('E-ALICE')::uuid)$q$, 'grace above the policy limit');
INSERT INTO exam.grace_award (exam_registration_id, grace_policy_id, marks, approved_by_employee_id) VALUES (pg_temp.u('ER-C-101'), 901, 3, pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.grace_award (exam_registration_id, grace_policy_id, marks, approved_by_employee_id)
  VALUES (md5('ER-C-201')::uuid, 901, 2, md5('E-ALICE')::uuid)$q$, 'grace in more courses than the policy allows');
-- internal 26/30×30 = 26, mid-term missing = 0, end-term 72/100×50 = 36, grace 3 → 65 → B+
SELECT pg_temp.ok((SELECT total_pct = 65.00 AND grade_letter = 'B+' AND grade_point = 7 AND is_pass AND components_missing = 1
                   FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-101')),
  'provisional result: weighted scheme + grace → 65% = B+');

INSERT INTO exam.result_publication (id, exam_session_id, publication_type_id, published_by_employee_id)
VALUES (pg_temp.u('PUB-1'), pg_temp.u('XS-END'), pg_temp.lk('publication_type','ORIGINAL'), pg_temp.u('E-ALICE'));
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
SELECT pg_temp.u('PUB-1'), exam_registration_id, total_pct, grade_band_id, pg_temp.lk('result_status','PASS')
FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-101');
SELECT pg_temp.ok((SELECT sgpa = 7.00 FROM exam.v_sgpa WHERE student_enrollment_id = pg_temp.u('EN-CAROL') AND exam_session_id = pg_temp.u('XS-END')),
  'SGPA derived from published results');
SELECT pg_temp.rejects($q$UPDATE exam.course_result SET total_pct = 90 WHERE exam_registration_id = md5('ER-C-101')::uuid$q$, 'editing a published result');
SELECT pg_temp.rejects($q$UPDATE exam.script_mark SET marks = 90 WHERE answer_script_id = md5('AS-C')::uuid$q$, 'editing marks behind a published result');
SELECT pg_temp.rejects($q$UPDATE exam.component_mark SET marks = 30 WHERE id = md5('CM-INT')::uuid$q$, 'editing internal marks behind a published result');
SELECT pg_temp.rejects($q$UPDATE academic.grade_band SET grade_point = 9 WHERE grade_letter = 'B+'
  AND grade_scale_id = (SELECT id FROM academic.grade_scale WHERE code = 'UGC_10')$q$, 'editing a grade band used by a published result');

INSERT INTO exam.marksheet (student_enrollment_id, exam_session_id, serial_no, issued_by_employee_id)
VALUES (pg_temp.u('EN-CAROL'), pg_temp.u('XS-END'), 'SGT/MS/2026/0001', pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.marksheet (student_enrollment_id, exam_session_id, serial_no, issued_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, md5('XS-END')::uuid, 'SGT/MS/2026/0002', md5('E-ALICE')::uuid)$q$, 'second original marksheet');
INSERT INTO exam.marksheet (student_enrollment_id, exam_session_id, serial_no, issued_by_employee_id, is_duplicate)
VALUES (pg_temp.u('EN-CAROL'), pg_temp.u('XS-END'), 'SGT/MS/2026/0003', pg_temp.u('E-ALICE'), true);

-- post-result: revaluation → new round → revised publication
INSERT INTO exam.revaluation_request (answer_script_id, revaluation_type_id, revaluation_status_id)
VALUES (pg_temp.u('AS-C'), pg_temp.lk('revaluation_type','REVALUATION'), pg_temp.lk('revaluation_status','IN_PROGRESS'));
INSERT INTO exam.evaluator_assignment (answer_script_id, evaluation_round_id, employee_id) VALUES
 (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','REVALUATION'), pg_temp.u('E-BOB'));
INSERT INTO exam.script_mark (answer_script_id, evaluation_round_id, marks, note) VALUES (pg_temp.u('AS-C'), pg_temp.lk('evaluation_round','REVALUATION'), 90, 'Revalued');
INSERT INTO exam.result_publication (id, exam_session_id, publication_type_id, published_by_employee_id, published_at)
VALUES (pg_temp.u('PUB-2'), pg_temp.u('XS-END'), pg_temp.lk('publication_type','REVISED'), pg_temp.u('E-ALICE'), now() + interval '1 minute');
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
SELECT pg_temp.u('PUB-2'), exam_registration_id, total_pct, grade_band_id, pg_temp.lk('result_status','PASS')
FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-101');
-- 26 + 0 + 90/100×50 = 45 + 3 → 74 → A
SELECT pg_temp.ok((SELECT grade_letter = 'A' AND total_pct = 74.00 FROM exam.v_current_result WHERE exam_registration_id = pg_temp.u('ER-C-101')),
  'revaluation produces a revised result; original stays on record');
SELECT pg_temp.ok((SELECT count(*) = 2 FROM exam.course_result WHERE exam_registration_id = pg_temp.u('ER-C-101')),
  'both the original and revised results are kept');
SELECT pg_temp.ok((SELECT cgpa = 8.00 FROM exam.v_cgpa WHERE student_enrollment_id = pg_temp.u('EN-CAROL')), 'CGPA follows the revised result');

-- supplementary / re-attempt
INSERT INTO academic.academic_term (academic_year_id, term_cycle_id, period)
VALUES (pg_temp.u('Y-B'), pg_temp.lk('term_cycle','EVEN'), daterange(current_date + 125, current_date + 300));
INSERT INTO exam.exam_session (id, academic_term_id, exam_session_type_id, name, period)
VALUES (pg_temp.u('XS-SUP'), pg_temp.term('Y-B','EVEN'), pg_temp.lk('exam_session_type','SUPPLEMENTARY'), 'Supplementary',
        daterange(current_date + 130, current_date + 140));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
  VALUES (md5('XS-SUP')::uuid, md5('R-C-201')::uuid, ref.id_of('exam_attempt_type','REGULAR'))$q$, 'REGULAR attempt outside the course''s own term');
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('ER-C-201-SUP'), pg_temp.u('XS-SUP'), pg_temp.u('R-C-201'), pg_temp.lk('exam_attempt_type','SUPPLEMENTARY'));
SELECT pg_temp.ok((SELECT attempt_no = 2 FROM exam.v_exam_attempt WHERE exam_registration_id = pg_temp.u('ER-C-201-SUP')),
  'supplementary registration counted as attempt 2');

-- ============================================================ IAM / login ====
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id) VALUES
 (pg_temp.u('A-ALICE'), pg_temp.u('ALICE'), 'E1001',         'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-BOB'),   pg_temp.u('BOB'),   'E1002',         'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-CAROL'), pg_temp.u('CAROL'), 'SGT2026CSE001', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-DAVE'),  pg_temp.u('DAVE'),  'P-DAVE-01',     'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-EVE'),   pg_temp.u('EVE'),   'E1003',         'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE'));

SELECT pg_temp.ok(iam.resolve_login('e1001') = pg_temp.u('A-ALICE'), 'login by UID (case-insensitive)');
SELECT pg_temp.ok(iam.resolve_login('Alice@SGTuniversity.org') = pg_temp.u('A-ALICE'), 'login by verified email');
SELECT pg_temp.ok(iam.resolve_login('nobody@x.org') IS NULL, 'unknown identifier resolves to NULL');

-- MFA
INSERT INTO iam.mfa_factor (id, account_id, mfa_factor_type_id, label, is_default, confirmed_at)
VALUES (pg_temp.u('F-BOB-TOTP'), pg_temp.u('A-BOB'), pg_temp.lk('mfa_factor_type','TOTP'), 'Phone', true, now()),
       (pg_temp.u('F-BOB-OTP'),  pg_temp.u('A-BOB'), pg_temp.lk('mfa_factor_type','EMAIL_OTP'), 'Email', false, now());
INSERT INTO iam.mfa_totp (factor_id, secret_ciphertext) VALUES (pg_temp.u('F-BOB-TOTP'), '\xdeadbeef');
INSERT INTO iam.mfa_otp_channel (factor_id, person_email_id) VALUES (pg_temp.u('F-BOB-OTP'), pg_temp.u('BOB-MAIL'));
SELECT pg_temp.rejects($q$INSERT INTO iam.mfa_webauthn (factor_id, credential_id, public_key)
  VALUES (md5('F-BOB-TOTP')::uuid, '\x01', '\x02')$q$, 'webauthn subtype on a TOTP factor');
SELECT pg_temp.rejects($q$UPDATE iam.mfa_otp_channel SET person_email_id = md5('ALICE-MAIL')::uuid
  WHERE factor_id = md5('F-BOB-OTP')::uuid$q$, 'OTP channel pointing at another person''s email');

-- sessions with refresh rotation
INSERT INTO iam.user_session (account_id, family_id, refresh_token_hash, expires_at)
VALUES (pg_temp.u('A-BOB'), pg_temp.u('FAM1'), digest('t1','sha256'), now() + interval '30 days');
SELECT pg_temp.rejects($q$INSERT INTO iam.user_session (account_id, family_id, refresh_token_hash, expires_at)
  VALUES (md5('A-BOB')::uuid, md5('FAM1')::uuid, digest('t2','sha256'), now() + interval '30 days')$q$,
  'two live tokens in one refresh family');

INSERT INTO iam.auth_event (account_id, auth_event_type_id, ip)
VALUES (pg_temp.u('A-ALICE'), pg_temp.lk('auth_event_type','LOGIN_SUCCESS'), '10.0.0.5');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM iam.v_account_last_login WHERE account_id = pg_temp.u('A-ALICE')),
  'last_login derived from auth_event');

-- ============================================================ authorization ==
-- Alice: HEAD of CSE -> ORG_UNIT_HEAD scoped to CSE subtree; EMPLOYEE_BASE -> SELF_SERVICE
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'core_admin.employee.view', pg_temp.u('CSE')), 'HOD can view employees of own dept');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-ALICE'), 'core_admin.employee.view', pg_temp.u('MBA')), 'HOD cannot view another dept');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-ALICE'), 'core_admin.employee.create', pg_temp.u('CSE')), 'HOD cannot create employees');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'core_admin.batch.view',
                    (SELECT offering_org_unit_id FROM academic.program WHERE id = pg_temp.u('P-BTECH'))),
  'HOD can view batches of programmes run by own dept');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'academics.attendance.create'), 'teaching staff automatically hold FACULTY');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-BOB'), 'academics.attendance.create'), 'non-teaching staff are not FACULTY');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-CAROL'), 'exam.hall_ticket.view'), 'students can view their hall ticket');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-CAROL'), 'exam.result.approve'), 'students cannot publish results');
INSERT INTO authz.account_role (account_id, role_id, reason)
VALUES (pg_temp.u('A-BOB'), (SELECT id FROM authz.role WHERE code='EXAM_CONTROLLER'), 'Exam cell');
SELECT pg_temp.rejects($q$INSERT INTO authz.account_role (account_id, role_id, reason)
  VALUES (md5('A-BOB')::uuid, (SELECT id FROM authz.role WHERE code='EXAM_EVALUATOR'), 'x')$q$,
  'separation of duties: Controller of Examinations cannot also evaluate scripts');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'self_service.profile.view'), 'employee baseline inherits self service');
SELECT pg_temp.ok(NOT authz.account_requires_mfa(pg_temp.u('A-ALICE')), 'Alice not forced to MFA');

-- Bob: designation HR_MANAGER -> HR_ADMIN globally
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-BOB'), 'core_admin.employee.create', pg_temp.u('MBA')), 'HR manager (designation role, global) creates employees anywhere');
SELECT pg_temp.ok(authz.account_requires_mfa(pg_temp.u('A-BOB')), 'HR_ADMIN requires MFA');

-- Carol (student) & Dave (guardian)
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-CAROL'), 'self_service.privacy_rights.create'), 'student baseline self service');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-CAROL'), 'core_admin.student.view'), 'student cannot view students');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-DAVE'), 'self_service.profile.view'), 'guardian baseline derived from relationship');

-- Eve: explicit scoped grant, expired grant, SoD, non-scopable
INSERT INTO authz.account_role (account_id, role_id, scope_org_unit_id, include_descendants, granted_by_account_id, reason)
VALUES (pg_temp.u('A-EVE'), (SELECT id FROM authz.role WHERE code='ACADEMIC_ADMIN'), pg_temp.u('SET'), true, pg_temp.u('A-BOB'), 'SET admissions desk');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-EVE'), 'core_admin.student.create', pg_temp.u('CSE')), 'scoped grant on SET covers CSE (descendant)');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-EVE'), 'core_admin.student.create', pg_temp.u('MBA')), 'scoped grant on SET does not cover MBA');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-EVE'), 'core_admin._module.access'), 'module access (anywhere) granted via scoped role');
SELECT pg_temp.ok((SELECT array_agg(x ORDER BY x) FROM authz.accessible_org_units(pg_temp.u('A-EVE'), 'core_admin.student.create') x)
                  = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[pg_temp.u('SET'), pg_temp.u('CSE')]) x),
  'accessible_org_units = {SET, CSE}');

INSERT INTO authz.account_role (account_id, role_id, valid, reason)
VALUES (pg_temp.u('A-EVE'), (SELECT id FROM authz.role WHERE code='ACCESS_ADMIN'),
        tstzrange(now() - interval '10 days', now() - interval '1 day'), 'temporary cover (expired)');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-EVE'), 'core_admin.account.view'), 'expired grant gives nothing');

INSERT INTO authz.account_role (account_id, role_id, reason)
VALUES (pg_temp.u('A-EVE'), (SELECT id FROM authz.role WHERE code='AUDITOR'), 'internal audit');
SELECT pg_temp.rejects($q$INSERT INTO authz.account_role (account_id, role_id, reason)
  VALUES (md5('A-EVE')::uuid, (SELECT id FROM authz.role WHERE code='CORE_ADMIN'), 'x')$q$,
  'separation of duties AUDITOR vs CORE_ADMIN');
SELECT pg_temp.rejects($q$INSERT INTO authz.account_role (account_id, role_id, reason)
  VALUES (md5('A-EVE')::uuid, (SELECT id FROM authz.role WHERE code='AUDITOR'), 'dup')$q$,
  'duplicate overlapping grant');
SELECT pg_temp.rejects($q$INSERT INTO authz.account_permission (account_id, permission_id, scope_org_unit_id, reason)
  VALUES (md5('A-EVE')::uuid, (SELECT permission_id FROM authz.v_permission_code WHERE code='core_admin.role.view'), md5('SET')::uuid, 'x')$q$,
  'non-scopable permission granted with a scope');
SELECT pg_temp.rejects($q$INSERT INTO authz.role_inheritance (senior_role_id, junior_role_id)
  VALUES ((SELECT id FROM authz.role WHERE code='SELF_SERVICE'), (SELECT id FROM authz.role WHERE code='EMPLOYEE_BASE'))$q$,
  'role inheritance cycle');

-- account status gates everything
UPDATE iam.user_account SET account_status_id = pg_temp.lk('account_status','SUSPENDED') WHERE id = pg_temp.u('A-ALICE');
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-ALICE'), 'self_service.profile.view'), 'suspended account has no permissions');

-- ================================================================== DPDP =====
INSERT INTO privacy.privacy_notice (id, version, language_id, content_sha256, published_at)
VALUES (pg_temp.u('NOTICE-1'), '2026.1', (SELECT id FROM ref.language WHERE code='en'), digest('notice text','sha256'), now());
INSERT INTO privacy.notice_purpose (notice_id, purpose_id)
SELECT pg_temp.u('NOTICE-1'), id FROM privacy.processing_purpose WHERE code IN ('STUDENT_ADMINISTRATION','EMERGENCY_CONTACT');

SELECT pg_temp.rejects($q$INSERT INTO privacy.consent (principal_person_id, notice_id, purpose_id, given_by_person_id, consent_channel_id)
  VALUES (md5('CAROL')::uuid, md5('NOTICE-1')::uuid, (SELECT id FROM privacy.processing_purpose WHERE code='STUDENT_ADMINISTRATION'),
          md5('EVE')::uuid, ref.id_of('consent_channel','WEB'))$q$, 'consent given by a non-guardian');
SELECT pg_temp.rejects($q$INSERT INTO privacy.consent (principal_person_id, notice_id, purpose_id, given_by_person_id, consent_channel_id)
  VALUES (md5('CAROL')::uuid, md5('NOTICE-1')::uuid, (SELECT id FROM privacy.processing_purpose WHERE code='ID_CARD_PHOTO'),
          md5('DAVE')::uuid, ref.id_of('consent_channel','WEB'))$q$, 'consent for a purpose not in the notice');

INSERT INTO privacy.consent (id, principal_person_id, notice_id, purpose_id, given_by_person_id, consent_channel_id)
VALUES (pg_temp.u('C-1'), pg_temp.u('CAROL'), pg_temp.u('NOTICE-1'),
        (SELECT id FROM privacy.processing_purpose WHERE code='STUDENT_ADMINISTRATION'), pg_temp.u('DAVE'), pg_temp.lk('consent_channel','WEB'));
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM privacy.v_minor_consent_gap WHERE person_id = pg_temp.u('CAROL') AND purpose_code = 'STUDENT_ADMINISTRATION'),
  'minor consent gap until guardian verified');
INSERT INTO privacy.verifiable_parental_consent (consent_id, verification_method_id)
VALUES (pg_temp.u('C-1'), pg_temp.lk('verification_method','OTP_TO_GUARDIAN'));
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM privacy.v_minor_consent_gap WHERE person_id = pg_temp.u('CAROL') AND purpose_code = 'STUDENT_ADMINISTRATION'),
  'gap closed after verifiable parental consent');
SELECT pg_temp.rejects($q$INSERT INTO privacy.consent (principal_person_id, notice_id, purpose_id, given_by_person_id, consent_channel_id)
  VALUES (md5('CAROL')::uuid, md5('NOTICE-1')::uuid, (SELECT id FROM privacy.processing_purpose WHERE code='STUDENT_ADMINISTRATION'),
          md5('DAVE')::uuid, ref.id_of('consent_channel','WEB'))$q$, 'second active consent for the same purpose');

INSERT INTO privacy.data_principal_request (id, person_id, dpr_request_type_id, submitted_by_person_id, submitted_at)
VALUES (pg_temp.u('DPR-1'), pg_temp.u('BOB'), pg_temp.lk('dpr_request_type','ACCESS_SUMMARY'), pg_temp.u('BOB'), now() - interval '40 days');
INSERT INTO privacy.dpr_request_event (request_id, dpr_status_id, occurred_at) VALUES
 (pg_temp.u('DPR-1'), pg_temp.lk('dpr_status','SUBMITTED'), now() - interval '40 days'),
 (pg_temp.u('DPR-1'), pg_temp.lk('dpr_status','IN_PROGRESS'), now() - interval '35 days');
SELECT pg_temp.ok((SELECT current_status = 'IN_PROGRESS' AND is_overdue FROM privacy.v_dpr_request_status WHERE request_id = pg_temp.u('DPR-1')),
  'DPR status derived from latest event and flagged overdue');

SELECT pg_temp.rejects($q$INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
  VALUES ('people','person','shoe_size', ref.id_of('data_category','IDENTITY'), ref.id_of('erasure_action','DELETE'))$q$,
  'data_element for a non-existent column');

-- ======================================= NEP 2020 / flexible academics =====

-- ---- (7) configurable result formula ----
-- best 2 of 3 class tests, internal may lead external by at most 30 points,
-- at least 40% in the external part, total rounded UP to whole marks
INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct, max_internal_lead_pct, round_to_step, round_up)
VALUES (9010, 'MINOR_40_60', 'Tests (best 2 of 3) + assignment 40 / practical 60', 40, 30, 1, true);
INSERT INTO academic.evaluation_component_group (id, evaluation_scheme_id, name, best_of) VALUES (9010, 9010, 'Class tests', 2);
INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, component_group_id) VALUES
 (9010, pg_temp.lk('assessment_type','QUIZ'), 'Test 1', 15, 10, 9010),
 (9010, pg_temp.lk('assessment_type','QUIZ'), 'Test 2', 15, 10, 9010),
 (9010, pg_temp.lk('assessment_type','QUIZ'), 'Test 3', 15, 10, 9010),
 (9010, pg_temp.lk('assessment_type','ASSIGNMENT'), 'Assignment', 10, 10, NULL),
 (9010, pg_temp.lk('assessment_type','PRACTICAL'), 'Practical exam', 60, 60, NULL);
INSERT INTO academic.evaluation_part_rule (evaluation_scheme_id, evaluation_part_id, min_pass_pct)
VALUES (9010, pg_temp.lk('evaluation_part','EXTERNAL'), 40);
SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights IMMEDIATE;
SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights DEFERRED;
SELECT pg_temp.ok(true, 'best-of group counts best_of x weight toward the 100%');
SELECT pg_temp.rejects($q$
  INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct) VALUES (9011, 'BAD_GRP1', 'Unequal group', 40);
  INSERT INTO academic.evaluation_component_group (id, evaluation_scheme_id, name, best_of) VALUES (9011, 9011, 'Tests', 1);
  INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, component_group_id) VALUES
    (9011, ref.id_of('assessment_type','QUIZ'), 'T1', 60, 10, 9011), (9011, ref.id_of('assessment_type','QUIZ'), 'T2', 40, 10, 9011),
    (9011, ref.id_of('assessment_type','END_TERM'), 'End', 40, 100, NULL);
  SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights IMMEDIATE$q$,
  'best-of group with unequal component weights');
SELECT pg_temp.rejects($q$
  INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct) VALUES (9012, 'BAD_GRP2', 'Too few', 40);
  INSERT INTO academic.evaluation_component_group (id, evaluation_scheme_id, name, best_of) VALUES (9012, 9012, 'Tests', 3);
  INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, component_group_id) VALUES
    (9012, ref.id_of('assessment_type','QUIZ'), 'T1', 50, 10, 9012), (9012, ref.id_of('assessment_type','QUIZ'), 'T2', 50, 10, 9012);
  SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights IMMEDIATE$q$,
  'best 3 of only 2 components');
SELECT pg_temp.rejects($q$INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, component_group_id)
  VALUES (9001, ref.id_of('assessment_type','QUIZ'), 'Stray test', 15, 10, 9010)$q$, 'component joining another scheme''s best-of group');

-- ---- courses used below ----
INSERT INTO academic.course (id, code, title, owner_org_unit_id, credits) VALUES
 (pg_temp.u('C-MB201'),  'MB201',  'Business Analytics',                          pg_temp.u('MBA'), 3),
 (pg_temp.u('C-CS102N'), 'CS102N', 'Programming Lab (2027 regulations)',          pg_temp.u('CSE'), 1),
 (pg_temp.u('C-CS101N'), 'CS101N', 'Programming Fundamentals (2027 regulations)', pg_temp.u('CSE'), 4);
INSERT INTO academic.course_component_hours (course_id, delivery_component_id, hours_per_week) VALUES
 (pg_temp.u('C-MB201'), pg_temp.lk('delivery_component','LECTURE'), 3),
 (pg_temp.u('C-CS102N'), pg_temp.lk('delivery_component','PRACTICAL'), 2);
INSERT INTO academic.course_offering (id, course_id, academic_term_id, offering_org_unit_id) VALUES
 (pg_temp.u('O-MB201'),  pg_temp.u('C-MB201'),  pg_temp.term('Y-B','ODD'),  pg_temp.u('MBA')),
 (pg_temp.u('O-CS102N'), pg_temp.u('C-CS102N'), pg_temp.term('Y-B','EVEN'), pg_temp.u('CSE'));

-- ---- (4) minors & honours ----
INSERT INTO academic.track (id, code, name, track_type_id, offering_org_unit_id, program_id, min_credits, min_cgpa_to_join) VALUES
 (pg_temp.u('T-MIN-BA'), 'MINOR-BA', 'Minor in Business Analytics', pg_temp.lk('track_type','MINOR'),   pg_temp.u('MBA'), NULL, 6, 6),
 (pg_temp.u('T-MIN-CS'), 'MINOR-CS', 'Minor in Computing',          pg_temp.lk('track_type','MINOR'),   pg_temp.u('CSE'), NULL, 6, NULL),
 (pg_temp.u('T-HON-CS'), 'HON-CSE',  'B.Tech CSE (Honours)',        pg_temp.lk('track_type','HONOURS'), pg_temp.u('CSE'), pg_temp.u('P-BTECH'), 18, 9);
SELECT pg_temp.rejects($q$INSERT INTO academic.track (code, name, track_type_id, offering_org_unit_id, min_credits)
  VALUES ('HON-X', 'Honours without programme', ref.id_of('track_type','HONOURS'), md5('CSE')::uuid, 18)$q$,
  'honours track not tied to a programme');
INSERT INTO academic.track_course (track_id, course_id, course_category_id, evaluation_scheme_id)
VALUES (pg_temp.u('T-MIN-BA'), pg_temp.u('C-MB201'), pg_temp.lk('course_category','MINOR'), 9010);
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-CAROL')::uuid, md5('O-MB201')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'minor course before joining the minor');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_track (student_enrollment_id, track_id)
  VALUES (md5('EN-CAROL')::uuid, md5('T-MIN-CS')::uuid)$q$, 'minor in the student''s own discipline');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_track (student_enrollment_id, track_id)
  VALUES (md5('EN-CAROL')::uuid, md5('T-HON-CS')::uuid)$q$, 'honours track below its CGPA entry bar (8.00 < 9)');
INSERT INTO academic.student_track (id, student_enrollment_id, track_id) VALUES (pg_temp.u('ST-C-BA'), pg_temp.u('EN-CAROL'), pg_temp.u('T-MIN-BA'));
INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id)
VALUES (pg_temp.u('R-C-MB201'), pg_temp.u('EN-CAROL'), pg_temp.u('O-MB201'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.ok((SELECT evaluation_scheme_id = 9010 AND track_id = pg_temp.u('T-MIN-BA')
                          AND course_category_id = pg_temp.lk('course_category','MINOR')
                   FROM academic.v_registration_scheme WHERE course_registration_id = pg_temp.u('R-C-MB201')),
  'minor course takes its scheme and category from the track');

-- the minor course's exam, under the configurable scheme
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('ER-C-MB201'), pg_temp.u('XS-END'), pg_temp.u('R-C-MB201'), pg_temp.lk('exam_attempt_type','REGULAR'));
INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
SELECT pg_temp.u('R-C-MB201'), ec.id, v.m, pg_temp.u('E-ALICE')
FROM (VALUES ('Test 1', 9), ('Test 2', 4), ('Test 3', 7), ('Assignment', 10), ('Practical exam', 20)) v(n, m)
JOIN academic.evaluation_component ec ON ec.evaluation_scheme_id = 9010 AND ec.name = v.n;
-- tests: best 9 & 7 → 24, assignment 10 → internal 34/40 = 85%; practical 20/60 → external 33.33%
-- internal leads by 51.67 > 30 → capped at 63.33% → -8.67; 34 + 20 - 8.67 = 45.33 → round up 46
SELECT pg_temp.ok((SELECT NOT is_pass AND total_pct = 46 AND external_pct = 33.33 AND internal_adjustment = -8.67 AND NOT parts_passed
                   FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-MB201')),
  'result formula: best 2 of 3, internal-lead cap, round up → 46%, yet FAIL (external 33% < 40% part minimum)');
UPDATE exam.component_mark SET marks = 24
WHERE course_registration_id = pg_temp.u('R-C-MB201')
  AND evaluation_component_id = (SELECT id FROM academic.evaluation_component WHERE evaluation_scheme_id = 9010 AND name = 'Practical exam');
INSERT INTO exam.result_moderation (exam_session_id, course_offering_id, add_pct, reason, approved_by_employee_id)
VALUES (pg_temp.u('XS-END'), pg_temp.u('O-MB201'), 2.5, 'Paper set above the syllabus level', pg_temp.u('E-ALICE'));
-- external 40%; internal 85% capped at 70% → -6; 34 + 24 - 6 = 52 + moderation 2.5 = 54.5 → round up 55 = B
SELECT pg_temp.ok((SELECT is_pass AND total_pct = 55 AND grade_letter = 'B' AND moderation_pct = 2.5 AND internal_adjustment = -6
                   FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-MB201')),
  'result formula: + board moderation 2.5 → 54.5 → rounded up to 55% = B, pass');
INSERT INTO exam.result_publication (id, exam_session_id, publication_type_id, published_by_employee_id)
VALUES (pg_temp.u('PUB-3'), pg_temp.u('XS-END'), pg_temp.lk('publication_type','ORIGINAL'), pg_temp.u('E-ALICE'));
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
SELECT pg_temp.u('PUB-3'), exam_registration_id, total_pct, grade_band_id, pg_temp.lk('result_status','PASS')
FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-C-MB201');
SELECT pg_temp.rejects($q$UPDATE exam.result_moderation SET add_pct = 5 WHERE course_offering_id = md5('O-MB201')::uuid$q$,
  'changing moderation after the results are published');
SELECT pg_temp.ok((SELECT credits_earned = 3 AND NOT is_complete FROM academic.v_student_track_progress
                   WHERE student_track_id = pg_temp.u('ST-C-BA')), 'minor progress: 3 of 6 credits, not yet complete');
SELECT pg_temp.ok((SELECT cgpa = 8.00 FROM exam.v_cgpa WHERE student_enrollment_id = pg_temp.u('EN-CAROL')),
  'minor grades stay out of the CGPA (track rule)');

-- ---- (5) course equivalence ----
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-CAROL')::uuid, md5('O-CS102N')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'new-regulation course that is not (yet) an approved equivalent');
INSERT INTO academic.course_equivalence (course_id, equivalent_course_id, approved_by_employee_id) VALUES
 (pg_temp.u('C-CS102'),  pg_temp.u('C-CS102N'), pg_temp.u('E-ALICE')),   -- backlog: new lab counts as old
 (pg_temp.u('C-CS101N'), pg_temp.u('C-CS101'),  pg_temp.u('E-ALICE'));   -- old theory counts toward the new course
SELECT pg_temp.rejects($q$INSERT INTO academic.course_equivalence (course_id, equivalent_course_id, approved_by_employee_id)
  VALUES (md5('C-CS101')::uuid, md5('C-CS101')::uuid, md5('E-ALICE')::uuid)$q$, 'course equivalent to itself');
INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id)
VALUES (pg_temp.u('R-C-102N'), pg_temp.u('EN-CAROL'), pg_temp.u('O-CS102N'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.ok((SELECT counts_as_course_id = pg_temp.u('C-CS102') AND evaluation_scheme_id = 9002 AND term_no = 1
                   FROM academic.v_registration_scheme WHERE course_registration_id = pg_temp.u('R-C-102N')),
  'backlog on a replaced course: the equivalent is assessed under the student''s own regulation');
SELECT pg_temp.ok((SELECT completed_via = 'EQUIVALENT' AND via_course_id = pg_temp.u('C-CS101') FROM academic.v_course_completion
                   WHERE student_enrollment_id = pg_temp.u('EN-CAROL') AND course_id = pg_temp.u('C-CS101N')),
  'passing the old course completes its new-regulation equivalent');

-- ---- (2)(3) Academic Bank of Credits & MOOC credit transfer ----
INSERT INTO pii.person_identity_document (person_id, id_document_type_id, number_ciphertext, number_hmac, number_last4)
VALUES (pg_temp.u('CAROL'), pg_temp.lk('id_document_type','APAAR_ID'), '\x00', digest('APAAR-123456789012', 'sha256'), '9012');
SELECT pg_temp.ok(true, 'APAAR / ABC ID stored as an encrypted identity document (pii schema)');
INSERT INTO academic.course_prerequisite (course_id, prerequisite_course_id) VALUES (pg_temp.u('C-CS102N'), pg_temp.u('C-CS201'));
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM academic.v_prerequisite_gap WHERE course_registration_id = pg_temp.u('R-C-102N')),
  'prerequisite gap: CS201 not yet completed');
UPDATE academic.curriculum SET max_transfer_credit_pct = 20 WHERE id = pg_temp.u('CUR-BT');   -- 20% of 160 = 32 credits
INSERT INTO academic.external_provider (id, code, name, external_provider_type_id)
VALUES (pg_temp.u('XP-NPTEL'), 'NPTEL', 'NPTEL (SWAYAM)', pg_temp.lk('external_provider_type','MOOC_PLATFORM'));
INSERT INTO academic.external_course (id, external_provider_id, code, title, credits, duration_weeks) VALUES
 (pg_temp.u('XC-ML'),  pg_temp.u('XP-NPTEL'), 'noc26-cs45', 'Introduction to Machine Learning', 3, 12),
 (pg_temp.u('XC-DS'),  pg_temp.u('XP-NPTEL'), 'noc26-cs10', 'Data Structures', 3, 12),
 (pg_temp.u('XC-BIG'), pg_temp.u('XP-NPTEL'), 'noc26-xx99', 'Year-long specialisation', 30, 52);
INSERT INTO academic.external_course_mapping (external_course_id, course_id, course_category_id, valid, approved_by_employee_id) VALUES
 (pg_temp.u('XC-ML'),  pg_temp.u('C-CS201'), NULL, daterange(current_date - 365, NULL), pg_temp.u('E-ALICE')),
 (pg_temp.u('XC-BIG'), NULL, pg_temp.lk('course_category','DISCIPLINE_ELECTIVE'), daterange(current_date - 365, NULL), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO academic.external_course_mapping (external_course_id, course_id, course_category_id, valid, approved_by_employee_id)
  VALUES (md5('XC-DS')::uuid, md5('C-CS101')::uuid, ref.id_of('course_category','CORE'), daterange(current_date, NULL), md5('E-ALICE')::uuid)$q$,
  'external course mapped to a course AND a category');
SELECT pg_temp.rejects($q$INSERT INTO academic.external_course_mapping (external_course_id, course_id, valid, approved_by_employee_id)
  VALUES (md5('XC-ML')::uuid, md5('C-CS101')::uuid, daterange(current_date, NULL), md5('E-ALICE')::uuid)$q$,
  'two overlapping mappings for one external course');
INSERT INTO academic.credit_transfer (id, student_enrollment_id, external_course_id, completed_on, grade_point, abc_reference, credit_transfer_status_id)
VALUES (pg_temp.u('CT-ML'), pg_temp.u('EN-CAROL'), pg_temp.u('XC-ML'), current_date - 10, 9, 'ABC-TXN-0001', pg_temp.lk('credit_transfer_status','SUBMITTED'));
SELECT pg_temp.rejects($q$UPDATE academic.credit_transfer SET credit_transfer_status_id = ref.id_of('credit_transfer_status','APPROVED')
  WHERE id = md5('CT-ML')::uuid$q$, 'accepting a credit transfer without an approver');
UPDATE academic.credit_transfer
SET credit_transfer_status_id = pg_temp.lk('credit_transfer_status','APPROVED'), decided_by_employee_id = pg_temp.u('E-ALICE'), decided_at = now()
WHERE id = pg_temp.u('CT-ML');
SELECT pg_temp.rejects($q$INSERT INTO academic.credit_transfer (student_enrollment_id, external_course_id, completed_on, credit_transfer_status_id, decided_by_employee_id, decided_at)
  VALUES (md5('EN-CAROL')::uuid, md5('XC-DS')::uuid, current_date - 5, ref.id_of('credit_transfer_status','APPROVED'), md5('E-ALICE')::uuid, now())$q$,
  'accepting credits for an external course with no approved mapping');
SELECT pg_temp.rejects($q$INSERT INTO academic.credit_transfer (student_enrollment_id, external_course_id, completed_on, credit_transfer_status_id, decided_by_employee_id, decided_at)
  VALUES (md5('EN-CAROL')::uuid, md5('XC-BIG')::uuid, current_date - 5, ref.id_of('credit_transfer_status','APPROVED'), md5('E-ALICE')::uuid, now())$q$,
  'transferred credits beyond the curriculum cap (3 + 30 > 32)');
SELECT pg_temp.rejects($q$INSERT INTO academic.credit_transfer (student_enrollment_id, external_course_id, completed_on, grade_point, credit_transfer_status_id)
  VALUES (md5('EN-CAROL')::uuid, md5('XC-DS')::uuid, current_date - 5, 11, ref.id_of('credit_transfer_status','SUBMITTED'))$q$,
  'converted grade point above the scale maximum');
SELECT pg_temp.ok((SELECT completed_via = 'CREDIT_TRANSFER' FROM academic.v_course_completion
                   WHERE student_enrollment_id = pg_temp.u('EN-CAROL') AND course_id = pg_temp.u('C-CS201')),
  'NPTEL credits complete the mapped course (CS201)');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM academic.v_prerequisite_gap WHERE course_registration_id = pg_temp.u('R-C-102N')),
  'prerequisite met through transferred credits');
SELECT pg_temp.ok((SELECT cgpa = 8.43 AND credits_earned = 7 FROM exam.v_cgpa WHERE student_enrollment_id = pg_temp.u('EN-CAROL')),
  'CGPA and credits include transferred credits: (8x4 + 9x3) / 7 = 8.43');

-- ---- (6) fortnightly / alternate-week classes ----
INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid, repeat_every_weeks)
VALUES (pg_temp.u('TT-FA'), pg_temp.u('TA-TB1'), 906, pg_temp.u('R101'),
        (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')), 2);
INSERT INTO academic.timetable_entry (id, teaching_assignment_id, time_slot_id, room_id, valid, repeat_every_weeks)
VALUES (pg_temp.u('TT-FB'), pg_temp.u('TA-F-TB'), 906, pg_temp.u('R101'),
        (SELECT daterange(lower(period) + 7, upper(period)) FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')), 2);
SELECT pg_temp.ok(true, 'fortnightly classes on alternate weeks share faculty, room and slot');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid, repeat_every_weeks)
  VALUES (md5('TA-A-P')::uuid, 906, md5('R101')::uuid,
          (SELECT valid FROM academic.timetable_entry WHERE id = md5('TT-FA')::uuid), 2)$q$,
  'fortnightly class in the same weeks and room as another');
INSERT INTO academic.class_session (timetable_entry_id, session_date, class_session_status_id)
SELECT pg_temp.u('TT-FA'), date_trunc('week', lower(valid))::date + 4 + 14, pg_temp.lk('class_session_status','SCHEDULED')
FROM academic.timetable_entry WHERE id = pg_temp.u('TT-FA');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_session (timetable_entry_id, session_date, class_session_status_id)
  SELECT id, date_trunc('week', lower(valid))::date + 4 + 7, ref.id_of('class_session_status','SCHEDULED')
  FROM academic.timetable_entry WHERE id = md5('TT-FA')::uuid$q$, 'class session on an off week of a fortnightly class');

-- ---- (1) multiple entry & exit ----
INSERT INTO academic.award_rule (id, curriculum_id, award_type_id, award_title, after_term_no, min_credits, reentry_within_years) VALUES
 (pg_temp.u('AR-CERT'), pg_temp.u('CUR-BT'), pg_temp.lk('award_type','UG_CERTIFICATE'), 'UG Certificate in Computer Science', 2, 7, 3),
 (pg_temp.u('AR-DIP'),  pg_temp.u('CUR-BT'), pg_temp.lk('award_type','UG_DIPLOMA'),     'UG Diploma in Computer Science',     4, 20, 3),
 (pg_temp.u('AR-DEG'),  pg_temp.u('CUR-BT'), pg_temp.lk('award_type','BACHELOR'),       'B.Tech (Computer Science & Engineering)', 8, 160, NULL);
INSERT INTO academic.award_rule_course (award_rule_id, course_id) VALUES (pg_temp.u('AR-CERT'), pg_temp.u('C-CS101'));
SELECT pg_temp.rejects($q$INSERT INTO academic.award_rule (curriculum_id, award_type_id, award_title, after_term_no, min_credits)
  VALUES (md5('CUR-BT')::uuid, ref.id_of('award_type','BACHELOR_HONOURS'), 'Honours', 9, 180)$q$, 'exit point beyond the programme duration');
SELECT pg_temp.ok((SELECT is_eligible FROM academic.v_award_eligibility WHERE student_enrollment_id = pg_temp.u('EN-CAROL') AND award_rule_id = pg_temp.u('AR-CERT'))
              AND NOT (SELECT is_eligible FROM academic.v_award_eligibility WHERE student_enrollment_id = pg_temp.u('EN-CAROL') AND award_rule_id = pg_temp.u('AR-DIP')),
  'exit eligibility: 7 credits + CS101 qualify for the UG certificate, not the diploma');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_award (student_enrollment_id, award_rule_id, conferred_on, approved_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, md5('AR-CERT')::uuid, current_date + 1, md5('E-ALICE')::uuid)$q$, 'award while the enrollment is still open');
UPDATE academic.student_enrollment SET valid = daterange(lower(valid), current_date + 1), end_reason_id = pg_temp.lk('enrollment_end_reason','AWARD')
WHERE id = pg_temp.u('EN-CAROL');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_award (student_enrollment_id, award_rule_id, conferred_on, approved_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, md5('AR-DIP')::uuid, current_date + 1, md5('E-ALICE')::uuid)$q$, 'diploma exit without enough credits');
INSERT INTO academic.student_award (id, student_enrollment_id, award_rule_id, conferred_on, approved_by_employee_id)
VALUES (pg_temp.u('SA-CAROL'), pg_temp.u('EN-CAROL'), pg_temp.u('AR-CERT'), current_date + 1, pg_temp.u('E-ALICE'));

-- re-entry about two years later into term 3 of a later batch
INSERT INTO academic.academic_year (id, code, period) VALUES (pg_temp.u('Y-R'), '2028-29', daterange(current_date + 695, current_date + 1060));
INSERT INTO academic.batch (id, program_id, admission_year_id, intake_capacity) VALUES (pg_temp.u('B-2028'), pg_temp.u('P-BTECH'), pg_temp.u('Y-R'), 120);
INSERT INTO academic.batch_curriculum (batch_id, curriculum_id) VALUES (pg_temp.u('B-2028'), pg_temp.u('CUR-BT'));
INSERT INTO academic.student_enrollment (id, student_id, batch_id, entry_term_no, valid)
VALUES (pg_temp.u('EN-CAROL-2'), pg_temp.u('S-CAROL'), pg_temp.u('B-2028'), 2, daterange(current_date + 695, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.enrollment_reentry (student_enrollment_id, student_award_id, approved_by_employee_id)
  VALUES (md5('EN-CAROL-2')::uuid, md5('SA-CAROL')::uuid, md5('E-ALICE')::uuid)$q$, 're-entry into the wrong term (exit after term 2 → enter term 3)');
UPDATE academic.student_enrollment SET entry_term_no = 3 WHERE id = pg_temp.u('EN-CAROL-2');
UPDATE academic.award_rule SET reentry_within_years = 1 WHERE id = pg_temp.u('AR-CERT');
SELECT pg_temp.rejects($q$INSERT INTO academic.enrollment_reentry (student_enrollment_id, student_award_id, approved_by_employee_id)
  VALUES (md5('EN-CAROL-2')::uuid, md5('SA-CAROL')::uuid, md5('E-ALICE')::uuid)$q$, 're-entry after the award''s re-entry window');
UPDATE academic.award_rule SET reentry_within_years = 3 WHERE id = pg_temp.u('AR-CERT');
INSERT INTO academic.enrollment_reentry (student_enrollment_id, student_award_id, approved_by_employee_id)
VALUES (pg_temp.u('EN-CAROL-2'), pg_temp.u('SA-CAROL'), pg_temp.u('E-ALICE'));
SELECT pg_temp.ok((SELECT credits_earned = 7 AND cgpa = 8.43 FROM exam.v_cgpa WHERE student_enrollment_id = pg_temp.u('EN-CAROL-2')),
  're-entering student keeps the credits and CGPA earned before the exit');
SELECT pg_temp.ok((SELECT completed_via = 'PASSED' FROM academic.v_course_completion
                   WHERE student_enrollment_id = pg_temp.u('EN-CAROL-2') AND course_id = pg_temp.u('C-CS101')),
  'courses completed before the exit count after re-entry');

-- ============================ term set-up: sections & core registration =====
-- two more 2026-batch students
INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('IVAN'), 'Ivan'), (pg_temp.u('JUDY'), 'Judy');
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on) VALUES
 (pg_temp.u('S-IVAN'), pg_temp.u('IVAN'), 'SGT2026CSE003', pg_temp.lk('student_status','ACTIVE'), current_date - 20),
 (pg_temp.u('S-JUDY'), pg_temp.u('JUDY'), 'SGT2026CSE004', pg_temp.lk('student_status','ACTIVE'), current_date - 20);
INSERT INTO academic.student_enrollment (id, student_id, batch_id, valid) VALUES
 (pg_temp.u('EN-IVAN'), pg_temp.u('S-IVAN'), pg_temp.u('B-2026'), daterange(current_date - 20, NULL)),
 (pg_temp.u('EN-JUDY'), pg_temp.u('S-JUDY'), pg_temp.u('B-2026'), daterange(current_date - 20, NULL));
SELECT pg_temp.ok(academic.enrollment_term_no(pg_temp.u('EN-IVAN'), pg_temp.term('Y-B','ODD')) = 1
              AND academic.enrollment_term_no(pg_temp.u('EN-IVAN'), pg_temp.term('Y-B','EVEN')) = 2,
  'programme term number derived per academic term (odd = term 1, even = term 2)');

-- core courses of term 1 for the whole batch: Heidi gets CS102, Ivan and Judy get CS101 + CS102
SELECT pg_temp.ok(academic.register_core_courses(pg_temp.u('B-2026'), pg_temp.term('Y-B','ODD')) = 5,
  'core courses registered for the whole batch in one call (5 new registrations)');
SELECT pg_temp.ok(academic.register_core_courses(pg_temp.u('B-2026'), pg_temp.term('Y-B','ODD')) = 0,
  'core registration is safe to re-run (nothing registered twice)');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM academic.course_registration r JOIN academic.course_offering o ON o.id = r.course_offering_id
                              WHERE r.student_enrollment_id = pg_temp.u('EN-IVAN') AND o.course_id = pg_temp.u('C-CS201')),
  'electives are not auto-registered');

-- sections for the even term, allocated by enrollment number
INSERT INTO academic.section (id, batch_id, academic_term_id, code, capacity) VALUES
 (pg_temp.u('SEC-E-A'), pg_temp.u('B-2026'), pg_temp.term('Y-B','EVEN'), 'A', 1),
 (pg_temp.u('SEC-E-B'), pg_temp.u('B-2026'), pg_temp.term('Y-B','EVEN'), 'B', 1);
SELECT pg_temp.rejects($q$SELECT academic.allocate_sections(md5('B-2026')::uuid,
  (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','EVEN')))$q$,
  'section allocation when the sections cannot hold the batch (all or nothing)');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM academic.section_student WHERE section_id IN (pg_temp.u('SEC-E-A'), pg_temp.u('SEC-E-B'))),
  'a failed allocation leaves no half-filled sections');
INSERT INTO academic.section (id, batch_id, academic_term_id, code, capacity)
VALUES (pg_temp.u('SEC-E-C'), pg_temp.u('B-2026'), pg_temp.term('Y-B','EVEN'), 'C', 5);
SELECT pg_temp.ok(academic.allocate_sections(pg_temp.u('B-2026'), pg_temp.term('Y-B','EVEN')) = 3,
  'section allocation places the whole batch (3 students)');
SELECT pg_temp.ok((SELECT string_agg(sec.code || ':' || st.enrollment_no, ',' ORDER BY st.enrollment_no)
                   FROM academic.section_student ss
                   JOIN academic.section sec ON sec.id = ss.section_id AND sec.academic_term_id = pg_temp.term('Y-B','EVEN')
                   JOIN academic.student_enrollment e ON e.id = ss.student_enrollment_id
                   JOIN people.student st ON st.id = e.student_id)
                  = 'A:SGT2026CSE002,B:SGT2026CSE003,C:SGT2026CSE004',
  'sections filled A, B, C in enrollment-number order up to capacity');

-- ===================== student lifecycle · calendar · content · research =====

-- ---- academic calendar ----
INSERT INTO academic.calendar_event (id, academic_year_id, academic_term_id, calendar_event_type_id, name, period) VALUES
 (pg_temp.u('CE-HOL'), pg_temp.u('Y-B'), pg_temp.term('Y-B','ODD'), pg_temp.lk('calendar_event_type','HOLIDAY'), 'Foundation day',
  daterange(pg_temp.nth_dow(current_date + 90, 1, 1), pg_temp.nth_dow(current_date + 90, 1, 1) + 1));
INSERT INTO academic.calendar_event (academic_year_id, calendar_event_type_id, org_unit_id, name, period) VALUES
 (pg_temp.u('Y-B'), pg_temp.lk('calendar_event_type','HOLIDAY'), pg_temp.u('SOM'), 'Management fest (SOM only)', daterange(current_date + 40, current_date + 41));
SELECT pg_temp.ok(NOT academic.is_working_day(pg_temp.nth_dow(current_date + 90, 1, 1), pg_temp.u('CSE'))
              AND academic.is_working_day(current_date + 40, pg_temp.u('CSE')) AND NOT academic.is_working_day(current_date + 40, pg_temp.u('MBA')),
  'working day derived from the calendar: a university holiday, and a school holiday that reaches its departments only');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_session (timetable_entry_id, session_date, class_session_status_id)
  VALUES (md5('TT-L')::uuid, pg_temp.nth_dow(current_date + 90, 1, 1), ref.id_of('class_session_status','SCHEDULED'))$q$,
  'timetabled class session on a holiday');
SELECT pg_temp.rejects($q$INSERT INTO academic.calendar_event (academic_year_id, academic_term_id, calendar_event_type_id, name, period)
  VALUES (md5('Y-A')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid LIMIT 1),
          ref.id_of('calendar_event_type','EXAM_PERIOD'), 'Wrong year', daterange(current_date - 300, current_date - 290))$q$,
  'calendar event whose term is in another academic year');
SELECT pg_temp.rejects($q$INSERT INTO academic.calendar_event (academic_year_id, calendar_event_type_id, name, period)
  VALUES (md5('Y-B')::uuid, ref.id_of('calendar_event_type','VACATION'), 'Outside the year', daterange(current_date + 400, current_date + 410))$q$,
  'calendar event outside its academic year');

-- ---- programme attributes, regulator approval, accreditation ----
SELECT pg_temp.ok((SELECT delivery_mode = 'REGULAR' AND medium_language IS NULL FROM academic.v_program WHERE program_id = pg_temp.u('P-BTECH')),
  'programme delivery mode and medium of instruction exposed');
INSERT INTO academic.program_approval (program_id, regulatory_body_id, reference_no, approved_seats, valid)
VALUES (pg_temp.u('P-BTECH'), pg_temp.lk('regulatory_body','AICTE'), 'F.No.Northern/2026/1', 120, daterange(current_date - 400, current_date + 330));
SELECT pg_temp.rejects($q$UPDATE academic.batch SET intake_capacity = 130 WHERE id = md5('B-2026')::uuid$q$, 'batch intake above the regulator''s approved seats');
UPDATE academic.batch SET intake_capacity = 100 WHERE id = pg_temp.u('B-2026');
SELECT pg_temp.rejects($q$INSERT INTO academic.program_approval (program_id, regulatory_body_id, reference_no, approved_seats, valid)
  VALUES (md5('P-BTECH')::uuid, ref.id_of('regulatory_body','AICTE'), 'F.No.2', 200, daterange(current_date, NULL))$q$, 'two overlapping approvals by the same regulator');
INSERT INTO academic.program_accreditation (program_id, accreditation_body_id, grade, valid)
VALUES (pg_temp.u('P-BTECH'), pg_temp.lk('accreditation_body','NBA'), 'Accredited (3 years)', daterange(current_date - 100, current_date + 995));
INSERT INTO academic.program_accreditation (org_unit_id, accreditation_body_id, grade, score, valid)
VALUES (pg_temp.u('SGTU'), pg_temp.lk('accreditation_body','NAAC'), 'A+', 3.35, daterange(current_date - 100, current_date + 1725));
SELECT pg_temp.rejects($q$INSERT INTO academic.program_accreditation (program_id, org_unit_id, accreditation_body_id, grade, valid)
  VALUES (md5('P-BTECH')::uuid, md5('SGTU')::uuid, ref.id_of('accreditation_body','NBA'), 'X', daterange(current_date, NULL))$q$,
  'accreditation of both a programme and a unit');

-- ---- term registration, promotion, standing ----
INSERT INTO academic.promotion_rule (curriculum_id, after_term_no, max_backlog_credits) VALUES (pg_temp.u('CUR-BT'), 1, 8);
SELECT pg_temp.rejects($q$INSERT INTO academic.promotion_rule (curriculum_id, after_term_no, max_backlog_credits) VALUES (md5('CUR-BT')::uuid, 9, 0)$q$,
  'promotion checkpoint beyond the programme duration');
UPDATE academic.curriculum SET max_duration_years = 6, max_attempts_per_course = 2 WHERE id = pg_temp.u('CUR-BT');
INSERT INTO academic.term_registration (id, student_enrollment_id, academic_term_id, term_no, term_registration_status_id) VALUES
 (pg_temp.u('TR-IVAN-1'),  pg_temp.u('EN-IVAN'),  pg_temp.term('Y-B','ODD'), 1, pg_temp.lk('term_registration_status','REGISTERED')),
 (pg_temp.u('TR-JUDY-1'),  pg_temp.u('EN-JUDY'),  pg_temp.term('Y-B','ODD'), 1, pg_temp.lk('term_registration_status','REGISTERED')),
 (pg_temp.u('TR-HEIDI-1'), pg_temp.u('EN-HEIDI'), pg_temp.term('Y-B','ODD'), 1, pg_temp.lk('term_registration_status','REGISTERED'));
SELECT pg_temp.rejects($q$INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
  VALUES ((SELECT id FROM academic.student_enrollment WHERE student_id = md5('S-GRACE')::uuid),
          (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')),
          1, ref.id_of('term_registration_status','REGISTERED'))$q$, 'term registration with the wrong term number (2025 batch student is in term 3)');
INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
VALUES ((SELECT id FROM academic.student_enrollment WHERE student_id = pg_temp.u('S-GRACE')), pg_temp.term('Y-B','ODD'), 3, pg_temp.lk('term_registration_status','REGISTERED'));
SELECT pg_temp.rejects($q$INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
  VALUES (md5('EN-IVAN')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ANNUAL')),
          1, ref.id_of('term_registration_status','REGISTERED'))$q$, 'term registration into a term of another calendar type');

-- Heidi was absent in CS101: published as ABSENT → a 4-credit backlog
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
VALUES (pg_temp.u('PUB-1'), pg_temp.u('ER-H-101'), 0,
        (SELECT id FROM academic.grade_band WHERE grade_letter = 'F' AND grade_scale_id = (SELECT id FROM academic.grade_scale WHERE code = 'UGC_10')),
        pg_temp.lk('result_status','ABSENT'));
SELECT pg_temp.ok((SELECT credits = 4 AND result_status = 'ABSENT' FROM academic.v_backlog WHERE student_enrollment_id = pg_temp.u('EN-HEIDI') AND course_id = pg_temp.u('C-CS101')),
  'backlog derived from published results (Heidi: CS101, 4 credits)');
SELECT pg_temp.rejects($q$UPDATE academic.term_registration SET academic_standing_id = ref.id_of('academic_standing','PROMOTED'),
  standing_decided_by_employee_id = md5('E-ALICE')::uuid, standing_decided_at = now() WHERE id = md5('TR-HEIDI-1')::uuid$q$,
  'clean promotion with a backlog');
UPDATE academic.promotion_rule SET max_backlog_credits = 2 WHERE curriculum_id = pg_temp.u('CUR-BT');
SELECT pg_temp.rejects($q$UPDATE academic.term_registration SET academic_standing_id = ref.id_of('academic_standing','PROMOTED_WITH_BACKLOG'),
  standing_decided_by_employee_id = md5('E-ALICE')::uuid, standing_decided_at = now() WHERE id = md5('TR-HEIDI-1')::uuid$q$,
  'promotion with more backlog than the rule allows (4 > 2 credits)');
UPDATE academic.promotion_rule SET max_backlog_credits = 8 WHERE curriculum_id = pg_temp.u('CUR-BT');
UPDATE academic.term_registration SET academic_standing_id = pg_temp.lk('academic_standing','PROMOTED_WITH_BACKLOG'),
  standing_decided_by_employee_id = pg_temp.u('E-ALICE'), standing_decided_at = now() WHERE id = pg_temp.u('TR-HEIDI-1');
UPDATE academic.term_registration SET academic_standing_id = pg_temp.lk('academic_standing','PROMOTED'),
  standing_decided_by_employee_id = pg_temp.u('E-ALICE'), standing_decided_at = now() WHERE id = pg_temp.u('TR-IVAN-1');
UPDATE academic.term_registration SET academic_standing_id = pg_temp.lk('academic_standing','DETAINED'),
  standing_decided_by_employee_id = pg_temp.u('E-ALICE'), standing_decided_at = now(), standing_note = 'Attendance shortage in every course'
WHERE id = pg_temp.u('TR-JUDY-1');
SELECT pg_temp.ok((SELECT is_eligible AND backlog_credits = 4 FROM academic.v_promotion_eligibility
                   WHERE student_enrollment_id = pg_temp.u('EN-HEIDI') AND after_term_no = 1),
  'promotion eligibility view: Heidi may move up with 4 backlog credits under the 8-credit rule');
SELECT pg_temp.ok(academic.enrollment_term_no(pg_temp.u('EN-IVAN'), pg_temp.term('Y-B','EVEN')) = 2
              AND academic.enrollment_term_no(pg_temp.u('EN-JUDY'), pg_temp.term('Y-B','EVEN')) = 1,
  'next term follows the standing: promoted Ivan → term 2, detained Judy → term 1 again');
SELECT pg_temp.rejects($q$INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
  VALUES (md5('EN-JUDY')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','EVEN')),
          2, ref.id_of('term_registration_status','REGISTERED'))$q$, 'detained student registering for the next term');
INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id) VALUES
 (pg_temp.u('EN-JUDY'), pg_temp.term('Y-B','EVEN'), 1, pg_temp.lk('term_registration_status','REGISTERED')),
 (pg_temp.u('EN-IVAN'), pg_temp.term('Y-B','EVEN'), 2, pg_temp.lk('term_registration_status','REGISTERED'));
SELECT pg_temp.ok((SELECT latest_registered_term_no = 1 AND latest_standing = 'PROMOTED_WITH_BACKLOG' AND backlog_credits = 4
                          AND NOT is_on_break AND must_complete_by = (current_date - 20 + interval '6 years')::date
                   FROM academic.v_student_standing WHERE student_enrollment_id = pg_temp.u('EN-HEIDI')),
  'student standing view: latest registered term and standing, backlog, break status, maximum-duration deadline');

-- ---- break in study ----
INSERT INTO academic.study_break (student_enrollment_id, study_break_type_id, period, reason, approved_by_employee_id)
VALUES (pg_temp.u('EN-HEIDI'), pg_temp.lk('study_break_type','MEDICAL'), daterange(current_date + 121, current_date + 305), 'Surgery and recovery', pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO academic.study_break (student_enrollment_id, study_break_type_id, period, approved_by_employee_id)
  VALUES (md5('EN-HEIDI')::uuid, ref.id_of('study_break_type','PERSONAL'), daterange(current_date + 200, NULL), md5('E-ALICE')::uuid)$q$, 'overlapping breaks in study');
SELECT pg_temp.rejects($q$INSERT INTO academic.study_break (student_enrollment_id, study_break_type_id, period, approved_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, ref.id_of('study_break_type','PERSONAL'), daterange(current_date + 50, current_date + 60), md5('E-ALICE')::uuid)$q$,
  'break in study on a closed enrollment');
SELECT pg_temp.rejects($q$INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
  VALUES (md5('EN-HEIDI')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','EVEN')),
          2, ref.id_of('term_registration_status','REGISTERED'))$q$, 'term registration while on a break in study');
SELECT pg_temp.ok(academic.enrollment_term_no(pg_temp.u('EN-HEIDI'), pg_temp.term('Y-B','EVEN')) = 1,
  'a term spent on a break in study does not advance the semester count');

-- ---- maximum duration and attempts ----
INSERT INTO academic.academic_year (id, code, period) VALUES (pg_temp.u('Y-F'), '2033-34', daterange(current_date + 2500, current_date + 2865));
INSERT INTO academic.academic_term (id, academic_year_id, term_cycle_id, period)
VALUES (pg_temp.u('T-FAR'), pg_temp.u('Y-F'), pg_temp.lk('term_cycle','ODD'), daterange(current_date + 2510, current_date + 2660));
SELECT pg_temp.rejects($q$INSERT INTO academic.term_registration (student_enrollment_id, academic_term_id, term_no, term_registration_status_id)
  VALUES (md5('EN-IVAN')::uuid, md5('T-FAR')::uuid, 3, ref.id_of('term_registration_status','REGISTERED'))$q$,
  'term registration beyond the maximum programme duration (6 years)');
INSERT INTO exam.exam_session (id, academic_term_id, exam_session_type_id, name, period)
VALUES (pg_temp.u('XS-SPL'), pg_temp.term('Y-B','EVEN'), pg_temp.lk('exam_session_type','SPECIAL'), 'Special', daterange(current_date + 150, current_date + 160));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
  VALUES (md5('XS-SPL')::uuid, md5('R-C-201')::uuid, ref.id_of('exam_attempt_type','SUPPLEMENTARY'))$q$, 'third attempt when the curriculum allows two');
INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('XS-SPL'), pg_temp.u('R-H-101'), pg_temp.lk('exam_attempt_type','BACKLOG'));
SELECT pg_temp.ok(true, 'a re-attempt within the curriculum''s attempt limit is accepted');

-- ---- change of programme ----
UPDATE academic.student_enrollment SET valid = daterange(lower(valid), current_date + 30), end_reason_id = pg_temp.lk('enrollment_end_reason','PROGRAM_CHANGE')
WHERE student_id = pg_temp.u('S-GRACE');
INSERT INTO academic.batch (id, program_id, admission_year_id, intake_capacity) VALUES (pg_temp.u('B-MBA-2026'), pg_temp.u('P-MBA'), pg_temp.u('Y-B'), 60);
INSERT INTO academic.batch_curriculum (batch_id, curriculum_id) VALUES (pg_temp.u('B-MBA-2026'), pg_temp.u('CUR-MBA'));
INSERT INTO academic.student_enrollment (id, student_id, batch_id, valid)
VALUES (pg_temp.u('EN-GRACE-2'), pg_temp.u('S-GRACE'), pg_temp.u('B-MBA-2026'), daterange(current_date + 30, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.program_transfer (from_enrollment_id, to_enrollment_id, approved_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, md5('EN-CAROL-2')::uuid, md5('E-ALICE')::uuid)$q$,
  'programme transfer from an enrollment that ended with an award, not a programme change');
INSERT INTO academic.program_transfer (from_enrollment_id, to_enrollment_id, approved_by_employee_id, reason)
VALUES ((SELECT id FROM academic.student_enrollment WHERE student_id = pg_temp.u('S-GRACE') AND NOT upper_inf(valid)),
        pg_temp.u('EN-GRACE-2'), pg_temp.u('E-ALICE'), 'Change of programme after year 1');
SELECT pg_temp.ok((SELECT count(*) = 2 FROM academic.v_enrollment_lineage WHERE student_enrollment_id = pg_temp.u('EN-GRACE-2')),
  'a transferred student''s earlier enrollment is in the lineage (credits carry)');
SELECT pg_temp.rejects($q$UPDATE academic.student_enrollment SET valid = daterange(lower(valid), current_date + 60) WHERE id = md5('EN-IVAN')::uuid$q$,
  'closing an enrollment without an end reason');

-- ---- elective preferences and merit allotment ----
INSERT INTO academic.course (id, code, title, owner_org_unit_id, credits) VALUES
 (pg_temp.u('C-EC101'), 'EC101', 'Economics for Engineers', pg_temp.u('MBA'), 3);
INSERT INTO academic.course_offering (id, course_id, academic_term_id, offering_org_unit_id) VALUES
 (pg_temp.u('O-EC101'), pg_temp.u('C-EC101'), pg_temp.term('Y-B','ODD'), pg_temp.u('MBA'));
INSERT INTO academic.elective_basket (id, curriculum_id, code, name, term_no, course_category_id, courses_to_choose) VALUES
 (pg_temp.u('OE1'), pg_temp.u('CUR-BT'), 'OE-1', 'Open elective 1', 1, pg_temp.lk('course_category','OPEN_ELECTIVE'), 1),
 (pg_temp.u('PE2'), pg_temp.u('CUR-BT'), 'PE-2', 'Programme elective 2', 2, pg_temp.lk('course_category','DISCIPLINE_ELECTIVE'), 1);
INSERT INTO academic.elective_basket_course (elective_basket_id, course_id, evaluation_scheme_id) VALUES
 (pg_temp.u('OE1'), pg_temp.u('C-MB101'), 9001), (pg_temp.u('OE1'), pg_temp.u('C-EC101'), 9001), (pg_temp.u('PE2'), pg_temp.u('C-CS101N'), 9001);
UPDATE academic.course_offering SET intake_limit = 1 WHERE id = pg_temp.u('O-MB101');
INSERT INTO academic.elective_preference (student_enrollment_id, elective_basket_id, academic_term_id, course_id, priority) VALUES
 (pg_temp.u('EN-IVAN'), pg_temp.u('OE1'), pg_temp.term('Y-B','ODD'), pg_temp.u('C-MB101'), 1),
 (pg_temp.u('EN-IVAN'), pg_temp.u('OE1'), pg_temp.term('Y-B','ODD'), pg_temp.u('C-EC101'), 2),
 (pg_temp.u('EN-JUDY'), pg_temp.u('OE1'), pg_temp.term('Y-B','ODD'), pg_temp.u('C-MB101'), 1),
 (pg_temp.u('EN-JUDY'), pg_temp.u('OE1'), pg_temp.term('Y-B','ODD'), pg_temp.u('C-EC101'), 2);
SELECT pg_temp.rejects($q$INSERT INTO academic.elective_preference (student_enrollment_id, elective_basket_id, academic_term_id, course_id, priority)
  VALUES (md5('EN-IVAN')::uuid, md5('OE1')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')),
          md5('C-CS201')::uuid, 3)$q$, 'preference for a course outside the basket');
SELECT pg_temp.rejects($q$INSERT INTO academic.elective_preference (student_enrollment_id, elective_basket_id, academic_term_id, course_id, priority)
  VALUES (md5('EN-IVAN')::uuid, md5('PE2')::uuid, (SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')),
          md5('C-CS101N')::uuid, 1)$q$, 'preference in a basket of another term (PE-2 is for term 2, the student is in term 1)');
SELECT pg_temp.ok(academic.allot_electives(pg_temp.u('OE1'), pg_temp.term('Y-B','ODD')) = 2, 'elective allotment in merit order: 2 students placed');
SELECT pg_temp.ok((SELECT string_agg(st.enrollment_no || ':' || c.code, ',' ORDER BY st.enrollment_no)
                   FROM academic.course_registration r
                   JOIN academic.course_offering o ON o.id = r.course_offering_id JOIN academic.course c ON c.id = o.course_id
                   JOIN academic.student_enrollment e ON e.id = r.student_enrollment_id JOIN people.student st ON st.id = e.student_id
                   WHERE o.id IN (pg_temp.u('O-MB101'), pg_temp.u('O-EC101')) AND e.id IN (pg_temp.u('EN-IVAN'), pg_temp.u('EN-JUDY')))
                  = 'SGT2026CSE003:MB101,SGT2026CSE004:EC101',
  'first in merit gets the first preference; the next gets their second when the seat is taken');
SELECT pg_temp.ok(academic.allot_electives(pg_temp.u('OE1'), pg_temp.term('Y-B','ODD')) = 0, 'elective allotment is safe to re-run');

-- ---- syllabus, outcomes, lesson plan, course file ----
INSERT INTO academic.course_syllabus (id, course_id, version, approved_by_employee_id, approved_on, valid) VALUES
 (pg_temp.u('SY-101'), pg_temp.u('C-CS101'), 'v1', pg_temp.u('E-ALICE'), current_date - 400, daterange(current_date - 400, NULL)),
 (pg_temp.u('SY-102'), pg_temp.u('C-CS102'), 'v1', pg_temp.u('E-ALICE'), current_date - 400, daterange(current_date - 400, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_syllabus (course_id, version, valid) VALUES (md5('C-CS101')::uuid, 'v2', daterange(current_date, NULL))$q$,
  'two current syllabus versions of one course');
INSERT INTO academic.syllabus_unit (id, course_syllabus_id, unit_no, title, contact_hours) VALUES
 (pg_temp.u('SU-101-1'), pg_temp.u('SY-101'), 1, 'Variables, types and control flow', 12),
 (pg_temp.u('SU-101-2'), pg_temp.u('SY-101'), 2, 'Functions and recursion', 10),
 (pg_temp.u('SU-102-1'), pg_temp.u('SY-102'), 1, 'Lab: environment set-up', 4);
INSERT INTO academic.course_outcome (id, course_syllabus_id, code, statement, bloom_level_id) VALUES
 (pg_temp.u('CO-101-1'), pg_temp.u('SY-101'), 'CO1', 'Write structured programs using control flow', pg_temp.lk('bloom_level','APPLY'));
INSERT INTO academic.program_outcome (id, program_id, program_outcome_type_id, code, statement) VALUES
 (pg_temp.u('PO-BT-1'),  pg_temp.u('P-BTECH'), pg_temp.lk('program_outcome_type','PO'), 'PO1', 'Engineering knowledge'),
 (pg_temp.u('PO-MBA-1'), pg_temp.u('P-MBA'),   pg_temp.lk('program_outcome_type','PO'), 'PO1', 'Business knowledge');
INSERT INTO academic.co_po_mapping (course_outcome_id, program_outcome_id, strength) VALUES (pg_temp.u('CO-101-1'), pg_temp.u('PO-BT-1'), 3);
SELECT pg_temp.rejects($q$INSERT INTO academic.co_po_mapping (course_outcome_id, program_outcome_id, strength) VALUES (md5('CO-101-1')::uuid, md5('PO-MBA-1')::uuid, 2)$q$,
  'CO mapped to a PO of a programme that does not teach the course');
INSERT INTO academic.lesson_plan_item (id, teaching_assignment_id, seq, syllabus_unit_id, topic, planned_hours, planned_week) VALUES
 (pg_temp.u('LP-1'), pg_temp.u('TA-A-L'), 1, pg_temp.u('SU-101-1'), 'Variables and types', 2, 1),
 (pg_temp.u('LP-2'), pg_temp.u('TA-A-L'), 2, pg_temp.u('SU-101-1'), 'Loops', 2, 2);
SELECT pg_temp.rejects($q$INSERT INTO academic.lesson_plan_item (teaching_assignment_id, seq, syllabus_unit_id, topic)
  VALUES (md5('TA-A-L')::uuid, 3, md5('SU-102-1')::uuid, 'Wrong course unit')$q$, 'lesson plan item pointing at another course''s syllabus unit');
INSERT INTO academic.class_session_topic (class_session_id, lesson_plan_item_id, topic) VALUES (pg_temp.u('CS-L1'), pg_temp.u('LP-1'), 'Variables and types');
SELECT pg_temp.rejects($q$INSERT INTO academic.class_session_topic (class_session_id, lesson_plan_item_id, topic) VALUES (md5('CS-TB1')::uuid, md5('LP-1')::uuid, 'x')$q$,
  'topic recorded against the lesson plan of another class');
SELECT pg_temp.ok((SELECT plan_items = 2 AND plan_items_covered = 1 AND planned_hours = 4 AND coverage_pct = 50
                   FROM academic.v_syllabus_coverage WHERE teaching_assignment_id = pg_temp.u('TA-A-L') AND syllabus_unit_id = pg_temp.u('SU-101-1')),
  'syllabus coverage derived from the course file (1 of 2 planned items delivered)');

-- ---- faculty workload ----
INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid)
VALUES (pg_temp.u('E-FRANK'), pg_temp.u('CSE'), (SELECT id FROM people.designation WHERE code = 'ASSISTANT_PROFESSOR'), true, daterange('2019-07-01', NULL));
INSERT INTO academic.workload_norm (designation_id, min_hours_per_week, max_hours_per_week, valid)
VALUES ((SELECT id FROM people.designation WHERE code = 'ASSISTANT_PROFESSOR'), 2, 2.5, daterange('2020-01-01', NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.workload_norm (designation_id, max_hours_per_week, valid)
  VALUES ((SELECT id FROM people.designation WHERE code = 'ASSISTANT_PROFESSOR'), 16, daterange('2024-01-01', NULL))$q$, 'overlapping workload norms for one designation');
SELECT pg_temp.ok((SELECT hours_per_week = 3.00 AND is_over_norm FROM academic.v_faculty_workload
                   WHERE employee_id = pg_temp.u('E-FRANK') AND academic_term_id = pg_temp.term('Y-B','ODD')),
  'faculty workload derived from the timetable (Frank: 3 h/week incl. fortnightly halves, over the 2.5 h norm)');

-- ---- division / class ----
SELECT pg_temp.ok((SELECT division_code = 'FIRST_DISTINCTION' AND equivalent_pct = 84.30 FROM exam.v_division WHERE student_enrollment_id = pg_temp.u('EN-CAROL-2')),
  'division and equivalent percentage derived from the CGPA (8.43 → 84.3%, first class with distinction)');
SELECT pg_temp.rejects($q$INSERT INTO academic.division_band (grade_scale_id, code, label, cgpa_range)
  VALUES ((SELECT id FROM academic.grade_scale WHERE code = 'UGC_10'), 'X', 'Overlap', numrange(7, 8))$q$, 'overlapping division bands');

-- ---- anonymous student feedback ----
INSERT INTO academic.feedback_questionnaire (id, code, name, max_rating) VALUES (91, 'FB-STD', 'Standard course feedback', 5), (92, 'FB-OTHER', 'Another questionnaire', 5);
INSERT INTO academic.feedback_question (id, feedback_questionnaire_id, seq, question, is_free_text) VALUES
 (9101, 91, 1, 'The teacher explains concepts clearly', false), (9102, 91, 2, 'Any other comments', true), (9201, 92, 1, 'Unrelated question', false);
INSERT INTO academic.feedback_cycle (id, academic_term_id, feedback_questionnaire_id, name, submission_window)
VALUES (pg_temp.u('FC-1'), pg_temp.term('Y-B','ODD'), 91, 'Odd term feedback', tstzrange(now() - interval '5 days', now() + interval '30 days'));
INSERT INTO academic.feedback_submission (feedback_cycle_id, course_registration_id)
VALUES (pg_temp.u('FC-1'), (SELECT id FROM academic.course_registration WHERE student_enrollment_id = pg_temp.u('EN-IVAN') AND course_offering_id = pg_temp.u('O-CS101')));
SELECT pg_temp.rejects($q$INSERT INTO academic.feedback_submission (feedback_cycle_id, course_registration_id)
  VALUES (md5('FC-1')::uuid, (SELECT id FROM academic.course_registration WHERE student_enrollment_id = md5('EN-IVAN')::uuid AND course_offering_id = md5('O-CS101')::uuid))$q$,
  'second feedback submission by the same registration');
SELECT pg_temp.rejects($q$INSERT INTO academic.feedback_submission (feedback_cycle_id, course_registration_id) VALUES (md5('FC-1')::uuid, md5('R-C-102N')::uuid)$q$,
  'feedback from a registration in another term');
INSERT INTO academic.feedback_response (feedback_cycle_id, teaching_assignment_id, feedback_question_id, rating) VALUES
 (pg_temp.u('FC-1'), pg_temp.u('TA-E-LB'), 9101, 4), (pg_temp.u('FC-1'), pg_temp.u('TA-E-LB'), 9101, 5);
INSERT INTO academic.feedback_response (feedback_cycle_id, teaching_assignment_id, feedback_question_id, comment)
VALUES (pg_temp.u('FC-1'), pg_temp.u('TA-E-LB'), 9102, 'More worked examples please');
SELECT pg_temp.rejects($q$INSERT INTO academic.feedback_response (feedback_cycle_id, teaching_assignment_id, feedback_question_id, rating) VALUES (md5('FC-1')::uuid, md5('TA-E-LB')::uuid, 9101, 6)$q$,
  'rating above the questionnaire scale');
SELECT pg_temp.rejects($q$INSERT INTO academic.feedback_response (feedback_cycle_id, teaching_assignment_id, feedback_question_id, rating) VALUES (md5('FC-1')::uuid, md5('TA-E-LB')::uuid, 9102, 3)$q$,
  'rating given to a free-text question');
SELECT pg_temp.rejects($q$INSERT INTO academic.feedback_response (feedback_cycle_id, teaching_assignment_id, feedback_question_id, rating) VALUES (md5('FC-1')::uuid, md5('TA-E-LB')::uuid, 9201, 3)$q$,
  'question from another questionnaire');
SELECT pg_temp.ok((SELECT avg_rating = 4.50 AND responses = 2 FROM academic.v_feedback_summary
                   WHERE feedback_cycle_id = pg_temp.u('FC-1') AND teaching_assignment_id = pg_temp.u('TA-E-LB') AND feedback_question_id = 9101),
  'feedback summary per class and question, with no link to who answered');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'academic' AND table_name = 'feedback_response'
                              AND (column_name LIKE '%student%' OR column_name LIKE '%registration%')),
  'feedback responses carry no student column (anonymous by construction)');

-- ---- doctoral research: supervision, committee, reviews, thesis, viva, degree ----
INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('KIM'), 'Kim'), (pg_temp.u('LEO'), 'Leo'), (pg_temp.u('MALLORY'), 'Mallory'), (pg_temp.u('NIAJ'), 'Niaj');
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on) VALUES
 (pg_temp.u('S-KIM'), pg_temp.u('KIM'), 'SGT2026PHD001', pg_temp.lk('student_status','ACTIVE'), current_date - 20),
 (pg_temp.u('S-LEO'), pg_temp.u('LEO'), 'SGT2026PHD002', pg_temp.lk('student_status','ACTIVE'), current_date - 20);
INSERT INTO academic.program (id, code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id, delivery_mode_id, duration_terms, min_credits, max_credits)
VALUES (pg_temp.u('P-PHD'), 'PHD-CSE', 'Ph.D. Computer Science & Engineering', pg_temp.lk('program_level','DOCTORAL'),
        pg_temp.lk('academic_calendar_type','SEMESTER'), pg_temp.u('CSE'), pg_temp.lk('delivery_mode','REGULAR'), 6, 1, 20);
INSERT INTO academic.curriculum (id, program_id, code, name, grade_scale_id, attendance_threshold_pct)
VALUES (pg_temp.u('CUR-PHD'), pg_temp.u('P-PHD'), 'R2026', 'Ph.D. coursework 2026', (SELECT id FROM academic.grade_scale WHERE code = 'UGC_10'), 75);
INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id)
VALUES (pg_temp.u('CUR-PHD'), 1, pg_temp.u('C-CS102'), pg_temp.lk('course_category','LAB'), 9002);
INSERT INTO academic.award_rule (id, curriculum_id, award_type_id, award_title, after_term_no, min_credits)
VALUES (pg_temp.u('AR-PHD'), pg_temp.u('CUR-PHD'), pg_temp.lk('award_type','DOCTORATE'), 'Doctor of Philosophy (Computer Science & Engineering)', 6, 1);
INSERT INTO academic.batch (id, program_id, admission_year_id, intake_capacity) VALUES (pg_temp.u('B-PHD-2026'), pg_temp.u('P-PHD'), pg_temp.u('Y-B'), 10);
INSERT INTO academic.batch_curriculum (batch_id, curriculum_id) VALUES (pg_temp.u('B-PHD-2026'), pg_temp.u('CUR-PHD'));
INSERT INTO academic.student_enrollment (id, student_id, batch_id, valid) VALUES
 (pg_temp.u('EN-KIM'), pg_temp.u('S-KIM'), pg_temp.u('B-PHD-2026'), daterange(current_date - 20, NULL)),
 (pg_temp.u('EN-LEO'), pg_temp.u('S-LEO'), pg_temp.u('B-PHD-2026'), daterange(current_date - 20, NULL));
UPDATE research.supervision_norm SET max_scholars = 1 WHERE designation_id = (SELECT id FROM people.designation WHERE code = 'PROFESSOR');
INSERT INTO research.supervisor_allocation (student_enrollment_id, supervisor_role_id, employee_id, approved_by_employee_id, valid)
VALUES (pg_temp.u('EN-KIM'), pg_temp.lk('supervisor_role','SUPERVISOR'), pg_temp.u('E-ALICE'), pg_temp.u('E-ALICE'), daterange(current_date - 20, NULL));
SELECT pg_temp.rejects($q$INSERT INTO research.supervisor_allocation (student_enrollment_id, supervisor_role_id, employee_id, approved_by_employee_id)
  VALUES (md5('EN-LEO')::uuid, ref.id_of('supervisor_role','SUPERVISOR'), md5('E-ALICE')::uuid, md5('E-ALICE')::uuid)$q$,
  'supervisor above the norm for their designation (Professor: 1 scholar in this test)');
SELECT pg_temp.rejects($q$INSERT INTO research.supervisor_allocation (student_enrollment_id, supervisor_role_id, employee_id, approved_by_employee_id)
  VALUES (md5('EN-KIM')::uuid, ref.id_of('supervisor_role','SUPERVISOR'), md5('E-FRANK')::uuid, md5('E-ALICE')::uuid)$q$, 'second concurrent principal supervisor');
SELECT pg_temp.rejects($q$INSERT INTO research.supervisor_allocation (student_enrollment_id, supervisor_role_id, external_person_id, approved_by_employee_id)
  VALUES (md5('EN-LEO')::uuid, ref.id_of('supervisor_role','SUPERVISOR'), md5('MALLORY')::uuid, md5('E-ALICE')::uuid)$q$, 'external person as principal supervisor');
INSERT INTO research.supervisor_allocation (student_enrollment_id, supervisor_role_id, employee_id, external_person_id, approved_by_employee_id) VALUES
 (pg_temp.u('EN-LEO'), pg_temp.lk('supervisor_role','SUPERVISOR'),             pg_temp.u('E-FRANK'), NULL, pg_temp.u('E-ALICE')),
 (pg_temp.u('EN-KIM'), pg_temp.lk('supervisor_role','CO_SUPERVISOR'),          pg_temp.u('E-FRANK'), NULL, pg_temp.u('E-ALICE')),
 (pg_temp.u('EN-KIM'), pg_temp.lk('supervisor_role','EXTERNAL_CO_SUPERVISOR'), NULL, pg_temp.u('MALLORY'), pg_temp.u('E-ALICE'));
INSERT INTO research.advisory_committee (id, student_enrollment_id, constituted_on, approved_by_employee_id)
VALUES (pg_temp.u('RAC-KIM'), pg_temp.u('EN-KIM'), current_date - 10, pg_temp.u('E-ALICE'));
INSERT INTO research.advisory_committee_member (advisory_committee_id, committee_role_id, employee_id) VALUES
 (pg_temp.u('RAC-KIM'), pg_temp.lk('committee_role','CHAIR'), pg_temp.u('E-ALICE')), (pg_temp.u('RAC-KIM'), pg_temp.lk('committee_role','MEMBER'), pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO research.advisory_committee_member (advisory_committee_id, committee_role_id, employee_id)
  VALUES (md5('RAC-KIM')::uuid, ref.id_of('committee_role','CHAIR'), md5('E-BOB')::uuid)$q$, 'two chairs of one committee');
INSERT INTO research.progress_review (student_enrollment_id, review_no, held_on, progress_review_outcome_id, remarks)
VALUES (pg_temp.u('EN-KIM'), 1, current_date - 1, pg_temp.lk('progress_review_outcome','SATISFACTORY'), 'Literature survey complete');
SELECT pg_temp.rejects($q$INSERT INTO research.progress_review (student_enrollment_id, review_no, held_on, progress_review_outcome_id)
  VALUES (md5('EN-LEO')::uuid, 1, current_date, ref.id_of('progress_review_outcome','SATISFACTORY'))$q$, 'progress review for a scholar without a committee');
INSERT INTO research.thesis (id, student_enrollment_id, title, thesis_status_id, topic_approved_on, synopsis_submitted_on, synopsis_approved_on, thesis_submitted_on, similarity_pct)
VALUES (pg_temp.u('TH-KIM'), pg_temp.u('EN-KIM'), 'Learned indexes for graph databases', pg_temp.lk('thesis_status','THESIS_SUBMITTED'),
        current_date - 15, current_date - 10, current_date - 8, current_date - 1, 6.5);
SELECT pg_temp.rejects($q$INSERT INTO research.thesis (student_enrollment_id, title, thesis_status_id, synopsis_submitted_on, thesis_submitted_on)
  VALUES (md5('EN-LEO')::uuid, 'Out of order', ref.id_of('thesis_status','THESIS_SUBMITTED'), current_date, current_date - 5)$q$, 'thesis submitted before its synopsis');
SELECT pg_temp.rejects($q$INSERT INTO research.thesis_examiner (thesis_id, thesis_examiner_role_id, employee_id)
  VALUES (md5('TH-KIM')::uuid, ref.id_of('thesis_examiner_role','INTERNAL'), md5('E-FRANK')::uuid)$q$, 'co-supervisor appointed as examiner');
SELECT pg_temp.rejects($q$INSERT INTO research.thesis_examiner (thesis_id, thesis_examiner_role_id, external_person_id)
  VALUES (md5('TH-KIM')::uuid, ref.id_of('thesis_examiner_role','EXTERNAL'), md5('MALLORY')::uuid)$q$, 'external co-supervisor appointed as examiner');
SELECT pg_temp.rejects($q$INSERT INTO research.thesis_examiner (thesis_id, thesis_examiner_role_id, employee_id)
  VALUES (md5('TH-KIM')::uuid, ref.id_of('thesis_examiner_role','EXTERNAL'), md5('E-EVE')::uuid)$q$, 'employee appointed as external examiner');
INSERT INTO research.thesis_examiner (id, thesis_id, thesis_examiner_role_id, employee_id, external_person_id) VALUES
 (pg_temp.u('TE-BOB'),  pg_temp.u('TH-KIM'), pg_temp.lk('thesis_examiner_role','INTERNAL'), pg_temp.u('E-BOB'), NULL),
 (pg_temp.u('TE-NIAJ'), pg_temp.u('TH-KIM'), pg_temp.lk('thesis_examiner_role','EXTERNAL'), NULL, pg_temp.u('NIAJ'));
SELECT pg_temp.rejects($q$INSERT INTO research.viva (thesis_id, held_on, examiner_recommendation_id, approved_by_employee_id)
  VALUES (md5('TH-KIM')::uuid, current_date, ref.id_of('examiner_recommendation','ACCEPT'), md5('E-ALICE')::uuid)$q$, 'viva before the examiner reports are in');
UPDATE research.thesis_examiner SET report_received_on = current_date, examiner_recommendation_id = pg_temp.lk('examiner_recommendation','REJECT') WHERE id = pg_temp.u('TE-BOB');
UPDATE research.thesis_examiner SET report_received_on = current_date, examiner_recommendation_id = pg_temp.lk('examiner_recommendation','MINOR_REVISION') WHERE id = pg_temp.u('TE-NIAJ');
SELECT pg_temp.rejects($q$INSERT INTO research.viva (thesis_id, held_on, examiner_recommendation_id, approved_by_employee_id)
  VALUES (md5('TH-KIM')::uuid, current_date, ref.id_of('examiner_recommendation','ACCEPT'), md5('E-ALICE')::uuid)$q$, 'viva after an examiner recommended rejection');
UPDATE research.thesis_examiner SET examiner_recommendation_id = pg_temp.lk('examiner_recommendation','ACCEPT') WHERE id = pg_temp.u('TE-BOB');
-- coursework: Kim passes the lab course and the result is published
INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id)
VALUES (pg_temp.u('R-K-102'), pg_temp.u('EN-KIM'), pg_temp.u('O-CS102'), pg_temp.lk('registration_status','REGISTERED'));
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('ER-K-102'), pg_temp.u('XS-END'), pg_temp.u('R-K-102'), pg_temp.lk('exam_attempt_type','REGULAR'));
INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
SELECT pg_temp.u('R-K-102'), ec.id, v.m, pg_temp.u('E-ALICE')
FROM (VALUES ('Continuous lab', 50), ('Practical exam', 30)) v(n, m)
JOIN academic.evaluation_component ec ON ec.evaluation_scheme_id = 9002 AND ec.name = v.n;
INSERT INTO exam.result_publication (id, exam_session_id, publication_type_id, published_by_employee_id)
VALUES (pg_temp.u('PUB-PHD'), pg_temp.u('XS-END'), pg_temp.lk('publication_type','ORIGINAL'), pg_temp.u('E-ALICE'));
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
SELECT pg_temp.u('PUB-PHD'), exam_registration_id, total_pct, grade_band_id, pg_temp.lk('result_status','PASS')
FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-K-102');
UPDATE academic.student_enrollment SET valid = daterange(lower(valid), current_date + 1), end_reason_id = pg_temp.lk('enrollment_end_reason','AWARD') WHERE id = pg_temp.u('EN-KIM');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_award (student_enrollment_id, award_rule_id, conferred_on, approved_by_employee_id)
  VALUES (md5('EN-KIM')::uuid, md5('AR-PHD')::uuid, current_date + 1, md5('E-ALICE')::uuid)$q$, 'doctoral degree before an accepted viva');
INSERT INTO research.viva (thesis_id, held_on, examiner_recommendation_id, approved_by_employee_id)
VALUES (pg_temp.u('TH-KIM'), current_date, pg_temp.lk('examiner_recommendation','ACCEPT'), pg_temp.u('E-ALICE'));
UPDATE research.thesis SET thesis_status_id = pg_temp.lk('thesis_status','ACCEPTED') WHERE id = pg_temp.u('TH-KIM');
INSERT INTO academic.student_award (id, student_enrollment_id, award_rule_id, conferred_on, approved_by_employee_id)
VALUES (pg_temp.u('SA-KIM'), pg_temp.u('EN-KIM'), pg_temp.u('AR-PHD'), current_date + 1, pg_temp.u('E-ALICE'));
SELECT pg_temp.ok((SELECT supervisor_employee_id = pg_temp.u('E-ALICE') AND has_committee AND progress_reviews = 1 AND last_review_outcome = 'SATISFACTORY'
                          AND coursework_credits = 1 AND thesis_status = 'ACCEPTED' AND examiner_reports_pending = 0 AND viva_outcome = 'ACCEPT'
                   FROM research.v_scholar_status WHERE student_enrollment_id = pg_temp.u('EN-KIM')),
  'scholar status derived: supervisor, committee, reviews, coursework, thesis, viva');
-- ---- seat quotas per school / programme on a cross-school elective ----
INSERT INTO academic.offering_seat_quota (course_offering_id, org_unit_id, max_seats) VALUES (pg_temp.u('O-EC101'), pg_temp.u('SET'), 1);
SELECT pg_temp.rejects($q$INSERT INTO academic.offering_seat_quota (course_offering_id, program_id, org_unit_id, max_seats)
  VALUES (md5('O-EC101')::uuid, md5('P-BTECH')::uuid, md5('SET')::uuid, 5)$q$, 'quota for both a programme and a unit');
SELECT pg_temp.rejects($q$INSERT INTO academic.offering_seat_quota (course_offering_id, org_unit_id, max_seats) VALUES (md5('O-EC101')::uuid, md5('HR')::uuid, 5)$q$,
  'quota for a non-academic unit');
INSERT INTO academic.elective_basket (id, curriculum_id, code, name, term_no, course_category_id, courses_to_choose)
VALUES (pg_temp.u('OE-PHD'), pg_temp.u('CUR-PHD'), 'OE-1', 'Open elective', 1, pg_temp.lk('course_category','OPEN_ELECTIVE'), 1);
INSERT INTO academic.elective_basket_course (elective_basket_id, course_id, evaluation_scheme_id) VALUES (pg_temp.u('OE-PHD'), pg_temp.u('C-EC101'), 9001);
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-LEO')::uuid, md5('O-EC101')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'School of Engineering''s only seat in the Management elective is already taken (Judy)');
INSERT INTO academic.offering_seat_quota (course_offering_id, program_id, max_seats) VALUES (pg_temp.u('O-EC101'), pg_temp.u('P-PHD'), 1);
INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
VALUES (pg_temp.u('EN-LEO'), pg_temp.u('O-EC101'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.ok((SELECT string_agg(COALESCE(p.code, u.code) || ':' || seats_used || '/' || max_seats, ',' ORDER BY COALESCE(p.code, u.code))
                   FROM academic.v_offering_quota_usage qu
                   LEFT JOIN academic.program p ON p.id = qu.program_id LEFT JOIN org.org_unit u ON u.id = qu.org_unit_id
                   WHERE qu.course_offering_id = pg_temp.u('O-EC101')) = 'PHD-CSE:1/1,SET:1/1',
  'seat quotas: a programme quota takes precedence over the school quota; usage derived per quota');


-- ---- question papers ----
INSERT INTO exam.paper_setter_assignment (id, exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id, employee_id, appointed_by_employee_id) VALUES
 (pg_temp.u('PS-SET'), pg_temp.u('XS-END'), pg_temp.u('O-CS101'), pg_temp.lk('assessment_type','END_TERM'), pg_temp.lk('paper_setter_role','SETTER'), pg_temp.u('E-FRANK'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.paper_setter_assignment (exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id, employee_id, appointed_by_employee_id)
  VALUES (md5('XS-END')::uuid, md5('O-CS101')::uuid, ref.id_of('assessment_type','END_TERM'), ref.id_of('paper_setter_role','MODERATOR'), md5('E-FRANK')::uuid, md5('E-ALICE')::uuid)$q$,
  'the setter moderating their own paper');
SELECT pg_temp.rejects($q$INSERT INTO exam.paper_setter_assignment (exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id, employee_id, appointed_by_employee_id)
  VALUES (md5('XS-END')::uuid, md5('O-CS101')::uuid, ref.id_of('assessment_type','ASSIGNMENT'), ref.id_of('paper_setter_role','SETTER'), md5('E-BOB')::uuid, md5('E-ALICE')::uuid)$q$,
  'paper setter for a continuous-assessment component');
INSERT INTO exam.paper_setter_assignment (id, exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id, employee_id, appointed_by_employee_id) VALUES
 (pg_temp.u('PS-MOD'), pg_temp.u('XS-END'), pg_temp.u('O-CS101'), pg_temp.lk('assessment_type','END_TERM'), pg_temp.lk('paper_setter_role','MODERATOR'), pg_temp.u('E-ALICE'), pg_temp.u('E-ALICE'));
INSERT INTO exam.question_paper (id, exam_session_id, course_offering_id, assessment_type_id, set_code, question_paper_status_id, submitted_by_assignment_id, submitted_at, max_marks, duration_minutes)
VALUES (pg_temp.u('QP-A'), pg_temp.u('XS-END'), pg_temp.u('O-CS101'), pg_temp.lk('assessment_type','END_TERM'), 'A', pg_temp.lk('question_paper_status','SUBMITTED'), pg_temp.u('PS-SET'), now(), 100, 180);
SELECT pg_temp.rejects($q$UPDATE exam.question_paper SET question_paper_status_id = ref.id_of('question_paper_status','APPROVED'),
  approved_by_employee_id = md5('E-ALICE')::uuid, approved_at = now() WHERE id = md5('QP-A')::uuid$q$, 'approving a paper that was never moderated');
SELECT pg_temp.rejects($q$UPDATE exam.question_paper SET moderated_by_assignment_id = md5('PS-SET')::uuid, moderated_at = now() WHERE id = md5('QP-A')::uuid$q$,
  'moderation recorded against the setter''s assignment');
UPDATE exam.question_paper SET question_paper_status_id = pg_temp.lk('question_paper_status','MODERATED'), moderated_by_assignment_id = pg_temp.u('PS-MOD'), moderated_at = now()
WHERE id = pg_temp.u('QP-A');
SELECT pg_temp.rejects($q$UPDATE exam.exam_schedule SET question_paper_id = md5('QP-A')::uuid WHERE id = md5('SCH-101')::uuid$q$, 'date sheet using a paper that is not yet approved');
UPDATE exam.question_paper SET question_paper_status_id = pg_temp.lk('question_paper_status','APPROVED'), approved_by_employee_id = pg_temp.u('E-ALICE'), approved_at = now()
WHERE id = pg_temp.u('QP-A');
UPDATE exam.exam_schedule SET question_paper_id = pg_temp.u('QP-A') WHERE id = pg_temp.u('SCH-101');
SELECT pg_temp.rejects($q$UPDATE exam.exam_schedule SET question_paper_id = md5('QP-A')::uuid WHERE id = md5('SCH-201')::uuid$q$, 'date sheet of another course using this paper');
SELECT pg_temp.ok(true, 'question paper: set → moderated by a different person → approved → on the date sheet');

-- ---- certificates and convocation ----
INSERT INTO exam.convocation (id, academic_year_id, name, held_on) VALUES (pg_temp.u('CONV-1'), pg_temp.u('Y-B'), '1st Convocation', current_date + 200);
SELECT pg_temp.rejects($q$INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, issued_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, ref.id_of('certificate_type','AWARD_CERTIFICATE'), 'SGT/DC/0001', 'V-0001', md5('E-ALICE')::uuid)$q$,
  'award certificate without a conferred award');
INSERT INTO exam.certificate (id, student_enrollment_id, certificate_type_id, serial_no, verification_code, student_award_id, convocation_id, issued_by_employee_id)
VALUES (pg_temp.u('CERT-1'), pg_temp.u('EN-CAROL'), pg_temp.lk('certificate_type','AWARD_CERTIFICATE'), 'SGT/DC/0001', 'V-0001', pg_temp.u('SA-CAROL'), pg_temp.u('CONV-1'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, student_award_id, issued_by_employee_id)
  VALUES (md5('EN-CAROL')::uuid, ref.id_of('certificate_type','AWARD_CERTIFICATE'), 'SGT/DC/0002', 'V-0002', md5('SA-CAROL')::uuid, md5('E-ALICE')::uuid)$q$,
  'second original award certificate');
SELECT pg_temp.rejects($q$INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, student_award_id, issued_by_employee_id)
  VALUES (md5('EN-IVAN')::uuid, ref.id_of('certificate_type','AWARD_CERTIFICATE'), 'SGT/DC/0003', 'V-0003', md5('SA-CAROL')::uuid, md5('E-ALICE')::uuid)$q$,
  'certificate citing another student''s award');
INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, student_award_id, issued_by_employee_id, is_duplicate)
VALUES (pg_temp.u('EN-CAROL'), pg_temp.lk('certificate_type','AWARD_CERTIFICATE'), 'SGT/DC/0004', 'V-0004', pg_temp.u('SA-CAROL'), pg_temp.u('E-ALICE'), true);
SELECT pg_temp.rejects($q$INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, issued_by_employee_id)
  VALUES (md5('EN-IVAN')::uuid, ref.id_of('certificate_type','MIGRATION'), 'SGT/MG/0001', 'V-0005', md5('E-ALICE')::uuid)$q$,
  'migration certificate while the enrollment is open');
INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, issued_by_employee_id) VALUES
 (pg_temp.u('EN-CAROL'), pg_temp.lk('certificate_type','MIGRATION'), 'SGT/MG/0001', 'V-0005', pg_temp.u('E-ALICE')),
 (pg_temp.u('EN-IVAN'),  pg_temp.lk('certificate_type','BONAFIDE'),  'SGT/BF/0001', 'V-0006', pg_temp.u('E-ALICE')),
 (pg_temp.u('EN-IVAN'),  pg_temp.lk('certificate_type','BONAFIDE'),  'SGT/BF/0002', 'V-0007', pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.certificate (student_enrollment_id, certificate_type_id, serial_no, verification_code, convocation_id, issued_by_employee_id)
  VALUES (md5('EN-IVAN')::uuid, ref.id_of('certificate_type','BONAFIDE'), 'SGT/BF/0003', 'V-0008', md5('CONV-1')::uuid, md5('E-ALICE')::uuid)$q$,
  'a bonafide certificate conferred at a convocation');
SELECT pg_temp.ok(true, 'certificate register: one original award / migration certificate per enrollment, duplicates and repeat bonafides allowed');

-- ============================ SOE: curriculum approval workflow & SOE content ==
-- people who review / sign: a Dean of SET, the Dean Academics, the Registrar,
-- and an external examiner (a person, not an employee)
INSERT INTO people.person (id, first_name) VALUES
 (pg_temp.u('DEANP'), 'Deepa'), (pg_temp.u('DACP'), 'Arun'), (pg_temp.u('REGP'), 'Ritu'), (pg_temp.u('EXTP'), 'Xavier'), (pg_temp.u('OLIVIA'), 'Olivia');
INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on) VALUES
 (pg_temp.u('E-DEAN'), pg_temp.u('DEANP'), 'E2001', pg_temp.lk('employee_category','TEACHING'),     pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2010-01-01'),
 (pg_temp.u('E-DAC'),  pg_temp.u('DACP'),  'E2002', pg_temp.lk('employee_category','TEACHING'),     pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2008-01-01'),
 (pg_temp.u('E-REG'),  pg_temp.u('REGP'),  'E2003', pg_temp.lk('employee_category','NON_TEACHING'), pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2012-01-01');
INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid) VALUES
 (pg_temp.u('SET'),  (SELECT id FROM org.position_type WHERE code='DEAN'),           pg_temp.u('E-DEAN'), daterange('2020-01-01', NULL)),
 (pg_temp.u('SGTU'), (SELECT id FROM org.position_type WHERE code='DEAN_ACADEMICS'), pg_temp.u('E-DAC'),  daterange('2020-01-01', NULL)),
 (pg_temp.u('SGTU'), (SELECT id FROM org.position_type WHERE code='REGISTRAR'),      pg_temp.u('E-REG'),  daterange('2020-01-01', NULL));
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id) VALUES
 (pg_temp.u('A-FRANK'), pg_temp.u('FRANK'), 'E1004', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-DEAN'),  pg_temp.u('DEANP'), 'E2001', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-DAC'),   pg_temp.u('DACP'),  'E2002', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-REG'),   pg_temp.u('REGP'),  'E2003', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE'));
-- Alice's account was suspended by the IAM tests: a suspended HOD holds no review power at all
SELECT pg_temp.ok(NOT authz.has_permission(pg_temp.u('A-ALICE'), 'academics.curriculum_department_review.approve', pg_temp.u('CSE')),
  'a suspended account cannot review, even as HOD');
UPDATE iam.user_account SET account_status_id = pg_temp.lk('account_status','ACTIVE') WHERE id = pg_temp.u('A-ALICE');
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'academics.curriculum_department_review.approve', pg_temp.u('CSE'))
              AND NOT authz.has_permission(pg_temp.u('A-ALICE'), 'academics.curriculum_department_review.approve', pg_temp.u('MBA'))
              AND authz.has_permission(pg_temp.u('A-DEAN'), 'academics.curriculum_school_review.approve', pg_temp.u('SET'))
              AND NOT authz.has_permission(pg_temp.u('A-DEAN'), 'academics.curriculum_school_review.approve', pg_temp.u('SOM'))
              AND authz.has_permission(pg_temp.u('A-DAC'), 'academics.curriculum_university_review.approve', pg_temp.u('SGTU'))
              AND authz.has_permission(pg_temp.u('A-REG'), 'academics.curriculum.sign', pg_temp.u('SGTU'))
              AND authz.account_requires_mfa(pg_temp.u('A-REG')),
  'SOE reviewers derived from appointments: HOD → department stage (own dept only), Dean → school stage, Dean Academics → university, Registrar → sign (MFA)');

-- ---- SGT-style schemes of examination ----
INSERT INTO academic.evaluation_scheme (id, code, name, min_aggregate_pct) VALUES
 (9020, 'SGT_THEORY', 'SGT theory: thematic 40 / unit 30 / experiential 20 / participation 10', 40),
 (9021, 'SGT_PRACTICAL', 'SGT practical: 4 × lab / clinical / OSPE 25', 40),
 (9022, 'SGT_DISSERTATION', 'SGT dissertation: report 20 + viva 30 (external) / internal 50', 40);
INSERT INTO academic.evaluation_component (evaluation_scheme_id, assessment_type_id, name, weight_pct, max_marks, min_pass_marks) VALUES
 (9020, pg_temp.lk('assessment_type','THEMATIC_ASSESSMENT'),   'Thematic assessment', 40, 40, 16),
 (9020, pg_temp.lk('assessment_type','UNIT_ASSESSMENT'),       'Unit assessment', 30, 30, 12),
 (9020, pg_temp.lk('assessment_type','EXPERIENTIAL_LEARNING'), 'Experiential and reflective learning', 20, 20, NULL),
 (9020, pg_temp.lk('assessment_type','PARTICIPATION'),         'Participation & engagement', 10, 10, NULL),
 (9021, pg_temp.lk('assessment_type','LAB_EVALUATION'), 'Lab 1', 25, 25, NULL),
 (9021, pg_temp.lk('assessment_type','LAB_EVALUATION'), 'Lab 2', 25, 25, NULL),
 (9021, pg_temp.lk('assessment_type','LAB_EVALUATION'), 'Lab 3', 25, 25, NULL),
 (9021, pg_temp.lk('assessment_type','LAB_EVALUATION'), 'Lab 4', 25, 25, NULL),
 (9022, pg_temp.lk('assessment_type','REPORT_EVALUATION'), 'Report / demonstration', 20, 20, NULL),
 (9022, pg_temp.lk('assessment_type','VIVA_VOCE_EXAM'),    'Viva-voce / presentation', 30, 30, NULL),
 (9022, pg_temp.lk('assessment_type','INTERNAL'),          'Internal', 50, 50, NULL);
INSERT INTO academic.evaluation_part_rule (evaluation_scheme_id, evaluation_part_id, min_pass_pct) VALUES
 (9020, pg_temp.lk('evaluation_part','INTERNAL'), 40), (9021, pg_temp.lk('evaluation_part','INTERNAL'), 40),
 (9022, pg_temp.lk('evaluation_part','INTERNAL'), 40), (9022, pg_temp.lk('evaluation_part','EXTERNAL'), 40);
SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights IMMEDIATE;
SET CONSTRAINTS academic.trg_evaluation_scheme_weights, academic.trg_evaluation_group_weights DEFERRED;

-- ---- courses, council codes, continuation ----
INSERT INTO academic.course (id, code, title, owner_org_unit_id, credits) VALUES
 (pg_temp.u('C-OT101'), 'OT101', 'Human Anatomy - Theory', pg_temp.u('CSE'), 3),
 (pg_temp.u('C-OT102'), 'OT102', 'Human Anatomy - Practical', pg_temp.u('CSE'), 1),
 (pg_temp.u('C-MDC1'),  'MDC101', 'Multidisciplinary: Design Thinking', pg_temp.u('CSE'), 3),
 (pg_temp.u('C-OT7A'),  'OT701', 'Advanced OT Management', pg_temp.u('CSE'), 3),
 (pg_temp.u('C-INT1'),  'OT706', 'Internship-1', pg_temp.u('CSE'), 4),
 (pg_temp.u('C-DIS1'),  'OT705', 'Dissertation - I', pg_temp.u('CSE'), 6),
 (pg_temp.u('C-DIS2'),  'OT806', 'Dissertation - II', pg_temp.u('CSE'), 6);
INSERT INTO academic.course_component_hours (course_id, delivery_component_id, hours_per_week)
SELECT pg_temp.u(v.c), pg_temp.lk('delivery_component', v.d), v.h
FROM (VALUES ('C-OT101','LECTURE',3),('C-OT102','PRACTICAL',2),('C-MDC1','LECTURE',3),('C-OT7A','LECTURE',3),
             ('C-INT1','PRACTICAL',8),('C-DIS1','PRACTICAL',12),('C-DIS2','PRACTICAL',12)) v(c, d, h);
INSERT INTO academic.course_regulator_code (course_id, regulatory_body_id, code)
VALUES (pg_temp.u('C-OT101'), pg_temp.lk('regulatory_body','NMC'), 'ANAT-01');
SELECT pg_temp.rejects($q$INSERT INTO academic.course_regulator_code (course_id, regulatory_body_id, code)
  VALUES (md5('C-OT102')::uuid, ref.id_of('regulatory_body','NMC'), 'ANAT-01')$q$, 'the same council code on two courses');
INSERT INTO academic.course_continuation (course_id, continues_course_id) VALUES (pg_temp.u('C-DIS2'), pg_temp.u('C-DIS1'));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_continuation (course_id, continues_course_id)
  VALUES (md5('C-DIS1')::uuid, md5('C-DIS2')::uuid)$q$, 'course continuation loop (Dissertation I continuing II)');

-- ---- the curriculum version (the SOE) with pathways, a combined result and exits ----
INSERT INTO academic.curriculum (id, program_id, code, name, grade_scale_id, attendance_threshold_pct, allows_internal_marks_revision)
VALUES (pg_temp.u('CUR-SOE'), pg_temp.u('P-BTECH'), 'R2022', 'B.Sc.-style regulations 2022 (SOE test)',
        (SELECT id FROM academic.grade_scale WHERE code='UGC_10'), 75, true);
INSERT INTO academic.curriculum_pathway (id, curriculum_id, code, name, from_term_no) VALUES
 (pg_temp.u('PW-HONS'), pg_temp.u('CUR-SOE'), 'HONS', 'Honours', 7),
 (pg_temp.u('PW-RES'),  pg_temp.u('CUR-SOE'), 'HONS-RES', 'Honours with Research', 7);
INSERT INTO academic.result_group (id, curriculum_id, code, name, min_pass_pct)
VALUES (pg_temp.u('RG-ANAT'), pg_temp.u('CUR-SOE'), 'ANAT', 'Human Anatomy (theory + practical)', 40);
INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id, pathway_id, result_group_id) VALUES
 (pg_temp.u('CUR-SOE'), 1, pg_temp.u('C-OT101'), pg_temp.lk('course_category','DSCC'), 9020, NULL, pg_temp.u('RG-ANAT')),
 (pg_temp.u('CUR-SOE'), 1, pg_temp.u('C-OT102'), pg_temp.lk('course_category','DSCC'), 9021, NULL, pg_temp.u('RG-ANAT')),
 (pg_temp.u('CUR-SOE'), 7, pg_temp.u('C-OT7A'),  pg_temp.lk('course_category','DSCC'), 9020, pg_temp.u('PW-HONS'), NULL),
 (pg_temp.u('CUR-SOE'), 7, pg_temp.u('C-OT7A'),  pg_temp.lk('course_category','DSCC'), 9021, pg_temp.u('PW-RES'), NULL),
 (pg_temp.u('CUR-SOE'), 7, pg_temp.u('C-INT1'),  pg_temp.lk('course_category','IACP'), 9022, pg_temp.u('PW-HONS'), NULL),
 (pg_temp.u('CUR-SOE'), 7, pg_temp.u('C-DIS1'),  pg_temp.lk('course_category','DISSERTATION'), 9022, pg_temp.u('PW-RES'), NULL),
 (pg_temp.u('CUR-SOE'), 8, pg_temp.u('C-DIS2'),  pg_temp.lk('course_category','DISSERTATION'), 9022, pg_temp.u('PW-RES'), NULL);
SELECT pg_temp.ok(true, 'the same course may sit on two pathways (Honours / Honours with Research) with different schemes');
INSERT INTO academic.elective_basket (id, curriculum_id, code, name, term_no, course_category_id, courses_to_choose)
VALUES (pg_temp.u('EB-MDC1'), pg_temp.u('CUR-SOE'), 'MDC-1', 'Multi Disciplinary Course-1', 1, pg_temp.lk('course_category','MULTIDISCIPLINARY'), 1);
INSERT INTO academic.elective_basket_course (elective_basket_id, course_id, evaluation_scheme_id) VALUES (pg_temp.u('EB-MDC1'), pg_temp.u('C-MDC1'), 9020);
SELECT pg_temp.rejects($q$INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id)
  VALUES (md5('CUR-SOE')::uuid, 7, md5('C-OT7A')::uuid, ref.id_of('course_category','DSCC'), 9020)$q$,
  'a course both common and on a pathway');
SELECT pg_temp.rejects($q$INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id, pathway_id)
  VALUES (md5('CUR-SOE')::uuid, 5, md5('C-MB101')::uuid, ref.id_of('course_category','DSCC'), 9020, md5('PW-HONS')::uuid)$q$,
  'pathway course before the pathway starts');
SELECT pg_temp.rejects($q$INSERT INTO academic.curriculum_course (curriculum_id, term_no, course_id, course_category_id, evaluation_scheme_id, pathway_id)
  VALUES (md5('CUR-BT')::uuid, 7, md5('C-OT101')::uuid, ref.id_of('course_category','DSCC'), 9020, md5('PW-HONS')::uuid)$q$,
  'pathway of another curriculum');
INSERT INTO academic.award_rule (id, curriculum_id, award_type_id, award_title, after_term_no, min_credits, reentry_within_years, pathway_id) VALUES
 (pg_temp.u('AR-SOE-CERT'), pg_temp.u('CUR-SOE'), pg_temp.lk('award_type','UG_CERTIFICATE'), 'Certificate in OT Technology', 1, 7, 3, NULL),
 (pg_temp.u('AR-SOE-HONS'), pg_temp.u('CUR-SOE'), pg_temp.lk('award_type','BACHELOR_HONOURS'), 'B.Sc. (Honours) OT Technology', 8, 17, NULL, pg_temp.u('PW-HONS')),
 (pg_temp.u('AR-SOE-RES'),  pg_temp.u('CUR-SOE'), pg_temp.lk('award_type','BACHELOR_HONOURS_RESEARCH'), 'B.Sc. (Honours with Research) OT Technology', 8, 22, NULL, pg_temp.u('PW-RES'));
INSERT INTO academic.attempt_allowance (curriculum_id, exam_attempt_type_id, max_attempts)
VALUES (pg_temp.u('CUR-SOE'), pg_temp.lk('exam_attempt_type','GOLDEN_CHANCE'), 1);

-- ---- the SOE, derived ----
SELECT pg_temp.ok((SELECT semester_year = 'I/I' AND course_category = 'DSC' AND course_sub_category = 'DSCC' AND result_type = 'Combined'
                          AND theory_practical = 'Theory' AND council_code = 'NMC:ANAT-01' AND lecture = 3 AND credits = 3
                          AND internal_max = 100 AND internal_pass = 40 AND external_max IS NULL AND passing_criteria = 'Internal'
                          AND internal_components LIKE 'Thematic assessment 40 (pass 16); Unit assessment 30 (pass 12)%'
                   FROM academic.v_soe WHERE curriculum_id = pg_temp.u('CUR-SOE') AND subject_code = 'OT101'),
  'SOE row: semester/year, category + sub-category, combined result, council code, L-T-P, internal 100 / pass 40 with its components');
SELECT pg_temp.ok((SELECT semester_year = 'VII/IV' AND pathway = 'HONS-RES' AND theory_practical = 'Practical'
                          AND external_max = 50 AND external_pass = 20 AND internal_max = 50 AND passing_criteria = 'External + Internal'
                   FROM academic.v_soe WHERE curriculum_id = pg_temp.u('CUR-SOE') AND subject_code = 'OT705'),
  'SOE row: dissertation — external 50 (pass 20) + internal 50, "External + Internal", on the research pathway');
SELECT pg_temp.ok((SELECT row_kind = 'ELECTIVE_SLOT' AND nomenclature = 'Multi Disciplinary Course-1' AND credits = 3 AND course_category = 'MULTIDISCIPLINARY'
                   FROM academic.v_soe WHERE curriculum_id = pg_temp.u('CUR-SOE') AND subject_code IS NULL),
  'SOE row: an elective slot ("Multi Disciplinary Course-1") with its credits');
SELECT pg_temp.ok((SELECT cumulative_credits = 7 AND exit_award = 'Certificate in OT Technology'
                   FROM academic.v_soe_exit WHERE curriculum_id = pg_temp.u('CUR-SOE') AND pathway IS NULL AND term_no = 1)
              AND (SELECT term_credits = 9 FROM academic.v_soe_exit WHERE curriculum_id = pg_temp.u('CUR-SOE') AND pathway = 'HONS-RES' AND term_no = 7)
              AND (SELECT term_credits = 7 FROM academic.v_soe_exit WHERE curriculum_id = pg_temp.u('CUR-SOE') AND pathway = 'HONS' AND term_no = 7)
              AND (SELECT cumulative_credits = 22 AND exit_award = 'B.Sc. (Honours with Research) OT Technology'
                   FROM academic.v_soe_exit WHERE curriculum_id = pg_temp.u('CUR-SOE') AND pathway = 'HONS-RES' AND term_no = 8),
  'SOE exits: credits per term and cumulative per pathway, with "Exit with …" rows');
SELECT pg_temp.ok((SELECT department = 'Computer Science & Engineering' AND school = 'School of Engineering & Technology' AND status = 'DRAFT'
                   FROM academic.v_soe_header WHERE curriculum_id = pg_temp.u('CUR-SOE')),
  'SOE header: department and school from the org tree; status DRAFT');

-- ---- approval round 1: submitted, reviewed, returned ----
SELECT pg_temp.rejects($q$SELECT academic.submit_curriculum(md5('CUR-SOE')::uuid, md5('A-FRANK')::uuid)$q$,
  'submitting an SOE without being the programme coordinator or a curriculum administrator');
SELECT academic.submit_curriculum(pg_temp.u('CUR-SOE'), pg_temp.u('A-ALICE'), 'SOE 2022 regulations');   -- Alice coordinates P-BTECH
SELECT pg_temp.ok((SELECT status = 'IN_REVIEW' AND current_step = 'DEPARTMENT' FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE'))
              AND (SELECT string_agg(st.code || '@' || u.code, ',' ORDER BY st.seq) FROM wf.approval_step st JOIN org.org_unit u ON u.id = st.anchor_org_unit_id
                   WHERE st.instance_id = (SELECT instance_id FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE')))
                  = 'DEPARTMENT@CSE,SCHOOL@SET,UNIVERSITY@SGTU,SIGN@SGTU',
  'submission snapshots the chain with anchors resolved: CSE → SET → university → sign');
SELECT pg_temp.rejects($q$SELECT academic.submit_curriculum(md5('CUR-SOE')::uuid, md5('A-ALICE')::uuid)$q$, 'submitting an SOE already under review');
CREATE FUNCTION pg_temp.soe_round() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT instance_id FROM academic.v_curriculum_status WHERE curriculum_id = md5('CUR-SOE')::uuid $$;
CREATE FUNCTION pg_temp.soe_act(p_action text, p_seq int, p_actor text, p_note text DEFAULT NULL, p_file uuid DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id, note, file_object_id)
  VALUES (pg_temp.soe_round(), p_seq, ref.id_of('wf_action_type', p_action), md5(p_actor)::uuid, p_note, p_file) $$;
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 1, 'A-ALICE')$q$, 'the submitter (also the HOD) approving her own SOE');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 1, 'A-EVE')$q$, 'approving without the department-review permission');
-- acting HOD: a dated grant to Frank, scoped to CSE — no role column edited anywhere
INSERT INTO authz.account_role (account_id, role_id, scope_org_unit_id, valid, reason)
VALUES (pg_temp.u('A-FRANK'), (SELECT id FROM authz.role WHERE code='CURRICULUM_DEPT_REVIEWER'), pg_temp.u('CSE'),
        tstzrange(now() - interval '1 day', now() + interval '30 days'), 'Acting HOD while the HOD is the SOE author');
SELECT pg_temp.soe_act('APPROVE', 1, 'A-FRANK');
SELECT pg_temp.ok((SELECT current_step = 'SCHOOL' FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE')),
  'acting HOD (time-boxed scoped grant) approves the department stage');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 2, 'A-FRANK')$q$, 'department reviewer acting on the school stage');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 3, 'A-DEAN')$q$, 'approving a stage that is not the current one');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-DEAN')) WHERE instance_id = pg_temp.soe_round())
              AND NOT EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-DAC')) WHERE instance_id = pg_temp.soe_round()),
  'pending queue: the Dean of SET sees it, the Dean Academics not yet');
INSERT INTO wf.approval_comment (instance_id, step_seq, author_account_id, target_table, target_row_id, target_column, body, suggested_value, wf_comment_status_id)
SELECT pg_temp.soe_round(), 2, pg_temp.u('A-DEAN'), 'academic.course', pg_temp.u('C-OT102'), 'credits',
       'Practical hours justify 1 credit only if the lab is 2 h', '1', pg_temp.lk('wf_comment_status','PENDING');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_comment (instance_id, step_seq, author_account_id, body, wf_comment_status_id)
  VALUES (pg_temp.soe_round(), 2, md5('A-EVE')::uuid, 'drive-by remark', ref.id_of('wf_comment_status','PENDING'))$q$,
  'comment by someone who is not the reviewer of the current stage');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_comment (instance_id, step_seq, author_account_id, target_table, target_column, body, wf_comment_status_id)
  VALUES (pg_temp.soe_round(), 2, md5('A-DEAN')::uuid, 'academic.course', 'shoe_size', 'x', ref.id_of('wf_comment_status','PENDING'))$q$,
  'comment on a column that does not exist');
-- while in review: the author may not edit; the current reviewer may (in-place edit, audited)
SELECT set_config('app.account_id', pg_temp.u('A-ALICE')::text, true);
SELECT pg_temp.rejects($q$UPDATE academic.curriculum SET name = name || ' (edited)' WHERE id = md5('CUR-SOE')::uuid$q$,
  'the author editing an SOE that is under review');
SELECT set_config('app.account_id', pg_temp.u('A-DEAN')::text, true);
UPDATE academic.curriculum SET name = 'B.Sc.-style regulations 2022 (SOE test, reviewed)' WHERE id = pg_temp.u('CUR-SOE');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM audit.audit_event e JOIN audit.audit_change c ON c.audit_event_id = e.id AND c.occurred_at = e.occurred_at
                          WHERE e.entity_table = 'curriculum' AND e.actor_account_id = pg_temp.u('A-DEAN') AND c.column_name = 'name'),
  'reviewer in-place edit allowed at the current stage and captured in the audit trail with the reviewer');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('RETURN', 2, 'A-DEAN')$q$, 'returning without a note');
SELECT pg_temp.soe_act('RETURN', 2, 'A-DEAN', 'Please justify the practical credit');
SELECT pg_temp.ok((SELECT status = 'RETURNED' AND current_step IS NULL FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE'))
              AND NOT EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-DEAN'))),
  'a return closes the round; nothing pending');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 2, 'A-DEAN')$q$, 'acting on a returned round');
SELECT pg_temp.rejects($q$UPDATE wf.approval_comment SET wf_comment_status_id = ref.id_of('wf_comment_status','ACCEPTED'),
  resolved_by_account_id = md5('A-DEAN')::uuid, resolved_at = now() WHERE instance_id = pg_temp.soe_round()$q$,
  'a reviewer resolving their own comment');
UPDATE wf.approval_comment SET wf_comment_status_id = pg_temp.lk('wf_comment_status','ACCEPTED'), resolved_by_account_id = pg_temp.u('A-ALICE'), resolved_at = now()
WHERE instance_id = pg_temp.soe_round();
SELECT pg_temp.rejects($q$UPDATE wf.approval_action SET note = 'rewritten' WHERE instance_id = pg_temp.soe_round()$q$, 'workflow actions are append-only');
SELECT set_config('app.account_id', pg_temp.u('A-ALICE')::text, true);
UPDATE academic.curriculum SET name = 'B.Sc.-style regulations 2022 (SOE test)' WHERE id = pg_temp.u('CUR-SOE');
SELECT pg_temp.ok(true, 'the author edits again once the SOE is returned');

-- ---- round 2: approved at every level and signed ----
SELECT academic.submit_curriculum(pg_temp.u('CUR-SOE'), pg_temp.u('A-ALICE'), 'Resubmitted with the practical credit justified');
SELECT pg_temp.ok((SELECT status = 'IN_REVIEW' AND rounds = 2 FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE')),
  'resubmission opens round 2; round 1 stays on record');
SELECT pg_temp.soe_act('APPROVE', 1, 'A-FRANK');
SELECT pg_temp.soe_act('APPROVE', 2, 'A-DEAN');
INSERT INTO authz.account_role (account_id, role_id, scope_org_unit_id, reason)
VALUES (pg_temp.u('A-DEAN'), (SELECT id FROM authz.role WHERE code='CURRICULUM_UNIVERSITY_REVIEWER'), pg_temp.u('SGTU'), 'Also on the academic council');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 3, 'A-DEAN')$q$, 'one person approving two stages of the same round');
SELECT pg_temp.soe_act('APPROVE', 3, 'A-DAC');
SELECT pg_temp.ok((SELECT status = 'APPROVED' AND current_step = 'SIGN' FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE'))
              AND EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-REG')) WHERE instance_id = pg_temp.soe_round()),
  'approved at department, school and university — waiting in the Registrar''s queue');
SELECT set_config('app.account_id', pg_temp.u('A-DAC')::text, true);
SELECT pg_temp.rejects($q$UPDATE academic.curriculum_course SET term_no = 2 WHERE curriculum_id = md5('CUR-SOE')::uuid AND course_id = md5('C-OT102')::uuid$q$,
  'editing an approved SOE, even by a reviewer');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('APPROVE', 4, 'A-REG')$q$, 'approving the signature step instead of signing');
SELECT pg_temp.rejects($q$SELECT pg_temp.soe_act('SIGN', 4, 'A-REG')$q$, 'signing without the signed document');
INSERT INTO people.file_object (id, storage_backend_id, object_key, mime_type, byte_size, sha256)
VALUES (pg_temp.u('F-SOE-SIGNED'), pg_temp.lk('storage_backend','S3'), 'soe/R2022-signed.pdf', 'application/pdf', 1024, digest('soe', 'sha256'));
SELECT pg_temp.soe_act('SIGN', 4, 'A-REG', NULL, pg_temp.u('F-SOE-SIGNED'));
SELECT pg_temp.ok((SELECT status = 'SIGNED' AND signed_by_account_id = pg_temp.u('A-REG') AND signed_at IS NOT NULL
                   FROM academic.v_curriculum_status WHERE curriculum_id = pg_temp.u('CUR-SOE'))
              AND (SELECT status = 'SIGNED' FROM academic.v_soe_header WHERE curriculum_id = pg_temp.u('CUR-SOE')),
  'Registrar sign-off: the SOE is SIGNED');
SELECT pg_temp.rejects($q$DELETE FROM academic.elective_basket_course WHERE elective_basket_id = md5('EB-MDC1')::uuid$q$, 'changing a signed SOE');
SELECT pg_temp.rejects($q$UPDATE academic.evaluation_component SET max_marks = 45 WHERE evaluation_scheme_id = 9020 AND name = 'Thematic assessment'$q$,
  'changing a scheme of examination used by a signed SOE');
SELECT pg_temp.rejects($q$UPDATE academic.course SET credits = 4 WHERE id = md5('C-OT101')::uuid$q$, 'changing the credits of a course in a signed SOE');
SELECT pg_temp.rejects($q$INSERT INTO academic.attempt_allowance (curriculum_id, exam_attempt_type_id, max_attempts)
  VALUES (md5('CUR-SOE')::uuid, ref.id_of('exam_attempt_type','MERCY_CHANCE'), 1)$q$, 'adding an exam rule to a signed SOE');
UPDATE academic.curriculum SET is_active = true WHERE id = pg_temp.u('CUR-SOE');
UPDATE academic.evaluation_scheme SET name = name WHERE id = 9001;
SELECT pg_temp.ok(true, 'retiring / re-activating a signed version and editing schemes of unsigned curricula remain possible');
SELECT set_config('app.account_id', '', true);

-- ---- a student on a pathway (lateral entry into term 7) ----
INSERT INTO academic.academic_year (id, code, period) VALUES (pg_temp.u('Y-OLD'), '2022-23', daterange(current_date - 1500, current_date - 1135));
INSERT INTO academic.batch (id, program_id, admission_year_id, intake_capacity) VALUES (pg_temp.u('B-2022'), pg_temp.u('P-BTECH'), pg_temp.u('Y-OLD'), 60);
INSERT INTO academic.batch_curriculum (batch_id, curriculum_id) VALUES (pg_temp.u('B-2022'), pg_temp.u('CUR-SOE'));
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
VALUES (pg_temp.u('S-OLIVIA'), pg_temp.u('OLIVIA'), 'SGT2022OT007', pg_temp.lk('student_status','ACTIVE'), current_date - 25);
INSERT INTO academic.student_enrollment (id, student_id, batch_id, entry_term_no, valid)
VALUES (pg_temp.u('EN-OLIVIA'), pg_temp.u('S-OLIVIA'), pg_temp.u('B-2022'), 7, daterange(current_date - 25, NULL));
INSERT INTO academic.course_offering (id, course_id, academic_term_id, offering_org_unit_id) VALUES
 (pg_temp.u('O-OT101'), pg_temp.u('C-OT101'), pg_temp.term('Y-B','ODD'), pg_temp.u('CSE')),
 (pg_temp.u('O-OT102'), pg_temp.u('C-OT102'), pg_temp.term('Y-B','ODD'), pg_temp.u('CSE')),
 (pg_temp.u('O-OT7A'),  pg_temp.u('C-OT7A'),  pg_temp.term('Y-B','ODD'), pg_temp.u('CSE')),
 (pg_temp.u('O-INT1'),  pg_temp.u('C-INT1'),  pg_temp.term('Y-B','ODD'), pg_temp.u('CSE')),
 (pg_temp.u('O-DIS1'),  pg_temp.u('C-DIS1'),  pg_temp.term('Y-B','ODD'), pg_temp.u('CSE')),
 (pg_temp.u('O-DIS2'),  pg_temp.u('C-DIS2'),  pg_temp.term('Y-B','EVEN'), pg_temp.u('CSE'));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-OLIVIA')::uuid, md5('O-DIS1')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'registering a pathway course before choosing the pathway');
SELECT pg_temp.rejects($q$INSERT INTO academic.student_pathway (student_enrollment_id, curriculum_pathway_id)
  VALUES (md5('EN-CAROL-2')::uuid, md5('PW-RES')::uuid)$q$, 'choosing a pathway of another curriculum');
INSERT INTO academic.student_pathway (student_enrollment_id, curriculum_pathway_id, valid)
VALUES (pg_temp.u('EN-OLIVIA'), pg_temp.u('PW-RES'), daterange(current_date - 25, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-OLIVIA')::uuid, md5('O-DIS2')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'Dissertation II before Dissertation I (course continuation)');
SELECT pg_temp.ok(academic.register_core_courses(pg_temp.u('B-2022'), pg_temp.term('Y-B','ODD')) = 2,
  'core registration follows the pathway: OT701 + Dissertation I, not the Honours internship');
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-OLIVIA')::uuid, md5('O-INT1')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'registering a course of the other pathway');
SELECT pg_temp.ok((SELECT rs.evaluation_scheme_id = 9021 FROM academic.v_registration_scheme rs
                   JOIN academic.course_registration r ON r.id = rs.course_registration_id
                   WHERE r.student_enrollment_id = pg_temp.u('EN-OLIVIA') AND r.course_offering_id = pg_temp.u('O-OT7A')),
  'a course on two pathways takes the scheme of the student''s pathway');
INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id) VALUES
 (pg_temp.u('R-O-DIS2'), pg_temp.u('EN-OLIVIA'), pg_temp.u('O-DIS2'), pg_temp.lk('registration_status','REGISTERED')),
 (pg_temp.u('R-O-101'),  pg_temp.u('EN-OLIVIA'), pg_temp.u('O-OT101'), pg_temp.lk('registration_status','REGISTERED')),
 (pg_temp.u('R-O-102'),  pg_temp.u('EN-OLIVIA'), pg_temp.u('O-OT102'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.ok(true, 'Dissertation II accepted once Dissertation I is registered in an earlier term');
SELECT pg_temp.rejects($q$INSERT INTO academic.award_rule (curriculum_id, award_type_id, award_title, after_term_no, min_credits, pathway_id)
  VALUES (md5('CUR-BT')::uuid, ref.id_of('award_type','BACHELOR_HONOURS'), 'x', 8, 10, md5('PW-HONS')::uuid)$q$,
  'award rule tied to a pathway of another curriculum');

-- ---- combined theory + practical result ----
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id) VALUES
 (pg_temp.u('ER-O-101'), pg_temp.u('XS-END'), pg_temp.u('R-O-101'), pg_temp.lk('exam_attempt_type','REGULAR')),
 (pg_temp.u('ER-O-102'), pg_temp.u('XS-END'), pg_temp.u('R-O-102'), pg_temp.lk('exam_attempt_type','REGULAR'));
INSERT INTO exam.component_mark (id, course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
SELECT pg_temp.u('CM-O-' || v.n), pg_temp.u(v.r), ec.id, v.m, pg_temp.u('E-ALICE')
FROM (VALUES ('R-O-101', 9020, 'Thematic assessment', 20), ('R-O-101', 9020, 'Unit assessment', 15),
             ('R-O-101', 9020, 'Experiential and reflective learning', 10), ('R-O-101', 9020, 'Participation & engagement', 5),
             ('R-O-102', 9021, 'Lab 1', 5), ('R-O-102', 9021, 'Lab 2', 5), ('R-O-102', 9021, 'Lab 3', 5), ('R-O-102', 9021, 'Lab 4', 5)) v(r, s, n, m)
JOIN academic.evaluation_component ec ON ec.evaluation_scheme_id = v.s AND ec.name = v.n;
INSERT INTO exam.result_publication (id, exam_session_id, publication_type_id, published_by_employee_id)
VALUES (pg_temp.u('PUB-SOE'), pg_temp.u('XS-END'), pg_temp.lk('publication_type','ORIGINAL'), pg_temp.u('E-ALICE'));
INSERT INTO exam.course_result (result_publication_id, exam_registration_id, total_pct, grade_band_id, result_status_id)
SELECT pg_temp.u('PUB-SOE'), exam_registration_id, total_pct, grade_band_id,
       CASE WHEN is_pass THEN pg_temp.lk('result_status','PASS') ELSE pg_temp.lk('result_status','FAIL') END
FROM exam.v_provisional_result WHERE exam_registration_id IN (pg_temp.u('ER-O-101'), pg_temp.u('ER-O-102'));
-- theory 50 % (3 cr), practical 20 % (1 cr) → combined (150 + 20) / 4 = 42.5 % ≥ 40 → both pass as one result
SELECT pg_temp.ok((SELECT combined_pct = 42.50 AND is_pass AND courses_with_result = 2 FROM exam.v_result_group_outcome
                   WHERE student_enrollment_id = pg_temp.u('EN-OLIVIA') AND result_group = 'ANAT')
              AND (SELECT is_pass FROM academic.v_credit_ledger WHERE course_registration_id = pg_temp.u('R-O-102')),
  'combined result: practical at 20 % passes because theory + practical together reach 42.5 %');

-- ---- internal-marks revision through the workflow ----
SELECT pg_temp.rejects($q$SELECT exam.request_internal_mark_revision(md5('CM-INT')::uuid, 28, 'x', md5('E-FRANK')::uuid, md5('A-FRANK')::uuid)$q$,
  'internal-marks revision where the curriculum does not allow it');
SELECT pg_temp.rejects($q$SELECT exam.request_internal_mark_revision(md5('CM-O-Lab 4')::uuid, 30, 'x', md5('E-FRANK')::uuid, md5('A-FRANK')::uuid)$q$,
  'revised mark above the component maximum');
CREATE TEMP TABLE soe_rev (k text PRIMARY KEY, id uuid);
INSERT INTO soe_rev VALUES ('R1', exam.request_internal_mark_revision(pg_temp.u('CM-O-Lab 4'), 25, 'Lab 4 record re-evaluated', pg_temp.u('E-FRANK'), pg_temp.u('A-FRANK')));
SELECT pg_temp.rejects($q$SELECT exam.request_internal_mark_revision(md5('CM-O-Lab 4')::uuid, 20, 'again', md5('E-FRANK')::uuid, md5('A-FRANK')::uuid)$q$,
  'a second revision of a mark already under review');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_action (instance_id, wf_action_type_id, actor_account_id)
  SELECT instance_id, ref.id_of('wf_action_type','WITHDRAW'), md5('A-DEAN')::uuid FROM exam.internal_mark_revision WHERE id = (SELECT id FROM soe_rev WHERE k = 'R1')$q$,
  'withdrawing someone else''s request');
INSERT INTO wf.approval_action (instance_id, wf_action_type_id, actor_account_id)
SELECT instance_id, pg_temp.lk('wf_action_type','WITHDRAW'), pg_temp.u('A-FRANK') FROM exam.internal_mark_revision WHERE id = (SELECT id FROM soe_rev WHERE k = 'R1');
INSERT INTO soe_rev VALUES ('R2', exam.request_internal_mark_revision(pg_temp.u('CM-O-Lab 4'), 25, 'Lab 4 record re-evaluated (resubmitted)', pg_temp.u('E-FRANK'), pg_temp.u('A-FRANK')));
SELECT pg_temp.ok((SELECT total_pct = 20 FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-O-102')),
  'a revision under review does not change the marks');
INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id)
SELECT instance_id, 1, pg_temp.lk('wf_action_type','APPROVE'), pg_temp.u('A-DEAN') FROM exam.internal_mark_revision WHERE id = (SELECT id FROM soe_rev WHERE k = 'R2');
SELECT pg_temp.ok((SELECT total_pct = 40 FROM exam.v_provisional_result WHERE exam_registration_id = pg_temp.u('ER-O-102'))
              AND (SELECT marks = 5 FROM exam.component_mark WHERE id = pg_temp.u('CM-O-Lab 4')),
  'approved by the Faculty Moderation Committee (Dean): Lab 4 counts 25, practical now 40 %; the original mark is kept');

-- ---- viva / practical exam marked by an examiner panel ----
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
SELECT pg_temp.u('ER-O-DIS1'), pg_temp.u('XS-END'), r.id, pg_temp.lk('exam_attempt_type','REGULAR')
FROM academic.course_registration r WHERE r.student_enrollment_id = pg_temp.u('EN-OLIVIA') AND r.course_offering_id = pg_temp.u('O-DIS1');
INSERT INTO exam.exam_schedule (id, exam_session_id, course_offering_id, assessment_type_id, exam_date, start_time, end_time)
VALUES (pg_temp.u('SCH-VIVA'), pg_temp.u('XS-END'), pg_temp.u('O-DIS1'), pg_temp.lk('assessment_type','VIVA_VOCE_EXAM'), current_date + 106, '14:00', '15:00');
INSERT INTO exam.exam_attendance (exam_schedule_id, exam_registration_id, exam_attendance_status_id, marked_by_employee_id)
VALUES (pg_temp.u('SCH-VIVA'), pg_temp.u('ER-O-DIS1'), pg_temp.lk('exam_attendance_status','PRESENT'), pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO exam.answer_script (exam_schedule_id, exam_registration_id, dummy_code)
  VALUES (md5('SCH-VIVA')::uuid, md5('ER-O-DIS1')::uuid, 'D-VIVA')$q$, 'an anonymous answer script for a viva');
SELECT pg_temp.rejects($q$INSERT INTO exam.examiner_panel (exam_schedule_id, examiner_role_id, employee_id, appointed_by_employee_id)
  VALUES (md5('SCH-101')::uuid, ref.id_of('examiner_role','INTERNAL'), md5('E-FRANK')::uuid, md5('E-ALICE')::uuid)$q$,
  'an examiner panel on a script-marked theory paper');
SELECT pg_temp.rejects($q$INSERT INTO exam.examiner_panel (exam_schedule_id, examiner_role_id, employee_id, appointed_by_employee_id)
  VALUES (md5('SCH-VIVA')::uuid, ref.id_of('examiner_role','EXTERNAL'), md5('E-DEAN')::uuid, md5('E-ALICE')::uuid)$q$,
  'an employee as the external examiner');
SELECT pg_temp.rejects($q$INSERT INTO exam.examiner_panel (exam_schedule_id, examiner_role_id, external_person_id, appointed_by_employee_id)
  VALUES (md5('SCH-VIVA')::uuid, ref.id_of('examiner_role','INTERNAL'), md5('EXTP')::uuid, md5('E-ALICE')::uuid)$q$,
  'an outsider as the internal examiner');
INSERT INTO exam.examiner_panel (exam_schedule_id, examiner_role_id, employee_id, appointed_by_employee_id)
VALUES (pg_temp.u('SCH-VIVA'), pg_temp.lk('examiner_role','INTERNAL'), pg_temp.u('E-FRANK'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, exam_registration_id, marks, entered_by_employee_id)
  SELECT er.course_registration_id, ec.id, er.id, 24, md5('E-FRANK')::uuid FROM exam.exam_registration er, academic.evaluation_component ec
  WHERE er.id = md5('ER-O-DIS1')::uuid AND ec.evaluation_scheme_id = 9022 AND ec.name = 'Viva-voce / presentation'$q$,
  'viva marks before an external examiner is on the panel');
INSERT INTO exam.examiner_panel (exam_schedule_id, examiner_role_id, external_person_id, appointed_by_employee_id)
VALUES (pg_temp.u('SCH-VIVA'), pg_temp.lk('examiner_role','EXTERNAL'), pg_temp.u('EXTP'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, exam_registration_id, marks, entered_by_employee_id)
  SELECT er.course_registration_id, ec.id, er.id, 24, md5('E-ALICE')::uuid FROM exam.exam_registration er, academic.evaluation_component ec
  WHERE er.id = md5('ER-O-DIS1')::uuid AND ec.evaluation_scheme_id = 9022 AND ec.name = 'Viva-voce / presentation'$q$,
  'viva marks entered by someone not on the panel');
SELECT pg_temp.rejects($q$INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
  SELECT er.course_registration_id, ec.id, 24, md5('E-FRANK')::uuid FROM exam.exam_registration er, academic.evaluation_component ec
  WHERE er.id = md5('ER-O-DIS1')::uuid AND ec.evaluation_scheme_id = 9022 AND ec.name = 'Viva-voce / presentation'$q$,
  'viva marks not tied to an exam attempt');
INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, exam_registration_id, marks, entered_by_employee_id)
SELECT er.course_registration_id, ec.id, er.id, 24, pg_temp.u('E-FRANK') FROM exam.exam_registration er, academic.evaluation_component ec
WHERE er.id = pg_temp.u('ER-O-DIS1') AND ec.evaluation_scheme_id = 9022 AND ec.name = 'Viva-voce / presentation';
SELECT pg_temp.ok((SELECT marks = 24 FROM exam.v_component_score WHERE exam_registration_id = pg_temp.u('ER-O-DIS1') AND component = 'Viva-voce / presentation'),
  'viva marks entered by the internal examiner once the external examiner is on the panel, and they count in the result');

-- ---- reappear chances per attempt type ----
INSERT INTO exam.exam_session (id, academic_term_id, exam_session_type_id, name, period)
VALUES (pg_temp.u('XS-SPECIAL'), pg_temp.term('Y-B','EVEN'), pg_temp.lk('exam_session_type','SPECIAL'), 'Golden-chance session (SOE test)', daterange(current_date + 150, current_date + 160));
INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
VALUES (pg_temp.u('XS-SUP'), pg_temp.u('R-O-102'), pg_temp.lk('exam_attempt_type','GOLDEN_CHANCE'));
SELECT pg_temp.rejects($q$INSERT INTO exam.exam_registration (exam_session_id, course_registration_id, exam_attempt_type_id)
  VALUES (md5('XS-SPECIAL')::uuid, md5('R-O-102')::uuid, ref.id_of('exam_attempt_type','GOLDEN_CHANCE'))$q$,
  'a second golden chance when the SOE allows one');

-- ================================ academic operations (06c) =================

-- ---- relative grading ----
INSERT INTO academic.grade_scale (id, code, name, max_grade_point, is_relative, relative_min_cohort)
VALUES (901, 'REL_10', 'Relative 10-point (test)', 10, true, 3);
INSERT INTO academic.grade_band (id, grade_scale_id, grade_letter, pct_range, grade_point, is_pass) VALUES
 (9011, 901, 'O', '[90,100]', 10, true), (9012, 901, 'A', '[70,90)', 8, true),
 (9013, 901, 'B', '[40,70)', 6, true),  (9014, 901, 'F', '[0,40)', 0, false);
INSERT INTO academic.relative_grade_cutoff (grade_band_id, min_percentile) VALUES (9011, 90), (9012, 40), (9013, 0);
SELECT pg_temp.rejects($q$INSERT INTO academic.relative_grade_cutoff (grade_band_id, min_percentile) VALUES (9014, 10)$q$,
  'a percentile cutoff on a failing band');
SELECT pg_temp.rejects($q$INSERT INTO academic.relative_grade_cutoff (grade_band_id, min_percentile)
  SELECT id, 50 FROM academic.grade_band WHERE grade_letter = 'A+' AND grade_scale_id = (SELECT id FROM academic.grade_scale WHERE code = 'UGC_10')$q$,
  'a percentile cutoff on an absolute grade scale');
SELECT pg_temp.rejects($q$UPDATE academic.relative_grade_cutoff SET min_percentile = 90 WHERE grade_band_id = 9012$q$,
  'two bands sharing a cutoff');
UPDATE academic.elective_basket_course SET evaluation_scheme_id = 9020 WHERE elective_basket_id = pg_temp.u('PE1') AND course_id = pg_temp.u('C-CS201');
INSERT INTO academic.course_offering (id, course_id, academic_term_id, offering_org_unit_id)
VALUES (pg_temp.u('O-CS201E'), pg_temp.u('C-CS201'), pg_temp.term('Y-B','EVEN'), pg_temp.u('CSE'));
INSERT INTO academic.course_registration (id, student_enrollment_id, course_offering_id, registration_status_id)
SELECT pg_temp.u('R-E-' || s), pg_temp.u('EN-' || s), pg_temp.u('O-CS201E'), pg_temp.lk('registration_status','REGISTERED')
FROM unnest(ARRAY['HEIDI','IVAN','JUDY']) s;
INSERT INTO exam.exam_session (id, academic_term_id, exam_session_type_id, name, period)
VALUES (pg_temp.u('XS-EVEN'), pg_temp.term('Y-B','EVEN'), pg_temp.lk('exam_session_type','END_TERM'), 'End-term (even)', daterange(current_date + 280, current_date + 295));
INSERT INTO exam.exam_registration (id, exam_session_id, course_registration_id, exam_attempt_type_id)
SELECT pg_temp.u('ER-E-' || s), pg_temp.u('XS-EVEN'), pg_temp.u('R-E-' || s), pg_temp.lk('exam_attempt_type','REGULAR')
FROM unnest(ARRAY['HEIDI','IVAN','JUDY']) s;
-- totals: Heidi 60, Ivan 55, Judy 45 — all "B" on absolute bands
INSERT INTO exam.component_mark (course_registration_id, evaluation_component_id, marks, entered_by_employee_id)
SELECT pg_temp.u('R-E-' || v.s), ec.id, v.m, pg_temp.u('E-ALICE')
FROM (VALUES ('HEIDI','Thematic assessment',24),('HEIDI','Unit assessment',18),('HEIDI','Experiential and reflective learning',12),('HEIDI','Participation & engagement',6),
             ('IVAN','Thematic assessment',22),('IVAN','Unit assessment',17),('IVAN','Experiential and reflective learning',11),('IVAN','Participation & engagement',5),
             ('JUDY','Thematic assessment',18),('JUDY','Unit assessment',13),('JUDY','Experiential and reflective learning',9),('JUDY','Participation & engagement',5)) v(s, n, m)
JOIN academic.evaluation_component ec ON ec.evaluation_scheme_id = 9020 AND ec.name = v.n;
UPDATE academic.curriculum SET grade_scale_id = 901 WHERE id = pg_temp.u('CUR-BT');
UPDATE academic.grade_scale SET relative_min_cohort = 4 WHERE id = 901;
SELECT pg_temp.ok((SELECT string_agg(grade_letter, ',' ORDER BY total_pct DESC) FROM exam.v_provisional_result
                   WHERE exam_registration_id IN (pg_temp.u('ER-E-HEIDI'), pg_temp.u('ER-E-IVAN'), pg_temp.u('ER-E-JUDY'))
                     AND NOT graded_relatively) = 'B,B,B',
  'relative scale, cohort of 3 below its minimum of 4: falls back to the absolute bands (60 / 55 / 45 % all B)');
UPDATE academic.grade_scale SET relative_min_cohort = 3 WHERE id = 901;
SELECT pg_temp.ok((SELECT string_agg(grade_letter || ':' || cohort_percentile, ',' ORDER BY total_pct DESC) FROM exam.v_provisional_result
                   WHERE exam_registration_id IN (pg_temp.u('ER-E-HEIDI'), pg_temp.u('ER-E-IVAN'), pg_temp.u('ER-E-JUDY'))
                     AND graded_relatively) = 'O:100.00,A:50.00,B:0.00',
  'relative grading: the same marks become O / A / B by percentile in the cohort');

-- ---- credit load per term ----
INSERT INTO academic.credit_load_rule (curriculum_id, term_no, min_credits, max_credits) VALUES
 (pg_temp.u('CUR-BT'), NULL, 2, 12), (pg_temp.u('CUR-BT'), 1, 6, 10), (pg_temp.u('CUR-BT'), 2, NULL, 3);
SELECT pg_temp.rejects($q$INSERT INTO academic.credit_load_rule (curriculum_id, term_no, min_credits, max_credits) VALUES (md5('CUR-BT')::uuid, 3, 20, 10)$q$,
  'credit load minimum above maximum');
SELECT pg_temp.rejects($q$INSERT INTO academic.credit_load_rule (curriculum_id, term_no, max_credits) VALUES (md5('CUR-BT')::uuid, NULL, 20)$q$,
  'two default credit-load rules for one curriculum');
SELECT pg_temp.ok((SELECT registered_credits = 5 AND min_credits = 6 AND load_status = 'UNDER' FROM academic.v_credit_load
                   WHERE student_enrollment_id = pg_temp.u('EN-HEIDI') AND academic_term_id = pg_temp.term('Y-B','ODD')),
  'credit load: 5 credits in term 1 is under the 6-credit minimum (reported)');
SELECT pg_temp.rejects($q$INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  VALUES (md5('EN-IVAN')::uuid, md5('O-CS102N')::uuid, ref.id_of('registration_status','REGISTERED'))$q$,
  'registering beyond the term''s credit maximum (3 + 1 > 3)');
INSERT INTO academic.credit_overload_approval (student_enrollment_id, academic_term_id, max_credits, reason, approved_by_employee_id)
VALUES (pg_temp.u('EN-IVAN'), pg_temp.term('Y-B','EVEN'), 5, 'Clearing a backlog alongside the regular load', pg_temp.u('E-ALICE'));
INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
VALUES (pg_temp.u('EN-IVAN'), pg_temp.u('O-CS102N'), pg_temp.lk('registration_status','REGISTERED'));
SELECT pg_temp.ok((SELECT registered_credits = 4 AND max_credits = 5 AND has_overload AND load_status = 'OK' FROM academic.v_credit_load
                   WHERE student_enrollment_id = pg_temp.u('EN-IVAN') AND academic_term_id = pg_temp.term('Y-B','EVEN')),
  'an approved overload lifts the maximum for that student and term');

-- ---- duty / medical leave through the approval workflow ----
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id)
VALUES (pg_temp.u('A-HEIDI'), pg_temp.u('HEIDI'), 'SGT2026CSE002', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE'));
INSERT INTO academic.class_session (id, timetable_entry_id, session_date, class_session_status_id)
VALUES (pg_temp.u('CS-TB1-2'), pg_temp.u('TT-TB1'),
        pg_temp.nth_dow(lower((SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD'))), 4, 2),
        pg_temp.lk('class_session_status','HELD'));
SELECT pg_temp.ok((SELECT sessions_held = 2 AND attendance_pct = 50 FROM academic.v_attendance_summary WHERE course_registration_id = pg_temp.u('R-H-101')),
  'Heidi missed one of two tutorials: 50 %');
SELECT pg_temp.rejects($q$SELECT academic.request_attendance_leave(md5('EN-HEIDI')::uuid, 'DUTY_LEAVE',
  daterange((SELECT session_date FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid), (SELECT session_date + 1 FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid)),
  'Inter-university sports', NULL, md5('A-CAROL')::uuid)$q$, 'a student applying for another student''s leave');
SELECT pg_temp.rejects($q$SELECT academic.request_attendance_leave(md5('EN-HEIDI')::uuid, 'MEDICAL_LEAVE',
  daterange((SELECT session_date FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid), (SELECT session_date + 1 FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid)),
  'Fever', NULL, md5('A-HEIDI')::uuid)$q$, 'medical leave without a supporting document');
SELECT academic.request_attendance_leave(pg_temp.u('EN-HEIDI'), 'DUTY_LEAVE',
  daterange((SELECT session_date FROM academic.class_session WHERE id = pg_temp.u('CS-TB1-2')), (SELECT session_date + 1 FROM academic.class_session WHERE id = pg_temp.u('CS-TB1-2'))),
  'Represented the university at the inter-university sports meet', NULL, pg_temp.u('A-HEIDI'));
SELECT pg_temp.rejects($q$SELECT academic.request_attendance_leave(md5('EN-HEIDI')::uuid, 'DUTY_LEAVE',
  daterange((SELECT session_date FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid), (SELECT session_date + 2 FROM academic.class_session WHERE id = md5('CS-TB1-2')::uuid)),
  'again', NULL, md5('A-HEIDI')::uuid)$q$, 'an overlapping leave request while one is pending');
SELECT pg_temp.ok((SELECT attendance_pct = 50 FROM academic.v_attendance_summary WHERE course_registration_id = pg_temp.u('R-H-101')),
  'a pending leave does not change attendance');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id)
  SELECT instance_id, 1, ref.id_of('wf_action_type','APPROVE'), md5('A-FRANK')::uuid FROM academic.attendance_leave WHERE student_enrollment_id = md5('EN-HEIDI')::uuid$q$,
  'leave approved by someone who is not the HOD');
INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id)
SELECT instance_id, 1, pg_temp.lk('wf_action_type','APPROVE'), pg_temp.u('A-ALICE') FROM academic.attendance_leave WHERE student_enrollment_id = pg_temp.u('EN-HEIDI');
SELECT pg_temp.ok((SELECT attendance_pct = 100 AND sessions_on_leave = 1 FROM academic.v_attendance_summary WHERE course_registration_id = pg_temp.u('R-H-101')),
  'approved duty leave: the missed tutorial counts as present (marks untouched)');

-- ---- projects, dissertations, internships ----
INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('PAT'), 'Pat'), (pg_temp.u('MENTORP'), 'Meera');
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
VALUES (pg_temp.u('S-PAT'), pg_temp.u('PAT'), 'SGT2022OT008', pg_temp.lk('student_status','ACTIVE'), current_date - 25);
INSERT INTO academic.student_enrollment (id, student_id, batch_id, entry_term_no, valid)
VALUES (pg_temp.u('EN-PAT'), pg_temp.u('S-PAT'), pg_temp.u('B-2022'), 7, daterange(current_date - 25, NULL));
INSERT INTO academic.student_pathway (student_enrollment_id, curriculum_pathway_id, valid)
VALUES (pg_temp.u('EN-PAT'), pg_temp.u('PW-HONS'), daterange(current_date - 25, NULL));
SELECT pg_temp.ok(academic.register_core_courses(pg_temp.u('B-2022'), pg_temp.term('Y-B','ODD')) = 2,
  'Honours-pathway student gets OT701 + the internship');
SELECT pg_temp.rejects($q$INSERT INTO academic.supervised_work (course_registration_id, title) VALUES (md5('R-O-101')::uuid, 'Anatomy project')$q$,
  'a project record on a theory course');
INSERT INTO academic.supervised_work (id, course_registration_id, title)
SELECT pg_temp.u('W-DIS'), r.id, 'Airway management outcomes in day-care surgery'
FROM academic.course_registration r WHERE r.student_enrollment_id = pg_temp.u('EN-OLIVIA') AND r.course_offering_id = pg_temp.u('O-DIS1');
INSERT INTO academic.supervised_work_guide (supervised_work_id, supervisor_role_id, employee_id)
VALUES (pg_temp.u('W-DIS'), pg_temp.lk('supervisor_role','SUPERVISOR'), pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO academic.supervised_work_guide (supervised_work_id, supervisor_role_id, employee_id)
  VALUES (md5('W-DIS')::uuid, ref.id_of('supervisor_role','SUPERVISOR'), md5('E-ALICE')::uuid)$q$, 'two principal guides at once');
SELECT pg_temp.rejects($q$INSERT INTO academic.supervised_work_guide (supervised_work_id, supervisor_role_id, external_person_id)
  VALUES (md5('W-DIS')::uuid, ref.id_of('supervisor_role','CO_SUPERVISOR'), md5('EXTP')::uuid)$q$, 'an outsider in an employee-only guide role');
SELECT pg_temp.rejects($q$INSERT INTO academic.supervised_work_guide (supervised_work_id, supervisor_role_id, external_person_id)
  VALUES (md5('W-DIS')::uuid, ref.id_of('supervisor_role','EXTERNAL_CO_SUPERVISOR'), md5('DEANP')::uuid)$q$, 'an employee as the external co-guide');
INSERT INTO academic.supervised_work_guide (supervised_work_id, supervisor_role_id, external_person_id)
VALUES (pg_temp.u('W-DIS'), pg_temp.lk('supervisor_role','EXTERNAL_CO_SUPERVISOR'), pg_temp.u('EXTP'));
SELECT pg_temp.rejects($q$INSERT INTO academic.internship (supervised_work_id, organisation_name, period)
  VALUES (md5('W-DIS')::uuid, 'City Hospital', daterange(current_date, current_date + 30))$q$, 'internship details on a dissertation');
INSERT INTO academic.supervised_work (id, course_registration_id, title)
SELECT pg_temp.u('W-INT'), r.id, 'Operation-theatre internship'
FROM academic.course_registration r WHERE r.student_enrollment_id = pg_temp.u('EN-PAT') AND r.course_offering_id = pg_temp.u('O-INT1');
SELECT pg_temp.rejects($q$INSERT INTO academic.internship (supervised_work_id, organisation_name, period, industry_mentor_person_id)
  VALUES (md5('W-INT')::uuid, 'City Hospital', daterange(current_date - 20, current_date + 40), md5('DEANP')::uuid)$q$,
  'a university employee as the industry mentor');
INSERT INTO academic.internship (supervised_work_id, organisation_name, period, industry_mentor_person_id)
VALUES (pg_temp.u('W-INT'), 'City Hospital', daterange(current_date - 20, current_date + 40), pg_temp.u('MENTORP'));
SELECT pg_temp.ok((SELECT principal_guide_of = 1 FROM academic.v_guide_load
                   WHERE employee_id = pg_temp.u('E-FRANK') AND academic_term_id = pg_temp.term('Y-B','ODD')),
  'guide load: Frank guides one dissertation this term');

-- ---- rank list and prizes ----
SELECT pg_temp.ok((SELECT student_enrollment_id = pg_temp.u('EN-OLIVIA') FROM exam.v_rank_list WHERE batch_id = pg_temp.u('B-2022') AND rank = 1),
  'rank list derived: Olivia tops the 2022 batch');
INSERT INTO exam.prize (id, code, name, prize_type_id, program_id, rank_position) VALUES
 (pg_temp.u('PR-GOLD'), 'GOLD-BTECH', 'Chancellor''s Gold Medal — B.Tech', pg_temp.lk('prize_type','GOLD_MEDAL'), pg_temp.u('P-BTECH'), 1),
 (pg_temp.u('PR-MBA'),  'GOLD-MBA',   'Gold Medal — MBA', pg_temp.lk('prize_type','GOLD_MEDAL'), pg_temp.u('P-MBA'), 1);
SELECT pg_temp.rejects($q$INSERT INTO exam.prize (code, name, prize_type_id, rank_position) VALUES ('X', 'Rank prize without programme', ref.id_of('prize_type','MERIT_PRIZE'), 1)$q$,
  'a rank-tied prize without a programme');
SELECT pg_temp.rejects($q$INSERT INTO exam.prize_award (prize_id, student_enrollment_id, awarded_on, approved_by_employee_id)
  VALUES (md5('PR-GOLD')::uuid, md5('EN-PAT')::uuid, current_date, md5('E-REG')::uuid)$q$, 'the topper''s medal to a student who is not rank 1');
SELECT pg_temp.rejects($q$INSERT INTO exam.prize_award (prize_id, student_enrollment_id, awarded_on, approved_by_employee_id)
  VALUES (md5('PR-MBA')::uuid, md5('EN-OLIVIA')::uuid, current_date, md5('E-REG')::uuid)$q$, 'another programme''s medal');
INSERT INTO exam.prize_award (prize_id, student_enrollment_id, awarded_on, citation, approved_by_employee_id)
VALUES (pg_temp.u('PR-GOLD'), pg_temp.u('EN-OLIVIA'), current_date, 'First rank, B.Tech 2022 batch', pg_temp.u('E-REG'));
SELECT pg_temp.rejects($q$INSERT INTO exam.prize_award (prize_id, student_enrollment_id, awarded_on, approved_by_employee_id)
  VALUES (md5('PR-GOLD')::uuid, md5('EN-OLIVIA')::uuid, current_date, md5('E-REG')::uuid)$q$, 'the same prize twice to one student');

-- ---- mentoring ----
INSERT INTO people.student_mentor (id, student_id, employee_id, valid)
VALUES (pg_temp.u('SM-HEIDI'), pg_temp.u('S-HEIDI'), pg_temp.u('E-FRANK'), daterange(current_date - 10, NULL));
INSERT INTO academic.mentoring_meeting (student_mentor_id, met_on, meeting_mode_id, summary, action_points, follow_up_on, concern_flag)
VALUES (pg_temp.u('SM-HEIDI'), current_date, pg_temp.lk('meeting_mode','IN_PERSON'), 'Attendance dipped after the sports meet',
        'Catch-up plan for tutorials', current_date + 14, true);
SELECT pg_temp.rejects($q$INSERT INTO academic.mentoring_meeting (student_mentor_id, met_on, meeting_mode_id, summary)
  VALUES (md5('SM-HEIDI')::uuid, current_date - 30, ref.id_of('meeting_mode','ONLINE'), 'x')$q$, 'a mentoring meeting before the mentorship began');
SELECT pg_temp.rejects($q$INSERT INTO academic.mentoring_meeting (student_mentor_id, met_on, meeting_mode_id, summary, follow_up_on)
  VALUES (md5('SM-HEIDI')::uuid, current_date, ref.id_of('meeting_mode','ONLINE'), 'x', current_date - 1)$q$, 'a follow-up dated before the meeting');
SELECT pg_temp.ok((SELECT meetings = 1 AND recent_concern AND next_follow_up_on = current_date + 14 FROM academic.v_mentoring_status
                   WHERE student_mentor_id = pg_temp.u('SM-HEIDI')),
  'mentoring status: one meeting, a flagged concern, next follow-up');

-- ---- class representatives ----
INSERT INTO academic.section_representative (section_id, section_role_id, student_enrollment_id, appointed_by_employee_id)
VALUES (pg_temp.u('SEC-B'), pg_temp.lk('section_role','CLASS_REPRESENTATIVE'), pg_temp.u('EN-HEIDI'), pg_temp.u('E-ALICE'));
SELECT pg_temp.rejects($q$INSERT INTO academic.section_representative (section_id, section_role_id, student_enrollment_id)
  VALUES (md5('SEC-B')::uuid, ref.id_of('section_role','DEPUTY_REPRESENTATIVE'), md5('EN-CAROL')::uuid)$q$, 'a representative from outside the section');
SELECT pg_temp.rejects($q$INSERT INTO academic.section_representative (section_id, section_role_id, student_enrollment_id)
  VALUES (md5('SEC-B')::uuid, ref.id_of('section_role','DEPUTY_REPRESENTATIVE'), md5('EN-HEIDI')::uuid)$q$, 'one student holding two roles in a section');

-- ---- timetable inputs: room requirements, capacity, faculty preferences ----
INSERT INTO academic.course_room_requirement (course_id, delivery_component_id, room_type_id, room_feature_id) VALUES
 (pg_temp.u('C-CS102'), pg_temp.lk('delivery_component','PRACTICAL'), pg_temp.lk('room_type','LAB'), NULL),
 (pg_temp.u('C-CS102'), pg_temp.lk('delivery_component','PRACTICAL'), NULL, pg_temp.lk('room_feature','COMPUTERS'));
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-A-P')::uuid, 904, md5('R103')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-A-P')::uuid))$q$,
  'a programming lab timetabled in a classroom');
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-A-P')::uuid, 904, md5('R102')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-A-P')::uuid))$q$,
  'a programming lab in a lab without computers');
INSERT INTO org.room_facility (room_id, room_feature_id, quantity) VALUES (pg_temp.u('R102'), pg_temp.lk('room_feature','COMPUTERS'), 30);
INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
VALUES (pg_temp.u('TA-A-P'), 904, pg_temp.u('R102'), (SELECT valid FROM academic.teaching_assignment WHERE id = pg_temp.u('TA-A-P')));
SELECT pg_temp.ok(true, 'the lab is accepted once the room has the computers the course needs');
INSERT INTO org.room (id, building_id, code, room_type_id, capacity) VALUES (pg_temp.u('R-SMALL'), pg_temp.u('BLDG'), 'A-001', pg_temp.lk('room_type','CLASSROOM'), 1);
INSERT INTO academic.teaching_assignment (id, course_offering_id, employee_id, delivery_component_id, valid)
VALUES (pg_temp.u('TA-COMB'), pg_temp.u('O-CS101'), pg_temp.u('E-BOB'), pg_temp.lk('delivery_component','LECTURE'),
        (SELECT period FROM academic.academic_term WHERE id = pg_temp.term('Y-B','ODD')));
SELECT pg_temp.rejects($q$INSERT INTO academic.timetable_entry (teaching_assignment_id, time_slot_id, room_id, valid)
  VALUES (md5('TA-COMB')::uuid, 904, md5('R-SMALL')::uuid, (SELECT valid FROM academic.teaching_assignment WHERE id = md5('TA-COMB')::uuid))$q$,
  'a combined class of 4 in a 1-seat room');
INSERT INTO academic.faculty_course_preference (academic_term_id, employee_id, course_id, preference_rank) VALUES
 (pg_temp.term('Y-B','ODD'), pg_temp.u('E-FRANK'), pg_temp.u('C-CS101'), 1),
 (pg_temp.term('Y-B','ODD'), pg_temp.u('E-FRANK'), pg_temp.u('C-CS102'), 2);
SELECT pg_temp.rejects($q$INSERT INTO academic.faculty_course_preference (academic_term_id, employee_id, course_id, preference_rank)
  VALUES ((SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')),
          md5('E-BOB')::uuid, md5('C-CS101')::uuid, 1)$q$, 'course preferences from non-teaching staff');
SELECT pg_temp.rejects($q$INSERT INTO academic.faculty_course_preference (academic_term_id, employee_id, course_id, preference_rank)
  VALUES ((SELECT id FROM academic.academic_term WHERE academic_year_id = md5('Y-B')::uuid AND term_cycle_id = ref.id_of('term_cycle','ODD')),
          md5('E-FRANK')::uuid, md5('C-CS201')::uuid, 1)$q$, 'two courses at the same preference rank');
SELECT pg_temp.ok((SELECT bool_and(is_allocated = (course_id = pg_temp.u('C-CS101'))) FROM academic.v_faculty_preference_status
                   WHERE employee_id = pg_temp.u('E-FRANK') AND academic_term_id = pg_temp.term('Y-B','ODD')),
  'preference status: Frank got CS101 (1st choice), not CS102');

-- ---- question bank ----
INSERT INTO exam.question_bank_item (id, course_id, course_outcome_id, bloom_level_id, question_difficulty_id, question_type_id,
                                     question_text, marks, created_by_employee_id)
VALUES (pg_temp.u('QB-1'), pg_temp.u('C-CS101'), pg_temp.u('CO-101-1'), pg_temp.lk('bloom_level','APPLY'), pg_temp.lk('question_difficulty','MEDIUM'),
        pg_temp.lk('question_type','LONG'), 'Write a program that prints the first n primes using a loop and a function.', 10, pg_temp.u('E-FRANK')),
       (pg_temp.u('QB-2'), pg_temp.u('C-CS101'), pg_temp.u('CO-101-1'), pg_temp.lk('bloom_level','APPLY'), pg_temp.lk('question_difficulty','EASY'),
        pg_temp.lk('question_type','SHORT'), 'What does a for-loop do?', 2, pg_temp.u('E-FRANK')),
       (pg_temp.u('QB-3'), pg_temp.u('C-CS102'), NULL, NULL, pg_temp.lk('question_difficulty','EASY'),
        pg_temp.lk('question_type','SHORT'), 'Set up the lab environment.', 5, pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$UPDATE exam.question_bank_item SET reviewed_by_employee_id = md5('E-FRANK')::uuid, reviewed_at = now() WHERE id = md5('QB-1')::uuid$q$,
  'a question reviewed by its own author');
SELECT pg_temp.rejects($q$INSERT INTO exam.question_bank_item (course_id, course_outcome_id, question_difficulty_id, question_type_id, question_text, marks, created_by_employee_id)
  VALUES (md5('C-CS102')::uuid, md5('CO-101-1')::uuid, ref.id_of('question_difficulty','EASY'), ref.id_of('question_type','MCQ'), 'x', 1, md5('E-FRANK')::uuid)$q$,
  'a question tagged with another course''s outcome');
UPDATE exam.question_bank_item SET reviewed_by_employee_id = pg_temp.u('E-ALICE'), reviewed_at = now() WHERE id IN (pg_temp.u('QB-1'), pg_temp.u('QB-3'));
INSERT INTO exam.question_paper (id, exam_session_id, course_offering_id, assessment_type_id, set_code, question_paper_status_id, max_marks, duration_minutes)
VALUES (pg_temp.u('QP-B'), pg_temp.u('XS-END'), pg_temp.u('O-CS101'), pg_temp.lk('assessment_type','END_TERM'), 'B', pg_temp.lk('question_paper_status','DRAFT'), 100, 180);
INSERT INTO exam.question_paper_item (question_paper_id, question_no, question_bank_item_id, marks) VALUES (pg_temp.u('QP-B'), '1', pg_temp.u('QB-1'), 10);
SELECT pg_temp.rejects($q$INSERT INTO exam.question_paper_item (question_paper_id, question_no, question_bank_item_id, marks) VALUES (md5('QP-B')::uuid, '2', md5('QB-2')::uuid, 2)$q$,
  'an unreviewed question on a paper');
SELECT pg_temp.rejects($q$INSERT INTO exam.question_paper_item (question_paper_id, question_no, question_bank_item_id, marks) VALUES (md5('QP-B')::uuid, '3', md5('QB-3')::uuid, 5)$q$,
  'another course''s question on the paper');
SELECT pg_temp.rejects($q$INSERT INTO exam.question_paper_item (question_paper_id, question_no, question_bank_item_id, marks) VALUES (md5('QP-A')::uuid, '1', md5('QB-1')::uuid, 10)$q$,
  'changing the questions of an approved paper');
SELECT pg_temp.ok((SELECT course_outcome = 'CO1' AND bloom_level = 'APPLY' AND marks = 10 AND share_pct = 100 FROM exam.v_question_paper_blueprint
                   WHERE question_paper_id = pg_temp.u('QP-B')),
  'question paper blueprint: marks by course outcome and Bloom level');

-- ================ academic bodies · CO / PO attainment · discipline =========

-- ---- Board of Studies: members, meetings, quorum-gated resolutions ----
INSERT INTO academic.academic_body (id, academic_body_type_id, org_unit_id, name, quorum) VALUES
 (pg_temp.u('BOS-CSE'), pg_temp.lk('academic_body_type','BOARD_OF_STUDIES'), pg_temp.u('CSE'), 'Board of Studies — CSE', 2),
 (pg_temp.u('DC-SGTU'), pg_temp.lk('academic_body_type','DISCIPLINARY_COMMITTEE'), pg_temp.u('SGTU'), 'University Disciplinary Committee', 1);
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_body (academic_body_type_id, org_unit_id, name) VALUES (ref.id_of('academic_body_type','BOARD_OF_STUDIES'), md5('CSE')::uuid, 'Second BoS')$q$,
  'two Boards of Studies for one department');
INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id, valid) VALUES
 (pg_temp.u('BOS-CSE'), pg_temp.lk('committee_role','CHAIR'),  pg_temp.u('E-ALICE'), daterange(current_date - 30, NULL)),
 (pg_temp.u('BOS-CSE'), pg_temp.lk('committee_role','MEMBER'), pg_temp.u('E-FRANK'), daterange(current_date - 30, NULL));
INSERT INTO academic.academic_body_member (id, academic_body_id, committee_role_id, external_person_id, valid)
VALUES (pg_temp.u('BM-EXT'), pg_temp.u('BOS-CSE'), pg_temp.lk('committee_role','EXTERNAL_EXPERT'), pg_temp.u('EXTP'), daterange(current_date + 10, NULL));
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id) VALUES (md5('BOS-CSE')::uuid, ref.id_of('committee_role','CHAIR'), md5('E-BOB')::uuid)$q$,
  'a second chair of the same body at the same time');
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, external_person_id) VALUES (md5('DC-SGTU')::uuid, ref.id_of('committee_role','CHAIR'), md5('EXTP')::uuid)$q$,
  'an outsider as chair');
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, external_person_id) VALUES (md5('BOS-CSE')::uuid, ref.id_of('committee_role','EXTERNAL_EXPERT'), md5('DEANP')::uuid)$q$,
  'an employee as the external expert');
SELECT pg_temp.rejects($q$INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id) VALUES (md5('BOS-CSE')::uuid, ref.id_of('committee_role','MEMBER'), md5('E-FRANK')::uuid)$q$,
  'the same member twice in one period');
INSERT INTO academic.body_meeting (id, academic_body_id, meeting_no, held_on) VALUES (pg_temp.u('BOS-M1'), pg_temp.u('BOS-CSE'), 'BoS-CSE/2026/01', current_date);
INSERT INTO academic.body_meeting_attendee (body_meeting_id, academic_body_member_id)
SELECT pg_temp.u('BOS-M1'), id FROM academic.academic_body_member WHERE academic_body_id = pg_temp.u('BOS-CSE') AND employee_id = pg_temp.u('E-ALICE');
SELECT pg_temp.rejects($q$INSERT INTO academic.body_meeting_attendee (body_meeting_id, academic_body_member_id) VALUES (md5('BOS-M1')::uuid, md5('BM-EXT')::uuid)$q$,
  'an attendee who joins the body only after the meeting');
SELECT pg_temp.rejects($q$INSERT INTO academic.body_resolution (body_meeting_id, resolution_no, subject, decision) VALUES (md5('BOS-M1')::uuid, 'R-1', 'Syllabus of CS101', 'Approved')$q$,
  'a resolution of a meeting without quorum (1 of 2 present)');
INSERT INTO academic.body_meeting_attendee (body_meeting_id, academic_body_member_id)
SELECT pg_temp.u('BOS-M1'), id FROM academic.academic_body_member WHERE academic_body_id = pg_temp.u('BOS-CSE') AND employee_id = pg_temp.u('E-FRANK');
INSERT INTO academic.body_resolution (id, body_meeting_id, resolution_no, subject, decision)
VALUES (pg_temp.u('RES-1'), pg_temp.u('BOS-M1'), 'R-1', 'Syllabus v1 of CS101 and its course outcomes', 'Approved as placed');
UPDATE academic.course_syllabus SET body_resolution_id = pg_temp.u('RES-1') WHERE id = pg_temp.u('SY-101');
SELECT pg_temp.ok((SELECT b.name = 'Board of Studies — CSE' FROM academic.course_syllabus sy
                   JOIN academic.body_resolution r ON r.id = sy.body_resolution_id
                   JOIN academic.body_meeting m ON m.id = r.body_meeting_id
                   JOIN academic.academic_body b ON b.id = m.academic_body_id WHERE sy.id = pg_temp.u('SY-101')),
  'the syllabus cites the Board of Studies resolution that approved it');

-- ---- CO / PO attainment ----
INSERT INTO academic.course_outcome (id, course_syllabus_id, code, statement, bloom_level_id)
VALUES (pg_temp.u('CO-101-2'), pg_temp.u('SY-101'), 'CO2', 'Decompose problems into functions', pg_temp.lk('bloom_level','ANALYSE'));
INSERT INTO academic.co_po_mapping (course_outcome_id, program_outcome_id, strength) VALUES (pg_temp.u('CO-101-2'), pg_temp.u('PO-BT-1'), 1);
SELECT pg_temp.rejects($q$INSERT INTO academic.attainment_policy (program_id, student_target_pct, level1_pct, level2_pct, level3_pct) VALUES (md5('P-MBA')::uuid, 60, 70, 60, 80)$q$,
  'attainment levels out of order');
SELECT pg_temp.rejects($q$INSERT INTO academic.attainment_policy (program_id, student_target_pct, level1_pct, level2_pct, level3_pct) VALUES (NULL, 50, 40, 50, 60)$q$,
  'a second university-default attainment policy');
SELECT pg_temp.rejects($q$INSERT INTO academic.evaluation_component_outcome (evaluation_component_id, course_outcome_id)
  SELECT id, md5('CO-101-1')::uuid FROM academic.evaluation_component WHERE evaluation_scheme_id = 9001 AND name = 'End-term exam'$q$,
  'mapping a script-marked exam as a whole to an outcome');
INSERT INTO academic.evaluation_component_outcome (evaluation_component_id, course_outcome_id)
SELECT id, pg_temp.u('CO-101-2') FROM academic.evaluation_component WHERE evaluation_scheme_id = 9001 AND name = 'Internal assessment';
-- set B of the CS101 end-term: Q1 CO1 10, Q2 CO1 40, Q3 CO2 50 — approved and put on the date sheet
INSERT INTO exam.question_bank_item (id, course_id, course_outcome_id, question_difficulty_id, question_type_id, question_text, marks,
                                     created_by_employee_id, reviewed_by_employee_id, reviewed_at) VALUES
 (pg_temp.u('QB-5'), pg_temp.u('C-CS101'), pg_temp.u('CO-101-1'), pg_temp.lk('question_difficulty','MEDIUM'), pg_temp.lk('question_type','LONG'),
  'Trace the control flow of the given program.', 40, pg_temp.u('E-FRANK'), pg_temp.u('E-ALICE'), now()),
 (pg_temp.u('QB-6'), pg_temp.u('C-CS101'), pg_temp.u('CO-101-2'), pg_temp.lk('question_difficulty','HARD'), pg_temp.lk('question_type','LONG'),
  'Design a modular solution for the billing problem.', 50, pg_temp.u('E-FRANK'), pg_temp.u('E-ALICE'), now());
INSERT INTO exam.question_paper_item (question_paper_id, question_no, question_bank_item_id, marks) VALUES
 (pg_temp.u('QP-B'), '2', pg_temp.u('QB-5'), 40), (pg_temp.u('QP-B'), '3', pg_temp.u('QB-6'), 50);
UPDATE exam.question_paper SET question_paper_status_id = pg_temp.lk('question_paper_status','APPROVED'),
       submitted_by_assignment_id = pg_temp.u('PS-SET'), submitted_at = now(), moderated_by_assignment_id = pg_temp.u('PS-MOD'), moderated_at = now(),
       approved_by_employee_id = pg_temp.u('E-ALICE'), approved_at = now()
WHERE id = pg_temp.u('QP-B');
UPDATE exam.exam_schedule SET question_paper_id = pg_temp.u('QP-B') WHERE id = pg_temp.u('SCH-101');
-- Carol's script (revalued mark 90): question-wise breakdown
INSERT INTO exam.question_mark (exam_registration_id, question_paper_id, question_no, marks, entered_by_employee_id) VALUES
 (pg_temp.u('ER-C-101'), pg_temp.u('QP-B'), '1', 8, pg_temp.u('E-FRANK')), (pg_temp.u('ER-C-101'), pg_temp.u('QP-B'), '2', 40, pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$INSERT INTO exam.question_mark (exam_registration_id, question_paper_id, question_no, marks, entered_by_employee_id)
  VALUES (md5('ER-C-101')::uuid, md5('QP-B')::uuid, '3', 51, md5('E-FRANK')::uuid)$q$, 'more marks than the question carries');
SELECT pg_temp.rejects($q$INSERT INTO exam.question_mark (exam_registration_id, question_paper_id, question_no, marks, entered_by_employee_id)
  VALUES (md5('ER-C-101')::uuid, md5('QP-B')::uuid, '3', 50, md5('E-FRANK')::uuid)$q$, 'question marks totalling more than the script mark (8 + 40 + 50 > 90)');
SELECT pg_temp.rejects($q$INSERT INTO exam.question_mark (exam_registration_id, question_paper_id, question_no, marks, entered_by_employee_id)
  VALUES (md5('ER-C-201')::uuid, md5('QP-B')::uuid, '1', 5, md5('E-FRANK')::uuid)$q$, 'question marks for a paper the student did not sit');
INSERT INTO exam.question_mark (exam_registration_id, question_paper_id, question_no, marks, entered_by_employee_id)
VALUES (pg_temp.u('ER-C-101'), pg_temp.u('QP-B'), '3', 30, pg_temp.u('E-FRANK'));
SELECT pg_temp.rejects($q$UPDATE exam.question_mark SET marks = 9 WHERE exam_registration_id = md5('ER-C-101')::uuid AND question_no = '1'$q$,
  'changing question marks after the result is published');
SELECT pg_temp.ok((SELECT string_agg(co.code || ':' || sc.score_pct, ',' ORDER BY co.code) FROM exam.v_student_co_score sc
                   JOIN academic.course_outcome co ON co.id = sc.course_outcome_id WHERE sc.exam_registration_id = pg_temp.u('ER-C-101'))
                  = 'CO1:96.00,CO2:70.00',
  'CO scores: CO1 = 48/50 from questions; CO2 = (30 + revised internal 26) / (50 + 30)');
SELECT pg_temp.ok((SELECT string_agg(co.code || ':' || a.students_attained || '/' || a.students || ':L' || a.attainment_level, ',' ORDER BY co.code)
                   FROM academic.v_co_attainment a JOIN academic.course_outcome co ON co.id = a.course_outcome_id
                   WHERE a.course_offering_id = pg_temp.u('O-CS101') AND a.program_id = pg_temp.u('P-BTECH')) = 'CO1:1/1:L3,CO2:1/1:L3',
  'CO attainment (default policy, 60 % target): both outcomes reached by every student scored → level 3');
INSERT INTO academic.attainment_policy (program_id, student_target_pct, level1_pct, level2_pct, level3_pct) VALUES (pg_temp.u('P-BTECH'), 75, 40, 60, 80);
SELECT pg_temp.ok((SELECT string_agg(co.code || ':L' || a.attainment_level, ',' ORDER BY co.code)
                   FROM academic.v_co_attainment a JOIN academic.course_outcome co ON co.id = a.course_outcome_id
                   WHERE a.course_offering_id = pg_temp.u('O-CS101') AND a.program_id = pg_temp.u('P-BTECH')) = 'CO1:L3,CO2:L0',
  'the programme''s own policy (75 % target) overrides the default: CO2 at 70 % misses its 75 % target');
SELECT pg_temp.ok((SELECT attainment = 2.25 AND course_outcomes = 2 FROM academic.v_po_attainment
                   WHERE program_id = pg_temp.u('P-BTECH') AND program_outcome_id = pg_temp.u('PO-BT-1')),
  'PO attainment = strength-weighted CO levels: (3×3 + 1×0) / 4 = 2.25');

-- ---- disciplinary cases ----
SELECT pg_temp.rejects($q$INSERT INTO academic.disciplinary_case (student_id, misconduct_type_id, occurred_on, reported_on, reported_by_employee_id, description, disciplinary_status_id)
  VALUES (md5('S-IVAN')::uuid, ref.id_of('misconduct_type','RAGGING'), current_date, current_date - 1, md5('E-FRANK')::uuid, 'x', ref.id_of('disciplinary_status','REPORTED'))$q$,
  'a case reported before the incident');
SELECT pg_temp.rejects($q$INSERT INTO academic.disciplinary_case (student_id, misconduct_type_id, occurred_on, reported_by_employee_id, description, disciplinary_status_id, disciplinary_penalty_id)
  VALUES (md5('S-IVAN')::uuid, ref.id_of('misconduct_type','RAGGING'), current_date, md5('E-FRANK')::uuid, 'x', ref.id_of('disciplinary_status','REPORTED'), ref.id_of('disciplinary_penalty','WARNING'))$q$,
  'a penalty before the case is decided');
SELECT pg_temp.rejects($q$INSERT INTO academic.disciplinary_case (student_id, misconduct_type_id, occurred_on, reported_by_employee_id, description, disciplinary_status_id, academic_body_id)
  VALUES (md5('S-IVAN')::uuid, ref.id_of('misconduct_type','RAGGING'), current_date, md5('E-FRANK')::uuid, 'x', ref.id_of('disciplinary_status','UNDER_INQUIRY'), md5('BOS-CSE')::uuid)$q$,
  'a case heard by the Board of Studies instead of a disciplinary committee');
INSERT INTO academic.disciplinary_case (id, student_id, misconduct_type_id, occurred_on, reported_by_employee_id, description, disciplinary_status_id, academic_body_id)
VALUES (pg_temp.u('DC-1'), pg_temp.u('S-IVAN'), pg_temp.lk('misconduct_type','RAGGING'), current_date - 2, pg_temp.u('E-FRANK'),
        'Reported by a first-year student in the hostel', pg_temp.lk('disciplinary_status','UNDER_INQUIRY'), pg_temp.u('DC-SGTU'));
SELECT pg_temp.rejects($q$UPDATE academic.disciplinary_case SET disciplinary_status_id = ref.id_of('disciplinary_status','DECIDED') WHERE id = md5('DC-1')::uuid$q$,
  'a decided case without the decision');
SELECT pg_temp.rejects($q$UPDATE academic.disciplinary_case SET disciplinary_status_id = ref.id_of('disciplinary_status','DECIDED'), decided_on = current_date,
  decision = 'Suspended for one month', disciplinary_penalty_id = ref.id_of('disciplinary_penalty','SUSPENSION') WHERE id = md5('DC-1')::uuid$q$,
  'a suspension not recorded as a study break');
SELECT pg_temp.rejects($q$UPDATE academic.disciplinary_case SET disciplinary_status_id = ref.id_of('disciplinary_status','DECIDED'), decided_on = current_date,
  decision = 'Suspended', disciplinary_penalty_id = ref.id_of('disciplinary_penalty','SUSPENSION'),
  study_break_id = (SELECT id FROM academic.study_break WHERE student_enrollment_id = md5('EN-HEIDI')::uuid LIMIT 1) WHERE id = md5('DC-1')::uuid$q$,
  'another student''s (medical) break as the suspension');
INSERT INTO academic.study_break (id, student_enrollment_id, study_break_type_id, period, reason, approved_by_employee_id)
VALUES (pg_temp.u('SB-IVAN'), pg_temp.u('EN-IVAN'), pg_temp.lk('study_break_type','DISCIPLINARY_SUSPENSION'), daterange(current_date + 1, current_date + 31),
        'Disciplinary committee decision', pg_temp.u('E-ALICE'));
UPDATE academic.disciplinary_case SET disciplinary_status_id = pg_temp.lk('disciplinary_status','DECIDED'), decided_on = current_date,
       decision = 'Suspended from classes for one month; written undertaking', disciplinary_penalty_id = pg_temp.lk('disciplinary_penalty','SUSPENSION'),
       study_break_id = pg_temp.u('SB-IVAN')
WHERE id = pg_temp.u('DC-1');
SELECT pg_temp.ok(true, 'a decided suspension served as the student''s disciplinary-suspension break');
UPDATE academic.disciplinary_case SET disciplinary_status_id = pg_temp.lk('disciplinary_status','CLOSED') WHERE id = pg_temp.u('DC-1');
SELECT pg_temp.rejects($q$UPDATE academic.disciplinary_case SET disciplinary_penalty_id = ref.id_of('disciplinary_penalty','WARNING') WHERE id = md5('DC-1')::uuid$q$,
  'changing a closed case');

-- ================================== resource & facility management (06d) =====
-- fixtures: floors, an open area and a car park, an auditorium made of two
-- halls, a VC room, a person-granted meeting room, a guest room, blocks with
-- custody, a transport office, a driver, a vehicle, assets, a key
INSERT INTO org.floor (id, building_id, code, name, level) VALUES
 (pg_temp.u('FL-G'), pg_temp.u('BLDG'), 'G', 'Ground floor', 0), (pg_temp.u('FL-1'), pg_temp.u('BLDG'), '1', 'First floor', 1);
INSERT INTO org.building (id, campus_id, code, name, building_kind_id) VALUES
 (pg_temp.u('BLDG-B'), pg_temp.u('CAMPUS'), 'B', 'Guest House', pg_temp.lk('building_kind','BUILDING')),
 (pg_temp.u('GROUNDS'), pg_temp.u('CAMPUS'), 'G', 'Sports grounds', pg_temp.lk('building_kind','OPEN_AREA')),
 (pg_temp.u('PARK'), pg_temp.u('CAMPUS'), 'P', 'Car park', pg_temp.lk('building_kind','PARKING'));
INSERT INTO org.floor (id, building_id, code, name, level) VALUES (pg_temp.u('FL-B1'), pg_temp.u('BLDG-B'), '1', 'First floor', 1);
SELECT pg_temp.rejects($q$UPDATE org.room SET floor_id = md5('FL-B1')::uuid WHERE id = md5('R101')::uuid$q$, 'a room on a floor of another building');
UPDATE org.room SET floor_id = pg_temp.u('FL-G'), room_use_id = pg_temp.lk('room_use','CLASSROOM'), area_sqm = 80 WHERE id = pg_temp.u('R101');
UPDATE org.room SET floor_id = pg_temp.u('FL-G'), room_use_id = pg_temp.lk('room_use','LABORATORY'), area_sqm = 120 WHERE id = pg_temp.u('R102');
UPDATE org.room SET floor_id = pg_temp.u('FL-1'), room_use_id = pg_temp.lk('room_use','CLASSROOM'), area_sqm = 80 WHERE id = pg_temp.u('R103');
INSERT INTO org.room (id, building_id, floor_id, code, name, room_type_id, room_use_id, capacity, area_sqm) VALUES
 (pg_temp.u('R201'),  pg_temp.u('BLDG'), pg_temp.u('FL-1'), 'A-201',  'Auditorium',        pg_temp.lk('room_type','AUDITORIUM'),      pg_temp.lk('room_use','ASSEMBLY'), 400, 600),
 (pg_temp.u('R201A'), pg_temp.u('BLDG'), pg_temp.u('FL-1'), 'A-201A', 'Auditorium hall A', pg_temp.lk('room_type','SEMINAR_HALL'),    pg_temp.lk('room_use','ASSEMBLY'), 200, 300),
 (pg_temp.u('R201B'), pg_temp.u('BLDG'), pg_temp.u('FL-1'), 'A-201B', 'Auditorium hall B', pg_temp.lk('room_type','SEMINAR_HALL'),    pg_temp.lk('room_use','ASSEMBLY'), 200, 300),
 (pg_temp.u('R-VC'),  pg_temp.u('BLDG'), pg_temp.u('FL-1'), 'A-VC',   'VC meeting room',   pg_temp.lk('room_type','CONFERENCE_ROOM'), pg_temp.lk('room_use','ASSEMBLY'), 20, 40),
 (pg_temp.u('R-CONF'),pg_temp.u('BLDG'), pg_temp.u('FL-G'), 'A-CONF', 'HR meeting room',   pg_temp.lk('room_type','CONFERENCE_ROOM'), pg_temp.lk('room_use','ASSEMBLY'), 12, 30),
 (pg_temp.u('R104'),  pg_temp.u('BLDG'), pg_temp.u('FL-G'), 'A-104',  'Meeting room (never timetabled: used by the clock-relative tests)', pg_temp.lk('room_type','CONFERENCE_ROOM'), pg_temp.lk('room_use','ASSEMBLY'), 20, 35),
 (pg_temp.u('GR-1'),  pg_temp.u('BLDG-B'), pg_temp.u('FL-B1'), 'GH-1', 'Guest room 1',     pg_temp.lk('room_type','GUEST_ROOM'),      pg_temp.lk('room_use','GUEST_ROOM'), 2, 25),
 (pg_temp.u('G1'),    pg_temp.u('GROUNDS'), NULL, 'G-1',  'Football ground',               pg_temp.lk('room_type','SPORTS_FACILITY'), pg_temp.lk('room_use','OPEN_GROUND'), 500, 7000),
 (pg_temp.u('P1'),    pg_temp.u('PARK'), NULL, 'P-1',     'Staff parking',                 pg_temp.lk('room_type','PARKING_ZONE'),    pg_temp.lk('room_use','PARKING_ZONE'), 2, 50);
INSERT INTO org.room_facility (room_id, room_feature_id, quantity) VALUES
 (pg_temp.u('R101'), pg_temp.lk('room_feature','PROJECTOR'), 1), (pg_temp.u('R201'), pg_temp.lk('room_feature','AUDIO_SYSTEM'), 1),
 (pg_temp.u('R-VC'), pg_temp.lk('room_feature','VIDEO_CONFERENCING'), 1);
INSERT INTO facility.room_composition (parent_room_id, part_room_id) VALUES (pg_temp.u('R201'), pg_temp.u('R201A')), (pg_temp.u('R201'), pg_temp.u('R201B'));
SELECT pg_temp.rejects($q$INSERT INTO facility.room_composition (parent_room_id, part_room_id) VALUES (md5('R201A')::uuid, md5('R101')::uuid)$q$, 'nested composition (a part that is itself a whole)');
SELECT pg_temp.rejects($q$INSERT INTO facility.room_composition (parent_room_id, part_room_id) VALUES (md5('R201')::uuid, md5('GR-1')::uuid)$q$, 'a part in another building');
SELECT pg_temp.ok((SELECT count(*) = 2 FROM facility.linked_rooms(pg_temp.u('R201A'))) AND (SELECT count(*) = 3 FROM facility.linked_rooms(pg_temp.u('R201'))),
  'linked rooms: a hall is tied to itself and the whole; the whole to itself and both halls');

-- org units: blocks in custody of buildings, a transport office; heads
INSERT INTO org.org_unit (id, org_unit_type_id, parent_id, code, name) VALUES
 (pg_temp.u('BLOCK-A'),   pg_temp.lk('org_unit_type','BLOCK'),              pg_temp.u('SGTU'), 'BLOCK-A',   'Block A'),
 (pg_temp.u('GH'),        pg_temp.lk('org_unit_type','BLOCK'),              pg_temp.u('SGTU'), 'GH',        'Guest House'),
 (pg_temp.u('TRANSPORT'), pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('SGTU'), 'TRANSPORT', 'Transport Office');
INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
VALUES (pg_temp.u('BLOCK-A'), (SELECT id FROM org.position_type WHERE code='HEAD'), pg_temp.u('E-BOB'), daterange('2024-01-01', NULL));   -- Bob heads Block A
INSERT INTO facility.custody (building_id, org_unit_id, valid) VALUES (pg_temp.u('BLDG'), pg_temp.u('BLOCK-A'), daterange('2020-01-01', NULL)), (pg_temp.u('BLDG-B'), pg_temp.u('GH'), daterange('2020-01-01', NULL));
INSERT INTO facility.custody (room_id, org_unit_id, valid) VALUES (pg_temp.u('R102'), pg_temp.u('CSE'), daterange('2020-01-01', NULL));   -- the department keeps its own lab
INSERT INTO facility.custody (campus_id, org_unit_id, valid) VALUES (pg_temp.u('CAMPUS'), pg_temp.u('SGTU'), daterange('2020-01-01', NULL));   -- everything else: the university
SELECT pg_temp.rejects($q$INSERT INTO facility.custody (building_id, org_unit_id) VALUES (md5('BLDG')::uuid, md5('HR')::uuid)$q$, 'two custodians of one building at a time');
SELECT pg_temp.rejects($q$INSERT INTO facility.custody (room_id, floor_id, org_unit_id) VALUES (md5('R101')::uuid, md5('FL-G')::uuid, md5('HR')::uuid)$q$, 'custody of two targets at once');
SELECT pg_temp.ok(facility.custodian_of(pg_temp.u('R101')) = pg_temp.u('BLOCK-A') AND facility.custodian_of(pg_temp.u('R102')) = pg_temp.u('CSE')
              AND facility.custodian_of(pg_temp.u('G1')) = pg_temp.u('SGTU'),
  'custodian derived: room custody beats building custody beats campus custody');

-- space allocation: shares of one room never exceed 100 %
INSERT INTO facility.space_allocation (room_id, org_unit_id, share_pct) VALUES (pg_temp.u('R101'), pg_temp.u('CSE'), 60), (pg_temp.u('R101'), pg_temp.u('MBA'), 40);
SELECT pg_temp.rejects($q$INSERT INTO facility.space_allocation (room_id, org_unit_id, share_pct) VALUES (md5('R101')::uuid, md5('HR')::uuid, 10)$q$, 'allocation shares over 100 %');
SELECT pg_temp.ok((SELECT rooms_equivalent = 0.60 AND area_sqm = 48.00 FROM facility.v_space_inventory WHERE org_unit_id = pg_temp.u('CSE')), 'space inventory: CSE holds 0.6 of a room (48 m²)');

-- reserved / private rooms
INSERT INTO people.person (id, first_name) VALUES (pg_temp.u('VCP'), 'Vikram'), (pg_temp.u('TMP'), 'Tara'), (pg_temp.u('DRVP'), 'Dinesh');
INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on) VALUES
 (pg_temp.u('E-VC'),  pg_temp.u('VCP'),  'E3001', pg_temp.lk('employee_category','TEACHING'),     pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2005-01-01'),
 (pg_temp.u('E-TM'),  pg_temp.u('TMP'),  'E3002', pg_temp.lk('employee_category','NON_TEACHING'), pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2015-01-01'),
 (pg_temp.u('E-DRV'), pg_temp.u('DRVP'), 'E3003', pg_temp.lk('employee_category','NON_TEACHING'), pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2018-01-01');
INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid) VALUES
 (pg_temp.u('E-VC'),  pg_temp.u('SGTU'),      (SELECT id FROM people.designation WHERE code='PROFESSOR'),    true, daterange('2020-01-01', NULL)),
 (pg_temp.u('E-TM'),  pg_temp.u('TRANSPORT'), (SELECT id FROM people.designation WHERE code='HR_EXECUTIVE'), true, daterange('2020-01-01', NULL)),
 (pg_temp.u('E-DRV'), pg_temp.u('TRANSPORT'), (SELECT id FROM people.designation WHERE code='HR_EXECUTIVE'), true, daterange('2020-01-01', NULL));
INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
VALUES (pg_temp.u('SGTU'), (SELECT id FROM org.position_type WHERE code='VICE_CHANCELLOR'), pg_temp.u('E-VC'), daterange('2020-01-01', NULL));
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id) VALUES
 (pg_temp.u('A-VC'),  pg_temp.u('VCP'),  'E3001', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-TM'),  pg_temp.u('TMP'),  'E3002', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE')),
 (pg_temp.u('A-DRV'), pg_temp.u('DRVP'), 'E3003', 'pbkdf2_sha256$x', pg_temp.lk('account_status','ACTIVE'));
INSERT INTO authz.account_role (account_id, role_id, reason) VALUES
 (pg_temp.u('A-TM'),  (SELECT id FROM authz.role WHERE code='TRANSPORT_MANAGER'), 'Transport office'),
 (pg_temp.u('A-EVE'), (SELECT id FROM authz.role WHERE code='GUEST_HOUSE_MANAGER'), 'Guest house desk');
SELECT pg_temp.rejects($q$INSERT INTO authz.account_role (account_id, role_id, reason) VALUES (md5('A-TM')::uuid, (SELECT id FROM authz.role WHERE code='FLEET_DRIVER'), 'x')$q$,
  'transport manager who is also a driver (separation of duties)');
INSERT INTO facility.room_reservation_rule (room_id, position_type_id, note) VALUES (pg_temp.u('R-VC'), (SELECT id FROM org.position_type WHERE code='VICE_CHANCELLOR'), 'VC only');
INSERT INTO facility.room_reservation_rule (room_id, person_id, granted_by_account_id) VALUES (pg_temp.u('R-CONF'), pg_temp.u('EVE'), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.room_reservation_rule (room_id, floor_id, person_id) VALUES (md5('R-CONF')::uuid, md5('FL-G')::uuid, md5('EVE')::uuid)$q$, 'a reservation rule on two targets');
SELECT pg_temp.ok((SELECT is_reserved AND NOT is_allowed FROM facility.room_reserved_for(pg_temp.u('R-VC'), current_date, pg_temp.u('ALICE'), pg_temp.u('CSE'), pg_temp.u('A-ALICE')))
              AND (SELECT is_allowed FROM facility.room_reserved_for(pg_temp.u('R-VC'), current_date, pg_temp.u('VCP'), NULL, pg_temp.u('A-VC')))
              AND (SELECT is_allowed FROM facility.room_reserved_for(pg_temp.u('R-CONF'), current_date, pg_temp.u('EVE'), NULL, pg_temp.u('A-EVE')))
              AND NOT (SELECT is_reserved FROM facility.room_reserved_for(pg_temp.u('R101'), current_date, pg_temp.u('ALICE'), NULL, NULL)),
  'reservation rules: the VC room for the VC, the HR room for Eve, an ordinary classroom for everyone');

-- priority rules and the workflow retrofits
SELECT pg_temp.rejects($q$INSERT INTO facility.hold_priority_rule (hold_type_id, outranks_hold_type_id) VALUES (ref.id_of('hold_type','TIMETABLE'), ref.id_of('hold_type','TIMETABLE'))$q$, 'a hold type outranking itself');
SELECT pg_temp.rejects($q$INSERT INTO facility.hold_priority_rule (hold_type_id, outranks_hold_type_id) VALUES (ref.id_of('hold_type','STUDENT_ACTIVITY'), ref.id_of('hold_type','TIMETABLE'))$q$, 'the reverse of an existing rule at the same scope');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_org_unit_type_id, anchor_is_owner)
  SELECT c.id, 9, 'X', 'x', pc.permission_id, ref.id_of('org_unit_type','SCHOOL'), true FROM wf.approval_chain c JOIN wf.approval_document_type dt ON dt.id = c.document_type_id AND dt.code = 'ROOM_BOOKING'
  JOIN authz.v_permission_code pc ON pc.code = 'facility.booking.approve' WHERE c.scope_org_unit_id IS NULL$q$, 'a stage anchored both at the owner and at a unit type');
SELECT pg_temp.ok(facility.outranks(pg_temp.lk('hold_type','EXAM')::smallint, pg_temp.lk('hold_type','TIMETABLE')::smallint, NULL, pg_temp.u('BLOCK-A'), current_date)
              AND NOT facility.outranks(pg_temp.lk('hold_type','TIMETABLE')::smallint, pg_temp.lk('hold_type','EXAM')::smallint, NULL, pg_temp.u('BLOCK-A'), current_date)
              AND NOT facility.outranks(pg_temp.lk('hold_type','OFFICIAL_EVENT')::smallint, pg_temp.lk('hold_type','TIMETABLE')::smallint, NULL, pg_temp.u('BLOCK-A'), current_date),
  'priority: exams outrank classes, classes do not outrank exams, official events do not outrank classes (by default)');
-- Block A's own policy: official events may displace classes in its rooms
INSERT INTO facility.hold_priority_rule (hold_type_id, outranks_hold_type_id, org_unit_id, note)
VALUES (pg_temp.lk('hold_type','OFFICIAL_EVENT'), pg_temp.lk('hold_type','TIMETABLE'), pg_temp.u('BLOCK-A'), 'Block A: official events first');
SELECT pg_temp.ok(facility.outranks(pg_temp.lk('hold_type','OFFICIAL_EVENT')::smallint, pg_temp.lk('hold_type','TIMETABLE')::smallint, NULL, pg_temp.u('BLOCK-A'), current_date)
              AND NOT facility.outranks(pg_temp.lk('hold_type','OFFICIAL_EVENT')::smallint, pg_temp.lk('hold_type','TIMETABLE')::smallint, NULL, pg_temp.u('CSE'), current_date),
  'a scoped priority rule applies in the custody subtree only');

-- ---- the ledger ----
SELECT pg_temp.rejects($q$INSERT INTO facility.room_hold (room_id, hold_type_id, during, timetable_entry_id, viva_id)
  VALUES (md5('R101')::uuid, ref.id_of('hold_type','TIMETABLE'), tsrange(current_date + 50 + time '20:00', current_date + 50 + time '21:00'), md5('TT-L')::uuid, gen_random_uuid())$q$, 'a hold with two sources');
SELECT pg_temp.rejects($q$INSERT INTO facility.room_hold (room_id, hold_type_id, during) VALUES (md5('R101')::uuid, ref.id_of('hold_type','TIMETABLE'), tsrange(current_date + 50 + time '20:00', current_date + 50 + time '21:00'))$q$, 'a hold without a source');
SELECT pg_temp.rejects($q$INSERT INTO facility.room_hold (room_id, hold_type_id, during, timetable_entry_id)
  VALUES (md5('R101')::uuid, ref.id_of('hold_type','EXAM'), tsrange(current_date + 50 + time '20:00', current_date + 50 + time '21:00'), md5('TT-L')::uuid)$q$, 'a hold whose type does not match its source');
-- exams already wrote their holds (with the EXAM buffers)
SELECT pg_temp.ok((SELECT count(*) = 2 AND bool_and(lower(facility.blocked(during, setup_minutes, teardown_minutes)) = pg_temp.nth_dow(current_date + 101, 6, 1) + time '08:30')
                   FROM facility.room_hold WHERE exam_schedule_id = pg_temp.u('SCH-101')),
  'exam rooms hold the ledger for the paper, 30 minutes of setup included');
-- materialise the term's timetable
CREATE TEMP TABLE mt AS SELECT * FROM facility.materialise_timetable(pg_temp.term('Y-B','ODD'));
SELECT pg_temp.ok((SELECT created > 10 AND existing > 0 AND conflicts = 0 FROM mt), 'timetable materialised: one hold per class date, co-teachers sharing it (created/existing/skipped/conflicts = ' || (SELECT created || '/' || existing || '/' || skipped || '/' || conflicts FROM mt) || ')');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = pg_temp.u('TT-L'))
              AND NOT EXISTS (SELECT 1 FROM facility.room_hold h WHERE h.timetable_entry_id = pg_temp.u('TT-Lco')
                                AND NOT EXISTS (SELECT 1 FROM academic.class_session cs JOIN ref.class_session_status st ON st.id = cs.class_session_status_id AND st.releases_room
                                                WHERE cs.timetable_entry_id = pg_temp.u('TT-L') AND cs.session_date = lower(h.during)::date)),
  'a co-taught class is held by the primary teacher''s entry; the co-teacher''s entry holds the room only on a date the primary''s session is cancelled');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM facility.room_hold h WHERE h.timetable_entry_id = pg_temp.u('TT-L') AND lower(h.during)::date = pg_temp.nth_dow(current_date + 90, 1, 1)),
  'no class hold on the holiday');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM facility.room_hold h JOIN academic.class_session cs ON cs.id = pg_temp.u('CS-L-CANCEL')
                              WHERE h.timetable_entry_id = pg_temp.u('TT-L') AND lower(h.during)::date = cs.session_date),
  'no class hold on the date of a cancelled session');
CREATE TEMP TABLE mt2 AS SELECT * FROM facility.materialise_timetable(pg_temp.term('Y-B','ODD'));
SELECT pg_temp.ok((SELECT created = 0 AND conflicts = 0 AND existing + skipped = (SELECT created + existing + skipped FROM mt) FROM mt2),
  'materialisation is idempotent (second run created/existing/skipped/conflicts = ' || (SELECT created || '/' || existing || '/' || skipped || '/' || conflicts FROM mt2) || ')');
SELECT pg_temp.rejects($q$UPDATE facility.room_hold SET during = tsrange(lower(during), upper(during) + interval '1 hour') WHERE timetable_entry_id = md5('TT-L')::uuid$q$, 'editing a hold');
-- a service window is a hold; two on one room at once are not
INSERT INTO facility.room_service_window (id, room_id, room_service_type_id, during, created_by_account_id)
VALUES (pg_temp.u('SW-1'), pg_temp.u('R103'), pg_temp.lk('room_service_type','CLEANING'), tsrange(pg_temp.nth_dow(current_date + 21, 3, 1) + time '14:00', pg_temp.nth_dow(current_date + 21, 3, 1) + time '18:00'), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.room_service_window (room_id, room_service_type_id, during, created_by_account_id)
  VALUES (md5('R103')::uuid, ref.id_of('room_service_type','REPAIR'), tsrange(pg_temp.nth_dow(current_date + 21, 3, 1) + time '14:00', pg_temp.nth_dow(current_date + 21, 3, 1) + time '15:00'), md5('A-BOB')::uuid)$q$,
  'a second hold on a room at the same time (no priority rule between them)');
-- a convocation in the auditorium blocks both halls
INSERT INTO exam.convocation (id, academic_year_id, name, held_on, start_time, end_time, room_id)
VALUES (pg_temp.u('CONV-2'), pg_temp.u('Y-B'), '2nd Convocation', current_date + 60, '10:00', '13:00', pg_temp.u('R201'));
SELECT pg_temp.ok((SELECT count(*) = 3 FROM facility.room_hold WHERE COALESCE(parent_hold_id, id) = (SELECT id FROM facility.room_hold WHERE convocation_id = pg_temp.u('CONV-2'))),
  'a hold on the whole auditorium shadows both halls');
SELECT pg_temp.rejects($q$INSERT INTO facility.room_service_window (room_id, room_service_type_id, during, created_by_account_id)
  VALUES (md5('R201A')::uuid, ref.id_of('room_service_type','CLEANING'), tsrange(current_date + 60 + time '11:00', current_date + 60 + time '12:00'), md5('A-BOB')::uuid)$q$,
  'a hall while the whole auditorium is in use');
INSERT INTO facility.room_service_window (room_id, room_service_type_id, during, created_by_account_id) VALUES
 (pg_temp.u('R201A'), pg_temp.lk('room_service_type','CLEANING'), tsrange(current_date + 61 + time '10:00', current_date + 61 + time '12:00'), pg_temp.u('A-BOB')),
 (pg_temp.u('R201B'), pg_temp.lk('room_service_type','CLEANING'), tsrange(current_date + 61 + time '10:00', current_date + 61 + time '12:00'), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.room_service_window (room_id, room_service_type_id, during, created_by_account_id)
  VALUES (md5('R201')::uuid, ref.id_of('room_service_type','CLEANING'), tsrange(current_date + 61 + time '11:00', current_date + 61 + time '13:00'), md5('A-BOB')::uuid)$q$,
  'the whole auditorium while a hall is in use');
SELECT pg_temp.ok(true, 'the two halls can be used in parallel; the whole cannot while either is in use');
-- deactivation
SELECT pg_temp.rejects($q$UPDATE org.room SET is_active = false WHERE id = md5('R201A')::uuid$q$, 'deactivating a room with future holds');
UPDATE org.floor SET is_active = false WHERE id = pg_temp.u('FL-B1');
SELECT pg_temp.ok(NOT (SELECT is_active FROM org.room WHERE id = pg_temp.u('GR-1')), 'deactivating a floor deactivates its rooms');
SELECT pg_temp.rejects($q$UPDATE org.room SET is_active = true WHERE id = md5('GR-1')::uuid$q$, 'activating a room under an inactive floor');
UPDATE org.floor SET is_active = true WHERE id = pg_temp.u('FL-B1');
UPDATE org.room SET is_active = true WHERE id = pg_temp.u('GR-1');

-- ---- bookings ----
CREATE FUNCTION pg_temp.wed(n int) RETURNS date LANGUAGE sql STABLE AS $$ SELECT pg_temp.nth_dow(current_date + 7 * n, 3, 1) $$;   -- a Wednesday n+ weeks out
CREATE FUNCTION pg_temp.grp_instance(g uuid) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT instance_id FROM facility.booking_request WHERE booking_group_id = g $$;
CREATE FUNCTION pg_temp.grp_status(g uuid) RETURNS text LANGUAGE sql STABLE AS $$ SELECT string_agg(status, ',' ORDER BY during) FROM facility.v_booking_status WHERE booking_group_id = g $$;
CREATE FUNCTION pg_temp.act(p_instance uuid, p_action text, p_seq int, p_actor text, p_note text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id, note)
  VALUES (p_instance, p_seq, ref.id_of('wf_action_type', p_action), md5(p_actor)::uuid, p_note) $$;
SELECT pg_temp.ok(authz.has_permission(pg_temp.u('A-ALICE'), 'facility.booking.create') AND authz.has_permission(pg_temp.u('A-CAROL'), 'facility.booking.create')
              AND authz.has_permission(pg_temp.u('A-BOB'), 'facility.booking.approve', pg_temp.u('BLOCK-A'))
              AND NOT authz.has_permission(pg_temp.u('A-ALICE'), 'facility.booking.approve', pg_temp.u('BLOCK-A')),
  'every employee and student may book; the head of Block A approves Block A''s rooms (derived from the appointment)');
-- a plain booking: tentative hold, PENDING, round owned by the custodian
CREATE TEMP TABLE bk (k text PRIMARY KEY, g uuid);
INSERT INTO bk SELECT 'B1', facility.request_booking(pg_temp.u('A-ALICE'), 'SEMINAR', 'Research seminar', ARRAY[pg_temp.u('R101')], ARRAY[pg_temp.wed(1)], '14:00', '16:00', 40, pg_temp.u('CSE'), ARRAY['PROJECTOR']);
SELECT pg_temp.ok((SELECT group_ref ~ '^GRP-[0-9]{4}-[0-9]{4}$' FROM facility.booking_group WHERE id = (SELECT g FROM bk WHERE k='B1'))
              AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B1')) = 'PENDING'
              AND (SELECT owner_org_unit_id = pg_temp.u('BLOCK-A') AND current_step = 'CUSTODIAN' AND current_anchor_org_unit_id = pg_temp.u('BLOCK-A')
                   FROM wf.v_instance_state WHERE instance_id = pg_temp.grp_instance((SELECT g FROM bk WHERE k='B1')))
              AND EXISTS (SELECT 1 FROM facility.room_hold h JOIN facility.booking_occurrence o ON o.id = h.booking_occurrence_id
                          JOIN facility.booking_request br ON br.id = o.booking_request_id WHERE br.booking_group_id = (SELECT g FROM bk WHERE k='B1') AND h.is_active),
  'booking: GRP reference, pending, round owned by the custodian block with the CUSTODIAN step anchored there, room held at once');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-BOB')::uuid, 'MEETING', 'x', ARRAY[md5('R101')::uuid], ARRAY[pg_temp.wed(1)], '15:00', '17:00')$q$, 'a second booking of a room already held (pending blocks the slot)');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '14:15')$q$, 'below the minimum duration');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[current_date + 200], '14:00', '16:00')$q$, 'beyond the advance window');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '16:00', 500)$q$, 'more people than the room holds');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '16:00', 10, NULL, ARRAY['VIDEO_CONFERENCING'])$q$, 'a room without a required feature');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R-VC')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '16:00')$q$, 'the VC''s room booked by a professor');
INSERT INTO bk SELECT 'B-VC', facility.request_booking(pg_temp.u('A-VC'), 'MEETING', 'Deans'' meeting', ARRAY[pg_temp.u('R-VC')], ARRAY[pg_temp.wed(1)], '14:00', '16:00');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R-CONF')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '16:00')$q$, 'a person-granted room booked by someone else');
INSERT INTO bk SELECT 'B-EVE', facility.request_booking(pg_temp.u('A-EVE'), 'MEETING', 'Recruitment panel', ARRAY[pg_temp.u('R-CONF')], ARRAY[pg_temp.wed(1)], '14:00', '16:00');
SELECT pg_temp.ok(true, 'reserved rooms: the VC books the VC room, Eve books the room granted to her');
INSERT INTO facility.booking_restriction (person_id, facility_resource_kind_id, booking_restriction_reason_id, note, imposed_by_account_id)
VALUES (pg_temp.u('FRANK'), pg_temp.lk('facility_resource_kind','ROOM'), pg_temp.lk('booking_restriction_reason','REPEATED_NO_SHOW'), 'Three no-shows in a month', pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-FRANK')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[pg_temp.wed(1)], '14:00', '16:00')$q$, 'a restricted person booking a room');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R103')::uuid], ARRAY[current_date - 1], '14:00', '16:00')$q$, 'a past-dated booking without the backdating right');
INSERT INTO facility.blackout (room_type_id, during, reason, created_by_account_id)
VALUES (pg_temp.lk('room_type','SEMINAR_HALL'), tsrange(pg_temp.wed(2)::timestamp, (pg_temp.wed(2) + 1)::timestamp), 'Entrance examinations', pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'MEETING', 'x', ARRAY[md5('R201A')::uuid], ARRAY[pg_temp.wed(2)], '14:00', '16:00')$q$, 'a seminar hall during a blackout');
-- approval at the custodian
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B1')), 'APPROVE', 1, 'A-ALICE')$q$, 'the requester approving her own booking');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B1')), 'APPROVE', 1, 'A-EVE')$q$, 'approving without the custodian right at that block');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B1')), 'APPROVE', 1, 'A-BOB');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B1')) = 'APPROVED', 'the head of the block approves → APPROVED');
-- a per-block chain: Block A bookings also go to the Registrar; a scoped custodian grant
INSERT INTO authz.account_role (account_id, role_id, scope_org_unit_id, include_descendants, granted_by_account_id, reason)
VALUES (pg_temp.u('A-EVE'), (SELECT id FROM authz.role WHERE code='FACILITY_CUSTODIAN'), pg_temp.u('BLOCK-A'), true, pg_temp.u('A-BOB'), 'Block A booking desk');
INSERT INTO wf.approval_chain (id, document_type_id, scope_org_unit_id, valid, note)
SELECT 9901, id, pg_temp.u('BLOCK-A'), daterange(current_date, NULL), 'Block A: custodian then Registrar' FROM wf.approval_document_type WHERE code = 'ROOM_BOOKING';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_is_owner)
SELECT 9901, v.seq, v.code, v.label, pc.permission_id, v.owner
FROM (VALUES (1, 'CUSTODIAN', 'Block A desk', 'facility.booking.approve', true), (2, 'REGISTRAR', 'Registrar''s office', 'facility.event.approve', false)) v(seq, code, label, perm, owner)
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;
INSERT INTO bk SELECT 'B2', facility.request_booking(pg_temp.u('A-DEAN'), 'WORKSHOP', 'FDP on outcome-based education', ARRAY[pg_temp.u('R103')], ARRAY[pg_temp.wed(1)], '10:30', '13:00', 50, pg_temp.u('SET'));
SELECT pg_temp.ok((SELECT string_agg(st.code || '@' || u.code, ',' ORDER BY st.seq) FROM wf.approval_step st JOIN org.org_unit u ON u.id = st.anchor_org_unit_id
                   WHERE st.instance_id = pg_temp.grp_instance((SELECT g FROM bk WHERE k='B2'))) = 'CUSTODIAN@BLOCK-A,REGISTRAR@SGTU',
  'a chain scoped to the block overrides the default: custodian at the block, then the Registrar at the university');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B2')), 'APPROVE', 1, 'A-EVE');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B2')) = 'PENDING', 'after the scoped custodian grant acts, the booking is still pending the Registrar');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B2')), 'APPROVE', 2, 'A-REG');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B2')) = 'APPROVED', 'two-stage approval complete');
-- a returned request frees the room
INSERT INTO bk SELECT 'B3', facility.request_booking(pg_temp.u('A-ALICE'), 'MEETING', 'Lab committee', ARRAY[pg_temp.u('R103')], ARRAY[pg_temp.wed(1)], '14:00', '16:00');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B3')), 'RETURN', 1, 'A-BOB', 'Room needed for the FDP overflow');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B3')) = 'RETURNED' AND facility.room_is_free(pg_temp.u('R103'), facility.span(pg_temp.wed(1), '14:00', '16:00')),
  'a returned (rejected) booking releases its hold');
-- check-in, no-show, expiry (backdated bookings by the custodian's staff)
INSERT INTO bk SELECT 'B-IN', facility.request_booking(pg_temp.u('A-BOB'), 'MEETING', 'Block staff meeting', ARRAY[pg_temp.u('R201A')], ARRAY[current_date],
  date_trunc('minute', localtime - interval '10 minutes')::time, date_trunc('minute', localtime + interval '50 minutes')::time);
INSERT INTO bk SELECT 'B-NS', facility.request_booking(pg_temp.u('A-BOB'), 'MEETING', 'Vendor meeting', ARRAY[pg_temp.u('R201B')], ARRAY[current_date],
  date_trunc('minute', localtime - interval '30 minutes')::time, date_trunc('minute', localtime + interval '30 minutes')::time);
INSERT INTO bk SELECT 'B-OLD', facility.request_booking(pg_temp.u('A-BOB'), 'MEETING', 'Yesterday''s meeting', ARRAY[pg_temp.u('R201A')], ARRAY[current_date - 1], '10:00', '12:00');
SELECT pg_temp.rejects($q$UPDATE facility.booking_occurrence SET checked_in_at = now(), checked_in_by_account_id = md5('A-BOB')::uuid
  WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-IN'))$q$, 'check-in before the booking is approved');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-IN')), 'APPROVE', 1, 'A-EVE');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-IN')), 'APPROVE', 2, 'A-REG');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-NS')), 'APPROVE', 1, 'A-EVE');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-NS')), 'APPROVE', 2, 'A-REG');
SELECT pg_temp.rejects($q$UPDATE facility.booking_occurrence SET checked_in_at = now(), checked_in_by_account_id = md5('A-BOB')::uuid
  WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B1'))$q$, 'check-in a week before the booking');
UPDATE facility.booking_occurrence SET checked_in_at = now(), checked_in_by_account_id = pg_temp.u('A-BOB')
WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-IN'));
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B-IN')) = 'IN_USE' AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B-NS')) = 'NO_SHOW'
              AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B-OLD')) = 'EXPIRED',
  'derived status: checked in = IN_USE; not checked in past the grace = NO_SHOW; never decided and over = EXPIRED');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-OLD')), 'APPROVE', 1, 'A-EVE')$q$, 'approving an expired booking');
SELECT pg_temp.rejects($q$SELECT facility.release_no_shows()$q$, 'the no-show sweep outside a system job');
SET LOCAL app.system_job = 'on';
SELECT pg_temp.ok(facility.release_no_shows() = 1, 'the no-show sweep cancels exactly the one no-show');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B-NS')) = 'CANCELLED', 'a swept no-show reads CANCELLED (' || pg_temp.grp_status((SELECT g FROM bk WHERE k='B-NS')) || ')');
SELECT pg_temp.ok(facility.room_is_free(pg_temp.u('R201B'), facility.span(current_date, date_trunc('minute', localtime - interval '20 minutes')::time, date_trunc('minute', localtime + interval '20 minutes')::time)),
  'the swept booking''s hall is free again');
SET LOCAL app.system_job = 'off';
-- self-cancellation cut-off
INSERT INTO bk SELECT 'B-SOON', facility.request_booking(pg_temp.u('A-DEAN'), 'MEETING', 'Urgent review', ARRAY[pg_temp.u('R104')], ARRAY[(localtimestamp + interval '30 minutes')::date],
  date_trunc('minute', (localtimestamp + interval '30 minutes'))::time, date_trunc('minute', (localtimestamp + interval '90 minutes'))::time);
SELECT pg_temp.rejects($q$UPDATE facility.booking_occurrence SET cancelled_at = now(), cancelled_by_account_id = md5('A-DEAN')::uuid, booking_cancel_reason_id = ref.id_of('booking_cancel_reason','REQUESTER')
  WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-SOON'))$q$, 'self-cancellation inside the cut-off');
SELECT pg_temp.rejects($q$UPDATE facility.booking_occurrence SET cancelled_at = now(), cancelled_by_account_id = md5('A-ALICE')::uuid, booking_cancel_reason_id = ref.id_of('booking_cancel_reason','REQUESTER')
  WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-SOON'))$q$, 'cancellation by an unrelated person');
SELECT pg_temp.ok(facility.cancel_booking_group((SELECT g FROM bk WHERE k='B-SOON'), pg_temp.u('A-BOB'), 'CUSTODIAN') = 1, 'the custodian cancels at any time');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B-SOON')) = 'CANCELLED', 'a custodian-cancelled booking reads CANCELLED');
SELECT pg_temp.ok(facility.cancel_booking_group((SELECT g FROM bk WHERE k='B1'), pg_temp.u('A-ALICE'), 'REQUESTER') = 1, 'the requester cancels a week ahead');
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B1')) = 'CANCELLED' AND facility.room_is_free(pg_temp.u('R101'), facility.span(pg_temp.wed(1), '14:00', '16:00')),
  'the cancelled booking reads CANCELLED and its room is free again');
SELECT pg_temp.rejects($q$UPDATE facility.booking_occurrence SET during = tsrange(lower(during), upper(during) + interval '1 hour')
  WHERE id = (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B2'))$q$, 'moving an occurrence (reschedule instead)');
-- reschedule: a change round; approval cancels the original
INSERT INTO bk SELECT 'B2R', facility.request_booking(pg_temp.u('A-DEAN'), 'WORKSHOP', 'FDP on outcome-based education (moved)', ARRAY[pg_temp.u('R103')], ARRAY[pg_temp.wed(3)], '10:30', '13:00', 50, pg_temp.u('SET'),
  NULL, false, NULL, NULL, (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B2')));
SELECT pg_temp.ok((SELECT document_type = 'ROOM_BOOKING_CHANGE' FROM wf.v_instance_state WHERE instance_id = pg_temp.grp_instance((SELECT g FROM bk WHERE k='B2R')))
              AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B2')) = 'APPROVED', 'a reschedule opens a ROOM_BOOKING_CHANGE round; the original stands until it is approved');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-DEAN')::uuid, 'WORKSHOP', 'x', ARRAY[md5('R103')::uuid], ARRAY[pg_temp.wed(4)], '10:30', '13:00', 50, md5('SET')::uuid,
  NULL, false, NULL, NULL, (SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B1')))$q$, 'rescheduling a cancelled occurrence');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B2R')), 'APPROVE', 1, 'A-EVE');   -- the change chain (default) has the custodian stage only
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B2R')) = 'APPROVED' AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B2')) = 'RESCHEDULED'
              AND facility.room_is_free(pg_temp.u('R103'), facility.span(pg_temp.wed(1), '10:30', '13:00')),
  'approving the reschedule cancels the original (RESCHEDULED) and frees its slot');
-- pre-emption: an official event displaces a class in Block A; withdrawing it reinstates the class
CREATE FUNCTION pg_temp.mon() RETURNS date LANGUAGE sql STABLE AS $$ SELECT pg_temp.nth_dow(current_date + 7, 1, 1) $$;
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = pg_temp.u('TT-L') AND lower(during) = pg_temp.mon() + time '09:00' AND is_active), 'the Monday class holds A-101 at 09:00');
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-CAROL')::uuid, 'CLUB_ACTIVITY', 'Coding club', ARRAY[md5('R101')::uuid], ARRAY[pg_temp.mon()], '09:00', '10:00')$q$, 'a student activity over a class (classes outrank it)');
INSERT INTO bk SELECT 'B-OFF', facility.request_booking(pg_temp.u('A-VC'), 'OFFICIAL_FUNCTION', 'Accreditation peer-team visit', ARRAY[pg_temp.u('R101')], ARRAY[pg_temp.mon()], '09:00', '11:00', 30, pg_temp.u('SGTU'));
SELECT pg_temp.ok((SELECT NOT is_active AND displaced_by_hold_id IS NOT NULL FROM facility.room_hold WHERE timetable_entry_id = pg_temp.u('TT-L') AND lower(during) = pg_temp.mon() + time '09:00')
              AND EXISTS (SELECT 1 FROM facility.v_displaced_hold WHERE hold_type = 'TIMETABLE' AND displaced_by_hold_type = 'OFFICIAL_EVENT' AND NOT room_free_again)
              AND EXISTS (SELECT 1 FROM facility.v_timetable_gap WHERE timetable_entry_id = pg_temp.u('TT-L') AND class_date = pg_temp.mon() AND gap_kind = 'DISPLACED'),
  'an official event (Block A rule) displaces the class: the class hold is inactive, listed as displaced and as a timetable gap');
INSERT INTO wf.approval_action (instance_id, wf_action_type_id, actor_account_id) VALUES (pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-OFF')), pg_temp.lk('wf_action_type','WITHDRAW'), pg_temp.u('A-VC'));
SELECT pg_temp.ok((SELECT is_active AND displaced_by_hold_id IS NULL FROM facility.room_hold WHERE timetable_entry_id = pg_temp.u('TT-L') AND lower(during) = pg_temp.mon() + time '09:00')
              AND NOT EXISTS (SELECT 1 FROM facility.v_timetable_gap WHERE timetable_entry_id = pg_temp.u('TT-L') AND class_date = pg_temp.mon()),
  'withdrawing the event reinstates the displaced class');
-- group booking: N rooms × M dates, skipping taken slots
SELECT pg_temp.rejects($q$SELECT facility.request_booking(md5('A-ALICE')::uuid, 'TRAINING', 'x', ARRAY[md5('R101')::uuid, md5('R103')::uuid], ARRAY[pg_temp.wed(3), pg_temp.wed(3) + 1], '13:00', '15:00')$q$,
  'a group with one taken slot, without skip-conflicts');
INSERT INTO bk SELECT 'B-GRP', facility.request_booking(pg_temp.u('A-ALICE'), 'TRAINING', 'Lab safety training', ARRAY[pg_temp.u('R101'), pg_temp.u('R103')], ARRAY[pg_temp.wed(3), pg_temp.wed(3) + 1], '13:00', '15:00',
  NULL, pg_temp.u('CSE'), NULL, true);
SELECT pg_temp.ok((SELECT occurrences = 3 AND requests = 1 AND pending = 3 FROM facility.v_booking_summary WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-GRP')),
  'group booking: 2 rooms × 2 dates with the cleaning-window slot skipped = 3 occurrences under one request (one custodian)');
SELECT pg_temp.ok((SELECT title IS NOT NULL AND requester_person_id IS NOT NULL FROM facility.v_booking_summary WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-GRP'))
              AND (SELECT count(*) = 3 FROM information_schema.columns WHERE table_schema = 'facility' AND table_name = 'booking_group'),
  'a booking group is only its reference; who asked and for what is read from its requests');
SELECT pg_temp.ok((SELECT count(*) = 6 FROM facility.occurrence_dates(current_date, current_date + 41, 'WEEKLY', 1, ARRAY[extract(isodow FROM current_date)::int]))
              AND (SELECT count(*) = 3 FROM facility.occurrence_dates(current_date, current_date + 41, 'WEEKLY', 2))
              AND (SELECT count(*) = 12 FROM facility.occurrence_dates(current_date, current_date + 41, 'CUSTOM', 1, ARRAY[1, 3])),
  'recurrence: weekly, fortnightly, custom weekdays');
-- events: one package; its rooms wait for the event, then go to their custodian
UPDATE facility.booking_restriction SET valid = tstzrange(now() - interval '1 day', now()) WHERE person_id = pg_temp.u('FRANK');   -- Frank's restriction closed (upper bound exclusive = lifted now)
INSERT INTO bk SELECT 'EV', facility.request_event(pg_temp.u('A-FRANK'), 'CSE TechFest', 'FEST', pg_temp.u('CSE'), tsrange(pg_temp.wed(5) + time '09:00', pg_temp.wed(5) + time '18:00'), 300);
INSERT INTO bk SELECT 'B-EV', facility.request_booking(pg_temp.u('A-FRANK'), 'CULTURAL', 'TechFest finale', ARRAY[pg_temp.u('R201')], ARRAY[pg_temp.wed(5)], '14:00', '18:00', 300, pg_temp.u('CSE'), NULL, false, NULL, (SELECT g FROM bk WHERE k='EV'));
SELECT pg_temp.ok(pg_temp.grp_status((SELECT g FROM bk WHERE k='B-EV')) = 'AWAITING_EVENT' AND pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-EV')) IS NULL
              AND NOT facility.room_is_free(pg_temp.u('R201B'), facility.span(pg_temp.wed(5), '15:00', '16:00'))
              AND (SELECT status = 'PENDING' FROM facility.v_event_status WHERE event_request_id = (SELECT g FROM bk WHERE k='EV')),
  'an event''s room request waits for the event (no round yet) but already holds the auditorium (and so its halls)');
SELECT pg_temp.act((SELECT instance_id FROM facility.event_request WHERE id = (SELECT g FROM bk WHERE k='EV')), 'APPROVE', 1, 'A-ALICE');    -- head of CSE endorses
SELECT pg_temp.act((SELECT instance_id FROM facility.event_request WHERE id = (SELECT g FROM bk WHERE k='EV')), 'APPROVE', 2, 'A-REG');      -- university approval
SELECT pg_temp.ok((SELECT status = 'APPROVED' FROM facility.v_event_status WHERE event_request_id = (SELECT g FROM bk WHERE k='EV'))
              AND pg_temp.grp_status((SELECT g FROM bk WHERE k='B-EV')) = 'PENDING'
              AND (SELECT owner_org_unit_id = pg_temp.u('BLOCK-A') FROM wf.v_instance_state WHERE instance_id = pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-EV'))),
  'approving the event submits its room request to the room''s custodian');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-EV')), 'APPROVE', 1, 'A-BOB');
SELECT pg_temp.act(pg_temp.grp_instance((SELECT g FROM bk WHERE k='B-EV')), 'APPROVE', 2, 'A-REG');
SELECT pg_temp.ok((SELECT room_requests_approved = 1 FROM facility.v_event_status WHERE event_request_id = (SELECT g FROM bk WHERE k='EV')), 'event status counts its approved rooms');
-- finding rooms, utilisation
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM facility.free_rooms(facility.span(pg_temp.wed(1), '14:00', '16:00'), 30, ARRAY['PROJECTOR']) WHERE room_id = pg_temp.u('R101'))
              AND NOT EXISTS (SELECT 1 FROM facility.free_rooms(facility.span(pg_temp.mon(), '09:00', '10:00')) WHERE room_id = pg_temp.u('R101'))
              AND NOT EXISTS (SELECT 1 FROM facility.free_rooms(facility.span(pg_temp.wed(1), '14:00', '16:00')) WHERE room_id = pg_temp.u('GR-1')),
  'free rooms: by size and feature; not during a class; guest rooms are not bookable rooms');
SELECT pg_temp.ok((SELECT sum(hours_held) > 0 FROM facility.v_room_utilisation WHERE room_id = pg_temp.u('R101') AND hold_type = 'TIMETABLE')
              AND EXISTS (SELECT 1 FROM facility.v_room_timeline WHERE room_id = pg_temp.u('R101') AND hold_type = 'TIMETABLE' AND label LIKE 'CS101%'),
  'utilisation per room and kind of use; the timeline labels a class with its course');

-- ---- assets, loans, maintenance ----
INSERT INTO facility.vendor (id, name, gstin) VALUES (pg_temp.u('V-AC'), 'CoolAir Services', '06AAACC1234A1Z5');
INSERT INTO facility.asset (id, asset_tag, asset_type_id, name, room_id, custodian_org_unit_id, is_portable, purchased_on, purchase_cost, warranty_until, asset_condition_id) VALUES
 (pg_temp.u('AS-PROJ'), 'PROJ-001', pg_temp.lk('asset_type','PROJECTOR'),       'Portable projector', pg_temp.u('R101'), pg_temp.u('BLOCK-A'), true,  current_date - 400, 45000, current_date + 330, pg_temp.lk('asset_condition','GOOD')),
 (pg_temp.u('AS-AC'),   'AC-101-1', pg_temp.lk('asset_type','AIR_CONDITIONER'), 'Split AC A-101',     pg_temp.u('R101'), pg_temp.u('BLOCK-A'), false, current_date - 800, 38000, current_date - 70,  pg_temp.lk('asset_condition','FAIR'));
SELECT pg_temp.rejects($q$INSERT INTO facility.asset (asset_tag, asset_type_id, name, custodian_org_unit_id, asset_condition_id, condemned_on)
  VALUES ('X-1', ref.id_of('asset_type','OTHER'), 'x', md5('BLOCK-A')::uuid, ref.id_of('asset_condition','CONDEMNED'), current_date)$q$, 'a condemned asset that is still active');
SELECT pg_temp.rejects($q$INSERT INTO facility.booking_asset (booking_occurrence_id, asset_id)
  VALUES ((SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B2R')), md5('AS-AC')::uuid)$q$, 'booking a fixed asset');
INSERT INTO facility.booking_asset (booking_occurrence_id, asset_id) VALUES ((SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B2R')), pg_temp.u('AS-PROJ'));
SELECT pg_temp.ok((SELECT count(*) = 1 FROM facility.asset_hold WHERE asset_id = pg_temp.u('AS-PROJ')), 'a portable asset booked with a room is held for the booking');
SELECT pg_temp.rejects($q$INSERT INTO facility.booking_asset (booking_occurrence_id, asset_id)
  VALUES ((SELECT occurrence_id FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk WHERE k='B-GRP') AND room_code = 'A-101' AND lower(during)::date = pg_temp.wed(3)), md5('AS-PROJ')::uuid)$q$,
  'the same projector for two bookings at once');
SELECT pg_temp.rejects($q$INSERT INTO facility.asset_loan (asset_id, borrower_person_id, during, issued_by_account_id)
  VALUES (md5('AS-PROJ')::uuid, md5('FRANK')::uuid, tsrange(pg_temp.wed(2) + time '09:00', pg_temp.wed(2) + time '17:00'), md5('A-ALICE')::uuid)$q$, 'lending an asset without the custodian''s loan right');
INSERT INTO facility.asset_loan (id, asset_id, borrower_person_id, on_behalf_org_unit_id, during, issued_by_account_id)
VALUES (pg_temp.u('LOAN-1'), pg_temp.u('AS-PROJ'), pg_temp.u('FRANK'), pg_temp.u('CSE'), tsrange(pg_temp.wed(2) + time '09:00', pg_temp.wed(2) + time '17:00'), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.asset_loan (asset_id, borrower_person_id, during, issued_by_account_id)
  VALUES (md5('AS-PROJ')::uuid, md5('ALICE')::uuid, tsrange(pg_temp.wed(2) + time '12:00', pg_temp.wed(2) + time '13:00'), md5('A-BOB')::uuid)$q$, 'lending an asset already out on loan');
-- cancelling a booking releases its assets
SELECT pg_temp.ok(facility.cancel_booking_group((SELECT g FROM bk WHERE k='B2R'), pg_temp.u('A-DEAN'), 'REQUESTER') = 1, 'the requester cancels the rescheduled booking');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM facility.asset_hold h JOIN facility.booking_asset ba ON ba.id = h.booking_asset_id)
              AND facility.room_is_free(pg_temp.u('R103'), facility.span(pg_temp.wed(3), '10:30', '13:00')), 'cancelling a booking releases the room and the projector');
-- work orders
INSERT INTO facility.maintenance_schedule (id, asset_id, maintenance_type_id, every, last_done_on, vendor_id)
VALUES (pg_temp.u('MS-AC'), pg_temp.u('AS-AC'), pg_temp.lk('maintenance_type','AMC_SERVICE'), interval '3 months', current_date - 100, pg_temp.u('V-AC'));
SELECT pg_temp.rejects($q$INSERT INTO facility.maintenance_schedule (maintenance_type_id, every) VALUES (ref.id_of('maintenance_type','INSPECTION'), interval '1 month')$q$, 'a schedule on neither an asset nor a room');
SELECT pg_temp.ok((SELECT is_due AND next_due_on = current_date - 100 + interval '3 months' FROM facility.v_maintenance_due WHERE maintenance_schedule_id = pg_temp.u('MS-AC')), 'preventive maintenance due date derived');
CREATE TEMP TABLE wo AS SELECT facility.raise_work_order(pg_temp.u('A-ALICE'), NULL, pg_temp.u('AS-AC'), 'HVAC', 'HIGH', 'AC in A-101 not cooling') AS id;
SELECT pg_temp.ok((SELECT wo_no ~ '^WO-[0-9]{4}-[0-9]{5}$' AND status = 'REPORTED' AND NOT is_overdue AND due_at = reported_at + interval '1 day' AND room_id = pg_temp.u('R101')
                   FROM facility.v_work_order_status WHERE work_order_id = (SELECT id FROM wo)),
  'work order raised: WO number, REPORTED, SLA due in a day, room taken from the asset');
SELECT pg_temp.rejects($q$INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id) VALUES ((SELECT id FROM wo), ref.id_of('work_order_status','ASSIGNED'), md5('A-BOB')::uuid)$q$, 'ASSIGNED without a technician or vendor');
UPDATE facility.work_order SET assignee_employee_id = pg_temp.u('E-EVE'), maintenance_schedule_id = pg_temp.u('MS-AC') WHERE id = (SELECT id FROM wo);
INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id) VALUES ((SELECT id FROM wo), pg_temp.lk('work_order_status','ASSIGNED'), pg_temp.u('A-BOB'));
INSERT INTO facility.room_service_window (id, room_id, room_service_type_id, during, work_order_id, created_by_account_id)
VALUES (pg_temp.u('SW-WO'), pg_temp.u('R101'), pg_temp.lk('room_service_type','REPAIR'), tsrange(pg_temp.wed(1) + time '16:00', pg_temp.wed(1) + time '18:00'), (SELECT id FROM wo), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id) VALUES ((SELECT id FROM wo), ref.id_of('work_order_status','CLOSED'), md5('A-BOB')::uuid)$q$, 'closing without a note');
INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id, note) VALUES ((SELECT id FROM wo), pg_temp.lk('work_order_status','CLOSED'), pg_temp.u('A-BOB'), 'Gas refilled');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND is_closed FROM facility.v_work_order_status WHERE work_order_id = (SELECT id FROM wo))
              AND NOT EXISTS (SELECT 1 FROM facility.room_service_window WHERE id = pg_temp.u('SW-WO'))
              AND (SELECT last_done_on = current_date AND NOT is_due FROM facility.v_maintenance_due WHERE maintenance_schedule_id = pg_temp.u('MS-AC')),
  'closing the work order releases its service window and marks the AMC schedule done');
SELECT pg_temp.rejects($q$INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id, note) VALUES ((SELECT id FROM wo), ref.id_of('work_order_status','IN_PROGRESS'), md5('A-BOB')::uuid, 'x')$q$, 'an event on a closed work order');
SELECT pg_temp.rejects($q$UPDATE facility.work_order SET cost = 1200 WHERE id = (SELECT id FROM wo)$q$, 'editing a closed work order');
SELECT pg_temp.rejects($q$DELETE FROM facility.work_order_event WHERE work_order_id = (SELECT id FROM wo)$q$, 'deleting work-order history');
INSERT INTO facility.work_order (id, room_id, work_order_category_id, work_order_priority_id, reported_by_person_id, description, reported_at)
VALUES (pg_temp.u('WO-EM'), pg_temp.u('R102'), pg_temp.lk('work_order_category','ELECTRICAL'), pg_temp.lk('work_order_priority','EMERGENCY'), pg_temp.u('ALICE'), 'Sparking socket in the lab', now() - interval '5 hours');
INSERT INTO facility.work_order_event (work_order_id, work_order_status_id) VALUES (pg_temp.u('WO-EM'), pg_temp.lk('work_order_status','REPORTED'));
SELECT pg_temp.ok((SELECT is_overdue FROM facility.v_work_order_status WHERE work_order_id = pg_temp.u('WO-EM')), 'an emergency job open for 5 hours is overdue (4-hour SLA)');
SELECT pg_temp.ok((SELECT under_warranty = false AND open_work_orders = 0 AND condition = 'FAIR' FROM facility.v_asset_register WHERE asset_id = pg_temp.u('AS-AC')), 'asset register: warranty over, no open jobs');

-- ---- guest house ----
INSERT INTO facility.guest_tariff (room_use_id, guest_category_id, rate_per_night) VALUES (pg_temp.lk('room_use','GUEST_ROOM'), pg_temp.lk('guest_category','VISITOR'), 1500);
SELECT pg_temp.rejects($q$INSERT INTO facility.guest_tariff (room_use_id, guest_category_id, rate_per_night) VALUES (ref.id_of('room_use','GUEST_ROOM'), ref.id_of('guest_category','VISITOR'), 1800)$q$, 'two tariffs for one category at a time');
SELECT pg_temp.rejects($q$SELECT facility.request_guest_stay(md5('A-FRANK')::uuid, md5('R101')::uuid, md5('EXTP')::uuid, 'VISITOR', md5('CSE')::uuid, daterange(current_date + 10, current_date + 13), 'x')$q$, 'a stay in a classroom');
SELECT pg_temp.rejects($q$SELECT facility.request_guest_stay(md5('A-FRANK')::uuid, md5('GR-1')::uuid, md5('EXTP')::uuid, 'FACULTY', md5('CSE')::uuid, daterange(current_date + 10, current_date + 13), 'x')$q$, 'an external guest under the faculty category');
SELECT pg_temp.rejects($q$SELECT facility.request_guest_stay(md5('A-FRANK')::uuid, md5('GR-1')::uuid, md5('EXTP')::uuid, 'VISITOR', md5('CSE')::uuid, daterange(current_date + 10, current_date + 13), 'x', 5)$q$, 'more guests than beds');
INSERT INTO bk SELECT 'GS-1', facility.request_guest_stay(pg_temp.u('A-FRANK'), pg_temp.u('GR-1'), pg_temp.u('EXTP'), 'VISITOR', pg_temp.u('CSE'), daterange(current_date + 10, current_date + 13), 'External examiner, visiting on his own account');
SELECT pg_temp.rejects($q$SELECT facility.request_guest_stay(md5('A-ALICE')::uuid, md5('GR-1')::uuid, md5('VCP')::uuid, 'FACULTY', md5('CSE')::uuid, daterange(current_date + 12, current_date + 14), 'x')$q$, 'overlapping nights in one guest room');
SELECT pg_temp.ok((SELECT status = 'PENDING' AND round_status = 'IN_PROGRESS' FROM facility.v_guest_stay_status WHERE guest_stay_id = (SELECT g FROM bk WHERE k='GS-1'))
              AND NOT facility.room_is_free(pg_temp.u('GR-1'), facility.night_span(daterange(current_date + 12, current_date + 13))),
  'a guest stay holds the room for its nights from submission');
SELECT pg_temp.act((SELECT instance_id FROM facility.guest_stay WHERE id = (SELECT g FROM bk WHERE k='GS-1')), 'APPROVE', 1, 'A-ALICE');   -- host unit head
SELECT pg_temp.act((SELECT instance_id FROM facility.guest_stay WHERE id = (SELECT g FROM bk WHERE k='GS-1')), 'APPROVE', 2, 'A-EVE');     -- guest-house manager
SELECT pg_temp.ok((SELECT status = 'APPROVED' FROM facility.v_guest_stay_status WHERE guest_stay_id = (SELECT g FROM bk WHERE k='GS-1'))
              AND (SELECT night_count = 3 AND total_charge = 4500 AND currency = 'INR' AND nights_without_tariff = 0 FROM facility.v_guest_stay_charge WHERE guest_stay_id = (SELECT g FROM bk WHERE k='GS-1')),
  'approved by the host unit and the guest house; charge = 3 nights × 1500');
INSERT INTO bk SELECT 'GS-2', facility.request_guest_stay(pg_temp.u('A-FRANK'), pg_temp.u('GR-1'), pg_temp.u('ALICE'), 'FACULTY', pg_temp.u('CSE'), daterange(current_date + 20, current_date + 22), 'Late-night lab work');
SELECT pg_temp.ok((SELECT total_charge = 0 FROM facility.v_guest_stay_charge WHERE guest_stay_id = (SELECT g FROM bk WHERE k='GS-2')), 'a faculty stay is complimentary');
SELECT pg_temp.rejects($q$UPDATE facility.guest_stay SET checked_in_at = now() WHERE id = (SELECT g FROM bk WHERE k='GS-2')$q$, 'checking in a guest before approval');
SELECT pg_temp.rejects($q$UPDATE facility.guest_stay SET nights = daterange(current_date + 10, current_date + 14) WHERE id = (SELECT g FROM bk WHERE k='GS-1')$q$, 'editing a stay');

-- ---- parking ----
INSERT INTO facility.parking_permit (zone_room_id, person_id, vehicle_registration_no, parking_permit_type_id) VALUES
 (pg_temp.u('P1'), pg_temp.u('ALICE'), 'HR26AB1111', pg_temp.lk('parking_permit_type','STAFF')),
 (pg_temp.u('P1'), pg_temp.u('BOB'),   'HR26AB2222', pg_temp.lk('parking_permit_type','STAFF'));
SELECT pg_temp.rejects($q$INSERT INTO facility.parking_permit (zone_room_id, person_id, vehicle_registration_no, parking_permit_type_id) VALUES (md5('P1')::uuid, md5('EVE')::uuid, 'HR26AB3333', ref.id_of('parking_permit_type','STAFF'))$q$, 'a third permit for a two-bay zone');
SELECT pg_temp.rejects($q$INSERT INTO facility.parking_permit (zone_room_id, person_id, vehicle_registration_no, parking_permit_type_id) VALUES (md5('R101')::uuid, md5('EVE')::uuid, 'HR26AB3333', ref.id_of('parking_permit_type','STAFF'))$q$, 'a permit for a classroom');
SELECT pg_temp.rejects($q$INSERT INTO facility.parking_permit (zone_room_id, person_id, vehicle_registration_no, parking_permit_type_id, valid) VALUES (md5('P1')::uuid, md5('EVE')::uuid, 'hr26ab1111', ref.id_of('parking_permit_type','STAFF'), daterange(current_date + 400, NULL))$q$, 'one vehicle under two permits at once');
SELECT pg_temp.ok((SELECT bays = 2 AND permits_today = 2 AND free_bays = 0 FROM facility.v_parking_zone_usage WHERE zone_room_id = pg_temp.u('P1')), 'parking zone usage derived');

-- ---- keys ----
INSERT INTO facility.key_item (id, key_code, key_kind_id, room_id, custodian_org_unit_id) VALUES (pg_temp.u('K-101'), 'K-A-101', pg_temp.lk('key_kind','KEY'), pg_temp.u('R101'), pg_temp.u('BLOCK-A'));
INSERT INTO facility.key_item (id, key_code, key_kind_id, floor_id, custodian_org_unit_id) VALUES (pg_temp.u('K-FL1'), 'MK-A-1', pg_temp.lk('key_kind','MASTER_KEY'), pg_temp.u('FL-1'), pg_temp.u('BLOCK-A'));
SELECT pg_temp.rejects($q$INSERT INTO facility.key_issue (key_item_id, holder_person_id, issued_by_account_id) VALUES (md5('K-101')::uuid, md5('FRANK')::uuid, md5('A-ALICE')::uuid)$q$, 'a key issued by someone who is not its custodian');
INSERT INTO facility.key_issue (id, key_item_id, holder_person_id, issued_by_account_id, due_back_at) VALUES (pg_temp.u('KI-1'), pg_temp.u('K-101'), pg_temp.u('FRANK'), pg_temp.u('A-BOB'), now() + interval '8 hours');
INSERT INTO facility.key_issue (key_item_id, holder_person_id, issued_by_account_id) VALUES (pg_temp.u('K-FL1'), pg_temp.u('BOB'), pg_temp.u('A-BOB'));
SELECT pg_temp.rejects($q$INSERT INTO facility.key_issue (key_item_id, holder_person_id, issued_by_account_id) VALUES (md5('K-101')::uuid, md5('ALICE')::uuid, md5('A-BOB')::uuid)$q$, 'a key issued while someone else holds it');
SELECT pg_temp.ok((SELECT holder_person_id = pg_temp.u('FRANK') AND NOT is_overdue FROM facility.v_key_custody WHERE key_item_id = pg_temp.u('K-101'))
              AND EXISTS (SELECT 1 FROM facility.v_key_access WHERE holder_person_id = pg_temp.u('FRANK') AND room_id = pg_temp.u('R101'))
              AND (SELECT count(*) = 5 FROM facility.v_key_access WHERE holder_person_id = pg_temp.u('BOB')),
  'key custody: Frank holds A-101''s key; Bob''s first-floor master key opens all five first-floor rooms');
UPDATE facility.key_issue SET returned_at = now(), returned_to_account_id = pg_temp.u('A-BOB') WHERE id = pg_temp.u('KI-1');
INSERT INTO facility.key_issue (key_item_id, holder_person_id, issued_by_account_id) VALUES (pg_temp.u('K-101'), pg_temp.u('ALICE'), pg_temp.u('A-BOB'));
SELECT pg_temp.ok(true, 'once returned, the key can be issued again');

-- ---- fleet & transport ----
INSERT INTO pii.person_identity_document (id, person_id, id_document_type_id, number_ciphertext, number_hmac, number_last4, expires_on) VALUES
 (pg_temp.u('DL-DRV'), pg_temp.u('DRVP'), pg_temp.lk('id_document_type','DRIVING_LICENCE'), '\x00'::bytea, digest('DL-1', 'sha256'), '4321', current_date + 400),
 (pg_temp.u('PAN-DRV'), pg_temp.u('DRVP'), pg_temp.lk('id_document_type','PAN'), '\x00'::bytea, digest('PAN-1', 'sha256'), '999X', NULL);
SELECT pg_temp.rejects($q$INSERT INTO facility.driver (employee_id, licence_document_id, licence_class_id) VALUES (md5('E-DRV')::uuid, md5('PAN-DRV')::uuid, ref.id_of('licence_class','LMV'))$q$, 'a driver whose licence document is a PAN card');
INSERT INTO facility.driver (id, employee_id, licence_document_id, licence_class_id) VALUES (pg_temp.u('DRV'), pg_temp.u('E-DRV'), pg_temp.u('DL-DRV'), pg_temp.lk('licence_class','LMV'));
INSERT INTO facility.vehicle (id, registration_no, vehicle_type_id, fuel_type_id, make_model, seats, min_licence_class_id, custodian_org_unit_id) VALUES
 (pg_temp.u('V-1'), 'HR26CA1001', pg_temp.lk('vehicle_type','CAR'), pg_temp.lk('fuel_type','PETROL'), 'Maruti Dzire', 4,  pg_temp.lk('licence_class','LMV'),  pg_temp.u('TRANSPORT')),
 (pg_temp.u('V-2'), 'HR26CB2002', pg_temp.lk('vehicle_type','BUS'), pg_temp.lk('fuel_type','DIESEL'), 'Tata Starbus',  40, pg_temp.lk('licence_class','HPMV'), pg_temp.u('TRANSPORT'));
INSERT INTO facility.vehicle_document (vehicle_id, vehicle_document_type_id, document_no, valid) VALUES
 (pg_temp.u('V-1'), pg_temp.lk('vehicle_document_type','RC'),        'RC-1001', daterange('2020-01-01', '2035-01-01')),
 (pg_temp.u('V-1'), pg_temp.lk('vehicle_document_type','INSURANCE'), 'INS-1001', daterange(current_date - 100, current_date + 265)),
 (pg_temp.u('V-2'), pg_temp.lk('vehicle_document_type','RC'),        'RC-2002', daterange('2020-01-01', '2035-01-01')),
 (pg_temp.u('V-2'), pg_temp.lk('vehicle_document_type','INSURANCE'), 'INS-2002', daterange(current_date - 100, current_date + 265)),
 (pg_temp.u('V-2'), pg_temp.lk('vehicle_document_type','PUC'),       'PUC-2002', daterange(current_date - 100, current_date + 80));
SELECT pg_temp.rejects($q$INSERT INTO facility.vehicle_document (vehicle_id, vehicle_document_type_id, document_no, valid) VALUES (md5('V-1')::uuid, ref.id_of('vehicle_document_type','INSURANCE'), 'INS-X', daterange(current_date, current_date + 10))$q$, 'two insurance documents in force at once');
SELECT pg_temp.ok((SELECT string_agg(document_type || ':' || status, ',' ORDER BY document_type) FROM facility.v_vehicle_document_status WHERE vehicle_id = pg_temp.u('V-1')) = 'INSURANCE:VALID,PUC:MISSING,RC:VALID',
  'vehicle document status: the PUC is missing');
CREATE FUNCTION pg_temp.dep(h int) RETURNS timestamp LANGUAGE sql STABLE AS $$ SELECT date_trunc('minute', localtimestamp) + make_interval(hours => h) $$;
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_request (requester_person_id, on_behalf_org_unit_id, trip_purpose_id, during, origin_text, destination_text, headcount, contact_phone, instance_id)
  VALUES (md5('FRANK')::uuid, md5('MBA')::uuid, ref.id_of('trip_purpose','OFFICIAL_VISIT'), tsrange(pg_temp.dep(48), pg_temp.dep(52)), 'Campus', 'Delhi', 3, '+919876543210',
          wf.submit('TRIP_REQUEST', md5('CSE')::uuid, md5('A-FRANK')::uuid))$q$, 'a trip request whose round belongs to another unit');
SELECT pg_temp.rejects($q$SELECT facility.request_trip(md5('A-FRANK')::uuid, md5('CSE')::uuid, 'OFFICIAL_VISIT', tsrange(pg_temp.dep(48), pg_temp.dep(52)), 'Campus', 'Delhi', 60, '+919876543210')$q$, 'a party larger than the policy allows');
SELECT pg_temp.rejects($q$SELECT facility.request_trip(md5('A-FRANK')::uuid, md5('CSE')::uuid, 'OFFICIAL_VISIT', tsrange(pg_temp.dep(48), pg_temp.dep(52)), 'Campus', 'Delhi', 3, '9876543210')$q$, 'a contact number that is not E.164');
INSERT INTO bk SELECT 'T1', facility.request_trip(pg_temp.u('A-FRANK'), pg_temp.u('CSE'), 'OFFICIAL_VISIT', tsrange(pg_temp.dep(48), pg_temp.dep(52)), 'SGT campus', 'AICTE, New Delhi', 3, '+919876543210', 'Accreditation meeting');
INSERT INTO bk SELECT 'T-URG', facility.request_trip(pg_temp.u('A-ALICE'), pg_temp.u('CSE'), 'MEDICAL', tsrange(pg_temp.dep(0) + interval '30 minutes', pg_temp.dep(3)), 'SGT campus', 'Civil hospital', 2, '+919876500000');
SELECT pg_temp.ok((SELECT NOT is_urgent AND status = 'PENDING' AND current_step = 'UNIT_HEAD' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1'))
              AND (SELECT is_urgent AND current_step = 'TRANSPORT' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T-URG')),
  'a trip two days out goes unit head → transport; one leaving within the hour goes straight to transport');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'allocating a vehicle before approval');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T1')), 'APPROVE', 1, 'A-ALICE');
SELECT pg_temp.rejects($q$SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T1')), 'APPROVE', 2, 'A-BOB')$q$, 'the transport step by someone outside the transport office');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T1')), 'APPROVE', 2, 'A-TM');
SELECT pg_temp.ok((SELECT status = 'APPROVED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1')), 'trip approved by the unit head and the transport office');
-- escalations
SELECT pg_temp.rejects($q$SELECT * FROM facility.run_trip_escalations()$q$, 'the escalation job outside a system job');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id)
  VALUES ((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T-URG')), 1, ref.id_of('wf_action_type','AUTO_APPROVE'))$q$, 'a system approval outside a system job');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id)
  VALUES ((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T-URG')), 1, ref.id_of('wf_action_type','AUTO_APPROVE'), md5('A-TM')::uuid)$q$, 'a system approval with a human actor');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE esc AS SELECT * FROM facility.run_trip_escalations();
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok((SELECT auto_approved = 1 AND alerts = 2 FROM esc), 'escalation job: one auto-approval, two alerts (auto_approved/alerts = ' || (SELECT auto_approved || '/' || alerts FROM esc) || ')');
SELECT pg_temp.ok((SELECT status = 'APPROVED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T-URG'))
              AND EXISTS (SELECT 1 FROM facility.trip_alert a JOIN ref.trip_alert_type t ON t.id = a.trip_alert_type_id AND t.code = 'AUTO_APPROVED' WHERE a.trip_request_id = (SELECT g FROM bk WHERE k='T-URG'))
              AND EXISTS (SELECT 1 FROM facility.trip_alert a JOIN ref.trip_alert_type t ON t.id = a.trip_alert_type_id AND t.code = 'UNALLOCATED_SOON' WHERE a.trip_request_id = (SELECT g FROM bk WHERE k='T-URG'))
              AND EXISTS (SELECT 1 FROM wf.approval_action a WHERE a.instance_id = (SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T-URG')) AND a.actor_account_id IS NULL),
  'the escalation job auto-approves the undecided urgent trip (system action, no actor) and raises the alerts');
-- allocation checks
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-2')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a bus for a driver with an LMV licence');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a vehicle without a valid PUC');
INSERT INTO facility.vehicle_document (id, vehicle_id, vehicle_document_type_id, document_no, valid) VALUES (pg_temp.u('PUC-1'), pg_temp.u('V-1'), pg_temp.lk('vehicle_document_type','PUC'), 'PUC-1001', daterange(current_date - 10, current_date + 1));
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a PUC that expires before the trip ends');
UPDATE facility.vehicle_document SET valid = daterange(current_date - 10, current_date + 170) WHERE id = pg_temp.u('PUC-1');
INSERT INTO facility.vehicle_service_window (id, vehicle_id, vehicle_service_type_id, during) VALUES (pg_temp.u('VSW-1'), pg_temp.u('V-1'), pg_temp.lk('vehicle_service_type','SERVICING'), tsrange(pg_temp.dep(50), pg_temp.dep(51)));
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a vehicle booked for servicing during the trip');
DELETE FROM facility.vehicle_service_window WHERE id = pg_temp.u('VSW-1');
INSERT INTO facility.driver_unavailability (id, driver_id, driver_unavailability_reason_id, during) VALUES (pg_temp.u('DU-1'), pg_temp.u('DRV'), pg_temp.lk('driver_unavailability_reason','LEAVE'), tsrange(pg_temp.dep(40), pg_temp.dep(60)));
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a driver on leave');
DELETE FROM facility.driver_unavailability WHERE id = pg_temp.u('DU-1');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(47), pg_temp.dep(53)), md5('A-BOB')::uuid)$q$, 'allocation by someone outside the transport office');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T1'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(49), pg_temp.dep(53)), md5('A-TM')::uuid)$q$, 'a dispatch window that does not cover the request');
INSERT INTO facility.trip_allocation (id, trip_request_id, driver_id, during, allocated_by_account_id, start_token_hash, complete_token_hash)
VALUES (pg_temp.u('AL-1'), (SELECT g FROM bk WHERE k='T1'), pg_temp.u('DRV'), tsrange(pg_temp.dep(47), pg_temp.dep(53)), pg_temp.u('A-TM'), digest('start-1', 'sha256'), digest('done-1', 'sha256'));
SELECT pg_temp.ok((SELECT status = 'DRIVER_ALLOCATED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1')), 'driver first: DRIVER_ALLOCATED');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip (trip_allocation_id) VALUES (md5('AL-1')::uuid)$q$, 'a trip on an allocation without a vehicle');
UPDATE facility.trip_allocation SET vehicle_id = pg_temp.u('V-1') WHERE id = pg_temp.u('AL-1');
SELECT pg_temp.ok((SELECT status = 'ALLOCATED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1')), 'then the vehicle: ALLOCATED');
SELECT pg_temp.rejects($q$UPDATE facility.trip_request SET cancelled_at = now(), cancelled_by_account_id = md5('A-FRANK')::uuid, trip_cancel_reason_id = ref.id_of('trip_cancel_reason','PLAN_CHANGED') WHERE id = (SELECT g FROM bk WHERE k='T1')$q$, 'cancelling a trip once a vehicle is allocated');
-- a second trip in the same window: the vehicle cannot be double-allocated, but the party can pool
INSERT INTO bk SELECT 'T3', facility.request_trip(pg_temp.u('A-FRANK'), pg_temp.u('CSE'), 'OFFICIAL_VISIT', tsrange(pg_temp.dep(48), pg_temp.dep(51)), 'SGT campus', 'UGC, New Delhi', 1, '+919876543210');
INSERT INTO bk SELECT 'T4', facility.request_trip(pg_temp.u('A-FRANK'), pg_temp.u('CSE'), 'FIELD_VISIT', tsrange(pg_temp.dep(48), pg_temp.dep(51)), 'SGT campus', 'Industry visit', 4, '+919876543210');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation_request (trip_allocation_id, trip_request_id, added_by_account_id) VALUES (md5('AL-1')::uuid, (SELECT g FROM bk WHERE k='T3'), md5('A-TM')::uuid)$q$, 'pooling a trip that is not yet approved');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T3')), 'APPROVE', 1, 'A-ALICE');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T3')), 'APPROVE', 2, 'A-TM');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T4')), 'APPROVE', 1, 'A-ALICE');
SELECT pg_temp.act((SELECT instance_id FROM facility.trip_request WHERE id = (SELECT g FROM bk WHERE k='T4')), 'APPROVE', 2, 'A-TM');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation (trip_request_id, driver_id, vehicle_id, during, allocated_by_account_id)
  VALUES ((SELECT g FROM bk WHERE k='T3'), md5('DRV')::uuid, md5('V-1')::uuid, tsrange(pg_temp.dep(48), pg_temp.dep(51)), md5('A-TM')::uuid)$q$, 'the same vehicle / driver for two trips at once');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation_request (trip_allocation_id, trip_request_id, added_by_account_id) VALUES (md5('AL-1')::uuid, (SELECT g FROM bk WHERE k='T4'), md5('A-TM')::uuid)$q$, 'pooling more passengers than seats (3 + 4 > 4)');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_allocation_request (trip_allocation_id, trip_request_id, added_by_account_id) VALUES (md5('AL-1')::uuid, (SELECT g FROM bk WHERE k='T-URG'), md5('A-TM')::uuid)$q$, 'pooling a trip outside the allocation window');
INSERT INTO facility.trip_allocation_request (trip_allocation_id, trip_request_id, added_by_account_id) VALUES (pg_temp.u('AL-1'), (SELECT g FROM bk WHERE k='T3'), pg_temp.u('A-TM'));
SELECT pg_temp.ok((SELECT status = 'POOLED' AND is_pooled AND vehicle_id = pg_temp.u('V-1') FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T3')), 'a one-person trip pools onto the car (3 + 1 seats)');
-- the trip itself
INSERT INTO facility.trip (id, trip_allocation_id, started_at, start_odometer_km) VALUES (pg_temp.u('TRIP-1'), pg_temp.u('AL-1'), now(), 41200);
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_rating (trip_id, rating_role_id, rated_by_person_id, rating) VALUES (md5('TRIP-1')::uuid, ref.id_of('rating_role','PASSENGER'), md5('FRANK')::uuid, 5)$q$, 'rating a trip that is not complete');
SELECT pg_temp.rejects($q$UPDATE facility.trip SET completed_at = now(), end_odometer_km = 41100 WHERE id = md5('TRIP-1')::uuid$q$, 'an odometer going backwards');
SELECT pg_temp.rejects($q$UPDATE facility.trip_allocation SET released_at = now(), released_by_account_id = md5('A-TM')::uuid WHERE id = md5('AL-1')::uuid$q$, 'releasing an allocation whose trip has started');
UPDATE facility.trip SET completed_at = now(), end_odometer_km = 41290 WHERE id = pg_temp.u('TRIP-1');
SELECT pg_temp.ok((SELECT status = 'COMPLETED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1'))
              AND (SELECT status = 'COMPLETED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T3')), 'the trip completes for the primary and the pooled request');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_rating (trip_id, rating_role_id, rated_by_person_id, rating) VALUES (md5('TRIP-1')::uuid, ref.id_of('rating_role','PASSENGER'), md5('FRANK')::uuid, 6)$q$, 'a rating out of 1–5');
SELECT pg_temp.rejects($q$INSERT INTO facility.trip_rating (trip_id, rating_role_id, rated_by_person_id, rating) VALUES (md5('TRIP-1')::uuid, ref.id_of('rating_role','PASSENGER'), md5('BOB')::uuid, 4)$q$, 'a rating by someone who was not on the trip');
INSERT INTO facility.trip_rating (trip_id, rating_role_id, rated_by_person_id, rating) VALUES
 (pg_temp.u('TRIP-1'), pg_temp.lk('rating_role','PASSENGER'), pg_temp.u('FRANK'), 5), (pg_temp.u('TRIP-1'), pg_temp.lk('rating_role','DRIVER'), pg_temp.u('DRVP'), 4);
SELECT pg_temp.rejects($q$UPDATE facility.trip SET closed_at = now(), closed_by_account_id = md5('A-FRANK')::uuid WHERE id = md5('TRIP-1')::uuid$q$, 'a passenger closing the trip');
UPDATE facility.trip SET closed_at = now(), closed_by_account_id = pg_temp.u('A-TM') WHERE id = pg_temp.u('TRIP-1');
SELECT pg_temp.ok((SELECT status = 'CLOSED' FROM facility.v_trip_status WHERE trip_request_id = (SELECT g FROM bk WHERE k='T1'))
              AND (SELECT sum(requests) = 4 AND sum(completed) = 2 AND sum(pooled) = 1 AND sum(km_driven) = 90 AND max(avg_driver_rating) = 5.00
                   FROM facility.v_trip_summary WHERE on_behalf_org_unit_id = pg_temp.u('CSE')),   -- summed: the trips may straddle a month end
  'trip summary for CSE: 4 requests, 2 completed (one pooled), 90 km, driver rated 5 (got ' || (SELECT sum(requests) || '/' || sum(completed) || '/' || sum(pooled) || '/' || sum(km_driven) || '/' || max(avg_driver_rating) FROM facility.v_trip_summary WHERE on_behalf_org_unit_id = pg_temp.u('CSE')) || ')');
SELECT pg_temp.rejects($q$UPDATE facility.trip SET note = 'x' WHERE id = md5('TRIP-1')::uuid$q$, 'editing a closed trip');
SELECT pg_temp.rejects($q$UPDATE facility.trip_request SET headcount = 2 WHERE id = (SELECT g FROM bk WHERE k='T4')$q$, 'editing a trip request');

-- ---- audit: a restriction note is personal (disciplinary) data ----
SET LOCAL app.account_id = 'ff000000-0000-0000-0000-000000000009';
UPDATE facility.booking_restriction SET note = 'Four no-shows' WHERE person_id = pg_temp.u('FRANK');
SELECT pg_temp.ok((SELECT c.new_value = '[REDACTED]' FROM audit.audit_event e JOIN audit.audit_change c ON c.audit_event_id = e.id AND c.occurred_at = e.occurred_at
                   WHERE e.entity_table = 'booking_restriction' AND c.column_name = 'note' ORDER BY e.id DESC LIMIT 1),
  'audit redacts the restriction note');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid WHERE c.relname = 'room_hold' AND t.tgname = 'trg_audit_capture'),
  'the ledger itself is not audited (its sources are)');

-- ============== approval engine: every pattern is configuration (06b) ==========
-- A document type no module knows about — a purchase request — put on the
-- engine with rows only: five levels showing each approver kind, conditions,
-- self-skip, forwarding, return-to, a checklist, a file, deadlines.
INSERT INTO authz.resource (app_module_id, code, label) SELECT id, 'purchase', 'Purchase requests (test)' FROM authz.app_module WHERE code = 'core_admin';
INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, true FROM authz.resource r JOIN authz.app_module m ON m.id = r.app_module_id AND m.code = 'core_admin' AND r.code = 'purchase'
JOIN authz.action a ON a.code = 'approve';
INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id FROM authz.role r, authz.v_permission_code pc WHERE r.code = 'ORG_UNIT_HEAD' AND pc.code = 'core_admin.purchase.approve';
INSERT INTO ref.wf_flag (code, label) VALUES ('CAPITAL', 'Capital expenditure');
INSERT INTO ref.academic_body_type (code, label, sort_order) VALUES ('PURCHASE_COMMITTEE', 'Purchase committee', 20);
INSERT INTO academic.academic_body (id, academic_body_type_id, org_unit_id, name, quorum)
VALUES (pg_temp.u('PC'), pg_temp.lk('academic_body_type','PURCHASE_COMMITTEE'), pg_temp.u('SGTU'), 'Central purchase committee', 2);
INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id, valid) VALUES
 (pg_temp.u('PC'), pg_temp.lk('committee_role','CHAIR'),  pg_temp.u('E-DAC'), daterange('2024-01-01', NULL)),
 (pg_temp.u('PC'), pg_temp.lk('committee_role','MEMBER'), pg_temp.u('E-BOB'), daterange('2024-01-01', NULL)),
 (pg_temp.u('PC'), pg_temp.lk('committee_role','MEMBER'), pg_temp.u('E-TM'),  daterange('2024-01-01', NULL));
INSERT INTO people.employee_reporting_line (employee_id, manager_employee_id, reporting_line_type_id, valid) VALUES
 (pg_temp.u('E-FRANK'), pg_temp.u('E-ALICE'), pg_temp.lk('reporting_line_type','REPORTING'), daterange('2024-01-01', NULL)),
 (pg_temp.u('E-ALICE'), pg_temp.u('E-DEAN'),  pg_temp.lk('reporting_line_type','REPORTING'), daterange('2024-01-01', NULL)),
 (pg_temp.u('E-BOB'),   pg_temp.u('E-REG'),   pg_temp.lk('reporting_line_type','REPORTING'), daterange('2024-01-01', NULL));
INSERT INTO people.file_object (id, storage_backend_id, object_key, mime_type, byte_size, sha256)
VALUES (pg_temp.u('F-SANCTION'), pg_temp.lk('storage_backend','S3'), 'wf/sanction-order.pdf', 'application/pdf', 1024, digest('sanction', 'sha256'));

INSERT INTO wf.approval_document_type (id, code, label, app_module_id, author_permission_id)
SELECT v.id, v.code, v.label, m.id, pc.permission_id
FROM (VALUES (9001, 'PURCHASE_REQUEST', 'Purchase request (test)'), (9002, 'QUICK_NOTE', 'Note with deadlines (test)'),
             (9003, 'QUICK_REJECT', 'Note rejected on timeout (test)')) v(id, code, label),
     authz.app_module m, authz.v_permission_code pc WHERE m.code = 'core_admin' AND pc.code = 'self_service.profile.view';
INSERT INTO wf.approval_document_type (id, code, label, app_module_id, author_permission_id, allows_empty_chain)
SELECT 9004, 'SMALL_CLAIM', 'Claim approved automatically below a threshold (test)', m.id, pc.permission_id, true
FROM authz.app_module m, authz.v_permission_code pc WHERE m.code = 'core_admin' AND pc.code = 'self_service.profile.view';
INSERT INTO wf.approval_chain (id, document_type_id, valid) VALUES
 (9101, 9001, daterange('2000-01-01', NULL)), (9102, 9002, daterange('2000-01-01', NULL)),
 (9103, 9003, daterange('2000-01-01', NULL)), (9104, 9004, daterange('2000-01-01', NULL));
-- purchase requests take every level strictly in order (a chain setting); passing levels over is shown further down
UPDATE wf.approval_chain SET allows_level_override = false WHERE id = 9101;
-- the five levels of a purchase request
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, allows_forward, due_within, wf_timeout_action_id)
VALUES (9101, 1, 'MANAGER', 'Reporting manager', pg_temp.lk('wf_approver_kind','MANAGER'), true, interval '2 days', pg_temp.lk('wf_timeout_action','ESCALATE'));
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_is_owner, wf_self_action_id)
SELECT 9101, 2, 'UNIT_HEAD', 'Head of the unit', permission_id, true, pg_temp.lk('wf_self_action','SKIP') FROM authz.v_permission_code WHERE code = 'core_admin.purchase.approve';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, min_amount)
SELECT 9101, 3, 'REGISTRAR', 'Registrar (50,000 and above)', pg_temp.lk('wf_approver_kind','POSITION'), id, 50000 FROM org.position_type WHERE code = 'REGISTRAR';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, academic_body_id, wf_flag_id)
VALUES (9101, 4, 'COMMITTEE', 'Purchase committee (capital items)', pg_temp.lk('wf_approver_kind','COMMITTEE'), pg_temp.u('PC'), pg_temp.lk('wf_flag','CAPITAL'));
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, allows_return_to, needs_file)
VALUES (9101, 5, 'SANCTION', 'Sanctioning authority named on the request', pg_temp.lk('wf_approver_kind','NAMED'), true, true);
INSERT INTO wf.approval_chain_stage_check (chain_id, seq, check_no, label) VALUES (9101, 5, 1, 'Budget head verified');
-- deadlines: escalate, then approve automatically; reject automatically; a level only above 1,000
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_is_owner, due_within, wf_timeout_action_id)
SELECT 9102, 1, 'UNIT_HEAD', 'Head of the unit', permission_id, true, interval '1 microsecond', pg_temp.lk('wf_timeout_action','ESCALATE') FROM authz.v_permission_code WHERE code = 'core_admin.purchase.approve';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, due_within, wf_timeout_action_id)
SELECT 9102, 2, 'REGISTRAR', 'Registrar', pg_temp.lk('wf_approver_kind','POSITION'), id, interval '1 microsecond', pg_temp.lk('wf_timeout_action','AUTO_APPROVE') FROM org.position_type WHERE code = 'REGISTRAR';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, due_within, wf_timeout_action_id)
SELECT 9103, 1, 'REGISTRAR', 'Registrar', pg_temp.lk('wf_approver_kind','POSITION'), id, interval '1 microsecond', pg_temp.lk('wf_timeout_action','AUTO_REJECT') FROM org.position_type WHERE code = 'REGISTRAR';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, min_amount)
SELECT 9104, 1, 'REGISTRAR', 'Registrar (1,000 and above)', pg_temp.lk('wf_approver_kind','POSITION'), id, 1000 FROM org.position_type WHERE code = 'REGISTRAR';

-- configuration is validated
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label) VALUES (9101, 9, 'X', 'x')$q$, 'a PERMISSION level without a permission');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','POSITION'))$q$, 'a POSITION level without a position type');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','COMMITTEE'))$q$, 'a COMMITTEE level without a body');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, academic_body_id) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','NAMED'), md5('PC')::uuid)$q$, 'a committee on a level that is not a COMMITTEE level');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, wf_timeout_action_id) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','NAMED'), ref.id_of('wf_timeout_action','REMIND'))$q$, 'a timeout action without a deadline');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, due_within, wf_timeout_action_id) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','NAMED'), interval '1 day', ref.id_of('wf_timeout_action','ESCALATE'))$q$, 'escalation on a NAMED level');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, min_amount, max_amount) VALUES (9101, 9, 'X', 'x', ref.id_of('wf_approver_kind','NAMED'), 500, 100)$q$, 'an amount band whose ceiling is below its floor');

CREATE TEMP TABLE pr (k text PRIMARY KEY, i uuid);
CREATE FUNCTION pg_temp.pri(k text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT i FROM pr WHERE pr.k = $1 $$;
CREATE FUNCTION pg_temp.steps(p uuid) RETURNS text LANGUAGE sql STABLE AS $$ SELECT string_agg(code, ',' ORDER BY seq) FROM wf.approval_step WHERE instance_id = p $$;
CREATE FUNCTION pg_temp.st(p uuid) RETURNS text LANGUAGE sql STABLE AS $$ SELECT status || COALESCE('@' || current_step, '') FROM wf.v_instance_state WHERE instance_id = p $$;

-- A. a small revenue purchase by Eve (Recruitment Cell): manager → unit head → named sanction
SELECT pg_temp.rejects($q$SELECT wf.submit('PURCHASE_REQUEST', md5('HR-S1')::uuid, md5('A-EVE')::uuid, 'Stationery', 10000)$q$, 'a NAMED level with nobody named at submission');
SELECT pg_temp.rejects($q$SELECT wf.submit('PURCHASE_REQUEST', md5('HR-S1')::uuid, md5('A-EVE')::uuid, 'Stationery', 10000, NULL, NULL, ARRAY[md5('A-EVE')::uuid])$q$, 'the requester named as her own sanctioning authority');
INSERT INTO pr SELECT 'A', wf.submit('PURCHASE_REQUEST', pg_temp.u('HR-S1'), pg_temp.u('A-EVE'), 'Stationery', 10000, NULL, NULL, ARRAY[pg_temp.u('A-VC')]);
SELECT pg_temp.ok(pg_temp.steps(pg_temp.pri('A')) = 'MANAGER,UNIT_HEAD,SANCTION' AND pg_temp.st(pg_temp.pri('A')) = 'IN_PROGRESS@MANAGER'
              AND (SELECT account_id = pg_temp.u('A-BOB') FROM wf.approval_step_assignee WHERE instance_id = pg_temp.pri('A') AND seq = 1),
  'conditions: below 50,000 and not capital → the Registrar and committee levels are left out; the manager level is resolved to Eve''s reporting manager');
SELECT pg_temp.ok(wf.can_act(pg_temp.u('A-BOB'), pg_temp.pri('A')) AND NOT wf.can_act(pg_temp.u('A-ALICE'), pg_temp.pri('A'))
              AND EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-BOB')) WHERE instance_id = pg_temp.pri('A') AND amount = 10000 AND current_due_at IS NOT NULL AND NOT is_overdue),
  'the manager finds it in his inbox with the amount and the deadline; nobody else can act');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'APPROVE', md5('A-ALICE')::uuid)$q$, 'approval of the manager level by someone who is not the manager');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'RETURN_TO', md5('A-BOB')::uuid, 'back', NULL, NULL, 1)$q$, 'RETURN_TO from a level that does not allow it');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'FORWARD', md5('A-BOB')::uuid, NULL, NULL, md5('A-EVE')::uuid)$q$, 'forwarding to the requester');
SELECT wf.act(pg_temp.pri('A'), 'FORWARD', pg_temp.u('A-BOB'), 'On tour — please decide', NULL, pg_temp.u('A-TM'));
SELECT pg_temp.ok(wf.can_act(pg_temp.u('A-TM'), pg_temp.pri('A')) AND NOT wf.can_act(pg_temp.u('A-BOB'), pg_temp.pri('A')), 'forwarding hands the level to the named person and releases the forwarder');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'APPROVE', md5('A-BOB')::uuid)$q$, 'the forwarder approving after forwarding');
SELECT wf.act(pg_temp.pri('A'), 'APPROVE', pg_temp.u('A-TM'));
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'FORWARD', md5('A-REG')::uuid, NULL, NULL, md5('A-DAC')::uuid)$q$, 'forwarding from a level that does not allow it');
SELECT wf.act(pg_temp.pri('A'), 'APPROVE', pg_temp.u('A-REG'));     -- unit head level: the Registrar holds it over the whole tree
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('A')) = 'IN_PROGRESS@SANCTION', 'two levels done; the named sanctioning authority is next');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'APPROVE', md5('A-VC')::uuid, NULL, md5('F-SANCTION')::uuid)$q$, 'approving without ticking the mandatory checklist');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_step_check (instance_id, seq, check_no, checked_by_account_id) VALUES (pg_temp.pri('A'), 5, 1, md5('A-BOB')::uuid)$q$, 'a checklist ticked by someone who is not the approver');
INSERT INTO wf.approval_step_check (instance_id, seq, check_no, checked_by_account_id) VALUES (pg_temp.pri('A'), 5, 1, pg_temp.u('A-VC'));
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'APPROVE', md5('A-VC')::uuid)$q$, 'approving a level that needs a file without one');
SELECT wf.act(pg_temp.pri('A'), 'RETURN_TO', pg_temp.u('A-VC'), 'Unit head to confirm the quantity', NULL, NULL, 2);
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('A')) = 'IN_PROGRESS@UNIT_HEAD' AND (SELECT NOT done FROM wf.v_step_state WHERE instance_id = pg_temp.pri('A') AND seq = 2),
  'RETURN_TO sends the round back to the earlier level; that level''s approval no longer counts');
SELECT wf.act(pg_temp.pri('A'), 'APPROVE', pg_temp.u('A-REG'), 'Quantity confirmed');
SELECT wf.act(pg_temp.pri('A'), 'APPROVE', pg_temp.u('A-VC'), NULL, pg_temp.u('F-SANCTION'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('A')) = 'APPROVED'
              AND (SELECT string_agg(k.code, ',' ORDER BY k.sort_order) FROM (SELECT DISTINCT wf_notice_kind_id FROM wf.approval_notice WHERE instance_id = pg_temp.pri('A')) n
                   JOIN ref.wf_notice_kind k ON k.id = n.wf_notice_kind_id) = 'STEP_PENDING,FORWARDED,APPROVED',
  'approved after the second pass; the outbox carried step-pending, forwarded and approved notices');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('A'), 'APPROVE', md5('A-VC')::uuid)$q$, 'acting on a closed round');

-- B. a capital purchase of 80,000 by Frank (CSE): all five levels
INSERT INTO pr SELECT 'B', wf.submit('PURCHASE_REQUEST', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'GPU server', 80000, ARRAY['CAPITAL'], NULL, ARRAY[pg_temp.u('A-VC')]);
SELECT pg_temp.ok(pg_temp.steps(pg_temp.pri('B')) = 'MANAGER,UNIT_HEAD,REGISTRAR,COMMITTEE,SANCTION'
              AND (SELECT required = 2 AND assignees = 3 FROM wf.v_step_state WHERE instance_id = pg_temp.pri('B') AND seq = 4),
  'amount and flag bring in the Registrar and the purchase committee (3 members, quorum 2)');
SELECT wf.act(pg_temp.pri('B'), 'APPROVE', pg_temp.u('A-ALICE'));
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('B'), 'APPROVE', md5('A-ALICE')::uuid)$q$, 'one person approving two levels of a round (manager and unit head)');
SELECT wf.act(pg_temp.pri('B'), 'APPROVE', pg_temp.u('A-DEAN'));
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('B'), 'APPROVE', md5('A-DAC')::uuid)$q$, 'the Registrar level approved by someone who does not hold the position');
SELECT wf.act(pg_temp.pri('B'), 'APPROVE', pg_temp.u('A-REG'));
SELECT wf.act(pg_temp.pri('B'), 'APPROVE', pg_temp.u('A-DAC'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('B')) = 'IN_PROGRESS@COMMITTEE', 'one committee member''s approval is below the quorum');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('B'), 'APPROVE', md5('A-DAC')::uuid)$q$, 'a committee member approving twice');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('B'), 'APPROVE', md5('A-EVE')::uuid)$q$, 'a non-member approving the committee level');
SELECT wf.act(pg_temp.pri('B'), 'APPROVE', pg_temp.u('A-BOB'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('B')) = 'IN_PROGRESS@SANCTION', 'the quorum (2 of 3) moves it on');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('B'), 'REJECT', md5('A-VC')::uuid)$q$, 'a rejection without a note');
SELECT wf.act(pg_temp.pri('B'), 'REJECT', pg_temp.u('A-VC'), 'Not in this year''s budget');
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('B')) = 'REJECTED' AND NOT (SELECT is_complete FROM wf.v_instance_state WHERE instance_id = pg_temp.pri('B')), 'REJECT is final (distinct from RETURN for revision)');
INSERT INTO pr SELECT 'B2', wf.submit('PURCHASE_REQUEST', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'GPU server (smaller)', 30000, NULL, NULL, ARRAY[pg_temp.u('A-VC')], pg_temp.pri('B'));
SELECT pg_temp.ok((SELECT revises_instance_id = pg_temp.pri('B') FROM wf.approval_instance WHERE id = pg_temp.pri('B2')), 'a new round records the round it revises');

-- C. the requester is the approver: the head of CSE asks for her own unit
INSERT INTO pr SELECT 'C', wf.submit('PURCHASE_REQUEST', pg_temp.u('CSE'), pg_temp.u('A-ALICE'), 'Lab consumables', 1000, NULL, NULL, ARRAY[pg_temp.u('A-VC')]);
SELECT pg_temp.ok(pg_temp.steps(pg_temp.pri('C')) = 'MANAGER,SANCTION'
              AND (SELECT account_id = pg_temp.u('A-DEAN') FROM wf.approval_step_assignee WHERE instance_id = pg_temp.pri('C') AND seq = 1),
  'self-action SKIP: the unit-head level is left out for the head''s own request; her manager (the Dean) still decides');

-- D. delegation: Bob is away; the transport manager stands in for a week
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_delegation (delegator_account_id, delegate_account_id, valid) VALUES (md5('A-BOB')::uuid, md5('A-TM')::uuid, tstzrange(now(), NULL))$q$, 'an open-ended delegation');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_delegation (delegator_account_id, delegate_account_id, valid) VALUES (md5('A-BOB')::uuid, md5('A-BOB')::uuid, tstzrange(now(), now() + interval '7 days'))$q$, 'delegating to oneself');
INSERT INTO wf.approval_delegation (delegator_account_id, delegate_account_id, valid, reason)
VALUES (pg_temp.u('A-BOB'), pg_temp.u('A-TM'), tstzrange(now() - interval '1 hour', now() + interval '7 days'), 'On leave');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_delegation (delegator_account_id, delegate_account_id, valid) VALUES (md5('A-BOB')::uuid, md5('A-REG')::uuid, tstzrange(now(), now() + interval '2 days'))$q$, 'two delegations of one approver at once');
INSERT INTO pr SELECT 'D', wf.submit('PURCHASE_REQUEST', pg_temp.u('HR-S1'), pg_temp.u('A-EVE'), 'Printer toner', 500, NULL, NULL, ARRAY[pg_temp.u('A-VC')]);
SELECT pg_temp.ok(wf.can_act(pg_temp.u('A-TM'), pg_temp.pri('D')) AND EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-TM')) WHERE instance_id = pg_temp.pri('D')),
  'the delegate sees the absent manager''s pending approvals');
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id, on_behalf_of_account_id)
  VALUES (pg_temp.pri('D'), 1, ref.id_of('wf_action_type','APPROVE'), md5('A-FRANK')::uuid, md5('A-BOB')::uuid)$q$, 'acting on behalf of an approver without a delegation');
SELECT wf.act(pg_temp.pri('D'), 'APPROVE', pg_temp.u('A-TM'));
SELECT pg_temp.ok((SELECT actor_account_id = pg_temp.u('A-TM') AND on_behalf_of_account_id = pg_temp.u('A-BOB') FROM wf.approval_action WHERE instance_id = pg_temp.pri('D') AND step_seq = 1),
  'the action records both the delegate and the approver he acted for');

-- E. consultation: an approver asks someone outside the chain; it never blocks
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_consultation (instance_id, asked_by_account_id, asked_account_id, question) VALUES (pg_temp.pri('D'), md5('A-FRANK')::uuid, md5('A-DAC')::uuid, 'x')$q$, 'a consultation by someone who is neither the requester nor a current approver');
INSERT INTO wf.approval_consultation (id, instance_id, asked_by_account_id, asked_account_id, question)
VALUES (pg_temp.u('CONS-1'), pg_temp.pri('D'), pg_temp.u('A-REG'), pg_temp.u('A-DAC'), 'Is toner on the rate contract?');
SELECT pg_temp.ok(wf.can_view(pg_temp.u('A-DAC'), pg_temp.pri('D')) AND wf.can_view(pg_temp.u('A-EVE'), pg_temp.pri('D')) AND NOT wf.can_view(pg_temp.u('A-CAROL'), pg_temp.pri('D')),
  'visibility: the requester, the people involved and the person consulted — not a stranger');
SET LOCAL app.account_id = 'ff000000-0000-0000-0000-000000000001';
SELECT pg_temp.rejects($q$UPDATE wf.approval_consultation SET reply = 'yes', replied_at = now() WHERE id = md5('CONS-1')::uuid$q$, 'a reply by someone other than the person asked');
SELECT set_config('app.account_id', pg_temp.u('A-DAC')::text, true);
UPDATE wf.approval_consultation SET reply = 'Yes, item 14', replied_at = now() WHERE id = pg_temp.u('CONS-1');
SELECT pg_temp.rejects($q$UPDATE wf.approval_consultation SET reply = 'changed' WHERE id = md5('CONS-1')::uuid$q$, 'changing a reply');
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('D')) = 'IN_PROGRESS@UNIT_HEAD', 'the consultation did not hold the round up');

-- F. deadlines: escalation one level up, then automatic approval; automatic rejection
SELECT pg_temp.rejects($q$SELECT * FROM wf.run_timeouts()$q$, 'the timeout job outside a system job');
INSERT INTO pr SELECT 'F', wf.submit('QUICK_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Urgent note');
INSERT INTO pr SELECT 'G', wf.submit('QUICK_REJECT', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Lapses if ignored');
SELECT pg_temp.ok(wf.is_eligible(pg_temp.u('A-ALICE'), pg_temp.pri('F'), 1::smallint) AND (SELECT is_overdue FROM wf.v_instance_state WHERE instance_id = pg_temp.pri('F')),
  'the unit-head level starts at the department (its head can act) and is overdue at once (1 µs deadline)');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE wt AS SELECT * FROM wf.run_timeouts();
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok((SELECT escalated >= 1 AND auto_rejected = 1 FROM wt)
              AND wf.step_anchor(pg_temp.pri('F'), 1::smallint) = pg_temp.u('SET')
              AND NOT wf.is_eligible(pg_temp.u('A-ALICE'), pg_temp.pri('F'), 1::smallint) AND wf.is_eligible(pg_temp.u('A-DEAN'), pg_temp.pri('F'), 1::smallint)
              AND pg_temp.st(pg_temp.pri('G')) = 'REJECTED',
  'the job escalates the overdue level one org level up (department → school: now the Dean''s) and rejects the note configured to lapse');
SELECT wf.act(pg_temp.pri('F'), 'APPROVE', pg_temp.u('A-DEAN'));
SET LOCAL app.system_job = 'on';
SELECT pg_temp.ok((SELECT auto_approved = 1 FROM wf.run_timeouts()), 'the next overdue level is approved automatically, as configured');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('F')) = 'APPROVED'
              AND EXISTS (SELECT 1 FROM wf.approval_action a JOIN ref.wf_action_type t ON t.id = a.wf_action_type_id AND t.code = 'AUTO_APPROVE'
                          WHERE a.instance_id = pg_temp.pri('F') AND a.actor_account_id IS NULL), 'approved by the system action, with no actor');

-- G. no level applies: approved on submission where the document type allows it
INSERT INTO pr SELECT 'H', wf.submit('SMALL_CLAIM', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Taxi fare', 450);
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('H')) = 'APPROVED' AND (SELECT is_complete FROM wf.v_instance_state WHERE instance_id = pg_temp.pri('H'))
              AND pg_temp.steps(pg_temp.pri('H')) IS NULL, 'a claim below the threshold has no level and is approved at once (auto-approval by configuration)');
INSERT INTO pr SELECT 'H2', wf.submit('SMALL_CLAIM', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Conference fee', 4500);
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('H2')) = 'IN_PROGRESS@REGISTRAR', 'the same claim above the threshold goes to the Registrar');

-- H. the existing document types sit on the same engine, and one inbox reaches any module's document
SELECT pg_temp.ok((SELECT link_table = 'facility.booking_request' AND document_id IS NOT NULL
                   FROM wf.document_of(pg_temp.grp_instance((SELECT g FROM bk WHERE k = 'B-GRP')))),
  'the round of a room booking points at its document through the registry');
SELECT pg_temp.ok((SELECT count(*) = 9 FROM wf.approval_document_type WHERE link_table IS NOT NULL
                   AND code IN ('CURRICULUM','INTERNAL_MARKS_REVISION','ATTENDANCE_LEAVE','ROOM_BOOKING','ROOM_BOOKING_CHANGE','EVENT_REQUEST','GUEST_STAY','TRIP_REQUEST','TRIP_REQUEST_URGENT')),
  'all nine foundation document types are registered with their documents');
SELECT pg_temp.ok((SELECT count(*) = 6 FROM authz.role_permission rp JOIN authz.role r ON r.id = rp.role_id JOIN authz.v_permission_code pc ON pc.permission_id = rp.permission_id
                   WHERE (r.code, pc.code::text) IN (('WORKFLOW_ADMIN','core_admin.approval_chain.update'), ('WORKFLOW_ADMIN','core_admin.approval_delegation.assign'),
                                                     ('CORE_ADMIN','core_admin.lookup.view'), ('CORE_ADMIN','core_admin.lookup.update'),
                                                     ('DPO','privacy.purpose.view'), ('DPO','privacy.purpose.update'))),
  'configuration has an owner: chains and delegations (workflow administrator), reference lists (core administrator), purposes and retention (DPO)');

-- I. a higher level approves out of turn: the lower pending levels are passed
-- over, but never leaving fewer than the chain's minimum of approved levels.
-- HOD → Dean → Registrar, all configuration (override is the default for a chain).
INSERT INTO wf.approval_document_type (id, code, label, app_module_id, author_permission_id)
SELECT 9005, 'TOUR_NOTE', 'Tour note: HOD, Dean, Registrar (test)', m.id, pc.permission_id
FROM authz.app_module m, authz.v_permission_code pc WHERE m.code = 'core_admin' AND pc.code = 'self_service.profile.view';
INSERT INTO wf.approval_chain (id, document_type_id, valid) VALUES (9105, 9005, daterange('2000-01-01', NULL));
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, anchor_is_owner)
SELECT 9105, 1, 'HOD', 'Head of department', pg_temp.lk('wf_approver_kind','POSITION'), id, true FROM org.position_type WHERE code = 'HEAD';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, anchor_org_unit_type_id)
SELECT 9105, 2, 'DEAN', 'Dean of the school', pg_temp.lk('wf_approver_kind','POSITION'), id, pg_temp.lk('org_unit_type','SCHOOL') FROM org.position_type WHERE code = 'DEAN';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id)
SELECT 9105, 3, 'REGISTRAR', 'Registrar', pg_temp.lk('wf_approver_kind','POSITION'), id FROM org.position_type WHERE code = 'REGISTRAR';
SELECT pg_temp.ok((SELECT allows_level_override AND min_approved_levels = 2 FROM wf.approval_chain WHERE id = 9105),
  'a chain lets a higher level pass the lower ones over, with at least 2 approved levels, unless configured otherwise');
SELECT pg_temp.rejects($q$UPDATE wf.approval_chain SET min_approved_levels = 0 WHERE id = 9105$q$, 'a chain that needs no approved level at all');

INSERT INTO pr SELECT 'I1', wf.submit('TOUR_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Conference in Pune');
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('I1')) = 'IN_PROGRESS@HOD'
              AND NOT wf.can_act(pg_temp.u('A-DEAN'), pg_temp.pri('I1'))
              AND NOT EXISTS (SELECT 1 FROM wf.pending_for(pg_temp.u('A-DEAN')) WHERE instance_id = pg_temp.pri('I1'))
              AND wf.override_step(pg_temp.u('A-DEAN'), pg_temp.pri('I1')) = 2
              AND EXISTS (SELECT 1 FROM wf.overridable_for(pg_temp.u('A-DEAN')) WHERE instance_id = pg_temp.pri('I1') AND current_step = 'HOD' AND override_step = 'DEAN'),
  'waiting at the HOD: it is not in the Dean''s inbox, but in his "waiting below me" list — he may decide his own level out of turn');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('I1'), 'REJECT', md5('A-DEAN')::uuid, 'no')$q$, 'a higher level rejecting out of turn (only an approval passes levels over)');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('I1'), 'APPROVE', md5('A-REG')::uuid)$q$, 'the Registrar passing over both lower levels (one approved level would remain, two are required)');
SELECT pg_temp.ok(wf.override_step(pg_temp.u('A-REG'), pg_temp.pri('I1')) IS NULL AND wf.override_refusal(pg_temp.pri('I1'), 3::smallint) ~ 'at least 2',
  'the minimum is checked before the action: the Registrar is not offered the round yet');
SELECT wf.act(pg_temp.pri('I1'), 'APPROVE', pg_temp.u('A-DEAN'), 'Approved; the HOD is on leave');
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('I1')) = 'IN_PROGRESS@REGISTRAR'
              AND (SELECT superseded AND NOT done FROM wf.v_step_state WHERE instance_id = pg_temp.pri('I1') AND seq = 1)
              AND (SELECT done AND NOT superseded FROM wf.v_step_state WHERE instance_id = pg_temp.pri('I1') AND seq = 2)
              AND (SELECT step_seq = 2 FROM wf.approval_action WHERE instance_id = pg_temp.pri('I1') ORDER BY id DESC LIMIT 1)
              AND EXISTS (SELECT 1 FROM wf.approval_notice n JOIN ref.wf_notice_kind k ON k.id = n.wf_notice_kind_id AND k.code = 'SUPERSEDED'
                          WHERE n.instance_id = pg_temp.pri('I1') AND n.step_seq = 1),
  'the Dean''s approval is recorded on the Dean''s level; the HOD''s level is passed over (derived, and the HOD is told); the Registrar is next');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('I1'), 'APPROVE', md5('A-ALICE')::uuid)$q$, 'the HOD approving after a higher level has decided');
SELECT wf.act(pg_temp.pri('I1'), 'APPROVE', pg_temp.u('A-REG'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('I1')) = 'APPROVED'
              AND (SELECT count(*) FILTER (WHERE done) = 2 AND count(*) FILTER (WHERE superseded) = 1 FROM wf.v_step_state WHERE instance_id = pg_temp.pri('I1')),
  'approved with two levels decided (Dean, Registrar) and one passed over — never fewer than two');
-- the minimum again: after the HOD, the Registrar may pass the Dean over
INSERT INTO pr SELECT 'I2', wf.submit('TOUR_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Workshop in Delhi');
SELECT wf.act(pg_temp.pri('I2'), 'APPROVE', pg_temp.u('A-ALICE'));
SELECT wf.act(pg_temp.pri('I2'), 'APPROVE', pg_temp.u('A-REG'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('I2')) = 'APPROVED' AND (SELECT superseded FROM wf.v_step_state WHERE instance_id = pg_temp.pri('I2') AND seq = 2),
  'with the HOD''s approval already there, the Registrar''s makes two: the Dean''s level is passed over');
-- a level that must always decide itself
UPDATE wf.approval_chain_stage SET is_mandatory = true WHERE chain_id = 9105 AND seq = 1;
INSERT INTO pr SELECT 'I3', wf.submit('TOUR_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Field visit');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('I3'), 'APPROVE', md5('A-DEAN')::uuid)$q$, 'passing over a level marked mandatory');
SELECT pg_temp.ok(wf.override_refusal(pg_temp.pri('I3'), 2::smallint) ~ 'HOD must decide itself', 'the refusal names the level that cannot be passed over');
UPDATE wf.approval_chain_stage SET is_mandatory = false WHERE chain_id = 9105 AND seq = 1;
-- switching it off for a chain; a round in flight keeps the setting it was submitted under
INSERT INTO pr SELECT 'I4', wf.submit('TOUR_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'Before the switch');
UPDATE wf.approval_chain SET allows_level_override = false WHERE id = 9105;
INSERT INTO pr SELECT 'I5', wf.submit('TOUR_NOTE', pg_temp.u('CSE'), pg_temp.u('A-FRANK'), 'After the switch');
SELECT pg_temp.rejects($q$SELECT wf.act(pg_temp.pri('I5'), 'APPROVE', md5('A-DEAN')::uuid)$q$, 'a higher level approving out of turn on a chain that takes its levels strictly in order');
SELECT wf.act(pg_temp.pri('I4'), 'APPROVE', pg_temp.u('A-DEAN'));
SELECT pg_temp.ok(pg_temp.st(pg_temp.pri('I4')) = 'IN_PROGRESS@REGISTRAR' AND pg_temp.st(pg_temp.pri('I5')) = 'IN_PROGRESS@HOD',
  'the round submitted before the switch still follows the old setting (a snapshot); the new one waits for the HOD');

-- decisions of 2026-10-01: statutory academic chains go strictly in order, operational ones may be passed over by a higher level
SELECT pg_temp.ok((SELECT bool_and(NOT c.allows_level_override) FROM wf.approval_chain c JOIN wf.approval_document_type t ON t.id = c.document_type_id
                    WHERE t.code IN ('CURRICULUM', 'INTERNAL_MARKS_REVISION') AND c.scope_org_unit_id IS NULL)
              AND (SELECT bool_and(c.allows_level_override) FROM wf.approval_chain c JOIN wf.approval_document_type t ON t.id = c.document_type_id
                    WHERE t.code IN ('ROOM_BOOKING', 'EVENT_REQUEST', 'GUEST_STAY', 'TRIP_REQUEST') AND c.scope_org_unit_id IS NULL)
              AND (SELECT count(*) = 2 FROM privacy.data_element WHERE schema_name = 'facility' AND table_name = 'vendor' AND column_name IN ('name', 'gstin')),
  'curriculum and marks revision take every level in order; bookings, events, stays and trips keep the higher-level override; a vendor''s name and GSTIN are in the privacy inventory');
-- audit of 2026-10-01: a round cannot name a chain of another document type; remarks about people are in the inventory and out of reporting
SELECT pg_temp.rejects($q$INSERT INTO wf.approval_instance (document_type_id, chain_id, owner_org_unit_id, submitted_by_account_id) VALUES (9002, 9101, md5('CSE')::uuid, md5('A-FRANK')::uuid)$q$,
  'a round whose document type is not its chain''s');
SELECT pg_temp.ok((SELECT count(*) = 16 FROM privacy.data_element WHERE (schema_name, table_name, column_name) IN (
                     ('academic','faculty_unavailability','reason'), ('academic','faculty_course_preference','remarks'), ('academic','credit_overload_approval','reason'),
                     ('exam','certificate','cancel_reason'), ('exam','script_mark','note'), ('research','viva','remarks'),
                     ('privacy','data_principal_request','details'), ('privacy','dpr_request_event','note'), ('privacy','breach_incident','description'),
                     ('wf','approval_instance','note'), ('wf','approval_action','note'), ('wf','approval_comment','body'), ('wf','approval_comment','suggested_value'),
                     ('authz','account_role','reason'), ('authz','account_permission','reason'), ('iam','user_device','name')))
              AND NOT has_table_privilege('intranet_analytics', 'exam.attendance_condonation', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'academic.faculty_unavailability', 'SELECT') AND NOT has_table_privilege('intranet_analytics', 'academic.faculty_course_preference', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'wf.approval_delegation', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'facility.booking_request', 'SELECT')
              AND has_table_privilege('intranet_analytics', 'facility.v_booking_summary', 'SELECT'),
  'free text about people is registered in the privacy inventory, and the tables that carry it are closed to the reporting role (which keeps the summaries)');

-- ================================================================= audit =====
SET LOCAL app.account_id = 'ff000000-0000-0000-0000-000000000001';
UPDATE people.person SET first_name = 'Alicia' WHERE id = pg_temp.u('ALICE');
SELECT pg_temp.ok((SELECT c.old_value = '[REDACTED]' AND c.new_value = '[REDACTED]' AND e.actor_account_id = 'ff000000-0000-0000-0000-000000000001'
                   FROM audit.audit_event e JOIN audit.audit_change c ON c.audit_event_id = e.id AND c.occurred_at = e.occurred_at
                   WHERE e.entity_table = 'person' AND e.entity_id = pg_temp.u('ALICE')::text AND c.column_name = 'first_name'
                   ORDER BY e.id DESC LIMIT 1),
  'audit captures actor; personal data redacted');
UPDATE people.employee SET grade_id = pg_temp.lk('grade','O3') WHERE id = pg_temp.u('E-ALICE');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM audit.audit_change WHERE column_name = 'grade_id' AND new_value = pg_temp.lk('grade','O3')::text),
  'audit keeps non-personal values in clear');
SELECT pg_temp.rejects($q$UPDATE audit.audit_event SET entity_table = 'x'$q$, 'audit_event is append-only');
SELECT pg_temp.rejects($q$DELETE FROM audit.audit_change$q$, 'audit_change is append-only');

\echo '>>> ALL SMOKE TESTS PASSED'
ROLLBACK;
