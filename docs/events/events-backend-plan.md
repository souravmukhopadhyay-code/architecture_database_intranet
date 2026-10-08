# Events & Clubs — backend implementation plan

**Status:** plan only, for later. The current work is the database alone; no
backend exists and none is being built now. This document describes how the
Django backend for the `events` module should be implemented, when that work
starts, on top of the database that already exists (`sql/13_events.sql`, 74
tables, 48 functions, 29 views, tested by `sql/97_events_smoke_test.sql`).

**The old SGT UMS is a reference for how things flow, nothing more.** No data
is pulled from it and nothing in it is changed.

**Audience:** the backend team. Read `docs/design.md` §4.1j (approval engine),
§4.1k (events) and §7 (Django mapping) first; the table-by-table reference is
`docs/table-catalog.md` §15.

---

## 1. Scope

In scope — an HTTP API and background workers for everything the database
models:

| Area | What the backend exposes |
|---|---|
| Clubs | directory, founding proposals, members and applications, suspensions, yearly calendar, change requests, primary club, points and leaderboard |
| Event proposals | drafts with all their parts, submission, revision, sponsors, venue and vehicle requests |
| Approvals | inbox, decisions, comments, consultations, delegation — through the shared workflow API |
| Events | organiser settings, rounds, FAQs, links, extra questions, publish / complete / cancel |
| Taking part | registration, waiting list, guests, tickets (QR), teams |
| Gate | scan preview, scan in / out, attendance import, volunteer assignment, sign-up and dashboard |
| Money | coupons, online and offline payments, refund queue, expiry of unpaid registrations |
| After the event | prizes, certificates and public verification, anonymous feedback, report, duty leave |
| Messages | bulk mail with audiences, scheduling and credits |
| Stalls | fees, applications, stalls, public feedback |
| Administration | module settings, points and tiers, dashboards |

Out of scope here: the frontend, and the approval-chain administration screens
(they belong to the workflow app and serve every module). There is no data
migration from the old UMS (§17).

---

## 2. Ground rules

These follow from how the database is built and are not negotiable in review.

1. **The database is the rule engine.** Every business rule — who may propose,
   seat limits, payment amounts, who may scan, what may be edited when — is
   enforced by a trigger or function and covered by a test. The backend never
   re-implements a rule to "check first". It calls the database and translates
   the refusal (§6.4).
2. **No status is stored.** Club, proposal, event, registration, team, mail and
   payment states are read from views (`v_club`, `v_proposal_status`,
   `v_event`, `v_registration`, `v_team`, `v_event_mail`, `v_refund_queue` …).
   The backend never caches a status in its own table or sets one.
3. **No policy value in code.** Limits, deadlines, scales and required fields
   come from `events.event_setting`, lookup flags, dated rows and approval
   chain rows. A constant such as "max 20 guests" in Python is a defect.
4. **No approval logic.** Proposals and club changes are documents on the `wf`
   engine. The backend calls `events.submit_*()` and the workflow API; it never
   decides who approves or what the next level is.
5. **No copied personal data.** The module's tables hold references to
   `people.person`. Names, e-mail and phone are joined at read time, only for
   callers allowed to see them, and bulk reads are logged (§13).
6. **Secrets stay out of the database in usable form.** Ticket and feedback
   tokens are returned once by the database and stored only as hashes; gateway
   keys and webhook secrets live in the secret manager.
7. **Permissions go through `authz.has_permission()`** (and the module's own
   `events.can_manage()`, `events.can_see()`), never through a role name in
   code.

---

## 3. Stack

`docs/design.md` fixes Django and PostgreSQL. The API framework, the job
runner, the cache and the payment gateway were confirmed on 2026-10-01 (§18);
the mail provider and file storage are still to be named.

| Concern | Choice |
|---|---|
| Framework | Django 5.x + Django REST Framework, `psycopg` 3 |
| Async work | Celery with Redis as broker; Celery beat for the scheduled jobs (§12) |
| Cache | Redis (already assumed by the design for the permission cache) |
| Files | S3-compatible storage through `people.file_object` |
| Payments | Razorpay (what the old system used) behind a small gateway interface |
| Mail | the university's transactional mail provider behind a sender interface |
| API docs | OpenAPI generated from the DRF serializers |

---

## 4. What must exist before this module

The events app depends on shared apps. If one is missing, it is built first or
stubbed with the same interface.

