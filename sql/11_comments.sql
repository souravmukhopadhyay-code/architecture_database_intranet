-- =============================================================================
-- 11_comments.sql — Catalog comments (visible in psql \d+, DB tools, Django
-- inspectdb) and the source of docs/data-dictionary.md.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = public;

COMMENT ON SCHEMA util    IS 'Generic helper functions (updated_at trigger, partition management).';
COMMENT ON SCHEMA ref     IS 'Reference / lookup data. Closed value lists as tables, never enums.';
COMMENT ON SCHEMA org     IS 'Organisation structure: org-unit tree, locations, leadership positions.';
COMMENT ON SCHEMA people  IS 'Persons and the roles they play (employee, student, guardian) — non-sensitive.';
COMMENT ON SCHEMA academic IS 'Programmes, specializations, academic years & terms, batches, student enrollment.';
COMMENT ON SCHEMA pii     IS 'Personal data (DPDP). Restricted: no access for analytics.';
COMMENT ON SCHEMA iam     IS 'Accounts, credentials, MFA, devices, sessions, authentication log.';
COMMENT ON SCHEMA authz   IS 'RBAC catalogue, roles, explicit grants and derivation rules.';
COMMENT ON SCHEMA privacy IS 'DPDP Act 2023: notices, consent, rights requests, processors, retention, breaches.';
COMMENT ON SCHEMA audit   IS 'Append-only column-level audit trail.';

-- lookups get a generic comment
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid::regclass AS t, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'ref' AND c.relkind = 'r' LOOP
    EXECUTE format('COMMENT ON TABLE %s IS %L', r.t, 'Lookup: ' || replace(r.relname, '_', ' ') || '.');
  END LOOP;
END $$;
COMMENT ON TABLE ref.country        IS 'Lookup: countries (ISO 3166-1).';
COMMENT ON TABLE ref.state_province IS 'Lookup: states / union territories (ISO 3166-2) per country.';
COMMENT ON TABLE ref.city           IS 'Lookup: cities per state. State and country are reached through city.';
COMMENT ON TABLE ref.language       IS 'Lookup: languages; is_scheduled_language marks the 8th-Schedule languages (DPDP §5(3)).';
COMMENT ON TABLE ref.org_unit_type  IS 'Lookup: kinds of organisational unit (UNIVERSITY, SCHOOL, DEPARTMENT, CENTRAL_DEPARTMENT ...).';
COMMENT ON TABLE ref.academic_calendar_type IS 'Lookup: how programmes divide time (SEMESTER, ANNUAL, PROFESSIONAL_YEAR) and terms per year.';
COMMENT ON TABLE ref.term_cycle     IS 'Lookup: recurring term slots of a calendar type (ODD, EVEN, ANNUAL, PROF_YEAR) and their order in the year.';
COMMENT ON TABLE ref.program_level  IS 'Lookup: UG, PG, integrated, doctoral, diploma, certificate.';
COMMENT ON TABLE ref.grade          IS 'Lookup: officer levels O1–O10 (rank 1 = most senior).';
COMMENT ON TABLE ref.job_function   IS 'Lookup: functional area of work (Academics, Finance, IT…), independent of the org-unit tree.';
COMMENT ON TABLE ref.job_role       IS 'Lookup: what the person actually does (Teaching, Recruitment…), distinct from Designation (the formal title/rank).';
COMMENT ON TABLE ref.reporting_line_type IS 'Lookup: REPORTING (line manager) vs REVIEWING (appraisal / skip-level manager).';
COMMENT ON TABLE ref.account_status IS 'Lookup: account states; can_login gates authentication and authorisation.';
COMMENT ON TABLE ref.legal_basis    IS 'Lookup: DPDP grounds for processing (consent §6 or legitimate use §7).';
COMMENT ON TABLE ref.data_category  IS 'Lookup: categories of personal data; is_sensitive drives redaction and controls.';
COMMENT ON TABLE ref.dpr_request_type IS 'Lookup: data-principal right requests with policy response window.';
COMMENT ON TABLE ref.employment_status IS 'Lookup: employment states; is_current_member = counts as a current employee.';
COMMENT ON TABLE ref.student_status IS 'Lookup: student states; is_current_member = counts as a current student.';

-- org
COMMENT ON TABLE org.org_unit                IS 'One generic tree of organisational units (university → schools → departments; central departments → sections). Type nesting rules + cycle prevention enforced by trigger; exactly one root.';
COMMENT ON TABLE org.org_unit_type_rule      IS 'Which org-unit type may be the parent of which.';
COMMENT ON TABLE org.org_unit_contact        IS 'Official contact points of a unit (office email, phone, website).';
COMMENT ON TABLE org.campus                  IS 'Physical campuses.';
COMMENT ON TABLE org.building                IS 'Buildings / blocks within a campus (shared by all modules).';
COMMENT ON TABLE org.org_unit_location       IS 'Offices of a unit in buildings.';
COMMENT ON TABLE org.position_type           IS 'Single-holder leadership positions (HEAD, DEAN, VC, REGISTRAR, DPO, GRIEVANCE_OFFICER).';
COMMENT ON TABLE org.position_type_unit_type IS 'Which unit types may carry which position.';
COMMENT ON TABLE org.appointment             IS 'Who holds a position of a unit over time; one holder per (unit, position) at any moment.';

-- people / pii
COMMENT ON TABLE people.file_object          IS 'Metadata of stored binaries (photos, notices, consent evidence).';
COMMENT ON TABLE people.person               IS 'The single human entity. Employees, students, guardians and nominees are all persons.';
COMMENT ON TABLE people.person_relationship  IS 'Family / guardian / emergency-contact links between persons.';
COMMENT ON TABLE people.designation          IS 'Master list of designations (replaces free-text designation).';
COMMENT ON TABLE people.employee_reporting_line IS 'Reporting manager (line manager) and reviewing manager (appraisal / skip-level) of an employee over time; one active manager of each type; no reporting-chain cycles.';
COMMENT ON TABLE people.employee             IS 'Employment record of a person.';
COMMENT ON TABLE people.employee_assignment  IS 'Where and as what an employee works over time; exactly one primary assignment at a time.';
COMMENT ON TABLE people.student              IS 'Student record of a person.';
COMMENT ON TABLE people.student_mentor       IS 'Faculty mentor of a student over time (one at a time).';
COMMENT ON TABLE pii.person_profile          IS '1:1 sensitive demographics of a person (DOB, blood group, nationality).';
COMMENT ON TABLE pii.person_email            IS 'Email addresses of a person; globally unique; verified + login-enabled ones can be used to sign in.';
COMMENT ON TABLE pii.person_phone            IS 'Phone numbers (E.164) of a person.';
COMMENT ON TABLE pii.address                 IS 'Postal addresses (may be shared by family members).';
COMMENT ON TABLE pii.person_address          IS 'A person''s address of each type over time.';
COMMENT ON TABLE pii.person_identity_document IS 'Government ID numbers, application-encrypted, with HMAC blind index. Collect only when required.';
COMMENT ON TABLE pii.person_photo            IS 'Photographs of a person over time (one current).';

