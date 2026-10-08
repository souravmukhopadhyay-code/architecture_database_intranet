-- =============================================================================
-- 90_example_sgt_org_structure.sql — ILLUSTRATIVE, NOT PART OF THE CORE PIPELINE
--
-- sql/00 .. sql/11 are schema + universal reference data (reusable by any
-- institution). Actual org units — which schools, which central departments,
-- which blocks exist — are OPERATIONAL data, specific to SGT, entered once
-- through this script (or an admin UI) after 00-11 have been applied. That is
-- a deliberate design choice, not an oversight: org_unit rows describe *who
-- exists today*, the same way people/employee rows do, so they don't belong
-- in the generic reusable seed any more than a fake employee would.
--
-- This script exists to answer one question directly: "does this foundation
-- actually provide for independent/central departments like HR, IT, Finance
-- etc.?" — Yes. Every one of them is just a row in org.org_unit with
-- org_unit_type = CENTRAL_DEPARTMENT (see ref.org_unit_type, seeded in
-- sql/10_seed_reference.sql). There is no separate "central department"
-- table, no special-cased HR/IT/Finance tables — one generic tree, same as
-- schools and academic departments. This script proves it by creating the
-- real SGT central departments and one worked example (an IT department
-- head whose permissions are derived automatically, with no row copied onto
-- their account) end to end.
--
-- The central-department list below matches the departmentType keys the old
-- SGT UMS actually used (hr, erp/it, drd, finance, library, admissions,
-- registrar, noting, gateEntry, cab_booking) plus Examinations, which the
-- old TMS escalation ladder required. Edit codes/names/sections to match
-- SGT's real structure before running against a real environment — this is
-- a template, not a fixture to run as-is in production.
--
-- Usage: run AFTER sql/00 .. sql/11 (and after the module files sql/12, sql/13
-- if their examples — the school's event approval chain — are wanted; it is
-- intentionally excluded from
-- the `for f in sql/0*.sql sql/1*.sql` loop in README.md, since 9* is not
-- matched by either glob):
--   psql -d intranet -v ON_ERROR_STOP=1 -f sql/90_example_sgt_org_structure.sql
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = org, people, ref, authz, public;

-- ------------------------------------------------------------------- roots --
INSERT INTO org.org_unit (id, org_unit_type_id, parent_id, code, name) VALUES
  (gen_random_uuid(), ref.id_of('org_unit_type','UNIVERSITY'), NULL, 'SGTU', 'SGT University')
ON CONFLICT (code) DO NOTHING;

-- Helper: fetch a unit's id by its code (used throughout this script for
-- readability — application code would normally hold these as variables).
CREATE OR REPLACE FUNCTION org.id_of(p_code text) RETURNS uuid
LANGUAGE sql STABLE AS $$ SELECT id FROM org.org_unit WHERE code = p_code $$;

-- ----------------------------------------------------------- academic side --
-- A couple of schools/departments, just enough to be a realistic example —
-- the full academic structure is entered the same way, unit by unit.
INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','SCHOOL'), org.id_of('SGTU'), 'SET', 'School of Engineering & Technology'),
  (ref.id_of('org_unit_type','SCHOOL'), org.id_of('SGTU'), 'SOM', 'School of Management')
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','DEPARTMENT'), org.id_of('SET'), 'CSE', 'Computer Science & Engineering'),
  (ref.id_of('org_unit_type','DEPARTMENT'), org.id_of('SOM'), 'MBA', 'Department of Management')
ON CONFLICT (code) DO NOTHING;

-- --------------------------------------------------- central departments ---
-- THE PROVISION IN QUESTION: HR, IT, Finance and every other central,
-- non-academic department, each simply a CENTRAL_DEPARTMENT org_unit.
INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'HR',      'Human Resources'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'IT',      'Information Technology'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'FIN',     'Finance & Accounts'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'REG',     'Registrar''s Office'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'ADM',     'Admissions Office'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'LIB',     'Central Library'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'DRD',     'Directorate of Research & Development'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'EXAM',    'Examination Controller''s Office'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'ESTATE',  'Estate & Security'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'TRANSP',  'Transport Office'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'DSW',     'Dean Students'' Welfare')
ON CONFLICT (code) DO NOTHING;

