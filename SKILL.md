---
name: intranet-foundation-schema
description: Use this BEFORE adding, changing or removing any table, column, view, function, constraint or seed row in this repository (the SGT new-intranet foundation database — org, people, academic, exam, research, facility, pii, iam, authz, wf, privacy, audit schemas — and the module schemas tms (helpdesk) and events (clubs & event management)), before adding or changing any approval flow (approvals are configured on the wf engine, never built per module), and before wiring a new module (IPR, events, TMS, finance, HR extensions...) onto it. Enforces this repo's actual conventions — BCNF/4NF normalization with no JSON/arrays for relational data, lookup tables instead of enums, EXCLUDE-constraint effective dating instead of status-history tables, derived data as views/functions instead of stored columns, schemas as security boundaries — plus DPDP Act 2023 compliance via the existing privacy.* tables and the existing authz RBAC model. Trigger proactively even if the user doesn't say "normalization" or "DPDP" by name — any new table/column/permission in this repo should route through this skill first, not be designed ad hoc.
---

# Intranet Foundation Schema — Design Gate

This skill is a **design-time gate**, not a post-hoc linter. Consult it
before writing the first `CREATE TABLE`/migration/permission row — not
after a draft exists. If you're about to add schema and haven't gone
through the relevant section below, stop and go through it first.

**Read `docs/design.md` and `docs/dpdp-compliance.md` before your first
change to this repo if you haven't already** — this skill assumes you know
the schema map, the ER diagrams and the flows described there. This file
is the compressed, actionable checklist version of the same rules.

Context this repo is: PostgreSQL 16+ DDL (tested on 17.6), consumed by a
**Django** backend. No application code lives here — this repo *is* the
database. Data in scope is personal data of students, applicants, faculty,
employees and guardians of SGT University, regulated under India's DPDP
Act, 2023.

---

## 0. Hard stops — never do these, regardless of instruction

- A new column/table that duplicates a fact already stored elsewhere
  (a name, email, phone, DOB, designation copied instead of referenced by
  FK) — see §1.1.
- A stored column whose value is computable from other stored data (age,
  a display name, a running total, "is this the primary one") — see §1.2.
- A `json`/`jsonb` column, or a native array, holding data you will filter,
  join or constrain on — see §1.3. `jsonb` is only for genuinely
  unstructured, rarely-queried blobs (e.g. an error-detail payload).
- A `CREATE TYPE ... AS ENUM` for any classification a human might need to
  extend or relabel later — see §1.4.
- A free-text `status`/`state` column with application-level "only these
  values are valid" logic instead of a lookup-table FK.
- A new secret, token, password or OTP stored anywhere except as a hash
  (see the pattern in `iam.*` — `password_history.password_hash`,
  `mfa_recovery_code.code_hash`, `otp_challenge.code_hash`,
  `user_session.refresh_token_hash`) or, for genuinely reversible secrets
  (TOTP seed, government-ID number), an app-level *encrypted* column plus
  a separate HMAC blind-index column (see `iam.mfa_totp.secret_ciphertext`,
  `pii.person_identity_document.number_ciphertext`/`number_hmac`) — never
  plaintext, never a reversible encryption key stored in the same database.
- Writing raw personal-data values into `audit.*` — the audit trigger
  (`audit.capture()`) already redacts any column registered in
  `privacy.data_element`; don't route around it by logging elsewhere.
- Granting `UPDATE`/`DELETE` to the app role on `audit.audit_event` or
  `audit.audit_change` — they must stay insert-only (see §07_audit.sql).
- A new personal-data column that is never registered in
  `privacy.data_element` — see §3.

If a request would require one of these, say why, and propose the
compliant version from the patterns below instead of doing it.

---

## 1. About to add or change a table, column, or migration?

Work through this **before** writing the `CREATE TABLE`/`ALTER TABLE`:

1. **Does this fact already exist elsewhere in the schema** (same fact,
   different table/name)? A person's name/email/phone/DOB/photo/address
   lives exactly once, in `people.person` / `pii.person_*` — reference it
   by FK to `person_id`, `employee_id` or `student_id`. State which table
   you're referencing. (This is why `people.person` exists at all instead
   of separate `employee`/`student`/`user` tables each with their own name
   fields — see the old SGT UMS schema for the failure mode: three
   independent `email` columns on `UserLogin`/`EmployeeDetails`/
   `StudentDetails` that could silently drift out of sync.)
