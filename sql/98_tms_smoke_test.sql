-- =============================================================================
-- 98_tms_smoke_test.sql — Helpdesk & grievance redressal (TMS, sql/12_tms.sql):
-- scenario + negative tests. Self-contained (own org units, people, accounts,
-- committees, calendar); runs in a transaction that is ROLLED BACK.
--   psql -v ON_ERROR_STOP=1 -f sql/98_tms_smoke_test.sql
-- Every check prints PASS; the first failure aborts with "FAIL: ...".
-- Dates used by the clock tests: 2026-10-01 is a Thursday; 2026-10-05
-- (Monday) is made a university holiday below. Time-dependent steps use the
-- real clock and forced scheduler runs at chosen instants.
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
    RAISE NOTICE 'PASS  rejected: % (%)', msg, left(SQLERRM, 110);
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL: expected rejection: %', msg;
END $$;
CREATE FUNCTION pg_temp.lk(t text, c text) RETURNS int LANGUAGE sql STABLE AS $$ SELECT ref.id_of(t, c) $$;
CREATE FUNCTION pg_temp.emp(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('E-' || k)::uuid $$;
CREATE FUNCTION pg_temp.acct(k text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('A-' || k)::uuid $$;

-- a category node
CREATE FUNCTION pg_temp.cat(k text, parent text, lvl text, nm text, dom text DEFAULT NULL, unit text DEFAULT NULL,
                            ctype text DEFAULT NULL, prio text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  INSERT INTO tms.ticket_category (id, parent_id, category_level_id, ticket_domain_id, org_unit_id, category_type_id, priority_id, name)
  VALUES (md5(k)::uuid, CASE WHEN parent IS NOT NULL THEN md5(parent)::uuid END, ref.id_of('tms_category_level', lvl),
          CASE WHEN dom IS NOT NULL THEN ref.id_of('tms_ticket_domain', dom) END, CASE WHEN unit IS NOT NULL THEN md5(unit)::uuid END,
          CASE WHEN ctype IS NOT NULL THEN ref.id_of('tms_category_type', ctype) END,
          CASE WHEN prio IS NOT NULL THEN ref.id_of('tms_priority', prio) END, nm)
$$;
-- a route level
CREATE FUNCTION pg_temp.lvl(p_route text, p_seq int, p_label text, p_kind text, p_clevel text DEFAULT NULL, p_pos text DEFAULT NULL,
                            p_base text DEFAULT NULL, p_anchor text DEFAULT NULL, p_unit text DEFAULT NULL, p_oversees boolean DEFAULT false,
                            p_emp text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  INSERT INTO tms.ticket_route_level (route_id, seq, label, route_level_kind_id, category_level_id, position_type_id, anchor_base_id,
                                      anchor_org_unit_type_id, org_unit_id, oversees, employee_id)
  SELECT r.id, p_seq, p_label, ref.id_of('tms_route_level_kind', p_kind),
         CASE WHEN p_clevel IS NOT NULL THEN ref.id_of('tms_category_level', p_clevel) END,
         (SELECT pt.id FROM org.position_type pt WHERE pt.code = p_pos),
         CASE WHEN p_base IS NOT NULL THEN ref.id_of('tms_anchor_base', p_base) END,
         CASE WHEN p_anchor IS NOT NULL THEN ref.id_of('org_unit_type', p_anchor) END,
         CASE WHEN p_unit IS NOT NULL THEN md5(p_unit)::uuid END, p_oversees,
         CASE WHEN p_emp IS NOT NULL THEN md5('E-' || p_emp)::uuid END
  FROM tms.ticket_route r WHERE r.code = p_route
$$;
CREATE FUNCTION pg_temp.lv(p_route text, p_seq int) RETURNS smallint LANGUAGE sql STABLE AS $$
  SELECT l.id FROM tms.ticket_route_level l JOIN tms.ticket_route r ON r.id = l.route_id WHERE r.code = p_route AND l.seq = p_seq $$;
CREATE FUNCTION pg_temp.fid(p_code text) RETURNS smallint LANGUAGE sql STABLE AS $$ SELECT id FROM tms.redressal_forum WHERE code = p_code $$;
-- raise ticket k in category cat as requester req (phone PH-req); the declaration in force is accepted
CREATE FUNCTION pg_temp.tk(k text, cat text, req text, msg text DEFAULT 'SERVICE_REQUEST', manual text DEFAULT NULL, ikey text DEFAULT NULL,
                           anon boolean DEFAULT false, incident date DEFAULT NULL, desk text DEFAULT NULL, channel text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  INSERT INTO tms.ticket (id, requester_account_id, raised_category_id, message_type_id, subject, description, relief_sought, contact_phone_id,
                          requested_assignee_employee_id, idempotency_key, is_anonymous, incident_on, raised_by_account_id, intake_channel_id, declaration_id)
  SELECT md5(k)::uuid, md5('A-' || req)::uuid, md5(cat)::uuid, ref.id_of('tms_message_type', msg), 'Ticket ' || k,
         'Description of the problem reported in ' || k, CASE WHEN msg = 'GRIEVANCE' THEN 'Relief sought in ' || k END, md5('PH-' || req)::uuid,
         CASE WHEN manual IS NOT NULL THEN md5('E-' || manual)::uuid END, ikey, anon, incident,
         CASE WHEN desk IS NOT NULL THEN md5('A-' || desk)::uuid END,
         CASE WHEN channel IS NOT NULL THEN ref.id_of('tms_intake_channel', channel) END,
         (SELECT d.id FROM tms.helpdesk_declaration d JOIN tms.v_ticket_category vc ON vc.ticket_domain_id = d.ticket_domain_id
          WHERE vc.category_id = md5(cat)::uuid AND d.valid @> current_date)
$$;
-- an event on ticket k by actor (account A-actor)
CREATE FUNCTION pg_temp.ev(k text, code text, actor text, remarks text DEFAULT NULL, assignee text DEFAULT NULL, cat text DEFAULT NULL,
                           rating smallint DEFAULT NULL, forum text DEFAULT NULL, related text DEFAULT NULL, outcome text DEFAULT NULL,
                           resolution text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, assignee_employee_id, category_id, rating,
                                forum_id, related_ticket_id, redressal_outcome_id, body_resolution_id)
  VALUES (md5(k)::uuid, ref.id_of('tms_event_type', code), CASE WHEN actor IS NOT NULL THEN md5('A-' || actor)::uuid END, remarks,
          CASE WHEN assignee IS NOT NULL THEN md5('E-' || assignee)::uuid END, CASE WHEN cat IS NOT NULL THEN md5(cat)::uuid END, rating,
          CASE WHEN forum IS NOT NULL THEN (SELECT f.id FROM tms.redressal_forum f WHERE f.code = forum) END,
          CASE WHEN related IS NOT NULL THEN md5(related)::uuid END,
          CASE WHEN outcome IS NOT NULL THEN ref.id_of('tms_redressal_outcome', outcome) END,
          CASE WHEN resolution IS NOT NULL THEN md5(resolution)::uuid END)
$$;
-- the derived state of ticket k
CREATE FUNCTION pg_temp.s(k text) RETURNS SETOF tms.v_ticket_state LANGUAGE sql AS $$ SELECT * FROM tms.v_ticket_state WHERE ticket_id = md5(k)::uuid $$;
-- the latest event of ticket k
CREATE FUNCTION pg_temp.last_ev(k text) RETURNS bigint LANGUAGE sql AS $$ SELECT max(id) FROM tms.ticket_event WHERE ticket_id = md5(k)::uuid $$;
-- notices queued for event type code of ticket k to account who (optionally one channel)
CREATE FUNCTION pg_temp.notices(p_k text, p_code text, p_who text, p_ch text DEFAULT NULL) RETURNS bigint LANGUAGE sql AS $$
  SELECT count(*) FROM tms.ticket_notification n JOIN tms.ticket_event e ON e.id = n.ticket_event_id
  JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = p_code
  WHERE e.ticket_id = md5(p_k)::uuid AND n.recipient_account_id = md5('A-' || p_who)::uuid
    AND (p_ch IS NULL OR n.contact_channel_id = ref.id_of('contact_channel', p_ch))
$$;

-- ================================================================ fixtures ==
INSERT INTO org.org_unit (id, org_unit_type_id, parent_id, code, name) VALUES
 (pg_temp.u('T-SGTU'), pg_temp.lk('org_unit_type','UNIVERSITY'),         NULL,                'T-SGTU', 'SGT University'),
 (pg_temp.u('T-IT'),   pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('T-SGTU'), 'T-IT',   'Information Technology'),
 (pg_temp.u('T-EXAM'), pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('T-SGTU'), 'T-EXAM', 'Examinations'),
 (pg_temp.u('T-ADMIN'),pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('T-SGTU'), 'T-ADMIN','Administration'),
 (pg_temp.u('T-ACAD'), pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('T-SGTU'), 'T-ACAD', 'Academic Affairs'),
 (pg_temp.u('T-FIN'),  pg_temp.lk('org_unit_type','CENTRAL_DEPARTMENT'), pg_temp.u('T-SGTU'), 'T-FIN',  'Finance'),
 (pg_temp.u('T-SET'),  pg_temp.lk('org_unit_type','SCHOOL'),             pg_temp.u('T-SGTU'), 'T-SET',  'School of Engineering'),
 (pg_temp.u('T-CSE'),  pg_temp.lk('org_unit_type','DEPARTMENT'),         pg_temp.u('T-SET'),  'T-CSE',  'Computer Science'),
 (pg_temp.u('T-SOM'),  pg_temp.lk('org_unit_type','SCHOOL'),             pg_temp.u('T-SGTU'), 'T-SOM',  'School of Management'),
 (pg_temp.u('T-MBA'),  pg_temp.lk('org_unit_type','DEPARTMENT'),         pg_temp.u('T-SOM'),  'T-MBA',  'Management Studies');

-- employees: handlers H1–H3 and FH1–FH3, owners CO / MO / KH, heads, VC,
-- registrar, Dean Academics, DSW, mentor MEN, HOD, DEAN, SGRC members SG1–SG3
-- (school) and SGU (university), Ombudsperson OMB, anti-ragging AR1–AR2,
-- intake desk DESK, grievance cell GC, confidential viewer CV, requesters RS
-- (staff) and RF (faculty), admin TA, outsider OUT; students ST, ST3 (CSE), ST2 (MBA)
CREATE TEMP TABLE emps AS SELECT unnest(ARRAY['H1','H2','H3','FH1','FH2','FH3','CO','MO','KH','AH','AD','EX','VC','REG','DA','DSW','ITH','FINH',
  'MEN','HOD','DEAN','SG1','SG2','SG3','SGU','OMB','AR1','AR2','SQ1','DESK','GC','CV','RS','RF','TA','OUT']) AS k;
INSERT INTO people.person (id, first_name)
SELECT pg_temp.u('P-' || k), k FROM (SELECT k FROM emps UNION ALL SELECT unnest(ARRAY['ST','ST2','ST3'])) x;
INSERT INTO people.employee (id, person_id, employee_code, employee_category_id, employment_type_id, employment_status_id, joined_on)
SELECT pg_temp.emp(k), pg_temp.u('P-' || k), 'TMS-' || k,
       pg_temp.lk('employee_category', CASE WHEN k IN ('RF','MEN','HOD','DEAN') THEN 'TEACHING' ELSE 'NON_TEACHING' END),
       pg_temp.lk('employment_type','PERMANENT'), pg_temp.lk('employment_status','ACTIVE'), '2020-01-01'
FROM emps;
INSERT INTO people.student (id, person_id, enrollment_no, student_status_id, admitted_on) VALUES
 (pg_temp.u('S-ST'),  pg_temp.u('P-ST'),  'TMS-ST-001', pg_temp.lk('student_status','ACTIVE'), '2026-07-15'),
 (pg_temp.u('S-ST2'), pg_temp.u('P-ST2'), 'TMS-ST-002', pg_temp.lk('student_status','ACTIVE'), '2026-07-15'),
 (pg_temp.u('S-ST3'), pg_temp.u('P-ST3'), 'TMS-ST-003', pg_temp.lk('student_status','ACTIVE'), '2026-07-15');
INSERT INTO iam.user_account (id, person_id, username, password, account_status_id)
SELECT pg_temp.acct(k), pg_temp.u('P-' || k), 'tms.' || lower(k), '!', pg_temp.lk('account_status','ACTIVE')
FROM (SELECT k FROM emps UNION ALL SELECT unnest(ARRAY['ST','ST2','ST3'])) x;
INSERT INTO pii.person_phone (id, person_id, e164, contact_purpose_id)
SELECT pg_temp.u('PH-' || k), pg_temp.u('P-' || k), '+9198' || lpad((row_number() OVER ())::text, 8, '0'), pg_temp.lk('contact_purpose','OFFICIAL')
FROM unnest(ARRAY['RS','RF','CO','ST','ST2','ST3','OUT']) k;

INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id, valid)
SELECT pg_temp.u(v.unit), (SELECT id FROM org.position_type WHERE code = v.pos), pg_temp.emp(v.who), daterange('2020-01-01', NULL)
FROM (VALUES ('T-SGTU','VICE_CHANCELLOR','VC'),('T-SGTU','REGISTRAR','REG'),('T-SGTU','DEAN_ACADEMICS','DA'),
             ('T-SGTU','DEAN_STUDENT_WELFARE','DSW'),('T-SGTU','OMBUDSPERSON','OMB'),('T-IT','HEAD','ITH'),('T-EXAM','HEAD','EX'),
             ('T-ADMIN','HEAD','AD'),('T-ACAD','HEAD','AH'),('T-FIN','HEAD','FINH'),('T-CSE','HEAD','HOD'),('T-SET','DEAN','DEAN')) v(unit, pos, who);

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES ('T_CONF_VIEW','Test confidential viewer','test',false,false);
INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id FROM authz.role r, authz.v_permission_code pc
WHERE r.code = 'T_CONF_VIEW' AND pc.code IN ('tms.confidential_ticket.view', 'tms.anonymous_identity.view');
INSERT INTO authz.account_role (account_id, role_id, scope_org_unit_id, reason)
SELECT pg_temp.acct(v.who), r.id, CASE WHEN v.unit IS NOT NULL THEN pg_temp.u(v.unit) END, 'TMS test'
FROM (VALUES ('TA','TMS_ADMIN',NULL),('DESK','TMS_INTAKE_DESK','T-SET'),('GC','TMS_GRIEVANCE_CELL',NULL),('CV','T_CONF_VIEW',NULL)) v(who, role_code, unit)
JOIN authz.role r ON r.code = v.role_code;

-- academic context: year, odd term, B.Tech (CSE, 8 semesters), MBA (4), batches, a course
INSERT INTO academic.academic_year (id, code, period) VALUES (pg_temp.u('Y26'), '2026-27', daterange('2026-07-01', '2027-07-01'));
INSERT INTO academic.academic_term (id, academic_year_id, term_cycle_id, period) VALUES
 (pg_temp.u('ODD26'), pg_temp.u('Y26'), pg_temp.lk('term_cycle','ODD'), daterange('2026-07-15', '2026-12-20'));
INSERT INTO academic.program (id, code, name, program_level_id, academic_calendar_type_id, offering_org_unit_id, delivery_mode_id, duration_terms) VALUES
 (pg_temp.u('BTECH'), 'T-BTECH', 'B.Tech CSE (TMS test)', pg_temp.lk('program_level','UG'), pg_temp.lk('academic_calendar_type','SEMESTER'),
  pg_temp.u('T-CSE'), pg_temp.lk('delivery_mode','REGULAR'), 8),
 (pg_temp.u('MBA'), 'T-MBA', 'MBA (TMS test)', pg_temp.lk('program_level','UG'), pg_temp.lk('academic_calendar_type','SEMESTER'),
  pg_temp.u('T-MBA'), pg_temp.lk('delivery_mode','REGULAR'), 4);
INSERT INTO academic.batch (id, program_id, admission_year_id) VALUES
 (pg_temp.u('B26'), pg_temp.u('BTECH'), pg_temp.u('Y26')), (pg_temp.u('BM26'), pg_temp.u('MBA'), pg_temp.u('Y26'));
INSERT INTO academic.student_enrollment (student_id, batch_id, valid) VALUES
 (pg_temp.u('S-ST'),  pg_temp.u('B26'),  daterange('2026-07-15', NULL)),
 (pg_temp.u('S-ST3'), pg_temp.u('B26'),  daterange('2026-07-15', NULL)),
 (pg_temp.u('S-ST2'), pg_temp.u('BM26'), daterange('2026-07-15', NULL));
INSERT INTO people.student_mentor (student_id, employee_id, valid) VALUES (pg_temp.u('S-ST'), pg_temp.emp('MEN'), daterange('2026-07-15', NULL));
INSERT INTO academic.course (id, code, title, owner_org_unit_id, credits) VALUES (pg_temp.u('CS301'), 'T-CS301', 'Operating Systems', pg_temp.u('T-CSE'), 4);
INSERT INTO academic.calendar_event (academic_year_id, calendar_event_type_id, name, period)
VALUES (pg_temp.u('Y26'), pg_temp.lk('calendar_event_type','HOLIDAY'), 'Test holiday', daterange('2026-10-05', '2026-10-06'));
INSERT INTO academic.calendar_event (academic_year_id, calendar_event_type_id, name, period)
VALUES (pg_temp.u('Y26'), pg_temp.lk('calendar_event_type','VACATION'), 'Test vacation', daterange('2026-12-21', '2027-01-05'));

-- committees: an SGRC for the School of Engineering (quorum 3), one for the
-- university (quorum 1), the anti-ragging committee (quorum 2)
INSERT INTO academic.academic_body (id, academic_body_type_id, org_unit_id, name, quorum) VALUES
 (pg_temp.u('SGRC-SET'), pg_temp.lk('academic_body_type','STUDENT_GRIEVANCE_COMMITTEE'), pg_temp.u('T-SET'),  'SGRC — School of Engineering', 3),
 (pg_temp.u('SGRC-U'),   pg_temp.lk('academic_body_type','STUDENT_GRIEVANCE_COMMITTEE'), pg_temp.u('T-SGTU'), 'SGRC — University', 1),
 (pg_temp.u('ARC'),      pg_temp.lk('academic_body_type','ANTI_RAGGING_COMMITTEE'),      pg_temp.u('T-SGTU'), 'Anti-Ragging Committee', 2);
INSERT INTO academic.academic_body_member (id, academic_body_id, committee_role_id, employee_id, valid)
SELECT pg_temp.u('M-' || v.who), pg_temp.u(v.body), pg_temp.lk('committee_role', v.role), pg_temp.emp(v.who), daterange('2026-01-01', NULL)
FROM (VALUES ('SG1','SGRC-SET','CHAIR'),('SG2','SGRC-SET','MEMBER'),('SG3','SGRC-SET','MEMBER'),
             ('SGU','SGRC-U','CHAIR'),('AR1','ARC','CHAIR'),('AR2','ARC','MEMBER')) v(who, body, role);

-- files for attachments
INSERT INTO people.file_object (id, storage_backend_id, object_key, mime_type, byte_size, sha256)
SELECT pg_temp.u(k), pg_temp.lk('storage_backend','S3'), 'tms/test/' || k, 'application/pdf', 1000, decode(md5(k) || md5(k), 'hex')
FROM unnest(ARRAY['F1','F2','F3']) k;

-- ======================================================= the office clock ==
SELECT pg_temp.ok(tms.business_deadline('2026-10-01 16:00+05:30', 120) = '2026-10-02 10:00+05:30',
  'Thu 16:00 + 2 office hours → Fri 10:00');
SELECT pg_temp.ok(tms.business_deadline('2026-10-02 16:30+05:30', 60) = '2026-10-06 09:30+05:30',
  'Fri 16:30 + 1 h → 30 min on Friday, the weekend and the Monday holiday skipped → Tue 09:30');
SELECT pg_temp.ok(tms.business_deadline('2026-10-03 11:00+05:30', 30) = '2026-10-06 09:30+05:30',
  'raised on Saturday: the clock starts at the next opening (Tue 09:00)');
SELECT pg_temp.ok(tms.business_deadline('2026-10-01 07:00+05:30', 480) = '2026-10-01 17:00+05:30',
  'raised before opening: a full 8-hour day ends at 17:00');
SELECT pg_temp.ok(tms.business_minutes_between('2026-10-02 16:00+05:30', '2026-10-06 10:00+05:30') = 120,
  'office minutes Fri 16:00 → Tue 10:00 = 60 + 60 (weekend and holiday excluded)');
SELECT pg_temp.ok(NOT tms.is_business_day('2026-10-05') AND tms.is_business_day('2026-10-06') AND NOT tms.is_business_day('2026-10-04'),
  'holiday and Sunday are not business days; Tuesday is');
SELECT pg_temp.ok(tms.is_business_day('2026-12-22'), 'a vacation stops teaching, not the helpdesk (only HOLIDAY closes offices)');
-- the calendar is the administrator's: what the screen shows, holidays counted or not, dated overrides, per-weekday hours
SELECT pg_temp.ok((SELECT string_agg(on_date::text || '=' || is_working::text || ':' || split_part(reason, ':', 1), ',' ORDER BY on_date)
                   FROM tms.helpdesk_calendar('2026-10-02', '2026-10-06'))
                  = '2026-10-02=true:Working day,2026-10-03=false:Weekly off,2026-10-04=false:Weekly off,2026-10-05=false:Holiday,2026-10-06=true:Working day',
  'the helpdesk calendar Fri–Tue: working, weekly off ×2, the holiday, working — each with its reason');
UPDATE tms.helpdesk_setting SET count_holidays = true;
SELECT pg_temp.ok(tms.business_deadline('2026-10-02 16:30+05:30', 60) = '2026-10-05 09:30+05:30'
              AND (SELECT reason LIKE 'Holiday counted%' FROM tms.day_hours('2026-10-05')),
  'with count_holidays on, the Monday holiday is a working day: Fri 16:30 + 1 h → Mon 09:30');
UPDATE tms.helpdesk_setting SET count_holidays = false;
INSERT INTO tms.helpdesk_day_override (on_date, is_working, note) VALUES ('2026-10-05', true, 'Fee deadline: the helpdesk opens');
SELECT pg_temp.ok(tms.business_deadline('2026-10-02 16:30+05:30', 60) = '2026-10-05 09:30+05:30',
  'a dated override opens the helpdesk on that one holiday');
UPDATE tms.helpdesk_day_override SET is_working = false, note = 'Closed: power shutdown' WHERE on_date = '2026-10-05';
INSERT INTO tms.helpdesk_day_override (on_date, is_working, note) VALUES ('2026-10-06', false, 'Closed: state election');
SELECT pg_temp.ok(tms.business_deadline('2026-10-02 16:30+05:30', 60) = '2026-10-07 09:30+05:30',
  'a dated override closes a normal Tuesday: the deadline moves to Wednesday');
UPDATE tms.helpdesk_day_override SET is_working = true, day_start = '10:00', day_end = '12:00', note = 'Open 10–12 only' WHERE on_date = '2026-10-06';
SELECT pg_temp.ok(tms.business_deadline('2026-10-02 16:30+05:30', 60) = '2026-10-06 10:30+05:30',
  'an override with its own hours: Tuesday opens at 10:00');
DELETE FROM tms.helpdesk_day_override;
INSERT INTO tms.helpdesk_weekday (iso_dow, day_start, day_end) VALUES (6, '09:00', '13:00');
SELECT pg_temp.ok(tms.business_deadline('2026-10-03 11:00+05:30', 30) = '2026-10-03 11:30+05:30'
              AND tms.business_deadline('2026-10-03 12:30+05:30', 60) = '2026-10-06 09:30+05:30',
  'a Saturday half day (09:00–13:00) counts its own hours; the rest carries over the Sunday and the holiday');
DELETE FROM tms.helpdesk_weekday WHERE iso_dow = 6;
SELECT pg_temp.rejects($q$INSERT INTO tms.helpdesk_day_override (on_date, is_working, day_start, day_end, note) VALUES ('2026-10-07', false, '09:00', '12:00', 'Closed')$q$,
  'hours on a closed day');
SELECT pg_temp.rejects($q$INSERT INTO tms.helpdesk_day_override (on_date, is_working, note) VALUES ('2026-10-07', true, '')$q$, 'an override without a reason');
SELECT pg_temp.rejects($q$INSERT INTO tms.helpdesk_weekday (iso_dow, day_start, day_end) VALUES (6, '13:00', '09:00')$q$, 'a weekday closing before it opens');
UPDATE tms.helpdesk_setting SET office_hours_only = false;
SELECT pg_temp.ok(NOT tms.sla_office(pg_temp.lk('tms_priority','MEDIUM')::smallint, NULL), 'the helpdesk-wide switch: every clock counts all hours');
UPDATE ref.tms_priority SET office_hours_only = true WHERE code = 'MEDIUM';
SELECT pg_temp.ok(tms.sla_office(pg_temp.lk('tms_priority','MEDIUM')::smallint, NULL) AND NOT tms.sla_office(pg_temp.lk('tms_priority','LOW')::smallint, NULL),
  'a priority may keep office hours against the helpdesk-wide default');
UPDATE ref.tms_priority SET office_hours_only = NULL WHERE code = 'MEDIUM';
UPDATE tms.helpdesk_setting SET office_hours_only = true;
SELECT pg_temp.ok(tms.days_after('2026-10-01 10:00+05:30', 3, true) = '2026-10-07 17:00+05:30'
              AND tms.days_after('2026-10-01 10:00+05:30', 3, false) = '2026-10-04 10:00+05:30',
  'a forum''s 3 days: close of office on the 3rd business day (Fri, Tue, Wed) or 3 calendar days');
SELECT pg_temp.ok(tms.deadline_after('2026-10-03 11:00+05:30', 120, false) = '2026-10-03 13:00+05:30'
              AND tms.deadline_after('2026-10-03 11:00+05:30', 120, true) = '2026-10-06 11:00+05:30',
  'round-the-clock time runs through the weekend; office time does not');
SELECT pg_temp.rejects($q$UPDATE tms.helpdesk_setting SET time_zone = 'Mars/Olympus'$q$, 'an unknown time zone');
SELECT pg_temp.rejects($q$UPDATE tms.helpdesk_setting SET business_day_end = '08:00'$q$, 'office hours ending before they start');
SELECT pg_temp.rejects($q$UPDATE tms.helpdesk_setting SET clarification_expiry_days = 2$q$, 'a clarification expiring no later than its reminder');
SELECT pg_temp.rejects($q$DELETE FROM tms.helpdesk_setting$q$, 'deleting the settings row');

-- ================================================= routes and forums ==
-- the old employee ladder, as configuration: handlers → KPI owner → KRA owner
-- → KRA head → the category-type head (a fixed office, overseeing) → VC
INSERT INTO tms.ticket_route (code, label, ticket_domain_id) VALUES
 ('T_EMP_NONACAD','Employee — non-academic (test)',pg_temp.lk('tms_ticket_domain','EMPLOYEE')),
 ('T_EMP_ACAD','Employee — academic (test)',pg_temp.lk('tms_ticket_domain','EMPLOYEE')),
 ('T_EMP_POOL_ONLY','Employee — handlers only (test)',pg_temp.lk('tms_ticket_domain','EMPLOYEE')),
 ('T_STU_POOL_ONLY','Student — handlers only (test)',pg_temp.lk('tms_ticket_domain','STUDENT'));
SELECT pg_temp.lvl(r, 1, 'Handlers', 'HANDLER_POOL'), pg_temp.lvl(r, 2, 'KPI owner', 'CATEGORY_OWNER', 'CATEGORY'),
       pg_temp.lvl(r, 3, 'KRA owner', 'CATEGORY_OWNER', 'MASTER'), pg_temp.lvl(r, 4, 'KRA head', 'CATEGORY_OWNER', 'KRA_TYPE'),
       pg_temp.lvl(r, 5, CASE r WHEN 'T_EMP_ACAD' THEN 'Academic head' ELSE 'Administration head' END, 'POSITION', NULL, 'HEAD', 'FIXED_UNIT', NULL,
                   CASE r WHEN 'T_EMP_ACAD' THEN 'T-ACAD' ELSE 'T-ADMIN' END, true),
       pg_temp.lvl(r, 9, 'Vice Chancellor', 'POSITION', NULL, 'VICE_CHANCELLOR', 'CATEGORY_UNIT', 'UNIVERSITY')
FROM unnest(ARRAY['T_EMP_NONACAD', 'T_EMP_ACAD']) r;
SELECT pg_temp.lvl('T_EMP_POOL_ONLY', 1, 'Handlers', 'HANDLER_POOL'), pg_temp.lvl('T_STU_POOL_ONLY', 1, 'Desk', 'HANDLER_POOL');
SELECT pg_temp.ok((SELECT count(*) = 5 FROM tms.ticket_route_level l JOIN tms.ticket_route r ON r.id = l.route_id AND r.code = 'STUDENT_ACADEMIC')
              AND (SELECT k.code = 'MENTOR' FROM tms.ticket_route_level l JOIN ref.tms_route_level_kind k ON k.id = l.route_level_kind_id
                   WHERE l.id = pg_temp.lv('STUDENT_ACADEMIC', 1)),
  'the seeded student academic route: mentor → HOD → Dean → Dean Academics → VC');

SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'POSITION', NULL, 'HEAD')$q$, 'a POSITION level that does not say where to look');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'POSITION', NULL, 'HEAD', 'FIXED_UNIT')$q$, 'a fixed-unit level without the unit');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'POSITION', NULL, 'HEAD', 'REQUESTER_UNIT', NULL, 'T-IT')$q$, 'a unit on a relative level');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'POSITION', NULL, 'REGISTRAR', 'REQUESTER_UNIT', 'DEPARTMENT')$q$,
  'a position that does not exist for the anchor unit type (Registrar of a department)');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'CATEGORY_OWNER')$q$, 'an owner level without the category level');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'CATEGORY_OWNER', 'SUB_CATEGORY')$q$, 'an owner level on the leaf');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'NAMED')$q$, 'a named level without the person');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 7, 'x', 'HANDLER_POOL', NULL, NULL, NULL, NULL, NULL, true)$q$, 'a handler pool that oversees');