-- Sub-units within a central department are just SECTION nodes one level
-- deeper in the same tree — no special modelling needed.
INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','SECTION'), org.id_of('HR'),     'HR-REC',   'Recruitment'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('HR'),     'HR-PAY',   'Payroll & Benefits'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('IT'),     'IT-HELP',  'IT Helpdesk'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('IT'),     'IT-ERP',   'ERP & Systems'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('FIN'),    'FIN-ACC',  'Accounts'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('FIN'),    'FIN-FEE',  'Fees & Scholarships'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('DRD'),    'DRD-GRT',  'Grants Cell'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('DRD'),    'DRD-IPR',  'IPR Cell'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('ESTATE'), 'EST-GATE', 'Gate Entry & Security'),
  (ref.id_of('org_unit_type','SECTION'), org.id_of('REG'),    'REG-NOTE', 'Noting / Internal Approvals')
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------ facility "blocks" --
-- Resource management organises the campus into administratively-managed
-- "blocks" (the old system's SeminarHallBlock: A, B, C, D …), each with its
-- own head / custodian staff. A block is an operational unit with its own
-- responsible people — that makes it an org_unit (type BLOCK, seeded in
-- sql/10 for the facility module), NOT a row in org.building (which models
-- the physical structure). Here the blocks sit under the Estate office; a
-- block takes custody of its building through facility.custody, and its head
-- (or anyone granted FACILITY_CUSTODIAN there) approves every booking of the
-- rooms in it — no per-module admin table, no role string on the user.
INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','BLOCK'), org.id_of('ESTATE'), 'BLOCK-A', 'Block A'),
  (ref.id_of('org_unit_type','BLOCK'), org.id_of('ESTATE'), 'BLOCK-B', 'Block B'),
  (ref.id_of('org_unit_type','BLOCK'), org.id_of('ESTATE'), 'BLOCK-C', 'Block C'),
  (ref.id_of('org_unit_type','BLOCK'), org.id_of('ESTATE'), 'BLOCK-D', 'Block D')
ON CONFLICT (code) DO NOTHING;

-- One campus, one building per block, the block in custody of its building.
INSERT INTO org.campus (code, name) VALUES ('MAIN', 'Main campus') ON CONFLICT (code) DO NOTHING;
INSERT INTO org.building (campus_id, code, name, building_kind_id)
SELECT c.id, v.code, v.name, ref.id_of('building_kind', 'BUILDING')
FROM org.campus c, (VALUES ('A','Block A'),('B','Block B'),('C','Block C'),('D','Block D')) v(code, name)
WHERE c.code = 'MAIN'
ON CONFLICT (campus_id, code) DO NOTHING;
INSERT INTO facility.custody (building_id, org_unit_id)
SELECT b.id, org.id_of('BLOCK-' || b.code) FROM org.building b JOIN org.campus c ON c.id = b.campus_id AND c.code = 'MAIN'
WHERE b.code IN ('A','B','C','D')
  AND NOT EXISTS (SELECT 1 FROM facility.custody x WHERE x.building_id = b.id AND x.valid @> current_date);

-- Per-block approval: Block A's auditorium bookings also need the Registrar's
-- office. A chain scoped to BLOCK-A overrides the default ROOM_BOOKING chain
-- for every space in that block's custody — configuration, not code.
INSERT INTO wf.approval_chain (document_type_id, scope_org_unit_id, valid, note)
SELECT dt.id, org.id_of('BLOCK-A'), daterange(current_date, NULL), 'Block A: custodian, then the Registrar''s office'
FROM wf.approval_document_type dt WHERE dt.code = 'ROOM_BOOKING'
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain c WHERE c.document_type_id = dt.id AND c.scope_org_unit_id = org.id_of('BLOCK-A') AND c.valid @> current_date);
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_org_unit_type_id, anchor_is_owner, is_signature)
SELECT c.id, v.seq, v.code, v.label, pc.permission_id, NULL, v.owner, false
FROM wf.approval_chain c JOIN wf.approval_document_type dt ON dt.id = c.document_type_id AND dt.code = 'ROOM_BOOKING'
JOIN (VALUES (1, 'CUSTODIAN', 'Block A custodian', 'facility.booking.approve', true),
             (2, 'REGISTRAR', 'Registrar''s office', 'facility.event.approve', false)) v(seq, code, label, perm, owner) ON true
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext
WHERE c.scope_org_unit_id = org.id_of('BLOCK-A') AND c.valid @> current_date
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain_stage s WHERE s.chain_id = c.id);

