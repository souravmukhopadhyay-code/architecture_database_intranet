# CLAUDE.md — New Intranet Foundation Database

This file governs how Claude Code works in this repository.

**What this repo is:** the normalised **PostgreSQL** foundation database
for a new SGT University intranet — organisation structure, academic
structure (programmes/calendar/batches), curriculum and teaching delivery
(courses, curricula, sections, faculty assignment, clash-checked
timetable, attendance), NEP 2020 flexibility (multiple entry & exit,
Academic Bank of Credits / MOOC credit transfer, minors & honours, course
equivalence, configurable result formulas), examinations (`exam` schema: eligibility,
registration, date sheet, seating, evaluation, published results,
revaluation, question papers, certificates, convocation), the student
lifecycle (term registration and academic standing, promotion rules,
breaks in study, programme transfer, maximum duration), the academic
calendar, regulator approvals and accreditation, syllabus and CO–PO
outcomes, faculty workload, anonymous student feedback, research degrees
(`research` schema: supervision, advisory committee, thesis, viva), resource
& facility management (`facility` schema: one occupancy ledger for every
room fed by the timetable, exams, vivas, convocations and bookings;
bookings and events approved at the custodian; assets, maintenance, guest
house, parking, fleet & transport, keys), people
(employees, students, guardians), user accounts,
roles/permissions, login with MFA, DPDP Act 2023 controls, and an
append-only audit trail. Backend target is
**Django**; no application code lives here — this repo *is* the database
layer those apps will connect to. Module-specific tables (IPR,
finance, HR extensions...) are **out of scope by design**; they
attach to this foundation later via foreign keys. (Seminar-hall / cab
booking is *not* one of them any more: it is the `facility` schema.) The
**helpdesk (TMS)** is the first module built that way: its own schema `tms`
in its own file `sql/12_tms.sql` (after `00`–`11`, with its own lookups,
RBAC, DPDP registration, audit and grants) and its own tests in
`sql/98_tms_smoke_test.sql` — a module's tables live in the module's file,
never in the foundation files. **Clubs & event management** is the second:
schema `events` in `sql/13_events.sql`, tests in
`sql/97_events_smoke_test.sql`; its approvals are configuration on the `wf`
engine, not tables of its own.

Personal data here belongs to students, applicants, faculty, employees
and guardians of SGT University — regulated under India's **Digital
Personal Data Protection Act, 2023 (DPDP Act)**, so every schema change is
written with that in mind by default, not bolted on later.

Claude must follow every rule below without being reminded, and must flag
(not silently skip) any request that would require breaking one.

---

## 1. Read this first

- `README.md` — file map, at-a-glance summary, how to run and verify.
- `docs/README.md` — the documentation index (every document by purpose); a
  module's own documents live in `docs/<module>/` (`docs/tms/`, `docs/events/`).
- `docs/design.md` — the design: principles, ER diagrams (mermaid), the
  actual flows (onboarding, login, authorization, module plug-in), Django
  mapping notes.
- `docs/dpdp-compliance.md` — DPDP section → table/constraint mapping,
  data-minimisation choices, and the items still marked POLICY (retention
  periods, response windows — need legal/DPO sign-off, not a code
  decision).
- `docs/data-dictionary.md` — every table/column/constraint, generated
  from the live catalog by `scripts/gen_data_dictionary.{sql,py}`. Never
  hand-edit it.
- `docs/module-integration.md` — worked examples: central/independent
  departments (HR, IT, Finance…), how TMS and Event Management are built on
  the foundation, how the old Resource Management module maps onto the
  built-in `facility` schema, and how an approval is configured on `wf`. Consult this before designing either module, before adding
  anything that occupies a room or a vehicle, or before assuming a new
  department needs a new table.
- `docs/academic-flow.md` (+ `.png`/`.svg`) — the one-slide academic flow
  for presentations. Re-render the images if the Mermaid source changes.
- `docs/data-flow.md` (+ `docs/dfd/`) — data-flow diagrams: context, the 16
  processes, and each process in detail with table-level data stores. The
  diagrams are generated from `docs/dfd/build_dfd.py`; after adding a table,
  add it to a store and a flow there, run the script (it fails if a table is
  unplaced) and re-render with `docs/dfd/render.sh`. The same script writes
  Level 3 — one diagram per feature in `docs/dfd/features/` and the document
  `docs/data-flow-features.md` — derived from the Level-2 specs; never edit
  those by hand.