SELECT pg_temp.rejects($q$SELECT pg_temp.lvl('T_EMP_NONACAD', 9, 'x', 'NAMED', NULL, NULL, NULL, NULL, NULL, false, 'VC')$q$, 'two levels with the same number');

SELECT pg_temp.rejects($q$UPDATE tms.redressal_forum SET appeal_forum_id = (SELECT id FROM tms.redressal_forum WHERE code = 'SGRC'), appeal_window_days = 10
  WHERE code = 'OMBUDSPERSON'$q$, 'an appeal chain that comes back to itself');
SELECT pg_temp.rejects($q$INSERT INTO tms.redressal_forum (code, label, academic_body_type_id, position_type_id, decision_within_days)
  VALUES ('BOTH', 'Both', ref.id_of('academic_body_type','ANTI_RAGGING_COMMITTEE'), (SELECT id FROM org.position_type WHERE code = 'REGISTRAR'), 5)$q$,
  'a forum that is both a committee and a position');
SELECT pg_temp.rejects($q$INSERT INTO tms.redressal_forum (code, label, position_type_id, decision_within_days, needs_resolution)
  VALUES ('POSRES', 'Position with a resolution', (SELECT id FROM org.position_type WHERE code = 'REGISTRAR'), 5, true)$q$,
  'a position forum whose decision must be a committee resolution');
SELECT pg_temp.rejects($q$INSERT INTO tms.redressal_forum (code, label, position_type_id, decision_within_days, appeal_forum_id)
  VALUES ('NOWIN', 'No window', (SELECT id FROM org.position_type WHERE code = 'REGISTRAR'), 5, (SELECT id FROM tms.redressal_forum WHERE code = 'OMBUDSPERSON'))$q$,
  'an appeal forum without an appeal window');

-- ========================================================= category tree ==
-- employee: the KRA tree (as the old system)
SELECT pg_temp.cat('C-ERP',  NULL,     'KRA_TYPE',     'ERP', 'EMPLOYEE', 'T-IT');
SELECT pg_temp.cat('C-ERPA', 'C-ERP',  'MASTER',       'ERP Academic', NULL, NULL, 'ACADEMIC');
SELECT pg_temp.cat('C-RES',  'C-ERPA', 'CATEGORY',     'Results');
SELECT pg_temp.cat('C-MARKS','C-RES',  'SUB_CATEGORY', 'Marks mismatch', NULL, NULL, NULL, 'HIGH');
SELECT pg_temp.cat('C-ERPN', 'C-ERP',  'MASTER',       'ERP Non-academic', NULL, NULL, 'NON_ACADEMIC');
SELECT pg_temp.cat('C-ACC',  'C-ERPN', 'CATEGORY',     'Access');
SELECT pg_temp.cat('C-PWD',  'C-ACC',  'SUB_CATEGORY', 'Password reset', NULL, NULL, NULL, 'MEDIUM');
SELECT pg_temp.cat('C-NOH',  'C-ACC',  'SUB_CATEGORY', 'No handler yet', NULL, NULL, NULL, 'LOW');
SELECT pg_temp.cat('C-VPN',  'C-ACC',  'SUB_CATEGORY', 'VPN', NULL, NULL, NULL, 'LOW');
SELECT pg_temp.cat('C-EMPTY','C-ACC',  'SUB_CATEGORY', 'Nobody here', NULL, NULL, NULL, 'LOW');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'EMPLOYEE_STANDARD') WHERE id = pg_temp.u('C-ERP');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_EMP_ACAD'),
                               academic_context_rule_id = pg_temp.lk('tms_academic_context_rule','COURSE') WHERE id = pg_temp.u('C-ERPA');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_EMP_NONACAD') WHERE id = pg_temp.u('C-ERPN');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_EMP_POOL_ONLY') WHERE id = pg_temp.u('C-EMPTY');
