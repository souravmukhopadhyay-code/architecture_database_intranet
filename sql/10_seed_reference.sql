-- =============================================================================
-- 10_seed_reference.sql — Reference data + core RBAC catalogue + DPDP inventory
--
-- Idempotent-ish starter data (run once on an empty DB). Values marked
-- "POLICY" (retention periods, response days) are placeholders to be confirmed
-- by the university's legal/DPO office.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = public;

-- ---------------------------------------------------------------- geography --
INSERT INTO ref.country (iso2, iso3, name, dial_code) VALUES ('IN', 'IND', 'India', '+91');

INSERT INTO ref.state_province (country_id, code, name)
SELECT ref_country.id, v.code, v.name
FROM (SELECT id FROM ref.country WHERE iso2 = 'IN') ref_country,
(VALUES ('AP','Andhra Pradesh'),('AR','Arunachal Pradesh'),('AS','Assam'),('BR','Bihar'),
        ('CT','Chhattisgarh'),('GA','Goa'),('GJ','Gujarat'),('HR','Haryana'),
        ('HP','Himachal Pradesh'),('JH','Jharkhand'),('KA','Karnataka'),('KL','Kerala'),
        ('MP','Madhya Pradesh'),('MH','Maharashtra'),('MN','Manipur'),('ML','Meghalaya'),
        ('MZ','Mizoram'),('NL','Nagaland'),('OR','Odisha'),('PB','Punjab'),('RJ','Rajasthan'),
        ('SK','Sikkim'),('TN','Tamil Nadu'),('TG','Telangana'),('TR','Tripura'),
        ('UP','Uttar Pradesh'),('UT','Uttarakhand'),('WB','West Bengal'),
        ('AN','Andaman and Nicobar Islands'),('CH','Chandigarh'),
        ('DH','Dadra and Nagar Haveli and Daman and Diu'),('DL','Delhi'),
        ('JK','Jammu and Kashmir'),('LA','Ladakh'),('LD','Lakshadweep'),('PY','Puducherry')
) AS v(code, name);

INSERT INTO ref.city (state_province_id, name)
SELECT s.id, v.city FROM ref.state_province s
JOIN (VALUES ('HR','Gurugram'),('HR','Faridabad'),('DL','New Delhi')) v(st, city) ON v.st = s.code;

-- English + the 22 languages of the Eighth Schedule (DPDP §5(3))
INSERT INTO ref.language (code, label, is_scheduled_language, sort_order) VALUES
 ('en','English',false,0),('as','Assamese',true,1),('bn','Bengali',true,2),('brx','Bodo',true,3),
 ('doi','Dogri',true,4),('gu','Gujarati',true,5),('hi','Hindi',true,6),('kn','Kannada',true,7),
 ('ks','Kashmiri',true,8),('kok','Konkani',true,9),('mai','Maithili',true,10),('ml','Malayalam',true,11),
 ('mni','Manipuri',true,12),('mr','Marathi',true,13),('ne','Nepali',true,14),('or','Odia',true,15),
 ('pa','Punjabi',true,16),('sa','Sanskrit',true,17),('sat','Santali',true,18),('sd','Sindhi',true,19),
 ('ta','Tamil',true,20),('te','Telugu',true,21),('ur','Urdu',true,22);

-- ------------------------------------------------------------ simple lookups --
INSERT INTO ref.gender (code, label, sort_order) VALUES
 ('MALE','Male',1),('FEMALE','Female',2),('TRANSGENDER','Transgender',3),('UNDISCLOSED','Prefer not to say',4);
INSERT INTO ref.blood_group (code, label, sort_order) VALUES
 ('A+','A+',1),('A-','A-',2),('B+','B+',3),('B-','B-',4),('AB+','AB+',5),('AB-','AB-',6),('O+','O+',7),('O-','O-',8);
INSERT INTO ref.contact_purpose (code, label, sort_order) VALUES
 ('OFFICIAL','Official',1),('PERSONAL','Personal',2),('EMERGENCY','Emergency',3);
INSERT INTO ref.contact_channel (code, label, sort_order) VALUES
 ('EMAIL','Email',1),('PHONE','Phone',2),('SMS','SMS',3),('WEBSITE','Website',4),('POSTAL','Postal',5),('IN_APP','In-app',6);
INSERT INTO ref.address_type (code, label, sort_order) VALUES
 ('PERMANENT','Permanent',1),('CURRENT','Current / Local',2),('CORRESPONDENCE','Correspondence',3);
INSERT INTO ref.relationship_type (code, label, sort_order) VALUES
 ('FATHER','Father',1),('MOTHER','Mother',2),('LEGAL_GUARDIAN','Legal guardian',3),('SPOUSE','Spouse',4),
 ('SIBLING','Sibling',5),('CHILD','Child',6),('OTHER','Other',9);
INSERT INTO ref.id_document_type (code, label, sort_order) VALUES
 ('PAN','PAN',1),('PASSPORT','Passport',2),('VOTER_ID','Voter ID',3),('DRIVING_LICENCE','Driving licence',4),
 ('APAAR_ID','APAAR / ABC ID',5),('AADHAAR_VID','Aadhaar Virtual ID (never full Aadhaar)',6);
INSERT INTO ref.storage_backend (code, label, sort_order) VALUES ('S3','Amazon S3',1),('LOCAL','Local filesystem',2);

INSERT INTO ref.org_unit_type (code, label, is_academic, sort_order) VALUES
 ('UNIVERSITY','University',true,1),('SCHOOL','School / Faculty',true,2),('DEPARTMENT','Academic department',true,3),
 ('CENTRE','Centre / Lab',true,4),('CENTRAL_DEPARTMENT','Central department',false,5),('SECTION','Section / Cell',false,6);

INSERT INTO ref.principal_kind (code, label, sort_order) VALUES
 ('EMPLOYEE','Employee',1),('STUDENT','Student',2),('GUARDIAN','Guardian',3);
INSERT INTO ref.employee_category (code, label, sort_order) VALUES
 ('TEACHING','Teaching',1),('NON_TEACHING','Non-teaching',2);
INSERT INTO ref.employment_type (code, label, sort_order) VALUES
 ('PERMANENT','Permanent',1),('CONTRACT','Contract',2),('TEMPORARY','Temporary',3),('VISITING','Visiting',4),('ADJUNCT','Adjunct',5);
INSERT INTO ref.employment_status (code, label, is_current_member, sort_order) VALUES
 ('ACTIVE','Active',true,1),('ON_LEAVE','On long leave',true,2),('SUSPENDED','Suspended',false,3),
 ('RESIGNED','Resigned',false,4),('RETIRED','Retired',false,5),('TERMINATED','Terminated',false,6);
INSERT INTO ref.student_status (code, label, is_current_member, sort_order) VALUES
 ('ACTIVE','Active',true,1),('GRADUATED','Graduated',false,3),   -- a break in study is a dated academic.study_break, not a status
 ('WITHDRAWN','Withdrawn',false,4),('EXPELLED','Expelled',false,5);
-- academic lookups
INSERT INTO ref.program_level (code, label, sort_order) VALUES
 ('UG','Undergraduate',1),('PG','Postgraduate',2),('INTEGRATED','Integrated UG+PG',3),('DOCTORAL','Doctoral',4),
 ('DIPLOMA','Diploma',5),('PG_DIPLOMA','Postgraduate diploma',6),('CERTIFICATE','Certificate',7);
INSERT INTO ref.academic_calendar_type (code, label, terms_per_year, sort_order) VALUES
 ('SEMESTER','Semester based',2,1),('ANNUAL','Annual',1,2),('PROFESSIONAL_YEAR','Professional-year based',1,3);
INSERT INTO ref.term_cycle (academic_calendar_type_id, code, label, position)
SELECT ref.id_of('academic_calendar_type', v.cal), v.code, v.label, v.pos
FROM (VALUES ('SEMESTER','ODD','Odd semester',1),('SEMESTER','EVEN','Even semester',2),
             ('ANNUAL','ANNUAL','Annual',1),('PROFESSIONAL_YEAR','PROF_YEAR','Professional year',1)) v(cal, code, label, pos);

INSERT INTO ref.grade (code, label, rank)
SELECT 'O' || g, 'Officer level ' || g, g FROM generate_series(1, 10) g;

INSERT INTO ref.account_status (code, label, can_login, sort_order) VALUES
 ('PENDING_ACTIVATION','Pending activation',false,1),('ACTIVE','Active',true,2),
 ('SUSPENDED','Suspended',false,3),('DISABLED','Disabled',false,4),('ANONYMISED','Anonymised (erased)',false,5);
INSERT INTO ref.mfa_factor_type (code, label, sort_order) VALUES
 ('TOTP','Authenticator app (TOTP)',1),('WEBAUTHN','Passkey / security key',2),
 ('EMAIL_OTP','One-time code by email',3),('SMS_OTP','One-time code by SMS',4);
INSERT INTO ref.otp_purpose (code, label, sort_order) VALUES
 ('LOGIN_MFA','Login second factor',1),('STEP_UP','Step-up for sensitive action',2),
 ('EMAIL_VERIFY','Email verification',3),('PHONE_VERIFY','Phone verification',4),('PASSWORD_RESET','Password reset',5);
INSERT INTO ref.auth_event_type (code, label, sort_order) VALUES
 ('LOGIN_SUCCESS','Login succeeded',1),('LOGIN_FAILURE','Login failed',2),('MFA_CHALLENGE_SENT','MFA challenge sent',3),
 ('MFA_SUCCESS','MFA succeeded',4),('MFA_FAILURE','MFA failed',5),('LOGOUT','Logout',6),('TOKEN_REFRESH','Token refreshed',7),
 ('TOKEN_REUSE_DETECTED','Refresh-token reuse detected',8),('PASSWORD_CHANGED','Password changed',9),
 ('PASSWORD_RESET_REQUESTED','Password reset requested',10),('PASSWORD_RESET_COMPLETED','Password reset completed',11),
 ('ACCOUNT_LOCKED','Account locked',12),('ACCOUNT_UNLOCKED','Account unlocked',13),
 ('MFA_ENROLLED','MFA factor enrolled',14),('MFA_REMOVED','MFA factor removed',15);
INSERT INTO ref.auth_failure_reason (code, label, sort_order) VALUES
 ('UNKNOWN_IDENTIFIER','Unknown UID/email',1),('BAD_PASSWORD','Wrong password',2),('ACCOUNT_INACTIVE','Account cannot log in',3),
 ('ACCOUNT_LOCKED','Account locked',4),('MFA_INVALID','Invalid second factor',5),('MFA_EXPIRED','Expired challenge',6),
 ('RATE_LIMITED','Rate limited',7);
INSERT INTO ref.session_revoke_reason (code, label, sort_order) VALUES
 ('LOGOUT','User logged out',1),('ROTATED','Rotated on refresh',2),('REUSE_DETECTED','Token reuse detected',3),
 ('PASSWORD_CHANGED','Password changed',4),('ADMIN_REVOKED','Revoked by administrator',5),
 ('ACCOUNT_DISABLED','Account disabled',6),('EXPIRED','Expired',7);
INSERT INTO ref.lockout_reason (code, label, sort_order) VALUES
 ('FAILED_LOGINS','Too many failed logins',1),('FAILED_MFA','Too many failed MFA attempts',2),
 ('ADMIN_ACTION','Administrator action',3),('SUSPICIOUS_ACTIVITY','Suspicious activity',4);

-- DPDP (legal bases: verify mapping with counsel — POLICY)
INSERT INTO ref.legal_basis (code, label, dpdp_section, requires_consent, sort_order) VALUES
 ('CONSENT','Consent of the data principal','§6',true,1),
 ('LU_VOLUNTARY','Voluntarily provided for a specified purpose','§7(a)',false,2),
 ('LU_LEGAL_OBLIGATION','Compliance with law / judgment','§7(d),(e)',false,3),
 ('LU_MEDICAL_EMERGENCY','Medical emergency / safety','§7(f),(h)',false,4),
 ('LU_EMPLOYMENT','Employment purposes','§7(i)',false,5);
INSERT INTO ref.data_category (code, label, is_sensitive, sort_order) VALUES
 ('IDENTITY','Name & identity',false,1),('CONTACT','Contact details',false,2),('DEMOGRAPHIC','Demographics',false,3),
 ('ADDRESS','Address',false,4),('HEALTH','Health (e.g. blood group)',true,5),('GOVERNMENT_ID','Government ID',true,6),
 ('PHOTO','Photograph',true,7),('CREDENTIAL','Credentials & secrets',true,8),('EMPLOYMENT','Employment',false,9),
 ('EDUCATION','Education',false,10),('DEVICE_NETWORK','Device & network identifiers',false,11),
 ('RELATIONSHIP','Family & guardians',false,12);
INSERT INTO ref.erasure_action (code, label, sort_order) VALUES
 ('DELETE','Delete value / row',1),('ANONYMISE','Replace with anonymised value',2),('RETAIN_LEGAL','Retain under legal obligation',3);
INSERT INTO ref.consent_channel (code, label, sort_order) VALUES
 ('WEB','Web portal',1),('MOBILE_APP','Mobile app',2),('PAPER','Signed paper form',3),
 ('CONSENT_MANAGER','Registered Consent Manager',4),('EMAIL','Email',5);
INSERT INTO ref.verification_method (code, label, sort_order) VALUES
 ('EXISTING_GUARDIAN_ACCOUNT','Verified guardian account on the portal',1),('DIGILOCKER_TOKEN','DigiLocker / virtual token',2),
 ('OFFLINE_DOCUMENT','Documents verified in person',3),('OTP_TO_GUARDIAN','OTP to guardian''s verified contact',4);
INSERT INTO ref.dpr_request_type (code, label, dpdp_section, response_days, sort_order) VALUES   -- response_days: POLICY
 ('ACCESS_SUMMARY','Summary of personal data processed','§11',30,1),
 ('CORRECTION','Correction / completion / updating','§12',30,2),
 ('ERASURE','Erasure','§12',30,3),
 ('GRIEVANCE','Grievance redressal','§13',30,4),
 ('NOMINATION','Nominate a representative','§14',30,5),
 ('CONSENT_WITHDRAWAL','Withdraw consent','§6(4)',7,6);
INSERT INTO ref.dpr_status (code, label, is_terminal, sort_order) VALUES
 ('SUBMITTED','Submitted',false,1),('ACKNOWLEDGED','Acknowledged',false,2),('IN_PROGRESS','In progress',false,3),
 ('AWAITING_PRINCIPAL','Awaiting data principal',false,4),('COMPLETED','Completed',true,5),
 ('REJECTED','Rejected with reasons',true,6),('WITHDRAWN','Withdrawn by requester',true,7);
INSERT INTO ref.breach_severity (code, label, sort_order) VALUES ('LOW','Low',1),('MEDIUM','Medium',2),('HIGH','High',3),('CRITICAL','Critical',4);
INSERT INTO ref.breach_status (code, label, is_terminal, sort_order) VALUES
 ('DETECTED','Detected',false,1),('CONTAINED','Contained',false,2),('INVESTIGATING','Investigating',false,3),
 ('NOTIFIED','Board & principals notified',false,4),('CLOSED','Closed',true,5);
-- ref.audit_action is seeded in 01_ref.sql (the audit trigger depends on it)

-- ------------------------------------------------------- org type rules etc. --
INSERT INTO org.org_unit_type_rule (parent_type_id, child_type_id)
SELECT ref.id_of('org_unit_type', p), ref.id_of('org_unit_type', c)
FROM (VALUES ('UNIVERSITY','SCHOOL'),('UNIVERSITY','CENTRAL_DEPARTMENT'),('UNIVERSITY','CENTRE'),
             ('SCHOOL','DEPARTMENT'),('SCHOOL','CENTRE'),('DEPARTMENT','CENTRE'),
             ('CENTRAL_DEPARTMENT','SECTION'),('SECTION','SECTION')) v(p, c);

INSERT INTO org.position_type (code, label, sort_order) VALUES
 ('VICE_CHANCELLOR','Vice Chancellor',1),('PRO_VICE_CHANCELLOR','Pro Vice Chancellor',2),('REGISTRAR','Registrar',3),
 ('DEAN','Dean',4),('HEAD','Head',5),('DPO','Data Protection Officer',6),('GRIEVANCE_OFFICER','Grievance Officer',7);

INSERT INTO org.position_type_unit_type (position_type_id, org_unit_type_id)
SELECT pt.id, ref.id_of('org_unit_type', v.t)
FROM (VALUES ('VICE_CHANCELLOR','UNIVERSITY'),('PRO_VICE_CHANCELLOR','UNIVERSITY'),('REGISTRAR','UNIVERSITY'),
             ('DPO','UNIVERSITY'),('GRIEVANCE_OFFICER','UNIVERSITY'),('DEAN','SCHOOL'),
             ('HEAD','DEPARTMENT'),('HEAD','CENTRE'),('HEAD','CENTRAL_DEPARTMENT'),('HEAD','SECTION')) v(p, t)
JOIN org.position_type pt ON pt.code = v.p;

-- job function / job role / reporting-line-type lookups
INSERT INTO ref.job_function (code, label, sort_order) VALUES
 ('ACADEMICS','Academics',1),('RESEARCH','Research',2),('ADMINISTRATION','Administration',3),
 ('FINANCE','Finance & Accounts',4),('HUMAN_RESOURCES','Human Resources',5),
 ('INFORMATION_TECHNOLOGY','Information Technology',6),('LIBRARY','Library',7),
 ('EXAMINATIONS','Examinations',8),('ADMISSIONS','Admissions',9),
 ('ESTATE_SECURITY','Estate & Security',10),('STUDENT_AFFAIRS','Student Affairs',11);
INSERT INTO ref.job_role (code, label, sort_order) VALUES
 ('TEACHING','Teaching',1),('RESEARCH_SUPERVISION','Research supervision',2),
 ('ACADEMIC_ADMINISTRATION','Academic administration',3),('RECRUITMENT','Recruitment',4),
 ('PAYROLL_PROCESSING','Payroll processing',5),('TECHNICAL_SUPPORT','Technical support',6),
 ('CURRICULUM_DESIGN','Curriculum design',7),('STUDENT_COUNSELLING','Student counselling',8),
 ('FRONT_OFFICE','Front office / reception',9),('SECURITY_OPERATIONS','Security operations',10);
