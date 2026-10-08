-- =============================================================================
-- 97_events_smoke_test.sql — Events & clubs (sql/13_events.sql): scenario +
-- negative tests. Self-contained (own org units, people, accounts, rooms);
-- runs in a transaction that is ROLLED BACK.
--   psql -v ON_ERROR_STOP=1 -f sql/97_events_smoke_test.sql
-- Every check prints PASS; the first failure aborts with "FAIL: ...".
-- One event ("Q") really happens during the test: it starts a few seconds
-- after it is approved, so the script sleeps about ten seconds in total.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

\set QUIET on
BEGIN;
SET LOCAL client_min_messages = notice;

CREATE FUNCTION pg_temp.u(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5(k)::uuid $$;
CREATE FUNCTION pg_temp.ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF COALESCE(c, false) THEN RAISE NOTICE 'PASS  %', msg; ELSE RAISE EXCEPTION 'FAIL: %', msg; END IF;
END $$;
CREATE FUNCTION pg_temp.rejects(q text, msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE q;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'PASS  rejected: % (%)', msg, left(SQLERRM, 100);
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL: expected rejection: %', msg;
END $$;
CREATE FUNCTION pg_temp.lk(t text, c text) RETURNS int LANGUAGE sql STABLE AS $$ SELECT ref.id_of(t, c) $$;
CREATE FUNCTION pg_temp.emp(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('E-' || k)::uuid $$;
CREATE FUNCTION pg_temp.acct(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('A-' || k)::uuid $$;
CREATE FUNCTION pg_temp.stu(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('S-' || k)::uuid $$;
CREATE FUNCTION pg_temp.act(p_instance uuid, p_action text, p_actor text, p_note text DEFAULT NULL) RETURNS bigint LANGUAGE sql AS $$
  SELECT wf.act(p_instance, p_action, md5('A-' || p_actor)::uuid, p_note) $$;
CREATE FUNCTION pg_temp.steps(p uuid) RETURNS text LANGUAGE sql STABLE AS $$ SELECT string_agg(code, ',' ORDER BY seq) FROM wf.approval_step WHERE instance_id = p $$;

-- ================================================================ fixtures ==
INSERT INTO org.org_unit (id, org_unit_type_id, parent_id, code, name) VALUES
 (pg_temp.u('V-SGTU'), pg_temp.lk('org_unit_type','UNIVERSITY'),         NULL,                'V-SGTU', 'SGT University'),
 (pg_temp.u('V-SA'),   pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('V-SGTU'), 'V-SA',   'Student Affairs'),
 (pg_temp.u('V-SET'),  pg_temp.lk('org_unit_type','SCHOOL'),             pg_temp.u('V-SGTU'), 'V-SET',  'School of Engineering'),
 (pg_temp.u('V-CSE'),  pg_temp.lk('org_unit_type','DEPARTMENT'),         pg_temp.u('V-SET'),  'V-CSE',  'Computer Science'),
 (pg_temp.u('V-LAB'),  pg_temp.lk('org_unit_type','CENTRE'),             pg_temp.u('V-CSE'),  'V-LAB',  'AI Lab');

-- staff: advisor, co-advisor, HOD, another faculty member, Dean, Registrar, two committee members
INSERT INTO people.person (id, first_name)
SELECT pg_temp.u('P-' || k), k FROM unnest(ARRAY['ADV','COADV','HOD','FAC','DEAN','REG','CCC1','CCC2','S1','S2','S3','S4','S5','S6','GUEST']) k;
INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on)
SELECT pg_temp.emp(k), pg_temp.u('P-' || k), 'EVT-' || k,
       pg_temp.lk('employee_category', CASE WHEN k IN ('CCC1','CCC2','REG') THEN 'NON_TEACHING' ELSE 'TEACHING' END),
       pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2020-01-01'
FROM unnest(ARRAY['ADV','COADV','HOD','FAC','DEAN','REG','CCC1','CCC2']) k;
INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary, valid)
SELECT pg_temp.emp(v.k), pg_temp.u(v.unit), (SELECT id FROM people.designation WHERE code = v.d), true, daterange('2020-01-01', NULL)
FROM (VALUES ('ADV','V-CSE','PROFESSOR'),('COADV','V-CSE','PROFESSOR'),('HOD','V-CSE','PROFESSOR'),('FAC','V-CSE','PROFESSOR'),('DEAN','V-SET','PROFESSOR'),
             ('REG','V-SGTU','HR_EXECUTIVE'),('CCC1','V-SA','HR_EXECUTIVE'),('CCC2','V-SA','HR_EXECUTIVE')) v(k, unit, d);
INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
SELECT pg_temp.u(v.unit), (SELECT id FROM org.position_type WHERE code = v.pos), pg_temp.emp(v.who), daterange('2020-01-01', NULL)
FROM (VALUES ('V-CSE','HEAD','HOD'),('V-SET','DEAN','DEAN'),('V-SGTU','REGISTRAR','REG')) v(unit, pos, who);
-- students, enrolled in B.Tech CSE
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on)
SELECT pg_temp.stu(k), pg_temp.u('P-' || k), 'EVT-' || k, pg_temp.lk('student_status','ACTIVE'), current_date - 60 FROM unnest(ARRAY['S1','S2','S3','S4','S5','S6']) k;
INSERT INTO academic.academic_year (id, code, period) VALUES (pg_temp.u('VY'), '2026-27', daterange(current_date - 90, current_date + 270));
INSERT INTO academic.academic_term (id, academic_year_id, term_cycle_id, period)
VALUES (pg_temp.u('VT'), pg_temp.u('VY'), pg_temp.lk('term_cycle','ODD'), daterange(current_date - 75, current_date + 90));
INSERT INTO academic.program (id, code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id, delivery_mode_id, duration_terms)
VALUES (pg_temp.u('VP'), 'V-BTECH', 'B.Tech CSE (events test)', pg_temp.lk('program_level','UG'), pg_temp.lk('academic_calendar_type','SEMESTER'),
        pg_temp.u('V-CSE'), pg_temp.lk('delivery_mode','REGULAR'), 8);
INSERT INTO academic.batch (id, program_id, admission_year_id) VALUES (pg_temp.u('VB'), pg_temp.u('VP'), pg_temp.u('VY'));
INSERT INTO academic.student_enrollment (student_id, batch_id, valid)
SELECT pg_temp.stu(k), pg_temp.u('VB'), daterange(current_date - 60, NULL) FROM unnest(ARRAY['S1','S2','S3','S4','S5','S6']) k;
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id)
SELECT pg_temp.acct(k), pg_temp.u('P-' || k), 'evt.' || lower(k), '!', pg_temp.lk('account_status','ACTIVE')
FROM unnest(ARRAY['ADV','COADV','HOD','FAC','DEAN','REG','CCC1','CCC2','S1','S2','S3','S4','S5','S6']) k;
INSERT INTO authz.account_role (account_id, role_id, reason)
SELECT pg_temp.acct(k), (SELECT id FROM authz.role WHERE code = 'EVENT_CCC_MEMBER'), 'Central coordination committee' FROM unnest(ARRAY['CCC1','CCC2']) k;
-- a venue in the department's custody
INSERT INTO org.campus (id, code, name) VALUES (pg_temp.u('V-CAMPUS'), 'V-MAIN', 'Main campus (events test)');
INSERT INTO org.building (id, campus_id, code, name, building_kind_id) VALUES (pg_temp.u('V-BLDG'), pg_temp.u('V-CAMPUS'), 'VA', 'Block VA', pg_temp.lk('building_kind','BUILDING'));
INSERT INTO org.room (id, building_id, code, name, room_type_id, room_use_id, capacity)
VALUES (pg_temp.u('V-AUD'), pg_temp.u('V-BLDG'), 'VA-AUD', 'Auditorium', pg_temp.lk('room_type','AUDITORIUM'), pg_temp.lk('room_use','ASSEMBLY'), 300);
INSERT INTO facility.custody (building_id, org_unit_id, valid) VALUES (pg_temp.u('V-BLDG'), pg_temp.u('V-CSE'), daterange('2020-01-01', NULL));
INSERT INTO people.file_object (id, storage_backend_id, object_key, mime_type, byte_size, sha256)
VALUES (pg_temp.u('F-REPORT'), pg_temp.lk('storage_backend','S3'), 'events/report.pdf', 'application/pdf', 2048, digest('report', 'sha256'));

SELECT pg_temp.ok(authz.has_permission(pg_temp.acct('S1'), 'events.proposal.create') AND authz.has_permission(pg_temp.acct('S1'), 'events.registration.create'),
  'baseline rights: every student proposes events and registers');
SELECT pg_temp.ok(authz.has_permission(pg_temp.acct('ADV'), 'events.club_proposal.create', pg_temp.u('V-CSE'))
              AND NOT authz.has_permission(pg_temp.acct('S1'), 'events.club_proposal.create', pg_temp.u('V-CSE')), 'faculty (not students) propose clubs');
SELECT pg_temp.ok(authz.has_permission(pg_temp.acct('CCC1'), 'events.proposal.approve', pg_temp.u('V-SGTU')), 'the committee members hold the approval permission at the university');

-- ================================================================== clubs ====
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal (proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id)
  VALUES (md5('A-ADV')::uuid, md5('V-CSE')::uuid, 'Coding Club', 'Too short', md5('E-ADV')::uuid)$q$, 'a club objective of a few words');
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal (proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id)
  VALUES (md5('A-ADV')::uuid, md5('V-LAB')::uuid, 'Coding Club', repeat('To build a culture of programming. ', 3), md5('E-ADV')::uuid)$q$, 'a club under a unit that cannot have clubs (a centre)');
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal (proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id)
  VALUES (md5('A-ADV')::uuid, md5('V-CSE')::uuid, 'Coding Club', repeat('To build a culture of programming. ', 3), md5('E-CCC1')::uuid)$q$, 'an advisor who is not faculty');
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal (proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id, co_advisor_employee_id)
  VALUES (md5('A-ADV')::uuid, md5('V-CSE')::uuid, 'Coding Club', repeat('To build a culture of programming. ', 3), md5('E-ADV')::uuid, md5('E-ADV')::uuid)$q$, 'the advisor as her own co-advisor');
INSERT INTO events.club_proposal (id, proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id, co_advisor_employee_id, club_category_id)
VALUES (pg_temp.u('CP'), pg_temp.acct('ADV'), pg_temp.u('V-CSE'), 'Coding Club', repeat('To build a culture of programming. ', 3), pg_temp.emp('ADV'), pg_temp.emp('COADV'),
        pg_temp.lk('club_category','TECHNICAL'));
SELECT pg_temp.ok((SELECT proposal_code ~ '^CP-[0-9]{4}-[0-9]{3}$' FROM events.club_proposal WHERE id = pg_temp.u('CP')), 'a club proposal gets its CP-YYYY-NNN code');
SELECT pg_temp.rejects($q$SELECT events.submit_club_proposal(md5('CP')::uuid, md5('A-ADV')::uuid)$q$, 'submitting a club proposal without a president');
INSERT INTO events.club_proposal_officer (club_proposal_id, club_office_id, student_id) VALUES
 (pg_temp.u('CP'), pg_temp.lk('club_office','PRESIDENT'), pg_temp.stu('S1')), (pg_temp.u('CP'), pg_temp.lk('club_office','SECRETARY'), pg_temp.stu('S2'));
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal_officer (club_proposal_id, club_office_id, student_id) VALUES (md5('CP')::uuid, ref.id_of('club_office','CREATIVE_HEAD'), md5('S-S1')::uuid)$q$, 'one student in two offices');
INSERT INTO events.club_proposal_member (club_proposal_id, student_id) VALUES (pg_temp.u('CP'), pg_temp.stu('S3'));
SELECT pg_temp.rejects($q$SELECT events.submit_club_proposal(md5('CP')::uuid, md5('A-FAC')::uuid)$q$, 'submitting someone else''s draft');
SELECT events.submit_club_proposal(pg_temp.u('CP'), pg_temp.acct('ADV'));
CREATE FUNCTION pg_temp.cp_round() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT instance_id FROM events.club_proposal WHERE id = md5('CP')::uuid $$;
SELECT pg_temp.ok(pg_temp.steps(pg_temp.cp_round()) = 'CCC' AND (SELECT current_due_at IS NOT NULL FROM wf.v_instance_state WHERE instance_id = pg_temp.cp_round())
              AND (SELECT link_table = 'events.club_proposal' AND document_id = pg_temp.u('CP') FROM wf.document_of(pg_temp.cp_round())),
  'the club proposal is a CLUB_PROPOSAL round (one committee level, with a deadline) pointing at its document — configuration only');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM wf.approval_instance_flag f JOIN ref.wf_flag w ON w.id = f.wf_flag_id AND w.code = 'CLUBCAT_TECHNICAL' WHERE f.instance_id = pg_temp.cp_round()),
  'the round carries the kind of club as a flag (CLUBCAT_TECHNICAL), so a chain can route sports, cultural or technical clubs differently');
SELECT pg_temp.rejects($q$INSERT INTO events.club_proposal_member (club_proposal_id, student_id) VALUES (md5('CP')::uuid, md5('S-S4')::uuid)$q$, 'changing a submitted proposal''s members');
SELECT pg_temp.rejects($q$UPDATE events.club_proposal SET club_name = 'Hack Club' WHERE id = md5('CP')::uuid$q$, 'editing a submitted club proposal');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.cp_round(), 'APPROVE', 'HOD')$q$, 'approval by someone outside the committee');
SELECT pg_temp.act(pg_temp.cp_round(), 'APPROVE', 'CCC1');
CREATE FUNCTION pg_temp.club() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT club_org_unit_id FROM events.club_proposal WHERE id = md5('CP')::uuid $$;
SELECT pg_temp.ok((SELECT status = 'ACTIVE' AND club_code ~ '^CLB-[0-9]{4}-[0-9]{5}$' AND parent_org_unit_id = pg_temp.u('V-CSE') AND members = 3
                          AND club_category = 'TECHNICAL' AND parent_unit_type = 'DEPARTMENT'
                          AND advisor_employee_id = pg_temp.emp('ADV') AND co_advisor_employee_id = pg_temp.emp('COADV') FROM events.v_club WHERE club_org_unit_id = pg_temp.club())
              AND (SELECT string_agg(office, ',' ORDER BY office) = 'PRESIDENT,SECRETARY' FROM events.v_club_officer_current WHERE club_org_unit_id = pg_temp.club())
              AND (SELECT t.code = 'CLUB' FROM org.org_unit u JOIN ref.org_unit_type t ON t.id = u.org_unit_type_id WHERE u.id = pg_temp.club()),
  'approval creates the club: an org unit of type CLUB under the department, advisor appointments, two officers, three members');
SELECT pg_temp.ok(authz.has_permission(pg_temp.acct('ADV'), 'events.proposal.review', pg_temp.club()) AND NOT authz.has_permission(pg_temp.acct('FAC'), 'events.proposal.review', pg_temp.club())
              AND events.is_club_officer(pg_temp.acct('S1'), pg_temp.club()) AND events.is_club_officer(pg_temp.acct('COADV'), pg_temp.club())
              AND NOT events.is_club_officer(pg_temp.acct('S3'), pg_temp.club()),
  'the advisor''s rights come from the appointment on the club; officers are the dated student posts');
SELECT pg_temp.rejects($q$INSERT INTO events.club_officer (club_org_unit_id, club_office_id, student_id) VALUES (pg_temp.club(), ref.id_of('club_office','PRESIDENT'), md5('S-S4')::uuid)$q$, 'a second president');
SELECT pg_temp.rejects($q$INSERT INTO events.club_officer (club_org_unit_id, club_office_id, student_id) VALUES (pg_temp.club(), ref.id_of('club_office','CREATIVE_HEAD'), md5('S-S2')::uuid)$q$, 'the secretary taking a second office');
SELECT pg_temp.rejects($q$INSERT INTO events.club (org_unit_id, objective, club_category_id) VALUES (md5('V-CSE')::uuid, 'x', ref.id_of('club_category','ACADEMIC'))$q$, 'a club on a unit that is not of type CLUB');
-- applications
INSERT INTO events.club_application (id, club_org_unit_id, student_id, note) VALUES (pg_temp.u('APP-4'), pg_temp.club(), pg_temp.stu('S4'), 'I build web apps');
SELECT pg_temp.rejects($q$INSERT INTO events.club_application (club_org_unit_id, student_id) VALUES (pg_temp.club(), md5('S-S4')::uuid)$q$, 'a second open application');
SELECT pg_temp.rejects($q$INSERT INTO events.club_application (club_org_unit_id, student_id) VALUES (pg_temp.club(), md5('S-S3')::uuid)$q$, 'an application by someone who is already a member');
SELECT pg_temp.rejects($q$UPDATE events.club_application SET decided_at = now(), decided_by_account_id = md5('A-S5')::uuid, is_approved = true WHERE id = md5('APP-4')::uuid$q$, 'an application decided by a student who holds no office');
UPDATE events.club_application SET decided_at = now(), decided_by_account_id = pg_temp.acct('ADV'), is_approved = true WHERE id = pg_temp.u('APP-4');
SELECT pg_temp.ok((SELECT members = 4 FROM events.v_club WHERE club_org_unit_id = pg_temp.club())
              AND EXISTS (SELECT 1 FROM events.club_member m JOIN ref.club_member_role r ON r.id = m.club_member_role_id AND r.code = 'VOLUNTEER'
                          WHERE m.club_org_unit_id = pg_temp.club() AND m.student_id = pg_temp.stu('S4')), 'an approved application becomes a membership');
SELECT pg_temp.rejects($q$UPDATE events.club_application SET decision_note = 'changed' WHERE id = md5('APP-4')::uuid$q$, 'changing a decided application');
-- suspension
INSERT INTO events.club_suspension (id, club_org_unit_id, during, reason, imposed_by_account_id)
VALUES (pg_temp.u('SUSP'), pg_temp.club(), tstzrange(now() - interval '1 minute', NULL), 'Unreported event', pg_temp.acct('CCC1'));
SELECT pg_temp.ok((SELECT status = 'SUSPENDED' FROM events.v_club WHERE club_org_unit_id = pg_temp.club()) AND NOT events.club_is_active(pg_temp.club()), 'a suspension makes the club SUSPENDED (derived)');
SELECT pg_temp.rejects($q$INSERT INTO events.club_member (club_org_unit_id, student_id, club_member_role_id) VALUES (pg_temp.club(), md5('S-S5')::uuid, ref.id_of('club_member_role','MEMBER'))$q$, 'a new member of a suspended club');
UPDATE events.club_suspension SET during = tstzrange(lower(during), now() - interval '1 second') WHERE id = pg_temp.u('SUSP');
SELECT pg_temp.ok((SELECT status = 'ACTIVE' FROM events.v_club WHERE club_org_unit_id = pg_temp.club()), 'when the suspension ends the club is ACTIVE again');