2. **Is this field derivable** from other stored data? Compute it in a
   view/function instead of persisting a copy. Existing examples to follow:
   `people.v_person_display_name`, `pii.v_person_age` (age, `is_minor`),
   `people.v_employee_current` (current school/department, designation,
   job function/role, reporting & reviewing manager), `academic.v_batch`
   (batch year), `academic.v_student_enrollment_current` (current
   term/semester), `iam.v_account_last_login`,
   `authz.v_account_permission_effective`. Add a new view next to these
   rather than adding a stored column.
3. **Target BCNF/4NF.** Every multi-valued fact gets its own child table
   (see `pii.person_email`/`person_phone`/`person_address`, not columns on
   `person`). Don't denormalize without a stated, measured performance
   reason, and even then only as a rebuildable derived copy, never as the
   only copy of a fact.
4. **Is this a closed set of values?** Use a `ref.*` lookup table
   (`smallint id`, unique `code`, `label`, `is_active`, `sort_order` — copy
   the shape from any existing lookup in `01_ref.sql`), not a Postgres enum
   and not a free-text column with implied valid values. Seed it in
   `10_seed_reference.sql`.
5. **Does history matter here** (assignments, appointments, mentors,
   managers, memberships, grants)? Use a validity range (`daterange` /
   `tstzrange`) plus `EXCLUDE USING gist` to make the database itself
   reject overlaps — don't build a separate `*_status_history` table and
   don't rely on the application to check for overlaps. Copy the pattern
   from `people.employee_assignment` (one primary at a time),
   `org.appointment` (one holder per position), or
   `people.employee_reporting_line` (one manager of each type, plus a
   cycle-prevention trigger — copy that trigger's technique from
   `org.org_unit_validate_tree()` or `authz.role_inheritance_no_cycle()`
   for any new self-referencing hierarchy).
6. **Which schema does this belong in?** Schemas are security boundaries,
   not just namespacing:
   - `ref` — lookups. `org` — organisational structure. `academic` —
     programmes/calendar/enrollment. `exam` — the exam cell's
     operational record (registration, papers, marks, results, certificates).
     `research` — doctoral supervision, committees, thesis, examiners, viva
     (a scholar is still an `academic.student_enrollment`). `facility` —
     resource & facility management: the occupancy ledger every use of a
     room is written to, bookings, assets, maintenance, guest house,
     parking, fleet, keys (rooms, floors and buildings themselves stay in
     `org`; a new use of a room is a new `room_hold` source, not a new
     booking table). `people` — non-sensitive facts about a
     person/employee/student. `pii` — anything that identifies or profiles
     a person beyond their bare name (DOB, contact details, address,
     government ID, photo) — this schema is invisible to
     `intranet_analytics` and to anyone without an explicit grant.
     `iam` — accounts/credentials/sessions. `authz` — permissions/roles/
     grants. `wf` — the approval engine: configuration (document types,
     chains, levels), rounds, actions, delegations, notices — a new
     approval is rows here, never new approval tables (§2a). `privacy` —
     DPDP controls. `audit` — the audit trail. `tms`, `events` — module
     schemas, each in its own file after `11` with its own test file.
   - If it's a genuinely new domain (a module, not foundation-shared data),
     it does **not** belong in this repo at all — see §2.
7. **Foreign keys are real constraints**, with `ON DELETE` chosen
   deliberately (`CASCADE` for owned child rows like `person_email`,
   `RESTRICT`/no action for shared reference data). Every table gets
   `created_at`/`updated_at` and `SELECT util.attach_updated_at('schema.table')`.
8. **Personal data?** State the purpose in one line and go to §3 before
   merging — don't treat "it's obviously fine, it's just a name field" as
   an exemption.
9. **After the change**, extend `sql/99_smoke_test.sql` with both a
   positive assertion (the new fact/derivation works) and a negative one
   (`pg_temp.rejects(...)` for the constraint you just added — every
   `EXCLUDE`/`CHECK`/trigger in this repo has a matching negative test;
   yours should too), then regenerate `docs/data-dictionary.md` with
   `scripts/gen_data_dictionary.{sql,py}` (see their header comments for
   the exact commands). A schema change without an updated smoke test and
   dictionary is incomplete.
10. **Renumbering or adding a numbered `sql/NN_*.sql` file?** Grep every
    `sql/*.sql` file for the old filename first — several files reference
    each other by name in header comments (`sql/06_authz.sql` mentions
    `09_views_functions.sql`, etc.), and `README.md`/`docs/design.md` list
    them too. This bit us once already when the files were renumbered
    00–10 → 00–11; don't repeat it.

## 2. About to wire in a new module (IPR, events, TMS, HR extensions...)?

