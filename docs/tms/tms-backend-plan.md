# Helpdesk & grievance redressal (TMS) — backend implementation plan

**Status:** plan only. The work so far is the database; no backend exists yet.
This document describes how the Django backend for the `tms` module is to be
built on top of the database that already exists:
- `sql/12_tms.sql`: 24 tables, 20 `ref` lookups, 13 views, 39 functions;
- tested by `sql/98_tms_smoke_test.sql` (319 assertions);
- configured for SGT by `sql/91_example_tms_student_helpdesk.sql`.

**The old SGT UMS is a reference for how things flow, nothing more.** No code
is reused from it.

**Audience:** the backend team. Read these first:
- [`tms-design.md`](tms-design.md): what the module does, the flows, the
  policy table and the parity map with the old system;
- `docs/design.md` §7: the Django mapping;
- `docs/table-catalog.md` §14: the table-by-table reference.

The events module has a plan of the same shape
([`../events/events-backend-plan.md`](../events/events-backend-plan.md)).
The two share the foundations of phase 0.

---

## 1. Scope

The backend provides an HTTP API and background workers for everything the
database models:

| Area | What the backend exposes |
|---|---|
| Raising | category picker per domain; leaf details (required fields, help articles, declaration); raise with files, academic context and respondents; intake desk for walk-in / phone / e-mail / letter; assignee choice for staff who may |
| Working a ticket | reply, internal note, clarification, hold and release, consult another office, reassign, transfer, escalate, refer to a committee, resolve, close as not maintainable, merge |
| Requester's side | comment, answer a clarification, accept, reopen, rate, withdraw, escalate when overdue, refer, appeal, name a respondent, notice opt-outs |
| Committees | the committee inbox, case detail, clarification and hold, decision with the committee's resolution, forwarding to another committee, reporting the action taken |
| Lists and dashboards | my tickets, assigned to me, history, consultations, unit tickets, the unrouted queue, the solver dashboard with attention tiers |
| Reports | SLA, handler and category statistics, the grievance register and the yearly UGC / NAAC return |
| Knowledge base | articles for a leaf, anonymous "did this help?" |
| Administration | every row in `tms-design.md` §4.8: switches, calendar, SLA, categories, routes, handlers, owners, committees, notice rules, files, declarations, articles |
| Delivery | the notification outbox (in-app, e-mail, SMS) and the hourly scheduler |

**Out of scope here:**
- the frontend;
- managing committees, their members, meetings and resolutions — the
  academic-bodies app, used by TMS (§9.4);
- the org / people / appointment screens.

There is no data migration from the old UMS (§16).

---

## 2. Ground rules

These follow from how the database is built and are not negotiable in review.

1. **The database is the rule engine.** Every rule is enforced by a trigger
   or function and covered by a test: who may act, which event is allowed in
   which status, the route, deadlines, reopen limits, referral timing,
   confidentiality. The backend never re-implements a rule to "check first".
   It inserts and translates the refusal (§6.4).
2. **No status is stored, and no time is computed in Python.** These are all
   read from `tms.v_ticket_state` / `tms.v_ticket_sla`:
   - status, assignee, level, forum, clock, due time;
   - attention tier, closure reason, rating.

   Deadlines come from the database's office calendar. A `timedelta` added
   to a due time in Python is a defect.
3. **No policy value in code.** Every limit, window, hour count and switch is
   a column of `tms.helpdesk_setting`, a lookup flag or a configuration row.
   A constant such as "reopen within 7 days" in Python is a defect.
4. **No approval engine.** Tickets do not use `wf`. Committee decisions are
   `academic.body_resolution` rows of a quorate meeting, cited by the
   decision event.
5. **Who may do what is asked of the database**, never decided by role
   names:
   - `authz.has_permission()` for endpoints;
   - `tms.can_view()`, `tms.can_act()`, `tms.is_forum_member()`,
     `tms.can_report_compliance()` and `tms.can_download()` for objects;
   - `tms.available_actions()` for the buttons.
6. **No copied personal data.** Names, e-mail and phone are joined at read
   time, only for callers allowed to see them. Bulk reads are logged (§13).
7. **Confidential, anonymous and respondent rules hold in every response:**
   - a respondent never gets a ticket: 404, not 403;
   - an anonymous requester is masked unless `tms.requester_shown_to()`;
   - confidential tickets never appear in a list or export for someone
     outside them.

---

## 3. Stack

The same stack as the events module (decided on 2026-10-01 for the backend
as a whole):