- `docs/table-catalog.md` — every one of the 546 tables individually: why
  it exists and exactly which tables it connects to (verified against the
  live FK graph). Read the relevant entries before changing a table's
  relationships, and add a new entry (with the same rigor — check it
  against the live catalog, don't hand-wave the connections) for any table
  you add. Put a new table in its group in `scripts/catalog_groups.py`, then
  run `python scripts/gen_catalog_diagrams.py` (ER diagrams + summaries; it
  fails if a table has no group) and `python scripts/check_table_catalog.py`.
- `SKILL.md` (companion to this file) — the step-by-step design-time gate
  Claude consults automatically before adding or changing any table,
  column, permission, or DPDP-relevant flow. This file states the rules;
  `SKILL.md` is the checklist version consulted while working.

---

## 2. Non-negotiables — stop and flag instead of proceeding

Claude does NOT do any of the following, even if asked directly. Instead,
explain why and propose the compliant alternative already described in
`SKILL.md`:

- Add a column/table that duplicates a fact already stored elsewhere
  (name, email, phone, DOB, designation copied instead of referenced by
  FK to `people.person` / `pii.person_*`).
- Store a value that's computable from other stored data (age, a display
  name, "is this the current one") instead of adding a view/function.
- Use a `jsonb` column or a native array for data that will be filtered,
  joined, or constrained on — that data gets a real child table.
- Use a Postgres `ENUM` or a free-text status column for a classification
  a human might extend later — that's a `ref.*` lookup table.
- Hard-code a policy value — a limit, a deadline, a required field, a
  scale, a points value, who must approve — in a function, trigger or
  `CHECK`. Policy is data an administrator can change: a column of the
  module's settings row (`events.event_setting`, `tms.helpdesk_setting`,
  `facility.booking_policy` …), a flag on a lookup, a dated row, or a chain
  row of the `wf` engine — with a named permission for who may change it
  and a smoke test that flips the value and shows the behaviour change.
  Only integrity rules (uniqueness, immutability, anonymity, separation of
  duties) are written into constraints.
- Store a password, OTP, recovery code, or refresh token anywhere except
  as a hash; store a reversible secret (TOTP seed, government-ID number)
  anywhere except application-level encrypted + a separate HMAC blind
  index — never plaintext.
- Grant `UPDATE`/`DELETE` on `audit.audit_event`/`audit.audit_change` to
  the application role — they are append-only by design (see
  `08_audit.sql`).
- Introduce a new personal-data column without registering it in
  `privacy.data_element` (this is what drives access-summary exports,
  erasure, and audit-trail redaction — skip it and all three silently
  miss the column).
- Hardcode a role/permission check (`if user.role == 'admin'`) instead of
  going through `authz.has_permission()` — roles and permissions in this
  design are data (`authz.role`, `authz.permission`,
  `authz.account_role`...), not a hardcoded enum. That hardcoded-enum
  pattern is the specific old-system bug (`UserLogin.role`) this database
  was built to replace; don't reintroduce it.

---

## 3. Database design — normalisation & single source of truth

Every duplicate copy of a personal-data field is a second place that can
drift out of sync, a second place to secure, and a second place someone
can forget to erase when a Data Principal exercises their erasure right.
Normalisation here is a security and compliance control, not just a
modelling nicety — see `SKILL.md` §1 for the full checklist before any
schema change. In short:

- **BCNF/4NF by default.** A fact about a person (name, email, phone, DOB,
  designation, enrollment number) lives in exactly one table keyed by that
  person's ID; every other table references it by foreign key.
- **No storing derivable data.** Age, display name, current
  affiliation/school, batch year, current semester, effective permissions
  — all views/functions (`pii.v_person_age`, `people.v_employee_current`,
  `academic.v_batch`, `academic.v_student_enrollment_current`,
  `academic.v_credit_ledger`, `exam.v_cgpa`,
  `authz.has_permission()`...), never persisted columns.
- **No storing the same fact under two names.** One column, one meaning.
- **Real foreign keys** (`REFERENCES ... ON DELETE ...`), the `ON DELETE`
  behaviour chosen deliberately per table — this is also the erasure
  implementation decision (§5).
- **Business history uses validity ranges + `EXCLUDE USING gist`**
  (`people.employee_assignment`, `org.appointment`,
  `people.employee_reporting_line`, `academic.student_enrollment`,
  `privacy.consent`...), so the database — not the application — rejects
  overlaps. Don't add a parallel `*_status_history` table for something an
  `EXCLUDE` constraint already prevents from going wrong.