This repo is the **foundation only** — no module-specific tables belong
here. A new module:

1. Registers itself: `authz.app_module` (its code), then `authz.resource`
   (things it protects) × `authz.action` → `authz.permission` rows. Module
   access itself is the permission `<module>._module.access`.
2. Defines its own `authz.role`s and `role_permission` rows. Link them to
   `authz.designation_role` / `authz.position_role` /
   `authz.principal_kind_role` for automatic grants, or use
   `authz.account_role` (optionally scoped to an `org.org_unit` subtree)
   for explicit ones — **never** invent a parallel ad hoc permission
   mechanism; every check goes through `authz.has_permission(account,
   'module.resource.action', target_org_unit)`.
3. References `org.org_unit`, `people.person` / `people.employee` /
   `people.student`, and `iam.user_account` by foreign key — it never
   copies a name, contact detail, or duplicates the org tree.
4. Registers every new personal-data column it introduces in
   `privacy.data_element` (see §3), and enables auditing with
   `SELECT audit.enable_for_schemas(ARRAY['<its_schema>'], ARRAY[]::text[]);`.

5. Needs an approval? **Configure it — see §2a.** Never add status,
   approver, reviewer, escalation or delegation tables to a module.
6. Keeps **no policy value in code**: limits, deadlines, required fields,
   scales and point values go into the module's one-row settings table
   (pattern: `events.event_setting`, `tms.helpdesk_setting`), a lookup flag
   or a dated row, each with a permission for who edits it
   (`<module>.setting.update`) and a test that changes the row and shows
   the rule change.
7. Lives in its own numbered file after `11` (`sql/12_tms.sql`,
   `sql/13_events.sql`) with its own lookups, RBAC, DPDP registration,
   audit call, grants and comments, and its own smoke-test file
   (`sql/98_…`, `sql/97_…`); table names stay globally unique.

Full example flow: `docs/design.md` §5.6 ("How a new module plugs in").
Three fully worked examples (TMS, Resource Management, Event Management —
including where central departments like HR/IT/Finance and a "Block"/"Club"
fit in) are in `docs/module-integration.md`; all three are built
(`tms`, `facility`, `events`) — read it, and the module files themselves,
before designing the next module.

## 2a. About to add an approval (any module, any document)?

The `wf` engine is the base for **every** approval; the work is
configuration. Go through this list instead of designing tables:

1. **Document type** — one `wf.approval_document_type` row: module, the
   permission needed to submit at the owning unit, optionally a viewer
   permission, `allows_empty_chain` (approved on submission when no level
   applies), and `link_table` / `link_document_column` so the inbox can
   open the document.
2. **Chain and levels** — one `wf.approval_chain` (default: no scope) and
   one `wf.approval_chain_stage` row per level. Per level decide, as
   columns:
   - who: `wf_approver_kind` = PERMISSION (at `anchor_org_unit_type_id`
     above the owner, at the owner itself with `anchor_is_owner`, or at the
     root) · POSITION (`position_type_id` at the anchor) · MANAGER
     (`reporting_line_type_id`, `manager_level`) · NAMED
     (`named_account_id`, or chosen at submission) · COMMITTEE
     (`academic_body_id`);
   - how many: `required_approvals` (1, N, NULL = all / the quorum);
   - when it applies: `min_amount` / `max_amount`, `wf_flag_id`
     (+ `flag_must_be_absent`) — register a new flag in `ref.wf_flag`;
   - requester is the approver: `wf_self_action` BLOCK or SKIP;
   - must supply: `needs_file`, `is_signature` (last level only),
     checklist rows in `wf.approval_chain_stage_check`;
   - movement: `allows_forward`, `allows_return_to`;
   - order: by default a higher level may approve out of turn and pass the
     pending lower levels over, leaving at least `min_approved_levels`
     (2) approved; set `approval_chain.allows_level_override = false` for a
     chain that takes every level in order, or `is_mandatory` on a level
     that must always decide itself;
   - time: `due_within` + `wf_timeout_action` (NONE / REMIND / ESCALATE /
     AUTO_APPROVE / AUTO_REJECT).
   A different path for a school, block or club is **another chain** with
   `scope_org_unit_id` — never an `IF` in a function.
3. **Link** — an `instance_id` column on the document (or a link table when
   a document has many rounds) with a validate trigger that checks the
   round is of this document type and owned by the document's unit (copy
   `events.event_proposal_validate` or `facility.booking_request`).