| Needed from | What | Used for |
|---|---|---|
| `iam` app | login, sessions, `request.account_id` | every authenticated call |
| `authz` backend | `has_perm(code, org_unit)` over `authz.has_permission()`, cached effective permissions | endpoint permissions, list filtering |
| request middleware | `SET LOCAL app.account_id / app.request_id / app.session_id / app.client_ip` inside the request transaction | the audit trail |
| `org` / `people` read API | org-unit tree, person display names, student and employee lookups | pickers, joining names |
| files app | upload → `people.file_object`, signed download URLs | attachments, proofs, reports, certificates |
| **workflow app** | inbox (`wf.pending_for`), round detail, `wf.act`, comments, consultations, delegations, notice delivery | every approval in §7.3 |
| facility app | `facility.request_booking`, `facility.request_trip`, booking status | venue and vehicles of a proposal |
| notifications service | in-app and e-mail delivery of a notice to an account | approvals, registration, payment, team events |
| privacy helper | writing `privacy.pii_access_log` | lists and exports with names |

None of these exist today — only the database does. The workflow app is the
one hard dependency: proposals cannot be submitted or approved without it, so
phase 0 (§16) creates the Django project and delivers the minimum of it.

---

## 5. Project layout

One Django app, split by area so that each part can be built and reviewed on
its own.

```
apps/events/
  models/            unmanaged models, one file per catalog group (clubs, proposals,
                     event, participation, recognition, money, mail, stalls, settings)
  views_ro/          read-only models over the database views (v_event, v_registration …)
  db/functions.py    one thin wrapper per events.* SQL function
  db/errors.py       SQLSTATE → API error mapping
  api/
    clubs/  proposals/  events/  registrations/  teams/  gate/  volunteers/
    payments/  recognition/  mail/  stalls/  admin/  public/
  services/          orchestration only: several DB calls in one transaction,
                     gateway and mail calls, QR and PDF rendering
  integrations/      gateway.py (interface + Razorpay), mailer.py, qr.py, pdf.py
  tasks.py           Celery tasks (§12)
  permissions.py     DRF permission classes over authz + events.can_manage / can_see
  tests/
```

`services/` never contains a business rule. If a service needs an `if` about
who may do something or whether a value is allowed, that rule belongs in the
database with a test in `sql/97`.

---

## 6. Data access

### 6.1 Models

- All models are `managed = False`. The SQL files are the source of truth; the
  backend ships no schema migration for `events`.
- `search_path` includes `events` (already in `docs/design.md` §7), so
  `Meta.db_table = "event_registration"` works; table names are globally
  unique.
- Range columns map to `DateRangeField` / `DateTimeRangeField`; `citext` to
  `CharField`.
- Each database view gets a read-only model (`save()` and `delete()` raise).
  List and detail endpoints read from these, not from the base tables, so the
  derived state is always what the database says.

### 6.2 Function wrappers

Every SQL function is called through one wrapper in `db/functions.py`, with
typed arguments and the caller's `account_id` passed explicitly. The full set:

| Group | Functions |
|---|---|
| Clubs | `submit_club_proposal`, `submit_club_change`, `club_is_active`, `is_club_officer`, `may_propose_for` |
| Proposals & events | `submit_proposal`, `submit_event_change`, `publish_event`, `complete_event`, `cancel_event`, `can_manage`, `can_see` |
| Registration | `register`, `promote_waitlist`, `registration_state`, `seats_taken`, `seat_limit`, `team_size` |
| Tickets & gate | `issue_ticket`, `ticket_check`, `scan`, `check_in_round`, `people_inside`, `attended` |
| Money | `amount_due`, `amount_settled`, `is_paid`, `payer_registration`, `redeem_coupon`, `record_refund`, `stall_fee`, `submit_settlement` |
| After the event | `feedback_token_for`, `submit_feedback`, `issue_certificates`, `grant_duty_leave` |
| Mail | `dispatch_mail`, `mail_opened`, `mail_credits_total`, `mail_credits_used` |
| Stalls | `submit_stall_feedback` |
| System jobs | `expire_unpaid_registrations`, `run_mail_scheduler` (and `wf.run_timeouts` in the workflow app) |

`apply_club_change` and `apply_event_change` are called by the approval hook
inside the database and are not exposed.

### 6.3 Writes that are plain rows

Where the database has no function, the backend inserts or updates the row and
the trigger validates it: draft proposals and their parts, organiser edits of
an event, rounds, FAQs, custom fields, volunteers, teams, invitations, join
requests, extra passes, field responses, prize awards, certificate templates,
reports, coupons, payments, mail drafts and selections, stall applications and
stalls, club applications, suspensions, calendar items, the settings row.

Decisions are updates of specific columns, exactly as the tests do them — for
example a club application is decided by setting `decided_at`,
`decided_by_account_id`, `is_approved`; a registration is withdrawn by setting
`cancelled_at`, `cancelled_by_account_id`, `registration_cancel_reason_id`.
The serializer for such an action accepts only those inputs.

