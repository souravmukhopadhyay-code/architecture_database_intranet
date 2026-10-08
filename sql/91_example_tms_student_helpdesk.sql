-- =============================================================================
-- 91_example_tms_student_helpdesk.sql — ILLUSTRATIVE, NOT PART OF THE CORE PIPELINE
--
-- The standard student helpdesk of SGT University, configured on the TMS
-- module (sql/12_tms.sql) along the UGC (Redress of Grievances of Students)
-- Regulations, 2023 — see docs/tms/tms-design.md §4 and §5. Like 90, this is
-- OPERATIONAL data (which committees exist, which office answers which
-- category), so it is not in the 0*/1* pipeline. Edit before using it for real:
-- committee members, handlers and category owners are entered through the
-- admin UI (they are people, not configuration), and every time limit marked
-- POLICY in 12_tms.sql must be confirmed by the Registrar / IQAC.
--
-- Usage: after sql/00 .. sql/13 and sql/90:
--   psql -d intranet -v ON_ERROR_STOP=1 -f sql/90_example_sgt_org_structure.sql
--   psql -d intranet -v ON_ERROR_STOP=1 -f sql/91_example_tms_student_helpdesk.sql
--
-- What it sets up
--   committees   one university SGRC, ICC, Anti-Ragging Squad and Committee,
--                Equal Opportunity Cell and SC / ST Cell (a school may add its own SGRC later — the
--                nearest SGRC above the student hears the case)
--   declaration  the text a student accepts when raising a ticket
--   tree         8 masters: Academic · Examinations · Fees & scholarships ·
--                Campus services · Records & documents · Equity & conduct ·
--                Ragging · Sexual harassment — every leaf mapped to a UGC
--                grievance head, a route and a redressal forum
--   switch       Student TMS on
-- =============================================================================

SET client_encoding = 'UTF8';
SET search_path = tms, org, people, academic, ref, public;

CREATE OR REPLACE FUNCTION pg_temp.unit(p_code text) RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM org.org_unit WHERE code = p_code $$;
CREATE OR REPLACE FUNCTION pg_temp.route(p_code text) RETURNS smallint LANGUAGE sql STABLE AS $$ SELECT id FROM tms.ticket_route WHERE code = p_code $$;
CREATE OR REPLACE FUNCTION pg_temp.forum(p_code text) RETURNS smallint LANGUAGE sql STABLE AS $$ SELECT id FROM tms.redressal_forum WHERE code = p_code $$;

DO $$ BEGIN
  IF pg_temp.unit('SGTU') IS NULL THEN
    RAISE EXCEPTION '91_example_tms_student_helpdesk.sql: run sql/90_example_sgt_org_structure.sql first';
  END IF;
  IF EXISTS (SELECT 1 FROM tms.ticket_category c JOIN ref.tms_ticket_domain d ON d.id = c.ticket_domain_id
             WHERE d.code = 'STUDENT' AND c.name = 'Academic') THEN
    RAISE NOTICE '91: the student helpdesk is configured already — nothing to do';
  END IF;
END $$;

-- ------------------------------------------------------------- committees --
INSERT INTO academic.academic_body (academic_body_type_id, org_unit_id, name, quorum)
SELECT ref.id_of('academic_body_type', v.t), pg_temp.unit('SGTU'), v.n, v.q
FROM (VALUES ('STUDENT_GRIEVANCE_COMMITTEE','Students'' Grievance Redressal Committee',3),
             ('INTERNAL_COMPLAINTS_COMMITTEE','Internal Complaints Committee',4),
             ('ANTI_RAGGING_COMMITTEE','Anti-Ragging Committee',3),
             ('EQUAL_OPPORTUNITY_CELL','Equal Opportunity Cell',3),
             ('ANTI_RAGGING_SQUAD','Anti-Ragging Squad',1),
             ('SC_ST_CELL','SC / ST Cell',3)) v(t, n, q)
ON CONFLICT (academic_body_type_id, org_unit_id) DO NOTHING;