| Concern | Choice |
|---|---|
| Framework | Django 5.x + Django REST Framework, `psycopg` 3 |
| Async work | Celery with Redis as broker; Celery beat for the scheduler (§11) |
| Cache | Redis (the `authz` permission cache) |
| Files | S3-compatible storage through `people.file_object` |
| Mail | the university's transactional mail provider behind a sender interface |
| SMS | an SMS provider behind a sender interface (urgent committee alerts) — to be named (§17) |
| API docs | OpenAPI generated from the DRF serializers |

---

## 4. What must exist before this module

| Needed from | What | Used for |
|---|---|---|
| `iam` app | login, sessions, `request.account_id` | every authenticated call |
| `authz` backend | `has_perm(code, org_unit)` over `authz.has_permission()`, cached effective permissions, `authz.accessible_org_units()` | endpoint checks, list scoping |
| request middleware | `SET LOCAL app.account_id / app.request_id / app.session_id / app.client_ip` | the audit trail |
| `org` / `people` read API | org tree, display names, the requester's own phones (`pii.person_phone`), employee search | pickers, names, the contact number |
| `academic` read API | the student's batches, terms, courses | the academic-context picker |
| files app | upload with type sniffing and virus scan → `people.file_object`; signed download URLs | attachments on any entry |
| academic-bodies app | committees, members, meetings, attendees, resolutions | committee decisions (§9.4) |
| notifications service | in-app delivery to an account | the outbox (§9.1) |
| privacy helper | `privacy.pii_access_log` rows | lists and exports with names |

TMS needs **no workflow app**: it can be built before the events module, or
alongside it. Only the academic-bodies app is required for committee
decisions; it is needed by phase 6.

---

## 5. Project layout

One Django app (`apps/helpdesk`, label `tms`), split by area:

```
apps/helpdesk/
  models/          unmanaged models, one file per catalog group:
                   config (settings, calendar, tree, owners, handlers, notice rules, files, channels),
                   routes_forums, tickets (ticket, context, respondent, event, file, notification),
                   knowledge_base
  views_ro/        read-only models over the 13 views (v_ticket_state, v_ticket_sla …)
  db/functions.py  one thin wrapper per tms.* function the API calls (§6.2)
  db/events.py     record_event(ticket, code, actor, **inputs) — the one way to write a timeline entry
  db/errors.py     SQLSTATE → API error mapping
  api/
    raise_/  tickets/  requester/  committee/  lists/  reports/  kb/  admin/  me/
  services/        orchestration only: raise-with-files, decide-with-resolution,
                   notification delivery, exports
  integrations/    mailer.py, sms.py, templates/ (one per event code and audience)
  tasks.py         Celery tasks (§11)
  permissions.py   DRF permission classes over authz + tms.can_view / can_act
  tests/
```

`services/` never contains a business rule. If a service needs an `if` about
who may do something or whether a value is allowed, the rule belongs in the
database, with a test in `sql/98`.

---

## 6. Data access

### 6.1 Models

- All models are `managed = False`. The SQL files are the source of truth; the
  backend ships no schema migration for `tms`.
- `search_path` includes `tms` (`docs/design.md` §7); table names are globally
  unique, so `Meta.db_table = "ticket_event"` works.
- `citext` columns are plain `CharField`s; ranges map to `DateRangeField`;
  `time` to `TimeField`.
- The 13 views get read-only models: `v_ticket_state`,
  `v_ticket_requester_timeline`, `v_ticket_sla`, `v_ticket_category`,
  `v_ticket_participant`, `v_ticket_consultation`, `v_ticket_unrouted`,
  `v_ticket_handler_stats`, `v_ticket_category_stats`,
  `v_ticket_category_rollup`, `v_grievance_register`, `v_grievance_summary`,
  `v_kb_article_stats`. Detail and list endpoints read the state from these,
  never from the base tables.

### 6.2 Function wrappers

| Group | Functions the API calls |
|---|---|
| Access | `can_view`, `can_act`, `is_forum_member`, `can_report_compliance`, `can_download`, `requester_shown_to`, `available_actions` |
| Routing (read only) | `eligible_assignees(leaf, requester)`, `next_escalation(ticket)` (a preview of who an escalation would reach), `forum_seat(forum, unit)` |
| Calendar | `helpdesk_calendar(from, to)`, `day_hours(date)` (the admin calendar screen) |
| Knowledge base | `kb_articles_for(leaf)` |
| System job | `run_scheduler(now, force)` |

The other functions are internal to the triggers and views, and are not
called by the API: the round-robin, route walking, the clock arithmetic and
the notice recipients.