### 6.4 Error mapping

The database raises with a specific SQLSTATE and a readable message that starts
with the object name. One exception handler maps them:

| SQLSTATE | Meaning in this schema | HTTP |
|---|---|---|
| `42501` insufficient_privilege | caller may not do this; record is frozen | 403 |
| `23514` check_violation | a business rule was not met | 422 |
| `23505` unique_violation | already exists (second registration, duplicate code) | 409 |
| `23P01` exclusion_violation | overlap or limit reached (second open proposal, seat or office taken) | 409 |
| `P0002` no_data_found | unknown ticket, coupon, stall | 404 |
| `23503` foreign_key_violation | referenced row missing or still in use | 409 |
| `23502` not_null_violation | required input missing | 400 |

The database message is returned as the error detail (it is written for
people). A stable machine code is derived from the prefix before the colon
(`registration`, `event_payment`, `dispatch_mail` …) plus the SQLSTATE, so the
frontend can branch without parsing prose.

### 6.5 Transactions and session variables

- `ATOMIC_REQUESTS = True`: one request, one transaction. Compound actions
  (register + answers + guests; proposal parts) either all happen or none.
- The middleware sets `app.account_id`, `app.request_id`, `app.session_id`,
  `app.client_ip` with `SET LOCAL`. Without them the audit trail has no actor.
- Workers that run system jobs set `SET LOCAL app.system_job = 'on'` inside
  their transaction and never use a human account.
- Statements that both change data and read derived state run as two
  statements (the smoke tests document why).

---

## 7. API design

Base path `/api/v1/events`. JSON; cursor pagination on lists; ISO-8601 times
with offset. Every list endpoint filters by what the caller may see (§8).

### 7.1 Clubs

| Method and path | Database | Who |
|---|---|---|
| `GET /clubs` | `v_club` (+ category, parent unit type, status), filters | `events.club.view` |
| `GET /clubs/{id}` | `v_club`, `v_club_officer_current`, `v_club_points` | same |
| `GET /clubs/leaderboard` | `v_club_leaderboard` | `events.points.view` |
| `POST /club-proposals` · `PATCH` · `DELETE` | `club_proposal` draft | `events.club_proposal.create` at the parent unit |
| `PUT /club-proposals/{id}/officers` · `/members` · `/attachments` | child rows of the draft | proposer |
| `POST /club-proposals/{id}/submit` | `submit_club_proposal()` | proposer |
| `GET /club-proposals` | `club_proposal` + `wf.v_instance_state` | proposer; reviewers via `wf.can_view` |
| `POST /clubs/{id}/applications` | `club_application` | any current student |
| `POST /club-applications/{id}/decision` | update of the decision columns | advisor, officer or `events.club_member.update` |
| `GET /clubs/{id}/members` · `POST` · `DELETE` | `club_member` (ending = closing `valid`) | `events.club_member.view` / `.update` |
| `POST /clubs/{id}/suspensions` · `POST …/lift` | `club_suspension` | `events.club.update` |
| `GET/POST/PATCH/DELETE /clubs/{id}/calendar` | `club_calendar_item` | officers, advisor |
| `POST /clubs/{id}/change-requests` · lines · `…/submit` | `club_change_request`, `club_change_officer`, `club_change_member`, `submit_club_change()` | officer or advisor |
| `GET /clubs/{id}/change-requests` | `v_club_change` | `events.club_change.view`, requester |
| `PUT /me/primary-club` · `DELETE` | `primary_club` | the student |

Officers are never edited directly: a change of officers, advisor, name,
objective or category is a change request.

### 7.2 Event proposals

| Method and path | Database | Who |
|---|---|---|
| `POST /proposals` · `PATCH` · `DELETE` | `event_proposal` draft | whoever `may_propose_for()` the unit |
| `PUT /proposals/{id}/{part}` | `proposal_audience`, `_sdg`, `_partner`, `_speaker`, `_coordinator`, `_budget_item`, `_funding`, `_prize`, `_attachment`, `_visibility_role`, `_visibility_scope` | proposer |
| `GET/POST /sponsors` · `PUT /proposals/{id}/sponsorships` | `event_sponsor`, `event_sponsorship` | proposer; `events.sponsor.update` |
| `POST /proposals/{id}/submit` | `submit_proposal()` — opens the round and the facility package | proposer |
| `POST /proposals/{id}/venues` | `facility.request_booking(…, p_event_request)` with the proposal's `facility_event_request_id` | proposer |
| `POST /proposals/{id}/trips` | `facility.request_trip(…, p_event)` | proposer |
| `POST /proposals/{id}/revise` | new draft with `revises_proposal_id`, parts copied | proposer of a returned or withdrawn proposal |
| `GET /proposals` · `GET /proposals/{id}` | `v_proposal_status` | proposer, organising unit, reviewers |
| `POST /sponsorships/{id}/receipts` · `PATCH /sponsorship-items/{id}` | `sponsorship_receipt`, `sponsorship_item` | organisers, `events.sponsor.update` |