-- academic
COMMENT ON TABLE academic.program                IS 'Programme offered by an academic unit: level, calendar type, duration in terms, credit range. Duration in years is derived.';
COMMENT ON TABLE academic.specialization         IS 'Specializations / branches within a programme.';
COMMENT ON TABLE academic.program_coordinator    IS 'Coordinator of a programme over time (one at a time).';
COMMENT ON TABLE academic.academic_year          IS 'Academic years, e.g. 2026-27; periods never overlap.';
COMMENT ON TABLE academic.academic_term          IS 'Concrete term = academic year x term cycle (e.g. 2026-27 ODD); inside its year; no overlap within a calendar type.';
COMMENT ON TABLE academic.batch                  IS 'Intake of a programme in an admission year. Batch year and label are derived (academic.v_batch).';
COMMENT ON TABLE academic.batch_document         IS 'Documents attached to a batch (approvals, scheme of studies).';
COMMENT ON TABLE academic.batch_specialization   IS 'Specializations offered to a batch and the term from which they apply.';
COMMENT ON TABLE academic.student_enrollment     IS 'Student in a batch over time (one at a time); entry_term_no > 1 = lateral entry. Home department and current term are derived.';
COMMENT ON TABLE academic.student_specialization IS 'Specialization chosen within an enrollment; must be offered to that batch.';

-- iam
COMMENT ON TABLE iam.user_account         IS 'Login account of a person (Django AUTH_USER_MODEL). username = UID. last_login is derived, not stored.';
COMMENT ON TABLE iam.password_history     IS 'Previous password hashes for the reuse policy.';
COMMENT ON TABLE iam.password_reset_token IS 'Self-service password reset tokens (hashed).';
COMMENT ON TABLE iam.mfa_factor           IS 'Enrolled second factors of an account (supertype).';
COMMENT ON TABLE iam.mfa_totp             IS 'TOTP factor details (secret encrypted by the application).';
COMMENT ON TABLE iam.mfa_webauthn         IS 'Passkey / security-key factor details.';
COMMENT ON TABLE iam.mfa_otp_channel      IS 'Email/SMS OTP factor: which of the person''s own contacts receives codes.';
COMMENT ON TABLE iam.mfa_recovery_code    IS 'Single-use MFA recovery codes (hashed).';
COMMENT ON TABLE iam.otp_challenge        IS 'Issued one-time codes (MFA, step-up, verification, reset).';
COMMENT ON TABLE iam.user_device          IS 'Devices seen for an account; trusted_until = "remember this device".';
COMMENT ON TABLE iam.user_session         IS 'Refresh-token sessions with rotation families and revocation.';
COMMENT ON TABLE iam.account_lockout      IS 'Lockout periods of an account.';
COMMENT ON TABLE iam.auth_event           IS 'Append-only authentication log (monthly partitions). Attempted identifiers stored only as HMAC.';

-- authz
COMMENT ON TABLE authz.app_module          IS 'Application modules; each module registers its resources and permissions.';
COMMENT ON TABLE authz.resource            IS 'Things a module protects. _module = the module itself (for access).';
COMMENT ON TABLE authz.action              IS 'Verbs (access, view, create, update, delete, approve, review, export, assign).';
COMMENT ON TABLE authz.permission          IS 'resource × action. Code module.resource.action is derived (authz.v_permission_code).';
COMMENT ON TABLE authz.role                IS 'Named bundle of permissions; requires_mfa forces MFA for holders.';
COMMENT ON TABLE authz.role_permission     IS 'Permissions contained in a role.';
COMMENT ON TABLE authz.role_inheritance    IS 'Senior role inherits all permissions of the junior role (acyclic).';
COMMENT ON TABLE authz.role_conflict       IS 'Static separation of duties: roles that may not be held together.';
COMMENT ON TABLE authz.account_role        IS 'Explicit, time-bound role grant to an account, globally or on an org-unit subtree.';
COMMENT ON TABLE authz.account_permission  IS 'Exceptional single-permission grant (must be justified).';
COMMENT ON TABLE authz.designation_role    IS 'Rule: holding a designation in an active assignment confers a role (at that unit or globally).';
COMMENT ON TABLE authz.position_role       IS 'Rule: an active appointment to a position confers a role on that unit.';
COMMENT ON TABLE authz.principal_kind_role IS 'Rule: baseline role for every current employee / student / guardian.';

-- privacy
COMMENT ON TABLE privacy.processing_purpose     IS 'Purposes of processing with legal basis and retention period.';
COMMENT ON TABLE privacy.purpose_data_category  IS 'Categories of personal data each purpose needs (data minimisation).';
COMMENT ON TABLE privacy.data_element           IS 'Personal-data inventory: column → category → erasure action. Drives exports, erasure and audit redaction.';
COMMENT ON TABLE privacy.privacy_notice         IS 'Published privacy notices per version and language (§5).';
COMMENT ON TABLE privacy.notice_purpose         IS 'Purposes a notice describes; consent must reference one of these.';
COMMENT ON TABLE privacy.consent                IS 'Consent acts per principal and purpose (§6); withdrawal closes the row; one active per purpose.';
COMMENT ON TABLE privacy.verifiable_parental_consent IS 'Verification of guardian consent for a child (§9).';
COMMENT ON TABLE privacy.nominee                IS 'Nominee who may exercise the principal''s rights (§14).';
COMMENT ON TABLE privacy.data_principal_request IS 'Rights requests: access, correction, erasure, grievance, nomination (§§11–14).';
COMMENT ON TABLE privacy.dpr_request_event      IS 'Status history of a rights request; current status is the latest event.';
COMMENT ON TABLE privacy.data_processor         IS 'Third parties processing personal data on the university''s behalf (§8(2)).';
COMMENT ON TABLE privacy.processor_purpose      IS 'Purposes for which each processor processes data.';
COMMENT ON TABLE privacy.erasure_log            IS 'Evidence of erasure / anonymisation actions (§8(7)).';
COMMENT ON TABLE privacy.breach_incident        IS 'Personal data breach register (§8(6)).';
COMMENT ON TABLE privacy.breach_affected_person IS 'Persons affected by a breach.';
COMMENT ON TABLE privacy.breach_notification    IS 'Breach intimations sent to affected persons.';
COMMENT ON TABLE privacy.pii_access_log         IS 'Who accessed whose personal data for which purpose (monthly partitions).';

-- audit
COMMENT ON TABLE audit.audit_event  IS 'One row per changed row: actor, action, entity, request context (monthly partitions, append-only).';
COMMENT ON TABLE audit.audit_change IS 'One row per changed column; personal-data columns stored as [REDACTED].';

