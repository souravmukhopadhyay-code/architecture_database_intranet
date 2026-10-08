-- =============================================================================
-- 09_views_functions.sql — Derived data (never stored) + privilege grants
--
-- Everything here is computable from base facts, so it is a view/function,
-- not a column: tree paths, display names, current affiliation, school of an
-- employee, age/minor status, last login, permission codes, effective roles and
-- permissions, DPDP request status. The application caches hot results (e.g.
-- effective permissions per account in Redis) and invalidates on change.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = public;

-- ================================================================== org =====
-- Ancestors of a unit, including itself (depth 0 = the unit).
CREATE OR REPLACE FUNCTION org.ancestors(p_unit uuid)
RETURNS TABLE (org_unit_id uuid, depth int) LANGUAGE sql STABLE AS $$
  WITH RECURSIVE up AS (
    SELECT id, parent_id, 0 AS depth FROM org.org_unit WHERE id = p_unit
    UNION ALL
    SELECT u.id, u.parent_id, up.depth + 1 FROM org.org_unit u JOIN up ON u.id = up.parent_id
  )
  SELECT id, depth FROM up;
$$;

-- Descendants of a unit, including itself (depth 0 = the unit).
CREATE OR REPLACE FUNCTION org.descendants(p_unit uuid)
RETURNS TABLE (org_unit_id uuid, depth int) LANGUAGE sql STABLE AS $$
  WITH RECURSIVE down AS (
    SELECT id, 0 AS depth FROM org.org_unit WHERE id = p_unit
    UNION ALL
    SELECT u.id, down.depth + 1 FROM org.org_unit u JOIN down ON u.parent_id = down.id
  )
  SELECT id, depth FROM down;
$$;

-- Nearest ancestor (or self) of a given unit type, e.g. the SCHOOL of a department.
CREATE OR REPLACE FUNCTION org.nearest_of_type(p_unit uuid, p_type_code text)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT a.org_unit_id
  FROM org.ancestors(p_unit) a
  JOIN org.org_unit u ON u.id = a.org_unit_id
  JOIN ref.org_unit_type t ON t.id = u.org_unit_type_id
  WHERE t.code = p_type_code
  ORDER BY a.depth
  LIMIT 1;
$$;

-- Whole tree with depth and readable path.
CREATE OR REPLACE VIEW org.v_org_unit_tree AS
WITH RECURSIVE t AS (
  SELECT u.id, u.parent_id, u.code, u.name, u.org_unit_type_id, 0 AS depth,
         u.name::text AS path, ARRAY[u.id] AS id_path
  FROM org.org_unit u WHERE u.parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, c.code, c.name, c.org_unit_type_id, t.depth + 1,
         t.path || ' › ' || c.name, t.id_path || c.id
  FROM org.org_unit c JOIN t ON c.parent_id = t.id
)
SELECT t.id AS org_unit_id, t.parent_id, t.code, t.name, ty.code AS org_unit_type,
       t.depth, t.path, t.id_path
FROM t JOIN ref.org_unit_type ty ON ty.id = t.org_unit_type_id;

-- Current holders of positions.
CREATE OR REPLACE VIEW org.v_current_appointment AS
SELECT a.id AS appointment_id, a.org_unit_id, pt.code AS position_code, a.employee_id, a.valid
FROM org.appointment a
JOIN org.position_type pt ON pt.id = a.position_type_id
WHERE a.valid @> current_date;

-- ================================================================ people =====
CREATE OR REPLACE VIEW people.v_person_display_name AS
SELECT p.id AS person_id,
       COALESCE(NULLIF(btrim(p.preferred_name), ''),
                concat_ws(' ', p.first_name, NULLIF(p.middle_name, ''), NULLIF(p.last_name, ''))) AS display_name
FROM people.person p;

CREATE OR REPLACE VIEW pii.v_person_age AS
SELECT pp.person_id,
       date_part('year', age(current_date, pp.date_of_birth))::int AS age_years,
       (pp.date_of_birth > (current_date - interval '18 years')::date) AS is_minor   -- DPDP §2(f) child
FROM pii.person_profile pp
WHERE pp.date_of_birth IS NOT NULL;

-- Active employees with their current primary assignment and derived school.
CREATE OR REPLACE VIEW people.v_employee_current AS
SELECT e.id AS employee_id, e.person_id, e.employee_code,
       ec.code AS employee_category, es.code AS employment_status,
       ea.org_unit_id  AS primary_org_unit_id,
       d.code          AS designation_code,
       jf.code         AS job_function_code,
       jr.code         AS job_role_code,
       org.nearest_of_type(ea.org_unit_id, 'SCHOOL')             AS school_org_unit_id,
       org.nearest_of_type(ea.org_unit_id, 'CENTRAL_DEPARTMENT') AS central_department_org_unit_id,
       rm.manager_employee_id AS reporting_manager_employee_id,
       vm.manager_employee_id AS reviewing_manager_employee_id
FROM people.employee e
JOIN ref.employment_status es ON es.id = e.employment_status_id AND es.is_current_member
JOIN ref.employee_category ec ON ec.id = e.employee_category_id
LEFT JOIN people.employee_assignment ea
       ON ea.employee_id = e.id AND ea.is_primary AND ea.valid @> current_date
LEFT JOIN people.designation d ON d.id = ea.designation_id
LEFT JOIN ref.job_function jf ON jf.id = ea.job_function_id
LEFT JOIN ref.job_role jr     ON jr.id = ea.job_role_id
LEFT JOIN people.employee_reporting_line rm
       ON rm.employee_id = e.id AND rm.valid @> current_date
      AND rm.reporting_line_type_id = ref.id_of('reporting_line_type', 'REPORTING')
LEFT JOIN people.employee_reporting_line vm
       ON vm.employee_id = e.id AND vm.valid @> current_date
      AND vm.reporting_line_type_id = ref.id_of('reporting_line_type', 'REVIEWING');

-- ============================================================== academic =====
-- Batch with its derived batch year and display label.
CREATE OR REPLACE VIEW academic.v_batch AS
SELECT b.id AS batch_id, b.program_id, p.code AS program_code, p.name AS program_name,
       b.admission_year_id, y.code AS admission_year_code,
       extract(year FROM lower(y.period))::int AS batch_year,
       p.code || ' ' || extract(year FROM lower(y.period))::int AS batch_label,
       b.intake_capacity, b.is_active
FROM academic.batch b
JOIN academic.program p       ON p.id = b.program_id
JOIN academic.academic_year y ON y.id = b.admission_year_id;

-- Programme with derived duration in years.
CREATE OR REPLACE VIEW academic.v_program AS
SELECT p.id AS program_id, p.code, p.name, pl.code AS program_level, ct.code AS calendar_type,
       p.duration_terms, round(p.duration_terms::numeric / ct.terms_per_year, 1) AS duration_years,
       p.offering_org_unit_id, org.nearest_of_type(p.offering_org_unit_id, 'SCHOOL') AS school_org_unit_id,
       dm.code AS delivery_mode, lg.code AS medium_language,
       p.min_credits, p.max_credits, p.is_active
FROM academic.program p
JOIN ref.program_level pl          ON pl.id = p.program_level_id
JOIN ref.academic_calendar_type ct ON ct.id = p.academic_calendar_type_id
JOIN ref.delivery_mode dm          ON dm.id = p.delivery_mode_id
LEFT JOIN ref.language lg          ON lg.id = p.medium_language_id;

-- Terms running today (e.g. "2026-27 ODD"), one per calendar type.
CREATE OR REPLACE VIEW academic.v_current_term AS
SELECT t.id AS academic_term_id, y.code AS academic_year_code, c.code AS term_cycle,
       ct.code AS calendar_type, t.period
FROM academic.academic_term t
JOIN academic.academic_year y      ON y.id = t.academic_year_id
JOIN ref.term_cycle c              ON c.id = t.term_cycle_id
JOIN ref.academic_calendar_type ct ON ct.id = c.academic_calendar_type_id
WHERE t.period @> current_date;

-- Which programme term (semester) an enrollment is in for a given academic
-- term. 1) The counted term registration for that term, if any. 2) Otherwise
-- from the latest earlier term registration: its term number (+1 if promoted,
-- the same again if detained) plus the terms of the calendar type since.
-- 3) With no registration at all: entry term − 1 + terms since enrollment.
-- Terms that fall entirely inside a break in study are never counted.
CREATE OR REPLACE FUNCTION academic.enrollment_term_no(p_enrollment uuid, p_term uuid)
RETURNS int LANGUAGE sql STABLE AS $$
  WITH e AS (
    SELECT e.id, e.entry_term_no, lower(e.valid) AS starts_on, p.academic_calendar_type_id AS cal
    FROM academic.student_enrollment e
    JOIN academic.batch b   ON b.id = e.batch_id
    JOIN academic.program p ON p.id = b.program_id
    WHERE e.id = p_enrollment),
  tgt AS (SELECT lower(period) AS starts_on FROM academic.academic_term WHERE id = p_term),
  anchor AS (
    SELECT tr.term_no, lower(t.period) AS starts_on, COALESCE(st.is_promoted, true) AS promoted
    FROM academic.term_registration tr
    JOIN academic.academic_term t              ON t.id = tr.academic_term_id
    JOIN ref.term_registration_status s        ON s.id = tr.term_registration_status_id AND s.is_counted
    LEFT JOIN ref.academic_standing st         ON st.id = tr.academic_standing_id
    WHERE tr.student_enrollment_id = p_enrollment AND lower(t.period) <= (SELECT starts_on FROM tgt)
    ORDER BY lower(t.period) DESC LIMIT 1)
  SELECT CASE WHEN a.starts_on = tgt.starts_on THEN a.term_no
         ELSE COALESCE(a.term_no - CASE WHEN a.promoted THEN 0 ELSE 1 END, e.entry_term_no - 1)
              + (SELECT count(*)::int FROM academic.academic_term t
                 JOIN ref.term_cycle c ON c.id = t.term_cycle_id
                 WHERE c.academic_calendar_type_id = e.cal
                   AND lower(t.period) <= tgt.starts_on
                   AND CASE WHEN a.starts_on IS NULL THEN upper(t.period) > e.starts_on ELSE lower(t.period) > a.starts_on END
                   AND NOT EXISTS (SELECT 1 FROM academic.study_break sb
                                   WHERE sb.student_enrollment_id = e.id AND sb.period @> t.period))
         END
  FROM e CROSS JOIN tgt LEFT JOIN anchor a ON true;
$$;

-- A student's current enrollment. current_term_no is academic.enrollment_term_no()
-- for the latest term of the programme's calendar type that has started: the
-- term registration where one exists, otherwise derived from dates (entry term,
-- terms since enrollment, minus terms spent on a break in study).
CREATE OR REPLACE VIEW academic.v_student_enrollment_current AS
SELECT e.student_id, e.id AS student_enrollment_id, e.batch_id, vb.batch_year, vb.batch_label,
       p.id AS program_id, p.code AS program_code, p.offering_org_unit_id,
       ss.specialization_id,
       e.entry_term_no,
       COALESCE((SELECT academic.enrollment_term_no(e.id, t.id)
                 FROM academic.academic_term t JOIN ref.term_cycle c ON c.id = t.term_cycle_id
                 WHERE c.academic_calendar_type_id = p.academic_calendar_type_id AND lower(t.period) <= current_date
                 ORDER BY lower(t.period) DESC LIMIT 1), e.entry_term_no - 1) AS current_term_no,
       p.duration_terms,
       EXISTS (SELECT 1 FROM academic.study_break sb WHERE sb.student_enrollment_id = e.id AND sb.period @> current_date) AS is_on_break
FROM academic.student_enrollment e
JOIN academic.v_batch vb    ON vb.batch_id = e.batch_id
JOIN academic.program p     ON p.id = vb.program_id
LEFT JOIN academic.student_specialization ss
       ON ss.student_enrollment_id = e.id AND ss.valid @> current_date
WHERE e.valid @> current_date;

-- Active students with programme, batch, derived home unit / school and mentor.
CREATE OR REPLACE VIEW people.v_student_current AS
SELECT s.id AS student_id, s.person_id, s.enrollment_no,
       en.program_id, en.batch_id, en.batch_year, en.current_term_no,
       en.offering_org_unit_id AS home_org_unit_id,
       org.nearest_of_type(en.offering_org_unit_id, 'SCHOOL') AS school_org_unit_id,
       sm.employee_id AS mentor_employee_id
FROM people.student s
JOIN ref.student_status ss ON ss.id = s.student_status_id AND ss.is_current_member
LEFT JOIN academic.v_student_enrollment_current en ON en.student_id = s.id
LEFT JOIN people.student_mentor sm ON sm.student_id = s.id AND sm.valid @> current_date;

-- What kinds of principal a person currently is (employee / student / guardian).
CREATE OR REPLACE VIEW people.v_person_principal_kind AS
SELECT ve.person_id, pk.id AS principal_kind_id, pk.code AS principal_kind,
       ve.primary_org_unit_id AS home_org_unit_id,
       (SELECT employee_category_id FROM people.employee WHERE id = ve.employee_id) AS employee_category_id
FROM people.v_employee_current ve JOIN ref.principal_kind pk ON pk.code = 'EMPLOYEE'
UNION ALL
SELECT vs.person_id, pk.id, pk.code, vs.home_org_unit_id, NULL
FROM people.v_student_current vs JOIN ref.principal_kind pk ON pk.code = 'STUDENT'
UNION ALL
SELECT DISTINCT r.related_person_id, pk.id, pk.code, NULL::uuid, NULL::smallint
FROM people.person_relationship r
JOIN people.v_student_current vs ON vs.person_id = r.person_id
JOIN ref.principal_kind pk ON pk.code = 'GUARDIAN'
WHERE r.is_guardian;

-- ================================================================== iam ======
-- Every identifier that can be typed into the login box.
CREATE OR REPLACE VIEW iam.v_login_identifier AS
SELECT a.username AS identifier, a.id AS account_id, 'USERNAME'::text AS identifier_kind
FROM iam.user_account a
UNION ALL
SELECT e.email, a.id, 'EMAIL'
FROM pii.person_email e
JOIN iam.user_account a ON a.person_id = e.person_id
WHERE e.is_login_enabled AND e.verified_at IS NOT NULL;

-- Resolve UID or email to an account (NULL if unknown).
CREATE OR REPLACE FUNCTION iam.resolve_login(p_identifier text)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT account_id FROM iam.v_login_identifier
  WHERE identifier = p_identifier::citext
  ORDER BY identifier_kind DESC      -- USERNAME before EMAIL
  LIMIT 1;
$$;

-- Django's last_login, derived from successful login events.
CREATE OR REPLACE VIEW iam.v_account_last_login AS
SELECT ae.account_id, max(ae.occurred_at) AS last_login
FROM iam.auth_event ae
JOIN ref.auth_event_type t ON t.id = ae.auth_event_type_id AND t.code = 'LOGIN_SUCCESS'
WHERE ae.account_id IS NOT NULL
GROUP BY ae.account_id;

CREATE OR REPLACE VIEW iam.v_account_active_lockout AS
SELECT l.account_id, l.id AS lockout_id, lower(l.period) AS locked_at, upper(l.period) AS locked_until
FROM iam.account_lockout l
WHERE l.released_at IS NULL AND l.period @> now();

-- ================================================================ authz ======
CREATE OR REPLACE VIEW authz.v_permission_code AS
SELECT p.id AS permission_id,
       (m.code || '.' || r.code || '.' || a.code)::citext AS code,
       m.code AS module_code, r.code AS resource_code, a.code AS action_code,
       p.is_scopable, p.description
FROM authz.permission p
JOIN authz.resource r   ON r.id = p.resource_id
JOIN authz.app_module m ON m.id = r.app_module_id
JOIN authz.action a     ON a.id = p.action_id;

-- role -> itself and every role it (transitively) inherits
CREATE OR REPLACE VIEW authz.v_role_closure AS
WITH RECURSIVE c AS (
  SELECT id AS role_id, id AS effective_role_id FROM authz.role WHERE is_active
  UNION
  SELECT c.role_id, ri.junior_role_id
  FROM c JOIN authz.role_inheritance ri ON ri.senior_role_id = c.effective_role_id
  JOIN authz.role jr ON jr.id = ri.junior_role_id AND jr.is_active
)
SELECT role_id, effective_role_id FROM c;

-- Roles an account holds RIGHT NOW, with the reason (source) and scope.
CREATE OR REPLACE VIEW authz.v_account_role_effective AS
-- 1. explicit grants
SELECT ar.account_id, ar.role_id, ar.scope_org_unit_id, ar.include_descendants,
       'EXPLICIT'::text AS source, ar.id AS source_id
FROM authz.account_role ar
JOIN authz.role r ON r.id = ar.role_id AND r.is_active
WHERE ar.valid @> now()
UNION ALL
-- 2. designation of an active assignment (primary or secondary)
SELECT a.id, dr.role_id,
       CASE WHEN dr.scope_to_assignment_unit THEN ea.org_unit_id END,
       dr.include_descendants, 'DESIGNATION', ea.id
FROM iam.user_account a
JOIN people.v_employee_current ve ON ve.person_id = a.person_id
JOIN people.employee_assignment ea ON ea.employee_id = ve.employee_id AND ea.valid @> current_date
JOIN authz.designation_role dr ON dr.designation_id = ea.designation_id
JOIN authz.role r ON r.id = dr.role_id AND r.is_active
UNION ALL
-- 3. current appointment to a position
SELECT a.id, pr.role_id, ap.org_unit_id, pr.include_descendants, 'POSITION', ap.id
FROM iam.user_account a
JOIN people.v_employee_current ve ON ve.person_id = a.person_id
JOIN org.appointment ap ON ap.employee_id = ve.employee_id AND ap.valid @> current_date
JOIN authz.position_role pr ON pr.position_type_id = ap.position_type_id
JOIN authz.role r ON r.id = pr.role_id AND r.is_active
UNION ALL
-- 4. baseline by principal kind (home-scoped rows are skipped when no home unit)
SELECT a.id, pkr.role_id,
       CASE WHEN pkr.scope_to_home_unit THEN k.home_org_unit_id END,
       true, 'PRINCIPAL_KIND', NULL::uuid
FROM iam.user_account a
JOIN people.v_person_principal_kind k ON k.person_id = a.person_id
JOIN authz.principal_kind_role pkr
  ON pkr.principal_kind_id = k.principal_kind_id
 AND (pkr.employee_category_id IS NULL OR pkr.employee_category_id = k.employee_category_id)
JOIN authz.role r ON r.id = pkr.role_id AND r.is_active
WHERE NOT pkr.scope_to_home_unit OR k.home_org_unit_id IS NOT NULL;

-- Permissions an account holds RIGHT NOW (role inheritance expanded).
CREATE OR REPLACE VIEW authz.v_account_permission_effective AS
SELECT er.account_id, rp.permission_id, pc.code AS permission_code,
       er.scope_org_unit_id, er.include_descendants, er.source, er.role_id AS via_role_id
FROM authz.v_account_role_effective er
JOIN authz.v_role_closure rc   ON rc.role_id = er.role_id
JOIN authz.role_permission rp  ON rp.role_id = rc.effective_role_id
JOIN authz.v_permission_code pc ON pc.permission_id = rp.permission_id
UNION ALL
SELECT ap.account_id, ap.permission_id, pc.code,
       ap.scope_org_unit_id, ap.include_descendants, 'DIRECT', NULL
FROM authz.account_permission ap
JOIN authz.v_permission_code pc ON pc.permission_id = ap.permission_id
WHERE ap.valid @> now();

-- has_permission(account, 'module.resource.action', target_unit)
--   target NULL  : "anywhere" — any grant counts (e.g. module access, menus)
--   target given : a global grant, a grant on the target, or a descendant-
--                  inclusive grant on one of the target's ancestors
--   non-scopable permissions only count when granted globally
--   superusers pass; accounts whose status cannot log in fail
CREATE OR REPLACE FUNCTION authz.has_permission(p_account uuid, p_code text, p_target uuid DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_superuser  boolean;
  v_can_login  boolean;
BEGIN
  SELECT a.is_superuser, s.can_login INTO v_superuser, v_can_login
  FROM iam.user_account a JOIN ref.account_status s ON s.id = a.account_status_id
  WHERE a.id = p_account;

  IF NOT FOUND OR NOT v_can_login THEN
    RETURN false;
  END IF;
  IF v_superuser THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM authz.v_account_permission_effective ep
    JOIN authz.v_permission_code pc ON pc.permission_id = ep.permission_id
    WHERE ep.account_id = p_account
      AND ep.permission_code = p_code::citext
      AND (pc.is_scopable OR ep.scope_org_unit_id IS NULL)
      AND (
            p_target IS NULL
         OR ep.scope_org_unit_id IS NULL
         OR ep.scope_org_unit_id = p_target
         OR (ep.include_descendants
             AND ep.scope_org_unit_id IN (SELECT org_unit_id FROM org.ancestors(p_target)))
      ));
END $$;

-- Units in which the account holds the permission (for list filtering).
CREATE OR REPLACE FUNCTION authz.accessible_org_units(p_account uuid, p_code text)
RETURNS SETOF uuid LANGUAGE sql STABLE AS $$
  WITH g AS (
    SELECT ep.scope_org_unit_id, ep.include_descendants
    FROM authz.v_account_permission_effective ep
    WHERE ep.account_id = p_account AND ep.permission_code = p_code::citext
  )
  SELECT u.id FROM org.org_unit u
  WHERE EXISTS (SELECT 1 FROM g WHERE g.scope_org_unit_id IS NULL)
     OR EXISTS (SELECT 1 FROM iam.user_account WHERE id = p_account AND is_superuser)
  UNION
  SELECT scope_org_unit_id FROM g WHERE scope_org_unit_id IS NOT NULL AND NOT include_descendants
  UNION
  SELECT d.org_unit_id FROM g CROSS JOIN LATERAL org.descendants(g.scope_org_unit_id) d
  WHERE g.scope_org_unit_id IS NOT NULL AND g.include_descendants;
$$;

-- MFA is mandatory for superusers and for anyone holding a requires_mfa role.
CREATE OR REPLACE FUNCTION authz.account_requires_mfa(p_account uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT is_superuser FROM iam.user_account WHERE id = p_account), false)
      OR EXISTS (
           SELECT 1 FROM authz.v_account_role_effective er
           JOIN authz.v_role_closure rc ON rc.role_id = er.role_id
           JOIN authz.role r ON r.id = rc.effective_role_id
           WHERE er.account_id = p_account AND r.requires_mfa);
$$;

-- ============================================================== privacy ======
CREATE OR REPLACE VIEW privacy.v_dpr_request_status AS
SELECT r.id AS request_id, r.person_id, rt.code AS request_type, r.submitted_at,
       r.submitted_at + make_interval(days => rt.response_days) AS due_by,
       st.code AS current_status,
       CASE WHEN st.is_terminal THEN le.occurred_at END AS closed_at,
       (NOT COALESCE(st.is_terminal, false)
        AND now() > r.submitted_at + make_interval(days => rt.response_days)) AS is_overdue
FROM privacy.data_principal_request r
JOIN ref.dpr_request_type rt ON rt.id = r.dpr_request_type_id
LEFT JOIN LATERAL (
  SELECT e.dpr_status_id, e.occurred_at FROM privacy.dpr_request_event e
  WHERE e.request_id = r.id ORDER BY e.occurred_at DESC, e.id DESC LIMIT 1
) le ON true
LEFT JOIN ref.dpr_status st ON st.id = le.dpr_status_id;

CREATE OR REPLACE VIEW privacy.v_active_consent AS
SELECT c.id AS consent_id, c.principal_person_id, pp.code AS purpose_code,
       c.notice_id, c.given_by_person_id, c.granted_at,
       (c.given_by_person_id <> c.principal_person_id) AS given_by_guardian,
       EXISTS (SELECT 1 FROM privacy.verifiable_parental_consent v WHERE v.consent_id = c.id) AS guardian_verified
FROM privacy.consent c
JOIN privacy.processing_purpose pp ON pp.id = c.purpose_id
WHERE c.withdrawn_at IS NULL;