INSERT INTO ref.reporting_line_type (code, label, sort_order) VALUES
 ('REPORTING','Reporting manager',1),('REVIEWING','Reviewing manager',2);

INSERT INTO people.designation (code, title, employee_category_id) VALUES
 ('PROFESSOR','Professor', ref.id_of('employee_category','TEACHING')),
 ('ASSOCIATE_PROFESSOR','Associate Professor', ref.id_of('employee_category','TEACHING')),
 ('ASSISTANT_PROFESSOR','Assistant Professor', ref.id_of('employee_category','TEACHING')),
 ('REGISTRAR_OFFICER','Registrar Office Officer', ref.id_of('employee_category','NON_TEACHING')),
 ('HR_MANAGER','HR Manager', ref.id_of('employee_category','NON_TEACHING')),
 ('HR_EXECUTIVE','HR Executive', ref.id_of('employee_category','NON_TEACHING')),
 ('ADMISSION_OFFICER','Admission Officer', ref.id_of('employee_category','NON_TEACHING')),
 ('ACCOUNTANT','Accountant', ref.id_of('employee_category','NON_TEACHING')),
 ('LIBRARIAN','Librarian', ref.id_of('employee_category','NON_TEACHING')),
 ('SYSTEM_ADMINISTRATOR','System Administrator', ref.id_of('employee_category','NON_TEACHING')),
 ('SECURITY_GUARD','Security Guard', ref.id_of('employee_category','NON_TEACHING'));

-- ======================================================= core RBAC catalogue ==
INSERT INTO authz.app_module (code, name, description) VALUES
 ('core_admin','Core administration','Organisation, people, accounts, roles'),
 ('privacy','Privacy (DPDP)','Consent, data-principal requests, breaches'),
 ('audit','Audit','Audit trail and authentication logs'),
 ('self_service','Self service','A user''s own profile, sessions, MFA and privacy rights');

INSERT INTO authz.action (code, label) VALUES
 ('access','Access module'),('view','View'),('create','Create'),('update','Update'),('delete','Delete'),
 ('approve','Approve'),('review','Review'),('export','Export'),('assign','Assign / grant');

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('core_admin','_module','Core administration module'),('core_admin','org_unit','Organisation units'),
  ('core_admin','appointment','Appointments'),('core_admin','person','Persons'),('core_admin','employee','Employees'),
  ('core_admin','student','Students'),('core_admin','account','User accounts'),('core_admin','role','Roles & permissions'),
  ('core_admin','role_grant','Role grants'),('core_admin','designation','Designations'),
  ('core_admin','reporting_line','Reporting & reviewing manager'),
  ('core_admin','program','Programmes & specializations'),('core_admin','academic_calendar','Academic years & terms'),
  ('core_admin','batch','Batches'),('core_admin','enrollment','Student enrollment'),
  ('privacy','_module','Privacy module'),('privacy','consent','Consents'),('privacy','request','Data-principal requests'),
  ('privacy','breach','Breach register'),('privacy','notice','Privacy notices'),
  ('audit','_module','Audit module'),('audit','audit_log','Audit trail'),('audit','auth_log','Authentication log'),
  ('self_service','profile','Own profile'),('self_service','privacy_rights','Own privacy rights')
) v(m, code, label) ON v.m = m.code;

-- permission matrix: (module, resource, action, is_scopable)
INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, v.scopable
FROM (VALUES
  ('core_admin','_module','access',true),
  ('core_admin','org_unit','view',true),('core_admin','org_unit','create',true),('core_admin','org_unit','update',true),
  ('core_admin','appointment','view',true),('core_admin','appointment','assign',true),
  ('core_admin','person','view',true),('core_admin','person','update',true),
  ('core_admin','employee','view',true),('core_admin','employee','create',true),('core_admin','employee','update',true),
  ('core_admin','student','view',true),('core_admin','student','create',true),('core_admin','student','update',true),
  ('core_admin','account','view',true),('core_admin','account','create',true),('core_admin','account','update',true),
  ('core_admin','role','view',false),('core_admin','role','create',false),('core_admin','role','update',false),
  ('core_admin','role_grant','assign',true),
  ('core_admin','designation','view',false),('core_admin','designation','update',false),
  ('core_admin','reporting_line','view',true),('core_admin','reporting_line','assign',true),
  ('core_admin','program','view',true),('core_admin','program','create',true),('core_admin','program','update',true),
  ('core_admin','academic_calendar','view',false),('core_admin','academic_calendar','update',false),
  ('core_admin','batch','view',true),('core_admin','batch','create',true),('core_admin','batch','update',true),
  ('core_admin','enrollment','view',true),('core_admin','enrollment','create',true),('core_admin','enrollment','update',true),
  ('privacy','_module','access',false),('privacy','consent','view',false),('privacy','request','view',false),
  ('privacy','request','review',false),('privacy','breach','view',false),('privacy','breach','update',false),
  ('privacy','notice','update',false),
  ('audit','_module','access',false),('audit','audit_log','view',false),('audit','audit_log','export',false),
  ('audit','auth_log','view',false),
  ('self_service','profile','view',false),('self_service','profile','update',false),
  ('self_service','privacy_rights','create',false)
) v(m, res, act, scopable)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('SELF_SERVICE','Self service','Every signed-in person: own profile & privacy rights',true,false),
 ('EMPLOYEE_BASE','Employee baseline','Default for all current employees',true,false),
 ('STUDENT_BASE','Student baseline','Default for all current students',true,false),
 ('GUARDIAN_BASE','Guardian baseline','Default for guardians of current students',true,false),
 ('ORG_UNIT_HEAD','Unit head','View people and structure of the unit led',true,false),
 ('HR_ADMIN','HR administrator','Manage employees and their assignments',true,true),
 ('ACADEMIC_ADMIN','Academic administrator','Manage students and their affiliation',true,true),
 ('ACCESS_ADMIN','Access administrator','Manage accounts, roles and grants',true,true),
 ('CORE_ADMIN','Core administrator','Full core administration',true,true),
 ('DPO','Data Protection Officer','Privacy register, requests and breaches',true,true),
 ('AUDITOR','Auditor','Read-only access to audit trails',true,true);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('SELF_SERVICE','self_service.profile.view'),('SELF_SERVICE','self_service.profile.update'),
  ('SELF_SERVICE','self_service.privacy_rights.create'),
  ('ORG_UNIT_HEAD','core_admin.org_unit.view'),('ORG_UNIT_HEAD','core_admin.employee.view'),
  ('ORG_UNIT_HEAD','core_admin.student.view'),('ORG_UNIT_HEAD','core_admin.appointment.view'),
  ('ORG_UNIT_HEAD','core_admin.program.view'),('ORG_UNIT_HEAD','core_admin.batch.view'),
  ('ORG_UNIT_HEAD','core_admin.enrollment.view'),('ORG_UNIT_HEAD','core_admin.reporting_line.view'),
  ('HR_ADMIN','core_admin._module.access'),('HR_ADMIN','core_admin.org_unit.view'),
  ('HR_ADMIN','core_admin.person.view'),('HR_ADMIN','core_admin.person.update'),
  ('HR_ADMIN','core_admin.employee.view'),('HR_ADMIN','core_admin.employee.create'),('HR_ADMIN','core_admin.employee.update'),
  ('HR_ADMIN','core_admin.designation.view'),('HR_ADMIN','core_admin.appointment.view'),
  ('HR_ADMIN','core_admin.reporting_line.view'),('HR_ADMIN','core_admin.reporting_line.assign'),
  ('ACADEMIC_ADMIN','core_admin._module.access'),('ACADEMIC_ADMIN','core_admin.org_unit.view'),
  ('ACADEMIC_ADMIN','core_admin.person.view'),('ACADEMIC_ADMIN','core_admin.person.update'),
  ('ACADEMIC_ADMIN','core_admin.student.view'),('ACADEMIC_ADMIN','core_admin.student.create'),
  ('ACADEMIC_ADMIN','core_admin.student.update'),
  ('ACADEMIC_ADMIN','core_admin.program.view'),('ACADEMIC_ADMIN','core_admin.program.create'),
  ('ACADEMIC_ADMIN','core_admin.program.update'),('ACADEMIC_ADMIN','core_admin.academic_calendar.view'),
  ('ACADEMIC_ADMIN','core_admin.batch.view'),('ACADEMIC_ADMIN','core_admin.batch.create'),
  ('ACADEMIC_ADMIN','core_admin.batch.update'),('ACADEMIC_ADMIN','core_admin.enrollment.view'),
  ('ACADEMIC_ADMIN','core_admin.enrollment.create'),('ACADEMIC_ADMIN','core_admin.enrollment.update'),
  ('ACCESS_ADMIN','core_admin._module.access'),('ACCESS_ADMIN','core_admin.account.view'),
  ('ACCESS_ADMIN','core_admin.account.create'),('ACCESS_ADMIN','core_admin.account.update'),
  ('ACCESS_ADMIN','core_admin.role.view'),('ACCESS_ADMIN','core_admin.role_grant.assign'),
  ('CORE_ADMIN','core_admin.org_unit.create'),('CORE_ADMIN','core_admin.org_unit.update'),
  ('CORE_ADMIN','core_admin.appointment.assign'),('CORE_ADMIN','core_admin.role.create'),
  ('CORE_ADMIN','core_admin.role.update'),('CORE_ADMIN','core_admin.designation.update'),
  ('CORE_ADMIN','core_admin.academic_calendar.update'),
  ('DPO','privacy._module.access'),('DPO','privacy.consent.view'),('DPO','privacy.request.view'),
  ('DPO','privacy.request.review'),('DPO','privacy.breach.view'),('DPO','privacy.breach.update'),
  ('DPO','privacy.notice.update'),
  ('AUDITOR','audit._module.access'),('AUDITOR','audit.audit_log.view'),('AUDITOR','audit.audit_log.export'),
  ('AUDITOR','audit.auth_log.view')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- hierarchy: baselines include self-service; CORE_ADMIN includes the admin roles
INSERT INTO authz.role_inheritance (senior_role_id, junior_role_id)
SELECT s.id, j.id FROM (VALUES
  ('EMPLOYEE_BASE','SELF_SERVICE'),('STUDENT_BASE','SELF_SERVICE'),('GUARDIAN_BASE','SELF_SERVICE'),
  ('CORE_ADMIN','HR_ADMIN'),('CORE_ADMIN','ACADEMIC_ADMIN'),('CORE_ADMIN','ACCESS_ADMIN')
) v(s, j)
JOIN authz.role s ON s.code = v.s JOIN authz.role j ON j.code = v.j;

-- separation of duties: whoever administers access/data must not audit it
INSERT INTO authz.role_conflict (role_a_id, role_b_id, reason)
SELECT LEAST(a.id, b.id), GREATEST(a.id, b.id), v.reason FROM (VALUES
  ('AUDITOR','CORE_ADMIN','Auditors must be independent of administrators'),
  ('AUDITOR','ACCESS_ADMIN','Auditors must be independent of access administrators')
) v(a, b, reason)
JOIN authz.role a ON a.code = v.a JOIN authz.role b ON b.code = v.b;

-- derivation rules
INSERT INTO authz.principal_kind_role (principal_kind_id, role_id, scope_to_home_unit)
SELECT ref.id_of('principal_kind', v.k), r.id, false
FROM (VALUES ('EMPLOYEE','EMPLOYEE_BASE'),('STUDENT','STUDENT_BASE'),('GUARDIAN','GUARDIAN_BASE')) v(k, role_code)
JOIN authz.role r ON r.code = v.role_code;

INSERT INTO authz.position_role (position_type_id, role_id, include_descendants)
SELECT pt.id, r.id, true FROM (VALUES
  ('HEAD','ORG_UNIT_HEAD'),('DEAN','ORG_UNIT_HEAD'),('VICE_CHANCELLOR','ORG_UNIT_HEAD'),
  ('REGISTRAR','ORG_UNIT_HEAD'),('DPO','DPO')
) v(p, role_code)
JOIN org.position_type pt ON pt.code = v.p JOIN authz.role r ON r.code = v.role_code;

INSERT INTO authz.designation_role (designation_id, role_id, scope_to_assignment_unit, include_descendants)
SELECT d.id, r.id, v.scoped, true FROM (VALUES
  ('HR_MANAGER','HR_ADMIN',false),            -- global: all employees
  ('ADMISSION_OFFICER','ACADEMIC_ADMIN',false)
) v(d, role_code, scoped)
JOIN people.designation d ON d.code = v.d JOIN authz.role r ON r.code = v.role_code;

-- ================================================ DPDP purposes & inventory ==
INSERT INTO privacy.processing_purpose (code, label, description, legal_basis_id, retention_period) VALUES   -- retention: POLICY
 ('EMPLOYMENT_ADMINISTRATION','Employment administration','HR records, org assignment, payroll linkage',
   ref.id_of('legal_basis','LU_EMPLOYMENT'), interval '8 years'),
 ('STUDENT_ADMINISTRATION','Student administration','Enrolment, affiliation, mentoring, student services',
   ref.id_of('legal_basis','CONSENT'), interval '10 years'),
 ('ACCOUNT_AND_ACCESS','Account & access management','Login, MFA, sessions, authorisation',
   ref.id_of('legal_basis','LU_VOLUNTARY'), interval '1 year'),
 ('SECURITY_LOGGING','Security logging','Authentication and audit logs (CERT-In: >= 180 days)',
   ref.id_of('legal_basis','LU_LEGAL_OBLIGATION'), interval '1 year'),
 ('EMERGENCY_CONTACT','Emergency contact','Guardian / emergency contact details',
   ref.id_of('legal_basis','CONSENT'), interval '1 year'),
 ('ID_CARD_PHOTO','ID card & photograph','Photograph for identity card and access control',
   ref.id_of('legal_basis','CONSENT'), interval '1 year');

INSERT INTO privacy.purpose_data_category (purpose_id, data_category_id)
SELECT pp.id, ref.id_of('data_category', v.c) FROM (VALUES
  ('EMPLOYMENT_ADMINISTRATION','IDENTITY'),('EMPLOYMENT_ADMINISTRATION','CONTACT'),('EMPLOYMENT_ADMINISTRATION','DEMOGRAPHIC'),
  ('EMPLOYMENT_ADMINISTRATION','ADDRESS'),('EMPLOYMENT_ADMINISTRATION','EMPLOYMENT'),('EMPLOYMENT_ADMINISTRATION','GOVERNMENT_ID'),
  ('STUDENT_ADMINISTRATION','IDENTITY'),('STUDENT_ADMINISTRATION','CONTACT'),('STUDENT_ADMINISTRATION','DEMOGRAPHIC'),
  ('STUDENT_ADMINISTRATION','ADDRESS'),('STUDENT_ADMINISTRATION','EDUCATION'),('STUDENT_ADMINISTRATION','RELATIONSHIP'),
  ('ACCOUNT_AND_ACCESS','IDENTITY'),('ACCOUNT_AND_ACCESS','CONTACT'),('ACCOUNT_AND_ACCESS','CREDENTIAL'),
  ('SECURITY_LOGGING','DEVICE_NETWORK'),
  ('EMERGENCY_CONTACT','RELATIONSHIP'),('EMERGENCY_CONTACT','CONTACT'),('EMERGENCY_CONTACT','HEALTH'),
  ('ID_CARD_PHOTO','PHOTO')
) v(p, c) JOIN privacy.processing_purpose pp ON pp.code = v.p;

-- personal-data inventory (drives exports, erasure and audit redaction)
INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act) FROM (VALUES
  ('people','person','first_name','IDENTITY','ANONYMISE'),('people','person','middle_name','IDENTITY','ANONYMISE'),
  ('people','person','last_name','IDENTITY','ANONYMISE'),('people','person','preferred_name','IDENTITY','ANONYMISE'),
  ('people','person','gender_id','DEMOGRAPHIC','DELETE'),
  ('pii','person_profile','date_of_birth','DEMOGRAPHIC','DELETE'),
  ('pii','person_profile','blood_group_id','HEALTH','DELETE'),
  ('pii','person_profile','nationality_country_id','DEMOGRAPHIC','DELETE'),
  ('pii','person_email','email','CONTACT','DELETE'),
  ('pii','person_phone','e164','CONTACT','DELETE'),
  ('pii','address','line1','ADDRESS','DELETE'),('pii','address','line2','ADDRESS','DELETE'),
  ('pii','address','locality','ADDRESS','DELETE'),('pii','address','postal_code','ADDRESS','DELETE'),
  ('pii','person_identity_document','number_ciphertext','GOVERNMENT_ID','DELETE'),
  ('pii','person_identity_document','number_hmac','GOVERNMENT_ID','DELETE'),
  ('pii','person_identity_document','number_last4','GOVERNMENT_ID','DELETE'),
  ('pii','person_photo','file_object_id','PHOTO','DELETE'),
  ('people','person_relationship','related_person_id','RELATIONSHIP','DELETE'),
  ('people','employee','employee_code','EMPLOYMENT','RETAIN_LEGAL'),
  ('people','student','enrollment_no','EDUCATION','RETAIN_LEGAL'),
  ('people','student','registration_no','EDUCATION','RETAIN_LEGAL'),
  ('people','employee_reporting_line','manager_employee_id','EMPLOYMENT','RETAIN_LEGAL'),
  ('academic','student_enrollment','batch_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','student_specialization','specialization_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','course_registration','course_offering_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','attendance','attendance_status_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','credit_transfer','grade_point','EDUCATION','RETAIN_LEGAL'),
  ('academic','credit_transfer','abc_reference','EDUCATION','RETAIN_LEGAL'),
  ('academic','student_award','award_rule_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','student_track','track_id','EDUCATION','RETAIN_LEGAL'),
  ('exam','component_mark','marks','EDUCATION','RETAIN_LEGAL'),
  ('exam','script_mark','marks','EDUCATION','RETAIN_LEGAL'),
  ('exam','course_result','total_pct','EDUCATION','RETAIN_LEGAL'),
  ('exam','course_result','grade_band_id','EDUCATION','RETAIN_LEGAL'),
  ('exam','grace_award','marks','EDUCATION','RETAIN_LEGAL'),
  ('exam','answer_script','dummy_code','EDUCATION','RETAIN_LEGAL'),
  ('exam','eligibility_hold','reason','EDUCATION','RETAIN_LEGAL'),
  ('exam','ufm_case','description','EDUCATION','RETAIN_LEGAL'),
  ('exam','attendance_condonation','reason','HEALTH','ANONYMISE'),   -- often a medical reason
  ('iam','user_account','username','IDENTITY','ANONYMISE'),
  ('iam','user_account','password','CREDENTIAL','DELETE'),
  ('iam','password_history','password_hash','CREDENTIAL','DELETE'),
  ('iam','password_reset_token','token_hash','CREDENTIAL','DELETE'),
  ('iam','password_reset_token','requested_ip','DEVICE_NETWORK','DELETE'),
  ('iam','mfa_totp','secret_ciphertext','CREDENTIAL','DELETE'),
  ('iam','mfa_webauthn','public_key','CREDENTIAL','DELETE'),
  ('iam','mfa_webauthn','credential_id','CREDENTIAL','DELETE'),
  ('iam','mfa_recovery_code','code_hash','CREDENTIAL','DELETE'),
  ('iam','otp_challenge','code_hash','CREDENTIAL','DELETE'),
  ('iam','user_session','refresh_token_hash','CREDENTIAL','DELETE'),
  ('iam','user_session','ip','DEVICE_NETWORK','DELETE'),
  ('iam','user_device','fingerprint_hash','DEVICE_NETWORK','DELETE'),
  ('iam','user_device','user_agent','DEVICE_NETWORK','DELETE'),
  ('iam','auth_event','ip','DEVICE_NETWORK','RETAIN_LEGAL'),
  ('iam','auth_event','user_agent','DEVICE_NETWORK','RETAIN_LEGAL'),
  ('privacy','consent','ip','DEVICE_NETWORK','RETAIN_LEGAL')
) v(s, t, c, cat, act);