-- ======================================== curriculum, delivery, examination ==
COMMENT ON SCHEMA academic IS 'Programmes, calendar, batches, enrollment; grade scales and schemes of examination; course catalogue and curriculum; offerings, sections, faculty assignment, timetable, class sessions and attendance.';
COMMENT ON SCHEMA exam     IS 'Exam cell operations: eligibility, exam registration, date sheet, seating, invigilation, conduct, anonymous evaluation, marks, grace, published results, marksheets, revaluation.';

COMMENT ON TABLE ref.course_category      IS 'Lookup: core / lab / project / elective kinds; is_elective decides fixed curriculum vs elective basket.';
COMMENT ON TABLE ref.delivery_component   IS 'Lookup: LECTURE / TUTORIAL / PRACTICAL — the L-T-P structure of a course.';
COMMENT ON TABLE ref.assessment_type      IS 'Lookup: kinds of assessment; is_scheduled_exam = has a date sheet, answer scripts and seating (mid-term, end-term).';
COMMENT ON TABLE ref.attendance_status    IS 'Lookup: attendance marks; counts_as_present drives the attendance percentage.';
COMMENT ON TABLE ref.class_session_status IS 'Lookup: scheduled / held / cancelled / rescheduled; only held sessions count and take attendance.';
COMMENT ON TABLE ref.exam_attempt_type    IS 'Lookup: regular / backlog / improvement / supplementary; requires_eligibility applies the attendance & hold check.';
COMMENT ON TABLE ref.evaluation_round     IS 'Lookup: first evaluation / moderation / revaluation; the highest precedence present is the mark that counts.';
COMMENT ON TABLE ref.result_status        IS 'Lookup: pass / fail / absent / withheld / incomplete.';
COMMENT ON TABLE ref.evaluation_part      IS 'Lookup: INTERNAL (continuous) / EXTERNAL (end-semester) part of a scheme; each assessment type belongs to one.';
COMMENT ON TABLE ref.award_type           IS 'Lookup: qualifications a student can leave with (UG certificate, diploma, degree, honours …) — NEP multiple exit.';
COMMENT ON TABLE ref.external_provider_type IS 'Lookup: where external credits come from (university, MOOC platform, industry).';
COMMENT ON TABLE ref.credit_transfer_status IS 'Lookup: submitted / approved / rejected; is_accepted decides whether the credits count.';
COMMENT ON TABLE ref.track_type           IS 'Lookup: minor / honours / honours with research; requires_own_program separates honours (own programme) from a minor (another discipline).';

COMMENT ON TABLE org.room IS 'Rooms in a building (classroom, lab, hall) with teaching capacity and exam capacity; shared by timetable, exam seating and Resource Management.';

COMMENT ON TABLE academic.grade_scale            IS 'A grading policy (e.g. UGC 10-point). New policy = new scale; bands used by published results are frozen.';
COMMENT ON TABLE academic.grade_band             IS 'Percentage range → grade letter + grade point + pass/fail; bands of a scale never overlap.';
COMMENT ON TABLE academic.evaluation_scheme      IS 'A reusable scheme of examination and its result rules as data: aggregate pass mark, internal-lead cap, rounding.';
COMMENT ON TABLE academic.evaluation_component   IS 'One component of a scheme: assessment type, weightage, maximum and optional pass marks, optional best-of group. Weights total 100% (checked at commit).';
COMMENT ON TABLE academic.evaluation_component_group IS '"Best N of M" group of equally weighted components (e.g. best 2 of 3 class tests); only the best best_of count.';
COMMENT ON TABLE academic.evaluation_part_rule   IS 'Minimum pass percentage for one part (internal / external) of a scheme, on top of the aggregate pass mark.';
COMMENT ON TABLE academic.course                 IS 'Course catalogue entry: code, title, credits, owning academic department.';
COMMENT ON TABLE academic.course_component_hours IS 'Weekly contact hours per delivery component (the course''s L-T-P).';
COMMENT ON TABLE academic.course_prerequisite    IS 'Course → prerequisite course (acyclic).';
COMMENT ON TABLE academic.curriculum             IS 'Versioned scheme of studies for a programme, with its grade scale, attendance threshold and cap on transferred credits.';
COMMENT ON TABLE academic.curriculum_course      IS 'A fixed course in a given term of a curriculum, with its category and scheme of examination.';
COMMENT ON TABLE academic.elective_basket        IS 'An elective slot in a curriculum term: choose N courses from the basket.';
COMMENT ON TABLE academic.elective_basket_course IS 'A course offered in an elective basket, with its scheme of examination.';
COMMENT ON TABLE academic.batch_curriculum       IS 'Which curriculum version a batch follows (must be its own programme''s).';
COMMENT ON TABLE academic.course_offering        IS 'A course running in a term, taught by an academic department (may differ from the owner); optional intake limit.';
COMMENT ON TABLE academic.section                IS 'A class section of a batch in a term, with capacity.';
COMMENT ON TABLE academic.section_student        IS 'A student''s section for a term — own batch only, one per term, within capacity.';
COMMENT ON TABLE academic.course_registration    IS 'A student taking a course offering: a curriculum course, an approved equivalent, or a course of the student''s minor/honours track. Scheme/category are derived.';
COMMENT ON TABLE academic.class_group            IS 'A teaching group inside an offering: a lab/tutorial batch of one section (parent_section_id) or an elective group across batches.';
COMMENT ON TABLE academic.class_group_member     IS 'A registered student placed in a class group: same offering, parent section, capacity, one group per component, no timetable clash.';
COMMENT ON TABLE academic.teaching_assignment    IS 'Faculty ↔ offering ↔ class (section, class group, or combined) ↔ L/T/P component over time; one primary per class, co-faculty allowed.';
COMMENT ON TABLE academic.time_slot              IS 'Reusable weekly slot template (ISO weekday, start, end).';
COMMENT ON TABLE academic.faculty_unavailability IS 'Weekly periods a faculty member cannot be timetabled (solver input, enforced on entries).';
COMMENT ON TABLE academic.timetable_entry        IS 'A teaching assignment placed in a slot and room for a date range, weekly or every N weeks; room/faculty/section/student clashes and unavailability are rejected; parallel batches and alternate weeks allowed.';
COMMENT ON TABLE academic.class_session          IS 'A dated class: from a timetable entry, or an extra class with its own time/room; status and substitute faculty.';
COMMENT ON TABLE academic.course_equivalence     IS 'Approved equivalence: passing equivalent_course_id counts as course_id (backlog after a curriculum change, credits before a change).';
COMMENT ON TABLE academic.award_rule             IS 'What a curriculum lets a student leave with and when: award, exit term, minimum credits, re-entry window (NEP multiple exit).';
COMMENT ON TABLE academic.award_rule_course      IS 'Courses that must be completed for an award (e.g. the internship for a UG certificate exit).';
COMMENT ON TABLE academic.student_award          IS 'The award conferred when an enrollment ends (exit certificate / diploma / degree); eligibility checked against the credit ledger.';
COMMENT ON TABLE academic.enrollment_reentry     IS 'A new enrollment resuming the same programme after an exit, within the award''s re-entry window; earlier credits carry forward.';
COMMENT ON TABLE academic.external_provider      IS 'A source of external credits: another university, a MOOC platform (SWAYAM, NPTEL), an industry body.';
COMMENT ON TABLE academic.external_course        IS 'A course at an external provider, with its credits.';
COMMENT ON TABLE academic.external_course_mapping IS 'How an external course counts here for a period: as an internal course or as credits in a category (Board of Studies approval).';
COMMENT ON TABLE academic.credit_transfer        IS 'External credits a student transfers in (ABC / MOOC / other university); on acceptance mapping, curriculum fit and the transfer cap are enforced.';
COMMENT ON TABLE academic.track                  IS 'A minor (another discipline) or honours track (own programme): minimum credits, CGPA entry bar, whether it counts in CGPA.';
COMMENT ON TABLE academic.track_course           IS 'A course of a minor / honours track, with its category and scheme of examination.';
COMMENT ON TABLE academic.student_track          IS 'A student on a minor / honours track over time; one active track per type, CGPA entry bar applied on joining.';
COMMENT ON TABLE academic.attendance             IS 'Attendance of a registered student in a held class session (right course; student must be on the roster of the section/group/combined class).';