-- Minors whose consent-based purposes lack verified guardian consent (§9 check).
CREATE OR REPLACE VIEW privacy.v_minor_consent_gap AS
SELECT ag.person_id, pp.code AS purpose_code
FROM pii.v_person_age ag
CROSS JOIN privacy.processing_purpose pp
JOIN ref.legal_basis lb ON lb.id = pp.legal_basis_id AND lb.requires_consent
WHERE ag.is_minor AND pp.is_active
  AND NOT EXISTS (
    SELECT 1 FROM privacy.v_active_consent c
    WHERE c.principal_person_id = ag.person_id AND c.purpose_code = pp.code
      AND c.given_by_guardian AND c.guardian_verified);


-- ================================================================ workflow ===
-- Completing actions that still count: an APPROVE / SIGN / system approval is
-- voided by a later RETURN_TO that sends the round back to its step or an
-- earlier one.
CREATE OR REPLACE VIEW wf.v_effective_action AS
SELECT a.id, a.instance_id, a.step_seq, a.actor_account_id, a.on_behalf_of_account_id, a.acted_at, t.code AS action_code, t.is_system
FROM wf.approval_action a
JOIN ref.wf_action_type t ON t.id = a.wf_action_type_id AND t.completes_step
WHERE NOT EXISTS (SELECT 1 FROM wf.approval_action r JOIN ref.wf_action_type rt ON rt.id = r.wf_action_type_id AND rt.returns_to_step
                  WHERE r.instance_id = a.instance_id AND r.return_to_seq <= a.step_seq AND r.id > a.id);

-- Where each step stands: its (unreleased) assignees, the approvals that
-- count, how many it needs, and whether it is done. A step needs
-- required_approvals; with none set it needs every assignee (one approval for
-- a pool step). A system approval (auto-approval, self-skip) completes it.
CREATE OR REPLACE VIEW wf.v_step_state AS
SELECT q.*,
       -- passed over: not decided itself, but a higher level of the round is (it approved out of turn)
       (NOT q.done AND COALESCE(bool_or(q.done) OVER (PARTITION BY q.instance_id ORDER BY q.seq DESC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), false)) AS superseded
FROM (
  SELECT st.instance_id, st.seq, st.code, st.is_signature, k.code AS approver_kind, st.permission_id, st.anchor_org_unit_id,
         x.assignees, x.approvals, x.system_done,
         COALESCE(st.required_approvals, NULLIF(x.assignees, 0), 1)::int AS required,
         (x.system_done OR x.approvals >= COALESCE(st.required_approvals, NULLIF(x.assignees, 0), 1)) AS done,
         st.is_mandatory
  FROM wf.approval_step st
  JOIN ref.wf_approver_kind k ON k.id = st.wf_approver_kind_id
  CROSS JOIN LATERAL (
    SELECT (SELECT count(*) FROM wf.approval_step_assignee sa
            WHERE sa.instance_id = st.instance_id AND sa.seq = st.seq AND sa.released_by_action_id IS NULL)::int AS assignees,
           (SELECT count(DISTINCT COALESCE(e.on_behalf_of_account_id, e.actor_account_id)) FROM wf.v_effective_action e
            WHERE e.instance_id = st.instance_id AND e.step_seq = st.seq AND NOT e.is_system)::int AS approvals,
           EXISTS (SELECT 1 FROM wf.v_effective_action e WHERE e.instance_id = st.instance_id AND e.step_seq = st.seq AND e.is_system) AS system_done) x) q;

-- The state of every approval round, derived from its steps and actions:
--   WITHDRAWN / RETURNED / REJECTED — closed by the submitter / sent back for
--                           revision (resubmit as a new round) / refused for good
--   SIGNED                — every step done and the chain has a signature step
--   APPROVED              — every review done (awaiting signature if the chain has one,
--                           else complete); also a round none of whose levels applied
--   IN_PROGRESS           — a step is pending
-- A level passed over by a higher level's approval (v_step_state.superseded)
-- counts as settled: it is no longer waited for.
-- current_seq / current_step / current permission + anchor = what is pending
-- (NULL when closed); current_since / current_due_at / is_overdue = its clock.
CREATE OR REPLACE VIEW wf.v_instance_state AS
WITH acts AS (
  SELECT a.instance_id,
         bool_or(t.code = 'WITHDRAW') AS withdrawn,
         bool_or(t.closes_instance AND t.is_rejection) AS rejected,
         bool_or(t.closes_instance AND NOT t.is_rejection AND t.code <> 'WITHDRAW') AS returned,
         max(a.acted_at) AS last_action_at,
         max(a.acted_at) FILTER (WHERE t.restarts_clock) AS clock_restarted_at
  FROM wf.approval_action a JOIN ref.wf_action_type t ON t.id = a.wf_action_type_id
  GROUP BY a.instance_id),
agg AS (
  SELECT instance_id,
         min(seq) FILTER (WHERE NOT done AND NOT superseded) AS pending_seq,
         COALESCE(bool_and(done OR superseded) FILTER (WHERE NOT is_signature), true) AS reviews_done,
         bool_or(is_signature) AS has_signature,
         bool_and(done OR superseded) AS all_done
  FROM wf.v_step_state GROUP BY instance_id),
st AS (
  SELECT i.id AS instance_id, i.document_type_id, i.owner_org_unit_id, i.submitted_by_account_id, i.submitted_at, i.amount,
         COALESCE(a.withdrawn, false) AS withdrawn, COALESCE(a.returned, false) AS returned, COALESCE(a.rejected, false) AS rejected,
         g.pending_seq, COALESCE(g.reviews_done, true) AS reviews_done, COALESCE(g.has_signature, false) AS has_signature,
         COALESCE(g.all_done, true) AS all_done, a.last_action_at, COALESCE(a.clock_restarted_at, i.submitted_at) AS current_since
  FROM wf.approval_instance i
  LEFT JOIN acts a ON a.instance_id = i.id
  LEFT JOIN agg g  ON g.instance_id = i.id)
SELECT st.instance_id, st.document_type_id, dt.code AS document_type, st.owner_org_unit_id,
       st.submitted_by_account_id, st.submitted_at, st.last_action_at,
       CASE WHEN st.withdrawn THEN 'WITHDRAWN'
            WHEN st.rejected  THEN 'REJECTED'
            WHEN st.returned  THEN 'RETURNED'
            WHEN st.all_done AND st.has_signature THEN 'SIGNED'
            WHEN st.reviews_done THEN 'APPROVED'
            ELSE 'IN_PROGRESS' END AS status,
       (st.all_done AND NOT st.withdrawn AND NOT st.returned AND NOT st.rejected) AS is_complete,
       CASE WHEN NOT st.withdrawn AND NOT st.returned AND NOT st.rejected THEN st.pending_seq END AS current_seq,
       cs.code AS current_step, cs.permission_id AS current_permission_id,
       cs.anchor_org_unit_id AS current_anchor_org_unit_id, cs.is_signature AS current_is_signature,
       st.amount,
       CASE WHEN cs.seq IS NOT NULL THEN st.current_since END AS current_since,
       CASE WHEN cs.seq IS NOT NULL THEN st.current_since + cs.due_within END AS current_due_at,
       COALESCE(cs.seq IS NOT NULL AND clock_timestamp() > st.current_since + cs.due_within, false) AS is_overdue
FROM st
JOIN wf.approval_document_type dt ON dt.id = st.document_type_id
LEFT JOIN wf.approval_step cs ON cs.instance_id = st.instance_id AND cs.seq = st.pending_seq
                             AND NOT st.withdrawn AND NOT st.returned AND NOT st.rejected;

-- The unit a step is currently anchored at: its own, or the one an escalation
-- moved it up to.
CREATE OR REPLACE FUNCTION wf.step_anchor(p_instance uuid, p_seq smallint)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (SELECT a.target_org_unit_id FROM wf.approval_action a
     WHERE a.instance_id = p_instance AND a.step_seq = p_seq AND a.target_org_unit_id IS NOT NULL ORDER BY a.id DESC LIMIT 1),
    (SELECT anchor_org_unit_id FROM wf.approval_step WHERE instance_id = p_instance AND seq = p_seq))
$$;

-- Is this account, in its own right, one of the people who decide this step?
--   a step with assignees: an unreleased assignee;
--   PERMISSION: holds the step's permission at its (current) anchor unit;
--   POSITION:   holds the position at the anchor unit today (and the step's
--               permission there, if it names one).
CREATE OR REPLACE FUNCTION wf.is_eligible(p_account uuid, p_instance uuid, p_seq smallint)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE v_step record; v_kind text; v_anchor uuid; v_perm text;
BEGIN
  SELECT * INTO v_step FROM wf.approval_step WHERE instance_id = p_instance AND seq = p_seq;
  IF NOT FOUND THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM iam.user_account a JOIN ref.account_status s ON s.id = a.account_status_id AND s.can_login WHERE a.id = p_account) THEN
    RETURN false;
  END IF;
  IF EXISTS (SELECT 1 FROM wf.approval_step_assignee WHERE instance_id = p_instance AND seq = p_seq) THEN
    RETURN EXISTS (SELECT 1 FROM wf.approval_step_assignee
                   WHERE instance_id = p_instance AND seq = p_seq AND account_id = p_account AND released_by_action_id IS NULL);
  END IF;
  SELECT code INTO v_kind FROM ref.wf_approver_kind WHERE id = v_step.wf_approver_kind_id;
  v_anchor := wf.step_anchor(p_instance, p_seq);
  SELECT code INTO v_perm FROM authz.v_permission_code WHERE permission_id = v_step.permission_id;
  IF v_kind = 'PERMISSION' THEN
    RETURN authz.has_permission(p_account, v_perm, v_anchor);
  ELSIF v_kind = 'POSITION' THEN
    RETURN EXISTS (SELECT 1 FROM org.appointment ap JOIN people.employee e ON e.id = ap.employee_id
                   JOIN iam.user_account ua ON ua.person_id = e.person_id
                   WHERE ua.id = p_account AND ap.org_unit_id = v_anchor AND ap.position_type_id = v_step.position_type_id
                     AND ap.valid @> current_date)
           AND (v_perm IS NULL OR authz.has_permission(p_account, v_perm, v_anchor));
  END IF;
  RETURN false;   -- MANAGER / NAMED / COMMITTEE without assignees: nobody
END $$;

-- Why a higher level (p_seq) may NOT be approved out of turn — NULL when it
-- may. It may when the chain allows it, the level is a pending review level
-- above the current one, no level in between insists on deciding itself, and
-- the round still ends with at least min_approved_levels levels approved by
-- people: those already approved below it, itself, and every level above it.
CREATE OR REPLACE FUNCTION wf.override_refusal(p_instance uuid, p_seq smallint)
RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE v_inst record; v_cur int; v_blocker text; v_levels int;
BEGIN
  SELECT allows_level_override, min_approved_levels INTO v_inst FROM wf.approval_instance WHERE id = p_instance;
  SELECT current_seq INTO v_cur FROM wf.v_instance_state WHERE instance_id = p_instance;
  IF NOT COALESCE(v_inst.allows_level_override, false) THEN
    RETURN 'this chain takes its levels strictly in order';
  END IF;
  IF v_cur IS NULL OR p_seq <= v_cur
     OR NOT EXISTS (SELECT 1 FROM wf.v_step_state s WHERE s.instance_id = p_instance AND s.seq = p_seq AND NOT s.done AND NOT s.is_signature) THEN
    RETURN 'that is not a pending review level above the current one';
  END IF;
  SELECT s.code::text INTO v_blocker FROM wf.v_step_state s
  WHERE s.instance_id = p_instance AND s.seq < p_seq AND NOT s.done AND NOT s.superseded AND s.is_mandatory ORDER BY s.seq LIMIT 1;
  IF v_blocker IS NOT NULL THEN
    RETURN format('level %s must decide itself and cannot be passed over', v_blocker);
  END IF;
  SELECT count(*) FILTER (WHERE s.seq < p_seq AND s.approvals >= s.required) + count(*) FILTER (WHERE s.seq >= p_seq) INTO v_levels
  FROM wf.v_step_state s WHERE s.instance_id = p_instance;
  IF v_levels < v_inst.min_approved_levels THEN
    RETURN format('passing over the lower level(s) would leave %s approved level(s); at least %s are required', v_levels, v_inst.min_approved_levels);
  END IF;
  RETURN NULL;
END $$;

-- The higher level this account could approve out of turn on a round that is
-- waiting at a lower level (NULL: none) — in its own right, never the
-- submitter, never someone who has already decided a level of the round.
CREATE OR REPLACE FUNCTION wf.override_step(p_account uuid, p_instance uuid)
RETURNS smallint LANGUAGE plpgsql STABLE AS $$
DECLARE v_state record; v_seq smallint;
BEGIN
  SELECT * INTO v_state FROM wf.v_instance_state WHERE instance_id = p_instance;
  IF v_state.current_seq IS NULL OR p_account = v_state.submitted_by_account_id
     OR EXISTS (SELECT 1 FROM wf.v_effective_action e WHERE e.instance_id = p_instance AND p_account IN (e.actor_account_id, e.on_behalf_of_account_id)) THEN
    RETURN NULL;
  END IF;
  FOR v_seq IN SELECT s.seq FROM wf.approval_step s WHERE s.instance_id = p_instance AND s.seq > v_state.current_seq ORDER BY s.seq LOOP
    IF wf.is_eligible(p_account, p_instance, v_seq) AND wf.override_refusal(p_instance, v_seq) IS NULL THEN
      RETURN v_seq;
    END IF;
  END LOOP;
  RETURN NULL;
END $$;