-- #############################################################################
-- ACADEMIC DELIVERY & EXAMINATION — lookups, default grade scale, RBAC
-- #############################################################################

INSERT INTO ref.course_category (code, label, is_elective, sort_order) VALUES
 ('CORE','Core',false,1),('FOUNDATION','Foundation / ability enhancement',false,2),('LAB','Laboratory',false,3),
 ('PROJECT','Project',false,4),('INTERNSHIP','Internship',false,5),('SEMINAR','Seminar',false,6),
 ('AUDIT','Audit (non-credit)',false,7),('DISCIPLINE_ELECTIVE','Discipline / programme elective',true,8),
 ('OPEN_ELECTIVE','Open elective',true,9),('VALUE_ADDED','Value-added course',true,10),('MOOC','MOOC',true,11),
 ('MINOR','Minor (additional discipline)',false,12),('HONOURS','Honours (additional depth)',false,13),
 ('SKILL_ENHANCEMENT','Skill enhancement course (SEC)',true,14),('MULTIDISCIPLINARY','Multidisciplinary course (MDC)',true,15),
 ('INDIAN_KNOWLEDGE','Indian Knowledge System',false,16),('DISSERTATION','Dissertation / research project',false,17),
 ('DSC','Discipline specific course (DSC)',false,18),('AEC','Ability enhancement course (AEC)',true,21),
 ('IACP','Internship / apprenticeship / community engagement / project (IACP)',false,22);