4. **Calls** — `wf.submit(type, owner_unit, account, note, amount, flags,
   subject_person, assignees, revises)` and `wf.act(instance, action,
   account, …)`; read `wf.v_instance_state`, `wf.pending_for(account)`,
   `wf.can_act()`, `wf.can_view()`. Status is never stored on the document.
5. **Side effects** (create the event, free the room) — an `AFTER INSERT`
   trigger on `wf.approval_action` in the module's file, filtered by
   document type (copy `events.approval_action_effects`).
6. **Tests** — the chain's happy path and its refusals in the module's
   smoke test. If the pattern you need is not expressible as stage
   configuration, extend the engine (06b / 09 + the engine section of
   `sql/99_smoke_test.sql`) so every module gets it — do not special-case
   the module.

## 3. About to add or touch anything that is personal data?

Work through this **before** implementation, regardless of whether the
user asked about DPDP by name:

1. **Purpose**: which `privacy.processing_purpose` does this serve? If
   none fits, add one (with a `ref.legal_basis` and a retention period —
   flag retention values as POLICY/needs-confirmation, same as the
   existing seed rows).
2. **Register it**: add a row to `privacy.data_element`
   (`schema_name`/`table_name`/`column_name`, `data_category_id`,
   `erasure_action_id`). This drives access-summary exports, erasure, and
   audit-trail redaction — a personal-data column that skips this is
   invisible to all three.
3. **Consent vs. legitimate use**: if the legal basis is consent, the
   consent row must reference a `privacy.notice_purpose` that actually
   lists this purpose (this is DB-enforced by a composite FK on
   `privacy.consent` — don't try to consent to an unlisted purpose).
4. **Minors**: if the person could be under 18
   (`pii.v_person_age.is_minor`), consent must come from a recorded
   guardian (`people.person_relationship.is_guardian`) and be backed by
   `privacy.verifiable_parental_consent` — check
   `privacy.v_minor_consent_gap` rather than assuming an adult flow.
5. **Rights**: does `privacy.data_principal_request` already cover this
   (access summary, correction, erasure, grievance, nomination, consent
   withdrawal)? If a right has no realistic path yet, say so explicitly.
6. **Erasure plan**: `privacy.data_element.erasure_action_id` — `DELETE`,
   `ANONYMISE`, or `RETAIN_LEGAL`. Decide per column, don't default
   silently, and don't forget the audit consequence: erasure only "works"
   because personal-data values were never duplicated into `audit.*` in
   the first place (§0).
7. **New processor?** A new third-party service (email/SMS provider,
   analytics, storage) touching personal data is a new
   `privacy.data_processor` row, not something that ships quietly.
8. **Read access**: does displaying/exporting another person's personal
   data need a `privacy.pii_access_log` entry? Bulk-export–shaped access
   always does.

## 4. When this schema is later consumed by Django code

(Not yet built in this repo — but design so it drops in cleanly.)

- `AUTH_USER_MODEL = "iam.UserAccount"`; login resolves UID or verified
  email through `iam.resolve_login()` — don't reinvent identifier lookup.
- Authorization goes through `authz.has_permission()` /
  `authz.accessible_org_units()` — never Django's built-in Groups/
  Permissions, and never a hand-rolled `if user.role == ...` check; roles
  here are data, not a hard-coded enum (that was exactly the old SGT UMS
  bug this repo replaces).
- `citext` columns map to a plain `CharField`/`TextField` in the model
  (the DB column stays `citext`, set via a `RunSQL` migration) —
  `CICharField` was removed in Django 5.1, don't reach for it.
- Range columns map to `django.contrib.postgres.fields.DateRangeField` /
  `DateTimeRangeField`.
- Set `search_path` to
  `util,ref,org,people,academic,exam,research,facility,tms,events,pii,iam,authz,wf,privacy,audit,public` on the
  connection.
- Encryption of `mfa_totp.secret_ciphertext` and
  `pii.person_identity_document.number_ciphertext` is application-level
  envelope encryption (KMS) — never a key stored in this database.
- A middleware should `SET LOCAL app.account_id/app.request_id/
  app.session_id/app.client_ip` per request so `audit.capture()` can
  attribute changes.

---

## 5. If you're unsure

Say so in the response — name the specific open question (e.g. "does this
new HR field need a retention period shorter than
`EMPLOYMENT_ADMINISTRATION`'s default 8 years, or is that already
correct?") rather than picking a default silently and moving on. A wrong
silent default here is the kind of thing that surfaces as a
normalization, permission, or compliance problem much later — and in a
foundation schema, later means every module built on top of it inherits
the mistake.