COMMENT ON TABLE exam.exam_session           IS 'An examination session in a term (mid-term, end-term, supplementary) with its exam period.';
COMMENT ON TABLE exam.eligibility_hold       IS 'A hold blocking exam eligibility for a term or one course (disciplinary, fee dues, administrative); released, never deleted.';
COMMENT ON TABLE exam.attendance_condonation IS 'Approved exception for an attendance shortage on one course registration.';
COMMENT ON TABLE exam.exam_registration      IS 'A student sitting a course''s exams in a session as a given attempt type; eligibility and paper clashes checked on insert.';
COMMENT ON TABLE exam.exam_schedule          IS 'The date sheet: date and time of a scheduled component of a course offering in a session; student clashes rejected.';
COMMENT ON TABLE exam.exam_room              IS 'Rooms allocated to a paper (must be exam venues).';
COMMENT ON TABLE exam.seat_allocation        IS 'Seating plan: registered student → room + seat; seats unique and capacity respected across concurrent papers.';
COMMENT ON TABLE exam.invigilation_duty      IS 'Invigilator duty per paper and room; one chief per room; no invigilator in two rooms at once.';
COMMENT ON TABLE exam.exam_attendance        IS 'Present / absent / UFM per student per paper.';
COMMENT ON TABLE exam.ufm_case               IS 'Unfair-means case reported in the hall and its committee decision / penalty.';
COMMENT ON TABLE exam.answer_script          IS 'A written script under a random dummy code — the only code ↔ student link (hidden from analytics).';
COMMENT ON TABLE exam.evaluator_assignment   IS 'Evaluator per script per round (first / moderation / revaluation); a different person each round.';
COMMENT ON TABLE exam.script_mark            IS 'Marks given in an assigned round; never overwritten — the highest-precedence round counts.';
COMMENT ON TABLE exam.component_mark         IS 'Marks for non-script components (internals, assignments, practicals, viva), per attempt or carried over.';
COMMENT ON TABLE exam.grace_policy           IS 'Grace-marks policy: maximum marks per course and courses per session.';
COMMENT ON TABLE exam.grace_award            IS 'Grace marks awarded to one exam attempt under a policy.';
COMMENT ON TABLE exam.result_moderation      IS 'Examination-board moderation for one course in one session (± percentage points, with reason); frozen once results are published.';
COMMENT ON TABLE exam.result_publication     IS 'A result release event (original, revised after revaluation, supplementary).';
COMMENT ON TABLE exam.course_result          IS 'Published result of an attempt: official total %, grade band, status. Immutable; corrections are new publications.';
COMMENT ON TABLE exam.marksheet              IS 'Register of issued marksheets (serial number, original vs duplicate).';
COMMENT ON TABLE exam.revaluation_request    IS 'Recheck / revaluation / photocopy request on a script, allowed only after its result is published.';

-- ------------------------------------------- 04d / 04e / 04f additions --
COMMENT ON SCHEMA research IS 'Doctoral / research degrees: supervision, advisory committees, progress reviews, thesis, examiners, viva.';

COMMENT ON TABLE academic.calendar_event         IS 'Academic calendar: holidays, vacations, registration / add-drop windows, exam periods, result dates — per year or term, university-wide or per org unit.';
COMMENT ON TABLE academic.program_approval       IS 'Regulator approval of a programme (UGC / AICTE / NMC …): letter, sanctioned seats, validity; a batch cannot exceed the approved seats.';
COMMENT ON TABLE academic.program_accreditation  IS 'Accreditation of a programme (NBA) or the institution / a unit (NAAC): grade, score, validity.';
COMMENT ON TABLE academic.promotion_rule         IS 'Promotion checkpoint of a curriculum: maximum backlog (credits / courses) a student may carry past term N.';
COMMENT ON TABLE academic.study_break            IS 'Dated break in study (medical, personal, suspension …) on one enrollment; pauses the term count. Reason is health data.';
COMMENT ON TABLE academic.term_registration      IS 'A student on the rolls of an academic term for a programme term number, with the end-of-term academic standing (promoted / with backlog / detained), checked against backlog and promotion rule.';
COMMENT ON TABLE academic.program_transfer       IS 'An enrollment continuing in another programme: old enrollment closed with PROGRAM_CHANGE, new one linked so credits follow through the lineage.';
COMMENT ON TABLE academic.offering_seat_quota    IS 'Ceiling on the seats of an offering for students of one programme or of one org unit and everything under it (cross-school electives); enforced at registration.';
COMMENT ON TABLE academic.elective_preference    IS 'A student''s ranked elective choices in a basket for a term; allotted in merit order by academic.allot_electives().';
COMMENT ON TABLE academic.course_syllabus        IS 'Versioned syllabus of a course (one current at a time), approved by the Board of Studies.';
COMMENT ON TABLE academic.syllabus_unit          IS 'A unit of a syllabus version with its content and contact hours.';
COMMENT ON TABLE academic.course_outcome         IS 'Course outcome (CO) of a syllabus version, with Bloom''s level.';
COMMENT ON TABLE academic.program_outcome        IS 'Programme outcome (PO) or programme-specific outcome (PSO) of a programme.';
COMMENT ON TABLE academic.co_po_mapping          IS 'CO ↔ PO / PSO mapping with strength 1–3; the course must belong to the programme.';
COMMENT ON TABLE academic.lesson_plan_item       IS 'Lesson plan of a teaching assignment: ordered topics tied to syllabus units, with planned hours.';
COMMENT ON TABLE academic.class_session_topic    IS 'Topics actually covered in a class session (course file), optionally tied to the lesson plan item delivered.';
COMMENT ON TABLE academic.workload_norm          IS 'Expected teaching hours per week per designation, dated; actual load is derived (academic.v_faculty_workload).';
COMMENT ON TABLE academic.division_band          IS 'Division / class (first class with distinction …) by CGPA range on a grade scale; read by exam.v_division.';
COMMENT ON TABLE academic.feedback_questionnaire IS 'A reusable student-feedback questionnaire with its rating scale.';
COMMENT ON TABLE academic.feedback_question      IS 'A question of a questionnaire: rating (1..max) or free text.';
COMMENT ON TABLE academic.feedback_cycle         IS 'A feedback round: questionnaire, term, submission window.';
COMMENT ON TABLE academic.feedback_submission    IS 'Proof that a course registration submitted feedback in a cycle (one each) — the only student link, never joined to responses.';
COMMENT ON TABLE academic.feedback_response      IS 'One answer per cycle × teaching assignment × question — no student column (anonymous by construction).';