Venue requests are made after submission, against the package the submission
created; they are held at once and go to each room's custodian when the
proposal is approved.

### 7.3 Approvals (workflow app, not events code)

| Method and path | Database |
|---|---|
| `GET /approvals/inbox` | `wf.pending_for(account)` — includes due time and overdue flag |
| `GET /approvals/{instance}` | `wf.v_instance_state`, steps, actions, `wf.document_of()` to link to the proposal |
| `POST /approvals/{instance}/actions` | `wf.act(instance, action, account, note, file, target, return_to)` — an approver of a higher level who approves is recorded on that level and the lower pending levels are passed over, where the chain allows |
| `GET /approvals/waiting-below` | `wf.overridable_for(account)` — rounds waiting at a lower level that the caller could decide out of turn; a separate list, not the inbox |
| comments, consultations, checklist ticks, delegations | `wf.approval_comment`, `approval_consultation`, `approval_step_check`, `approval_delegation` |

The events API only links to these. When a round is approved the database
creates the club or the event itself (trigger on `wf.approval_action`); the
backend does nothing at that moment except deliver the notices.

### 7.4 Events (organisers)

| Method and path | Database | Who |
|---|---|---|
| `GET /events` · `GET /events/{id}` | `v_event`, limited by `can_see()` for participants | `events.event.view` |
| `PATCH /events/{id}` | organiser columns of `event` (descriptions, contact, window, cap, switches for volunteer and stall applications) | `can_manage()` |
| rounds, FAQs, links, custom fields + options | `event_round`, `event_faq`, `event_link`, `event_custom_field`, `custom_field_option` | `can_manage()` |
| `POST /events/{id}/publish` · `/complete` · `/cancel` | `publish_event()`, `complete_event()`, `cancel_event()` | `can_manage()` |
| `POST /events/{id}/unpublish` | `published_at = NULL` (refused once people registered) | `can_manage()` |
| `GET /events/{id}/statistics` | `v_event_statistics` | organisers, committee |
| `POST /events/{id}/change-requests` · `PATCH` · `…/submit` | `event_change_request`, `submit_event_change()` | `can_manage()` |
| `GET /events/{id}/change-requests` | `v_event_change` | organisers, reviewers |

### 7.5 Registration, tickets, teams

| Method and path | Database | Who |
|---|---|---|
| `POST /events/{id}/registrations` | `register()` + `field_response` + `extra_pass` in one transaction | `events.registration.create` |
| `GET /me/registrations` | `v_registration`, `v_ticket` | the participant |
| `POST /registrations/{id}/withdraw` | cancel columns, then `promote_waitlist()` | the participant (if the event allows), organisers |
| `GET /events/{id}/registrations` · export | `v_registration` with names | `events.registration.view`; logged (§13) |
| `POST /registrations/{id}/decision` | decision columns (events that require approval) | `can_manage()` |
| `POST /registrations/{id}/ticket` | `issue_ticket()` → token → QR image | holder, organisers |
| `POST /events/{id}/teams` · lock · withdraw · disqualify | `event_team` | leader; organisers for disqualify |
| invitations and join requests (create, accept, decline) | `team_invitation`, `team_join_request` | leader / participant |
| `GET /events/{id}/teams` | `v_team` | organisers, participants of the event |

The ticket token is shown once. The backend renders it as a QR and does not
keep it; "show my ticket again" re-issues it, which invalidates the old QR.

### 7.6 Gate and volunteers

| Method and path | Database | Who |
|---|---|---|
| `POST /events/{id}/scan/preview` | `ticket_check(token, account)` | scanning volunteer, organisers |
| `POST /events/{id}/scan` | `scan(token, direction, account, people, gate)` | same |
| `POST /events/{id}/attendance/import` | `entry_scan` rows with source `IMPORT` | organisers |
| `POST /rounds/{id}/check-in` | `check_in_round(token, round, account)` | scanning volunteer, organisers |
| `POST /rounds/{id}/attendance/import` | `round_attendance` rows with source `IMPORT` | organisers |
| `GET /events/{id}/rounds/attendance` | `v_round_attendance` | `events.attendance.view` |
| `GET /events/{id}/attendance` · export | `v_attendance`, `v_gate_summary` | `events.attendance.view` |
| `GET/POST/DELETE /events/{id}/volunteers` | `event_volunteer` | `can_manage()` |
| `POST /events/{id}/volunteer-applications` · decision | `volunteer_application` | any student or employee; organisers decide |
| `GET /me/volunteer-assignments` · `/me/volunteer-activity` | `v_volunteer_assignment`, `v_volunteer_activity` | the volunteer |