-- May this account act on the pending step of this round right now? In its
-- own right, or as the standing delegate of someone who could; never the
-- submitter; one step per person; one approval per person on a step.
CREATE OR REPLACE FUNCTION wf.can_act(p_account uuid, p_instance uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE((
    SELECT s.current_seq IS NOT NULL
       AND p_account <> s.submitted_by_account_id
       AND (wf.is_eligible(p_account, p_instance, s.current_seq::smallint)
            OR EXISTS (SELECT 1 FROM wf.approval_delegation d
                       WHERE d.delegate_account_id = p_account AND d.valid @> now()
                         AND (d.document_type_id IS NULL OR d.document_type_id = s.document_type_id)
                         AND d.delegator_account_id <> s.submitted_by_account_id
                         AND wf.is_eligible(d.delegator_account_id, p_instance, s.current_seq::smallint)))
       AND NOT EXISTS (SELECT 1 FROM wf.v_effective_action e
                       WHERE e.instance_id = p_instance AND p_account IN (e.actor_account_id, e.on_behalf_of_account_id))
    FROM wf.v_instance_state s
    WHERE s.instance_id = p_instance), false);
$$;

-- May this account see the round: its submitter, anyone who acted on it, was
-- assigned or consulted, can act on it now, could decide any of its steps, or
-- holds the document type's viewer permission at the owning unit.
CREATE OR REPLACE FUNCTION wf.can_view(p_account uuid, p_instance uuid)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE v record; v_perm text;
BEGIN
  SELECT i.submitted_by_account_id, i.owner_org_unit_id, dt.viewer_permission_id INTO v
  FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id WHERE i.id = p_instance;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v.submitted_by_account_id = p_account
     OR EXISTS (SELECT 1 FROM wf.approval_action a WHERE a.instance_id = p_instance AND p_account IN (a.actor_account_id, a.on_behalf_of_account_id, a.target_account_id))
     OR EXISTS (SELECT 1 FROM wf.approval_step_assignee sa WHERE sa.instance_id = p_instance AND sa.account_id = p_account)
     OR EXISTS (SELECT 1 FROM wf.approval_consultation c WHERE c.instance_id = p_instance AND p_account IN (c.asked_account_id, c.asked_by_account_id))
     OR wf.can_act(p_account, p_instance)
     OR EXISTS (SELECT 1 FROM wf.approval_step st WHERE st.instance_id = p_instance AND wf.is_eligible(p_account, p_instance, st.seq)) THEN
    RETURN true;
  END IF;
  SELECT code INTO v_perm FROM authz.v_permission_code WHERE permission_id = v.viewer_permission_id;
  RETURN v_perm IS NOT NULL AND authz.has_permission(p_account, v_perm, v.owner_org_unit_id);
END $$;

-- The document a round is about, from the document type's link registry.
CREATE OR REPLACE FUNCTION wf.document_of(p_instance uuid, OUT link_table text, OUT document_id uuid)
LANGUAGE plpgsql STABLE AS $$
DECLARE v_col text;
BEGIN
  SELECT dt.link_table, dt.link_document_column INTO link_table, v_col
  FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id WHERE i.id = p_instance;
  IF link_table IS NOT NULL THEN
    EXECUTE format('SELECT %I::uuid FROM %s WHERE instance_id = $1 LIMIT 1', v_col, link_table) INTO document_id USING p_instance;
  END IF;
END $$;

-- "Pending for me": every open round the account can act on now — HOD sees
-- their department's, a Dean their school's, a manager their reports', a
-- delegate the absent approver's — with its clock and the document it is about.
CREATE OR REPLACE FUNCTION wf.pending_for(p_account uuid)
RETURNS TABLE (instance_id uuid, document_type text, current_step text, submitted_at timestamptz,
               owner_org_unit_id uuid, amount numeric, current_due_at timestamptz, is_overdue boolean)
LANGUAGE sql STABLE AS $$
  SELECT s.instance_id, s.document_type::text, s.current_step::text, s.submitted_at, s.owner_org_unit_id, s.amount, s.current_due_at, s.is_overdue
  FROM wf.v_instance_state s
  WHERE s.current_seq IS NOT NULL AND wf.can_act(p_account, s.instance_id)
  ORDER BY s.is_overdue DESC, s.current_due_at NULLS LAST, s.submitted_at;
$$;

-- "Waiting below me": open rounds pending at a lower level that the account
-- could decide out of turn, with the level it would decide. Kept apart from
-- the inbox (wf.pending_for) so that a Dean's inbox is not filled with
-- everything waiting at the HODs.
CREATE OR REPLACE FUNCTION wf.overridable_for(p_account uuid)
RETURNS TABLE (instance_id uuid, document_type text, current_step text, override_step text, submitted_at timestamptz,
               owner_org_unit_id uuid, amount numeric, current_due_at timestamptz, is_overdue boolean)
LANGUAGE sql STABLE AS $$
  SELECT s.instance_id, s.document_type::text, s.current_step::text, st.code::text, s.submitted_at, s.owner_org_unit_id, s.amount, s.current_due_at, s.is_overdue
  FROM wf.v_instance_state s
  JOIN wf.approval_step st ON st.instance_id = s.instance_id AND st.seq = wf.override_step(p_account, s.instance_id)
  WHERE s.current_seq IS NOT NULL
  ORDER BY s.is_overdue DESC, s.current_due_at NULLS LAST, s.submitted_at;
$$;

-- The account of the manager N levels above a person on a reporting line.
CREATE OR REPLACE FUNCTION wf.manager_account(p_person uuid, p_line_type smallint, p_level int DEFAULT 1)
RETURNS uuid LANGUAGE plpgsql STABLE AS $$
DECLARE v_emp uuid; i int;
BEGIN
  SELECT id INTO v_emp FROM people.employee WHERE person_id = p_person;
  FOR i IN 1 .. p_level LOOP
    SELECT rl.manager_employee_id INTO v_emp FROM people.employee_reporting_line rl
    WHERE rl.employee_id = v_emp AND rl.reporting_line_type_id = p_line_type AND rl.valid @> current_date;
    IF v_emp IS NULL THEN RETURN NULL; END IF;
  END LOOP;
  RETURN (SELECT ua.id FROM people.employee e JOIN iam.user_account ua ON ua.person_id = e.person_id WHERE e.id = v_emp);
END $$;

-- Open an approval round. Checks the author's permission at the owning unit,
-- picks the most specific valid chain (a chain scoped to the nearest ancestor
-- wins over the default) and snapshots the levels that apply:
--   * a level with an amount band or a flag condition is kept only if the
--     round's amount / flags meet it;
--   * the anchor unit is resolved (nearest unit of the type above the owner;
--     the owner itself; the university root);
--   * MANAGER / NAMED / COMMITTEE levels get their assignees (the subject's
--     manager; the fixed account or the accounts named in p_assignees; the
--     current members of the body, quorum = required approvals);
--   * a level the submitter would decide is left out (self-action SKIP) or
--     kept for someone else to decide (BLOCK).
-- With no level left: approved at once if the document type allows an empty
-- chain, else refused. Returns the new instance.
CREATE OR REPLACE FUNCTION wf.submit(p_document_type text, p_owner_unit uuid, p_account uuid, p_note text DEFAULT NULL,
                                     p_amount numeric DEFAULT NULL, p_flags text[] DEFAULT NULL, p_subject_person uuid DEFAULT NULL,
                                     p_assignees uuid[] DEFAULT NULL, p_revises uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_type record; v_chain int; v_instance uuid; v_root uuid; v_stage record; v_anchor uuid; v_subject uuid;
        v_accounts uuid[]; v_required smallint; v_self boolean; v_steps int := 0; v_first smallint; v_acc uuid;
BEGIN
  SELECT dt.id, dt.allows_empty_chain, pc.code AS author_code INTO v_type
  FROM wf.approval_document_type dt JOIN authz.v_permission_code pc ON pc.permission_id = dt.author_permission_id
  WHERE dt.code = p_document_type AND dt.is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'wf.submit: unknown document type %', p_document_type USING ERRCODE = 'check_violation';
  END IF;
  IF NOT authz.has_permission(p_account, v_type.author_code, p_owner_unit) THEN
    RAISE EXCEPTION 'wf.submit: the account may not submit % for this unit (needs %)', p_document_type, v_type.author_code
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT c.id INTO v_chain
  FROM wf.approval_chain c
  LEFT JOIN org.ancestors(p_owner_unit) a ON a.org_unit_id = c.scope_org_unit_id
  WHERE c.document_type_id = v_type.id AND c.valid @> current_date
    AND (c.scope_org_unit_id IS NULL OR a.org_unit_id IS NOT NULL)
  ORDER BY a.depth NULLS LAST
  LIMIT 1;
  IF v_chain IS NULL OR (NOT v_type.allows_empty_chain AND NOT EXISTS (SELECT 1 FROM wf.approval_chain_stage WHERE chain_id = v_chain)) THEN
    RAISE EXCEPTION 'wf.submit: no approval chain is configured for %', p_document_type USING ERRCODE = 'check_violation';
  END IF;
  v_subject := COALESCE(p_subject_person, (SELECT person_id FROM iam.user_account WHERE id = p_account));

  INSERT INTO wf.approval_instance (document_type_id, chain_id, owner_org_unit_id, submitted_by_account_id, note, amount, subject_person_id, revises_instance_id,
                                    allows_level_override, min_approved_levels)
  SELECT v_type.id, v_chain, p_owner_unit, p_account, p_note, p_amount, v_subject, p_revises, c.allows_level_override, c.min_approved_levels
  FROM wf.approval_chain c WHERE c.id = v_chain
  RETURNING id INTO v_instance;
  INSERT INTO wf.approval_instance_flag (instance_id, wf_flag_id)
  SELECT DISTINCT v_instance, ref.id_of('wf_flag', f) FROM unnest(COALESCE(p_flags, '{}'::text[])) f;

  SELECT a.org_unit_id INTO v_root FROM org.ancestors(p_owner_unit) a ORDER BY a.depth DESC LIMIT 1;
  FOR v_stage IN
    SELECT cs.*, t.code AS unit_type, k.code AS kind, sa.code AS self_action, pc.code AS perm_code
    FROM wf.approval_chain_stage cs
    JOIN ref.wf_approver_kind k ON k.id = cs.wf_approver_kind_id
    JOIN ref.wf_self_action sa ON sa.id = cs.wf_self_action_id
    LEFT JOIN ref.org_unit_type t ON t.id = cs.anchor_org_unit_type_id
    LEFT JOIN authz.v_permission_code pc ON pc.permission_id = cs.permission_id
    WHERE cs.chain_id = v_chain ORDER BY cs.seq
  LOOP
    -- does the level apply to this round?
    CONTINUE WHEN v_stage.min_amount IS NOT NULL AND (p_amount IS NULL OR p_amount < v_stage.min_amount);
    CONTINUE WHEN v_stage.max_amount IS NOT NULL AND p_amount IS NOT NULL AND p_amount >= v_stage.max_amount;
    CONTINUE WHEN v_stage.wf_flag_id IS NOT NULL AND v_stage.flag_must_be_absent
                  = EXISTS (SELECT 1 FROM wf.approval_instance_flag f WHERE f.instance_id = v_instance AND f.wf_flag_id = v_stage.wf_flag_id);

    v_anchor := CASE WHEN v_stage.anchor_is_owner THEN p_owner_unit                      -- the owning unit itself (its head / custodian)
                     WHEN v_stage.unit_type IS NULL THEN v_root
                     ELSE org.nearest_of_type(p_owner_unit, v_stage.unit_type) END;
    IF v_anchor IS NULL THEN
      RAISE EXCEPTION 'wf.submit: stage % needs a % above the owning unit, and there is none', v_stage.code, v_stage.unit_type
        USING ERRCODE = 'check_violation';
    END IF;

    -- who decides it
    v_accounts := NULL; v_required := v_stage.required_approvals;
    IF v_stage.kind = 'MANAGER' THEN
      v_acc := wf.manager_account(v_subject, v_stage.reporting_line_type_id, v_stage.manager_level);
      IF v_acc IS NULL THEN
        RAISE EXCEPTION 'wf.submit: stage % needs the subject''s manager (level %), and there is none with an account', v_stage.code, v_stage.manager_level
          USING ERRCODE = 'check_violation';
      END IF;
      v_accounts := ARRAY[v_acc];
    ELSIF v_stage.kind = 'NAMED' THEN
      v_accounts := CASE WHEN v_stage.named_account_id IS NOT NULL THEN ARRAY[v_stage.named_account_id] ELSE p_assignees END;
      IF COALESCE(cardinality(v_accounts), 0) = 0 THEN
        RAISE EXCEPTION 'wf.submit: stage % needs the approver(s) to be named at submission', v_stage.code USING ERRCODE = 'check_violation';
      END IF;
      FOREACH v_acc IN ARRAY v_accounts LOOP
        IF NOT EXISTS (SELECT 1 FROM iam.user_account a JOIN ref.account_status s ON s.id = a.account_status_id AND s.can_login WHERE a.id = v_acc)
           OR (v_stage.perm_code IS NOT NULL AND NOT authz.has_permission(v_acc, v_stage.perm_code, v_anchor)) THEN
          RAISE EXCEPTION 'wf.submit: a person named for stage % may not approve it (needs an active account%)', v_stage.code,
            COALESCE(' holding ' || v_stage.perm_code, '') USING ERRCODE = 'insufficient_privilege';
        END IF;
      END LOOP;
    ELSIF v_stage.kind = 'COMMITTEE' THEN
      SELECT array_agg(DISTINCT ua.id), COALESCE(v_stage.required_approvals, max(b.quorum)) INTO v_accounts, v_required
      FROM academic.academic_body b
      JOIN academic.academic_body_member m ON m.academic_body_id = b.id AND m.valid @> current_date
      LEFT JOIN people.employee e ON e.id = m.employee_id
      JOIN iam.user_account ua ON ua.person_id = COALESCE(e.person_id, m.external_person_id)
      WHERE b.id = v_stage.academic_body_id;
      IF COALESCE(cardinality(v_accounts), 0) < COALESCE(v_required, 1) THEN
        RAISE EXCEPTION 'wf.submit: the committee of stage % has fewer members with accounts than its quorum', v_stage.code USING ERRCODE = 'check_violation';
      END IF;
    ELSE
      v_required := COALESCE(v_stage.required_approvals, 1);   -- PERMISSION / POSITION pools
    END IF;

    -- the submitter as approver
    IF v_accounts IS NOT NULL THEN
      v_self := p_account = ANY (v_accounts);
      IF v_self AND v_stage.self_action = 'SKIP' THEN
        v_accounts := array_remove(v_accounts, p_account);
        CONTINUE WHEN cardinality(v_accounts) = 0;
        IF v_stage.kind = 'COMMITTEE' THEN v_required := least(v_required, cardinality(v_accounts))::smallint; END IF;
      ELSIF v_self AND v_stage.kind <> 'COMMITTEE' AND v_required IS NULL THEN
        RAISE EXCEPTION 'wf.submit: the submitter is an approver of stage % (configure its self-action as SKIP, or name someone else)', v_stage.code
          USING ERRCODE = 'check_violation';
      ELSIF v_self THEN
        v_accounts := array_remove(v_accounts, p_account);      -- a committee member's own proposal: the others decide
        IF cardinality(v_accounts) < v_required THEN
          RAISE EXCEPTION 'wf.submit: without the submitter stage % cannot reach its required approvals', v_stage.code USING ERRCODE = 'check_violation';
        END IF;
      END IF;
    ELSIF v_stage.self_action = 'SKIP' THEN
      v_self := CASE v_stage.kind
                  WHEN 'PERMISSION' THEN authz.has_permission(p_account, v_stage.perm_code, v_anchor)
                  ELSE EXISTS (SELECT 1 FROM org.appointment ap JOIN people.employee e ON e.id = ap.employee_id
                               JOIN iam.user_account ua ON ua.person_id = e.person_id
                               WHERE ua.id = p_account AND ap.org_unit_id = v_anchor AND ap.position_type_id = v_stage.position_type_id
                                 AND ap.valid @> current_date) END;
      CONTINUE WHEN v_self;
    END IF;

    INSERT INTO wf.approval_step (instance_id, seq, code, wf_approver_kind_id, permission_id, anchor_org_unit_id, position_type_id,
                                  required_approvals, needs_file, allows_forward, allows_return_to, due_within, wf_timeout_action_id, is_signature,
                                  is_mandatory)
    VALUES (v_instance, v_stage.seq, v_stage.code, v_stage.wf_approver_kind_id, v_stage.permission_id, v_anchor, v_stage.position_type_id,
            v_required, v_stage.needs_file, v_stage.allows_forward, v_stage.allows_return_to, v_stage.due_within, v_stage.wf_timeout_action_id,
            v_stage.is_signature, v_stage.is_mandatory);
    IF v_accounts IS NOT NULL THEN
      INSERT INTO wf.approval_step_assignee (instance_id, seq, account_id) SELECT v_instance, v_stage.seq, a FROM unnest(v_accounts) a;
    END IF;
    v_steps := v_steps + 1;
    v_first := COALESCE(v_first, v_stage.seq);
  END LOOP;

  IF v_steps = 0 AND NOT v_type.allows_empty_chain THEN
    RAISE EXCEPTION 'wf.submit: no level of the % chain applies to this request', p_document_type USING ERRCODE = 'check_violation';
  ELSIF v_steps = 0 THEN
    INSERT INTO wf.approval_notice (instance_id, wf_notice_kind_id, account_id) VALUES (v_instance, ref.id_of('wf_notice_kind', 'APPROVED'), p_account);
  ELSE
    PERFORM wf.notify_step(v_instance, v_first, 'STEP_PENDING');
  END IF;
  RETURN v_instance;
END $$;

-- Act on a round by action code: works out the step — the current one; or,
-- for an approver of a higher level who is not an approver of the current one,
-- that higher level (an approval out of turn, where the chain allows it) —
-- and, when the account is not an approver in its own right but stands in for
-- one (wf.approval_delegation), records whom it acts for. Returns the action id.
CREATE OR REPLACE FUNCTION wf.act(p_instance uuid, p_action text, p_account uuid, p_note text DEFAULT NULL, p_file uuid DEFAULT NULL,
                                  p_target_account uuid DEFAULT NULL, p_return_to_seq int DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_state record; v_behalf uuid; v_id bigint; v_seq int;
BEGIN
  SELECT * INTO v_state FROM wf.v_instance_state WHERE instance_id = p_instance;
  v_seq := v_state.current_seq;
  IF upper(p_action) <> 'WITHDRAW' AND v_state.current_seq IS NOT NULL
     AND NOT wf.is_eligible(p_account, p_instance, v_state.current_seq::smallint) THEN
    SELECT d.delegator_account_id INTO v_behalf FROM wf.approval_delegation d
    WHERE d.delegate_account_id = p_account AND d.valid @> now()
      AND (d.document_type_id IS NULL OR d.document_type_id = v_state.document_type_id)
      AND wf.is_eligible(d.delegator_account_id, p_instance, v_state.current_seq::smallint)
    ORDER BY d.document_type_id NULLS LAST LIMIT 1;
    IF v_behalf IS NULL AND upper(p_action) = 'APPROVE' THEN
      v_seq := COALESCE(wf.override_step(p_account, p_instance), v_seq);
    END IF;
  END IF;
  INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, actor_account_id, note, file_object_id,
                                  target_account_id, return_to_seq, on_behalf_of_account_id)
  VALUES (p_instance, CASE WHEN upper(p_action) = 'WITHDRAW' THEN NULL ELSE v_seq END, ref.id_of('wf_action_type', upper(p_action)),
          p_account, p_note, p_file, p_target_account, p_return_to_seq, v_behalf)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Scheduled job (app.system_job = on): every open round whose current step is
-- past its deadline gets what its stage configured — a reminder (one a day),
-- an escalation (a pool step moves one org level up; a manager step goes to
-- the next manager; with nowhere to go, a reminder), an automatic approval,
-- or an automatic rejection.
CREATE OR REPLACE FUNCTION wf.run_timeouts()
RETURNS TABLE (reminded int, escalated int, auto_approved int, auto_rejected int) LANGUAGE plpgsql AS $$
DECLARE r record; v_parent uuid; v_next uuid; v_n int;
BEGIN
  IF current_setting('app.system_job', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'wf.run_timeouts: runs as a system job only' USING ERRCODE = 'insufficient_privilege';
  END IF;
  reminded := 0; escalated := 0; auto_approved := 0; auto_rejected := 0;
  FOR r IN
    SELECT s.instance_id, s.current_seq::smallint AS seq, ta.code AS timeout_action, k.code AS kind, i.subject_person_id, i.chain_id, st.code AS step_code
    FROM wf.v_instance_state s
    JOIN wf.approval_instance i ON i.id = s.instance_id
    JOIN wf.approval_step st ON st.instance_id = s.instance_id AND st.seq = s.current_seq
    JOIN ref.wf_timeout_action ta ON ta.id = st.wf_timeout_action_id
    JOIN ref.wf_approver_kind k ON k.id = st.wf_approver_kind_id
    WHERE s.is_overdue AND ta.code <> 'NONE'
  LOOP
    IF r.timeout_action = 'AUTO_APPROVE' THEN
      INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, note)
      VALUES (r.instance_id, r.seq, ref.id_of('wf_action_type', 'AUTO_APPROVE'), 'No decision within the deadline');
      auto_approved := auto_approved + 1; CONTINUE;
    ELSIF r.timeout_action = 'AUTO_REJECT' THEN
      INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, note)
      VALUES (r.instance_id, r.seq, ref.id_of('wf_action_type', 'AUTO_REJECT'), 'No decision within the deadline');
      auto_rejected := auto_rejected + 1; CONTINUE;
    ELSIF r.timeout_action = 'ESCALATE' THEN
      v_parent := NULL; v_next := NULL;
      IF r.kind = 'MANAGER' THEN
        SELECT wf.manager_account((SELECT person_id FROM iam.user_account WHERE id = sa.account_id),
                                  COALESCE((SELECT cs.reporting_line_type_id FROM wf.approval_chain_stage cs      -- the line the level is configured on
                                            WHERE cs.chain_id = r.chain_id AND cs.code = r.step_code LIMIT 1),
                                           ref.id_of('reporting_line_type', 'REPORTING'))::smallint, 1) INTO v_next
        FROM wf.approval_step_assignee sa WHERE sa.instance_id = r.instance_id AND sa.seq = r.seq AND sa.released_by_action_id IS NULL LIMIT 1;
      ELSE
        SELECT parent_id INTO v_parent FROM org.org_unit WHERE id = wf.step_anchor(r.instance_id, r.seq);
      END IF;
      IF v_parent IS NOT NULL OR (v_next IS NOT NULL AND v_next <> (SELECT submitted_by_account_id FROM wf.approval_instance WHERE id = r.instance_id)) THEN
        INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, note, target_org_unit_id, target_account_id)
        VALUES (r.instance_id, r.seq, ref.id_of('wf_action_type', 'ESCALATE'), 'No decision within the deadline', v_parent, v_next);
        escalated := escalated + 1; CONTINUE;
      END IF;
    END IF;
    PERFORM wf.notify_step(r.instance_id, r.seq, 'REMINDER');
    reminded := reminded + 1;
  END LOOP;
  RETURN NEXT;
END $$;