-- UGC sub-categories under DSC (the SOE's "course sub-category")
INSERT INTO ref.course_category (code, label, is_elective, parent_category_id, sort_order)
SELECT v.code, v.label, v.elective, ref.id_of('course_category', 'DSC'), v.ord
FROM (VALUES ('DSCC','DSC — core',false,19),('DSCE','DSC — elective',true,20)) v(code, label, elective, ord);
INSERT INTO ref.delivery_component (code, label, sort_order) VALUES
 ('LECTURE','Lecture (L)',1),('TUTORIAL','Tutorial (T)',2),('PRACTICAL','Practical / lab (P)',3);
INSERT INTO ref.room_type (code, label, sort_order) VALUES
 ('CLASSROOM','Classroom',1),('TUTORIAL_ROOM','Tutorial room',2),('LAB','Laboratory',3),
 ('SEMINAR_HALL','Seminar hall',4),('AUDITORIUM','Auditorium',5),('EXAM_HALL','Examination hall',6);
INSERT INTO ref.batch_document_type (code, label, sort_order) VALUES
 ('INTAKE_APPROVAL','Intake / seat approval (regulator or council)',1),
 ('REGULATORY_CIRCULAR','Regulatory circular for this batch',2),('OTHER','Other',9);
INSERT INTO ref.registration_status (code, label, is_counted, sort_order) VALUES
 ('REGISTERED','Registered',true,1),('DROPPED','Dropped (add/drop window)',false,2),('WITHDRAWN','Withdrawn',false,3);
INSERT INTO ref.class_session_status (code, label, counts_as_held, sort_order) VALUES
 ('SCHEDULED','Scheduled',false,1),('HELD','Held',true,2),('CANCELLED','Cancelled',false,3),('RESCHEDULED','Rescheduled',false,4);
INSERT INTO ref.attendance_status (code, label, counts_as_present, sort_order) VALUES
 ('PRESENT','Present',true,1),('ABSENT','Absent',false,2),('LATE','Late',true,3),
 ('ON_DUTY','On official duty',true,4),('MEDICAL_LEAVE','Medical leave',false,5);

INSERT INTO ref.evaluation_part (code, label, sort_order) VALUES
 ('INTERNAL','Internal / continuous evaluation (CIE)',1),('EXTERNAL','External / end-semester evaluation (ESE)',2);
-- Which part each assessment type belongs to is data: a university that treats
-- the practical exam as internal changes one row.
-- is_scheduled_exam = on the date sheet; uses_answer_scripts = marked through
-- anonymous scripts (theory papers) — scheduled but directly-marked types
-- (end-term practical, viva) are marked by an examiner panel instead.
INSERT INTO ref.assessment_type (code, label, is_scheduled_exam, uses_answer_scripts, requires_external_examiner, evaluation_part_id, sort_order)
SELECT v.code, v.label, v.sched, v.scripts, v.ext, ref.id_of('evaluation_part', v.part), v.ord
FROM (VALUES
 ('INTERNAL','Continuous internal assessment',false,false,false,'INTERNAL',1),('ASSIGNMENT','Assignment',false,false,false,'INTERNAL',2),
 ('QUIZ','Quiz / class test',false,false,false,'INTERNAL',3),('LAB_RECORD','Lab record / continuous lab',false,false,false,'INTERNAL',4),
 ('PRACTICAL','Practical examination',false,false,false,'EXTERNAL',5),('VIVA','Viva voce',false,false,false,'INTERNAL',6),
 ('PROJECT','Project evaluation',false,false,false,'INTERNAL',7),('MID_TERM','Mid-term examination',true,true,false,'INTERNAL',8),
 ('END_TERM','End-term examination',true,true,false,'EXTERNAL',9),
 -- SGT SOE internal assessment (theory)
 ('THEMATIC_ASSESSMENT','Thematic assessment',false,false,false,'INTERNAL',10),
 ('UNIT_ASSESSMENT','Unit assessment',false,false,false,'INTERNAL',11),
 ('EXPERIENTIAL_LEARNING','Experiential and reflective learning assessment',false,false,false,'INTERNAL',12),
 ('PARTICIPATION','Participation & engagement',false,false,false,'INTERNAL',13),
 -- practical / clinical internal, and the externally examined parts
 ('LAB_EVALUATION','Practical / laboratory / clinical proficiency / OSPE',false,false,false,'INTERNAL',14),
 ('REPORT_EVALUATION','Report / demonstration (dissertation, internship)',false,false,false,'EXTERNAL',15),
 ('END_TERM_PRACTICAL','End-term practical examination (ETP) — demonstration',true,false,true,'EXTERNAL',16),
 ('VIVA_VOCE_EXAM','Viva-voce examination (external)',true,false,true,'EXTERNAL',17)
) v(code, label, sched, scripts, ext, part, ord);

-- NEP 2020 flexibility
INSERT INTO ref.award_type (code, label, sort_order) VALUES
 ('UG_CERTIFICATE','UG Certificate (exit after year 1)',1),('UG_DIPLOMA','UG Diploma (exit after year 2)',2),
 ('BACHELOR','Bachelor''s degree',3),('BACHELOR_HONOURS','Bachelor''s degree (Honours)',4),
 ('BACHELOR_HONOURS_RESEARCH','Bachelor''s degree (Honours with Research)',5),
 ('PG_DIPLOMA','PG Diploma',6),('MASTER','Master''s degree',7),('DOCTORATE','Doctoral degree (Ph.D.)',8);
INSERT INTO ref.external_provider_type (code, label, sort_order) VALUES
 ('UNIVERSITY','University / higher-education institution',1),('MOOC_PLATFORM','MOOC platform (SWAYAM, NPTEL …)',2),
 ('INDUSTRY','Industry certification body',3),('OTHER','Other',9);
INSERT INTO ref.credit_transfer_status (code, label, is_accepted, sort_order) VALUES
 ('SUBMITTED','Submitted',false,1),('APPROVED','Approved',true,2),('REJECTED','Rejected',false,3);
INSERT INTO ref.track_type (code, label, requires_own_program, sort_order) VALUES
 ('MINOR','Minor',false,1),('HONOURS','Honours',true,2),('HONOURS_RESEARCH','Honours with research',true,3);
INSERT INTO ref.exam_session_type (code, label, sort_order) VALUES
 ('MID_TERM','Mid-term',1),('END_TERM','End-term',2),('SUPPLEMENTARY','Supplementary',3),('SPECIAL','Special',4);
INSERT INTO ref.exam_attempt_type (code, label, requires_eligibility, sort_order) VALUES
 ('REGULAR','Regular',true,1),('BACKLOG','Backlog / re-appear',false,2),
 ('IMPROVEMENT','Improvement',false,3),('SUPPLEMENTARY','Supplementary',false,4),
 ('GOLDEN_CHANCE','Golden chance',false,5),('MERCY_CHANCE','Mercy chance',false,6);
INSERT INTO ref.exam_hold_type (code, label, sort_order) VALUES
 ('DISCIPLINARY','Disciplinary',1),('FEE_DUES','Fee dues (from Finance)',2),('ADMINISTRATIVE','Administrative',3),('OTHER','Other',9);
INSERT INTO ref.exam_attendance_status (code, label, sort_order) VALUES
 ('PRESENT','Present',1),('ABSENT','Absent',2),('UFM','Booked for unfair means',3);
INSERT INTO ref.ufm_case_status (code, label, is_terminal, sort_order) VALUES
 ('REPORTED','Reported',false,1),('UNDER_REVIEW','Under committee review',false,2),
 ('DECIDED','Decided',true,3),('DISMISSED','Dismissed',true,4);
INSERT INTO ref.ufm_penalty (code, label, sort_order) VALUES
 ('WARNING','Warning',1),('PAPER_CANCELLED','Paper cancelled',2),('SESSION_CANCELLED','All papers of the session cancelled',3),
 ('DEBARRED','Debarred from next session(s)',4);
INSERT INTO ref.evaluation_round (code, label, precedence) VALUES
 ('FIRST','First evaluation',1),('MODERATION','Moderation / second evaluation',2),('REVALUATION','Revaluation',3);
INSERT INTO ref.result_status (code, label, is_pass, sort_order) VALUES
 ('PASS','Pass',true,1),('FAIL','Fail',false,2),('ABSENT','Absent',false,3),
 ('WITHHELD','Withheld (UFM / dues)',false,4),('INCOMPLETE','Incomplete',false,5);
INSERT INTO ref.publication_type (code, label, sort_order) VALUES
 ('ORIGINAL','Original result',1),('REVISED','Revised after revaluation',2),('SUPPLEMENTARY','Supplementary result',3);
INSERT INTO ref.revaluation_type (code, label, sort_order) VALUES
 ('RECHECK','Re-totalling / recheck',1),('REVALUATION','Full revaluation',2),('PHOTOCOPY','Photocopy of script',3);
INSERT INTO ref.revaluation_status (code, label, is_terminal, sort_order) VALUES
 ('SUBMITTED','Submitted',false,1),('IN_PROGRESS','In progress',false,2),('COMPLETED','Completed',true,3),('REJECTED','Rejected',true,4);

-- Default grade scale: UGC 10-point CBCS (POLICY — confirm SGT's own bands).
INSERT INTO academic.grade_scale (code, name, max_grade_point, pct_conversion_factor) VALUES ('UGC_10', 'UGC 10-point (CBCS)', 10, 10);  -- % = CGPA x 10 (UGC)
INSERT INTO academic.grade_band (grade_scale_id, grade_letter, pct_range, grade_point, is_pass)
SELECT gs.id, v.letter, v.r::numrange, v.gp, v.pass
FROM academic.grade_scale gs, (VALUES
  ('O','[90,100]',10,true),('A+','[80,90)',9,true),('A','[70,80)',8,true),('B+','[60,70)',7,true),
  ('B','[50,60)',6,true),('C','[45,50)',5,true),('P','[40,45)',4,true),('F','[0,40)',0,false)
) v(letter, r, gp, pass)
WHERE gs.code = 'UGC_10';

-- DPDP purpose for teaching delivery, examinations and results.
INSERT INTO privacy.processing_purpose (code, label, description, legal_basis_id, retention_period) VALUES   -- retention: POLICY
 ('EXAMINATION_AND_RESULTS','Examination and results',
  'Exam registration, attendance-based eligibility, evaluation, results, marksheets and transcripts',
  ref.id_of('legal_basis','LU_LEGAL_OBLIGATION'), interval '50 years');
INSERT INTO privacy.purpose_data_category (purpose_id, data_category_id)
SELECT pp.id, ref.id_of('data_category', v.c)
FROM privacy.processing_purpose pp, (VALUES ('EDUCATION'),('IDENTITY'),('HEALTH')) v(c)
WHERE pp.code = 'EXAMINATION_AND_RESULTS';

-- ------------------------------------------------------------ RBAC catalogue --
INSERT INTO authz.app_module (code, name, description) VALUES
 ('academics','Academics','Curriculum, course offerings, sections, timetable, attendance'),
 ('exam','Examination','Exam registration, date sheet, seating, evaluation, results');

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('academics','_module','Academics module'),('academics','course','Course catalogue'),
  ('academics','curriculum','Curriculum / scheme of studies'),('academics','evaluation_scheme','Scheme of examination'),
  ('academics','offering','Course offerings'),('academics','section','Sections'),('academics','class_group','Lab batches / elective groups'),
  ('academics','registration','Course registration'),('academics','teaching_assignment','Faculty assignment'),
  ('academics','timetable','Timetable'),('academics','attendance','Attendance'),
  ('academics','course_equivalence','Course equivalence'),('academics','award','Exit awards & re-entry'),
  ('academics','external_course','MOOC / external courses & mappings'),('academics','credit_transfer','Credit transfer (ABC / MOOC)'),
  ('academics','track','Minors & honours'),
  ('exam','_module','Examination module'),('exam','session','Exam sessions'),('exam','eligibility','Eligibility, holds, condonation'),
  ('exam','exam_registration','Exam registration'),('exam','schedule','Date sheet'),('exam','seating','Seating plan'),
  ('exam','invigilation','Invigilation'),('exam','exam_attendance','Exam attendance'),('exam','ufm','Unfair-means cases'),
  ('exam','script','Answer scripts & evaluation'),('exam','marks','Marks'),('exam','grace','Grace marks'),('exam','moderation','Result moderation'),
  ('exam','result','Results'),('exam','marksheet','Marksheets'),('exam','revaluation','Revaluation'),
  ('exam','hall_ticket','Hall tickets')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, v.scopable
FROM (VALUES
  ('academics','_module','access',true),
  ('academics','course','view',true),('academics','course','create',true),('academics','course','update',true),
  ('academics','curriculum','view',true),('academics','curriculum','create',true),('academics','curriculum','update',true),
  ('academics','curriculum','approve',true),
  ('academics','evaluation_scheme','view',false),('academics','evaluation_scheme','update',false),
  ('academics','offering','view',true),('academics','offering','create',true),('academics','offering','update',true),
  ('academics','section','view',true),('academics','section','create',true),('academics','section','update',true),
  ('academics','registration','view',true),('academics','registration','create',true),('academics','registration','update',true),
  ('academics','class_group','view',true),('academics','class_group','create',true),('academics','class_group','update',true),
  ('academics','teaching_assignment','view',true),('academics','teaching_assignment','assign',true),
  ('academics','timetable','view',true),('academics','timetable','create',true),('academics','timetable','update',true),
  ('academics','attendance','view',true),('academics','attendance','create',true),('academics','attendance','update',true),
  ('academics','course_equivalence','view',true),('academics','course_equivalence','approve',true),
  ('academics','award','view',true),('academics','award','create',true),('academics','award','approve',true),
  ('academics','external_course','view',false),('academics','external_course','create',false),('academics','external_course','update',false),
  ('academics','credit_transfer','view',true),('academics','credit_transfer','create',true),('academics','credit_transfer','approve',true),
  ('academics','track','view',true),('academics','track','create',true),('academics','track','update',true),('academics','track','assign',true),
  ('exam','_module','access',true),
  ('exam','session','view',true),('exam','session','create',true),('exam','session','update',true),
  ('exam','eligibility','view',true),('exam','eligibility','update',true),('exam','eligibility','approve',true),
  ('exam','exam_registration','view',true),('exam','exam_registration','create',true),
  ('exam','schedule','view',true),('exam','schedule','create',true),('exam','schedule','update',true),
  ('exam','seating','view',true),('exam','seating','assign',true),
  ('exam','invigilation','view',true),('exam','invigilation','assign',true),
  ('exam','exam_attendance','create',true),('exam','ufm','create',true),('exam','ufm','review',true),
  ('exam','script','view',true),('exam','script','assign',true),('exam','script','review',true),
  ('exam','marks','view',true),('exam','marks','create',true),
  ('exam','grace','approve',true),('exam','moderation','approve',true),('exam','result','view',true),('exam','result','approve',true),
  ('exam','marksheet','create',true),('exam','revaluation','create',true),('exam','revaluation','review',true),
  ('exam','hall_ticket','view',true)
) v(m, res, act, scopable)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('FACULTY','Faculty','Teaching staff: own timetable, attendance and internal marks for assigned classes',true,false),
 ('TIMETABLE_ADMIN','Timetable administrator','Sections, faculty assignment, timetable',true,true),
 ('CURRICULUM_ADMIN','Curriculum administrator','Course catalogue, curricula, schemes of examination',true,true),
 ('EXAM_CONTROLLER','Controller of Examinations','Exam sessions, date sheet, seating, eligibility, result publication',true,true),
 ('EXAM_EVALUATOR','Evaluator','Evaluates anonymised answer scripts assigned to them',true,true);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('FACULTY','academics._module.access'),('FACULTY','academics.timetable.view'),('FACULTY','academics.offering.view'),
  ('FACULTY','academics.section.view'),('FACULTY','academics.class_group.view'),('FACULTY','academics.registration.view'),
  ('FACULTY','academics.attendance.view'),('FACULTY','academics.attendance.create'),
  ('FACULTY','exam._module.access'),('FACULTY','exam.marks.create'),('FACULTY','exam.invigilation.view'),
  ('FACULTY','exam.exam_attendance.create'),('FACULTY','exam.ufm.create'),
  ('STUDENT_BASE','academics._module.access'),('STUDENT_BASE','academics.timetable.view'),
  ('STUDENT_BASE','academics.registration.create'),('STUDENT_BASE','academics.attendance.view'),
  ('STUDENT_BASE','exam._module.access'),('STUDENT_BASE','exam.hall_ticket.view'),
  ('STUDENT_BASE','exam.result.view'),('STUDENT_BASE','exam.revaluation.create'),
  ('ORG_UNIT_HEAD','academics.offering.view'),('ORG_UNIT_HEAD','academics.timetable.view'),
  ('ORG_UNIT_HEAD','academics.attendance.view'),('ORG_UNIT_HEAD','academics.teaching_assignment.view'),('ORG_UNIT_HEAD','exam.result.view'),
  ('TIMETABLE_ADMIN','academics._module.access'),('TIMETABLE_ADMIN','academics.section.view'),
  ('TIMETABLE_ADMIN','academics.section.create'),('TIMETABLE_ADMIN','academics.section.update'),
  ('TIMETABLE_ADMIN','academics.class_group.view'),('TIMETABLE_ADMIN','academics.class_group.create'),
  ('TIMETABLE_ADMIN','academics.class_group.update'),
  ('TIMETABLE_ADMIN','academics.teaching_assignment.view'),('TIMETABLE_ADMIN','academics.teaching_assignment.assign'),
  ('TIMETABLE_ADMIN','academics.timetable.view'),('TIMETABLE_ADMIN','academics.timetable.create'),
  ('TIMETABLE_ADMIN','academics.timetable.update'),('TIMETABLE_ADMIN','academics.offering.view'),
  ('CURRICULUM_ADMIN','academics._module.access'),('CURRICULUM_ADMIN','academics.course.view'),
  ('CURRICULUM_ADMIN','academics.course.create'),('CURRICULUM_ADMIN','academics.course.update'),
  ('CURRICULUM_ADMIN','academics.curriculum.view'),('CURRICULUM_ADMIN','academics.curriculum.create'),
  ('CURRICULUM_ADMIN','academics.curriculum.update'),('CURRICULUM_ADMIN','academics.evaluation_scheme.view'),
  ('CURRICULUM_ADMIN','academics.evaluation_scheme.update'),('CURRICULUM_ADMIN','academics.offering.view'),
  ('CURRICULUM_ADMIN','academics.offering.create'),('CURRICULUM_ADMIN','academics.offering.update'),
  ('ACADEMIC_ADMIN','academics.registration.view'),('ACADEMIC_ADMIN','academics.registration.create'),
  ('ACADEMIC_ADMIN','academics.registration.update'),('ACADEMIC_ADMIN','academics.curriculum.approve'),
  ('ACADEMIC_ADMIN','academics.credit_transfer.view'),('ACADEMIC_ADMIN','academics.credit_transfer.approve'),
  ('ACADEMIC_ADMIN','academics.award.view'),('ACADEMIC_ADMIN','academics.award.approve'),
  ('ACADEMIC_ADMIN','academics.track.view'),('ACADEMIC_ADMIN','academics.track.assign'),
  ('CURRICULUM_ADMIN','academics.course_equivalence.view'),('CURRICULUM_ADMIN','academics.course_equivalence.approve'),
  ('CURRICULUM_ADMIN','academics.award.view'),('CURRICULUM_ADMIN','academics.award.create'),
  ('CURRICULUM_ADMIN','academics.external_course.view'),('CURRICULUM_ADMIN','academics.external_course.create'),
  ('CURRICULUM_ADMIN','academics.external_course.update'),('CURRICULUM_ADMIN','academics.track.view'),
  ('CURRICULUM_ADMIN','academics.track.create'),('CURRICULUM_ADMIN','academics.track.update'),
  ('STUDENT_BASE','academics.credit_transfer.create'),('STUDENT_BASE','academics.track.view'),
  ('EXAM_CONTROLLER','exam.moderation.approve'),
  ('EXAM_CONTROLLER','exam._module.access'),('EXAM_CONTROLLER','exam.session.view'),('EXAM_CONTROLLER','exam.session.create'),
  ('EXAM_CONTROLLER','exam.session.update'),('EXAM_CONTROLLER','exam.eligibility.view'),('EXAM_CONTROLLER','exam.eligibility.update'),
  ('EXAM_CONTROLLER','exam.eligibility.approve'),('EXAM_CONTROLLER','exam.exam_registration.view'),
  ('EXAM_CONTROLLER','exam.exam_registration.create'),('EXAM_CONTROLLER','exam.schedule.view'),
  ('EXAM_CONTROLLER','exam.schedule.create'),('EXAM_CONTROLLER','exam.schedule.update'),
  ('EXAM_CONTROLLER','exam.seating.view'),('EXAM_CONTROLLER','exam.seating.assign'),
  ('EXAM_CONTROLLER','exam.invigilation.view'),('EXAM_CONTROLLER','exam.invigilation.assign'),
  ('EXAM_CONTROLLER','exam.ufm.review'),('EXAM_CONTROLLER','exam.script.view'),('EXAM_CONTROLLER','exam.script.assign'),
  ('EXAM_CONTROLLER','exam.marks.view'),('EXAM_CONTROLLER','exam.grace.approve'),('EXAM_CONTROLLER','exam.result.view'),
  ('EXAM_CONTROLLER','exam.result.approve'),('EXAM_CONTROLLER','exam.marksheet.create'),
  ('EXAM_CONTROLLER','exam.revaluation.review'),('EXAM_CONTROLLER','exam.hall_ticket.view'),
  ('EXAM_EVALUATOR','exam._module.access'),('EXAM_EVALUATOR','exam.script.review')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- Every current teaching employee is FACULTY automatically; which classes a
-- faculty member may mark attendance / internals for is row-level ownership
-- (their own academic.teaching_assignment), checked by the application.
INSERT INTO authz.principal_kind_role (principal_kind_id, employee_category_id, role_id, scope_to_home_unit)
SELECT ref.id_of('principal_kind','EMPLOYEE'), ref.id_of('employee_category','TEACHING'), r.id, false
FROM authz.role r WHERE r.code = 'FACULTY';

-- Separation of duties: the Controller can decode answer scripts (dummy code
-- → student), so must never also be an evaluator.
INSERT INTO authz.role_conflict (role_a_id, role_b_id, reason)
SELECT LEAST(a.id, b.id), GREATEST(a.id, b.id), 'Script decoding and script evaluation must be separate people'
FROM authz.role a, authz.role b WHERE a.code = 'EXAM_CONTROLLER' AND b.code = 'EXAM_EVALUATOR';


-- #############################################################################
-- STUDENT LIFECYCLE, CURRICULUM CONTENT, RESEARCH, PAPERS & CERTIFICATES
-- (04d / 04e / 04f) — lookups, default bands, DPDP inventory, RBAC
-- #############################################################################
INSERT INTO ref.term_registration_status (code, label, is_counted, sort_order) VALUES
 ('REGISTERED','Registered',true,1),('PROVISIONAL','Provisional (dues / documents pending)',true,2),('CANCELLED','Cancelled',false,3);
INSERT INTO ref.academic_standing (code, label, is_promoted, allows_backlog, sort_order) VALUES
 ('PROMOTED','Promoted',true,false,1),('PROMOTED_WITH_BACKLOG','Promoted with backlog (carry-over)',true,true,2),
 ('DETAINED','Detained — repeats the term',false,true,3),('NOT_ELIGIBLE','Not eligible (attendance / dues)',false,true,4);
INSERT INTO ref.study_break_type (code, label, sort_order) VALUES
 ('MEDICAL','Medical',1),('PERSONAL','Personal / family',2),('MATERNITY','Maternity',3),('FINANCIAL','Financial',4),
 ('DISCIPLINARY_SUSPENSION','Disciplinary suspension',5),('INTERNSHIP','Industry / research break',6),('OTHER','Other',9);
INSERT INTO ref.enrollment_end_reason (code, label, sort_order) VALUES
 ('AWARD','Award conferred (exit or degree)',1),('PROGRAM_CHANGE','Change of programme',2),('MIGRATED_OUT','Migrated to another university',3),
 ('WITHDRAWN','Withdrawn',4),('EXPELLED','Expelled',5),('MAX_DURATION','Maximum duration exceeded',6),('DECEASED','Deceased',7),('OTHER','Other',9);
INSERT INTO ref.delivery_mode (code, label, sort_order) VALUES
 ('REGULAR','Regular (full-time, on campus)',1),('PART_TIME','Part-time',2),('DISTANCE','Open & distance learning',3),('ONLINE','Online',4),('HYBRID','Hybrid',5);
INSERT INTO ref.regulatory_body (code, label, sort_order) VALUES
 ('UGC','University Grants Commission',1),('AICTE','All India Council for Technical Education',2),('NMC','National Medical Commission',3),
 ('DCI','Dental Council of India',4),('PCI','Pharmacy Council of India',5),('INC','Indian Nursing Council',6),('BCI','Bar Council of India',7),
 ('NCTE','National Council for Teacher Education',8),('COA','Council of Architecture',9),('NCISM','National Commission for Indian System of Medicine',10),
 ('RCI','Rehabilitation Council of India',11),('CCH','Central Council of Homoeopathy',12),('STATE_GOVT','State government',13),('OTHER','Other',99);
INSERT INTO ref.accreditation_body (code, label, sort_order) VALUES
 ('NAAC','National Assessment and Accreditation Council',1),('NBA','National Board of Accreditation',2),('ABET','ABET',3),('OTHER','Other',9);
INSERT INTO ref.calendar_event_type (code, label, is_non_working, sort_order) VALUES
 ('HOLIDAY','Holiday',true,1),('VACATION','Vacation',true,2),('TEACHING_PERIOD','Teaching period',false,3),
 ('REGISTRATION_WINDOW','Term registration window',false,4),('ADD_DROP_WINDOW','Course add / drop window',false,5),
 ('EXAM_PERIOD','Examination period',false,6),('RESULT_DECLARATION','Result declaration',false,7),('CONVOCATION','Convocation',false,8),('OTHER','Other',false,9);
INSERT INTO ref.bloom_level (code, label, rank) VALUES
 ('REMEMBER','Remember',1),('UNDERSTAND','Understand',2),('APPLY','Apply',3),('ANALYSE','Analyse',4),('EVALUATE','Evaluate',5),('CREATE','Create',6);
INSERT INTO ref.program_outcome_type (code, label, sort_order) VALUES
 ('PO','Programme outcome',1),('PSO','Programme-specific outcome',2);
INSERT INTO ref.supervisor_role (code, label, is_principal, allows_external, sort_order) VALUES
 ('SUPERVISOR','Supervisor',true,false,1),('CO_SUPERVISOR','Co-supervisor',false,false,2),('EXTERNAL_CO_SUPERVISOR','External co-supervisor',false,true,3);
INSERT INTO ref.committee_role (code, label, is_chair, sort_order) VALUES
 ('CHAIR','Chair',true,1),('MEMBER','Member',false,2),('EXTERNAL_EXPERT','External expert',false,3);
INSERT INTO ref.progress_review_outcome (code, label, is_satisfactory, sort_order) VALUES
 ('SATISFACTORY','Satisfactory',true,1),('UNSATISFACTORY','Unsatisfactory',false,2),('TERMINATION_RECOMMENDED','Termination recommended',false,3);
INSERT INTO ref.thesis_status (code, label, is_terminal, sort_order) VALUES
 ('TOPIC_APPROVED','Topic approved',false,1),('SYNOPSIS_SUBMITTED','Synopsis submitted',false,2),('SYNOPSIS_APPROVED','Synopsis approved',false,3),
 ('THESIS_SUBMITTED','Thesis submitted',false,4),('UNDER_EVALUATION','Under evaluation',false,5),('REVISION_REQUIRED','Revision required',false,6),
 ('VIVA_SCHEDULED','Viva scheduled',false,7),('ACCEPTED','Accepted',true,8),('REJECTED','Rejected',true,9);
INSERT INTO ref.thesis_examiner_role (code, label, is_external, sort_order) VALUES
 ('INTERNAL','Internal examiner',false,1),('EXTERNAL','External examiner (India)',true,2),('EXTERNAL_FOREIGN','External examiner (abroad)',true,3);
INSERT INTO ref.examiner_recommendation (code, label, is_accept, blocks_viva, sort_order) VALUES
 ('ACCEPT','Accept',true,false,1),('MINOR_REVISION','Accept with minor revision',true,false,2),
 ('MAJOR_REVISION','Major revision and re-submission',false,true,3),('REJECT','Reject',false,true,4);
INSERT INTO ref.paper_setter_role (code, label, sort_order) VALUES ('SETTER','Paper setter',1),('MODERATOR','Moderator',2);
INSERT INTO ref.question_paper_status (code, label, is_moderated, is_approved, sort_order) VALUES
 ('DRAFT','Draft',false,false,1),('SUBMITTED','Submitted',false,false,2),('MODERATED','Moderated',true,false,3),
 ('APPROVED','Approved',true,true,4),('PRINTED','Printed',true,true,5),('USED','Used',true,true,6),('WITHDRAWN','Withdrawn',false,false,7);
INSERT INTO ref.certificate_type (code, label, requires_award, requires_closed_enrollment, is_single_issue, sort_order) VALUES
 ('TRANSCRIPT','Transcript',false,false,false,1),('PROVISIONAL_CERTIFICATE','Provisional degree / diploma certificate',true,false,true,2),
 ('AWARD_CERTIFICATE','Degree / diploma / certificate (final)',true,false,true,3),('MIGRATION','Migration certificate',false,true,true,4),
 ('CHARACTER','Character certificate',false,false,false,5),('BONAFIDE','Bonafide certificate',false,false,false,6),
 ('RANK','Rank / merit certificate',false,false,false,7),('COURSE_COMPLETION','Course completion certificate',false,false,false,8);

-- Division bands on the UGC 10-point scale (POLICY — confirm SGT's own cut-offs).
INSERT INTO academic.division_band (grade_scale_id, code, label, cgpa_range)
SELECT gs.id, v.code, v.label, v.r::numrange
FROM academic.grade_scale gs, (VALUES
  ('FIRST_DISTINCTION','First class with distinction','[7.5,10]'),('FIRST','First class','[6.5,7.5)'),
  ('SECOND','Second class','[5.5,6.5)'),('PASS','Pass class','[4,5.5)')
) v(code, label, r)
WHERE gs.code = 'UGC_10';

-- UGC (Ph.D.) Regulations 2022: scholars per supervisor (POLICY — confirm).
INSERT INTO research.supervision_norm (designation_id, max_scholars, valid)
SELECT d.id, v.n, daterange('2022-11-07', NULL)
FROM people.designation d JOIN (VALUES ('PROFESSOR',8),('ASSOCIATE_PROFESSOR',6),('ASSISTANT_PROFESSOR',4)) v(code, n) ON v.code = d.code;

-- DPDP: purpose for teaching feedback (data about the teacher, employment basis) and the inventory.
INSERT INTO privacy.processing_purpose (code, label, description, legal_basis_id, retention_period) VALUES   -- retention: POLICY
 ('TEACHING_FEEDBACK','Teaching quality feedback','Anonymous student feedback on courses and teachers, used for faculty appraisal and NAAC / NBA reporting',
  ref.id_of('legal_basis','LU_EMPLOYMENT'), interval '5 years');
INSERT INTO privacy.purpose_data_category (purpose_id, data_category_id)
SELECT p.id, ref.id_of('data_category','EMPLOYMENT') FROM privacy.processing_purpose p WHERE p.code = 'TEACHING_FEEDBACK';
INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('academic','term_registration','academic_standing_id','EDUCATION','RETAIN_LEGAL'),
  ('academic','term_registration','standing_note','EDUCATION','RETAIN_LEGAL'),
  ('academic','study_break','study_break_type_id','HEALTH','ANONYMISE'),   -- MEDICAL / MATERNITY reveal health; erased to OTHER
  ('academic','study_break','reason','HEALTH','ANONYMISE'),
  ('academic','program_transfer','reason','EDUCATION','RETAIN_LEGAL'),
  ('academic','elective_preference','course_id','EDUCATION','DELETE'),
  ('academic','feedback_submission','course_registration_id','EDUCATION','DELETE'),
  ('academic','feedback_response','comment','EMPLOYMENT','ANONYMISE'),      -- opinion about an identifiable teacher
  ('research','supervisor_allocation','employee_id','EMPLOYMENT','RETAIN_LEGAL'),
  ('research','thesis','title','EDUCATION','RETAIN_LEGAL'),
  ('research','thesis','similarity_pct','EDUCATION','RETAIN_LEGAL'),
  ('research','progress_review','remarks','EDUCATION','RETAIN_LEGAL'),
  ('research','thesis_examiner','examiner_recommendation_id','EDUCATION','RETAIN_LEGAL'),
  ('research','viva','examiner_recommendation_id','EDUCATION','RETAIN_LEGAL'),
  ('exam','certificate','serial_no','EDUCATION','RETAIN_LEGAL'),
  ('exam','certificate','verification_code','EDUCATION','RETAIN_LEGAL'),
  ('exam','certificate','nad_reference','EDUCATION','RETAIN_LEGAL')
) v(s, t, c, cat, act);

-- ------------------------------------------------------------ RBAC catalogue --
INSERT INTO authz.app_module (code, name, description) VALUES
 ('research','Research degrees','Supervision, advisory committees, progress reviews, thesis, viva');

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('academics','calendar','Academic calendar'),('academics','program_approval','Regulator approvals & accreditation'),
  ('academics','term_registration','Term registration'),('academics','promotion','Promotion rules & academic standing'),
  ('academics','study_break','Breaks in study'),('academics','program_transfer','Programme transfers'),
  ('academics','elective_preference','Elective preferences & allotment'),('academics','syllabus','Syllabus, units & outcomes'),
  ('academics','lesson_plan','Lesson plans & course file'),('academics','workload','Faculty workload'),('academics','feedback','Student feedback'),
  ('exam','paper_setter','Paper setters & moderators'),('exam','question_paper','Question papers'),
  ('exam','certificate','Certificates'),('exam','convocation','Convocation'),
  ('research','_module','Research module'),('research','supervision','Supervisor allocation'),('research','committee','Advisory committees'),
  ('research','progress_review','Progress reviews'),('research','thesis','Thesis'),('research','examiner','Thesis examiners'),('research','viva','Viva voce')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, v.scopable
FROM (VALUES
  ('academics','calendar','view',true),('academics','calendar','create',true),('academics','calendar','update',true),
  ('academics','program_approval','view',true),('academics','program_approval','create',true),('academics','program_approval','update',true),
  ('academics','term_registration','view',true),('academics','term_registration','create',true),('academics','term_registration','update',true),
  ('academics','promotion','view',true),('academics','promotion','create',true),('academics','promotion','update',true),('academics','promotion','approve',true),
  ('academics','study_break','view',true),('academics','study_break','create',true),('academics','study_break','approve',true),
  ('academics','program_transfer','view',true),('academics','program_transfer','approve',true),
  ('academics','elective_preference','view',true),('academics','elective_preference','create',true),('academics','elective_preference','assign',true),
  ('academics','syllabus','view',true),('academics','syllabus','create',true),('academics','syllabus','update',true),('academics','syllabus','approve',true),
  ('academics','lesson_plan','view',true),('academics','lesson_plan','create',true),('academics','lesson_plan','update',true),
  ('academics','workload','view',true),('academics','workload','update',true),
  ('academics','feedback','view',true),('academics','feedback','create',true),('academics','feedback','update',true),
  ('exam','paper_setter','view',true),('exam','paper_setter','assign',true),
  ('exam','question_paper','view',true),('exam','question_paper','create',true),('exam','question_paper','update',true),
  ('exam','question_paper','review',true),('exam','question_paper','approve',true),
  ('exam','certificate','view',true),('exam','certificate','create',true),('exam','certificate','update',true),
  ('exam','convocation','view',true),('exam','convocation','create',true),('exam','convocation','update',true),
  ('research','_module','access',true),
  ('research','supervision','view',true),('research','supervision','assign',true),
  ('research','committee','view',true),('research','committee','create',true),('research','committee','update',true),
  ('research','progress_review','view',true),('research','progress_review','create',true),
  ('research','thesis','view',true),('research','thesis','create',true),('research','thesis','update',true),
  ('research','examiner','view',true),('research','examiner','assign',true),('research','examiner','update',true),
  ('research','viva','view',true),('research','viva','create',true)
) v(m, res, act, scopable)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('RESEARCH_ADMIN','Research administrator','Doctoral research directorate: supervision, committees, thesis and viva records',true,true),
 ('EXAM_PAPER_SETTER','Paper setter / moderator','Prepares or moderates question papers assigned to them',true,true);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('STUDENT_BASE','academics.calendar.view'),('STUDENT_BASE','academics.term_registration.view'),('STUDENT_BASE','academics.term_registration.create'),
  ('STUDENT_BASE','academics.elective_preference.view'),('STUDENT_BASE','academics.elective_preference.create'),
  ('STUDENT_BASE','academics.study_break.create'),('STUDENT_BASE','academics.feedback.create'),('STUDENT_BASE','academics.syllabus.view'),
  ('STUDENT_BASE','exam.certificate.view'),
  ('STUDENT_BASE','research._module.access'),('STUDENT_BASE','research.thesis.view'),('STUDENT_BASE','research.thesis.create'),
  ('STUDENT_BASE','research.progress_review.view'),
  ('FACULTY','academics.calendar.view'),('FACULTY','academics.syllabus.view'),('FACULTY','academics.lesson_plan.view'),
  ('FACULTY','academics.lesson_plan.create'),('FACULTY','academics.lesson_plan.update'),('FACULTY','academics.workload.view'),
  ('FACULTY','academics.feedback.view'),
  ('FACULTY','exam.question_paper.view'),
  ('FACULTY','research._module.access'),('FACULTY','research.supervision.view'),('FACULTY','research.committee.view'),
  ('FACULTY','research.progress_review.view'),('FACULTY','research.progress_review.create'),('FACULTY','research.thesis.view'),
  ('ORG_UNIT_HEAD','academics.calendar.view'),('ORG_UNIT_HEAD','academics.workload.view'),('ORG_UNIT_HEAD','academics.feedback.view'),
  ('ORG_UNIT_HEAD','academics.promotion.view'),('ORG_UNIT_HEAD','academics.term_registration.view'),('ORG_UNIT_HEAD','academics.lesson_plan.view'),
  ('ORG_UNIT_HEAD','research.supervision.view'),
  ('TIMETABLE_ADMIN','academics.calendar.view'),('TIMETABLE_ADMIN','academics.calendar.create'),('TIMETABLE_ADMIN','academics.calendar.update'),
  ('TIMETABLE_ADMIN','academics.workload.view'),('TIMETABLE_ADMIN','academics.workload.update'),
  ('CURRICULUM_ADMIN','academics.syllabus.view'),('CURRICULUM_ADMIN','academics.syllabus.create'),('CURRICULUM_ADMIN','academics.syllabus.update'),
  ('CURRICULUM_ADMIN','academics.syllabus.approve'),('CURRICULUM_ADMIN','academics.program_approval.view'),
  ('CURRICULUM_ADMIN','academics.program_approval.create'),('CURRICULUM_ADMIN','academics.program_approval.update'),
  ('CURRICULUM_ADMIN','academics.promotion.view'),('CURRICULUM_ADMIN','academics.promotion.create'),('CURRICULUM_ADMIN','academics.promotion.update'),
  ('ACADEMIC_ADMIN','academics.calendar.view'),('ACADEMIC_ADMIN','academics.term_registration.view'),('ACADEMIC_ADMIN','academics.term_registration.create'),
  ('ACADEMIC_ADMIN','academics.term_registration.update'),('ACADEMIC_ADMIN','academics.promotion.view'),('ACADEMIC_ADMIN','academics.promotion.approve'),
  ('ACADEMIC_ADMIN','academics.study_break.view'),('ACADEMIC_ADMIN','academics.study_break.approve'),
  ('ACADEMIC_ADMIN','academics.program_transfer.view'),('ACADEMIC_ADMIN','academics.program_transfer.approve'),
  ('ACADEMIC_ADMIN','academics.elective_preference.view'),('ACADEMIC_ADMIN','academics.elective_preference.assign'),
  ('ACADEMIC_ADMIN','academics.feedback.view'),('ACADEMIC_ADMIN','academics.feedback.create'),('ACADEMIC_ADMIN','academics.feedback.update'),
  ('ACADEMIC_ADMIN','exam.certificate.view'),('ACADEMIC_ADMIN','exam.certificate.create'),
  ('EXAM_CONTROLLER','exam.paper_setter.view'),('EXAM_CONTROLLER','exam.paper_setter.assign'),('EXAM_CONTROLLER','exam.question_paper.view'),
  ('EXAM_CONTROLLER','exam.question_paper.approve'),('EXAM_CONTROLLER','exam.certificate.view'),('EXAM_CONTROLLER','exam.certificate.create'),
  ('EXAM_CONTROLLER','exam.certificate.update'),('EXAM_CONTROLLER','exam.convocation.view'),('EXAM_CONTROLLER','exam.convocation.create'),
  ('EXAM_CONTROLLER','exam.convocation.update'),
  ('EXAM_PAPER_SETTER','exam._module.access'),('EXAM_PAPER_SETTER','exam.question_paper.view'),('EXAM_PAPER_SETTER','exam.question_paper.create'),
  ('EXAM_PAPER_SETTER','exam.question_paper.update'),('EXAM_PAPER_SETTER','exam.question_paper.review'),
  ('RESEARCH_ADMIN','research._module.access'),('RESEARCH_ADMIN','research.supervision.view'),('RESEARCH_ADMIN','research.supervision.assign'),
  ('RESEARCH_ADMIN','research.committee.view'),('RESEARCH_ADMIN','research.committee.create'),('RESEARCH_ADMIN','research.committee.update'),
  ('RESEARCH_ADMIN','research.progress_review.view'),('RESEARCH_ADMIN','research.progress_review.create'),
  ('RESEARCH_ADMIN','research.thesis.view'),('RESEARCH_ADMIN','research.thesis.update'),
  ('RESEARCH_ADMIN','research.examiner.view'),('RESEARCH_ADMIN','research.examiner.assign'),('RESEARCH_ADMIN','research.examiner.update'),
  ('RESEARCH_ADMIN','research.viva.view'),('RESEARCH_ADMIN','research.viva.create')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- Separation of duties: whoever approves and prints question papers must not set them.
INSERT INTO authz.role_conflict (role_a_id, role_b_id, reason)
SELECT LEAST(a.id, b.id), GREATEST(a.id, b.id), 'Paper approval / custody and paper setting must be separate people'
FROM authz.role a, authz.role b WHERE a.code = 'EXAM_CONTROLLER' AND b.code = 'EXAM_PAPER_SETTER';


-- #############################################################################
-- APPROVAL WORKFLOW (wf) — curriculum / SOE approval, internal-marks revision,
-- examiner panels
-- #############################################################################

INSERT INTO ref.examiner_role (code, label, is_external, sort_order) VALUES
 ('INTERNAL','Internal examiner',false,1),('EXTERNAL','External examiner',true,2),('CHAIR','Chair of the panel',false,3);
INSERT INTO ref.wf_action_type (code, label, completes_step, closes_instance, needs_note, sort_order) VALUES
 ('APPROVE','Approve and forward',true,false,false,1),('SIGN','Sign (final sign-off)',true,false,false,2),
 ('RETURN','Return for revision',false,true,true,3),('WITHDRAW','Withdraw',false,true,false,4);
UPDATE ref.wf_action_type SET restarts_clock = true WHERE code IN ('APPROVE','SIGN');
INSERT INTO ref.wf_action_type (code, label, completes_step, closes_instance, needs_note, is_system, is_rejection, returns_to_step, reassigns, restarts_clock, sort_order) VALUES
 ('REJECT','Reject (final)',                       false,true, true, false,true, false,false,false,6),
 ('RETURN_TO','Send back to an earlier level',     false,false,true, false,false,true, false,true, 7),
 ('FORWARD','Forward to another approver',         false,false,false,false,false,false,true, true, 8),
 ('DELEGATE','Delegate this step',                 false,false,false,false,false,false,true, true, 9),
 ('ESCALATE','Escalated (deadline passed)',        false,false,false,true, false,false,false,true, 10),
 ('AUTO_REJECT','Rejected automatically (deadline passed)', false,true,false,true,true,false,false,false,11);
INSERT INTO ref.wf_approver_kind (code, label, sort_order) VALUES
 ('PERMISSION','Whoever holds a permission at the level''s unit',1),('POSITION','The holder of a position at the level''s unit',2),
 ('MANAGER','The reporting / reviewing manager of the person concerned',3),('NAMED','Named person(s): fixed, chosen at submission, or by forwarding',4),
 ('COMMITTEE','Members of a committee (quorum)',5);
INSERT INTO ref.wf_self_action (code, label, sort_order) VALUES
 ('BLOCK','Someone else must decide (the requester never approves their own request)',1),('SKIP','The level is left out when the requester is its approver',2);
INSERT INTO ref.wf_timeout_action (code, label, sort_order) VALUES
 ('NONE','Nothing',1),('REMIND','Remind the approver(s) daily',2),('ESCALATE','Escalate one level up',3),
 ('AUTO_APPROVE','Approve automatically',4),('AUTO_REJECT','Reject automatically',5);
INSERT INTO ref.wf_notice_kind (code, label, sort_order) VALUES
 ('STEP_PENDING','A level is waiting for you',1),('REMINDER','Reminder: a level is overdue',2),('ESCALATED','Escalated to you',3),
 ('FORWARDED','Forwarded / delegated to you',4),('RETURNED','Returned for revision',5),('REJECTED','Rejected',6),('APPROVED','Approved',7),
 ('SUPERSEDED','Decided by a higher level — no longer waiting for you',8);
INSERT INTO ref.wf_comment_status (code, label, is_resolved, sort_order) VALUES
 ('PENDING','Pending',false,1),('ACCEPTED','Accepted',true,2),('REJECTED','Rejected',true,3);

-- Dean Academics: a university-level position (on the university or the
-- Academic Affairs central department).
INSERT INTO org.position_type (code, label, sort_order) VALUES ('DEAN_ACADEMICS','Dean Academics',8);
INSERT INTO org.position_type_unit_type (position_type_id, org_unit_type_id)
SELECT pt.id, ref.id_of('org_unit_type', v.t)
FROM (VALUES ('DEAN_ACADEMICS','UNIVERSITY'),('DEAN_ACADEMICS','CENTRAL_DEPARTMENT')) v(p, t)
JOIN org.position_type pt ON pt.code = v.p;

INSERT INTO authz.action (code, label) VALUES ('submit','Submit for approval'),('sign','Sign off');

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('academics','curriculum_department_review','Curriculum / SOE review — department stage'),
  ('academics','curriculum_school_review','Curriculum / SOE review — school stage'),
  ('academics','curriculum_university_review','Curriculum / SOE review — university stage'),
  ('exam','marks_revision','Internal-marks revision')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, true
FROM (VALUES
  ('academics','curriculum','submit'),('academics','curriculum','sign'),
  ('academics','curriculum_department_review','approve'),('academics','curriculum_school_review','approve'),
  ('academics','curriculum_university_review','approve'),
  ('exam','marks_revision','create'),('exam','marks_revision','approve')
) v(m, res, act)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

-- Stage roles are named by LEVEL of review, and reach people through their
-- appointment (position_role) — never by a role string on the user.
INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('CURRICULUM_DEPT_REVIEWER','Curriculum reviewer — department','Reviews curriculum versions / SOEs of the department''s programmes',true,false),
 ('CURRICULUM_SCHOOL_REVIEWER','Curriculum reviewer — school','Reviews curriculum versions / SOEs of the school''s programmes',true,false),
 ('CURRICULUM_UNIVERSITY_REVIEWER','Curriculum reviewer — university','University-level academic approval (Dean Academics)',true,true),
 ('CURRICULUM_SIGNATORY','Curriculum signatory','Final sign-off of approved curriculum versions (Registrar)',true,true),
 ('INTERNAL_MARKS_MODERATOR','Internal-marks moderation','Approves revisions of published internal marks (Faculty Moderation Committee)',true,true);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('CURRICULUM_DEPT_REVIEWER','academics._module.access'),('CURRICULUM_DEPT_REVIEWER','academics.curriculum.view'),
  ('CURRICULUM_DEPT_REVIEWER','academics.curriculum_department_review.approve'),
  ('CURRICULUM_SCHOOL_REVIEWER','academics._module.access'),('CURRICULUM_SCHOOL_REVIEWER','academics.curriculum.view'),
  ('CURRICULUM_SCHOOL_REVIEWER','academics.curriculum_school_review.approve'),
  ('CURRICULUM_UNIVERSITY_REVIEWER','academics._module.access'),('CURRICULUM_UNIVERSITY_REVIEWER','academics.curriculum.view'),
  ('CURRICULUM_UNIVERSITY_REVIEWER','academics.curriculum_university_review.approve'),
  ('CURRICULUM_SIGNATORY','academics._module.access'),('CURRICULUM_SIGNATORY','academics.curriculum.view'),
  ('CURRICULUM_SIGNATORY','academics.curriculum.sign'),
  ('INTERNAL_MARKS_MODERATOR','exam._module.access'),('INTERNAL_MARKS_MODERATOR','exam.marks_revision.approve'),
  ('FACULTY','academics.curriculum.submit'),('FACULTY','exam.marks_revision.create'),
  ('CURRICULUM_ADMIN','academics.curriculum.submit')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

INSERT INTO authz.position_role (position_type_id, role_id, include_descendants)
SELECT pt.id, r.id, true FROM (VALUES
  ('HEAD','CURRICULUM_DEPT_REVIEWER'),('DEAN','CURRICULUM_SCHOOL_REVIEWER'),('DEAN','INTERNAL_MARKS_MODERATOR'),
  ('DEAN_ACADEMICS','CURRICULUM_UNIVERSITY_REVIEWER'),('REGISTRAR','CURRICULUM_SIGNATORY')
) v(p, role_code)
JOIN org.position_type pt ON pt.code = v.p JOIN authz.role r ON r.code = v.role_code;

-- Document types and their default chains.
INSERT INTO wf.approval_document_type (code, label, app_module_id, author_permission_id)
SELECT v.code, v.label, m.id, pc.permission_id
FROM (VALUES
  ('CURRICULUM','Curriculum version / Statement of Examination (SOE)','academics','academics.curriculum.submit'),
  ('INTERNAL_MARKS_REVISION','Revision of published internal marks','exam','exam.marks_revision.create')
) v(code, label, module, perm)
JOIN authz.app_module m ON m.code = v.module
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- Statutory academic approvals go level by level: a Board of Studies /
-- department review, the school and the Academic Council are each a required
-- step (UGC / university statutes), so no higher level passes a lower one over.
-- An administrator may change this per chain (POLICY).
INSERT INTO wf.approval_chain (document_type_id, valid, note, allows_level_override)
SELECT id, daterange('2000-01-01', NULL), 'Default chain — statutory: every level in order', false FROM wf.approval_document_type;

INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_org_unit_type_id, is_signature)
SELECT c.id, v.seq, v.code, v.label, pc.permission_id, CASE WHEN v.unit IS NULL THEN NULL ELSE ref.id_of('org_unit_type', v.unit) END, v.sig
FROM (VALUES
  ('CURRICULUM', 1, 'DEPARTMENT', 'Head of department review', 'academics.curriculum_department_review.approve', 'DEPARTMENT', false),
  ('CURRICULUM', 2, 'SCHOOL', 'Dean of school review', 'academics.curriculum_school_review.approve', 'SCHOOL', false),
  ('CURRICULUM', 3, 'UNIVERSITY', 'Dean Academics approval', 'academics.curriculum_university_review.approve', NULL, false),
  ('CURRICULUM', 4, 'SIGN', 'Registrar sign-off', 'academics.curriculum.sign', NULL, true),
  ('INTERNAL_MARKS_REVISION', 1, 'MODERATION', 'Faculty Moderation Committee', 'exam.marks_revision.approve', 'SCHOOL', false)
) v(doc, seq, code, label, perm, unit, sig)
JOIN wf.approval_document_type dt ON dt.code = v.doc
JOIN wf.approval_chain c ON c.document_type_id = dt.id AND c.scope_org_unit_id IS NULL
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- Personal-data inventory: revised marks are academic records (retained).
INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('exam','internal_mark_revision','revised_marks','EDUCATION','RETAIN_LEGAL'),
  ('exam','internal_mark_revision','reason','EDUCATION','RETAIN_LEGAL')
) v(s, t, c, cat, act);