-- student: academic (the relative route, SGRC), examination, fees & services, ragging (straight to the committee)
SELECT pg_temp.cat('C-SACAD','C-X',    'MASTER',       'never') WHERE false;
SELECT pg_temp.cat('C-SACAD',NULL,     'MASTER',       'Academic', 'STUDENT', 'T-ACAD', 'ACADEMIC');
SELECT pg_temp.cat('C-ATT',  'C-SACAD','CATEGORY',     'Teaching & attendance');
SELECT pg_temp.cat('C-ATTL', 'C-ATT',  'SUB_CATEGORY', 'Attendance shortage', NULL, NULL, NULL, 'MEDIUM');
SELECT pg_temp.cat('C-TEACH','C-ATT',  'SUB_CATEGORY', 'Teaching quality', NULL, NULL, NULL, 'LOW');
SELECT pg_temp.cat('C-CREG', 'C-ATT',  'SUB_CATEGORY', 'Course registration', NULL, NULL, NULL, 'HIGH');
SELECT pg_temp.cat('C-SEX',  NULL,     'MASTER',       'Examination', 'STUDENT', 'T-EXAM', 'EXAMINATION');
SELECT pg_temp.cat('C-SRES', 'C-SEX',  'CATEGORY',     'Results');
SELECT pg_temp.cat('C-SND',  'C-SRES', 'SUB_CATEGORY', 'Result not declared', NULL, NULL, NULL, 'URGENT');
SELECT pg_temp.cat('C-SADM', NULL,     'MASTER',       'Fees & services', 'STUDENT', 'T-FIN', 'NON_ACADEMIC');
SELECT pg_temp.cat('C-FEE',  'C-SADM', 'CATEGORY',     'Fees');
SELECT pg_temp.cat('C-FEER', 'C-FEE',  'SUB_CATEGORY', 'Fee refund', NULL, NULL, NULL, 'MEDIUM');
SELECT pg_temp.cat('C-LIB',  'C-FEE',  'SUB_CATEGORY', 'Library card', NULL, NULL, NULL, 'LOW');
SELECT pg_temp.cat('C-RAG',  NULL,     'MASTER',       'Ragging', 'STUDENT', 'T-SGTU', 'NON_ACADEMIC');
SELECT pg_temp.cat('C-RAGC', 'C-RAG',  'CATEGORY',     'Ragging');
SELECT pg_temp.cat('C-RAGL', 'C-RAGC', 'SUB_CATEGORY', 'Ragging complaint', NULL, NULL, NULL, 'URGENT');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'STUDENT_ACADEMIC'), redressal_forum_id = pg_temp.fid('SGRC'),
       grievance_head_id = pg_temp.lk('tms_grievance_head','QUALITY_OF_EDUCATION'), allows_respondent = true WHERE id = pg_temp.u('C-SACAD');
UPDATE tms.ticket_category SET allows_anonymous = true WHERE id = pg_temp.u('C-TEACH');
UPDATE tms.ticket_category SET academic_context_rule_id = pg_temp.lk('tms_academic_context_rule','COURSE') WHERE id = pg_temp.u('C-CREG');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'STUDENT_EXAMINATION'), redressal_forum_id = pg_temp.fid('SGRC'),
       grievance_head_id = pg_temp.lk('tms_grievance_head','EVALUATION') WHERE id = pg_temp.u('C-SEX');
UPDATE tms.ticket_category SET grievance_head_id = pg_temp.lk('tms_grievance_head','EXAM_RESULT_DELAY') WHERE id = pg_temp.u('C-SND');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'STUDENT_ADMINISTRATIVE'), redressal_forum_id = pg_temp.fid('SGRC'),
       grievance_head_id = pg_temp.lk('tms_grievance_head','EXCESS_FEE') WHERE id = pg_temp.u('C-SADM');
UPDATE tms.ticket_category SET grievance_head_id = pg_temp.lk('tms_grievance_head','FEE_REFUND') WHERE id = pg_temp.u('C-FEER');
UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_STU_POOL_ONLY') WHERE id = pg_temp.u('C-LIB');
UPDATE tms.ticket_category SET redressal_forum_id = pg_temp.fid('ANTI_RAGGING'), direct_to_forum = true, is_confidential = true,
       allows_anonymous = true, allows_respondent = true, requires_incident_date = true,
       grievance_head_id = pg_temp.lk('tms_grievance_head','RAGGING') WHERE id = pg_temp.u('C-RAG');

SELECT pg_temp.ok((SELECT ticket_domain = 'EMPLOYEE' AND category_type = 'NON_ACADEMIC' AND responsible_org_unit_id = pg_temp.u('T-IT')
                          AND kra_type_id = pg_temp.u('C-ERP') AND master_id = pg_temp.u('C-ERPN') AND is_leaf AND depth = 3
                          AND route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_EMP_NONACAD')
                   FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-PWD')),
  'a leaf inherits domain, unit, category type, KRA type, master and the nearest route from its path');
SELECT pg_temp.ok((SELECT needs_context AND needs_course FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-MARKS'))
                  AND NOT (SELECT needs_context FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-PWD')),
  'academic context (with the course) is required below ERP Academic only');
SELECT pg_temp.ok((SELECT route_id = (SELECT id FROM tms.ticket_route WHERE code = 'STUDENT_ACADEMIC') AND redressal_forum_id = pg_temp.fid('SGRC')
                          AND grievance_head_id = pg_temp.lk('tms_grievance_head','QUALITY_OF_EDUCATION') AND allows_respondent
                          AND NOT allows_anonymous AND NOT is_confidential AND NOT direct_to_forum
                   FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-ATTL'))
              AND (SELECT allows_anonymous FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-TEACH')),
  'student academic leaves inherit the academic route, the SGRC, the grievance head and respondents; one leaf adds anonymity');
SELECT pg_temp.ok((SELECT direct_to_forum AND is_confidential AND allows_anonymous AND requires_incident_date AND route_id IS NULL
                          AND redressal_forum_id = pg_temp.fid('ANTI_RAGGING')
                   FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-RAGL')),
  'ragging complaints: straight to the anti-ragging committee, confidential, anonymous allowed, incident date required');

SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X1', NULL, 'KRA_TYPE', 'KRA in student', 'STUDENT', 'T-IT')$q$, 'a KRA type in the student domain');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X2', NULL, 'MASTER', 'Master at the root', 'EMPLOYEE', 'T-IT', 'ACADEMIC')$q$, 'an employee master without a KRA type above it');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X3', 'C-ERP', 'CATEGORY', 'Skips a level')$q$, 'a category directly under a KRA type');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X4', 'C-ERP', 'MASTER', 'No type')$q$, 'a master without a category type');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X5', 'C-ACC', 'SUB_CATEGORY', 'No priority')$q$, 'a leaf without a priority');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X6', 'C-ERPN', 'CATEGORY', 'Priority here', NULL, NULL, NULL, 'LOW')$q$, 'a priority on a non-leaf');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X7', NULL, 'MASTER', 'No unit', 'STUDENT', NULL, 'ACADEMIC')$q$, 'a root without a responsible unit');
SELECT pg_temp.rejects($q$SELECT pg_temp.cat('X8', 'C-ACC', 'SUB_CATEGORY', 'password RESET', NULL, NULL, NULL, 'LOW')$q$, 'a duplicate name under one parent (case-insensitive)');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_category SET route_id = (SELECT id FROM tms.ticket_route WHERE code = 'EMPLOYEE_STANDARD') WHERE id = md5('C-ATT')::uuid$q$,
  'an employee route on a student category');

INSERT INTO tms.ticket_category_owner (category_id, employee_id, valid) VALUES
 (pg_temp.u('C-ACC'),  pg_temp.emp('CO'), daterange('2020-01-01', NULL)),
 (pg_temp.u('C-ERPN'), pg_temp.emp('MO'), daterange('2020-01-01', NULL)),
 (pg_temp.u('C-ERP'),  pg_temp.emp('KH'), daterange('2020-01-01', NULL));
INSERT INTO tms.ticket_category_handler (category_id, employee_id, org_unit_id, sort_order) VALUES
 (pg_temp.u('C-PWD'), pg_temp.emp('H1'), NULL, 1), (pg_temp.u('C-PWD'), pg_temp.emp('H2'), NULL, 2), (pg_temp.u('C-PWD'), pg_temp.emp('RS'), NULL, 3),
 (pg_temp.u('C-VPN'), pg_temp.emp('H3'), NULL, 1), (pg_temp.u('C-MARKS'), pg_temp.emp('H3'), NULL, 1),
 (pg_temp.u('C-FEER'), pg_temp.emp('FH1'), NULL, 1),
 (pg_temp.u('C-FEER'), pg_temp.emp('FH2'), pg_temp.u('T-SET'), 1), (pg_temp.u('C-FEER'), pg_temp.emp('FH3'), pg_temp.u('T-SET'), 2);
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_category_owner (category_id, employee_id) VALUES (md5('C-PWD')::uuid, md5('E-OUT')::uuid)$q$, 'an owner on a leaf');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_category_handler (category_id, employee_id) VALUES (md5('C-ACC')::uuid, md5('E-OUT')::uuid)$q$, 'a handler on a non-leaf');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_category_owner (category_id, employee_id, valid) VALUES (md5('C-ACC')::uuid, md5('E-OUT')::uuid, daterange('2025-01-01', NULL))$q$,
  'two owners of one category at the same time');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_category_handler (category_id, employee_id, org_unit_id) VALUES (md5('C-FEER')::uuid, md5('E-FH2')::uuid, md5('T-SET')::uuid)$q$,
  'the same handler twice for the same unit');

-- ============================================ employee tickets (parity) ==
SELECT pg_temp.tk('T1', 'C-PWD', 'RS', 'SERVICE_REQUEST', NULL, 'rs-key-0001');
SELECT pg_temp.ok((SELECT request_no ~ '^TMS-[0-9]{4}-[0-9]{5}$' AND priority_id = pg_temp.lk('tms_priority','MEDIUM')
                          AND route_id = (SELECT id FROM tms.ticket_route WHERE code = 'T_EMP_NONACAD') AND intake_channel_id = pg_temp.lk('tms_intake_channel','PORTAL')
                   FROM tms.ticket WHERE id = pg_temp.u('T1')),
  'ticket numbered TMS-YYYY-NNNNN; priority and route taken from the leaf; raised on the portal');
SELECT pg_temp.ok((SELECT status = 'OPEN' AND assignee_employee_id = pg_temp.emp('H1') AND level_id = pg_temp.lv('T_EMP_NONACAD', 1)
                          AND level_category_id = pg_temp.u('C-PWD') AND clock_state = 'RUNNING' AND NOT is_manual_assignment
                   FROM pg_temp.s('T1')),
  'T1 (raised by RS): open, round-robin to H1 (RS, a handler too, is skipped as the requester)');
SELECT pg_temp.ok((SELECT s.due_at = tms.business_deadline(t.created_at, 48 * 60) FROM pg_temp.s('T1') s JOIN tms.ticket t ON t.id = s.ticket_id),
  'the due time is 48 office hours after raising (MEDIUM)');
SELECT pg_temp.tk('T2', 'C-PWD', 'RF');
SELECT pg_temp.tk('T3', 'C-PWD', 'RF');
SELECT pg_temp.tk('T4', 'C-PWD', 'RS');
SELECT pg_temp.ok((SELECT assignee_employee_id FROM pg_temp.s('T2')) = pg_temp.emp('H2')
              AND (SELECT assignee_employee_id FROM pg_temp.s('T3')) = pg_temp.emp('RS')
              AND (SELECT assignee_employee_id FROM pg_temp.s('T4')) = pg_temp.emp('H1'),
  'round-robin in order H1 → H2 → RS; for RS''s own ticket the turn after RS restarts at H1');
SELECT pg_temp.tk('T5', 'C-NOH', 'RF');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('CO') AND level_id = pg_temp.lv('T_EMP_NONACAD', 2) AND level_category_id = pg_temp.u('C-ACC')
                   FROM pg_temp.s('T5'))
              AND (SELECT b.code = 'ROUTE' FROM tms.ticket_event e JOIN ref.tms_assignment_basis b ON b.id = e.assignment_basis_id
                   WHERE e.ticket_id = pg_temp.u('T5')),
  'a leaf without handlers: the next level of the route (the KPI owner) takes it, at that level');
SELECT pg_temp.tk('T6', 'C-PWD', 'CO');
SELECT pg_temp.ok((SELECT assignee_employee_id FROM pg_temp.s('T6')) = pg_temp.emp('H2'), 'T6 (raised by CO): the next turn after H1 is H2');
SELECT pg_temp.tk('T9', 'C-PWD', 'RS', 'SERVICE_REQUEST', 'H2');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('H2') AND is_manual_assignment AND level_id = pg_temp.lv('T_EMP_NONACAD', 1)
                   FROM pg_temp.s('T9')),
  'non-teaching staff may choose the handler (manual assignment)');
SELECT pg_temp.tk('T10', 'C-PWD', 'RS', 'SERVICE_REQUEST', 'MO');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('MO') AND level_id = pg_temp.lv('T_EMP_NONACAD', 3) AND level_category_id = pg_temp.u('C-ERPN')
                   FROM pg_temp.s('T10')),
  'a manually chosen owner starts the ticket at the owner''s route level');

SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X11', 'C-PWD', 'RF', 'ENQUIRY')$q$, 'an employee ticket with a student-only message type');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket (requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
  VALUES (md5('A-RF')::uuid, md5('C-PWD')::uuid, ref.id_of('tms_message_type','SERVICE_REQUEST'), 'Not my phone', 'Using somebody else''s number', md5('PH-RS')::uuid)$q$,
  'a contact number that is not the requester''s own');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket (requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
  VALUES (md5('A-RF')::uuid, md5('C-PWD')::uuid, ref.id_of('tms_message_type','GRIEVANCE'), 'No relief', 'A grievance without the relief sought', md5('PH-RF')::uuid)$q$,
  'a grievance that does not state the relief sought');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X12', 'C-ACC', 'RF')$q$, 'a ticket under a non-leaf category');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X13', 'C-PWD', 'ST')$q$, 'a student raising an employee ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X14', 'C-PWD', 'RF', 'SERVICE_REQUEST', 'H1')$q$, 'faculty choosing the assignee (not permitted)');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X15', 'C-PWD', 'RS', 'SERVICE_REQUEST', 'OUT')$q$, 'a chosen assignee who is not on the category''s route');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X16', 'C-PWD', 'RS', 'SERVICE_REQUEST', 'RS')$q$, 'choosing oneself as the assignee');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X17', 'C-PWD', 'RS', 'SERVICE_REQUEST', NULL, 'rs-key-0001')$q$, 'the same idempotency key twice');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X18', 'C-PWD', 'RS', 'SERVICE_REQUEST', NULL, NULL, true)$q$, 'an anonymous ticket where the category does not allow it');
SELECT pg_temp.rejects($q$UPDATE tms.ticket SET subject = 'Edited' WHERE id = md5('T1')::uuid$q$, 'editing a raised ticket');
SELECT pg_temp.rejects($q$DELETE FROM tms.ticket WHERE id = md5('T1')::uuid$q$, 'deleting a ticket');
UPDATE tms.ticket_category SET is_active = false WHERE id = pg_temp.u('C-ACC');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X19', 'C-VPN', 'RF')$q$, 'a ticket under a leaf whose parent is inactive');
UPDATE tms.ticket_category SET is_active = true WHERE id = pg_temp.u('C-ACC');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_category SET parent_id = md5('C-ERPA')::uuid WHERE id = md5('C-ACC')::uuid$q$,
  'moving a category that has tickets under it');

-- academic context (employee side: any batch)
SET CONSTRAINTS tms.trg_ticket_context_required IMMEDIATE;
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X20', 'C-MARKS', 'RS')$q$, 'an ERP-academic ticket without batch / term / course');
SET CONSTRAINTS tms.trg_ticket_context_required DEFERRED;
SELECT pg_temp.tk('T7', 'C-MARKS', 'RS');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
  VALUES (md5('T7')::uuid, md5('B26')::uuid, md5('ODD26')::uuid, md5('CS301')::uuid, 4)$q$, 'an even semester in an odd term');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
  VALUES (md5('T7')::uuid, md5('B26')::uuid, md5('ODD26')::uuid, md5('CS301')::uuid, 9)$q$, 'a semester beyond the programme''s 8');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, term_no)
  VALUES (md5('T7')::uuid, md5('B26')::uuid, md5('ODD26')::uuid, 3)$q$, 'no course where the category''s rule needs it');
INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
VALUES (pg_temp.u('T7'), pg_temp.u('B26'), pg_temp.u('ODD26'), pg_temp.u('CS301'), 3);
SET CONSTRAINTS tms.trg_ticket_context_required IMMEDIATE;
SET CONSTRAINTS tms.trg_ticket_context_required DEFERRED;
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('H3') AND priority_id = pg_temp.lk('tms_priority','HIGH') FROM pg_temp.s('T7')),
  'T7 with its academic context (batch 2026, odd term, semester 3, CS301): H3, HIGH — an employee may name any batch');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
  VALUES (md5('T1')::uuid, md5('B26')::uuid, md5('ODD26')::uuid, md5('CS301')::uuid, 3)$q$, 'academic context on a ticket whose category takes none');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_academic_context SET term_no = 5 WHERE ticket_id = md5('T7')::uuid$q$, 'editing the academic context');