-- ======================================================== event proposal A ===
-- a future hackathon of the club, proposed by its president, with a room
CREATE FUNCTION pg_temp.day() RETURNS date LANGUAGE sql STABLE AS $$ SELECT current_date + 20 $$;
CREATE FUNCTION pg_temp.draft(k text, unit uuid, who text, typ text, ttl text, dur tsrange, part text DEFAULT 'INDIVIDUAL', mn int DEFAULT NULL, mx int DEFAULT NULL,
                              cap int DEFAULT 100, fixed int DEFAULT NULL, passes int DEFAULT 0, certs boolean DEFAULT false, leave text DEFAULT NULL, revises uuid DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO events.event_proposal (id, organising_org_unit_id, proposed_by_account_id, event_type_id, title, during, event_level_id, event_mode_id, theme, objective,
                                     participation_type_id, min_team_size, max_team_size, approx_capacity, capacity_fixed, allow_extra_passes, max_extra_passes,
                                     gives_certificates, duty_leave_scope_id, revises_proposal_id)
  VALUES (md5(k)::uuid, unit, md5('A-' || who)::uuid, ref.id_of('event_type', typ), ttl, dur, ref.id_of('event_level', 'LEVEL_2'), ref.id_of('event_mode', 'OFFLINE'),
          'Innovation', 'Hands-on problem solving', ref.id_of('participation_type', part), mn, mx, cap, fixed, passes > 0, passes, certs,
          CASE WHEN leave IS NOT NULL THEN ref.id_of('duty_leave_scope', leave) END, revises) $$;
CREATE FUNCTION pg_temp.parts(k text, coordinator text, cost numeric DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO events.proposal_audience (event_proposal_id, event_audience_kind_id) VALUES (md5(k)::uuid, ref.id_of('event_audience_kind', 'STUDENTS'));
  INSERT INTO events.proposal_sdg (event_proposal_id, sdg_no) VALUES (md5(k)::uuid, 4);
  INSERT INTO events.proposal_coordinator (event_proposal_id, person_id, coordinator_role) VALUES (md5(k)::uuid, md5('P-' || coordinator)::uuid, 'Faculty coordinator');
  IF cost IS NOT NULL THEN
    INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost, quantity)
    VALUES (md5(k)::uuid, ref.id_of('budget_item_type', 'REFRESHMENTS'), 'Refreshments', cost, 1);
  END IF;
END $$;
CREATE FUNCTION pg_temp.round_of(k text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT instance_id FROM events.event_proposal WHERE id = md5(k)::uuid $$;
CREATE FUNCTION pg_temp.event_of(k text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM events.event WHERE event_proposal_id = md5(k)::uuid $$;

SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'S5', 'HACKATHON', 'x event', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'))$q$, 'an event of the club proposed by a student who holds no office');
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'S1', 'HACKATHON', 'x event', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'), 'INDIVIDUAL', 2, 3)$q$, 'team sizes on an individual event');
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'S1', 'HACKATHON', 'x event', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'), 'TEAM')$q$, 'a team event without team sizes');
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'S1', 'HACKATHON', 'x event', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'), 'INDIVIDUAL', NULL, NULL, 100, 50)$q$, 'a fixed capacity below the expected attendance');
SELECT pg_temp.rejects($q$INSERT INTO events.event_proposal (organising_org_unit_id, proposed_by_account_id, event_type_id, title, during, event_level_id, event_mode_id, theme, objective, participation_type_id, approx_capacity, is_paid)
  VALUES (pg_temp.club(), md5('A-S1')::uuid, ref.id_of('event_type','HACKATHON'), 'paid event', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'), ref.id_of('event_level','LEVEL_2'),
          ref.id_of('event_mode','OFFLINE'), 't', 'o', ref.id_of('participation_type','INDIVIDUAL'), 10, true)$q$, 'a paid event without a fee');
SELECT pg_temp.draft('A', pg_temp.club(), 'S1', 'HACKATHON', 'CodeSprint 2026', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '18:00'));
SELECT pg_temp.rejects($q$SELECT events.submit_proposal(md5('A')::uuid, md5('A-S1')::uuid)$q$, 'submitting without audience, coordinator and SDG');
SELECT pg_temp.parts('A', 'ADV');
INSERT INTO events.proposal_audience (event_proposal_id, event_audience_kind_id) VALUES (pg_temp.u('A'), pg_temp.lk('event_audience_kind','EXTERNAL_GUESTS'));
INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost, quantity) VALUES
 (pg_temp.u('A'), pg_temp.lk('budget_item_type','PRIZES'), 'Prize money', 5000, 2), (pg_temp.u('A'), pg_temp.lk('budget_item_type','PRINTING'), 'Banners', 2500, 1);
INSERT INTO events.proposal_funding (event_proposal_id, funding_source_id, expected_amount) VALUES (pg_temp.u('A'), pg_temp.lk('funding_source','SPONSORSHIP'), 20000);
INSERT INTO events.proposal_prize (id, event_proposal_id, position, title, event_prize_type_id, amount) VALUES (pg_temp.u('PRZ-A'), pg_temp.u('A'), 1, 'Winner', pg_temp.lk('event_prize_type','CASH'), 5000);
INSERT INTO events.proposal_speaker (event_proposal_id, speaker_name, designation, organisation) VALUES (pg_temp.u('A'), 'R. Mehta', 'CTO', 'Acme Labs');
SELECT pg_temp.rejects($q$INSERT INTO events.proposal_speaker (event_proposal_id, person_id, speaker_name) VALUES (md5('A')::uuid, md5('P-FAC')::uuid, 'Also named')$q$, 'a speaker given both as a person and as a name');
INSERT INTO events.proposal_speaker (event_proposal_id, person_id) VALUES (pg_temp.u('A'), pg_temp.u('P-FAC'));
SELECT pg_temp.rejects($q$INSERT INTO events.proposal_speaker (event_proposal_id, person_id) VALUES (md5('A')::uuid, md5('P-FAC')::uuid)$q$, 'the same person listed twice as a speaker of one proposal');
DELETE FROM events.proposal_speaker WHERE event_proposal_id = pg_temp.u('A') AND person_id IS NOT NULL;
INSERT INTO events.proposal_visibility_scope (event_proposal_id, org_unit_id) VALUES (pg_temp.u('A'), pg_temp.u('V-CSE'));
SELECT pg_temp.rejects($q$INSERT INTO events.proposal_visibility_scope (event_proposal_id, org_unit_id) VALUES (md5('A')::uuid, md5('V-CSE')::uuid)$q$, 'the same visibility scope twice on one proposal');
DELETE FROM events.proposal_visibility_scope WHERE event_proposal_id = pg_temp.u('A');
INSERT INTO events.proposal_visibility_role (event_proposal_id, principal_kind_id) VALUES (pg_temp.u('A'), pg_temp.lk('principal_kind','STUDENT'));
INSERT INTO events.event_sponsor (id, name, sponsor_type_id) VALUES (pg_temp.u('SPON'), 'Acme Labs', pg_temp.lk('sponsor_type','CORPORATE'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_sponsorship (event_proposal_id, sponsor_id, contribution_type_id) VALUES (md5('A')::uuid, md5('SPON')::uuid, ref.id_of('contribution_type','CASH'))$q$, 'a cash sponsorship without an amount');
INSERT INTO events.event_sponsorship (id, event_proposal_id, sponsor_id, contribution_type_id, cash_amount)
VALUES (pg_temp.u('SHIP'), pg_temp.u('A'), pg_temp.u('SPON'), pg_temp.lk('contribution_type','CASH'), 20000);
SELECT pg_temp.ok((SELECT status = 'DRAFT' AND budget_total = 12500 AND funding_total = 20000 FROM events.v_proposal_status WHERE event_proposal_id = pg_temp.u('A')),
  'a draft proposal: budget total derived from its lines');
SELECT events.submit_proposal(pg_temp.u('A'), pg_temp.acct('S1'));
SELECT pg_temp.ok(pg_temp.steps(pg_temp.round_of('A')) = 'ADVISOR,CCC'
              AND (SELECT amount = 12500 FROM wf.approval_instance WHERE id = pg_temp.round_of('A'))
              AND (SELECT string_agg(f.code, ',' ORDER BY f.code) = 'CLUBCAT_TECHNICAL,EXTERNAL_GUESTS,SPONSORED' FROM wf.approval_instance_flag i JOIN ref.wf_flag f ON f.id = i.wf_flag_id WHERE i.instance_id = pg_temp.round_of('A'))
              AND (SELECT anchor_org_unit_id = pg_temp.club() FROM wf.approval_step WHERE instance_id = pg_temp.round_of('A') AND seq = 1)
              AND (SELECT e.instance_id = pg_temp.round_of('A') FROM facility.event_request e JOIN events.event_proposal p ON p.facility_event_request_id = e.id WHERE p.id = pg_temp.u('A')),
  'submission: default chain advisor@club → committee; the round carries the budget as amount and the flags; the facility package shares the round');
SELECT pg_temp.rejects($q$UPDATE events.event_proposal SET title = 'Renamed' WHERE id = md5('A')::uuid$q$, 'editing a submitted proposal');
SELECT pg_temp.rejects($q$INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost) VALUES (md5('A')::uuid, ref.id_of('budget_item_type','OTHER'), 'late', 1)$q$, 'adding a budget line after submission');
SELECT pg_temp.draft('A2', pg_temp.club(), 'S1', 'WORKSHOP', 'Second idea', tsrange(pg_temp.day() + 1 + time '09:00', pg_temp.day() + 1 + time '12:00'));
SELECT pg_temp.parts('A2', 'ADV');
SELECT pg_temp.rejects($q$SELECT events.submit_proposal(md5('A2')::uuid, md5('A-S1')::uuid)$q$, 'a second proposal of the club by the same proposer while one is under approval');
-- the venue: requested under the event, held at once, waits for the event's approval
CREATE TEMP TABLE bk AS SELECT facility.request_booking(pg_temp.acct('S1'), 'CULTURAL', 'CodeSprint venue', ARRAY[pg_temp.u('V-AUD')], ARRAY[pg_temp.day()], '09:00', '18:00', 100,
  pg_temp.club(), NULL, false, NULL, (SELECT facility_event_request_id FROM events.event_proposal WHERE id = pg_temp.u('A'))) AS g;
SELECT pg_temp.ok((SELECT status = 'AWAITING_EVENT' FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk))
              AND NOT facility.room_is_free(pg_temp.u('V-AUD'), facility.span(pg_temp.day(), '10:00', '11:00'))
              AND (SELECT room_requests = 1 AND room_requests_approved = 0 FROM events.v_proposal_status WHERE event_proposal_id = pg_temp.u('A')),
  'the auditorium is held from the moment it is asked for; its own approval waits for the event');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.round_of('A'), 'APPROVE', 'S1')$q$, 'the proposer approving his own proposal');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.round_of('A'), 'APPROVE', 'HOD')$q$, 'the advisor level approved by someone who is not the club''s advisor');
SELECT pg_temp.act(pg_temp.round_of('A'), 'APPROVE', 'COADV');          -- advisor or co-advisor, either
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.round_of('A'), 'APPROVE', 'ADV')$q$, 'the committee level approved by the advisor');
SELECT pg_temp.ok(pg_temp.event_of('A') IS NULL, 'no event exists before the final approval');
SELECT pg_temp.act(pg_temp.round_of('A'), 'APPROVE', 'CCC1');
SELECT pg_temp.ok((SELECT status = 'DRAFT' AND event_code ~ '^EVT-[0-9]{4}-[0-9]{4}$' AND title = 'CodeSprint 2026' AND seat_limit IS NULL FROM events.v_event WHERE event_id = pg_temp.event_of('A'))
              AND events.can_manage(pg_temp.acct('S1'), pg_temp.event_of('A')) AND events.can_manage(pg_temp.acct('S2'), pg_temp.event_of('A'))
              AND events.can_manage(pg_temp.acct('ADV'), pg_temp.event_of('A')) AND NOT events.can_manage(pg_temp.acct('S3'), pg_temp.event_of('A'))
              AND (SELECT status = 'PENDING' AND custodian_org_unit_id = pg_temp.u('V-CSE') FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk)),
  'final approval creates the unpublished event (its facts read from the proposal), makes the club''s officers its organisers, and sends the room to its custodian');
SELECT pg_temp.act((SELECT instance_id FROM facility.booking_request WHERE booking_group_id = (SELECT g FROM bk)), 'APPROVE', 'HOD');
SELECT pg_temp.ok((SELECT room_requests_approved = 1 AND status = 'APPROVED' AND event_id IS NOT NULL FROM events.v_proposal_status WHERE event_proposal_id = pg_temp.u('A')), 'the custodian approves the room; the proposal shows its venue approved');
SELECT pg_temp.rejects($q$INSERT INTO events.event (event_proposal_id) VALUES (md5('A2')::uuid)$q$, 'an event for a proposal that was never approved');
-- sponsorship fulfilment
SELECT pg_temp.rejects($q$INSERT INTO events.sponsorship_receipt (sponsorship_id, amount, recorded_by_account_id) VALUES (md5('SHIP')::uuid, 5000, md5('A-S3')::uuid)$q$, 'a sponsorship receipt recorded by a non-organiser');
INSERT INTO events.sponsorship_receipt (sponsorship_id, amount, reference, recorded_by_account_id) VALUES (pg_temp.u('SHIP'), 15000, 'NEFT 4411', pg_temp.acct('ADV'));
SELECT pg_temp.rejects($q$INSERT INTO events.sponsorship_receipt (sponsorship_id, amount, recorded_by_account_id) VALUES (md5('SHIP')::uuid, 10000, md5('A-ADV')::uuid)$q$, 'receipts above the commitment');
SELECT pg_temp.ok((SELECT cash_amount = 20000 AND cash_received = 15000 FROM events.v_sponsorship_status WHERE sponsorship_id = pg_temp.u('SHIP')), 'sponsorship fulfilment derived from receipts');
-- publishing A
SELECT pg_temp.rejects($q$SELECT events.publish_event(pg_temp.event_of('A'), md5('A-S1')::uuid)$q$, 'publishing without descriptions, contact and registration window');
SELECT pg_temp.rejects($q$INSERT INTO events.event_round (event_id, name, during, event_round_type_id) VALUES (pg_temp.event_of('A'), 'After party', tsrange(pg_temp.day() + time '19:00', pg_temp.day() + time '20:00'), ref.id_of('event_round_type','GENERAL'))$q$, 'a round outside the event');
INSERT INTO events.event_round (event_id, name, during, event_round_type_id) VALUES (pg_temp.event_of('A'), 'Hack', tsrange(pg_temp.day() + time '09:00', pg_temp.day() + time '17:00'), pg_temp.lk('event_round_type','GENERAL'));
SELECT pg_temp.rejects($q$UPDATE events.event SET registration_window = tstzrange(now(), (pg_temp.day() + 1)::timestamptz) WHERE id = pg_temp.event_of('A')$q$, 'a registration window that closes after the event starts');
UPDATE events.event SET short_description = '24-hour hackathon', long_description = 'Build something in a day.', contact_person_id = pg_temp.u('P-ADV'),
       registration_window = tstzrange(now() - interval '1 hour', (pg_temp.day() - 1)::timestamptz) WHERE id = pg_temp.event_of('A');
SELECT pg_temp.rejects($q$SELECT events.publish_event(pg_temp.event_of('A'), md5('A-S3')::uuid)$q$, 'publishing by someone who is not an organiser');
SELECT events.publish_event(pg_temp.event_of('A'), pg_temp.acct('S1'));
SELECT pg_temp.ok((SELECT status = 'PUBLISHED' AND registration_open FROM events.v_event WHERE event_id = pg_temp.event_of('A')), 'published: registration is open');
SELECT pg_temp.rejects($q$SELECT events.register(pg_temp.event_of('A'), md5('A-FAC')::uuid)$q$, 'registration by someone the event is not open to (students only)');
SELECT events.register(pg_temp.event_of('A'), pg_temp.acct('S3'));
SELECT pg_temp.rejects($q$UPDATE events.event SET published_at = NULL, published_by_account_id = NULL WHERE id = pg_temp.event_of('A')$q$, 'unpublishing an event people have registered for');
SELECT pg_temp.rejects($q$SELECT events.complete_event(pg_temp.event_of('A'), md5('A-S1')::uuid)$q$, 'completing an event that has not happened yet');

-- ============================================ event Q: one that really happens ===
-- individual, two seats, one guest each, certificates, duty leave; starts in a few seconds
SELECT pg_temp.draft('Q', pg_temp.club(), 'S2', 'WORKSHOP', 'Git in an hour', tsrange(clock_timestamp()::timestamp + interval '5 seconds', clock_timestamp()::timestamp + interval '7 seconds'),
                     'INDIVIDUAL', NULL, NULL, 2, 2, 1, true, 'BOTH');
SELECT pg_temp.parts('Q', 'ADV', 800);
INSERT INTO events.proposal_prize (id, event_proposal_id, position, title, event_prize_type_id) VALUES (pg_temp.u('PRZ-Q'), pg_temp.u('Q'), 1, 'Best commit', pg_temp.lk('event_prize_type','CERTIFICATE'));
SELECT events.submit_proposal(pg_temp.u('Q'), pg_temp.acct('S2'));
SELECT pg_temp.act(pg_temp.round_of('Q'), 'APPROVE', 'ADV');
SELECT pg_temp.act(pg_temp.round_of('Q'), 'APPROVE', 'CCC2');
INSERT INTO events.event_round (event_id, name, during, event_round_type_id)
SELECT pg_temp.event_of('Q'), 'Session', during, pg_temp.lk('event_round_type','GENERAL') FROM events.event_proposal WHERE id = pg_temp.u('Q');
UPDATE events.event SET short_description = 'Git basics', long_description = 'Commit, branch, merge.', contact_person_id = pg_temp.u('P-ADV'),
       registration_window = tstzrange(now() - interval '1 minute', (SELECT lower(during) FROM events.event_proposal WHERE id = pg_temp.u('Q'))::timestamptz)