-- #############################################################################
-- ACADEMIC OPERATIONS (06c) — credit load, leave, projects, prizes, relative
-- grading, mentoring, class representatives, timetable inputs, question bank
-- #############################################################################

UPDATE ref.course_category SET requires_supervision = true WHERE code IN ('PROJECT','INTERNSHIP','DISSERTATION','IACP');

INSERT INTO ref.leave_type (code, label, attendance_status_id, needs_document, sort_order)
SELECT v.code, v.label, ref.id_of('attendance_status', v.st), v.doc, v.ord
FROM (VALUES ('DUTY_LEAVE','Duty leave (university representation, NCC, sports …)','ON_DUTY',false,1),
             ('MEDICAL_LEAVE','Medical leave','MEDICAL_LEAVE',true,2)) v(code, label, st, doc, ord);
INSERT INTO ref.prize_type (code, label, sort_order) VALUES
 ('GOLD_MEDAL','Gold medal',1),('SILVER_MEDAL','Silver medal',2),('BRONZE_MEDAL','Bronze medal',3),
 ('MERIT_PRIZE','Merit prize',4),('ENDOWMENT_PRIZE','Endowment prize',5);
INSERT INTO ref.meeting_mode (code, label, sort_order) VALUES ('IN_PERSON','In person',1),('ONLINE','Online',2),('PHONE','Phone',3);
INSERT INTO ref.section_role (code, label, sort_order) VALUES
 ('CLASS_REPRESENTATIVE','Class representative',1),('DEPUTY_REPRESENTATIVE','Deputy class representative',2);