### 6.3 Writes

There are only three kinds of write.

**1. Raising** inserts `tms.ticket` — never with a number, priority, route,
unit or date, which the trigger fills — together with these, in the same
transaction:
- `tms.ticket_academic_context` when the leaf's rule needs it;
- `tms.ticket_respondent` rows when the leaf allows them;
- `tms.ticket_event_file` rows on the `CREATED` event (read its id back after
  the insert).

**2. Every later action** is one insert into `tms.ticket_event`, through
`db/events.py`. Only the inputs that event takes are passed (Appendix A).
The trigger computes everything else:
- the next assignee, level or committee;
- the due time, and the minutes left when the clock is paused.

Files are attached in the same transaction.

**3. Configuration** is plain row edits on the configuration tables, plus
delivery updates on `tms.ticket_notification` by the sender (§9.1).

Two details matter:
- **Deferred checks.** Academic context (when required) and "a clarification
  needs a reply or a file" are checked at commit. Every write service ends
  with `SET CONSTRAINTS ALL IMMEDIATE`, so these refusals come back as a 422
  inside the request instead of a failed commit.
- **Double submissions.**
  - The `Idempotency-Key` header goes into `ticket.idempotency_key`. On a
    unique violation of `(requester, key)`, return the existing ticket with
    200.
  - Without a key, the database refuses the same requester, leaf and text
    within `duplicate_window_seconds` (`23505`, naming the original request
    number). Return 409 with the original ticket.

### 6.4 Error mapping

The database raises a specific SQLSTATE with a message written for people,
starting with the object name (`tms.ticket_event: …`). One handler maps them:

| SQLSTATE | Meaning in this schema | HTTP |
|---|---|---|
| `42501` insufficient_privilege | may not do this; the domain is switched off; a record is immutable | 403 (404 when the caller may not even see the ticket) |
| `23514` check_violation | a rule was not met (status, window, limit, missing input) | 422 |
| `23505` unique_violation | duplicate submission, same idempotency key, already exists | 409 |
| `23P01` exclusion_violation | overlap (two owners at once, two declarations in force) | 409 |
| `23503` foreign_key_violation | referenced row missing or still in use (deleting a used category) | 409 |
| `23502` not_null_violation | required input missing | 400 |
| `22000` data_exception | the calendar has no working day (configuration error) | 503, alert the administrators |

The database message is returned as the error detail. A stable machine code
is the object prefix plus the SQLSTATE (`tms.ticket_event/23514`), so the
frontend can branch without parsing prose.

### 6.5 Transactions and session variables

- `ATOMIC_REQUESTS = True`: one request, one transaction. Raise + context +
  respondents + files, or decide + resolution, happen together or not at all.
- The middleware sets `app.account_id`, `app.request_id`, `app.session_id`
  and `app.client_ip` with `SET LOCAL`.
- The scheduler and the notification sender set `SET LOCAL app.system_job =
  'on'` and never use a human account.
- Read the new state (`v_ticket_state`) in a separate statement after the
  write, never in the same statement.

---

## 7. API design

Base path `/api/v1/helpdesk`. JSON; cursor pagination; ISO-8601 times with
offset. Every response that shows a ticket carries `available_actions` (from
`tms.available_actions`). The frontend shows exactly those buttons — the old
system's front end and back end disagreed, and this ends that.

### 7.1 Raising

| Endpoint | Does |
|---|---|
| `GET /categories?domain=` | the active tree for the caller's domain; internal-only nodes hidden; labels per domain |
| `GET /categories/{leaf}` | what raising here needs: message types; relief required; incident date required; anonymous allowed; respondents allowed; academic-context rule; the declaration in force; `kb_articles_for(leaf)` |
| `GET /categories/{leaf}/assignees` | `eligible_assignees` — only for callers with `tms.employee_ticket.assign` |
| `POST /tickets` | raise (§6.3); body: leaf, message type, subject (optional), description, relief, incident date, anonymous, phone id, declaration id, file ids, academic context, respondent person ids, chosen assignee |
| `POST /intake/tickets` | the same, recorded by an intake desk for a requester, with the channel |
| `GET /me/phones` | the caller's own phone numbers to choose the contact from |

### 7.2 A ticket

