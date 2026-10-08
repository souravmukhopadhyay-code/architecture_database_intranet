# Module integration — worked examples

This document answers two concrete questions with actual SQL, not just
principles: **"is there provision for central departments like HR, IT,
Finance?"** and **"how would TMS, Resource Management and Event Management
actually attach to this foundation?"** Read `docs/design.md` §5.6 first for
the general pattern; this document applies it to three real modules from the
old SGT UMS.

---

## 0. Central / independent departments — the provision already exists

**Short answer: yes.** HR, IT, Finance, Registrar, Admissions, Library, DRD,
Examinations, Estate & Security, Transport — every one of them is simply a
row in `org.org_unit` with `org_unit_type = CENTRAL_DEPARTMENT`. There is no
separate "central department" table, and none is needed: schools, academic
departments and central departments all live in the **same** generic tree
(`org.org_unit`), distinguished only by `org_unit_type`. That is deliberate —
see `docs/design.md` §2 principle 1 (normalisation) and the org-unit type
rules in `sql/02_org.sql`.

**Why the core files (`sql/00`–`sql/11`) don't already contain "HR", "IT",
"Finance" as rows:** those files are schema plus *universal* reference data
— the kind any institution could reuse unmodified. Which departments exist
is *operational* data specific to SGT (the same category of fact as which
employees exist), so it does not belong in a generically reusable seed.

`sql/90_example_sgt_org_structure.sql` proves the provision works, end to
end, with real SQL you can run:

```sql
INSERT INTO org.org_unit (org_unit_type_id, parent_id, code, name) VALUES
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'HR',  'Human Resources'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'IT',  'Information Technology'),
  (ref.id_of('org_unit_type','CENTRAL_DEPARTMENT'), org.id_of('SGTU'), 'FIN', 'Finance & Accounts');
  -- ... Registrar, Admissions, Library, DRD, Examinations, Estate & Security, Transport
```

It carries the same department list the old SGT UMS actually used
(`hr`, `it`/`erp`, `drd`, `finance`, `library`, `admissions`, `registrar`,
`noting`, `gateEntry`, `cab_booking` — from `CENTRAL_DEPARTMENT_PERMISSIONS`
in the old codebase), plus **Examinations**, which the old TMS escalation
ladder required (§2 below) but which the old schema never modelled as a
first-class department. Sub-units (Recruitment, Payroll, IT Helpdesk, ERP &
Systems, Accounts, Fees & Scholarships, Grants Cell, IPR Cell, Gate Entry &
Security, Noting/Internal Approvals…) are just `SECTION` nodes one level
deeper — again, no new modelling, the same tree.

The script then runs a live proof: it appoints an example "Head of IT"
(`org.appointment`, position `HEAD`) and checks their permissions —

```
NOTICE:  core_admin.employee.view over the IT department, derived (not stored) -> t
NOTICE:  same permission over Finance, which she was never granted        -> f
```

Nothing was copied onto her account. The moment she's appointed HEAD of IT,
`authz.position_role` (`HEAD → ORG_UNIT_HEAD`, seeded in
`sql/10_seed_reference.sql`) grants her `ORG_UNIT_HEAD` scoped to IT
automatically, through `authz.v_account_role_effective`. If she's later
reassigned, the permission moves with her without an admin having to revoke
and re-grant anything.

**To use this for real:** copy `sql/90_example_sgt_org_structure.sql`,
replace the codes/names with SGT's actual department list and reporting
structure (confirm names/heads with HR before entering them), remove the
illustrative "Priya Sharma" block, and run it once against the real database
after `sql/00`–`sql/11`.

---

## 1. TMS (Ticketing / Helpdesk) integration