COMMENT ON TABLE research.supervision_norm         IS 'Maximum doctoral scholars a designation may supervise as principal supervisor at one time (UGC 2022: 8 / 6 / 4).';
COMMENT ON TABLE research.supervisor_allocation    IS 'Supervisor / co-supervisor (may be external) of a scholar over time; one principal supervisor at a time, norm enforced.';
COMMENT ON TABLE research.advisory_committee       IS 'Research advisory / doctoral committee of a scholar (one per enrollment).';
COMMENT ON TABLE research.advisory_committee_member IS 'Dated committee members (employees or external experts); exactly one chair at a time.';
COMMENT ON TABLE research.progress_review          IS 'Periodic progress review of a scholar by the committee, numbered, with outcome.';
COMMENT ON TABLE research.thesis                   IS 'A scholar''s thesis: title, milestone dates in order, status, plagiarism similarity, files; submission needs a principal supervisor.';
COMMENT ON TABLE research.thesis_examiner          IS 'Internal / external examiners of a thesis and their reports; supervisors may not examine.';
COMMENT ON TABLE research.viva                     IS 'The viva voce and its outcome; only after every examiner report is in and none rejects.';

COMMENT ON TABLE exam.paper_setter_assignment   IS 'Setter / moderator of a scheduled component''s paper in a session (employee or external); setter and moderator differ.';
COMMENT ON TABLE exam.question_paper            IS 'A question-paper set with its confidential file; draft → submitted → moderated → approved → printed → used (flags on the status decide what must be present).';
COMMENT ON COLUMN exam.exam_schedule.question_paper_id IS 'The approved question-paper set the paper used.';
COMMENT ON TABLE exam.convocation               IS 'A convocation ceremony at which award certificates are conferred.';
COMMENT ON TABLE exam.certificate               IS 'Register of issued certificates (transcript, provisional / final award certificate, migration, character, bonafide …): serial, public verification code, NAD reference; type rules enforced.';

-- ================================== approval workflow (wf) & SOE content ==
COMMENT ON SCHEMA wf IS 'Generic, permission-based approval workflow: document types, chains of stages (permission × org level), approval rounds, append-only actions, reviewer comments. First users: curriculum / SOE approval and internal-marks revision.';

COMMENT ON TABLE ref.examiner_role     IS 'Lookup: internal / external examiner / chair of a practical or viva panel; is_external = must be an outside person.';
COMMENT ON TABLE ref.wf_action_type    IS 'Lookup: APPROVE / SIGN / RETURN / RETURN_TO / REJECT / WITHDRAW / FORWARD / DELEGATE and the system actions AUTO_APPROVE / AUTO_REJECT / ESCALATE; the flags (completes_step, closes_instance, needs_note, is_system, is_rejection, returns_to_step, reassigns, restarts_clock) drive the workflow rules.';
COMMENT ON TABLE ref.wf_approver_kind  IS 'Lookup: who decides a level — PERMISSION at a unit, POSITION holder, MANAGER of the person concerned, NAMED person(s), COMMITTEE with a quorum.';
COMMENT ON TABLE ref.wf_self_action    IS 'Lookup: what a level does when the requester is its approver — BLOCK (someone else decides) or SKIP (level left out).';
COMMENT ON TABLE ref.wf_timeout_action IS 'Lookup: what happens when a level passes its deadline — NONE / REMIND / ESCALATE / AUTO_APPROVE / AUTO_REJECT.';
COMMENT ON TABLE ref.wf_flag           IS 'Lookup: facts about a request (registered by modules: PAID, EXTERNAL_GUESTS …) on which a level can be made conditional.';
COMMENT ON TABLE ref.wf_notice_kind    IS 'Lookup: kinds of notice in the approval outbox (step pending, reminder, escalated, forwarded, returned, rejected, approved).';
COMMENT ON TABLE ref.wf_comment_status IS 'Lookup: pending / accepted / rejected reviewer comment.';

COMMENT ON TABLE wf.approval_document_type IS 'A kind of document that goes through approval (CURRICULUM, INTERNAL_MARKS_REVISION …) and the permission needed to submit it.';
COMMENT ON TABLE wf.approval_chain         IS 'The approval chain of a document type — default, or overriding it for an org subtree — valid for a period.';
COMMENT ON TABLE wf.approval_chain_stage   IS 'One level of a chain, all configuration: who approves (permission at an org level / position / manager / named / committee), how many, when it applies (amount band, flag), self-approval rule, required file / signature, forwarding and return-to, deadline and timeout action; the signature stage is last.';
COMMENT ON TABLE wf.approval_chain_stage_check IS 'Checklist items an approver of a level must tick before approving (mandatory or optional).';
COMMENT ON TABLE wf.approval_instance_flag IS 'The flags a round was submitted with; level conditions are evaluated on them.';
COMMENT ON TABLE wf.approval_step_assignee IS 'The named approvers of a step: resolved at submission (manager, named, committee members) or added by FORWARD / DELEGATE / ESCALATE; released when handed on.';
COMMENT ON TABLE wf.approval_step_check    IS 'Checklist items ticked by an approver on a step of a round.';
COMMENT ON TABLE wf.approval_delegation    IS 'Standing delegation (out of office): for a bounded period the delegate may act wherever the delegator could, for one document type or all; actions record both.';
COMMENT ON TABLE wf.approval_consultation  IS 'A question put to someone outside the chain by the submitter or a current approver, and the reply; never blocks the round.';
COMMENT ON TABLE wf.approval_notice        IS 'Outbox of approval notices for the application to deliver (pending, reminder, escalated, forwarded, returned, rejected, approved); one of a kind per step, account and day.';
COMMENT ON TABLE wf.approval_instance      IS 'One approval round of one document: owning unit, submitter, time. Created by wf.submit(); append-only.';
COMMENT ON TABLE wf.approval_step IS 'The stages of a round snapshotted at submission, with the anchor unit resolved (the actual department / school / university).';
COMMENT ON TABLE wf.approval_action        IS 'Append-only log of approve / sign / return / withdraw; the round''s status is derived from it (wf.v_instance_state).';
COMMENT ON TABLE wf.approval_comment       IS 'Reviewer remark on a round, optionally on a table / row / column with a suggested value; resolved by the submitter.';