WHERE id = pg_temp.event_of('Q');
SELECT events.publish_event(pg_temp.event_of('Q'), pg_temp.acct('S2'));
CREATE TEMP TABLE reg (k text PRIMARY KEY, id uuid);
INSERT INTO reg SELECT 'S3', events.register(pg_temp.event_of('Q'), pg_temp.acct('S3'));
INSERT INTO reg SELECT 'S4', events.register(pg_temp.event_of('Q'), pg_temp.acct('S4'));
INSERT INTO reg SELECT 'S5', events.register(pg_temp.event_of('Q'), pg_temp.acct('S5'));
-- ticket generation: each holder gets the token of their QR, once
SELECT pg_temp.rejects($q$SELECT events.issue_ticket((SELECT id FROM reg WHERE k = 'S3'), md5('A-S4')::uuid)$q$, 'a ticket handed to someone who is neither its holder nor an organiser');
CREATE TEMP TABLE tkt AS SELECT k, events.issue_ticket(id, pg_temp.acct(k)) AS t FROM reg;
CREATE FUNCTION pg_temp.reg(k text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM reg WHERE reg.k = $1 $$;
CREATE FUNCTION pg_temp.rstate(k text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT events.registration_state(pg_temp.reg(k)) $$;
SELECT pg_temp.ok(pg_temp.rstate('S3') = 'CONFIRMED' AND pg_temp.rstate('S4') = 'CONFIRMED' AND pg_temp.rstate('S5') = 'WAITLISTED'
              AND (SELECT registration_code ~ '^REG-' FROM events.event_registration WHERE id = pg_temp.reg('S3'))
              AND (SELECT seats_taken = 2 AND seat_limit = 2 FROM events.v_event WHERE event_id = pg_temp.event_of('Q')),
  'two seats: the third registration is waitlisted');
SELECT pg_temp.rejects($q$SELECT events.register(pg_temp.event_of('Q'), md5('A-S3')::uuid)$q$, 'registering twice for one event');
SELECT pg_temp.rejects($q$UPDATE events.event_registration SET cancelled_at = now(), cancelled_by_account_id = md5('A-S6')::uuid, registration_cancel_reason_id = ref.id_of('registration_cancel_reason','WITHDRAWN') WHERE id = pg_temp.reg('S4')$q$, 'a registration cancelled by a stranger');
SELECT pg_temp.rejects($q$UPDATE events.event_registration SET promoted_at = now() WHERE id = pg_temp.reg('S5')$q$, 'promoting from the waiting list with no seat free');
UPDATE events.event_registration SET cancelled_at = now(), cancelled_by_account_id = pg_temp.acct('S4'), registration_cancel_reason_id = pg_temp.lk('registration_cancel_reason','WITHDRAWN') WHERE id = pg_temp.reg('S4');
SELECT pg_temp.ok(events.promote_waitlist(pg_temp.event_of('Q')) = 1, 'a withdrawal frees a seat; the waiting list moves up by one');
SELECT pg_temp.ok(pg_temp.rstate('S4') = 'CANCELLED' AND pg_temp.rstate('S5') = 'CONFIRMED', 'the withdrawn registration is CANCELLED, the promoted one CONFIRMED');
SELECT pg_temp.rejects($q$UPDATE events.event_registration SET person_id = md5('P-S6')::uuid WHERE id = pg_temp.reg('S3')$q$, 'changing who a registration belongs to');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
  VALUES (pg_temp.reg('S3'), 100, ref.id_of('payment_channel','GATEWAY'), ref.id_of('payment_status','CREATED'), 'order_free')$q$, 'a payment on a free event');
-- guests and an extra question
INSERT INTO events.extra_pass (registration_id, guest_name, guest_phone, relationship) VALUES (pg_temp.reg('S3'), 'Guest of S3', '+919812345678', 'Sibling');
SELECT pg_temp.rejects($q$INSERT INTO events.extra_pass (registration_id, guest_name) VALUES (pg_temp.reg('S3'), 'Second guest')$q$, 'more guests than the event allows per participant');
SELECT pg_temp.rejects($q$INSERT INTO events.extra_pass (registration_id, guest_name) VALUES ((SELECT id FROM events.event_registration WHERE event_id = pg_temp.event_of('A') LIMIT 1), 'x')$q$, 'a guest at an event that takes none');
INSERT INTO events.event_custom_field (id, event_id, field_name, label, event_field_type_id, is_required)
VALUES (pg_temp.u('FLD'), pg_temp.event_of('Q'), 'tshirt', 'T-shirt size', pg_temp.lk('event_field_type','DROPDOWN'), true);
INSERT INTO events.custom_field_option (event_custom_field_id, option_value, sort_order) VALUES (pg_temp.u('FLD'), 'S', 1), (pg_temp.u('FLD'), 'M', 2), (pg_temp.u('FLD'), 'L', 3);
SELECT pg_temp.rejects($q$INSERT INTO events.field_response (registration_id, event_custom_field_id, value) VALUES (pg_temp.reg('S3'), md5('FLD')::uuid, 'XXL')$q$, 'an answer that is not one of the options');
SELECT pg_temp.rejects($q$INSERT INTO events.field_response (registration_id, event_custom_field_id, value) VALUES ((SELECT id FROM events.event_registration WHERE event_id = pg_temp.event_of('A') LIMIT 1), md5('FLD')::uuid, 'M')$q$, 'an answer to another event''s question');
INSERT INTO events.field_response (registration_id, event_custom_field_id, value) VALUES (pg_temp.reg('S3'), pg_temp.u('FLD'), 'M');
-- volunteers and the gate
SELECT pg_temp.rejects($q$INSERT INTO events.event_volunteer (event_id, person_id, volunteer_role_id, assigned_by_account_id) VALUES (pg_temp.event_of('Q'), md5('P-S6')::uuid, ref.id_of('volunteer_role','VOLUNTEER'), md5('A-S5')::uuid)$q$, 'a volunteer assigned by a participant');
SELECT pg_temp.rejects($q$INSERT INTO events.event_volunteer (event_id, person_id, volunteer_role_id, assigned_by_account_id) VALUES (pg_temp.event_of('Q'), md5('P-GUEST')::uuid, ref.id_of('volunteer_role','VOLUNTEER'), md5('A-S2')::uuid)$q$, 'a volunteer who is neither a student nor an employee');
INSERT INTO events.event_volunteer (id, event_id, person_id, volunteer_role_id, gate, assigned_by_account_id)
VALUES (pg_temp.u('VOL-6'), pg_temp.event_of('Q'), pg_temp.u('P-S6'), pg_temp.lk('volunteer_role','VOLUNTEER'), 'Main gate', pg_temp.acct('S2'));
CREATE FUNCTION pg_temp.qr(k text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT t FROM tkt WHERE tkt.k = $1 $$;
SELECT pg_temp.ok((SELECT t ~ '^TKT-[0-9A-F]{40}$' FROM tkt WHERE k = 'S3')
              AND (SELECT ticket_issued_at IS NOT NULL FROM events.event_registration WHERE id = pg_temp.reg('S3'))
              AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'events' AND table_name = 'event_registration' AND column_name ~ 'token$')
              AND (SELECT status = 'CONFIRMED' AND pass_size = 2 AND guests = 1 AND inside = 0 AND event_code ~ '^EVT-' AND title = 'Git in an hour'
                   FROM events.v_ticket WHERE registration_id = pg_temp.reg('S3')),
  'ticket generation: the holder gets the token for the QR (only its hash is stored); the ticket shows the event, the state and a pass for 2 (holder + guest)');
SELECT pg_temp.rejects($q$UPDATE events.event_registration SET qr_token_hash = decode(repeat('00', 32), 'hex') WHERE id = pg_temp.reg('S3')$q$, 'a ticket token set by hand');
SELECT pg_temp.rejects($q$SELECT events.issue_ticket(pg_temp.reg('S4'), md5('A-S4')::uuid)$q$, 'a new ticket for a cancelled registration');
SELECT pg_temp.rejects($q$SELECT events.scan('TKT-NOT-A-TICKET', 'IN', md5('A-S6')::uuid)$q$, 'a scan of an unknown pass');
SELECT pg_temp.rejects($q$SELECT * FROM events.ticket_check(pg_temp.qr('S3'), md5('A-S5')::uuid)$q$, 'a pass checked by someone who is not on gate duty');
SELECT pg_temp.ok((SELECT status = 'CONFIRMED' AND pass_size = 2 AND inside = 0 AND may_enter = 2 FROM events.ticket_check(pg_temp.qr('S3'), pg_temp.acct('S6')))
              AND (SELECT status = 'CANCELLED' AND may_enter = 0 FROM events.ticket_check(pg_temp.qr('S4'), pg_temp.acct('S6'))),
  'the volunteer''s scan preview: two may enter on this pass; nobody on a cancelled registration');
SELECT pg_temp.rejects($q$SELECT events.scan(pg_temp.qr('S3'), 'IN', md5('A-S5')::uuid)$q$, 'a scan by someone who is neither a scanning volunteer nor an organiser');
SELECT pg_temp.rejects($q$SELECT events.scan(pg_temp.qr('S4'), 'IN', md5('A-S6')::uuid)$q$, 'entry on a cancelled registration');
SELECT pg_temp.rejects($q$SELECT events.scan(pg_temp.qr('S3'), 'OUT', md5('A-S6')::uuid)$q$, 'an exit before any entry');
SELECT events.scan(pg_temp.qr('S3'), 'IN', pg_temp.acct('S6'), 2, 'Main gate');           -- the participant and the guest
SELECT pg_temp.rejects($q$SELECT events.scan(pg_temp.qr('S3'), 'IN', md5('A-S6')::uuid, 1)$q$, 'more people in than the pass allows (1 + 1 guest)');
SELECT events.scan(pg_temp.qr('S3'), 'OUT', pg_temp.acct('S6'), 1);
SELECT events.scan(pg_temp.qr('S3'), 'IN', pg_temp.acct('S6'), 1);                        -- re-entry
CREATE TEMP TABLE tkt_old AS SELECT t FROM tkt WHERE k = 'S5';
UPDATE tkt SET t = events.issue_ticket(pg_temp.reg('S5'), pg_temp.acct('S2')) WHERE k = 'S5';   -- lost phone: an organiser re-issues the ticket
SELECT pg_temp.rejects($q$SELECT events.scan((SELECT t FROM tkt_old), 'IN', md5('A-S6')::uuid)$q$, 'the old QR after the ticket was re-issued');
SELECT pg_temp.rejects($q$INSERT INTO events.entry_scan (registration_id, entry_direction_id, scanned_by_account_id, scan_source_id)
  VALUES (pg_temp.reg('S5'), ref.id_of('entry_direction','IN'), md5('A-S6')::uuid, ref.id_of('scan_source','IMPORT'))$q$, 'an attendance import by a volunteer');
INSERT INTO events.entry_scan (registration_id, entry_direction_id, scanned_by_account_id, scan_source_id, remarks)
VALUES (pg_temp.reg('S5'), pg_temp.lk('entry_direction','IN'), pg_temp.acct('S2'), pg_temp.lk('scan_source','IMPORT'), 'attendance sheet');
SELECT pg_temp.rejects($q$UPDATE events.entry_scan SET people_count = 5$q$, 'editing the gate log');
SELECT pg_temp.ok((SELECT entered = 3 AND exited = 1 AND inside = 2 AND attended FROM events.v_attendance WHERE registration_id = pg_temp.reg('S3'))
              AND (SELECT attended FROM events.v_attendance WHERE registration_id = pg_temp.reg('S5'))
              AND NOT (SELECT attended FROM events.v_attendance WHERE registration_id = pg_temp.reg('S4')),
  'attendance derived from the gate log: entries, exits, who is inside, re-entry, imported sheet');
SELECT pg_temp.ok((SELECT volunteer_role = 'VOLUNTEER' AND can_scan AND gate = 'Main gate' AND is_active AND title = 'Git in an hour' AND registrations = 2
                          AND scans = 3 AND people_in = 3 AND people_out = 1 AND last_scan_at IS NOT NULL
                   FROM events.v_volunteer_assignment WHERE person_id = pg_temp.u('P-S6') AND event_id = pg_temp.event_of('Q'))
              AND (SELECT count(*) = 3 AND bool_and(registration_code ~ '^REG-') FROM events.v_volunteer_activity WHERE volunteer_person_id = pg_temp.u('P-S6'))
              AND (SELECT scans = 1 AND entered = 2 AND exited = 0 AND scanners = 1 FROM events.v_gate_summary WHERE event_id = pg_temp.event_of('Q') AND gate = 'Main gate'),
  'the volunteer''s dashboard: the duty (event, gate, may scan), their own scans (3: three in, one out) and the count at the gate');
-- prizes
SELECT pg_temp.rejects($q$INSERT INTO events.event_prize_award (proposal_prize_id, registration_id, awarded_by_account_id) VALUES (md5('PRZ-Q')::uuid, pg_temp.reg('S4'), md5('A-S2')::uuid)$q$, 'a prize for someone who did not attend');
SELECT pg_temp.rejects($q$INSERT INTO events.event_prize_award (proposal_prize_id, registration_id, awarded_by_account_id) VALUES (md5('PRZ-A')::uuid, pg_temp.reg('S3'), md5('A-S2')::uuid)$q$, 'a prize of another event');
SELECT pg_temp.rejects($q$INSERT INTO events.event_prize_award (proposal_prize_id, registration_id, awarded_by_account_id) VALUES (md5('PRZ-Q')::uuid, pg_temp.reg('S3'), md5('A-S5')::uuid)$q$, 'a prize awarded by a participant');
INSERT INTO events.event_prize_award (proposal_prize_id, registration_id, awarded_by_account_id) VALUES (pg_temp.u('PRZ-Q'), pg_temp.reg('S3'), pg_temp.acct('S2'));
-- certificates are for an event that has started; completion for one that has ended
INSERT INTO events.event_certificate_template (id, event_id, event_certificate_type_id, title, body) VALUES
 (pg_temp.u('CT-P'), pg_temp.event_of('Q'), pg_temp.lk('event_certificate_type','PARTICIPATION'), 'Certificate of participation', 'This certifies that [Name] took part in [Event].'),
 (pg_temp.u('CT-W'), pg_temp.event_of('Q'), pg_temp.lk('event_certificate_type','WINNER'), 'Certificate of merit', 'This certifies that [Name] won [Prize] at [Event].'),
 (pg_temp.u('CT-V'), pg_temp.event_of('Q'), pg_temp.lk('event_certificate_type','VOLUNTEER'), 'Certificate of appreciation', 'With thanks to [Name] for volunteering at [Event].');
SELECT pg_temp.rejects($q$SELECT events.issue_certificates(pg_temp.event_of('Q'), 'PARTICIPATION', md5('A-S2')::uuid)$q$, 'certificates before the event has started');
SELECT pg_temp.rejects($q$SELECT events.complete_event(pg_temp.event_of('Q'), md5('A-S2')::uuid)$q$, 'completing an event before it has ended');
SELECT pg_sleep(8);
SELECT pg_temp.ok((SELECT status = 'ENDED' AND NOT registration_open FROM events.v_event WHERE event_id = pg_temp.event_of('Q')), 'the event is over: ENDED until the organisers close it (status derived from the clock)');
SELECT pg_temp.rejects($q$SELECT events.register(pg_temp.event_of('Q'), md5('A-S6')::uuid)$q$, 'registering after the window closed');
SELECT pg_temp.rejects($q$SELECT events.complete_event(pg_temp.event_of('Q'), md5('A-S3')::uuid)$q$, 'completion by a participant');
SELECT events.complete_event(pg_temp.event_of('Q'), pg_temp.acct('S2'));
SELECT pg_temp.ok((SELECT status = 'COMPLETED' FROM events.v_event WHERE event_id = pg_temp.event_of('Q'))
              AND (SELECT total_points = 5 AND events_completed = 1 AND tier = 'Bronze' FROM events.v_club_points WHERE club_org_unit_id = pg_temp.club())
              AND (SELECT rank = 1 FROM events.v_club_leaderboard WHERE club_org_unit_id = pg_temp.club()),
  'completion awards the club the points of a workshop (5): Bronze tier, first on the leaderboard');
SELECT pg_temp.rejects($q$UPDATE events.event SET long_description = 'changed' WHERE id = pg_temp.event_of('Q')$q$, 'editing a completed event');
SELECT pg_temp.rejects($q$INSERT INTO events.club_tier (name, tier_order, points) VALUES ('Copper', 9, int4range(10, 30))$q$, 'a tier whose band overlaps another');
SELECT pg_temp.rejects($q$INSERT INTO events.event_type_points (event_type_id, points) VALUES (ref.id_of('event_type','WORKSHOP'), 7)$q$, 'two point values for one event type at a time');
-- certificates
SELECT pg_temp.ok(events.issue_certificates(pg_temp.event_of('Q'), 'PARTICIPATION', pg_temp.acct('S2')) = 2, 'participation certificates go to the two who attended');
SELECT pg_temp.ok(events.issue_certificates(pg_temp.event_of('Q'), 'PARTICIPATION', pg_temp.acct('S2')) = 0, 'issuing again creates nothing new');
SELECT pg_temp.ok(events.issue_certificates(pg_temp.event_of('Q'), 'WINNER', pg_temp.acct('S2')) = 1, 'the winner certificate goes to the prize winner');
SELECT pg_temp.ok(events.issue_certificates(pg_temp.event_of('Q'), 'VOLUNTEER', pg_temp.acct('S2')) = 2, 'volunteer certificates go to the volunteer and the event manager');
SELECT pg_temp.rejects($q$INSERT INTO events.event_certificate (certificate_template_id, registration_id, issued_by_account_id) VALUES (md5('CT-P')::uuid, pg_temp.reg('S4'), md5('A-S2')::uuid)$q$, 'a certificate for someone who did not attend');
SELECT pg_temp.rejects($q$INSERT INTO events.event_certificate (certificate_template_id, registration_id, issued_by_account_id) VALUES (md5('CT-W')::uuid, pg_temp.reg('S5'), md5('A-S2')::uuid)$q$, 'a winner certificate without a prize');
SELECT pg_temp.rejects($q$INSERT INTO events.event_certificate (certificate_template_id, registration_id, issued_by_account_id) VALUES (md5('CT-V')::uuid, pg_temp.reg('S5'), md5('A-S2')::uuid)$q$, 'a volunteer certificate for a participant');
SELECT pg_temp.ok((SELECT count(*) = 5 AND bool_and(is_valid) AND bool_and(holder_name IS NOT NULL) AND bool_and(serial_no ~ '^EC-[0-9]{4}-[0-9]{6}$')
                   FROM events.v_certificate_verify WHERE event_title = 'Git in an hour'), 'five certificates, each verifiable by its code');
SELECT pg_temp.rejects($q$UPDATE events.event_certificate SET serial_no = 'EC-0000-000000'$q$, 'altering an issued certificate');
UPDATE events.event_certificate SET revoked_at = now(), revoke_reason = 'Issued in error' WHERE registration_id = pg_temp.reg('S5') AND certificate_template_id = pg_temp.u('CT-P');
SELECT pg_temp.ok((SELECT count(*) FILTER (WHERE NOT is_valid) = 1 FROM events.v_certificate_verify WHERE event_title = 'Git in an hour'), 'a revoked certificate verifies as invalid');
-- anonymous feedback
SELECT pg_temp.rejects($q$SELECT events.feedback_token_for(pg_temp.reg('S4'))$q$, 'a feedback token for someone who did not attend');
CREATE TEMP TABLE tok AS SELECT events.feedback_token_for(pg_temp.reg('S3')) AS t;
SELECT pg_temp.rejects($q$SELECT events.feedback_token_for(pg_temp.reg('S3'))$q$, 'a second token for one attendee');
SELECT pg_temp.rejects($q$INSERT INTO events.event_feedback (event_id, rating) VALUES (pg_temp.event_of('Q'), 10)$q$, 'feedback written without a token');
SELECT events.submit_feedback((SELECT t FROM tok), 9, 'Clear and practical');
SELECT pg_temp.rejects($q$SELECT events.submit_feedback((SELECT t FROM tok), 1, 'again')$q$, 'a token used twice');
SELECT pg_temp.rejects($q$SELECT events.submit_feedback('not-a-token', 5)$q$, 'an unknown token');
SELECT pg_temp.ok((SELECT feedback_count = 1 AND feedback_avg = 9.00 AND attended = 2 AND confirmed = 2 AND cancelled = 1 AND volunteers = 2 AND certificates = 4
                   FROM events.v_event_statistics WHERE event_id = pg_temp.event_of('Q'))
              AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'events' AND table_name = 'event_feedback'
                              AND column_name IN ('person_id', 'registration_id', 'account_id', 'submitted_at')),
  'event statistics; the feedback row has no column that could identify who wrote it');
-- the report, and duty leave
SELECT pg_temp.rejects($q$INSERT INTO events.post_event_report (event_id, version, file_object_id, uploaded_by_account_id) VALUES (pg_temp.event_of('Q'), 1, md5('F-REPORT')::uuid, md5('A-S3')::uuid)$q$, 'a report filed by a participant');
INSERT INTO events.post_event_report (event_id, version, file_object_id, summary, actual_attendance, uploaded_by_account_id) VALUES (pg_temp.event_of('Q'), 1, pg_temp.u('F-REPORT'), 'Went well', 2, pg_temp.acct('S2'));
INSERT INTO events.post_event_report (event_id, version, file_object_id, summary, uploaded_by_account_id) VALUES (pg_temp.event_of('Q'), 1, pg_temp.u('F-REPORT'), 'Corrected figures', pg_temp.acct('ADV'));
SELECT pg_temp.ok((SELECT report_version = 2 FROM events.v_event_statistics WHERE event_id = pg_temp.event_of('Q')), 'a second filing is version 2');
SELECT pg_temp.rejects($q$UPDATE events.post_event_report SET summary = 'x'$q$, 'editing a filed report');
SELECT pg_temp.ok((SELECT count(*) FILTER (WHERE basis = 'PARTICIPANT') = 2 AND count(*) FILTER (WHERE basis = 'ORGANISER') = 2
                   FROM events.v_duty_leave_eligible WHERE event_id = pg_temp.event_of('Q')),
  'duty-leave list: the two students who attended and the two student organisers');