> **Status: built** — schema `tms` in `sql/12_tms.sql` (24 tables, 20 `ref`
> lookups), tested by `sql/98_tms_smoke_test.sql`; design, policy and the
> end-to-end flows in [`docs/tms/tms-design.md`](tms/tms-design.md); the tables in
> `docs/table-catalog.md` §14, the flow in `docs/data-flow.md` §2.15; SGT's
> standard student helpdesk (UGC grievance heads, committees) in
> `sql/91_example_tms_student_helpdesk.sql`. The build differs from the plan
> below where the old system's behaviour or the UGC regulations required it:
> - **One category tree per domain** (`tms.ticket_category`: KRA type → KRA →
>   KPI → criteria for employees, master → category → sub-category for
>   students); the root names the responsible org unit, the priority (with its
>   SLA hours) sits on the leaf, and route, forum, confidentiality, anonymity,
>   respondents, incident date, grievance head and academic context are
>   inherited down the tree.
> - **Routes** (`tms.ticket_route` / `ticket_route_level`) instead of a fixed
>   ladder: handler pools (optionally per school or campus), category owners,
>   the student's mentor, the employee's manager, positions **relative to the
>   requester's unit** (HOD, Dean), to the category's office or fixed
>   (Registrar, Dean Academics, VC) — resolved through `org.appointment`, not
>   a bare `org.ancestors()` walk, because a ladder crosses units.
> - **Redressal forums** (`tms.redressal_forum`): the nearest SGRC
>   (`academic.academic_body`), whose decision is a quorate
>   `academic.body_resolution`, then the Ombudsperson on appeal; ragging,
>   sexual harassment and discrimination go straight to their committees,
>   confidentially, with respondents who never see or handle the ticket.
> - **No `wf` chain**: a ticket is not an approval and a committee's decision
>   is a resolution, so the history is the ticket's own append-only
>   `tms.ticket_event`, validated against a lifecycle table, and status,
>   assignee, level, forum and clock are derived (`tms.v_ticket_state`).
> - **Business-hours SLA clock** (or round the clock per priority) with a
>   first-response target, pausing for clarification; `tms.run_scheduler()` is
>   the hourly job (auto-referral, escalation, reminders, expiry, closing).
> - Roles as built: `TMS_STUDENT_REQUESTER`, `TMS_EMPLOYEE_REQUESTER`,
>   `TMS_STAFF_REQUESTER`, `TMS_UNIT_SUPERVISOR` (derived from the HEAD and
>   DEAN appointments), `TMS_STUDENT_OVERSEER` (derived from the DSW
>   appointment), `TMS_INTAKE_DESK`, `TMS_GRIEVANCE_CELL` and `TMS_ADMIN`
>   (no access to confidential tickets); handlers need no role — being on the
>   route gets them tickets, and being a ticket's assignee is their right to
>   act on it (`tms.can_act()`).
>
> The tables below map the old system onto what was built (the earlier
> plan's working names — `tms.category`, `tms.sla_policy`, `tms.timeline`,
> `tms.ticket.resolve` — were never created; the built names are used here).

**What TMS reuses — nothing rebuilt:**

| Old TMS concept | Reused from this foundation |
|---|---|
| Who can raise a ticket | `people.employee` / `people.student` (current members, `people.v_person_principal_kind`) — no re-collecting name or department |
| Ticket routed to "IT", "HR", "Finance"… | the `CENTRAL_DEPARTMENT` org units from §0 — the category tree's root names the responsible `org_unit_id` |
| `TmsRoleHandler` / `TmsEmployeeRoleHandler` ("who currently heads X") | `org.appointment` + `org.position_type`, reached by route levels relative to the requester's unit, the category's unit or a fixed unit — no handler table |
| Mentor, HOD, Dean on the academic path | `people.student_mentor`; HEAD / DEAN appointments found from the student's unit |
| Grievance committees (SGRC, ICC, anti-ragging squad and committee, SC / ST cell, equal opportunity cell) | `academic.academic_body` (+ members, meetings, quorum-checked `academic.body_resolution`); the Ombudsperson is an `org.appointment` |
| Holidays | `academic.calendar_event` (the helpdesk adds only its weekdays, hours and dated overrides) |
| "May this person act on / see this ticket" | `tms.can_act()` / `tms.can_view()`, built on `authz.has_permission(account, 'tms.student_ticket.update', unit)` (and `.view`, and the `employee_ticket` pair) |

**What TMS adds — its own** (full list in `docs/table-catalog.md` §14, design in `docs/tms/tms-design.md`):
- `authz.app_module` `tms`; resources `_module`, `student_ticket`, `employee_ticket`, `intake`, `confidential_ticket`,
  `anonymous_identity`, `grievance_register`, `config`, `analytics`; permissions such as `tms.student_ticket.create`,
  `tms.student_ticket.view`, `tms.student_ticket.update`, `tms.employee_ticket.assign`, `tms.intake.create`,
  `tms.config.update`.
- Tables: `tms.ticket_category` (one tree per domain), `tms.ticket_route` / `ticket_route_level` (the ladders),
  `tms.redressal_forum`, `tms.ticket`, `tms.ticket_event` (the append-only timeline — status and SLA are derived),
  respondents, files, notices, the knowledge base and the settings / calendar tables. Priority SLA hours are on
  `ref.tms_priority` and can be overridden per category and per route level.