The scan endpoints are the hot path on event day (§14).

### 7.7 Coupons, payments, refunds

| Method and path | Database | Who |
|---|---|---|
| `GET/POST/PATCH/DELETE /events/{id}/coupons` | `event_coupon`, `v_coupon_usage` | `can_manage()` |
| `POST /registrations/{id}/coupon` · `DELETE` | `redeem_coupon()`; delete of the redemption | the participant |
| `POST /registrations/{id}/payments/order` | gateway order, then `event_payment` (open) | the payer |
| `POST /payments/{id}/confirm` | verify the gateway signature, then status → captured | the payer's client |
| `POST /webhooks/payments` | verify the webhook signature, then captured / failed, `webhook_verified` | gateway (public, signed) |
| `POST /registrations/{id}/payments/offline` | `event_payment` (open, reference, proof) | the payer |
| `POST /payments/{id}/verify` | status → captured with `verified_by_account_id` | organisers |
| `POST /events/{id}/payments/cash` | `event_payment` as received | organisers |
| `GET /events/{id}/payments` | `event_payment` | `events.payment.view` |
| `GET /refunds/queue` | `v_refund_queue` | `events.refund.view` |
| `POST /payments/{id}/refund` | `record_refund()` | `events.refund.create` |
| `GET/POST/PATCH/DELETE /events/{id}/expenses` | `event_expense` | `can_manage()` |
| `GET /events/{id}/accounts` | `v_event_budget_actual`, `v_event_settlement` | organisers, `events.settlement.view` |
| `POST /events/{id}/settlement` | `submit_settlement()` | `can_manage()` |

The amount is never taken from the client: the backend reads
`amount_due()` − `amount_settled()` and the database refuses anything else.

### 7.8 After the event

| Method and path | Database | Who |
|---|---|---|
| `POST /events/{id}/prize-awards` | `event_prize_award` | organisers |
| certificate templates CRUD | `event_certificate_template` | organisers |
| `POST /events/{id}/certificates/issue` | `issue_certificates(kind)`, then PDF rendering task | `events.certificate.issue` |
| `GET /me/certificates` · download | `event_certificate` | the holder |
| `GET /public/certificates/{code}` | `v_certificate_verify` | anyone (rate-limited) |
| `POST /registrations/{id}/feedback-token` | `feedback_token_for()` | the attendee |
| `POST /public/feedback` | `submit_feedback(token, rating, comment)` | anyone holding a token |
| `POST /events/{id}/reports` | `post_event_report` (new version) | organisers |
| `GET /events/{id}/duty-leave` · `POST …/grant` | `v_duty_leave_eligible`, `grant_duty_leave()` | organisers; leave is then approved by the HOD chain |

The feedback endpoint must not log the caller, the token or the IP alongside
the feedback (§13).

### 7.9 Messages

| Method and path | Database | Who |
|---|---|---|
| `POST /events/{id}/mails` · `PATCH` · `DELETE` | `event_mail` (draft or scheduled) | `can_manage()` |
| `PUT /mails/{id}/recipients` | `event_mail_recipient` (selection only) | `can_manage()` |
| `POST /mails/{id}/send` | `dispatch_mail()` | `can_manage()` |
| `POST /mails/{id}/cancel` | cancel columns | `can_manage()` |
| `GET /events/{id}/mails` · `/mail-credits` | `v_event_mail`, `v_event_mail_credit` | `events.mail.view` |
| `POST /events/{id}/mail-credits` | `event_mail_credit_grant` | `events.setting.update` |
| `POST /mails/test` | no database write; rate-limited | `can_manage()` |
| `GET /public/mail/{recipient}/open.png` | `mail_opened()` | anyone (the tracking pixel) |

### 7.10 Stalls