-- =============================== configuration: a school changes its own path ===
-- The School of Engineering wants its Dean on anything above 50,000 and the
-- whole committee (quorum 2) instead of any one member: one chain row, three
-- stage rows — no code.
INSERT INTO ref.academic_body_type (code, label, sort_order) VALUES ('CENTRAL_COORDINATION_COMMITTEE', 'Central coordination committee', 30);
INSERT INTO academic.academic_body (id, academic_body_type_id, org_unit_id, name, quorum)
VALUES (pg_temp.u('CCC'), pg_temp.lk('academic_body_type','CENTRAL_COORDINATION_COMMITTEE'), pg_temp.u('V-SGTU'), 'Central coordination committee', 2);
INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id, valid) VALUES
 (pg_temp.u('CCC'), pg_temp.lk('committee_role','CHAIR'),  pg_temp.emp('REG'),  daterange('2024-01-01', NULL)),
 (pg_temp.u('CCC'), pg_temp.lk('committee_role','MEMBER'), pg_temp.emp('CCC1'), daterange('2024-01-01', NULL)),
 (pg_temp.u('CCC'), pg_temp.lk('committee_role','MEMBER'), pg_temp.emp('CCC2'), daterange('2024-01-01', NULL));
INSERT INTO wf.approval_chain (id, document_type_id, scope_org_unit_id, valid, note)
SELECT 9701, id, pg_temp.u('V-SET'), daterange(current_date, NULL), 'School of Engineering: Dean above 50,000; committee quorum' FROM wf.approval_document_type WHERE code = 'EVENT_PROPOSAL';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_is_owner, wf_self_action_id)
SELECT 9701, 1, 'ADVISOR', 'Advisor / head of the unit', permission_id, true, pg_temp.lk('wf_self_action','SKIP') FROM authz.v_permission_code WHERE code = 'events.proposal.review';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, anchor_org_unit_type_id, min_amount)
SELECT 9701, 2, 'DEAN', 'Dean (budget of 50,000 and above)', pg_temp.lk('wf_approver_kind','POSITION'), id, pg_temp.lk('org_unit_type','SCHOOL'), 50000 FROM org.position_type WHERE code = 'DEAN';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, academic_body_id)
VALUES (9701, 3, 'CCC', 'Central coordination committee (quorum)', pg_temp.lk('wf_approver_kind','COMMITTEE'), pg_temp.u('CCC'));

-- B: a department's own team event, budget 60,000 — head → Dean → committee quorum
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', md5('V-CSE')::uuid, 'S1', 'COMPETITION', 'x event', tsrange(pg_temp.day() + 2 + time '09:00', pg_temp.day() + 2 + time '17:00'))$q$, 'a department event proposed by a student');
SELECT pg_temp.draft('B', pg_temp.u('V-CSE'), 'FAC', 'COMPETITION', 'Inter-department coding league', tsrange(pg_temp.day() + 2 + time '09:00', pg_temp.day() + 2 + time '17:00'), 'TEAM', 2, 3, 60);
SELECT pg_temp.parts('B', 'FAC', 60000);
SELECT events.submit_proposal(pg_temp.u('B'), pg_temp.acct('FAC'));
SELECT pg_temp.ok(pg_temp.steps(pg_temp.round_of('B')) = 'ADVISOR,DEAN,CCC'
              AND (SELECT string_agg(u.code, ',' ORDER BY st.seq) = 'V-CSE,V-SET,V-SGTU' FROM wf.approval_step st JOIN org.org_unit u ON u.id = st.anchor_org_unit_id WHERE st.instance_id = pg_temp.round_of('B'))
              AND (SELECT required = 2 AND assignees = 3 FROM wf.v_step_state WHERE instance_id = pg_temp.round_of('B') AND seq = 3),
  'the school''s own chain applies below it: head of the department, the Dean (60,000 ≥ 50,000), the committee with a quorum of 2');
SELECT pg_temp.act(pg_temp.round_of('B'), 'APPROVE', 'HOD');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.round_of('B'), 'APPROVE', 'HOD')$q$, 'the Dean''s level approved by the head of department');
SELECT pg_temp.act(pg_temp.round_of('B'), 'APPROVE', 'DEAN');
SELECT pg_temp.act(pg_temp.round_of('B'), 'APPROVE', 'CCC1');
SELECT pg_temp.ok(pg_temp.event_of('B') IS NULL, 'one committee member is not the quorum');
SELECT pg_temp.act(pg_temp.round_of('B'), 'APPROVE', 'CCC2');
SELECT pg_temp.ok(pg_temp.event_of('B') IS NOT NULL AND events.can_manage(pg_temp.acct('FAC'), pg_temp.event_of('B')) AND events.can_manage(pg_temp.acct('HOD'), pg_temp.event_of('B'))
              AND NOT events.can_manage(pg_temp.acct('S1'), pg_temp.event_of('B')),
  'the quorum approves it; a department event is run by the department''s staff, not by a club');
-- C: the advisor proposes for her own club, small budget — her own level and the Dean's fall away
SELECT pg_temp.draft('C', pg_temp.club(), 'ADV', 'SEMINAR', 'Alumni talk', tsrange(pg_temp.day() + 3 + time '15:00', pg_temp.day() + 3 + time '17:00'));
SELECT pg_temp.parts('C', 'ADV', 2000);
SELECT events.submit_proposal(pg_temp.u('C'), pg_temp.acct('ADV'));
SELECT pg_temp.ok(pg_temp.steps(pg_temp.round_of('C')) = 'CCC', 'the advisor''s own proposal skips the advisor level (self-action SKIP); a 2,000 budget skips the Dean');
SELECT pg_temp.act(pg_temp.round_of('C'), 'RETURN', 'CCC1', 'Please add the speaker''s profile');
SELECT pg_temp.ok((SELECT status = 'RETURNED' AND event_id IS NULL FROM events.v_proposal_status WHERE event_proposal_id = pg_temp.u('C')), 'a returned proposal creates no event');
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'ADV', 'SEMINAR', 'x event', tsrange(pg_temp.day() + 3 + time '15:00', pg_temp.day() + 3 + time '17:00'),
  'INDIVIDUAL', NULL, NULL, 100, NULL, 0, false, NULL, md5('A')::uuid)$q$, 'revising a proposal that was approved');
SELECT pg_temp.draft('C2', pg_temp.club(), 'ADV', 'SEMINAR', 'Alumni talk (with profile)', tsrange(pg_temp.day() + 3 + time '15:00', pg_temp.day() + 3 + time '17:00'),
  'INDIVIDUAL', NULL, NULL, 100, NULL, 0, false, NULL, pg_temp.u('C'));
SELECT pg_temp.parts('C2', 'ADV', 2000);
SELECT events.submit_proposal(pg_temp.u('C2'), pg_temp.acct('ADV'));
SELECT pg_temp.ok((SELECT revises_instance_id = pg_temp.round_of('C') FROM wf.approval_instance WHERE id = pg_temp.round_of('C2')), 'the revision is a new proposal and a new round that names the one it revises');

-- ================================================================== teams ====
INSERT INTO events.event_round (event_id, name, during, event_round_type_id)
SELECT pg_temp.event_of('B'), 'League', during, pg_temp.lk('event_round_type','GENERAL') FROM events.event_proposal WHERE id = pg_temp.u('B');
UPDATE events.event SET short_description = 'Coding league', long_description = 'Teams of two or three.', contact_person_id = pg_temp.u('P-FAC'),
       registration_window = tstzrange(now() - interval '1 hour', (pg_temp.day() + 1)::timestamptz) WHERE id = pg_temp.event_of('B');
SELECT events.publish_event(pg_temp.event_of('B'), pg_temp.acct('FAC'));
INSERT INTO reg SELECT 'B3', events.register(pg_temp.event_of('B'), pg_temp.acct('S3'));
INSERT INTO reg SELECT 'B4', events.register(pg_temp.event_of('B'), pg_temp.acct('S4'));
INSERT INTO reg SELECT 'B5', events.register(pg_temp.event_of('B'), pg_temp.acct('S5'));
INSERT INTO reg SELECT 'B6', events.register(pg_temp.event_of('B'), pg_temp.acct('S6'));
SELECT pg_temp.ok(pg_temp.rstate('B3') = 'INCOMPLETE_TEAM', 'in a team event a registration is incomplete until its team is');
SELECT pg_temp.rejects($q$INSERT INTO events.event_team (event_id, name, leader_registration_id) VALUES (pg_temp.event_of('B'), 'Wrong', pg_temp.reg('S3'))$q$, 'a team led by a registration of another event');
INSERT INTO events.event_team (id, event_id, name, leader_registration_id) VALUES (pg_temp.u('TEAM'), pg_temp.event_of('B'), 'Alpha', pg_temp.reg('B3'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_team (event_id, name, leader_registration_id) VALUES (pg_temp.event_of('B'), 'ALPHA', pg_temp.reg('B4'))$q$, 'two teams with the same name (case-insensitive)');
SELECT pg_temp.rejects($q$INSERT INTO events.event_team (event_id, name, leader_registration_id) VALUES (pg_temp.event_of('B'), 'Beta', pg_temp.reg('B3'))$q$, 'a participant leading a second team');
SELECT pg_temp.rejects($q$UPDATE events.event_team SET locked_at = now() WHERE id = md5('TEAM')::uuid$q$, 'finalising a team below the minimum size');
INSERT INTO events.team_invitation (id, event_team_id, invitee_registration_id, message) VALUES (pg_temp.u('INV-4'), pg_temp.u('TEAM'), pg_temp.reg('B4'), 'Join us');
SELECT pg_temp.rejects($q$INSERT INTO events.team_invitation (event_team_id, invitee_registration_id) VALUES (md5('TEAM')::uuid, pg_temp.reg('B4'))$q$, 'a second open invitation to the same participant');
UPDATE events.team_invitation SET responded_at = now(), is_accepted = true WHERE id = pg_temp.u('INV-4');
SELECT pg_temp.ok(pg_temp.rstate('B3') = 'CONFIRMED' AND pg_temp.rstate('B4') = 'CONFIRMED' AND (SELECT status = 'COMPLETE' AND members = 2 FROM events.v_team WHERE event_team_id = pg_temp.u('TEAM')),
  'an accepted invitation makes the member; at the minimum size the team is complete and its members confirmed');
INSERT INTO events.team_join_request (id, event_team_id, registration_id) VALUES (pg_temp.u('JR-5'), pg_temp.u('TEAM'), pg_temp.reg('B5'));
UPDATE events.team_join_request SET responded_at = now(), is_accepted = true WHERE id = pg_temp.u('JR-5');
INSERT INTO events.team_join_request (id, event_team_id, registration_id) VALUES (pg_temp.u('JR-6'), pg_temp.u('TEAM'), pg_temp.reg('B6'));
SELECT pg_temp.rejects($q$UPDATE events.team_join_request SET responded_at = now(), is_accepted = true WHERE id = md5('JR-6')::uuid$q$, 'a fourth member of a team of at most three');
SELECT pg_temp.rejects($q$INSERT INTO events.team_invitation (event_team_id, invitee_registration_id) VALUES (md5('TEAM')::uuid, pg_temp.reg('B5'))$q$, 'inviting someone who is already in a team');
SELECT pg_temp.rejects($q$UPDATE events.event_team_member SET left_at = now() WHERE event_team_id = md5('TEAM')::uuid AND registration_id = pg_temp.reg('B3')$q$, 'the leader leaving without withdrawing the team');
UPDATE events.event_team SET locked_at = now() WHERE id = pg_temp.u('TEAM');
SELECT pg_temp.rejects($q$UPDATE events.event_team_member SET left_at = now() WHERE event_team_id = md5('TEAM')::uuid AND registration_id = pg_temp.reg('B5')$q$, 'leaving a finalised team');
SELECT pg_temp.rejects($q$UPDATE events.event_team SET disqualified_at = now(), disqualified_by_account_id = md5('A-S3')::uuid WHERE id = md5('TEAM')::uuid$q$, 'a team disqualified by a participant');
SELECT pg_temp.ok((SELECT status = 'FINAL' AND members = 3 FROM events.v_team WHERE event_team_id = pg_temp.u('TEAM')) AND pg_temp.rstate('B6') = 'INCOMPLETE_TEAM', 'a finalised team of three; the fourth applicant stays without a team');

-- ================================================ cancelling a future event ===
SELECT pg_temp.rejects($q$SELECT events.cancel_event(pg_temp.event_of('A'), md5('A-S3')::uuid, 'x')$q$, 'an event cancelled by a participant');
SELECT events.cancel_event(pg_temp.event_of('A'), pg_temp.acct('S1'), 'Sponsor withdrew');
SELECT pg_temp.ok((SELECT status = 'CANCELLED' FROM events.v_event WHERE event_id = pg_temp.event_of('A'))
              AND (SELECT bool_and(events.registration_state(id) = 'CANCELLED') FROM events.event_registration WHERE event_id = pg_temp.event_of('A'))
              AND (SELECT status = 'CANCELLED' AND cancel_reason = 'EVENT_CANCELLED' FROM facility.v_booking_status WHERE booking_group_id = (SELECT g FROM bk))
              AND facility.room_is_free(pg_temp.u('V-AUD'), facility.span(pg_temp.day(), '09:00', '18:00')),
  'cancelling the event cancels its registrations and its facility package: the auditorium is free again');
SELECT pg_temp.rejects($q$UPDATE events.event SET short_description = 'x' WHERE id = pg_temp.event_of('A')$q$, 'editing a cancelled event');
SELECT pg_temp.ok((SELECT sum(proposals) >= 4 AND sum(approved) >= 3 FROM events.v_ccc_overview), 'the committee''s overview counts proposals by state');

-- ==================================== admin settings: policy is data, not code ===
-- Every rule below was refused or required a moment ago; an administrator
-- changes a row and the behaviour changes — no function is edited.
SELECT pg_temp.rejects($q$DELETE FROM events.event_setting$q$, 'removing the settings row');
SELECT pg_temp.rejects($q$INSERT INTO events.event_setting (id) VALUES (false)$q$, 'a second settings row');
SELECT pg_temp.rejects($q$UPDATE events.event_setting SET club_name_max_length = 2$q$, 'a maximum club-name length below the minimum');
-- clubs: objective length, who may advise, which offices a proposal must name
UPDATE events.event_setting SET club_objective_min_length = 10, advisor_must_be_faculty = false, updated_by_account_id = pg_temp.acct('CCC1');
INSERT INTO events.club_proposal (id, proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id, club_category_id)
VALUES (pg_temp.u('CP2'), pg_temp.acct('ADV'), pg_temp.u('V-CSE'), 'Robotics Club', 'Build robots.', pg_temp.emp('CCC1'), pg_temp.lk('club_category','TECHNICAL'));
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM events.club_proposal WHERE id = pg_temp.u('CP2')),
  'settings changed: a 13-character objective and a non-teaching advisor — both refused at the start of this test — are now accepted');
UPDATE ref.club_office SET is_required = true WHERE code = 'SECRETARY';
INSERT INTO events.club_proposal_officer (club_proposal_id, club_office_id, student_id) VALUES (pg_temp.u('CP2'), pg_temp.lk('club_office','PRESIDENT'), pg_temp.stu('S5'));
SELECT pg_temp.rejects($q$SELECT events.submit_club_proposal(md5('CP2')::uuid, md5('A-ADV')::uuid)$q$, 'a club proposal without a secretary once that office is marked required');
UPDATE ref.club_office SET is_required = false;
DELETE FROM events.club_proposal_officer WHERE club_proposal_id = pg_temp.u('CP2');
UPDATE events.club_proposal SET club_category_id = NULL WHERE id = pg_temp.u('CP2');
SELECT pg_temp.rejects($q$SELECT events.submit_club_proposal(md5('CP2')::uuid, md5('A-ADV')::uuid)$q$, 'a club proposal that does not say what kind of club it is');
UPDATE events.club_proposal SET club_category_id = pg_temp.lk('club_category','CULTURAL') WHERE id = pg_temp.u('CP2');
SELECT events.submit_club_proposal(pg_temp.u('CP2'), pg_temp.acct('ADV'));
SELECT pg_temp.ok((SELECT instance_id IS NOT NULL FROM events.club_proposal WHERE id = pg_temp.u('CP2')), 'with no office marked required a proposal is submitted without officers (the president rule was a lookup flag)');
UPDATE ref.club_office SET is_required = true WHERE code = 'PRESIDENT';
UPDATE events.event_setting SET club_objective_min_length = 50, advisor_must_be_faculty = true;
-- event proposals: lead time, required sections, concurrent proposals, guest-pass ceiling
UPDATE events.event_setting SET proposal_min_lead_time = interval '30 days';
SELECT pg_temp.draft('L', pg_temp.club(), 'S1', 'SEMINAR', 'Lead-time talk', tsrange(pg_temp.day() + 5 + time '10:00', pg_temp.day() + 5 + time '12:00'));
SELECT pg_temp.parts('L', 'ADV', 100);
SELECT pg_temp.rejects($q$SELECT events.submit_proposal(md5('L')::uuid, md5('A-S1')::uuid)$q$, 'an event 25 days ahead while the lead time is set to 30 days');
UPDATE events.event_setting SET proposal_min_lead_time = interval '7 days';
SELECT pg_temp.draft('M', pg_temp.club(), 'S1', 'SEMINAR', 'Second talk', tsrange(pg_temp.day() + 6 + time '10:00', pg_temp.day() + 6 + time '12:00'));
INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost, quantity)
VALUES (pg_temp.u('M'), pg_temp.lk('budget_item_type','REFRESHMENTS'), 'Tea', 100, 1);
SELECT pg_temp.rejects($q$SELECT events.submit_proposal(md5('M')::uuid, md5('A-S1')::uuid)$q$, 'a proposal without audience, coordinator and SDG while the settings require them');
UPDATE events.event_setting SET proposal_needs_audience = false, proposal_needs_coordinator = false, proposal_needs_sdg = false;
SELECT events.submit_proposal(pg_temp.u('L'), pg_temp.acct('S1'));
SELECT pg_temp.rejects($q$SELECT events.submit_proposal(md5('M')::uuid, md5('A-S1')::uuid)$q$, 'a second proposal of one proposer under approval while the limit is 1');
UPDATE events.event_setting SET max_open_proposals_per_proposer = 2;
SELECT events.submit_proposal(pg_temp.u('M'), pg_temp.acct('S1'));
SELECT pg_temp.ok((SELECT count(*) = 2 FROM events.v_proposal_status WHERE event_proposal_id IN (pg_temp.u('L'), pg_temp.u('M')) AND status = 'IN_PROGRESS'),
  'lead time cut to 7 days, sections made optional, limit raised to 2: both proposals go into approval');
SELECT pg_temp.rejects($q$SELECT pg_temp.draft('X', pg_temp.club(), 'S2', 'SEMINAR', 'x event', tsrange(pg_temp.day() + 7 + time '10:00', pg_temp.day() + 7 + time '12:00'),
  'INDIVIDUAL', NULL, NULL, 100, NULL, 21)$q$, '21 guest passes per participant while the ceiling is 20');