-- ------------------------------------------------------------ declaration --
INSERT INTO tms.helpdesk_declaration (ticket_domain_id, body, valid)
SELECT ref.id_of('tms_ticket_domain', 'STUDENT'),
       'I declare that the information given is true to the best of my knowledge; that the matter is not pending before any court or tribunal; '
       'and that I have read the relevant university notices and policies before raising this request.',
       daterange(current_date, NULL)
WHERE NOT EXISTS (SELECT 1 FROM tms.helpdesk_declaration d WHERE d.ticket_domain_id = ref.id_of('tms_ticket_domain', 'STUDENT') AND d.valid @> current_date);

-- ------------------------------------------------------------------- tree --
-- One row per node: key, parent key, level, name, responsible unit (root, or
-- an override), category type (masters), priority (leaves), route, forum,
-- grievance head, academic context, and the handling flags (NULL = inherit).
CREATE TEMP TABLE t91 (k text PRIMARY KEY, parent text, lvl text, name text, unit text, ctype text, prio text, route text, forum text,
                       head text, ctx text, direct boolean, conf boolean, anon boolean, resp boolean, incident boolean, ord smallint);
INSERT INTO t91 VALUES
 -- 1. Academic: the relative route (mentor → HOD → Dean → Dean Academics → VC), then the SGRC
 ('ACAD',      NULL,    'MASTER',      'Academic',                           'SGTU',    'ACADEMIC',     NULL,     'STUDENT_ACADEMIC',       'SGRC', 'QUALITY_OF_EDUCATION', NULL,      NULL, NULL, NULL, true, NULL, 1),
 ('ACAD.TL',   'ACAD',  'CATEGORY',    'Teaching & learning',                NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('ACAD.TL.Q', 'ACAD.TL','SUB_CATEGORY','Quality of teaching',               NULL,      NULL,           'LOW',    NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, true, NULL, NULL, 1),
 ('ACAD.TL.C', 'ACAD.TL','SUB_CATEGORY','Classes not held / timetable',      NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   'PROGRAMME',NULL,NULL, NULL, NULL, NULL, 2),
 ('ACAD.TL.A', 'ACAD.TL','SUB_CATEGORY','Attendance',                        NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 3),
 ('ACAD.TL.R', 'ACAD.TL','SUB_CATEGORY','Course registration',               NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 4),
 ('ACAD.TL.M', 'ACAD.TL','SUB_CATEGORY','Mentoring & academic advice',       NULL,      NULL,           'LOW',    NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 5),
 ('ACAD.EV',   'ACAD',  'CATEGORY',    'Internal evaluation',                NULL,      NULL,           NULL,     NULL,                     NULL,   'EVALUATION',           NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('ACAD.EV.M', 'ACAD.EV','SUB_CATEGORY','Internal assessment marks',         NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 1),
 -- 2. Examinations: the exam desk, owners, the Controller, then the VC; SGRC
 ('EXAM',      NULL,    'MASTER',      'Examinations',                       'EXAM',    'EXAMINATION',  NULL,     'STUDENT_EXAMINATION',    'SGRC', 'EVALUATION',           NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('EXAM.RS',   'EXAM',  'CATEGORY',    'Results',                            NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('EXAM.RS.D', 'EXAM.RS','SUB_CATEGORY','Result not declared / delayed',     NULL,      NULL,           'URGENT', NULL,                     NULL,   'EXAM_RESULT_DELAY',    'PROGRAMME',NULL,NULL, NULL, NULL, NULL, 1),
 ('EXAM.RS.E', 'EXAM.RS','SUB_CATEGORY','Marks or grade error',              NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 2),
 ('EXAM.RS.R', 'EXAM.RS','SUB_CATEGORY','Revaluation / re-totalling',        NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 3),
 ('EXAM.AD',   'EXAM',  'CATEGORY',    'Admit card & date sheet',            NULL,      NULL,           NULL,     NULL,                     NULL,   'EXAM_RESULT_DELAY',    NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('EXAM.AD.A', 'EXAM.AD','SUB_CATEGORY','Admit card not issued',             NULL,      NULL,           'URGENT', NULL,                     NULL,   NULL,                   'PROGRAMME',NULL,NULL, NULL, NULL, NULL, 1),
 ('EXAM.AD.C', 'EXAM.AD','SUB_CATEGORY','Date-sheet clash',                  NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   'COURSE',  NULL, NULL, NULL, NULL, NULL, 2),
 ('EXAM.CT',   'EXAM',  'CATEGORY',    'Certificates',                       NULL,      NULL,           NULL,     NULL,                     NULL,   'DOCUMENTS_WITHHELD',   NULL,      NULL, NULL, NULL, NULL, NULL, 3),
 ('EXAM.CT.D', 'EXAM.CT','SUB_CATEGORY','Degree, transcript or migration',   NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 -- 3. Fees & scholarships: the fee desk, owners, head of the fee section, Registrar, VC; SGRC
 ('FEE',       NULL,    'MASTER',      'Fees & scholarships',                'FIN-FEE', 'NON_ACADEMIC', NULL,     'STUDENT_ADMINISTRATIVE', 'SGRC', 'EXCESS_FEE',           NULL,      NULL, NULL, NULL, NULL, NULL, 3),
 ('FEE.F',     'FEE',   'CATEGORY',    'Fees',                               NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('FEE.F.X',   'FEE.F', 'SUB_CATEGORY','Fee demanded beyond the declared fee',NULL,     NULL,           'HIGH',   NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('FEE.F.R',   'FEE.F', 'SUB_CATEGORY','Fee refund',                         NULL,      NULL,           'MEDIUM', NULL,                     NULL,   'FEE_REFUND',           NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('FEE.F.P',   'FEE.F', 'SUB_CATEGORY','Payment not reflected',              NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 3),
 ('FEE.S',     'FEE',   'CATEGORY',    'Scholarships & financial aid',       NULL,      NULL,           NULL,     NULL,                     NULL,   'SCHOLARSHIP',          NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('FEE.S.N',   'FEE.S', 'SUB_CATEGORY','Scholarship not credited',           NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 -- 4. Campus services: each leaf answered by its own office; SGRC (amenities)
 ('SVC',       NULL,    'MASTER',      'Campus services',                    'ESTATE',  'NON_ACADEMIC', NULL,     'STUDENT_ADMINISTRATIVE', 'SGRC', 'AMENITIES',            NULL,      NULL, NULL, NULL, NULL, NULL, 4),
 ('SVC.C',     'SVC',   'CATEGORY',    'Campus & facilities',                NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('SVC.C.R',   'SVC.C', 'SUB_CATEGORY','Classroom or laboratory facilities', NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('SVC.C.H',   'SVC.C', 'SUB_CATEGORY','Hostel & mess',                      NULL,      NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('SVC.C.T',   'SVC.C', 'SUB_CATEGORY','Transport',                          'TRANSP',  NULL,           'MEDIUM', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 3),
 ('SVC.C.L',   'SVC.C', 'SUB_CATEGORY','Library',                            'LIB',     NULL,           'LOW',    NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 4),
 ('SVC.C.I',   'SVC.C', 'SUB_CATEGORY','Wi-Fi, e-mail & ERP login',          'IT-HELP', NULL,           'HIGH',   NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 5),
 -- 5. Records & documents: the Registrar's office; SGRC
 ('REC',       NULL,    'MASTER',      'Records & documents',                'REG',     'NON_ACADEMIC', NULL,     'STUDENT_ADMINISTRATIVE', 'SGRC', 'DOCUMENTS_WITHHELD',   NULL,      NULL, NULL, NULL, NULL, NULL, 5),
 ('REC.D',     'REC',   'CATEGORY',    'Documents',                          NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('REC.D.O',   'REC.D', 'SUB_CATEGORY','Original documents not returned',    NULL,      NULL,           'HIGH',   NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('REC.D.B',   'REC.D', 'SUB_CATEGORY','Bonafide certificate / ID card',     NULL,      NULL,           'LOW',    NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 -- 6. Equity & conduct: straight to the committees, confidential, complaint against a person
 ('EQ',        NULL,    'MASTER',      'Equity & conduct',                   'SGTU',    'NON_ACADEMIC', NULL,     NULL,                     NULL,   NULL,                   NULL,      true, true, NULL, true, true, 6),
 ('EQ.C',      'EQ',    'CATEGORY',    'Equity & conduct',                   NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('EQ.C.D',    'EQ.C',  'SUB_CATEGORY','Discrimination (SC / ST / OBC / women / minority / PwD)', NULL, NULL, 'HIGH', NULL,           'EQUAL_OPPORTUNITY','DISCRIMINATION', NULL,   NULL, NULL, NULL, NULL, NULL, 1),
 ('EQ.C.H',    'EQ.C',  'SUB_CATEGORY','Harassment or victimisation',        NULL,      NULL,           'URGENT',   NULL,                     'SGRC', 'HARASSMENT',           NULL,      NULL, NULL, NULL, NULL, NULL, 2),
 ('EQ.C.S',    'EQ.C',  'SUB_CATEGORY','Caste-based discrimination (SC / ST)', NULL,  NULL,           'HIGH',   NULL,                     'SC_ST_CELL','DISCRIMINATION',NULL, NULL, NULL, NULL, NULL, NULL, 3),
 -- 7. Ragging: the Anti-Ragging Committee at once; anonymous allowed
 ('RAG',       NULL,    'MASTER',      'Ragging',                            'SGTU',    'NON_ACADEMIC', NULL,     NULL,                     'ANTI_RAGGING_SQUAD','RAGGING',       NULL,      true, true, true, true, true, 7),
 ('RAG.C',     'RAG',   'CATEGORY',    'Ragging',                            NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('RAG.C.R',   'RAG.C', 'SUB_CATEGORY','Ragging complaint',                  NULL,      NULL,           'URGENT', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 -- 8. Sexual harassment: the Internal Complaints Committee at once; a named complainant
 ('POSH',      NULL,    'MASTER',      'Sexual harassment',                  'SGTU',    'NON_ACADEMIC', NULL,     NULL,                     'ICC',  'SEXUAL_HARASSMENT',    NULL,      true, true, false, true, true, 8),
 ('POSH.C',    'POSH',  'CATEGORY',    'Sexual harassment',                  NULL,      NULL,           NULL,     NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1),
 ('POSH.C.C',  'POSH.C','SUB_CATEGORY','Complaint to the ICC',               NULL,      NULL,           'URGENT', NULL,                     NULL,   NULL,                   NULL,      NULL, NULL, NULL, NULL, NULL, 1);

-- insert top-down (parents first); a re-run inserts nothing
CREATE TEMP TABLE t91_id AS SELECT k, gen_random_uuid() AS id FROM t91;
INSERT INTO tms.ticket_category (id, parent_id, category_level_id, ticket_domain_id, org_unit_id, category_type_id, priority_id,
                                 academic_context_rule_id, route_id, redressal_forum_id, direct_to_forum, is_confidential, allows_anonymous,
                                 allows_respondent, requires_incident_date, grievance_head_id, name, sort_order)
SELECT i.id, p.id, ref.id_of('tms_category_level', t.lvl),
       CASE WHEN t.parent IS NULL THEN ref.id_of('tms_ticket_domain', 'STUDENT') END,
       CASE WHEN t.unit IS NOT NULL THEN pg_temp.unit(t.unit) END,
       CASE WHEN t.ctype IS NOT NULL THEN ref.id_of('tms_category_type', t.ctype) END,
       CASE WHEN t.prio IS NOT NULL THEN ref.id_of('tms_priority', t.prio) END,
       CASE WHEN t.ctx IS NOT NULL THEN ref.id_of('tms_academic_context_rule', t.ctx) END,
       pg_temp.route(t.route), pg_temp.forum(t.forum), t.direct, t.conf, t.anon, t.resp, t.incident,
       CASE WHEN t.head IS NOT NULL THEN ref.id_of('tms_grievance_head', t.head) END,
       t.name, t.ord
FROM t91 t JOIN t91_id i ON i.k = t.k LEFT JOIN t91_id p ON p.k = t.parent
WHERE NOT EXISTS (SELECT 1 FROM tms.ticket_category c JOIN ref.tms_ticket_domain d ON d.id = c.ticket_domain_id
                  WHERE d.code = 'STUDENT' AND c.name = 'Academic')
ORDER BY CASE t.lvl WHEN 'MASTER' THEN 1 WHEN 'CATEGORY' THEN 2 ELSE 3 END;

-- -------------------------------------------------- knowledge base (starter) --
INSERT INTO tms.kb_article (ticket_domain_id, category_id, title, body, published, sort_order)
SELECT ref.id_of('tms_ticket_domain', 'STUDENT'), c.id, v.title, v.body, daterange(current_date, NULL), v.ord
FROM (VALUES
  (NULL::text, 'How your grievance is handled',
   'Your ticket first goes to the office or person responsible (for academic matters: your mentor, then your HOD, your Dean, Dean Academics and the VC). '
   'If you are not satisfied with the answer, or it is not settled in time, you can take it to the Students'' Grievance Redressal Committee, '
   'which decides within the time set by the university. You may appeal the committee''s decision to the Ombudsperson.', 1),
  (NULL, 'Ragging and harassment: where to complain',
   'Ragging complaints go directly and confidentially to the Anti-Ragging Committee (you may stay anonymous). Complaints of sexual harassment go to '
   'the Internal Complaints Committee. Discrimination goes to the Equal Opportunity Cell. The person you complain about never sees or handles your complaint.', 2),
  ('Fees & scholarships', 'Fee refunds and payments',
   'Check the fee receipt in the ERP first; a payment can take up to two working days to appear. Refunds follow the refund policy in the prospectus.', 1)
) v(cat, title, body, ord)
LEFT JOIN tms.ticket_category c ON c.name = v.cat AND c.parent_id IS NULL AND c.ticket_domain_id = ref.id_of('tms_ticket_domain', 'STUDENT')
WHERE NOT EXISTS (SELECT 1 FROM tms.kb_article k WHERE k.title = v.title);

-- ----------------------------------------------------------- SLA by category --
-- Harassment, sexual harassment and ragging are URGENT (the leaves above) and
-- their clock runs round the clock — nights, weekends and holidays count.
-- Every other category takes its priority's SLA until SGT defines its own,
-- per category (inherited by everything below it; NULL = as the parent):
--   UPDATE tms.ticket_category SET sla_hours = 24, first_response_hours = 4,
--          sla_office_hours_only = true WHERE name = 'Admit card not issued';
UPDATE tms.ticket_category c SET sla_office_hours_only = false
FROM ref.tms_ticket_domain d
WHERE d.id = ref.id_of('tms_ticket_domain', 'STUDENT')
  AND ((c.parent_id IS NULL AND c.ticket_domain_id = d.id AND c.name IN ('Ragging', 'Sexual harassment'))
       OR c.name = 'Harassment or victimisation')
  AND c.sla_office_hours_only IS DISTINCT FROM false;

-- urgent cases are the committees' to act on within hours, nights and holidays
-- included: the scheduler runs round the clock so their alerts go out at once
UPDATE tms.helpdesk_setting SET scheduler_office_hours_only = false WHERE scheduler_office_hours_only;
UPDATE tms.helpdesk_setting SET student_tms_enabled = true WHERE NOT student_tms_enabled;

DO $$
DECLARE n int; l int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE is_leaf) INTO n, l FROM tms.v_ticket_category WHERE ticket_domain = 'STUDENT';
  RAISE NOTICE '91: student helpdesk — % categories, % leaves; % of them filed straight with a committee; Student TMS on',
    n, l, (SELECT count(*) FROM tms.v_ticket_category WHERE ticket_domain = 'STUDENT' AND is_leaf AND direct_to_forum);
  RAISE NOTICE '91: next — add committee members (academic.academic_body_member), appoint the Ombudsperson (org.appointment, OMBUDSPERSON at SGTU), '
               'assign handlers and owners to the categories, and confirm the POLICY time limits.';
END $$;