-- Per-school event approval: every approval is configuration on the wf engine.
-- The default EVENT_PROPOSAL chain (sql/13_events.sql) is advisor / head of the
-- organising unit -> central coordination committee. The School of Engineering
-- also wants its Dean when the budget is 50,000 or more: one chain scoped to
-- SET (it covers its departments and the clubs under them), three stage rows.
-- The Dean's level is a POSITION level with min_amount — it simply does not
-- appear in a round with a smaller budget. (No rows are written when the
-- events module is not installed.)
INSERT INTO wf.approval_chain (document_type_id, scope_org_unit_id, valid, note)
SELECT dt.id, org.id_of('SET'), daterange(current_date, NULL), 'School of Engineering & Technology: Dean from a budget of 50,000'
FROM wf.approval_document_type dt WHERE dt.code = 'EVENT_PROPOSAL'
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain c WHERE c.document_type_id = dt.id AND c.scope_org_unit_id = org.id_of('SET') AND c.valid @> current_date);
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, permission_id, position_type_id,
                                     anchor_org_unit_type_id, anchor_is_owner, min_amount, wf_self_action_id, due_within, wf_timeout_action_id)
SELECT c.id, v.seq, v.code, v.label, ref.id_of('wf_approver_kind', v.kind),
       (SELECT pc.permission_id FROM authz.v_permission_code pc WHERE pc.code = v.perm::citext),
       (SELECT pt.id FROM org.position_type pt WHERE pt.code = v.pos),
       CASE WHEN v.anchor IS NOT NULL THEN ref.id_of('org_unit_type', v.anchor) END,
       v.owner, v.min_amount, ref.id_of('wf_self_action', v.self), v.due, ref.id_of('wf_timeout_action', v.timeout)
FROM wf.approval_chain c JOIN wf.approval_document_type dt ON dt.id = c.document_type_id AND dt.code = 'EVENT_PROPOSAL'
JOIN (VALUES
  (1, 'ADVISOR', 'Club advisor / head of the organising unit', 'PERMISSION', 'events.proposal.review',  NULL,   NULL,     true,  NULL::numeric, 'SKIP',  interval '3 days', 'REMIND'),
  (2, 'DEAN',    'Dean (budget of 50,000 and above)',          'POSITION',   NULL,                      'DEAN', 'SCHOOL', false, 50000,         'BLOCK', interval '3 days', 'ESCALATE'),
  (3, 'CCC',     'Central coordination committee',             'PERMISSION', 'events.proposal.approve', NULL,   NULL,     false, NULL,          'BLOCK', interval '5 days', 'REMIND')
) v(seq, code, label, kind, perm, pos, anchor, owner, min_amount, self, due, timeout) ON true
WHERE c.scope_org_unit_id = org.id_of('SET') AND c.valid @> current_date
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain_stage s WHERE s.chain_id = c.id);

-- Every kind of club. WHOSE a club is is its parent unit: an academic club sits
-- under its school or department, a cultural / sports / social-service club
-- under the Dean Students' Welfare office (DSW, created above), a university
-- society under the university. WHAT it is is its category (ref.club_category).
-- The DSW clubs get their own path with one chain scoped to the DSW office:
-- the head of that office, then the committee — for founding a club and for
-- its events. (No rows are written when the events module is not installed.)
INSERT INTO wf.approval_chain (document_type_id, scope_org_unit_id, valid, note)
SELECT dt.id, org.id_of('DSW'), daterange(current_date, NULL), 'Clubs of the Dean Students'' Welfare office'
FROM wf.approval_document_type dt WHERE dt.code IN ('CLUB_PROPOSAL', 'EVENT_PROPOSAL')
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain c WHERE c.document_type_id = dt.id AND c.scope_org_unit_id = org.id_of('DSW') AND c.valid @> current_date);
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, wf_approver_kind_id, permission_id, position_type_id,
                                     anchor_org_unit_type_id, anchor_is_owner, wf_self_action_id, due_within, wf_timeout_action_id)