COMMENT ON TABLE academic.curriculum_pathway    IS 'An alternative course set inside a curriculum chosen from a term on (Honours vs Honours with Research).';
COMMENT ON TABLE academic.student_pathway       IS 'A student''s pathway choice over time (one at a time), from their own curriculum; drives registration and awards.';
COMMENT ON TABLE academic.result_group          IS 'Curriculum courses that pass or fail as one combined result (theory + practical), with the combined pass percentage.';
COMMENT ON TABLE academic.attempt_allowance     IS 'Reappear chances per attempt type for a curriculum (e.g. 2 backlog, 1 golden, 1 mercy), on top of max_attempts_per_course.';
COMMENT ON TABLE academic.course_regulator_code IS 'The code a regulator (council) knows a course by — the SOE''s council code; unique per regulator.';
COMMENT ON TABLE academic.course_continuation   IS 'A course that continues an earlier one across terms (Dissertation II ← I); registration needs the earlier part first.';
COMMENT ON TABLE academic.curriculum_approval   IS 'Links a curriculum version (the SOE) to each of its approval rounds; its status is derived from the latest round.';

COMMENT ON TABLE exam.examiner_panel         IS 'Internal / external examiners of a directly-marked scheduled paper (end-term practical, viva); only panel members enter its marks.';
COMMENT ON TABLE exam.internal_mark_revision IS 'Request to revise a published internal mark, decided through the INTERNAL_MARKS_REVISION workflow; the original mark is kept.';

-- ============================================== academic operations (06c) ==
COMMENT ON TABLE ref.leave_type          IS 'Lookup: duty / medical leave; attendance_status_id = how an approved leave day counts in attendance.';
COMMENT ON TABLE ref.prize_type          IS 'Lookup: gold / silver / bronze medal, merit and endowment prizes.';
COMMENT ON TABLE ref.meeting_mode        IS 'Lookup: in person / online / phone mentoring meeting.';
COMMENT ON TABLE ref.section_role        IS 'Lookup: class representative roles in a section.';
COMMENT ON TABLE ref.room_feature        IS 'Lookup: room features (projector, computers, wheelchair access …) a course may require.';
COMMENT ON TABLE ref.question_difficulty IS 'Lookup: easy / medium / hard question.';
COMMENT ON TABLE ref.question_type       IS 'Lookup: MCQ / short / long / numerical / case-study question.';

COMMENT ON TABLE academic.credit_load_rule          IS 'Minimum / maximum credits per term of a curriculum (term_no NULL = default); the maximum is enforced on registration.';
COMMENT ON TABLE academic.credit_overload_approval  IS 'An approved credit overload for one student in one term.';
COMMENT ON TABLE academic.attendance_leave          IS 'Duty / medical leave for a period, approved through the ATTENDANCE_LEAVE workflow; counts in attendance per its leave type.';
COMMENT ON TABLE academic.supervised_work           IS 'A project / dissertation / internship done as a course registration whose category requires supervision.';
COMMENT ON TABLE academic.supervised_work_guide     IS 'Guides of a supervised work over time: one principal (employee) at a time, external co-guides allowed.';
COMMENT ON TABLE academic.internship                IS 'Placement details of an internship: organisation, city, period, industry mentor, offer letter, certificate.';
COMMENT ON TABLE academic.relative_grade_cutoff     IS 'On a relative grade scale: the cohort percentile at which a passing band is awarded.';
COMMENT ON TABLE academic.mentoring_meeting         IS 'A mentor–mentee meeting during a current mentorship, with notes, follow-up date and concern flag (sensitive).';
COMMENT ON TABLE academic.section_representative    IS 'A student holding a role (class representative …) in their section: one holder per role, one role per student.';
COMMENT ON TABLE academic.course_room_requirement   IS 'Room type or feature a course component needs; enforced on timetable entries together with seat capacity.';
COMMENT ON TABLE academic.faculty_course_preference IS 'A teaching employee''s ranked course preferences for a term (allocation input).';
COMMENT ON TABLE org.room_facility                  IS 'Features a room has (projector, computers …) with quantity.';
COMMENT ON TABLE exam.prize                         IS 'A medal / prize for a programme or university-wide, optionally tied to a rank in the programme''s rank list.';
COMMENT ON TABLE exam.prize_award                   IS 'A prize awarded to a graduating student; a rank prize only to the holder of that rank, once per batch.';
COMMENT ON TABLE exam.question_bank_item            IS 'A reusable question for a course tagged by course outcome, Bloom level, difficulty and type; reviewed by a second person.';
COMMENT ON TABLE exam.question_paper_item           IS 'A question of a question paper drawn from the bank; fixed once the paper is approved.';

-- ================================= academic bodies, attainment, discipline ==
COMMENT ON TABLE ref.academic_body_type   IS 'Lookup: Board of Studies, Faculty Board, Academic Council, examination / moderation / disciplinary committees.';
COMMENT ON TABLE ref.misconduct_type      IS 'Lookup: kinds of student misconduct outside the exam hall (ragging, harassment, property damage …).';
COMMENT ON TABLE ref.disciplinary_status  IS 'Lookup: stage of a disciplinary case; is_decided = decision on record, is_terminal = case closed and final.';
COMMENT ON TABLE ref.disciplinary_penalty IS 'Lookup: penalties; requires_suspension = must be served as a DISCIPLINARY_SUSPENSION study break.';

COMMENT ON TABLE academic.academic_body          IS 'A statutory / academic body of an org unit (Board of Studies of a department, Academic Council …) with its quorum.';
COMMENT ON TABLE academic.academic_body_member   IS 'Members of an academic body over time: employees or external experts; one chair (an employee) at a time.';
COMMENT ON TABLE academic.body_meeting           IS 'A meeting of an academic body with its number, date and minutes.';
COMMENT ON TABLE academic.body_meeting_attendee  IS 'Members present at a meeting; each a member of the body on the meeting date.';
COMMENT ON TABLE academic.body_resolution        IS 'A resolution passed at a meeting that had its quorum; referenced by the approvals it authorises (equivalence, MOOC mapping, syllabus, programme transfer).';