-- ================================================ curriculum approval (SOE) ==
-- Is this account's person the current coordinator of the programme?
-- (row-level ownership, the same idea as a faculty member's own classes)
CREATE OR REPLACE FUNCTION academic.is_program_coordinator(p_account uuid, p_program uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM iam.user_account a
    JOIN people.employee e              ON e.person_id = a.person_id
    JOIN academic.program_coordinator pc ON pc.employee_id = e.id AND pc.valid @> current_date
    WHERE a.id = p_account AND pc.program_id = p_program);
$$;

-- Status of each curriculum version from its latest approval round:
-- DRAFT (never submitted) / IN_REVIEW / RETURNED / WITHDRAWN / APPROVED
-- (awaiting signature) / SIGNED.
CREATE OR REPLACE VIEW academic.v_curriculum_status AS
SELECT c.id AS curriculum_id, c.program_id, lr.instance_id,
       CASE WHEN lr.instance_id IS NULL THEN 'DRAFT'
            WHEN s.status = 'IN_PROGRESS' THEN 'IN_REVIEW'
            ELSE s.status END AS status,
       s.current_step, s.submitted_at,
       (SELECT max(a.acted_at) FROM wf.approval_action a JOIN ref.wf_action_type t ON t.id = a.wf_action_type_id AND t.code = 'SIGN'
        WHERE a.instance_id = lr.instance_id) AS signed_at,
       (SELECT a.actor_account_id FROM wf.approval_action a JOIN ref.wf_action_type t ON t.id = a.wf_action_type_id AND t.code = 'SIGN'
        WHERE a.instance_id = lr.instance_id ORDER BY a.acted_at DESC LIMIT 1) AS signed_by_account_id,
       (SELECT count(*) FROM academic.curriculum_approval ca WHERE ca.curriculum_id = c.id) AS rounds
FROM academic.curriculum c
LEFT JOIN LATERAL (
  SELECT ca.instance_id FROM academic.curriculum_approval ca JOIN wf.approval_instance i ON i.id = ca.instance_id
  WHERE ca.curriculum_id = c.id ORDER BY i.submitted_at DESC LIMIT 1) lr ON true
LEFT JOIN wf.v_instance_state s ON s.instance_id = lr.instance_id;

-- Send a curriculum version (the SOE) for approval. The submitter must be the
-- programme's current coordinator or hold academics.curriculum.update at the
-- programme's department; wf.submit then checks academics.curriculum.submit.
CREATE OR REPLACE FUNCTION academic.submit_curriculum(p_curriculum uuid, p_account uuid, p_note text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_program uuid; v_unit uuid; v_status text; v_instance uuid;
BEGIN
  SELECT c.program_id, p.offering_org_unit_id INTO v_program, v_unit
  FROM academic.curriculum c JOIN academic.program p ON p.id = c.program_id WHERE c.id = p_curriculum;
  SELECT status INTO v_status FROM academic.v_curriculum_status WHERE curriculum_id = p_curriculum;
  IF v_status IN ('IN_REVIEW', 'APPROVED', 'SIGNED') THEN
    RAISE EXCEPTION 'submit_curriculum: the curriculum is already %', v_status USING ERRCODE = 'check_violation';
  END IF;
  IF NOT academic.is_program_coordinator(p_account, v_program)
     AND NOT authz.has_permission(p_account, 'academics.curriculum.update', v_unit) THEN
    RAISE EXCEPTION 'submit_curriculum: only the programme coordinator or a curriculum administrator may submit it'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  v_instance := wf.submit('CURRICULUM', v_unit, p_account, p_note);
  INSERT INTO academic.curriculum_approval (instance_id, curriculum_id) VALUES (v_instance, p_curriculum);
  RETURN v_instance;
END $$;

-- Request a revision of a published internal mark (see exam.internal_mark_revision).
CREATE OR REPLACE FUNCTION exam.request_internal_mark_revision(p_component_mark uuid, p_revised numeric, p_reason text,
                                                               p_employee uuid, p_account uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_unit uuid; v_instance uuid; v_id uuid;
BEGIN
  SELECT o.offering_org_unit_id INTO v_unit
  FROM exam.component_mark cm
  JOIN academic.course_registration r ON r.id = cm.course_registration_id
  JOIN academic.course_offering o     ON o.id = r.course_offering_id
  WHERE cm.id = p_component_mark;
  v_instance := wf.submit('INTERNAL_MARKS_REVISION', v_unit, p_account, p_reason);
  INSERT INTO exam.internal_mark_revision (component_mark_id, revised_marks, reason, requested_by_employee_id, instance_id)
  VALUES (p_component_mark, p_revised, p_reason, p_employee, v_instance) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- ======================================================= academic delivery ====
-- Every course of a curriculum (fixed or in an elective basket) with its term,
-- category and evaluation scheme.
CREATE OR REPLACE VIEW academic.v_curriculum_item AS
SELECT cc.curriculum_id, cc.term_no, cc.course_id, cc.course_category_id, cc.evaluation_scheme_id,
       cc.specialization_id, NULL::uuid AS elective_basket_id, cc.pathway_id, cc.result_group_id
FROM academic.curriculum_course cc
UNION ALL
SELECT b.curriculum_id, b.term_no, bc.course_id, b.course_category_id, bc.evaluation_scheme_id,
       b.specialization_id, b.id, b.pathway_id, NULL::uuid
FROM academic.elective_basket b JOIN academic.elective_basket_course bc ON bc.elective_basket_id = b.id;

-- A registration's scheme of examination, category and curriculum term —
-- derived, never copied onto the registration. In order of precedence:
--   1. the course is in the student's curriculum (fixed or elective basket);
--   2. it is an approved equivalent of a curriculum course — assessed under the
--      student's OWN regulation (counts_as_course_id = the curriculum course);
--   3. it is a course of a minor / honours track the student is on (track_id).
-- curriculum_id is always the student's curriculum (its grade scale applies).
CREATE OR REPLACE VIEW academic.v_registration_scheme AS
WITH reg AS (
  SELECT r.id AS course_registration_id, r.student_enrollment_id, o.course_id, o.academic_term_id, bc.curriculum_id,
         academic.enrollment_pathway(r.student_enrollment_id, t.period) AS pathway_id
  FROM academic.course_registration r
  JOIN academic.course_offering o    ON o.id = r.course_offering_id
  JOIN academic.academic_term t      ON t.id = o.academic_term_id
  JOIN academic.student_enrollment e ON e.id = r.student_enrollment_id
  JOIN academic.batch_curriculum bc  ON bc.batch_id = e.batch_id),
candidate AS (
  SELECT reg.*, 1 AS priority, ci.term_no, ci.course_category_id, ci.evaluation_scheme_id, ci.elective_basket_id,
         NULL::uuid AS track_id, NULL::uuid AS counts_as_course_id
  FROM reg JOIN academic.v_curriculum_item ci ON ci.curriculum_id = reg.curriculum_id AND ci.course_id = reg.course_id
                                            AND (ci.pathway_id IS NULL OR ci.pathway_id = reg.pathway_id)
  UNION ALL
  SELECT reg.*, 2, ci.term_no, ci.course_category_id, ci.evaluation_scheme_id, ci.elective_basket_id,
         NULL::uuid, ci.course_id
  FROM reg
  JOIN academic.course_equivalence ce ON ce.equivalent_course_id = reg.course_id
  JOIN academic.v_curriculum_item ci  ON ci.curriculum_id = reg.curriculum_id AND ci.course_id = ce.course_id
                                     AND (ci.pathway_id IS NULL OR ci.pathway_id = reg.pathway_id)
  UNION ALL
  SELECT reg.*, 3, NULL::smallint, tc.course_category_id, tc.evaluation_scheme_id, NULL::uuid,
         st.track_id, NULL::uuid
  FROM reg
  JOIN academic.academic_term t   ON t.id = reg.academic_term_id
  JOIN academic.student_track st  ON st.student_enrollment_id = reg.student_enrollment_id AND st.valid && t.period
  JOIN academic.track_course tc   ON tc.track_id = st.track_id AND tc.course_id = reg.course_id)
SELECT DISTINCT ON (course_registration_id)
       course_registration_id, student_enrollment_id, course_id, academic_term_id, curriculum_id,
       term_no, course_category_id, evaluation_scheme_id, elective_basket_id, track_id, counts_as_course_id
FROM candidate
ORDER BY course_registration_id, priority, counts_as_course_id, track_id;

-- Every enrollment with itself and every earlier enrollment it resumed
-- through re-entry (multiple entry / exit): credits and completed courses of
-- the ancestors count for the descendant.
CREATE OR REPLACE VIEW academic.v_enrollment_lineage AS
WITH RECURSIVE lineage AS (
  SELECT e.id AS student_enrollment_id, e.id AS ancestor_enrollment_id, 0 AS depth
  FROM academic.student_enrollment e
  UNION ALL
  SELECT l.student_enrollment_id, lk.parent_enrollment_id, l.depth + 1
  FROM lineage l
  JOIN (SELECT re.student_enrollment_id AS child_enrollment_id, sa.student_enrollment_id AS parent_enrollment_id
        FROM academic.enrollment_reentry re JOIN academic.student_award sa ON sa.id = re.student_award_id
        UNION ALL
        SELECT pt.to_enrollment_id, pt.from_enrollment_id FROM academic.program_transfer pt) lk
    ON lk.child_enrollment_id = l.ancestor_enrollment_id)
SELECT student_enrollment_id, ancestor_enrollment_id, depth FROM lineage;

CREATE OR REPLACE FUNCTION academic.registration_scheme_id(p_course_registration uuid)
RETURNS int LANGUAGE sql STABLE AS $$
  SELECT evaluation_scheme_id FROM academic.v_registration_scheme WHERE course_registration_id = p_course_registration;
$$;

-- The roster of every teaching assignment: which registered students the
-- class is for. A combined class (no section, no group) = every counted
-- registration of the offering; a section class = registered students of
-- that section; a class-group class = the group's members. Used by the
-- timetable clash trigger, attendance validation and every view below.
CREATE OR REPLACE VIEW academic.v_assignment_student AS
SELECT ta.id AS teaching_assignment_id, r.id AS course_registration_id, r.student_enrollment_id
FROM academic.teaching_assignment ta
JOIN academic.course_registration r  ON r.course_offering_id = ta.course_offering_id
JOIN ref.registration_status rs      ON rs.id = r.registration_status_id AND rs.is_counted
WHERE (ta.section_id IS NULL AND ta.class_group_id IS NULL)
   OR (ta.section_id IS NOT NULL AND EXISTS (
         SELECT 1 FROM academic.section_student ss
         WHERE ss.section_id = ta.section_id AND ss.student_enrollment_id = r.student_enrollment_id))
   OR (ta.class_group_id IS NOT NULL AND EXISTS (
         SELECT 1 FROM academic.class_group_member m
         WHERE m.class_group_id = ta.class_group_id AND m.course_registration_id = r.id));

-- A class session with its effective time, room and teacher resolved from the
-- timetable entry or the extra-class fields (whichever shape it has).
CREATE OR REPLACE VIEW academic.v_class_session AS
SELECT cs.id AS class_session_id, cs.session_date,
       ta.id AS teaching_assignment_id, ta.course_offering_id, ta.section_id, ta.class_group_id, ta.delivery_component_id,
       COALESCE(cs.start_time, s.start_time) AS start_time,
       COALESCE(cs.end_time,   s.end_time)   AS end_time,
       COALESCE(cs.room_id,    te.room_id)   AS room_id,
       COALESCE(cs.substitute_employee_id, ta.employee_id) AS taught_by_employee_id,
       (cs.substitute_employee_id IS NOT NULL) AS is_substituted,
       st.code AS status, st.counts_as_held
FROM academic.class_session cs
LEFT JOIN academic.timetable_entry te ON te.id = cs.timetable_entry_id
LEFT JOIN academic.time_slot s        ON s.id = te.time_slot_id
JOIN academic.teaching_assignment ta  ON ta.id = COALESCE(cs.teaching_assignment_id, te.teaching_assignment_id)
JOIN ref.class_session_status st      ON st.id = cs.class_session_status_id;

-- Attendance per registration: held sessions of classes the student belongs
-- to (their section, their lab batch / elective group, or a combined class)
-- and sessions attended. An unmarked held session counts as absent. On a day
-- covered by an APPROVED leave (academic.attendance_leave) a session the
-- student was not marked present in counts as the leave type says (duty leave
-- = present); the marks themselves are untouched.
CREATE OR REPLACE VIEW academic.v_attendance_summary AS
SELECT r.id AS course_registration_id,
       count(DISTINCT vs.class_session_id) AS sessions_held,
       count(DISTINCT vs.class_session_id) FILTER (WHERE ast.counts_as_present) AS sessions_attended,
       round(100.0 * count(DISTINCT vs.class_session_id) FILTER (WHERE ast.counts_as_present)
             / NULLIF(count(DISTINCT vs.class_session_id), 0), 2) AS attendance_pct,
       count(DISTINCT vs.class_session_id) FILTER (WHERE lv.attendance_status_id IS NOT NULL
                                                   AND NOT COALESCE(ast_m.counts_as_present, false)) AS sessions_on_leave
FROM academic.course_registration r
LEFT JOIN academic.v_assignment_student asg ON asg.course_registration_id = r.id
LEFT JOIN academic.v_class_session vs
       ON vs.teaching_assignment_id = asg.teaching_assignment_id AND vs.counts_as_held
LEFT JOIN academic.attendance a      ON a.class_session_id = vs.class_session_id AND a.course_registration_id = r.id
LEFT JOIN ref.attendance_status ast_m ON ast_m.id = a.attendance_status_id
LEFT JOIN LATERAL (SELECT lt.attendance_status_id
                   FROM academic.attendance_leave al
                   JOIN ref.leave_type lt ON lt.id = al.leave_type_id
                   JOIN wf.v_instance_state ws ON ws.instance_id = al.instance_id AND ws.is_complete
                   WHERE al.student_enrollment_id = r.student_enrollment_id AND al.period @> vs.session_date
                   LIMIT 1) lv ON true
LEFT JOIN ref.attendance_status ast  ON ast.id = CASE WHEN ast_m.counts_as_present THEN a.attendance_status_id
                                                      ELSE COALESCE(lv.attendance_status_id, a.attendance_status_id) END
GROUP BY r.id;

-- A student's weekly timetable (what the student portal shows).
CREATE OR REPLACE VIEW academic.v_student_timetable AS
SELECT asg.student_enrollment_id, asg.course_registration_id, o.course_id, s.day_of_week, s.start_time, s.end_time,
       te.room_id, ta.employee_id, ta.delivery_component_id, ta.section_id, ta.class_group_id, te.valid,
       te.repeat_every_weeks
FROM academic.v_assignment_student asg
JOIN academic.teaching_assignment ta  ON ta.id = asg.teaching_assignment_id
JOIN academic.course_offering o       ON o.id = ta.course_offering_id
JOIN academic.timetable_entry te      ON te.teaching_assignment_id = ta.id
JOIN academic.time_slot s             ON s.id = te.time_slot_id;

-- Students whose registered courses overlap in the weekly timetable — mainly
-- combined/elective classes, which the per-section trigger cannot see.
CREATE OR REPLACE VIEW academic.v_student_timetable_clash AS
SELECT a.student_enrollment_id, a.course_registration_id AS registration_a, b.course_registration_id AS registration_b,
       a.day_of_week, greatest(a.start_time, b.start_time) AS overlap_start, least(a.end_time, b.end_time) AS overlap_end
FROM academic.v_student_timetable a
JOIN academic.v_student_timetable b
  ON b.student_enrollment_id = a.student_enrollment_id AND b.course_registration_id > a.course_registration_id
 AND b.day_of_week = a.day_of_week AND b.start_time < a.end_time AND a.start_time < b.end_time AND b.valid && a.valid
 AND academic.week_patterns_meet(lower(a.valid), a.repeat_every_weeks, lower(b.valid), b.repeat_every_weeks);

-- SECTION-WISE TEACHING: for every section and every course its students are
-- registered for, who teaches each component and how — to the whole section
-- (SECTION), to one of its lab batches or to an elective group its students
-- are in (CLASS_GROUP), or in a combined class (COMBINED). The HOD's
-- "section x course x faculty" load sheet.
CREATE OR REPLACE VIEW academic.v_section_teaching AS
WITH section_offering AS (
  SELECT DISTINCT ss.section_id, r.course_offering_id
  FROM academic.section_student ss
  JOIN academic.section sec             ON sec.id = ss.section_id
  JOIN academic.course_registration r   ON r.student_enrollment_id = ss.student_enrollment_id
  JOIN academic.course_offering o       ON o.id = r.course_offering_id AND o.academic_term_id = sec.academic_term_id
  JOIN ref.registration_status rs       ON rs.id = r.registration_status_id AND rs.is_counted
)
SELECT so.section_id, so.course_offering_id, ta.delivery_component_id,
       CASE WHEN ta.section_id IS NOT NULL THEN 'SECTION'
            WHEN ta.class_group_id IS NOT NULL THEN 'CLASS_GROUP'
            ELSE 'COMBINED' END AS taught_as,
       g.code AS class_group_code, ta.id AS teaching_assignment_id, ta.employee_id, ta.is_primary, ta.valid
FROM section_offering so
JOIN academic.teaching_assignment ta ON ta.course_offering_id = so.course_offering_id
LEFT JOIN academic.class_group g     ON g.id = ta.class_group_id
WHERE ta.section_id = so.section_id
   OR g.parent_section_id = so.section_id
   OR (ta.section_id IS NULL AND ta.class_group_id IS NULL)
   OR (g.id IS NOT NULL AND g.parent_section_id IS NULL AND EXISTS (
         SELECT 1 FROM academic.class_group_member m
         JOIN academic.course_registration r ON r.id = m.course_registration_id
         JOIN academic.section_student ss    ON ss.student_enrollment_id = r.student_enrollment_id
         WHERE m.class_group_id = g.id AND ss.section_id = so.section_id));

-- TEACHING GAPS: every counted registration x every component the course has
-- hours for, where NO primary teacher reaches that student (no section,
-- batch, group or combined assignment covers them). Empty = every student
-- has a teacher for every lecture/lab/tutorial. section_id is the student's
-- section in the offering's term (NULL if not yet sectioned).
CREATE OR REPLACE VIEW academic.v_teaching_gap AS
SELECT r.id AS course_registration_id, r.student_enrollment_id, r.course_offering_id, o.academic_term_id,
       h.delivery_component_id, ss.section_id
FROM academic.course_registration r
JOIN ref.registration_status rs        ON rs.id = r.registration_status_id AND rs.is_counted
JOIN academic.course_offering o        ON o.id = r.course_offering_id
JOIN academic.course_component_hours h ON h.course_id = o.course_id
LEFT JOIN (academic.section_student ss JOIN academic.section sec ON sec.id = ss.section_id)
       ON ss.student_enrollment_id = r.student_enrollment_id AND sec.academic_term_id = o.academic_term_id
WHERE NOT EXISTS (
  SELECT 1 FROM academic.v_assignment_student a
  JOIN academic.teaching_assignment ta ON ta.id = a.teaching_assignment_id
  WHERE a.course_registration_id = r.id AND ta.delivery_component_id = h.delivery_component_id AND ta.is_primary);

-- ============================================ term set-up (bulk operations) ==
-- Which term of the programme (1, 2, 3 …) a given academic term is for an
-- enrollment: entry term + the programme-calendar terms elapsed since joining.

-- SECTION ALLOCATION: place every student of a batch who is enrolled during
-- the term and has no section yet into the batch's sections for that term,
-- in enrollment-number order, filling section A, then B … up to capacity.
-- All or nothing: if the sections cannot hold everyone, nothing is allocated.
-- Returns the number of students placed. (Moving an individual student later
-- is an ordinary UPDATE/INSERT, still checked by the section_student trigger.)
CREATE OR REPLACE FUNCTION academic.allocate_sections(p_batch uuid, p_term uuid)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_count int := 0; v_enrollment uuid; v_section uuid; v_left int;
BEGIN
  FOR v_enrollment IN
    SELECT e.id
    FROM academic.student_enrollment e
    JOIN people.student st        ON st.id = e.student_id
    JOIN academic.academic_term t ON t.id = p_term
    WHERE e.batch_id = p_batch AND e.valid && t.period
      AND NOT EXISTS (SELECT 1 FROM academic.section_student ss JOIN academic.section sec ON sec.id = ss.section_id
                      WHERE ss.student_enrollment_id = e.id AND sec.academic_term_id = p_term)
    ORDER BY st.enrollment_no
  LOOP
    SELECT sec.id INTO v_section
    FROM academic.section sec
    WHERE sec.batch_id = p_batch AND sec.academic_term_id = p_term
      AND (SELECT count(*) FROM academic.section_student ss WHERE ss.section_id = sec.id) < sec.capacity
    ORDER BY sec.code
    LIMIT 1;
    IF v_section IS NULL THEN
      SELECT count(*) INTO v_left
      FROM academic.student_enrollment e JOIN academic.academic_term t ON t.id = p_term
      WHERE e.batch_id = p_batch AND e.valid && t.period
        AND NOT EXISTS (SELECT 1 FROM academic.section_student ss JOIN academic.section sec ON sec.id = ss.section_id
                        WHERE ss.student_enrollment_id = e.id AND sec.academic_term_id = p_term);
      RAISE EXCEPTION 'allocate_sections: sections are full — % student(s) still without a section; add a section or raise capacity', v_left
        USING ERRCODE = 'check_violation';
    END IF;
    INSERT INTO academic.section_student (section_id, student_enrollment_id) VALUES (v_section, v_enrollment);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END $$;

-- CORE COURSE REGISTRATION: register every student of a batch enrolled
-- during the term for the FIXED courses of their curriculum for their own
-- term number (and their specialization's fixed courses), wherever an
-- offering exists that term. Electives, minor/honours courses and equivalents
-- are registered by choice. Safe to re-run (already-registered rows are
-- skipped); every row still passes the registration trigger. Returns the
-- number of new registrations.
CREATE OR REPLACE FUNCTION academic.register_core_courses(p_batch uuid, p_term uuid)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_count int;
BEGIN
  INSERT INTO academic.course_registration (student_enrollment_id, course_offering_id, registration_status_id)
  SELECT e.id, o.id, ref.id_of('registration_status', 'REGISTERED')
  FROM academic.student_enrollment e
  JOIN academic.academic_term t        ON t.id = p_term
  JOIN academic.batch_curriculum bc    ON bc.batch_id = e.batch_id
  JOIN academic.curriculum_course cc   ON cc.curriculum_id = bc.curriculum_id
                                      AND cc.term_no = academic.enrollment_term_no(e.id, p_term)
  JOIN academic.course_offering o      ON o.course_id = cc.course_id AND o.academic_term_id = p_term
  WHERE e.batch_id = p_batch AND e.valid && t.period
    AND (cc.specialization_id IS NULL OR EXISTS (
          SELECT 1 FROM academic.student_specialization ss
          WHERE ss.student_enrollment_id = e.id AND ss.specialization_id = cc.specialization_id AND ss.valid && t.period))
    AND (cc.pathway_id IS NULL OR cc.pathway_id = academic.enrollment_pathway(e.id, t.period))
  ON CONFLICT (student_enrollment_id, course_offering_id) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

-- ================================================================= exam =====
-- Eligibility per registration: attendance (or a condonation) and no active
-- hold. No held class yet = no shortage can be established.
CREATE OR REPLACE VIEW exam.v_exam_eligibility AS
SELECT r.id AS course_registration_id,
       s.attendance_pct,
       c.attendance_threshold_pct,
       (ac.course_registration_id IS NOT NULL) AS is_condoned,
       EXISTS (SELECT 1 FROM exam.eligibility_hold h
               JOIN academic.student_enrollment e2 ON e2.student_id = h.student_id
               WHERE e2.id = r.student_enrollment_id AND h.released_at IS NULL
                 AND h.academic_term_id = o.academic_term_id
                 AND (h.course_offering_id IS NULL OR h.course_offering_id = o.id)) AS has_active_hold,
       ( (s.attendance_pct IS NULL OR s.attendance_pct >= c.attendance_threshold_pct
          OR ac.course_registration_id IS NOT NULL)
         AND NOT EXISTS (SELECT 1 FROM exam.eligibility_hold h
               JOIN academic.student_enrollment e2 ON e2.student_id = h.student_id
               WHERE e2.id = r.student_enrollment_id AND h.released_at IS NULL
                 AND h.academic_term_id = o.academic_term_id
                 AND (h.course_offering_id IS NULL OR h.course_offering_id = o.id)) ) AS is_eligible
FROM academic.course_registration r
JOIN academic.course_offering o         ON o.id = r.course_offering_id
JOIN academic.student_enrollment e      ON e.id = r.student_enrollment_id
JOIN academic.batch_curriculum bc       ON bc.batch_id = e.batch_id
JOIN academic.curriculum c              ON c.id = bc.curriculum_id
JOIN academic.v_attendance_summary s    ON s.course_registration_id = r.id
LEFT JOIN exam.attendance_condonation ac ON ac.course_registration_id = r.id;

CREATE OR REPLACE FUNCTION exam.is_eligible(p_course_registration uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT is_eligible FROM exam.v_exam_eligibility WHERE course_registration_id = p_course_registration), false);
$$;

-- Would registering this course in this session put the student in two papers at once?
CREATE OR REPLACE FUNCTION exam.registration_has_clash(p_course_registration uuid, p_exam_session uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM academic.course_registration me
    JOIN academic.student_enrollment me_e ON me_e.id = me.student_enrollment_id
    JOIN exam.exam_schedule s1 ON s1.exam_session_id = p_exam_session AND s1.course_offering_id = me.course_offering_id
    JOIN exam.exam_registration er ON er.exam_session_id = p_exam_session AND er.course_registration_id <> me.id
    JOIN academic.course_registration other ON other.id = er.course_registration_id
    JOIN academic.student_enrollment ot_e ON ot_e.id = other.student_enrollment_id AND ot_e.student_id = me_e.student_id
    JOIN exam.exam_schedule s2 ON s2.exam_session_id = p_exam_session AND s2.course_offering_id = other.course_offering_id
    WHERE me.id = p_course_registration
      AND s2.exam_date = s1.exam_date AND s2.start_time < s1.end_time AND s1.start_time < s2.end_time);
$$;

-- Would this paper's slot clash for any student registered for it?
CREATE OR REPLACE FUNCTION exam.schedule_has_clash(p_schedule uuid, p_exam_session uuid, p_course_offering uuid,
                                                   p_date date, p_start time, p_end time)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM exam.exam_registration er1
    JOIN academic.course_registration r1 ON r1.id = er1.course_registration_id AND r1.course_offering_id = p_course_offering
    JOIN academic.student_enrollment e1  ON e1.id = r1.student_enrollment_id
    JOIN exam.exam_registration er2      ON er2.exam_session_id = p_exam_session AND er2.id <> er1.id
    JOIN academic.course_registration r2 ON r2.id = er2.course_registration_id AND r2.course_offering_id <> p_course_offering
    JOIN academic.student_enrollment e2  ON e2.id = r2.student_enrollment_id AND e2.student_id = e1.student_id
    JOIN exam.exam_schedule s2           ON s2.exam_session_id = p_exam_session AND s2.course_offering_id = r2.course_offering_id
    WHERE er1.exam_session_id = p_exam_session AND s2.id IS DISTINCT FROM p_schedule
      AND s2.exam_date = p_date AND s2.start_time < p_end AND p_start < s2.end_time);
$$;

-- Hall ticket: every paper a registered student sits, with room and seat.
CREATE OR REPLACE VIEW exam.v_hall_ticket AS
SELECT er.id AS exam_registration_id, er.exam_session_id, e.student_id, o.course_id,
       s.id AS exam_schedule_id, s.assessment_type_id, s.exam_date, s.start_time, s.end_time,
       sa.room_id, sa.seat_no, at.code AS attempt_type
FROM exam.exam_registration er
JOIN academic.course_registration r ON r.id = er.course_registration_id
JOIN academic.student_enrollment e  ON e.id = r.student_enrollment_id
JOIN academic.course_offering o     ON o.id = r.course_offering_id
JOIN exam.exam_schedule s           ON s.exam_session_id = er.exam_session_id AND s.course_offering_id = r.course_offering_id
JOIN ref.exam_attempt_type at       ON at.id = er.exam_attempt_type_id
LEFT JOIN exam.seat_allocation sa   ON sa.exam_schedule_id = s.id AND sa.exam_registration_id = er.id;

-- The mark that counts for an answer script: the highest-precedence round
-- that has a mark (revaluation > moderation > first evaluation).
CREATE OR REPLACE VIEW exam.v_effective_script_mark AS
SELECT DISTINCT ON (sm.answer_script_id)
       sm.answer_script_id, sm.evaluation_round_id, rr.code AS evaluation_round, sm.marks
FROM exam.script_mark sm
JOIN ref.evaluation_round rr ON rr.id = sm.evaluation_round_id
ORDER BY sm.answer_script_id, rr.precedence DESC;

-- Every component of an attempt's scheme with the marks that count: answer
-- script (scheduled exams) or component mark (the attempt's own, else the
-- carried-over internal mark; an approved internal-marks revision replaces
-- it). Scheduled papers marked directly by a panel (practical, viva) read the
-- attempt's component mark. NULL marks = absent or not yet entered.
-- is_counted: false for the components a "best N of M" group drops (the
-- lowest percentages); evaluation_part_id: internal or external.
CREATE OR REPLACE VIEW exam.v_component_score AS
WITH base AS (
SELECT er.id AS exam_registration_id, ec.id AS evaluation_component_id, ec.name AS component,
       ec.weight_pct, ec.max_marks, ec.min_pass_marks, at.is_scheduled_exam, at.evaluation_part_id,
       ec.component_group_id, grp.best_of, at.uses_answer_scripts,
       CASE WHEN at.uses_answer_scripts THEN esm.marks
            ELSE COALESCE(rev_attempt.revised_marks, cm_attempt.marks, rev_carried.revised_marks, cm_carried.marks) END AS marks
FROM exam.exam_registration er
JOIN academic.v_registration_scheme rs      ON rs.course_registration_id = er.course_registration_id
JOIN academic.evaluation_component ec       ON ec.evaluation_scheme_id = rs.evaluation_scheme_id
JOIN ref.assessment_type at                 ON at.id = ec.assessment_type_id
LEFT JOIN academic.evaluation_component_group grp ON grp.id = ec.component_group_id
LEFT JOIN academic.course_registration r    ON r.id = er.course_registration_id
LEFT JOIN exam.exam_schedule s              ON s.exam_session_id = er.exam_session_id
                                           AND s.course_offering_id = r.course_offering_id
                                           AND s.assessment_type_id = ec.assessment_type_id
LEFT JOIN exam.answer_script ans            ON ans.exam_schedule_id = s.id AND ans.exam_registration_id = er.id
LEFT JOIN exam.v_effective_script_mark esm  ON esm.answer_script_id = ans.id
LEFT JOIN exam.component_mark cm_attempt    ON cm_attempt.course_registration_id = er.course_registration_id
                                           AND cm_attempt.evaluation_component_id = ec.id
                                           AND cm_attempt.exam_registration_id = er.id
LEFT JOIN exam.component_mark cm_carried    ON cm_carried.course_registration_id = er.course_registration_id
                                           AND cm_carried.evaluation_component_id = ec.id
                                           AND cm_carried.exam_registration_id IS NULL
-- an approved internal-marks revision replaces the mark (original kept)
LEFT JOIN LATERAL (SELECT imr.revised_marks FROM exam.internal_mark_revision imr
                   JOIN wf.v_instance_state ws ON ws.instance_id = imr.instance_id AND ws.is_complete
                   WHERE imr.component_mark_id = cm_attempt.id ORDER BY imr.created_at DESC LIMIT 1) rev_attempt ON true
LEFT JOIN LATERAL (SELECT imr.revised_marks FROM exam.internal_mark_revision imr
                   JOIN wf.v_instance_state ws ON ws.instance_id = imr.instance_id AND ws.is_complete
                   WHERE imr.component_mark_id = cm_carried.id ORDER BY imr.created_at DESC LIMIT 1) rev_carried ON true)
SELECT b.*,
       (b.component_group_id IS NULL
        OR row_number() OVER (PARTITION BY b.exam_registration_id, b.component_group_id
                              ORDER BY COALESCE(b.marks, 0) / b.max_marks DESC, b.evaluation_component_id) <= b.best_of) AS is_counted
FROM base b;

-- The provisional result of an attempt, exactly as the exam cell would
-- publish it. Every step is driven by data on the scheme of examination:
--   1. counted components (best N of M) → weighted score per part
--      (internal / external) and in total;
--   2. internal-lead cap: if internal % exceeds external % by more than
--      max_internal_lead_pct, the excess internal marks are removed;
--   3. + board moderation (exam.result_moderation) + grace, capped to 0..100;
--   4. rounding (round_to_step, round_up);
--   5. grade band from the curriculum's scale — on a relative scale, a
--      passing attempt gets the band its percentile in the cohort (offering ×
--      session) reaches, unless the cohort is too small;
--   6. pass = aggregate ≥ min_aggregate_pct AND every part meets its
--      evaluation_part_rule AND every counted component meets its own pass
--      mark AND the grade band is a pass.
-- Publishing = inserting these values into exam.course_result.
CREATE OR REPLACE VIEW exam.v_provisional_result AS
WITH parts AS (
  SELECT cs.exam_registration_id, cs.evaluation_part_id, ep.code AS part_code,
         sum(COALESCE(cs.marks, 0) / cs.max_marks * cs.weight_pct) AS part_score,
         sum(cs.weight_pct) AS part_weight
  FROM exam.v_component_score cs
  JOIN ref.evaluation_part ep ON ep.id = cs.evaluation_part_id
  WHERE cs.is_counted
  GROUP BY cs.exam_registration_id, cs.evaluation_part_id, ep.code),
totals AS (
  SELECT cs.exam_registration_id,
         COALESCE(bool_and(cs.min_pass_marks IS NULL OR COALESCE(cs.marks, 0) >= cs.min_pass_marks)
                  FILTER (WHERE cs.is_counted), true) AS components_passed,
         count(*) FILTER (WHERE cs.marks IS NULL) AS components_missing
  FROM exam.v_component_score cs GROUP BY cs.exam_registration_id),
calc AS (
  SELECT t.exam_registration_id, t.components_passed, t.components_missing, rs.curriculum_id,
         er.exam_session_id, r.course_offering_id,
         sch.min_aggregate_pct, sch.max_internal_lead_pct, sch.round_to_step, sch.round_up,
         (SELECT sum(p.part_score) FROM parts p WHERE p.exam_registration_id = t.exam_registration_id) AS weighted_pct,
         (SELECT 100 * p.part_score / p.part_weight FROM parts p
          WHERE p.exam_registration_id = t.exam_registration_id AND p.part_code = 'INTERNAL') AS internal_pct,
         (SELECT 100 * p.part_score / p.part_weight FROM parts p
          WHERE p.exam_registration_id = t.exam_registration_id AND p.part_code = 'EXTERNAL') AS external_pct,
         (SELECT p.part_weight FROM parts p
          WHERE p.exam_registration_id = t.exam_registration_id AND p.part_code = 'INTERNAL') AS internal_weight,
         NOT EXISTS (SELECT 1 FROM academic.evaluation_part_rule pr
                     LEFT JOIN parts p ON p.exam_registration_id = t.exam_registration_id
                                      AND p.evaluation_part_id = pr.evaluation_part_id
                     WHERE pr.evaluation_scheme_id = rs.evaluation_scheme_id
                       AND COALESCE(100 * p.part_score / p.part_weight, 0) < pr.min_pass_pct) AS parts_passed,
         COALESCE(g.marks, 0) AS grace_marks,
         COALESCE(m.add_pct, 0) AS moderation_pct
  FROM totals t
  JOIN exam.exam_registration er          ON er.id = t.exam_registration_id
  JOIN academic.course_registration r     ON r.id = er.course_registration_id
  JOIN academic.v_registration_scheme rs  ON rs.course_registration_id = er.course_registration_id
  JOIN academic.evaluation_scheme sch     ON sch.id = rs.evaluation_scheme_id
  LEFT JOIN exam.grace_award g            ON g.exam_registration_id = er.id
  LEFT JOIN exam.result_moderation m      ON m.exam_session_id = er.exam_session_id AND m.course_offering_id = r.course_offering_id),
capped AS (
  SELECT c.*,
         CASE WHEN c.max_internal_lead_pct IS NOT NULL AND c.internal_pct - c.external_pct > c.max_internal_lead_pct
              THEN (c.external_pct + c.max_internal_lead_pct - c.internal_pct) / 100 * c.internal_weight
              ELSE 0 END AS internal_adjustment
  FROM calc c),
totalled AS (
  SELECT c.*,
         least(100, greatest(0, c.weighted_pct + c.internal_adjustment + c.moderation_pct + c.grace_marks)) AS raw_total
  FROM capped c),
rounded AS (
  SELECT t.*,
         least(100, CASE WHEN t.round_to_step IS NULL THEN round(t.raw_total, 2)
                         WHEN t.round_up THEN ceil(t.raw_total / t.round_to_step) * t.round_to_step
                         ELSE round(t.raw_total / t.round_to_step) * t.round_to_step END)::numeric(5,2) AS total_pct
  FROM totalled t),
-- relative grading: percentile of each passing attempt among the passing
-- attempts of the same course offering in the same exam session
cohort AS (
  SELECT x.*,
         (x.components_passed AND x.parts_passed AND x.total_pct >= x.min_aggregate_pct) AS pass_basic,
         round((100 * percent_rank() OVER (
                  PARTITION BY x.exam_session_id, x.course_offering_id,
                               (x.components_passed AND x.parts_passed AND x.total_pct >= x.min_aggregate_pct)
                  ORDER BY x.total_pct))::numeric, 2) AS cohort_percentile,
         count(*) FILTER (WHERE x.components_passed AND x.parts_passed AND x.total_pct >= x.min_aggregate_pct)
           OVER (PARTITION BY x.exam_session_id, x.course_offering_id) AS cohort_passers
  FROM rounded x)
SELECT x.exam_registration_id, x.total_pct, x.grace_marks, x.moderation_pct,
       round(x.internal_adjustment, 2) AS internal_adjustment,
       round(x.internal_pct, 2) AS internal_pct, round(x.external_pct, 2) AS external_pct,
       x.components_missing, x.parts_passed,
       COALESCE(rel.id, gb.id) AS grade_band_id,
       COALESCE(rel.grade_letter, gb.grade_letter) AS grade_letter,
       COALESCE(rel.grade_point, gb.grade_point) AS grade_point,
       (x.pass_basic AND COALESCE(rel.is_pass, gb.is_pass)) AS is_pass,
       CASE WHEN rel.id IS NOT NULL THEN x.cohort_percentile END AS cohort_percentile,
       (rel.id IS NOT NULL) AS graded_relatively
FROM cohort x
JOIN academic.curriculum cur     ON cur.id = x.curriculum_id
JOIN academic.grade_scale gs     ON gs.id = cur.grade_scale_id
LEFT JOIN academic.grade_band gb ON gb.grade_scale_id = cur.grade_scale_id AND gb.pct_range @> x.total_pct
LEFT JOIN LATERAL (SELECT b2.id, b2.grade_letter, b2.grade_point, b2.is_pass
                   FROM academic.relative_grade_cutoff rc JOIN academic.grade_band b2 ON b2.id = rc.grade_band_id
                   WHERE b2.grade_scale_id = gs.id AND rc.min_percentile <= x.cohort_percentile
                   ORDER BY rc.min_percentile DESC LIMIT 1) rel
       ON gs.is_relative AND x.pass_basic AND x.cohort_passers >= gs.relative_min_cohort;

-- The result currently in force for each attempt: the latest publication.
CREATE OR REPLACE VIEW exam.v_current_result AS
SELECT DISTINCT ON (cr.exam_registration_id)
       cr.exam_registration_id, cr.id AS course_result_id, cr.result_publication_id, p.published_at,
       cr.total_pct, gb.grade_letter, gb.grade_point, rs.code AS result_status, rs.is_pass,
       er.exam_session_id, er.course_registration_id
FROM exam.course_result cr
JOIN exam.result_publication p  ON p.id = cr.result_publication_id
JOIN academic.grade_band gb     ON gb.id = cr.grade_band_id
JOIN ref.result_status rs       ON rs.id = cr.result_status_id
JOIN exam.exam_registration er  ON er.id = cr.exam_registration_id
ORDER BY cr.exam_registration_id, p.published_at DESC;

-- Attempt number per course, derived (1 = first sitting).
CREATE OR REPLACE VIEW exam.v_exam_attempt AS
SELECT er.id AS exam_registration_id, er.course_registration_id,
       row_number() OVER (PARTITION BY er.course_registration_id ORDER BY lower(sess.period)) AS attempt_no
FROM exam.exam_registration er JOIN exam.exam_session sess ON sess.id = er.exam_session_id;

-- SGPA per student per exam session (credit-weighted grade points). Minor /
-- honours courses count only if their track says so.
CREATE OR REPLACE VIEW exam.v_sgpa AS
SELECT r.student_enrollment_id, cur.exam_session_id,
       round(sum(cur.grade_point * c.credits) / NULLIF(sum(c.credits), 0), 2) AS sgpa,
       sum(c.credits) FILTER (WHERE cur.is_pass) AS credits_earned
FROM exam.v_current_result cur
JOIN academic.course_registration r ON r.id = cur.course_registration_id
JOIN academic.course_offering o     ON o.id = r.course_offering_id
JOIN academic.course c              ON c.id = o.course_id
LEFT JOIN academic.v_registration_scheme rs ON rs.course_registration_id = r.id
LEFT JOIN academic.track t          ON t.id = rs.track_id
WHERE c.credits > 0 AND (rs.track_id IS NULL OR t.counts_in_cgpa)
GROUP BY r.student_enrollment_id, cur.exam_session_id;

-- COMBINED RESULT: per student and result group (theory + practical courses
-- that pass as one), the credit-weighted combined percentage of the members'
-- latest published results; pass only when every member has a result and
-- the combined % reaches the group's pass mark.
CREATE OR REPLACE VIEW exam.v_result_group_outcome AS
WITH member AS (
  SELECT DISTINCT ON (r.student_enrollment_id, o.course_id)
         r.student_enrollment_id, cc.result_group_id, o.course_id, c.credits, cur.total_pct
  FROM exam.v_current_result cur
  JOIN academic.course_registration r ON r.id = cur.course_registration_id
  JOIN academic.course_offering o     ON o.id = r.course_offering_id
  JOIN academic.course c              ON c.id = o.course_id
  JOIN academic.student_enrollment e  ON e.id = r.student_enrollment_id
  JOIN academic.batch_curriculum bc   ON bc.batch_id = e.batch_id
  JOIN academic.curriculum_course cc  ON cc.curriculum_id = bc.curriculum_id AND cc.course_id = o.course_id
                                     AND cc.result_group_id IS NOT NULL
  ORDER BY r.student_enrollment_id, o.course_id, cur.published_at DESC)
SELECT m.student_enrollment_id, m.result_group_id, g.code AS result_group,
       count(*) AS courses_with_result,
       (SELECT count(*) FROM academic.curriculum_course x WHERE x.result_group_id = m.result_group_id) AS courses_in_group,
       round(sum(m.total_pct * m.credits) / NULLIF(sum(m.credits), 0), 2) AS combined_pct,
       g.min_pass_pct,
       (count(*) = (SELECT count(*) FROM academic.curriculum_course x WHERE x.result_group_id = m.result_group_id)
        AND round(sum(m.total_pct * m.credits) / NULLIF(sum(m.credits), 0), 2) >= g.min_pass_pct) AS is_pass
FROM member m
JOIN academic.result_group g ON g.id = m.result_group_id
GROUP BY m.student_enrollment_id, m.result_group_id, g.code, g.min_pass_pct;

-- THE CREDIT LEDGER: every credit a student holds, one row per course.
--   INTERNAL         each course registration's latest published result
--                    (a passed backlog / improvement replaces the earlier attempt)
--   CREDIT_TRANSFER  accepted external credits (ABC, MOOC, other university),
--                    counted as the mapped course or category
-- Rows are expanded over the enrollment lineage, so a re-entering student
-- keeps the credits earned before the exit. track_id marks minor / honours
-- credits (outside the programme's credits); counts_in_cgpa says whether the
-- row enters the CGPA.
CREATE OR REPLACE VIEW academic.v_credit_ledger AS
WITH latest AS (
  SELECT DISTINCT ON (cur.course_registration_id) cur.course_registration_id, cur.grade_point, cur.is_pass
  FROM exam.v_current_result cur
  ORDER BY cur.course_registration_id, cur.published_at DESC),
entries AS (
  SELECT r.student_enrollment_id AS source_enrollment_id, 'INTERNAL'::text AS source,
         o.course_id, rs.course_category_id, rs.track_id,
         r.id AS course_registration_id, NULL::uuid AS credit_transfer_id,
         c.credits, l.grade_point, COALESCE(gro.is_pass, l.is_pass) AS is_pass,   -- a combined result decides for the whole group
         (rs.track_id IS NULL OR t.counts_in_cgpa) AS counts_in_cgpa
  FROM latest l
  JOIN academic.course_registration r ON r.id = l.course_registration_id
  JOIN academic.course_offering o     ON o.id = r.course_offering_id
  JOIN academic.course c              ON c.id = o.course_id
  LEFT JOIN academic.v_registration_scheme rs ON rs.course_registration_id = r.id
  LEFT JOIN academic.track t          ON t.id = rs.track_id
  LEFT JOIN academic.curriculum_course gcc ON gcc.curriculum_id = rs.curriculum_id AND gcc.course_id = o.course_id
                                          AND gcc.result_group_id IS NOT NULL
  LEFT JOIN exam.v_result_group_outcome gro ON gro.student_enrollment_id = r.student_enrollment_id
                                           AND gro.result_group_id = gcc.result_group_id
  UNION ALL
  SELECT ct.student_enrollment_id, 'CREDIT_TRANSFER', m.course_id, m.course_category_id, NULL::uuid,
         NULL::uuid, ct.id,
         ec.credits, ct.grade_point, true,
         ct.grade_point IS NOT NULL
  FROM academic.credit_transfer ct
  JOIN ref.credit_transfer_status s   ON s.id = ct.credit_transfer_status_id AND s.is_accepted
  JOIN academic.external_course ec    ON ec.id = ct.external_course_id
  LEFT JOIN academic.external_course_mapping m ON m.external_course_id = ct.external_course_id AND m.valid @> ct.completed_on)
SELECT lin.student_enrollment_id, x.source_enrollment_id, x.source, x.course_id, x.course_category_id, x.track_id,
       x.course_registration_id, x.credit_transfer_id, x.credits, x.grade_point, x.is_pass, x.counts_in_cgpa
FROM entries x
JOIN academic.v_enrollment_lineage lin ON lin.ancestor_enrollment_id = x.source_enrollment_id;

-- CGPA per enrollment from the credit ledger: each course once (latest
-- result), transferred credits with a converted grade point, earlier
-- enrollments of a re-entering student, minor/honours only if the track
-- counts in CGPA. credits_earned = programme credits (tracks excluded).
CREATE OR REPLACE VIEW exam.v_cgpa AS
SELECT l.student_enrollment_id,
       round(sum(l.grade_point * l.credits) FILTER (WHERE l.counts_in_cgpa)
             / NULLIF(sum(l.credits) FILTER (WHERE l.counts_in_cgpa), 0), 2) AS cgpa,
       COALESCE(sum(l.credits) FILTER (WHERE l.is_pass AND l.track_id IS NULL), 0) AS credits_earned,
       count(*) FILTER (WHERE NOT l.is_pass) AS courses_pending
FROM academic.v_credit_ledger l
WHERE l.credits > 0
GROUP BY l.student_enrollment_id;

-- RANK LIST: per batch, students with no pending course, ranked by CGPA
-- (dense rank: equal CGPA = equal rank). Rank-tied prizes read it.
CREATE OR REPLACE VIEW exam.v_rank_list AS
SELECT e.batch_id, b.program_id, cg.student_enrollment_id, cg.cgpa, cg.credits_earned,
       dense_rank() OVER (PARTITION BY e.batch_id ORDER BY cg.cgpa DESC) AS rank
FROM exam.v_cgpa cg
JOIN academic.student_enrollment e ON e.id = cg.student_enrollment_id
JOIN academic.batch b              ON b.id = e.batch_id
WHERE cg.courses_pending = 0 AND cg.cgpa IS NOT NULL;

-- A question paper's blueprint: marks per course outcome and per Bloom level,
-- as a share of the paper — the outcome-based-education check before approval.
CREATE OR REPLACE VIEW exam.v_question_paper_blueprint AS
SELECT qpi.question_paper_id,
       co.code AS course_outcome, bl.code AS bloom_level,
       sum(qpi.marks) AS marks,
       round(100 * sum(qpi.marks) / NULLIF(sum(sum(qpi.marks)) OVER (PARTITION BY qpi.question_paper_id), 0), 2) AS share_pct
FROM exam.question_paper_item qpi
JOIN exam.question_bank_item qb      ON qb.id = qpi.question_bank_item_id
LEFT JOIN academic.course_outcome co ON co.id = qb.course_outcome_id
LEFT JOIN ref.bloom_level bl         ON bl.id = qb.bloom_level_id
GROUP BY qpi.question_paper_id, co.code, bl.code;

-- A student's score per course outcome in one attempt: question-wise marks of
-- the paper sat (each question's outcome from the question bank) plus the
-- counted internal / directly marked components mapped to the outcome
-- (academic.evaluation_component_outcome). Components not yet marked do not count.
CREATE OR REPLACE VIEW exam.v_student_co_score AS
WITH by_question AS (
  SELECT qm.exam_registration_id, qb.course_outcome_id, sum(qm.marks) AS marks, sum(qpi.marks) AS max_marks
  FROM exam.question_mark qm
  JOIN exam.question_paper_item qpi ON qpi.question_paper_id = qm.question_paper_id AND qpi.question_no = qm.question_no
  JOIN exam.question_bank_item qb   ON qb.id = qpi.question_bank_item_id
  WHERE qb.course_outcome_id IS NOT NULL
  GROUP BY qm.exam_registration_id, qb.course_outcome_id),
by_component AS (
  SELECT cs.exam_registration_id, eco.course_outcome_id, sum(cs.marks) AS marks, sum(cs.max_marks) AS max_marks
  FROM exam.v_component_score cs
  JOIN academic.evaluation_component_outcome eco ON eco.evaluation_component_id = cs.evaluation_component_id
  JOIN academic.course_outcome co     ON co.id = eco.course_outcome_id
  JOIN academic.course_syllabus sy    ON sy.id = co.course_syllabus_id
  JOIN exam.exam_registration er      ON er.id = cs.exam_registration_id
  JOIN academic.course_registration r ON r.id = er.course_registration_id
  JOIN academic.course_offering o     ON o.id = r.course_offering_id AND o.course_id = sy.course_id
  WHERE cs.is_counted AND cs.marks IS NOT NULL
  GROUP BY cs.exam_registration_id, eco.course_outcome_id)
SELECT exam_registration_id, course_outcome_id, sum(marks) AS marks, sum(max_marks) AS max_marks,
       round(100 * sum(marks) / sum(max_marks), 2) AS score_pct
FROM (SELECT * FROM by_question UNION ALL SELECT * FROM by_component) x
GROUP BY exam_registration_id, course_outcome_id;

-- Course-outcome attainment of an offering's regular attempts, per programme
-- of the students (a shared course can serve several programmes): the share
-- of students scoring at least the policy's target, and the level 0–3 it
-- reaches. Policy = the programme's own, else the university default.
CREATE OR REPLACE VIEW academic.v_co_attainment AS
WITH scored AS (
  SELECT r.course_offering_id, b.program_id, sc.course_outcome_id, sc.score_pct
  FROM exam.v_student_co_score sc
  JOIN exam.exam_registration er      ON er.id = sc.exam_registration_id
  JOIN ref.exam_attempt_type eat      ON eat.id = er.exam_attempt_type_id AND eat.code = 'REGULAR'
  JOIN academic.course_registration r ON r.id = er.course_registration_id
  JOIN academic.student_enrollment e  ON e.id = r.student_enrollment_id
  JOIN academic.batch b               ON b.id = e.batch_id),
counted AS (
  SELECT s.course_offering_id, s.program_id, s.course_outcome_id,
         p.student_target_pct, p.level1_pct, p.level2_pct, p.level3_pct,
         count(*) AS students,
         count(*) FILTER (WHERE s.score_pct >= p.student_target_pct) AS students_attained
  FROM scored s
  CROSS JOIN LATERAL (SELECT ap.* FROM academic.attainment_policy ap
                      WHERE ap.program_id = s.program_id OR ap.program_id IS NULL
                      ORDER BY ap.program_id NULLS LAST LIMIT 1) p
  GROUP BY s.course_offering_id, s.program_id, s.course_outcome_id,
           p.student_target_pct, p.level1_pct, p.level2_pct, p.level3_pct)
SELECT course_offering_id, program_id, course_outcome_id, student_target_pct, students, students_attained,
       round(100.0 * students_attained / students, 2) AS attained_pct,
       CASE WHEN 100.0 * students_attained / students >= level3_pct THEN 3
            WHEN 100.0 * students_attained / students >= level2_pct THEN 2
            WHEN 100.0 * students_attained / students >= level1_pct THEN 1
            ELSE 0 END AS attainment_level
FROM counted;

-- Programme-outcome attainment per term: the strength-weighted average of the
-- levels of the course outcomes mapped to the PO (academic.co_po_mapping),
-- over the programme's offerings of that term. Scale 0–3.
CREATE OR REPLACE VIEW academic.v_po_attainment AS
SELECT ca.program_id, m.program_outcome_id, o.academic_term_id,
       count(*) AS course_outcomes,
       round(sum(m.strength * ca.attainment_level)::numeric / sum(m.strength), 2) AS attainment
FROM academic.v_co_attainment ca
JOIN academic.co_po_mapping m     ON m.course_outcome_id = ca.course_outcome_id
JOIN academic.program_outcome po  ON po.id = m.program_outcome_id AND po.program_id = ca.program_id
JOIN academic.course_offering o   ON o.id = ca.course_offering_id
GROUP BY ca.program_id, m.program_outcome_id, o.academic_term_id;

-- Which courses an enrollment has COMPLETED, and how: passed here (PASSED),
-- through accepted external credits mapped to the course (CREDIT_TRANSFER),
-- or by passing an approved equivalent (EQUIVALENT, via_course_id = the
-- course actually passed). Includes earlier enrollments through re-entry.
CREATE OR REPLACE VIEW academic.v_course_completion AS
WITH done AS (
  SELECT student_enrollment_id, course_id,
         CASE source WHEN 'INTERNAL' THEN 1 ELSE 2 END AS priority,
         CASE source WHEN 'INTERNAL' THEN 'PASSED' ELSE 'CREDIT_TRANSFER' END AS completed_via
  FROM academic.v_credit_ledger
  WHERE is_pass AND course_id IS NOT NULL),
any_route AS (
  SELECT student_enrollment_id, course_id, priority, completed_via, NULL::uuid AS via_course_id FROM done
  UNION ALL
  SELECT d.student_enrollment_id, ce.course_id, 3, 'EQUIVALENT', d.course_id
  FROM done d JOIN academic.course_equivalence ce ON ce.equivalent_course_id = d.course_id)
SELECT DISTINCT ON (student_enrollment_id, course_id) student_enrollment_id, course_id, completed_via, via_course_id
FROM any_route
ORDER BY student_enrollment_id, course_id, priority, via_course_id;

-- Registrations whose prerequisites are not completed (passed, transferred or
-- via an equivalent). A report, not a block: a Dean may waive a prerequisite.
CREATE OR REPLACE VIEW academic.v_prerequisite_gap AS
SELECT r.id AS course_registration_id, r.student_enrollment_id, o.course_id, p.prerequisite_course_id
FROM academic.course_registration r
JOIN academic.course_offering o     ON o.id = r.course_offering_id
JOIN academic.course_prerequisite p ON p.course_id = o.course_id
WHERE NOT EXISTS (SELECT 1 FROM academic.v_course_completion cc
                  WHERE cc.student_enrollment_id = r.student_enrollment_id AND cc.course_id = p.prerequisite_course_id);

-- MULTIPLE EXIT: for each enrollment, every award its curriculum offers and
-- whether the student qualifies right now (programme credits across
-- re-entries ≥ the rule's minimum, and every required course completed).
CREATE OR REPLACE VIEW academic.v_award_eligibility AS
SELECT e.id AS student_enrollment_id, ar.id AS award_rule_id, at.code AS award_type, ar.award_title,
       ar.after_term_no, ar.min_credits,
       COALESCE(cg.credits_earned, 0) AS credits_earned,
       req.missing AS required_courses_missing,
       (COALESCE(cg.credits_earned, 0) >= ar.min_credits AND req.missing = 0
        AND (ar.pathway_id IS NULL OR EXISTS (SELECT 1 FROM academic.student_pathway sp
                                              WHERE sp.student_enrollment_id = e.id AND sp.curriculum_pathway_id = ar.pathway_id))) AS is_eligible,
       ar.pathway_id
FROM academic.student_enrollment e
JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
JOIN academic.award_rule ar       ON ar.curriculum_id = bc.curriculum_id
JOIN ref.award_type at            ON at.id = ar.award_type_id
LEFT JOIN exam.v_cgpa cg          ON cg.student_enrollment_id = e.id
CROSS JOIN LATERAL (
  SELECT count(*) AS missing FROM academic.award_rule_course arc
  WHERE arc.award_rule_id = ar.id
    AND NOT EXISTS (SELECT 1 FROM academic.v_course_completion cc
                    WHERE cc.student_enrollment_id = e.id AND cc.course_id = arc.course_id)) req;

-- MINORS & HONOURS: credits earned on each track and whether it is complete
-- (the transcript then reads "B.Tech CSE with a Minor in …").
CREATE OR REPLACE VIEW academic.v_student_track_progress AS
SELECT st.id AS student_track_id, st.student_enrollment_id, st.track_id, t.code AS track_code, tt.code AS track_type,
       t.min_credits,
       COALESCE(sum(l.credits) FILTER (WHERE l.is_pass), 0) AS credits_earned,
       COALESCE(sum(l.credits) FILTER (WHERE l.is_pass), 0) >= t.min_credits AS is_complete
FROM academic.student_track st
JOIN academic.track t   ON t.id = st.track_id
JOIN ref.track_type tt  ON tt.id = t.track_type_id
LEFT JOIN academic.v_credit_ledger l ON l.student_enrollment_id = st.student_enrollment_id AND l.track_id = st.track_id
GROUP BY st.id, st.student_enrollment_id, st.track_id, t.code, tt.code, t.min_credits;

-- ============================================ student lifecycle & standing =====
-- BACKLOG: counted course registrations (of the enrollment or any earlier one
-- in its lineage) whose latest published result is not a pass and whose course
-- is not otherwise completed (equivalent / transfer). Track (minor / honours)
-- courses are outside the programme and do not count.
CREATE OR REPLACE VIEW academic.v_backlog AS
WITH latest AS (
  SELECT DISTINCT ON (cur.course_registration_id) cur.course_registration_id, cur.total_pct, cur.result_status, cur.is_pass
  FROM exam.v_current_result cur
  ORDER BY cur.course_registration_id, cur.published_at DESC)
SELECT lin.student_enrollment_id, r.id AS course_registration_id, r.student_enrollment_id AS source_enrollment_id,
       o.course_id, c.credits, o.academic_term_id, rs.term_no, l.total_pct, l.result_status
FROM latest l
JOIN academic.course_registration r        ON r.id = l.course_registration_id
JOIN ref.registration_status st            ON st.id = r.registration_status_id AND st.is_counted
JOIN academic.course_offering o            ON o.id = r.course_offering_id
JOIN academic.course c                     ON c.id = o.course_id
LEFT JOIN academic.v_registration_scheme rs ON rs.course_registration_id = r.id
JOIN academic.v_enrollment_lineage lin     ON lin.ancestor_enrollment_id = r.student_enrollment_id
WHERE NOT l.is_pass AND rs.track_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM academic.v_course_completion cc
                  WHERE cc.student_enrollment_id = lin.student_enrollment_id AND cc.course_id = o.course_id);

-- PROMOTION: for each enrollment and each checkpoint of its curriculum, the
-- backlog up to that term and whether the rule allows moving up.
CREATE OR REPLACE VIEW academic.v_promotion_eligibility AS
SELECT e.id AS student_enrollment_id, pr.id AS promotion_rule_id, pr.after_term_no,
       pr.max_backlog_credits, pr.max_backlog_courses,
       COALESCE(b.credits, 0) AS backlog_credits, COALESCE(b.courses, 0) AS backlog_courses,
       (COALESCE(b.credits, 0) <= pr.max_backlog_credits
        AND (pr.max_backlog_courses IS NULL OR COALESCE(b.courses, 0) <= pr.max_backlog_courses)) AS is_eligible
FROM academic.student_enrollment e
JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
JOIN academic.promotion_rule pr   ON pr.curriculum_id = bc.curriculum_id
LEFT JOIN LATERAL (
  SELECT sum(bl.credits) AS credits, count(*) AS courses
  FROM academic.v_backlog bl WHERE bl.student_enrollment_id = e.id AND bl.term_no <= pr.after_term_no) b ON true;

-- STANDING: one row per active enrollment — latest term registration and its
-- standing, current backlog, break status, and the last date a term may start
-- under the curriculum's maximum duration (counted from the first enrollment
-- of the lineage).
CREATE OR REPLACE VIEW academic.v_student_standing AS
SELECT e.id AS student_enrollment_id, e.student_id,
       tr.academic_term_id AS latest_registered_term_id, tr.term_no AS latest_registered_term_no,
       st.code AS latest_standing,
       COALESCE(b.credits, 0) AS backlog_credits, COALESCE(b.courses, 0) AS backlog_courses,
       EXISTS (SELECT 1 FROM academic.study_break sb WHERE sb.student_enrollment_id = e.id AND sb.period @> current_date) AS is_on_break,
       root.starts_on AS programme_started_on,
       CASE WHEN c.max_duration_years IS NULL THEN NULL
            ELSE (root.starts_on + make_interval(months => (c.max_duration_years * 12)::int))::date END AS must_complete_by
FROM academic.student_enrollment e
JOIN academic.batch_curriculum bc ON bc.batch_id = e.batch_id
JOIN academic.curriculum c        ON c.id = bc.curriculum_id
LEFT JOIN LATERAL (
  SELECT tr.academic_term_id, tr.term_no, tr.academic_standing_id
  FROM academic.term_registration tr
  JOIN academic.academic_term t       ON t.id = tr.academic_term_id
  JOIN ref.term_registration_status s ON s.id = tr.term_registration_status_id AND s.is_counted
  WHERE tr.student_enrollment_id = e.id ORDER BY lower(t.period) DESC LIMIT 1) tr ON true
LEFT JOIN ref.academic_standing st ON st.id = tr.academic_standing_id
LEFT JOIN LATERAL (SELECT sum(credits) AS credits, count(*) AS courses FROM academic.v_backlog bl WHERE bl.student_enrollment_id = e.id) b ON true
CROSS JOIN LATERAL (
  SELECT min(lower(e2.valid)) AS starts_on
  FROM academic.v_enrollment_lineage lin JOIN academic.student_enrollment e2 ON e2.id = lin.ancestor_enrollment_id
  WHERE lin.student_enrollment_id = e.id) root
WHERE e.valid @> current_date;

-- SEAT QUOTA USAGE per offering and quota: how many counted registrations
-- fall under each programme / unit ceiling.
CREATE OR REPLACE VIEW academic.v_offering_quota_usage AS
SELECT q.course_offering_id, q.id AS offering_seat_quota_id, q.program_id, q.org_unit_id, q.max_seats,
       (SELECT count(*) FROM academic.course_registration r
        JOIN ref.registration_status s ON s.id = r.registration_status_id AND s.is_counted
        WHERE r.course_offering_id = q.course_offering_id
          AND academic.offering_quota_for(q.course_offering_id, r.student_enrollment_id) = q.id) AS seats_used
FROM academic.offering_seat_quota q;

-- ============================================ curriculum content & workload =====
-- SYLLABUS COVERAGE per teaching assignment and unit: planned hours and items,
-- and how many items a held class session has delivered (course file).
CREATE OR REPLACE VIEW academic.v_syllabus_coverage AS
WITH cov AS (
  SELECT lp.id, EXISTS (
    SELECT 1 FROM academic.class_session_topic cst
    JOIN academic.class_session cs        ON cs.id = cst.class_session_id
    JOIN ref.class_session_status st      ON st.id = cs.class_session_status_id AND st.counts_as_held
    WHERE cst.lesson_plan_item_id = lp.id) AS covered
  FROM academic.lesson_plan_item lp)
SELECT lp.teaching_assignment_id, lp.syllabus_unit_id, su.unit_no, su.title AS unit_title,
       sum(lp.planned_hours) AS planned_hours,
       count(*) AS plan_items,
       count(*) FILTER (WHERE cov.covered) AS plan_items_covered,
       round(100.0 * count(*) FILTER (WHERE cov.covered) / count(*), 2) AS coverage_pct
FROM academic.lesson_plan_item lp
JOIN cov ON cov.id = lp.id
LEFT JOIN academic.syllabus_unit su ON su.id = lp.syllabus_unit_id
GROUP BY lp.teaching_assignment_id, lp.syllabus_unit_id, su.unit_no, su.title;

-- FACULTY WORKLOAD per employee and term: timetabled hours per week (a class
-- every N weeks counts 1/N), against the norm of the employee's current
-- primary designation.
CREATE OR REPLACE VIEW academic.v_faculty_workload AS
WITH load AS (
  SELECT ta.employee_id, o.academic_term_id,
         count(DISTINCT ta.id) AS teaching_assignments,
         COALESCE(sum(extract(epoch FROM (s.end_time - s.start_time)) / 3600.0 / te.repeat_every_weeks), 0) AS hours_per_week
  FROM academic.teaching_assignment ta
  JOIN academic.course_offering o       ON o.id = ta.course_offering_id
  JOIN academic.academic_term t         ON t.id = o.academic_term_id
  LEFT JOIN academic.timetable_entry te ON te.teaching_assignment_id = ta.id AND te.valid && t.period
  LEFT JOIN academic.time_slot s        ON s.id = te.time_slot_id
  WHERE ta.valid && t.period
  GROUP BY ta.employee_id, o.academic_term_id)
SELECT l.employee_id, l.academic_term_id, l.teaching_assignments,
       round(l.hours_per_week::numeric, 2) AS hours_per_week,
       ea.designation_id, n.min_hours_per_week, n.max_hours_per_week,
       (n.max_hours_per_week IS NOT NULL AND l.hours_per_week > n.max_hours_per_week) AS is_over_norm,
       (n.min_hours_per_week IS NOT NULL AND l.hours_per_week < n.min_hours_per_week) AS is_under_norm
FROM load l
LEFT JOIN people.employee_assignment ea ON ea.employee_id = l.employee_id AND ea.is_primary AND ea.valid @> current_date
LEFT JOIN academic.workload_norm n      ON n.designation_id = ea.designation_id AND n.valid @> current_date;

-- FEEDBACK SUMMARY per cycle, class and question — the only way feedback is
-- read; responses carry no student.
CREATE OR REPLACE VIEW academic.v_feedback_summary AS
SELECT fr.feedback_cycle_id, fr.teaching_assignment_id, fr.feedback_question_id, q.seq, q.question,
       count(fr.rating) AS responses, round(avg(fr.rating), 2) AS avg_rating, count(fr.comment) AS comments
FROM academic.feedback_response fr
JOIN academic.feedback_question q ON q.id = fr.feedback_question_id
GROUP BY fr.feedback_cycle_id, fr.teaching_assignment_id, fr.feedback_question_id, q.seq, q.question;

-- ======================================================= division / class =====
-- DIVISION and equivalent percentage from the CGPA, on the curriculum's scale.
CREATE OR REPLACE VIEW exam.v_division AS
SELECT cg.student_enrollment_id, cg.cgpa, cg.credits_earned,
       round(cg.cgpa * gs.pct_conversion_factor, 2) AS equivalent_pct,
       db.code AS division_code, db.label AS division
FROM exam.v_cgpa cg
JOIN academic.student_enrollment e ON e.id = cg.student_enrollment_id
JOIN academic.batch_curriculum bc  ON bc.batch_id = e.batch_id
JOIN academic.curriculum c         ON c.id = bc.curriculum_id
JOIN academic.grade_scale gs       ON gs.id = c.grade_scale_id
LEFT JOIN academic.division_band db ON db.grade_scale_id = gs.id AND db.cgpa_range @> cg.cgpa;

-- ============================================================= research =====
-- SCHOLAR STATUS: one row per doctoral enrollment — principal supervisor,
-- committee, reviews, coursework credits, thesis and viva.
CREATE OR REPLACE VIEW research.v_scholar_status AS
SELECT e.id AS student_enrollment_id, e.student_id, p.code AS program_code,
       sup.employee_id AS supervisor_employee_id,
       (ac.id IS NOT NULL) AS has_committee,
       (SELECT count(*) FROM research.progress_review pr WHERE pr.student_enrollment_id = e.id) AS progress_reviews,
       (SELECT o.code FROM research.progress_review pr JOIN ref.progress_review_outcome o ON o.id = pr.progress_review_outcome_id
        WHERE pr.student_enrollment_id = e.id ORDER BY pr.review_no DESC LIMIT 1) AS last_review_outcome,
       COALESCE(cg.credits_earned, 0) AS coursework_credits, p.min_credits AS coursework_credits_required,
       ts.code AS thesis_status, t.thesis_submitted_on,
       (SELECT count(*) FROM research.thesis_examiner te WHERE te.thesis_id = t.id AND te.report_received_on IS NULL) AS examiner_reports_pending,
       v.held_on AS viva_on, er.code AS viva_outcome
FROM academic.student_enrollment e
JOIN academic.batch b        ON b.id = e.batch_id
JOIN academic.program p      ON p.id = b.program_id
JOIN ref.program_level pl    ON pl.id = p.program_level_id AND pl.code = 'DOCTORAL'
LEFT JOIN research.supervisor_allocation sup
       ON sup.student_enrollment_id = e.id AND sup.valid @> current_date
      AND sup.supervisor_role_id IN (SELECT id FROM ref.supervisor_role WHERE is_principal)
LEFT JOIN research.advisory_committee ac ON ac.student_enrollment_id = e.id
LEFT JOIN exam.v_cgpa cg                 ON cg.student_enrollment_id = e.id
LEFT JOIN research.thesis t              ON t.student_enrollment_id = e.id
LEFT JOIN ref.thesis_status ts           ON ts.id = t.thesis_status_id
LEFT JOIN research.viva v                ON v.thesis_id = t.id
LEFT JOIN ref.examiner_recommendation er ON er.id = v.examiner_recommendation_id;



-- ================================================= academic operations (06c) ==
-- Credits registered per student and term against the curriculum's load rule
-- (term rule, else the default) and any approved overload: UNDER / OK / OVER.
CREATE OR REPLACE VIEW academic.v_credit_load AS
WITH reg AS (
  SELECT r.student_enrollment_id, o.academic_term_id, sum(c.credits) AS registered_credits
  FROM academic.course_registration r
  JOIN ref.registration_status rs ON rs.id = r.registration_status_id AND rs.is_counted
  JOIN academic.course_offering o ON o.id = r.course_offering_id
  JOIN academic.course c          ON c.id = o.course_id
  GROUP BY r.student_enrollment_id, o.academic_term_id)
SELECT reg.student_enrollment_id, reg.academic_term_id,
       academic.enrollment_term_no(reg.student_enrollment_id, reg.academic_term_id) AS term_no,
       reg.registered_credits, rule.min_credits,
       COALESCE(ov.max_credits, rule.max_credits) AS max_credits,
       (ov.student_enrollment_id IS NOT NULL) AS has_overload,
       CASE WHEN reg.registered_credits > COALESCE(ov.max_credits, rule.max_credits) THEN 'OVER'
            WHEN reg.registered_credits < rule.min_credits THEN 'UNDER'
            ELSE 'OK' END AS load_status
FROM reg
JOIN academic.student_enrollment e ON e.id = reg.student_enrollment_id
JOIN academic.batch_curriculum bc  ON bc.batch_id = e.batch_id
LEFT JOIN LATERAL (SELECT lr.min_credits, lr.max_credits FROM academic.credit_load_rule lr
                   WHERE lr.curriculum_id = bc.curriculum_id
                     AND (lr.term_no = academic.enrollment_term_no(reg.student_enrollment_id, reg.academic_term_id) OR lr.term_no IS NULL)
                   ORDER BY lr.term_no NULLS LAST LIMIT 1) rule ON true
LEFT JOIN academic.credit_overload_approval ov ON ov.student_enrollment_id = reg.student_enrollment_id
                                              AND ov.academic_term_id = reg.academic_term_id;

-- Apply for duty / medical leave: the student themself (or a staff member who
-- may update attendance in the student's department) opens an ATTENDANCE_LEAVE
-- round owned by the programme's department and records the request.
CREATE OR REPLACE FUNCTION academic.request_attendance_leave(p_enrollment uuid, p_leave_type text, p_period daterange,
                                                            p_reason text, p_document uuid, p_account uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_unit uuid; v_student_person uuid; v_instance uuid; v_id uuid;
BEGIN
  SELECT p.offering_org_unit_id, st.person_id INTO v_unit, v_student_person
  FROM academic.student_enrollment e
  JOIN people.student st   ON st.id = e.student_id
  JOIN academic.batch b    ON b.id = e.batch_id
  JOIN academic.program p  ON p.id = b.program_id
  WHERE e.id = p_enrollment;
  IF NOT EXISTS (SELECT 1 FROM iam.user_account WHERE id = p_account AND person_id = v_student_person)
     AND NOT authz.has_permission(p_account, 'academics.attendance.update', v_unit) THEN
    RAISE EXCEPTION 'request_attendance_leave: only the student or attendance staff of the department may apply'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  v_instance := wf.submit('ATTENDANCE_LEAVE', v_unit, p_account, p_reason);
  INSERT INTO academic.attendance_leave (student_enrollment_id, leave_type_id, period, reason, document_file_id, instance_id)
  VALUES (p_enrollment, ref.id_of('leave_type', p_leave_type), p_period, p_reason, p_document, v_instance)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Projects / internships each employee currently guides, per term.
CREATE OR REPLACE VIEW academic.v_guide_load AS
SELECT g.employee_id, o.academic_term_id,
       count(*) FILTER (WHERE sr.is_principal) AS principal_guide_of,
       count(*) FILTER (WHERE NOT sr.is_principal) AS co_guide_of
FROM academic.supervised_work_guide g
JOIN ref.supervisor_role sr          ON sr.id = g.supervisor_role_id
JOIN academic.supervised_work w      ON w.id = g.supervised_work_id
JOIN academic.course_registration r  ON r.id = w.course_registration_id
JOIN academic.course_offering o      ON o.id = r.course_offering_id
WHERE g.employee_id IS NOT NULL AND g.valid @> current_date
GROUP BY g.employee_id, o.academic_term_id;

-- Each current mentorship: meetings held, the last one, open follow-ups and
-- whether a concern is flagged — the mentor's (and HOD's) dashboard.
CREATE OR REPLACE VIEW academic.v_mentoring_status AS
SELECT sm.id AS student_mentor_id, sm.student_id, sm.employee_id AS mentor_employee_id,
       count(mm.id) AS meetings,
       max(mm.met_on) AS last_met_on,
       min(mm.follow_up_on) FILTER (WHERE mm.follow_up_on >= current_date) AS next_follow_up_on,
       bool_or(mm.concern_flag) FILTER (WHERE mm.met_on >= current_date - 180) AS recent_concern
FROM people.student_mentor sm
LEFT JOIN academic.mentoring_meeting mm ON mm.student_mentor_id = sm.id
WHERE sm.valid @> current_date
GROUP BY sm.id, sm.student_id, sm.employee_id;

-- Faculty course preferences for a term against the actual allocation
-- (teaching_assignment): did each teacher get the courses they asked for?
CREATE OR REPLACE VIEW academic.v_faculty_preference_status AS
SELECT fp.academic_term_id, fp.employee_id, fp.course_id, fp.preference_rank,
       EXISTS (SELECT 1 FROM academic.teaching_assignment ta
               JOIN academic.course_offering o ON o.id = ta.course_offering_id
               WHERE ta.employee_id = fp.employee_id AND o.course_id = fp.course_id
                 AND o.academic_term_id = fp.academic_term_id) AS is_allocated
FROM academic.faculty_course_preference fp;

-- ======================================================= SOE (Statement of Examination) ==
-- The SOE sheet, derived: one row per curriculum item (a fixed course, or one
-- row per elective slot) of a curriculum version, with everything the SGT SOE
-- Excel shows. Nothing here is stored twice — Django writes this to Excel.
CREATE OR REPLACE VIEW academic.v_soe AS
WITH item AS (
  SELECT cc.curriculum_id, cc.term_no, 'COURSE'::text AS row_kind, cc.course_id, NULL::uuid AS elective_basket_id,
         cc.course_category_id, cc.evaluation_scheme_id, cc.pathway_id, cc.result_group_id, NULL::smallint AS courses_to_choose
  FROM academic.curriculum_course cc
  UNION ALL
  SELECT b.curriculum_id, b.term_no, 'ELECTIVE_SLOT', NULL, b.id, b.course_category_id,
         (SELECT min(bc.evaluation_scheme_id) FROM academic.elective_basket_course bc WHERE bc.elective_basket_id = b.id),
         b.pathway_id, NULL, b.courses_to_choose
  FROM academic.elective_basket b),
hours AS (
  SELECT h.course_id,
         sum(h.hours_per_week) FILTER (WHERE dc.code = 'LECTURE')   AS l,
         sum(h.hours_per_week) FILTER (WHERE dc.code = 'TUTORIAL')  AS t,
         sum(h.hours_per_week) FILTER (WHERE dc.code = 'PRACTICAL') AS p
  FROM academic.course_component_hours h JOIN ref.delivery_component dc ON dc.id = h.delivery_component_id
  GROUP BY h.course_id),
comp AS (
  SELECT ec.evaluation_scheme_id, ep.code AS part, ec.id, ec.name, ec.max_marks, ec.min_pass_marks, ec.component_group_id
  FROM academic.evaluation_component ec
  JOIN ref.assessment_type at ON at.id = ec.assessment_type_id
  JOIN ref.evaluation_part ep ON ep.id = at.evaluation_part_id),
part AS (   -- per scheme and part: maximum marks (a best-of group counts best_of components) and the component list
  SELECT c.evaluation_scheme_id, c.part,
         COALESCE(sum(c.max_marks) FILTER (WHERE c.component_group_id IS NULL), 0)
         + COALESCE((SELECT sum(g.best_of * (SELECT max(c2.max_marks) FROM comp c2 WHERE c2.component_group_id = g.id))
                     FROM academic.evaluation_component_group g
                     WHERE g.evaluation_scheme_id = c.evaluation_scheme_id
                       AND EXISTS (SELECT 1 FROM comp c3 WHERE c3.component_group_id = g.id AND c3.part = c.part)), 0) AS max_marks,
         string_agg(c.name || ' ' || trim_scale(c.max_marks)
                    || COALESCE(' (pass ' || trim_scale(c.min_pass_marks) || ')', ''), '; ' ORDER BY c.id) AS components
  FROM comp c
  GROUP BY c.evaluation_scheme_id, c.part)
SELECT i.curriculum_id, cur.code AS curriculum_code, i.term_no,
       to_char(i.term_no, 'FMRN') || '/' ||
         to_char(ceil(i.term_no::numeric / GREATEST(cal.terms_per_year, 1))::int, 'FMRN') AS semester_year,
       i.row_kind,
       (SELECT string_agg(rb.code || ':' || rc.code, ', ' ORDER BY rb.sort_order)
        FROM academic.course_regulator_code rc JOIN ref.regulatory_body rb ON rb.id = rc.regulatory_body_id
        WHERE rc.course_id = i.course_id) AS council_code,
       co.code AS subject_code,
       COALESCE(co.title, eb.name) AS nomenclature,
       CASE WHEN i.course_id IS NULL THEN NULL
            WHEN COALESCE(hr.p, 0) > 0 AND COALESCE(hr.l, 0) + COALESCE(hr.t, 0) = 0 THEN 'Practical'
            WHEN COALESCE(hr.p, 0) = 0 THEN 'Theory'
            ELSE 'Theory + Practical' END AS theory_practical,
       COALESCE(pcat.code, cat.code) AS course_category,
       cat.code AS course_sub_category,
       CASE WHEN i.result_group_id IS NOT NULL THEN 'Combined' ELSE 'Separate' END AS result_type,
       rg.code AS result_group,
       hr.l AS lecture, hr.t AS tutorial, hr.p AS practical,
       COALESCE(co.credits,
                (SELECT CASE WHEN min(c2.credits) = max(c2.credits) THEN min(c2.credits) * i.courses_to_choose END
                 FROM academic.elective_basket_course bc2 JOIN academic.course c2 ON c2.id = bc2.course_id
                 WHERE bc2.elective_basket_id = i.elective_basket_id)) AS credits,
       i.courses_to_choose,
       pw.code AS pathway, i.pathway_id,
       sch.code AS scheme_code,
       ext.max_marks AS external_max, round(ext.max_marks * epr.min_pass_pct / 100, 2) AS external_pass, ext.components AS external_components,
       int_.max_marks AS internal_max, round(int_.max_marks * ipr.min_pass_pct / 100, 2) AS internal_pass, int_.components AS internal_components,
       sch.min_aggregate_pct AS overall_pass_pct,
       CASE WHEN ext.max_marks IS NOT NULL AND int_.max_marks IS NOT NULL THEN 'External + Internal'
            WHEN ext.max_marks IS NOT NULL THEN 'External'
            WHEN int_.max_marks IS NOT NULL THEN 'Internal' END AS passing_criteria,
       (cat.code = 'AUDIT' OR pcat.code = 'AUDIT') AS is_audit_only
FROM item i
JOIN academic.curriculum cur               ON cur.id = i.curriculum_id
JOIN academic.program pr                   ON pr.id = cur.program_id
JOIN ref.academic_calendar_type cal        ON cal.id = pr.academic_calendar_type_id
JOIN ref.course_category cat               ON cat.id = i.course_category_id
LEFT JOIN ref.course_category pcat         ON pcat.id = cat.parent_category_id
LEFT JOIN academic.course co               ON co.id = i.course_id
LEFT JOIN academic.elective_basket eb      ON eb.id = i.elective_basket_id
LEFT JOIN hours hr                         ON hr.course_id = i.course_id
LEFT JOIN academic.curriculum_pathway pw   ON pw.id = i.pathway_id
LEFT JOIN academic.result_group rg         ON rg.id = i.result_group_id
LEFT JOIN academic.evaluation_scheme sch   ON sch.id = i.evaluation_scheme_id
LEFT JOIN part ext                         ON ext.evaluation_scheme_id = i.evaluation_scheme_id AND ext.part = 'EXTERNAL'
LEFT JOIN part int_                        ON int_.evaluation_scheme_id = i.evaluation_scheme_id AND int_.part = 'INTERNAL'
LEFT JOIN academic.evaluation_part_rule epr ON epr.evaluation_scheme_id = i.evaluation_scheme_id
                                          AND epr.evaluation_part_id = ref.id_of('evaluation_part', 'EXTERNAL')
LEFT JOIN academic.evaluation_part_rule ipr ON ipr.evaluation_scheme_id = i.evaluation_scheme_id
                                          AND ipr.evaluation_part_id = ref.id_of('evaluation_part', 'INTERNAL');

-- Credits per term and cumulatively, for the common course set and for each
-- pathway (a pathway's rows include the common items), with the exit award
-- reached at that term ("Exit with a Certificate in …").
CREATE OR REPLACE VIEW academic.v_soe_exit AS
WITH lanes AS (
  SELECT c.id AS curriculum_id, NULL::uuid AS pathway_id FROM academic.curriculum c
  UNION ALL
  SELECT curriculum_id, id FROM academic.curriculum_pathway),
terms AS (
  SELECT l.curriculum_id, l.pathway_id, gs.term_no
  FROM lanes l
  JOIN academic.curriculum cur ON cur.id = l.curriculum_id
  JOIN academic.program p      ON p.id = cur.program_id
  CROSS JOIN LATERAL generate_series(1, p.duration_terms) AS gs(term_no)),
per_term AS (
  SELECT t.curriculum_id, t.pathway_id, t.term_no,
         COALESCE((SELECT sum(s.credits) FROM academic.v_soe s
                   WHERE s.curriculum_id = t.curriculum_id AND s.term_no = t.term_no
                     AND (s.pathway_id IS NULL OR s.pathway_id = t.pathway_id)), 0) AS term_credits
  FROM terms t)
SELECT pt.curriculum_id, pw.code AS pathway, pt.term_no, pt.term_credits,
       sum(pt.term_credits) OVER (PARTITION BY pt.curriculum_id, pt.pathway_id ORDER BY pt.term_no) AS cumulative_credits,
       ar.award_title AS exit_award, ar.min_credits AS exit_min_credits
FROM per_term pt
LEFT JOIN academic.curriculum_pathway pw ON pw.id = pt.pathway_id
LEFT JOIN academic.award_rule ar ON ar.curriculum_id = pt.curriculum_id AND ar.after_term_no = pt.term_no
                                AND ar.pathway_id IS NOT DISTINCT FROM pt.pathway_id;

-- The SOE header block: programme, department / school (from the org tree),
-- degree level, duration, curriculum version and its approval status.
CREATE OR REPLACE VIEW academic.v_soe_header AS
SELECT cur.id AS curriculum_id, cur.code AS curriculum_code, cur.name AS curriculum_name,
       p.code AS program_code, p.name AS program_name, pl.code AS program_level,
       dept.name AS department, school.name AS school,
       vp.duration_years, cur.max_attempts_per_course, cur.allows_internal_marks_revision,
       cs.status, cs.current_step, cs.submitted_at, cs.signed_at, cs.rounds
FROM academic.curriculum cur
JOIN academic.program p            ON p.id = cur.program_id
JOIN ref.program_level pl          ON pl.id = p.program_level_id
JOIN org.org_unit dept             ON dept.id = p.offering_org_unit_id
LEFT JOIN org.org_unit school      ON school.id = org.nearest_of_type(p.offering_org_unit_id, 'SCHOOL')
LEFT JOIN academic.v_program vp    ON vp.program_id = p.id
JOIN academic.v_curriculum_status cs ON cs.curriculum_id = cur.id;

-- ============================================================ facility =====
-- Everything a room is doing: the ledger with its source, without requester
-- identity (who booked is on v_booking_status, scoped by permission).
CREATE OR REPLACE VIEW facility.v_room_timeline AS
SELECT h.id AS hold_id, h.room_id, r.code AS room_code, r.building_id,
       t.code AS hold_type, h.during, facility.blocked(h.during, h.setup_minutes, h.teardown_minutes) AS blocked,
       h.is_active, (h.parent_hold_id IS NOT NULL) AS is_shadow,
       facility.hold_source_table(root) AS source_table,
       COALESCE(root.timetable_entry_id, root.class_session_id, root.exam_schedule_id, root.viva_id, root.convocation_id,
                root.booking_occurrence_id, root.guest_stay_id, root.room_service_window_id) AS source_id,
       COALESCE(br.title, c.code || ' ' || c.title, t.label) AS label,
       h.displaced_by_hold_id, h.displaced_at
FROM facility.room_hold h
JOIN org.room r ON r.id = h.room_id
JOIN facility.room_hold root ON root.id = COALESCE(h.parent_hold_id, h.id)
JOIN ref.hold_type t ON t.id = h.hold_type_id
LEFT JOIN facility.booking_occurrence o ON o.id = root.booking_occurrence_id
LEFT JOIN facility.booking_request br ON br.id = o.booking_request_id
LEFT JOIN academic.class_session cs ON cs.id = root.class_session_id
LEFT JOIN academic.timetable_entry te ON te.id = COALESCE(root.timetable_entry_id, cs.timetable_entry_id)
LEFT JOIN academic.teaching_assignment ta ON ta.id = COALESCE(te.teaching_assignment_id, cs.teaching_assignment_id)
LEFT JOIN academic.course_offering co ON co.id = ta.course_offering_id
LEFT JOIN academic.course c ON c.id = co.course_id;

-- Holds that lost their room to a higher-priority use and still need a new
-- place (or were reinstated: displaced_at kept, displaced_by cleared).
CREATE OR REPLACE VIEW facility.v_displaced_hold AS
SELECT h.id AS hold_id, h.room_id, r.code AS room_code, t.code AS hold_type, h.during,
       facility.hold_source_table(h) AS source_table, h.displaced_at,
       h.displaced_by_hold_id, dt.code AS displaced_by_hold_type, d.during AS displaced_by_during,
       facility.room_is_free(h.room_id, h.during, h.setup_minutes, h.teardown_minutes) AS room_free_again
FROM facility.room_hold h
JOIN org.room r ON r.id = h.room_id
JOIN ref.hold_type t ON t.id = h.hold_type_id
LEFT JOIN facility.room_hold d ON d.id = h.displaced_by_hold_id
LEFT JOIN ref.hold_type dt ON dt.id = d.hold_type_id
WHERE NOT h.is_active AND h.parent_hold_id IS NULL;

-- Class dates of a materialised term that have no active hold: displaced by
-- an exam / event, or never placed because the room was taken.
CREATE OR REPLACE VIEW facility.v_timetable_gap AS
WITH entries AS (
  SELECT te.id AS timetable_entry_id, te.room_id, te.valid, te.repeat_every_weeks, s.day_of_week, s.start_time, s.end_time,
         o.offering_org_unit_id, o.academic_term_id, at.period
  FROM academic.timetable_entry te
  JOIN academic.time_slot s ON s.id = te.time_slot_id
  JOIN academic.teaching_assignment ta ON ta.id = te.teaching_assignment_id
  JOIN academic.course_offering o ON o.id = ta.course_offering_id
  JOIN academic.academic_term at ON at.id = o.academic_term_id
  WHERE EXISTS (SELECT 1 FROM facility.room_hold h WHERE h.timetable_entry_id = te.id)),
expected AS (
  SELECT e.*, d::date AS class_date
  FROM entries e
  CROSS JOIN LATERAL generate_series(greatest(lower(e.period), lower(e.valid)),
                                     least(upper(e.period), COALESCE(upper(e.valid), upper(e.period))) - 1, interval '1 day') d
  WHERE extract(isodow FROM d) = e.day_of_week
    AND academic.is_pattern_week(lower(e.valid), e.repeat_every_weeks, d::date)
    AND academic.is_working_day(d::date, e.offering_org_unit_id)
    AND NOT EXISTS (SELECT 1 FROM academic.class_session cs JOIN ref.class_session_status st ON st.id = cs.class_session_status_id AND st.releases_room
                    WHERE cs.timetable_entry_id = e.timetable_entry_id AND cs.session_date = d::date))
SELECT x.timetable_entry_id, x.academic_term_id, x.room_id, x.class_date, facility.span(x.class_date, x.start_time, x.end_time) AS during,
       h.id AS displaced_hold_id,
       CASE WHEN h.id IS NOT NULL THEN 'DISPLACED' ELSE 'NOT_PLACED' END AS gap_kind
FROM expected x
LEFT JOIN facility.room_hold h ON h.timetable_entry_id = x.timetable_entry_id AND lower(h.during) = x.class_date + x.start_time
WHERE (h.id IS NULL OR NOT h.is_active)
  AND NOT EXISTS (SELECT 1 FROM facility.room_hold c JOIN ref.hold_type t ON t.id = c.hold_type_id AND t.code = 'TIMETABLE'   -- a co-teacher's entry shares the hold
                  WHERE c.room_id = x.room_id AND c.is_active AND c.during = facility.span(x.class_date, x.start_time, x.end_time));

-- One row per booking occurrence with its derived status:
--   AWAITING_EVENT (an event's room, event not yet approved) · PENDING ·
--   APPROVED · IN_USE (checked in) · NO_SHOW (not checked in past the grace)
--   · COMPLETED · EXPIRED (never decided) · RETURNED (rejected) · WITHDRAWN
--   · CANCELLED · RESCHEDULED
CREATE OR REPLACE VIEW facility.v_booking_status AS
SELECT o.id AS occurrence_id, br.id AS request_id, br.booking_group_id, g.group_ref, br.event_request_id,
       br.requester_person_id, br.on_behalf_org_unit_id, br.booking_purpose_id, br.title, br.expected_headcount,
       o.room_id, r.code AS room_code, o.during, o.setup_minutes, o.teardown_minutes,
       br.instance_id, s.status AS round_status, s.owner_org_unit_id AS custodian_org_unit_id, s.submitted_by_account_id, s.submitted_at,
       o.checked_in_at, o.cancelled_at, cr.code AS cancel_reason,
       CASE WHEN o.cancelled_at IS NOT NULL THEN CASE WHEN cr.code = 'RESCHEDULED' THEN 'RESCHEDULED' ELSE 'CANCELLED' END
            WHEN br.instance_id IS NULL THEN 'AWAITING_EVENT'
            WHEN s.status IN ('WITHDRAWN', 'RETURNED') THEN s.status
            WHEN s.status = 'IN_PROGRESS' THEN CASE WHEN upper(o.during) <= localtimestamp THEN 'EXPIRED' ELSE 'PENDING' END
            WHEN o.checked_in_at IS NOT NULL THEN CASE WHEN upper(o.during) <= localtimestamp THEN 'COMPLETED' ELSE 'IN_USE' END
            WHEN upper(o.during) <= localtimestamp THEN 'COMPLETED'
            WHEN localtimestamp > lower(o.during) + make_interval(mins => pol.no_show_grace_minutes) THEN 'NO_SHOW'
            ELSE 'APPROVED' END AS status,
       br.rescheduled_from_occurrence_id
FROM facility.booking_occurrence o
JOIN facility.booking_request br ON br.id = o.booking_request_id
JOIN org.room r ON r.id = o.room_id
LEFT JOIN facility.booking_group g ON g.id = br.booking_group_id
LEFT JOIN wf.v_instance_state s ON s.instance_id = br.instance_id
LEFT JOIN ref.booking_cancel_reason cr ON cr.id = o.booking_cancel_reason_id
LEFT JOIN LATERAL (SELECT * FROM facility.policy_for(COALESCE(s.owner_org_unit_id, br.on_behalf_org_unit_id), lower(o.during)::date)) pol ON true;

-- A booking group at a glance.
CREATE OR REPLACE VIEW facility.v_booking_summary AS
SELECT g.id AS booking_group_id, g.group_ref, min(v.title) AS title, (array_agg(v.requester_person_id))[1] AS requester_person_id,
       (array_agg(v.event_request_id))[1] AS event_request_id, g.created_at,
       count(*) AS occurrences, count(DISTINCT v.request_id) AS requests,
       min(lower(v.during))::date AS first_date, max(lower(v.during))::date AS last_date,
       count(*) FILTER (WHERE v.status = 'PENDING') AS pending,
       count(*) FILTER (WHERE v.status IN ('APPROVED', 'IN_USE', 'COMPLETED')) AS approved,
       count(*) FILTER (WHERE v.status IN ('RETURNED', 'WITHDRAWN', 'EXPIRED')) AS refused,
       count(*) FILTER (WHERE v.status IN ('CANCELLED', 'RESCHEDULED', 'NO_SHOW')) AS cancelled
FROM facility.booking_group g
JOIN facility.v_booking_status v ON v.booking_group_id = g.id
GROUP BY g.id;

-- An event with its round and its child requests.
CREATE OR REPLACE VIEW facility.v_event_status AS
SELECT e.id AS event_request_id, e.title, e.organiser_person_id, e.on_behalf_org_unit_id, k.code AS event_kind, e.during, e.expected_attendance,
       e.instance_id, s.status AS round_status,
       CASE WHEN e.cancelled_at IS NOT NULL THEN 'CANCELLED'
            WHEN s.status = 'IN_PROGRESS' AND upper(e.during) <= localtimestamp THEN 'EXPIRED'
            WHEN s.status = 'IN_PROGRESS' THEN 'PENDING'
            WHEN s.status = 'APPROVED' AND upper(e.during) <= localtimestamp THEN 'HELD'
            ELSE s.status END AS status,
       (SELECT count(*) FROM facility.booking_request br WHERE br.event_request_id = e.id) AS room_requests,
       (SELECT count(*) FROM facility.booking_request br JOIN wf.v_instance_state bs ON bs.instance_id = br.instance_id
        WHERE br.event_request_id = e.id AND bs.status = 'APPROVED') AS room_requests_approved,
       (SELECT count(*) FROM facility.trip_request tr WHERE tr.event_request_id = e.id) AS trip_requests
FROM facility.event_request e
JOIN ref.event_kind k ON k.id = e.event_kind_id
JOIN wf.v_instance_state s ON s.instance_id = e.instance_id;

-- Space per org unit today (allocated rooms, weighted by share): the basis of
-- NAAC / AICTE space returns.
CREATE OR REPLACE VIEW facility.v_space_inventory AS
SELECT u.id AS org_unit_id, u.code AS org_unit_code, u.name AS org_unit_name,
       count(a.id) AS rooms_allocated,
       round(sum(a.share_pct / 100), 2) AS rooms_equivalent,
       round(sum(r.area_sqm * a.share_pct / 100), 2) AS area_sqm,
       sum(r.capacity) AS seats,
       count(a.id) FILTER (WHERE ru.code = 'CLASSROOM') AS classrooms,
       count(a.id) FILTER (WHERE ru.code = 'LABORATORY') AS laboratories,
       count(a.id) FILTER (WHERE ru.code = 'OFFICE') AS offices
FROM org.org_unit u
LEFT JOIN facility.space_allocation a ON a.org_unit_id = u.id AND a.valid @> current_date
LEFT JOIN org.room r ON r.id = a.room_id
LEFT JOIN ref.room_use ru ON ru.id = r.room_use_id
GROUP BY u.id;

-- Hours held per room, month and kind of use, and the share of a 12-hour
-- working day (POLICY) they represent.
CREATE OR REPLACE VIEW facility.v_room_utilisation AS
SELECT h.room_id, r.code AS room_code, r.building_id, date_trunc('month', lower(h.during))::date AS month, t.code AS hold_type,
       round(sum(extract(epoch FROM (upper(h.during) - lower(h.during))) / 3600)::numeric, 1) AS hours_held,
       round((sum(extract(epoch FROM (upper(h.during) - lower(h.during))) / 3600)
              / (12 * extract(day FROM (date_trunc('month', lower(h.during)) + interval '1 month' - interval '1 day'))) * 100)::numeric, 1) AS pct_of_working_hours
FROM facility.room_hold h
JOIN org.room r ON r.id = h.room_id
JOIN ref.hold_type t ON t.id = h.hold_type_id
WHERE h.is_active AND h.parent_hold_id IS NULL
GROUP BY h.room_id, r.code, r.building_id, date_trunc('month', lower(h.during)), t.code;

-- Current status of every work order (the last event), SLA due time, overdue.
CREATE OR REPLACE VIEW facility.v_work_order_status AS
SELECT w.id AS work_order_id, w.wo_no, w.room_id, w.asset_id, cat.code AS category, pr.code AS priority,
       w.reported_by_person_id, w.reported_at, w.assignee_employee_id, w.vendor_id, w.cost,
       st.code AS status, st.is_terminal AS is_closed, e.occurred_at AS status_since, e.actor_account_id AS status_by_account_id,
       w.reported_at + pr.resolve_within AS due_at,
       (NOT st.is_terminal AND now() > w.reported_at + pr.resolve_within) AS is_overdue,
       CASE WHEN st.is_terminal THEN e.occurred_at END AS closed_at
FROM facility.work_order w
JOIN ref.work_order_category cat ON cat.id = w.work_order_category_id
JOIN ref.work_order_priority pr ON pr.id = w.work_order_priority_id
LEFT JOIN LATERAL (SELECT * FROM facility.work_order_event x WHERE x.work_order_id = w.id ORDER BY x.occurred_at DESC, x.id DESC LIMIT 1) e ON true
LEFT JOIN ref.work_order_status st ON st.id = e.work_order_status_id;

-- Preventive maintenance: when each schedule is next due.
CREATE OR REPLACE VIEW facility.v_maintenance_due AS
SELECT s.id AS maintenance_schedule_id, s.asset_id, s.room_id, mt.code AS maintenance_type, s.every, s.last_done_on, s.vendor_id,
       (COALESCE(s.last_done_on, s.created_at::date) + s.every)::date AS next_due_on,
       ((COALESCE(s.last_done_on, s.created_at::date) + s.every)::date <= current_date) AS is_due,
       EXISTS (SELECT 1 FROM facility.v_work_order_status w WHERE w.work_order_id IN (SELECT id FROM facility.work_order WHERE maintenance_schedule_id = s.id) AND NOT w.is_closed) AS has_open_work_order
FROM facility.maintenance_schedule s
JOIN ref.maintenance_type mt ON mt.id = s.maintenance_type_id
WHERE s.is_active;

-- The asset register: where, whose, in what condition, under warranty, in use.
CREATE OR REPLACE VIEW facility.v_asset_register AS
SELECT a.id AS asset_id, a.asset_tag, a.name, t.code AS asset_type, a.room_id, r.code AS room_code, a.custodian_org_unit_id,
       a.is_portable, c.code AS condition, c.is_serviceable, a.purchased_on, a.purchase_cost, a.warranty_until,
       (a.warranty_until IS NOT NULL AND a.warranty_until >= current_date) AS under_warranty,
       a.is_active, a.condemned_on,
       (SELECT h.during FROM facility.asset_hold h WHERE h.asset_id = a.id AND h.during @> localtimestamp) AS in_use_during,
       (SELECT count(*) FROM facility.v_work_order_status w WHERE w.asset_id = a.id AND NOT COALESCE(w.is_closed, false)) AS open_work_orders
FROM facility.asset a
JOIN ref.asset_type t ON t.id = a.asset_type_id
JOIN ref.asset_condition c ON c.id = a.asset_condition_id
LEFT JOIN org.room r ON r.id = a.room_id;

-- Guest stays with their derived status.
CREATE OR REPLACE VIEW facility.v_guest_stay_status AS
SELECT g.id AS guest_stay_id, g.room_id, r.code AS room_code, g.guest_person_id, gc.code AS guest_category, g.host_org_unit_id, g.host_employee_id,
       g.nights, (upper(g.nights) - lower(g.nights)) AS night_count, g.headcount, g.purpose, g.instance_id, s.status AS round_status,
       CASE WHEN g.cancelled_at IS NOT NULL THEN 'CANCELLED'
            WHEN s.status IN ('WITHDRAWN', 'RETURNED') THEN s.status
            WHEN s.status = 'IN_PROGRESS' THEN CASE WHEN upper(g.nights) <= current_date THEN 'EXPIRED' ELSE 'PENDING' END
            WHEN g.checked_out_at IS NOT NULL THEN 'CHECKED_OUT'
            WHEN g.checked_in_at IS NOT NULL THEN 'CHECKED_IN'
            WHEN upper(g.nights) <= current_date THEN 'NO_SHOW'
            ELSE 'APPROVED' END AS status,
       g.checked_in_at, g.checked_out_at
FROM facility.guest_stay g
JOIN org.room r ON r.id = g.room_id
JOIN ref.guest_category gc ON gc.id = g.guest_category_id
JOIN wf.v_instance_state s ON s.instance_id = g.instance_id;

-- What a stay costs: nights × the rate in force each night (a room's own
-- tariff over the tariff of its use; complimentary categories pay nothing).
-- Billing itself belongs to Finance.
CREATE OR REPLACE VIEW facility.v_guest_stay_charge AS
SELECT g.id AS guest_stay_id, g.room_id, g.guest_person_id, gc.code AS guest_category, g.nights,
       count(n.night) AS night_count,
       CASE WHEN gc.is_complimentary THEN 0 ELSE sum(t.rate_per_night) END AS total_charge,
       CASE WHEN gc.is_complimentary THEN NULL ELSE max(t.currency) END AS currency,
       CASE WHEN gc.is_complimentary THEN 0 ELSE count(n.night) FILTER (WHERE t.id IS NULL) END AS nights_without_tariff
FROM facility.guest_stay g
JOIN ref.guest_category gc ON gc.id = g.guest_category_id
JOIN org.room r ON r.id = g.room_id
CROSS JOIN LATERAL generate_series(lower(g.nights), upper(g.nights) - 1, interval '1 day') n(night)
LEFT JOIN LATERAL (
  SELECT t.* FROM facility.guest_tariff t
  WHERE t.guest_category_id = g.guest_category_id AND t.valid @> n.night::date
    AND (t.room_id = g.room_id OR t.room_use_id = r.room_use_id)
  ORDER BY (t.room_id IS NOT NULL) DESC LIMIT 1) t ON true
WHERE g.cancelled_at IS NULL
GROUP BY g.id, gc.code, gc.is_complimentary;

-- Parking zones: bays, permits in force today, free bays.
CREATE OR REPLACE VIEW facility.v_parking_zone_usage AS
SELECT r.id AS zone_room_id, r.code AS zone_code, r.building_id, r.capacity AS bays,
       count(p.id) AS permits_today, r.capacity - count(p.id) AS free_bays
FROM org.room r
JOIN ref.room_use u ON u.id = r.room_use_id AND u.is_parking_zone
LEFT JOIN facility.parking_permit p ON p.zone_room_id = r.id AND p.valid @> current_date
GROUP BY r.id;

-- Every key and who holds it now.
CREATE OR REPLACE VIEW facility.v_key_custody AS
SELECT k.id AS key_item_id, k.key_code, kk.code AS key_kind, kk.is_master, k.room_id, k.floor_id, k.building_id, k.custodian_org_unit_id,
       k.is_active, k.lost_reported_at, k.replaced_by_key_item_id,
       i.id AS key_issue_id, i.holder_person_id, i.issued_at, i.due_back_at,
       (i.due_back_at IS NOT NULL AND i.due_back_at < now()) AS is_overdue
FROM facility.key_item k
JOIN ref.key_kind kk ON kk.id = k.key_kind_id
LEFT JOIN facility.key_issue i ON i.key_item_id = k.id AND i.returned_at IS NULL;

-- Who can open which room right now (keys held, expanded to rooms).
CREATE OR REPLACE VIEW facility.v_key_access AS
SELECT DISTINCT c.holder_person_id, r.id AS room_id, r.code AS room_code, c.key_item_id, c.key_code
FROM facility.v_key_custody c
JOIN org.room r ON r.id = c.room_id OR r.floor_id = c.floor_id OR r.building_id = c.building_id
WHERE c.holder_person_id IS NOT NULL AND c.is_active;

-- Trip requests with their derived status:
--   PENDING · EXPIRED · RETURNED · WITHDRAWN · CANCELLED · APPROVED (awaiting
--   allocation) · DRIVER_ALLOCATED · ALLOCATED · POOLED · ON_TRIP · COMPLETED · CLOSED
CREATE OR REPLACE VIEW facility.v_trip_status AS
SELECT t.id AS trip_request_id, t.requester_person_id, t.on_behalf_org_unit_id, p.code AS purpose, t.during, t.origin_text, t.destination_text,
       t.headcount, t.event_request_id, t.instance_id, s.status AS round_status, (s.document_type = 'TRIP_REQUEST_URGENT') AS is_urgent,
       s.submitted_at, s.current_step,
       COALESCE(a.id, pa.id) AS trip_allocation_id, COALESCE(a.driver_id, pa.driver_id) AS driver_id, COALESCE(a.vehicle_id, pa.vehicle_id) AS vehicle_id,
       (pa.id IS NOT NULL) AS is_pooled, tr.id AS trip_id, tr.started_at, tr.completed_at, tr.closed_at,
       CASE WHEN t.cancelled_at IS NOT NULL THEN 'CANCELLED'
            WHEN s.status IN ('WITHDRAWN', 'RETURNED') THEN s.status
            WHEN s.status = 'IN_PROGRESS' THEN CASE WHEN upper(t.during) <= localtimestamp THEN 'EXPIRED' ELSE 'PENDING' END
            WHEN tr.closed_at IS NOT NULL THEN 'CLOSED'
            WHEN tr.completed_at IS NOT NULL THEN 'COMPLETED'
            WHEN tr.started_at IS NOT NULL THEN 'ON_TRIP'
            WHEN pa.id IS NOT NULL THEN 'POOLED'
            WHEN a.vehicle_id IS NOT NULL THEN 'ALLOCATED'
            WHEN a.id IS NOT NULL THEN 'DRIVER_ALLOCATED'
            WHEN upper(t.during) <= localtimestamp THEN 'EXPIRED'
            ELSE 'APPROVED' END AS status
FROM facility.trip_request t
JOIN ref.trip_purpose p ON p.id = t.trip_purpose_id
JOIN wf.v_instance_state s ON s.instance_id = t.instance_id
LEFT JOIN facility.trip_allocation a ON a.trip_request_id = t.id AND a.released_at IS NULL
LEFT JOIN facility.trip_allocation_request par ON par.trip_request_id = t.id
LEFT JOIN facility.trip_allocation pa ON pa.id = par.trip_allocation_id AND pa.released_at IS NULL
LEFT JOIN facility.trip tr ON tr.trip_allocation_id = COALESCE(a.id, pa.id);

-- Transport per unit and month: requests, outcomes, kilometres.
CREATE OR REPLACE VIEW facility.v_trip_summary AS
SELECT v.on_behalf_org_unit_id, date_trunc('month', lower(v.during))::date AS month,
       count(*) AS requests,
       count(*) FILTER (WHERE v.is_urgent) AS urgent,
       count(*) FILTER (WHERE v.status IN ('COMPLETED', 'CLOSED')) AS completed,
       count(*) FILTER (WHERE v.status IN ('CANCELLED', 'RETURNED', 'WITHDRAWN', 'EXPIRED')) AS not_run,
       count(*) FILTER (WHERE v.is_pooled) AS pooled,
       sum(t.end_odometer_km - t.start_odometer_km) FILTER (WHERE NOT v.is_pooled) AS km_driven,
       round(avg(rt.driver_rating), 2) AS avg_driver_rating
FROM facility.v_trip_status v
LEFT JOIN facility.trip t ON t.id = v.trip_id
LEFT JOIN LATERAL (SELECT avg(r.rating) AS driver_rating FROM facility.trip_rating r JOIN ref.rating_role rr ON rr.id = r.rating_role_id AND rr.code = 'PASSENGER'
                   WHERE r.trip_id = t.id) rt ON true
GROUP BY v.on_behalf_org_unit_id, date_trunc('month', lower(v.during));

-- Every vehicle × mandatory document: valid, expiring (30 days), expired, missing.
CREATE OR REPLACE VIEW facility.v_vehicle_document_status AS
SELECT v.id AS vehicle_id, v.registration_no, t.code AS document_type, d.document_no, upper(d.valid) - 1 AS expires_on,
       CASE WHEN d.id IS NULL THEN 'MISSING'
            WHEN upper(d.valid) <= current_date THEN 'EXPIRED'
            WHEN upper(d.valid) <= current_date + 30 THEN 'EXPIRING'
            ELSE 'VALID' END AS status
FROM facility.vehicle v
CROSS JOIN ref.vehicle_document_type t
LEFT JOIN LATERAL (SELECT * FROM facility.vehicle_document x WHERE x.vehicle_id = v.id AND x.vehicle_document_type_id = t.id
                   ORDER BY upper(x.valid) DESC LIMIT 1) d ON true
WHERE v.is_active AND t.is_active AND t.is_mandatory_for_trip;

-- Rooms free for a span, optionally by size, features, building, type.
CREATE OR REPLACE FUNCTION facility.free_rooms(p_during tsrange, p_headcount int DEFAULT NULL, p_features text[] DEFAULT NULL,
                                               p_building uuid DEFAULT NULL, p_room_type text DEFAULT NULL)
RETURNS TABLE (room_id uuid, room_code citext, building_id uuid, room_type text, capacity smallint) LANGUAGE sql STABLE AS $$
  SELECT r.id, r.code, r.building_id, t.code::text, r.capacity
  FROM org.room r
  JOIN ref.room_type t ON t.id = r.room_type_id
  LEFT JOIN ref.room_use u ON u.id = r.room_use_id
  WHERE r.is_active AND COALESCE(u.is_bookable, true) AND NOT COALESCE(u.is_guest_room, false) AND NOT COALESCE(u.is_parking_zone, false)
    AND (p_headcount IS NULL OR r.capacity >= p_headcount)
    AND (p_building IS NULL OR r.building_id = p_building)
    AND (p_room_type IS NULL OR t.code = p_room_type)
    AND (p_features IS NULL OR NOT EXISTS (
          SELECT 1 FROM unnest(p_features) f(code)
          WHERE NOT EXISTS (SELECT 1 FROM org.room_facility rf JOIN ref.room_feature ft ON ft.id = rf.room_feature_id
                            WHERE rf.room_id = r.id AND ft.code = f.code)))
    AND facility.room_is_free(r.id, p_during)
  ORDER BY r.capacity, r.code
$$;

-- The dates of a series: DAILY / WEEKLY (on the given ISO weekdays, default
-- the start's) / MONTHLY (same day of month), every N; CUSTOM = the listed
-- weekdays every week.
CREATE OR REPLACE FUNCTION facility.occurrence_dates(p_from date, p_to date, p_recurrence text DEFAULT 'DAILY', p_every int DEFAULT 1, p_weekdays int[] DEFAULT NULL)
RETURNS SETOF date LANGUAGE sql IMMUTABLE AS $$
  SELECT d::date FROM generate_series(p_from, p_to, interval '1 day') d
  WHERE CASE upper(p_recurrence)
          WHEN 'DAILY'   THEN (d::date - p_from) % greatest(p_every, 1) = 0
          WHEN 'WEEKLY'  THEN extract(isodow FROM d)::int = ANY (COALESCE(p_weekdays, ARRAY[extract(isodow FROM p_from)::int]))
                              AND ((date_trunc('week', d)::date - date_trunc('week', p_from)::date) / 7) % greatest(p_every, 1) = 0
          WHEN 'MONTHLY' THEN extract(day FROM d) = extract(day FROM p_from)
                              AND ((extract(year FROM d) - extract(year FROM p_from)) * 12 + extract(month FROM d) - extract(month FROM p_from))::int % greatest(p_every, 1) = 0
          WHEN 'CUSTOM'  THEN extract(isodow FROM d)::int = ANY (p_weekdays)
          ELSE false END
$$;

-- Book N rooms × M dates in one go: one group, one request per custodian,
-- one occurrence per room and date. With p_skip_conflicts the slots already
-- taken are left out (the summary shows what was booked); without it any
-- taken slot fails the whole request. A room of an event not yet approved
-- waits for the event (no round yet); a reschedule names the occurrence it
-- replaces and goes through ROOM_BOOKING_CHANGE.
CREATE OR REPLACE FUNCTION facility.request_booking(
  p_account uuid, p_purpose text, p_title text, p_rooms uuid[], p_dates date[], p_start time, p_end time,
  p_headcount int DEFAULT NULL, p_on_behalf_unit uuid DEFAULT NULL, p_features text[] DEFAULT NULL,
  p_skip_conflicts boolean DEFAULT false, p_note text DEFAULT NULL, p_event uuid DEFAULT NULL, p_rescheduled_from uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_person uuid; v_group uuid; v_request uuid; v_instance uuid; v_custodian uuid; v_room uuid; v_date date;
        v_doc text; v_event_open boolean := false; v_any boolean := false;
BEGIN
  SELECT person_id INTO v_person FROM iam.user_account WHERE id = p_account;
  IF cardinality(p_rooms) = 0 OR cardinality(p_dates) = 0 THEN
    RAISE EXCEPTION 'request_booking: at least one room and one date' USING ERRCODE = 'check_violation';
  END IF;
  IF p_event IS NOT NULL THEN
    v_event_open := (SELECT s.status <> 'APPROVED' FROM facility.event_request e JOIN wf.v_instance_state s ON s.instance_id = e.instance_id WHERE e.id = p_event);
  END IF;
  v_doc := CASE WHEN p_rescheduled_from IS NOT NULL THEN 'ROOM_BOOKING_CHANGE' ELSE 'ROOM_BOOKING' END;
  INSERT INTO facility.booking_group DEFAULT VALUES RETURNING id INTO v_group;

  FOR v_custodian IN SELECT DISTINCT facility.custodian_of(r, p_dates[1]) FROM unnest(p_rooms) r LOOP
    -- the slots of this custodian's rooms that are (still) free, if conflicts are to be skipped
    IF p_skip_conflicts AND NOT EXISTS (
         SELECT 1 FROM unnest(p_rooms) r CROSS JOIN unnest(p_dates) d
         WHERE facility.custodian_of(r, p_dates[1]) = v_custodian AND facility.room_is_free(r, facility.span(d, p_start, p_end))) THEN
      CONTINUE;
    END IF;
    v_instance := CASE WHEN v_event_open THEN NULL ELSE wf.submit(v_doc, v_custodian, p_account, p_note) END;
    INSERT INTO facility.booking_request (booking_group_id, event_request_id, requester_person_id, on_behalf_org_unit_id, booking_purpose_id,
                                          title, expected_headcount, note, instance_id, rescheduled_from_occurrence_id)
    VALUES (v_group, p_event, v_person, p_on_behalf_unit, ref.id_of('booking_purpose', p_purpose), p_title, p_headcount, p_note, v_instance, p_rescheduled_from)
    RETURNING id INTO v_request;
    INSERT INTO facility.booking_requirement (booking_request_id, room_feature_id)
    SELECT v_request, ref.id_of('room_feature', f) FROM unnest(COALESCE(p_features, '{}'::text[])) f;
    FOR v_room, v_date IN
      SELECT r, d FROM unnest(p_rooms) r CROSS JOIN unnest(p_dates) d WHERE facility.custodian_of(r, p_dates[1]) = v_custodian ORDER BY d, r
    LOOP
      IF p_skip_conflicts AND NOT facility.room_is_free(v_room, facility.span(v_date, p_start, p_end)) THEN CONTINUE; END IF;
      INSERT INTO facility.booking_occurrence (booking_request_id, room_id, during) VALUES (v_request, v_room, facility.span(v_date, p_start, p_end));
      v_any := true;
    END LOOP;
  END LOOP;
  IF NOT v_any THEN
    RAISE EXCEPTION 'request_booking: every requested slot is already taken' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN v_group;
END $$;

-- Cancel what is left of a group: every future occurrence (the occurrence
-- rules decide who may), and withdraw rounds still open.
CREATE OR REPLACE FUNCTION facility.cancel_booking_group(p_group uuid, p_account uuid, p_reason text DEFAULT 'REQUESTER')
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_n int; r record;
BEGIN
  UPDATE facility.booking_occurrence o
     SET cancelled_at = now(), cancelled_by_account_id = p_account, booking_cancel_reason_id = ref.id_of('booking_cancel_reason', p_reason)
  FROM facility.booking_request br
  WHERE br.id = o.booking_request_id AND br.booking_group_id = p_group AND o.cancelled_at IS NULL AND upper(o.during) > localtimestamp;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  FOR r IN SELECT s.instance_id FROM facility.booking_request br JOIN wf.v_instance_state s ON s.instance_id = br.instance_id
           WHERE br.booking_group_id = p_group AND s.status = 'IN_PROGRESS' AND s.submitted_by_account_id = p_account LOOP
    INSERT INTO wf.approval_action (instance_id, wf_action_type_id, actor_account_id, note)
    VALUES (r.instance_id, ref.id_of('wf_action_type', 'WITHDRAW'), p_account, 'Group cancelled');
  END LOOP;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION facility.request_event(p_account uuid, p_title text, p_kind text, p_unit uuid, p_during tsrange,
                                                  p_attendance int DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO facility.event_request (title, organiser_person_id, on_behalf_org_unit_id, event_kind_id, during, expected_attendance, note, instance_id)
  VALUES (p_title, (SELECT person_id FROM iam.user_account WHERE id = p_account), p_unit, ref.id_of('event_kind', p_kind), p_during, p_attendance, p_note,
          wf.submit('EVENT_REQUEST', p_unit, p_account, p_note))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION facility.request_guest_stay(p_account uuid, p_room uuid, p_guest uuid, p_category text, p_host_unit uuid,
                                                       p_nights daterange, p_purpose text, p_headcount int DEFAULT 1, p_host_employee uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO facility.guest_stay (room_id, guest_person_id, guest_category_id, host_org_unit_id, host_employee_id, nights, purpose, headcount, instance_id)
  VALUES (p_room, p_guest, ref.id_of('guest_category', p_category), p_host_unit, p_host_employee, p_nights, p_purpose, p_headcount,
          wf.submit('GUEST_STAY', p_host_unit, p_account, p_purpose))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- A trip request; urgent (departure within the policy threshold) goes
-- straight to transport.
CREATE OR REPLACE FUNCTION facility.request_trip(p_account uuid, p_unit uuid, p_purpose text, p_during tsrange, p_origin text, p_destination text,
                                                 p_headcount int, p_contact_phone text, p_note text DEFAULT NULL, p_event uuid DEFAULT NULL,
                                                 p_origin_lat numeric DEFAULT NULL, p_origin_lon numeric DEFAULT NULL,
                                                 p_destination_lat numeric DEFAULT NULL, p_destination_lon numeric DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid; v_pol facility.transport_policy; v_doc text;
BEGIN
  v_pol := facility.transport_policy_for(p_unit);
  v_doc := CASE WHEN lower(p_during) < (clock_timestamp() + v_pol.urgent_threshold)::timestamp THEN 'TRIP_REQUEST_URGENT' ELSE 'TRIP_REQUEST' END;
  INSERT INTO facility.trip_request (requester_person_id, on_behalf_org_unit_id, trip_purpose_id, event_request_id, during, origin_text, destination_text,
                                     origin_lat, origin_lon, destination_lat, destination_lon, headcount, contact_phone, note, instance_id)
  VALUES ((SELECT person_id FROM iam.user_account WHERE id = p_account), p_unit, ref.id_of('trip_purpose', p_purpose), p_event, p_during, p_origin, p_destination,
          p_origin_lat, p_origin_lon, p_destination_lat, p_destination_lon, p_headcount, p_contact_phone, p_note,
          wf.submit(v_doc, p_unit, p_account, p_note))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION facility.raise_work_order(p_account uuid, p_room uuid, p_asset uuid, p_category text, p_priority text, p_description text)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO facility.work_order (room_id, asset_id, work_order_category_id, work_order_priority_id, reported_by_person_id, description)
  VALUES (p_room, p_asset, ref.id_of('work_order_category', p_category), ref.id_of('work_order_priority', p_priority),
          (SELECT person_id FROM iam.user_account WHERE id = p_account), p_description)
  RETURNING id INTO v_id;
  INSERT INTO facility.work_order_event (work_order_id, work_order_status_id, actor_account_id) VALUES (v_id, ref.id_of('work_order_status', 'REPORTED'), p_account);
  RETURN v_id;
END $$;

-- Scheduled job (app.system_job = on): free the rooms of bookings nobody
-- checked in to after the grace period.
CREATE OR REPLACE FUNCTION facility.release_no_shows()
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_n int;
BEGIN
  IF current_setting('app.system_job', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'release_no_shows: runs as a system job only' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE facility.booking_occurrence o SET cancelled_at = now(), booking_cancel_reason_id = ref.id_of('booking_cancel_reason', 'NO_SHOW')
  FROM facility.v_booking_status v WHERE v.occurrence_id = o.id AND v.status = 'NO_SHOW';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

-- Scheduled job (app.system_job = on): the transport escalations — an
-- undecided request this close to departure is approved automatically
-- (AUTO_APPROVE on each pending step, alert AUTO_APPROVED); an approved but
-- unallocated one this close raises UNALLOCATED_SOON; a request whose window
-- has passed without a trip raises EXPIRED.
CREATE OR REPLACE FUNCTION facility.run_trip_escalations()
RETURNS TABLE (auto_approved int, alerts int) LANGUAGE plpgsql AS $$
DECLARE r record; v_pol facility.transport_policy; v_state record; v_n int; v_status text;
BEGIN
  IF current_setting('app.system_job', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'run_trip_escalations: runs as a system job only' USING ERRCODE = 'insufficient_privilege';
  END IF;
  auto_approved := 0; alerts := 0;
  FOR r IN SELECT * FROM facility.v_trip_status WHERE status IN ('PENDING', 'APPROVED') LOOP
    v_pol := facility.transport_policy_for(r.on_behalf_org_unit_id);
    v_status := r.status;
    IF v_status = 'PENDING' AND lower(r.during) <= (clock_timestamp() + v_pol.auto_approve_before)::timestamp THEN
      LOOP
        SELECT * INTO v_state FROM wf.v_instance_state WHERE instance_id = r.instance_id;
        EXIT WHEN v_state.current_seq IS NULL;
        INSERT INTO wf.approval_action (instance_id, step_seq, wf_action_type_id, note)
        VALUES (r.instance_id, v_state.current_seq, ref.id_of('wf_action_type', 'AUTO_APPROVE'), 'No decision before the auto-approval deadline');
      END LOOP;
      auto_approved := auto_approved + 1; v_status := 'APPROVED';
      INSERT INTO facility.trip_alert (trip_request_id, trip_alert_type_id) VALUES (r.trip_request_id, ref.id_of('trip_alert_type', 'AUTO_APPROVED')) ON CONFLICT DO NOTHING;
      GET DIAGNOSTICS v_n = ROW_COUNT; alerts := alerts + v_n;
    END IF;
    IF v_status = 'APPROVED' AND lower(r.during) <= (clock_timestamp() + v_pol.alert_before)::timestamp THEN
      INSERT INTO facility.trip_alert (trip_request_id, trip_alert_type_id) VALUES (r.trip_request_id, ref.id_of('trip_alert_type', 'UNALLOCATED_SOON')) ON CONFLICT DO NOTHING;
      GET DIAGNOSTICS v_n = ROW_COUNT; alerts := alerts + v_n;
    END IF;
  END LOOP;
  INSERT INTO facility.trip_alert (trip_request_id, trip_alert_type_id)
  SELECT trip_request_id, ref.id_of('trip_alert_type', 'EXPIRED') FROM facility.v_trip_status WHERE status = 'EXPIRED' ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT; alerts := alerts + v_n;
  RETURN NEXT;
END $$;

-- ================================================================ grants =====
REVOKE ALL ON SCHEMA pii, iam, privacy, audit, exam, research, wf, facility FROM PUBLIC;

-- application runtime
GRANT USAGE ON SCHEMA util, ref, org, people, academic, exam, research, facility, pii, iam, authz, wf, privacy, audit TO intranet_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ref, org, people, academic, exam, research, facility, pii, iam, authz, wf, privacy TO intranet_app;
REVOKE UPDATE, DELETE ON wf.approval_instance, wf.approval_step, wf.approval_action, wf.approval_instance_flag FROM intranet_app;   -- approval records are append-only
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA audit TO intranet_app;          -- append-only
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ref, org, people, academic, exam, research, facility, pii, iam, authz, wf, privacy, audit TO intranet_app;

-- reporting: no personal-data schema, no credentials, no names, and no
-- de-anonymising exam data (answer-script codes, unfair-means narratives)
GRANT USAGE ON SCHEMA ref, org, people, academic, exam, research, facility, authz, wf TO intranet_analytics;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, org, people, academic, exam, research, facility, authz, wf TO intranet_analytics;
REVOKE SELECT ON wf.approval_comment, wf.approval_consultation FROM intranet_analytics;   -- free-text reviewer remarks, questions and replies
REVOKE SELECT ON exam.examiner_panel FROM intranet_analytics;           -- who examined whom (external examiners are persons)
REVOKE SELECT ON academic.attendance_leave, academic.mentoring_meeting FROM intranet_analytics;   -- health reasons, mentoring notes
REVOKE SELECT ON exam.attendance_condonation, academic.faculty_unavailability, academic.faculty_course_preference FROM intranet_analytics;   -- reasons that may be about health, a teacher's own remarks
REVOKE SELECT ON wf.approval_delegation FROM intranet_analytics;        -- why someone is away
REVOKE SELECT ON facility.booking_request, facility.event_request FROM intranet_analytics;   -- free-text notes; use v_booking_summary / v_booking_status / v_event_status
REVOKE SELECT ON exam.question_bank_item, exam.question_paper_item FROM intranet_analytics;     -- confidential questions
REVOKE SELECT ON people.person, people.person_relationship, people.file_object,
                 people.v_person_display_name FROM intranet_analytics;   -- names are personal data
REVOKE SELECT ON exam.answer_script, exam.ufm_case FROM intranet_analytics;
REVOKE SELECT ON academic.credit_transfer FROM intranet_analytics;       -- ABC / APAAR transaction ids, certificates
REVOKE SELECT ON exam.question_paper FROM intranet_analytics;            -- confidential until the exam
REVOKE SELECT ON academic.feedback_response FROM intranet_analytics;     -- free-text comments; use v_feedback_summary
REVOKE SELECT ON academic.study_break FROM intranet_analytics;           -- medical reasons
REVOKE SELECT ON academic.disciplinary_case FROM intranet_analytics;     -- misconduct narratives
REVOKE SELECT ON facility.booking_restriction FROM intranet_analytics;   -- disciplinary: who is barred and why
REVOKE SELECT ON facility.trip_request, facility.trip_allocation, facility.trip, facility.trip_rating,
                 facility.v_trip_status FROM intranet_analytics;          -- journeys, contact numbers, tokens, ratings of people; use v_trip_summary
REVOKE SELECT ON facility.driver, facility.driver_unavailability FROM intranet_analytics;   -- licence document links, absences
REVOKE SELECT ON facility.guest_stay, facility.v_guest_stay_status, facility.v_guest_stay_charge FROM intranet_analytics;   -- who stayed where
REVOKE SELECT ON facility.key_issue, facility.v_key_custody, facility.v_key_access FROM intranet_analytics;   -- who can open what
REVOKE SELECT ON facility.work_order, facility.work_order_event FROM intranet_analytics;   -- free-text reports naming people; use v_work_order_status
REVOKE SELECT ON facility.asset_loan, facility.parking_permit, facility.room_reservation_rule FROM intranet_analytics;   -- named persons, vehicle numbers

-- Data Protection Officer tooling
GRANT USAGE ON SCHEMA ref, org, people, academic, exam, research, facility, pii, privacy TO intranet_dpo;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, org, people, academic, exam, research, facility, pii, privacy TO intranet_dpo;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA privacy TO intranet_dpo;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA privacy TO intranet_dpo;