-- acting: internal notes
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'REMARKED', 'OUT', 'Not mine')$q$, 'an outsider acting on a ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'REMARKED', 'H1')$q$, 'a note without text');
SELECT pg_temp.ev('T1', 'REMARKED', 'H1', 'Looking into it');
SELECT pg_temp.ev('T1', 'REMARKED', 'TA', 'Admin note');
SELECT pg_temp.ev('T1', 'REMARKED', 'AD', 'Administration head watching');
SELECT pg_temp.ev('T1', 'REMARKED', 'KH', 'KRA head watching');
SELECT pg_temp.ok((SELECT count(*) = 4 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'REMARKED'
                   WHERE e.ticket_id = pg_temp.u('T1')),
  'notes by the assignee, the TMS admin, the overseeing administration head and the KRA head');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'REMARKED', 'EX', 'Exam head on a non-academic ticket')$q$, 'a head who is not on the ticket''s route');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'REMARKED', 'ITH', 'Unit head')$q$, 'a unit head (view-only supervision) acting');

-- clarification pauses and resumes the clock
SELECT pg_temp.ev('T1', 'CLARIFICATION_REQUESTED', 'H1', 'Which account is locked?');
SELECT pg_temp.ok((SELECT clock_state = 'PAUSED' AND due_at IS NULL AND paused_remaining_minutes > 0 FROM pg_temp.s('T1')),
  'asking for clarification pauses the clock and keeps the office minutes left');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'CLARIFICATION_REQUESTED', 'H1', 'Again?')$q$, 'a second clarification request while one is pending');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'CLARIFICATION_PROVIDED', 'H1', 'Answering for the requester')$q$, 'someone other than the requester answering');
SET CONSTRAINTS tms.trg_ticket_event_complete IMMEDIATE;
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'CLARIFICATION_PROVIDED', 'RS')$q$, 'a clarification with neither reply nor document');
SET CONSTRAINTS tms.trg_ticket_event_complete DEFERRED;
SELECT pg_temp.ev('T1', 'CLARIFICATION_PROVIDED', 'RS', 'The ERP account rs.tms');
SELECT pg_temp.ok((SELECT clock_state = 'RUNNING' AND due_at > now() FROM pg_temp.s('T1')), 'the reply resumes the clock with the minutes that were left');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'CLARIFICATION_PROVIDED', 'RS', 'Nothing was asked')$q$, 'a clarification when none is pending');

-- escalation up the route
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'ESCALATED', 'H1')$q$, 'escalating without a reason');
SELECT pg_temp.ev('T1', 'ESCALATED', 'H1', 'Needs the access owner');
SELECT pg_temp.ok((SELECT status = 'ESCALATED' AND assignee_employee_id = pg_temp.emp('CO') AND level_id = pg_temp.lv('T_EMP_NONACAD', 2) AND clock_state = 'RUNNING'
                   FROM pg_temp.s('T1')),
  'escalation 1: the KPI owner (CO)');
SELECT pg_temp.ev('T1', 'ESCALATED', 'CO', 'KRA owner please');
SELECT pg_temp.ev('T1', 'ESCALATED', 'MO', 'KRA head please');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('KH') AND level_category_id = pg_temp.u('C-ERP') FROM pg_temp.s('T1')),
  'escalations 2–3: KRA owner, then the KRA head');
SELECT pg_temp.ev('T1', 'ESCALATED', 'KH', 'Beyond the KRA');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('AD') AND level_id = pg_temp.lv('T_EMP_NONACAD', 5) AND level_category_id IS NULL FROM pg_temp.s('T1')),
  'escalation 4: the head of the fixed Administration office');
SELECT pg_temp.ev('T1', 'ESCALATED', 'AD', 'To the VC');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('VC') FROM pg_temp.s('T1')) AND NOT EXISTS (SELECT 1 FROM tms.next_escalation(pg_temp.u('T1'))),
  'escalation 5: the Vice Chancellor — nobody above');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'ESCALATED', 'VC', 'Higher?')$q$, 'escalating beyond the top');
SELECT pg_temp.ok((SELECT escalation_count = 5 FROM pg_temp.s('T1')), 'five escalations counted');
SELECT pg_temp.ev('T6', 'ESCALATED', 'H2', 'Owner please');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('MO') FROM pg_temp.s('T6')),
  'the KPI owner raised T6 himself, so the escalation skips him to the KRA owner');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id, remarks) VALUES (md5('T4')::uuid, ref.id_of('tms_event_type','AUTO_ESCALATED'), 'x')$q$,
  'an automatic escalation outside the scheduled job');

-- reassignment and transfer
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REASSIGNED', 'H2', 'To an outsider', 'OUT')$q$, 'reassigning to someone who is not a handler of the category');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REASSIGNED', 'H2', 'To myself', 'H2')$q$, 'reassigning to the current handler');
SELECT pg_temp.ev('T2', 'REASSIGNED', 'H2', 'H1 knows this system', 'H1');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('H1') AND status = 'OPEN' FROM pg_temp.s('T2')), 'reassigned to H1 within the category; status unchanged');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T1', 'REASSIGNED', 'VC', 'Back to a handler', 'H1')$q$, 'reassigning above the handler level');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T4', 'REASSIGNED', 'H1', 'To the requester', 'RS')$q$, 'reassigning to the requester');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T3', 'TRANSFERRED', 'RS', 'Wrong area', NULL, 'C-MARKS')$q$, 'a transfer into a category needing academic context');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T3', 'TRANSFERRED', 'RS', 'Wrong area', NULL, 'C-EMPTY')$q$, 'a transfer into a category nobody on whose route can take it');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T3', 'TRANSFERRED', 'RS', 'Wrong area', NULL, 'C-SND')$q$, 'a transfer into the other domain');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T3', 'TRANSFERRED', 'RS', 'Same', NULL, 'C-PWD')$q$, 'a transfer into the same category');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T3', 'REMARKED', 'RS', 'A category', NULL, 'C-VPN')$q$, 'a category on an event that is not a transfer');
SELECT pg_temp.ev('T3', 'TRANSFERRED', 'RS', 'This is a VPN problem', NULL, 'C-VPN');
SELECT pg_temp.ok((SELECT category_id = pg_temp.u('C-VPN') AND assignee_employee_id = pg_temp.emp('H3') AND level_category_id = pg_temp.u('C-VPN')
                          AND priority_id = pg_temp.lk('tms_priority','LOW') AND status = 'OPEN' FROM pg_temp.s('T3')),
  'transferred to VPN: its handler H3, its priority LOW, back to OPEN');

-- resolve → the requester accepts, reopens or rates
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RESOLVED', 'RF', 'Fixed it myself')$q$, 'the requester resolving their own ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RESOLVED', 'H1')$q$, 'resolving without closure remarks');
SELECT pg_temp.ev('T2', 'RESOLVED', 'H1', 'Password reset done');
SELECT pg_temp.ok((SELECT status = 'RESOLVED' AND awaits_requester AND NOT is_closed AND clock_state = 'STOPPED' AND due_at IS NULL
                          AND resolved_by_account_id = pg_temp.acct('H1') AND resolution_event = 'RESOLVED' FROM pg_temp.s('T2')),
  'resolved: awaiting the requester, clock stopped, resolver recorded (old system closed at once)');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REPLIED', 'H1', 'One more thing')$q$, 'a reply on a resolved ticket (the lifecycle table)');
SELECT pg_temp.ev('T2', 'REMARKED', 'H1', 'Internal: root cause was an expired password');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RATED', 'OUT', NULL, NULL, NULL, 4::smallint)$q$, 'a rating by someone else');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RATED', 'RF', NULL, NULL, NULL, 6::smallint)$q$, 'a rating of 6');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RATED', 'RF')$q$, 'a rating without a value');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T4', 'REMARKED', 'H1', 'x', NULL, NULL, 3::smallint)$q$, 'a rating on an event that is not a rating');
SELECT pg_temp.ev('T2', 'RATED', 'RF', 'Quick', NULL, NULL, 4::smallint);
SELECT pg_temp.ok((SELECT rating = 4 FROM pg_temp.s('T2')), 'rated 4 while the resolution awaits acceptance');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RATED', 'RF', NULL, NULL, NULL, 5::smallint)$q$, 'rating twice');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REOPENED', 'RF')$q$, 'reopening without a reason');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REOPENED', 'H1', 'Not solved')$q$, 'reopening by someone other than the requester');
SELECT pg_temp.ev('T2', 'REOPENED', 'RF', 'It is locked again');
SELECT pg_temp.ok((SELECT status = 'OPEN' AND clock_state = 'RUNNING' AND rating IS NULL AND assignee_employee_id = pg_temp.emp('H1') AND reopen_count = 1
                   FROM pg_temp.s('T2')),
  'reopened: open with a new due time, same handler, the rating no longer current (but kept in the timeline)');
SELECT pg_temp.ok((SELECT count(*) = 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'RATED' WHERE e.ticket_id = pg_temp.u('T2')),
  'the earlier rating stays on the timeline (old system deleted it)');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'RATED', 'RF', NULL, NULL, NULL, 5::smallint)$q$, 'rating an open ticket');
SELECT pg_temp.ev('T2', 'RESOLVED', 'H1', 'Reset again, MFA re-enrolled');
SELECT pg_temp.ev('T2', 'CONFIRMED', 'RF');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND is_closed AND closed_at IS NOT NULL
                          AND closure_reason_id = pg_temp.lk('tms_closure_reason','RESOLVED') FROM pg_temp.s('T2')),
  'the requester accepts: closed, the reason taken from the resolution');
SELECT pg_temp.ev('T2', 'REOPENED', 'RF', 'Locked a third time');
SELECT pg_temp.ev('T2', 'RESOLVED', 'H1', 'Account unlocked');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T2', 'REOPENED', 'RF', 'And again')$q$, 'a third reopening (max_reopens = 2)');
UPDATE tms.helpdesk_setting SET max_reopens = 3;
SELECT pg_temp.ev('T2', 'REOPENED', 'RF', 'And again');
SELECT pg_temp.ok((SELECT reopen_count = 3 AND status = 'OPEN' FROM pg_temp.s('T2')), 'with max_reopens raised to 3 the third reopening is taken');
UPDATE tms.helpdesk_setting SET max_reopens = 2;
SELECT pg_temp.ev('T2', 'RESOLVED', 'H1', 'Unlocked for good');
SELECT pg_temp.ev('T2', 'CONFIRMED', 'RF');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_event SET remarks = 'rewritten' WHERE ticket_id = md5('T2')::uuid$q$, 'rewriting the timeline');
SELECT pg_temp.rejects($q$DELETE FROM tms.ticket_event WHERE ticket_id = md5('T2')::uuid$q$, 'deleting from the timeline');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM tms.v_ticket_requester_timeline WHERE ticket_id = pg_temp.u('T2') AND event_type IN ('REASSIGNED', 'REMARKED'))
              AND EXISTS (SELECT 1 FROM tms.v_ticket_requester_timeline WHERE ticket_id = pg_temp.u('T2') AND event_type = 'RESOLVED'),
  'requester timeline: resolution shown, internal notes and reassignment hidden');

-- who may see / act
SELECT pg_temp.ok(tms.can_view(pg_temp.acct('RS'), pg_temp.u('T1')) AND tms.can_view(pg_temp.acct('H1'), pg_temp.u('T1'))
              AND tms.can_view(pg_temp.acct('ITH'), pg_temp.u('T1')) AND tms.can_view(pg_temp.acct('MO'), pg_temp.u('T5'))
              AND NOT tms.can_view(pg_temp.acct('OUT'), pg_temp.u('T1')) AND NOT tms.can_view(pg_temp.acct('RF'), pg_temp.u('T1')),
  'view: requester, past handler, head of IT (the responsible unit), an owner above; not an outsider or another requester');
SELECT pg_temp.ok(tms.can_act(pg_temp.acct('VC'), pg_temp.u('T1')) AND NOT tms.can_act(pg_temp.acct('H1'), pg_temp.u('T1'))
              AND tms.can_act(pg_temp.acct('TA'), pg_temp.u('T1')) AND NOT tms.can_act(pg_temp.acct('ITH'), pg_temp.u('T1')),
  'act: the current assignee (VC) and the TMS admin; no longer the first handler; not the head of IT');

-- ======================================================= student tickets ==
INSERT INTO tms.helpdesk_declaration (ticket_domain_id, body, valid) VALUES
 (pg_temp.lk('tms_ticket_domain','STUDENT'),
  'The information given is true; the matter is not before a court; I have read the relevant notices before raising it.', daterange('2026-01-01', NULL));
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X30', 'C-ATTL', 'ST', 'ENQUIRY')$q$, 'a student ticket while Student TMS is switched off');
UPDATE tms.helpdesk_setting SET student_tms_enabled = true;

-- the academic path is relative to the student: mentor → HOD → Dean → Dean Academics → VC
SELECT pg_temp.tk('S1', 'C-ATTL', 'ST', 'ENQUIRY');
SELECT pg_temp.ok((SELECT requester_org_unit_id = pg_temp.u('T-CSE') AND declaration_id IS NOT NULL AND route_id = (SELECT id FROM tms.ticket_route WHERE code = 'STUDENT_ACADEMIC')
                   FROM tms.ticket WHERE id = pg_temp.u('S1'))
              AND (SELECT assignee_employee_id = pg_temp.emp('MEN') AND level_id = pg_temp.lv('STUDENT_ACADEMIC', 1) AND ticket_domain = 'STUDENT'
                   FROM pg_temp.s('S1'))
              AND (SELECT b.code = 'ROUTE' FROM tms.ticket_event e JOIN ref.tms_assignment_basis b ON b.id = e.assignment_basis_id WHERE e.ticket_id = pg_temp.u('S1')),
  'S1 (CSE student): filed under the student''s department, the declaration recorded, to the student''s mentor');
SELECT pg_temp.tk('S2', 'C-ATTL', 'ST2', 'ENQUIRY');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('DA') AND level_id = pg_temp.lv('STUDENT_ACADEMIC', 4) FROM pg_temp.s('S2')),
  'S2 (MBA student without mentor, HOD or Dean in post): vacant levels are skipped — Dean Academics');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket (requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
  VALUES (md5('A-ST')::uuid, md5('C-ATTL')::uuid, ref.id_of('tms_message_type','ENQUIRY'), 'No declaration', 'Raised without the declaration', md5('PH-ST')::uuid)$q$,
  'a student ticket that does not accept the declaration in force');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X31', 'C-ATTL', 'ST', 'SERVICE_REQUEST')$q$, 'a student using an employee-only message type');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X32', 'C-ATTL', 'ST', 'ENQUIRY', NULL, NULL, false, NULL, NULL, 'WALK_IN')$q$, 'a walk-in ticket without the desk that recorded it');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X33', 'C-ATTL', 'ST', 'ENQUIRY', NULL, NULL, false, NULL, 'DESK', 'PORTAL')$q$, 'the desk recording a portal ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X34', 'C-ATTL', 'ST', 'ENQUIRY', NULL, NULL, false, NULL, 'OUT', 'WALK_IN')$q$, 'someone without intake permission recording a ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X35', 'C-ATTL', 'ST2', 'ENQUIRY', NULL, NULL, false, NULL, 'DESK', 'WALK_IN')$q$,
  'the School of Engineering desk recording for a management student');
SELECT pg_temp.tk('S3', 'C-ATTL', 'ST', 'GRIEVANCE', NULL, NULL, false, NULL, 'DESK', 'WALK_IN');
SELECT pg_temp.ok((SELECT raised_by_account_id = pg_temp.acct('DESK') AND intake_channel_id = pg_temp.lk('tms_intake_channel','WALK_IN') AND relief_sought IS NOT NULL
                   FROM tms.ticket WHERE id = pg_temp.u('S3'))
              AND (SELECT actor_account_id = pg_temp.acct('DESK') FROM tms.ticket_event WHERE ticket_id = pg_temp.u('S3'))
              AND (SELECT assignee_employee_id = pg_temp.emp('MEN') FROM pg_temp.s('S3')),
  'S3: a walk-in grievance recorded by the intake desk for the student, routed as if raised by the student');
SELECT pg_temp.ok(tms.can_view(pg_temp.acct('DEAN'), pg_temp.u('S3')) AND tms.can_view(pg_temp.acct('HOD'), pg_temp.u('S3'))
              AND tms.can_view(pg_temp.acct('DSW'), pg_temp.u('S3')) AND NOT tms.can_view(pg_temp.acct('FINH'), pg_temp.u('S3'))
              AND NOT tms.can_view(pg_temp.acct('DSW'), pg_temp.u('T1')),
  'the Dean and HOD of the student''s school / department and the DSW see S3; the head of Finance does not; the DSW sees no employee ticket');

SELECT pg_temp.ev('S1', 'ESCALATED', 'MEN', 'Needs the HOD');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('HOD') AND level_id = pg_temp.lv('STUDENT_ACADEMIC', 2) FROM pg_temp.s('S1')),
  'escalation 1: the Head of the student''s department');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S1', 'ESCALATED', 'ST', 'Please hurry')$q$, 'the requester escalating a ticket that is not overdue');