COMMENT ON TABLE academic.attainment_policy            IS 'CO attainment thresholds: student target % and the % of students for levels 1/2/3; program_id NULL = university default.';
COMMENT ON TABLE academic.evaluation_component_outcome IS 'Course outcomes assessed by an internal / directly marked component; script-marked exams map outcomes per question instead.';
COMMENT ON TABLE exam.question_mark                    IS 'Marks per question of the paper a student sat; basis of CO attainment; never above the script mark in total; unchangeable once the result is published.';

COMMENT ON TABLE academic.disciplinary_case IS 'A student misconduct case outside exams: report, committee hearing, decision and penalty; a suspension links its study break; closed cases are final.';

-- ================================== resource & facility management (06d) ==
COMMENT ON SCHEMA facility IS 'Resource & facility management: one occupancy ledger for every room (timetable, exams, vivas, convocations, bookings, guest stays, maintenance), configurable pre-emption, bookings approved through wf at the custodian, assets & maintenance, guest house, parking, fleet & transport, keys.';

COMMENT ON TABLE ref.building_kind          IS 'Lookup: BUILDING / OPEN_AREA (grounds, courts) / PARKING — an open area or car park is a "building" whose rooms are its zones.';
COMMENT ON TABLE ref.room_use               IS 'Lookup: FICM-style use classification of a room (classroom, laboratory, office, assembly, guest room, parking zone …) with is_bookable / is_guest_room / is_parking_zone.';
COMMENT ON TABLE ref.hold_type              IS 'Lookup: kind of use in the occupancy ledger (TIMETABLE, EXAM, CONVOCATION, OFFICIAL_EVENT …), the source table that writes it and its default setup / teardown buffers.';
COMMENT ON TABLE ref.booking_purpose        IS 'Lookup: why a room is booked (seminar, meeting, club activity …) → the hold type (and so the priority) it makes.';
COMMENT ON TABLE ref.facility_resource_kind IS 'Lookup: ROOM / ASSET / VEHICLE / GUEST_ROOM / PARKING / KEY — what a booking restriction bars a person from.';
COMMENT ON TABLE ref.booking_restriction_reason IS 'Lookup: why a person is barred (misuse, repeated no-shows, dues, disciplinary).';
COMMENT ON TABLE ref.booking_cancel_reason  IS 'Lookup: why a booking / stay was cancelled; is_system = set by the workflow or a job (RESCHEDULED, NO_SHOW), not chosen by a person.';
COMMENT ON TABLE ref.room_service_type      IS 'Lookup: cleaning / repair / renovation / inspection / fumigation.';
COMMENT ON TABLE ref.asset_type             IS 'Lookup: kinds of asset (projector, computer, air conditioner, lab equipment …).';
COMMENT ON TABLE ref.asset_condition        IS 'Lookup: new / good / fair / under repair / unserviceable / condemned; is_serviceable = may be used or lent.';
COMMENT ON TABLE ref.work_order_category    IS 'Lookup: electrical / plumbing / HVAC / civil / IT-AV / furniture / housekeeping / safety.';
COMMENT ON TABLE ref.work_order_priority    IS 'Lookup: emergency / high / normal / low with resolve_within (the SLA) — POLICY.';
COMMENT ON TABLE ref.work_order_status      IS 'Lookup: reported / assigned / in progress / on hold / closed / rejected; is_terminal ends the work order.';
COMMENT ON TABLE ref.maintenance_type       IS 'Lookup: AMC service, inspection, calibration, deep cleaning, fire safety, pest control.';
COMMENT ON TABLE ref.guest_category         IS 'Lookup: who a guest is (faculty, student, official guest, external examiner, visitor, parent), which kind of person may be booked under it and whether the stay is complimentary.';
COMMENT ON TABLE ref.event_kind             IS 'Lookup: conference / fest / workshop / ceremony / sports meet / exhibition.';
COMMENT ON TABLE ref.key_kind               IS 'Lookup: key / spare key / master key / access card.';
COMMENT ON TABLE ref.parking_permit_type    IS 'Lookup: staff / student / visitor / contractor parking permit.';
COMMENT ON TABLE ref.vehicle_type           IS 'Lookup: car / SUV / van / mini bus / bus / ambulance / truck / two-wheeler; is_passenger.';
COMMENT ON TABLE ref.fuel_type              IS 'Lookup: petrol / diesel / CNG / electric / hybrid.';
COMMENT ON TABLE ref.licence_class          IS 'Lookup: driving-licence classes ranked so that a higher class covers the lower ones (MCWG < LMV < LMV_TR < HMV < HPMV).';
COMMENT ON TABLE ref.vehicle_document_type  IS 'Lookup: RC, insurance, PUC, fitness, permit, road tax; is_mandatory_for_trip = must be valid for the whole trip.';
COMMENT ON TABLE ref.vehicle_service_type   IS 'Lookup: servicing / repair / tyres / accident repair / inspection.';
COMMENT ON TABLE ref.driver_unavailability_reason IS 'Lookup: leave / sick / other duty / training (no free text about health).';
COMMENT ON TABLE ref.trip_purpose           IS 'Lookup: official visit, field visit, guest pick-up, airport transfer, excursion, medical, event logistics.';
COMMENT ON TABLE ref.trip_cancel_reason     IS 'Lookup: why a trip request was cancelled.';
COMMENT ON TABLE ref.trip_alert_type        IS 'Lookup: AUTO_APPROVED / UNALLOCATED_SOON / EXPIRED — alerts raised by the escalation job.';
COMMENT ON TABLE ref.rating_role            IS 'Lookup: PASSENGER (rates the driver) / DRIVER (rates the passengers).';

COMMENT ON TABLE org.floor IS 'A floor of a building (level 0 = ground, negative = basement); rooms may sit on a floor; custody, reservation rules and keys can target a floor.';
COMMENT ON COLUMN org.building.building_kind_id IS 'BUILDING, or an OPEN_AREA / PARKING lot whose rooms are its grounds / zones.';
COMMENT ON COLUMN org.room.room_use_id IS 'FICM-style use classification for the space inventory; drives what may be booked, what is a guest room, what is a parking zone.';
COMMENT ON COLUMN org.room.area_sqm IS 'Floor area, for space returns (NAAC / AICTE).';
COMMENT ON COLUMN pii.person_identity_document.expires_on IS 'Validity of the document itself (driving licence, passport); the fleet refuses a driver whose licence expires before a trip ends.';
COMMENT ON COLUMN wf.approval_chain_stage.anchor_is_owner IS 'The stage''s permission is held at the owning unit itself (its head, a custodian grant), whatever the unit''s type — used by facility rounds owned by a BLOCK or a department.';
COMMENT ON COLUMN ref.wf_action_type.is_system IS 'A system action (AUTO_APPROVE) has no actor and may only be written under app.system_job = on.';