| Endpoint | Does |
|---|---|
| `GET /tickets/{id}` | state from `v_ticket_state` + `v_ticket_sla`; the requester masked unless `requester_shown_to`; the level label or committee name instead of names for requesters; `available_actions` |
| `GET /tickets/{id}/timeline` | requester and followers: `v_ticket_requester_timeline`; everyone else who can view: the full timeline with actor names |
| `GET /files/{id}` | `can_download` → a short-lived signed URL |
| `POST /tickets/{id}/respondents` | name a person complained against |

### 7.3 Actions

One endpoint per action. Each maps to one event code (Appendix A) and accepts
only that event's inputs:

`reply`, `note`, `clarification/request`, `clarification/answer`, `hold`,
`hold/release`, `consult`, `consultations/{event}/answer`, `reassign`,
`transfer`, `escalate`, `refer`, `resolve`, `reject`, `merge`, `comment`,
`accept`, `reopen`, `rate`, `withdraw`, `appeal`, `decide`, `forward`,
`action-taken` — all under `POST /tickets/{id}/…`.

### 7.4 Committee workspace

| Endpoint | Does |
|---|---|
| `GET /committee/cases` | cases with the committees the caller sits on (current `academic_body_member`) or holds (Ombudsperson), from `v_ticket_state` |
| `POST /tickets/{id}/decide` | outcome, the order (remarks), signed order file, `body_resolution_id` — the meeting and resolution are created first in the academic-bodies app (§9.4) |
| `POST /tickets/{id}/forward` | to the committee's default next forum, or a named one, with the report |
| `POST /tickets/{id}/action-taken` | compliance report with evidence |

### 7.5 Lists

| Endpoint | Source |
|---|---|
| `GET /me/tickets` | `v_ticket_participant` (REQUESTER / RAISED_BY / FOLLOWER) |
| `GET /me/assigned` | `v_ticket_state.assignee_employee_id` = me |
| `GET /me/history` | `v_ticket_participant` (PAST_ASSIGNEE / ACTOR / CONSULTED) |
| `GET /me/consultations` | `v_ticket_consultation`, open first |
| `GET /units/{unit}/tickets` | supervisors: responsible or requester unit inside `accessible_org_units(…view)`, confidential excluded |
| `GET /admin/unrouted` | `v_ticket_unrouted` |

Filters: domain, status, attention, priority, category subtree, committee,
dates (end of day inclusive — an old bug). Sort fields are allowlisted.
`can_view` is applied to the page in SQL (§8).

### 7.6 Dashboards and reports

| Endpoint | Source | Permission |
|---|---|---|
| `GET /me/dashboard` | my open / overdue / paused / resolved, attention top 5, resolved today / week / month, trend — `v_ticket_state`, `v_ticket_sla` | any handler |
| `GET /reports/handlers`, `/reports/categories`, `/reports/rollup`, `/reports/sla` | the statistics views | `tms.analytics.view` (scoped) |
| `GET /reports/grievances` | `v_grievance_register` | `tms.grievance_register.view` |
| `GET /reports/grievances/return?year=` | `v_grievance_summary` — the UGC / NAAC return; CSV and XLSX export | `tms.grievance_register.view` |

### 7.7 Knowledge base

| Endpoint | Does |
|---|---|
| `GET /kb?leaf=` | `kb_articles_for(leaf)` |
| `POST /kb/{id}/feedback` | `{was_helpful}` — written without any account id; the request log omits the caller (§13) |
| `/admin/kb…` | articles CRUD with publication dates; `v_kb_article_stats` |

### 7.8 Administration

All endpoints here require `tms.config.update`. Every write sets
`updated_by_account_id` where the table has it, and is audited by the
database.

| Resource | Tables |
|---|---|
| settings | `helpdesk_setting` (PATCH; the deployment lock `student_tms_locked` is not exposed) |
| calendar | `helpdesk_weekday`, `helpdesk_day_override`, `helpdesk_closure_type`; preview `GET /admin/calendar?from=&to=` → `helpdesk_calendar` |
| SLA | `ref.tms_priority`; category SLA fields; route-level hours |
| categories | `ticket_category` tree (create, rename, reorder, deactivate; a move refused by the database is shown as such), owners (dated), handlers (bulk replace per leaf, optional unit scope) |
| routes | `ticket_route`, `ticket_route_level` |
| committees | `redressal_forum` (bodies and members in the academic-bodies app) |
| requester side | `helpdesk_declaration`, `ref.tms_message_type`, `ref.tms_grievance_head` |
| delivery | `ticket_notice_rule`, `helpdesk_channel`, `helpdesk_file_type` |

The `ref.tms_*` lookups go through the shared lookup admin API
(`core_admin.lookup.update`). The exceptions are those named above, which
helpdesk administrators maintain.