UPDATE tms.helpdesk_setting SET requester_may_escalate_overdue = false;
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S1', 'ESCALATED', 'ST', 'Please hurry')$q$, 'the requester escalating with the setting off');
UPDATE tms.helpdesk_setting SET requester_may_escalate_overdue = true;
SELECT pg_temp.ev('S1', 'ESCALATED', 'HOD', 'Dean please');
SELECT pg_temp.ev('S1', 'ESCALATED', 'DEAN', 'Dean Academics please');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('DA') FROM pg_temp.s('S1')), 'escalations 2–3: the Dean of the student''s school, then Dean Academics');
SELECT pg_temp.ev('S1', 'ESCALATED', 'DA', 'To the VC');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('VC') AND level_id = pg_temp.lv('STUDENT_ACADEMIC', 5) FROM pg_temp.s('S1'))
              AND NOT EXISTS (SELECT 1 FROM tms.next_escalation(pg_temp.u('S1'))),
  'escalation 4: the Vice Chancellor — the top of the academic route');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S1', 'REFERRED', 'ST', 'To the committee')$q$, 'an enquiry referred to a grievance committee');
SELECT pg_temp.ok(pg_temp.notices('S1', 'CREATED', 'ST') = 2 AND pg_temp.notices('S1', 'CREATED', 'MEN') = 2
              AND pg_temp.notices('S1', 'ESCALATED', 'ST', 'IN_APP') = 4 AND pg_temp.notices('S1', 'ESCALATED', 'HOD') = 2
              AND pg_temp.notices('S1', 'ESCALATED', 'MEN') = 0,
  'the student gets a receipt and hears of every escalation; each new holder is told (not whoever escalated it themselves)');

-- course registration: academic context of the student's own batch, with the course
SELECT pg_temp.tk('S8', 'C-CREG', 'ST', 'ENQUIRY');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
  VALUES (md5('S8')::uuid, md5('BM26')::uuid, md5('ODD26')::uuid, md5('CS301')::uuid, 3)$q$, 'a student naming a batch that is not theirs');
INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
VALUES (pg_temp.u('S8'), pg_temp.u('B26'), pg_temp.u('ODD26'), pg_temp.u('CS301'), 3);
SET CONSTRAINTS tms.trg_ticket_context_required IMMEDIATE;
SET CONSTRAINTS tms.trg_ticket_context_required DEFERRED;
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('MEN') FROM pg_temp.s('S8')), 'S8 with the student''s own batch and the course');

-- fee refunds: the most specific handler scope serving the student wins
SELECT pg_temp.tk('S4', 'C-FEER', 'ST', 'GRIEVANCE');
SELECT pg_temp.tk('S6', 'C-FEER', 'ST', 'GRIEVANCE');
SELECT pg_temp.tk('S5', 'C-FEER', 'ST2', 'GRIEVANCE');
SELECT pg_temp.ok((SELECT assignee_employee_id FROM pg_temp.s('S4')) = pg_temp.emp('FH2') AND (SELECT assignee_employee_id FROM pg_temp.s('S6')) = pg_temp.emp('FH3')
              AND (SELECT assignee_employee_id FROM pg_temp.s('S5')) = pg_temp.emp('FH1'),
  'engineering students go round the School of Engineering fee desk (FH2, FH3); a management student to the general desk (FH1)');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S5', 'REASSIGNED', 'FH1', 'Engineering desk', 'FH2')$q$, 'reassigning to a handler who does not serve the requester''s unit');
SELECT pg_temp.ev('S6', 'REASSIGNED', 'FH3', 'General desk', 'FH1');

-- public replies, internal notes, requester comments, files, first response
SELECT pg_temp.ev('S4', 'REPLIED', 'FH2', 'Your refund request is being checked');
INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES (pg_temp.last_ev('S4'), pg_temp.u('F1'));
SELECT pg_temp.ev('S4', 'REMARKED', 'FH2', 'Internal: accounts to confirm the bank details');
SELECT pg_temp.ev('S4', 'REQUESTER_COMMENTED', 'ST', 'The amount is 45,000');
SELECT pg_temp.ok((SELECT count(*) = 3 FROM tms.v_ticket_requester_timeline WHERE ticket_id = pg_temp.u('S4'))
              AND NOT EXISTS (SELECT 1 FROM tms.v_ticket_requester_timeline WHERE ticket_id = pg_temp.u('S4') AND event_type = 'REMARKED'),
  'the student sees the receipt, the reply and their comment — never the internal note');
SELECT pg_temp.ok(pg_temp.notices('S4', 'REPLIED', 'ST') = 2 AND pg_temp.notices('S4', 'REMARKED', 'ST') = 0
              AND pg_temp.notices('S4', 'REQUESTER_COMMENTED', 'FH2') = 2,
  'a reply reaches the student; a note does not; the student''s comment reaches the handler');
SELECT pg_temp.ok((SELECT first_responded_at IS NOT NULL AND NOT first_response_breached AND first_response_due_at > first_responded_at
                   FROM tms.v_ticket_sla WHERE ticket_id = pg_temp.u('S4')),
  'first response recorded within the MEDIUM target (8 office hours)');
UPDATE tms.helpdesk_setting SET max_files_per_event = 1;
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id)
  VALUES ((SELECT max(e.id) FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'REPLIED' WHERE e.ticket_id = md5('S4')::uuid), md5('F2')::uuid)$q$,
  'a second file with max_files_per_event = 1');
UPDATE tms.helpdesk_setting SET max_files_per_event = 5;
SELECT pg_temp.ev('S6', 'CLARIFICATION_REQUESTED', 'FH1', 'Please upload the fee receipt');
SELECT pg_temp.ev('S6', 'CLARIFICATION_PROVIDED', 'ST');
INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES (pg_temp.last_ev('S6'), pg_temp.u('F3'));
SET CONSTRAINTS tms.trg_ticket_event_complete IMMEDIATE;
SET CONSTRAINTS tms.trg_ticket_event_complete DEFERRED;
SELECT pg_temp.ok((SELECT clock_state = 'RUNNING' FROM pg_temp.s('S6')), 'a clarification answered with a document only (no text) is accepted');

-- a complaint against a person: recusal and invisibility
SELECT pg_temp.tk('S15', 'C-TEACH', 'ST', 'GRIEVANCE', NULL, NULL, true);
SELECT pg_temp.ok(NOT tms.requester_shown_to(pg_temp.acct('MEN'), pg_temp.u('S15')) AND tms.requester_shown_to(pg_temp.acct('ST'), pg_temp.u('S15'))
              AND tms.requester_shown_to(pg_temp.acct('CV'), pg_temp.u('S15')) AND tms.requester_shown_to(pg_temp.acct('MEN'), pg_temp.u('S1')),
  'an anonymous ticket hides the requester from the mentor handling it; not from the requester or an authorised viewer');
INSERT INTO tms.ticket_respondent (ticket_id, person_id, added_by_account_id) VALUES (pg_temp.u('S15'), pg_temp.u('P-MEN'), pg_temp.acct('ST'));
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('HOD') FROM pg_temp.s('S15'))
              AND EXISTS (SELECT 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'RECUSED' WHERE e.ticket_id = pg_temp.u('S15')),
  'naming the mentor who holds the ticket moves it on to the HOD (recusal)');
SELECT pg_temp.ok(NOT tms.can_view(pg_temp.acct('MEN'), pg_temp.u('S15')) AND NOT tms.can_act(pg_temp.acct('MEN'), pg_temp.u('S15')),
  'the respondent can neither see nor act on the ticket, though they once held it');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_respondent (ticket_id, person_id, added_by_account_id) VALUES (md5('S4')::uuid, md5('P-FH1')::uuid, md5('A-ST')::uuid)$q$,
  'a respondent in a category that takes no complaints against a person');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_respondent (ticket_id, person_id, added_by_account_id) VALUES (md5('S15')::uuid, md5('P-ST')::uuid, md5('A-ST')::uuid)$q$,
  'the requester as the respondent');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_respondent (ticket_id, person_id, added_by_account_id) VALUES (md5('S15')::uuid, md5('P-OUT')::uuid, md5('A-OUT')::uuid)$q$,
  'an outsider naming a respondent');
SELECT pg_temp.rejects($q$DELETE FROM tms.ticket_respondent WHERE ticket_id = md5('S15')::uuid$q$, 'removing a respondent');

-- ============================================ grievance redressal (UGC) ==
-- S4: resolved, reopened twice, then referred to the school's SGRC, decided
-- by a quorate resolution, appealed to the Ombudsperson, decided, accepted
SELECT pg_temp.ev('S4', 'RESOLVED', 'FH2', 'Refund of 40,000 processed');
SELECT pg_temp.ev('S4', 'REOPENED', 'ST', 'The full 45,000 was due');
SELECT pg_temp.ev('S4', 'RESOLVED', 'FH2', 'Only 40,000 is refundable');
SELECT pg_temp.ev('S4', 'REOPENED', 'ST', 'The prospectus says otherwise');
SELECT pg_temp.ev('S4', 'RESOLVED', 'FH2', 'Decision stands');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'REOPENED', 'ST', 'Third time')$q$, 'a third reopening — the grievance goes to the committee instead');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'REFERRED', 'FH2', 'Handler refers the resolved ticket')$q$, 'the handling side referring a ticket it resolved');
SELECT pg_temp.ev('S4', 'REFERRED', 'ST', 'I am not satisfied with the resolution');
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND forum_id = pg_temp.fid('SGRC') AND academic_body_id = pg_temp.u('SGRC-SET') AND assignee_employee_id IS NULL
                          AND clock_state = 'RUNNING' FROM pg_temp.s('S4'))
              AND (SELECT due_at = occurred_at + interval '15 days' FROM tms.ticket_event WHERE id = pg_temp.last_ev('S4')),
  'referred by the dissatisfied student: with the School of Engineering SGRC (the nearest), 15 days to decide');
SELECT pg_temp.ok(pg_temp.notices('S4', 'REFERRED', 'SG1') = 2 AND pg_temp.notices('S4', 'REFERRED', 'SG3') = 2
              AND pg_temp.notices('S4', 'REFERRED', 'ST') = 2 AND pg_temp.notices('S4', 'REFERRED', 'FH2', 'IN_APP') = 1,
  'the committee members are told; the student gets a receipt; the former handler hears it left them');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'REPLIED', 'FH2', 'Still mine?')$q$, 'the former handler acting once the committee has it');
SELECT pg_temp.ev('S4', 'REPLIED', 'SG1', 'The committee will hear you on Monday');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'FH2', 'Not a member', NULL, NULL, NULL, NULL, NULL, 'NOT_UPHELD')$q$, 'a decision by someone outside the committee');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'SG1', 'No outcome')$q$, 'a decision without its outcome');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'SG1', 'Chair alone', NULL, NULL, NULL, NULL, NULL, 'NOT_UPHELD')$q$,
  'a committee decision that is not a resolution of a meeting');
INSERT INTO academic.body_meeting (id, academic_body_id, meeting_no, held_on) VALUES
 (pg_temp.u('MT1'), pg_temp.u('SGRC-SET'), 'SGRC-SET/2026/01', current_date),
 (pg_temp.u('MT2'), pg_temp.u('SGRC-U'),   'SGRC-U/2026/01',   current_date),
 (pg_temp.u('MT3'), pg_temp.u('ARC'),      'ARC/2026/01',      current_date);
INSERT INTO academic.body_meeting_attendee (body_meeting_id, academic_body_member_id)
SELECT pg_temp.u(v.mt), pg_temp.u('M-' || v.who) FROM (VALUES ('MT1','SG1'),('MT1','SG2'),('MT1','SG3'),('MT2','SGU'),('MT3','AR1'),('MT3','AR2')) v(mt, who);
INSERT INTO academic.body_resolution (id, body_meeting_id, resolution_no, subject, decision) VALUES
 (pg_temp.u('RES1'), pg_temp.u('MT1'), 'R-1', 'Fee refund grievance', 'The refund of 40,000 is in line with the refund policy'),
 (pg_temp.u('RES2'), pg_temp.u('MT2'), 'R-1', 'Another matter', 'Recorded'),
 (pg_temp.u('RES3'), pg_temp.u('MT3'), 'R-1', 'Ragging complaint', 'Proven; disciplinary action recommended');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'SG1', 'Wrong body', NULL, NULL, NULL, NULL, NULL, 'NOT_UPHELD', 'RES2')$q$,
  'a decision citing another committee''s resolution');
SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'SG1', 'Refund policy applied correctly', NULL, NULL, NULL, NULL, NULL, 'NOT_UPHELD', 'RES1');
SELECT pg_temp.ok((SELECT status = 'RESOLVED' AND resolution_event = 'FORUM_DECIDED' AND redressal_outcome_id = pg_temp.lk('tms_redressal_outcome','NOT_UPHELD')
                   FROM pg_temp.s('S4')),
  'the SGRC decides (resolution R-1 of a quorate meeting): not upheld — the student may now appeal');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'REOPENED', 'ST', 'Reopen instead')$q$, 'reopening a forum decision');
SELECT pg_temp.ev('S4', 'APPEALED', 'ST', 'Appeal to the Ombudsperson');
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND forum_id = pg_temp.fid('OMBUDSPERSON') AND assignee_employee_id = pg_temp.emp('OMB') AND academic_body_id IS NULL
                   FROM pg_temp.s('S4'))
              AND (SELECT due_at = occurred_at + interval '30 days' FROM tms.ticket_event WHERE id = pg_temp.last_ev('S4')),
  'appealed: with the Ombudsperson, 30 days to decide');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'REPLIED', 'SG1', 'Still ours?')$q$, 'the SGRC acting once the Ombudsperson has the appeal');
SELECT pg_temp.ev('S4', 'FORUM_DECIDED', 'OMB', 'The prospectus promised a full refund; refund the balance of 5,000', NULL, NULL, NULL, NULL, NULL, 'UPHELD');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'APPEALED', 'ST', 'Appeal again')$q$, 'appealing the Ombudsperson''s decision (no appeal forum configured)');
SELECT pg_temp.ev('S4', 'CONFIRMED', 'ST');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND closure_reason_id = pg_temp.lk('tms_closure_reason','FORUM_DECISION') FROM pg_temp.s('S4')),
  'accepted: closed as decided by a redressal forum');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'RATED', 'ST', NULL, NULL, NULL, 5::smallint)$q$, 'rating a forum decision');
SELECT pg_temp.ok((SELECT count(*) = 2 AND bool_and(register_status = 'DECIDED' AND decided_in_time)
                          AND bool_or(is_appeal AND outcome = 'UPHELD') AND bool_or(NOT is_appeal AND outcome = 'NOT_UPHELD')
                   FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('S4')),
  'the grievance register: the SGRC referral and the appeal, both decided in time');

-- referral rules
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S3', 'REFERRED', 'ST', 'Straight to the committee')$q$, 'the requester referring before 7 days have passed');
UPDATE tms.helpdesk_setting SET requester_refer_after_days = 0;
SELECT pg_temp.ev('S3', 'REFERRED', 'ST', 'Straight to the committee');
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND academic_body_id = pg_temp.u('SGRC-SET') FROM pg_temp.s('S3')),
  'with requester_refer_after_days = 0 the student refers at once');
UPDATE tms.helpdesk_setting SET requester_refer_after_days = 7;
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S3', 'REFERRED', 'ST', 'Twice')$q$, 'referring a second time');
SELECT pg_temp.tk('S16', 'C-ATTL', 'ST2', 'GRIEVANCE');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S16', 'REFERRED', 'ST2', 'Wrong forum', NULL, NULL, NULL, 'ANTI_RAGGING')$q$, 'the requester choosing another forum');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S16', 'REFERRED', 'DA', 'Discrimination', NULL, NULL, NULL, 'EQUAL_OPPORTUNITY')$q$,
  'referring to a forum with no committee constituted');

-- duplicates: merged into one ticket; its resolution reaches the followers
SELECT pg_temp.tk('S10', 'C-FEER', 'ST3', 'GRIEVANCE');
SELECT pg_temp.tk('S11', 'C-FEER', 'ST', 'GRIEVANCE');
SELECT pg_temp.ok((SELECT assignee_employee_id FROM pg_temp.s('S10')) = pg_temp.emp('FH2') AND (SELECT assignee_employee_id FROM pg_temp.s('S11')) = pg_temp.emp('FH3'),
  'the engineering desk takes turns');
SELECT pg_temp.ev('S11', 'MERGED', 'FH3', 'Same refund batch as S10', NULL, NULL, NULL, NULL, 'S10');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND merged_into_ticket_id = pg_temp.u('S10') AND closure_reason_id = pg_temp.lk('tms_closure_reason','DUPLICATE')
                   FROM pg_temp.s('S11'))
              AND tms.can_view(pg_temp.acct('ST'), pg_temp.u('S10')),
  'merged: the duplicate closes, its requester follows the surviving ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S11', 'REOPENED', 'ST', 'Not a duplicate')$q$, 'reopening a merged duplicate');
SELECT pg_temp.ev('S10', 'RESOLVED', 'FH2', 'Refund batch processed');
SELECT pg_temp.ok(pg_temp.notices('S10', 'RESOLVED', 'ST') = 2, 'the follower is told when the surviving ticket is resolved');