- Roles: `TMS_STUDENT_REQUESTER` / `TMS_EMPLOYEE_REQUESTER` (derived for every current student / employee),
  `TMS_STAFF_REQUESTER`, `TMS_UNIT_SUPERVISOR` (derived from HEAD and DEAN appointments), `TMS_STUDENT_OVERSEER`
  (DSW), `TMS_EMPLOYEE_OVERSEER`, `TMS_INTAKE_DESK`, `TMS_GRIEVANCE_CELL`, `TMS_ADMIN`. Handlers need no role — being
  on a route gets them tickets, being the assignee is their right to act.
- Escalation does **not** walk `org.ancestors()` of the ticket's unit: the old ladder jumps across units (a school's
  ticket to central offices, the Registrar and the VC), so each level names where to look (the requester's unit,
  the category's unit, or a fixed unit, optionally the nearest unit of a type above it).
- `TmsSettings` (auto-escalation, reopen window) and the business-hours SLA clock are genuinely TMS-specific — they
  stay in the `tms` schema (`tms.helpdesk_setting`, `helpdesk_weekday`, `helpdesk_day_override`).

---

## 2. Resource Management (Seminar Hall & Cab Booking) — now part of the foundation

Resource Management is the one old module that did **not** stay a module: the
timetable, the examinations, vivas and convocations all occupy rooms, and a
booking that is blind to them is wrong by construction. So rooms, the
occupancy ledger, bookings, assets, maintenance, the guest house, parking, the
fleet and keys are the `facility` schema (`sql/06d_facility.sql`, 41 tables),
built on the same mechanisms every other module reuses. What the old module
had, and where it lives now:

| Old concept | Now |
|---|---|
| `SeminarHallBlock` (A, B, C, D…) → floors → rooms (a second room tree) | `org.building` → `org.floor` → `org.room` (one tree, with `room_use`, `area_sqm`, composed halls); a **block** is an `org.org_unit` of type `BLOCK` (seeded in `sql/10`) that takes **custody** of its building (`facility.custody`) |
| Main admin / block admin / subadmin, per-user room access with revocation | `FACILITY_ADMIN`; the block's head is its custodian by appointment (`position_role`), or `FACILITY_CUSTODIAN` granted scoped to the block; per-person access = `facility.room_reservation_rule` with a `person_id`, revoked by closing its validity |
| Inactive block / floor / room = private; cannot deactivate with active bookings | `is_active` on building / floor / room with triggers (no deactivation with future holds, no activation under an inactive parent); private rooms are reservation rules |
| Booking with date, HH:MM strings, purpose; 30-minute minimum; pending blocks the slot; expiry sweep | `facility.booking_occurrence` with a `tsrange`, validated against `booking_policy`; a tentative `room_hold` from submission; status derived (`v_booking_status`), `release_no_shows()` |
| Approve / reject by the block admin; cancel and reschedule requests; booking groups `GRP-YYYY-NNNN` with recurrence and skip-conflict | a ROOM_BOOKING round owned by the custodian (`wf`, `anchor_is_owner`; a per-block chain is one scoped `wf.approval_chain`); ROOM_BOOKING_CHANGE for a reschedule; `booking_group` + `request_booking(..., p_skip_conflicts)` + `occurrence_dates()` |
| Cab request → manager approval (`cab_manager_queue`) → transport dashboard; urgent skips the manager; auto-approve at T−1 h; T−30 alert; driver token links; ratings in notes | TRIP_REQUEST (unit head → transport) / TRIP_REQUEST_URGENT (`transport_policy`); `run_trip_escalations()` as a system job (AUTO_APPROVE, `trip_alert`); `trip_allocation` (EXCLUDE per driver and vehicle, token hashes); `trip_rating` |
| Vehicle / driver masters with status flags and unenforced expiries | `vehicle` + `vehicle_document` (mandatory documents must cover the trip), `driver` whose licence is a `pii.person_identity_document` with `expires_on`; "on trip" is derived, never a flag |

What it added beyond the old module, because a university runs on more than
seminar halls: composed halls, space allocation for NAAC / AICTE returns,
configurable pre-emption (an exam displaces a class, a class displaces a
club), event packages, assets and loans, work orders with SLAs, preventive
maintenance, guest-house tariffs, parking, keys — all in `docs/design.md`
§4.1i and `docs/table-catalog.md` §13.

The lesson for every later module stands: the block admin table, the status
enum, the copied requester details and the application-side clash check all
disappeared into org units, scoped grants, the `wf` engine and one EXCLUDE
constraint.

---

## 3. Event Management (+ Academic Clubs) — built (`sql/13_events.sql`, schema `events`)

The module is implemented and tested (`sql/97_events_smoke_test.sql`). This section records how each old concept was mapped, as the pattern for the next module.

**What it reuses, and what it therefore does not contain:**

| Old concept | In the new database |
|---|---|
| Who registers / attends | `people.person` — a registration references `person_id`; no name, e-mail or phone is copied |
| Kinds of club (the old system had only "academic clubs" with a department name, and the special Anvaya team) | a club's **parent unit** (school, department, the Dean Students' Welfare office, the university) and its **category** (`ref.club_category`); a different path for one kind is a chain scoped to its parent unit, or a level conditional on the category flag |
| Which school / department / club organises | `org.org_unit` — a **club is an org unit** of type CLUB (under the university, a school, a department or a central department) |
| Faculty advisor, co-advisor | `org.appointment` (positions CLUB_ADVISOR, CLUB_CO_ADVISOR) — dated, one holder at a time, and the source of the advisor's permissions (`position_role` → EVENT_ADVISOR) |
| The seven officer columns on `AcademicClub` | `events.club_officer` — one row per office and period; one holder per office and one office per student at a time, with history |
| `EventPermissionConfig` (`userId, role: block_incharge \| ccc_member \| anvaya, block`) | scoped `authz` grants (EVENT_CCC_MEMBER, EVENT_UNIT_ENDORSER from the HEAD / DEAN appointment) **plus chain rows** on the approval engine |
| `ClubEventProposal.status`, `StudentClubProposal.status`, the hard-coded Advisor → Block In-Charge → CCC path and its bypass | two `wf.approval_document_type` rows (CLUB_PROPOSAL, EVENT_PROPOSAL) and their chains — **no approval code in the module** |
| Venue check before approval | the proposal opens a `facility.event_request` on the same round: rooms are held from submission and go to their custodians on approval |
| Event status, registration status, seat counters, attendance flags | derived views (`v_event`, `v_registration`, `v_attendance`, `v_team`) |
| Club points in Redis | `events.event_type_points` (dated), `club_point_award`, `club_tier`; totals derived |
| Certificates, audit of who did what | `events.event_certificate` (serial + verification code); `audit.*` automatic |
| The Anvaya bypass (a team whose proposals skipped the advisor and block levels) | no code: a chain scoped to that unit, or simply the engine's rule that a higher level may approve out of turn and pass lower levels over (with a minimum of approved levels) |
| Moving an approved event (not possible in the old system without re-proposing) | `events.event_change_request` on the EVENT_CHANGE chain, applied by the database |
| Attendance per session; actual spending | `events.round_attendance`; `events.event_expense` and `events.event_settlement` on the EVENT_SETTLEMENT chain |
| `AcademicClubChangeRequest` (a table with a JSON of requested changes and no code behind it) | `events.club_change_request` + officer / member lines — a third document type on the engine (CLUB_CHANGE); the approved change is applied by the database |
| `UserPrimaryAcademicClub` | `events.primary_club` |
| `EventCoupon`, `CouponUsage` (`usedCount` counter, never released) | `events.event_coupon`, `events.coupon_redemption`; use is derived and freed by a cancelled registration |
| `Payment` (Razorpay), `paymentStatus` / `amountPaid` on the registration, `metadata.needsRefund` | `events.event_payment` (online orders and offline claims); paid state, fees and the refund queue derived |
| Pending-registration expiry (written, never started) · refund queue handlers (written, never routed) | `events.expire_unpaid_registrations()` (a setting, off by default) · `events.v_refund_queue`, `events.record_refund()` |
| `EventEmailLog`, `EmailRecipientLog` (addresses stored), `EventEmailCredit`, `EmailCreditLog` | `events.event_mail`, `event_mail_recipient` (no address), credits derived + `event_mail_credit_grant` |
| `Stall`, `StallApplication`, `StallFeedback` (tables only — their screens were removed in June 2026) | `events.event_stall_fee`, `stall_application` (+ set-ups, documents), `event_stall` (+ products), `stall_feedback` (+ points) |

