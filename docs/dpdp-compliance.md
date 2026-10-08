# DPDP Act 2023 — compliance mapping

This maps the obligations of the **Digital Personal Data Protection Act, 2023** (with the DPDP Rules) to the tables, constraints and views in this design.

> **This is a technical design, not legal advice.** Items marked **POLICY** need values or decisions from the university's legal counsel or Data Protection Officer:
> - retention periods,
> - response windows,
> - the legal basis chosen for each purpose,
> - whether any student-data exemption notified under the Rules applies.

The university acts as the **Data Fiduciary**. Staff, students, guardians and nominees are **Data Principals**. SaaS vendors (email, SMS, cloud) are **Data Processors**.

## Obligation → implementation

| DPDP provision | Obligation | Where it lives | DB-enforced guarantees |
|---|---|---|---|
| §4, §7 | Process only for a lawful purpose, on consent or a legitimate use | `privacy.processing_purpose.legal_basis_id` → `ref.legal_basis` (`CONSENT`, `LU_EMPLOYMENT` §7(i), `LU_LEGAL_OBLIGATION` …) | Every purpose must have a basis (NOT NULL FK) |
| §5 | Notice before or with the consent request: what data, which purpose, how to exercise rights and complain | `privacy.privacy_notice` (version × language, content hash, file), `privacy.notice_purpose` | Notice version + language is unique. Content is fixed by its SHA-256 |
| §5(3) | Notice available in English or any 8th-Schedule language | `ref.language.is_scheduled_language` (22 languages seeded) | — |
| §6(1) | Consent must be free, specific, informed, unambiguous; limited to the purpose | `privacy.consent`: one row per principal × purpose × notice | Consent can only reference a purpose listed on that notice (composite FK). Only one active consent per principal and purpose (EXCLUDE) |
| §6(4)–(6) | Withdrawing is as easy as consenting; processing stops after withdrawal | `consent.withdrawn_at`; request type `CONSENT_WITHDRAWAL`; `privacy.v_active_consent` | A withdrawn consent disappears from `v_active_consent` |
| §6(7)–(9) | Consent Managers | `consent.consent_manager_ref`, channel `CONSENT_MANAGER` | — |
| §8(1) | Fiduciary is responsible, including for its processors | `privacy.data_processor` (country, DPA date), `privacy.processor_purpose` | — |
| §8(3) | Accuracy and completeness of data used for decisions | Correction requests (`CORRECTION`); normalised single source per fact (no duplicated copies to drift) | 4NF: one email/phone/address table, no copies |
| §8(4), (5) | Organisational measures and reasonable security safeguards | `pii` schema isolation + DB roles; `intranet_analytics` cannot read `pii`, `iam` or names; encrypted gov-ID and TOTP secrets with HMAC blind index; hashed tokens/OTPs/recovery codes; MFA; session revocation; audit | Privileges tested: analytics is denied on `pii.*` and `people.person`. Audit is append-only |
| §8(6) | Intimate a personal data breach to the Board and to each affected principal | `privacy.breach_incident` (`detected_at`, `board_notified_at`, severity, status), `breach_affected_person`, `breach_notification` | A notification can only go to a person recorded as affected (composite FK). Board notice cannot predate detection (CHECK) |
| §8(7) | Erase personal data once the purpose is served or consent is withdrawn, unless retention is legally required; processors must erase too | `processing_purpose.retention_period` (**POLICY**), `privacy.data_element.erasure_action_id` (`DELETE`/`ANONYMISE`/`RETAIN_LEGAL`), `privacy.erasure_log` | Inventory entries must point to real columns (trigger) |
| §8(9), §10 | Publish DPO / contact person; Significant Data Fiduciary duties (DPIA, audit) | `org.position_type` `DPO`, `GRIEVANCE_OFFICER` → `org.appointment` (single holder, dated) | One holder per position at a time (EXCLUDE) |
| §8(10), §13 | Effective grievance redressal | `privacy.data_principal_request` type `GRIEVANCE`, `dpr_request_event`, `v_dpr_request_status` (`due_by`, `is_overdue`) | Current status is derived from events, so it cannot be edited |
| §9(1) | Verifiable consent of the parent/guardian before processing a child's (<18) data | `pii.v_person_age.is_minor`; `consent.given_by_person_id`; `privacy.verifiable_parental_consent` (method, evidence); `privacy.v_minor_consent_gap` | Consent given by someone else must come from a recorded guardian (`person_relationship.is_guardian`, trigger) |
| §9(3) | No tracking, behavioural monitoring or targeted advertising of children | No such processing in the foundation. Modules must not add it; the review checklist below covers this | — |
| §11 | Right to a summary of personal data and processing, and the processors it was shared with | Request `ACCESS_SUMMARY`; export driven by `privacy.data_element` + `processor_purpose` | — |
| §12 | Right to correction, completion, updating and erasure | Requests `CORRECTION`, `ERASURE`; `erasure_log` | — |
| §14 | Right to nominate | `privacy.nominee` (dated; nominee is a `person`) | One active nominee (EXCLUDE) |
| §16 | Transfers outside India (subject to restrictions notified by the government) | `data_processor.country_id` | — |
| Accountability | Prove who accessed what | `privacy.pii_access_log` (accessor, principal, category, purpose); `audit.audit_event/audit_change`; `iam.auth_event` | Audit is append-only (trigger + grants). Personal-data values in the audit trail are `[REDACTED]` |