INSERT INTO ref.room_feature (code, label, sort_order) VALUES
 ('PROJECTOR','Projector',1),('SMART_BOARD','Smart board',2),('COMPUTERS','Computers',3),('AIR_CONDITIONED','Air conditioned',4),
 ('WHEELCHAIR_ACCESS','Wheelchair accessible',5),('LAB_BENCHES','Laboratory benches',6),('AUDIO_SYSTEM','Audio system',7);
INSERT INTO ref.question_difficulty (code, label, rank) VALUES ('EASY','Easy',1),('MEDIUM','Medium',2),('HARD','Hard',3);
INSERT INTO ref.question_type (code, label, sort_order) VALUES
 ('MCQ','Multiple choice',1),('SHORT','Short answer',2),('LONG','Long answer',3),('NUMERICAL','Numerical',4),('CASE','Case study',5);

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('academics','attendance_leave','Duty / medical leave requests'),('academics','project','Projects, dissertations & internships'),
  ('academics','mentoring','Mentoring meetings'),('academics','teaching_preference','Faculty course preferences'),
  ('exam','prize','Medals & prizes'),('exam','question_bank','Question bank')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, true
FROM (VALUES
  ('academics','attendance_leave','create'),('academics','attendance_leave','approve'),
  ('academics','project','view'),('academics','project','create'),('academics','project','assign'),
  ('academics','mentoring','view'),('academics','mentoring','create'),
  ('academics','teaching_preference','view'),('academics','teaching_preference','create'),
  ('exam','prize','view'),('exam','prize','create'),('exam','prize','approve'),
  ('exam','question_bank','view'),('exam','question_bank','create'),('exam','question_bank','review')
) v(m, res, act)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('ATTENDANCE_LEAVE_APPROVER','Leave approver','Approves students'' duty / medical leave for the department',true,false);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('ATTENDANCE_LEAVE_APPROVER','academics._module.access'),('ATTENDANCE_LEAVE_APPROVER','academics.attendance_leave.approve'),
  ('STUDENT_BASE','academics.attendance_leave.create'),
  ('FACULTY','academics.project.view'),('FACULTY','academics.mentoring.view'),('FACULTY','academics.mentoring.create'),
  ('FACULTY','academics.teaching_preference.create'),('FACULTY','exam.question_bank.view'),('FACULTY','exam.question_bank.create'),
  ('ORG_UNIT_HEAD','academics.project.assign'),('ORG_UNIT_HEAD','academics.mentoring.view'),('ORG_UNIT_HEAD','academics.teaching_preference.view'),
  ('EXAM_CONTROLLER','exam.prize.view'),('EXAM_CONTROLLER','exam.prize.create'),('EXAM_CONTROLLER','exam.prize.approve'),
  ('EXAM_CONTROLLER','exam.question_bank.view'),('EXAM_CONTROLLER','exam.question_bank.review')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

INSERT INTO authz.position_role (position_type_id, role_id, include_descendants)
SELECT pt.id, r.id, true FROM org.position_type pt, authz.role r
WHERE pt.code = 'HEAD' AND r.code = 'ATTENDANCE_LEAVE_APPROVER';

INSERT INTO wf.approval_document_type (code, label, app_module_id, author_permission_id)
SELECT 'ATTENDANCE_LEAVE', 'Duty / medical leave request', m.id, pc.permission_id
FROM authz.app_module m, authz.v_permission_code pc
WHERE m.code = 'academics' AND pc.code = 'academics.attendance_leave.create';
INSERT INTO wf.approval_chain (document_type_id, valid, note)
SELECT id, daterange('2000-01-01', NULL), 'Default chain' FROM wf.approval_document_type WHERE code = 'ATTENDANCE_LEAVE';
INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_org_unit_type_id, is_signature)
SELECT c.id, 1, 'DEPARTMENT', 'Head of department', pc.permission_id, ref.id_of('org_unit_type', 'DEPARTMENT'), false
FROM wf.approval_chain c JOIN wf.approval_document_type dt ON dt.id = c.document_type_id AND dt.code = 'ATTENDANCE_LEAVE'
JOIN authz.v_permission_code pc ON pc.code = 'academics.attendance_leave.approve';

INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('academic','attendance_leave','reason','HEALTH','ANONYMISE'),
  ('academic','mentoring_meeting','summary','EDUCATION','ANONYMISE'),
  ('academic','mentoring_meeting','action_points','EDUCATION','ANONYMISE'),
  ('exam','prize_award','citation','EDUCATION','RETAIN_LEGAL')
) v(s, t, c, cat, act);

-- #############################################################################
-- ACADEMIC BODIES, CO / PO ATTAINMENT, DISCIPLINE
-- #############################################################################

INSERT INTO ref.academic_body_type (code, label, sort_order) VALUES
 ('BOARD_OF_STUDIES','Board of Studies',1),('FACULTY_BOARD','Faculty Board',2),('ACADEMIC_COUNCIL','Academic Council',3),
 ('EXAMINATION_COMMITTEE','Examination Committee',4),('MODERATION_COMMITTEE','Moderation / Result Committee',5),
 ('DISCIPLINARY_COMMITTEE','Disciplinary Committee',6);
INSERT INTO ref.misconduct_type (code, label, sort_order) VALUES
 ('RAGGING','Ragging',1),('HARASSMENT','Harassment / bullying',2),('VIOLENCE','Violence / threat',3),
 ('PROPERTY_DAMAGE','Damage to university property',4),('SUBSTANCE','Alcohol / drugs on campus',5),
 ('ACADEMIC_DISHONESTY','Plagiarism / academic dishonesty (outside exams)',6),('INDISCIPLINE','General indiscipline',7),
 ('CYBER_MISCONDUCT','Misuse of IT / social media',8),('OTHER','Other',9);
INSERT INTO ref.disciplinary_status (code, label, is_decided, is_terminal, sort_order) VALUES
 ('REPORTED','Reported',false,false,1),('UNDER_INQUIRY','Under inquiry',false,false,2),
 ('DECIDED','Decided',true,false,3),('APPEALED','Under appeal',true,false,4),
 ('CLOSED','Closed',true,true,5),('DROPPED','Dropped — no case',false,true,6);
INSERT INTO ref.disciplinary_penalty (code, label, requires_suspension, sort_order) VALUES
 ('WARNING','Written warning',false,1),('APOLOGY','Written apology / undertaking',false,2),('FINE','Fine',false,3),
 ('COMMUNITY_SERVICE','Community service',false,4),('HOSTEL_EXPULSION','Expulsion from hostel',false,5),
 ('SUSPENSION','Suspension from classes',true,6),('RUSTICATION','Rustication',true,7),('EXPULSION','Expulsion',false,8);
INSERT INTO ref.data_category (code, label, is_sensitive, sort_order) VALUES ('DISCIPLINARY','Disciplinary records',true,13);

INSERT INTO academic.attainment_policy (program_id, student_target_pct, level1_pct, level2_pct, level3_pct)
VALUES (NULL, 60, 50, 60, 70);   -- university default: 60 % marks; level 1/2/3 at 50/60/70 % of students

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('academics','academic_body','Boards of Studies, Academic Council & committees'),
  ('academics','attainment','CO / PO attainment'),
  ('academics','discipline','Student disciplinary cases')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, true
FROM (VALUES
  ('academics','academic_body','view'),('academics','academic_body','create'),('academics','academic_body','update'),
  ('academics','attainment','view'),('academics','attainment','create'),
  ('academics','discipline','view'),('academics','discipline','create'),('academics','discipline','approve')
) v(m, res, act)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('DISCIPLINE_OFFICER','Discipline officer','Proctor / disciplinary committee secretary: records cases, hearings and decisions',true,true);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('CURRICULUM_ADMIN','academics.academic_body.view'),('CURRICULUM_ADMIN','academics.academic_body.create'),
  ('CURRICULUM_ADMIN','academics.academic_body.update'),
  ('CURRICULUM_ADMIN','academics.attainment.view'),('CURRICULUM_ADMIN','academics.attainment.create'),
  ('FACULTY','academics.academic_body.view'),('FACULTY','academics.attainment.view'),('FACULTY','academics.discipline.create'),
  ('ORG_UNIT_HEAD','academics.attainment.view'),('ORG_UNIT_HEAD','academics.discipline.view'),
  ('DISCIPLINE_OFFICER','academics._module.access'),('DISCIPLINE_OFFICER','academics.discipline.view'),
  ('DISCIPLINE_OFFICER','academics.discipline.create'),('DISCIPLINE_OFFICER','academics.discipline.approve')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('exam','question_mark','marks','EDUCATION','RETAIN_LEGAL'),
  ('academic','disciplinary_case','description','DISCIPLINARY','ANONYMISE'),
  ('academic','disciplinary_case','decision','DISCIPLINARY','RETAIN_LEGAL')
) v(s, t, c, cat, act);

-- #############################################################################
-- RESOURCE & FACILITY MANAGEMENT (06d) — space, occupancy ledger, bookings,
-- assets, maintenance, guest house, parking, fleet, keys
-- #############################################################################

INSERT INTO ref.building_kind (code, label, sort_order) VALUES
 ('BUILDING','Building',1),('OPEN_AREA','Open area (grounds, courts, lawns)',2),('PARKING','Parking lot',3);
INSERT INTO ref.room_use (code, label, is_bookable, is_guest_room, is_parking_zone, sort_order) VALUES
 ('CLASSROOM','Classroom / lecture room',true,false,false,1),('LABORATORY','Laboratory',true,false,false,2),
 ('OFFICE','Office',false,false,false,3),('LIBRARY','Library / study space',false,false,false,4),
 ('ASSEMBLY','Assembly (hall, auditorium, seminar / conference room)',true,false,false,5),
 ('SPORTS','Sports / recreation',true,false,false,6),('GUEST_ROOM','Guest room',false,true,false,7),
 ('SUPPORT','Support (store, plant, server room)',false,false,false,8),('CIRCULATION','Circulation (corridor, lobby)',false,false,false,9),
 ('RESIDENTIAL','Residential (hostel, staff quarters)',false,false,false,10),('HEALTH','Health care',false,false,false,11),
 ('PARKING_ZONE','Parking zone',false,false,true,12),('OPEN_GROUND','Open ground / court',true,false,false,13);
INSERT INTO ref.room_type (code, label, sort_order) VALUES
 ('CONFERENCE_ROOM','Conference / meeting room',7),('SPORTS_FACILITY','Sports facility (ground, court)',8),
 ('GUEST_ROOM','Guest room',9),('PARKING_ZONE','Parking zone',10),('OFFICE','Office',11);
UPDATE ref.room_feature SET category = CASE code
  WHEN 'PROJECTOR' THEN 'AV' WHEN 'SMART_BOARD' THEN 'AV' WHEN 'AUDIO_SYSTEM' THEN 'AV' WHEN 'COMPUTERS' THEN 'IT'
  WHEN 'AIR_CONDITIONED' THEN 'COMFORT' WHEN 'WHEELCHAIR_ACCESS' THEN 'ACCESS' WHEN 'LAB_BENCHES' THEN 'LAB' END;
INSERT INTO ref.room_feature (code, label, category, sort_order) VALUES
 ('VIDEO_CONFERENCING','Video conferencing',  'AV',8),('STAGE','Stage','FURNITURE',9),('PODIUM','Podium / lectern','FURNITURE',10),
 ('MOVABLE_SEATING','Movable seating','FURNITURE',11),('POWER_BACKUP','Power backup','COMFORT',12);
UPDATE ref.class_session_status SET releases_room = true WHERE code IN ('CANCELLED','RESCHEDULED');

INSERT INTO ref.hold_type (code, label, source_table, default_setup_minutes, default_teardown_minutes, sort_order) VALUES
 ('TIMETABLE','Timetabled class','academic.timetable_entry',0,0,1),
 ('EXTRA_CLASS','Extra / make-up class','academic.class_session',0,0,2),
 ('EXAM','Examination','exam.exam_room',30,15,3),
 ('VIVA','Viva voce','research.viva',0,0,4),
 ('CONVOCATION','Convocation','exam.convocation',120,60,5),
 ('OFFICIAL_EVENT','Official university event','facility.booking_occurrence',30,30,6),
 ('ACADEMIC_EVENT','Academic event (seminar, workshop, guest lecture)','facility.booking_occurrence',15,15,7),
 ('MEETING','Meeting','facility.booking_occurrence',0,0,8),
 ('STUDENT_ACTIVITY','Student activity (club, cultural, sports)','facility.booking_occurrence',15,15,9),
 ('GUEST_STAY','Guest stay','facility.guest_stay',0,0,10),
 ('MAINTENANCE','Maintenance / service window','facility.room_service_window',0,0,11);
INSERT INTO ref.booking_purpose (code, label, hold_type_id, sort_order)
SELECT v.c, v.l, ref.id_of('hold_type', v.h), v.o FROM (VALUES
  ('SEMINAR','Seminar','ACADEMIC_EVENT',1),('WORKSHOP','Workshop / FDP','ACADEMIC_EVENT',2),('GUEST_LECTURE','Guest lecture','ACADEMIC_EVENT',3),
  ('TRAINING','Training session','ACADEMIC_EVENT',4),('CONFERENCE','Conference','OFFICIAL_EVENT',5),
  ('OFFICIAL_FUNCTION','Official function / ceremony','OFFICIAL_EVENT',6),('PLACEMENT_DRIVE','Placement drive','OFFICIAL_EVENT',7),
  ('MEETING','Meeting','MEETING',8),('INTERVIEW','Interview / selection','MEETING',9),
  ('CLUB_ACTIVITY','Club / society activity','STUDENT_ACTIVITY',10),('CULTURAL','Cultural programme','STUDENT_ACTIVITY',11),
  ('SPORTS','Sports practice / match','STUDENT_ACTIVITY',12)) v(c, l, h, o);
INSERT INTO ref.facility_resource_kind (code, label, sort_order) VALUES
 ('ROOM','Rooms & halls',1),('ASSET','Equipment',2),('VEHICLE','Vehicles',3),('GUEST_ROOM','Guest rooms',4),('PARKING','Parking',5),('KEY','Keys & access cards',6);
INSERT INTO ref.booking_restriction_reason (code, label, sort_order) VALUES
 ('MISUSE','Misuse / damage of a facility',1),('REPEATED_NO_SHOW','Repeated no-shows',2),('DUES','Outstanding dues',3),
 ('DISCIPLINARY','Disciplinary decision',4),('OTHER','Other',9);
INSERT INTO ref.booking_cancel_reason (code, label, is_system, sort_order) VALUES
 ('REQUESTER','Cancelled by the requester',false,1),('CUSTODIAN','Cancelled by the custodian',false,2),
 ('EVENT_CANCELLED','The event was cancelled',false,3),('ROOM_UNAVAILABLE','Room became unavailable',false,4),
 ('RESCHEDULED','Rescheduled (replaced by a new booking)',true,5),('NO_SHOW','No-show (released by the system)',true,6);