**Why student officers are not `org.appointment` rows** (an earlier sketch of this document suggested they would be): appointments are held by *employees* and feed `authz.position_role`; club officers are *students*, need "one office per student" as well as "one holder per office", and get their rights from the club itself (`events.is_club_officer()`, `may_propose_for()`), so they have their own dated table. The advisors, who are employees, *are* appointments.

**Approval is configuration.** Seeded defaults:

| Document | Level | Who | Deadline |
|---|---|---|---|
| CLUB_PROPOSAL | 1 | central coordination committee — `events.club_proposal.approve` at the university | 7 days, reminder |
| EVENT_PROPOSAL | 1 | advisor of the club / head of the organising unit — `events.proposal.review` at the owning unit itself; skipped when that person is the proposer | 3 days, reminder |
| EVENT_PROPOSAL | 2 | central coordination committee — `events.proposal.approve` at the university | 5 days, reminder |

A school that wants more adds a chain scoped to itself — the test file does exactly this for a School of Engineering: advisor → **the Dean, only when the budget exceeds 50,000** (a POSITION level with `min_amount`) → **the committee as a body with a quorum of two** (a COMMITTEE level). The old "block in-charge" level is the same thing: a level anchored at the BLOCK unit, or simply the room's custodian approving the venue through the facility package. A level only for paid events or events with external guests is a level with `wf_flag_id` — the round already carries PAID_EVENT, EXTERNAL_GUESTS and SPONSORED.