## Data minimisation choices built into the schema
- **Optional by default.** Gender, DOB, blood group, nationality, phones and addresses are nullable or optional. Collect them only when a purpose in `purpose_data_category` needs them.
- **No full Aadhaar.** `id_document_type` offers `AADHAAR_VID` (virtual ID) only. All document numbers are app-encrypted with just `last4` in clear.
- **Auth logs don't store raw identifiers.** A failed login stores `identifier_hmac`, never the attempted email or UID.
- **The audit trail isn't a shadow copy.** Erasable personal-data columns (anything in `data_element` with an erasure action of DELETE or ANONYMISE) are logged as changed, but their values are not kept, so erasure is not defeated by the audit. Columns the university must retain by law anyway (`RETAIN_LEGAL` — marks, results, enrollment numbers) keep their old/new values in the audit, because proving who changed a mark from 40 to 70 is the point of auditing them, and retaining them does not undermine any erasure right.
- **Analytics sees no identities.** `intranet_analytics` has no access to `pii`, `iam`, `people.person` or `person_relationship`.
- **External examiners are persons, not employees.** A practical / viva external examiner is a `people.person` referenced from `exam.examiner_panel` (their contact details stay in `pii`); the panel table is hidden from `intranet_analytics`, as are free-text reviewer remarks (`wf.approval_comment`). Approval rounds, steps and actions (who approved what, when) stay visible for turnaround reporting.
- **Revised internal marks keep the original.** `exam.internal_mark_revision` records the revised value and reason (registered `RETAIN_LEGAL`) through an approval round; the original mark is never overwritten, so the change stays traceable.
- **ABC / APAAR ID is an identity document, not an academic column.** It is stored app-encrypted in `pii.person_identity_document` (type `APAAR_ID`, `last4` in clear). A credit transfer keeps only the ABC *transaction* reference; `academic.credit_transfer` is hidden from `intranet_analytics`, and its grade point and ABC reference are registered in `data_element` as `RETAIN_LEGAL` academic records.
- **MOOC platforms are not processors by default.** Recording that a student completed an NPTEL course sends no data to NPTEL. If the university later pulls or pushes data through a platform or the ABC portal, that integration must be registered as a `privacy.data_processor` with its purposes.