COMMENT ON TABLE facility.room_composition      IS 'A combinable hall: the whole and its parts (one level, same building); a hold on either side shadows the other so the per-room EXCLUDE catches every combination.';
COMMENT ON TABLE facility.custody               IS 'Which org unit manages a room / floor / building / campus for a period (most specific wins); the custodian owns the booking rounds for the space.';
COMMENT ON TABLE facility.space_allocation      IS 'Which org unit occupies a room for a period, with a share (shares of one room never exceed 100 % on a day) — the space inventory.';
COMMENT ON TABLE facility.room_reservation_rule IS 'Reserved / private rooms: while a rule covers a room (or its floor / building), only a requester matching a rule (position holder, unit member, permission holder, named person) may book it; revoke = close the validity.';
COMMENT ON TABLE facility.hold_priority_rule    IS 'Configurable pre-emption: which kind of use outranks which, optionally per room type and custody subtree; no rule = first come, first served.';
COMMENT ON TABLE facility.room_service_window   IS 'Planned maintenance / cleaning of a room (a MAINTENANCE hold), optionally belonging to a work order that releases it when closed.';
COMMENT ON TABLE facility.blackout              IS 'No bookings of a kind of room or of a building for a period (exam weeks, lockdown); institutional holds are unaffected.';
COMMENT ON TABLE facility.room_hold             IS 'THE occupancy ledger: one row per use of one room for one span, written only by triggers from every source; active holds on a room never overlap (gist EXCLUDE incl. buffers); shadows for composed rooms; displacement by higher-priority holds with reinstatement.';
COMMENT ON TABLE facility.booking_policy        IS 'Booking rules per unit (nearest ancestor applies): minimum duration, advance window, self-cancel cut-off, no-show grace, check-in window — POLICY.';
COMMENT ON TABLE facility.booking_restriction   IS 'A person barred from a kind of resource (or all) for a period — disciplinary personal data, hidden from analytics.';
COMMENT ON TABLE facility.event_request         IS 'An event as one package (EVENT_REQUEST round: organising unit head → university); its room / trip requests carry the event and go to their custodians once the event is approved.';
COMMENT ON TABLE facility.booking_group         IS 'Bookings made together (N rooms × M dates, a recurring series): one GRP-YYYY-NNNN for the requester, one request per custodian. Only the reference: requester, title and event are the requests'' (v_booking_summary).';
COMMENT ON TABLE facility.booking_request       IS 'One booking request (who, for which unit, purpose, headcount) approved through a ROOM_BOOKING round owned by the custodian; immutable; a reschedule is a ROOM_BOOKING_CHANGE naming the occurrence it replaces.';
COMMENT ON TABLE facility.booking_requirement   IS 'Room features a request needs (checked against the room''s facilities).';
COMMENT ON TABLE facility.booking_occurrence    IS 'One room for one span of a request: a tentative hold from submission; check-in, cancellation (self until the cut-off, custodian any time); never moved.';
COMMENT ON TABLE facility.vendor                IS 'Suppliers and service providers (AMC, hire, repairs).';
COMMENT ON TABLE facility.asset                 IS 'One physical asset, fixed or portable: tag, type, location room, custodian unit, purchase / warranty, condition, condemnation; portable assets are bookable and loanable.';
COMMENT ON TABLE facility.service_contract      IS 'An AMC / service contract with a vendor for an asset, an asset type or a room''s installations.';
COMMENT ON TABLE facility.booking_asset         IS 'A portable asset booked with a room booking (held for the blocked span, released with it).';
COMMENT ON TABLE facility.asset_loan            IS 'A portable asset lent to a person by the custodian''s staff for a period; early return frees it.';
COMMENT ON TABLE facility.asset_hold            IS 'The asset ledger: one row per use of a portable asset (booking or loan); never two at once.';
COMMENT ON TABLE facility.maintenance_schedule  IS 'Preventive maintenance: what is serviced how often; next due derived; closing a work order of the schedule marks it done.';
COMMENT ON TABLE facility.work_order            IS 'A reported fault / job on a room or asset (WO-YYYY-NNNNN): category, priority with SLA, reporter, assignee employee or vendor, cost; status derived from its events; final once closed.';
COMMENT ON TABLE facility.work_order_event      IS 'Append-only status history of a work order (who, when, note); closing releases its service windows.';
COMMENT ON TABLE facility.guest_stay            IS 'A stay in a guest room by an internal or external guest hosted by a unit (GUEST_STAY round: host unit head → guest house); nights hold the room; charge derived from tariffs.';
COMMENT ON TABLE facility.guest_tariff          IS 'Nightly rate per guest category for a room or a room use, valid for a period — POLICY; complimentary categories pay nothing.';
COMMENT ON TABLE facility.parking_permit        IS 'A person''s vehicle in a parking zone for a period; a zone is never over-allocated; one permit per vehicle at a time.';
COMMENT ON TABLE facility.vehicle               IS 'A university vehicle: registration, type, fuel, passenger seats, minimum licence class, custodian (transport office).';
COMMENT ON TABLE facility.vehicle_document      IS 'RC / insurance / PUC / fitness … of a vehicle with validity; mandatory ones must cover every trip.';
COMMENT ON TABLE facility.vehicle_service_window IS 'Servicing / repair / off-road periods of a vehicle (no allocation across them).';
COMMENT ON TABLE facility.driver                IS 'A driver: an employee with a driving-licence identity document (class, expiry) — the licence is never copied.';
COMMENT ON TABLE facility.driver_unavailability IS 'When a driver cannot drive (leave, sick, other duty, training).';
COMMENT ON TABLE facility.transport_policy      IS 'Transport rules per unit: urgent threshold, auto-approval deadline, alert lead, largest party, minimum notice — POLICY.';
COMMENT ON TABLE facility.trip_request          IS 'A request for a vehicle (who, unit, purpose, from → to with coordinates, departure → return, party size, contact number) approved through TRIP_REQUEST (unit head → transport) or TRIP_REQUEST_URGENT (transport); cancellable until allocated.';
COMMENT ON TABLE facility.trip_allocation       IS 'Dispatch of a driver (first) and a vehicle for a window covering the request; neither is ever double-booked; documents, licence, service windows and unavailability checked; driver token hashes; released = undone.';
COMMENT ON TABLE facility.trip_allocation_request IS 'Pooling: another approved request riding on an existing allocation (inside its window, seats permitting).';
COMMENT ON TABLE facility.trip                  IS 'What happened on the road: start (odometer, pickup photo), completion, closure by the transport office.';
COMMENT ON TABLE facility.trip_rating           IS 'Passenger → driver and driver → passengers ratings (1–5) after a completed trip.';
COMMENT ON TABLE facility.trip_alert            IS 'Alerts of the escalation job (auto-approved, unallocated soon, expired), one of a kind per request.';
COMMENT ON TABLE facility.key_item              IS 'A key / access card opening a room, floor or building, kept by a custodian unit; lost / replaced handling.';
COMMENT ON TABLE facility.key_issue             IS 'The issue register: who holds which key from when (one holder at a time), due and actual return.';