INSERT INTO ref.room_service_type (code, label, sort_order) VALUES
 ('CLEANING','Cleaning',1),('REPAIR','Repair',2),('RENOVATION','Renovation',3),('INSPECTION','Inspection / audit',4),('FUMIGATION','Fumigation / pest control',5);
INSERT INTO ref.asset_type (code, label, sort_order) VALUES
 ('PROJECTOR','Projector',1),('DISPLAY','Display / smart board',2),('COMPUTER','Computer / laptop',3),('AUDIO_SYSTEM','Audio system',4),
 ('CAMERA','Camera',5),('AIR_CONDITIONER','Air conditioner',6),('FURNITURE','Furniture',7),('LAB_EQUIPMENT','Laboratory equipment',8),
 ('GENERATOR','Generator / UPS',9),('NETWORK','Network equipment',10),('VEHICLE_PART','Vehicle part',11),('OTHER','Other',99);
INSERT INTO ref.asset_condition (code, label, is_serviceable, sort_order) VALUES
 ('NEW','New',true,1),('GOOD','Good',true,2),('FAIR','Fair',true,3),('UNDER_REPAIR','Under repair',false,4),
 ('UNSERVICEABLE','Unserviceable',false,5),('CONDEMNED','Condemned',false,6);
INSERT INTO ref.work_order_category (code, label, sort_order) VALUES
 ('ELECTRICAL','Electrical',1),('PLUMBING','Plumbing',2),('HVAC','Air conditioning / ventilation',3),('CIVIL','Civil works',4),
 ('IT_AV','IT / audio-visual',5),('FURNITURE','Furniture',6),('HOUSEKEEPING','Housekeeping',7),('SAFETY','Fire & safety',8),('OTHER','Other',9);
INSERT INTO ref.work_order_priority (code, label, resolve_within, rank) VALUES
 ('EMERGENCY','Emergency (safety, outage)',interval '4 hours',1),('HIGH','High',interval '1 day',2),
 ('NORMAL','Normal',interval '3 days',3),('LOW','Low',interval '14 days',4);
INSERT INTO ref.work_order_status (code, label, is_terminal, sort_order) VALUES
 ('REPORTED','Reported',false,1),('ASSIGNED','Assigned',false,2),('IN_PROGRESS','In progress',false,3),('ON_HOLD','On hold (parts / vendor)',false,4),
 ('CLOSED','Closed (done)',true,5),('REJECTED','Rejected (not a valid job)',true,6);
INSERT INTO ref.maintenance_type (code, label, sort_order) VALUES
 ('AMC_SERVICE','AMC service',1),('INSPECTION','Inspection',2),('CALIBRATION','Calibration',3),('DEEP_CLEANING','Deep cleaning',4),
 ('FIRE_SAFETY','Fire-safety check',5),('PEST_CONTROL','Pest control',6);
INSERT INTO ref.guest_category (code, label, guest_kind, is_complimentary, sort_order) VALUES
 ('FACULTY','Faculty / staff of the university','EMPLOYEE',true,1),('STUDENT_GUEST','Student of the university','STUDENT',true,2),
 ('OFFICIAL_GUEST','Official guest of the university','EXTERNAL',true,3),('EXTERNAL_EXAMINER','External examiner / expert','EXTERNAL',true,4),
 ('VISITOR','Visitor (paid)','EXTERNAL',false,5),('PARENT','Parent / family of a student (paid)','EXTERNAL',false,6);
INSERT INTO ref.event_kind (code, label, sort_order) VALUES
 ('CONFERENCE','Conference / symposium',1),('FEST','Fest / cultural festival',2),('WORKSHOP','Workshop / FDP',3),('CEREMONY','Ceremony / function',4),
 ('SPORTS_MEET','Sports meet',5),('EXHIBITION','Exhibition / fair',6),('OTHER','Other',9);
INSERT INTO ref.key_kind (code, label, is_master, sort_order) VALUES
 ('KEY','Key',false,1),('SPARE_KEY','Spare key',false,2),('MASTER_KEY','Master key',true,3),('ACCESS_CARD','Access card',false,4);
INSERT INTO ref.parking_permit_type (code, label, sort_order) VALUES
 ('STAFF','Staff',1),('STUDENT','Student',2),('VISITOR','Visitor',3),('CONTRACTOR','Contractor / vendor',4);
INSERT INTO ref.vehicle_type (code, label, is_passenger, sort_order) VALUES
 ('CAR','Car',true,1),('SUV','SUV',true,2),('VAN','Van / tempo traveller',true,3),('MINI_BUS','Mini bus',true,4),('BUS','Bus',true,5),
 ('AMBULANCE','Ambulance',true,6),('TRUCK','Truck / goods carrier',false,7),('TWO_WHEELER','Two-wheeler',true,8);
INSERT INTO ref.fuel_type (code, label, sort_order) VALUES ('PETROL','Petrol',1),('DIESEL','Diesel',2),('CNG','CNG',3),('ELECTRIC','Electric',4),('HYBRID','Hybrid',5);
INSERT INTO ref.licence_class (code, label, rank) VALUES
 ('MCWG','Motorcycle with gear',1),('LMV','Light motor vehicle',2),('LMV_TR','Light motor vehicle — transport',3),
 ('HMV','Heavy motor vehicle',4),('HPMV','Heavy passenger motor vehicle',5);
INSERT INTO ref.vehicle_document_type (code, label, is_mandatory_for_trip, sort_order) VALUES
 ('RC','Registration certificate',true,1),('INSURANCE','Insurance',true,2),('PUC','Pollution under control',true,3),
 ('FITNESS','Fitness certificate',false,4),('PERMIT','Permit',false,5),('ROAD_TAX','Road tax',false,6);
INSERT INTO ref.vehicle_service_type (code, label, sort_order) VALUES
 ('SERVICING','Periodic servicing',1),('REPAIR','Repair',2),('TYRE','Tyres',3),('ACCIDENT_REPAIR','Accident repair',4),('INSPECTION','Inspection',5);
INSERT INTO ref.driver_unavailability_reason (code, label, sort_order) VALUES
 ('LEAVE','Leave',1),('SICK','Sick',2),('OTHER_DUTY','Other duty',3),('TRAINING','Training',4);
INSERT INTO ref.trip_purpose (code, label, allows_self_drive, sort_order) VALUES
 ('OFFICIAL_VISIT','Official visit / meeting',false,1),('FIELD_VISIT','Field / industrial visit',false,2),('GUEST_PICKUP','Guest pick-up / drop',false,3),
 ('AIRPORT_TRANSFER','Airport / station transfer',false,4),('STUDENT_EXCURSION','Student excursion',false,5),('MEDICAL','Medical',false,6),
 ('EVENT_LOGISTICS','Event logistics',true,7);
INSERT INTO ref.trip_cancel_reason (code, label, sort_order) VALUES
 ('PLAN_CHANGED','Plan changed',1),('NO_VEHICLE','No vehicle available',2),('DUPLICATE','Duplicate request',3),('OTHER','Other',9);
INSERT INTO ref.trip_alert_type (code, label, sort_order) VALUES
 ('AUTO_APPROVED','Approved automatically (no decision in time)',1),('UNALLOCATED_SOON','Departure near, no vehicle allocated',2),('EXPIRED','Window passed without a trip',3);
INSERT INTO ref.rating_role (code, label, sort_order) VALUES ('PASSENGER','Passenger rating the driver',1),('DRIVER','Driver rating the passengers',2);
INSERT INTO ref.wf_action_type (code, label, completes_step, closes_instance, needs_note, is_system, restarts_clock, sort_order) VALUES
 ('AUTO_APPROVE','Approved automatically (no decision in time)',true,false,false,true,true,5);

-- Facility blocks are org units (custodians of buildings / floors / rooms),
-- headed like any other unit; the Chancellor and the Chairperson are
-- positions of the university (reserved rooms name them).
INSERT INTO ref.org_unit_type (code, label, is_academic, sort_order) VALUES
 ('BLOCK','Facility block (campus block, hostel block, guest house)',false,7);
INSERT INTO org.org_unit_type_rule (parent_type_id, child_type_id)
SELECT ref.id_of('org_unit_type', p), ref.id_of('org_unit_type', c)
FROM (VALUES ('UNIVERSITY','BLOCK'),('CENTRAL_DEPARTMENT','BLOCK')) v(p, c);
INSERT INTO org.position_type (code, label, sort_order) VALUES ('CHANCELLOR','Chancellor',0),('CHAIRPERSON','Chairperson (governing body)',0);
INSERT INTO org.position_type_unit_type (position_type_id, org_unit_type_id)
SELECT pt.id, ref.id_of('org_unit_type', v.t)
FROM (VALUES ('CHANCELLOR','UNIVERSITY'),('CHAIRPERSON','UNIVERSITY'),('HEAD','BLOCK')) v(p, t)
JOIN org.position_type pt ON pt.code = v.p;

-- ---- RBAC
INSERT INTO authz.app_module (code, name, description) VALUES
 ('facility','Resource & facility management','Rooms, bookings, assets, maintenance, guest house, parking, fleet, keys');
INSERT INTO authz.action (code, label) VALUES ('issue','Issue / hand over'),('create_backdated','Create with a past date');
INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES
  ('facility','_module','Facility module'),('facility','space','Buildings, floors, rooms, features'),
  ('facility','custody','Custody of spaces'),('facility','allocation','Space allocation to units'),
  ('facility','booking','Room bookings'),('facility','event','Event requests'),
  ('facility','reservation_rule','Reserved / private rooms'),('facility','restriction','Booking restrictions on persons'),
  ('facility','priority_rule','Hold priority (pre-emption) rules'),('facility','policy','Booking / transport policies, blackouts'),
  ('facility','hold','The occupancy ledger'),('facility','asset','Assets & equipment'),('facility','asset_loan','Equipment loans'),
  ('facility','work_order','Work orders'),('facility','maintenance','Preventive maintenance schedules'),
  ('facility','guest_stay','Guest-house stays'),('facility','tariff','Guest-house tariffs'),('facility','parking','Parking permits'),
  ('facility','vehicle','Vehicles'),('facility','driver','Drivers'),('facility','trip','Trip requests'),
  ('facility','trip_allocation','Vehicle / driver allocation'),('facility','key','Keys & access cards')
) v(m, code, label) ON v.m = m.code;

INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, v.scopable
FROM (VALUES
  ('facility','_module','access',true),
  ('facility','space','view',true),('facility','space','update',true),
  ('facility','custody','assign',true),('facility','allocation','update',true),
  ('facility','booking','view',true),('facility','booking','create',false),('facility','booking','create_backdated',true),
  ('facility','booking','update',true),('facility','booking','review',true),('facility','booking','approve',true),
  ('facility','event','view',true),('facility','event','create',true),('facility','event','review',true),('facility','event','approve',true),
  ('facility','reservation_rule','update',true),('facility','restriction','assign',true),
  ('facility','priority_rule','update',true),('facility','policy','update',true),('facility','hold','view',true),
  ('facility','asset','view',true),('facility','asset','create',true),('facility','asset','update',true),
  ('facility','asset_loan','view',true),('facility','asset_loan','create',true),
  ('facility','work_order','view',true),('facility','work_order','create',false),('facility','work_order','assign',true),('facility','work_order','update',true),
  ('facility','maintenance','update',true),
  ('facility','guest_stay','view',true),('facility','guest_stay','create',true),('facility','guest_stay','review',true),
  ('facility','guest_stay','approve',true),('facility','guest_stay','update',true),
  ('facility','tariff','update',true),('facility','parking','view',true),('facility','parking','assign',true),
  ('facility','vehicle','view',true),('facility','vehicle','create',true),('facility','vehicle','update',true),
  ('facility','driver','view',true),('facility','driver','create',true),('facility','driver','update',true),
  ('facility','trip','view',true),('facility','trip','create',false),('facility','trip','review',true),('facility','trip','approve',true),('facility','trip','update',true),
  ('facility','trip_allocation','assign',true),
  ('facility','key','view',true),('facility','key','issue',true)
) v(m, res, act, scopable)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;

INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('FACILITY_REQUESTER','Facility requester','Books rooms, requests vehicles and guest rooms, reports faults (every employee and student)',true,false),
 ('FACILITY_UNIT_ENDORSER','Facility endorser — unit head','Endorses the unit''s event, guest and trip requests (first stage)',true,false),
 ('FACILITY_CUSTODIAN','Facility custodian','Approves and manages bookings of the spaces in the unit''s custody; keys and loans of its assets',true,false),
 ('FACILITY_REVIEWER','Facility reviewer — university','University-level approval of events',true,false),
 ('FACILITY_ADMIN','Facility administrator','Space inventory, custody, allocation, policies, priority rules, restrictions, tariffs',true,true),
 ('MAINTENANCE_MANAGER','Maintenance manager','Work orders, preventive maintenance, assets and service contracts',true,false),
 ('MAINTENANCE_TECHNICIAN','Maintenance technician','Works assigned work orders',true,false),
 ('GUEST_HOUSE_MANAGER','Guest-house manager','Approves and runs guest stays',true,false),
 ('TRANSPORT_MANAGER','Transport manager','Approves trips, allocates vehicles and drivers, keeps the fleet',true,false),
 ('FLEET_DRIVER','Fleet driver','Sees own trips',true,false),
 ('KEY_CUSTODIAN','Key custodian','Issues and takes back keys / access cards of the unit',true,false);

INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES
  ('FACILITY_REQUESTER','facility._module.access'),('FACILITY_REQUESTER','facility.booking.view'),('FACILITY_REQUESTER','facility.booking.create'),
  ('FACILITY_REQUESTER','facility.event.create'),('FACILITY_REQUESTER','facility.trip.create'),('FACILITY_REQUESTER','facility.guest_stay.create'),
  ('FACILITY_REQUESTER','facility.work_order.create'),('FACILITY_REQUESTER','facility.space.view'),
  ('FACILITY_UNIT_ENDORSER','facility.booking.review'),('FACILITY_UNIT_ENDORSER','facility.event.review'),
  ('FACILITY_UNIT_ENDORSER','facility.guest_stay.review'),('FACILITY_UNIT_ENDORSER','facility.trip.review'),
  ('FACILITY_UNIT_ENDORSER','facility.event.view'),('FACILITY_UNIT_ENDORSER','facility.trip.view'),('FACILITY_UNIT_ENDORSER','facility.guest_stay.view'),
  ('FACILITY_CUSTODIAN','facility._module.access'),('FACILITY_CUSTODIAN','facility.space.view'),('FACILITY_CUSTODIAN','facility.hold.view'),
  ('FACILITY_CUSTODIAN','facility.booking.view'),('FACILITY_CUSTODIAN','facility.booking.update'),('FACILITY_CUSTODIAN','facility.booking.approve'),
  ('FACILITY_CUSTODIAN','facility.booking.create_backdated'),('FACILITY_CUSTODIAN','facility.reservation_rule.update'),
  ('FACILITY_CUSTODIAN','facility.event.view'),('FACILITY_CUSTODIAN','facility.asset.view'),
  ('FACILITY_CUSTODIAN','facility.asset_loan.view'),('FACILITY_CUSTODIAN','facility.asset_loan.create'),
  ('FACILITY_CUSTODIAN','facility.work_order.view'),('FACILITY_CUSTODIAN','facility.key.view'),('FACILITY_CUSTODIAN','facility.key.issue'),
  ('FACILITY_REVIEWER','facility._module.access'),('FACILITY_REVIEWER','facility.event.view'),('FACILITY_REVIEWER','facility.event.approve'),
  ('FACILITY_REVIEWER','facility.booking.view'),('FACILITY_REVIEWER','facility.hold.view'),
  ('FACILITY_ADMIN','facility._module.access'),('FACILITY_ADMIN','facility.space.update'),('FACILITY_ADMIN','facility.custody.assign'),
  ('FACILITY_ADMIN','facility.allocation.update'),('FACILITY_ADMIN','facility.restriction.assign'),('FACILITY_ADMIN','facility.priority_rule.update'),
  ('FACILITY_ADMIN','facility.policy.update'),('FACILITY_ADMIN','facility.tariff.update'),('FACILITY_ADMIN','facility.event.approve'),
  ('FACILITY_ADMIN','facility.parking.view'),('FACILITY_ADMIN','facility.parking.assign'),
  ('MAINTENANCE_MANAGER','facility._module.access'),('MAINTENANCE_MANAGER','facility.space.view'),
  ('MAINTENANCE_MANAGER','facility.work_order.view'),('MAINTENANCE_MANAGER','facility.work_order.create'),
  ('MAINTENANCE_MANAGER','facility.work_order.assign'),('MAINTENANCE_MANAGER','facility.work_order.update'),
  ('MAINTENANCE_MANAGER','facility.maintenance.update'),('MAINTENANCE_MANAGER','facility.asset.view'),
  ('MAINTENANCE_MANAGER','facility.asset.create'),('MAINTENANCE_MANAGER','facility.asset.update'),('MAINTENANCE_MANAGER','facility.policy.update'),
  ('MAINTENANCE_TECHNICIAN','facility._module.access'),('MAINTENANCE_TECHNICIAN','facility.work_order.view'),
  ('MAINTENANCE_TECHNICIAN','facility.work_order.update'),('MAINTENANCE_TECHNICIAN','facility.asset.view'),
  ('GUEST_HOUSE_MANAGER','facility._module.access'),('GUEST_HOUSE_MANAGER','facility.guest_stay.view'),('GUEST_HOUSE_MANAGER','facility.guest_stay.create'),
  ('GUEST_HOUSE_MANAGER','facility.guest_stay.approve'),('GUEST_HOUSE_MANAGER','facility.guest_stay.update'),('GUEST_HOUSE_MANAGER','facility.space.view'),
  ('TRANSPORT_MANAGER','facility._module.access'),('TRANSPORT_MANAGER','facility.trip.view'),('TRANSPORT_MANAGER','facility.trip.approve'),
  ('TRANSPORT_MANAGER','facility.trip.update'),('TRANSPORT_MANAGER','facility.trip_allocation.assign'),
  ('TRANSPORT_MANAGER','facility.vehicle.view'),('TRANSPORT_MANAGER','facility.vehicle.create'),('TRANSPORT_MANAGER','facility.vehicle.update'),
  ('TRANSPORT_MANAGER','facility.driver.view'),('TRANSPORT_MANAGER','facility.driver.create'),('TRANSPORT_MANAGER','facility.driver.update'),
  ('FLEET_DRIVER','facility._module.access'),('FLEET_DRIVER','facility.trip.view'),
  ('KEY_CUSTODIAN','facility._module.access'),('KEY_CUSTODIAN','facility.key.view'),('KEY_CUSTODIAN','facility.key.issue')
) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- every employee and student may request (all rooms are free of charge for
-- them); the facility administrator inherits every operational role
INSERT INTO authz.role_inheritance (senior_role_id, junior_role_id)
SELECT s.id, j.id FROM (VALUES
  ('EMPLOYEE_BASE','FACILITY_REQUESTER'),('STUDENT_BASE','FACILITY_REQUESTER'),
  ('FACILITY_ADMIN','FACILITY_CUSTODIAN'),('FACILITY_ADMIN','FACILITY_REVIEWER'),('FACILITY_ADMIN','MAINTENANCE_MANAGER'),
  ('FACILITY_ADMIN','GUEST_HOUSE_MANAGER'),('FACILITY_ADMIN','TRANSPORT_MANAGER'),('FACILITY_ADMIN','KEY_CUSTODIAN'),
  ('MAINTENANCE_MANAGER','MAINTENANCE_TECHNICIAN')
) v(s, j)
JOIN authz.role s ON s.code = v.s JOIN authz.role j ON j.code = v.j;