### 7.9 Me

`GET/PUT /me/notice-opt-outs` maps to `tms.notice_opt_out`. The screen says
which notices are mandatory and still arrive.

---

## 8. Authorisation

Three layers, all answered by the database:

1. **Endpoint permission.** A DRF class calls `has_perm(code, unit)`. The
   codes are:
   - `tms._module.access`;
   - `tms.student_ticket.create` / `.view` / `.update`, and the same for
     `employee_ticket`, plus `.assign`;
   - `tms.intake.create`;
   - `tms.confidential_ticket.view`, `tms.anonymous_identity.view`;
   - `tms.grievance_register.view`, `tms.config.update`,
     `tms.analytics.view`.
2. **Object rights.**
   - `can_view` to read a ticket. If it is false, answer 404 — this also
     hides that a confidential case or a complaint against the caller
     exists.
   - `can_act` / `is_forum_member` / `can_report_compliance` to act, and
     `can_download` for files.
3. **The trigger** has the last word. A request that passes 1 and 2 but
   breaks a rule is refused (§6.4).

**Lists** are narrowed first by a cheap predicate: participation, assignee,
committee membership, or the unit scope from `accessible_org_units`. Then
`can_view` is applied in SQL to the page (≤ 50 rows), never in Python over
everything.

**Roles** (seeded in `sql/12_tms.sql`): `TMS_STUDENT_REQUESTER` and
`TMS_EMPLOYEE_REQUESTER` (derived), `TMS_STAFF_REQUESTER`,
`TMS_UNIT_SUPERVISOR` (HEAD and DEAN appointments), `TMS_STUDENT_OVERSEER`
(DSW), `TMS_EMPLOYEE_OVERSEER`, `TMS_INTAKE_DESK`, `TMS_GRIEVANCE_CELL` and
`TMS_ADMIN`. The backend refers to permission codes only.

**Serializer rules:**
- **Anonymous ticket**: no requester name, no phone, no account id for
  anyone without `requester_shown_to`.
- **Requesters**: never see assignee names, internal notes, consultations or
  files of internal entries — the requester timeline view already excludes
  them; the serializer must not add them back.
- **Confidential ticket**: never in exports beyond the register's counts.

---

## 9. Integrations

### 9.1 Notification delivery (the outbox)

The database queues `tms.ticket_notification` rows: one per event ×
recipient × channel, already filtered by the rules, opt-outs and channel
switches. A Celery worker delivers them:

- pick `PENDING` and retryable `FAILED` rows with back-off;
- look up the address at send time: in-app → the notifications service; e-mail
  → the official e-mail in `pii`; SMS → the phone;