| Method and path | Database | Who |
|---|---|---|
| `PUT /events/{id}/stall-fees` | `event_stall_fee` | `can_manage()` |
| `POST /events/{id}/stall-applications` (+ set-ups, documents) | `stall_application`, `_setup`, `_document` | `events.stall.create` |
| `POST /stall-applications/{id}/decision` | decision columns | `can_manage()` |
| stall-fee payment | same payment endpoints with `stall_application_id` | applicant; organisers verify |
| `GET/POST/PATCH/DELETE /events/{id}/stalls` · products | `event_stall`, `event_stall_product`, `v_stall` | organisers |
| `GET /events/{id}/stall-applications` | `v_stall_application` | `events.stall.view` |
| `GET /public/stalls/{code}` · `POST /public/stalls/{code}/feedback` | `v_stall`; `submit_stall_feedback()` | anyone (rate-limited) |

### 7.11 Administration

| Method and path | Database | Who |
|---|---|---|
| `GET/PATCH /admin/settings` | `event_setting` | `events.setting.view` / `.update` |
| `GET/POST /admin/points` · `/admin/tiers` | `event_type_points` (a change closes the current row and opens a new one), `club_tier` | `events.points.update` |
| `GET /admin/overview` | `v_ccc_overview`, `v_event_statistics` | committee, administrators |
| lookups (event types, club categories, offices …) | shared lookup admin API | `core_admin.lookup.update` |
| approval chains and delegations | workflow admin API | `core_admin.approval_chain.update` |

---

## 8. Authorisation

Three layers, all answered by the database:

1. **Endpoint permission** — a DRF permission class calls
   `authz.has_permission(account, code, org_unit)` (through the cached
   backend) with the organising unit of the object.
2. **Object rights** — `events.can_manage(account, event)` for organiser
   actions, `events.can_see(event, person)` for participants,
   `events.is_club_officer()` / `may_propose_for()` for clubs,
   `wf.can_view()` / `wf.can_act()` for rounds.
3. **The trigger** — the last word. A request that passes 1 and 2 but breaks a
   rule is refused with `42501` or `23514`.

List endpoints never load everything and filter in Python: they join to
`authz.accessible_org_units(account, code)` or apply `can_see` in SQL.

The seeded roles and what they hold are in `sql/13_events.sql` (RBAC section):
EVENT_PARTICIPANT (every student and employee), EVENT_ADVISOR (from the club
appointment), EVENT_UNIT_ENDORSER (heads and deans, for their own unit),
EVENT_CCC_MEMBER, EVENT_ADMIN. The backend refers to permission codes only.

---

## 9. Integrations

### 9.1 Payment gateway

- A `Gateway` interface with `create_order(amount, currency, receipt)`,
  `verify_client_signature(order, payment, signature)`,
  `verify_webhook(body, signature)`, `fetch_order_payments(order)`.
- **Order:** read the amount due from the database, create the gateway order,
  insert `event_payment` (status open, `gateway_order_id`). A second order for
  the same registration supersedes the first — the database does this.
- **Confirmation** arrives three ways (client callback, webhook,
  reconciliation). All three call one service function that verifies the
  signature and updates the row to captured. The update is idempotent: a
  payment already captured is left alone.
- **Never reject a capture in the backend.** If the money cannot be used
  (registration cancelled, duplicate, superseded order) it still must be
  recorded; it then appears in `v_refund_queue` by itself.
- **Refunds** are made by hand in the gateway dashboard and recorded with
  `record_refund()` (decided, §18). The backend never moves money out itself.
- Signatures are verified in the backend and not stored.

### 9.2 Mail

- `dispatch_mail()` fills `event_mail_recipient` and takes the credits. A
  Celery task then sends each queued recipient: look up the person's official
  e-mail in `pii`, send, set the row to delivered or failed with the reason.
- Send in small waves with back-off on provider rate limits; a retry never
  re-sends a row that is already final.
- Open tracking stays off (decided, §18): the setting
  `event_setting.mail_open_tracking` remains false, so the pixel endpoint
  records nothing. It is still built, so an administrator could switch
  tracking on later after a DPO decision; the database never records an open
  for a minor either way.

### 9.3 QR and PDF

- QR images are rendered from the ticket token on request and not stored.
- Certificates: `issue_certificates()` creates the register rows; a task
  renders the PDF from the template, stores it as a `file_object` and sets
  `file_object_id`. The verification code in the PDF links to
  `/public/certificates/{code}`.

### 9.4 Facility and attendance leave

Called through their own apps' wrappers (`facility.request_booking`,
`facility.request_trip`, and `grant_duty_leave()` which files
`academic.attendance_leave`). The events backend shows their status by reading
their views; it does not manage them.

---

## 10. Notifications

Notices are produced in three places and delivered by the shared
notifications service:

| Source | Examples |
|---|---|
| `wf.approval_notice` (outbox) | a level is waiting, reminder, escalated, returned, rejected, approved |
| events actions (emitted by the backend after commit) | registration confirmed / waitlisted / promoted, payment received, team invitation, application decided, event cancelled, certificate issued |
| organiser messages | `event_mail` (§9.2) |