- **Lookup tables, not enums**, for every closed value set
  (`ref.*` — 183 of them today). Adding a new valid value is a seed-data
  `INSERT`, not a migration that alters a type.
- **Schemas are security boundaries**: `ref, org, people, academic, exam, research, facility, tms, events, wf,
  pii, iam, authz, privacy, audit`. `pii` holds anything beyond a bare name —
  it is invisible to `intranet_analytics` and must stay that way.
- New schema objects get checked against this before being considered
  done: does this field already exist somewhere else under a different
  name/table? If yes, reference it instead of duplicating it.

---

## 4. Access control

- Permissions are `authz.permission` rows (`resource × action`, code
  derived as `module.resource.action`). Roles (`authz.role`) bundle
  permissions, can inherit other roles (`authz.role_inheritance`), and can
  conflict (`authz.role_conflict`, static separation of duties).
- Grants are always one of: an explicit, org-unit-scoped
  `authz.account_role` / `authz.account_permission`, or a **derived**
  grant from `authz.designation_role` / `authz.position_role` /
  `authz.principal_kind_role` — derived grants are resolved live in
  `authz.v_account_role_effective`, never copied onto the user. If you
  find yourself wanting to write role data directly onto an account
  record instead of a scoped grant or a derivation rule, stop — that's
  the old `applyRoleToUser`-style copy-and-drift bug this design avoids.
- Every authorization check is `authz.has_permission(account_id,
  'module.resource.action', target_org_unit_id)`, or
  `authz.accessible_org_units()` for list filtering. Don't write a new
  ad hoc permission check.
- **Approvals go through `wf`, and are configured, never developed**
  (`sql/06b_workflow.sql`). The engine is the base for every approval of the
  intranet: a module that needs one adds a `wf.approval_document_type` row,
  a `wf.approval_chain` with its `approval_chain_stage` rows, an
  `instance_id` on its document (validate trigger), and calls `wf.submit()` /
  `wf.act()` — it does **not** build its own approval / status / reviewer /
  delegation / escalation tables. Everything about a level is a column of
  the stage row: who approves (`ref.wf_approver_kind`: PERMISSION at an org
  level or the owning unit, POSITION holder, MANAGER of the person concerned,
  NAMED people, COMMITTEE quorum), how many, the amount band and flag it
  applies under, the self-approval rule (BLOCK / SKIP), required file /
  signature / checklist, forward and return-to, the deadline and its timeout
  action. A different path for a school / block / club is another chain
  scoped to that org unit — not a code branch. If a requested approval
  pattern cannot be expressed as stage configuration, extend the engine
  (a new column or lookup value, with tests in the engine section of
  `sql/99_smoke_test.sql`), never the module. A higher level may approve out
  of turn and pass the pending lower levels over — per chain
  (`allows_level_override`, `min_approved_levels`, default 2) and per level
  (`is_mandatory`); do not code a bypass. A stage never names a role. A
  scheduled job acts through a system action type
  (`ref.wf_action_type.is_system`: ESCALATE, AUTO_APPROVE, AUTO_REJECT) under
  `SET app.system_job = 'on'`, never with a borrowed human account.
- **Rooms and other physical resources are used through the `facility`
  ledger**: anything that occupies a room, an asset or a vehicle for a span
  is a source of `facility.room_hold` / `asset_hold` / `trip_allocation`
  (written by a trigger from the source table), not a separate booking
  table with its own clash check.

---

## 5. DPDP Act, 2023 — practical rules for this repository

The university is the **Data Fiduciary**; students, employees and
guardians are **Data Principals**. Full mapping in
`docs/dpdp-compliance.md`; the practical, schema-level rules:

- **Every personal-data column is registered** in `privacy.data_element`
  (category + erasure action). This is what makes an access-summary
  export, an erasure request, and audit redaction all work off one
  source of truth instead of a manual hunt across tables.
- **Purpose limitation**: personal data is collected against a stated
  `privacy.processing_purpose`, which carries a legal basis
  (`ref.legal_basis` — consent vs. legitimate use) and a retention period.
  Don't add a column "in case it's useful later."
- **Consent** is structured (`privacy.consent`: principal, notice,
  purpose, channel, timestamp, withdrawal), not a boolean flag, and can
  only reference a purpose the cited notice actually lists (DB-enforced
  composite FK to `privacy.notice_purpose`).