- render the template for the event code and audience. Requester templates
  never show assignee names; all user text is HTML-escaped (old bug #16);
- set `SENT` / `FAILED` (with `attempt_count` + 1 and the error) /
  `SKIPPED` (no address). The database turns a notice into `GAVE_UP` after
  `notice_max_attempts`;
- a final row is never touched again. A retry can never send twice, because
  the row is unique.

`FORUM_ACTION_OVERDUE` (an urgent case a committee has not acted on) is sent
first, ahead of the queue.

### 9.2 Mail and SMS

Each sits behind an interface (`send(to, subject, body)`, `send_sms(to,
text)`) with a fake for tests and one contract test per provider. Both
providers are data processors and must be registered in
`privacy.data_processor` before go-live (§13).

### 9.3 Files

Uploads go through the files app:
1. sniff the real type;
2. virus-scan;
3. record the MIME type and size on `people.file_object`;
4. attach in the same transaction as the entry.

The database refuses types not in `helpdesk_file_type`, files over
`max_file_bytes`, too many files, and a file belonging to another ticket.
Downloads are signed URLs issued after `can_download`.

### 9.4 Academic bodies (committee decisions)

A committee decides in a meeting. The decide screen:
1. creates or chooses the `academic.body_meeting` of that committee, with its
   attendees, in the academic-bodies app;
2. records the `academic.body_resolution` — the database checks the quorum;
3. records `FORUM_DECIDED` citing that resolution.

All three happen in one request when done from the case screen. A position
forum (the Ombudsperson) decides without a meeting.

### 9.5 Discipline

A ragging decision that leads to discipline is recorded by the discipline app
as an `academic.disciplinary_case`. The helpdesk links to it from the case
screen and does not manage it.

---

## 10. Notifications in short

| Produced by | Delivered by |
|---|---|
| the database, per notice rule, inside the transaction that records the event | the outbox worker (§9.1), after commit |

The backend sends **no** notice of its own for ticket events. A message the
rules do not cover is a new notice rule, not code.

---

## 11. Background jobs

| Job | Schedule | What it runs | Notes |
|---|---|---|---|
| Helpdesk scheduler | every 15 min (hourly is enough when only office hours count) | `tms.run_scheduler()` | system job; advisory-locked, so overlapping runs are harmless. It does auto-referral, escalation, overdue notices, hold release, compliance reminders, committee first-action alerts, clarification reminders / expiry and auto-close. `scheduler_office_hours_only` decides whether it acts at night |
| Catch-up after deploy | once at start | `tms.run_scheduler(now(), true)` | the old startup catch-up |
| Notice sender | continuous | §9.1 | urgent alerts first |
| Exports | on demand | grievance return, statistics | streamed; logged (§13) |

Every system job sets `app.system_job = 'on'` with `SET LOCAL` in its own
transaction, logs the counts it returns, and is safe to run twice.

---

## 12. Performance

| Hot spot | Approach |
|---|---|
| `v_ticket_state` (lateral subqueries per ticket) | lists filter the ticket ids first (§8) and join the view for the page only; detail reads one row. If a list is still slow at real volume, add a materialised view refreshed after each write in SQL — never a status column in Python |
| `can_view` per row | only on the page; the cheap predicates do the narrowing |
| Clock functions (`business_deadline`, `day_hours`) | called by the database per event, not per request; the calendar tables are tiny |
| Scheduler | one pass over open tickets; at university scale (tens of thousands of tickets a year) well under a minute; measure on a copy of real data |
| Raising at peak (results day, fee deadline) | one transaction per ticket; the per-year counter row serialises numbering briefly; respond fast, deliver notices after commit |
| Permission checks | the Redis-cached effective set |

Load-test raising and the assigned list against a copy of the database
before go-live.

---

## 13. Privacy and security

- **Purposes.** `HELPDESK` and `GRIEVANCE_REDRESSAL` (`sql/12_tms.sql`). Any
  list or export with other people's names writes one
  `privacy.pii_access_log` row: who, purpose, how many.
- **Confidential cases** (ragging, sexual harassment, discrimination) are
  logged on every view, not only in lists.
- **Respondents** get 404 on everything about the case, and are never
  notified. The backend must never "helpfully" tell someone they were named.
- **Anonymous requesters**: masked in every response, export and template.
  Notices still reach them (the database addresses them).
- **Knowledge-base feedback** is anonymous by construction. The request log
  for that endpoint omits the account and the IP beyond rate-limiting.
- **Analytics** connections use `intranet_analytics`. It sees the state and
  the statistics, never ticket text, timelines, respondents or the register.
- **Uploads**: type sniffing and virus scan before attaching; signed URLs;
  no public links.
- **Processors**: register the mail and SMS providers in
  `privacy.data_processor` with their purposes.
- **Erasure** is handled by the privacy app through `privacy.data_element`
  (ticket text anonymised, contact and files deleted, respondents and
  academic context retained under legal obligation). The helpdesk adds no
  erasure code of its own.
- **Rate limits**: raising per account per hour (configuration), on top of the
  database's duplicate guard; feedback per IP.

---

## 14. Testing

- **No mocked database.** API tests run against PostgreSQL built from
  `sql/0*.sql sql/1*.sql`, as in `CLAUDE.md` §6.
- **`sql/98` stays the authority on rules.** API tests check that each
  endpoint writes the right row or event, maps the refusal correctly, and
  returns the derived state.
- **For every endpoint:** the success path; one refusal per error class; a
  caller without the permission; for ticket endpoints, also a respondent (404)
  and an outsider on a confidential case (404).
- **Scenario tests mirroring `sql/98`:**
  - the student academic route (mentor → HOD → Dean → Dean Academics → VC);
  - resolve → reopen → refer to the SGRC → decision with a quorate
    resolution → appeal to the Ombudsperson → action taken;
  - ragging to the squad → late-action alert → forward to the committee;
  - intake desk;
  - merge with followers;
  - clarification expiry;
  - holds and consultations.
- **Time-dependent behaviour** is tested by calling `tms.run_scheduler(p_now,
  true)` with a chosen instant, never by sleeping or faking the clock in
  Python.
- **Contract tests**: the outbox sender against a fake mailer / SMS gateway;
  one sandbox test per real provider.
- **Concurrency**: two raises with the same idempotency key; two handlers
  acting on one ticket (the row lock serialises them); two scheduler runs at
  once (one returns at once).
- **A CI check** that no module code contains a role name, an event-status
  literal used as a rule, or a literal limit that exists in
  `helpdesk_setting`.

---

## 15. Delivery phases

Each phase ends with something usable. Sizes are relative (S / M / L).

| # | Phase | Delivers | Depends on | Size |
|---|---|---|---|---|
| 0 | Foundations | project skeleton (shared with events if not yet built), unmanaged models and view models, function wrappers, `record_event`, error mapping, permission classes, middleware, test database fixture | iam, authz | M (S if events built it) |
| 1 | Administration | settings, calendar with preview, priorities and category SLA, category tree, owners, handlers, routes, committees, declarations, notice rules, file types, channels | 0 | L |
| 2 | Raising and the ticket | category picker, leaf details, raise with files / context / respondents, intake desk, ticket detail with masking and available actions, timelines, downloads | 1, files app | M |
| 3 | Handling | reply, note, clarification, hold, consult, reassign, transfer, escalate, resolve, reject, merge; assigned / history / consultation lists; assignee search | 2 | L |
| 4 | Requester's side | comment, answer, accept, reopen, rate, withdraw, escalate when overdue, refer, appeal, respondents, opt-outs | 2 | M |
| 5 | Delivery and scheduler | outbox worker (in-app, e-mail, SMS), templates, the scheduler job and catch-up | 2, mail / SMS providers | M |
| 6 | Committees | committee inbox and case screen, decide with meeting and resolution, forward, action taken, register | 3, academic-bodies app | M |
| 7 | Reports and dashboards | solver dashboard with attention, unit lists, statistics, SLA, grievance register and the yearly return export | 3 | M |
| 8 | Knowledge base | articles admin, the raise-screen panel, anonymous feedback, deflection report | 1 | S |
| 9 | Hardening | load tests, security and DPO review (confidential, anonymous, respondents), runbooks, monitoring of the scheduler and the outbox | all | M |

Phases 3 and 4 can run in parallel after 2; phases 6, 7 and 8 are
independent of each other.

**Definition of done for a phase:**
- endpoints documented in OpenAPI;
- API tests green against a freshly built database;
- no rule duplicated in Python;
- lists with names write the access log;
- `available_actions` drives every button on its screens;
- the matching scenario of `sql/98` can be replayed through the API.

---

## 16. Go-live: configuration, not migration

Nothing is migrated from the old UMS: no tickets, timelines, ratings or
numbers (default, §17). The new system starts empty, and request numbers start
at TMS-YYYY-00001. Go-live is configuration, owned by the university:

| Step | What | Who |
|---|---|---|
| 1 | org structure, appointments (HOD, Dean, Dean Academics, Registrar, VC, DSW, Ombudsperson), mentors | Registrar / HR |
| 2 | committees and members: SGRC (one or per school), ICC, Anti-Ragging Squad and Committee, Equal Opportunity Cell, SC / ST Cell | Registrar / IQAC |
| 3 | the student category tree (start from `sql/91_example_tms_student_helpdesk.sql`) and the employee KRA tree | Helpdesk admin |
| 4 | handlers and owners per category; routes (the academic path is seeded); fixed-office levels for the employee ladder | Helpdesk admin |
| 5 | SLA per category; priority defaults; the calendar (weekdays, hours, holidays counted or not, dated overrides) | Helpdesk admin / IQAC |
| 6 | the declaration text, help articles, notice templates, file types | Helpdesk admin / DSW |
| 7 | POLICY values confirmed (time limits, windows, retention — `tms-design.md` §5 and §14) | Registrar / IQAC / legal / DPO |
| 8 | switches: Employee TMS on; Student TMS on when ready; scheduler office hours or round the clock | Helpdesk admin |

---

## 17. Decisions

Decided (2026-10-01):

| # | Decision | Outcome |
|---|---|---|
| 1 | Stack | Django, DRF, Celery, Redis — shared with the events module |
| 2 | Requesters | current students and employees only (no guardians, applicants or alumni) |
| 3 | Student side | UGC (Redress of Grievances of Students) Regulations, 2023: helpdesk first, then the SGRC, then the Ombudsperson; statutory committees for ragging, sexual harassment and discrimination |
| 4 | Academic path | mentor → HOD → Dean of the school → Dean Academics → VC |
| 5 | Urgency | harassment and ragging are URGENT and handled by the respective committees, with first-action alerts |
| 6 | SLA | category by category, defined by SGT; priority hours as the default |
| 7 | Configuration | everything from the admin side, including counting non-working hours and holidays |
| 8 | Approvals | tickets do not use the `wf` engine; committee decisions are resolutions |

Still open — the plan proceeds on the default until settled:

| # | Decision | Default |
|---|---|---|
| 9 | Data from the old UMS | none; the old system stays read-only as an archive |
| 10 | Mail provider and sending domain | to be named (shared with events) |
| 11 | SMS provider | to be named; until then urgent alerts go by e-mail and in-app only |
| 12 | Who holds `TMS_ADMIN`, the intake desks and the grievance cell at go-live | to be named by the university |
| 13 | POLICY values | as seeded, flagged in `tms-design.md` |

---

## 18. Risks

| Risk | Mitigation |
|---|---|
| Rules or deadlines re-implemented in Python drift from the database | ground rules §2; CI check; refusals returned as they are |
| A confidential case or a complaint leaks to the wrong person | 404 for anyone `can_view` refuses; serializer rules; tests with respondents and outsiders; DPO review in phase 9 |
| An urgent committee alert is delayed | the scheduler every 15 min and round the clock where configured; urgent alerts first in the outbox; monitoring on both |
| The academic-bodies app is not ready for committee decisions | phase 6 waits for it; until then committees can reply, hold, consult and forward, but not decide |
| Lists slow at volume because of the derived state | page-first querying; a materialised view in SQL if measured necessary |
| The calendar misconfigured (no working day) | the database refuses with `22000`; the admin calendar preview shows the effect before saving |
| Schema changes while the backend is being built | the SQL files are the contract; unmanaged models regenerated; API tests on every schema change |

---

## Appendix A — events, endpoints and inputs

| Event code | Endpoint (`POST /tickets/{id}/…`) | Who (database rule) | Inputs |
|---|---|---|---|
| `CREATED` | `POST /tickets`, `POST /intake/tickets` | requester / intake desk | the ticket (§7.1) |
| `REPLIED` | `reply` | can act | remarks, files |
| `REMARKED` | `note` | can act | remarks, files |
| `REQUESTER_COMMENTED` | `comment` | requester | remarks, files |
| `CLARIFICATION_REQUESTED` | `clarification/request` | can act | remarks |
| `CLARIFICATION_PROVIDED` | `clarification/answer` | requester | remarks and / or files |
| `PUT_ON_HOLD` | `hold` | can act | hold reason, remarks, files |
| `HOLD_RELEASED` | `hold/release` | can act | remarks |
| `CONSULTATION_REQUESTED` | `consult` | can act | employee, question, files |
| `CONSULTATION_ANSWERED` | `consultations/{event}/answer` | the person consulted | remarks and / or files |
| `REASSIGNED` | `reassign` | can act | employee, remarks |
| `TRANSFERRED` | `transfer` | can act | leaf, remarks |
| `ESCALATED` | `escalate` | can act; requester when overdue | remarks |
| `REFERRED` | `refer` | requester (when allowed); can act (any committee) | remarks, committee (handling side only), files |
| `APPEALED` | `appeal` | requester | remarks, files |
| `FORUM_DECIDED` | `decide` | committee member / holder | outcome, remarks (the order), resolution, files |
| `FORUM_FORWARDED` | `forward` | committee member | remarks (the report), committee (optional), files |
| `ACTION_TAKEN` | `action-taken` | committee member, last handler, update permission | remarks, files |
| `RESOLVED` | `resolve` | can act (not the requester) | remarks, files |
| `REJECTED` | `reject` | can act (not the requester) | remarks |
| `MERGED` | `merge` | can act | the surviving ticket, remarks |
| `CONFIRMED` | `accept` | requester | — |
| `REOPENED` | `reopen` | requester | remarks, files |
| `WITHDRAWN` | `withdraw` | requester | remarks |
| `RATED` | `rate` | requester | rating 1–5, remarks |
| `RECUSED` | — (recorded by the database when the assignee is named as respondent) | — | — |
| `AUTO_ESCALATED`, `ESCALATION_EXHAUSTED`, `OVERDUE_NOTICE`, `AUTO_REFERRED`, `HOLD_EXPIRED`, `COMPLIANCE_REMINDER`, `FORUM_ACTION_OVERDUE`, `CLARIFICATION_REMINDER`, `CLARIFICATION_EXPIRED`, `AUTO_CLOSED` | — (the scheduler) | system job | — |

The trigger fills everything else: the assignee, level, committee, due time,
minutes left and the occurred-at time. The backend never sends them.