-- withdrawal
SELECT pg_temp.tk('S13', 'C-FEER', 'ST', 'GRIEVANCE');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S13', 'WITHDRAWN', 'FH3', 'Withdrawn for them')$q$, 'someone else withdrawing the ticket');
SELECT pg_temp.ev('S13', 'WITHDRAWN', 'ST', 'Paid by the bank after all');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND closure_reason_id = pg_temp.lk('tms_closure_reason','WITHDRAWN') FROM pg_temp.s('S13')), 'withdrawn by the student');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S13', 'REOPENED', 'ST', 'Changed my mind')$q$, 'reopening a withdrawn ticket');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S13', 'RATED', 'ST', NULL, NULL, NULL, 3::smallint)$q$, 'rating a withdrawn ticket');

-- ===================================== ragging: confidential, anonymous ==
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X40', 'C-RAGL', 'ST', 'GRIEVANCE')$q$, 'a ragging complaint without the date of the incident');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X41', 'C-RAGL', 'ST', 'GRIEVANCE', NULL, NULL, false, current_date + 3)$q$, 'an incident in the future');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X42', 'C-RAGL', 'ST', 'ENQUIRY', NULL, NULL, false, current_date - 3)$q$, 'a ragging complaint that is not a grievance');
SELECT pg_temp.tk('R1', 'C-RAGL', 'ST', 'GRIEVANCE', NULL, NULL, true, current_date - 3);
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND forum_id = pg_temp.fid('ANTI_RAGGING') AND academic_body_id = pg_temp.u('ARC') AND is_confidential
                          AND route_id IS NULL AND assignee_employee_id IS NULL FROM pg_temp.s('R1'))
              AND (SELECT due_at = occurred_at + interval '7 days' FROM tms.ticket_event WHERE id = pg_temp.last_ev('R1')),
  'R1: raised and filed with the anti-ragging committee at once, confidential, 7 days to decide');
INSERT INTO tms.ticket_respondent (ticket_id, person_id, added_by_account_id) VALUES (pg_temp.u('R1'), pg_temp.u('P-ST3'), pg_temp.acct('ST'));
SELECT pg_temp.ok(tms.can_view(pg_temp.acct('ST'), pg_temp.u('R1')) AND tms.can_view(pg_temp.acct('AR1'), pg_temp.u('R1')) AND tms.can_act(pg_temp.acct('AR2'), pg_temp.u('R1'))
              AND tms.can_view(pg_temp.acct('CV'), pg_temp.u('R1')) AND NOT tms.can_act(pg_temp.acct('CV'), pg_temp.u('R1')),
  'the complainant and the committee see it; an explicitly authorised viewer sees but cannot act');
SELECT pg_temp.ok(NOT tms.can_view(pg_temp.acct('TA'), pg_temp.u('R1')) AND NOT tms.can_act(pg_temp.acct('TA'), pg_temp.u('R1'))
              AND NOT tms.can_view(pg_temp.acct('DSW'), pg_temp.u('R1')) AND NOT tms.can_view(pg_temp.acct('GC'), pg_temp.u('R1'))
              AND NOT tms.can_view(pg_temp.acct('ST3'), pg_temp.u('R1')),
  'confidential: not the helpdesk admin, the DSW, the grievance cell — and never the student complained against');
SELECT pg_temp.ok(NOT tms.requester_shown_to(pg_temp.acct('AR1'), pg_temp.u('R1')) AND tms.requester_shown_to(pg_temp.acct('CV'), pg_temp.u('R1')),
  'the committee does not see who complained anonymously; the authorised viewer does');
SELECT pg_temp.ev('R1', 'CLARIFICATION_REQUESTED', 'AR1', 'Which hostel block, and were there witnesses?');
SELECT pg_temp.ev('R1', 'CLARIFICATION_PROVIDED', 'ST', 'Block C, two witnesses');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R1', 'MERGED', 'AR1', 'Duplicate', NULL, NULL, NULL, NULL, 'S10')$q$, 'merging a confidential ticket');
SELECT pg_temp.ev('R1', 'FORUM_DECIDED', 'AR1', 'Ragging proven; recommended for disciplinary action', NULL, NULL, NULL, NULL, NULL, 'UPHELD', 'RES3');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R1', 'APPEALED', 'ST', 'More action wanted')$q$, 'appealing where the forum has no appeal forum');
SELECT pg_temp.ev('R1', 'CONFIRMED', 'ST');
SELECT pg_temp.ok((SELECT status = 'CLOSED' FROM pg_temp.s('R1'))
              AND NOT EXISTS (SELECT 1 FROM tms.ticket_notification n JOIN tms.ticket_event e ON e.id = n.ticket_event_id
                              WHERE e.ticket_id = pg_temp.u('R1') AND n.recipient_account_id = pg_temp.acct('ST3')),
  'decided and closed; the respondent was never notified of anything');
SELECT pg_temp.ok((SELECT is_confidential AND register_status = 'DECIDED' AND grievance_head = 'RAGGING' FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('R1')),
  'the register counts the ragging case (flagged confidential, no text)');

-- unrouted: a category whose route has nobody
SELECT pg_temp.tk('L1', 'C-LIB', 'ST', 'ENQUIRY');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.v_ticket_unrouted WHERE ticket_id = pg_temp.u('L1'))
              AND NOT EXISTS (SELECT 1 FROM tms.v_ticket_unrouted WHERE ticket_id = pg_temp.u('S1')),
  'a ticket nobody on its route can take shows in the administrators'' queue');
SELECT pg_temp.ev('L1', 'REPLIED', 'TA', 'The library desk will contact you');

-- ============================================================ scheduler ==
SELECT pg_temp.rejects($q$SELECT * FROM tms.run_scheduler()$q$, 'running the scheduler outside a system job');
SELECT pg_temp.tk('E1', 'C-SND', 'ST', 'ENQUIRY');
SELECT pg_temp.ok((SELECT assignee_employee_id = pg_temp.emp('EX') AND level_id = pg_temp.lv('STUDENT_EXAMINATION', 4) FROM pg_temp.s('E1')),
  'E1 (no exam handlers or owners yet): the head of the Examinations office (Controller)');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run1 AS SELECT * FROM tms.run_scheduler((SELECT due_at FROM pg_temp.s('E1')) + interval '1 minute', true);
SELECT pg_temp.ok((SELECT escalated >= 1 FROM run1) AND (SELECT status = 'ESCALATED' AND assignee_employee_id = pg_temp.emp('VC') AND clock_state = 'RUNNING' FROM pg_temp.s('E1')),
  'scheduler run 1: the overdue exam ticket goes to the Vice Chancellor');
CREATE TEMP TABLE run2 AS SELECT * FROM tms.run_scheduler((SELECT due_at FROM pg_temp.s('E1')) + interval '1 minute', true);
SELECT pg_temp.ok((SELECT exhausted >= 1 FROM run2) AND (SELECT clock_state = 'STOPPED' AND due_at IS NULL AND assignee_employee_id = pg_temp.emp('VC') AND NOT is_closed FROM pg_temp.s('E1')),
  'scheduler run 2: nobody above — the clock stops, the ticket stays open with the VC (old bug: re-processed every hour)');
CREATE TEMP TABLE run3 AS SELECT * FROM tms.run_scheduler(now() + interval '1 day', true);
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code IN ('AUTO_ESCALATED','ESCALATION_EXHAUSTED')
                              WHERE e.ticket_id = pg_temp.u('E1') AND e.id > (SELECT max(x.id) FROM tms.ticket_event x WHERE x.ticket_id = pg_temp.u('E1')
                                                                                AND x.event_type_id = pg_temp.lk('tms_event_type','ESCALATION_EXHAUSTED'))),
  'the exhausted ticket is left alone by later runs');
CREATE TEMP TABLE run4 AS SELECT * FROM tms.run_scheduler('2026-10-03 11:00+05:30', false);
SELECT pg_temp.ok((SELECT auto_referred + escalated + exhausted + overdue_notices + reminders + expired + auto_closed = 0 FROM run4),
  'outside office hours (Saturday) the scheduler does nothing unless forced');

-- policy runs: no escalation, no referral, so only the step under test moves
SET LOCAL app.system_job = 'off';
UPDATE tms.helpdesk_setting SET auto_escalation_enabled = false, auto_refer_after_days = NULL;
SELECT pg_temp.tk('T11', 'C-VPN', 'RF');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run5 AS SELECT * FROM tms.run_scheduler((SELECT due_at FROM pg_temp.s('T11')) + interval '1 minute', true);
CREATE TEMP TABLE run6 AS SELECT * FROM tms.run_scheduler((SELECT due_at FROM pg_temp.s('T11')) + interval '1 minute', true);
SELECT pg_temp.ok((SELECT escalated = 0 AND overdue_notices >= 1 FROM run5) AND (SELECT status = 'OPEN' FROM pg_temp.s('T11'))
              AND pg_temp.notices('T11', 'OVERDUE_NOTICE', 'H3', 'EMAIL') = 1,
  'auto-escalation off: one overdue notice per overdue spell, e-mailed to the assignee (H3)');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ev('S2', 'CLARIFICATION_REQUESTED', 'DA', 'Which subjects are short of attendance?');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run7 AS SELECT * FROM tms.run_scheduler(now() + interval '3 days 1 hour', true);
CREATE TEMP TABLE run8 AS SELECT * FROM tms.run_scheduler(now() + interval '3 days 1 hour', true);
SELECT pg_temp.ok((SELECT count(*) = 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'CLARIFICATION_REMINDER'
                   WHERE e.ticket_id = pg_temp.u('S2'))
              AND pg_temp.notices('S2', 'CLARIFICATION_REMINDER', 'ST2', 'EMAIL') = 1,
  'after 2 days the student is reminded of the clarification — once');
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND closure_reason_id = pg_temp.lk('tms_closure_reason','RESOLVED') FROM pg_temp.s('S10'))
              AND EXISTS (SELECT 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'AUTO_CLOSED' WHERE e.ticket_id = pg_temp.u('S10')),
  'a resolution not contested within 3 days is closed automatically');
CREATE TEMP TABLE run9 AS SELECT * FROM tms.run_scheduler(now() + interval '8 days', true);
SELECT pg_temp.ok((SELECT status = 'CLOSED' AND closure_reason_id = pg_temp.lk('tms_closure_reason','NO_RESPONSE') FROM pg_temp.s('S2')),
  'no reply within 7 days: closed for no response');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ev('S2', 'REOPENED', 'ST2', 'Sorry, I was travelling');
SELECT pg_temp.ok((SELECT status = 'OPEN' AND assignee_employee_id = pg_temp.emp('DA') AND clock_state = 'RUNNING' FROM pg_temp.s('S2')),
  'a ticket closed for no response can be reopened; it goes back to Dean Academics');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run10 AS SELECT * FROM tms.run_scheduler(now() + interval '16 days', true);
SELECT pg_temp.ok((SELECT referral_count = 0 FROM pg_temp.s('S16')) AND (SELECT auto_referred = 0 FROM run10),
  'auto_refer_after_days off: an unsettled grievance stays at the helpdesk');
SELECT pg_temp.ok(pg_temp.notices('S3', 'OVERDUE_NOTICE', 'SG1', 'EMAIL') = 1,
  'a forum past its time limit is not escalated: its members are e-mailed an overdue notice');
SET LOCAL app.system_job = 'off';
UPDATE tms.helpdesk_setting SET auto_refer_after_days = 15;
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run11 AS SELECT * FROM tms.run_scheduler(now() + interval '16 days', true);
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND academic_body_id = pg_temp.u('SGRC-U') FROM pg_temp.s('S16'))
              AND (SELECT is_automatic FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('S16')),
  'with auto_refer_after_days = 15 the management student''s grievance goes to the university SGRC (no school SGRC)');
SET LOCAL app.system_job = 'off';
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id) VALUES (md5('T11')::uuid, ref.id_of('tms_event_type','OVERDUE_NOTICE'))$q$,
  'an overdue notice recorded by a person');
UPDATE tms.helpdesk_setting SET auto_escalation_enabled = true;

-- ========================================= parity with the old UMS & more ==
-- request numbers restart every year; the counter knows the last one
SELECT pg_temp.ok((SELECT request_no FROM tms.ticket WHERE id = pg_temp.u('T1')) = format('TMS-%s-00001', extract(year FROM now() AT TIME ZONE 'Asia/Kolkata'))
              AND (SELECT last_no FROM tms.ticket_number_counter WHERE year = extract(year FROM now() AT TIME ZONE 'Asia/Kolkata')) = (SELECT count(*) FROM tms.ticket),
  'request numbers TMS-YYYY-NNNNN count from 00001 within the year (old: MAX+1 under an advisory lock)');

-- the old 10-second double-submission guard, and the subject derived from the description
INSERT INTO tms.ticket (id, requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
VALUES (pg_temp.u('D1'), pg_temp.acct('RF'), pg_temp.u('C-VPN'), pg_temp.lk('tms_message_type','SERVICE_REQUEST'), NULL,
        'VPN client   keeps disconnecting every ten minutes from the hostel network', pg_temp.u('PH-RF'));
SELECT pg_temp.ok((SELECT subject = 'VPN client keeps disconnecting every ten minutes from the hostel network' FROM tms.ticket WHERE id = pg_temp.u('D1')),
  'no subject given: it is taken from the description (old employee form)');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket (requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
  VALUES (md5('A-RF')::uuid, md5('C-VPN')::uuid, ref.id_of('tms_message_type','SERVICE_REQUEST'), 'Again',
          'VPN client   keeps disconnecting every ten minutes from the hostel network', md5('PH-RF')::uuid)$q$,
  'the same requester, leaf and text again within 10 seconds (a double submission)');
UPDATE tms.helpdesk_setting SET duplicate_window_seconds = 0;
INSERT INTO tms.ticket (id, requester_account_id, raised_category_id, message_type_id, subject, description, contact_phone_id)
VALUES (pg_temp.u('D2'), pg_temp.acct('RF'), pg_temp.u('C-VPN'), pg_temp.lk('tms_message_type','SERVICE_REQUEST'), 'Again',
        'VPN client   keeps disconnecting every ten minutes from the hostel network', pg_temp.u('PH-RF'));
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.ticket WHERE id = pg_temp.u('D2')), 'with duplicate_window_seconds = 0 the second one is taken');
UPDATE tms.helpdesk_setting SET duplicate_window_seconds = 10;

-- internal-only categories: reached by transfer, never raised under
SELECT pg_temp.cat('C-INT', 'C-FEE', 'SUB_CATEGORY', 'Fee audit (internal)', NULL, NULL, NULL, 'MEDIUM');
UPDATE tms.ticket_category SET allows_raising = false WHERE id = pg_temp.u('C-INT');
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X50', 'C-INT', 'ST2', 'GRIEVANCE')$q$, 'raising under an internal-only category');
SELECT pg_temp.tk('S20', 'C-FEER', 'ST2', 'ENQUIRY');
SELECT pg_temp.ev('S20', 'TRANSFERRED', 'FH1', 'Needs the fee audit', NULL, 'C-INT');
SELECT pg_temp.ok((SELECT category_id = pg_temp.u('C-INT') AND assignee_employee_id = pg_temp.emp('FINH') FROM pg_temp.s('S20')),
  'a handler transfers into it; with no handlers or owners the head of the responsible office (Finance) takes it');

-- attachments: type, size, one ticket per file, who may download
INSERT INTO people.file_object (id, storage_backend_id, object_key, mime_type, byte_size, sha256) VALUES
 (pg_temp.u('F4'), pg_temp.lk('storage_backend','S3'), 'tms/test/F4', 'application/zip', 1000, decode(md5('F4') || md5('F4'), 'hex')),
 (pg_temp.u('F5'), pg_temp.lk('storage_backend','S3'), 'tms/test/F5', 'application/pdf', 10485760, decode(md5('F5') || md5('F5'), 'hex')),
 (pg_temp.u('F6'), pg_temp.lk('storage_backend','S3'), 'tms/test/F6', 'image/png', 2000, decode(md5('F6') || md5('F6'), 'hex'));
SELECT pg_temp.ev('S20', 'REMARKED', 'FINH', 'Internal: audit sheet attached');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES ((SELECT max(id) FROM tms.ticket_event WHERE ticket_id = md5('S20')::uuid), md5('F4')::uuid)$q$,
  'a file type that is not accepted (zip)');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES ((SELECT max(id) FROM tms.ticket_event WHERE ticket_id = md5('S20')::uuid), md5('F5')::uuid)$q$,
  'a file larger than 5 MB');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES ((SELECT max(id) FROM tms.ticket_event WHERE ticket_id = md5('S20')::uuid), md5('F1')::uuid)$q$,
  'attaching a file that belongs to another ticket');
INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id) VALUES (pg_temp.last_ev('S20'), pg_temp.u('F6'));
SELECT pg_temp.ok(tms.can_download(pg_temp.acct('ST'), pg_temp.u('F1')) AND NOT tms.can_download(pg_temp.acct('ST3'), pg_temp.u('F1'))
              AND tms.can_download(pg_temp.acct('FINH'), pg_temp.u('F6')) AND NOT tms.can_download(pg_temp.acct('ST2'), pg_temp.u('F6')),
  'downloads: the student gets the file of a reply, not another student; staff get an internal note''s file, the requester does not');