SELECT c.id, v.seq, v.code, v.label, ref.id_of('wf_approver_kind', v.kind),
       (SELECT pc.permission_id FROM authz.v_permission_code pc WHERE pc.code = v.perm::citext),
       (SELECT pt.id FROM org.position_type pt WHERE pt.code = v.pos),
       CASE WHEN v.anchor IS NOT NULL THEN ref.id_of('org_unit_type', v.anchor) END,
       v.owner, ref.id_of('wf_self_action', v.self), v.due, ref.id_of('wf_timeout_action', 'REMIND')
FROM wf.approval_chain c JOIN wf.approval_document_type dt ON dt.id = c.document_type_id
JOIN (VALUES
  ('CLUB_PROPOSAL',  1, 'DSW',     'Dean Students'' Welfare',        'POSITION',   NULL,                           'HEAD', NULL,                 true,  'BLOCK', interval '5 days'),
  ('CLUB_PROPOSAL',  2, 'CCC',     'Central coordination committee', 'PERMISSION', 'events.club_proposal.approve', NULL,   NULL,                 false, 'BLOCK', interval '7 days'),
  ('EVENT_PROPOSAL', 1, 'ADVISOR', 'Club advisor',                   'PERMISSION', 'events.proposal.review',       NULL,   NULL,                 true,  'SKIP',  interval '3 days'),
  ('EVENT_PROPOSAL', 2, 'DSW',     'Dean Students'' Welfare',        'POSITION',   NULL,                           'HEAD', 'CENTRAL_DEPARTMENT', false, 'BLOCK', interval '3 days'),
  ('EVENT_PROPOSAL', 3, 'CCC',     'Central coordination committee', 'PERMISSION', 'events.proposal.approve',      NULL,   NULL,                 false, 'BLOCK', interval '5 days')
) v(doc, seq, code, label, kind, perm, pos, anchor, owner, self, due) ON v.doc = dt.code
WHERE c.scope_org_unit_id = org.id_of('DSW') AND c.valid @> current_date
  AND NOT EXISTS (SELECT 1 FROM wf.approval_chain_stage s WHERE s.chain_id = c.id);

-- ============================================================================
-- Worked proof: appoint a Head of IT and show their permissions are derived
-- automatically — nothing is copied onto their account.
-- ============================================================================
DO $$
DECLARE
  v_person_id   uuid;
  v_employee_id uuid;
  v_account_id  uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM people.employee WHERE employee_code = 'EX-IT-HEAD') THEN
    RETURN;  -- already created by a previous run
  END IF;

  INSERT INTO people.person (id, first_name, last_name) VALUES (gen_random_uuid(), 'Priya', 'Sharma')
    RETURNING id INTO v_person_id;
  INSERT INTO people.employee (id, person_id, employee_code, employee_category_id,
                               employment_type_id, employment_status_id, joined_on)
  VALUES (gen_random_uuid(), v_person_id, 'EX-IT-HEAD', ref.id_of('employee_category','NON_TEACHING'),
          ref.id_of('employment_type','PERMANENT'), ref.id_of('employment_status','ACTIVE'), current_date)
  RETURNING id INTO v_employee_id;
  INSERT INTO people.employee_assignment (employee_id, org_unit_id, designation_id, is_primary)
  VALUES (v_employee_id, org.id_of('IT'),
          (SELECT id FROM people.designation WHERE code = 'SYSTEM_ADMINISTRATOR'), true);
  INSERT INTO org.appointment (org_unit_id, position_type_id, employee_id)
  VALUES (org.id_of('IT'), (SELECT id FROM org.position_type WHERE code = 'HEAD'), v_employee_id);
  INSERT INTO iam.user_account (id, person_id, username, password, account_status_id)
  VALUES (gen_random_uuid(), v_person_id, 'EX-IT-HEAD', '!unusable', ref.id_of('account_status','ACTIVE'))
  RETURNING id INTO v_account_id;

  RAISE NOTICE 'Example: Priya Sharma appointed HEAD of IT.';
  RAISE NOTICE '  core_admin.employee.view over the IT department, derived (not stored) -> %',
    authz.has_permission(v_account_id, 'core_admin.employee.view', org.id_of('IT'));
  RAISE NOTICE '  same permission over Finance, which she was never granted -> %',
    authz.has_permission(v_account_id, 'core_admin.employee.view', org.id_of('FIN'));
END $$;

DROP FUNCTION org.id_of(text);