Rules: send after the transaction commits; one notice per recipient and
cause; the recipient's address is looked up at send time; a participant who
did the action themselves is not notified of it.

---

## 11. Public endpoints

Four endpoints work without login: certificate verification, feedback with a
token, stall feedback, and the mail-open pixel. For each:

- rate-limit by IP and by target (code, stall, token);
- return the same response for "unknown" and "not allowed" where that would
  leak whether a code exists;
- no session, no cookies, no account id set — these writes are anonymous by
  design;
- request logs for the two feedback endpoints exclude the body and are not
  joined to other logs.

---

## 12. Background jobs

| Job | Schedule | What it runs | Notes |
|---|---|---|---|
| Approval deadlines | every 15 min | `wf.run_timeouts()` | system job; belongs to the workflow app |
| Approval notices | every minute | deliver `wf.approval_notice` rows, set `dispatched_at` | workflow app |
| Unpaid registrations | every 15 min | `events.expire_unpaid_registrations()` | system job; does nothing unless the setting is filled |
| Scheduled mail | every 30 s | `events.run_mail_scheduler()` | system job |
| Mail sender | continuous | send queued `event_mail_recipient` rows | §9.2 |
| Payment reconciliation | every 10 min | for open orders older than 15 min, ask the gateway and confirm captures | uses the same confirm service as the webhook |
| Certificate rendering | on demand | PDFs for issued certificates | §9.3 |
| Waiting list | after a cancellation | `promote_waitlist(event)` | called in the cancelling request, not on a timer |

Every system job sets `app.system_job = 'on'` with `SET LOCAL` in its own
transaction, logs the count it returns, and is safe to run twice.

---

## 13. Privacy and security

- **Names on lists.** Registrant, attendee, applicant and volunteer lists join
  `people.v_person_display_name`. Any list or export of other people's
  personal data writes one `privacy.pii_access_log` row (who, purpose
  `EVENT_PARTICIPATION`, how many).
- **Contact details** (e-mail, phone) are returned only to organisers of that
  event and only where the screen needs them; never in a public or
  participant-facing list.
- **Anonymous feedback.** The backend must not create its own link between a
  feedback row and a person: no account id in the log line, no token in the
  log, no timestamp finer than the database keeps.
- **Analytics role.** Reporting connections use `intranet_analytics`, which
  cannot read the participant-level tables. Dashboards read
  `v_event_statistics`, `v_club_leaderboard`, `v_ccc_overview`.
- **Exports** are generated server-side, streamed, and logged; no client-side
  "download all" from a list endpoint.
- **Uploads** (attachments, payment proofs, reports, stall documents): type
  and size limits from configuration, virus scan before the `file_object` is
  usable, signed URLs for download.
- **Webhook** endpoint: raw-body signature check before any parsing; replay
  protection by the idempotent update.
- **Minors.** No behavioural tracking: the mail-open rule is in the database;
  the backend adds no analytics of its own on participants.

---

## 14. Performance

| Hot spot | Approach |
|---|---|
| Registration opening (many at once) | one transaction per registration; the database locks the event row, so seats are never oversold; return quickly and send notices after commit |
| Gate scanning | two short calls (`ticket_check`, `scan`); no joins to names in the scan response beyond the display name; keep p95 under 300 ms; the scanner retries on timeout and the second call is refused cleanly if the first succeeded |
| Event listing | cache the public listing per audience for a short time; invalidate on publish, cancel, complete |
| Permission checks | the Redis-cached effective set from the `authz` backend |
| Statistics | read the views; if a dashboard becomes slow, add a materialised view in SQL, not a counter table in the backend |
| Webhook bursts | acknowledge fast; the confirm service is one indexed update |

Load-test registration opening and scanning against a copy of the real
database before the first large event.

---

## 15. Testing

- **No mocked database.** API tests run against a PostgreSQL built from
  `sql/0*.sql sql/1*.sql`, the same way `CLAUDE.md` §6 builds it.
- **The SQL smoke tests stay the authority on rules.** API tests check that
  each endpoint calls the right thing, maps errors correctly and returns the
  derived state — not that the rule itself is right.
- For every endpoint: the success path; one refusal per error class it can
  return; a permission test with an account that lacks the right.
- Scenario tests mirroring `sql/97`: found a club → propose → approve →
  publish → register → pay → scan → certificate → feedback → complete.
- Gateway and mailer are tested against their interfaces with a fake
  implementation; one contract test per real provider in a sandbox.