- **Student feedback is anonymous by construction, not by promise.** `academic.feedback_submission` (one row per course registration per cycle) is the only place a student is linked to feedback, and it shares no key with `academic.feedback_response`, which has no student column at all. Free-text comments are registered as employment data about the teacher (`ANONYMISE` on erasure) and the table is hidden from `intranet_analytics`; reporting uses `academic.v_feedback_summary`.
- **A break in study is health data.** `academic.study_break.reason` and its type (MEDICAL, MATERNITY …) are registered under the HEALTH category with `ANONYMISE`, and the table is withheld from the analytics role; the term-count effect of the break survives erasure because it is derived from the dates, not the reason.
- **Disciplinary cases are sensitive, not public.** `academic.disciplinary_case.description` (what happened, often naming other students) is registered under the new sensitive category DISCIPLINARY with `ANONYMISE`; the `decision` is a `RETAIN_LEGAL` record (it may be needed in an appeal or court). The table is hidden from `intranet_analytics`, and a suspension is visible elsewhere only as a dated study break of type DISCIPLINARY_SUSPENSION.
- **Academic body members are persons.** An external Board of Studies expert is a `people.person` referenced from `academic.academic_body_member` (contact details stay in `pii`); question-wise marks (`exam.question_mark`) are `RETAIN_LEGAL` academic records like component marks.
- **Question papers are confidential, not personal.** `exam.question_paper` holds no personal data but is hidden from `intranet_analytics` until the exam; the setter / moderator identities in `exam.paper_setter_assignment` are ordinary employee references.
- **Certificates are retained records.** `exam.certificate.serial_no`, the public `verification_code` and the NAD / DigiLocker reference are `RETAIN_LEGAL` academic records (the verification code must keep working after a student leaves); the certificate's content is never stored, only derived.
- **Research records** (thesis title, similarity, examiner recommendations, review remarks, supervisor allocation) are `RETAIN_LEGAL` academic / employment records; an external examiner or co-supervisor is a `people.person` whose contact details, if any, live in `pii` like everyone else's.

- **Facilities keep references, not people.** A booking, a loan, a key issue, a parking permit, a guest stay and a trip request all reference `people.person` (or an account); no name, phone or email is copied. The one contact column, `facility.trip_request.contact_phone` (the driver needs it), the journey's origin / destination and coordinates, free-text notes and the pickup photo are registered (`CONTACT`, `ADDRESS`, `IDENTITY`, `PHOTO`) and deleted or anonymised on erasure; driver token hashes are `CREDENTIAL`.
- **A driver's licence is an identity document.** `facility.driver` references `pii.person_identity_document` (with its new `expires_on`) — the number stays encrypted in `pii`; the fleet only learns whether it is valid.
- **Booking restrictions are disciplinary data.** `facility.booking_restriction` (who is barred from which resource and why) is registered under `DISCIPLINARY` and hidden from analytics, as are trip requests, guest stays, key issues, work orders, loans and parking permits (named persons); the booking and event requests themselves (free-text notes) are withheld too; analytics reads the ledger, the utilisation, booking and trip *summaries* only.
- **Ratings are about the driver's work.** `facility.trip_rating` is registered under `EMPLOYMENT` (anonymised on erasure); the old system kept them inside free-text history notes.
- **The occupancy ledger is not audited** (its sources are); it holds no personal data — a hold says a room is taken, `v_room_timeline` shows the use without the requester.