UPDATE events.event_setting SET max_extra_passes_per_participant = 25;
SELECT pg_temp.draft('N', pg_temp.club(), 'S2', 'SEMINAR', 'Open day', tsrange(pg_temp.day() + 7 + time '10:00', pg_temp.day() + 7 + time '12:00'), 'INDIVIDUAL', NULL, NULL, 100, NULL, 21);
SELECT pg_temp.ok((SELECT max_extra_passes = 21 FROM events.event_proposal WHERE id = pg_temp.u('N')), 'with the ceiling raised to 25 a proposal may ask for 21 guest passes');
-- publishing: what a published event must have
SELECT pg_temp.act(pg_temp.round_of('C2'), 'APPROVE', 'CCC1');
SELECT pg_temp.act(pg_temp.round_of('C2'), 'APPROVE', 'CCC2');
UPDATE events.event SET registration_window = tstzrange(now(), (pg_temp.day() + 2)::timestamptz) WHERE id = pg_temp.event_of('C2');
SELECT pg_temp.rejects($q$SELECT events.publish_event(pg_temp.event_of('C2'), md5('A-ADV')::uuid)$q$, 'publishing without descriptions, a contact person and a round while the settings require them');
UPDATE events.event_setting SET publish_needs_description = false, publish_needs_contact = false, publish_needs_round = false;
SELECT events.publish_event(pg_temp.event_of('C2'), pg_temp.acct('ADV'));
SELECT pg_temp.ok((SELECT published_at IS NOT NULL FROM events.event WHERE id = pg_temp.event_of('C2')), 'with those requirements switched off the same event is published');
-- the feedback scale
CREATE TEMP TABLE tok2 AS SELECT events.feedback_token_for(pg_temp.reg('S5')) AS t;
SELECT pg_temp.rejects($q$SELECT events.submit_feedback((SELECT t FROM tok2), 11)$q$, 'a rating of 11 on a scale of 1 to 10');
UPDATE events.event_setting SET feedback_rating_max = 12;
SELECT events.submit_feedback((SELECT t FROM tok2), 11);
SELECT pg_temp.ok((SELECT feedback_count = 2 FROM events.v_event_statistics WHERE event_id = pg_temp.event_of('Q')), 'with the scale widened to 12 the rating of 11 is taken');
SELECT pg_temp.rejects($q$UPDATE events.event_setting SET feedback_rating_max = 10$q$, 'cutting the scale below a rating already given');
-- points and tiers are dated / banded rows an administrator replaces
UPDATE events.event_type_points SET valid = daterange(lower(valid), current_date) WHERE event_type_id = pg_temp.lk('event_type','WORKSHOP') AND upper_inf(valid);
INSERT INTO events.event_type_points (event_type_id, points, valid) VALUES (pg_temp.lk('event_type','WORKSHOP'), 12, daterange(current_date, NULL));
SELECT pg_temp.ok((SELECT total_points = 5 FROM events.v_club_points WHERE club_org_unit_id = pg_temp.club())
              AND (SELECT points = 12 FROM events.event_type_points WHERE event_type_id = pg_temp.lk('event_type','WORKSHOP') AND valid @> current_date),
  'new point value for workshops from today (12); points already awarded keep the value in force when they were earned (5)');
-- who may change all this
SELECT pg_temp.ok((SELECT count(*) = 2 FROM authz.role_permission rp JOIN authz.role r ON r.id = rp.role_id AND r.code = 'EVENT_ADMIN'
                   JOIN authz.v_permission_code pc ON pc.permission_id = rp.permission_id AND pc.code IN ('events.setting.update', 'events.setting.view'))
              AND EXISTS (SELECT 1 FROM authz.v_role_closure c JOIN authz.role s ON s.id = c.role_id AND s.code = 'EVENT_ADMIN'
                          JOIN authz.role j ON j.id = c.effective_role_id AND j.code = 'EVENT_CCC_MEMBER')
              AND EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'events' AND entity_table = 'event_setting'),
  'the settings belong to the events administrator (who also holds points and tiers through the committee role); every change is audited');

-- ================= paid events: coupons, payments, refunds, expiry (event P) ===
-- (the settings above are still relaxed: sections optional, two open proposals, publishing needs only the window)
INSERT INTO authz.account_role (account_id, role_id, reason) SELECT pg_temp.acct('REG'), id, 'Events administrator' FROM authz.role WHERE code = 'EVENT_ADMIN';
INSERT INTO events.event_proposal (id, organising_org_unit_id, proposed_by_account_id, event_type_id, title, during, event_level_id, event_mode_id, theme, objective,
                                   participation_type_id, approx_capacity, capacity_fixed, is_paid, fee_individual)
VALUES (pg_temp.u('P'), pg_temp.club(), pg_temp.acct('S2'), pg_temp.lk('event_type','WORKSHOP'), 'Paid masterclass',
        tsrange(pg_temp.day() + 8 + time '10:00', pg_temp.day() + 8 + time '13:00'), pg_temp.lk('event_level','LEVEL_2'), pg_temp.lk('event_mode','OFFLINE'),
        'Skills', 'A paid session', pg_temp.lk('participation_type','INDIVIDUAL'), 3, 3, true, 500);
INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost, quantity)
VALUES (pg_temp.u('P'), pg_temp.lk('budget_item_type','REFRESHMENTS'), 'Tea', 1000, 1);
SELECT events.submit_proposal(pg_temp.u('P'), pg_temp.acct('S2'));
SELECT pg_temp.act(pg_temp.round_of('P'), 'APPROVE', 'ADV');
SELECT pg_temp.act(pg_temp.round_of('P'), 'APPROVE', 'CCC1');
SELECT pg_temp.act(pg_temp.round_of('P'), 'APPROVE', 'CCC2');
UPDATE events.event SET registration_window = tstzrange(now() - interval '1 minute', (pg_temp.day() + 7)::timestamptz),
       accepts_volunteer_applications = true, stall_applications_open = true, max_applied_stalls = 1 WHERE id = pg_temp.event_of('P');
SELECT events.publish_event(pg_temp.event_of('P'), pg_temp.acct('S2'));
INSERT INTO reg SELECT 'P3', events.register(pg_temp.event_of('P'), pg_temp.acct('S3'));
INSERT INTO reg SELECT 'P4', events.register(pg_temp.event_of('P'), pg_temp.acct('S4'));
INSERT INTO reg SELECT 'P5', events.register(pg_temp.event_of('P'), pg_temp.acct('S5'));
INSERT INTO reg SELECT 'P6', events.register(pg_temp.event_of('P'), pg_temp.acct('S6'));
SELECT pg_temp.ok(pg_temp.rstate('P3') = 'PENDING_PAYMENT' AND pg_temp.rstate('P6') = 'WAITLISTED'
              AND (SELECT amount_due = 500 AND amount_paid = 0 FROM events.v_registration WHERE registration_id = pg_temp.reg('P3')),
  'a paid event: a registration holds its seat but is PENDING_PAYMENT, owing the fee (500); the fourth is waitlisted');
-- coupons
SELECT pg_temp.rejects($q$INSERT INTO events.event_coupon (event_id, code, coupon_discount_type_id, discount_value, created_by_account_id)
  VALUES (pg_temp.event_of('C2'), 'FREE10', ref.id_of('coupon_discount_type','PERCENTAGE'), 10, md5('A-ADV')::uuid)$q$, 'a coupon on a free event');
SELECT pg_temp.rejects($q$INSERT INTO events.event_coupon (event_id, code, coupon_discount_type_id, discount_value, created_by_account_id)
  VALUES (pg_temp.event_of('P'), 'MINE', ref.id_of('coupon_discount_type','PERCENTAGE'), 10, md5('A-S3')::uuid)$q$, 'a coupon created by a participant');
SELECT pg_temp.rejects($q$INSERT INTO events.event_coupon (event_id, code, coupon_discount_type_id, discount_value, created_by_account_id)
  VALUES (pg_temp.event_of('P'), 'TOOMUCH', ref.id_of('coupon_discount_type','PERCENTAGE'), 150, md5('A-S2')::uuid)$q$, 'a discount of 150 per cent');
SELECT pg_temp.rejects($q$INSERT INTO events.event_coupon (event_id, code, coupon_discount_type_id, discount_value, max_discount, created_by_account_id)
  VALUES (pg_temp.event_of('P'), 'CAPPED', ref.id_of('coupon_discount_type','FIXED'), 50, 20, md5('A-S2')::uuid)$q$, 'a cap on a fixed-amount coupon');
INSERT INTO events.event_coupon (id, event_id, code, coupon_discount_type_id, discount_value, max_discount, max_uses, created_by_account_id) VALUES
 (pg_temp.u('CPN-E'), pg_temp.event_of('P'), ' early20 ', pg_temp.lk('coupon_discount_type','PERCENTAGE'), 20, 80, 1, pg_temp.acct('S2')),
 (pg_temp.u('CPN-F'), pg_temp.event_of('P'), 'FLAT', pg_temp.lk('coupon_discount_type','FIXED'), 499.50, NULL, NULL, pg_temp.acct('S2')),
 (pg_temp.u('CPN-A'), pg_temp.event_of('P'), 'FULL', pg_temp.lk('coupon_discount_type','PERCENTAGE'), 100, NULL, NULL, pg_temp.acct('S2'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_coupon (event_id, code, coupon_discount_type_id, discount_value, created_by_account_id)
  VALUES (pg_temp.event_of('P'), 'Early20', ref.id_of('coupon_discount_type','FIXED'), 5, md5('A-S2')::uuid)$q$, 'the same coupon code twice for one event (codes are case-insensitive)');
SELECT pg_temp.rejects($q$SELECT events.redeem_coupon(pg_temp.reg('P3'), 'EARLY20', md5('A-S4')::uuid)$q$, 'a coupon applied to someone else''s registration');
SELECT pg_temp.rejects($q$SELECT events.redeem_coupon(pg_temp.reg('P3'), 'NOSUCH', md5('A-S3')::uuid)$q$, 'an unknown coupon code');
CREATE TEMP TABLE res (k text PRIMARY KEY, n numeric);      -- results of calls that change data, kept apart from the checks on them
INSERT INTO res SELECT 'CPN3', events.redeem_coupon(pg_temp.reg('P3'), 'early20', pg_temp.acct('S3'));
SELECT pg_temp.ok((SELECT n = 80 FROM res WHERE k = 'CPN3') AND events.amount_due(pg_temp.reg('P3')) = 420
              AND (SELECT code = 'EARLY20' FROM events.event_coupon WHERE id = pg_temp.u('CPN-E')),
  'a 20 % coupon capped at 80 takes 80 off the 500 fee; the code is stored trimmed and upper-cased');
SELECT pg_temp.rejects($q$SELECT events.redeem_coupon(pg_temp.reg('P3'), 'FLAT', md5('A-S3')::uuid)$q$, 'a second coupon on one registration');
SELECT pg_temp.rejects($q$SELECT events.redeem_coupon(pg_temp.reg('P4'), 'EARLY20', md5('A-S4')::uuid)$q$, 'a coupon used beyond its limit (1 use)');
INSERT INTO res SELECT 'CPN4', events.redeem_coupon(pg_temp.reg('P4'), 'FLAT', pg_temp.acct('S4'));
SELECT pg_temp.ok((SELECT n = 499 FROM res WHERE k = 'CPN4') AND events.amount_due(pg_temp.reg('P4')) = 1,
  'a coupon may not leave an unpayable remainder: 499.50 off 500 becomes 499, leaving the minimum payable amount (1 — a setting)');
INSERT INTO res SELECT 'CPN5', events.redeem_coupon(pg_temp.reg('P5'), 'FULL', pg_temp.acct('S5'));
SELECT pg_temp.ok((SELECT n = 500 FROM res WHERE k = 'CPN5') AND pg_temp.rstate('P5') = 'CONFIRMED',
  'a 100 % coupon leaves nothing to pay: the registration is CONFIRMED without a payment');
SELECT pg_temp.ok((SELECT uses = 1 AND uses_left = 0 AND discount_total = 80 FROM events.v_coupon_usage WHERE event_coupon_id = pg_temp.u('CPN-E')), 'coupon usage is derived');
SELECT pg_temp.rejects($q$DELETE FROM events.event_coupon WHERE id = md5('CPN-E')::uuid$q$, 'deleting a coupon that was used');
-- online payment: order, retry, capture
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
  VALUES (pg_temp.reg('P3'), 500, ref.id_of('payment_channel','GATEWAY'), ref.id_of('payment_status','CREATED'), 'order_0')$q$, 'an order for 500 when 420 is due');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id)
  VALUES (pg_temp.reg('P3'), 420, ref.id_of('payment_channel','GATEWAY'), ref.id_of('payment_status','CREATED'))$q$, 'an online payment without the gateway''s order id');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
  VALUES (pg_temp.reg('P3'), 420, ref.id_of('payment_channel','GATEWAY'), ref.id_of('payment_status','CAPTURED'), 'order_0')$q$, 'an online payment that starts as paid');
INSERT INTO events.event_payment (id, registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
VALUES (pg_temp.u('PAY-1'), pg_temp.reg('P3'), 420, pg_temp.lk('payment_channel','GATEWAY'), pg_temp.lk('payment_status','CREATED'), 'order_1');
INSERT INTO events.event_payment (id, registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
VALUES (pg_temp.u('PAY-2'), pg_temp.reg('P3'), 420, pg_temp.lk('payment_channel','GATEWAY'), pg_temp.lk('payment_status','CREATED'), 'order_2');
SELECT pg_temp.ok((SELECT superseded_at IS NOT NULL AND failed_at IS NOT NULL AND payment_status_id = pg_temp.lk('payment_status','FAILED') AND currency_code = 'INR'
                          AND receipt_no ~ '^RCP-[0-9]{4}-[0-9]{6}$' FROM events.event_payment WHERE id = pg_temp.u('PAY-1'))
              AND pg_temp.rstate('P3') = 'PENDING_PAYMENT',
  'one open order at a time: a second order supersedes the first; receipts are numbered and carry the currency of the settings');
UPDATE events.event_payment SET payment_status_id = pg_temp.lk('payment_status','CAPTURED'), gateway_payment_id = 'pay_2', webhook_verified = true, attempts = 1 WHERE id = pg_temp.u('PAY-2');
SELECT pg_temp.ok(pg_temp.rstate('P3') = 'CONFIRMED' AND (SELECT amount_paid = 420 FROM events.v_registration WHERE registration_id = pg_temp.reg('P3'))
              AND (SELECT captured_at IS NOT NULL FROM events.event_payment WHERE id = pg_temp.u('PAY-2'))
              AND (SELECT fees_collected = 420 FROM events.v_event_statistics WHERE event_id = pg_temp.event_of('P')),
  'the captured payment confirms the registration: paid and fees collected are derived from the payments');
SELECT pg_temp.rejects($q$UPDATE events.event_payment SET payment_status_id = ref.id_of('payment_status','FAILED') WHERE id = md5('PAY-2')::uuid$q$, 'a captured payment marked failed');
SELECT pg_temp.rejects($q$UPDATE events.event_payment SET amount = 1 WHERE id = md5('PAY-2')::uuid$q$, 'changing the amount of a payment');
SELECT pg_temp.rejects($q$DELETE FROM events.event_payment WHERE id = md5('PAY-1')::uuid$q$, 'deleting a payment');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, gateway_order_id)
  VALUES (pg_temp.reg('P3'), 420, ref.id_of('payment_channel','GATEWAY'), ref.id_of('payment_status','CREATED'), 'order_3')$q$, 'a new order when nothing is due any more');
SELECT pg_temp.rejects($q$DELETE FROM events.coupon_redemption WHERE registration_id = pg_temp.reg('P3')$q$, 'removing a coupon after the fee was paid with it');
-- the gateway later reports the superseded order as captured too: the money must go back
UPDATE events.event_payment SET payment_status_id = pg_temp.lk('payment_status','CAPTURED'), gateway_payment_id = 'pay_1' WHERE id = pg_temp.u('PAY-1');
SELECT pg_temp.ok((SELECT count(*) = 1 AND bool_and(reason = 'SUPERSEDED_ORDER' AND event_payment_id = pg_temp.u('PAY-1')) FROM events.v_refund_queue WHERE event_id = pg_temp.event_of('P')),
  'a payment captured on a superseded order appears in the refund queue (derived, nothing flagged by hand)');
SELECT pg_temp.rejects($q$SELECT events.record_refund(md5('PAY-1')::uuid, md5('A-S2')::uuid, 'rfnd_1')$q$, 'a refund recorded by an organiser without the refund right');
SELECT pg_temp.rejects($q$UPDATE events.event_payment SET payment_status_id = ref.id_of('payment_status','REFUNDED'), refund_recorded_by_account_id = md5('A-REG')::uuid WHERE id = md5('PAY-1')::uuid$q$, 'a refund without its reference');
SELECT events.record_refund(pg_temp.u('PAY-1'), pg_temp.acct('REG'), 'rfnd_1', 'Duplicate order');
SELECT pg_temp.ok((SELECT refunded_at IS NOT NULL FROM events.event_payment WHERE id = pg_temp.u('PAY-1'))
              AND NOT EXISTS (SELECT 1 FROM events.v_refund_queue WHERE event_id = pg_temp.event_of('P'))
              AND events.amount_settled(pg_temp.reg('P3')) = 420, 'the events administrator records the refund: the queue is empty and the registration still paid once');
SELECT pg_temp.rejects($q$SELECT events.record_refund(md5('PAY-1')::uuid, md5('A-REG')::uuid, 'rfnd_2')$q$, 'refunding a refunded payment again');
-- offline payment: claimed by the payer, verified by an organiser
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, payment_reference, recorded_by_account_id)
  VALUES (pg_temp.reg('P4'), 1, ref.id_of('payment_channel','UPI'), ref.id_of('payment_status','CREATED'), 'UPI-1', md5('A-S5')::uuid)$q$, 'an offline payment claimed by a stranger');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, recorded_by_account_id)
  VALUES (pg_temp.reg('P4'), 1, ref.id_of('payment_channel','UPI'), ref.id_of('payment_status','CREATED'), md5('A-S4')::uuid)$q$, 'an offline claim without its transaction reference');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, payment_reference, recorded_by_account_id)
  VALUES (pg_temp.reg('P4'), 1, ref.id_of('payment_channel','CASH'), ref.id_of('payment_status','CAPTURED'), 'cash', md5('A-S4')::uuid)$q$, 'the payer recording their own cash as received');
INSERT INTO events.event_payment (id, registration_id, amount, payment_channel_id, payment_status_id, payment_reference, recorded_by_account_id)
VALUES (pg_temp.u('PAY-4'), pg_temp.reg('P4'), 1, pg_temp.lk('payment_channel','UPI'), pg_temp.lk('payment_status','CREATED'), 'UPI-778899', pg_temp.acct('S4'));
SELECT pg_temp.rejects($q$UPDATE events.event_payment SET payment_status_id = ref.id_of('payment_status','CAPTURED'), verified_by_account_id = md5('A-S4')::uuid WHERE id = md5('PAY-4')::uuid$q$, 'an offline payment verified by the payer');
UPDATE events.event_payment SET payment_status_id = pg_temp.lk('payment_status','CAPTURED'), verified_by_account_id = pg_temp.acct('S2') WHERE id = pg_temp.u('PAY-4');
SELECT pg_temp.ok(pg_temp.rstate('P4') = 'CONFIRMED', 'an offline payment counts once an organiser has verified it');
-- a paid registration is cancelled: its payment is owed back; the waiting list moves up
UPDATE events.event_registration SET cancelled_at = now(), cancelled_by_account_id = pg_temp.acct('S2'), registration_cancel_reason_id = pg_temp.lk('registration_cancel_reason','ORGANISER') WHERE id = pg_temp.reg('P3');
INSERT INTO res SELECT 'PROMO', events.promote_waitlist(pg_temp.event_of('P'));
SELECT pg_temp.ok((SELECT reason = 'REGISTRATION_CANCELLED' AND amount = 420 FROM events.v_refund_queue WHERE event_payment_id = pg_temp.u('PAY-2'))
              AND (SELECT n = 1 FROM res WHERE k = 'PROMO') AND (SELECT uses = 0 FROM events.v_coupon_usage WHERE event_coupon_id = pg_temp.u('CPN-E')),
  'cancelling a paid registration puts its payment in the refund queue, frees its coupon use and its seat');