INSERT INTO authz.role_conflict (role_a_id, role_b_id, reason)
SELECT LEAST(a.id, b.id), GREATEST(a.id, b.id), v.reason FROM (VALUES
  ('TRANSPORT_MANAGER','FLEET_DRIVER','A driver must not allocate or close trips')
) v(a, b, reason)
JOIN authz.role a ON a.code = v.a JOIN authz.role b ON b.code = v.b;

-- heads endorse their unit's requests and act as custodian of the spaces in
-- their unit's custody; the Registrar is the university-level event reviewer
INSERT INTO authz.position_role (position_type_id, role_id, include_descendants)
SELECT pt.id, r.id, true FROM (VALUES
  ('HEAD','FACILITY_UNIT_ENDORSER'),('DEAN','FACILITY_UNIT_ENDORSER'),('REGISTRAR','FACILITY_UNIT_ENDORSER'),
  ('VICE_CHANCELLOR','FACILITY_UNIT_ENDORSER'),('DEAN_ACADEMICS','FACILITY_UNIT_ENDORSER'),
  ('HEAD','FACILITY_CUSTODIAN'),('DEAN','FACILITY_CUSTODIAN'),
  ('REGISTRAR','FACILITY_REVIEWER')
) v(p, role_code)
JOIN org.position_type pt ON pt.code = v.p JOIN authz.role r ON r.code = v.role_code;

-- ---- approval document types and their default chains
INSERT INTO wf.approval_document_type (code, label, app_module_id, author_permission_id)
SELECT v.code, v.label, m.id, pc.permission_id
FROM (VALUES
  ('ROOM_BOOKING','Room booking','facility','facility.booking.create'),
  ('ROOM_BOOKING_CHANGE','Room booking — reschedule','facility','facility.booking.create'),
  ('EVENT_REQUEST','Event request (rooms, equipment, vehicles as one package)','facility','facility.event.create'),
  ('GUEST_STAY','Guest-house stay','facility','facility.guest_stay.create'),
  ('TRIP_REQUEST','Trip / vehicle request','facility','facility.trip.create'),
  ('TRIP_REQUEST_URGENT','Trip / vehicle request — urgent','facility','facility.trip.create')
) v(code, label, module, perm)
JOIN authz.app_module m ON m.code = v.module
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

INSERT INTO wf.approval_chain (document_type_id, valid, note)
SELECT id, daterange('2000-01-01', NULL), 'Default chain' FROM wf.approval_document_type
WHERE code IN ('ROOM_BOOKING','ROOM_BOOKING_CHANGE','EVENT_REQUEST','GUEST_STAY','TRIP_REQUEST','TRIP_REQUEST_URGENT');

INSERT INTO wf.approval_chain_stage (chain_id, seq, code, label, permission_id, anchor_org_unit_type_id, anchor_is_owner, is_signature)
SELECT c.id, v.seq, v.code, v.label, pc.permission_id, NULL, v.owner, false
FROM (VALUES
  ('ROOM_BOOKING',        1, 'CUSTODIAN',   'Custodian of the space',               'facility.booking.approve',     true),
  ('ROOM_BOOKING_CHANGE', 1, 'CUSTODIAN',   'Custodian of the space',               'facility.booking.approve',     true),
  ('EVENT_REQUEST',       1, 'UNIT_HEAD',   'Head of the organising unit',          'facility.event.review',        true),
  ('EVENT_REQUEST',       2, 'UNIVERSITY',  'University approval (Registrar)',      'facility.event.approve',       false),
  ('GUEST_STAY',          1, 'HOST_UNIT',   'Head of the host unit',                'facility.guest_stay.review',   true),
  ('GUEST_STAY',          2, 'GUEST_HOUSE', 'Guest-house manager',                  'facility.guest_stay.approve',  false),
  ('TRIP_REQUEST',        1, 'UNIT_HEAD',   'Head of the requesting unit',          'facility.trip.review',         true),
  ('TRIP_REQUEST',        2, 'TRANSPORT',   'Transport office',                     'facility.trip.approve',        false),
  ('TRIP_REQUEST_URGENT', 1, 'TRANSPORT',   'Transport office (urgent)',            'facility.trip.approve',        false)
) v(doc, seq, code, label, perm, owner)
JOIN wf.approval_document_type dt ON dt.code = v.doc
JOIN wf.approval_chain c ON c.document_type_id = dt.id AND c.scope_org_unit_id IS NULL
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;

-- ---- default pre-emption rules (POLICY): what may displace what
INSERT INTO facility.hold_priority_rule (hold_type_id, outranks_hold_type_id, note)
SELECT ref.id_of('hold_type', v.a), ref.id_of('hold_type', v.b), 'University default (POLICY)'
FROM (VALUES
  ('CONVOCATION','TIMETABLE'),('CONVOCATION','EXTRA_CLASS'),('CONVOCATION','EXAM'),('CONVOCATION','VIVA'),
  ('CONVOCATION','OFFICIAL_EVENT'),('CONVOCATION','ACADEMIC_EVENT'),('CONVOCATION','MEETING'),('CONVOCATION','STUDENT_ACTIVITY'),
  ('EXAM','TIMETABLE'),('EXAM','EXTRA_CLASS'),('EXAM','ACADEMIC_EVENT'),('EXAM','MEETING'),('EXAM','STUDENT_ACTIVITY'),
  ('OFFICIAL_EVENT','ACADEMIC_EVENT'),('OFFICIAL_EVENT','MEETING'),('OFFICIAL_EVENT','STUDENT_ACTIVITY'),
  ('TIMETABLE','ACADEMIC_EVENT'),('TIMETABLE','MEETING'),('TIMETABLE','STUDENT_ACTIVITY'),
  ('EXTRA_CLASS','STUDENT_ACTIVITY'),('ACADEMIC_EVENT','STUDENT_ACTIVITY')
) v(a, b);

-- ---- default policies (POLICY)
INSERT INTO facility.booking_policy (org_unit_id, min_duration_minutes, max_advance_days, self_cancel_until_minutes_before, no_show_grace_minutes, checkin_opens_minutes_before, note)
VALUES (NULL, 30, 90, 60, 15, 30, 'University default (POLICY)');
INSERT INTO facility.transport_policy (org_unit_id, urgent_threshold, auto_approve_before, alert_before, max_headcount, min_notice)
VALUES (NULL, interval '1 hour', interval '1 hour', interval '30 minutes', 50, interval '0');

-- ---- DPDP
INSERT INTO privacy.processing_purpose (code, label, description, legal_basis_id, retention_period) VALUES   -- retention: POLICY
 ('FACILITY_AND_TRANSPORT_ADMINISTRATION','Facility & transport administration',
   'Room, equipment and vehicle bookings, work orders, keys, parking; who used what when',
   ref.id_of('legal_basis','LU_VOLUNTARY'), interval '3 years'),
 ('GUEST_ACCOMMODATION','Guest accommodation','Guest-house stays of employees, students and external guests',
   ref.id_of('legal_basis','CONSENT'), interval '3 years');
INSERT INTO privacy.purpose_data_category (purpose_id, data_category_id)
SELECT pp.id, ref.id_of('data_category', v.c) FROM (VALUES
  ('FACILITY_AND_TRANSPORT_ADMINISTRATION','IDENTITY'),('FACILITY_AND_TRANSPORT_ADMINISTRATION','CONTACT'),
  ('FACILITY_AND_TRANSPORT_ADMINISTRATION','ADDRESS'),('FACILITY_AND_TRANSPORT_ADMINISTRATION','EMPLOYMENT'),
  ('FACILITY_AND_TRANSPORT_ADMINISTRATION','GOVERNMENT_ID'),('FACILITY_AND_TRANSPORT_ADMINISTRATION','PHOTO'),
  ('FACILITY_AND_TRANSPORT_ADMINISTRATION','CREDENTIAL'),('FACILITY_AND_TRANSPORT_ADMINISTRATION','DISCIPLINARY'),
  ('GUEST_ACCOMMODATION','IDENTITY'),('GUEST_ACCOMMODATION','CONTACT')
) v(p, c) JOIN privacy.processing_purpose pp ON pp.code = v.p;

INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('facility','booking_restriction','note','DISCIPLINARY','ANONYMISE'),
  ('facility','booking_request','note','IDENTITY','ANONYMISE'),
  ('facility','event_request','note','IDENTITY','ANONYMISE'),
  ('facility','room_reservation_rule','note','IDENTITY','ANONYMISE'),
  ('facility','asset_loan','note','IDENTITY','ANONYMISE'),
  ('facility','work_order','description','IDENTITY','ANONYMISE'),
  ('facility','work_order_event','note','IDENTITY','ANONYMISE'),
  ('facility','guest_stay','guest_person_id','IDENTITY','DELETE'),
  ('facility','guest_stay','purpose','IDENTITY','ANONYMISE'),
  ('facility','parking_permit','vehicle_registration_no','IDENTITY','DELETE'),
  ('facility','vendor','contact_person_id','IDENTITY','DELETE'),
  -- a vendor may be a sole proprietor: the name and GSTIN then identify a person; kept with the purchase records (tax law)
  ('facility','vendor','name','IDENTITY','RETAIN_LEGAL'),('facility','vendor','gstin','IDENTITY','RETAIN_LEGAL'),
  ('facility','driver','licence_document_id','GOVERNMENT_ID','DELETE'),
  ('facility','trip_request','origin_text','ADDRESS','DELETE'),('facility','trip_request','destination_text','ADDRESS','DELETE'),
  ('facility','trip_request','origin_lat','ADDRESS','DELETE'),('facility','trip_request','origin_lon','ADDRESS','DELETE'),
  ('facility','trip_request','destination_lat','ADDRESS','DELETE'),('facility','trip_request','destination_lon','ADDRESS','DELETE'),
  ('facility','trip_request','contact_phone','CONTACT','DELETE'),
  ('facility','trip_request','note','IDENTITY','ANONYMISE'),
  ('facility','trip_allocation','start_token_hash','CREDENTIAL','DELETE'),('facility','trip_allocation','complete_token_hash','CREDENTIAL','DELETE'),
  ('facility','trip_allocation','note','IDENTITY','ANONYMISE'),
  ('facility','trip','pickup_photo_file_id','PHOTO','DELETE'),('facility','trip','note','IDENTITY','ANONYMISE'),
  ('facility','trip_rating','rating','EMPLOYMENT','ANONYMISE'),('facility','trip_rating','comment','IDENTITY','ANONYMISE'),
  ('facility','key_issue','note','IDENTITY','ANONYMISE'),
  ('pii','person_identity_document','expires_on','GOVERNMENT_ID','DELETE')
) v(s, t, c, cat, act);

-- #############################################################################
-- APPROVAL ENGINE (06b) — where each document type's document lives, the
-- administration of chains, and the engine's own personal data
-- #############################################################################

UPDATE wf.approval_document_type dt SET link_table = v.t, link_document_column = v.c
FROM (VALUES ('CURRICULUM','academic.curriculum_approval','curriculum_id'),
             ('INTERNAL_MARKS_REVISION','exam.internal_mark_revision','id'),
             ('ATTENDANCE_LEAVE','academic.attendance_leave','id'),
             ('ROOM_BOOKING','facility.booking_request','id'),('ROOM_BOOKING_CHANGE','facility.booking_request','id'),
             ('EVENT_REQUEST','facility.event_request','id'),('GUEST_STAY','facility.guest_stay','id'),
             ('TRIP_REQUEST','facility.trip_request','id'),('TRIP_REQUEST_URGENT','facility.trip_request','id')) v(code, t, c)
WHERE dt.code = v.code;

INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES ('core_admin','approval_chain','Approval chains (document types, levels, conditions, deadlines)'),
             ('core_admin','approval_delegation','Approval delegations')) v(m, code, label) ON v.m = m.code;
INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, true
FROM (VALUES ('core_admin','approval_chain','view'),('core_admin','approval_chain','update'),
             ('core_admin','approval_delegation','view'),('core_admin','approval_delegation','assign')) v(m, res, act)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;
INSERT INTO authz.role (code, name, description, is_system, requires_mfa) VALUES
 ('WORKFLOW_ADMIN','Workflow administrator','Configures approval chains (levels, approvers, conditions, deadlines) and delegations — for the whole university or scoped to a school / block',true,true);
INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES ('WORKFLOW_ADMIN','core_admin._module.access'),('WORKFLOW_ADMIN','core_admin.approval_chain.view'),
             ('WORKFLOW_ADMIN','core_admin.approval_chain.update'),('WORKFLOW_ADMIN','core_admin.approval_delegation.view'),
             ('WORKFLOW_ADMIN','core_admin.approval_delegation.assign'),
             ('ORG_UNIT_HEAD','core_admin.approval_chain.view')) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext;
INSERT INTO authz.role_inheritance (senior_role_id, junior_role_id)
SELECT s.id, j.id FROM authz.role s, authz.role j WHERE s.code = 'CORE_ADMIN' AND j.code = 'WORKFLOW_ADMIN';

-- Configuration is data, so someone must be allowed to maintain it: the
-- reference lists (ref.* lookups — types, statuses, levels, flags) by the core
-- administrator, purposes and their retention periods by the DPO.
INSERT INTO authz.resource (app_module_id, code, label)
SELECT m.id, v.code, v.label FROM authz.app_module m
JOIN (VALUES ('core_admin','lookup','Reference lists (lookups: types, statuses, levels, flags)'),
             ('privacy','purpose','Processing purposes & retention periods')) v(m, code, label) ON v.m = m.code;
INSERT INTO authz.permission (resource_id, action_id, is_scopable)
SELECT r.id, a.id, false
FROM (VALUES ('core_admin','lookup','view'),('core_admin','lookup','update'),
             ('privacy','purpose','view'),('privacy','purpose','update')) v(m, res, act)
JOIN authz.app_module m ON m.code = v.m
JOIN authz.resource r   ON r.app_module_id = m.id AND r.code = v.res
JOIN authz.action a     ON a.code = v.act;
INSERT INTO authz.role_permission (role_id, permission_id)
SELECT r.id, pc.permission_id
FROM (VALUES ('CORE_ADMIN','core_admin.lookup.view'),('CORE_ADMIN','core_admin.lookup.update'),
             ('DPO','privacy.purpose.view'),('DPO','privacy.purpose.update')) v(role_code, perm)
JOIN authz.role r ON r.code = v.role_code
JOIN authz.v_permission_code pc ON pc.code = v.perm::citext
ON CONFLICT DO NOTHING;

INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('wf','approval_consultation','question','IDENTITY','ANONYMISE'),
  ('wf','approval_consultation','reply','IDENTITY','ANONYMISE'),
  ('wf','approval_delegation','reason','IDENTITY','ANONYMISE')
) v(s, t, c, cat, act);

-- Free text written about (or by) an identifiable person that the audit of
-- 2026-10-01 found outside the inventory. Decision and compliance records are
-- retained; working remarks are anonymised on erasure (and so redacted in the
-- audit trail).
INSERT INTO privacy.data_element (schema_name, table_name, column_name, data_category_id, erasure_action_id)
SELECT v.s, v.t, v.c, ref.id_of('data_category', v.cat), ref.id_of('erasure_action', v.act)
FROM (VALUES
  ('academic','faculty_unavailability','reason','HEALTH','ANONYMISE'),
  ('academic','faculty_course_preference','remarks','EMPLOYMENT','ANONYMISE'),
  ('academic','credit_overload_approval','reason','EDUCATION','RETAIN_LEGAL'),
  ('exam','certificate','cancel_reason','EDUCATION','RETAIN_LEGAL'),
  ('exam','script_mark','note','EDUCATION','RETAIN_LEGAL'),
  ('research','viva','remarks','EDUCATION','RETAIN_LEGAL'),
  ('privacy','data_principal_request','details','IDENTITY','RETAIN_LEGAL'),
  ('privacy','dpr_request_event','note','IDENTITY','RETAIN_LEGAL'),
  ('privacy','breach_incident','description','IDENTITY','RETAIN_LEGAL'),
  ('wf','approval_instance','note','IDENTITY','RETAIN_LEGAL'),
  ('wf','approval_action','note','IDENTITY','RETAIN_LEGAL'),
  ('wf','approval_comment','body','IDENTITY','ANONYMISE'),
  ('wf','approval_comment','suggested_value','IDENTITY','ANONYMISE'),
  ('authz','account_role','reason','IDENTITY','RETAIN_LEGAL'),
  ('authz','account_permission','reason','IDENTITY','RETAIN_LEGAL'),
  ('iam','user_device','name','DEVICE_NETWORK','DELETE')
) v(s, t, c, cat, act);