-- assignee search (the old /employees/search) and the actions a screen offers (the old canReopen)
SELECT pg_temp.ok((SELECT count(*) = 5 AND bool_and(employee_id <> pg_temp.emp('RS'))
                   FROM tms.eligible_assignees(pg_temp.u('C-PWD'), pg_temp.acct('RS')))
              AND (SELECT level_id = pg_temp.lv('T_EMP_NONACAD', 1) FROM tms.eligible_assignees(pg_temp.u('C-PWD'), pg_temp.acct('RS')) WHERE employee_id = pg_temp.emp('H1')),
  'eligible assignees for RS in Password reset: handlers H1, H2 and the owners CO, MO, KH — never RS himself');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('ST'), pg_temp.u('S1')) WHERE event_code = 'REQUESTER_COMMENTED')
              AND EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('ST'), pg_temp.u('S1')) WHERE event_code = 'WITHDRAWN')
              AND NOT EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('ST'), pg_temp.u('S1')) WHERE event_code IN ('RESOLVED', 'ESCALATED', 'REPLIED'))
              AND EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('VC'), pg_temp.u('S1')) WHERE event_code = 'RESOLVED')
              AND NOT EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('VC'), pg_temp.u('S1')) WHERE event_code = 'ESCALATED'),
  'available actions: the student may comment or withdraw (not resolve, not escalate in time); the VC may resolve but not escalate past the top');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('RF'), pg_temp.u('T2')) WHERE event_code = 'REOPENED')
              AND NOT EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('MEN'), pg_temp.u('S15'))),
  'no reopen offered past the reopen limit; nothing at all for a respondent');

-- carrying out a forum's decision (Ombudsperson upheld S4; compliance tracked)
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('FH2'), pg_temp.u('S4')) WHERE event_code = 'ACTION_TAKEN')
              AND (SELECT compliance_due_at IS NOT NULL AND complied_at IS NULL FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('S4') AND is_appeal),
  'the upheld appeal has a compliance date; the fee desk that handled it may report the action taken');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'ACTION_TAKEN', 'OUT', 'Not my office')$q$, 'an outsider reporting the action taken');
SELECT pg_temp.ev('S4', 'ACTION_TAKEN', 'FH2', 'Balance of 5,000 refunded on the order of the Ombudsperson');
SELECT pg_temp.ok((SELECT complied_at IS NOT NULL AND NOT compliance_overdue FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('S4') AND is_appeal)
              AND pg_temp.notices('S4', 'ACTION_TAKEN', 'ST', 'EMAIL') = 1,
  'complied: the register shows when, and the student is told');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S4', 'ACTION_TAKEN', 'FH2', 'Twice')$q$, 'reporting the action taken twice');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S2', 'ACTION_TAKEN', 'DA', 'Nothing was decided')$q$, 'an action report without a forum decision');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'COMPLIANCE_REMINDER'
                          WHERE e.ticket_id = pg_temp.u('R1'))
              AND pg_temp.notices('R1', 'COMPLIANCE_REMINDER', 'AR1', 'EMAIL') = 1,
  'the ragging decision not carried out within 15 days: the scheduler reminded the committee');
SELECT pg_temp.ev('R1', 'ACTION_TAKEN', 'AR1', 'Disciplinary case opened; hostel allotment changed');
SELECT pg_temp.ok((SELECT complied_at IS NOT NULL FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('R1')), 'the committee reports the action on the ragging case');

-- consulting another office without handing the ticket over
INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, consulted_employee_id)
VALUES (pg_temp.u('S20'), pg_temp.lk('tms_event_type','CONSULTATION_REQUESTED'), pg_temp.acct('FINH'), 'Was the refund batch of September paid out?', pg_temp.emp('FH2'));
SELECT pg_temp.ok(tms.can_view(pg_temp.acct('FH2'), pg_temp.u('S20')) AND NOT tms.can_act(pg_temp.acct('FH2'), pg_temp.u('S20'))
              AND pg_temp.notices('S20', 'CONSULTATION_REQUESTED', 'FH2', 'EMAIL') = 1
              AND (SELECT is_open FROM tms.v_ticket_consultation WHERE ticket_id = pg_temp.u('S20')),
  'the consulted officer is told, may see the ticket, but does not take it over');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, consulted_employee_id)
  VALUES (md5('S20')::uuid, ref.id_of('tms_event_type','CONSULTATION_REQUESTED'), md5('A-FINH')::uuid, 'Ask the student', md5('E-FINH')::uuid)$q$,
  'consulting yourself');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, reply_to_event_id)
  VALUES (md5('S20')::uuid, ref.id_of('tms_event_type','CONSULTATION_ANSWERED'), md5('A-OUT')::uuid, 'Not asked',
          (SELECT max(id) FROM tms.ticket_event WHERE ticket_id = md5('S20')::uuid))$q$,
  'someone who was not asked answering');
INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, reply_to_event_id)
VALUES (pg_temp.u('S20'), pg_temp.lk('tms_event_type','CONSULTATION_ANSWERED'), pg_temp.acct('FH2'), 'Yes, paid on 28 September',
        (SELECT q.request_event_id FROM tms.v_ticket_consultation q WHERE q.ticket_id = pg_temp.u('S20')));
SELECT pg_temp.ok(NOT (SELECT is_open FROM tms.v_ticket_consultation WHERE ticket_id = pg_temp.u('S20'))
              AND pg_temp.notices('S20', 'CONSULTATION_ANSWERED', 'FINH', 'EMAIL') = 1
              AND NOT EXISTS (SELECT 1 FROM tms.v_ticket_requester_timeline WHERE ticket_id = pg_temp.u('S20') AND event_type LIKE 'CONSULTATION%'),
  'answered: whoever asked is told; the student''s timeline shows nothing of it');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, reply_to_event_id)
  VALUES (md5('S20')::uuid, ref.id_of('tms_event_type','CONSULTATION_ANSWERED'), md5('A-FH2')::uuid, 'Again',
          (SELECT q.request_event_id FROM tms.v_ticket_consultation q WHERE q.ticket_id = md5('S20')::uuid))$q$,
  'answering a consultation twice');

-- notices: opt-out (mandatory notices still go); S20 closes here, before the scheduler
-- jumps 11 days ahead below (its 48-hour SLA would otherwise escalate it on some weekdays)
INSERT INTO tms.notice_opt_out (account_id, contact_channel_id) VALUES (pg_temp.acct('ST2'), pg_temp.lk('contact_channel','EMAIL'));
SELECT pg_temp.ev('S20', 'REPLIED', 'FINH', 'The refund was paid on 28 September');
SELECT pg_temp.ok(pg_temp.notices('S20', 'REPLIED', 'ST2', 'EMAIL') = 0 AND pg_temp.notices('S20', 'REPLIED', 'ST2', 'IN_APP') = 1,
  'opted out of e-mail: the reply arrives in-app only');
SELECT pg_temp.ev('S20', 'REJECTED', 'FINH', 'The refund was already paid — nothing is due');
SELECT pg_temp.ok(pg_temp.notices('S20', 'REJECTED', 'ST2', 'EMAIL') = 1, 'a mandatory notice (closing as not maintainable) is e-mailed despite the opt-out');
SELECT pg_temp.ev('S20', 'CONFIRMED', 'ST2');

-- on hold (the old system's unused vendor / department pause reasons)
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T11', 'PUT_ON_HOLD', 'H3', 'Waiting for the network vendor')$q$, 'a hold without saying what is awaited');
INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, hold_reason_id)
VALUES (pg_temp.u('T11'), pg_temp.lk('tms_event_type','PUT_ON_HOLD'), pg_temp.acct('H3'), 'Waiting for the network vendor', pg_temp.lk('tms_hold_reason','VENDOR'));
SELECT pg_temp.ok((SELECT clock_state = 'PAUSED' AND clock_event = 'PUT_ON_HOLD' FROM pg_temp.s('T11'))
              AND (SELECT attention = 'PAUSED' FROM tms.v_ticket_sla WHERE ticket_id = pg_temp.u('T11')),
  'on hold: the clock pauses; attention tier PAUSED');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T11', 'CLARIFICATION_REQUESTED', 'H3', 'And a question')$q$, 'a clarification while the clock is already paused');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('T11', 'CLARIFICATION_PROVIDED', 'RF', 'Answer')$q$, 'answering a clarification that was never asked (the pause is a hold)');
SELECT pg_temp.ev('T11', 'HOLD_RELEASED', 'H3', 'The vendor replaced the router');
SELECT pg_temp.ok((SELECT clock_state = 'RUNNING' FROM pg_temp.s('T11')), 'released: the clock runs again with the time that was left');
INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, hold_reason_id)
VALUES (pg_temp.u('T11'), pg_temp.lk('tms_event_type','PUT_ON_HOLD'), pg_temp.acct('H3'), 'Waiting again', pg_temp.lk('tms_hold_reason','OTHER_OFFICE'));
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run12 AS SELECT * FROM tms.run_scheduler(now() + interval '11 days', true);
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok((SELECT holds_released >= 1 FROM run12) AND (SELECT clock_state = 'RUNNING' AND clock_event = 'HOLD_EXPIRED' FROM pg_temp.s('T11')),
  'a hold longer than max_hold_days (10) is released by the scheduler');
UPDATE tms.helpdesk_setting SET on_hold_enabled = false;
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event (ticket_id, event_type_id, actor_account_id, remarks, hold_reason_id)
  VALUES (md5('T11')::uuid, ref.id_of('tms_event_type','PUT_ON_HOLD'), md5('A-H3')::uuid, 'Hold', ref.id_of('tms_hold_reason','VENDOR'))$q$,
  'a hold with on_hold_enabled off');
UPDATE tms.helpdesk_setting SET on_hold_enabled = true;

-- notices: channel kill switch, giving up
UPDATE tms.helpdesk_channel SET is_enabled = false WHERE contact_channel_id = pg_temp.lk('contact_channel','EMAIL');
SELECT pg_temp.tk('N1', 'C-VPN', 'RF');
SELECT pg_temp.ok(pg_temp.notices('N1', 'CREATED', 'RF', 'EMAIL') = 0 AND pg_temp.notices('N1', 'CREATED', 'RF', 'IN_APP') = 1,
  'with the e-mail channel switched off no e-mail is queued at all');
UPDATE tms.helpdesk_channel SET is_enabled = true WHERE contact_channel_id = pg_temp.lk('contact_channel','EMAIL');
UPDATE tms.ticket_notification SET notification_status_id = pg_temp.lk('tms_notification_status','FAILED'), attempt_count = 1
WHERE id = (SELECT max(id) FROM tms.ticket_notification);
UPDATE tms.ticket_notification SET attempt_count = 3 WHERE id = (SELECT max(id) FROM tms.ticket_notification);
SELECT pg_temp.ok((SELECT notification_status_id = pg_temp.lk('tms_notification_status','GAVE_UP') AND last_attempt_at IS NOT NULL
                   FROM tms.ticket_notification WHERE id = (SELECT max(id) FROM tms.ticket_notification)),
  'a notice that failed 3 times (notice_max_attempts) is given up — no endless retries');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_notification SET attempt_count = 4 WHERE id = (SELECT max(id) FROM tms.ticket_notification)$q$, 'retrying a notice given up');

-- SLA attention tiers (old normal / warning / critical / paused)
SELECT pg_temp.ok((SELECT attention = 'NORMAL' AND sla_percent_left > 25 FROM tms.v_ticket_sla WHERE ticket_id = pg_temp.u('N1'))
              AND (SELECT attention IS NULL FROM tms.v_ticket_sla WHERE ticket_id = pg_temp.u('S20'))
              AND (SELECT paused_office_minutes >= 0 FROM tms.v_ticket_sla WHERE ticket_id = pg_temp.u('T1')),
  'attention: a fresh ticket is NORMAL, a closed one has none; paused office time is accounted for');

-- knowledge base: articles before raising, anonymous helpfulness
INSERT INTO tms.kb_article (id, ticket_domain_id, category_id, title, body, published) VALUES
 (pg_temp.u('KB1'), pg_temp.lk('tms_ticket_domain','STUDENT'), pg_temp.u('C-FEE'), 'How fee refunds work', 'Refunds are paid within 30 days of approval to the bank account on record.', daterange(current_date, NULL)),
 (pg_temp.u('KB2'), pg_temp.lk('tms_ticket_domain','STUDENT'), NULL, 'Before you raise a ticket', 'Check the notices and the student handbook first.', daterange(current_date, NULL)),
 (pg_temp.u('KB3'), pg_temp.lk('tms_ticket_domain','STUDENT'), pg_temp.u('C-FEE'), 'Draft', 'Not yet published text of an article.', NULL);
SELECT pg_temp.ok((SELECT count(*) = 2 FROM tms.kb_articles_for(pg_temp.u('C-FEER')))
              AND (SELECT count(*) = 1 FROM tms.kb_articles_for(pg_temp.u('C-ATTL'))),
  'fee refunds show the fee article and the general one; attendance only the general one; drafts never');
SELECT pg_temp.rejects($q$INSERT INTO tms.kb_article (ticket_domain_id, category_id, title, body) VALUES
  (ref.id_of('tms_ticket_domain','EMPLOYEE'), md5('C-FEE')::uuid, 'Wrong domain', 'An employee article on a student category.')$q$,
  'an article on a category of the other domain');
INSERT INTO tms.kb_feedback (kb_article_id, was_helpful) VALUES (pg_temp.u('KB1'), true), (pg_temp.u('KB1'), true), (pg_temp.u('KB1'), false);
SELECT pg_temp.ok((SELECT answers = 3 AND helpful = 2 AND deflection_percent = 66.7 FROM tms.v_kb_article_stats WHERE kb_article_id = pg_temp.u('KB1')),
  'two of three readers needed no ticket after the fee article (deflection 66.7 %)');
SELECT pg_temp.rejects($q$INSERT INTO tms.kb_feedback (kb_article_id, was_helpful) VALUES (md5('KB3')::uuid, true)$q$, 'feedback on a draft');
SELECT pg_temp.rejects($q$UPDATE tms.kb_feedback SET was_helpful = false$q$, 'changing feedback');

-- switches: Employee TMS, and the deployment lock on Student TMS
UPDATE tms.helpdesk_setting SET employee_tms_enabled = false;
SELECT pg_temp.rejects($q$SELECT pg_temp.tk('X51', 'C-VPN', 'RF')$q$, 'an employee ticket while Employee TMS is switched off (old flag never enforced)');
SELECT pg_temp.ok(NOT tms.can_view(pg_temp.acct('RS'), pg_temp.u('T1')), 'with Employee TMS off, employee tickets are hidden');
UPDATE tms.helpdesk_setting SET employee_tms_enabled = true;
SELECT pg_temp.rejects($q$UPDATE tms.helpdesk_setting SET student_tms_locked = true$q$, 'locking Student TMS while it is on');
SELECT pg_temp.ok(NOT has_column_privilege('intranet_app', 'tms.helpdesk_setting', 'student_tms_locked', 'UPDATE')
              AND has_column_privilege('intranet_app', 'tms.helpdesk_setting', 'student_tms_enabled', 'UPDATE'),
  'the application may switch Student TMS, but not lift the deployment lock');

-- context: the programme must be active (old ERP rule)
UPDATE academic.program SET is_active = false WHERE id = pg_temp.u('BTECH');
SELECT pg_temp.tk('S9', 'C-CREG', 'ST3', 'ENQUIRY');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
  VALUES (md5('S9')::uuid, md5('B26')::uuid, md5('ODD26')::uuid, md5('CS301')::uuid, 3)$q$, 'academic context of a programme that is not active');
UPDATE academic.program SET is_active = true WHERE id = pg_temp.u('BTECH');
INSERT INTO tms.ticket_academic_context (ticket_id, batch_id, academic_term_id, course_id, term_no)
VALUES (pg_temp.u('S9'), pg_temp.u('B26'), pg_temp.u('ODD26'), pg_temp.u('CS301'), 3);

-- governance roles and lists
INSERT INTO authz.account_role (account_id, role_id, reason)
SELECT pg_temp.acct('AH'), id, 'TMS test: employee governance' FROM authz.role WHERE code = 'TMS_EMPLOYEE_OVERSEER';
SELECT pg_temp.ok(tms.can_view(pg_temp.acct('AH'), pg_temp.u('T5')) AND NOT tms.can_act(pg_temp.acct('AH'), pg_temp.u('T5'))
              AND authz.has_permission(pg_temp.acct('DSW'), 'tms.analytics.view', NULL),
  'the employee overseer (old IT Department Head) sees every employee ticket, view only; the DSW now has the statistics');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.v_ticket_participant WHERE ticket_id = pg_temp.u('S3') AND account_id = pg_temp.acct('DESK') AND participation = 'RAISED_BY')
              AND EXISTS (SELECT 1 FROM tms.v_ticket_participant WHERE ticket_id = pg_temp.u('S20') AND account_id = pg_temp.acct('FH2') AND participation = 'CONSULTED')
              AND EXISTS (SELECT 1 FROM tms.v_ticket_participant WHERE ticket_id = pg_temp.u('S10') AND account_id = pg_temp.acct('ST') AND participation = 'FOLLOWER'),
  'the participation view behind the my / assigned / history lists');