-- unpaid registrations expire (a setting; off by default)
SELECT pg_temp.rejects($q$SELECT events.expire_unpaid_registrations()$q$, 'the expiry job run outside a system job');
SET LOCAL app.system_job = 'on';
INSERT INTO res SELECT 'EXP0', events.expire_unpaid_registrations();
SELECT pg_temp.ok((SELECT n = 0 FROM res WHERE k = 'EXP0') AND pg_temp.rstate('P6') = 'PENDING_PAYMENT', 'with no expiry configured nothing expires');
UPDATE events.event_setting SET unpaid_registration_expiry = interval '1 millisecond';
SELECT pg_temp.ok(events.expire_unpaid_registrations() = 1, 'with an expiry configured the unpaid registration is cancelled by the job');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok(pg_temp.rstate('P6') = 'CANCELLED' AND pg_temp.rstate('P4') = 'CONFIRMED'
              AND (SELECT c.code = 'UNPAID' FROM events.event_registration r JOIN ref.registration_cancel_reason c ON c.id = r.registration_cancel_reason_id WHERE r.id = pg_temp.reg('P6')),
  'expired with the reason UNPAID; paid registrations are untouched');
UPDATE events.event_setting SET unpaid_registration_expiry = NULL;

-- ============================ a paid team event: one fee, paid by the leader ===
INSERT INTO events.event_proposal (id, organising_org_unit_id, proposed_by_account_id, event_type_id, title, during, event_level_id, event_mode_id, theme, objective,
                                   participation_type_id, min_team_size, max_team_size, approx_capacity, is_paid, fee_team)
VALUES (pg_temp.u('T'), pg_temp.club(), pg_temp.acct('S2'), pg_temp.lk('event_type','COMPETITION'), 'Paid team quiz',
        tsrange(pg_temp.day() + 9 + time '10:00', pg_temp.day() + 9 + time '13:00'), pg_temp.lk('event_level','LEVEL_2'), pg_temp.lk('event_mode','OFFLINE'),
        'Quiz', 'A paid team event', pg_temp.lk('participation_type','TEAM'), 2, 2, 20, true, 300);
INSERT INTO events.proposal_budget_item (event_proposal_id, budget_item_type_id, description, unit_cost, quantity)
VALUES (pg_temp.u('T'), pg_temp.lk('budget_item_type','REFRESHMENTS'), 'Tea', 500, 1);
SELECT events.submit_proposal(pg_temp.u('T'), pg_temp.acct('S2'));
SELECT pg_temp.act(pg_temp.round_of('T'), 'APPROVE', 'ADV');
SELECT pg_temp.act(pg_temp.round_of('T'), 'APPROVE', 'CCC1');
SELECT pg_temp.act(pg_temp.round_of('T'), 'APPROVE', 'CCC2');
UPDATE events.event SET registration_window = tstzrange(now() - interval '1 minute', (pg_temp.day() + 8)::timestamptz) WHERE id = pg_temp.event_of('T');
SELECT events.publish_event(pg_temp.event_of('T'), pg_temp.acct('S2'));
INSERT INTO reg SELECT 'T3', events.register(pg_temp.event_of('T'), pg_temp.acct('S3'));
INSERT INTO reg SELECT 'T4', events.register(pg_temp.event_of('T'), pg_temp.acct('S4'));
INSERT INTO events.event_team (id, event_id, name, leader_registration_id) VALUES (pg_temp.u('TEAM-T'), pg_temp.event_of('T'), 'Payers', pg_temp.reg('T3'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, recorded_by_account_id)
  VALUES (pg_temp.reg('T3'), 300, ref.id_of('payment_channel','CASH'), ref.id_of('payment_status','CAPTURED'), md5('A-S2')::uuid)$q$, 'a team fee paid before the team is complete');
INSERT INTO events.team_invitation (id, event_team_id, invitee_registration_id) VALUES (pg_temp.u('INV-T4'), pg_temp.u('TEAM-T'), pg_temp.reg('T4'));
UPDATE events.team_invitation SET responded_at = now(), is_accepted = true WHERE id = pg_temp.u('INV-T4');
SELECT pg_temp.ok(pg_temp.rstate('T3') = 'PENDING_PAYMENT' AND pg_temp.rstate('T4') = 'PENDING_PAYMENT'
              AND events.amount_due(pg_temp.reg('T3')) = 300 AND events.amount_due(pg_temp.reg('T4')) = 0,
  'a complete team owes one flat fee, and it is the leader who owes it');
SELECT pg_temp.rejects($q$INSERT INTO events.event_payment (registration_id, amount, payment_channel_id, payment_status_id, recorded_by_account_id)
  VALUES (pg_temp.reg('T4'), 300, ref.id_of('payment_channel','CASH'), ref.id_of('payment_status','CAPTURED'), md5('A-S2')::uuid)$q$, 'the team fee paid by a member who is not the leader');
INSERT INTO events.event_payment (id, registration_id, amount, payment_channel_id, payment_status_id, recorded_by_account_id)
VALUES (pg_temp.u('PAY-T'), pg_temp.reg('T3'), 300, pg_temp.lk('payment_channel','CASH'), pg_temp.lk('payment_status','CAPTURED'), pg_temp.acct('S2'));
SELECT pg_temp.ok(pg_temp.rstate('T3') = 'CONFIRMED' AND pg_temp.rstate('T4') = 'CONFIRMED'
              AND (SELECT event_team_id = pg_temp.u('TEAM-T') AND captured_at IS NOT NULL AND verified_by_account_id = pg_temp.acct('S2') FROM events.event_payment WHERE id = pg_temp.u('PAY-T')),
  'cash received by an organiser for the team confirms every member; the payment names the team');

-- ======================================================== volunteer sign-up ===
SELECT pg_temp.rejects($q$INSERT INTO events.volunteer_application (event_id, person_id) VALUES (pg_temp.event_of('C2'), md5('P-S6')::uuid)$q$, 'a volunteer application to an event that takes none');
SELECT pg_temp.rejects($q$INSERT INTO events.volunteer_application (event_id, person_id) VALUES (pg_temp.event_of('P'), md5('P-GUEST')::uuid)$q$, 'a volunteer application from someone outside the university');
INSERT INTO events.volunteer_application (id, event_id, person_id, note) VALUES (pg_temp.u('VAPP'), pg_temp.event_of('P'), pg_temp.u('P-S6'), 'Happy to help at the desk');
SELECT pg_temp.rejects($q$INSERT INTO events.volunteer_application (event_id, person_id) VALUES (pg_temp.event_of('P'), md5('P-S6')::uuid)$q$, 'a second application for the same event');
SELECT pg_temp.rejects($q$UPDATE events.volunteer_application SET decided_at = now(), decided_by_account_id = md5('A-S5')::uuid, is_accepted = true WHERE id = md5('VAPP')::uuid$q$, 'a volunteer application decided by a participant');
UPDATE events.volunteer_application SET decided_at = now(), decided_by_account_id = pg_temp.acct('S2'), is_accepted = true WHERE id = pg_temp.u('VAPP');
SELECT pg_temp.ok((SELECT volunteer_role = 'VOLUNTEER' AND NOT can_scan AND is_active FROM events.v_volunteer_assignment WHERE person_id = pg_temp.u('P-S6') AND event_id = pg_temp.event_of('P')),
  'an accepted application makes the volunteer (scanning and the gate are then given by the organisers)');
SELECT pg_temp.rejects($q$UPDATE events.volunteer_application SET decision_note = 'changed' WHERE id = md5('VAPP')::uuid$q$, 'changing a decided volunteer application');

-- =================================================================== stalls ===
INSERT INTO events.event_stall_fee (event_id, stall_category_id, fee) VALUES (pg_temp.event_of('P'), pg_temp.lk('stall_category','STANDARD'), 200);
SELECT pg_temp.rejects($q$INSERT INTO events.stall_application (event_id, applicant_person_id, stall_name, stall_type_id, stall_category_id, stall_size_id, declarations_accepted_at)
  VALUES (pg_temp.event_of('C2'), md5('P-S5')::uuid, 'Chai', ref.id_of('stall_type','FOOD'), ref.id_of('stall_category','STANDARD'), ref.id_of('stall_size','SIZE_6X6'), now())$q$, 'a stall application to an event that takes none');
SELECT pg_temp.rejects($q$INSERT INTO events.stall_application (event_id, applicant_person_id, stall_name, stall_type_id, stall_category_id, stall_size_id, declarations_accepted_at)
  VALUES (pg_temp.event_of('P'), md5('P-S5')::uuid, 'Chai', ref.id_of('stall_type','FOOD'), ref.id_of('stall_category','STANDARD'), ref.id_of('stall_size','CUSTOM'), now())$q$, 'a custom stall size that is not described');
SELECT pg_temp.rejects($q$INSERT INTO events.stall_application (event_id, applicant_person_id, stall_name, stall_type_id, stall_category_id, stall_size_id)
  VALUES (pg_temp.event_of('P'), md5('P-S5')::uuid, 'Chai', ref.id_of('stall_type','FOOD'), ref.id_of('stall_category','STANDARD'), ref.id_of('stall_size','SIZE_6X6'))$q$, 'a stall application without the declarations accepted');
INSERT INTO events.stall_application (id, event_id, applicant_person_id, stall_name, stall_type_id, stall_category_id, stall_size_id, is_selling, price_range, electricity_required, declarations_accepted_at)
VALUES (pg_temp.u('SAPP'), pg_temp.event_of('P'), pg_temp.u('P-S5'), 'Chai corner', pg_temp.lk('stall_type','FOOD'), pg_temp.lk('stall_category','STANDARD'), pg_temp.lk('stall_size','SIZE_6X6'),
        true, numrange(10, 60), true, now());
INSERT INTO events.stall_application_setup (stall_application_id, stall_setup_id) VALUES (pg_temp.u('SAPP'), pg_temp.lk('stall_setup','WATER_SUPPLY'));
SELECT pg_temp.rejects($q$INSERT INTO events.stall_application (event_id, applicant_person_id, stall_name, stall_type_id, stall_category_id, stall_size_id, declarations_accepted_at)
  VALUES (pg_temp.event_of('P'), md5('P-S6')::uuid, 'Books', ref.id_of('stall_type','PRODUCT'), ref.id_of('stall_category','STANDARD'), ref.id_of('stall_size','SIZE_6X6'), now())$q$, 'more stall applications than the event takes (1)');
SELECT pg_temp.rejects($q$UPDATE events.stall_application SET decided_at = now(), decided_by_account_id = md5('A-S5')::uuid, is_approved = true WHERE id = md5('SAPP')::uuid$q$, 'a stall application approved by its applicant');
SELECT pg_temp.rejects($q$UPDATE events.stall_application SET decided_at = now(), decided_by_account_id = md5('A-S2')::uuid, is_approved = false WHERE id = md5('SAPP')::uuid$q$, 'a stall application rejected without a reason');
INSERT INTO events.event_payment (id, stall_application_id, amount, payment_channel_id, payment_status_id, payment_reference, recorded_by_account_id, proof_file_id)
VALUES (pg_temp.u('PAY-S'), pg_temp.u('SAPP'), 200, pg_temp.lk('payment_channel','BANK_TRANSFER'), pg_temp.lk('payment_status','CREATED'), 'NEFT-4411', pg_temp.acct('S5'), pg_temp.u('F-REPORT'));
UPDATE events.event_payment SET payment_status_id = pg_temp.lk('payment_status','CAPTURED'), verified_by_account_id = pg_temp.acct('S2') WHERE id = pg_temp.u('PAY-S');
UPDATE events.stall_application SET decided_at = now(), decided_by_account_id = pg_temp.acct('S2'), is_approved = true WHERE id = pg_temp.u('SAPP');
SELECT pg_temp.ok((SELECT status = 'APPROVED' AND fee = 200 AND fee_paid = 200 AND stall_code ~ '^ST[0-9]{5}$' FROM events.v_stall_application WHERE stall_application_id = pg_temp.u('SAPP'))
              AND (SELECT v.owner_person_id = pg_temp.u('P-S5') AND v.stall_name = 'Chai corner' AND v.electricity_required AND v.stall_type = 'FOOD' AND s.stall_name IS NULL
                   FROM events.v_stall v JOIN events.event_stall s ON s.id = v.event_stall_id WHERE s.stall_application_id = pg_temp.u('SAPP')),
  'the stall fee (per category, 200) is paid by transfer and verified; approval creates the stall ST<number> for its applicant — it points at the application and repeats none of it');
SELECT pg_temp.rejects($q$INSERT INTO events.event_stall (event_id, stall_application_id, stall_name, created_by_account_id) VALUES (pg_temp.event_of('P'), md5('SAPP')::uuid, 'Copy', md5('A-S2')::uuid)$q$, 'a second stall, or a described one, for an application');
SELECT pg_temp.rejects($q$INSERT INTO events.stall_application_setup (stall_application_id, stall_setup_id) VALUES (md5('SAPP')::uuid, ref.id_of('stall_setup','CANOPY'))$q$, 'changing a decided stall application');
SELECT pg_temp.rejects($q$UPDATE events.event_stall SET stall_name = 'Tea palace' WHERE stall_application_id = md5('SAPP')::uuid$q$, 'renaming a stall that came from an application');
UPDATE events.event_stall SET location = 'Row B-4' WHERE stall_application_id = pg_temp.u('SAPP');
SELECT pg_temp.rejects($q$INSERT INTO events.event_stall (event_id, stall_name, created_by_account_id) VALUES (pg_temp.event_of('P'), 'Rogue stall', md5('A-S4')::uuid)$q$, 'a stall set up by a participant');
INSERT INTO events.event_stall (id, event_id, stall_name, stall_type_id, created_by_account_id) VALUES (pg_temp.u('STALL-H'), pg_temp.event_of('P'), 'Help desk', pg_temp.lk('stall_type','INFORMATION'), pg_temp.acct('S2'));
INSERT INTO events.event_stall_product (event_stall_id, name) VALUES (pg_temp.u('STALL-H'), 'Programme booklet');
CREATE FUNCTION pg_temp.stall_code() RETURNS text LANGUAGE sql STABLE AS $$ SELECT stall_code::text FROM events.event_stall WHERE stall_application_id = md5('SAPP')::uuid $$;
SELECT pg_temp.rejects($q$INSERT INTO events.stall_feedback (event_stall_id, comment) VALUES (md5('STALL-H')::uuid, 'direct')$q$, 'stall feedback written directly');
SELECT pg_temp.rejects($q$SELECT events.submit_stall_feedback('ST00000', ARRAY[5])$q$, 'feedback on an unknown stall');
SELECT pg_temp.rejects($q$SELECT events.submit_stall_feedback(pg_temp.stall_code(), ARRAY[13])$q$, 'a stall score above the feedback scale (1 to 12 now)');
SELECT pg_temp.rejects($q$SELECT events.submit_stall_feedback(pg_temp.stall_code(), ARRAY[5,5,5,5,5,5,5,5,5,5,5])$q$, 'eleven scores when at most ten are taken');
SELECT events.submit_stall_feedback(pg_temp.stall_code(), ARRAY[9, 7], 'Good tea');
SELECT pg_temp.ok((SELECT feedback_count = 1 AND feedback_avg = 8.00 AND from_application AND location = 'Row B-4' FROM events.v_stall WHERE stall_code = pg_temp.stall_code()::citext)
              AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'events' AND table_name = 'stall_feedback' AND column_name ~ 'person|account|registration')
              AND (SELECT stalls = 2 FROM events.v_event_statistics WHERE event_id = pg_temp.event_of('P')),
  'public stall feedback: two scores averaged (8.00), no column that could identify the visitor; the event counts two stalls');
SELECT pg_temp.rejects($q$DELETE FROM events.event_stall WHERE stall_application_id = md5('SAPP')::uuid$q$, 'deleting a stall that came from an application');

-- ============================================== messages to the registrants ===
-- event P now has four registrations (two confirmed, two cancelled): 3 credits each = 12
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail (event_id, subject, body, mail_audience_id, created_by_account_id)
  VALUES (pg_temp.event_of('P'), 'Hello', 'x', ref.id_of('mail_audience','ALL'), md5('A-S4')::uuid)$q$, 'a message to the registrants written by a participant');
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail (event_id, subject, body, mail_audience_id, created_by_account_id)
  VALUES (pg_temp.event_of('P'), E'Two\nlines', 'x', ref.id_of('mail_audience','ALL'), md5('A-S2')::uuid)$q$, 'a subject of two lines');
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail (event_id, subject, body, mail_audience_id, created_by_account_id, scheduled_at)
  VALUES (pg_temp.event_of('P'), 'Late', 'x', ref.id_of('mail_audience','ALL'), md5('A-S2')::uuid, now() - interval '1 hour')$q$, 'a message scheduled in the past');