**After approval** the hook on `wf.approval_action` creates the event; the organisers publish it; registration (seats, waiting list, guests, extra questions), teams, gate scans, prizes, certificates, anonymous feedback, the report, duty leave and club points follow — see `docs/design.md` §4.1k and §5.3j.

**Configurable at admin level, nothing hard-coded:** besides the approval levels and deadlines (chain rows), the module's limits and requirements are one settings row (`events.event_setting` — lead time, required proposal sections, proposals under approval per proposer, guest-pass ceiling, what publishing needs, the feedback scale, club name / objective lengths, whether advisors must be faculty), lookup flags (`ref.club_office.is_required`, `may_propose`), and dated rows (points per event type, tiers). The full table of what is configured where and by whom is in `README.md` (*What an administrator configures*).

**What stays with the application:** the conversation with the payment gateway (order creation, signature and webhook verification, asking the gateway to reconcile), the actual sending of mail and its tracking pixel, rendering the QR and the certificate PDF. The database records the outcome of each and enforces the rules around it.

**Left out on purpose:** the old "Anvaya bypass" as code — a bypass is a chain scoped to that unit.

---

## 4. Common thread

In every one of the three modules above (all now built: `tms`, `facility`, `events`), the part that used to be a
bespoke, module-specific table in the old system — a role-handler table, a
block-assignment table, a seven-column officer list, a permission-config
table — turns out to already be exactly `org.org_unit` +
`org.appointment` + a scoped `authz.account_role`/`authz.role` grant. That
is the concrete payoff of the foundation being generic rather than
department-specific: **HR, IT, Finance, a seminar-hall Block and an
Academic Club are all just org units with appointed or granted people** —
one mechanism, reused by everything that plugs in, including modules not
yet designed.

The same holds for **approvals** — more strongly, because the `wf` engine
is built to be the base for all of them. A module that needs a sign-off (a
room booking needing the Block custodian, an event proposal going Advisor →
committee, and later a noting, an IPR filing, a leave, a purchase) does not
build an approval table, a status column or an escalation job: it registers
a `wf.approval_document_type` and **configures** a `wf.approval_chain` —
per level: who approves (a permission at an org level, a position holder,
the requester's manager, named people, a committee quorum), how many, the
amount band or flag under which the level applies, what happens when the
requester is the approver, what must be supplied, whether it can be
forwarded or sent back a level, and the deadline with its timeout action —
and links its record to `wf.approval_instance`. `wf.submit()`, `wf.act()`,
`wf.pending_for()` and the append-only `wf.approval_action` then give it
snapshots, returns, rejection, delegation, consultation, comments,
reminders and escalation, separation of duties, notices and an audit trail
for free. A school, block or club that wants a different path adds a chain
scoped to itself. Reference implementations: the curriculum / SOE approval
(`academic.curriculum_approval`), the facility requests, and the events
module (two document types, three stage rows, no approval code); the recipe
is `SKILL.md` §2a and `docs/design.md` §4.1j.