- **Approvals carry decisions, not profiles.** Who approved what and when (`wf.approval_instance`, `approval_step`, `approval_action`, assignees) stays visible for turnaround reporting; the free text — reviewer comments and suggested values, a consultation's question and reply (`wf.approval_consultation`), a delegation's reason — is registered (`IDENTITY`, `ANONYMISE`) and the comment, consultation and delegation tables are withheld from `intranet_analytics`. The note on a submission and on a decision is part of the decision record (`RETAIN_LEGAL`). The notice outbox (`wf.approval_notice`) stores no address: it is looked up when sending.
- **Event participation is voluntary and minimal.** A registration, a team membership, a volunteer duty and a club membership reference `people.person` / `people.student`; nothing about the person is copied. Purposes `EVENT_PARTICIPATION` and `CLUB_MEMBERSHIP` (legitimate use — voluntarily provided). Free-text answers to an event's extra questions (`events.field_response.value`), team messages, application notes and gate remarks are registered and anonymised on erasure.
- **Guests are not data principals of the university's systems.** `events.extra_pass` keeps a guest's name, relationship and (optionally) phone only — registered `DELETE`; an outside speaker on a proposal is a name, designation and organisation (`events.proposal_speaker`, `ANONYMISE`), or a reference to a person already in the system.
- **Event feedback is anonymous by construction**, like course feedback: `events.event_feedback_token` (one per attendee, a hash, used once) shares no key with `events.event_feedback`, which has no person, no registration and a date instead of a timestamp. Neither table is audited (the audit trail would re-link them) and both are hidden from analytics.
- **Tokens and codes:** the registration QR token and the feedback token are stored as hashes (`CREDENTIAL`, `DELETE`); a certificate's serial and public verification code are retained records (`RETAIN_LEGAL`) so verification keeps working after the student leaves — `events.v_certificate_verify` exposes only what a verifier needs.
- **A remark about a person is personal data.** The audit of 2026-10-01 went through every free-text column and registered those that describe an identifiable person: why a teacher is unavailable (`HEALTH`, `ANONYMISE`) and their remarks on a course preference, the reason for a credit overload, a cancelled certificate, a script mark's note and a viva's remarks (`EDUCATION`, `RETAIN_LEGAL`), the details of a data-principal request, its events and a breach description, the reason a role or permission was granted (`RETAIN_LEGAL`), a device's name (`DEVICE_NETWORK`, `DELETE`), a sponsor's name and a certificate's revocation reason. Tables whose remarks may be about health or are a person's own words (`exam.attendance_condonation`, `academic.faculty_unavailability`, `academic.faculty_course_preference`) are withheld from `intranet_analytics`. What stays unregistered is text about institutions and configuration (resolutions, descriptions, policies, article bodies).

- **A vendor may be a person.** A sole proprietor's name and GSTIN (which embeds the proprietor's PAN) identify them, so `facility.vendor.name` and `gstin` are registered (`IDENTITY`, `RETAIN_LEGAL` — kept with the purchase records for as long as tax law requires). The GSTIN is a public registration printed on every invoice, so it is stored in clear, unlike an Aadhaar or a PAN on its own.

- **Reporting on events sees counts, not people.** `intranet_analytics` reads events, proposals, clubs, statistics and points, but not registrations, answers, guests, the gate log, feedback, certificates, club applications, team invitations, speakers, sponsors, stalls or change requests (their views, without the free text, stay readable).
- **Payments are financial records, not profiles.** `events.event_payment` references the registration (or stall application); the gateway's order / payment ids, offline references and refund references are registered under the new category `FINANCIAL` with `RETAIN_LEGAL` (purpose `EVENT_FEE_COLLECTION`, legal obligation, 8 years — POLICY); no card or bank detail is ever stored, and the table is withheld from analytics, which reads only the fees collected per event.
- **Expenses name payees, not participants.** `events.event_expense` (payee, bill number, description) and the settlement remarks are financial records (`FINANCIAL`, `RETAIN_LEGAL`); the table is withheld from analytics, which reads budget against actual per head. Session attendance (`events.round_attendance`) is person-level like the gate log: not audited, hidden from analytics.
- **Bulk mail stores no address.** A recipient of `events.event_mail` is a registration; the address is looked up when sending and is not copied into the delivery log (`event_mail_recipient`, not audited, hidden from analytics). **Open tracking is off by default** and, when an administrator switches it on, is never recorded for a minor (§9(3)) — whether to switch it on at all is a DPO decision.
- **Stall feedback is public and anonymous:** `events.stall_feedback` has no person, no account and a date instead of a time; like event feedback it is not audited. A stall applicant's phone and e-mail are not copied from `pii`.
- **Club change requests and volunteer applications** hold a justification / note (registered, `ANONYMISE`); what they change is references to people already in the system.
- **No tracking from the gate log.** `events.entry_scan` records entry and exit at an event and nothing else; attendance is the only thing derived from it, and no behavioural profile of a participant (in particular of a minor, §9(3)) is built on it.
- **Helpdesk tickets and grievances (`tms`).** A ticket references the requester's account, own phone and (when the category needs it) their batch and course — nothing is copied. Ticket text, relief sought, incident date, timeline remarks and attachments are registered (`SUPPORT_REQUEST`; anonymised or deleted on erasure). A person a complaint is against (`tms.ticket_respondent`) is the sensitive category `GRIEVANCE_CASE`, retained under legal obligation, and that person never sees, handles or is notified about the case. Ragging, sexual-harassment and discrimination complaints are confidential (participants and an explicit permission only); an anonymous complaint keeps the requester for notices but hides them from the people handling it (`tms.requester_shown_to()`). Analytics sees the derived state and the grievance return, never ticket text, timelines, respondents or the per-ticket register. A notice opt-out is registered personal data (`CONTACT`, deleted on erasure); knowledge-base feedback (`tms.kb_feedback`) carries no person at all and is not audited; consulting another office shows a ticket to one more named employee and is refused on confidential tickets. Purposes `HELPDESK` and `GRIEVANCE_REDRESSAL`; design in `docs/tms/tms-design.md`.