INSERT INTO events.event_mail (id, event_id, subject, body, mail_audience_id, created_by_account_id)
VALUES (pg_temp.u('MAIL1'), pg_temp.event_of('P'), 'Venue details', 'See you in Block VA.', pg_temp.lk('mail_audience','CONFIRMED'), pg_temp.acct('S2'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail_recipient (event_mail_id, registration_id, mail_delivery_status_id) VALUES (md5('MAIL1')::uuid, pg_temp.reg('P3'), ref.id_of('mail_delivery_status','QUEUED'))$q$, 'hand-picking recipients of a message that goes to an audience');
SELECT pg_temp.rejects($q$SELECT events.dispatch_mail(md5('MAIL1')::uuid, md5('A-S4')::uuid)$q$, 'a message sent by a participant');
SELECT pg_temp.ok(events.dispatch_mail(pg_temp.u('MAIL1'), pg_temp.acct('S2')) = 2, 'sending to the confirmed participants resolves two recipients');
SELECT pg_temp.rejects($q$SELECT events.dispatch_mail(md5('MAIL1')::uuid, md5('A-S2')::uuid)$q$, 'sending a message twice');
SELECT pg_temp.rejects($q$UPDATE events.event_mail SET body = 'changed' WHERE id = md5('MAIL1')::uuid$q$, 'editing a message once sending has started');
SELECT pg_temp.ok((SELECT status = 'SENDING' AND recipients = 2 AND queued = 2 FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL1'))
              AND (SELECT total = 12 AND used = 2 AND available = 10 FROM events.v_event_mail_credit WHERE event_id = pg_temp.event_of('P')),
  'each recipient takes one credit: 12 allowed (3 per registration — a setting), 2 used');
UPDATE events.event_mail_recipient SET mail_delivery_status_id = pg_temp.lk('mail_delivery_status','DELIVERED') WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P4');
UPDATE events.event_mail_recipient SET mail_delivery_status_id = pg_temp.lk('mail_delivery_status','FAILED'), failure_reason = 'mailbox full' WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P5');
SELECT pg_temp.ok((SELECT status = 'PARTIAL' AND delivered = 1 AND failed = 1 FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL1'))
              AND (SELECT used = 1 FROM events.v_event_mail_credit WHERE event_id = pg_temp.event_of('P'))
              AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'events' AND table_name = 'event_mail_recipient' AND column_name ~ 'email|address'),
  'one delivered, one failed: the message is PARTIAL and the failed delivery gives its credit back; no address is stored');
SELECT pg_temp.rejects($q$UPDATE events.event_mail_recipient SET mail_delivery_status_id = ref.id_of('mail_delivery_status','DELIVERED') WHERE event_mail_id = md5('MAIL1')::uuid AND registration_id = pg_temp.reg('P5')$q$, 'changing a final delivery outcome');
-- opens are tracked only when the setting is on
SELECT events.mail_opened((SELECT id FROM events.event_mail_recipient WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P4')));
SELECT pg_temp.ok((SELECT open_count = 0 FROM events.event_mail_recipient WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P4')), 'with open tracking off (the default) an open is not recorded');
UPDATE events.event_setting SET mail_open_tracking = true;
SELECT events.mail_opened((SELECT id FROM events.event_mail_recipient WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P4')));
SELECT pg_temp.ok((SELECT open_count = 1 AND first_opened_at IS NOT NULL FROM events.event_mail_recipient WHERE event_mail_id = pg_temp.u('MAIL1') AND registration_id = pg_temp.reg('P4'))
              AND (SELECT opened = 1 FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL1')), 'with open tracking switched on the open is counted');
-- a hand-picked selection
INSERT INTO events.event_mail (id, event_id, subject, body, mail_audience_id, created_by_account_id)
VALUES (pg_temp.u('MAIL2'), pg_temp.event_of('P'), 'About your refund', 'It is on its way.', pg_temp.lk('mail_audience','SELECTED'), pg_temp.acct('S2'));
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail_recipient (event_mail_id, registration_id, mail_delivery_status_id) VALUES (md5('MAIL2')::uuid, pg_temp.reg('S3'), ref.id_of('mail_delivery_status','QUEUED'))$q$, 'a recipient who registered for another event');
SELECT pg_temp.rejects($q$SELECT events.dispatch_mail(md5('MAIL2')::uuid, md5('A-S2')::uuid)$q$, 'sending a selection with nobody selected');
INSERT INTO events.event_mail_recipient (event_mail_id, registration_id, mail_delivery_status_id) VALUES (pg_temp.u('MAIL2'), pg_temp.reg('P3'), pg_temp.lk('mail_delivery_status','QUEUED'));
SELECT pg_temp.ok(events.dispatch_mail(pg_temp.u('MAIL2'), pg_temp.acct('S2')) = 1, 'a selection goes to exactly the registrations picked');
-- scheduled, then cancelled
INSERT INTO events.event_mail (id, event_id, subject, body, mail_audience_id, created_by_account_id, scheduled_at)
VALUES (pg_temp.u('MAIL3'), pg_temp.event_of('P'), 'Reminder', 'Tomorrow at 10.', pg_temp.lk('mail_audience','ALL'), pg_temp.acct('S2'), now() + interval '1 hour');
SELECT pg_temp.rejects($q$SELECT events.dispatch_mail(md5('MAIL3')::uuid, md5('A-S2')::uuid)$q$, 'sending a scheduled message before its time');
UPDATE events.event_mail SET cancelled_at = now(), cancelled_by_account_id = pg_temp.acct('S2') WHERE id = pg_temp.u('MAIL3');
SELECT pg_temp.ok((SELECT status = 'CANCELLED' FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL3')), 'a scheduled message can be cancelled until sending starts');
-- credits run out; an administrator tops them up
UPDATE events.event_setting SET mail_credits_per_registration = 0;
INSERT INTO events.event_mail (id, event_id, subject, body, mail_audience_id, created_by_account_id)
VALUES (pg_temp.u('MAIL4'), pg_temp.event_of('P'), 'Thank you', 'Thanks for coming.', pg_temp.lk('mail_audience','ALL'), pg_temp.acct('S2'));
SELECT pg_temp.rejects($q$SELECT events.dispatch_mail(md5('MAIL4')::uuid, md5('A-S2')::uuid)$q$, 'sending with no mail credits left');
SELECT pg_temp.rejects($q$INSERT INTO events.event_mail_credit_grant (event_id, credits, reason, granted_by_account_id) VALUES (pg_temp.event_of('P'), 10, 'more', md5('A-S2')::uuid)$q$, 'extra credits granted by an organiser to their own event');
INSERT INTO events.event_mail_credit_grant (event_id, credits, reason, granted_by_account_id) VALUES (pg_temp.event_of('P'), 10, 'Large event', pg_temp.acct('REG'));
INSERT INTO res SELECT 'MAIL4', events.dispatch_mail(pg_temp.u('MAIL4'), pg_temp.acct('S2'));
SELECT pg_temp.ok((SELECT n = 4 FROM res WHERE k = 'MAIL4')
              AND (SELECT granted = 10 AND total = 10 AND used = 6 AND available = 4 FROM events.v_event_mail_credit WHERE event_id = pg_temp.event_of('P')),
  'with the allowance set to 0 and 10 credits granted by the administrator, the message to all four goes out');
-- the scheduler sends what is due and fails what cannot be sent
INSERT INTO events.event_mail (id, event_id, subject, body, mail_audience_id, created_by_account_id, scheduled_at) VALUES
 (pg_temp.u('MAIL5'), pg_temp.event_of('P'), 'Photos', 'The photos are up.', pg_temp.lk('mail_audience','CONFIRMED'), pg_temp.acct('S2'), clock_timestamp() + interval '1 second'),
 (pg_temp.u('MAIL6'), pg_temp.event_of('P'), 'Nobody', 'Nobody selected.', pg_temp.lk('mail_audience','SELECTED'), pg_temp.acct('S2'), clock_timestamp() + interval '1 second');
SELECT pg_temp.rejects($q$SELECT events.run_mail_scheduler()$q$, 'the mail scheduler run outside a system job');
SELECT pg_sleep(1.2);
SET LOCAL app.system_job = 'on';
SELECT pg_temp.ok(events.run_mail_scheduler() = 1, 'the scheduler sends the message that is due');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok((SELECT status = 'SENDING' AND recipients = 2 FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL5'))
              AND (SELECT status = 'FAILED' AND failure_reason ~ 'no recipients' FROM events.v_event_mail WHERE event_mail_id = pg_temp.u('MAIL6')),
  'the due message is on its way; the one that cannot be sent is marked FAILED with the reason');

-- ===================================== club change requests and primary club ===
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, new_name, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','NAME_CHANGE'), 'x', 'Hack Club', md5('A-S5')::uuid)$q$, 'a club change requested by a student who holds no office');
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','NAME_CHANGE'), 'x', md5('A-S1')::uuid)$q$, 'a name change without the new name');
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, new_name, new_objective, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','NAME_CHANGE'), 'x', 'Hack Club', repeat('y', 60), md5('A-S1')::uuid)$q$, 'a name change that also changes the objective');
INSERT INTO events.club_change_request (id, club_org_unit_id, club_change_type_id, justification, new_name, requested_by_account_id)
VALUES (pg_temp.u('CCR1'), pg_temp.club(), pg_temp.lk('club_change_type','NAME_CHANGE'), 'We now build robots too', 'Coding & Robotics Club', pg_temp.acct('S1'));
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_officer (club_change_request_id, club_office_id, student_id) VALUES (md5('CCR1')::uuid, ref.id_of('club_office','PRESIDENT'), md5('S-S3')::uuid)$q$, 'an officer line on a name-change request');
SELECT pg_temp.rejects($q$SELECT events.submit_club_change(md5('CCR1')::uuid, md5('A-S2')::uuid)$q$, 'a club change submitted by someone other than its requester');
SELECT events.submit_club_change(pg_temp.u('CCR1'), pg_temp.acct('S1'));
SELECT pg_temp.ok((SELECT request_code ~ '^CCR-[0-9]{4}-[0-9]{3}$' AND status = 'IN_PROGRESS' AND change_type = 'NAME_CHANGE' FROM events.v_club_change WHERE club_change_request_id = pg_temp.u('CCR1'))
              AND pg_temp.steps((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR1'))) = 'ADVISOR,CCC'
              AND EXISTS (SELECT 1 FROM wf.approval_instance_flag f JOIN ref.wf_flag w ON w.id = f.wf_flag_id AND w.code = 'CLUB_NAME_CHANGE'
                          WHERE f.instance_id = (SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR1'))),
  'a club change is a CLUB_CHANGE round — advisor, then committee, by configuration — carrying the kind of change as a flag');
SELECT pg_temp.rejects($q$UPDATE events.club_change_request SET new_name = 'Other' WHERE id = md5('CCR1')::uuid$q$, 'editing a submitted club change');
-- an officer change, drafted by the advisor while the first request is still open
INSERT INTO events.club_change_request (id, club_org_unit_id, club_change_type_id, justification, requested_by_account_id)
VALUES (pg_temp.u('CCR2'), pg_temp.club(), pg_temp.lk('club_change_type','OFFICER_CHANGE'), 'New academic year', pg_temp.acct('ADV'));
SELECT pg_temp.rejects($q$SELECT events.submit_club_change(md5('CCR2')::uuid, md5('A-ADV')::uuid)$q$, 'an officer change submitted without naming the officers');
INSERT INTO events.club_change_officer (club_change_request_id, club_office_id, student_id) VALUES
 (pg_temp.u('CCR2'), pg_temp.lk('club_office','PRESIDENT'), pg_temp.stu('S3')), (pg_temp.u('CCR2'), pg_temp.lk('club_office','SECRETARY'), NULL);
SELECT pg_temp.rejects($q$SELECT events.submit_club_change(md5('CCR2')::uuid, md5('A-ADV')::uuid)$q$, 'a second change request of the club while one is under approval (limit 1 — a setting)');
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR1')), 'APPROVE', 'ADV');
SELECT pg_temp.rejects($q$SELECT events.apply_club_change(md5('CCR1')::uuid)$q$, 'applying a club change that is not yet approved');
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR1')), 'APPROVE', 'CCC1');
SELECT pg_temp.ok((SELECT club_name = 'Coding & Robotics Club' FROM events.v_club WHERE club_org_unit_id = pg_temp.club())
              AND (SELECT applied_at IS NOT NULL AND status = 'APPROVED' FROM events.v_club_change WHERE club_change_request_id = pg_temp.u('CCR1')),
  'on approval the database renames the club itself and records that the change was applied');
SELECT events.submit_club_change(pg_temp.u('CCR2'), pg_temp.acct('ADV'));
SELECT pg_temp.ok(pg_temp.steps((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR2'))) = 'CCC', 'the advisor''s own request skips the advisor level');
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR2')), 'APPROVE', 'CCC2');
SELECT pg_temp.ok((SELECT string_agg(office || ':' || student_id, ',') = 'PRESIDENT:' || pg_temp.stu('S3') FROM events.v_club_officer_current WHERE club_org_unit_id = pg_temp.club())
              AND events.is_club_officer(pg_temp.acct('S3'), pg_temp.club()) AND NOT events.is_club_officer(pg_temp.acct('S1'), pg_temp.club())
              AND NOT events.is_club_officer(pg_temp.acct('S2'), pg_temp.club()),
  'the approved officer change is applied: a new president, the old one out, the secretary''s post vacant');
-- a change of advisor, asked for by the new president
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, new_employee_id, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','ADVISOR_CHANGE'), 'x', md5('E-CCC1')::uuid, md5('A-S3')::uuid)$q$, 'an incoming advisor who is not faculty');
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, new_employee_id, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','ADVISOR_CHANGE'), 'x', md5('E-COADV')::uuid, md5('A-S3')::uuid)$q$, 'the co-advisor proposed as advisor while still co-advisor');
INSERT INTO events.club_change_request (id, club_org_unit_id, club_change_type_id, justification, new_employee_id, requested_by_account_id)
VALUES (pg_temp.u('CCR3'), pg_temp.club(), pg_temp.lk('club_change_type','ADVISOR_CHANGE'), 'The advisor is going on sabbatical', pg_temp.emp('FAC'), pg_temp.acct('S3'));
SELECT events.submit_club_change(pg_temp.u('CCR3'), pg_temp.acct('S3'));
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR3')), 'APPROVE', 'ADV');
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR3')), 'APPROVE', 'CCC1');
SELECT pg_temp.ok((SELECT advisor_employee_id = pg_temp.emp('FAC') AND co_advisor_employee_id = pg_temp.emp('COADV') FROM events.v_club WHERE club_org_unit_id = pg_temp.club())
              AND authz.has_permission(pg_temp.acct('FAC'), 'events.proposal.review', pg_temp.club())
              AND NOT authz.has_permission(pg_temp.acct('ADV'), 'events.proposal.review', pg_temp.club()),
  'the approved advisor change replaces the appointment: the new advisor has the advisor''s rights, the old one no longer');
-- every kind of club: a club of the student-welfare office (a central department), with that office's own approval path — rows only
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM wf.approval_instance_flag f JOIN ref.wf_flag w ON w.id = f.wf_flag_id AND w.code = 'CLUBCAT_TECHNICAL' WHERE f.instance_id = pg_temp.round_of('P')),
  'an event of a club carries the club''s category on its approval round as well');
INSERT INTO wf.approval_chain (id, document_type_id, scope_org_unit_id, valid, note)
SELECT 9702, id, pg_temp.u('V-SA'), daterange(current_date, NULL), 'Clubs of Student Affairs: its head, then the committee' FROM wf.approval_document_type WHERE code = 'CLUB_PROPOSAL';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, position_type_id, anchor_is_owner)
SELECT 9702, 1, 'DSW', 'Head of Student Affairs', pg_temp.lk('wf_approver_kind','POSITION'), id, true FROM org.position_type WHERE code = 'HEAD';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id)
SELECT 9702, 2, 'CCC', 'Central coordination committee', permission_id FROM authz.v_permission_code WHERE code = 'events.club_proposal.approve';
INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
SELECT pg_temp.u('V-SA'), id, pg_temp.emp('REG'), daterange('2024-01-01', NULL) FROM org.position_type WHERE code = 'HEAD';
INSERT INTO events.club_proposal (id, proposed_by_account_id, parent_org_unit_id, club_name, objective, advisor_employee_id, club_category_id)
VALUES (pg_temp.u('CP3'), pg_temp.acct('FAC'), pg_temp.u('V-SA'), 'Dramatics Society', repeat('To stage plays and street theatre. ', 3), pg_temp.emp('HOD'), pg_temp.lk('club_category','CULTURAL'));
INSERT INTO events.club_proposal_officer (club_proposal_id, club_office_id, student_id) VALUES (pg_temp.u('CP3'), pg_temp.lk('club_office','PRESIDENT'), pg_temp.stu('S6'));
SELECT events.submit_club_proposal(pg_temp.u('CP3'), pg_temp.acct('FAC'));
SELECT pg_temp.ok(pg_temp.steps((SELECT instance_id FROM events.club_proposal WHERE id = pg_temp.u('CP3'))) = 'DSW,CCC',
  'a club proposed under the student-welfare office follows that office''s own chain (its head, then the committee) — a chain scoped to the unit');
SELECT pg_temp.rejects($q$SELECT pg_temp.act((SELECT instance_id FROM events.club_proposal WHERE id = md5('CP3')::uuid), 'APPROVE', 'HOD')$q$, 'the student-welfare level approved by a department head');
SELECT pg_temp.act((SELECT instance_id FROM events.club_proposal WHERE id = pg_temp.u('CP3')), 'APPROVE', 'REG');
SELECT pg_temp.act((SELECT instance_id FROM events.club_proposal WHERE id = pg_temp.u('CP3')), 'APPROVE', 'CCC1');
SELECT pg_temp.ok((SELECT club_category = 'CULTURAL' AND parent_unit_type = 'CENTRAL_DEPARTMENT' AND status = 'ACTIVE' FROM events.v_club WHERE club_name = 'Dramatics Society')
              AND (SELECT count(DISTINCT parent_unit_type) = 2 FROM events.v_club),
  'the cultural club of the student-welfare office exists beside the technical club of the department: whose club (its parent unit) and what kind (its category) are two separate facts');
-- a change of category goes through a change request like any other change
SELECT pg_temp.rejects($q$INSERT INTO events.club_change_request (club_org_unit_id, club_change_type_id, justification, requested_by_account_id)
  VALUES (pg_temp.club(), ref.id_of('club_change_type','CATEGORY_CHANGE'), 'x', md5('A-S3')::uuid)$q$, 'a category change without the new category');
INSERT INTO events.club_change_request (id, club_org_unit_id, club_change_type_id, justification, new_club_category_id, requested_by_account_id)
VALUES (pg_temp.u('CCR4'), pg_temp.club(), pg_temp.lk('club_change_type','CATEGORY_CHANGE'), 'The club now runs academic seminars', pg_temp.lk('club_category','ACADEMIC'), pg_temp.acct('S3'));
SELECT events.submit_club_change(pg_temp.u('CCR4'), pg_temp.acct('S3'));
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR4')), 'APPROVE', 'FAC');
SELECT pg_temp.act((SELECT instance_id FROM events.club_change_request WHERE id = pg_temp.u('CCR4')), 'APPROVE', 'CCC2');
SELECT pg_temp.ok((SELECT club_category = 'ACADEMIC' FROM events.v_club WHERE club_org_unit_id = pg_temp.club()), 'the approved category change is applied to the club');
-- the primary club
SELECT pg_temp.rejects($q$INSERT INTO events.primary_club (student_id, club_org_unit_id) VALUES (md5('S-S4')::uuid, pg_temp.club())$q$, 'a primary club in which the student holds no office');
INSERT INTO events.primary_club (student_id, club_org_unit_id) VALUES (pg_temp.stu('S3'), pg_temp.club());
SELECT pg_temp.rejects($q$INSERT INTO events.primary_club (student_id, club_org_unit_id) VALUES (md5('S-S3')::uuid, pg_temp.club())$q$, 'a second primary club for one student');
UPDATE events.event_setting SET primary_club_requires_office = false;
INSERT INTO events.primary_club (student_id, club_org_unit_id) VALUES (pg_temp.stu('S4'), pg_temp.club());
SELECT pg_temp.rejects($q$INSERT INTO events.primary_club (student_id, club_org_unit_id) VALUES (md5('S-S6')::uuid, pg_temp.club())$q$, 'a primary club the student is not even a member of');
SELECT pg_temp.ok((SELECT count(*) = 2 FROM events.primary_club WHERE club_org_unit_id = pg_temp.club()), 'with the office requirement switched off a plain member may choose the club as primary');

-- ======================== changing an approved event (EVENT_CHANGE round) ===
-- C2 is approved and published, three days after pg_temp.day(); it gets a round so the move can be seen on it
INSERT INTO events.event_round (id, event_id, name, during, event_round_type_id)
VALUES (pg_temp.u('RND-C2'), pg_temp.event_of('C2'), 'Talk', tsrange(pg_temp.day() + 3 + time '15:00', pg_temp.day() + 3 + time '16:00'), pg_temp.lk('event_round_type','GENERAL'));
SELECT pg_temp.rejects($q$UPDATE events.event_proposal SET during = tsrange(pg_temp.day() + 5 + time '15:00', pg_temp.day() + 5 + time '17:00') WHERE id = md5('C2')::uuid$q$, 'moving an approved event by editing its proposal');
SELECT pg_temp.rejects($q$INSERT INTO events.event_change_request (event_id, reason, new_venue_text, requested_by_account_id) VALUES (pg_temp.event_of('C2'), 'x', 'Elsewhere', md5('A-S4')::uuid)$q$, 'an event change requested by a participant');
SELECT pg_temp.rejects($q$INSERT INTO events.event_change_request (event_id, reason, requested_by_account_id) VALUES (pg_temp.event_of('C2'), 'x', md5('A-ADV')::uuid)$q$, 'a change request that changes nothing');
SELECT pg_temp.rejects($q$INSERT INTO events.event_change_request (event_id, reason, new_capacity_fixed, requested_by_account_id) VALUES (pg_temp.event_of('C2'), 'x', 50, md5('A-ADV')::uuid)$q$, 'a fixed capacity below the expected attendance');
SELECT pg_temp.rejects($q$INSERT INTO events.event_change_request (event_id, reason, new_venue_text, requested_by_account_id) VALUES (pg_temp.event_of('Q'), 'x', 'Elsewhere', md5('A-S2')::uuid)$q$, 'a change to an event that is over');
CREATE TEMP TABLE oldpkg AS SELECT facility_event_request_id AS id, during FROM events.event_proposal WHERE id = pg_temp.u('C2');
INSERT INTO events.event_change_request (id, event_id, reason, new_during, new_venue_text, new_capacity_fixed, requested_by_account_id)
VALUES (pg_temp.u('ECR1'), pg_temp.event_of('C2'), 'The speaker can only come two days later', tsrange(pg_temp.day() + 5 + time '15:00', pg_temp.day() + 5 + time '17:00'),
        'Seminar hall 2', 150, pg_temp.acct('ADV'));
SELECT pg_temp.rejects($q$SELECT events.submit_event_change(md5('ECR1')::uuid, md5('A-S2')::uuid)$q$, 'an event change submitted by someone other than its requester');
SELECT events.submit_event_change(pg_temp.u('ECR1'), pg_temp.acct('ADV'));
CREATE FUNCTION pg_temp.ecr(k text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT instance_id FROM events.event_change_request WHERE id = md5(k)::uuid $$;
SELECT pg_temp.ok((SELECT request_code ~ '^ECR-[0-9]{4}-[0-9]{3}$' AND status = 'IN_PROGRESS' AND changes_dates AND changes_venue AND changes_capacity FROM events.v_event_change WHERE event_change_request_id = pg_temp.u('ECR1'))
              AND pg_temp.steps(pg_temp.ecr('ECR1')) = 'ADVISOR,CCC'
              AND (SELECT string_agg(f.code, ',' ORDER BY f.code) = 'EVENT_CAPACITY_CHANGE,EVENT_RESCHEDULE,EVENT_VENUE_CHANGE' FROM wf.approval_instance_flag i JOIN ref.wf_flag f ON f.id = i.wf_flag_id WHERE i.instance_id = pg_temp.ecr('ECR1'))
              AND (SELECT f.instance_id = pg_temp.ecr('ECR1') AND lower(f.during) = pg_temp.day() + 5 + time '15:00' FROM facility.event_request f JOIN events.event_change_request c ON c.facility_event_request_id = f.id WHERE c.id = pg_temp.u('ECR1'))
              AND (SELECT lower(during) = pg_temp.day() + 3 + time '15:00' FROM events.v_event WHERE event_id = pg_temp.event_of('C2')),
  'an event change is an EVENT_CHANGE round (advisor, committee — configuration) flagged with what it changes; new dates open a venue package for them; nothing changes until it is approved');
SELECT pg_temp.rejects($q$UPDATE events.event_change_request SET reason = 'changed' WHERE id = md5('ECR1')::uuid$q$, 'editing a submitted event change');
INSERT INTO events.event_change_request (id, event_id, reason, new_venue_text, requested_by_account_id) VALUES (pg_temp.u('ECR2'), pg_temp.event_of('C2'), 'Bigger room', 'Seminar hall 3', pg_temp.acct('ADV'));
SELECT pg_temp.rejects($q$SELECT events.submit_event_change(md5('ECR2')::uuid, md5('A-ADV')::uuid)$q$, 'a second change of an event while one is under approval');
SELECT pg_temp.rejects($q$SELECT pg_temp.act(pg_temp.ecr('ECR1'), 'APPROVE', 'CCC1')$q$, 'the committee passing the advisor over in a two-level chain (one approved level would remain)');
SELECT pg_temp.act(pg_temp.ecr('ECR1'), 'APPROVE', 'FAC');
SELECT pg_temp.act(pg_temp.ecr('ECR1'), 'APPROVE', 'CCC1');
SELECT pg_temp.ok((SELECT lower(during) = pg_temp.day() + 5 + time '15:00' AND upper(during) = pg_temp.day() + 5 + time '17:00' AND seat_limit = 150 FROM events.v_event WHERE event_id = pg_temp.event_of('C2'))
              AND (SELECT venue_text = 'Seminar hall 2' AND facility_event_request_id = (SELECT facility_event_request_id FROM events.event_change_request WHERE id = pg_temp.u('ECR1'))
                   FROM events.event_proposal WHERE id = pg_temp.u('C2'))
              AND (SELECT during = tsrange(pg_temp.day() + 5 + time '15:00', pg_temp.day() + 5 + time '16:00') FROM events.event_round WHERE id = pg_temp.u('RND-C2'))
              AND (SELECT r.applied_at IS NOT NULL AND r.previous_during = (SELECT during FROM oldpkg) AND r.previous_capacity_fixed IS NULL AND v.status = 'APPROVED'
                   FROM events.event_change_request r JOIN events.v_event_change v ON v.event_change_request_id = r.id WHERE r.id = pg_temp.u('ECR1'))
              AND (SELECT cancelled_at IS NOT NULL FROM facility.event_request WHERE id = (SELECT id FROM oldpkg)),
  'on approval the database moves the event: new dates, venue and capacity, its round shifted with it, the old venue package released, and what it was before kept on the request');

-- ================================================ attendance per session ===
CREATE FUNCTION pg_temp.q_round() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM events.event_round WHERE event_id = pg_temp.event_of('Q') LIMIT 1 $$;
SELECT pg_temp.rejects($q$SELECT events.check_in_round(pg_temp.qr('S3'), pg_temp.q_round(), md5('A-S5')::uuid)$q$, 'a session check-in by someone who is neither a scanning volunteer nor an organiser');
SELECT pg_temp.rejects($q$SELECT events.check_in_round('TKT-NOT-A-TICKET', pg_temp.q_round(), md5('A-S6')::uuid)$q$, 'a session check-in with an unknown pass');
INSERT INTO res SELECT 'CHK', events.check_in_round(pg_temp.qr('S3'), pg_temp.q_round(), pg_temp.acct('S6'));
SELECT pg_temp.rejects($q$SELECT events.check_in_round(pg_temp.qr('S3'), pg_temp.q_round(), md5('A-S6')::uuid)$q$, 'a second check-in to the same session');
SELECT pg_temp.rejects($q$UPDATE events.round_attendance SET marked_at = now()$q$, 'editing session attendance');
INSERT INTO events.event_round (id, event_id, name, during, event_round_type_id)
VALUES (pg_temp.u('RND-P'), pg_temp.event_of('P'), 'Masterclass', tsrange(pg_temp.day() + 8 + time '10:00', pg_temp.day() + 8 + time '13:00'), pg_temp.lk('event_round_type','GENERAL'));
SELECT pg_temp.rejects($q$SELECT events.check_in_round(pg_temp.qr('S3'), md5('RND-P')::uuid, md5('A-S2')::uuid)$q$, 'a check-in with the ticket of another event');
CREATE TEMP TABLE tkt4 AS SELECT events.issue_ticket(pg_temp.reg('P4'), pg_temp.acct('S4')) AS t;
SELECT pg_temp.rejects($q$SELECT events.check_in_round((SELECT t FROM tkt4), md5('RND-P')::uuid, md5('A-S2')::uuid)$q$, 'a check-in days before the session (it opens 30 minutes before — a setting)');
UPDATE events.event_setting SET round_checkin_opens_before = interval '30 days';
INSERT INTO res SELECT 'CHK4', events.check_in_round((SELECT t FROM tkt4), pg_temp.u('RND-P'), pg_temp.acct('S2'));
SELECT pg_temp.rejects($q$INSERT INTO events.round_attendance (event_round_id, registration_id, marked_by_account_id, scan_source_id)
  VALUES (md5('RND-P')::uuid, pg_temp.reg('P5'), md5('A-S6')::uuid, ref.id_of('scan_source','IMPORT'))$q$, 'a session sheet imported by a volunteer');
SELECT pg_temp.rejects($q$INSERT INTO events.round_attendance (event_round_id, registration_id, marked_by_account_id, scan_source_id)
  VALUES (md5('RND-P')::uuid, pg_temp.reg('P3'), md5('A-S2')::uuid, ref.id_of('scan_source','IMPORT'))$q$, 'session attendance for a cancelled registration');
INSERT INTO events.round_attendance (event_round_id, registration_id, marked_by_account_id, scan_source_id)
VALUES (pg_temp.u('RND-P'), pg_temp.reg('P5'), pg_temp.acct('S2'), pg_temp.lk('scan_source','IMPORT'));
SELECT pg_temp.ok((SELECT confirmed = 2 AND attended = 2 FROM events.v_round_attendance WHERE event_round_id = pg_temp.u('RND-P'))
              AND (SELECT attended = 1 FROM events.v_round_attendance WHERE event_round_id = pg_temp.q_round())
              AND (SELECT sessions_attended = 1 AND attended AND entered = 0 FROM events.v_attendance WHERE registration_id = pg_temp.reg('P4'))
              AND (SELECT sessions_attended = 1 AND entered = 3 FROM events.v_attendance WHERE registration_id = pg_temp.reg('S3'))
              AND events.attended(pg_temp.reg('P5')),
  'attendance per session: a check-in by ticket or an imported sheet, counted per round; a participant checked in to a session has attended, gate scan or not');

-- ======================================= expenses and settlement (event Q) ===
SELECT pg_temp.rejects($q$INSERT INTO events.event_expense (event_id, budget_item_type_id, description, amount, incurred_on, recorded_by_account_id)
  VALUES (pg_temp.event_of('Q'), ref.id_of('budget_item_type','REFRESHMENTS'), 'Tea', 100, current_date, md5('A-S5')::uuid)$q$, 'an expense recorded by a participant');
SELECT pg_temp.rejects($q$INSERT INTO events.event_expense (event_id, budget_item_type_id, description, amount, incurred_on, recorded_by_account_id)
  VALUES (pg_temp.event_of('Q'), ref.id_of('budget_item_type','REFRESHMENTS'), 'Tea', 0, current_date, md5('A-S2')::uuid)$q$, 'an expense of nothing');
SELECT pg_temp.rejects($q$INSERT INTO events.event_expense (event_id, budget_item_type_id, description, amount, incurred_on, recorded_by_account_id)
  VALUES (pg_temp.event_of('Q'), ref.id_of('budget_item_type','REFRESHMENTS'), 'Tea', 100, current_date + 3, md5('A-S2')::uuid)$q$, 'an expense dated in the future');
SELECT pg_temp.rejects($q$INSERT INTO events.event_expense (event_id, budget_item_type_id, proposal_budget_item_id, description, amount, incurred_on, recorded_by_account_id)
  VALUES (pg_temp.event_of('Q'), ref.id_of('budget_item_type','REFRESHMENTS'), (SELECT id FROM events.proposal_budget_item WHERE event_proposal_id = md5('P')::uuid LIMIT 1), 'Tea', 100, current_date, md5('A-S2')::uuid)$q$,
  'an expense against the budget line of another event');
INSERT INTO events.event_expense (id, event_id, budget_item_type_id, proposal_budget_item_id, description, amount, incurred_on, payee, recorded_by_account_id) VALUES
 (pg_temp.u('EXP1'), pg_temp.event_of('Q'), pg_temp.lk('budget_item_type','REFRESHMENTS'), (SELECT id FROM events.proposal_budget_item WHERE event_proposal_id = pg_temp.u('Q')),
  'Tea and snacks', 650, current_date, 'Campus canteen', pg_temp.acct('S2')),
 (pg_temp.u('EXP2'), pg_temp.event_of('Q'), pg_temp.lk('budget_item_type','PRINTING'), NULL, 'Handouts', 300, current_date, NULL, pg_temp.acct('S2'));
SELECT pg_temp.ok((SELECT budgeted = 800 AND actual = 650 AND variance = -150 FROM events.v_event_budget_actual WHERE event_id = pg_temp.event_of('Q') AND budget_item_type = 'REFRESHMENTS')
              AND (SELECT budgeted = 0 AND actual = 300 FROM events.v_event_budget_actual WHERE event_id = pg_temp.event_of('Q') AND budget_item_type = 'PRINTING')
              AND (SELECT budget_total = 800 AND expense_total = 950 AND variance = 150 AND status = 'NOT_SUBMITTED' FROM events.v_event_settlement WHERE event_id = pg_temp.event_of('Q')),
  'budget against actual per head and in total: 800 approved, 950 spent, 150 over');
SELECT pg_temp.rejects($q$SELECT events.submit_settlement(pg_temp.event_of('P'), md5('A-S2')::uuid)$q$, 'settling an event that has not taken place yet');
SELECT pg_temp.rejects($q$SELECT events.submit_settlement(pg_temp.event_of('Q'), md5('A-S5')::uuid)$q$, 'a settlement submitted by a participant');
UPDATE events.event_setting SET expense_bill_required_above = 500;
SELECT pg_temp.rejects($q$SELECT events.submit_settlement(pg_temp.event_of('Q'), md5('A-S2')::uuid)$q$, 'a settlement with an expense above the bill limit (500 — a setting) and no bill');
UPDATE events.event_expense SET bill_file_id = pg_temp.u('F-REPORT'), bill_no = 'CN-118' WHERE id = pg_temp.u('EXP1');
SELECT events.submit_settlement(pg_temp.event_of('Q'), pg_temp.acct('S2'), 'Printing was not in the budget');
CREATE FUNCTION pg_temp.settle() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT instance_id FROM events.v_event_settlement WHERE event_id = pg_temp.event_of('Q') $$;
SELECT pg_temp.ok(pg_temp.steps(pg_temp.settle()) = 'ADVISOR,CCC'
              AND (SELECT amount = 950 FROM wf.approval_instance WHERE id = pg_temp.settle())
              AND EXISTS (SELECT 1 FROM wf.approval_instance_flag f JOIN ref.wf_flag w ON w.id = f.wf_flag_id AND w.code = 'OVER_BUDGET' WHERE f.instance_id = pg_temp.settle())
              AND (SELECT status = 'IN_PROGRESS' AND settlement_code ~ '^EST-[0-9]{4}-[0-9]{3}$' FROM events.v_event_settlement WHERE event_id = pg_temp.event_of('Q')),
  'the settlement is an EVENT_SETTLEMENT round carrying the total spent as its amount and the flag OVER_BUDGET — a chain can add a level for either');
SELECT pg_temp.rejects($q$UPDATE events.event_expense SET amount = 1 WHERE id = md5('EXP2')::uuid$q$, 'changing an expense while the settlement is under approval');
SELECT pg_temp.rejects($q$SELECT events.submit_settlement(pg_temp.event_of('Q'), md5('A-S2')::uuid)$q$, 'a second settlement while one is under approval');
SELECT pg_temp.rejects($q$UPDATE events.event_settlement SET remarks = 'x'$q$, 'editing a submitted settlement');
SELECT pg_temp.act(pg_temp.settle(), 'RETURN', 'FAC', 'Reduce the printing bill');
UPDATE events.event_expense SET amount = 100 WHERE id = pg_temp.u('EXP2');
SELECT events.submit_settlement(pg_temp.event_of('Q'), pg_temp.acct('S2'), 'Corrected');
SELECT pg_temp.act(pg_temp.settle(), 'APPROVE', 'FAC');
SELECT pg_temp.act(pg_temp.settle(), 'APPROVE', 'CCC2');
SELECT pg_temp.ok((SELECT status = 'APPROVED' AND settled_amount = 750 AND expense_total = 750 AND variance = -50 FROM events.v_event_settlement WHERE event_id = pg_temp.event_of('Q'))
              AND NOT EXISTS (SELECT 1 FROM wf.approval_instance_flag f WHERE f.instance_id = pg_temp.settle())
              AND (SELECT count(*) = 2 FROM events.event_settlement WHERE event_id = pg_temp.event_of('Q')),
  'returned, corrected and submitted again as a new settlement: approved at 750, within budget, with the first round kept as history');
SELECT pg_temp.rejects($q$INSERT INTO events.event_expense (event_id, budget_item_type_id, description, amount, incurred_on, recorded_by_account_id)
  VALUES (pg_temp.event_of('Q'), ref.id_of('budget_item_type','OTHER'), 'Late bill', 50, current_date, md5('A-S2')::uuid)$q$, 'a new expense after the settlement is approved');

-- =============================================== audit of 2026-10-01: guards ===
SELECT pg_temp.ok((SELECT NOT c.allows_level_override FROM wf.approval_chain c JOIN wf.approval_document_type t ON t.id = c.document_type_id WHERE t.code = 'EVENT_SETTLEMENT' AND c.scope_org_unit_id IS NULL)
              AND (SELECT c.allows_level_override FROM wf.approval_chain c JOIN wf.approval_document_type t ON t.id = c.document_type_id WHERE t.code = 'EVENT_CHANGE' AND c.scope_org_unit_id IS NULL),
  'a settlement (money) takes every level in order; an event change keeps the higher-level override');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'events' AND table_name = 'club_point_award' AND column_name = 'club_org_unit_id')
              AND (SELECT total_points = 5 FROM events.v_club_points WHERE club_org_unit_id = pg_temp.club()),
  'a point award names only its event; the club is derived from the event''s organiser');
SELECT pg_temp.ok(NOT has_table_privilege('intranet_analytics', 'events.event_stall', 'SELECT') AND NOT has_table_privilege('intranet_analytics', 'events.event_sponsor', 'SELECT') AND NOT has_table_privilege('intranet_analytics', 'events.club_change_request', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'events.event_change_request', 'SELECT') AND has_table_privilege('intranet_analytics', 'events.v_stall', 'SELECT')
              AND has_table_privilege('intranet_analytics', 'events.v_club_change', 'SELECT')
              AND (SELECT count(*) = 2 FROM privacy.data_element WHERE schema_name = 'events' AND (table_name, column_name) IN (('event_sponsor','name'), ('event_certificate','revoke_reason'))),
  'reporting reads stalls and change requests through their views, not the tables with free-text remarks; sponsor names and revocation reasons are in the privacy inventory');

-- =================================================================== audit ====
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'events' AND entity_table = 'event_proposal')
              AND NOT EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'events' AND entity_table IN ('entry_scan', 'event_feedback', 'event_feedback_token')),
  'the module is audited; the gate log and the anonymous feedback are not');
SELECT pg_temp.ok((SELECT c.new_value = '[REDACTED]' FROM audit.audit_event e JOIN audit.audit_change c ON c.audit_event_id = e.id AND c.occurred_at = e.occurred_at
                   WHERE e.entity_table = 'extra_pass' AND c.column_name = 'guest_name' LIMIT 1), 'a guest''s name is redacted in the audit trail');

\echo '>>> ALL EVENTS SMOKE TESTS PASSED'
ROLLBACK;