SELECT pg_temp.ok((SELECT tickets = 8 FROM tms.v_ticket_category_rollup WHERE node_id = pg_temp.u('C-SADM'))
              AND (SELECT tickets FROM tms.v_ticket_category_rollup WHERE node_id = pg_temp.u('C-SADM'))
                  = (SELECT sum(tickets) FROM tms.v_ticket_category_rollup r JOIN tms.ticket_category c ON c.id = r.node_id WHERE c.parent_id = pg_temp.u('C-SADM'))
              AND (SELECT ever_assigned >= 3 FROM tms.v_ticket_handler_stats WHERE employee_id = pg_temp.emp('H1')),
  'per-master statistics roll up from the categories below; handlers'' tickets ever assigned are counted');

-- category-wise SLA: a category defines its own hours (inherited below it),
-- a route level's own hours win over it, the priority applies where nothing is set
UPDATE tms.ticket_category SET sla_hours = 6 WHERE id = pg_temp.u('C-ACC');
UPDATE tms.ticket_category SET sla_hours = 4, first_response_hours = 1 WHERE id = pg_temp.u('C-VPN');
SELECT pg_temp.ok((SELECT sla_hours = 6 FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-PWD'))
              AND (SELECT sla_hours = 4 AND first_response_hours = 1 FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-VPN')),
  'category SLA is inherited down the tree (Password reset takes Access''s 6 h) unless a node sets its own (VPN 4 h)');
SELECT pg_temp.tk('N2', 'C-VPN', 'RF');
SELECT pg_temp.ok((SELECT s.due_at = tms.business_deadline(t.created_at, 4 * 60) FROM pg_temp.s('N2') s JOIN tms.ticket t ON t.id = s.ticket_id)
              AND (SELECT sla.first_response_due_at = tms.business_deadline(t.created_at, 60)
                   FROM tms.v_ticket_sla sla JOIN tms.ticket t ON t.id = sla.ticket_id WHERE sla.ticket_id = pg_temp.u('N2')),
  'a VPN ticket (priority LOW = 72 h) gets the category''s 4 office hours to resolve and 1 hour to first response');
UPDATE tms.ticket_category SET sla_hours = 2, sla_office_hours_only = false WHERE id = pg_temp.u('C-NOH');
SELECT pg_temp.tk('N3', 'C-NOH', 'RF');
SELECT pg_temp.ok((SELECT s.due_at = t.created_at + interval '2 hours' AND s.clock_is_office = false
                   FROM pg_temp.s('N3') s JOIN tms.ticket t ON t.id = s.ticket_id),
  'a category set to run round the clock: 2 wall-clock hours, nights and weekends counted');
UPDATE tms.ticket_route_level SET sla_hours = 3 WHERE id = pg_temp.lv('T_EMP_NONACAD', 2);
SELECT pg_temp.tk('N4', 'C-NOH', 'RS');
SELECT pg_temp.ok((SELECT s.due_at = t.created_at + interval '3 hours' FROM pg_temp.s('N4') s JOIN tms.ticket t ON t.id = s.ticket_id),
  'a route level''s own hours (3 h at the KPI owner) win over the category''s');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_category SET first_response_hours = 8 WHERE id = md5('C-VPN')::uuid$q$,
  'a category first-response target longer than its resolution time');
UPDATE tms.ticket_route_level SET sla_hours = NULL WHERE id = pg_temp.lv('T_EMP_NONACAD', 2);
UPDATE tms.ticket_category SET sla_hours = NULL, first_response_hours = NULL, sla_office_hours_only = NULL
WHERE id IN (pg_temp.u('C-ACC'), pg_temp.u('C-VPN'), pg_temp.u('C-NOH'));
SELECT pg_temp.ok((SELECT sla_hours IS NULL FROM tms.v_ticket_category WHERE category_id = pg_temp.u('C-PWD')),
  'cleared: the priority''s SLA applies again');

-- multiple committees (UGC): the anti-ragging squad inquires first and
-- forwards its report to the anti-ragging committee; urgent cases need the
-- committee's first action within hours, or the head of the institution is alerted
INSERT INTO academic.academic_body (id, academic_body_type_id, org_unit_id, name, quorum)
VALUES (pg_temp.u('SQUAD'), pg_temp.lk('academic_body_type','ANTI_RAGGING_SQUAD'), pg_temp.u('T-SGTU'), 'Anti-Ragging Squad', 1);
INSERT INTO academic.academic_body_member (academic_body_id, committee_role_id, employee_id, valid)
VALUES (pg_temp.u('SQUAD'), pg_temp.lk('committee_role','CHAIR'), pg_temp.emp('SQ1'), daterange('2026-01-01', NULL));
SELECT pg_temp.cat('C-RAGS', 'C-RAGC', 'SUB_CATEGORY', 'Ragging (squad inquiry first)', NULL, NULL, NULL, 'URGENT');
UPDATE tms.ticket_category SET redressal_forum_id = pg_temp.fid('ANTI_RAGGING_SQUAD'), sla_office_hours_only = false WHERE id = pg_temp.u('C-RAGS');
SELECT pg_temp.tk('R2', 'C-RAGS', 'ST2', 'GRIEVANCE', NULL, NULL, true, current_date - 1);
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND forum_id = pg_temp.fid('ANTI_RAGGING_SQUAD') AND academic_body_id = pg_temp.u('SQUAD') AND is_confidential
                   FROM pg_temp.s('R2'))
              AND (SELECT due_at = occurred_at + interval '1 day' FROM tms.ticket_event WHERE id = pg_temp.last_ev('R2')),
  'R2: the ragging complaint goes to the anti-ragging squad first (1 day to report), confidential');
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run15 AS SELECT * FROM tms.run_scheduler(now() + interval '3 hours', true);
CREATE TEMP TABLE run16 AS SELECT * FROM tms.run_scheduler(now() + interval '4 hours', true);
SET LOCAL app.system_job = 'off';
SELECT pg_temp.ok((SELECT forum_action_alerts >= 1 FROM run15)
              AND (SELECT count(*) = 1 FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'FORUM_ACTION_OVERDUE'
                   WHERE e.ticket_id = pg_temp.u('R2')),
  'the squad did not act within 2 hours (round the clock, URGENT): one alert, not repeated');
SELECT pg_temp.ok(pg_temp.notices('R2', 'FORUM_ACTION_OVERDUE', 'SQ1', 'EMAIL') = 1 AND pg_temp.notices('R2', 'FORUM_ACTION_OVERDUE', 'VC', 'SMS') = 1
              AND pg_temp.notices('R2', 'FORUM_ACTION_OVERDUE', 'ST3') = 0,
  'the squad is e-mailed and the head of the institution (VC) alerted by SMS too');
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM tms.available_actions(pg_temp.acct('SQ1'), pg_temp.u('R2')) WHERE event_code = 'FORUM_FORWARDED'),
  'the squad may forward its report');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'OUT', 'Not a member')$q$, 'forwarding by someone outside the committee');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'SQ1')$q$, 'forwarding without the report');
SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'SQ1', 'Inquiry report: two first-year students, Block C, 30 September; witnesses heard');
SELECT pg_temp.ok((SELECT status = 'WITH_FORUM' AND forum_id = pg_temp.fid('ANTI_RAGGING') AND academic_body_id = pg_temp.u('ARC') FROM pg_temp.s('R2'))
              AND (SELECT due_at = occurred_at + interval '7 days' FROM tms.ticket_event WHERE id = pg_temp.last_ev('R2'))
              AND NOT tms.can_act(pg_temp.acct('SQ1'), pg_temp.u('R2')) AND tms.can_act(pg_temp.acct('AR1'), pg_temp.u('R2'))
              AND tms.can_view(pg_temp.acct('SQ1'), pg_temp.u('R2')),
  'forwarded by default to the anti-ragging committee (7 days); the squad keeps sight of it but no longer acts');
SELECT pg_temp.ok((SELECT register_status = 'FORWARDED' AND outcome = 'FORWARDED' AND first_action_at IS NOT NULL AND first_action_due_at IS NOT NULL AND decided_in_time
                   FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('R2') AND forum = 'ANTI_RAGGING_SQUAD')
              AND (SELECT register_status = 'PENDING' AND is_forwarded_in FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('R2') AND forum = 'ANTI_RAGGING'),
  'the register: the squad''s stage forwarded in time with its first action and its due time; the committee''s stage pending');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'AR1', 'Back again', NULL, NULL, NULL, 'ANTI_RAGGING')$q$, 'forwarding to the forum that has the case');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'AR1', 'Onwards')$q$, 'forwarding where the forum has no default and none is named');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('R2', 'FORUM_FORWARDED', 'AR1', 'Caste angle', NULL, NULL, NULL, 'SC_ST_CELL')$q$,
  'forwarding to a committee that is not constituted');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S1', 'FORUM_FORWARDED', 'VC', 'Not with a forum')$q$, 'forwarding a ticket that is not with a forum');
SELECT pg_temp.ok((SELECT sum(forwarded) >= 1 FROM tms.v_grievance_summary WHERE forum = 'ANTI_RAGGING_SQUAD'),
  'the yearly return counts forwarded cases');

-- ======================================================== notifications ==
SELECT pg_temp.ok(pg_temp.notices('T1', 'CREATED', 'RS') = 2 AND pg_temp.notices('T1', 'CREATED', 'H1') = 2,
  'raising T1 queued the requester''s receipt and the handler''s notice, in-app and e-mail');
SELECT pg_temp.ok(pg_temp.notices('L1', 'CREATED', 'ST') = 2
              AND (SELECT count(*) = 2 FROM tms.ticket_notification n JOIN tms.ticket_event e ON e.id = n.ticket_event_id WHERE e.ticket_id = pg_temp.u('L1')
                   AND e.event_type_id = pg_temp.lk('tms_event_type','CREATED')),
  'an unassigned student ticket still sends the student a receipt (the old system sent nothing)');
SELECT pg_temp.ok(pg_temp.notices('S3', 'CREATED', 'ST') = 2 AND pg_temp.notices('S3', 'CREATED', 'DESK') = 0,
  'a desk-recorded ticket: the student gets the receipt, not the desk');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM tms.ticket_notification n JOIN tms.ticket_event e ON e.id = n.ticket_event_id
                              JOIN ref.tms_event_type et ON et.id = e.event_type_id
                              WHERE n.recipient_account_id = e.actor_account_id AND et.code NOT IN ('CREATED', 'REFERRED', 'APPEALED')),
  'nobody is notified of their own action (only receipts)');
SELECT pg_temp.ok(NOT EXISTS (SELECT 1 FROM tms.ticket_notification n JOIN tms.ticket_event e ON e.id = n.ticket_event_id
                              WHERE e.ticket_id = pg_temp.u('S15') AND n.recipient_account_id = pg_temp.acct('MEN')
                                AND e.id >= (SELECT min(x.id) FROM tms.ticket_event x WHERE x.ticket_id = pg_temp.u('S15') AND x.event_type_id = pg_temp.lk('tms_event_type','RECUSED'))),
  'once named, the respondent hears nothing more about the ticket');
UPDATE tms.ticket_notification SET notification_status_id = pg_temp.lk('tms_notification_status','SENT'), attempt_count = 1
WHERE id = (SELECT min(id) FROM tms.ticket_notification);
SELECT pg_temp.ok((SELECT sent_at IS NOT NULL FROM tms.ticket_notification WHERE id = (SELECT min(id) FROM tms.ticket_notification)), 'sending stamps sent_at');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_notification SET attempt_count = 2 WHERE id = (SELECT min(id) FROM tms.ticket_notification)$q$, 'changing a sent notice');
SELECT pg_temp.rejects($q$UPDATE tms.ticket_notification SET recipient_account_id = md5('A-OUT')::uuid WHERE id = (SELECT max(id) FROM tms.ticket_notification)$q$, 'redirecting a queued notice');
SELECT pg_temp.rejects($q$INSERT INTO tms.ticket_event_file (ticket_event_id, file_object_id)
  VALUES ((SELECT max(e.id) FROM tms.ticket_event e JOIN ref.tms_event_type et ON et.id = e.event_type_id AND et.code = 'CONFIRMED'), md5('F2')::uuid)$q$,
  'a file on an entry that takes none');
SELECT pg_temp.rejects($q$DELETE FROM tms.ticket_event_file$q$, 'removing an attachment');

-- ============================================================== reports ==
SELECT pg_temp.ok((SELECT resolved_tickets >= 1 FROM tms.v_ticket_handler_stats WHERE employee_id = pg_temp.emp('H1'))
              AND (SELECT open_tickets >= 1 FROM tms.v_ticket_handler_stats WHERE employee_id = pg_temp.emp('H3')),
  'handler statistics: H1 has resolved, H3 has open tickets');
SELECT pg_temp.ok((SELECT tickets >= 4 AND escalations >= 1 FROM tms.v_ticket_category_stats WHERE category_id = pg_temp.u('C-PWD'))
              AND (SELECT referrals >= 2 FROM tms.v_ticket_category_stats WHERE category_id = pg_temp.u('C-FEER')),
  'category statistics: password resets escalated, fee refunds referred');
SELECT pg_temp.ok((SELECT sum(received) >= 3 AND sum(decided) >= 1 AND sum(decided_in_time) >= 1 AND sum(appeals) >= 1 AND sum(pending) >= 2
                   FROM tms.v_grievance_summary WHERE forum IN ('SGRC', 'OMBUDSPERSON'))
              AND (SELECT academic_year_id = pg_temp.u('Y26') FROM tms.v_grievance_register WHERE ticket_id = pg_temp.u('S3')),
  'the grievance return per academic year and forum: received, decided in time, pending, appeals');

-- the scheduler round the clock (24 × 7 priorities)
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run13 AS SELECT * FROM tms.run_scheduler('2027-03-06 11:00+05:30', false);
SELECT pg_temp.ok((SELECT auto_referred + escalated + exhausted + overdue_notices + reminders + expired + auto_closed + holds_released + compliance_reminders = 0 FROM run13),
  'a Saturday run outside office hours does nothing');
SET LOCAL app.system_job = 'off';
UPDATE tms.helpdesk_setting SET scheduler_office_hours_only = false;
SET LOCAL app.system_job = 'on';
CREATE TEMP TABLE run14 AS SELECT * FROM tms.run_scheduler('2027-03-06 11:00+05:30', false);
SELECT pg_temp.ok((SELECT auto_referred + escalated + exhausted + overdue_notices + reminders + expired + auto_closed + holds_released + compliance_reminders > 0 FROM run14),
  'with scheduler_office_hours_only off the same Saturday run does its work');
SET LOCAL app.system_job = 'off';

-- ================================================ Student TMS switched off ==
UPDATE tms.helpdesk_setting SET student_tms_enabled = false;
SELECT pg_temp.ok(NOT tms.can_view(pg_temp.acct('ST'), pg_temp.u('S1')), 'with Student TMS off, student tickets are hidden');
SELECT pg_temp.rejects($q$SELECT pg_temp.ev('S1', 'REMARKED', 'TA', 'While switched off')$q$, 'acting on a student ticket while Student TMS is off');

-- ================================================ audit, privacy, grants ==
SELECT pg_temp.ok(EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'tms' AND entity_table = 'ticket_category')
              AND EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'tms' AND entity_table = 'ticket_respondent')
              AND NOT EXISTS (SELECT 1 FROM audit.audit_event WHERE entity_schema = 'tms' AND entity_table IN ('ticket_event', 'ticket_event_file')),
  'configuration and respondents are audited; the timeline and its files (themselves a record) are not');
SELECT pg_temp.ok((SELECT count(*) = 11 FROM privacy.data_element WHERE schema_name = 'tms')
              AND (SELECT d.is_sensitive FROM privacy.data_element e JOIN ref.data_category d ON d.id = e.data_category_id
                   WHERE e.schema_name = 'tms' AND e.table_name = 'ticket_respondent'),
  'ticket text, relief, incident date, contact, files, remarks, respondents and opt-outs are in the personal-data inventory (respondents sensitive)');
SELECT pg_temp.ok(NOT has_table_privilege('intranet_analytics', 'tms.ticket', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'tms.ticket_event', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'tms.ticket_respondent', 'SELECT')
              AND NOT has_table_privilege('intranet_analytics', 'tms.v_grievance_register', 'SELECT')
              AND has_table_privilege('intranet_analytics', 'tms.v_grievance_summary', 'SELECT')
              AND has_table_privilege('intranet_analytics', 'tms.v_ticket_category_stats', 'SELECT')
              AND NOT has_table_privilege('intranet_app', 'tms.ticket_event', 'UPDATE')
              AND NOT has_table_privilege('intranet_app', 'tms.ticket_respondent', 'DELETE'),
  'analytics sees statistics and the grievance return, never ticket text, timelines, respondents or the register; the app cannot rewrite records');

\echo '>>> ALL TMS SMOKE TESTS PASSED'
ROLLBACK;