## Default purposes and retention (POLICY — confirm before go-live)

| Purpose | Legal basis | Retention (placeholder) |
|---|---|---|
| EMPLOYMENT_ADMINISTRATION | Legitimate use — employment §7(i) | 8 years after separation |
| STUDENT_ADMINISTRATION | Consent (confirm whether an education exemption under the Rules applies) | 10 years after leaving |
| EXAMINATION_AND_RESULTS | Legal obligation (academic records must be retained) | 50 years (placeholder — confirm the statutory period) |
| ACCOUNT_AND_ACCESS | Legitimate use — voluntarily provided §7(a) | 1 year after account closure |
| SECURITY_LOGGING | Legal obligation (CERT-In directions require ≥ 180 days of logs) | 1 year |
| EMERGENCY_CONTACT | Consent | 1 year after relationship ends |
| ID_CARD_PHOTO | Consent | 1 year after relationship ends |
| TEACHING_FEEDBACK | Legitimate use — employment §7(i) (the data is about the teacher; the student is anonymous by construction) | 5 years |
| FACILITY_AND_TRANSPORT_ADMINISTRATION | Legitimate use — voluntarily provided §7(a) (a request for a room, a vehicle, a key) | 3 years |
| GUEST_ACCOMMODATION | Consent (external guests are not members of the university) | 3 years |
| EVENT_PARTICIPATION | Legitimate use — voluntarily provided §7(a) (registering for an event) | 3 years |
| EVENT_FEE_COLLECTION | Legal obligation (financial records of fees, refunds and coupons) | 8 years |
| CLUB_MEMBERSHIP | Legitimate use — voluntarily provided §7(a) (joining or founding a club) | 3 years |
| HELPDESK | Legitimate use — voluntarily provided §7(a) (raising a ticket) | 3 years |
| GRIEVANCE_REDRESSAL | Legal obligation (UGC grievance, anti-ragging and sexual-harassment regulations) | 5 years (placeholder — confirm the statutory period) |

## Operational checklist for modules built on this foundation
1. Register every new personal-data column in `privacy.data_element`, with its category and erasure action.
2. Map each module purpose in `privacy.processing_purpose` and `purpose_data_category`, and add it to the current notice.
3. Call `pii_access_log` when displaying or exporting another person's personal data.
4. Do not copy names, emails or phones into module tables. Reference `people.person` / `pii.person_email` by FK instead.
5. Do not profile, track or target children (§9(3)).
6. Enable auditing on the module schema with `audit.enable_for_schemas`.