- **Children**: a principal under 18
  (`pii.v_person_age.is_minor`) needs verifiable guardian consent
  (`privacy.verifiable_parental_consent`) before consent-based processing
  — check `privacy.v_minor_consent_gap` rather than assuming an adult
  flow. No behavioural tracking or targeted advertising of children,
  full stop.
- **Rights** (access, correction, erasure, grievance, nomination, consent
  withdrawal) route through `privacy.data_principal_request` +
  `privacy.dpr_request_event`; status and overdue-ness are derived
  (`privacy.v_dpr_request_status`), never hand-set.
- **Retention & erasure**: `processing_purpose.retention_period`
  (currently POLICY placeholders pending legal/DPO sign-off, see
  `docs/dpdp-compliance.md`) and `data_element.erasure_action_id`
  (`DELETE`/`ANONYMISE`/`RETAIN_LEGAL`), with every erasure action written
  to `privacy.erasure_log`.
- **Processors**: a new third-party service touching personal data
  (email/SMS/storage/analytics vendor) is a `privacy.data_processor` row,
  flagged explicitly — not something that ships quietly as a dependency.
- **Breach readiness**: `privacy.breach_incident` /
  `breach_affected_person` / `breach_notification` exist for exactly this;
  any change that could plausibly leak personal data at scale gets called
  out in review, not just merged because it works.
- **Accountability**: `privacy.pii_access_log` records who read/exported
  whose personal data for which purpose; `audit.*` is the append-only,
  column-level change trail with personal-data values redacted to
  `[REDACTED]` unless the column is legally retained (`RETAIN_LEGAL` —
  marks, results; kept visible so tampering is traceable) (driven by `privacy.data_element`, so this happens
  automatically for any column registered there — see §2's non-negotiable
  about registering new PII columns).

---

## 6. Verifying a change

This repo has no CI configured yet, so verify locally against a real
PostgreSQL (16+; developed and tested against 17.6) before considering a
schema change done:

```bash
createdb intranet_check
for f in sql/0*.sql sql/1*.sql; do
  psql -d intranet_check -v ON_ERROR_STOP=1 -f "$f" || break
done
psql -d intranet_check -v ON_ERROR_STOP=1 -f sql/99_smoke_test.sql   # prints PASS lines; ends with ROLLBACK
psql -d intranet_check -v ON_ERROR_STOP=1 -f sql/98_tms_smoke_test.sql   # the helpdesk module's own tests
psql -d intranet_check -v ON_ERROR_STOP=1 -f sql/97_events_smoke_test.sql   # the clubs & events module's own tests
```

- Every constraint added to the schema needs a matching negative
  assertion in `sql/99_smoke_test.sql` (`pg_temp.rejects(...)`), and every
  new derived view/function needs a positive one (`pg_temp.ok(...)`).
  The file is self-contained and rolls back at the end — it never leaves
  data behind.
- Regenerate the dictionary after any schema change:
  ```bash
  psql -d intranet_check -f scripts/gen_data_dictionary.sql > /tmp/dict.tsv
  python scripts/gen_data_dictionary.py /tmp/dict.tsv docs/data-dictionary.md
  ```
- If you renumbered or added a numbered `sql/NN_*.sql` file, grep every
  `sql/*.sql` header comment for the old filename — several files
  cross-reference each other by name, and so do `README.md`/`docs/*.md`.
- Sanity-check privilege separation after a change touching `GRANT`s:
  ```bash
  psql -d intranet_check -c "SET ROLE intranet_analytics; SELECT count(*) FROM pii.person_email;"   -- must fail
  psql -d intranet_check -c "SET ROLE intranet_app; UPDATE audit.audit_event SET entity_table='x';"  -- must fail
  ```
- Drop `intranet_check` when done; nothing here depends on a
  long-lived local database.

---

## 7. These checks happen at design time, not as a final review

When a request involves a new table/column/migration, a new permission, or
any feature touching personal data, Claude works through the relevant
section of `SKILL.md` as part of *designing* the change, and says so in
the response (which table a field belongs in, which existing field it
references, what the DPDP purpose/legal-basis is) — rather than silently
deciding and only surfacing it if asked. Finding a normalisation, access-
control, or DPDP gap after the fact means reworking a foundation every
later module already depends on — much more expensive than getting it
right the first time.

If the answer to any check in `SKILL.md` is "no" or "not sure," Claude
says so before writing the schema, not after.