- Concurrency tests: parallel registrations for the last seat; a webhook and a
  client confirmation for the same payment; two scans of one ticket.
- A check in CI that no module code contains a role name or a literal limit
  that exists in `event_setting`.

---

## 16. Delivery phases

Each phase ends with something usable and demonstrable. Sizes are relative
(S / M / L), not durations.

| # | Phase | Delivers | Depends on | Size |
|---|---|---|---|---|
| 0 | Foundations | app skeleton, unmanaged models and view models, function wrappers, error mapping, permission classes, request middleware, test database fixture; minimum workflow API (inbox, round detail, act) if not yet available | iam, authz | L |
| 1 | Clubs | directory, founding proposals through approval, members, applications, suspensions, calendar | 0 | M |
| 2 | Event proposals | drafts with all parts, sponsors, submit, revise, venue and trip requests, proposal status | 0, facility app | L |
| 3 | Events | organiser settings, rounds, FAQs, questions, publish / cancel / complete, listing with visibility | 2 | M |
| 4 | Registration and teams | register, answers, guests, withdraw, waiting list, tickets and QR, teams, invitations, join requests | 3 | L |
| 5 | Gate and volunteers | scan preview and scan, attendance views and import, volunteer assignment, sign-up and dashboard | 4 | M |
| 6 | Money | coupons, gateway orders, confirmation paths, offline payments, refund queue, expiry and reconciliation jobs | 4, gateway account | L |
| 7 | After the event | prizes, certificates with PDF and public verification, anonymous feedback, report, duty leave, points and leaderboard | 5 | M |
| 8 | Messages | drafts, audiences, scheduling, sender worker, credits, open pixel | 4, mail provider | M |
| 9 | Stalls | fees, applications, payment, stalls, public feedback | 6 | M |
| 10 | Club changes | change requests through approval, primary club | 1 | S |
| 11 | Administration | settings, points and tiers, overview dashboards | 0 | S |
| 12 | Hardening | load tests, security review, privacy review with the DPO, runbooks, monitoring | all | M |

Phases 1 and 2 can run in parallel after 0; 5 and 6 in parallel after 4;
8, 9, 10, 11 are independent of each other.

**Definition of done for a phase:** endpoints documented in OpenAPI; API tests
green against a freshly built database; no rule duplicated in Python; lists
with names write the access log; notices sent after commit; the matching
section of `sql/97` can be replayed through the API.

---

## 17. No data migration

Nothing is pulled from the old SGT UMS (decided, §18). It was read only to
understand how clubs and events flow; the new system starts with its own data:

- clubs are founded through the new club-proposal process (or entered by an
  events administrator), each with a parent unit and a category;
- there are no past events, registrations, payments, certificates or club
  points to carry over, so no old QR codes or verification codes need to keep
  working;
- the backend therefore needs no import tooling, and go-live does not wait on
  a migration.

---

## 18. Decisions

Decided on 2026-10-01:

| # | Decision | Outcome |
|---|---|---|
| 1 | Stack beyond Django | Django REST Framework, Celery, Redis |
| 2 | Existing backend to build on | none — only the database is being developed now; the backend, starting with phase 0, comes later |
| 3 | Payment gateway and refunds | Razorpay; refunds made by hand in its dashboard and recorded in the intranet |
| 4 | Mail open tracking | stays off |
| 5 | Data from the old UMS | none; the old system is a reference for flows only |

Still open — to be settled when the backend work starts; the plan proceeds on
the default until then:

| # | Decision | Default |
|---|---|---|
| 6 | Mail provider and sending domain | to be named |
| 7 | Certificate PDF: how it is produced | an HTML template rendered to PDF |
| 8 | Scanning with no network at the venue | not supported; the attendance import covers it |
| 9 | What volunteers scan with | a responsive web page on their phone |
| 10 | Who holds EVENT_ADMIN and sits on the committee at go-live | to be named by the university |

---

## 19. Risks

| Risk | Mitigation |
|---|---|
| Rules re-implemented in Python drift from the database | code review rule; CI check; error mapping makes the database refusal the user-facing message |
| Workflow app not ready when proposals are built | phase 0 delivers the minimum inbox and act endpoints |
| Gateway callbacks lost or duplicated | three confirmation paths into one idempotent update; reconciliation job |
| Registration rush oversells or times out | the database lock guarantees seats; load test before go-live |
| Personal data leaks through lists and exports | names joined only for permitted callers; access log; analytics role |
| Anonymous feedback de-anonymised by application logs | logging rules in §11 and §13, reviewed with the DPO |
| Schema changes while the backend is being built | the SQL files are the contract; unmanaged models are regenerated and the API tests run on every schema change |
