# Data dictionary

> Generated from the live PostgreSQL catalog after running `sql/00`–`sql/12`. Do not edit by hand; regenerate with `scripts/gen_data_dictionary.{sql,py}` after schema changes.

**546 tables · 129 views · 159 functions** across 15 schemas. The **PII** column shows the `privacy.data_element` category. Every column with a PII category is written as `[REDACTED]` in the audit trail unless its erasure action is RETAIN_LEGAL (marks, results, attendance); `(sensitive)` marks the higher-risk categories.

## Contents

- **ref** — Lookups: [`academic_body_type`](#refacademic_body_type), [`academic_calendar_type`](#refacademic_calendar_type), [`academic_standing`](#refacademic_standing), [`account_status`](#refaccount_status), [`accreditation_body`](#refaccreditation_body), [`address_type`](#refaddress_type), [`assessment_type`](#refassessment_type), [`asset_condition`](#refasset_condition), [`asset_type`](#refasset_type), [`attendance_status`](#refattendance_status), [`audit_action`](#refaudit_action), [`auth_event_type`](#refauth_event_type), [`auth_failure_reason`](#refauth_failure_reason), [`award_type`](#refaward_type), [`batch_document_type`](#refbatch_document_type), [`blood_group`](#refblood_group), [`bloom_level`](#refbloom_level), [`booking_cancel_reason`](#refbooking_cancel_reason), [`booking_purpose`](#refbooking_purpose), [`booking_restriction_reason`](#refbooking_restriction_reason), [`breach_severity`](#refbreach_severity), [`breach_status`](#refbreach_status), [`budget_item_type`](#refbudget_item_type), [`building_kind`](#refbuilding_kind), [`calendar_event_type`](#refcalendar_event_type), [`certificate_type`](#refcertificate_type), [`city`](#refcity), [`class_session_status`](#refclass_session_status), [`club_category`](#refclub_category), [`club_change_type`](#refclub_change_type), [`club_member_role`](#refclub_member_role), [`club_office`](#refclub_office), [`committee_role`](#refcommittee_role), [`consent_channel`](#refconsent_channel), [`contact_channel`](#refcontact_channel), [`contact_purpose`](#refcontact_purpose), [`contribution_type`](#refcontribution_type), [`country`](#refcountry), [`coupon_discount_type`](#refcoupon_discount_type), [`course_category`](#refcourse_category), [`credit_transfer_status`](#refcredit_transfer_status), [`data_category`](#refdata_category), [`delivery_component`](#refdelivery_component), [`delivery_mode`](#refdelivery_mode), [`disciplinary_penalty`](#refdisciplinary_penalty), [`disciplinary_status`](#refdisciplinary_status), [`dpr_request_type`](#refdpr_request_type), [`dpr_status`](#refdpr_status), [`driver_unavailability_reason`](#refdriver_unavailability_reason), [`duty_leave_scope`](#refduty_leave_scope), [`employee_category`](#refemployee_category), [`employment_status`](#refemployment_status), [`employment_type`](#refemployment_type), [`enrollment_end_reason`](#refenrollment_end_reason), [`entry_direction`](#refentry_direction), [`erasure_action`](#referasure_action), [`evaluation_part`](#refevaluation_part), [`evaluation_round`](#refevaluation_round), [`event_audience_kind`](#refevent_audience_kind), [`event_certificate_type`](#refevent_certificate_type), [`event_field_type`](#refevent_field_type), [`event_kind`](#refevent_kind), [`event_level`](#refevent_level), [`event_mode`](#refevent_mode), [`event_prize_type`](#refevent_prize_type), [`event_round_type`](#refevent_round_type), [`event_type`](#refevent_type), [`exam_attempt_type`](#refexam_attempt_type), [`exam_attendance_status`](#refexam_attendance_status), [`exam_hold_type`](#refexam_hold_type), [`exam_session_type`](#refexam_session_type), [`examiner_recommendation`](#refexaminer_recommendation), [`examiner_role`](#refexaminer_role), [`external_provider_type`](#refexternal_provider_type), [`facility_resource_kind`](#reffacility_resource_kind), [`fuel_type`](#reffuel_type), [`funding_source`](#reffunding_source), [`gender`](#refgender), [`grade`](#refgrade), [`guest_category`](#refguest_category), [`hold_type`](#refhold_type), [`id_document_type`](#refid_document_type), [`job_function`](#refjob_function), [`job_role`](#refjob_role), [`key_kind`](#refkey_kind), [`language`](#reflanguage), [`leave_type`](#refleave_type), [`legal_basis`](#reflegal_basis), [`licence_class`](#reflicence_class), [`lockout_reason`](#reflockout_reason), [`mail_audience`](#refmail_audience), [`mail_delivery_status`](#refmail_delivery_status), [`maintenance_type`](#refmaintenance_type), [`meeting_mode`](#refmeeting_mode), [`mfa_factor_type`](#refmfa_factor_type), [`misconduct_type`](#refmisconduct_type), [`org_unit_type`](#reforg_unit_type), [`otp_purpose`](#refotp_purpose), [`paper_setter_role`](#refpaper_setter_role), [`parking_permit_type`](#refparking_permit_type), [`participation_type`](#refparticipation_type), [`payment_channel`](#refpayment_channel), [`payment_status`](#refpayment_status), [`principal_kind`](#refprincipal_kind), [`prize_type`](#refprize_type), [`program_level`](#refprogram_level), [`program_outcome_type`](#refprogram_outcome_type), [`progress_review_outcome`](#refprogress_review_outcome), [`publication_type`](#refpublication_type), [`question_difficulty`](#refquestion_difficulty), [`question_paper_status`](#refquestion_paper_status), [`question_type`](#refquestion_type), [`rating_role`](#refrating_role), [`registration_cancel_reason`](#refregistration_cancel_reason), [`registration_status`](#refregistration_status), [`regulatory_body`](#refregulatory_body), [`relationship_type`](#refrelationship_type), [`reporting_line_type`](#refreporting_line_type), [`result_status`](#refresult_status), [`revaluation_status`](#refrevaluation_status), [`revaluation_type`](#refrevaluation_type), [`room_feature`](#refroom_feature), [`room_service_type`](#refroom_service_type), [`room_type`](#refroom_type), [`room_use`](#refroom_use), [`scan_source`](#refscan_source), [`section_role`](#refsection_role), [`session_revoke_reason`](#refsession_revoke_reason), [`sponsor_type`](#refsponsor_type), [`stall_category`](#refstall_category), [`stall_setup`](#refstall_setup), [`stall_size`](#refstall_size), [`stall_type`](#refstall_type), [`state_province`](#refstate_province), [`storage_backend`](#refstorage_backend), [`student_status`](#refstudent_status), [`study_break_type`](#refstudy_break_type), [`supervisor_role`](#refsupervisor_role), [`term_cycle`](#refterm_cycle), [`term_registration_status`](#refterm_registration_status), [`thesis_examiner_role`](#refthesis_examiner_role), [`thesis_status`](#refthesis_status), [`tms_academic_context_rule`](#reftms_academic_context_rule), [`tms_anchor_base`](#reftms_anchor_base), [`tms_assignment_basis`](#reftms_assignment_basis), [`tms_category_level`](#reftms_category_level), [`tms_category_type`](#reftms_category_type), [`tms_closure_reason`](#reftms_closure_reason), [`tms_event_actor`](#reftms_event_actor), [`tms_event_allowed_status`](#reftms_event_allowed_status), [`tms_event_type`](#reftms_event_type), [`tms_grievance_head`](#reftms_grievance_head), [`tms_hold_reason`](#reftms_hold_reason), [`tms_intake_channel`](#reftms_intake_channel), [`tms_message_type`](#reftms_message_type), [`tms_notice_recipient`](#reftms_notice_recipient), [`tms_notification_status`](#reftms_notification_status), [`tms_priority`](#reftms_priority), [`tms_redressal_outcome`](#reftms_redressal_outcome), [`tms_route_level_kind`](#reftms_route_level_kind), [`tms_ticket_domain`](#reftms_ticket_domain), [`tms_ticket_status`](#reftms_ticket_status), [`track_type`](#reftrack_type), [`trip_alert_type`](#reftrip_alert_type), [`trip_cancel_reason`](#reftrip_cancel_reason), [`trip_purpose`](#reftrip_purpose), [`ufm_case_status`](#refufm_case_status), [`ufm_penalty`](#refufm_penalty), [`vehicle_document_type`](#refvehicle_document_type), [`vehicle_service_type`](#refvehicle_service_type), [`vehicle_type`](#refvehicle_type), [`verification_method`](#refverification_method), [`volunteer_role`](#refvolunteer_role), [`wf_action_type`](#refwf_action_type), [`wf_approver_kind`](#refwf_approver_kind), [`wf_comment_status`](#refwf_comment_status), [`wf_flag`](#refwf_flag), [`wf_notice_kind`](#refwf_notice_kind), [`wf_self_action`](#refwf_self_action), [`wf_timeout_action`](#refwf_timeout_action), [`work_order_category`](#refwork_order_category), [`work_order_priority`](#refwork_order_priority), [`work_order_status`](#refwork_order_status)
- **org** — Organisation: [`appointment`](#orgappointment), [`building`](#orgbuilding), [`campus`](#orgcampus), [`floor`](#orgfloor), [`org_unit`](#orgorg_unit), [`org_unit_contact`](#orgorg_unit_contact), [`org_unit_location`](#orgorg_unit_location), [`org_unit_type_rule`](#orgorg_unit_type_rule), [`position_type`](#orgposition_type), [`position_type_unit_type`](#orgposition_type_unit_type), [`room`](#orgroom), [`room_facility`](#orgroom_facility)
- **people** — People: [`designation`](#peopledesignation), [`employee`](#peopleemployee), [`employee_assignment`](#peopleemployee_assignment), [`employee_reporting_line`](#peopleemployee_reporting_line), [`file_object`](#peoplefile_object), [`person`](#peopleperson), [`person_relationship`](#peopleperson_relationship), [`student`](#peoplestudent), [`student_mentor`](#peoplestudent_mentor)
- **academic** — Academic structure, curriculum, timetable & attendance: [`academic_body`](#academicacademic_body), [`academic_body_member`](#academicacademic_body_member), [`academic_term`](#academicacademic_term), [`academic_year`](#academicacademic_year), [`attainment_policy`](#academicattainment_policy), [`attempt_allowance`](#academicattempt_allowance), [`attendance`](#academicattendance), [`attendance_leave`](#academicattendance_leave), [`award_rule`](#academicaward_rule), [`award_rule_course`](#academicaward_rule_course), [`batch`](#academicbatch), [`batch_curriculum`](#academicbatch_curriculum), [`batch_document`](#academicbatch_document), [`batch_specialization`](#academicbatch_specialization), [`body_meeting`](#academicbody_meeting), [`body_meeting_attendee`](#academicbody_meeting_attendee), [`body_resolution`](#academicbody_resolution), [`calendar_event`](#academiccalendar_event), [`class_group`](#academicclass_group), [`class_group_member`](#academicclass_group_member), [`class_session`](#academicclass_session), [`class_session_topic`](#academicclass_session_topic), [`co_po_mapping`](#academicco_po_mapping), [`course`](#academiccourse), [`course_component_hours`](#academiccourse_component_hours), [`course_continuation`](#academiccourse_continuation), [`course_equivalence`](#academiccourse_equivalence), [`course_offering`](#academiccourse_offering), [`course_outcome`](#academiccourse_outcome), [`course_prerequisite`](#academiccourse_prerequisite), [`course_registration`](#academiccourse_registration), [`course_regulator_code`](#academiccourse_regulator_code), [`course_room_requirement`](#academiccourse_room_requirement), [`course_syllabus`](#academiccourse_syllabus), [`credit_load_rule`](#academiccredit_load_rule), [`credit_overload_approval`](#academiccredit_overload_approval), [`credit_transfer`](#academiccredit_transfer), [`curriculum`](#academiccurriculum), [`curriculum_approval`](#academiccurriculum_approval), [`curriculum_course`](#academiccurriculum_course), [`curriculum_pathway`](#academiccurriculum_pathway), [`disciplinary_case`](#academicdisciplinary_case), [`division_band`](#academicdivision_band), [`elective_basket`](#academicelective_basket), [`elective_basket_course`](#academicelective_basket_course), [`elective_preference`](#academicelective_preference), [`enrollment_reentry`](#academicenrollment_reentry), [`evaluation_component`](#academicevaluation_component), [`evaluation_component_group`](#academicevaluation_component_group), [`evaluation_component_outcome`](#academicevaluation_component_outcome), [`evaluation_part_rule`](#academicevaluation_part_rule), [`evaluation_scheme`](#academicevaluation_scheme), [`external_course`](#academicexternal_course), [`external_course_mapping`](#academicexternal_course_mapping), [`external_provider`](#academicexternal_provider), [`faculty_course_preference`](#academicfaculty_course_preference), [`faculty_unavailability`](#academicfaculty_unavailability), [`feedback_cycle`](#academicfeedback_cycle), [`feedback_question`](#academicfeedback_question), [`feedback_questionnaire`](#academicfeedback_questionnaire), [`feedback_response`](#academicfeedback_response), [`feedback_submission`](#academicfeedback_submission), [`grade_band`](#academicgrade_band), [`grade_scale`](#academicgrade_scale), [`internship`](#academicinternship), [`lesson_plan_item`](#academiclesson_plan_item), [`mentoring_meeting`](#academicmentoring_meeting), [`offering_seat_quota`](#academicoffering_seat_quota), [`program`](#academicprogram), [`program_accreditation`](#academicprogram_accreditation), [`program_approval`](#academicprogram_approval), [`program_coordinator`](#academicprogram_coordinator), [`program_outcome`](#academicprogram_outcome), [`program_transfer`](#academicprogram_transfer), [`promotion_rule`](#academicpromotion_rule), [`relative_grade_cutoff`](#academicrelative_grade_cutoff), [`result_group`](#academicresult_group), [`section`](#academicsection), [`section_representative`](#academicsection_representative), [`section_student`](#academicsection_student), [`specialization`](#academicspecialization), [`student_award`](#academicstudent_award), [`student_enrollment`](#academicstudent_enrollment), [`student_pathway`](#academicstudent_pathway), [`student_specialization`](#academicstudent_specialization), [`student_track`](#academicstudent_track), [`study_break`](#academicstudy_break), [`supervised_work`](#academicsupervised_work), [`supervised_work_guide`](#academicsupervised_work_guide), [`syllabus_unit`](#academicsyllabus_unit), [`teaching_assignment`](#academicteaching_assignment), [`term_registration`](#academicterm_registration), [`time_slot`](#academictime_slot), [`timetable_entry`](#academictimetable_entry), [`track`](#academictrack), [`track_course`](#academictrack_course), [`workload_norm`](#academicworkload_norm)
- **exam** — Examination: [`answer_script`](#examanswer_script), [`attendance_condonation`](#examattendance_condonation), [`certificate`](#examcertificate), [`component_mark`](#examcomponent_mark), [`convocation`](#examconvocation), [`course_result`](#examcourse_result), [`eligibility_hold`](#exameligibility_hold), [`evaluator_assignment`](#examevaluator_assignment), [`exam_attendance`](#examexam_attendance), [`exam_registration`](#examexam_registration), [`exam_room`](#examexam_room), [`exam_schedule`](#examexam_schedule), [`exam_session`](#examexam_session), [`examiner_panel`](#examexaminer_panel), [`grace_award`](#examgrace_award), [`grace_policy`](#examgrace_policy), [`internal_mark_revision`](#examinternal_mark_revision), [`invigilation_duty`](#examinvigilation_duty), [`marksheet`](#exammarksheet), [`paper_setter_assignment`](#exampaper_setter_assignment), [`prize`](#examprize), [`prize_award`](#examprize_award), [`question_bank_item`](#examquestion_bank_item), [`question_mark`](#examquestion_mark), [`question_paper`](#examquestion_paper), [`question_paper_item`](#examquestion_paper_item), [`result_moderation`](#examresult_moderation), [`result_publication`](#examresult_publication), [`revaluation_request`](#examrevaluation_request), [`script_mark`](#examscript_mark), [`seat_allocation`](#examseat_allocation), [`ufm_case`](#examufm_case)
- **research** — Doctoral research: supervision, committees, thesis, viva: [`advisory_committee`](#researchadvisory_committee), [`advisory_committee_member`](#researchadvisory_committee_member), [`progress_review`](#researchprogress_review), [`supervision_norm`](#researchsupervision_norm), [`supervisor_allocation`](#researchsupervisor_allocation), [`thesis`](#researchthesis), [`thesis_examiner`](#researchthesis_examiner), [`viva`](#researchviva)
- **facility** — Resource & facility management: occupancy ledger, bookings, assets, maintenance, guest house, parking, fleet, keys: [`asset`](#facilityasset), [`asset_hold`](#facilityasset_hold), [`asset_loan`](#facilityasset_loan), [`blackout`](#facilityblackout), [`booking_asset`](#facilitybooking_asset), [`booking_group`](#facilitybooking_group), [`booking_occurrence`](#facilitybooking_occurrence), [`booking_policy`](#facilitybooking_policy), [`booking_request`](#facilitybooking_request), [`booking_requirement`](#facilitybooking_requirement), [`booking_restriction`](#facilitybooking_restriction), [`custody`](#facilitycustody), [`driver`](#facilitydriver), [`driver_unavailability`](#facilitydriver_unavailability), [`event_request`](#facilityevent_request), [`guest_stay`](#facilityguest_stay), [`guest_tariff`](#facilityguest_tariff), [`hold_priority_rule`](#facilityhold_priority_rule), [`key_issue`](#facilitykey_issue), [`key_item`](#facilitykey_item), [`maintenance_schedule`](#facilitymaintenance_schedule), [`parking_permit`](#facilityparking_permit), [`room_composition`](#facilityroom_composition), [`room_hold`](#facilityroom_hold), [`room_reservation_rule`](#facilityroom_reservation_rule), [`room_service_window`](#facilityroom_service_window), [`service_contract`](#facilityservice_contract), [`space_allocation`](#facilityspace_allocation), [`transport_policy`](#facilitytransport_policy), [`trip`](#facilitytrip), [`trip_alert`](#facilitytrip_alert), [`trip_allocation`](#facilitytrip_allocation), [`trip_allocation_request`](#facilitytrip_allocation_request), [`trip_rating`](#facilitytrip_rating), [`trip_request`](#facilitytrip_request), [`vehicle`](#facilityvehicle), [`vehicle_document`](#facilityvehicle_document), [`vehicle_service_window`](#facilityvehicle_service_window), [`vendor`](#facilityvendor), [`work_order`](#facilitywork_order), [`work_order_event`](#facilitywork_order_event)
- **tms** — Helpdesk (TMS): tickets, category tree, escalation ladder, business-hours SLA, notices: [`helpdesk_channel`](#tmshelpdesk_channel), [`helpdesk_closure_type`](#tmshelpdesk_closure_type), [`helpdesk_day_override`](#tmshelpdesk_day_override), [`helpdesk_declaration`](#tmshelpdesk_declaration), [`helpdesk_file_type`](#tmshelpdesk_file_type), [`helpdesk_setting`](#tmshelpdesk_setting), [`helpdesk_weekday`](#tmshelpdesk_weekday), [`kb_article`](#tmskb_article), [`kb_feedback`](#tmskb_feedback), [`notice_opt_out`](#tmsnotice_opt_out), [`redressal_forum`](#tmsredressal_forum), [`ticket`](#tmsticket), [`ticket_academic_context`](#tmsticket_academic_context), [`ticket_category`](#tmsticket_category), [`ticket_category_handler`](#tmsticket_category_handler), [`ticket_category_owner`](#tmsticket_category_owner), [`ticket_event`](#tmsticket_event), [`ticket_event_file`](#tmsticket_event_file), [`ticket_notice_rule`](#tmsticket_notice_rule), [`ticket_notification`](#tmsticket_notification), [`ticket_number_counter`](#tmsticket_number_counter), [`ticket_respondent`](#tmsticket_respondent), [`ticket_route`](#tmsticket_route), [`ticket_route_level`](#tmsticket_route_level)
- **events** — Events & clubs: clubs, proposals, events, registrations, teams, gate scans, certificates, feedback, club points: [`club`](#eventsclub), [`club_application`](#eventsclub_application), [`club_calendar_item`](#eventsclub_calendar_item), [`club_change_member`](#eventsclub_change_member), [`club_change_officer`](#eventsclub_change_officer), [`club_change_request`](#eventsclub_change_request), [`club_member`](#eventsclub_member), [`club_officer`](#eventsclub_officer), [`club_point_award`](#eventsclub_point_award), [`club_proposal`](#eventsclub_proposal), [`club_proposal_attachment`](#eventsclub_proposal_attachment), [`club_proposal_member`](#eventsclub_proposal_member), [`club_proposal_officer`](#eventsclub_proposal_officer), [`club_suspension`](#eventsclub_suspension), [`club_tier`](#eventsclub_tier), [`coupon_redemption`](#eventscoupon_redemption), [`custom_field_option`](#eventscustom_field_option), [`entry_scan`](#eventsentry_scan), [`event`](#eventsevent), [`event_certificate`](#eventsevent_certificate), [`event_certificate_template`](#eventsevent_certificate_template), [`event_change_request`](#eventsevent_change_request), [`event_coupon`](#eventsevent_coupon), [`event_custom_field`](#eventsevent_custom_field), [`event_expense`](#eventsevent_expense), [`event_faq`](#eventsevent_faq), [`event_feedback`](#eventsevent_feedback), [`event_feedback_token`](#eventsevent_feedback_token), [`event_link`](#eventsevent_link), [`event_mail`](#eventsevent_mail), [`event_mail_credit_grant`](#eventsevent_mail_credit_grant), [`event_mail_recipient`](#eventsevent_mail_recipient), [`event_payment`](#eventsevent_payment), [`event_prize_award`](#eventsevent_prize_award), [`event_proposal`](#eventsevent_proposal), [`event_registration`](#eventsevent_registration), [`event_round`](#eventsevent_round), [`event_setting`](#eventsevent_setting), [`event_settlement`](#eventsevent_settlement), [`event_sponsor`](#eventsevent_sponsor), [`event_sponsorship`](#eventsevent_sponsorship), [`event_stall`](#eventsevent_stall), [`event_stall_fee`](#eventsevent_stall_fee), [`event_stall_product`](#eventsevent_stall_product), [`event_team`](#eventsevent_team), [`event_team_member`](#eventsevent_team_member), [`event_type_points`](#eventsevent_type_points), [`event_volunteer`](#eventsevent_volunteer), [`extra_pass`](#eventsextra_pass), [`field_response`](#eventsfield_response), [`post_event_report`](#eventspost_event_report), [`primary_club`](#eventsprimary_club), [`proposal_attachment`](#eventsproposal_attachment), [`proposal_audience`](#eventsproposal_audience), [`proposal_budget_item`](#eventsproposal_budget_item), [`proposal_coordinator`](#eventsproposal_coordinator), [`proposal_funding`](#eventsproposal_funding), [`proposal_partner`](#eventsproposal_partner), [`proposal_prize`](#eventsproposal_prize), [`proposal_sdg`](#eventsproposal_sdg), [`proposal_speaker`](#eventsproposal_speaker), [`proposal_visibility_role`](#eventsproposal_visibility_role), [`proposal_visibility_scope`](#eventsproposal_visibility_scope), [`round_attendance`](#eventsround_attendance), [`sponsorship_item`](#eventssponsorship_item), [`sponsorship_receipt`](#eventssponsorship_receipt), [`stall_application`](#eventsstall_application), [`stall_application_document`](#eventsstall_application_document), [`stall_application_setup`](#eventsstall_application_setup), [`stall_feedback`](#eventsstall_feedback), [`stall_feedback_point`](#eventsstall_feedback_point), [`team_invitation`](#eventsteam_invitation), [`team_join_request`](#eventsteam_join_request), [`volunteer_application`](#eventsvolunteer_application)
- **pii** — Personal data (restricted): [`address`](#piiaddress), [`person_address`](#piiperson_address), [`person_email`](#piiperson_email), [`person_identity_document`](#piiperson_identity_document), [`person_phone`](#piiperson_phone), [`person_photo`](#piiperson_photo), [`person_profile`](#piiperson_profile)
- **iam** — Identity & authentication: [`account_lockout`](#iamaccount_lockout), [`auth_event`](#iamauth_event), [`mfa_factor`](#iammfa_factor), [`mfa_otp_channel`](#iammfa_otp_channel), [`mfa_recovery_code`](#iammfa_recovery_code), [`mfa_totp`](#iammfa_totp), [`mfa_webauthn`](#iammfa_webauthn), [`otp_challenge`](#iamotp_challenge), [`password_history`](#iampassword_history), [`password_reset_token`](#iampassword_reset_token), [`user_account`](#iamuser_account), [`user_device`](#iamuser_device), [`user_session`](#iamuser_session)
- **authz** — Authorisation (RBAC): [`account_permission`](#authzaccount_permission), [`account_role`](#authzaccount_role), [`action`](#authzaction), [`app_module`](#authzapp_module), [`designation_role`](#authzdesignation_role), [`permission`](#authzpermission), [`position_role`](#authzposition_role), [`principal_kind_role`](#authzprincipal_kind_role), [`resource`](#authzresource), [`role`](#authzrole), [`role_conflict`](#authzrole_conflict), [`role_inheritance`](#authzrole_inheritance), [`role_permission`](#authzrole_permission)
- **wf** — Approval workflow: [`approval_action`](#wfapproval_action), [`approval_chain`](#wfapproval_chain), [`approval_chain_stage`](#wfapproval_chain_stage), [`approval_chain_stage_check`](#wfapproval_chain_stage_check), [`approval_comment`](#wfapproval_comment), [`approval_consultation`](#wfapproval_consultation), [`approval_delegation`](#wfapproval_delegation), [`approval_document_type`](#wfapproval_document_type), [`approval_instance`](#wfapproval_instance), [`approval_instance_flag`](#wfapproval_instance_flag), [`approval_notice`](#wfapproval_notice), [`approval_step`](#wfapproval_step), [`approval_step_assignee`](#wfapproval_step_assignee), [`approval_step_check`](#wfapproval_step_check)
- **privacy** — DPDP privacy controls: [`breach_affected_person`](#privacybreach_affected_person), [`breach_incident`](#privacybreach_incident), [`breach_notification`](#privacybreach_notification), [`consent`](#privacyconsent), [`data_element`](#privacydata_element), [`data_principal_request`](#privacydata_principal_request), [`data_processor`](#privacydata_processor), [`dpr_request_event`](#privacydpr_request_event), [`erasure_log`](#privacyerasure_log), [`nominee`](#privacynominee), [`notice_purpose`](#privacynotice_purpose), [`pii_access_log`](#privacypii_access_log), [`privacy_notice`](#privacyprivacy_notice), [`processing_purpose`](#privacyprocessing_purpose), [`processor_purpose`](#privacyprocessor_purpose), [`purpose_data_category`](#privacypurpose_data_category), [`verifiable_parental_consent`](#privacyverifiable_parental_consent)
- **audit** — Audit trail: [`audit_change`](#auditaudit_change), [`audit_event`](#auditaudit_event)

## Schema `ref` — Lookups

<a id="refacademic_body_type"></a>
### `ref.academic_body_type`

Lookup: Board of Studies, Faculty Board, Academic Council, examination / moderation / disciplinary committees.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `academic_body_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_body_type_code_key`: `UNIQUE (code)`

<a id="refacademic_calendar_type"></a>
### `ref.academic_calendar_type`

Lookup: how programmes divide time (SEMESTER, ANNUAL, PROFESSIONAL_YEAR) and terms per year.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `terms_per_year` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `academic_calendar_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_calendar_type_code_key`: `UNIQUE (code)`
- CHECK `academic_calendar_type_terms_per_year_check`: `CHECK (((terms_per_year >= 1) AND (terms_per_year <= 4)))`

<a id="refacademic_standing"></a>
### `ref.academic_standing`

Lookup: academic standing.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_promoted` | boolean |  |  |  |
| `allows_backlog` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `academic_standing_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_standing_code_key`: `UNIQUE (code)`

<a id="refaccount_status"></a>
### `ref.account_status`

Lookup: account states; can_login gates authentication and authorisation.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `can_login` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `account_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `account_status_code_key`: `UNIQUE (code)`

<a id="refaccreditation_body"></a>
### `ref.accreditation_body`

Lookup: accreditation body.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `accreditation_body_pkey`: `PRIMARY KEY (id)`
- UNIQUE `accreditation_body_code_key`: `UNIQUE (code)`

<a id="refaddress_type"></a>
### `ref.address_type`

Lookup: address type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `address_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `address_type_code_key`: `UNIQUE (code)`

<a id="refassessment_type"></a>
### `ref.assessment_type`

Lookup: kinds of assessment; is_scheduled_exam = has a date sheet, answer scripts and seating (mid-term, end-term).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_scheduled_exam` | boolean |  |  |  |
| `uses_answer_scripts` | boolean |  |  |  |
| `requires_external_examiner` | boolean |  | `false` |  |
| `evaluation_part_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `assessment_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `assessment_type_code_key`: `UNIQUE (code)`
- FK `assessment_type_evaluation_part_id_fkey`: `FOREIGN KEY (evaluation_part_id) REFERENCES ref.evaluation_part(id)`
- CHECK `assessment_type_check`: `CHECK ((is_scheduled_exam OR (NOT uses_answer_scripts)))`

<a id="refasset_condition"></a>
### `ref.asset_condition`

Lookup: new / good / fair / under repair / unserviceable / condemned; is_serviceable = may be used or lent.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_serviceable` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `asset_condition_pkey`: `PRIMARY KEY (id)`
- UNIQUE `asset_condition_code_key`: `UNIQUE (code)`

<a id="refasset_type"></a>
### `ref.asset_type`

Lookup: kinds of asset (projector, computer, air conditioner, lab equipment …).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `asset_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `asset_type_code_key`: `UNIQUE (code)`

<a id="refattendance_status"></a>
### `ref.attendance_status`

Lookup: attendance marks; counts_as_present drives the attendance percentage.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `counts_as_present` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `attendance_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `attendance_status_code_key`: `UNIQUE (code)`

<a id="refaudit_action"></a>
### `ref.audit_action`

Lookup: audit action.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `audit_action_pkey`: `PRIMARY KEY (id)`
- UNIQUE `audit_action_code_key`: `UNIQUE (code)`

<a id="refauth_event_type"></a>
### `ref.auth_event_type`

Lookup: auth event type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `auth_event_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `auth_event_type_code_key`: `UNIQUE (code)`

<a id="refauth_failure_reason"></a>
### `ref.auth_failure_reason`

Lookup: auth failure reason.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `auth_failure_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `auth_failure_reason_code_key`: `UNIQUE (code)`

<a id="refaward_type"></a>
### `ref.award_type`

Lookup: qualifications a student can leave with (UG certificate, diploma, degree, honours …) — NEP multiple exit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `award_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `award_type_code_key`: `UNIQUE (code)`

<a id="refbatch_document_type"></a>
### `ref.batch_document_type`

Lookup: batch document type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `batch_document_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `batch_document_type_code_key`: `UNIQUE (code)`

<a id="refblood_group"></a>
### `ref.blood_group`

Lookup: blood group.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `blood_group_pkey`: `PRIMARY KEY (id)`
- UNIQUE `blood_group_code_key`: `UNIQUE (code)`

<a id="refbloom_level"></a>
### `ref.bloom_level`

Lookup: bloom level.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `rank` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `bloom_level_pkey`: `PRIMARY KEY (id)`
- UNIQUE `bloom_level_code_key`: `UNIQUE (code)`
- UNIQUE `bloom_level_rank_key`: `UNIQUE (rank)`

<a id="refbooking_cancel_reason"></a>
### `ref.booking_cancel_reason`

Lookup: why a booking / stay was cancelled; is_system = set by the workflow or a job (RESCHEDULED, NO_SHOW), not chosen by a person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_system` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `booking_cancel_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_cancel_reason_code_key`: `UNIQUE (code)`

<a id="refbooking_purpose"></a>
### `ref.booking_purpose`

Lookup: why a room is booked (seminar, meeting, club activity …) → the hold type (and so the priority) it makes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `hold_type_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `booking_purpose_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_purpose_code_key`: `UNIQUE (code)`
- FK `booking_purpose_hold_type_id_fkey`: `FOREIGN KEY (hold_type_id) REFERENCES ref.hold_type(id)`

<a id="refbooking_restriction_reason"></a>
### `ref.booking_restriction_reason`

Lookup: why a person is barred (misuse, repeated no-shows, dues, disciplinary).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `booking_restriction_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_restriction_reason_code_key`: `UNIQUE (code)`

<a id="refbreach_severity"></a>
### `ref.breach_severity`

Lookup: breach severity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `breach_severity_pkey`: `PRIMARY KEY (id)`
- UNIQUE `breach_severity_code_key`: `UNIQUE (code)`

<a id="refbreach_status"></a>
### `ref.breach_status`

Lookup: breach status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `breach_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `breach_status_code_key`: `UNIQUE (code)`

<a id="refbudget_item_type"></a>
### `ref.budget_item_type`

Lookup: budget heads of an event (venue, refreshments, printing, prizes, honorarium, travel, equipment, publicity).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `budget_item_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `budget_item_type_code_key`: `UNIQUE (code)`

<a id="refbuilding_kind"></a>
### `ref.building_kind`

Lookup: BUILDING / OPEN_AREA (grounds, courts) / PARKING — an open area or car park is a "building" whose rooms are its zones.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `building_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `building_kind_code_key`: `UNIQUE (code)`

<a id="refcalendar_event_type"></a>
### `ref.calendar_event_type`

Lookup: calendar event type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_non_working` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `calendar_event_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `calendar_event_type_code_key`: `UNIQUE (code)`

<a id="refcertificate_type"></a>
### `ref.certificate_type`

Lookup: certificate type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `requires_award` | boolean |  |  |  |
| `requires_closed_enrollment` | boolean |  |  |  |
| `is_single_issue` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `certificate_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `certificate_type_code_key`: `UNIQUE (code)`

<a id="refcity"></a>
### `ref.city`

Lookup: cities per state. State and country are reached through city.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `state_province_id` | integer |  |  |  |
| `name` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `city_pkey`: `PRIMARY KEY (id)`
- UNIQUE `city_state_province_id_name_key`: `UNIQUE (state_province_id, name)`
- FK `city_state_province_id_fkey`: `FOREIGN KEY (state_province_id) REFERENCES ref.state_province(id)`

<a id="refclass_session_status"></a>
### `ref.class_session_status`

Lookup: scheduled / held / cancelled / rescheduled; only held sessions count and take attendance.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `counts_as_held` | boolean |  |  |  |
| `releases_room` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `class_session_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `class_session_status_code_key`: `UNIQUE (code)`

<a id="refclub_category"></a>
### `ref.club_category`

Lookup: what kind of club — academic, technical, cultural, sports, literary, social service, professional chapter, hobby; carried on approval rounds as the flag CLUBCAT_<code>.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `club_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_category_code_key`: `UNIQUE (code)`

<a id="refclub_change_type"></a>
### `ref.club_change_type`

Lookup: kinds of change to a club (name, objective, advisor, co-advisor, officers, members, recorded decisions); the sets_* flags say what the database applies on approval.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `sets_name` | boolean |  | `false` |  |
| `sets_objective` | boolean |  | `false` |  |
| `sets_advisor` | boolean |  | `false` |  |
| `sets_co_advisor` | boolean |  | `false` |  |
| `sets_officers` | boolean |  | `false` |  |
| `sets_members` | boolean |  | `false` |  |
| `sets_category` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `club_change_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_change_type_code_key`: `UNIQUE (code)`

<a id="refclub_member_role"></a>
### `ref.club_member_role`

Lookup: roles of club members (member, volunteer, core member, coordinator, heads).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `club_member_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_member_role_code_key`: `UNIQUE (code)`

<a id="refclub_office"></a>
### `ref.club_office`

Lookup: student posts of a club (president, secretary, joint secretary, document curator, creative head); may_propose = may propose the club's events; is_required = a club proposal must name this office.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `may_propose` | boolean |  | `true` |  |
| `is_required` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `club_office_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_office_code_key`: `UNIQUE (code)`

<a id="refcommittee_role"></a>
### `ref.committee_role`

Lookup: committee role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_chair` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `committee_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `committee_role_code_key`: `UNIQUE (code)`

<a id="refconsent_channel"></a>
### `ref.consent_channel`

Lookup: consent channel.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `consent_channel_pkey`: `PRIMARY KEY (id)`
- UNIQUE `consent_channel_code_key`: `UNIQUE (code)`

<a id="refcontact_channel"></a>
### `ref.contact_channel`

Lookup: contact channel.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `contact_channel_pkey`: `PRIMARY KEY (id)`
- UNIQUE `contact_channel_code_key`: `UNIQUE (code)`

<a id="refcontact_purpose"></a>
### `ref.contact_purpose`

Lookup: contact purpose.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `contact_purpose_pkey`: `PRIMARY KEY (id)`
- UNIQUE `contact_purpose_code_key`: `UNIQUE (code)`

<a id="refcontribution_type"></a>
### `ref.contribution_type`

Lookup: cash, in kind, or both.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `has_cash` | boolean |  |  |  |
| `has_in_kind` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `contribution_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `contribution_type_code_key`: `UNIQUE (code)`

<a id="refcountry"></a>
### `ref.country`

Lookup: countries (ISO 3166-1).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `iso2` | character(2) |  |  |  |
| `iso3` | character(3) |  |  |  |
| `name` | text |  |  |  |
| `dial_code` | character varying(6) |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `country_pkey`: `PRIMARY KEY (id)`
- UNIQUE `country_iso2_key`: `UNIQUE (iso2)`
- UNIQUE `country_iso3_key`: `UNIQUE (iso3)`
- UNIQUE `country_name_key`: `UNIQUE (name)`
- CHECK `country_dial_code_check`: `CHECK (((dial_code)::text ~ '^\+[0-9]{1,4}$'::text))`
- CHECK `country_iso2_check`: `CHECK ((iso2 ~ '^[A-Z]{2}$'::text))`
- CHECK `country_iso3_check`: `CHECK ((iso3 ~ '^[A-Z]{3}$'::text))`

<a id="refcoupon_discount_type"></a>
### `ref.coupon_discount_type`

Lookup: percentage of the fee, or a fixed amount.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_percentage` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `coupon_discount_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `coupon_discount_type_code_key`: `UNIQUE (code)`

<a id="refcourse_category"></a>
### `ref.course_category`

Lookup: core / lab / project / elective kinds; is_elective decides fixed curriculum vs elective basket.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_elective` | boolean |  |  |  |
| `parent_category_id` | smallint | yes |  |  |
| `requires_supervision` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `course_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_category_code_key`: `UNIQUE (code)`
- FK `course_category_parent_category_id_fkey`: `FOREIGN KEY (parent_category_id) REFERENCES ref.course_category(id)`
- CHECK `course_category_check`: `CHECK ((parent_category_id IS DISTINCT FROM id))`

<a id="refcredit_transfer_status"></a>
### `ref.credit_transfer_status`

Lookup: submitted / approved / rejected; is_accepted decides whether the credits count.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_accepted` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `credit_transfer_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `credit_transfer_status_code_key`: `UNIQUE (code)`

<a id="refdata_category"></a>
### `ref.data_category`

Lookup: categories of personal data; is_sensitive drives redaction and controls.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_sensitive` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `data_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `data_category_code_key`: `UNIQUE (code)`

<a id="refdelivery_component"></a>
### `ref.delivery_component`

Lookup: LECTURE / TUTORIAL / PRACTICAL — the L-T-P structure of a course.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `delivery_component_pkey`: `PRIMARY KEY (id)`
- UNIQUE `delivery_component_code_key`: `UNIQUE (code)`

<a id="refdelivery_mode"></a>
### `ref.delivery_mode`

Lookup: delivery mode.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `delivery_mode_pkey`: `PRIMARY KEY (id)`
- UNIQUE `delivery_mode_code_key`: `UNIQUE (code)`

<a id="refdisciplinary_penalty"></a>
### `ref.disciplinary_penalty`

Lookup: penalties; requires_suspension = must be served as a DISCIPLINARY_SUSPENSION study break.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `requires_suspension` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `disciplinary_penalty_pkey`: `PRIMARY KEY (id)`
- UNIQUE `disciplinary_penalty_code_key`: `UNIQUE (code)`

<a id="refdisciplinary_status"></a>
### `ref.disciplinary_status`

Lookup: stage of a disciplinary case; is_decided = decision on record, is_terminal = case closed and final.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_decided` | boolean |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `disciplinary_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `disciplinary_status_code_key`: `UNIQUE (code)`

<a id="refdpr_request_type"></a>
### `ref.dpr_request_type`

Lookup: data-principal right requests with policy response window.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `dpdp_section` | text |  |  |  |
| `response_days` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `dpr_request_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `dpr_request_type_code_key`: `UNIQUE (code)`
- CHECK `dpr_request_type_response_days_check`: `CHECK ((response_days > 0))`

<a id="refdpr_status"></a>
### `ref.dpr_status`

Lookup: dpr status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `dpr_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `dpr_status_code_key`: `UNIQUE (code)`

<a id="refdriver_unavailability_reason"></a>
### `ref.driver_unavailability_reason`

Lookup: leave / sick / other duty / training (no free text about health).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `driver_unavailability_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `driver_unavailability_reason_code_key`: `UNIQUE (code)`

<a id="refduty_leave_scope"></a>
### `ref.duty_leave_scope`

Lookup: who gets duty leave for an event — participants, organisers, or both.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `covers_participants` | boolean |  |  |  |
| `covers_organisers` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `duty_leave_scope_pkey`: `PRIMARY KEY (id)`
- UNIQUE `duty_leave_scope_code_key`: `UNIQUE (code)`

<a id="refemployee_category"></a>
### `ref.employee_category`

Lookup: employee category.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `employee_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `employee_category_code_key`: `UNIQUE (code)`

<a id="refemployment_status"></a>
### `ref.employment_status`

Lookup: employment states; is_current_member = counts as a current employee.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_current_member` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `employment_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `employment_status_code_key`: `UNIQUE (code)`

<a id="refemployment_type"></a>
### `ref.employment_type`

Lookup: employment type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `employment_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `employment_type_code_key`: `UNIQUE (code)`

<a id="refenrollment_end_reason"></a>
### `ref.enrollment_end_reason`

Lookup: enrollment end reason.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `enrollment_end_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `enrollment_end_reason_code_key`: `UNIQUE (code)`

<a id="refentry_direction"></a>
### `ref.entry_direction`

Lookup: IN (entry) / OUT (exit) at the gate.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_entry` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `entry_direction_pkey`: `PRIMARY KEY (id)`
- UNIQUE `entry_direction_code_key`: `UNIQUE (code)`

<a id="referasure_action"></a>
### `ref.erasure_action`

Lookup: erasure action.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `erasure_action_pkey`: `PRIMARY KEY (id)`
- UNIQUE `erasure_action_code_key`: `UNIQUE (code)`

<a id="refevaluation_part"></a>
### `ref.evaluation_part`

Lookup: INTERNAL (continuous) / EXTERNAL (end-semester) part of a scheme; each assessment type belongs to one.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `evaluation_part_pkey`: `PRIMARY KEY (id)`
- UNIQUE `evaluation_part_code_key`: `UNIQUE (code)`

<a id="refevaluation_round"></a>
### `ref.evaluation_round`

Lookup: first evaluation / moderation / revaluation; the highest precedence present is the mark that counts.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `precedence` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `evaluation_round_pkey`: `PRIMARY KEY (id)`
- UNIQUE `evaluation_round_code_key`: `UNIQUE (code)`
- UNIQUE `evaluation_round_precedence_key`: `UNIQUE (precedence)`

<a id="refevent_audience_kind"></a>
### `ref.event_audience_kind`

Lookup: who an event is for (students, faculty, staff, alumni, external guests …); is_external raises the EXTERNAL_GUESTS flag on the approval round.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_external` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_audience_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_audience_kind_code_key`: `UNIQUE (code)`

<a id="refevent_certificate_type"></a>
### `ref.event_certificate_type`

Lookup: participation, winner or volunteer certificate.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_certificate_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_certificate_type_code_key`: `UNIQUE (code)`

<a id="refevent_field_type"></a>
### `ref.event_field_type`

Lookup: types of an extra registration question; has_options (dropdown / radio), is_file.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `has_options` | boolean |  | `false` |  |
| `is_file` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_field_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_field_type_code_key`: `UNIQUE (code)`

<a id="refevent_kind"></a>
### `ref.event_kind`

Lookup: conference / fest / workshop / ceremony / sports meet / exhibition.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_kind_code_key`: `UNIQUE (code)`

<a id="refevent_level"></a>
### `ref.event_level`

Lookup: event level by duration in hours (level 1: 2–4 h … level 4: more than 18 h).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `min_hours` | smallint |  |  |  |
| `max_hours` | smallint | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_level_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_level_code_key`: `UNIQUE (code)`
- CHECK `event_level_check`: `CHECK ((max_hours > min_hours))`
- CHECK `event_level_min_hours_check`: `CHECK ((min_hours >= 0))`

<a id="refevent_mode"></a>
### `ref.event_mode`

Lookup: offline / online / hybrid.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_mode_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_mode_code_key`: `UNIQUE (code)`

<a id="refevent_prize_type"></a>
### `ref.event_prize_type`

Lookup: cash, certificate, trophy, internship, scholarship, voucher, merchandise.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_prize_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_prize_type_code_key`: `UNIQUE (code)`

<a id="refevent_round_type"></a>
### `ref.event_round_type`

Lookup: general session, registration desk, elimination round, final.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_round_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_round_type_code_key`: `UNIQUE (code)`

<a id="refevent_type"></a>
### `ref.event_type`

Lookup: kinds of event (workshop, hackathon, seminar …) and the facility package kind each books under.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `event_kind_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `event_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_type_code_key`: `UNIQUE (code)`
- FK `event_type_event_kind_id_fkey`: `FOREIGN KEY (event_kind_id) REFERENCES ref.event_kind(id)`

<a id="refexam_attempt_type"></a>
### `ref.exam_attempt_type`

Lookup: regular / backlog / improvement / supplementary; requires_eligibility applies the attendance & hold check.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `requires_eligibility` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `exam_attempt_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_attempt_type_code_key`: `UNIQUE (code)`

<a id="refexam_attendance_status"></a>
### `ref.exam_attendance_status`

Lookup: exam attendance status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `exam_attendance_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_attendance_status_code_key`: `UNIQUE (code)`

<a id="refexam_hold_type"></a>
### `ref.exam_hold_type`

Lookup: exam hold type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `exam_hold_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_hold_type_code_key`: `UNIQUE (code)`

<a id="refexam_session_type"></a>
### `ref.exam_session_type`

Lookup: exam session type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `exam_session_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_session_type_code_key`: `UNIQUE (code)`

<a id="refexaminer_recommendation"></a>
### `ref.examiner_recommendation`

Lookup: examiner recommendation.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_accept` | boolean |  |  |  |
| `blocks_viva` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `examiner_recommendation_pkey`: `PRIMARY KEY (id)`
- UNIQUE `examiner_recommendation_code_key`: `UNIQUE (code)`

<a id="refexaminer_role"></a>
### `ref.examiner_role`

Lookup: internal / external examiner / chair of a practical or viva panel; is_external = must be an outside person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_external` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `examiner_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `examiner_role_code_key`: `UNIQUE (code)`

<a id="refexternal_provider_type"></a>
### `ref.external_provider_type`

Lookup: where external credits come from (university, MOOC platform, industry).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `external_provider_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `external_provider_type_code_key`: `UNIQUE (code)`

<a id="reffacility_resource_kind"></a>
### `ref.facility_resource_kind`

Lookup: ROOM / ASSET / VEHICLE / GUEST_ROOM / PARKING / KEY — what a booking restriction bars a person from.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `facility_resource_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `facility_resource_kind_code_key`: `UNIQUE (code)`

<a id="reffuel_type"></a>
### `ref.fuel_type`

Lookup: petrol / diesel / CNG / electric / hybrid.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `fuel_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `fuel_type_code_key`: `UNIQUE (code)`

<a id="reffunding_source"></a>
### `ref.funding_source`

Lookup: where an event's money comes from (university fund, sponsorship, registration fees, other).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `funding_source_pkey`: `PRIMARY KEY (id)`
- UNIQUE `funding_source_code_key`: `UNIQUE (code)`

<a id="refgender"></a>
### `ref.gender`

Lookup: gender.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `gender_pkey`: `PRIMARY KEY (id)`
- UNIQUE `gender_code_key`: `UNIQUE (code)`

<a id="refgrade"></a>
### `ref.grade`

Lookup: officer levels O1–O10 (rank 1 = most senior).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `rank` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `grade_pkey`: `PRIMARY KEY (id)`
- UNIQUE `grade_code_key`: `UNIQUE (code)`
- UNIQUE `grade_rank_key`: `UNIQUE (rank)`

<a id="refguest_category"></a>
### `ref.guest_category`

Lookup: who a guest is (faculty, student, official guest, external examiner, visitor, parent), which kind of person may be booked under it and whether the stay is complimentary.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `guest_kind` | citext |  |  |  |
| `is_complimentary` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `guest_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `guest_category_code_key`: `UNIQUE (code)`
- CHECK `guest_category_guest_kind_check`: `CHECK ((guest_kind = ANY (ARRAY['EMPLOYEE'::citext, 'STUDENT'::citext, 'EXTERNAL'::citext, 'ANY'::citext])))`

<a id="refhold_type"></a>
### `ref.hold_type`

Lookup: kind of use in the occupancy ledger (TIMETABLE, EXAM, CONVOCATION, OFFICIAL_EVENT …), the source table that writes it and its default setup / teardown buffers.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `source_table` | text |  |  |  |
| `default_setup_minutes` | smallint |  | `0` |  |
| `default_teardown_minutes` | smallint |  | `0` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `hold_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `hold_type_code_key`: `UNIQUE (code)`
- CHECK `hold_type_default_setup_minutes_check`: `CHECK ((default_setup_minutes >= 0))`
- CHECK `hold_type_default_teardown_minutes_check`: `CHECK ((default_teardown_minutes >= 0))`

<a id="refid_document_type"></a>
### `ref.id_document_type`

Lookup: id document type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `id_document_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `id_document_type_code_key`: `UNIQUE (code)`

<a id="refjob_function"></a>
### `ref.job_function`

Lookup: functional area of work (Academics, Finance, IT…), independent of the org-unit tree.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `job_function_pkey`: `PRIMARY KEY (id)`
- UNIQUE `job_function_code_key`: `UNIQUE (code)`

<a id="refjob_role"></a>
### `ref.job_role`

Lookup: what the person actually does (Teaching, Recruitment…), distinct from Designation (the formal title/rank).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `job_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `job_role_code_key`: `UNIQUE (code)`

<a id="refkey_kind"></a>
### `ref.key_kind`

Lookup: key / spare key / master key / access card.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_master` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `key_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `key_kind_code_key`: `UNIQUE (code)`

<a id="reflanguage"></a>
### `ref.language`

Lookup: languages; is_scheduled_language marks the 8th-Schedule languages (DPDP §5(3)).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_scheduled_language` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `language_pkey`: `PRIMARY KEY (id)`
- UNIQUE `language_code_key`: `UNIQUE (code)`

<a id="refleave_type"></a>
### `ref.leave_type`

Lookup: duty / medical leave; attendance_status_id = how an approved leave day counts in attendance.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `attendance_status_id` | smallint |  |  |  |
| `needs_document` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `leave_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `leave_type_code_key`: `UNIQUE (code)`
- FK `leave_type_attendance_status_id_fkey`: `FOREIGN KEY (attendance_status_id) REFERENCES ref.attendance_status(id)`

<a id="reflegal_basis"></a>
### `ref.legal_basis`

Lookup: DPDP grounds for processing (consent §6 or legitimate use §7).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `dpdp_section` | text |  |  |  |
| `requires_consent` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `legal_basis_pkey`: `PRIMARY KEY (id)`
- UNIQUE `legal_basis_code_key`: `UNIQUE (code)`

<a id="reflicence_class"></a>
### `ref.licence_class`

Lookup: driving-licence classes ranked so that a higher class covers the lower ones (MCWG < LMV < LMV_TR < HMV < HPMV).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `rank` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `licence_class_pkey`: `PRIMARY KEY (id)`
- UNIQUE `licence_class_code_key`: `UNIQUE (code)`
- UNIQUE `licence_class_rank_key`: `UNIQUE (rank)`

<a id="reflockout_reason"></a>
### `ref.lockout_reason`

Lookup: lockout reason.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `lockout_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `lockout_reason_code_key`: `UNIQUE (code)`

<a id="refmail_audience"></a>
### `ref.mail_audience`

Lookup: whom a message goes to — all, confirmed, pending, cancelled (flags per registration state), or a selection.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `includes_confirmed` | boolean |  | `false` |  |
| `includes_pending` | boolean |  | `false` |  |
| `includes_cancelled` | boolean |  | `false` |  |
| `is_selection` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `mail_audience_pkey`: `PRIMARY KEY (id)`
- UNIQUE `mail_audience_code_key`: `UNIQUE (code)`

<a id="refmail_delivery_status"></a>
### `ref.mail_delivery_status`

Lookup: queued, delivered (is_delivered), failed, bounced; is_final = the outcome can no longer change.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_final` | boolean |  | `false` |  |
| `is_delivered` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `mail_delivery_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `mail_delivery_status_code_key`: `UNIQUE (code)`

<a id="refmaintenance_type"></a>
### `ref.maintenance_type`

Lookup: AMC service, inspection, calibration, deep cleaning, fire safety, pest control.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `maintenance_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `maintenance_type_code_key`: `UNIQUE (code)`

<a id="refmeeting_mode"></a>
### `ref.meeting_mode`

Lookup: in person / online / phone mentoring meeting.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `meeting_mode_pkey`: `PRIMARY KEY (id)`
- UNIQUE `meeting_mode_code_key`: `UNIQUE (code)`

<a id="refmfa_factor_type"></a>
### `ref.mfa_factor_type`

Lookup: mfa factor type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `mfa_factor_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `mfa_factor_type_code_key`: `UNIQUE (code)`

<a id="refmisconduct_type"></a>
### `ref.misconduct_type`

Lookup: kinds of student misconduct outside the exam hall (ragging, harassment, property damage …).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `misconduct_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `misconduct_type_code_key`: `UNIQUE (code)`

<a id="reforg_unit_type"></a>
### `ref.org_unit_type`

Lookup: kinds of organisational unit (UNIVERSITY, SCHOOL, DEPARTMENT, CENTRAL_DEPARTMENT ...).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_academic` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `org_unit_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `org_unit_type_code_key`: `UNIQUE (code)`

<a id="refotp_purpose"></a>
### `ref.otp_purpose`

Lookup: otp purpose.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `otp_purpose_pkey`: `PRIMARY KEY (id)`
- UNIQUE `otp_purpose_code_key`: `UNIQUE (code)`

<a id="refpaper_setter_role"></a>
### `ref.paper_setter_role`

Lookup: paper setter role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `paper_setter_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `paper_setter_role_code_key`: `UNIQUE (code)`

<a id="refparking_permit_type"></a>
### `ref.parking_permit_type`

Lookup: staff / student / visitor / contractor parking permit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `parking_permit_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `parking_permit_type_code_key`: `UNIQUE (code)`

<a id="refparticipation_type"></a>
### `ref.participation_type`

Lookup: individual or team participation.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_team` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `participation_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `participation_type_code_key`: `UNIQUE (code)`

<a id="refpayment_channel"></a>
### `ref.payment_channel`

Lookup: online gateway (is_online) or offline — UPI, bank transfer, cash — verified by an organiser.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_online` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `payment_channel_pkey`: `PRIMARY KEY (id)`
- UNIQUE `payment_channel_code_key`: `UNIQUE (code)`

<a id="refpayment_status"></a>
### `ref.payment_status`

Lookup: created / authorised (is_open), captured (is_settled), failed, refunded (is_refunded).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_open` | boolean |  | `false` |  |
| `is_settled` | boolean |  | `false` |  |
| `is_refunded` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `payment_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `payment_status_code_key`: `UNIQUE (code)`

<a id="refprincipal_kind"></a>
### `ref.principal_kind`

Lookup: principal kind.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `principal_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `principal_kind_code_key`: `UNIQUE (code)`

<a id="refprize_type"></a>
### `ref.prize_type`

Lookup: gold / silver / bronze medal, merit and endowment prizes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `prize_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `prize_type_code_key`: `UNIQUE (code)`

<a id="refprogram_level"></a>
### `ref.program_level`

Lookup: UG, PG, integrated, doctoral, diploma, certificate.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `program_level_pkey`: `PRIMARY KEY (id)`
- UNIQUE `program_level_code_key`: `UNIQUE (code)`

<a id="refprogram_outcome_type"></a>
### `ref.program_outcome_type`

Lookup: program outcome type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `program_outcome_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `program_outcome_type_code_key`: `UNIQUE (code)`

<a id="refprogress_review_outcome"></a>
### `ref.progress_review_outcome`

Lookup: progress review outcome.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_satisfactory` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `progress_review_outcome_pkey`: `PRIMARY KEY (id)`
- UNIQUE `progress_review_outcome_code_key`: `UNIQUE (code)`

<a id="refpublication_type"></a>
### `ref.publication_type`

Lookup: publication type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `publication_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `publication_type_code_key`: `UNIQUE (code)`

<a id="refquestion_difficulty"></a>
### `ref.question_difficulty`

Lookup: easy / medium / hard question.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `rank` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `question_difficulty_pkey`: `PRIMARY KEY (id)`
- UNIQUE `question_difficulty_code_key`: `UNIQUE (code)`
- UNIQUE `question_difficulty_rank_key`: `UNIQUE (rank)`

<a id="refquestion_paper_status"></a>
### `ref.question_paper_status`

Lookup: question paper status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_moderated` | boolean |  |  |  |
| `is_approved` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `question_paper_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `question_paper_status_code_key`: `UNIQUE (code)`

<a id="refquestion_type"></a>
### `ref.question_type`

Lookup: MCQ / short / long / numerical / case-study question.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `question_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `question_type_code_key`: `UNIQUE (code)`

<a id="refrating_role"></a>
### `ref.rating_role`

Lookup: PASSENGER (rates the driver) / DRIVER (rates the passengers).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `rating_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `rating_role_code_key`: `UNIQUE (code)`

<a id="refregistration_cancel_reason"></a>
### `ref.registration_cancel_reason`

Lookup: why a registration was cancelled (withdrawn, by the organisers, event cancelled, unpaid).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `registration_cancel_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `registration_cancel_reason_code_key`: `UNIQUE (code)`

<a id="refregistration_status"></a>
### `ref.registration_status`

Lookup: registration status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_counted` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `registration_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `registration_status_code_key`: `UNIQUE (code)`

<a id="refregulatory_body"></a>
### `ref.regulatory_body`

Lookup: regulatory body.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `regulatory_body_pkey`: `PRIMARY KEY (id)`
- UNIQUE `regulatory_body_code_key`: `UNIQUE (code)`

<a id="refrelationship_type"></a>
### `ref.relationship_type`

Lookup: relationship type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `relationship_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `relationship_type_code_key`: `UNIQUE (code)`

<a id="refreporting_line_type"></a>
### `ref.reporting_line_type`

Lookup: REPORTING (line manager) vs REVIEWING (appraisal / skip-level manager).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `reporting_line_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `reporting_line_type_code_key`: `UNIQUE (code)`

<a id="refresult_status"></a>
### `ref.result_status`

Lookup: pass / fail / absent / withheld / incomplete.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_pass` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `result_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `result_status_code_key`: `UNIQUE (code)`

<a id="refrevaluation_status"></a>
### `ref.revaluation_status`

Lookup: revaluation status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `revaluation_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `revaluation_status_code_key`: `UNIQUE (code)`

<a id="refrevaluation_type"></a>
### `ref.revaluation_type`

Lookup: revaluation type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `revaluation_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `revaluation_type_code_key`: `UNIQUE (code)`

<a id="refroom_feature"></a>
### `ref.room_feature`

Lookup: room features (projector, computers, wheelchair access …) a course may require.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `category` | citext | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `room_feature_pkey`: `PRIMARY KEY (id)`
- UNIQUE `room_feature_code_key`: `UNIQUE (code)`

<a id="refroom_service_type"></a>
### `ref.room_service_type`

Lookup: cleaning / repair / renovation / inspection / fumigation.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `room_service_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `room_service_type_code_key`: `UNIQUE (code)`

<a id="refroom_type"></a>
### `ref.room_type`

Lookup: room type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `room_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `room_type_code_key`: `UNIQUE (code)`

<a id="refroom_use"></a>
### `ref.room_use`

Lookup: FICM-style use classification of a room (classroom, laboratory, office, assembly, guest room, parking zone …) with is_bookable / is_guest_room / is_parking_zone.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_bookable` | boolean |  | `true` |  |
| `is_guest_room` | boolean |  | `false` |  |
| `is_parking_zone` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `room_use_pkey`: `PRIMARY KEY (id)`
- UNIQUE `room_use_code_key`: `UNIQUE (code)`

<a id="refscan_source"></a>
### `ref.scan_source`

Lookup: LIVE gate scan or IMPORT of an offline attendance sheet.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `scan_source_pkey`: `PRIMARY KEY (id)`
- UNIQUE `scan_source_code_key`: `UNIQUE (code)`

<a id="refsection_role"></a>
### `ref.section_role`

Lookup: class representative roles in a section.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `section_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `section_role_code_key`: `UNIQUE (code)`

<a id="refsession_revoke_reason"></a>
### `ref.session_revoke_reason`

Lookup: session revoke reason.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `session_revoke_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `session_revoke_reason_code_key`: `UNIQUE (code)`

<a id="refsponsor_type"></a>
### `ref.sponsor_type`

Lookup: corporate / individual / organisation sponsor.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `sponsor_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `sponsor_type_code_key`: `UNIQUE (code)`

<a id="refstall_category"></a>
### `ref.stall_category`

Lookup: standard, premium, sponsored — the fee of a stall is set per event and category.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `stall_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_category_code_key`: `UNIQUE (code)`

<a id="refstall_setup"></a>
### `ref.stall_setup`

Lookup: special set-ups a stall may ask for (water, extra lighting, display board, canopy).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `stall_setup_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_setup_code_key`: `UNIQUE (code)`

<a id="refstall_size"></a>
### `ref.stall_size`

Lookup: standard stall sizes and CUSTOM (is_custom: described in words).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_custom` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `stall_size_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_size_code_key`: `UNIQUE (code)`

<a id="refstall_type"></a>
### `ref.stall_type`

Lookup: food, product, service, information, other.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `stall_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_type_code_key`: `UNIQUE (code)`

<a id="refstate_province"></a>
### `ref.state_province`

Lookup: states / union territories (ISO 3166-2) per country.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `country_id` | smallint |  |  |  |
| `code` | character varying(10) |  |  |  |
| `name` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `state_province_pkey`: `PRIMARY KEY (id)`
- UNIQUE `state_province_country_id_code_key`: `UNIQUE (country_id, code)`
- UNIQUE `state_province_country_id_name_key`: `UNIQUE (country_id, name)`
- FK `state_province_country_id_fkey`: `FOREIGN KEY (country_id) REFERENCES ref.country(id)`

<a id="refstorage_backend"></a>
### `ref.storage_backend`

Lookup: storage backend.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `storage_backend_pkey`: `PRIMARY KEY (id)`
- UNIQUE `storage_backend_code_key`: `UNIQUE (code)`

<a id="refstudent_status"></a>
### `ref.student_status`

Lookup: student states; is_current_member = counts as a current student.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_current_member` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `student_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `student_status_code_key`: `UNIQUE (code)`

<a id="refstudy_break_type"></a>
### `ref.study_break_type`

Lookup: study break type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `study_break_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `study_break_type_code_key`: `UNIQUE (code)`

<a id="refsupervisor_role"></a>
### `ref.supervisor_role`

Lookup: supervisor role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_principal` | boolean |  |  |  |
| `allows_external` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `supervisor_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `supervisor_role_code_key`: `UNIQUE (code)`

<a id="refterm_cycle"></a>
### `ref.term_cycle`

Lookup: recurring term slots of a calendar type (ODD, EVEN, ANNUAL, PROF_YEAR) and their order in the year.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `academic_calendar_type_id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `position` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `term_cycle_pkey`: `PRIMARY KEY (id)`
- UNIQUE `term_cycle_academic_calendar_type_id_position_key`: `UNIQUE (academic_calendar_type_id, "position")`
- UNIQUE `term_cycle_code_key`: `UNIQUE (code)`
- FK `term_cycle_academic_calendar_type_id_fkey`: `FOREIGN KEY (academic_calendar_type_id) REFERENCES ref.academic_calendar_type(id)`
- CHECK `term_cycle_position_check`: `CHECK (("position" >= 1))`

<a id="refterm_registration_status"></a>
### `ref.term_registration_status`

Lookup: term registration status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_counted` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `term_registration_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `term_registration_status_code_key`: `UNIQUE (code)`

<a id="refthesis_examiner_role"></a>
### `ref.thesis_examiner_role`

Lookup: thesis examiner role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_external` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `thesis_examiner_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `thesis_examiner_role_code_key`: `UNIQUE (code)`

<a id="refthesis_status"></a>
### `ref.thesis_status`

Lookup: thesis status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `thesis_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `thesis_status_code_key`: `UNIQUE (code)`

<a id="reftms_academic_context_rule"></a>
### `ref.tms_academic_context_rule`

Lookup: what academic context a category's tickets carry (none; batch, term and semester; and the course).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `needs_context` | boolean |  |  |  |
| `needs_course` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_academic_context_rule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_academic_context_rule_code_key`: `UNIQUE (code)`
- CHECK `tms_academic_context_rule_check`: `CHECK (((NOT needs_course) OR needs_context))`

<a id="reftms_anchor_base"></a>
### `ref.tms_anchor_base`

Lookup: where a POSITION route level looks — the requester's unit, the category's unit, or a fixed unit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_anchor_base_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_anchor_base_code_key`: `UNIQUE (code)`

<a id="reftms_assignment_basis"></a>
### `ref.tms_assignment_basis`

Lookup: why a ticket went to its assignee (round-robin, route, manual, escalation, reassignment, recusal, referral).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_assignment_basis_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_assignment_basis_code_key`: `UNIQUE (code)`

<a id="reftms_category_level"></a>
### `ref.tms_category_level`

Lookup: levels of the helpdesk category tree (KRA type, master, category, leaf) with their labels per domain.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `depth` | smallint |  |  |  |
| `student_label` | text | yes |  |  |
| `employee_label` | text |  |  |  |
| `is_leaf` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_category_level_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_category_level_code_key`: `UNIQUE (code)`
- UNIQUE `tms_category_level_depth_key`: `UNIQUE (depth)`
- CHECK `tms_category_level_depth_check`: `CHECK (((depth >= 0) AND (depth <= 3)))`

<a id="reftms_category_type"></a>
### `ref.tms_category_type`

Lookup: academic / non-academic / examination — classification of a master category.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_category_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_category_type_code_key`: `UNIQUE (code)`

<a id="reftms_closure_reason"></a>
### `ref.tms_closure_reason`

Lookup: why a ticket ended, and whether it can then be rated or reopened.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_ratable` | boolean |  |  |  |
| `is_reopenable` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_closure_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_closure_reason_code_key`: `UNIQUE (code)`

<a id="reftms_event_actor"></a>
### `ref.tms_event_actor`

Lookup: who may record an event (requester, handler, either, forum member, scheduled job).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_event_actor_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_event_actor_code_key`: `UNIQUE (code)`

<a id="reftms_event_allowed_status"></a>
### `ref.tms_event_allowed_status`

The ticket lifecycle as data: the statuses in which each event may be recorded.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_type_id` | smallint |  |  |  |
| `ticket_status_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `tms_event_allowed_status_pkey`: `PRIMARY KEY (event_type_id, ticket_status_id)`
- FK `tms_event_allowed_status_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.tms_event_type(id) ON DELETE CASCADE`
- FK `tms_event_allowed_status_ticket_status_id_fkey`: `FOREIGN KEY (ticket_status_id) REFERENCES ref.tms_ticket_status(id)`

<a id="reftms_event_type"></a>
### `ref.tms_event_type`

Lookup: timeline event types and what each does to the derived state (status, assignee, SLA clock, closure).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `event_actor_id` | smallint |  |  |  |
| `sets_status_id` | smallint | yes |  |  |
| `sets_assignee` | boolean |  | `false` |  |
| `starts_clock` | boolean |  | `false` |  |
| `pauses_clock` | boolean |  | `false` |  |
| `stops_clock` | boolean |  | `false` |  |
| `needs_remark` | boolean |  | `false` |  |
| `needs_remark_or_file` | boolean |  | `false` |  |
| `closure_reason_id` | smallint | yes |  |  |
| `counts_as_response` | boolean |  | `false` |  |
| `allows_files` | boolean |  | `false` |  |
| `shown_to_requester` | boolean |  | `true` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_event_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_event_type_code_key`: `UNIQUE (code)`
- FK `tms_event_type_closure_reason_id_fkey`: `FOREIGN KEY (closure_reason_id) REFERENCES ref.tms_closure_reason(id)`
- FK `tms_event_type_event_actor_id_fkey`: `FOREIGN KEY (event_actor_id) REFERENCES ref.tms_event_actor(id)`
- FK `tms_event_type_sets_status_id_fkey`: `FOREIGN KEY (sets_status_id) REFERENCES ref.tms_ticket_status(id)`
- CHECK `tms_event_type_check`: `CHECK (((((starts_clock)::integer + (pauses_clock)::integer) + (stops_clock)::integer) <= 1))`
- CHECK `tms_event_type_check1`: `CHECK ((NOT (needs_remark AND needs_remark_or_file)))`

<a id="reftms_grievance_head"></a>
### `ref.tms_grievance_head`

Lookup: grievance heads for reporting — those listed in the UGC grievance regulations, the statutory channels and other.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_ugc_listed` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_grievance_head_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_grievance_head_code_key`: `UNIQUE (code)`

<a id="reftms_hold_reason"></a>
### `ref.tms_hold_reason`

Lookup: what a ticket on hold awaits (another office, a vendor, an external body, a third-party document).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_hold_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_hold_reason_code_key`: `UNIQUE (code)`

<a id="reftms_intake_channel"></a>
### `ref.tms_intake_channel`

Lookup: how a ticket reached the helpdesk (portal, walk-in, phone, e-mail, letter).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_self_service` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_intake_channel_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_intake_channel_code_key`: `UNIQUE (code)`

<a id="reftms_message_type"></a>
### `ref.tms_message_type`

Lookup: grievance / assistance / enquiry / feedback / service request — domains, whether it can go to a forum, whether relief sought is required.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `for_student` | boolean |  |  |  |
| `for_employee` | boolean |  |  |  |
| `is_grievance` | boolean |  | `false` |  |
| `requires_relief` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_message_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_message_type_code_key`: `UNIQUE (code)`

<a id="reftms_notice_recipient"></a>
### `ref.tms_notice_recipient`

Lookup: who a notice rule addresses (requester, assignee after / before, forum members, followers).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_notice_recipient_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_notice_recipient_code_key`: `UNIQUE (code)`

<a id="reftms_notification_status"></a>
### `ref.tms_notification_status`

Lookup: delivery outcome of a queued notice.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_final` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_notification_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_notification_status_code_key`: `UNIQUE (code)`

<a id="reftms_priority"></a>
### `ref.tms_priority`

Lookup: ticket priorities — the default SLA hours per level, first-response hours, office hours or round the clock (POLICY); a category may define its own.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `sla_hours` | smallint |  |  |  |
| `first_response_hours` | smallint | yes |  |  |
| `office_hours_only` | boolean | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_priority_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_priority_code_key`: `UNIQUE (code)`
- CHECK `tms_priority_check`: `CHECK (((first_response_hours IS NULL) OR (first_response_hours <= sla_hours)))`
- CHECK `tms_priority_first_response_hours_check`: `CHECK ((first_response_hours > 0))`
- CHECK `tms_priority_sla_hours_check`: `CHECK ((sla_hours > 0))`

<a id="reftms_redressal_outcome"></a>
### `ref.tms_redressal_outcome`

Lookup: outcome of a forum decision (upheld, partly upheld, not upheld, not maintainable).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_in_favour` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_redressal_outcome_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_redressal_outcome_code_key`: `UNIQUE (code)`

<a id="reftms_route_level_kind"></a>
### `ref.tms_route_level_kind`

Lookup: kinds of route level (handler pool, category owner, mentor, manager, position, named person).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_route_level_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_route_level_kind_code_key`: `UNIQUE (code)`

<a id="reftms_ticket_domain"></a>
### `ref.tms_ticket_domain`

Lookup: helpdesk domains (student / employee) — who may raise, the permissions that govern them, whether context must be the requester's own.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `principal_kind_id` | smallint |  |  |  |
| `uses_kra_type` | boolean |  |  |  |
| `context_must_be_own` | boolean |  | `false` |  |
| `create_permission_id` | integer |  |  |  |
| `view_permission_id` | integer |  |  |  |
| `update_permission_id` | integer |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_ticket_domain_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_ticket_domain_code_key`: `UNIQUE (code)`
- FK `tms_ticket_domain_create_permission_id_fkey`: `FOREIGN KEY (create_permission_id) REFERENCES authz.permission(id)`
- FK `tms_ticket_domain_principal_kind_id_fkey`: `FOREIGN KEY (principal_kind_id) REFERENCES ref.principal_kind(id)`
- FK `tms_ticket_domain_update_permission_id_fkey`: `FOREIGN KEY (update_permission_id) REFERENCES authz.permission(id)`
- FK `tms_ticket_domain_view_permission_id_fkey`: `FOREIGN KEY (view_permission_id) REFERENCES authz.permission(id)`

<a id="reftms_ticket_status"></a>
### `ref.tms_ticket_status`

Lookup: ticket statuses (derived from the timeline): open, escalated, with the forum, resolved (awaiting the requester), closed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_closed` | boolean |  |  |  |
| `awaits_requester` | boolean |  | `false` |  |
| `is_with_forum` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `tms_ticket_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `tms_ticket_status_code_key`: `UNIQUE (code)`

<a id="reftrack_type"></a>
### `ref.track_type`

Lookup: minor / honours / honours with research; requires_own_program separates honours (own programme) from a minor (another discipline).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `requires_own_program` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `track_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `track_type_code_key`: `UNIQUE (code)`

<a id="reftrip_alert_type"></a>
### `ref.trip_alert_type`

Lookup: AUTO_APPROVED / UNALLOCATED_SOON / EXPIRED — alerts raised by the escalation job.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `trip_alert_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_alert_type_code_key`: `UNIQUE (code)`

<a id="reftrip_cancel_reason"></a>
### `ref.trip_cancel_reason`

Lookup: why a trip request was cancelled.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `trip_cancel_reason_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_cancel_reason_code_key`: `UNIQUE (code)`

<a id="reftrip_purpose"></a>
### `ref.trip_purpose`

Lookup: official visit, field visit, guest pick-up, airport transfer, excursion, medical, event logistics.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `allows_self_drive` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `trip_purpose_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_purpose_code_key`: `UNIQUE (code)`

<a id="refufm_case_status"></a>
### `ref.ufm_case_status`

Lookup: ufm case status.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `ufm_case_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ufm_case_status_code_key`: `UNIQUE (code)`

<a id="refufm_penalty"></a>
### `ref.ufm_penalty`

Lookup: ufm penalty.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `ufm_penalty_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ufm_penalty_code_key`: `UNIQUE (code)`

<a id="refvehicle_document_type"></a>
### `ref.vehicle_document_type`

Lookup: RC, insurance, PUC, fitness, permit, road tax; is_mandatory_for_trip = must be valid for the whole trip.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_mandatory_for_trip` | boolean |  | `true` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `vehicle_document_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `vehicle_document_type_code_key`: `UNIQUE (code)`

<a id="refvehicle_service_type"></a>
### `ref.vehicle_service_type`

Lookup: servicing / repair / tyres / accident repair / inspection.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `vehicle_service_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `vehicle_service_type_code_key`: `UNIQUE (code)`

<a id="refvehicle_type"></a>
### `ref.vehicle_type`

Lookup: car / SUV / van / mini bus / bus / ambulance / truck / two-wheeler; is_passenger.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_passenger` | boolean |  | `true` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `vehicle_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `vehicle_type_code_key`: `UNIQUE (code)`

<a id="refverification_method"></a>
### `ref.verification_method`

Lookup: verification method.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `verification_method_pkey`: `PRIMARY KEY (id)`
- UNIQUE `verification_method_code_key`: `UNIQUE (code)`

<a id="refvolunteer_role"></a>
### `ref.volunteer_role`

Lookup: volunteer or event manager (is_manager = may manage the event).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_manager` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `volunteer_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `volunteer_role_code_key`: `UNIQUE (code)`

<a id="refwf_action_type"></a>
### `ref.wf_action_type`

Lookup: APPROVE / SIGN / RETURN / RETURN_TO / REJECT / WITHDRAW / FORWARD / DELEGATE and the system actions AUTO_APPROVE / AUTO_REJECT / ESCALATE; the flags (completes_step, closes_instance, needs_note, is_system, is_rejection, returns_to_step, reassigns, restarts_clock) drive the workflow rules.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `completes_step` | boolean |  |  |  |
| `closes_instance` | boolean |  |  |  |
| `needs_note` | boolean |  |  |  |
| `is_system` | boolean |  | `false` |  |
| `is_rejection` | boolean |  | `false` |  |
| `returns_to_step` | boolean |  | `false` |  |
| `reassigns` | boolean |  | `false` |  |
| `restarts_clock` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_action_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_action_type_code_key`: `UNIQUE (code)`

<a id="refwf_approver_kind"></a>
### `ref.wf_approver_kind`

Lookup: who decides a level — PERMISSION at a unit, POSITION holder, MANAGER of the person concerned, NAMED person(s), COMMITTEE with a quorum.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_approver_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_approver_kind_code_key`: `UNIQUE (code)`

<a id="refwf_comment_status"></a>
### `ref.wf_comment_status`

Lookup: pending / accepted / rejected reviewer comment.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_resolved` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_comment_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_comment_status_code_key`: `UNIQUE (code)`

<a id="refwf_flag"></a>
### `ref.wf_flag`

Lookup: facts about a request (registered by modules: PAID, EXTERNAL_GUESTS …) on which a level can be made conditional.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_flag_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_flag_code_key`: `UNIQUE (code)`

<a id="refwf_notice_kind"></a>
### `ref.wf_notice_kind`

Lookup: kinds of notice in the approval outbox (step pending, reminder, escalated, forwarded, returned, rejected, approved).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_notice_kind_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_notice_kind_code_key`: `UNIQUE (code)`

<a id="refwf_self_action"></a>
### `ref.wf_self_action`

Lookup: what a level does when the requester is its approver — BLOCK (someone else decides) or SKIP (level left out).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_self_action_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_self_action_code_key`: `UNIQUE (code)`

<a id="refwf_timeout_action"></a>
### `ref.wf_timeout_action`

Lookup: what happens when a level passes its deadline — NONE / REMIND / ESCALATE / AUTO_APPROVE / AUTO_REJECT.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `wf_timeout_action_pkey`: `PRIMARY KEY (id)`
- UNIQUE `wf_timeout_action_code_key`: `UNIQUE (code)`

<a id="refwork_order_category"></a>
### `ref.work_order_category`

Lookup: electrical / plumbing / HVAC / civil / IT-AV / furniture / housekeeping / safety.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `work_order_category_pkey`: `PRIMARY KEY (id)`
- UNIQUE `work_order_category_code_key`: `UNIQUE (code)`

<a id="refwork_order_priority"></a>
### `ref.work_order_priority`

Lookup: emergency / high / normal / low with resolve_within (the SLA) — POLICY.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `resolve_within` | interval |  |  |  |
| `rank` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `work_order_priority_pkey`: `PRIMARY KEY (id)`
- UNIQUE `work_order_priority_code_key`: `UNIQUE (code)`
- UNIQUE `work_order_priority_rank_key`: `UNIQUE (rank)`

<a id="refwork_order_status"></a>
### `ref.work_order_status`

Lookup: reported / assigned / in progress / on hold / closed / rejected; is_terminal ends the work order.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_terminal` | boolean |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `work_order_status_pkey`: `PRIMARY KEY (id)`
- UNIQUE `work_order_status_code_key`: `UNIQUE (code)`

## Schema `org` — Organisation

<a id="orgappointment"></a>
### `org.appointment`

Who holds a position of a unit over time; one holder per (unit, position) at any moment.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `org_unit_id` | uuid |  |  |  |
| `position_type_id` | smallint |  |  |  |
| `employee_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `order_reference` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `appointment_pkey`: `PRIMARY KEY (id)`
- FK `appointment_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `appointment_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `appointment_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- CHECK `appointment_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `appointment_single_holder`: `EXCLUDE USING gist (org_unit_id WITH =, position_type_id WITH =, valid WITH &&)`
- INDEX `appointment_employee_idx`: `btree (employee_id)`

<a id="orgbuilding"></a>
### `org.building`

Buildings / blocks within a campus (shared by all modules).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `campus_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `building_kind_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `building_pkey`: `PRIMARY KEY (id)`
- UNIQUE `building_campus_id_code_key`: `UNIQUE (campus_id, code)`
- UNIQUE `building_campus_id_name_key`: `UNIQUE (campus_id, name)`
- FK `building_building_kind_id_fkey`: `FOREIGN KEY (building_kind_id) REFERENCES ref.building_kind(id)`
- FK `building_campus_id_fkey`: `FOREIGN KEY (campus_id) REFERENCES org.campus(id)`

<a id="orgcampus"></a>
### `org.campus`

Physical campuses.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `city_id` | integer | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `campus_pkey`: `PRIMARY KEY (id)`
- UNIQUE `campus_code_key`: `UNIQUE (code)`
- UNIQUE `campus_name_key`: `UNIQUE (name)`
- FK `campus_city_id_fkey`: `FOREIGN KEY (city_id) REFERENCES ref.city(id)`

<a id="orgfloor"></a>
### `org.floor`

A floor of a building (level 0 = ground, negative = basement); rooms may sit on a floor; custody, reservation rules and keys can target a floor.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `building_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `level` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `floor_pkey`: `PRIMARY KEY (id)`
- UNIQUE `floor_building_id_code_key`: `UNIQUE (building_id, code)`
- UNIQUE `floor_building_id_level_key`: `UNIQUE (building_id, level)`
- FK `floor_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id) ON DELETE CASCADE`

<a id="orgorg_unit"></a>
### `org.org_unit`

One generic tree of organisational units (university → schools → departments; central departments → sections). Type nesting rules + cycle prevention enforced by trigger; exactly one root.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `org_unit_type_id` | smallint |  |  |  |
| `parent_id` | uuid | yes |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `short_name` | citext | yes |  |  |
| `description` | text | yes |  |  |
| `established_on` | date | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `org_unit_pkey`: `PRIMARY KEY (id)`
- UNIQUE `org_unit_code_key`: `UNIQUE (code)`
- UNIQUE `org_unit_name_uq_per_parent`: `UNIQUE NULLS NOT DISTINCT (parent_id, name)`
- UNIQUE `org_unit_short_name_uq`: `UNIQUE (short_name)`
- FK `org_unit_org_unit_type_id_fkey`: `FOREIGN KEY (org_unit_type_id) REFERENCES ref.org_unit_type(id)`
- FK `org_unit_parent_id_fkey`: `FOREIGN KEY (parent_id) REFERENCES org.org_unit(id) ON DELETE RESTRICT`
- CHECK `org_unit_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{2,32}$'::citext))`
- CHECK `org_unit_name_check`: `CHECK ((btrim(name) <> ''::text))`
- CHECK `org_unit_not_own_parent`: `CHECK ((parent_id IS DISTINCT FROM id))`
- INDEX `org_unit_parent_idx`: `btree (parent_id)`
- INDEX `org_unit_single_root_uq`: `btree ((true)) WHERE (parent_id IS NULL)`
- INDEX `org_unit_type_idx`: `btree (org_unit_type_id)`

<a id="orgorg_unit_contact"></a>
### `org.org_unit_contact`

Official contact points of a unit (office email, phone, website).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `org_unit_id` | uuid |  |  |  |
| `contact_channel_id` | smallint |  |  |  |
| `value` | citext |  |  |  |
| `is_primary` | boolean |  | `false` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `org_unit_contact_pkey`: `PRIMARY KEY (id)`
- UNIQUE `org_unit_contact_org_unit_id_contact_channel_id_value_key`: `UNIQUE (org_unit_id, contact_channel_id, value)`
- FK `org_unit_contact_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`
- FK `org_unit_contact_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- CHECK `org_unit_contact_value_check`: `CHECK ((btrim((value)::text) <> ''::text))`
- INDEX `org_unit_contact_one_primary_uq`: `btree (org_unit_id, contact_channel_id) WHERE is_primary`

<a id="orgorg_unit_location"></a>
### `org.org_unit_location`

Offices of a unit in buildings.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `org_unit_id` | uuid |  |  |  |
| `building_id` | uuid |  |  |  |
| `office_room` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `org_unit_location_pkey`: `PRIMARY KEY (org_unit_id, building_id)`
- FK `org_unit_location_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id)`
- FK `org_unit_location_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`

<a id="orgorg_unit_type_rule"></a>
### `org.org_unit_type_rule`

Which org-unit type may be the parent of which.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `parent_type_id` | smallint |  |  |  |
| `child_type_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `org_unit_type_rule_pkey`: `PRIMARY KEY (parent_type_id, child_type_id)`
- FK `org_unit_type_rule_child_type_id_fkey`: `FOREIGN KEY (child_type_id) REFERENCES ref.org_unit_type(id)`
- FK `org_unit_type_rule_parent_type_id_fkey`: `FOREIGN KEY (parent_type_id) REFERENCES ref.org_unit_type(id)`

<a id="orgposition_type"></a>
### `org.position_type`

Single-holder leadership positions (HEAD, DEAN, VC, REGISTRAR, DPO, GRIEVANCE_OFFICER).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `position_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `position_type_code_key`: `UNIQUE (code)`

<a id="orgposition_type_unit_type"></a>
### `org.position_type_unit_type`

Which unit types may carry which position.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `position_type_id` | smallint |  |  |  |
| `org_unit_type_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `position_type_unit_type_pkey`: `PRIMARY KEY (position_type_id, org_unit_type_id)`
- FK `position_type_unit_type_org_unit_type_id_fkey`: `FOREIGN KEY (org_unit_type_id) REFERENCES ref.org_unit_type(id)`
- FK `position_type_unit_type_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`

<a id="orgroom"></a>
### `org.room`

Rooms in a building (classroom, lab, hall) with teaching capacity and exam capacity; shared by timetable, exam seating and Resource Management.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `building_id` | uuid |  |  |  |
| `floor_id` | uuid | yes |  |  |
| `code` | citext |  |  |  |
| `name` | text | yes |  |  |
| `room_type_id` | smallint |  |  |  |
| `room_use_id` | smallint | yes |  |  |
| `capacity` | smallint |  |  |  |
| `chairs` | smallint | yes |  |  |
| `exam_capacity` | smallint | yes |  |  |
| `area_sqm` | numeric(8,2) | yes |  |  |
| `is_accessible` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `room_pkey`: `PRIMARY KEY (id)`
- UNIQUE `room_building_id_code_key`: `UNIQUE (building_id, code)`
- FK `room_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id)`
- FK `room_floor_id_fkey`: `FOREIGN KEY (floor_id) REFERENCES org.floor(id)`
- FK `room_room_type_id_fkey`: `FOREIGN KEY (room_type_id) REFERENCES ref.room_type(id)`
- FK `room_room_use_id_fkey`: `FOREIGN KEY (room_use_id) REFERENCES ref.room_use(id)`
- CHECK `room_area_sqm_check`: `CHECK ((area_sqm > (0)::numeric))`
- CHECK `room_capacity_check`: `CHECK ((capacity > 0))`
- CHECK `room_chairs_check`: `CHECK ((chairs >= 0))`
- CHECK `room_exam_capacity_check`: `CHECK ((exam_capacity > 0))`

<a id="orgroom_facility"></a>
### `org.room_facility`

Features a room has (projector, computers …) with quantity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `room_id` | uuid |  |  |  |
| `room_feature_id` | smallint |  |  |  |
| `quantity` | smallint |  | `1` |  |

**Constraints & indexes**

- PK `room_facility_pkey`: `PRIMARY KEY (room_id, room_feature_id)`
- FK `room_facility_room_feature_id_fkey`: `FOREIGN KEY (room_feature_id) REFERENCES ref.room_feature(id)`
- FK `room_facility_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `room_facility_quantity_check`: `CHECK ((quantity > 0))`

## Schema `people` — People

<a id="peopledesignation"></a>
### `people.designation`

Master list of designations (replaces free-text designation).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `title` | text |  |  |  |
| `employee_category_id` | smallint | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `designation_pkey`: `PRIMARY KEY (id)`
- UNIQUE `designation_code_key`: `UNIQUE (code)`
- UNIQUE `designation_title_key`: `UNIQUE (title)`
- FK `designation_employee_category_id_fkey`: `FOREIGN KEY (employee_category_id) REFERENCES ref.employee_category(id)`

<a id="peopleemployee"></a>
### `people.employee`

Employment record of a person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `employee_code` | citext |  |  | EMPLOYMENT |
| `employee_category_id` | smallint |  |  |  |
| `employment_type_id` | smallint |  |  |  |
| `employment_status_id` | smallint |  |  |  |
| `grade_id` | smallint | yes |  |  |
| `joined_on` | date |  |  |  |
| `separated_on` | date | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `employee_pkey`: `PRIMARY KEY (id)`
- UNIQUE `employee_employee_code_key`: `UNIQUE (employee_code)`
- UNIQUE `employee_person_id_key`: `UNIQUE (person_id)`
- FK `employee_employee_category_id_fkey`: `FOREIGN KEY (employee_category_id) REFERENCES ref.employee_category(id)`
- FK `employee_employment_status_id_fkey`: `FOREIGN KEY (employment_status_id) REFERENCES ref.employment_status(id)`
- FK `employee_employment_type_id_fkey`: `FOREIGN KEY (employment_type_id) REFERENCES ref.employment_type(id)`
- FK `employee_grade_id_fkey`: `FOREIGN KEY (grade_id) REFERENCES ref.grade(id)`
- FK `employee_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- CHECK `employee_check`: `CHECK (((separated_on IS NULL) OR (separated_on >= joined_on)))`
- CHECK `employee_employee_code_check`: `CHECK ((employee_code ~ '^[A-Za-z0-9_-]{3,32}$'::citext))`

<a id="peopleemployee_assignment"></a>
### `people.employee_assignment`

Where and as what an employee works over time; exactly one primary assignment at a time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `employee_id` | uuid |  |  |  |
| `org_unit_id` | uuid |  |  |  |
| `designation_id` | smallint |  |  |  |
| `job_function_id` | smallint | yes |  |  |
| `job_role_id` | smallint | yes |  |  |
| `is_primary` | boolean |  | `false` |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `employee_assignment_pkey`: `PRIMARY KEY (id)`
- FK `employee_assignment_designation_id_fkey`: `FOREIGN KEY (designation_id) REFERENCES people.designation(id)`
- FK `employee_assignment_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id) ON DELETE CASCADE`
- FK `employee_assignment_job_function_id_fkey`: `FOREIGN KEY (job_function_id) REFERENCES ref.job_function(id)`
- FK `employee_assignment_job_role_id_fkey`: `FOREIGN KEY (job_role_id) REFERENCES ref.job_role(id)`
- FK `employee_assignment_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `employee_assignment_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `employee_assignment_no_duplicate`: `EXCLUDE USING gist (employee_id WITH =, org_unit_id WITH =, designation_id WITH =, valid WITH &&)`
- EXCLUDE `employee_assignment_one_primary`: `EXCLUDE USING gist (employee_id WITH =, valid WITH &&) WHERE (is_primary)`
- INDEX `employee_assignment_function_idx`: `btree (job_function_id)`
- INDEX `employee_assignment_role_idx`: `btree (job_role_id)`
- INDEX `employee_assignment_unit_idx`: `btree (org_unit_id)`

<a id="peopleemployee_reporting_line"></a>
### `people.employee_reporting_line`

Reporting manager (line manager) and reviewing manager (appraisal / skip-level) of an employee over time; one active manager of each type; no reporting-chain cycles.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `employee_id` | uuid |  |  |  |
| `manager_employee_id` | uuid |  |  | EMPLOYMENT |
| `reporting_line_type_id` | smallint |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `employee_reporting_line_pkey`: `PRIMARY KEY (id)`
- FK `employee_reporting_line_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id) ON DELETE CASCADE`
- FK `employee_reporting_line_manager_employee_id_fkey`: `FOREIGN KEY (manager_employee_id) REFERENCES people.employee(id)`
- FK `employee_reporting_line_reporting_line_type_id_fkey`: `FOREIGN KEY (reporting_line_type_id) REFERENCES ref.reporting_line_type(id)`
- CHECK `employee_reporting_line_check`: `CHECK ((employee_id <> manager_employee_id))`
- CHECK `employee_reporting_line_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `employee_reporting_line_one_active`: `EXCLUDE USING gist (employee_id WITH =, reporting_line_type_id WITH =, valid WITH &&)`
- INDEX `employee_reporting_line_manager_idx`: `btree (manager_employee_id, reporting_line_type_id)`

<a id="peoplefile_object"></a>
### `people.file_object`

Metadata of stored binaries (photos, notices, consent evidence).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `storage_backend_id` | smallint |  |  |  |
| `object_key` | text |  |  |  |
| `mime_type` | text |  |  |  |
| `byte_size` | bigint |  |  |  |
| `sha256` | bytea |  |  |  |
| `uploaded_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `file_object_pkey`: `PRIMARY KEY (id)`
- UNIQUE `file_object_storage_backend_id_object_key_key`: `UNIQUE (storage_backend_id, object_key)`
- FK `file_object_storage_backend_id_fkey`: `FOREIGN KEY (storage_backend_id) REFERENCES ref.storage_backend(id)`
- CHECK `file_object_byte_size_check`: `CHECK ((byte_size >= 0))`
- CHECK `file_object_mime_type_check`: `CHECK ((mime_type ~ '^[a-z]+/[A-Za-z0-9.+-]+$'::text))`
- CHECK `file_object_sha256_check`: `CHECK ((octet_length(sha256) = 32))`

<a id="peopleperson"></a>
### `people.person`

The single human entity. Employees, students, guardians and nominees are all persons.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `first_name` | text |  |  | IDENTITY |
| `middle_name` | text | yes |  | IDENTITY |
| `last_name` | text | yes |  | IDENTITY |
| `preferred_name` | text | yes |  | IDENTITY |
| `gender_id` | smallint | yes |  | DEMOGRAPHIC |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_pkey`: `PRIMARY KEY (id)`
- FK `person_gender_id_fkey`: `FOREIGN KEY (gender_id) REFERENCES ref.gender(id)`
- CHECK `person_first_name_check`: `CHECK ((btrim(first_name) <> ''::text))`
- INDEX `person_name_idx`: `btree (lower(first_name), lower(last_name))`

<a id="peopleperson_relationship"></a>
### `people.person_relationship`

Family / guardian / emergency-contact links between persons.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `person_id` | uuid |  |  |  |
| `related_person_id` | uuid |  |  | RELATIONSHIP |
| `relationship_type_id` | smallint |  |  |  |
| `is_guardian` | boolean |  | `false` |  |
| `is_emergency_contact` | boolean |  | `false` |  |
| `is_primary_contact` | boolean |  | `false` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_relationship_pkey`: `PRIMARY KEY (person_id, related_person_id, relationship_type_id)`
- FK `person_relationship_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- FK `person_relationship_related_person_id_fkey`: `FOREIGN KEY (related_person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- FK `person_relationship_relationship_type_id_fkey`: `FOREIGN KEY (relationship_type_id) REFERENCES ref.relationship_type(id)`
- CHECK `person_relationship_check`: `CHECK ((person_id <> related_person_id))`
- INDEX `person_relationship_one_primary_uq`: `btree (person_id) WHERE is_primary_contact`
- INDEX `person_relationship_related_idx`: `btree (related_person_id)`

<a id="peoplestudent"></a>
### `people.student`

Student record of a person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `enrollment_no` | citext |  |  | EDUCATION |
| `registration_no` | citext | yes |  | EDUCATION |
| `student_status_id` | smallint |  |  |  |
| `admitted_on` | date |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_pkey`: `PRIMARY KEY (id)`
- UNIQUE `student_enrollment_no_key`: `UNIQUE (enrollment_no)`
- UNIQUE `student_person_id_key`: `UNIQUE (person_id)`
- UNIQUE `student_registration_no_key`: `UNIQUE (registration_no)`
- FK `student_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- FK `student_student_status_id_fkey`: `FOREIGN KEY (student_status_id) REFERENCES ref.student_status(id)`

<a id="peoplestudent_mentor"></a>
### `people.student_mentor`

Faculty mentor of a student over time (one at a time).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_mentor_pkey`: `PRIMARY KEY (id)`
- FK `student_mentor_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `student_mentor_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id) ON DELETE CASCADE`
- CHECK `student_mentor_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `student_mentor_one_current`: `EXCLUDE USING gist (student_id WITH =, valid WITH &&)`
- INDEX `student_mentor_employee_idx`: `btree (employee_id)`

## Schema `academic` — Academic structure, curriculum, timetable & attendance

<a id="academicacademic_body"></a>
### `academic.academic_body`

A statutory / academic body of an org unit (Board of Studies of a department, Academic Council …) with its quorum.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_body_type_id` | smallint |  |  |  |
| `org_unit_id` | uuid |  |  |  |
| `name` | text |  |  |  |
| `quorum` | smallint |  | `1` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `academic_body_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_body_academic_body_type_id_org_unit_id_key`: `UNIQUE (academic_body_type_id, org_unit_id)`
- FK `academic_body_academic_body_type_id_fkey`: `FOREIGN KEY (academic_body_type_id) REFERENCES ref.academic_body_type(id)`
- FK `academic_body_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `academic_body_quorum_check`: `CHECK ((quorum >= 1))`

<a id="academicacademic_body_member"></a>
### `academic.academic_body_member`

Members of an academic body over time: employees or external experts; one chair (an employee) at a time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_body_id` | uuid |  |  |  |
| `committee_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `academic_body_member_pkey`: `PRIMARY KEY (id)`
- FK `academic_body_member_academic_body_id_fkey`: `FOREIGN KEY (academic_body_id) REFERENCES academic.academic_body(id) ON DELETE CASCADE`
- FK `academic_body_member_committee_role_id_fkey`: `FOREIGN KEY (committee_role_id) REFERENCES ref.committee_role(id)`
- FK `academic_body_member_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `academic_body_member_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- CHECK `academic_body_member_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- CHECK `academic_body_member_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- INDEX `academic_body_member_body_idx`: `btree (academic_body_id)`

<a id="academicacademic_term"></a>
### `academic.academic_term`

Concrete term = academic year x term cycle (e.g. 2026-27 ODD); inside its year; no overlap within a calendar type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_year_id` | uuid |  |  |  |
| `term_cycle_id` | smallint |  |  |  |
| `period` | daterange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `academic_term_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_term_academic_year_id_term_cycle_id_key`: `UNIQUE (academic_year_id, term_cycle_id)`
- FK `academic_term_academic_year_id_fkey`: `FOREIGN KEY (academic_year_id) REFERENCES academic.academic_year(id)`
- FK `academic_term_term_cycle_id_fkey`: `FOREIGN KEY (term_cycle_id) REFERENCES ref.term_cycle(id)`
- CHECK `academic_term_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`

<a id="academicacademic_year"></a>
### `academic.academic_year`

Academic years, e.g. 2026-27; periods never overlap.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `period` | daterange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `academic_year_pkey`: `PRIMARY KEY (id)`
- UNIQUE `academic_year_code_key`: `UNIQUE (code)`
- CHECK `academic_year_code_check`: `CHECK ((code ~ '^[0-9]{4}-[0-9]{2}$'::citext))`
- CHECK `academic_year_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`
- EXCLUDE `academic_year_no_overlap`: `EXCLUDE USING gist (period WITH &&)`

<a id="academicattainment_policy"></a>
### `academic.attainment_policy`

CO attainment thresholds: student target % and the % of students for levels 1/2/3; program_id NULL = university default.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid | yes |  |  |
| `student_target_pct` | numeric(5,2) |  |  |  |
| `level1_pct` | numeric(5,2) |  |  |  |
| `level2_pct` | numeric(5,2) |  |  |  |
| `level3_pct` | numeric(5,2) |  |  |  |

**Constraints & indexes**

- PK `attainment_policy_pkey`: `PRIMARY KEY (id)`
- UNIQUE `attainment_policy_program_id_key`: `UNIQUE NULLS NOT DISTINCT (program_id)`
- FK `attainment_policy_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- CHECK `attainment_policy_check`: `CHECK ((((0)::numeric < level1_pct) AND (level1_pct < level2_pct) AND (level2_pct < level3_pct) AND (level3_pct <= (100)::numeric)))`
- CHECK `attainment_policy_student_target_pct_check`: `CHECK (((student_target_pct >= (0)::numeric) AND (student_target_pct <= (100)::numeric)))`

<a id="academicattempt_allowance"></a>
### `academic.attempt_allowance`

Reappear chances per attempt type for a curriculum (e.g. 2 backlog, 1 golden, 1 mercy), on top of max_attempts_per_course.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `curriculum_id` | uuid |  |  |  |
| `exam_attempt_type_id` | smallint |  |  |  |
| `max_attempts` | smallint |  |  |  |

**Constraints & indexes**

- PK `attempt_allowance_pkey`: `PRIMARY KEY (curriculum_id, exam_attempt_type_id)`
- FK `attempt_allowance_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- FK `attempt_allowance_exam_attempt_type_id_fkey`: `FOREIGN KEY (exam_attempt_type_id) REFERENCES ref.exam_attempt_type(id)`
- CHECK `attempt_allowance_max_attempts_check`: `CHECK ((max_attempts >= 0))`

<a id="academicattendance"></a>
### `academic.attendance`

Attendance of a registered student in a held class session (right course; student must be on the roster of the section/group/combined class).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `class_session_id` | uuid |  |  |  |
| `course_registration_id` | uuid |  |  |  |
| `attendance_status_id` | smallint |  |  | EDUCATION |
| `marked_by_employee_id` | uuid | yes |  |  |
| `marked_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `attendance_pkey`: `PRIMARY KEY (class_session_id, course_registration_id)`
- FK `attendance_attendance_status_id_fkey`: `FOREIGN KEY (attendance_status_id) REFERENCES ref.attendance_status(id)`
- FK `attendance_class_session_id_fkey`: `FOREIGN KEY (class_session_id) REFERENCES academic.class_session(id) ON DELETE CASCADE`
- FK `attendance_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`
- FK `attendance_marked_by_employee_id_fkey`: `FOREIGN KEY (marked_by_employee_id) REFERENCES people.employee(id)`
- INDEX `attendance_registration_idx`: `btree (course_registration_id)`

<a id="academicattendance_leave"></a>
### `academic.attendance_leave`

Duty / medical leave for a period, approved through the ATTENDANCE_LEAVE workflow; counts in attendance per its leave type.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `leave_type_id` | smallint |  |  |  |
| `period` | daterange |  |  |  |
| `reason` | text |  |  | HEALTH (sensitive) |
| `document_file_id` | uuid | yes |  |  |
| `instance_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `attendance_leave_pkey`: `PRIMARY KEY (id)`
- UNIQUE `attendance_leave_instance_id_key`: `UNIQUE (instance_id)`
- FK `attendance_leave_document_file_id_fkey`: `FOREIGN KEY (document_file_id) REFERENCES people.file_object(id)`
- FK `attendance_leave_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `attendance_leave_leave_type_id_fkey`: `FOREIGN KEY (leave_type_id) REFERENCES ref.leave_type(id)`
- FK `attendance_leave_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `attendance_leave_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`
- CHECK `attendance_leave_reason_check`: `CHECK ((btrim(reason) <> ''::text))`
- INDEX `attendance_leave_enrollment_idx`: `btree (student_enrollment_id)`

<a id="academicaward_rule"></a>
### `academic.award_rule`

What a curriculum lets a student leave with and when: award, exit term, minimum credits, re-entry window (NEP multiple exit).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `award_type_id` | smallint |  |  |  |
| `award_title` | text |  |  |  |
| `after_term_no` | smallint |  |  |  |
| `min_credits` | numeric(5,1) |  |  |  |
| `reentry_within_years` | smallint | yes |  |  |
| `pathway_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `award_rule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `award_rule_curriculum_id_award_type_id_key`: `UNIQUE (curriculum_id, award_type_id)`
- FK `award_rule_award_type_id_fkey`: `FOREIGN KEY (award_type_id) REFERENCES ref.award_type(id)`
- FK `award_rule_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- FK `award_rule_pathway_id_curriculum_id_fkey`: `FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id)`
- CHECK `award_rule_after_term_no_check`: `CHECK ((after_term_no >= 1))`
- CHECK `award_rule_min_credits_check`: `CHECK ((min_credits > (0)::numeric))`
- CHECK `award_rule_reentry_within_years_check`: `CHECK ((reentry_within_years > 0))`

<a id="academicaward_rule_course"></a>
### `academic.award_rule_course`

Courses that must be completed for an award (e.g. the internship for a UG certificate exit).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `award_rule_id` | uuid |  |  |  |
| `course_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `award_rule_course_pkey`: `PRIMARY KEY (award_rule_id, course_id)`
- FK `award_rule_course_award_rule_id_fkey`: `FOREIGN KEY (award_rule_id) REFERENCES academic.award_rule(id) ON DELETE CASCADE`
- FK `award_rule_course_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`

<a id="academicbatch"></a>
### `academic.batch`

Intake of a programme in an admission year. Batch year and label are derived (academic.v_batch).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `admission_year_id` | uuid |  |  |  |
| `intake_capacity` | integer | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `batch_pkey`: `PRIMARY KEY (id)`
- UNIQUE `batch_program_id_admission_year_id_key`: `UNIQUE (program_id, admission_year_id)`
- FK `batch_admission_year_id_fkey`: `FOREIGN KEY (admission_year_id) REFERENCES academic.academic_year(id)`
- FK `batch_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id)`
- CHECK `batch_intake_capacity_check`: `CHECK ((intake_capacity >= 0))`

<a id="academicbatch_curriculum"></a>
### `academic.batch_curriculum`

Which curriculum version a batch follows (must be its own programme's).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `batch_id` | uuid |  |  |  |
| `curriculum_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `batch_curriculum_pkey`: `PRIMARY KEY (batch_id)`
- FK `batch_curriculum_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id) ON DELETE CASCADE`
- FK `batch_curriculum_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id)`

<a id="academicbatch_document"></a>
### `academic.batch_document`

Documents attached to a batch (approvals, scheme of studies).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `batch_id` | uuid |  |  |  |
| `batch_document_type_id` | smallint |  |  |  |
| `file_object_id` | uuid |  |  |  |
| `title` | text |  |  |  |
| `reference_no` | text | yes |  |  |
| `issued_on` | date | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `batch_document_pkey`: `PRIMARY KEY (id)`
- UNIQUE `batch_document_file_object_id_key`: `UNIQUE (file_object_id)`
- FK `batch_document_batch_document_type_id_fkey`: `FOREIGN KEY (batch_document_type_id) REFERENCES ref.batch_document_type(id)`
- FK `batch_document_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id) ON DELETE CASCADE`
- FK `batch_document_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`

<a id="academicbatch_specialization"></a>
### `academic.batch_specialization`

Specializations offered to a batch and the term from which they apply.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `batch_id` | uuid |  |  |  |
| `specialization_id` | uuid |  |  |  |
| `from_term_no` | smallint |  | `1` |  |

**Constraints & indexes**

- PK `batch_specialization_pkey`: `PRIMARY KEY (batch_id, specialization_id)`
- FK `batch_specialization_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id) ON DELETE CASCADE`
- FK `batch_specialization_specialization_id_fkey`: `FOREIGN KEY (specialization_id) REFERENCES academic.specialization(id)`
- CHECK `batch_specialization_from_term_no_check`: `CHECK ((from_term_no >= 1))`

<a id="academicbody_meeting"></a>
### `academic.body_meeting`

A meeting of an academic body with its number, date and minutes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_body_id` | uuid |  |  |  |
| `meeting_no` | citext |  |  |  |
| `held_on` | date |  |  |  |
| `minutes_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `body_meeting_pkey`: `PRIMARY KEY (id)`
- UNIQUE `body_meeting_academic_body_id_meeting_no_key`: `UNIQUE (academic_body_id, meeting_no)`
- FK `body_meeting_academic_body_id_fkey`: `FOREIGN KEY (academic_body_id) REFERENCES academic.academic_body(id)`
- FK `body_meeting_minutes_file_id_fkey`: `FOREIGN KEY (minutes_file_id) REFERENCES people.file_object(id)`

<a id="academicbody_meeting_attendee"></a>
### `academic.body_meeting_attendee`

Members present at a meeting; each a member of the body on the meeting date.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `body_meeting_id` | uuid |  |  |  |
| `academic_body_member_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `body_meeting_attendee_pkey`: `PRIMARY KEY (body_meeting_id, academic_body_member_id)`
- FK `body_meeting_attendee_academic_body_member_id_fkey`: `FOREIGN KEY (academic_body_member_id) REFERENCES academic.academic_body_member(id)`
- FK `body_meeting_attendee_body_meeting_id_fkey`: `FOREIGN KEY (body_meeting_id) REFERENCES academic.body_meeting(id) ON DELETE CASCADE`

<a id="academicbody_resolution"></a>
### `academic.body_resolution`

A resolution passed at a meeting that had its quorum; referenced by the approvals it authorises (equivalence, MOOC mapping, syllabus, programme transfer).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `body_meeting_id` | uuid |  |  |  |
| `resolution_no` | citext |  |  |  |
| `subject` | text |  |  |  |
| `decision` | text |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `body_resolution_pkey`: `PRIMARY KEY (id)`
- UNIQUE `body_resolution_body_meeting_id_resolution_no_key`: `UNIQUE (body_meeting_id, resolution_no)`
- FK `body_resolution_body_meeting_id_fkey`: `FOREIGN KEY (body_meeting_id) REFERENCES academic.body_meeting(id)`
- CHECK `body_resolution_decision_check`: `CHECK ((btrim(decision) <> ''::text))`
- CHECK `body_resolution_subject_check`: `CHECK ((btrim(subject) <> ''::text))`

<a id="academiccalendar_event"></a>
### `academic.calendar_event`

Academic calendar: holidays, vacations, registration / add-drop windows, exam periods, result dates — per year or term, university-wide or per org unit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_year_id` | uuid |  |  |  |
| `academic_term_id` | uuid | yes |  |  |
| `calendar_event_type_id` | smallint |  |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `name` | text |  |  |  |
| `period` | daterange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `calendar_event_pkey`: `PRIMARY KEY (id)`
- FK `calendar_event_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id) ON DELETE CASCADE`
- FK `calendar_event_academic_year_id_fkey`: `FOREIGN KEY (academic_year_id) REFERENCES academic.academic_year(id) ON DELETE CASCADE`
- FK `calendar_event_calendar_event_type_id_fkey`: `FOREIGN KEY (calendar_event_type_id) REFERENCES ref.calendar_event_type(id)`
- FK `calendar_event_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `calendar_event_name_check`: `CHECK ((btrim(name) <> ''::text))`
- CHECK `calendar_event_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`
- INDEX `calendar_event_period_idx`: `gist (period)`
- INDEX `calendar_event_year_idx`: `btree (academic_year_id)`

<a id="academicclass_group"></a>
### `academic.class_group`

A teaching group inside an offering: a lab/tutorial batch of one section (parent_section_id) or an elective group across batches.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_offering_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `parent_section_id` | uuid | yes |  |  |
| `delivery_component_id` | smallint | yes |  |  |
| `capacity` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `class_group_pkey`: `PRIMARY KEY (id)`
- UNIQUE `class_group_course_offering_id_code_key`: `UNIQUE (course_offering_id, code)`
- FK `class_group_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id) ON DELETE CASCADE`
- FK `class_group_delivery_component_id_fkey`: `FOREIGN KEY (delivery_component_id) REFERENCES ref.delivery_component(id)`
- FK `class_group_parent_section_id_fkey`: `FOREIGN KEY (parent_section_id) REFERENCES academic.section(id)`
- CHECK `class_group_capacity_check`: `CHECK ((capacity > 0))`
- INDEX `class_group_parent_section_idx`: `btree (parent_section_id)`

<a id="academicclass_group_member"></a>
### `academic.class_group_member`

A registered student placed in a class group: same offering, parent section, capacity, one group per component, no timetable clash.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `class_group_id` | uuid |  |  |  |
| `course_registration_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `class_group_member_pkey`: `PRIMARY KEY (class_group_id, course_registration_id)`
- FK `class_group_member_class_group_id_fkey`: `FOREIGN KEY (class_group_id) REFERENCES academic.class_group(id) ON DELETE CASCADE`
- FK `class_group_member_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`
- INDEX `class_group_member_registration_idx`: `btree (course_registration_id)`

<a id="academicclass_session"></a>
### `academic.class_session`

A dated class: from a timetable entry, or an extra class with its own time/room; status and substitute faculty.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `timetable_entry_id` | uuid | yes |  |  |
| `teaching_assignment_id` | uuid | yes |  |  |
| `session_date` | date |  |  |  |
| `start_time` | time without time zone | yes |  |  |
| `end_time` | time without time zone | yes |  |  |
| `room_id` | uuid | yes |  |  |
| `class_session_status_id` | smallint |  |  |  |
| `substitute_employee_id` | uuid | yes |  |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `class_session_pkey`: `PRIMARY KEY (id)`
- UNIQUE `class_session_timetable_entry_id_session_date_key`: `UNIQUE (timetable_entry_id, session_date)`
- FK `class_session_class_session_status_id_fkey`: `FOREIGN KEY (class_session_status_id) REFERENCES ref.class_session_status(id)`
- FK `class_session_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- FK `class_session_substitute_employee_id_fkey`: `FOREIGN KEY (substitute_employee_id) REFERENCES people.employee(id)`
- FK `class_session_teaching_assignment_id_fkey`: `FOREIGN KEY (teaching_assignment_id) REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE`
- FK `class_session_timetable_entry_id_fkey`: `FOREIGN KEY (timetable_entry_id) REFERENCES academic.timetable_entry(id) ON DELETE CASCADE`
- CHECK `class_session_shape`: `CHECK ((((timetable_entry_id IS NOT NULL) AND (teaching_assignment_id IS NULL) AND (start_time IS NULL) AND (end_time IS NULL) AND (room_id IS NULL)) OR ((timetable_entry_id IS NULL) AND (teaching_assignment_id IS NOT NULL) AND (start_time IS NOT NULL) AND (end_time IS NOT NULL) AND (end_time > start_time))))`
- INDEX `class_session_assignment_idx`: `btree (teaching_assignment_id)`

<a id="academicclass_session_topic"></a>
### `academic.class_session_topic`

Topics actually covered in a class session (course file), optionally tied to the lesson plan item delivered.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `class_session_id` | uuid |  |  |  |
| `lesson_plan_item_id` | uuid | yes |  |  |
| `topic` | text |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `class_session_topic_pkey`: `PRIMARY KEY (id)`
- FK `class_session_topic_class_session_id_fkey`: `FOREIGN KEY (class_session_id) REFERENCES academic.class_session(id) ON DELETE CASCADE`
- FK `class_session_topic_lesson_plan_item_id_fkey`: `FOREIGN KEY (lesson_plan_item_id) REFERENCES academic.lesson_plan_item(id) ON DELETE SET NULL`
- CHECK `class_session_topic_topic_check`: `CHECK ((btrim(topic) <> ''::text))`
- INDEX `class_session_topic_session_idx`: `btree (class_session_id)`

<a id="academicco_po_mapping"></a>
### `academic.co_po_mapping`

CO ↔ PO / PSO mapping with strength 1–3; the course must belong to the programme.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_outcome_id` | uuid |  |  |  |
| `program_outcome_id` | uuid |  |  |  |
| `strength` | smallint |  |  |  |

**Constraints & indexes**

- PK `co_po_mapping_pkey`: `PRIMARY KEY (course_outcome_id, program_outcome_id)`
- FK `co_po_mapping_course_outcome_id_fkey`: `FOREIGN KEY (course_outcome_id) REFERENCES academic.course_outcome(id) ON DELETE CASCADE`
- FK `co_po_mapping_program_outcome_id_fkey`: `FOREIGN KEY (program_outcome_id) REFERENCES academic.program_outcome(id) ON DELETE CASCADE`
- CHECK `co_po_mapping_strength_check`: `CHECK (((strength >= 1) AND (strength <= 3)))`

<a id="academiccourse"></a>
### `academic.course`

Course catalogue entry: code, title, credits, owning academic department.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `title` | text |  |  |  |
| `owner_org_unit_id` | uuid |  |  |  |
| `credits` | numeric(4,1) |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `course_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_code_key`: `UNIQUE (code)`
- FK `course_owner_org_unit_id_fkey`: `FOREIGN KEY (owner_org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `course_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{2,32}$'::citext))`
- CHECK `course_credits_check`: `CHECK ((credits >= (0)::numeric))`
- CHECK `course_title_check`: `CHECK ((btrim(title) <> ''::text))`
- INDEX `course_owner_idx`: `btree (owner_org_unit_id)`

<a id="academiccourse_component_hours"></a>
### `academic.course_component_hours`

Weekly contact hours per delivery component (the course's L-T-P).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_id` | uuid |  |  |  |
| `delivery_component_id` | smallint |  |  |  |
| `hours_per_week` | numeric(4,1) |  |  |  |

**Constraints & indexes**

- PK `course_component_hours_pkey`: `PRIMARY KEY (course_id, delivery_component_id)`
- FK `course_component_hours_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- FK `course_component_hours_delivery_component_id_fkey`: `FOREIGN KEY (delivery_component_id) REFERENCES ref.delivery_component(id)`
- CHECK `course_component_hours_hours_per_week_check`: `CHECK ((hours_per_week > (0)::numeric))`

<a id="academiccourse_continuation"></a>
### `academic.course_continuation`

A course that continues an earlier one across terms (Dissertation II ← I); registration needs the earlier part first.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_id` | uuid |  |  |  |
| `continues_course_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `course_continuation_pkey`: `PRIMARY KEY (course_id)`
- FK `course_continuation_continues_course_id_fkey`: `FOREIGN KEY (continues_course_id) REFERENCES academic.course(id)`
- FK `course_continuation_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- CHECK `course_continuation_check`: `CHECK ((course_id <> continues_course_id))`

<a id="academiccourse_equivalence"></a>
### `academic.course_equivalence`

Approved equivalence: passing equivalent_course_id counts as course_id (backlog after a curriculum change, credits before a change).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_id` | uuid |  |  |  |
| `equivalent_course_id` | uuid |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_on` | date |  | `CURRENT_DATE` |  |
| `body_resolution_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `course_equivalence_pkey`: `PRIMARY KEY (course_id, equivalent_course_id)`
- FK `course_equivalence_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `course_equivalence_body_resolution_id_fkey`: `FOREIGN KEY (body_resolution_id) REFERENCES academic.body_resolution(id)`
- FK `course_equivalence_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- FK `course_equivalence_equivalent_course_id_fkey`: `FOREIGN KEY (equivalent_course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- CHECK `course_equivalence_check`: `CHECK ((course_id <> equivalent_course_id))`
- INDEX `course_equivalence_equivalent_idx`: `btree (equivalent_course_id)`

<a id="academiccourse_offering"></a>
### `academic.course_offering`

A course running in a term, taught by an academic department (may differ from the owner); optional intake limit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `offering_org_unit_id` | uuid |  |  |  |
| `intake_limit` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `course_offering_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_offering_course_id_academic_term_id_key`: `UNIQUE (course_id, academic_term_id)`
- FK `course_offering_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `course_offering_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `course_offering_offering_org_unit_id_fkey`: `FOREIGN KEY (offering_org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `course_offering_intake_limit_check`: `CHECK ((intake_limit > 0))`

<a id="academiccourse_outcome"></a>
### `academic.course_outcome`

Course outcome (CO) of a syllabus version, with Bloom's level.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_syllabus_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `statement` | text |  |  |  |
| `bloom_level_id` | smallint | yes |  |  |

**Constraints & indexes**

- PK `course_outcome_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_outcome_course_syllabus_id_code_key`: `UNIQUE (course_syllabus_id, code)`
- FK `course_outcome_bloom_level_id_fkey`: `FOREIGN KEY (bloom_level_id) REFERENCES ref.bloom_level(id)`
- FK `course_outcome_course_syllabus_id_fkey`: `FOREIGN KEY (course_syllabus_id) REFERENCES academic.course_syllabus(id) ON DELETE CASCADE`
- CHECK `course_outcome_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{1,16}$'::citext))`
- CHECK `course_outcome_statement_check`: `CHECK ((btrim(statement) <> ''::text))`

<a id="academiccourse_prerequisite"></a>
### `academic.course_prerequisite`

Course → prerequisite course (acyclic).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_id` | uuid |  |  |  |
| `prerequisite_course_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `course_prerequisite_pkey`: `PRIMARY KEY (course_id, prerequisite_course_id)`
- FK `course_prerequisite_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- FK `course_prerequisite_prerequisite_course_id_fkey`: `FOREIGN KEY (prerequisite_course_id) REFERENCES academic.course(id)`
- CHECK `course_prerequisite_check`: `CHECK ((course_id <> prerequisite_course_id))`

<a id="academiccourse_registration"></a>
### `academic.course_registration`

A student taking a course offering: a curriculum course, an approved equivalent, or a course of the student's minor/honours track. Scheme/category are derived.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `course_offering_id` | uuid |  |  | EDUCATION |
| `registration_status_id` | smallint |  |  |  |
| `registered_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `course_registration_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_registration_student_enrollment_id_course_offering_i_key`: `UNIQUE (student_enrollment_id, course_offering_id)`
- FK `course_registration_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `course_registration_registration_status_id_fkey`: `FOREIGN KEY (registration_status_id) REFERENCES ref.registration_status(id)`
- FK `course_registration_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- INDEX `course_registration_offering_idx`: `btree (course_offering_id)`

<a id="academiccourse_regulator_code"></a>
### `academic.course_regulator_code`

The code a regulator (council) knows a course by — the SOE's council code; unique per regulator.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_id` | uuid |  |  |  |
| `regulatory_body_id` | smallint |  |  |  |
| `code` | citext |  |  |  |

**Constraints & indexes**

- PK `course_regulator_code_pkey`: `PRIMARY KEY (course_id, regulatory_body_id)`
- UNIQUE `course_regulator_code_regulatory_body_id_code_key`: `UNIQUE (regulatory_body_id, code)`
- FK `course_regulator_code_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- FK `course_regulator_code_regulatory_body_id_fkey`: `FOREIGN KEY (regulatory_body_id) REFERENCES ref.regulatory_body(id)`

<a id="academiccourse_room_requirement"></a>
### `academic.course_room_requirement`

Room type or feature a course component needs; enforced on timetable entries together with seat capacity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_id` | uuid |  |  |  |
| `delivery_component_id` | smallint |  |  |  |
| `room_type_id` | smallint | yes |  |  |
| `room_feature_id` | smallint | yes |  |  |

**Constraints & indexes**

- PK `course_room_requirement_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_room_requirement_course_id_delivery_component_id_roo_key`: `UNIQUE NULLS NOT DISTINCT (course_id, delivery_component_id, room_type_id, room_feature_id)`
- FK `course_room_requirement_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- FK `course_room_requirement_delivery_component_id_fkey`: `FOREIGN KEY (delivery_component_id) REFERENCES ref.delivery_component(id)`
- FK `course_room_requirement_room_feature_id_fkey`: `FOREIGN KEY (room_feature_id) REFERENCES ref.room_feature(id)`
- FK `course_room_requirement_room_type_id_fkey`: `FOREIGN KEY (room_type_id) REFERENCES ref.room_type(id)`
- CHECK `course_room_requirement_check`: `CHECK ((num_nonnulls(room_type_id, room_feature_id) = 1))`

<a id="academiccourse_syllabus"></a>
### `academic.course_syllabus`

Versioned syllabus of a course (one current at a time), approved by the Board of Studies.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_id` | uuid |  |  |  |
| `version` | citext |  |  |  |
| `approved_by_employee_id` | uuid | yes |  |  |
| `approved_on` | date | yes |  |  |
| `body_resolution_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `course_syllabus_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_syllabus_course_id_version_key`: `UNIQUE (course_id, version)`
- FK `course_syllabus_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `course_syllabus_body_resolution_id_fkey`: `FOREIGN KEY (body_resolution_id) REFERENCES academic.body_resolution(id)`
- FK `course_syllabus_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id) ON DELETE CASCADE`
- CHECK `course_syllabus_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `course_syllabus_one_current`: `EXCLUDE USING gist (course_id WITH =, valid WITH &&)`

<a id="academiccredit_load_rule"></a>
### `academic.credit_load_rule`

Minimum / maximum credits per term of a curriculum (term_no NULL = default); the maximum is enforced on registration.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `term_no` | smallint | yes |  |  |
| `min_credits` | numeric(5,1) | yes |  |  |
| `max_credits` | numeric(5,1) | yes |  |  |

**Constraints & indexes**

- PK `credit_load_rule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `credit_load_rule_curriculum_id_term_no_key`: `UNIQUE NULLS NOT DISTINCT (curriculum_id, term_no)`
- FK `credit_load_rule_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- CHECK `credit_load_rule_check`: `CHECK ((num_nonnulls(min_credits, max_credits) >= 1))`
- CHECK `credit_load_rule_check1`: `CHECK (((min_credits IS NULL) OR (max_credits IS NULL) OR (min_credits <= max_credits)))`
- CHECK `credit_load_rule_max_credits_check`: `CHECK ((max_credits > (0)::numeric))`
- CHECK `credit_load_rule_min_credits_check`: `CHECK ((min_credits >= (0)::numeric))`
- CHECK `credit_load_rule_term_no_check`: `CHECK ((term_no >= 1))`

<a id="academiccredit_overload_approval"></a>
### `academic.credit_overload_approval`

An approved credit overload for one student in one term.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `student_enrollment_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `max_credits` | numeric(5,1) |  |  |  |
| `reason` | text |  |  | EDUCATION |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `credit_overload_approval_pkey`: `PRIMARY KEY (student_enrollment_id, academic_term_id)`
- FK `credit_overload_approval_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `credit_overload_approval_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `credit_overload_approval_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `credit_overload_approval_max_credits_check`: `CHECK ((max_credits > (0)::numeric))`
- CHECK `credit_overload_approval_reason_check`: `CHECK ((btrim(reason) <> ''::text))`

<a id="academiccredit_transfer"></a>
### `academic.credit_transfer`

External credits a student transfers in (ABC / MOOC / other university); on acceptance mapping, curriculum fit and the transfer cap are enforced.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `external_course_id` | uuid |  |  |  |
| `completed_on` | date |  |  |  |
| `grade_point` | numeric(4,2) | yes |  | EDUCATION |
| `abc_reference` | citext | yes |  | EDUCATION |
| `certificate_file_id` | uuid | yes |  |  |
| `credit_transfer_status_id` | smallint |  |  |  |
| `decided_by_employee_id` | uuid | yes |  |  |
| `decided_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `credit_transfer_pkey`: `PRIMARY KEY (id)`
- UNIQUE `credit_transfer_abc_reference_key`: `UNIQUE (abc_reference)`
- UNIQUE `credit_transfer_certificate_file_id_key`: `UNIQUE (certificate_file_id)`
- UNIQUE `credit_transfer_student_enrollment_id_external_course_id_key`: `UNIQUE (student_enrollment_id, external_course_id)`
- FK `credit_transfer_certificate_file_id_fkey`: `FOREIGN KEY (certificate_file_id) REFERENCES people.file_object(id)`
- FK `credit_transfer_credit_transfer_status_id_fkey`: `FOREIGN KEY (credit_transfer_status_id) REFERENCES ref.credit_transfer_status(id)`
- FK `credit_transfer_decided_by_employee_id_fkey`: `FOREIGN KEY (decided_by_employee_id) REFERENCES people.employee(id)`
- FK `credit_transfer_external_course_id_fkey`: `FOREIGN KEY (external_course_id) REFERENCES academic.external_course(id)`
- FK `credit_transfer_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `credit_transfer_check`: `CHECK (((decided_at IS NULL) = (decided_by_employee_id IS NULL)))`
- CHECK `credit_transfer_grade_point_check`: `CHECK ((grade_point >= (0)::numeric))`

<a id="academiccurriculum"></a>
### `academic.curriculum`

Versioned scheme of studies for a programme, with its grade scale, attendance threshold and cap on transferred credits.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `grade_scale_id` | smallint |  |  |  |
| `attendance_threshold_pct` | numeric(5,2) |  |  |  |
| `max_transfer_credit_pct` | numeric(5,2) | yes |  |  |
| `max_duration_years` | numeric(3,1) | yes |  |  |
| `max_attempts_per_course` | smallint | yes |  |  |
| `allows_internal_marks_revision` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `curriculum_pkey`: `PRIMARY KEY (id)`
- UNIQUE `curriculum_program_id_code_key`: `UNIQUE (program_id, code)`
- FK `curriculum_grade_scale_id_fkey`: `FOREIGN KEY (grade_scale_id) REFERENCES academic.grade_scale(id)`
- FK `curriculum_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id)`
- CHECK `curriculum_attendance_threshold_pct_check`: `CHECK (((attendance_threshold_pct >= (0)::numeric) AND (attendance_threshold_pct <= (100)::numeric)))`
- CHECK `curriculum_max_attempts_per_course_check`: `CHECK ((max_attempts_per_course > 0))`
- CHECK `curriculum_max_duration_years_check`: `CHECK ((max_duration_years > (0)::numeric))`
- CHECK `curriculum_max_transfer_credit_pct_check`: `CHECK (((max_transfer_credit_pct >= (0)::numeric) AND (max_transfer_credit_pct <= (100)::numeric)))`

<a id="academiccurriculum_approval"></a>
### `academic.curriculum_approval`

Links a curriculum version (the SOE) to each of its approval rounds; its status is derived from the latest round.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `instance_id` | uuid |  |  |  |
| `curriculum_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `curriculum_approval_pkey`: `PRIMARY KEY (instance_id)`
- FK `curriculum_approval_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id)`
- FK `curriculum_approval_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- INDEX `curriculum_approval_curriculum_idx`: `btree (curriculum_id)`

<a id="academiccurriculum_course"></a>
### `academic.curriculum_course`

A fixed course in a given term of a curriculum, with its category and scheme of examination.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `term_no` | smallint |  |  |  |
| `course_id` | uuid |  |  |  |
| `course_category_id` | smallint |  |  |  |
| `evaluation_scheme_id` | integer |  |  |  |
| `specialization_id` | uuid | yes |  |  |
| `pathway_id` | uuid | yes |  |  |
| `result_group_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `curriculum_course_pkey`: `PRIMARY KEY (id)`
- FK `curriculum_course_course_category_id_fkey`: `FOREIGN KEY (course_category_id) REFERENCES ref.course_category(id)`
- FK `curriculum_course_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `curriculum_course_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- FK `curriculum_course_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id)`
- FK `curriculum_course_pathway_id_curriculum_id_fkey`: `FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id)`
- FK `curriculum_course_result_group_id_curriculum_id_fkey`: `FOREIGN KEY (result_group_id, curriculum_id) REFERENCES academic.result_group(id, curriculum_id)`
- FK `curriculum_course_specialization_id_fkey`: `FOREIGN KEY (specialization_id) REFERENCES academic.specialization(id)`
- CHECK `curriculum_course_term_no_check`: `CHECK ((term_no >= 1))`

<a id="academiccurriculum_pathway"></a>
### `academic.curriculum_pathway`

An alternative course set inside a curriculum chosen from a term on (Honours vs Honours with Research).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `from_term_no` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `curriculum_pathway_pkey`: `PRIMARY KEY (id)`
- UNIQUE `curriculum_pathway_curriculum_id_code_key`: `UNIQUE (curriculum_id, code)`
- UNIQUE `curriculum_pathway_id_curriculum_id_key`: `UNIQUE (id, curriculum_id)`
- FK `curriculum_pathway_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- CHECK `curriculum_pathway_from_term_no_check`: `CHECK ((from_term_no >= 1))`

<a id="academicdisciplinary_case"></a>
### `academic.disciplinary_case`

A student misconduct case outside exams: report, committee hearing, decision and penalty; a suspension links its study break; closed cases are final.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_id` | uuid |  |  |  |
| `misconduct_type_id` | smallint |  |  |  |
| `occurred_on` | date |  |  |  |
| `reported_on` | date |  | `CURRENT_DATE` |  |
| `reported_by_employee_id` | uuid |  |  |  |
| `description` | text |  |  | DISCIPLINARY (sensitive) |
| `academic_body_id` | uuid | yes |  |  |
| `disciplinary_status_id` | smallint |  |  |  |
| `decided_on` | date | yes |  |  |
| `decision` | text | yes |  | DISCIPLINARY (sensitive) |
| `disciplinary_penalty_id` | smallint | yes |  |  |
| `study_break_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `disciplinary_case_pkey`: `PRIMARY KEY (id)`
- UNIQUE `disciplinary_case_study_break_id_key`: `UNIQUE (study_break_id)`
- FK `disciplinary_case_academic_body_id_fkey`: `FOREIGN KEY (academic_body_id) REFERENCES academic.academic_body(id)`
- FK `disciplinary_case_disciplinary_penalty_id_fkey`: `FOREIGN KEY (disciplinary_penalty_id) REFERENCES ref.disciplinary_penalty(id)`
- FK `disciplinary_case_disciplinary_status_id_fkey`: `FOREIGN KEY (disciplinary_status_id) REFERENCES ref.disciplinary_status(id)`
- FK `disciplinary_case_misconduct_type_id_fkey`: `FOREIGN KEY (misconduct_type_id) REFERENCES ref.misconduct_type(id)`
- FK `disciplinary_case_reported_by_employee_id_fkey`: `FOREIGN KEY (reported_by_employee_id) REFERENCES people.employee(id)`
- FK `disciplinary_case_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id) ON DELETE CASCADE`
- FK `disciplinary_case_study_break_id_fkey`: `FOREIGN KEY (study_break_id) REFERENCES academic.study_break(id)`
- CHECK `disciplinary_case_check`: `CHECK ((reported_on >= occurred_on))`
- CHECK `disciplinary_case_check1`: `CHECK (((decided_on IS NULL) OR (decided_on >= reported_on)))`
- CHECK `disciplinary_case_description_check`: `CHECK ((btrim(description) <> ''::text))`
- INDEX `disciplinary_case_student_idx`: `btree (student_id)`

<a id="academicdivision_band"></a>
### `academic.division_band`

Division / class (first class with distinction …) by CGPA range on a grade scale; read by exam.v_division.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `grade_scale_id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `cgpa_range` | numrange |  |  |  |

**Constraints & indexes**

- PK `division_band_pkey`: `PRIMARY KEY (id)`
- UNIQUE `division_band_grade_scale_id_code_key`: `UNIQUE (grade_scale_id, code)`
- FK `division_band_grade_scale_id_fkey`: `FOREIGN KEY (grade_scale_id) REFERENCES academic.grade_scale(id) ON DELETE CASCADE`
- CHECK `division_band_cgpa_range_check`: `CHECK (((NOT isempty(cgpa_range)) AND (lower(cgpa_range) >= (0)::numeric)))`
- EXCLUDE `division_band_no_overlap`: `EXCLUDE USING gist (grade_scale_id WITH =, cgpa_range WITH &&)`

<a id="academicelective_basket"></a>
### `academic.elective_basket`

An elective slot in a curriculum term: choose N courses from the basket.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `term_no` | smallint |  |  |  |
| `course_category_id` | smallint |  |  |  |
| `courses_to_choose` | smallint |  |  |  |
| `specialization_id` | uuid | yes |  |  |
| `pathway_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `elective_basket_pkey`: `PRIMARY KEY (id)`
- UNIQUE `elective_basket_curriculum_id_code_key`: `UNIQUE (curriculum_id, code)`
- FK `elective_basket_course_category_id_fkey`: `FOREIGN KEY (course_category_id) REFERENCES ref.course_category(id)`
- FK `elective_basket_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- FK `elective_basket_pathway_id_curriculum_id_fkey`: `FOREIGN KEY (pathway_id, curriculum_id) REFERENCES academic.curriculum_pathway(id, curriculum_id)`
- FK `elective_basket_specialization_id_fkey`: `FOREIGN KEY (specialization_id) REFERENCES academic.specialization(id)`
- CHECK `elective_basket_courses_to_choose_check`: `CHECK ((courses_to_choose >= 1))`
- CHECK `elective_basket_term_no_check`: `CHECK ((term_no >= 1))`

<a id="academicelective_basket_course"></a>
### `academic.elective_basket_course`

A course offered in an elective basket, with its scheme of examination.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `elective_basket_id` | uuid |  |  |  |
| `course_id` | uuid |  |  |  |
| `evaluation_scheme_id` | integer |  |  |  |

**Constraints & indexes**

- PK `elective_basket_course_pkey`: `PRIMARY KEY (elective_basket_id, course_id)`
- FK `elective_basket_course_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `elective_basket_course_elective_basket_id_fkey`: `FOREIGN KEY (elective_basket_id) REFERENCES academic.elective_basket(id) ON DELETE CASCADE`
- FK `elective_basket_course_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id)`

<a id="academicelective_preference"></a>
### `academic.elective_preference`

A student's ranked elective choices in a basket for a term; allotted in merit order by academic.allot_electives().

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `elective_basket_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `course_id` | uuid |  |  | EDUCATION |
| `priority` | smallint |  |  |  |
| `submitted_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `elective_preference_pkey`: `PRIMARY KEY (id)`
- UNIQUE `elective_preference_student_enrollment_id_elective_basket__key1`: `UNIQUE (student_enrollment_id, elective_basket_id, academic_term_id, course_id)`
- UNIQUE `elective_preference_student_enrollment_id_elective_basket_i_key`: `UNIQUE (student_enrollment_id, elective_basket_id, academic_term_id, priority)`
- FK `elective_preference_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `elective_preference_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `elective_preference_elective_basket_id_fkey`: `FOREIGN KEY (elective_basket_id) REFERENCES academic.elective_basket(id) ON DELETE CASCADE`
- FK `elective_preference_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `elective_preference_priority_check`: `CHECK ((priority >= 1))`

<a id="academicenrollment_reentry"></a>
### `academic.enrollment_reentry`

A new enrollment resuming the same programme after an exit, within the award's re-entry window; earlier credits carry forward.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `student_enrollment_id` | uuid |  |  |  |
| `student_award_id` | uuid |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `enrollment_reentry_pkey`: `PRIMARY KEY (student_enrollment_id)`
- UNIQUE `enrollment_reentry_student_award_id_key`: `UNIQUE (student_award_id)`
- FK `enrollment_reentry_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `enrollment_reentry_student_award_id_fkey`: `FOREIGN KEY (student_award_id) REFERENCES academic.student_award(id)`
- FK `enrollment_reentry_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`

<a id="academicevaluation_component"></a>
### `academic.evaluation_component`

One component of a scheme: assessment type, weightage, maximum and optional pass marks, optional best-of group. Weights total 100% (checked at commit).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `evaluation_scheme_id` | integer |  |  |  |
| `assessment_type_id` | smallint |  |  |  |
| `name` | text |  |  |  |
| `weight_pct` | numeric(5,2) |  |  |  |
| `max_marks` | numeric(6,2) |  |  |  |
| `min_pass_marks` | numeric(6,2) | yes |  |  |
| `component_group_id` | integer | yes |  |  |

**Constraints & indexes**

- PK `evaluation_component_pkey`: `PRIMARY KEY (id)`
- UNIQUE `evaluation_component_evaluation_scheme_id_name_key`: `UNIQUE (evaluation_scheme_id, name)`
- FK `evaluation_component_assessment_type_id_fkey`: `FOREIGN KEY (assessment_type_id) REFERENCES ref.assessment_type(id)`
- FK `evaluation_component_component_group_id_evaluation_scheme__fkey`: `FOREIGN KEY (component_group_id, evaluation_scheme_id) REFERENCES academic.evaluation_component_group(id, evaluation_scheme_id) ON DELETE CASCADE`
- FK `evaluation_component_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE`
- CHECK `evaluation_component_check`: `CHECK (((min_pass_marks IS NULL) OR (min_pass_marks <= max_marks)))`
- CHECK `evaluation_component_max_marks_check`: `CHECK ((max_marks > (0)::numeric))`
- CHECK `evaluation_component_min_pass_marks_check`: `CHECK ((min_pass_marks >= (0)::numeric))`
- CHECK `evaluation_component_weight_pct_check`: `CHECK (((weight_pct > (0)::numeric) AND (weight_pct <= (100)::numeric)))`
- CONSTRAINT TRIGGER `trg_evaluation_scheme_weights`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`
- INDEX `evaluation_component_group_idx`: `btree (component_group_id)`

<a id="academicevaluation_component_group"></a>
### `academic.evaluation_component_group`

"Best N of M" group of equally weighted components (e.g. best 2 of 3 class tests); only the best best_of count.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `evaluation_scheme_id` | integer |  |  |  |
| `name` | text |  |  |  |
| `best_of` | smallint |  |  |  |

**Constraints & indexes**

- PK `evaluation_component_group_pkey`: `PRIMARY KEY (id)`
- UNIQUE `evaluation_component_group_evaluation_scheme_id_name_key`: `UNIQUE (evaluation_scheme_id, name)`
- UNIQUE `evaluation_component_group_id_evaluation_scheme_id_key`: `UNIQUE (id, evaluation_scheme_id)`
- FK `evaluation_component_group_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE`
- CHECK `evaluation_component_group_best_of_check`: `CHECK ((best_of >= 1))`
- CONSTRAINT TRIGGER `trg_evaluation_group_weights`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`

<a id="academicevaluation_component_outcome"></a>
### `academic.evaluation_component_outcome`

Course outcomes assessed by an internal / directly marked component; script-marked exams map outcomes per question instead.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `evaluation_component_id` | integer |  |  |  |
| `course_outcome_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `evaluation_component_outcome_pkey`: `PRIMARY KEY (evaluation_component_id, course_outcome_id)`
- FK `evaluation_component_outcome_course_outcome_id_fkey`: `FOREIGN KEY (course_outcome_id) REFERENCES academic.course_outcome(id) ON DELETE CASCADE`
- FK `evaluation_component_outcome_evaluation_component_id_fkey`: `FOREIGN KEY (evaluation_component_id) REFERENCES academic.evaluation_component(id) ON DELETE CASCADE`

<a id="academicevaluation_part_rule"></a>
### `academic.evaluation_part_rule`

Minimum pass percentage for one part (internal / external) of a scheme, on top of the aggregate pass mark.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `evaluation_scheme_id` | integer |  |  |  |
| `evaluation_part_id` | smallint |  |  |  |
| `min_pass_pct` | numeric(5,2) |  |  |  |

**Constraints & indexes**

- PK `evaluation_part_rule_pkey`: `PRIMARY KEY (evaluation_scheme_id, evaluation_part_id)`
- FK `evaluation_part_rule_evaluation_part_id_fkey`: `FOREIGN KEY (evaluation_part_id) REFERENCES ref.evaluation_part(id)`
- FK `evaluation_part_rule_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id) ON DELETE CASCADE`
- CHECK `evaluation_part_rule_min_pass_pct_check`: `CHECK (((min_pass_pct >= (0)::numeric) AND (min_pass_pct <= (100)::numeric)))`

<a id="academicevaluation_scheme"></a>
### `academic.evaluation_scheme`

A reusable scheme of examination and its result rules as data: aggregate pass mark, internal-lead cap, rounding.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `min_aggregate_pct` | numeric(5,2) |  |  |  |
| `max_internal_lead_pct` | numeric(5,2) | yes |  |  |
| `round_to_step` | numeric(4,2) | yes |  |  |
| `round_up` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `evaluation_scheme_pkey`: `PRIMARY KEY (id)`
- UNIQUE `evaluation_scheme_code_key`: `UNIQUE (code)`
- CHECK `evaluation_scheme_check`: `CHECK (((NOT round_up) OR (round_to_step IS NOT NULL)))`
- CHECK `evaluation_scheme_max_internal_lead_pct_check`: `CHECK (((max_internal_lead_pct >= (0)::numeric) AND (max_internal_lead_pct <= (100)::numeric)))`
- CHECK `evaluation_scheme_min_aggregate_pct_check`: `CHECK (((min_aggregate_pct >= (0)::numeric) AND (min_aggregate_pct <= (100)::numeric)))`
- CHECK `evaluation_scheme_round_to_step_check`: `CHECK ((round_to_step > (0)::numeric))`

<a id="academicexternal_course"></a>
### `academic.external_course`

A course at an external provider, with its credits.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `external_provider_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `title` | text |  |  |  |
| `credits` | numeric(4,1) |  |  |  |
| `duration_weeks` | smallint | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `external_course_pkey`: `PRIMARY KEY (id)`
- UNIQUE `external_course_external_provider_id_code_key`: `UNIQUE (external_provider_id, code)`
- FK `external_course_external_provider_id_fkey`: `FOREIGN KEY (external_provider_id) REFERENCES academic.external_provider(id)`
- CHECK `external_course_credits_check`: `CHECK ((credits > (0)::numeric))`
- CHECK `external_course_duration_weeks_check`: `CHECK ((duration_weeks > 0))`

<a id="academicexternal_course_mapping"></a>
### `academic.external_course_mapping`

How an external course counts here for a period: as an internal course or as credits in a category (Board of Studies approval).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `external_course_id` | uuid |  |  |  |
| `course_id` | uuid | yes |  |  |
| `course_category_id` | smallint | yes |  |  |
| `valid` | daterange |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `body_resolution_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `external_course_mapping_pkey`: `PRIMARY KEY (id)`
- FK `external_course_mapping_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `external_course_mapping_body_resolution_id_fkey`: `FOREIGN KEY (body_resolution_id) REFERENCES academic.body_resolution(id)`
- FK `external_course_mapping_course_category_id_fkey`: `FOREIGN KEY (course_category_id) REFERENCES ref.course_category(id)`
- FK `external_course_mapping_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `external_course_mapping_external_course_id_fkey`: `FOREIGN KEY (external_course_id) REFERENCES academic.external_course(id) ON DELETE CASCADE`
- CHECK `external_course_mapping_check`: `CHECK ((num_nonnulls(course_id, course_category_id) = 1))`
- CHECK `external_course_mapping_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `external_course_mapping_one_at_a_time`: `EXCLUDE USING gist (external_course_id WITH =, valid WITH &&)`

<a id="academicexternal_provider"></a>
### `academic.external_provider`

A source of external credits: another university, a MOOC platform (SWAYAM, NPTEL), an industry body.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `external_provider_type_id` | smallint |  |  |  |
| `country_id` | smallint | yes |  |  |
| `aishe_code` | citext | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `external_provider_pkey`: `PRIMARY KEY (id)`
- UNIQUE `external_provider_aishe_code_key`: `UNIQUE (aishe_code)`
- UNIQUE `external_provider_code_key`: `UNIQUE (code)`
- FK `external_provider_country_id_fkey`: `FOREIGN KEY (country_id) REFERENCES ref.country(id)`
- FK `external_provider_external_provider_type_id_fkey`: `FOREIGN KEY (external_provider_type_id) REFERENCES ref.external_provider_type(id)`

<a id="academicfaculty_course_preference"></a>
### `academic.faculty_course_preference`

A teaching employee's ranked course preferences for a term (allocation input).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `academic_term_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `course_id` | uuid |  |  |  |
| `preference_rank` | smallint |  |  |  |
| `remarks` | text | yes |  | EMPLOYMENT |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `faculty_course_preference_pkey`: `PRIMARY KEY (academic_term_id, employee_id, course_id)`
- UNIQUE `faculty_course_preference_academic_term_id_employee_id_pref_key`: `UNIQUE (academic_term_id, employee_id, preference_rank)`
- FK `faculty_course_preference_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `faculty_course_preference_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `faculty_course_preference_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id) ON DELETE CASCADE`
- CHECK `faculty_course_preference_preference_rank_check`: `CHECK (((preference_rank >= 1) AND (preference_rank <= 20)))`

<a id="academicfaculty_unavailability"></a>
### `academic.faculty_unavailability`

Weekly periods a faculty member cannot be timetabled (solver input, enforced on entries).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `employee_id` | uuid |  |  |  |
| `day_of_week` | smallint |  |  |  |
| `start_time` | time without time zone |  |  |  |
| `end_time` | time without time zone |  |  |  |
| `valid` | daterange |  |  |  |
| `reason` | text | yes |  | HEALTH (sensitive) |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `faculty_unavailability_pkey`: `PRIMARY KEY (id)`
- FK `faculty_unavailability_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id) ON DELETE CASCADE`
- CHECK `faculty_unavailability_check`: `CHECK ((end_time > start_time))`
- CHECK `faculty_unavailability_day_of_week_check`: `CHECK (((day_of_week >= 1) AND (day_of_week <= 7)))`
- CHECK `faculty_unavailability_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- INDEX `faculty_unavailability_employee_idx`: `btree (employee_id)`

<a id="academicfeedback_cycle"></a>
### `academic.feedback_cycle`

A feedback round: questionnaire, term, submission window.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_term_id` | uuid |  |  |  |
| `feedback_questionnaire_id` | smallint |  |  |  |
| `name` | text |  |  |  |
| `submission_window` | tstzrange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `feedback_cycle_pkey`: `PRIMARY KEY (id)`
- UNIQUE `feedback_cycle_academic_term_id_name_key`: `UNIQUE (academic_term_id, name)`
- FK `feedback_cycle_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `feedback_cycle_feedback_questionnaire_id_fkey`: `FOREIGN KEY (feedback_questionnaire_id) REFERENCES academic.feedback_questionnaire(id)`
- CHECK `feedback_cycle_submission_window_check`: `CHECK (((NOT isempty(submission_window)) AND (NOT lower_inf(submission_window)) AND (NOT upper_inf(submission_window))))`

<a id="academicfeedback_question"></a>
### `academic.feedback_question`

A question of a questionnaire: rating (1..max) or free text.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `feedback_questionnaire_id` | smallint |  |  |  |
| `seq` | smallint |  |  |  |
| `question` | text |  |  |  |
| `is_free_text` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `feedback_question_pkey`: `PRIMARY KEY (id)`
- UNIQUE `feedback_question_feedback_questionnaire_id_seq_key`: `UNIQUE (feedback_questionnaire_id, seq)`
- FK `feedback_question_feedback_questionnaire_id_fkey`: `FOREIGN KEY (feedback_questionnaire_id) REFERENCES academic.feedback_questionnaire(id) ON DELETE CASCADE`
- CHECK `feedback_question_question_check`: `CHECK ((btrim(question) <> ''::text))`
- CHECK `feedback_question_seq_check`: `CHECK ((seq >= 1))`

<a id="academicfeedback_questionnaire"></a>
### `academic.feedback_questionnaire`

A reusable student-feedback questionnaire with its rating scale.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `max_rating` | smallint |  | `5` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `feedback_questionnaire_pkey`: `PRIMARY KEY (id)`
- UNIQUE `feedback_questionnaire_code_key`: `UNIQUE (code)`
- CHECK `feedback_questionnaire_max_rating_check`: `CHECK (((max_rating >= 2) AND (max_rating <= 10)))`

<a id="academicfeedback_response"></a>
### `academic.feedback_response`

One answer per cycle × teaching assignment × question — no student column (anonymous by construction).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `feedback_cycle_id` | uuid |  |  |  |
| `teaching_assignment_id` | uuid |  |  |  |
| `feedback_question_id` | integer |  |  |  |
| `rating` | smallint | yes |  |  |
| `comment` | text | yes |  | EMPLOYMENT |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `feedback_response_pkey`: `PRIMARY KEY (id)`
- FK `feedback_response_feedback_cycle_id_fkey`: `FOREIGN KEY (feedback_cycle_id) REFERENCES academic.feedback_cycle(id) ON DELETE CASCADE`
- FK `feedback_response_feedback_question_id_fkey`: `FOREIGN KEY (feedback_question_id) REFERENCES academic.feedback_question(id)`
- FK `feedback_response_teaching_assignment_id_fkey`: `FOREIGN KEY (teaching_assignment_id) REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE`
- CHECK `feedback_response_check`: `CHECK ((num_nonnulls(rating, comment) = 1))`
- CHECK `feedback_response_rating_check`: `CHECK ((rating >= 1))`
- INDEX `feedback_response_ta_idx`: `btree (feedback_cycle_id, teaching_assignment_id)`

<a id="academicfeedback_submission"></a>
### `academic.feedback_submission`

Proof that a course registration submitted feedback in a cycle (one each) — the only student link, never joined to responses.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `feedback_cycle_id` | uuid |  |  |  |
| `course_registration_id` | uuid |  |  | EDUCATION |
| `submitted_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `feedback_submission_pkey`: `PRIMARY KEY (feedback_cycle_id, course_registration_id)`
- FK `feedback_submission_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`
- FK `feedback_submission_feedback_cycle_id_fkey`: `FOREIGN KEY (feedback_cycle_id) REFERENCES academic.feedback_cycle(id) ON DELETE CASCADE`

<a id="academicgrade_band"></a>
### `academic.grade_band`

Percentage range → grade letter + grade point + pass/fail; bands of a scale never overlap.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `grade_scale_id` | smallint |  |  |  |
| `grade_letter` | citext |  |  |  |
| `pct_range` | numrange |  |  |  |
| `grade_point` | numeric(4,2) |  |  |  |
| `is_pass` | boolean |  |  |  |

**Constraints & indexes**

- PK `grade_band_pkey`: `PRIMARY KEY (id)`
- UNIQUE `grade_band_grade_scale_id_grade_letter_key`: `UNIQUE (grade_scale_id, grade_letter)`
- FK `grade_band_grade_scale_id_fkey`: `FOREIGN KEY (grade_scale_id) REFERENCES academic.grade_scale(id) ON DELETE CASCADE`
- CHECK `grade_band_grade_point_check`: `CHECK ((grade_point >= (0)::numeric))`
- CHECK `grade_band_pct_range_check`: `CHECK (((NOT isempty(pct_range)) AND (lower(pct_range) >= (0)::numeric) AND (upper(pct_range) <= (100)::numeric)))`
- EXCLUDE `grade_band_no_overlap`: `EXCLUDE USING gist (grade_scale_id WITH =, pct_range WITH &&)`

<a id="academicgrade_scale"></a>
### `academic.grade_scale`

A grading policy (e.g. UGC 10-point). New policy = new scale; bands used by published results are frozen.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `max_grade_point` | numeric(4,2) |  |  |  |
| `pct_conversion_factor` | numeric(5,2) | yes |  |  |
| `is_relative` | boolean |  | `false` |  |
| `relative_min_cohort` | smallint | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `grade_scale_pkey`: `PRIMARY KEY (id)`
- UNIQUE `grade_scale_code_key`: `UNIQUE (code)`
- CHECK `grade_scale_check`: `CHECK (((NOT is_relative) OR (relative_min_cohort IS NOT NULL)))`
- CHECK `grade_scale_max_grade_point_check`: `CHECK ((max_grade_point > (0)::numeric))`
- CHECK `grade_scale_pct_conversion_factor_check`: `CHECK ((pct_conversion_factor > (0)::numeric))`
- CHECK `grade_scale_relative_min_cohort_check`: `CHECK ((relative_min_cohort > 1))`

<a id="academicinternship"></a>
### `academic.internship`

Placement details of an internship: organisation, city, period, industry mentor, offer letter, certificate.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `supervised_work_id` | uuid |  |  |  |
| `organisation_name` | text |  |  |  |
| `city_id` | integer | yes |  |  |
| `period` | daterange |  |  |  |
| `industry_mentor_person_id` | uuid | yes |  |  |
| `offer_letter_file_id` | uuid | yes |  |  |
| `completion_certificate_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `internship_pkey`: `PRIMARY KEY (supervised_work_id)`
- FK `internship_city_id_fkey`: `FOREIGN KEY (city_id) REFERENCES ref.city(id)`
- FK `internship_completion_certificate_file_id_fkey`: `FOREIGN KEY (completion_certificate_file_id) REFERENCES people.file_object(id)`
- FK `internship_industry_mentor_person_id_fkey`: `FOREIGN KEY (industry_mentor_person_id) REFERENCES people.person(id)`
- FK `internship_offer_letter_file_id_fkey`: `FOREIGN KEY (offer_letter_file_id) REFERENCES people.file_object(id)`
- FK `internship_supervised_work_id_fkey`: `FOREIGN KEY (supervised_work_id) REFERENCES academic.supervised_work(id) ON DELETE CASCADE`
- CHECK `internship_organisation_name_check`: `CHECK ((btrim(organisation_name) <> ''::text))`
- CHECK `internship_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`

<a id="academiclesson_plan_item"></a>
### `academic.lesson_plan_item`

Lesson plan of a teaching assignment: ordered topics tied to syllabus units, with planned hours.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `teaching_assignment_id` | uuid |  |  |  |
| `seq` | smallint |  |  |  |
| `syllabus_unit_id` | uuid | yes |  |  |
| `topic` | text |  |  |  |
| `planned_hours` | numeric(4,1) |  | `1` |  |
| `planned_week` | smallint | yes |  |  |

**Constraints & indexes**

- PK `lesson_plan_item_pkey`: `PRIMARY KEY (id)`
- UNIQUE `lesson_plan_item_teaching_assignment_id_seq_key`: `UNIQUE (teaching_assignment_id, seq)`
- FK `lesson_plan_item_syllabus_unit_id_fkey`: `FOREIGN KEY (syllabus_unit_id) REFERENCES academic.syllabus_unit(id)`
- FK `lesson_plan_item_teaching_assignment_id_fkey`: `FOREIGN KEY (teaching_assignment_id) REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE`
- CHECK `lesson_plan_item_planned_hours_check`: `CHECK ((planned_hours > (0)::numeric))`
- CHECK `lesson_plan_item_planned_week_check`: `CHECK ((planned_week >= 1))`
- CHECK `lesson_plan_item_seq_check`: `CHECK ((seq >= 1))`
- CHECK `lesson_plan_item_topic_check`: `CHECK ((btrim(topic) <> ''::text))`

<a id="academicmentoring_meeting"></a>
### `academic.mentoring_meeting`

A mentor–mentee meeting during a current mentorship, with notes, follow-up date and concern flag (sensitive).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_mentor_id` | uuid |  |  |  |
| `met_on` | date |  |  |  |
| `meeting_mode_id` | smallint |  |  |  |
| `summary` | text |  |  | EDUCATION |
| `action_points` | text | yes |  | EDUCATION |
| `follow_up_on` | date | yes |  |  |
| `concern_flag` | boolean |  | `false` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `mentoring_meeting_pkey`: `PRIMARY KEY (id)`
- FK `mentoring_meeting_meeting_mode_id_fkey`: `FOREIGN KEY (meeting_mode_id) REFERENCES ref.meeting_mode(id)`
- FK `mentoring_meeting_student_mentor_id_fkey`: `FOREIGN KEY (student_mentor_id) REFERENCES people.student_mentor(id) ON DELETE CASCADE`
- CHECK `mentoring_meeting_check`: `CHECK (((follow_up_on IS NULL) OR (follow_up_on >= met_on)))`
- CHECK `mentoring_meeting_summary_check`: `CHECK ((btrim(summary) <> ''::text))`
- INDEX `mentoring_meeting_mentor_idx`: `btree (student_mentor_id)`

<a id="academicoffering_seat_quota"></a>
### `academic.offering_seat_quota`

Ceiling on the seats of an offering for students of one programme or of one org unit and everything under it (cross-school electives); enforced at registration.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_offering_id` | uuid |  |  |  |
| `program_id` | uuid | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `max_seats` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `offering_seat_quota_pkey`: `PRIMARY KEY (id)`
- UNIQUE `offering_seat_quota_course_offering_id_org_unit_id_key`: `UNIQUE (course_offering_id, org_unit_id)`
- UNIQUE `offering_seat_quota_course_offering_id_program_id_key`: `UNIQUE (course_offering_id, program_id)`
- FK `offering_seat_quota_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id) ON DELETE CASCADE`
- FK `offering_seat_quota_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- FK `offering_seat_quota_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- CHECK `offering_seat_quota_check`: `CHECK ((num_nonnulls(program_id, org_unit_id) = 1))`
- CHECK `offering_seat_quota_max_seats_check`: `CHECK ((max_seats >= 0))`

<a id="academicprogram"></a>
### `academic.program`

Programme offered by an academic unit: level, calendar type, duration in terms, credit range. Duration in years is derived.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `short_name` | citext | yes |  |  |
| `program_level_id` | smallint |  |  |  |
| `academic_calendar_type_id` | smallint |  |  |  |
| `offering_org_unit_id` | uuid |  |  |  |
| `delivery_mode_id` | smallint |  |  |  |
| `medium_language_id` | smallint | yes |  |  |
| `duration_terms` | smallint |  |  |  |
| `min_credits` | smallint | yes |  |  |
| `max_credits` | smallint | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_pkey`: `PRIMARY KEY (id)`
- UNIQUE `program_code_key`: `UNIQUE (code)`
- UNIQUE `program_name_key`: `UNIQUE (name)`
- UNIQUE `program_short_name_key`: `UNIQUE (short_name)`
- FK `program_academic_calendar_type_id_fkey`: `FOREIGN KEY (academic_calendar_type_id) REFERENCES ref.academic_calendar_type(id)`
- FK `program_delivery_mode_id_fkey`: `FOREIGN KEY (delivery_mode_id) REFERENCES ref.delivery_mode(id)`
- FK `program_medium_language_id_fkey`: `FOREIGN KEY (medium_language_id) REFERENCES ref.language(id)`
- FK `program_offering_org_unit_id_fkey`: `FOREIGN KEY (offering_org_unit_id) REFERENCES org.org_unit(id)`
- FK `program_program_level_id_fkey`: `FOREIGN KEY (program_level_id) REFERENCES ref.program_level(id)`
- CHECK `program_check`: `CHECK (((min_credits IS NULL) OR (max_credits IS NULL) OR (min_credits <= max_credits)))`
- CHECK `program_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{2,32}$'::citext))`
- CHECK `program_duration_terms_check`: `CHECK (((duration_terms >= 1) AND (duration_terms <= 20)))`
- CHECK `program_max_credits_check`: `CHECK ((max_credits > 0))`
- CHECK `program_min_credits_check`: `CHECK ((min_credits > 0))`
- CHECK `program_name_check`: `CHECK ((btrim(name) <> ''::text))`
- INDEX `program_offering_unit_idx`: `btree (offering_org_unit_id)`

<a id="academicprogram_accreditation"></a>
### `academic.program_accreditation`

Accreditation of a programme (NBA) or the institution / a unit (NAAC): grade, score, validity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `accreditation_body_id` | smallint |  |  |  |
| `grade` | text |  |  |  |
| `score` | numeric(5,2) | yes |  |  |
| `reference_no` | text | yes |  |  |
| `valid` | daterange |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_accreditation_pkey`: `PRIMARY KEY (id)`
- FK `program_accreditation_accreditation_body_id_fkey`: `FOREIGN KEY (accreditation_body_id) REFERENCES ref.accreditation_body(id)`
- FK `program_accreditation_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `program_accreditation_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- FK `program_accreditation_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- CHECK `program_accreditation_check`: `CHECK ((num_nonnulls(program_id, org_unit_id) = 1))`
- CHECK `program_accreditation_score_check`: `CHECK ((score >= (0)::numeric))`
- CHECK `program_accreditation_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `program_accreditation_one_at_a_time`: `EXCLUDE USING gist (COALESCE(program_id, org_unit_id) WITH =, accreditation_body_id WITH =, valid WITH &&)`

<a id="academicprogram_approval"></a>
### `academic.program_approval`

Regulator approval of a programme (UGC / AICTE / NMC …): letter, sanctioned seats, validity; a batch cannot exceed the approved seats.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `regulatory_body_id` | smallint |  |  |  |
| `reference_no` | text |  |  |  |
| `approved_seats` | integer | yes |  |  |
| `valid` | daterange |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_approval_pkey`: `PRIMARY KEY (id)`
- FK `program_approval_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `program_approval_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- FK `program_approval_regulatory_body_id_fkey`: `FOREIGN KEY (regulatory_body_id) REFERENCES ref.regulatory_body(id)`
- CHECK `program_approval_approved_seats_check`: `CHECK ((approved_seats >= 0))`
- CHECK `program_approval_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `program_approval_one_at_a_time`: `EXCLUDE USING gist (program_id WITH =, regulatory_body_id WITH =, valid WITH &&)`

<a id="academicprogram_coordinator"></a>
### `academic.program_coordinator`

Coordinator of a programme over time (one at a time).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_coordinator_pkey`: `PRIMARY KEY (id)`
- FK `program_coordinator_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `program_coordinator_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- CHECK `program_coordinator_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `program_coordinator_single`: `EXCLUDE USING gist (program_id WITH =, valid WITH &&)`
- INDEX `program_coordinator_employee_idx`: `btree (employee_id)`

<a id="academicprogram_outcome"></a>
### `academic.program_outcome`

Programme outcome (PO) or programme-specific outcome (PSO) of a programme.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `program_outcome_type_id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `statement` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_outcome_pkey`: `PRIMARY KEY (id)`
- UNIQUE `program_outcome_program_id_code_key`: `UNIQUE (program_id, code)`
- FK `program_outcome_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- FK `program_outcome_program_outcome_type_id_fkey`: `FOREIGN KEY (program_outcome_type_id) REFERENCES ref.program_outcome_type(id)`
- CHECK `program_outcome_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{1,16}$'::citext))`
- CHECK `program_outcome_statement_check`: `CHECK ((btrim(statement) <> ''::text))`

<a id="academicprogram_transfer"></a>
### `academic.program_transfer`

An enrollment continuing in another programme: old enrollment closed with PROGRAM_CHANGE, new one linked so credits follow through the lineage.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `from_enrollment_id` | uuid |  |  |  |
| `to_enrollment_id` | uuid |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_on` | date |  | `CURRENT_DATE` |  |
| `reason` | text | yes |  | EDUCATION |
| `body_resolution_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `program_transfer_pkey`: `PRIMARY KEY (id)`
- UNIQUE `program_transfer_from_enrollment_id_key`: `UNIQUE (from_enrollment_id)`
- UNIQUE `program_transfer_to_enrollment_id_key`: `UNIQUE (to_enrollment_id)`
- FK `program_transfer_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `program_transfer_body_resolution_id_fkey`: `FOREIGN KEY (body_resolution_id) REFERENCES academic.body_resolution(id)`
- FK `program_transfer_from_enrollment_id_fkey`: `FOREIGN KEY (from_enrollment_id) REFERENCES academic.student_enrollment(id)`
- FK `program_transfer_to_enrollment_id_fkey`: `FOREIGN KEY (to_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `program_transfer_check`: `CHECK ((from_enrollment_id <> to_enrollment_id))`

<a id="academicpromotion_rule"></a>
### `academic.promotion_rule`

Promotion checkpoint of a curriculum: maximum backlog (credits / courses) a student may carry past term N.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `after_term_no` | smallint |  |  |  |
| `max_backlog_credits` | numeric(5,1) |  |  |  |
| `max_backlog_courses` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `promotion_rule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `promotion_rule_curriculum_id_after_term_no_key`: `UNIQUE (curriculum_id, after_term_no)`
- FK `promotion_rule_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- CHECK `promotion_rule_after_term_no_check`: `CHECK ((after_term_no >= 1))`
- CHECK `promotion_rule_max_backlog_courses_check`: `CHECK ((max_backlog_courses >= 0))`
- CHECK `promotion_rule_max_backlog_credits_check`: `CHECK ((max_backlog_credits >= (0)::numeric))`

<a id="academicrelative_grade_cutoff"></a>
### `academic.relative_grade_cutoff`

On a relative grade scale: the cohort percentile at which a passing band is awarded.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `grade_band_id` | integer |  |  |  |
| `min_percentile` | numeric(5,2) |  |  |  |

**Constraints & indexes**

- PK `relative_grade_cutoff_pkey`: `PRIMARY KEY (grade_band_id)`
- FK `relative_grade_cutoff_grade_band_id_fkey`: `FOREIGN KEY (grade_band_id) REFERENCES academic.grade_band(id) ON DELETE CASCADE`
- CHECK `relative_grade_cutoff_min_percentile_check`: `CHECK (((min_percentile >= (0)::numeric) AND (min_percentile <= (100)::numeric)))`

<a id="academicresult_group"></a>
### `academic.result_group`

Curriculum courses that pass or fail as one combined result (theory + practical), with the combined pass percentage.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `curriculum_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `min_pass_pct` | numeric(5,2) |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `result_group_pkey`: `PRIMARY KEY (id)`
- UNIQUE `result_group_curriculum_id_code_key`: `UNIQUE (curriculum_id, code)`
- UNIQUE `result_group_id_curriculum_id_key`: `UNIQUE (id, curriculum_id)`
- FK `result_group_curriculum_id_fkey`: `FOREIGN KEY (curriculum_id) REFERENCES academic.curriculum(id) ON DELETE CASCADE`
- CHECK `result_group_min_pass_pct_check`: `CHECK (((min_pass_pct >= (0)::numeric) AND (min_pass_pct <= (100)::numeric)))`

<a id="academicsection"></a>
### `academic.section`

A class section of a batch in a term, with capacity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `batch_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `capacity` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `section_pkey`: `PRIMARY KEY (id)`
- UNIQUE `section_batch_id_academic_term_id_code_key`: `UNIQUE (batch_id, academic_term_id, code)`
- FK `section_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `section_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id)`
- CHECK `section_capacity_check`: `CHECK ((capacity > 0))`

<a id="academicsection_representative"></a>
### `academic.section_representative`

A student holding a role (class representative …) in their section: one holder per role, one role per student.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `section_id` | uuid |  |  |  |
| `section_role_id` | smallint |  |  |  |
| `student_enrollment_id` | uuid |  |  |  |
| `appointed_by_employee_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `section_representative_pkey`: `PRIMARY KEY (section_id, section_role_id)`
- UNIQUE `section_representative_section_id_student_enrollment_id_key`: `UNIQUE (section_id, student_enrollment_id)`
- FK `section_representative_appointed_by_employee_id_fkey`: `FOREIGN KEY (appointed_by_employee_id) REFERENCES people.employee(id)`
- FK `section_representative_section_id_fkey`: `FOREIGN KEY (section_id) REFERENCES academic.section(id) ON DELETE CASCADE`
- FK `section_representative_section_role_id_fkey`: `FOREIGN KEY (section_role_id) REFERENCES ref.section_role(id)`
- FK `section_representative_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`

<a id="academicsection_student"></a>
### `academic.section_student`

A student's section for a term — own batch only, one per term, within capacity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `section_id` | uuid |  |  |  |
| `student_enrollment_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `section_student_pkey`: `PRIMARY KEY (section_id, student_enrollment_id)`
- FK `section_student_section_id_fkey`: `FOREIGN KEY (section_id) REFERENCES academic.section(id) ON DELETE CASCADE`
- FK `section_student_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- INDEX `section_student_enrollment_idx`: `btree (student_enrollment_id)`

<a id="academicspecialization"></a>
### `academic.specialization`

Specializations / branches within a programme.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `program_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `specialization_pkey`: `PRIMARY KEY (id)`
- UNIQUE `specialization_program_id_code_key`: `UNIQUE (program_id, code)`
- UNIQUE `specialization_program_id_name_key`: `UNIQUE (program_id, name)`
- FK `specialization_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id) ON DELETE CASCADE`
- CHECK `specialization_code_check`: `CHECK ((code ~ '^[A-Za-z0-9_-]{1,32}$'::citext))`

<a id="academicstudent_award"></a>
### `academic.student_award`

The award conferred when an enrollment ends (exit certificate / diploma / degree); eligibility checked against the credit ledger.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `award_rule_id` | uuid |  |  | EDUCATION |
| `conferred_on` | date |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_award_pkey`: `PRIMARY KEY (id)`
- UNIQUE `student_award_student_enrollment_id_key`: `UNIQUE (student_enrollment_id)`
- FK `student_award_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `student_award_award_rule_id_fkey`: `FOREIGN KEY (award_rule_id) REFERENCES academic.award_rule(id)`
- FK `student_award_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`

<a id="academicstudent_enrollment"></a>
### `academic.student_enrollment`

Student in a batch over time (one at a time); entry_term_no > 1 = lateral entry. Home department and current term are derived.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_id` | uuid |  |  |  |
| `batch_id` | uuid |  |  | EDUCATION |
| `entry_term_no` | smallint |  | `1` |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `end_reason_id` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_enrollment_pkey`: `PRIMARY KEY (id)`
- FK `student_enrollment_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id)`
- FK `student_enrollment_end_reason_id_fkey`: `FOREIGN KEY (end_reason_id) REFERENCES ref.enrollment_end_reason(id)`
- FK `student_enrollment_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id) ON DELETE CASCADE`
- CHECK `student_enrollment_end_reason`: `CHECK ((upper_inf(valid) = (end_reason_id IS NULL)))`
- CHECK `student_enrollment_entry_term_no_check`: `CHECK ((entry_term_no >= 1))`
- CHECK `student_enrollment_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `student_enrollment_one_active`: `EXCLUDE USING gist (student_id WITH =, valid WITH &&)`
- INDEX `student_enrollment_batch_idx`: `btree (batch_id)`

<a id="academicstudent_pathway"></a>
### `academic.student_pathway`

A student's pathway choice over time (one at a time), from their own curriculum; drives registration and awards.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `curriculum_pathway_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_pathway_pkey`: `PRIMARY KEY (id)`
- FK `student_pathway_curriculum_pathway_id_fkey`: `FOREIGN KEY (curriculum_pathway_id) REFERENCES academic.curriculum_pathway(id)`
- FK `student_pathway_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `student_pathway_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `student_pathway_one_active`: `EXCLUDE USING gist (student_enrollment_id WITH =, valid WITH &&)`
- INDEX `student_pathway_pathway_idx`: `btree (curriculum_pathway_id)`

<a id="academicstudent_specialization"></a>
### `academic.student_specialization`

Specialization chosen within an enrollment; must be offered to that batch.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `specialization_id` | uuid |  |  | EDUCATION |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_specialization_pkey`: `PRIMARY KEY (id)`
- FK `student_specialization_specialization_id_fkey`: `FOREIGN KEY (specialization_id) REFERENCES academic.specialization(id)`
- FK `student_specialization_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `student_specialization_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `student_specialization_one_active`: `EXCLUDE USING gist (student_enrollment_id WITH =, valid WITH &&)`

<a id="academicstudent_track"></a>
### `academic.student_track`

A student on a minor / honours track over time; one active track per type, CGPA entry bar applied on joining.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `track_id` | uuid |  |  | EDUCATION |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `student_track_pkey`: `PRIMARY KEY (id)`
- FK `student_track_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- FK `student_track_track_id_fkey`: `FOREIGN KEY (track_id) REFERENCES academic.track(id)`
- CHECK `student_track_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `student_track_no_overlap`: `EXCLUDE USING gist (student_enrollment_id WITH =, track_id WITH =, valid WITH &&)`
- INDEX `student_track_track_idx`: `btree (track_id)`

<a id="academicstudy_break"></a>
### `academic.study_break`

Dated break in study (medical, personal, suspension …) on one enrollment; pauses the term count. Reason is health data.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `study_break_type_id` | smallint |  |  | HEALTH (sensitive) |
| `period` | daterange |  |  |  |
| `reason` | text | yes |  | HEALTH (sensitive) |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_on` | date |  | `CURRENT_DATE` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `study_break_pkey`: `PRIMARY KEY (id)`
- FK `study_break_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `study_break_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- FK `study_break_study_break_type_id_fkey`: `FOREIGN KEY (study_break_type_id) REFERENCES ref.study_break_type(id)`
- CHECK `study_break_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period))))`
- EXCLUDE `study_break_no_overlap`: `EXCLUDE USING gist (student_enrollment_id WITH =, period WITH &&)`

<a id="academicsupervised_work"></a>
### `academic.supervised_work`

A project / dissertation / internship done as a course registration whose category requires supervision.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_registration_id` | uuid |  |  |  |
| `title` | text |  |  |  |
| `synopsis` | text | yes |  |  |
| `report_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `supervised_work_pkey`: `PRIMARY KEY (id)`
- UNIQUE `supervised_work_course_registration_id_key`: `UNIQUE (course_registration_id)`
- FK `supervised_work_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`
- FK `supervised_work_report_file_id_fkey`: `FOREIGN KEY (report_file_id) REFERENCES people.file_object(id)`
- CHECK `supervised_work_title_check`: `CHECK ((btrim(title) <> ''::text))`

<a id="academicsupervised_work_guide"></a>
### `academic.supervised_work_guide`

Guides of a supervised work over time: one principal (employee) at a time, external co-guides allowed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `supervised_work_id` | uuid |  |  |  |
| `supervisor_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `supervised_work_guide_pkey`: `PRIMARY KEY (id)`
- FK `supervised_work_guide_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `supervised_work_guide_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- FK `supervised_work_guide_supervised_work_id_fkey`: `FOREIGN KEY (supervised_work_id) REFERENCES academic.supervised_work(id) ON DELETE CASCADE`
- FK `supervised_work_guide_supervisor_role_id_fkey`: `FOREIGN KEY (supervisor_role_id) REFERENCES ref.supervisor_role(id)`
- CHECK `supervised_work_guide_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- CHECK `supervised_work_guide_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- INDEX `supervised_work_guide_employee_idx`: `btree (employee_id)`
- INDEX `supervised_work_guide_work_idx`: `btree (supervised_work_id)`

<a id="academicsyllabus_unit"></a>
### `academic.syllabus_unit`

A unit of a syllabus version with its content and contact hours.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_syllabus_id` | uuid |  |  |  |
| `unit_no` | smallint |  |  |  |
| `title` | text |  |  |  |
| `content` | text | yes |  |  |
| `contact_hours` | numeric(5,1) | yes |  |  |

**Constraints & indexes**

- PK `syllabus_unit_pkey`: `PRIMARY KEY (id)`
- UNIQUE `syllabus_unit_course_syllabus_id_unit_no_key`: `UNIQUE (course_syllabus_id, unit_no)`
- FK `syllabus_unit_course_syllabus_id_fkey`: `FOREIGN KEY (course_syllabus_id) REFERENCES academic.course_syllabus(id) ON DELETE CASCADE`
- CHECK `syllabus_unit_contact_hours_check`: `CHECK ((contact_hours >= (0)::numeric))`
- CHECK `syllabus_unit_title_check`: `CHECK ((btrim(title) <> ''::text))`
- CHECK `syllabus_unit_unit_no_check`: `CHECK ((unit_no >= 1))`

<a id="academicteaching_assignment"></a>
### `academic.teaching_assignment`

Faculty ↔ offering ↔ class (section, class group, or combined) ↔ L/T/P component over time; one primary per class, co-faculty allowed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_offering_id` | uuid |  |  |  |
| `section_id` | uuid | yes |  |  |
| `class_group_id` | uuid | yes |  |  |
| `employee_id` | uuid |  |  |  |
| `delivery_component_id` | smallint |  |  |  |
| `is_primary` | boolean |  | `true` |  |
| `valid` | daterange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `teaching_assignment_pkey`: `PRIMARY KEY (id)`
- FK `teaching_assignment_class_group_id_fkey`: `FOREIGN KEY (class_group_id) REFERENCES academic.class_group(id) ON DELETE CASCADE`
- FK `teaching_assignment_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id) ON DELETE CASCADE`
- FK `teaching_assignment_delivery_component_id_fkey`: `FOREIGN KEY (delivery_component_id) REFERENCES ref.delivery_component(id)`
- FK `teaching_assignment_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `teaching_assignment_section_id_fkey`: `FOREIGN KEY (section_id) REFERENCES academic.section(id)`
- CHECK `teaching_assignment_one_target`: `CHECK ((num_nonnulls(section_id, class_group_id) <= 1))`
- CHECK `teaching_assignment_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `teaching_assignment_no_duplicate`: `EXCLUDE USING gist (course_offering_id WITH =, COALESCE(class_group_id, section_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, delivery_component_id WITH =, employee_id WITH =, valid WITH &&)`
- EXCLUDE `teaching_assignment_one_primary`: `EXCLUDE USING gist (course_offering_id WITH =, COALESCE(class_group_id, section_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, delivery_component_id WITH =, valid WITH &&) WHERE (is_primary)`
- INDEX `teaching_assignment_employee_idx`: `btree (employee_id)`
- INDEX `teaching_assignment_group_idx`: `btree (class_group_id)`

<a id="academicterm_registration"></a>
### `academic.term_registration`

A student on the rolls of an academic term for a programme term number, with the end-of-term academic standing (promoted / with backlog / detained), checked against backlog and promotion rule.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `term_no` | smallint |  |  |  |
| `term_registration_status_id` | smallint |  |  |  |
| `registered_at` | timestamp with time zone |  | `now()` |  |
| `registered_by_employee_id` | uuid | yes |  |  |
| `academic_standing_id` | smallint | yes |  | EDUCATION |
| `standing_decided_by_employee_id` | uuid | yes |  |  |
| `standing_decided_at` | timestamp with time zone | yes |  |  |
| `standing_note` | text | yes |  | EDUCATION |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `term_registration_pkey`: `PRIMARY KEY (id)`
- UNIQUE `term_registration_student_enrollment_id_academic_term_id_key`: `UNIQUE (student_enrollment_id, academic_term_id)`
- FK `term_registration_academic_standing_id_fkey`: `FOREIGN KEY (academic_standing_id) REFERENCES ref.academic_standing(id)`
- FK `term_registration_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `term_registration_registered_by_employee_id_fkey`: `FOREIGN KEY (registered_by_employee_id) REFERENCES people.employee(id)`
- FK `term_registration_standing_decided_by_employee_id_fkey`: `FOREIGN KEY (standing_decided_by_employee_id) REFERENCES people.employee(id)`
- FK `term_registration_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- FK `term_registration_term_registration_status_id_fkey`: `FOREIGN KEY (term_registration_status_id) REFERENCES ref.term_registration_status(id)`
- CHECK `term_registration_check`: `CHECK ((((academic_standing_id IS NULL) = (standing_decided_by_employee_id IS NULL)) AND ((academic_standing_id IS NULL) = (standing_decided_at IS NULL))))`
- CHECK `term_registration_term_no_check`: `CHECK ((term_no >= 1))`
- INDEX `term_registration_term_idx`: `btree (academic_term_id)`

<a id="academictime_slot"></a>
### `academic.time_slot`

Reusable weekly slot template (ISO weekday, start, end).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `day_of_week` | smallint |  |  |  |
| `start_time` | time without time zone |  |  |  |
| `end_time` | time without time zone |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `time_slot_pkey`: `PRIMARY KEY (id)`
- UNIQUE `time_slot_code_key`: `UNIQUE (code)`
- UNIQUE `time_slot_day_of_week_start_time_end_time_key`: `UNIQUE (day_of_week, start_time, end_time)`
- CHECK `time_slot_check`: `CHECK ((end_time > start_time))`
- CHECK `time_slot_day_of_week_check`: `CHECK (((day_of_week >= 1) AND (day_of_week <= 7)))`

<a id="academictimetable_entry"></a>
### `academic.timetable_entry`

A teaching assignment placed in a slot and room for a date range, weekly or every N weeks; room/faculty/section/student clashes and unavailability are rejected; parallel batches and alternate weeks allowed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `teaching_assignment_id` | uuid |  |  |  |
| `time_slot_id` | smallint |  |  |  |
| `room_id` | uuid |  |  |  |
| `repeat_every_weeks` | smallint |  | `1` |  |
| `valid` | daterange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `timetable_entry_pkey`: `PRIMARY KEY (id)`
- FK `timetable_entry_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- FK `timetable_entry_teaching_assignment_id_fkey`: `FOREIGN KEY (teaching_assignment_id) REFERENCES academic.teaching_assignment(id) ON DELETE CASCADE`
- FK `timetable_entry_time_slot_id_fkey`: `FOREIGN KEY (time_slot_id) REFERENCES academic.time_slot(id)`
- CHECK `timetable_entry_repeat_every_weeks_check`: `CHECK (((repeat_every_weeks >= 1) AND (repeat_every_weeks <= 4)))`
- CHECK `timetable_entry_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- INDEX `timetable_entry_assignment_idx`: `btree (teaching_assignment_id)`
- INDEX `timetable_entry_room_idx`: `btree (room_id)`

<a id="academictrack"></a>
### `academic.track`

A minor (another discipline) or honours track (own programme): minimum credits, CGPA entry bar, whether it counts in CGPA.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `track_type_id` | smallint |  |  |  |
| `offering_org_unit_id` | uuid |  |  |  |
| `program_id` | uuid | yes |  |  |
| `min_credits` | numeric(5,1) |  |  |  |
| `min_cgpa_to_join` | numeric(4,2) | yes |  |  |
| `counts_in_cgpa` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `track_pkey`: `PRIMARY KEY (id)`
- UNIQUE `track_code_key`: `UNIQUE (code)`
- FK `track_offering_org_unit_id_fkey`: `FOREIGN KEY (offering_org_unit_id) REFERENCES org.org_unit(id)`
- FK `track_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id)`
- FK `track_track_type_id_fkey`: `FOREIGN KEY (track_type_id) REFERENCES ref.track_type(id)`
- CHECK `track_min_cgpa_to_join_check`: `CHECK ((min_cgpa_to_join >= (0)::numeric))`
- CHECK `track_min_credits_check`: `CHECK ((min_credits > (0)::numeric))`

<a id="academictrack_course"></a>
### `academic.track_course`

A course of a minor / honours track, with its category and scheme of examination.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `track_id` | uuid |  |  |  |
| `course_id` | uuid |  |  |  |
| `course_category_id` | smallint |  |  |  |
| `evaluation_scheme_id` | integer |  |  |  |

**Constraints & indexes**

- PK `track_course_pkey`: `PRIMARY KEY (track_id, course_id)`
- FK `track_course_course_category_id_fkey`: `FOREIGN KEY (course_category_id) REFERENCES ref.course_category(id)`
- FK `track_course_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `track_course_evaluation_scheme_id_fkey`: `FOREIGN KEY (evaluation_scheme_id) REFERENCES academic.evaluation_scheme(id)`
- FK `track_course_track_id_fkey`: `FOREIGN KEY (track_id) REFERENCES academic.track(id) ON DELETE CASCADE`

<a id="academicworkload_norm"></a>
### `academic.workload_norm`

Expected teaching hours per week per designation, dated; actual load is derived (academic.v_faculty_workload).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `designation_id` | smallint |  |  |  |
| `min_hours_per_week` | numeric(4,1) | yes |  |  |
| `max_hours_per_week` | numeric(4,1) | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `workload_norm_pkey`: `PRIMARY KEY (id)`
- FK `workload_norm_designation_id_fkey`: `FOREIGN KEY (designation_id) REFERENCES people.designation(id)`
- CHECK `workload_norm_check`: `CHECK ((num_nonnulls(min_hours_per_week, max_hours_per_week) >= 1))`
- CHECK `workload_norm_check1`: `CHECK (((min_hours_per_week IS NULL) OR (max_hours_per_week IS NULL) OR (min_hours_per_week <= max_hours_per_week)))`
- CHECK `workload_norm_max_hours_per_week_check`: `CHECK ((max_hours_per_week >= (0)::numeric))`
- CHECK `workload_norm_min_hours_per_week_check`: `CHECK ((min_hours_per_week >= (0)::numeric))`
- CHECK `workload_norm_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `workload_norm_one_at_a_time`: `EXCLUDE USING gist (designation_id WITH =, valid WITH &&)`

## Schema `exam` — Examination

<a id="examanswer_script"></a>
### `exam.answer_script`

A written script under a random dummy code — the only code ↔ student link (hidden from analytics).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_schedule_id` | uuid |  |  |  |
| `exam_registration_id` | uuid |  |  |  |
| `dummy_code` | citext |  |  | EDUCATION |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `answer_script_pkey`: `PRIMARY KEY (id)`
- UNIQUE `answer_script_dummy_code_key`: `UNIQUE (dummy_code)`
- UNIQUE `answer_script_exam_schedule_id_exam_registration_id_key`: `UNIQUE (exam_schedule_id, exam_registration_id)`
- FK `answer_script_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id)`
- FK `answer_script_exam_schedule_id_fkey`: `FOREIGN KEY (exam_schedule_id) REFERENCES exam.exam_schedule(id)`

<a id="examattendance_condonation"></a>
### `exam.attendance_condonation`

Approved exception for an attendance shortage on one course registration.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `course_registration_id` | uuid |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `reason` | text |  |  | HEALTH (sensitive) |
| `approved_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `attendance_condonation_pkey`: `PRIMARY KEY (course_registration_id)`
- FK `attendance_condonation_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `attendance_condonation_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`

<a id="examcertificate"></a>
### `exam.certificate`

Register of issued certificates (transcript, provisional / final award certificate, migration, character, bonafide …): serial, public verification code, NAD reference; type rules enforced.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `certificate_type_id` | smallint |  |  |  |
| `serial_no` | citext |  |  | EDUCATION |
| `verification_code` | citext |  |  | EDUCATION |
| `student_award_id` | uuid | yes |  |  |
| `convocation_id` | uuid | yes |  |  |
| `is_duplicate` | boolean |  | `false` |  |
| `issued_on` | date |  | `CURRENT_DATE` |  |
| `issued_by_employee_id` | uuid |  |  |  |
| `nad_reference` | citext | yes |  | EDUCATION |
| `file_object_id` | uuid | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancel_reason` | text | yes |  | EDUCATION |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `certificate_pkey`: `PRIMARY KEY (id)`
- UNIQUE `certificate_nad_reference_key`: `UNIQUE (nad_reference)`
- UNIQUE `certificate_serial_no_key`: `UNIQUE (serial_no)`
- UNIQUE `certificate_verification_code_key`: `UNIQUE (verification_code)`
- FK `certificate_certificate_type_id_fkey`: `FOREIGN KEY (certificate_type_id) REFERENCES ref.certificate_type(id)`
- FK `certificate_convocation_id_fkey`: `FOREIGN KEY (convocation_id) REFERENCES exam.convocation(id)`
- FK `certificate_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `certificate_issued_by_employee_id_fkey`: `FOREIGN KEY (issued_by_employee_id) REFERENCES people.employee(id)`
- FK `certificate_student_award_id_fkey`: `FOREIGN KEY (student_award_id) REFERENCES academic.student_award(id)`
- FK `certificate_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id)`
- CHECK `certificate_check`: `CHECK (((cancelled_at IS NULL) = (cancel_reason IS NULL)))`
- INDEX `certificate_enrollment_idx`: `btree (student_enrollment_id)`

<a id="examcomponent_mark"></a>
### `exam.component_mark`

Marks for non-script components (internals, assignments, practicals, viva), per attempt or carried over.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_registration_id` | uuid |  |  |  |
| `evaluation_component_id` | integer |  |  |  |
| `exam_registration_id` | uuid | yes |  |  |
| `marks` | numeric(6,2) | yes |  | EDUCATION |
| `is_absent` | boolean |  | `false` |  |
| `entered_by_employee_id` | uuid |  |  |  |
| `entered_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `component_mark_pkey`: `PRIMARY KEY (id)`
- UNIQUE `component_mark_once`: `UNIQUE NULLS NOT DISTINCT (course_registration_id, evaluation_component_id, exam_registration_id)`
- FK `component_mark_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id) ON DELETE CASCADE`
- FK `component_mark_entered_by_employee_id_fkey`: `FOREIGN KEY (entered_by_employee_id) REFERENCES people.employee(id)`
- FK `component_mark_evaluation_component_id_fkey`: `FOREIGN KEY (evaluation_component_id) REFERENCES academic.evaluation_component(id)`
- FK `component_mark_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id)`
- CHECK `component_mark_check`: `CHECK ((is_absent = (marks IS NULL)))`
- CHECK `component_mark_marks_check`: `CHECK ((marks >= (0)::numeric))`

<a id="examconvocation"></a>
### `exam.convocation`

A convocation ceremony at which award certificates are conferred.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_year_id` | uuid |  |  |  |
| `name` | text |  |  |  |
| `held_on` | date |  |  |  |
| `start_time` | time without time zone | yes |  |  |
| `end_time` | time without time zone | yes |  |  |
| `room_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `convocation_pkey`: `PRIMARY KEY (id)`
- UNIQUE `convocation_academic_year_id_name_key`: `UNIQUE (academic_year_id, name)`
- FK `convocation_academic_year_id_fkey`: `FOREIGN KEY (academic_year_id) REFERENCES academic.academic_year(id)`
- FK `convocation_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- CHECK `convocation_check`: `CHECK ((((start_time IS NULL) = (end_time IS NULL)) AND ((end_time IS NULL) OR (end_time > start_time))))`

<a id="examcourse_result"></a>
### `exam.course_result`

Published result of an attempt: official total %, grade band, status. Immutable; corrections are new publications.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `result_publication_id` | uuid |  |  |  |
| `exam_registration_id` | uuid |  |  |  |
| `total_pct` | numeric(5,2) |  |  | EDUCATION |
| `grade_band_id` | integer |  |  | EDUCATION |
| `result_status_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `course_result_pkey`: `PRIMARY KEY (id)`
- UNIQUE `course_result_result_publication_id_exam_registration_id_key`: `UNIQUE (result_publication_id, exam_registration_id)`
- FK `course_result_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id)`
- FK `course_result_grade_band_id_fkey`: `FOREIGN KEY (grade_band_id) REFERENCES academic.grade_band(id)`
- FK `course_result_result_publication_id_fkey`: `FOREIGN KEY (result_publication_id) REFERENCES exam.result_publication(id)`
- FK `course_result_result_status_id_fkey`: `FOREIGN KEY (result_status_id) REFERENCES ref.result_status(id)`
- CHECK `course_result_total_pct_check`: `CHECK (((total_pct >= (0)::numeric) AND (total_pct <= (100)::numeric)))`
- INDEX `course_result_registration_idx`: `btree (exam_registration_id)`

<a id="exameligibility_hold"></a>
### `exam.eligibility_hold`

A hold blocking exam eligibility for a term or one course (disciplinary, fee dues, administrative); released, never deleted.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_id` | uuid |  |  |  |
| `academic_term_id` | uuid |  |  |  |
| `course_offering_id` | uuid | yes |  |  |
| `exam_hold_type_id` | smallint |  |  |  |
| `reason` | text |  |  | EDUCATION |
| `placed_by_employee_id` | uuid | yes |  |  |
| `placed_at` | timestamp with time zone |  | `now()` |  |
| `released_at` | timestamp with time zone | yes |  |  |
| `released_by_employee_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `eligibility_hold_pkey`: `PRIMARY KEY (id)`
- FK `eligibility_hold_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `eligibility_hold_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `eligibility_hold_exam_hold_type_id_fkey`: `FOREIGN KEY (exam_hold_type_id) REFERENCES ref.exam_hold_type(id)`
- FK `eligibility_hold_placed_by_employee_id_fkey`: `FOREIGN KEY (placed_by_employee_id) REFERENCES people.employee(id)`
- FK `eligibility_hold_released_by_employee_id_fkey`: `FOREIGN KEY (released_by_employee_id) REFERENCES people.employee(id)`
- FK `eligibility_hold_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id) ON DELETE CASCADE`
- CHECK `eligibility_hold_check`: `CHECK (((released_at IS NULL) OR (released_at >= placed_at)))`
- CHECK `eligibility_hold_check1`: `CHECK (((released_at IS NULL) = (released_by_employee_id IS NULL)))`
- INDEX `eligibility_hold_student_idx`: `btree (student_id, academic_term_id)`

<a id="examevaluator_assignment"></a>
### `exam.evaluator_assignment`

Evaluator per script per round (first / moderation / revaluation); a different person each round.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `answer_script_id` | uuid |  |  |  |
| `evaluation_round_id` | smallint |  |  |  |
| `employee_id` | uuid |  |  |  |
| `assigned_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `evaluator_assignment_pkey`: `PRIMARY KEY (answer_script_id, evaluation_round_id)`
- FK `evaluator_assignment_answer_script_id_fkey`: `FOREIGN KEY (answer_script_id) REFERENCES exam.answer_script(id) ON DELETE CASCADE`
- FK `evaluator_assignment_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `evaluator_assignment_evaluation_round_id_fkey`: `FOREIGN KEY (evaluation_round_id) REFERENCES ref.evaluation_round(id)`
- INDEX `evaluator_assignment_employee_idx`: `btree (employee_id)`

<a id="examexam_attendance"></a>
### `exam.exam_attendance`

Present / absent / UFM per student per paper.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `exam_schedule_id` | uuid |  |  |  |
| `exam_registration_id` | uuid |  |  |  |
| `exam_attendance_status_id` | smallint |  |  |  |
| `marked_by_employee_id` | uuid | yes |  |  |
| `marked_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `exam_attendance_pkey`: `PRIMARY KEY (exam_schedule_id, exam_registration_id)`
- FK `exam_attendance_exam_attendance_status_id_fkey`: `FOREIGN KEY (exam_attendance_status_id) REFERENCES ref.exam_attendance_status(id)`
- FK `exam_attendance_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id) ON DELETE CASCADE`
- FK `exam_attendance_exam_schedule_id_fkey`: `FOREIGN KEY (exam_schedule_id) REFERENCES exam.exam_schedule(id) ON DELETE CASCADE`
- FK `exam_attendance_marked_by_employee_id_fkey`: `FOREIGN KEY (marked_by_employee_id) REFERENCES people.employee(id)`

<a id="examexam_registration"></a>
### `exam.exam_registration`

A student sitting a course's exams in a session as a given attempt type; eligibility and paper clashes checked on insert.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `course_registration_id` | uuid |  |  |  |
| `exam_attempt_type_id` | smallint |  |  |  |
| `registered_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `exam_registration_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_registration_exam_session_id_course_registration_id_key`: `UNIQUE (exam_session_id, course_registration_id)`
- FK `exam_registration_course_registration_id_fkey`: `FOREIGN KEY (course_registration_id) REFERENCES academic.course_registration(id)`
- FK `exam_registration_exam_attempt_type_id_fkey`: `FOREIGN KEY (exam_attempt_type_id) REFERENCES ref.exam_attempt_type(id)`
- FK `exam_registration_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id)`
- INDEX `exam_registration_course_reg_idx`: `btree (course_registration_id)`

<a id="examexam_room"></a>
### `exam.exam_room`

Rooms allocated to a paper (must be exam venues).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `exam_schedule_id` | uuid |  |  |  |
| `room_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `exam_room_pkey`: `PRIMARY KEY (exam_schedule_id, room_id)`
- FK `exam_room_exam_schedule_id_fkey`: `FOREIGN KEY (exam_schedule_id) REFERENCES exam.exam_schedule(id) ON DELETE CASCADE`
- FK `exam_room_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`

<a id="examexam_schedule"></a>
### `exam.exam_schedule`

The date sheet: date and time of a scheduled component of a course offering in a session; student clashes rejected.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `course_offering_id` | uuid |  |  |  |
| `assessment_type_id` | smallint |  |  |  |
| `exam_date` | date |  |  |  |
| `start_time` | time without time zone |  |  |  |
| `end_time` | time without time zone |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |
| `question_paper_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `exam_schedule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_schedule_exam_session_id_course_offering_id_assessment_key`: `UNIQUE (exam_session_id, course_offering_id, assessment_type_id)`
- FK `exam_schedule_assessment_type_id_fkey`: `FOREIGN KEY (assessment_type_id) REFERENCES ref.assessment_type(id)`
- FK `exam_schedule_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `exam_schedule_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id) ON DELETE CASCADE`
- FK `exam_schedule_question_paper_id_fkey`: `FOREIGN KEY (question_paper_id) REFERENCES exam.question_paper(id)`
- CHECK `exam_schedule_check`: `CHECK ((end_time > start_time))`
- INDEX `exam_schedule_date_idx`: `btree (exam_date)`

<a id="examexam_session"></a>
### `exam.exam_session`

An examination session in a term (mid-term, end-term, supplementary) with its exam period.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `academic_term_id` | uuid |  |  |  |
| `exam_session_type_id` | smallint |  |  |  |
| `name` | text |  |  |  |
| `period` | daterange |  |  |  |
| `registration_window` | daterange | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `exam_session_pkey`: `PRIMARY KEY (id)`
- UNIQUE `exam_session_academic_term_id_name_key`: `UNIQUE (academic_term_id, name)`
- FK `exam_session_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `exam_session_exam_session_type_id_fkey`: `FOREIGN KEY (exam_session_type_id) REFERENCES ref.exam_session_type(id)`
- CHECK `exam_session_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period)) AND (NOT upper_inf(period))))`

<a id="examexaminer_panel"></a>
### `exam.examiner_panel`

Internal / external examiners of a directly-marked scheduled paper (end-term practical, viva); only panel members enter its marks.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_schedule_id` | uuid |  |  |  |
| `examiner_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `appointed_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `examiner_panel_pkey`: `PRIMARY KEY (id)`
- UNIQUE `examiner_panel_exam_schedule_id_employee_id_key`: `UNIQUE (exam_schedule_id, employee_id)`
- UNIQUE `examiner_panel_exam_schedule_id_external_person_id_key`: `UNIQUE (exam_schedule_id, external_person_id)`
- FK `examiner_panel_appointed_by_employee_id_fkey`: `FOREIGN KEY (appointed_by_employee_id) REFERENCES people.employee(id)`
- FK `examiner_panel_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `examiner_panel_exam_schedule_id_fkey`: `FOREIGN KEY (exam_schedule_id) REFERENCES exam.exam_schedule(id) ON DELETE CASCADE`
- FK `examiner_panel_examiner_role_id_fkey`: `FOREIGN KEY (examiner_role_id) REFERENCES ref.examiner_role(id)`
- FK `examiner_panel_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- CHECK `examiner_panel_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- INDEX `examiner_panel_employee_idx`: `btree (employee_id)`

<a id="examgrace_award"></a>
### `exam.grace_award`

Grace marks awarded to one exam attempt under a policy.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_registration_id` | uuid |  |  |  |
| `grace_policy_id` | smallint |  |  |  |
| `marks` | numeric(5,2) |  |  | EDUCATION |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `grace_award_pkey`: `PRIMARY KEY (id)`
- UNIQUE `grace_award_exam_registration_id_key`: `UNIQUE (exam_registration_id)`
- FK `grace_award_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `grace_award_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id) ON DELETE CASCADE`
- FK `grace_award_grace_policy_id_fkey`: `FOREIGN KEY (grace_policy_id) REFERENCES exam.grace_policy(id)`
- CHECK `grace_award_marks_check`: `CHECK ((marks > (0)::numeric))`

<a id="examgrace_policy"></a>
### `exam.grace_policy`

Grace-marks policy: maximum marks per course and courses per session.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `max_marks_per_course` | numeric(5,2) |  |  |  |
| `max_courses_per_session` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `grace_policy_pkey`: `PRIMARY KEY (id)`
- UNIQUE `grace_policy_code_key`: `UNIQUE (code)`
- CHECK `grace_policy_max_courses_per_session_check`: `CHECK ((max_courses_per_session > 0))`
- CHECK `grace_policy_max_marks_per_course_check`: `CHECK ((max_marks_per_course > (0)::numeric))`

<a id="examinternal_mark_revision"></a>
### `exam.internal_mark_revision`

Request to revise a published internal mark, decided through the INTERNAL_MARKS_REVISION workflow; the original mark is kept.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `component_mark_id` | uuid |  |  |  |
| `revised_marks` | numeric(6,2) |  |  | EDUCATION |
| `reason` | text |  |  | EDUCATION |
| `requested_by_employee_id` | uuid |  |  |  |
| `instance_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `internal_mark_revision_pkey`: `PRIMARY KEY (id)`
- UNIQUE `internal_mark_revision_instance_id_key`: `UNIQUE (instance_id)`
- FK `internal_mark_revision_component_mark_id_fkey`: `FOREIGN KEY (component_mark_id) REFERENCES exam.component_mark(id)`
- FK `internal_mark_revision_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `internal_mark_revision_requested_by_employee_id_fkey`: `FOREIGN KEY (requested_by_employee_id) REFERENCES people.employee(id)`
- CHECK `internal_mark_revision_reason_check`: `CHECK ((btrim(reason) <> ''::text))`
- CHECK `internal_mark_revision_revised_marks_check`: `CHECK ((revised_marks >= (0)::numeric))`
- INDEX `internal_mark_revision_mark_idx`: `btree (component_mark_id)`

<a id="examinvigilation_duty"></a>
### `exam.invigilation_duty`

Invigilator duty per paper and room; one chief per room; no invigilator in two rooms at once.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `exam_schedule_id` | uuid |  |  |  |
| `room_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `is_chief` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `invigilation_duty_pkey`: `PRIMARY KEY (exam_schedule_id, room_id, employee_id)`
- FK `invigilation_duty_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `invigilation_duty_exam_schedule_id_room_id_fkey`: `FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE`
- INDEX `invigilation_one_chief_uq`: `btree (exam_schedule_id, room_id) WHERE is_chief`

<a id="exammarksheet"></a>
### `exam.marksheet`

Register of issued marksheets (serial number, original vs duplicate).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `exam_session_id` | uuid |  |  |  |
| `serial_no` | citext |  |  |  |
| `is_duplicate` | boolean |  | `false` |  |
| `issued_by_employee_id` | uuid |  |  |  |
| `issued_at` | timestamp with time zone |  | `now()` |  |
| `file_object_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `marksheet_pkey`: `PRIMARY KEY (id)`
- UNIQUE `marksheet_serial_no_key`: `UNIQUE (serial_no)`
- FK `marksheet_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id)`
- FK `marksheet_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `marksheet_issued_by_employee_id_fkey`: `FOREIGN KEY (issued_by_employee_id) REFERENCES people.employee(id)`
- FK `marksheet_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id)`
- INDEX `marksheet_enrollment_idx`: `btree (student_enrollment_id)`
- INDEX `marksheet_one_original_uq`: `btree (student_enrollment_id, exam_session_id) WHERE (NOT is_duplicate)`

<a id="exampaper_setter_assignment"></a>
### `exam.paper_setter_assignment`

Setter / moderator of a scheduled component's paper in a session (employee or external); setter and moderator differ.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `course_offering_id` | uuid |  |  |  |
| `assessment_type_id` | smallint |  |  |  |
| `paper_setter_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `due_on` | date | yes |  |  |
| `appointed_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `paper_setter_assignment_pkey`: `PRIMARY KEY (id)`
- UNIQUE `paper_setter_assignment_exam_session_id_course_offering_id__key`: `UNIQUE (exam_session_id, course_offering_id, assessment_type_id, paper_setter_role_id)`
- FK `paper_setter_assignment_appointed_by_employee_id_fkey`: `FOREIGN KEY (appointed_by_employee_id) REFERENCES people.employee(id)`
- FK `paper_setter_assignment_assessment_type_id_fkey`: `FOREIGN KEY (assessment_type_id) REFERENCES ref.assessment_type(id)`
- FK `paper_setter_assignment_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `paper_setter_assignment_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `paper_setter_assignment_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id) ON DELETE CASCADE`
- FK `paper_setter_assignment_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- FK `paper_setter_assignment_paper_setter_role_id_fkey`: `FOREIGN KEY (paper_setter_role_id) REFERENCES ref.paper_setter_role(id)`
- CHECK `paper_setter_assignment_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`

<a id="examprize"></a>
### `exam.prize`

A medal / prize for a programme or university-wide, optionally tied to a rank in the programme's rank list.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `prize_type_id` | smallint |  |  |  |
| `program_id` | uuid | yes |  |  |
| `rank_position` | smallint | yes |  |  |
| `sponsor` | text | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `prize_pkey`: `PRIMARY KEY (id)`
- UNIQUE `prize_code_key`: `UNIQUE (code)`
- FK `prize_prize_type_id_fkey`: `FOREIGN KEY (prize_type_id) REFERENCES ref.prize_type(id)`
- FK `prize_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id)`
- CHECK `prize_check`: `CHECK (((rank_position IS NULL) OR (program_id IS NOT NULL)))`
- CHECK `prize_rank_position_check`: `CHECK ((rank_position >= 1))`

<a id="examprize_award"></a>
### `exam.prize_award`

A prize awarded to a graduating student; a rank prize only to the holder of that rank, once per batch.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `prize_id` | uuid |  |  |  |
| `student_enrollment_id` | uuid |  |  |  |
| `convocation_id` | uuid | yes |  |  |
| `awarded_on` | date |  |  |  |
| `citation` | text | yes |  | EDUCATION |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `prize_award_pkey`: `PRIMARY KEY (id)`
- UNIQUE `prize_award_prize_id_student_enrollment_id_key`: `UNIQUE (prize_id, student_enrollment_id)`
- FK `prize_award_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `prize_award_convocation_id_fkey`: `FOREIGN KEY (convocation_id) REFERENCES exam.convocation(id)`
- FK `prize_award_prize_id_fkey`: `FOREIGN KEY (prize_id) REFERENCES exam.prize(id)`
- FK `prize_award_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id)`

<a id="examquestion_bank_item"></a>
### `exam.question_bank_item`

A reusable question for a course tagged by course outcome, Bloom level, difficulty and type; reviewed by a second person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `course_id` | uuid |  |  |  |
| `course_outcome_id` | uuid | yes |  |  |
| `bloom_level_id` | smallint | yes |  |  |
| `question_difficulty_id` | smallint |  |  |  |
| `question_type_id` | smallint |  |  |  |
| `question_text` | text |  |  |  |
| `marks` | numeric(5,2) |  |  |  |
| `created_by_employee_id` | uuid |  |  |  |
| `reviewed_by_employee_id` | uuid | yes |  |  |
| `reviewed_at` | timestamp with time zone | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `question_bank_item_pkey`: `PRIMARY KEY (id)`
- FK `question_bank_item_bloom_level_id_fkey`: `FOREIGN KEY (bloom_level_id) REFERENCES ref.bloom_level(id)`
- FK `question_bank_item_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `question_bank_item_course_outcome_id_fkey`: `FOREIGN KEY (course_outcome_id) REFERENCES academic.course_outcome(id)`
- FK `question_bank_item_created_by_employee_id_fkey`: `FOREIGN KEY (created_by_employee_id) REFERENCES people.employee(id)`
- FK `question_bank_item_question_difficulty_id_fkey`: `FOREIGN KEY (question_difficulty_id) REFERENCES ref.question_difficulty(id)`
- FK `question_bank_item_question_type_id_fkey`: `FOREIGN KEY (question_type_id) REFERENCES ref.question_type(id)`
- FK `question_bank_item_reviewed_by_employee_id_fkey`: `FOREIGN KEY (reviewed_by_employee_id) REFERENCES people.employee(id)`
- CHECK `question_bank_item_check`: `CHECK (((reviewed_by_employee_id IS NULL) = (reviewed_at IS NULL)))`
- CHECK `question_bank_item_check1`: `CHECK ((reviewed_by_employee_id IS DISTINCT FROM created_by_employee_id))`
- CHECK `question_bank_item_marks_check`: `CHECK ((marks > (0)::numeric))`
- CHECK `question_bank_item_question_text_check`: `CHECK ((btrim(question_text) <> ''::text))`
- INDEX `question_bank_item_course_idx`: `btree (course_id)`

<a id="examquestion_mark"></a>
### `exam.question_mark`

Marks per question of the paper a student sat; basis of CO attainment; never above the script mark in total; unchangeable once the result is published.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `exam_registration_id` | uuid |  |  |  |
| `question_paper_id` | uuid |  |  |  |
| `question_no` | citext |  |  |  |
| `marks` | numeric(5,2) |  |  | EDUCATION |
| `entered_by_employee_id` | uuid |  |  |  |
| `entered_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `question_mark_pkey`: `PRIMARY KEY (exam_registration_id, question_paper_id, question_no)`
- FK `question_mark_entered_by_employee_id_fkey`: `FOREIGN KEY (entered_by_employee_id) REFERENCES people.employee(id)`
- FK `question_mark_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id) ON DELETE CASCADE`
- FK `question_mark_question_paper_id_question_no_fkey`: `FOREIGN KEY (question_paper_id, question_no) REFERENCES exam.question_paper_item(question_paper_id, question_no)`
- CHECK `question_mark_marks_check`: `CHECK ((marks >= (0)::numeric))`

<a id="examquestion_paper"></a>
### `exam.question_paper`

A question-paper set with its confidential file; draft → submitted → moderated → approved → printed → used (flags on the status decide what must be present).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `course_offering_id` | uuid |  |  |  |
| `assessment_type_id` | smallint |  |  |  |
| `set_code` | citext |  | `'A'::citext` |  |
| `question_paper_status_id` | smallint |  |  |  |
| `submitted_by_assignment_id` | uuid | yes |  |  |
| `submitted_at` | timestamp with time zone | yes |  |  |
| `moderated_by_assignment_id` | uuid | yes |  |  |
| `moderated_at` | timestamp with time zone | yes |  |  |
| `approved_by_employee_id` | uuid | yes |  |  |
| `approved_at` | timestamp with time zone | yes |  |  |
| `max_marks` | numeric(6,2) | yes |  |  |
| `duration_minutes` | smallint | yes |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `question_paper_pkey`: `PRIMARY KEY (id)`
- UNIQUE `question_paper_exam_session_id_course_offering_id_assessmen_key`: `UNIQUE (exam_session_id, course_offering_id, assessment_type_id, set_code)`
- FK `question_paper_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `question_paper_assessment_type_id_fkey`: `FOREIGN KEY (assessment_type_id) REFERENCES ref.assessment_type(id)`
- FK `question_paper_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `question_paper_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id) ON DELETE CASCADE`
- FK `question_paper_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `question_paper_moderated_by_assignment_id_fkey`: `FOREIGN KEY (moderated_by_assignment_id) REFERENCES exam.paper_setter_assignment(id)`
- FK `question_paper_question_paper_status_id_fkey`: `FOREIGN KEY (question_paper_status_id) REFERENCES ref.question_paper_status(id)`
- FK `question_paper_submitted_by_assignment_id_fkey`: `FOREIGN KEY (submitted_by_assignment_id) REFERENCES exam.paper_setter_assignment(id)`
- CHECK `question_paper_check`: `CHECK (((submitted_by_assignment_id IS NULL) = (submitted_at IS NULL)))`
- CHECK `question_paper_check1`: `CHECK (((moderated_by_assignment_id IS NULL) = (moderated_at IS NULL)))`
- CHECK `question_paper_check2`: `CHECK (((approved_by_employee_id IS NULL) = (approved_at IS NULL)))`
- CHECK `question_paper_duration_minutes_check`: `CHECK ((duration_minutes > 0))`
- CHECK `question_paper_max_marks_check`: `CHECK ((max_marks > (0)::numeric))`

<a id="examquestion_paper_item"></a>
### `exam.question_paper_item`

A question of a question paper drawn from the bank; fixed once the paper is approved.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `question_paper_id` | uuid |  |  |  |
| `question_no` | citext |  |  |  |
| `question_bank_item_id` | uuid |  |  |  |
| `marks` | numeric(5,2) |  |  |  |

**Constraints & indexes**

- PK `question_paper_item_pkey`: `PRIMARY KEY (question_paper_id, question_no)`
- UNIQUE `question_paper_item_question_paper_id_question_bank_item_id_key`: `UNIQUE (question_paper_id, question_bank_item_id)`
- FK `question_paper_item_question_bank_item_id_fkey`: `FOREIGN KEY (question_bank_item_id) REFERENCES exam.question_bank_item(id)`
- FK `question_paper_item_question_paper_id_fkey`: `FOREIGN KEY (question_paper_id) REFERENCES exam.question_paper(id) ON DELETE CASCADE`
- CHECK `question_paper_item_marks_check`: `CHECK ((marks > (0)::numeric))`

<a id="examresult_moderation"></a>
### `exam.result_moderation`

Examination-board moderation for one course in one session (± percentage points, with reason); frozen once results are published.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `course_offering_id` | uuid |  |  |  |
| `add_pct` | numeric(5,2) |  |  |  |
| `reason` | text |  |  |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `approved_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `result_moderation_pkey`: `PRIMARY KEY (id)`
- UNIQUE `result_moderation_exam_session_id_course_offering_id_key`: `UNIQUE (exam_session_id, course_offering_id)`
- FK `result_moderation_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `result_moderation_course_offering_id_fkey`: `FOREIGN KEY (course_offering_id) REFERENCES academic.course_offering(id)`
- FK `result_moderation_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id)`
- CHECK `result_moderation_add_pct_check`: `CHECK (((add_pct <> (0)::numeric) AND ((add_pct >= ('-20'::integer)::numeric) AND (add_pct <= (20)::numeric))))`

<a id="examresult_publication"></a>
### `exam.result_publication`

A result release event (original, revised after revaluation, supplementary).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_session_id` | uuid |  |  |  |
| `publication_type_id` | smallint |  |  |  |
| `published_at` | timestamp with time zone |  | `now()` |  |
| `published_by_employee_id` | uuid |  |  |  |
| `note` | text | yes |  |  |

**Constraints & indexes**

- PK `result_publication_pkey`: `PRIMARY KEY (id)`
- FK `result_publication_exam_session_id_fkey`: `FOREIGN KEY (exam_session_id) REFERENCES exam.exam_session(id)`
- FK `result_publication_publication_type_id_fkey`: `FOREIGN KEY (publication_type_id) REFERENCES ref.publication_type(id)`
- FK `result_publication_published_by_employee_id_fkey`: `FOREIGN KEY (published_by_employee_id) REFERENCES people.employee(id)`

<a id="examrevaluation_request"></a>
### `exam.revaluation_request`

Recheck / revaluation / photocopy request on a script, allowed only after its result is published.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `answer_script_id` | uuid |  |  |  |
| `revaluation_type_id` | smallint |  |  |  |
| `revaluation_status_id` | smallint |  |  |  |
| `requested_at` | timestamp with time zone |  | `now()` |  |
| `closed_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `revaluation_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `revaluation_request_answer_script_id_revaluation_type_id_key`: `UNIQUE (answer_script_id, revaluation_type_id)`
- FK `revaluation_request_answer_script_id_fkey`: `FOREIGN KEY (answer_script_id) REFERENCES exam.answer_script(id)`
- FK `revaluation_request_revaluation_status_id_fkey`: `FOREIGN KEY (revaluation_status_id) REFERENCES ref.revaluation_status(id)`
- FK `revaluation_request_revaluation_type_id_fkey`: `FOREIGN KEY (revaluation_type_id) REFERENCES ref.revaluation_type(id)`
- CHECK `revaluation_request_check`: `CHECK (((closed_at IS NULL) OR (closed_at >= requested_at)))`

<a id="examscript_mark"></a>
### `exam.script_mark`

Marks given in an assigned round; never overwritten — the highest-precedence round counts.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `answer_script_id` | uuid |  |  |  |
| `evaluation_round_id` | smallint |  |  |  |
| `marks` | numeric(6,2) |  |  | EDUCATION |
| `note` | text | yes |  | EDUCATION |
| `entered_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `script_mark_pkey`: `PRIMARY KEY (answer_script_id, evaluation_round_id)`
- FK `script_mark_answer_script_id_evaluation_round_id_fkey`: `FOREIGN KEY (answer_script_id, evaluation_round_id) REFERENCES exam.evaluator_assignment(answer_script_id, evaluation_round_id)`
- CHECK `script_mark_marks_check`: `CHECK ((marks >= (0)::numeric))`

<a id="examseat_allocation"></a>
### `exam.seat_allocation`

Seating plan: registered student → room + seat; seats unique and capacity respected across concurrent papers.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `exam_schedule_id` | uuid |  |  |  |
| `exam_registration_id` | uuid |  |  |  |
| `room_id` | uuid |  |  |  |
| `seat_no` | citext |  |  |  |

**Constraints & indexes**

- PK `seat_allocation_pkey`: `PRIMARY KEY (exam_schedule_id, exam_registration_id)`
- FK `seat_allocation_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id) ON DELETE CASCADE`
- FK `seat_allocation_exam_schedule_id_room_id_fkey`: `FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE`

<a id="examufm_case"></a>
### `exam.ufm_case`

Unfair-means case reported in the hall and its committee decision / penalty.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `exam_schedule_id` | uuid |  |  |  |
| `exam_registration_id` | uuid |  |  |  |
| `reported_by_employee_id` | uuid |  |  |  |
| `reported_at` | timestamp with time zone |  | `now()` |  |
| `description` | text |  |  | EDUCATION |
| `ufm_case_status_id` | smallint |  |  |  |
| `ufm_penalty_id` | smallint | yes |  |  |
| `decided_by_employee_id` | uuid | yes |  |  |
| `decided_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `ufm_case_pkey`: `PRIMARY KEY (id)`
- FK `ufm_case_decided_by_employee_id_fkey`: `FOREIGN KEY (decided_by_employee_id) REFERENCES people.employee(id)`
- FK `ufm_case_exam_registration_id_fkey`: `FOREIGN KEY (exam_registration_id) REFERENCES exam.exam_registration(id)`
- FK `ufm_case_exam_schedule_id_fkey`: `FOREIGN KEY (exam_schedule_id) REFERENCES exam.exam_schedule(id)`
- FK `ufm_case_reported_by_employee_id_fkey`: `FOREIGN KEY (reported_by_employee_id) REFERENCES people.employee(id)`
- FK `ufm_case_ufm_case_status_id_fkey`: `FOREIGN KEY (ufm_case_status_id) REFERENCES ref.ufm_case_status(id)`
- FK `ufm_case_ufm_penalty_id_fkey`: `FOREIGN KEY (ufm_penalty_id) REFERENCES ref.ufm_penalty(id)`
- CHECK `ufm_case_check`: `CHECK (((decided_at IS NULL) = (decided_by_employee_id IS NULL)))`
- CHECK `ufm_case_check1`: `CHECK (((ufm_penalty_id IS NULL) OR (decided_at IS NOT NULL)))`
- INDEX `ufm_case_registration_idx`: `btree (exam_registration_id)`

## Schema `research` — Doctoral research: supervision, committees, thesis, viva

<a id="researchadvisory_committee"></a>
### `research.advisory_committee`

Research advisory / doctoral committee of a scholar (one per enrollment).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `constituted_on` | date |  | `CURRENT_DATE` |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `advisory_committee_pkey`: `PRIMARY KEY (id)`
- UNIQUE `advisory_committee_student_enrollment_id_key`: `UNIQUE (student_enrollment_id)`
- FK `advisory_committee_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `advisory_committee_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`

<a id="researchadvisory_committee_member"></a>
### `research.advisory_committee_member`

Dated committee members (employees or external experts); exactly one chair at a time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `advisory_committee_id` | uuid |  |  |  |
| `committee_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |

**Constraints & indexes**

- PK `advisory_committee_member_pkey`: `PRIMARY KEY (id)`
- FK `advisory_committee_member_advisory_committee_id_fkey`: `FOREIGN KEY (advisory_committee_id) REFERENCES research.advisory_committee(id) ON DELETE CASCADE`
- FK `advisory_committee_member_committee_role_id_fkey`: `FOREIGN KEY (committee_role_id) REFERENCES ref.committee_role(id)`
- FK `advisory_committee_member_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `advisory_committee_member_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- CHECK `advisory_committee_member_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- CHECK `advisory_committee_member_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `advisory_committee_member_no_duplicate`: `EXCLUDE USING gist (advisory_committee_id WITH =, COALESCE(employee_id, external_person_id) WITH =, valid WITH &&)`

<a id="researchprogress_review"></a>
### `research.progress_review`

Periodic progress review of a scholar by the committee, numbered, with outcome.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `review_no` | smallint |  |  |  |
| `held_on` | date |  |  |  |
| `progress_review_outcome_id` | smallint |  |  |  |
| `remarks` | text | yes |  | EDUCATION |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `progress_review_pkey`: `PRIMARY KEY (id)`
- UNIQUE `progress_review_student_enrollment_id_review_no_key`: `UNIQUE (student_enrollment_id, review_no)`
- FK `progress_review_progress_review_outcome_id_fkey`: `FOREIGN KEY (progress_review_outcome_id) REFERENCES ref.progress_review_outcome(id)`
- FK `progress_review_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- CHECK `progress_review_review_no_check`: `CHECK ((review_no >= 1))`

<a id="researchsupervision_norm"></a>
### `research.supervision_norm`

Maximum doctoral scholars a designation may supervise as principal supervisor at one time (UGC 2022: 8 / 6 / 4).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `designation_id` | smallint |  |  |  |
| `max_scholars` | smallint |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `supervision_norm_pkey`: `PRIMARY KEY (id)`
- FK `supervision_norm_designation_id_fkey`: `FOREIGN KEY (designation_id) REFERENCES people.designation(id)`
- CHECK `supervision_norm_max_scholars_check`: `CHECK ((max_scholars >= 0))`
- CHECK `supervision_norm_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `supervision_norm_one_at_a_time`: `EXCLUDE USING gist (designation_id WITH =, valid WITH &&)`

<a id="researchsupervisor_allocation"></a>
### `research.supervisor_allocation`

Supervisor / co-supervisor (may be external) of a scholar over time; one principal supervisor at a time, norm enforced.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `supervisor_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  | EMPLOYMENT |
| `external_person_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `supervisor_allocation_pkey`: `PRIMARY KEY (id)`
- FK `supervisor_allocation_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `supervisor_allocation_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `supervisor_allocation_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- FK `supervisor_allocation_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- FK `supervisor_allocation_supervisor_role_id_fkey`: `FOREIGN KEY (supervisor_role_id) REFERENCES ref.supervisor_role(id)`
- CHECK `supervisor_allocation_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- CHECK `supervisor_allocation_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `supervisor_allocation_no_duplicate`: `EXCLUDE USING gist (student_enrollment_id WITH =, COALESCE(employee_id, external_person_id) WITH =, valid WITH &&)`
- INDEX `supervisor_allocation_employee_idx`: `btree (employee_id)`

<a id="researchthesis"></a>
### `research.thesis`

A scholar's thesis: title, milestone dates in order, status, plagiarism similarity, files; submission needs a principal supervisor.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `student_enrollment_id` | uuid |  |  |  |
| `title` | text |  |  | EDUCATION |
| `thesis_status_id` | smallint |  |  |  |
| `topic_approved_on` | date | yes |  |  |
| `synopsis_submitted_on` | date | yes |  |  |
| `synopsis_approved_on` | date | yes |  |  |
| `thesis_submitted_on` | date | yes |  |  |
| `similarity_pct` | numeric(5,2) | yes |  | EDUCATION |
| `synopsis_file_id` | uuid | yes |  |  |
| `thesis_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `thesis_pkey`: `PRIMARY KEY (id)`
- UNIQUE `thesis_student_enrollment_id_key`: `UNIQUE (student_enrollment_id)`
- FK `thesis_student_enrollment_id_fkey`: `FOREIGN KEY (student_enrollment_id) REFERENCES academic.student_enrollment(id) ON DELETE CASCADE`
- FK `thesis_synopsis_file_id_fkey`: `FOREIGN KEY (synopsis_file_id) REFERENCES people.file_object(id)`
- FK `thesis_thesis_file_id_fkey`: `FOREIGN KEY (thesis_file_id) REFERENCES people.file_object(id)`
- FK `thesis_thesis_status_id_fkey`: `FOREIGN KEY (thesis_status_id) REFERENCES ref.thesis_status(id)`
- CHECK `thesis_check`: `CHECK (((synopsis_submitted_on IS NULL) OR (topic_approved_on IS NULL) OR (synopsis_submitted_on >= topic_approved_on)))`
- CHECK `thesis_check1`: `CHECK (((synopsis_approved_on IS NULL) OR ((synopsis_submitted_on IS NOT NULL) AND (synopsis_approved_on >= synopsis_submitted_on))))`
- CHECK `thesis_check2`: `CHECK (((thesis_submitted_on IS NULL) OR (synopsis_submitted_on IS NULL) OR (thesis_submitted_on >= synopsis_submitted_on)))`
- CHECK `thesis_similarity_pct_check`: `CHECK (((similarity_pct >= (0)::numeric) AND (similarity_pct <= (100)::numeric)))`
- CHECK `thesis_title_check`: `CHECK ((btrim(title) <> ''::text))`

<a id="researchthesis_examiner"></a>
### `research.thesis_examiner`

Internal / external examiners of a thesis and their reports; supervisors may not examine.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `thesis_id` | uuid |  |  |  |
| `thesis_examiner_role_id` | smallint |  |  |  |
| `employee_id` | uuid | yes |  |  |
| `external_person_id` | uuid | yes |  |  |
| `appointed_on` | date |  | `CURRENT_DATE` |  |
| `report_received_on` | date | yes |  |  |
| `examiner_recommendation_id` | smallint | yes |  | EDUCATION |
| `report_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `thesis_examiner_pkey`: `PRIMARY KEY (id)`
- UNIQUE `thesis_examiner_thesis_id_employee_id_key`: `UNIQUE (thesis_id, employee_id)`
- UNIQUE `thesis_examiner_thesis_id_external_person_id_key`: `UNIQUE (thesis_id, external_person_id)`
- FK `thesis_examiner_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `thesis_examiner_examiner_recommendation_id_fkey`: `FOREIGN KEY (examiner_recommendation_id) REFERENCES ref.examiner_recommendation(id)`
- FK `thesis_examiner_external_person_id_fkey`: `FOREIGN KEY (external_person_id) REFERENCES people.person(id)`
- FK `thesis_examiner_report_file_id_fkey`: `FOREIGN KEY (report_file_id) REFERENCES people.file_object(id)`
- FK `thesis_examiner_thesis_examiner_role_id_fkey`: `FOREIGN KEY (thesis_examiner_role_id) REFERENCES ref.thesis_examiner_role(id)`
- FK `thesis_examiner_thesis_id_fkey`: `FOREIGN KEY (thesis_id) REFERENCES research.thesis(id) ON DELETE CASCADE`
- CHECK `thesis_examiner_check`: `CHECK ((num_nonnulls(employee_id, external_person_id) = 1))`
- CHECK `thesis_examiner_check1`: `CHECK (((report_received_on IS NULL) = (examiner_recommendation_id IS NULL)))`
- CHECK `thesis_examiner_check2`: `CHECK (((report_received_on IS NULL) OR (report_received_on >= appointed_on)))`

<a id="researchviva"></a>
### `research.viva`

The viva voce and its outcome; only after every examiner report is in and none rejects.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `thesis_id` | uuid |  |  |  |
| `held_on` | date |  |  |  |
| `start_time` | time without time zone | yes |  |  |
| `end_time` | time without time zone | yes |  |  |
| `room_id` | uuid | yes |  |  |
| `examiner_recommendation_id` | smallint |  |  | EDUCATION |
| `remarks` | text | yes |  | EDUCATION |
| `approved_by_employee_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `viva_pkey`: `PRIMARY KEY (id)`
- UNIQUE `viva_thesis_id_key`: `UNIQUE (thesis_id)`
- FK `viva_approved_by_employee_id_fkey`: `FOREIGN KEY (approved_by_employee_id) REFERENCES people.employee(id)`
- FK `viva_examiner_recommendation_id_fkey`: `FOREIGN KEY (examiner_recommendation_id) REFERENCES ref.examiner_recommendation(id)`
- FK `viva_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- FK `viva_thesis_id_fkey`: `FOREIGN KEY (thesis_id) REFERENCES research.thesis(id) ON DELETE CASCADE`
- CHECK `viva_check`: `CHECK ((((start_time IS NULL) = (end_time IS NULL)) AND ((end_time IS NULL) OR (end_time > start_time))))`
- CHECK `viva_check1`: `CHECK (((room_id IS NULL) OR (start_time IS NOT NULL)))`

## Schema `facility` — Resource & facility management: occupancy ledger, bookings, assets, maintenance, guest house, parking, fleet, keys

<a id="facilityasset"></a>
### `facility.asset`

One physical asset, fixed or portable: tag, type, location room, custodian unit, purchase / warranty, condition, condemnation; portable assets are bookable and loanable.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `asset_tag` | citext |  |  |  |
| `asset_type_id` | smallint |  |  |  |
| `name` | text |  |  |  |
| `room_id` | uuid | yes |  |  |
| `custodian_org_unit_id` | uuid |  |  |  |
| `is_portable` | boolean |  | `false` |  |
| `purchased_on` | date | yes |  |  |
| `purchase_cost` | numeric(12,2) | yes |  |  |
| `warranty_until` | date | yes |  |  |
| `asset_condition_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `condemned_on` | date | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `asset_pkey`: `PRIMARY KEY (id)`
- UNIQUE `asset_asset_tag_key`: `UNIQUE (asset_tag)`
- FK `asset_asset_condition_id_fkey`: `FOREIGN KEY (asset_condition_id) REFERENCES ref.asset_condition(id)`
- FK `asset_asset_type_id_fkey`: `FOREIGN KEY (asset_type_id) REFERENCES ref.asset_type(id)`
- FK `asset_custodian_org_unit_id_fkey`: `FOREIGN KEY (custodian_org_unit_id) REFERENCES org.org_unit(id)`
- FK `asset_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- CHECK `asset_asset_tag_check`: `CHECK ((asset_tag ~ '^[A-Za-z0-9/_-]{2,40}$'::citext))`
- CHECK `asset_check`: `CHECK (((condemned_on IS NULL) OR (NOT is_active)))`
- CHECK `asset_check1`: `CHECK (((warranty_until IS NULL) OR (purchased_on IS NULL) OR (warranty_until >= purchased_on)))`
- CHECK `asset_name_check`: `CHECK ((btrim(name) <> ''::text))`
- CHECK `asset_purchase_cost_check`: `CHECK ((purchase_cost >= (0)::numeric))`
- INDEX `asset_custodian_idx`: `btree (custodian_org_unit_id)`
- INDEX `asset_room_idx`: `btree (room_id)`

<a id="facilityasset_hold"></a>
### `facility.asset_hold`

The asset ledger: one row per use of a portable asset (booking or loan); never two at once.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `asset_id` | uuid |  |  |  |
| `during` | tsrange |  |  |  |
| `booking_asset_id` | uuid | yes |  |  |
| `asset_loan_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `asset_hold_pkey`: `PRIMARY KEY (id)`
- FK `asset_hold_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id)`
- FK `asset_hold_asset_loan_id_fkey`: `FOREIGN KEY (asset_loan_id) REFERENCES facility.asset_loan(id) ON DELETE CASCADE`
- FK `asset_hold_booking_asset_id_fkey`: `FOREIGN KEY (booking_asset_id) REFERENCES facility.booking_asset(id) ON DELETE CASCADE`
- CHECK `asset_hold_check`: `CHECK ((num_nonnulls(booking_asset_id, asset_loan_id) = 1))`
- CHECK `asset_hold_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- EXCLUDE `asset_hold_no_overlap`: `EXCLUDE USING gist (asset_id WITH =, during WITH &&)`

<a id="facilityasset_loan"></a>
### `facility.asset_loan`

A portable asset lent to a person by the custodian's staff for a period; early return frees it.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `asset_id` | uuid |  |  |  |
| `borrower_person_id` | uuid |  |  |  |
| `on_behalf_org_unit_id` | uuid | yes |  |  |
| `during` | tsrange |  |  |  |
| `issued_by_account_id` | uuid |  |  |  |
| `returned_at` | timestamp with time zone | yes |  |  |
| `returned_to_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `asset_loan_pkey`: `PRIMARY KEY (id)`
- FK `asset_loan_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id)`
- FK `asset_loan_borrower_person_id_fkey`: `FOREIGN KEY (borrower_person_id) REFERENCES people.person(id)`
- FK `asset_loan_issued_by_account_id_fkey`: `FOREIGN KEY (issued_by_account_id) REFERENCES iam.user_account(id)`
- FK `asset_loan_on_behalf_org_unit_id_fkey`: `FOREIGN KEY (on_behalf_org_unit_id) REFERENCES org.org_unit(id)`
- FK `asset_loan_returned_to_account_id_fkey`: `FOREIGN KEY (returned_to_account_id) REFERENCES iam.user_account(id)`
- CHECK `asset_loan_check`: `CHECK (((returned_at IS NULL) = (returned_to_account_id IS NULL)))`
- CHECK `asset_loan_check1`: `CHECK (((returned_at IS NULL) OR ((returned_at)::timestamp without time zone >= lower(during))))`
- CHECK `asset_loan_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- INDEX `asset_loan_asset_idx`: `btree (asset_id)`
- INDEX `asset_loan_borrower_idx`: `btree (borrower_person_id)`

<a id="facilityblackout"></a>
### `facility.blackout`

No bookings of a kind of room or of a building for a period (exam weeks, lockdown); institutional holds are unaffected.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_type_id` | smallint | yes |  |  |
| `building_id` | uuid | yes |  |  |
| `during` | tsrange |  |  |  |
| `reason` | text |  |  |  |
| `created_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `blackout_pkey`: `PRIMARY KEY (id)`
- FK `blackout_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id) ON DELETE CASCADE`
- FK `blackout_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- FK `blackout_room_type_id_fkey`: `FOREIGN KEY (room_type_id) REFERENCES ref.room_type(id)`
- CHECK `blackout_check`: `CHECK ((num_nonnulls(room_type_id, building_id) >= 1))`
- CHECK `blackout_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `blackout_reason_check`: `CHECK ((btrim(reason) <> ''::text))`

<a id="facilitybooking_asset"></a>
### `facility.booking_asset`

A portable asset booked with a room booking (held for the blocked span, released with it).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `booking_occurrence_id` | uuid |  |  |  |
| `asset_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_asset_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_asset_booking_occurrence_id_asset_id_key`: `UNIQUE (booking_occurrence_id, asset_id)`
- FK `booking_asset_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id)`
- FK `booking_asset_booking_occurrence_id_fkey`: `FOREIGN KEY (booking_occurrence_id) REFERENCES facility.booking_occurrence(id) ON DELETE CASCADE`

<a id="facilitybooking_group"></a>
### `facility.booking_group`

Bookings made together (N rooms × M dates, a recurring series): one GRP-YYYY-NNNN for the requester, one request per custodian. Only the reference: requester, title and event are the requests' (v_booking_summary).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `group_ref` | citext |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_group_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_group_group_ref_key`: `UNIQUE (group_ref)`
- CHECK `booking_group_group_ref_check`: `CHECK ((group_ref ~ '^GRP-[0-9]{4}-[0-9]{4,}$'::citext))`

<a id="facilitybooking_occurrence"></a>
### `facility.booking_occurrence`

One room for one span of a request: a tentative hold from submission; check-in, cancellation (self until the cut-off, custodian any time); never moved.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `booking_request_id` | uuid |  |  |  |
| `room_id` | uuid |  |  |  |
| `during` | tsrange |  |  |  |
| `setup_minutes` | smallint |  |  |  |
| `teardown_minutes` | smallint |  |  |  |
| `checked_in_at` | timestamp with time zone | yes |  |  |
| `checked_in_by_account_id` | uuid | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `booking_cancel_reason_id` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_occurrence_pkey`: `PRIMARY KEY (id)`
- FK `booking_occurrence_booking_cancel_reason_id_fkey`: `FOREIGN KEY (booking_cancel_reason_id) REFERENCES ref.booking_cancel_reason(id)`
- FK `booking_occurrence_booking_request_id_fkey`: `FOREIGN KEY (booking_request_id) REFERENCES facility.booking_request(id) ON DELETE CASCADE`
- FK `booking_occurrence_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `booking_occurrence_checked_in_by_account_id_fkey`: `FOREIGN KEY (checked_in_by_account_id) REFERENCES iam.user_account(id)`
- FK `booking_occurrence_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- CHECK `booking_occurrence_check`: `CHECK (((checked_in_at IS NULL) = (checked_in_by_account_id IS NULL)))`
- CHECK `booking_occurrence_check1`: `CHECK ((((cancelled_at IS NULL) = (booking_cancel_reason_id IS NULL)) AND ((cancelled_by_account_id IS NULL) OR (cancelled_at IS NOT NULL))))`
- CHECK `booking_occurrence_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `booking_occurrence_setup_minutes_check`: `CHECK ((setup_minutes >= 0))`
- CHECK `booking_occurrence_teardown_minutes_check`: `CHECK ((teardown_minutes >= 0))`
- INDEX `booking_occurrence_request_idx`: `btree (booking_request_id)`
- INDEX `booking_occurrence_room_idx`: `gist (room_id, during)`

<a id="facilitybooking_policy"></a>
### `facility.booking_policy`

Booking rules per unit (nearest ancestor applies): minimum duration, advance window, self-cancel cut-off, no-show grace, check-in window — POLICY.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `org_unit_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange('2000-01-01'::date, NULL::date)` |  |
| `min_duration_minutes` | smallint |  |  |  |
| `max_advance_days` | smallint |  |  |  |
| `self_cancel_until_minutes_before` | smallint |  |  |  |
| `no_show_grace_minutes` | smallint |  |  |  |
| `checkin_opens_minutes_before` | smallint |  |  |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_policy_pkey`: `PRIMARY KEY (id)`
- FK `booking_policy_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- CHECK `booking_policy_checkin_opens_minutes_before_check`: `CHECK ((checkin_opens_minutes_before >= 0))`
- CHECK `booking_policy_max_advance_days_check`: `CHECK ((max_advance_days > 0))`
- CHECK `booking_policy_min_duration_minutes_check`: `CHECK ((min_duration_minutes > 0))`
- CHECK `booking_policy_no_show_grace_minutes_check`: `CHECK ((no_show_grace_minutes >= 0))`
- CHECK `booking_policy_self_cancel_until_minutes_before_check`: `CHECK ((self_cancel_until_minutes_before >= 0))`
- CHECK `booking_policy_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `booking_policy_one_per_scope`: `EXCLUDE USING gist (COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`

<a id="facilitybooking_request"></a>
### `facility.booking_request`

One booking request (who, for which unit, purpose, headcount) approved through a ROOM_BOOKING round owned by the custodian; immutable; a reschedule is a ROOM_BOOKING_CHANGE naming the occurrence it replaces.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `booking_group_id` | uuid | yes |  |  |
| `event_request_id` | uuid | yes |  |  |
| `requester_person_id` | uuid |  |  |  |
| `on_behalf_org_unit_id` | uuid | yes |  |  |
| `booking_purpose_id` | smallint |  |  |  |
| `title` | text |  |  |  |
| `expected_headcount` | integer | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `instance_id` | uuid | yes |  |  |
| `rescheduled_from_occurrence_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `booking_request_instance_id_key`: `UNIQUE (instance_id)`
- FK `booking_request_booking_group_id_fkey`: `FOREIGN KEY (booking_group_id) REFERENCES facility.booking_group(id)`
- FK `booking_request_booking_purpose_id_fkey`: `FOREIGN KEY (booking_purpose_id) REFERENCES ref.booking_purpose(id)`
- FK `booking_request_event_request_id_fkey`: `FOREIGN KEY (event_request_id) REFERENCES facility.event_request(id)`
- FK `booking_request_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `booking_request_on_behalf_org_unit_id_fkey`: `FOREIGN KEY (on_behalf_org_unit_id) REFERENCES org.org_unit(id)`
- FK `booking_request_requester_person_id_fkey`: `FOREIGN KEY (requester_person_id) REFERENCES people.person(id)`
- FK `booking_request_rescheduled_from_occurrence_id_fkey`: `FOREIGN KEY (rescheduled_from_occurrence_id) REFERENCES facility.booking_occurrence(id)`
- CHECK `booking_request_check`: `CHECK (((instance_id IS NOT NULL) OR (event_request_id IS NOT NULL)))`
- CHECK `booking_request_expected_headcount_check`: `CHECK ((expected_headcount > 0))`
- CHECK `booking_request_title_check`: `CHECK ((btrim(title) <> ''::text))`
- INDEX `booking_request_event_idx`: `btree (event_request_id)`
- INDEX `booking_request_group_idx`: `btree (booking_group_id)`
- INDEX `booking_request_requester_idx`: `btree (requester_person_id)`

<a id="facilitybooking_requirement"></a>
### `facility.booking_requirement`

Room features a request needs (checked against the room's facilities).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `booking_request_id` | uuid |  |  |  |
| `room_feature_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `booking_requirement_pkey`: `PRIMARY KEY (booking_request_id, room_feature_id)`
- FK `booking_requirement_booking_request_id_fkey`: `FOREIGN KEY (booking_request_id) REFERENCES facility.booking_request(id) ON DELETE CASCADE`
- FK `booking_requirement_room_feature_id_fkey`: `FOREIGN KEY (room_feature_id) REFERENCES ref.room_feature(id)`

<a id="facilitybooking_restriction"></a>
### `facility.booking_restriction`

A person barred from a kind of resource (or all) for a period — disciplinary personal data, hidden from analytics.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `facility_resource_kind_id` | smallint | yes |  |  |
| `booking_restriction_reason_id` | smallint |  |  |  |
| `note` | text | yes |  | DISCIPLINARY (sensitive) |
| `valid` | tstzrange |  | `tstzrange(now(), NULL::timestamp with time zone)` |  |
| `imposed_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `booking_restriction_pkey`: `PRIMARY KEY (id)`
- FK `booking_restriction_booking_restriction_reason_id_fkey`: `FOREIGN KEY (booking_restriction_reason_id) REFERENCES ref.booking_restriction_reason(id)`
- FK `booking_restriction_facility_resource_kind_id_fkey`: `FOREIGN KEY (facility_resource_kind_id) REFERENCES ref.facility_resource_kind(id)`
- FK `booking_restriction_imposed_by_account_id_fkey`: `FOREIGN KEY (imposed_by_account_id) REFERENCES iam.user_account(id)`
- FK `booking_restriction_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `booking_restriction_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `booking_restriction_no_overlap`: `EXCLUDE USING gist (person_id WITH =, COALESCE((facility_resource_kind_id)::integer, 0) WITH =, valid WITH &&)`

<a id="facilitycustody"></a>
### `facility.custody`

Which org unit manages a room / floor / building / campus for a period (most specific wins); the custodian owns the booking rounds for the space.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid | yes |  |  |
| `floor_id` | uuid | yes |  |  |
| `building_id` | uuid | yes |  |  |
| `campus_id` | uuid | yes |  |  |
| `org_unit_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `custody_pkey`: `PRIMARY KEY (id)`
- FK `custody_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id) ON DELETE CASCADE`
- FK `custody_campus_id_fkey`: `FOREIGN KEY (campus_id) REFERENCES org.campus(id) ON DELETE CASCADE`
- FK `custody_floor_id_fkey`: `FOREIGN KEY (floor_id) REFERENCES org.floor(id) ON DELETE CASCADE`
- FK `custody_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `custody_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `custody_check`: `CHECK ((num_nonnulls(room_id, floor_id, building_id, campus_id) = 1))`
- CHECK `custody_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `custody_one_per_target`: `EXCLUDE USING gist (COALESCE(room_id, floor_id, building_id, campus_id) WITH =, valid WITH &&)`

<a id="facilitydriver"></a>
### `facility.driver`

A driver: an employee with a driving-licence identity document (class, expiry) — the licence is never copied.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `employee_id` | uuid |  |  |  |
| `licence_document_id` | uuid |  |  | GOVERNMENT_ID (sensitive) |
| `licence_class_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `driver_pkey`: `PRIMARY KEY (id)`
- UNIQUE `driver_employee_id_key`: `UNIQUE (employee_id)`
- UNIQUE `driver_licence_document_id_key`: `UNIQUE (licence_document_id)`
- FK `driver_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `driver_licence_class_id_fkey`: `FOREIGN KEY (licence_class_id) REFERENCES ref.licence_class(id)`
- FK `driver_licence_document_id_fkey`: `FOREIGN KEY (licence_document_id) REFERENCES pii.person_identity_document(id)`

<a id="facilitydriver_unavailability"></a>
### `facility.driver_unavailability`

When a driver cannot drive (leave, sick, other duty, training).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `driver_id` | uuid |  |  |  |
| `driver_unavailability_reason_id` | smallint |  |  |  |
| `during` | tsrange |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `driver_unavailability_pkey`: `PRIMARY KEY (id)`
- FK `driver_unavailability_driver_id_fkey`: `FOREIGN KEY (driver_id) REFERENCES facility.driver(id) ON DELETE CASCADE`
- FK `driver_unavailability_driver_unavailability_reason_id_fkey`: `FOREIGN KEY (driver_unavailability_reason_id) REFERENCES ref.driver_unavailability_reason(id)`
- CHECK `driver_unavailability_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- EXCLUDE `driver_unavailability_no_overlap`: `EXCLUDE USING gist (driver_id WITH =, during WITH &&)`

<a id="facilityevent_request"></a>
### `facility.event_request`

An event as one package (EVENT_REQUEST round: organising unit head → university); its room / trip requests carry the event and go to their custodians once the event is approved.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `title` | text |  |  |  |
| `organiser_person_id` | uuid |  |  |  |
| `on_behalf_org_unit_id` | uuid |  |  |  |
| `event_kind_id` | smallint |  |  |  |
| `during` | tsrange |  |  |  |
| `expected_attendance` | integer | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `instance_id` | uuid |  |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_request_instance_id_key`: `UNIQUE (instance_id)`
- FK `event_request_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_request_event_kind_id_fkey`: `FOREIGN KEY (event_kind_id) REFERENCES ref.event_kind(id)`
- FK `event_request_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `event_request_on_behalf_org_unit_id_fkey`: `FOREIGN KEY (on_behalf_org_unit_id) REFERENCES org.org_unit(id)`
- FK `event_request_organiser_person_id_fkey`: `FOREIGN KEY (organiser_person_id) REFERENCES people.person(id)`
- CHECK `event_request_check`: `CHECK (((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL)))`
- CHECK `event_request_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `event_request_expected_attendance_check`: `CHECK ((expected_attendance > 0))`
- CHECK `event_request_title_check`: `CHECK ((btrim(title) <> ''::text))`
- INDEX `event_request_unit_idx`: `btree (on_behalf_org_unit_id)`

<a id="facilityguest_stay"></a>
### `facility.guest_stay`

A stay in a guest room by an internal or external guest hosted by a unit (GUEST_STAY round: host unit head → guest house); nights hold the room; charge derived from tariffs.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid |  |  |  |
| `guest_person_id` | uuid |  |  | IDENTITY |
| `guest_category_id` | smallint |  |  |  |
| `host_org_unit_id` | uuid |  |  |  |
| `host_employee_id` | uuid | yes |  |  |
| `nights` | daterange |  |  |  |
| `purpose` | text |  |  | IDENTITY |
| `headcount` | smallint |  | `1` |  |
| `instance_id` | uuid |  |  |  |
| `checked_in_at` | timestamp with time zone | yes |  |  |
| `checked_out_at` | timestamp with time zone | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `booking_cancel_reason_id` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `guest_stay_pkey`: `PRIMARY KEY (id)`
- UNIQUE `guest_stay_instance_id_key`: `UNIQUE (instance_id)`
- FK `guest_stay_booking_cancel_reason_id_fkey`: `FOREIGN KEY (booking_cancel_reason_id) REFERENCES ref.booking_cancel_reason(id)`
- FK `guest_stay_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `guest_stay_guest_category_id_fkey`: `FOREIGN KEY (guest_category_id) REFERENCES ref.guest_category(id)`
- FK `guest_stay_guest_person_id_fkey`: `FOREIGN KEY (guest_person_id) REFERENCES people.person(id)`
- FK `guest_stay_host_employee_id_fkey`: `FOREIGN KEY (host_employee_id) REFERENCES people.employee(id)`
- FK `guest_stay_host_org_unit_id_fkey`: `FOREIGN KEY (host_org_unit_id) REFERENCES org.org_unit(id)`
- FK `guest_stay_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `guest_stay_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- CHECK `guest_stay_check`: `CHECK (((checked_out_at IS NULL) OR (checked_out_at >= checked_in_at)))`
- CHECK `guest_stay_check1`: `CHECK ((((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL)) AND ((cancelled_at IS NULL) = (booking_cancel_reason_id IS NULL))))`
- CHECK `guest_stay_headcount_check`: `CHECK ((headcount > 0))`
- CHECK `guest_stay_nights_check`: `CHECK (((NOT isempty(nights)) AND (NOT lower_inf(nights)) AND (NOT upper_inf(nights))))`
- CHECK `guest_stay_purpose_check`: `CHECK ((btrim(purpose) <> ''::text))`
- INDEX `guest_stay_guest_idx`: `btree (guest_person_id)`
- INDEX `guest_stay_room_idx`: `gist (room_id, nights)`

<a id="facilityguest_tariff"></a>
### `facility.guest_tariff`

Nightly rate per guest category for a room or a room use, valid for a period — POLICY; complimentary categories pay nothing.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid | yes |  |  |
| `room_use_id` | smallint | yes |  |  |
| `guest_category_id` | smallint |  |  |  |
| `rate_per_night` | numeric(10,2) |  |  |  |
| `currency` | character(3) |  | `'INR'::bpchar` |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `guest_tariff_pkey`: `PRIMARY KEY (id)`
- FK `guest_tariff_guest_category_id_fkey`: `FOREIGN KEY (guest_category_id) REFERENCES ref.guest_category(id)`
- FK `guest_tariff_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- FK `guest_tariff_room_use_id_fkey`: `FOREIGN KEY (room_use_id) REFERENCES ref.room_use(id)`
- CHECK `guest_tariff_check`: `CHECK ((num_nonnulls(room_id, room_use_id) = 1))`
- CHECK `guest_tariff_currency_check`: `CHECK ((currency ~ '^[A-Z]{3}$'::text))`
- CHECK `guest_tariff_rate_per_night_check`: `CHECK ((rate_per_night >= (0)::numeric))`
- CHECK `guest_tariff_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `guest_tariff_one_per_target`: `EXCLUDE USING gist (COALESCE(room_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, COALESCE((room_use_id)::integer, 0) WITH =, guest_category_id WITH =, valid WITH &&)`

<a id="facilityhold_priority_rule"></a>
### `facility.hold_priority_rule`

Configurable pre-emption: which kind of use outranks which, optionally per room type and custody subtree; no rule = first come, first served.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `hold_type_id` | smallint |  |  |  |
| `outranks_hold_type_id` | smallint |  |  |  |
| `room_type_id` | smallint | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange('2000-01-01'::date, NULL::date)` |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `hold_priority_rule_pkey`: `PRIMARY KEY (id)`
- FK `hold_priority_rule_hold_type_id_fkey`: `FOREIGN KEY (hold_type_id) REFERENCES ref.hold_type(id)`
- FK `hold_priority_rule_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- FK `hold_priority_rule_outranks_hold_type_id_fkey`: `FOREIGN KEY (outranks_hold_type_id) REFERENCES ref.hold_type(id)`
- FK `hold_priority_rule_room_type_id_fkey`: `FOREIGN KEY (room_type_id) REFERENCES ref.room_type(id)`
- CHECK `hold_priority_rule_check`: `CHECK ((hold_type_id <> outranks_hold_type_id))`
- CHECK `hold_priority_rule_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `hold_priority_rule_one`: `EXCLUDE USING gist (hold_type_id WITH =, outranks_hold_type_id WITH =, COALESCE((room_type_id)::integer, 0) WITH =, COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`

<a id="facilitykey_issue"></a>
### `facility.key_issue`

The issue register: who holds which key from when (one holder at a time), due and actual return.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `key_item_id` | uuid |  |  |  |
| `holder_person_id` | uuid |  |  |  |
| `issued_by_account_id` | uuid |  |  |  |
| `issued_at` | timestamp with time zone |  | `now()` |  |
| `due_back_at` | timestamp with time zone | yes |  |  |
| `returned_at` | timestamp with time zone | yes |  |  |
| `returned_to_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `key_issue_pkey`: `PRIMARY KEY (id)`
- FK `key_issue_holder_person_id_fkey`: `FOREIGN KEY (holder_person_id) REFERENCES people.person(id)`
- FK `key_issue_issued_by_account_id_fkey`: `FOREIGN KEY (issued_by_account_id) REFERENCES iam.user_account(id)`
- FK `key_issue_key_item_id_fkey`: `FOREIGN KEY (key_item_id) REFERENCES facility.key_item(id)`
- FK `key_issue_returned_to_account_id_fkey`: `FOREIGN KEY (returned_to_account_id) REFERENCES iam.user_account(id)`
- CHECK `key_issue_check`: `CHECK (((returned_at IS NULL) = (returned_to_account_id IS NULL)))`
- CHECK `key_issue_check1`: `CHECK (((returned_at IS NULL) OR (returned_at >= issued_at)))`
- CHECK `key_issue_check2`: `CHECK (((due_back_at IS NULL) OR (due_back_at > issued_at)))`
- EXCLUDE `key_issue_one_holder`: `EXCLUDE USING gist (key_item_id WITH =, tstzrange(issued_at, returned_at, '[)'::text) WITH &&)`
- INDEX `key_issue_holder_idx`: `btree (holder_person_id)`

<a id="facilitykey_item"></a>
### `facility.key_item`

A key / access card opening a room, floor or building, kept by a custodian unit; lost / replaced handling.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `key_code` | citext |  |  |  |
| `key_kind_id` | smallint |  |  |  |
| `room_id` | uuid | yes |  |  |
| `floor_id` | uuid | yes |  |  |
| `building_id` | uuid | yes |  |  |
| `custodian_org_unit_id` | uuid |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `lost_reported_at` | timestamp with time zone | yes |  |  |
| `replaced_by_key_item_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `key_item_pkey`: `PRIMARY KEY (id)`
- UNIQUE `key_item_key_code_key`: `UNIQUE (key_code)`
- FK `key_item_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id) ON DELETE CASCADE`
- FK `key_item_custodian_org_unit_id_fkey`: `FOREIGN KEY (custodian_org_unit_id) REFERENCES org.org_unit(id)`
- FK `key_item_floor_id_fkey`: `FOREIGN KEY (floor_id) REFERENCES org.floor(id) ON DELETE CASCADE`
- FK `key_item_key_kind_id_fkey`: `FOREIGN KEY (key_kind_id) REFERENCES ref.key_kind(id)`
- FK `key_item_replaced_by_key_item_id_fkey`: `FOREIGN KEY (replaced_by_key_item_id) REFERENCES facility.key_item(id)`
- FK `key_item_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `key_item_check`: `CHECK ((num_nonnulls(room_id, floor_id, building_id) = 1))`
- CHECK `key_item_check1`: `CHECK (((replaced_by_key_item_id IS NULL) OR (NOT is_active)))`
- CHECK `key_item_check2`: `CHECK ((replaced_by_key_item_id IS DISTINCT FROM id))`
- CHECK `key_item_key_code_check`: `CHECK ((key_code ~ '^[A-Za-z0-9/_-]{2,40}$'::citext))`

<a id="facilitymaintenance_schedule"></a>
### `facility.maintenance_schedule`

Preventive maintenance: what is serviced how often; next due derived; closing a work order of the schedule marks it done.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `asset_id` | uuid | yes |  |  |
| `room_id` | uuid | yes |  |  |
| `maintenance_type_id` | smallint |  |  |  |
| `every` | interval |  |  |  |
| `last_done_on` | date | yes |  |  |
| `vendor_id` | uuid | yes |  |  |
| `note` | text | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `maintenance_schedule_pkey`: `PRIMARY KEY (id)`
- FK `maintenance_schedule_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id) ON DELETE CASCADE`
- FK `maintenance_schedule_maintenance_type_id_fkey`: `FOREIGN KEY (maintenance_type_id) REFERENCES ref.maintenance_type(id)`
- FK `maintenance_schedule_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- FK `maintenance_schedule_vendor_id_fkey`: `FOREIGN KEY (vendor_id) REFERENCES facility.vendor(id)`
- CHECK `maintenance_schedule_check`: `CHECK ((num_nonnulls(asset_id, room_id) = 1))`
- CHECK `maintenance_schedule_every_check`: `CHECK ((every > '00:00:00'::interval))`

<a id="facilityparking_permit"></a>
### `facility.parking_permit`

A person's vehicle in a parking zone for a period; a zone is never over-allocated; one permit per vehicle at a time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `zone_room_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `vehicle_registration_no` | citext |  |  | IDENTITY |
| `parking_permit_type_id` | smallint |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `parking_permit_pkey`: `PRIMARY KEY (id)`
- FK `parking_permit_parking_permit_type_id_fkey`: `FOREIGN KEY (parking_permit_type_id) REFERENCES ref.parking_permit_type(id)`
- FK `parking_permit_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- FK `parking_permit_zone_room_id_fkey`: `FOREIGN KEY (zone_room_id) REFERENCES org.room(id)`
- CHECK `parking_permit_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- CHECK `parking_permit_vehicle_registration_no_check`: `CHECK ((vehicle_registration_no ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$'::citext))`
- EXCLUDE `parking_permit_one_per_vehicle`: `EXCLUDE USING gist (upper((vehicle_registration_no)::text) WITH =, valid WITH &&)`
- INDEX `parking_permit_person_idx`: `btree (person_id)`
- INDEX `parking_permit_zone_idx`: `btree (zone_room_id)`

<a id="facilityroom_composition"></a>
### `facility.room_composition`

A combinable hall: the whole and its parts (one level, same building); a hold on either side shadows the other so the per-room EXCLUDE catches every combination.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `parent_room_id` | uuid |  |  |  |
| `part_room_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `room_composition_pkey`: `PRIMARY KEY (parent_room_id, part_room_id)`
- UNIQUE `room_composition_part_room_id_key`: `UNIQUE (part_room_id)`
- FK `room_composition_parent_room_id_fkey`: `FOREIGN KEY (parent_room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- FK `room_composition_part_room_id_fkey`: `FOREIGN KEY (part_room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `room_composition_check`: `CHECK ((parent_room_id <> part_room_id))`

<a id="facilityroom_hold"></a>
### `facility.room_hold`

THE occupancy ledger: one row per use of one room for one span, written only by triggers from every source; active holds on a room never overlap (gist EXCLUDE incl. buffers); shadows for composed rooms; displacement by higher-priority holds with reinstatement.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid |  |  |  |
| `hold_type_id` | smallint |  |  |  |
| `during` | tsrange |  |  |  |
| `setup_minutes` | smallint |  |  |  |
| `teardown_minutes` | smallint |  |  |  |
| `timetable_entry_id` | uuid | yes |  |  |
| `class_session_id` | uuid | yes |  |  |
| `exam_schedule_id` | uuid | yes |  |  |
| `viva_id` | uuid | yes |  |  |
| `convocation_id` | uuid | yes |  |  |
| `booking_occurrence_id` | uuid | yes |  |  |
| `guest_stay_id` | uuid | yes |  |  |
| `room_service_window_id` | uuid | yes |  |  |
| `parent_hold_id` | uuid | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `displaced_by_hold_id` | uuid | yes |  |  |
| `displaced_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `room_hold_pkey`: `PRIMARY KEY (id)`
- FK `room_hold_booking_occurrence_id_fkey`: `FOREIGN KEY (booking_occurrence_id) REFERENCES facility.booking_occurrence(id) ON DELETE CASCADE`
- FK `room_hold_class_session_id_fkey`: `FOREIGN KEY (class_session_id) REFERENCES academic.class_session(id) ON DELETE CASCADE`
- FK `room_hold_convocation_id_fkey`: `FOREIGN KEY (convocation_id) REFERENCES exam.convocation(id) ON DELETE CASCADE`
- FK `room_hold_displaced_by_hold_id_fkey`: `FOREIGN KEY (displaced_by_hold_id) REFERENCES facility.room_hold(id) DEFERRABLE INITIALLY DEFERRED`
- FK `room_hold_exam_schedule_id_room_id_fkey`: `FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE`
- FK `room_hold_guest_stay_id_fkey`: `FOREIGN KEY (guest_stay_id) REFERENCES facility.guest_stay(id) ON DELETE CASCADE`
- FK `room_hold_hold_type_id_fkey`: `FOREIGN KEY (hold_type_id) REFERENCES ref.hold_type(id)`
- FK `room_hold_parent_hold_id_fkey`: `FOREIGN KEY (parent_hold_id) REFERENCES facility.room_hold(id) ON DELETE CASCADE`
- FK `room_hold_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- FK `room_hold_room_service_window_id_fkey`: `FOREIGN KEY (room_service_window_id) REFERENCES facility.room_service_window(id) ON DELETE CASCADE`
- FK `room_hold_timetable_entry_id_fkey`: `FOREIGN KEY (timetable_entry_id) REFERENCES academic.timetable_entry(id) ON DELETE CASCADE`
- FK `room_hold_viva_id_fkey`: `FOREIGN KEY (viva_id) REFERENCES research.viva(id) ON DELETE CASCADE`
- CHECK `room_hold_displacement`: `CHECK (((is_active = (displaced_at IS NULL)) AND ((displaced_by_hold_id IS NULL) OR (displaced_at IS NOT NULL))))`
- CHECK `room_hold_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `room_hold_one_source`: `CHECK (((parent_hold_id IS NULL) = (num_nonnulls(timetable_entry_id, class_session_id, exam_schedule_id, viva_id, convocation_id, booking_occurrence_id, guest_stay_id, room_service_window_id) = 1)))`
- CHECK `room_hold_setup_minutes_check`: `CHECK ((setup_minutes >= 0))`
- CHECK `room_hold_teardown_minutes_check`: `CHECK ((teardown_minutes >= 0))`
- EXCLUDE `room_hold_no_overlap`: `EXCLUDE USING gist (room_id WITH =, facility.blocked(during, setup_minutes, teardown_minutes) WITH &&) WHERE (is_active)`
- INDEX `room_hold_displaced_by_idx`: `btree (displaced_by_hold_id)`
- INDEX `room_hold_guest_stay_idx`: `btree (guest_stay_id)`
- INDEX `room_hold_occurrence_idx`: `btree (booking_occurrence_id)`
- INDEX `room_hold_parent_idx`: `btree (parent_hold_id)`
- INDEX `room_hold_room_time_idx`: `gist (room_id, during)`
- INDEX `room_hold_session_idx`: `btree (class_session_id)`
- INDEX `room_hold_timetable_date_uq`: `btree (timetable_entry_id, lower(during)) WHERE (timetable_entry_id IS NOT NULL)`

<a id="facilityroom_reservation_rule"></a>
### `facility.room_reservation_rule`

Reserved / private rooms: while a rule covers a room (or its floor / building), only a requester matching a rule (position holder, unit member, permission holder, named person) may book it; revoke = close the validity.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid | yes |  |  |
| `floor_id` | uuid | yes |  |  |
| `building_id` | uuid | yes |  |  |
| `position_type_id` | smallint | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `permission_id` | integer | yes |  |  |
| `person_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `granted_by_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `room_reservation_rule_pkey`: `PRIMARY KEY (id)`
- FK `room_reservation_rule_building_id_fkey`: `FOREIGN KEY (building_id) REFERENCES org.building(id) ON DELETE CASCADE`
- FK `room_reservation_rule_floor_id_fkey`: `FOREIGN KEY (floor_id) REFERENCES org.floor(id) ON DELETE CASCADE`
- FK `room_reservation_rule_granted_by_account_id_fkey`: `FOREIGN KEY (granted_by_account_id) REFERENCES iam.user_account(id)`
- FK `room_reservation_rule_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- FK `room_reservation_rule_permission_id_fkey`: `FOREIGN KEY (permission_id) REFERENCES authz.permission(id)`
- FK `room_reservation_rule_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- FK `room_reservation_rule_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- FK `room_reservation_rule_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `room_reservation_rule_check`: `CHECK ((num_nonnulls(room_id, floor_id, building_id) = 1))`
- CHECK `room_reservation_rule_check1`: `CHECK ((num_nonnulls(position_type_id, org_unit_id, permission_id, person_id) = 1))`
- CHECK `room_reservation_rule_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- INDEX `room_reservation_rule_person_idx`: `btree (person_id)`
- INDEX `room_reservation_rule_room_idx`: `btree (room_id)`

<a id="facilityroom_service_window"></a>
### `facility.room_service_window`

Planned maintenance / cleaning of a room (a MAINTENANCE hold), optionally belonging to a work order that releases it when closed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid |  |  |  |
| `room_service_type_id` | smallint |  |  |  |
| `during` | tsrange |  |  |  |
| `note` | text | yes |  |  |
| `work_order_id` | uuid | yes |  |  |
| `created_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `room_service_window_pkey`: `PRIMARY KEY (id)`
- FK `room_service_window_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- FK `room_service_window_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- FK `room_service_window_room_service_type_id_fkey`: `FOREIGN KEY (room_service_type_id) REFERENCES ref.room_service_type(id)`
- FK `room_service_window_work_order_id_fkey`: `FOREIGN KEY (work_order_id) REFERENCES facility.work_order(id) ON DELETE SET NULL`
- CHECK `room_service_window_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- INDEX `room_service_window_room_idx`: `btree (room_id)`

<a id="facilityservice_contract"></a>
### `facility.service_contract`

An AMC / service contract with a vendor for an asset, an asset type or a room's installations.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `asset_id` | uuid | yes |  |  |
| `asset_type_id` | smallint | yes |  |  |
| `room_id` | uuid | yes |  |  |
| `vendor_id` | uuid |  |  |  |
| `contract_ref` | text |  |  |  |
| `valid` | daterange |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `service_contract_pkey`: `PRIMARY KEY (id)`
- FK `service_contract_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id) ON DELETE CASCADE`
- FK `service_contract_asset_type_id_fkey`: `FOREIGN KEY (asset_type_id) REFERENCES ref.asset_type(id)`
- FK `service_contract_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `service_contract_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- FK `service_contract_vendor_id_fkey`: `FOREIGN KEY (vendor_id) REFERENCES facility.vendor(id)`
- CHECK `service_contract_check`: `CHECK ((num_nonnulls(asset_id, asset_type_id, room_id) = 1))`
- CHECK `service_contract_contract_ref_check`: `CHECK ((btrim(contract_ref) <> ''::text))`
- CHECK `service_contract_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid)) AND (NOT upper_inf(valid))))`
- EXCLUDE `service_contract_one_per_target`: `EXCLUDE USING gist (COALESCE(asset_id, room_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, COALESCE((asset_type_id)::integer, 0) WITH =, vendor_id WITH =, valid WITH &&)`

<a id="facilityspace_allocation"></a>
### `facility.space_allocation`

Which org unit occupies a room for a period, with a share (shares of one room never exceed 100 % on a day) — the space inventory.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `room_id` | uuid |  |  |  |
| `org_unit_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `share_pct` | numeric(5,2) |  | `100` |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `space_allocation_pkey`: `PRIMARY KEY (id)`
- FK `space_allocation_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `space_allocation_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id) ON DELETE CASCADE`
- CHECK `space_allocation_share_pct_check`: `CHECK (((share_pct > (0)::numeric) AND (share_pct <= (100)::numeric)))`
- CHECK `space_allocation_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `space_allocation_no_overlap`: `EXCLUDE USING gist (room_id WITH =, org_unit_id WITH =, valid WITH &&)`
- INDEX `space_allocation_unit_idx`: `btree (org_unit_id)`

<a id="facilitytransport_policy"></a>
### `facility.transport_policy`

Transport rules per unit: urgent threshold, auto-approval deadline, alert lead, largest party, minimum notice — POLICY.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `org_unit_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange('2000-01-01'::date, NULL::date)` |  |
| `urgent_threshold` | interval |  |  |  |
| `auto_approve_before` | interval |  |  |  |
| `alert_before` | interval |  |  |  |
| `max_headcount` | smallint |  |  |  |
| `min_notice` | interval |  | `'00:00:00'::interval` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `transport_policy_pkey`: `PRIMARY KEY (id)`
- FK `transport_policy_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id) ON DELETE CASCADE`
- CHECK `transport_policy_alert_before_check`: `CHECK ((alert_before > '00:00:00'::interval))`
- CHECK `transport_policy_auto_approve_before_check`: `CHECK ((auto_approve_before > '00:00:00'::interval))`
- CHECK `transport_policy_max_headcount_check`: `CHECK (((max_headcount >= 1) AND (max_headcount <= 100)))`
- CHECK `transport_policy_urgent_threshold_check`: `CHECK ((urgent_threshold > '00:00:00'::interval))`
- CHECK `transport_policy_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `transport_policy_one_per_scope`: `EXCLUDE USING gist (COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`

<a id="facilitytrip"></a>
### `facility.trip`

What happened on the road: start (odometer, pickup photo), completion, closure by the transport office.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `trip_allocation_id` | uuid |  |  |  |
| `started_at` | timestamp with time zone | yes |  |  |
| `start_odometer_km` | integer | yes |  |  |
| `pickup_photo_file_id` | uuid | yes |  | PHOTO (sensitive) |
| `completed_at` | timestamp with time zone | yes |  |  |
| `end_odometer_km` | integer | yes |  |  |
| `closed_at` | timestamp with time zone | yes |  |  |
| `closed_by_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_trip_allocation_id_key`: `UNIQUE (trip_allocation_id)`
- FK `trip_closed_by_account_id_fkey`: `FOREIGN KEY (closed_by_account_id) REFERENCES iam.user_account(id)`
- FK `trip_pickup_photo_file_id_fkey`: `FOREIGN KEY (pickup_photo_file_id) REFERENCES people.file_object(id)`
- FK `trip_trip_allocation_id_fkey`: `FOREIGN KEY (trip_allocation_id) REFERENCES facility.trip_allocation(id)`
- CHECK `trip_check`: `CHECK (((started_at IS NULL) = (start_odometer_km IS NULL)))`
- CHECK `trip_check1`: `CHECK (((completed_at IS NULL) OR ((started_at IS NOT NULL) AND (completed_at >= started_at) AND (end_odometer_km IS NOT NULL))))`
- CHECK `trip_check2`: `CHECK (((end_odometer_km IS NULL) OR (end_odometer_km >= start_odometer_km)))`
- CHECK `trip_check3`: `CHECK ((((closed_at IS NULL) = (closed_by_account_id IS NULL)) AND ((closed_at IS NULL) OR (completed_at IS NOT NULL))))`
- CHECK `trip_end_odometer_km_check`: `CHECK ((end_odometer_km >= 0))`
- CHECK `trip_start_odometer_km_check`: `CHECK ((start_odometer_km >= 0))`

<a id="facilitytrip_alert"></a>
### `facility.trip_alert`

Alerts of the escalation job (auto-approved, unallocated soon, expired), one of a kind per request.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `trip_request_id` | uuid |  |  |  |
| `trip_alert_type_id` | smallint |  |  |  |
| `raised_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_alert_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_alert_trip_request_id_trip_alert_type_id_key`: `UNIQUE (trip_request_id, trip_alert_type_id)`
- FK `trip_alert_trip_alert_type_id_fkey`: `FOREIGN KEY (trip_alert_type_id) REFERENCES ref.trip_alert_type(id)`
- FK `trip_alert_trip_request_id_fkey`: `FOREIGN KEY (trip_request_id) REFERENCES facility.trip_request(id) ON DELETE CASCADE`

<a id="facilitytrip_allocation"></a>
### `facility.trip_allocation`

Dispatch of a driver (first) and a vehicle for a window covering the request; neither is ever double-booked; documents, licence, service windows and unavailability checked; driver token hashes; released = undone.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `trip_request_id` | uuid |  |  |  |
| `driver_id` | uuid |  |  |  |
| `vehicle_id` | uuid | yes |  |  |
| `during` | tsrange |  |  |  |
| `allocated_by_account_id` | uuid |  |  |  |
| `allocated_at` | timestamp with time zone |  | `now()` |  |
| `start_token_hash` | bytea | yes |  | CREDENTIAL (sensitive) |
| `complete_token_hash` | bytea | yes |  | CREDENTIAL (sensitive) |
| `released_at` | timestamp with time zone | yes |  |  |
| `released_by_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_allocation_pkey`: `PRIMARY KEY (id)`
- FK `trip_allocation_allocated_by_account_id_fkey`: `FOREIGN KEY (allocated_by_account_id) REFERENCES iam.user_account(id)`
- FK `trip_allocation_driver_id_fkey`: `FOREIGN KEY (driver_id) REFERENCES facility.driver(id)`
- FK `trip_allocation_released_by_account_id_fkey`: `FOREIGN KEY (released_by_account_id) REFERENCES iam.user_account(id)`
- FK `trip_allocation_trip_request_id_fkey`: `FOREIGN KEY (trip_request_id) REFERENCES facility.trip_request(id)`
- FK `trip_allocation_vehicle_id_fkey`: `FOREIGN KEY (vehicle_id) REFERENCES facility.vehicle(id)`
- CHECK `trip_allocation_check`: `CHECK (((released_at IS NULL) = (released_by_account_id IS NULL)))`
- CHECK `trip_allocation_complete_token_hash_check`: `CHECK ((octet_length(complete_token_hash) = 32))`
- CHECK `trip_allocation_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `trip_allocation_start_token_hash_check`: `CHECK ((octet_length(start_token_hash) = 32))`
- EXCLUDE `trip_allocation_driver_once`: `EXCLUDE USING gist (driver_id WITH =, during WITH &&) WHERE ((released_at IS NULL))`
- EXCLUDE `trip_allocation_vehicle_once`: `EXCLUDE USING gist (vehicle_id WITH =, during WITH &&) WHERE (((released_at IS NULL) AND (vehicle_id IS NOT NULL)))`
- INDEX `trip_allocation_one_live`: `btree (trip_request_id) WHERE (released_at IS NULL)`
- INDEX `trip_allocation_vehicle_idx`: `btree (vehicle_id)`

<a id="facilitytrip_allocation_request"></a>
### `facility.trip_allocation_request`

Pooling: another approved request riding on an existing allocation (inside its window, seats permitting).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `trip_allocation_id` | uuid |  |  |  |
| `trip_request_id` | uuid |  |  |  |
| `added_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_allocation_request_pkey`: `PRIMARY KEY (trip_allocation_id, trip_request_id)`
- UNIQUE `trip_allocation_request_trip_request_id_key`: `UNIQUE (trip_request_id)`
- FK `trip_allocation_request_added_by_account_id_fkey`: `FOREIGN KEY (added_by_account_id) REFERENCES iam.user_account(id)`
- FK `trip_allocation_request_trip_allocation_id_fkey`: `FOREIGN KEY (trip_allocation_id) REFERENCES facility.trip_allocation(id) ON DELETE CASCADE`
- FK `trip_allocation_request_trip_request_id_fkey`: `FOREIGN KEY (trip_request_id) REFERENCES facility.trip_request(id)`

<a id="facilitytrip_rating"></a>
### `facility.trip_rating`

Passenger → driver and driver → passengers ratings (1–5) after a completed trip.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `trip_id` | uuid |  |  |  |
| `rating_role_id` | smallint |  |  |  |
| `rated_by_person_id` | uuid |  |  |  |
| `rating` | smallint |  |  | EMPLOYMENT |
| `comment` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_rating_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_rating_trip_id_rating_role_id_rated_by_person_id_key`: `UNIQUE (trip_id, rating_role_id, rated_by_person_id)`
- FK `trip_rating_rated_by_person_id_fkey`: `FOREIGN KEY (rated_by_person_id) REFERENCES people.person(id)`
- FK `trip_rating_rating_role_id_fkey`: `FOREIGN KEY (rating_role_id) REFERENCES ref.rating_role(id)`
- FK `trip_rating_trip_id_fkey`: `FOREIGN KEY (trip_id) REFERENCES facility.trip(id) ON DELETE CASCADE`
- CHECK `trip_rating_rating_check`: `CHECK (((rating >= 1) AND (rating <= 5)))`

<a id="facilitytrip_request"></a>
### `facility.trip_request`

A request for a vehicle (who, unit, purpose, from → to with coordinates, departure → return, party size, contact number) approved through TRIP_REQUEST (unit head → transport) or TRIP_REQUEST_URGENT (transport); cancellable until allocated.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `requester_person_id` | uuid |  |  |  |
| `on_behalf_org_unit_id` | uuid |  |  |  |
| `trip_purpose_id` | smallint |  |  |  |
| `event_request_id` | uuid | yes |  |  |
| `during` | tsrange |  |  |  |
| `origin_text` | text |  |  | ADDRESS |
| `destination_text` | text |  |  | ADDRESS |
| `origin_lat` | numeric(9,6) | yes |  | ADDRESS |
| `origin_lon` | numeric(9,6) | yes |  | ADDRESS |
| `destination_lat` | numeric(9,6) | yes |  | ADDRESS |
| `destination_lon` | numeric(9,6) | yes |  | ADDRESS |
| `estimated_km` | numeric(7,1) | yes |  |  |
| `estimated_minutes` | integer | yes |  |  |
| `headcount` | smallint |  |  |  |
| `contact_phone` | character varying(16) |  |  | CONTACT |
| `note` | text | yes |  | IDENTITY |
| `instance_id` | uuid |  |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `trip_cancel_reason_id` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `trip_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `trip_request_instance_id_key`: `UNIQUE (instance_id)`
- FK `trip_request_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `trip_request_event_request_id_fkey`: `FOREIGN KEY (event_request_id) REFERENCES facility.event_request(id)`
- FK `trip_request_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `trip_request_on_behalf_org_unit_id_fkey`: `FOREIGN KEY (on_behalf_org_unit_id) REFERENCES org.org_unit(id)`
- FK `trip_request_requester_person_id_fkey`: `FOREIGN KEY (requester_person_id) REFERENCES people.person(id)`
- FK `trip_request_trip_cancel_reason_id_fkey`: `FOREIGN KEY (trip_cancel_reason_id) REFERENCES ref.trip_cancel_reason(id)`
- FK `trip_request_trip_purpose_id_fkey`: `FOREIGN KEY (trip_purpose_id) REFERENCES ref.trip_purpose(id)`
- CHECK `trip_request_check`: `CHECK ((((origin_lat IS NULL) = (origin_lon IS NULL)) AND ((destination_lat IS NULL) = (destination_lon IS NULL))))`
- CHECK `trip_request_check1`: `CHECK ((((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL)) AND ((cancelled_at IS NULL) = (trip_cancel_reason_id IS NULL))))`
- CHECK `trip_request_contact_phone_check`: `CHECK (((contact_phone)::text ~ '^\+[1-9][0-9]{7,14}$'::text))`
- CHECK `trip_request_destination_lat_check`: `CHECK (((destination_lat >= ('-90'::integer)::numeric) AND (destination_lat <= (90)::numeric)))`
- CHECK `trip_request_destination_lon_check`: `CHECK (((destination_lon >= ('-180'::integer)::numeric) AND (destination_lon <= (180)::numeric)))`
- CHECK `trip_request_destination_text_check`: `CHECK ((btrim(destination_text) <> ''::text))`
- CHECK `trip_request_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `trip_request_estimated_km_check`: `CHECK ((estimated_km >= (0)::numeric))`
- CHECK `trip_request_estimated_minutes_check`: `CHECK ((estimated_minutes >= 0))`
- CHECK `trip_request_headcount_check`: `CHECK (((headcount >= 1) AND (headcount <= 100)))`
- CHECK `trip_request_origin_lat_check`: `CHECK (((origin_lat >= ('-90'::integer)::numeric) AND (origin_lat <= (90)::numeric)))`
- CHECK `trip_request_origin_lon_check`: `CHECK (((origin_lon >= ('-180'::integer)::numeric) AND (origin_lon <= (180)::numeric)))`
- CHECK `trip_request_origin_text_check`: `CHECK ((btrim(origin_text) <> ''::text))`
- INDEX `trip_request_during_idx`: `gist (during)`
- INDEX `trip_request_requester_idx`: `btree (requester_person_id)`
- INDEX `trip_request_unit_idx`: `btree (on_behalf_org_unit_id)`

<a id="facilityvehicle"></a>
### `facility.vehicle`

A university vehicle: registration, type, fuel, passenger seats, minimum licence class, custodian (transport office).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `registration_no` | citext |  |  |  |
| `vehicle_type_id` | smallint |  |  |  |
| `fuel_type_id` | smallint |  |  |  |
| `make_model` | text |  |  |  |
| `seats` | smallint |  |  |  |
| `min_licence_class_id` | smallint |  |  |  |
| `custodian_org_unit_id` | uuid |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `retired_on` | date | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `vehicle_pkey`: `PRIMARY KEY (id)`
- UNIQUE `vehicle_registration_no_key`: `UNIQUE (registration_no)`
- FK `vehicle_custodian_org_unit_id_fkey`: `FOREIGN KEY (custodian_org_unit_id) REFERENCES org.org_unit(id)`
- FK `vehicle_fuel_type_id_fkey`: `FOREIGN KEY (fuel_type_id) REFERENCES ref.fuel_type(id)`
- FK `vehicle_min_licence_class_id_fkey`: `FOREIGN KEY (min_licence_class_id) REFERENCES ref.licence_class(id)`
- FK `vehicle_vehicle_type_id_fkey`: `FOREIGN KEY (vehicle_type_id) REFERENCES ref.vehicle_type(id)`
- CHECK `vehicle_check`: `CHECK (((retired_on IS NULL) OR (NOT is_active)))`
- CHECK `vehicle_make_model_check`: `CHECK ((btrim(make_model) <> ''::text))`
- CHECK `vehicle_registration_no_check`: `CHECK ((registration_no ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$'::citext))`
- CHECK `vehicle_seats_check`: `CHECK (((seats >= 1) AND (seats <= 100)))`

<a id="facilityvehicle_document"></a>
### `facility.vehicle_document`

RC / insurance / PUC / fitness … of a vehicle with validity; mandatory ones must cover every trip.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `vehicle_id` | uuid |  |  |  |
| `vehicle_document_type_id` | smallint |  |  |  |
| `document_no` | text |  |  |  |
| `valid` | daterange |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `vehicle_document_pkey`: `PRIMARY KEY (id)`
- FK `vehicle_document_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `vehicle_document_vehicle_document_type_id_fkey`: `FOREIGN KEY (vehicle_document_type_id) REFERENCES ref.vehicle_document_type(id)`
- FK `vehicle_document_vehicle_id_fkey`: `FOREIGN KEY (vehicle_id) REFERENCES facility.vehicle(id) ON DELETE CASCADE`
- CHECK `vehicle_document_document_no_check`: `CHECK ((btrim(document_no) <> ''::text))`
- CHECK `vehicle_document_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid)) AND (NOT upper_inf(valid))))`
- EXCLUDE `vehicle_document_one_current`: `EXCLUDE USING gist (vehicle_id WITH =, vehicle_document_type_id WITH =, valid WITH &&)`

<a id="facilityvehicle_service_window"></a>
### `facility.vehicle_service_window`

Servicing / repair / off-road periods of a vehicle (no allocation across them).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `vehicle_id` | uuid |  |  |  |
| `vehicle_service_type_id` | smallint |  |  |  |
| `during` | tsrange |  |  |  |
| `note` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `vehicle_service_window_pkey`: `PRIMARY KEY (id)`
- FK `vehicle_service_window_vehicle_id_fkey`: `FOREIGN KEY (vehicle_id) REFERENCES facility.vehicle(id) ON DELETE CASCADE`
- FK `vehicle_service_window_vehicle_service_type_id_fkey`: `FOREIGN KEY (vehicle_service_type_id) REFERENCES ref.vehicle_service_type(id)`
- CHECK `vehicle_service_window_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- EXCLUDE `vehicle_service_window_no_overlap`: `EXCLUDE USING gist (vehicle_id WITH =, during WITH &&)`

<a id="facilityvendor"></a>
### `facility.vendor`

Suppliers and service providers (AMC, hire, repairs).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `name` | text |  |  | IDENTITY |
| `contact_person_id` | uuid | yes |  | IDENTITY |
| `gstin` | citext | yes |  | IDENTITY |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `vendor_pkey`: `PRIMARY KEY (id)`
- UNIQUE `vendor_name_key`: `UNIQUE (name)`
- FK `vendor_contact_person_id_fkey`: `FOREIGN KEY (contact_person_id) REFERENCES people.person(id)`
- CHECK `vendor_gstin_check`: `CHECK ((gstin ~ '^[0-9]{2}[A-Z0-9]{13}$'::citext))`
- CHECK `vendor_name_check`: `CHECK ((btrim(name) <> ''::text))`

<a id="facilitywork_order"></a>
### `facility.work_order`

A reported fault / job on a room or asset (WO-YYYY-NNNNN): category, priority with SLA, reporter, assignee employee or vendor, cost; status derived from its events; final once closed.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `wo_no` | citext |  |  |  |
| `room_id` | uuid | yes |  |  |
| `asset_id` | uuid | yes |  |  |
| `work_order_category_id` | smallint |  |  |  |
| `work_order_priority_id` | smallint |  |  |  |
| `reported_by_person_id` | uuid |  |  |  |
| `description` | text |  |  | IDENTITY |
| `reported_at` | timestamp with time zone |  | `now()` |  |
| `assignee_employee_id` | uuid | yes |  |  |
| `vendor_id` | uuid | yes |  |  |
| `maintenance_schedule_id` | uuid | yes |  |  |
| `cost` | numeric(12,2) | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `work_order_pkey`: `PRIMARY KEY (id)`
- UNIQUE `work_order_wo_no_key`: `UNIQUE (wo_no)`
- FK `work_order_asset_id_fkey`: `FOREIGN KEY (asset_id) REFERENCES facility.asset(id)`
- FK `work_order_assignee_employee_id_fkey`: `FOREIGN KEY (assignee_employee_id) REFERENCES people.employee(id)`
- FK `work_order_maintenance_schedule_id_fkey`: `FOREIGN KEY (maintenance_schedule_id) REFERENCES facility.maintenance_schedule(id)`
- FK `work_order_reported_by_person_id_fkey`: `FOREIGN KEY (reported_by_person_id) REFERENCES people.person(id)`
- FK `work_order_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- FK `work_order_vendor_id_fkey`: `FOREIGN KEY (vendor_id) REFERENCES facility.vendor(id)`
- FK `work_order_work_order_category_id_fkey`: `FOREIGN KEY (work_order_category_id) REFERENCES ref.work_order_category(id)`
- FK `work_order_work_order_priority_id_fkey`: `FOREIGN KEY (work_order_priority_id) REFERENCES ref.work_order_priority(id)`
- CHECK `work_order_check`: `CHECK ((num_nonnulls(room_id, asset_id) >= 1))`
- CHECK `work_order_cost_check`: `CHECK ((cost >= (0)::numeric))`
- CHECK `work_order_description_check`: `CHECK ((btrim(description) <> ''::text))`
- CHECK `work_order_wo_no_check`: `CHECK ((wo_no ~ '^WO-[0-9]{4}-[0-9]{5,}$'::citext))`
- INDEX `work_order_asset_idx`: `btree (asset_id)`
- INDEX `work_order_assignee_idx`: `btree (assignee_employee_id)`
- INDEX `work_order_room_idx`: `btree (room_id)`

<a id="facilitywork_order_event"></a>
### `facility.work_order_event`

Append-only status history of a work order (who, when, note); closing releases its service windows.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `work_order_id` | uuid |  |  |  |
| `work_order_status_id` | smallint |  |  |  |
| `actor_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `occurred_at` | timestamp with time zone |  | `clock_timestamp()` |  |

**Constraints & indexes**

- PK `work_order_event_pkey`: `PRIMARY KEY (id)`
- UNIQUE `work_order_event_work_order_id_occurred_at_key`: `UNIQUE (work_order_id, occurred_at)`
- FK `work_order_event_actor_account_id_fkey`: `FOREIGN KEY (actor_account_id) REFERENCES iam.user_account(id)`
- FK `work_order_event_work_order_id_fkey`: `FOREIGN KEY (work_order_id) REFERENCES facility.work_order(id) ON DELETE CASCADE`
- FK `work_order_event_work_order_status_id_fkey`: `FOREIGN KEY (work_order_status_id) REFERENCES ref.work_order_status(id)`

## Schema `tms` — Helpdesk (TMS): tickets, category tree, escalation ladder, business-hours SLA, notices

<a id="tmshelpdesk_channel"></a>
### `tms.helpdesk_channel`

Notice channels with a kill switch each (old TMS_EMAIL_ENABLED).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `contact_channel_id` | smallint |  |  |  |
| `is_enabled` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `helpdesk_channel_pkey`: `PRIMARY KEY (contact_channel_id)`
- FK `helpdesk_channel_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`

<a id="tmshelpdesk_closure_type"></a>
### `tms.helpdesk_closure_type`

Academic-calendar event types that close the helpdesk (university-wide events only).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `calendar_event_type_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `helpdesk_closure_type_pkey`: `PRIMARY KEY (calendar_event_type_id)`
- FK `helpdesk_closure_type_calendar_event_type_id_fkey`: `FOREIGN KEY (calendar_event_type_id) REFERENCES ref.calendar_event_type(id)`

<a id="tmshelpdesk_day_override"></a>
### `tms.helpdesk_day_override`

A date that differs from the weekly pattern and the calendar: open (on a holiday or weekly off) or closed, with the reason and optional hours.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `on_date` | date |  |  |  |
| `is_working` | boolean |  |  |  |
| `day_start` | time without time zone | yes |  |  |
| `day_end` | time without time zone | yes |  |  |
| `note` | text |  |  |  |
| `created_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `helpdesk_day_override_pkey`: `PRIMARY KEY (on_date)`
- FK `helpdesk_day_override_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `helpdesk_day_override_check`: `CHECK (((day_start IS NULL) = (day_end IS NULL)))`
- CHECK `helpdesk_day_override_check1`: `CHECK ((day_end > day_start))`
- CHECK `helpdesk_day_override_check2`: `CHECK ((is_working OR (day_start IS NULL)))`
- CHECK `helpdesk_day_override_note_check`: `CHECK (((length(btrim(note)) >= 3) AND (length(btrim(note)) <= 256)))`

<a id="tmshelpdesk_declaration"></a>
### `tms.helpdesk_declaration`

Dated declaration a requester accepts when raising a ticket of a domain; the ticket records the version.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `ticket_domain_id` | smallint |  |  |  |
| `body` | text |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `helpdesk_declaration_pkey`: `PRIMARY KEY (id)`
- FK `helpdesk_declaration_ticket_domain_id_fkey`: `FOREIGN KEY (ticket_domain_id) REFERENCES ref.tms_ticket_domain(id)`
- CHECK `helpdesk_declaration_body_check`: `CHECK (((length(btrim(body)) >= 10) AND (length(btrim(body)) <= 4000)))`
- CHECK `helpdesk_declaration_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `helpdesk_declaration_one_at_a_time`: `EXCLUDE USING gist (ticket_domain_id WITH =, valid WITH &&)`

<a id="tmshelpdesk_file_type"></a>
### `tms.helpdesk_file_type`

File types a ticket may carry (POLICY; old: PDF / PNG / JPEG); the size limit is helpdesk_setting.max_file_bytes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `mime_type` | text |  |  |  |

**Constraints & indexes**

- PK `helpdesk_file_type_pkey`: `PRIMARY KEY (mime_type)`
- CHECK `helpdesk_file_type_mime_type_check`: `CHECK ((mime_type ~ '^[a-z]+/[A-Za-z0-9.+-]+$'::text))`

<a id="tmshelpdesk_setting"></a>
### `tms.helpdesk_setting`

Helpdesk policy (one row): escalation, reopen / confirmation / rating windows, clarification reminders and expiry, referral rules, attachments, Student TMS switch, office hours.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | boolean |  | `true` |  |
| `auto_escalation_enabled` | boolean |  | `true` |  |
| `reopen_window_days` | smallint |  | `7` |  |
| `max_reopens` | smallint |  | `2` |  |
| `confirmation_window_days` | smallint |  | `3` |  |
| `rating_window_days` | smallint |  | `15` |  |
| `clarification_reminder_days` | smallint | yes | `2` |  |
| `clarification_expiry_days` | smallint | yes | `7` |  |
| `requester_may_escalate_overdue` | boolean |  | `true` |  |
| `requester_refer_after_days` | smallint | yes | `7` |  |
| `auto_refer_after_days` | smallint | yes | `15` |  |
| `max_files_per_event` | smallint |  | `5` |  |
| `max_file_bytes` | integer |  | `5242880` |  |
| `duplicate_window_seconds` | smallint |  | `10` |  |
| `sla_warning_percent` | smallint |  | `25` |  |
| `on_hold_enabled` | boolean |  | `true` |  |
| `max_hold_days` | smallint | yes | `10` |  |
| `notice_max_attempts` | smallint |  | `3` |  |
| `scheduler_office_hours_only` | boolean |  | `true` |  |
| `office_hours_only` | boolean |  | `true` |  |
| `count_holidays` | boolean |  | `false` |  |
| `student_tms_enabled` | boolean |  | `false` |  |
| `student_tms_locked` | boolean |  | `false` |  |
| `employee_tms_enabled` | boolean |  | `true` |  |
| `business_day_start` | time without time zone |  | `'09:00:00'::time without time zone` |  |
| `business_day_end` | time without time zone |  | `'17:00:00'::time without time zone` |  |
| `time_zone` | text |  | `'Asia/Kolkata'::text` |  |
| `updated_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `helpdesk_setting_pkey`: `PRIMARY KEY (id)`
- FK `helpdesk_setting_updated_by_account_id_fkey`: `FOREIGN KEY (updated_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `helpdesk_setting_auto_refer_after_days_check`: `CHECK ((auto_refer_after_days >= 1))`
- CHECK `helpdesk_setting_check`: `CHECK ((business_day_end > business_day_start))`
- CHECK `helpdesk_setting_check1`: `CHECK (((clarification_expiry_days IS NULL) OR (clarification_reminder_days IS NULL) OR (clarification_expiry_days > clarification_reminder_days)))`
- CHECK `helpdesk_setting_clarification_expiry_days_check`: `CHECK ((clarification_expiry_days >= 1))`
- CHECK `helpdesk_setting_clarification_reminder_days_check`: `CHECK ((clarification_reminder_days >= 1))`
- CHECK `helpdesk_setting_confirmation_window_days_check`: `CHECK (((confirmation_window_days >= 1) AND (confirmation_window_days <= 30)))`
- CHECK `helpdesk_setting_duplicate_window_seconds_check`: `CHECK (((duplicate_window_seconds >= 0) AND (duplicate_window_seconds <= 3600)))`
- CHECK `helpdesk_setting_id_check`: `CHECK (id)`
- CHECK `helpdesk_setting_max_file_bytes_check`: `CHECK ((max_file_bytes > 0))`
- CHECK `helpdesk_setting_max_files_per_event_check`: `CHECK (((max_files_per_event >= 0) AND (max_files_per_event <= 20)))`
- CHECK `helpdesk_setting_max_hold_days_check`: `CHECK ((max_hold_days >= 1))`
- CHECK `helpdesk_setting_max_reopens_check`: `CHECK (((max_reopens >= 0) AND (max_reopens <= 10)))`
- CHECK `helpdesk_setting_notice_max_attempts_check`: `CHECK (((notice_max_attempts >= 1) AND (notice_max_attempts <= 20)))`
- CHECK `helpdesk_setting_rating_window_days_check`: `CHECK (((rating_window_days >= 1) AND (rating_window_days <= 90)))`
- CHECK `helpdesk_setting_reopen_window_days_check`: `CHECK (((reopen_window_days >= 1) AND (reopen_window_days <= 90)))`
- CHECK `helpdesk_setting_requester_refer_after_days_check`: `CHECK ((requester_refer_after_days >= 0))`
- CHECK `helpdesk_setting_sla_warning_percent_check`: `CHECK (((sla_warning_percent >= 1) AND (sla_warning_percent <= 99)))`

<a id="tmshelpdesk_weekday"></a>
### `tms.helpdesk_weekday`

Days of the week the helpdesk works (ISO 1 = Monday), each with its own hours if they differ from the default.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `iso_dow` | smallint |  |  |  |
| `day_start` | time without time zone | yes |  |  |
| `day_end` | time without time zone | yes |  |  |

**Constraints & indexes**

- PK `helpdesk_weekday_pkey`: `PRIMARY KEY (iso_dow)`
- CHECK `helpdesk_weekday_check`: `CHECK (((day_start IS NULL) = (day_end IS NULL)))`
- CHECK `helpdesk_weekday_check1`: `CHECK ((day_end > day_start))`
- CHECK `helpdesk_weekday_iso_dow_check`: `CHECK (((iso_dow >= 1) AND (iso_dow <= 7)))`

<a id="tmskb_article"></a>
### `tms.kb_article`

Knowledge-base article shown before raising a ticket: on a category node (and every leaf below) or a whole domain, dated publication.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `ticket_domain_id` | smallint |  |  |  |
| `category_id` | uuid | yes |  |  |
| `title` | text |  |  |  |
| `body` | text |  |  |  |
| `published` | daterange | yes |  |  |
| `sort_order` | smallint |  | `0` |  |
| `written_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `kb_article_pkey`: `PRIMARY KEY (id)`
- FK `kb_article_category_id_fkey`: `FOREIGN KEY (category_id) REFERENCES tms.ticket_category(id) ON DELETE CASCADE`
- FK `kb_article_ticket_domain_id_fkey`: `FOREIGN KEY (ticket_domain_id) REFERENCES ref.tms_ticket_domain(id)`
- FK `kb_article_written_by_account_id_fkey`: `FOREIGN KEY (written_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `kb_article_body_check`: `CHECK (((length(btrim(body)) >= 10) AND (length(btrim(body)) <= 20000)))`
- CHECK `kb_article_published_check`: `CHECK (((published IS NULL) OR ((NOT isempty(published)) AND (NOT lower_inf(published)))))`
- CHECK `kb_article_title_check`: `CHECK (((length(btrim(title)) >= 3) AND (length(btrim(title)) <= 256)))`
- INDEX `kb_article_category_idx`: `btree (category_id)`

<a id="tmskb_feedback"></a>
### `tms.kb_feedback`

Anonymous "did this answer your question" per article — measures deflection without tracking anyone.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `kb_article_id` | uuid |  |  |  |
| `was_helpful` | boolean |  |  |  |
| `given_on` | date |  | `CURRENT_DATE` |  |

**Constraints & indexes**

- PK `kb_feedback_pkey`: `PRIMARY KEY (id)`
- FK `kb_feedback_kb_article_id_fkey`: `FOREIGN KEY (kb_article_id) REFERENCES tms.kb_article(id) ON DELETE CASCADE`
- INDEX `kb_feedback_article_idx`: `btree (kb_article_id)`

<a id="tmsnotice_opt_out"></a>
### `tms.notice_opt_out`

A person's opt-out from helpdesk notices on a channel; mandatory notices still go.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `account_id` | uuid |  |  | CONTACT |
| `contact_channel_id` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `notice_opt_out_pkey`: `PRIMARY KEY (account_id, contact_channel_id)`
- FK `notice_opt_out_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `notice_opt_out_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`

<a id="tmsredressal_forum"></a>
### `tms.redressal_forum`

A redressal forum: a committee type or a position, found nearest the requester's unit; time limit, first-action time and who is alerted, resolution required, default forward and appeal forum, compliance period, confidentiality.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `academic_body_type_id` | smallint | yes |  |  |
| `position_type_id` | smallint | yes |  |  |
| `anchor_org_unit_type_id` | smallint | yes |  |  |
| `decision_within_days` | smallint |  |  |  |
| `counts_office_days` | boolean |  | `false` |  |
| `needs_resolution` | boolean |  | `false` |  |
| `appeal_forum_id` | smallint | yes |  |  |
| `appeal_window_days` | smallint | yes |  |  |
| `compliance_within_days` | smallint | yes |  |  |
| `next_forum_id` | smallint | yes |  |  |
| `first_action_within_hours` | smallint | yes |  |  |
| `alert_position_type_id` | smallint | yes |  |  |
| `is_confidential` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `redressal_forum_pkey`: `PRIMARY KEY (id)`
- UNIQUE `redressal_forum_code_key`: `UNIQUE (code)`
- FK `redressal_forum_academic_body_type_id_fkey`: `FOREIGN KEY (academic_body_type_id) REFERENCES ref.academic_body_type(id)`
- FK `redressal_forum_alert_position_type_id_fkey`: `FOREIGN KEY (alert_position_type_id) REFERENCES org.position_type(id)`
- FK `redressal_forum_anchor_org_unit_type_id_fkey`: `FOREIGN KEY (anchor_org_unit_type_id) REFERENCES ref.org_unit_type(id)`
- FK `redressal_forum_appeal_forum_id_fkey`: `FOREIGN KEY (appeal_forum_id) REFERENCES tms.redressal_forum(id)`
- FK `redressal_forum_next_forum_id_fkey`: `FOREIGN KEY (next_forum_id) REFERENCES tms.redressal_forum(id)`
- FK `redressal_forum_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- CHECK `redressal_forum_appeal_window_days_check`: `CHECK ((appeal_window_days > 0))`
- CHECK `redressal_forum_check`: `CHECK ((num_nonnulls(academic_body_type_id, position_type_id) = 1))`
- CHECK `redressal_forum_check1`: `CHECK (((appeal_forum_id IS NULL) = (appeal_window_days IS NULL)))`
- CHECK `redressal_forum_check2`: `CHECK (((NOT needs_resolution) OR (academic_body_type_id IS NOT NULL)))`
- CHECK `redressal_forum_check3`: `CHECK ((appeal_forum_id IS DISTINCT FROM id))`
- CHECK `redressal_forum_check4`: `CHECK ((next_forum_id IS DISTINCT FROM id))`
- CHECK `redressal_forum_code_check`: `CHECK ((code ~ '^[A-Z][A-Z0-9_]{1,60}$'::citext))`
- CHECK `redressal_forum_compliance_within_days_check`: `CHECK ((compliance_within_days > 0))`
- CHECK `redressal_forum_decision_within_days_check`: `CHECK ((decision_within_days > 0))`
- CHECK `redressal_forum_first_action_within_hours_check`: `CHECK ((first_action_within_hours > 0))`
- CHECK `redressal_forum_label_check`: `CHECK ((btrim(label) <> ''::text))`

<a id="tmsticket"></a>
### `tms.ticket`

A raised ticket (TMS-YYYY-NNNNN): the facts as raised, immutable; state comes from tms.ticket_event.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `request_no` | citext |  |  |  |
| `requester_account_id` | uuid |  |  |  |
| `requester_org_unit_id` | uuid | yes |  |  |
| `raised_by_account_id` | uuid | yes |  |  |
| `intake_channel_id` | smallint |  |  |  |
| `raised_category_id` | uuid |  |  |  |
| `route_id` | smallint | yes |  |  |
| `priority_id` | smallint |  |  |  |
| `message_type_id` | smallint |  |  |  |
| `subject` | text |  |  | SUPPORT_REQUEST |
| `description` | text |  |  | SUPPORT_REQUEST |
| `relief_sought` | text | yes |  | SUPPORT_REQUEST |
| `incident_on` | date | yes |  | SUPPORT_REQUEST |
| `is_anonymous` | boolean |  | `false` |  |
| `contact_phone_id` | uuid | yes |  | CONTACT |
| `declaration_id` | uuid | yes |  |  |
| `requested_assignee_employee_id` | uuid | yes |  |  |
| `idempotency_key` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `clock_timestamp()` |  |

**Constraints & indexes**

- PK `ticket_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_request_no_key`: `UNIQUE (request_no)`
- UNIQUE `ticket_requester_account_id_idempotency_key_key`: `UNIQUE (requester_account_id, idempotency_key)`
- FK `ticket_contact_phone_id_fkey`: `FOREIGN KEY (contact_phone_id) REFERENCES pii.person_phone(id) ON DELETE SET NULL`
- FK `ticket_declaration_id_fkey`: `FOREIGN KEY (declaration_id) REFERENCES tms.helpdesk_declaration(id)`
- FK `ticket_intake_channel_id_fkey`: `FOREIGN KEY (intake_channel_id) REFERENCES ref.tms_intake_channel(id)`
- FK `ticket_message_type_id_fkey`: `FOREIGN KEY (message_type_id) REFERENCES ref.tms_message_type(id)`
- FK `ticket_priority_id_fkey`: `FOREIGN KEY (priority_id) REFERENCES ref.tms_priority(id)`
- FK `ticket_raised_by_account_id_fkey`: `FOREIGN KEY (raised_by_account_id) REFERENCES iam.user_account(id)`
- FK `ticket_raised_category_id_fkey`: `FOREIGN KEY (raised_category_id) REFERENCES tms.ticket_category(id)`
- FK `ticket_requested_assignee_employee_id_fkey`: `FOREIGN KEY (requested_assignee_employee_id) REFERENCES people.employee(id)`
- FK `ticket_requester_account_id_fkey`: `FOREIGN KEY (requester_account_id) REFERENCES iam.user_account(id)`
- FK `ticket_requester_org_unit_id_fkey`: `FOREIGN KEY (requester_org_unit_id) REFERENCES org.org_unit(id)`
- FK `ticket_route_id_fkey`: `FOREIGN KEY (route_id) REFERENCES tms.ticket_route(id)`
- CHECK `ticket_check`: `CHECK ((raised_by_account_id IS DISTINCT FROM requester_account_id))`
- CHECK `ticket_description_check`: `CHECK (((length(btrim(description)) >= 10) AND (length(btrim(description)) <= 5000)))`
- CHECK `ticket_idempotency_key_check`: `CHECK ((idempotency_key ~ '^[A-Za-z0-9_-]{8,64}$'::text))`
- CHECK `ticket_relief_sought_check`: `CHECK (((relief_sought IS NULL) OR ((length(btrim(relief_sought)) >= 3) AND (length(btrim(relief_sought)) <= 2000))))`
- CHECK `ticket_request_no_check`: `CHECK ((request_no ~ '^TMS-[0-9]{4}-[0-9]{5,}$'::citext))`
- CHECK `ticket_subject_check`: `CHECK (((length(btrim(subject)) >= 3) AND (length(btrim(subject)) <= 256)))`
- CONSTRAINT TRIGGER `trg_ticket_context_required`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`
- INDEX `ticket_raised_category_idx`: `btree (raised_category_id, created_at DESC)`
- INDEX `ticket_requester_idx`: `btree (requester_account_id, created_at DESC)`
- INDEX `ticket_requester_unit_idx`: `btree (requester_org_unit_id)`

<a id="tmsticket_academic_context"></a>
### `tms.ticket_academic_context`

Batch, term, semester (and course) of a ticket whose category needs academic context.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `ticket_id` | uuid |  |  |  |
| `batch_id` | uuid |  |  | EDUCATION |
| `academic_term_id` | uuid |  |  |  |
| `course_id` | uuid | yes |  | EDUCATION |
| `term_no` | smallint |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_academic_context_pkey`: `PRIMARY KEY (ticket_id)`
- FK `ticket_academic_context_academic_term_id_fkey`: `FOREIGN KEY (academic_term_id) REFERENCES academic.academic_term(id)`
- FK `ticket_academic_context_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id)`
- FK `ticket_academic_context_course_id_fkey`: `FOREIGN KEY (course_id) REFERENCES academic.course(id)`
- FK `ticket_academic_context_ticket_id_fkey`: `FOREIGN KEY (ticket_id) REFERENCES tms.ticket(id) ON DELETE CASCADE`
- CHECK `ticket_academic_context_term_no_check`: `CHECK ((term_no >= 1))`

<a id="tmsticket_category"></a>
### `tms.ticket_category`

Helpdesk category tree: KRA type → master → category → leaf; domain and responsible unit on the root, type on the master, priority on the leaf; route, forum and handling flags inherited.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `parent_id` | uuid | yes |  |  |
| `category_level_id` | smallint |  |  |  |
| `ticket_domain_id` | smallint | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `category_type_id` | smallint | yes |  |  |
| `priority_id` | smallint | yes |  |  |
| `academic_context_rule_id` | smallint | yes |  |  |
| `route_id` | smallint | yes |  |  |
| `redressal_forum_id` | smallint | yes |  |  |
| `direct_to_forum` | boolean | yes |  |  |
| `is_confidential` | boolean | yes |  |  |
| `allows_anonymous` | boolean | yes |  |  |
| `allows_respondent` | boolean | yes |  |  |
| `requires_incident_date` | boolean | yes |  |  |
| `allows_raising` | boolean | yes |  |  |
| `sla_hours` | smallint | yes |  |  |
| `first_response_hours` | smallint | yes |  |  |
| `sla_office_hours_only` | boolean | yes |  |  |
| `grievance_head_id` | smallint | yes |  |  |
| `name` | citext |  |  |  |
| `description` | text | yes |  |  |
| `sort_order` | smallint |  | `0` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_category_pkey`: `PRIMARY KEY (id)`
- FK `ticket_category_academic_context_rule_id_fkey`: `FOREIGN KEY (academic_context_rule_id) REFERENCES ref.tms_academic_context_rule(id)`
- FK `ticket_category_category_level_id_fkey`: `FOREIGN KEY (category_level_id) REFERENCES ref.tms_category_level(id)`
- FK `ticket_category_category_type_id_fkey`: `FOREIGN KEY (category_type_id) REFERENCES ref.tms_category_type(id)`
- FK `ticket_category_grievance_head_id_fkey`: `FOREIGN KEY (grievance_head_id) REFERENCES ref.tms_grievance_head(id)`
- FK `ticket_category_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `ticket_category_parent_id_fkey`: `FOREIGN KEY (parent_id) REFERENCES tms.ticket_category(id) ON DELETE RESTRICT`
- FK `ticket_category_priority_id_fkey`: `FOREIGN KEY (priority_id) REFERENCES ref.tms_priority(id)`
- FK `ticket_category_redressal_forum_id_fkey`: `FOREIGN KEY (redressal_forum_id) REFERENCES tms.redressal_forum(id)`
- FK `ticket_category_route_id_fkey`: `FOREIGN KEY (route_id) REFERENCES tms.ticket_route(id)`
- FK `ticket_category_ticket_domain_id_fkey`: `FOREIGN KEY (ticket_domain_id) REFERENCES ref.tms_ticket_domain(id)`
- CHECK `ticket_category_check`: `CHECK ((parent_id IS DISTINCT FROM id))`
- CHECK `ticket_category_check1`: `CHECK (((parent_id IS NULL) = (ticket_domain_id IS NOT NULL)))`
- CHECK `ticket_category_check2`: `CHECK (((parent_id IS NOT NULL) OR (org_unit_id IS NOT NULL)))`
- CHECK `ticket_category_check3`: `CHECK (((first_response_hours IS NULL) OR (sla_hours IS NULL) OR (first_response_hours <= sla_hours)))`
- CHECK `ticket_category_description_check`: `CHECK (((description IS NULL) OR (length(description) <= 512)))`
- CHECK `ticket_category_first_response_hours_check`: `CHECK ((first_response_hours > 0))`
- CHECK `ticket_category_name_check`: `CHECK (((btrim((name)::text) <> ''::text) AND (length((name)::text) <= 256)))`
- CHECK `ticket_category_sla_hours_check`: `CHECK ((sla_hours > 0))`
- INDEX `ticket_category_child_name_uq`: `btree (parent_id, name) WHERE (parent_id IS NOT NULL)`
- INDEX `ticket_category_parent_idx`: `btree (parent_id)`
- INDEX `ticket_category_root_name_uq`: `btree (ticket_domain_id, name) WHERE (parent_id IS NULL)`

<a id="tmsticket_category_handler"></a>
### `tms.ticket_category_handler`

Round-robin pool of handlers of a leaf category, in order, optionally serving one unit's requesters only.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `category_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `sort_order` | smallint |  | `0` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_category_handler_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_category_handler_uq`: `UNIQUE NULLS NOT DISTINCT (category_id, employee_id, org_unit_id)`
- FK `ticket_category_handler_category_id_fkey`: `FOREIGN KEY (category_id) REFERENCES tms.ticket_category(id) ON DELETE CASCADE`
- FK `ticket_category_handler_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `ticket_category_handler_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- INDEX `ticket_category_handler_employee_idx`: `btree (employee_id)`

<a id="tmsticket_category_owner"></a>
### `tms.ticket_category_owner`

Dated owner of a non-leaf category (category owner, master owner, KRA head) — reached by CATEGORY_OWNER route levels.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `category_id` | uuid |  |  |  |
| `employee_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_category_owner_pkey`: `PRIMARY KEY (id)`
- FK `ticket_category_owner_category_id_fkey`: `FOREIGN KEY (category_id) REFERENCES tms.ticket_category(id) ON DELETE CASCADE`
- FK `ticket_category_owner_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- CHECK `ticket_category_owner_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `ticket_category_owner_one_at_a_time`: `EXCLUDE USING gist (category_id WITH =, valid WITH &&)`
- INDEX `ticket_category_owner_employee_idx`: `btree (employee_id)`

<a id="tmsticket_event"></a>
### `tms.ticket_event`

Append-only timeline of a ticket; status, assignee, level, forum, SLA clock and rating are derived from it (v_ticket_state).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `ticket_id` | uuid |  |  |  |
| `event_type_id` | smallint |  |  |  |
| `actor_account_id` | uuid | yes |  |  |
| `occurred_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `remarks` | text | yes |  | SUPPORT_REQUEST |
| `assignee_employee_id` | uuid | yes |  |  |
| `assignment_basis_id` | smallint | yes |  |  |
| `level_id` | smallint | yes |  |  |
| `level_category_id` | uuid | yes |  |  |
| `forum_id` | smallint | yes |  |  |
| `academic_body_id` | uuid | yes |  |  |
| `category_id` | uuid | yes |  |  |
| `route_id` | smallint | yes |  |  |
| `priority_id` | smallint | yes |  |  |
| `related_ticket_id` | uuid | yes |  |  |
| `consulted_employee_id` | uuid | yes |  |  |
| `reply_to_event_id` | bigint | yes |  |  |
| `hold_reason_id` | smallint | yes |  |  |
| `redressal_outcome_id` | smallint | yes |  |  |
| `body_resolution_id` | uuid | yes |  |  |
| `due_at` | timestamp with time zone | yes |  |  |
| `sla_remaining_minutes` | integer | yes |  |  |
| `rating` | smallint | yes |  |  |

**Constraints & indexes**

- PK `ticket_event_pkey`: `PRIMARY KEY (id)`
- FK `ticket_event_academic_body_id_fkey`: `FOREIGN KEY (academic_body_id) REFERENCES academic.academic_body(id)`
- FK `ticket_event_actor_account_id_fkey`: `FOREIGN KEY (actor_account_id) REFERENCES iam.user_account(id)`
- FK `ticket_event_assignee_employee_id_fkey`: `FOREIGN KEY (assignee_employee_id) REFERENCES people.employee(id)`
- FK `ticket_event_assignment_basis_id_fkey`: `FOREIGN KEY (assignment_basis_id) REFERENCES ref.tms_assignment_basis(id)`
- FK `ticket_event_body_resolution_id_fkey`: `FOREIGN KEY (body_resolution_id) REFERENCES academic.body_resolution(id)`
- FK `ticket_event_category_id_fkey`: `FOREIGN KEY (category_id) REFERENCES tms.ticket_category(id)`
- FK `ticket_event_consulted_employee_id_fkey`: `FOREIGN KEY (consulted_employee_id) REFERENCES people.employee(id)`
- FK `ticket_event_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.tms_event_type(id)`
- FK `ticket_event_forum_id_fkey`: `FOREIGN KEY (forum_id) REFERENCES tms.redressal_forum(id)`
- FK `ticket_event_hold_reason_id_fkey`: `FOREIGN KEY (hold_reason_id) REFERENCES ref.tms_hold_reason(id)`
- FK `ticket_event_level_category_id_fkey`: `FOREIGN KEY (level_category_id) REFERENCES tms.ticket_category(id)`
- FK `ticket_event_level_id_fkey`: `FOREIGN KEY (level_id) REFERENCES tms.ticket_route_level(id)`
- FK `ticket_event_priority_id_fkey`: `FOREIGN KEY (priority_id) REFERENCES ref.tms_priority(id)`
- FK `ticket_event_redressal_outcome_id_fkey`: `FOREIGN KEY (redressal_outcome_id) REFERENCES ref.tms_redressal_outcome(id)`
- FK `ticket_event_related_ticket_id_fkey`: `FOREIGN KEY (related_ticket_id) REFERENCES tms.ticket(id)`
- FK `ticket_event_reply_to_event_id_fkey`: `FOREIGN KEY (reply_to_event_id) REFERENCES tms.ticket_event(id)`
- FK `ticket_event_route_id_fkey`: `FOREIGN KEY (route_id) REFERENCES tms.ticket_route(id)`
- FK `ticket_event_ticket_id_fkey`: `FOREIGN KEY (ticket_id) REFERENCES tms.ticket(id)`
- CHECK `ticket_event_check`: `CHECK (((assignee_employee_id IS NULL) OR (assignment_basis_id IS NOT NULL)))`
- CHECK `ticket_event_check1`: `CHECK ((related_ticket_id IS DISTINCT FROM ticket_id))`
- CHECK `ticket_event_rating_check`: `CHECK (((rating >= 1) AND (rating <= 5)))`
- CHECK `ticket_event_remarks_check`: `CHECK (((remarks IS NULL) OR (length(remarks) <= 5000)))`
- CHECK `ticket_event_sla_remaining_minutes_check`: `CHECK ((sla_remaining_minutes >= 0))`
- CONSTRAINT TRIGGER `trg_ticket_event_complete`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`
- INDEX `ticket_event_actor_idx`: `btree (actor_account_id)`
- INDEX `ticket_event_assignee_idx`: `btree (assignee_employee_id)`
- INDEX `ticket_event_body_idx`: `btree (academic_body_id) WHERE (academic_body_id IS NOT NULL)`
- INDEX `ticket_event_consulted_idx`: `btree (consulted_employee_id) WHERE (consulted_employee_id IS NOT NULL)`
- INDEX `ticket_event_level_idx`: `btree (level_category_id, id DESC)`
- INDEX `ticket_event_related_idx`: `btree (related_ticket_id) WHERE (related_ticket_id IS NOT NULL)`
- INDEX `ticket_event_reply_idx`: `btree (reply_to_event_id) WHERE (reply_to_event_id IS NOT NULL)`
- INDEX `ticket_event_ticket_idx`: `btree (ticket_id, id DESC)`

<a id="tmsticket_event_file"></a>
### `tms.ticket_event_file`

Files attached to a timeline entry (the ticket's own files are on its CREATED entry).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `ticket_event_id` | bigint |  |  |  |
| `file_object_id` | uuid |  |  | SUPPORT_REQUEST |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_event_file_pkey`: `PRIMARY KEY (ticket_event_id, file_object_id)`
- FK `ticket_event_file_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `ticket_event_file_ticket_event_id_fkey`: `FOREIGN KEY (ticket_event_id) REFERENCES tms.ticket_event(id)`
- INDEX `ticket_event_file_file_idx`: `btree (file_object_id)`

<a id="tmsticket_notice_rule"></a>
### `tms.ticket_notice_rule`

Which event notifies whom on which channel, per domain.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `event_type_id` | smallint |  |  |  |
| `notice_recipient_id` | smallint |  |  |  |
| `contact_channel_id` | smallint |  |  |  |
| `ticket_domain_id` | smallint | yes |  |  |
| `notify_actor` | boolean |  | `false` |  |
| `is_mandatory` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `ticket_notice_rule_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_notice_rule_uq`: `UNIQUE NULLS NOT DISTINCT (event_type_id, notice_recipient_id, contact_channel_id, ticket_domain_id)`
- FK `ticket_notice_rule_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`
- FK `ticket_notice_rule_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.tms_event_type(id)`
- FK `ticket_notice_rule_notice_recipient_id_fkey`: `FOREIGN KEY (notice_recipient_id) REFERENCES ref.tms_notice_recipient(id)`
- FK `ticket_notice_rule_ticket_domain_id_fkey`: `FOREIGN KEY (ticket_domain_id) REFERENCES ref.tms_ticket_domain(id)`

<a id="tmsticket_notification"></a>
### `tms.ticket_notification`

Delivery log of queued notices, one per event × recipient × channel (no addresses stored).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `ticket_event_id` | bigint |  |  |  |
| `recipient_account_id` | uuid |  |  |  |
| `contact_channel_id` | smallint |  |  |  |
| `notification_status_id` | smallint |  |  |  |
| `attempt_count` | smallint |  | `0` |  |
| `last_attempt_at` | timestamp with time zone | yes |  |  |
| `sent_at` | timestamp with time zone | yes |  |  |
| `error` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_notification_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_notification_ticket_event_id_recipient_account_id_co_key`: `UNIQUE (ticket_event_id, recipient_account_id, contact_channel_id)`
- FK `ticket_notification_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`
- FK `ticket_notification_notification_status_id_fkey`: `FOREIGN KEY (notification_status_id) REFERENCES ref.tms_notification_status(id)`
- FK `ticket_notification_recipient_account_id_fkey`: `FOREIGN KEY (recipient_account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `ticket_notification_ticket_event_id_fkey`: `FOREIGN KEY (ticket_event_id) REFERENCES tms.ticket_event(id)`
- CHECK `ticket_notification_attempt_count_check`: `CHECK ((attempt_count >= 0))`
- INDEX `ticket_notification_pending_idx`: `btree (notification_status_id, created_at)`
- INDEX `ticket_notification_recipient_idx`: `btree (recipient_account_id, created_at DESC)`

<a id="tmsticket_number_counter"></a>
### `tms.ticket_number_counter`

Last request number used per calendar year — TMS-YYYY-NNNNN restarts every year.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `year` | smallint |  |  |  |
| `last_no` | integer |  |  |  |

**Constraints & indexes**

- PK `ticket_number_counter_pkey`: `PRIMARY KEY (year)`
- CHECK `ticket_number_counter_last_no_check`: `CHECK ((last_no >= 1))`
- CHECK `ticket_number_counter_year_check`: `CHECK (((year >= 2000) AND (year <= 2999)))`

<a id="tmsticket_respondent"></a>
### `tms.ticket_respondent`

A person a complaint is against: never handles, hears or sees the ticket; kept on record.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `ticket_id` | uuid |  |  |  |
| `person_id` | uuid |  |  | GRIEVANCE_CASE (sensitive) |
| `added_by_account_id` | uuid |  |  |  |
| `added_at` | timestamp with time zone |  | `clock_timestamp()` |  |

**Constraints & indexes**

- PK `ticket_respondent_pkey`: `PRIMARY KEY (ticket_id, person_id)`
- FK `ticket_respondent_added_by_account_id_fkey`: `FOREIGN KEY (added_by_account_id) REFERENCES iam.user_account(id)`
- FK `ticket_respondent_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- FK `ticket_respondent_ticket_id_fkey`: `FOREIGN KEY (ticket_id) REFERENCES tms.ticket(id)`
- INDEX `ticket_respondent_person_idx`: `btree (person_id)`

<a id="tmsticket_route"></a>
### `tms.ticket_route`

A route: the ladder a ticket climbs (per domain), attached to category nodes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `ticket_domain_id` | smallint |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_route_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_route_code_key`: `UNIQUE (code)`
- FK `ticket_route_ticket_domain_id_fkey`: `FOREIGN KEY (ticket_domain_id) REFERENCES ref.tms_ticket_domain(id)`
- CHECK `ticket_route_code_check`: `CHECK ((code ~ '^[A-Z][A-Z0-9_]{1,60}$'::citext))`
- CHECK `ticket_route_label_check`: `CHECK ((btrim(label) <> ''::text))`

<a id="tmsticket_route_level"></a>
### `tms.ticket_route_level`

One level of a route: handler pool, category owner, mentor, manager, a position relative to the requester / category / a fixed unit, or a named person; optional SLA override; oversight.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `route_id` | smallint |  |  |  |
| `seq` | smallint |  |  |  |
| `label` | text |  |  |  |
| `route_level_kind_id` | smallint |  |  |  |
| `category_level_id` | smallint | yes |  |  |
| `position_type_id` | smallint | yes |  |  |
| `anchor_base_id` | smallint | yes |  |  |
| `anchor_org_unit_type_id` | smallint | yes |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `reporting_line_type_id` | smallint | yes |  |  |
| `manager_level` | smallint | yes |  |  |
| `employee_id` | uuid | yes |  |  |
| `sla_hours` | smallint | yes |  |  |
| `oversees` | boolean |  | `false` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `ticket_route_level_pkey`: `PRIMARY KEY (id)`
- UNIQUE `ticket_route_level_route_id_seq_key`: `UNIQUE (route_id, seq)`
- FK `ticket_route_level_anchor_base_id_fkey`: `FOREIGN KEY (anchor_base_id) REFERENCES ref.tms_anchor_base(id)`
- FK `ticket_route_level_anchor_org_unit_type_id_fkey`: `FOREIGN KEY (anchor_org_unit_type_id) REFERENCES ref.org_unit_type(id)`
- FK `ticket_route_level_category_level_id_fkey`: `FOREIGN KEY (category_level_id) REFERENCES ref.tms_category_level(id)`
- FK `ticket_route_level_employee_id_fkey`: `FOREIGN KEY (employee_id) REFERENCES people.employee(id)`
- FK `ticket_route_level_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `ticket_route_level_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- FK `ticket_route_level_reporting_line_type_id_fkey`: `FOREIGN KEY (reporting_line_type_id) REFERENCES ref.reporting_line_type(id)`
- FK `ticket_route_level_route_id_fkey`: `FOREIGN KEY (route_id) REFERENCES tms.ticket_route(id) ON DELETE CASCADE`
- FK `ticket_route_level_route_level_kind_id_fkey`: `FOREIGN KEY (route_level_kind_id) REFERENCES ref.tms_route_level_kind(id)`
- CHECK `ticket_route_level_label_check`: `CHECK ((btrim(label) <> ''::text))`
- CHECK `ticket_route_level_manager_level_check`: `CHECK (((manager_level >= 1) AND (manager_level <= 5)))`
- CHECK `ticket_route_level_seq_check`: `CHECK ((seq >= 1))`
- CHECK `ticket_route_level_sla_hours_check`: `CHECK ((sla_hours > 0))`
- INDEX `ticket_route_level_employee_idx`: `btree (employee_id)`

## Schema `events` — Events & clubs: clubs, proposals, events, registrations, teams, gate scans, certificates, feedback, club points

<a id="eventsclub"></a>
### `events.club`

A student club of any kind — academic, technical, cultural, sports … (ref.club_category) — under a school, a department, a central department such as student welfare, or the university: one row per org unit of type CLUB (code CLB-YYYY-NNNNN, category, objective, founding proposal); name, parent and activity are the org unit's; advisors are appointments; status derived (v_club).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `org_unit_id` | uuid |  |  |  |
| `club_code` | citext |  |  |  |
| `objective` | text |  |  |  |
| `club_category_id` | smallint |  |  |  |
| `club_proposal_id` | uuid | yes |  |  |
| `founded_on` | date |  | `CURRENT_DATE` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_pkey`: `PRIMARY KEY (org_unit_id)`
- UNIQUE `club_club_code_key`: `UNIQUE (club_code)`
- UNIQUE `club_club_proposal_id_key`: `UNIQUE (club_proposal_id)`
- FK `club_club_category_id_fkey`: `FOREIGN KEY (club_category_id) REFERENCES ref.club_category(id)`
- FK `club_club_proposal_id_fkey`: `FOREIGN KEY (club_proposal_id) REFERENCES events.club_proposal(id)`
- FK `club_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `club_club_code_check`: `CHECK ((club_code ~ '^CLB-[0-9]{4}-[0-9]{5,}$'::citext))`
- CHECK `club_objective_check`: `CHECK ((btrim(objective) <> ''::text))`

<a id="eventsclub_application"></a>
### `events.club_application`

A student's application to join a club and the advisors' decision; approval creates the membership.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_org_unit_id` | uuid |  |  |  |
| `student_id` | uuid |  |  |  |
| `note` | text | yes |  | IDENTITY |
| `applied_at` | timestamp with time zone |  | `now()` |  |
| `decided_at` | timestamp with time zone | yes |  |  |
| `decided_by_account_id` | uuid | yes |  |  |
| `is_approved` | boolean | yes |  |  |
| `decision_note` | text | yes |  | IDENTITY |

**Constraints & indexes**

- PK `club_application_pkey`: `PRIMARY KEY (id)`
- FK `club_application_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `club_application_decided_by_account_id_fkey`: `FOREIGN KEY (decided_by_account_id) REFERENCES iam.user_account(id)`
- FK `club_application_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`
- CHECK `club_application_check`: `CHECK ((((decided_at IS NULL) = (decided_by_account_id IS NULL)) AND ((decided_at IS NULL) = (is_approved IS NULL))))`
- INDEX `club_application_one_open`: `btree (club_org_unit_id, student_id) WHERE (decided_at IS NULL)`

<a id="eventsclub_calendar_item"></a>
### `events.club_calendar_item`

A club's planned activities for an academic year.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_org_unit_id` | uuid |  |  |  |
| `academic_year_id` | uuid |  |  |  |
| `activity` | text |  |  |  |
| `event_type_id` | smallint | yes |  |  |
| `tentative_on` | date |  |  |  |
| `target_group` | text | yes |  |  |
| `coordinator_student_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_calendar_item_pkey`: `PRIMARY KEY (id)`
- FK `club_calendar_item_academic_year_id_fkey`: `FOREIGN KEY (academic_year_id) REFERENCES academic.academic_year(id)`
- FK `club_calendar_item_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `club_calendar_item_coordinator_student_id_fkey`: `FOREIGN KEY (coordinator_student_id) REFERENCES people.student(id)`
- FK `club_calendar_item_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.event_type(id)`
- CHECK `club_calendar_item_activity_check`: `CHECK ((btrim(activity) <> ''::text))`

<a id="eventsclub_change_member"></a>
### `events.club_change_member`

Member lines of a club change request: who joins with which role, who leaves.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_change_request_id` | uuid |  |  |  |
| `student_id` | uuid |  |  |  |
| `is_removal` | boolean |  | `false` |  |
| `club_member_role_id` | smallint | yes |  |  |

**Constraints & indexes**

- PK `club_change_member_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_change_member_club_change_request_id_student_id_key`: `UNIQUE (club_change_request_id, student_id)`
- FK `club_change_member_club_change_request_id_fkey`: `FOREIGN KEY (club_change_request_id) REFERENCES events.club_change_request(id) ON DELETE CASCADE`
- FK `club_change_member_club_member_role_id_fkey`: `FOREIGN KEY (club_member_role_id) REFERENCES ref.club_member_role(id)`
- FK `club_change_member_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`
- CHECK `club_change_member_check`: `CHECK ((is_removal = (club_member_role_id IS NULL)))`

<a id="eventsclub_change_officer"></a>
### `events.club_change_officer`

Officer lines of a club change request: who takes which office (no student = the office falls vacant).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_change_request_id` | uuid |  |  |  |
| `club_office_id` | smallint |  |  |  |
| `student_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `club_change_officer_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_change_officer_club_change_request_id_club_office_id_key`: `UNIQUE (club_change_request_id, club_office_id)`
- FK `club_change_officer_club_change_request_id_fkey`: `FOREIGN KEY (club_change_request_id) REFERENCES events.club_change_request(id) ON DELETE CASCADE`
- FK `club_change_officer_club_office_id_fkey`: `FOREIGN KEY (club_office_id) REFERENCES ref.club_office(id)`
- FK `club_change_officer_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`
- INDEX `club_change_officer_student_uq`: `btree (club_change_request_id, student_id) WHERE (student_id IS NOT NULL)`

<a id="eventsclub_change_request"></a>
### `events.club_change_request`

A request to change a running club (name, objective, advisor, co-advisor, officers, members, or a recorded decision); a draft until submitted as a CLUB_CHANGE round; on approval the database applies the change.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `request_code` | citext |  |  |  |
| `club_org_unit_id` | uuid |  |  |  |
| `club_change_type_id` | smallint |  |  |  |
| `justification` | text |  |  | IDENTITY |
| `new_name` | text | yes |  |  |
| `new_objective` | text | yes |  |  |
| `new_employee_id` | uuid | yes |  |  |
| `new_club_category_id` | smallint | yes |  |  |
| `requested_by_account_id` | uuid |  |  |  |
| `instance_id` | uuid | yes |  |  |
| `applied_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_change_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_change_request_instance_id_key`: `UNIQUE (instance_id)`
- UNIQUE `club_change_request_request_code_key`: `UNIQUE (request_code)`
- FK `club_change_request_club_change_type_id_fkey`: `FOREIGN KEY (club_change_type_id) REFERENCES ref.club_change_type(id)`
- FK `club_change_request_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id)`
- FK `club_change_request_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `club_change_request_new_club_category_id_fkey`: `FOREIGN KEY (new_club_category_id) REFERENCES ref.club_category(id)`
- FK `club_change_request_new_employee_id_fkey`: `FOREIGN KEY (new_employee_id) REFERENCES people.employee(id)`
- FK `club_change_request_requested_by_account_id_fkey`: `FOREIGN KEY (requested_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `club_change_request_justification_check`: `CHECK ((btrim(justification) <> ''::text))`
- CHECK `club_change_request_new_name_check`: `CHECK ((btrim(new_name) <> ''::text))`
- CHECK `club_change_request_new_objective_check`: `CHECK ((btrim(new_objective) <> ''::text))`
- CHECK `club_change_request_request_code_check`: `CHECK ((request_code ~ '^CCR-[0-9]{4}-[0-9]{3,}$'::citext))`
- INDEX `club_change_request_club_idx`: `btree (club_org_unit_id)`

<a id="eventsclub_member"></a>
### `events.club_member`

Club membership over time with the member's role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_org_unit_id` | uuid |  |  |  |
| `student_id` | uuid |  |  |  |
| `club_member_role_id` | smallint |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `added_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_member_pkey`: `PRIMARY KEY (id)`
- FK `club_member_added_by_account_id_fkey`: `FOREIGN KEY (added_by_account_id) REFERENCES iam.user_account(id)`
- FK `club_member_club_member_role_id_fkey`: `FOREIGN KEY (club_member_role_id) REFERENCES ref.club_member_role(id)`
- FK `club_member_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `club_member_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`
- CHECK `club_member_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `club_member_once`: `EXCLUDE USING gist (club_org_unit_id WITH =, student_id WITH =, valid WITH &&)`
- INDEX `club_member_student_idx`: `btree (student_id)`

<a id="eventsclub_officer"></a>
### `events.club_officer`

Who holds which student post of a club over time: one holder per office, one office per student at a time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_org_unit_id` | uuid |  |  |  |
| `club_office_id` | smallint |  |  |  |
| `student_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_officer_pkey`: `PRIMARY KEY (id)`
- FK `club_officer_club_office_id_fkey`: `FOREIGN KEY (club_office_id) REFERENCES ref.club_office(id)`
- FK `club_officer_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `club_officer_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`
- CHECK `club_officer_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `club_officer_one_holder`: `EXCLUDE USING gist (club_org_unit_id WITH =, club_office_id WITH =, valid WITH &&)`
- EXCLUDE `club_officer_one_office`: `EXCLUDE USING gist (club_org_unit_id WITH =, student_id WITH =, valid WITH &&)`
- INDEX `club_officer_student_idx`: `btree (student_id)`

<a id="eventsclub_point_award"></a>
### `events.club_point_award`

Points awarded for one completed event to the club that organised it (the club is the event's organising unit, not repeated here); removed if the event is cancelled.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `points` | smallint |  |  |  |
| `awarded_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_point_award_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_point_award_event_id_key`: `UNIQUE (event_id)`
- FK `club_point_award_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- CHECK `club_point_award_points_check`: `CHECK ((points >= 0))`

<a id="eventsclub_proposal"></a>
### `events.club_proposal`

Proposal to found a club (parent unit, name, objective, faculty advisor / co-advisor); a draft until submitted as a CLUB_PROPOSAL round; approval creates the org unit, the club, the advisor appointments, officers and members.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `proposal_code` | citext |  |  |  |
| `proposed_by_account_id` | uuid |  |  |  |
| `parent_org_unit_id` | uuid |  |  |  |
| `club_name` | text |  |  |  |
| `objective` | text |  |  |  |
| `advisor_employee_id` | uuid |  |  |  |
| `co_advisor_employee_id` | uuid | yes |  |  |
| `club_category_id` | smallint | yes |  |  |
| `instance_id` | uuid | yes |  |  |
| `club_org_unit_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_proposal_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_proposal_club_org_unit_id_key`: `UNIQUE (club_org_unit_id)`
- UNIQUE `club_proposal_instance_id_key`: `UNIQUE (instance_id)`
- UNIQUE `club_proposal_proposal_code_key`: `UNIQUE (proposal_code)`
- FK `club_proposal_advisor_employee_id_fkey`: `FOREIGN KEY (advisor_employee_id) REFERENCES people.employee(id)`
- FK `club_proposal_club_category_id_fkey`: `FOREIGN KEY (club_category_id) REFERENCES ref.club_category(id)`
- FK `club_proposal_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES org.org_unit(id)`
- FK `club_proposal_co_advisor_employee_id_fkey`: `FOREIGN KEY (co_advisor_employee_id) REFERENCES people.employee(id)`
- FK `club_proposal_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `club_proposal_parent_org_unit_id_fkey`: `FOREIGN KEY (parent_org_unit_id) REFERENCES org.org_unit(id)`
- FK `club_proposal_proposed_by_account_id_fkey`: `FOREIGN KEY (proposed_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `club_proposal_check`: `CHECK ((co_advisor_employee_id IS DISTINCT FROM advisor_employee_id))`
- CHECK `club_proposal_club_name_check`: `CHECK ((btrim(club_name) <> ''::text))`
- CHECK `club_proposal_objective_check`: `CHECK ((btrim(objective) <> ''::text))`
- CHECK `club_proposal_proposal_code_check`: `CHECK ((proposal_code ~ '^CP-[0-9]{4}-[0-9]{3,}$'::citext))`

<a id="eventsclub_proposal_attachment"></a>
### `events.club_proposal_attachment`

Files attached to a club proposal.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `club_proposal_id` | uuid |  |  |  |
| `file_object_id` | uuid |  |  |  |
| `description` | text | yes |  |  |

**Constraints & indexes**

- PK `club_proposal_attachment_pkey`: `PRIMARY KEY (club_proposal_id, file_object_id)`
- FK `club_proposal_attachment_club_proposal_id_fkey`: `FOREIGN KEY (club_proposal_id) REFERENCES events.club_proposal(id) ON DELETE CASCADE`
- FK `club_proposal_attachment_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`

<a id="eventsclub_proposal_member"></a>
### `events.club_proposal_member`

Founding members named in a club proposal.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `club_proposal_id` | uuid |  |  |  |
| `student_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `club_proposal_member_pkey`: `PRIMARY KEY (club_proposal_id, student_id)`
- FK `club_proposal_member_club_proposal_id_fkey`: `FOREIGN KEY (club_proposal_id) REFERENCES events.club_proposal(id) ON DELETE CASCADE`
- FK `club_proposal_member_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`

<a id="eventsclub_proposal_officer"></a>
### `events.club_proposal_officer`

Student officers named in a club proposal: one per office, a student in one office.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `club_proposal_id` | uuid |  |  |  |
| `club_office_id` | smallint |  |  |  |
| `student_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `club_proposal_officer_pkey`: `PRIMARY KEY (club_proposal_id, club_office_id)`
- UNIQUE `club_proposal_officer_club_proposal_id_student_id_key`: `UNIQUE (club_proposal_id, student_id)`
- FK `club_proposal_officer_club_office_id_fkey`: `FOREIGN KEY (club_office_id) REFERENCES ref.club_office(id)`
- FK `club_proposal_officer_club_proposal_id_fkey`: `FOREIGN KEY (club_proposal_id) REFERENCES events.club_proposal(id) ON DELETE CASCADE`
- FK `club_proposal_officer_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id)`

<a id="eventsclub_suspension"></a>
### `events.club_suspension`

A period during which a club is suspended, with the reason and who imposed it.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `club_org_unit_id` | uuid |  |  |  |
| `during` | tstzrange |  | `tstzrange(now(), NULL::timestamp with time zone)` |  |
| `reason` | text |  |  |  |
| `imposed_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `club_suspension_pkey`: `PRIMARY KEY (id)`
- FK `club_suspension_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `club_suspension_imposed_by_account_id_fkey`: `FOREIGN KEY (imposed_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `club_suspension_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during))))`
- CHECK `club_suspension_reason_check`: `CHECK ((btrim(reason) <> ''::text))`
- EXCLUDE `club_suspension_once`: `EXCLUDE USING gist (club_org_unit_id WITH =, during WITH &&)`

<a id="eventsclub_tier"></a>
### `events.club_tier`

Club tiers by total points (Bronze … Diamond), non-overlapping bands (POLICY).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `name` | citext |  |  |  |
| `tier_order` | smallint |  |  |  |
| `points` | int4range |  |  |  |
| `badge_color` | character(7) | yes |  |  |

**Constraints & indexes**

- PK `club_tier_pkey`: `PRIMARY KEY (id)`
- UNIQUE `club_tier_name_key`: `UNIQUE (name)`
- UNIQUE `club_tier_tier_order_key`: `UNIQUE (tier_order)`
- CHECK `club_tier_badge_color_check`: `CHECK ((badge_color ~ '^#[0-9A-Fa-f]{6}$'::text))`
- CHECK `club_tier_points_check`: `CHECK (((NOT isempty(points)) AND (NOT lower_inf(points)) AND (lower(points) >= 0)))`
- CHECK `club_tier_tier_order_check`: `CHECK ((tier_order >= 1))`
- EXCLUDE `club_tier_no_overlap`: `EXCLUDE USING gist (points WITH &&)`

<a id="eventscoupon_redemption"></a>
### `events.coupon_redemption`

A coupon used on a registration (one per registration) with the discount fixed at that moment.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_coupon_id` | uuid |  |  |  |
| `registration_id` | uuid |  |  |  |
| `discount_amount` | numeric(10,2) |  |  |  |
| `redeemed_at` | timestamp with time zone |  | `clock_timestamp()` |  |

**Constraints & indexes**

- PK `coupon_redemption_pkey`: `PRIMARY KEY (id)`
- UNIQUE `coupon_redemption_registration_id_key`: `UNIQUE (registration_id)`
- FK `coupon_redemption_event_coupon_id_fkey`: `FOREIGN KEY (event_coupon_id) REFERENCES events.event_coupon(id)`
- FK `coupon_redemption_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id) ON DELETE CASCADE`
- CHECK `coupon_redemption_discount_amount_check`: `CHECK ((discount_amount >= (0)::numeric))`
- INDEX `coupon_redemption_coupon_idx`: `btree (event_coupon_id)`

<a id="eventscustom_field_option"></a>
### `events.custom_field_option`

Options of a dropdown / single-choice question.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_custom_field_id` | uuid |  |  |  |
| `option_value` | text |  |  |  |
| `sort_order` | smallint |  | `0` |  |

**Constraints & indexes**

- PK `custom_field_option_pkey`: `PRIMARY KEY (event_custom_field_id, option_value)`
- FK `custom_field_option_event_custom_field_id_fkey`: `FOREIGN KEY (event_custom_field_id) REFERENCES events.event_custom_field(id) ON DELETE CASCADE`
- CHECK `custom_field_option_option_value_check`: `CHECK ((btrim(option_value) <> ''::text))`

<a id="eventsentry_scan"></a>
### `events.entry_scan`

The gate log: every scan in or out (with guests), append-only; attendance is derived (v_attendance).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `registration_id` | uuid |  |  |  |
| `entry_direction_id` | smallint |  |  |  |
| `people_count` | smallint |  | `1` |  |
| `scanned_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `scanned_by_account_id` | uuid |  |  |  |
| `scan_source_id` | smallint |  |  |  |
| `gate` | text | yes |  |  |
| `remarks` | text | yes |  | IDENTITY |

**Constraints & indexes**

- PK `entry_scan_pkey`: `PRIMARY KEY (id)`
- FK `entry_scan_entry_direction_id_fkey`: `FOREIGN KEY (entry_direction_id) REFERENCES ref.entry_direction(id)`
- FK `entry_scan_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- FK `entry_scan_scan_source_id_fkey`: `FOREIGN KEY (scan_source_id) REFERENCES ref.scan_source(id)`
- FK `entry_scan_scanned_by_account_id_fkey`: `FOREIGN KEY (scanned_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `entry_scan_people_count_check`: `CHECK ((people_count >= 1))`
- INDEX `entry_scan_registration_idx`: `btree (registration_id)`

<a id="eventsevent"></a>
### `events.event`

The event (EVT-YYYY-NNNN), created unpublished by the approval of its proposal: what the organisers settle afterwards (descriptions, contact, registration window and settings) and when it was published, completed or cancelled; status derived (v_event).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_code` | citext |  |  |  |
| `event_proposal_id` | uuid |  |  |  |
| `short_description` | text | yes |  |  |
| `long_description` | text | yes |  |  |
| `contact_person_id` | uuid | yes |  |  |
| `registration_window` | tstzrange | yes |  |  |
| `registration_cap` | integer | yes |  |  |
| `requires_approval` | boolean |  | `false` |  |
| `allow_withdraw` | boolean |  | `true` |  |
| `accepts_volunteer_applications` | boolean |  | `false` |  |
| `stall_applications_open` | boolean |  | `false` |  |
| `stall_application_deadline` | timestamp with time zone | yes |  |  |
| `max_applied_stalls` | integer | yes |  |  |
| `website_url` | text | yes |  |  |
| `logo_file_id` | uuid | yes |  |  |
| `banner_file_id` | uuid | yes |  |  |
| `eligibility_text` | text | yes |  |  |
| `rules_text` | text | yes |  |  |
| `published_at` | timestamp with time zone | yes |  |  |
| `published_by_account_id` | uuid | yes |  |  |
| `completed_at` | timestamp with time zone | yes |  |  |
| `completed_by_account_id` | uuid | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `cancel_reason` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_event_code_key`: `UNIQUE (event_code)`
- UNIQUE `event_event_proposal_id_key`: `UNIQUE (event_proposal_id)`
- FK `event_banner_file_id_fkey`: `FOREIGN KEY (banner_file_id) REFERENCES people.file_object(id)`
- FK `event_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_completed_by_account_id_fkey`: `FOREIGN KEY (completed_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_contact_person_id_fkey`: `FOREIGN KEY (contact_person_id) REFERENCES people.person(id)`
- FK `event_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id)`
- FK `event_logo_file_id_fkey`: `FOREIGN KEY (logo_file_id) REFERENCES people.file_object(id)`
- FK `event_published_by_account_id_fkey`: `FOREIGN KEY (published_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_check`: `CHECK (((published_at IS NULL) = (published_by_account_id IS NULL)))`
- CHECK `event_check1`: `CHECK (((completed_at IS NULL) = (completed_by_account_id IS NULL)))`
- CHECK `event_check2`: `CHECK ((((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL)) AND ((cancelled_at IS NULL) = (cancel_reason IS NULL))))`
- CHECK `event_check3`: `CHECK (((completed_at IS NULL) OR (published_at IS NOT NULL)))`
- CHECK `event_event_code_check`: `CHECK ((event_code ~ '^EVT-[0-9]{4}-[0-9]{4,}$'::citext))`
- CHECK `event_max_applied_stalls_check`: `CHECK ((max_applied_stalls >= 1))`
- CHECK `event_registration_cap_check`: `CHECK ((registration_cap >= 1))`
- CHECK `event_registration_window_check`: `CHECK (((registration_window IS NULL) OR ((NOT isempty(registration_window)) AND (NOT lower_inf(registration_window)) AND (NOT upper_inf(registration_window)))))`
- CHECK `event_short_description_check`: `CHECK ((char_length(short_description) <= 200))`
- CHECK `event_website_url_check`: `CHECK ((website_url ~ '^https?://'::text))`

<a id="eventsevent_certificate"></a>
### `events.event_certificate`

Register of event certificates issued, with serial and public verification code; only to attendees, winners or volunteers.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `certificate_template_id` | uuid |  |  |  |
| `registration_id` | uuid | yes |  |  |
| `event_volunteer_id` | uuid | yes |  |  |
| `serial_no` | citext |  |  | EDUCATION |
| `verification_code` | citext |  |  | EDUCATION |
| `issued_at` | timestamp with time zone |  | `now()` |  |
| `issued_by_account_id` | uuid |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `revoked_at` | timestamp with time zone | yes |  |  |
| `revoke_reason` | text | yes |  | EDUCATION |

**Constraints & indexes**

- PK `event_certificate_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_certificate_certificate_template_id_event_volunteer_i_key`: `UNIQUE (certificate_template_id, event_volunteer_id)`
- UNIQUE `event_certificate_certificate_template_id_registration_id_key`: `UNIQUE (certificate_template_id, registration_id)`
- UNIQUE `event_certificate_serial_no_key`: `UNIQUE (serial_no)`
- UNIQUE `event_certificate_verification_code_key`: `UNIQUE (verification_code)`
- FK `event_certificate_certificate_template_id_fkey`: `FOREIGN KEY (certificate_template_id) REFERENCES events.event_certificate_template(id)`
- FK `event_certificate_event_volunteer_id_fkey`: `FOREIGN KEY (event_volunteer_id) REFERENCES events.event_volunteer(id)`
- FK `event_certificate_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `event_certificate_issued_by_account_id_fkey`: `FOREIGN KEY (issued_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_certificate_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- CHECK `event_certificate_check`: `CHECK ((num_nonnulls(registration_id, event_volunteer_id) = 1))`
- CHECK `event_certificate_check1`: `CHECK (((revoked_at IS NULL) = (revoke_reason IS NULL)))`

<a id="eventsevent_certificate_template"></a>
### `events.event_certificate_template`

An event's certificate template per kind (participation / winner / volunteer).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `event_certificate_type_id` | smallint |  |  |  |
| `title` | text |  |  |  |
| `body` | text |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_certificate_template_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_certificate_template_event_id_event_certificate_type__key`: `UNIQUE (event_id, event_certificate_type_id)`
- FK `event_certificate_template_event_certificate_type_id_fkey`: `FOREIGN KEY (event_certificate_type_id) REFERENCES ref.event_certificate_type(id)`
- FK `event_certificate_template_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_certificate_template_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- CHECK `event_certificate_template_body_check`: `CHECK ((btrim(body) <> ''::text))`
- CHECK `event_certificate_template_title_check`: `CHECK ((btrim(title) <> ''::text))`

<a id="eventsevent_change_request"></a>
### `events.event_change_request`

A change to an approved event that has not started — new dates, venue or capacity; a draft until submitted as an EVENT_CHANGE round; on approval the database applies it and keeps what the event was before.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `request_code` | citext |  |  |  |
| `event_id` | uuid |  |  |  |
| `reason` | text |  |  | IDENTITY |
| `new_during` | tsrange | yes |  |  |
| `new_venue_text` | text | yes |  |  |
| `new_approx_capacity` | integer | yes |  |  |
| `new_capacity_fixed` | integer | yes |  |  |
| `previous_during` | tsrange | yes |  |  |
| `previous_venue_text` | text | yes |  |  |
| `previous_approx_capacity` | integer | yes |  |  |
| `previous_capacity_fixed` | integer | yes |  |  |
| `facility_event_request_id` | uuid | yes |  |  |
| `requested_by_account_id` | uuid |  |  |  |
| `instance_id` | uuid | yes |  |  |
| `applied_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_change_request_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_change_request_instance_id_key`: `UNIQUE (instance_id)`
- UNIQUE `event_change_request_request_code_key`: `UNIQUE (request_code)`
- FK `event_change_request_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- FK `event_change_request_facility_event_request_id_fkey`: `FOREIGN KEY (facility_event_request_id) REFERENCES facility.event_request(id)`
- FK `event_change_request_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `event_change_request_requested_by_account_id_fkey`: `FOREIGN KEY (requested_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_change_request_check`: `CHECK ((num_nonnulls(new_during, new_venue_text, new_approx_capacity, new_capacity_fixed) >= 1))`
- CHECK `event_change_request_new_approx_capacity_check`: `CHECK ((new_approx_capacity >= 1))`
- CHECK `event_change_request_new_capacity_fixed_check`: `CHECK ((new_capacity_fixed >= 1))`
- CHECK `event_change_request_new_during_check`: `CHECK (((new_during IS NULL) OR ((NOT isempty(new_during)) AND (NOT lower_inf(new_during)) AND (NOT upper_inf(new_during)))))`
- CHECK `event_change_request_new_venue_text_check`: `CHECK ((btrim(new_venue_text) <> ''::text))`
- CHECK `event_change_request_reason_check`: `CHECK ((btrim(reason) <> ''::text))`
- CHECK `event_change_request_request_code_check`: `CHECK ((request_code ~ '^ECR-[0-9]{4}-[0-9]{3,}$'::citext))`
- INDEX `event_change_request_event_idx`: `btree (event_id)`

<a id="eventsevent_coupon"></a>
### `events.event_coupon`

A discount coupon of a paid event: percentage (with cap) or fixed amount, minimum fee, total and per-person limits, expiry.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `code` | citext |  |  |  |
| `coupon_discount_type_id` | smallint |  |  |  |
| `discount_value` | numeric(10,2) |  |  |  |
| `max_discount` | numeric(10,2) | yes |  |  |
| `min_amount` | numeric(10,2) | yes |  |  |
| `max_uses` | integer | yes |  |  |
| `max_uses_per_person` | integer | yes | `1` |  |
| `expires_at` | timestamp with time zone | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `description` | text | yes |  |  |
| `created_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_coupon_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_coupon_event_id_code_key`: `UNIQUE (event_id, code)`
- FK `event_coupon_coupon_discount_type_id_fkey`: `FOREIGN KEY (coupon_discount_type_id) REFERENCES ref.coupon_discount_type(id)`
- FK `event_coupon_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_coupon_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- CHECK `event_coupon_code_check`: `CHECK ((((code)::text = upper(btrim((code)::text))) AND (code <> ''::citext)))`
- CHECK `event_coupon_discount_value_check`: `CHECK ((discount_value > (0)::numeric))`
- CHECK `event_coupon_max_discount_check`: `CHECK ((max_discount > (0)::numeric))`
- CHECK `event_coupon_max_uses_check`: `CHECK ((max_uses >= 1))`
- CHECK `event_coupon_max_uses_per_person_check`: `CHECK ((max_uses_per_person >= 1))`
- CHECK `event_coupon_min_amount_check`: `CHECK ((min_amount >= (0)::numeric))`

<a id="eventsevent_custom_field"></a>
### `events.event_custom_field`

Extra questions on an event's registration form.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `field_name` | citext |  |  |  |
| `label` | text |  |  |  |
| `event_field_type_id` | smallint |  |  |  |
| `is_required` | boolean |  | `false` |  |
| `help_text` | text | yes |  |  |
| `sort_order` | smallint |  | `0` |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `event_custom_field_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_custom_field_event_id_field_name_key`: `UNIQUE (event_id, field_name)`
- FK `event_custom_field_event_field_type_id_fkey`: `FOREIGN KEY (event_field_type_id) REFERENCES ref.event_field_type(id)`
- FK `event_custom_field_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- CHECK `event_custom_field_field_name_check`: `CHECK ((field_name ~ '^[a-z][a-z0-9_]{1,60}$'::citext))`
- CHECK `event_custom_field_label_check`: `CHECK ((btrim(label) <> ''::text))`

<a id="eventsevent_expense"></a>
### `events.event_expense`

What was actually spent on an event, line by line, under a budget head and against an approved budget line where there is one; frozen once its settlement is submitted.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `budget_item_type_id` | smallint |  |  |  |
| `proposal_budget_item_id` | uuid | yes |  |  |
| `description` | text |  |  | FINANCIAL |
| `amount` | numeric(12,2) |  |  |  |
| `incurred_on` | date |  |  |  |
| `payee` | text | yes |  | FINANCIAL |
| `bill_no` | text | yes |  | FINANCIAL |
| `bill_file_id` | uuid | yes |  |  |
| `recorded_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_expense_pkey`: `PRIMARY KEY (id)`
- FK `event_expense_bill_file_id_fkey`: `FOREIGN KEY (bill_file_id) REFERENCES people.file_object(id)`
- FK `event_expense_budget_item_type_id_fkey`: `FOREIGN KEY (budget_item_type_id) REFERENCES ref.budget_item_type(id)`
- FK `event_expense_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- FK `event_expense_proposal_budget_item_id_fkey`: `FOREIGN KEY (proposal_budget_item_id) REFERENCES events.proposal_budget_item(id)`
- FK `event_expense_recorded_by_account_id_fkey`: `FOREIGN KEY (recorded_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_expense_amount_check`: `CHECK ((amount > (0)::numeric))`
- CHECK `event_expense_description_check`: `CHECK ((btrim(description) <> ''::text))`
- INDEX `event_expense_event_idx`: `btree (event_id)`

<a id="eventsevent_faq"></a>
### `events.event_faq`

Frequently asked questions of an event.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `seq` | smallint |  |  |  |
| `question` | text |  |  |  |
| `answer` | text |  |  |  |

**Constraints & indexes**

- PK `event_faq_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_faq_event_id_seq_key`: `UNIQUE (event_id, seq)`
- FK `event_faq_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- CHECK `event_faq_answer_check`: `CHECK ((btrim(answer) <> ''::text))`
- CHECK `event_faq_question_check`: `CHECK ((btrim(question) <> ''::text))`

<a id="eventsevent_feedback"></a>
### `events.event_feedback`

Anonymous feedback on an event: rating and comment, with no link to who wrote it.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `event_id` | uuid |  |  |  |
| `rating` | smallint |  |  |  |
| `comment` | text | yes |  | IDENTITY |
| `submitted_on` | date |  | `CURRENT_DATE` |  |

**Constraints & indexes**

- PK `event_feedback_pkey`: `PRIMARY KEY (id)`
- FK `event_feedback_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- CHECK `event_feedback_comment_check`: `CHECK ((char_length(comment) <= 2000))`
- CHECK `event_feedback_rating_check`: `CHECK ((rating >= 1))`

<a id="eventsevent_feedback_token"></a>
### `events.event_feedback_token`

The one feedback token of an attendee (hash) and whether it was used.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `registration_id` | uuid |  |  |  |
| `token_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `issued_at` | timestamp with time zone |  | `now()` |  |
| `used_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `event_feedback_token_pkey`: `PRIMARY KEY (registration_id)`
- UNIQUE `event_feedback_token_token_hash_key`: `UNIQUE (token_hash)`
- FK `event_feedback_token_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id) ON DELETE CASCADE`
- CHECK `event_feedback_token_token_hash_check`: `CHECK ((octet_length(token_hash) = 32))`

<a id="eventsevent_link"></a>
### `events.event_link`

Links of an event (social media, resources).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `label` | text |  |  |  |
| `url` | text |  |  |  |

**Constraints & indexes**

- PK `event_link_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_link_event_id_label_key`: `UNIQUE (event_id, label)`
- FK `event_link_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- CHECK `event_link_label_check`: `CHECK ((btrim(label) <> ''::text))`
- CHECK `event_link_url_check`: `CHECK ((url ~ '^https?://'::text))`

<a id="eventsevent_mail"></a>
### `events.event_mail`

A message from the organisers to an event's registrants (all / confirmed / pending / cancelled / selected), sent now or scheduled; status derived (v_event_mail).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `subject` | text |  |  |  |
| `body` | text |  |  |  |
| `mail_audience_id` | smallint |  |  |  |
| `created_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `scheduled_at` | timestamp with time zone | yes |  |  |
| `dispatch_started_at` | timestamp with time zone | yes |  |  |
| `failed_at` | timestamp with time zone | yes |  |  |
| `failure_reason` | text | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `event_mail_pkey`: `PRIMARY KEY (id)`
- FK `event_mail_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_mail_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_mail_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_mail_mail_audience_id_fkey`: `FOREIGN KEY (mail_audience_id) REFERENCES ref.mail_audience(id)`
- CHECK `event_mail_body_check`: `CHECK ((btrim(body) <> ''::text))`
- CHECK `event_mail_check`: `CHECK (((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL)))`
- CHECK `event_mail_check1`: `CHECK (((failed_at IS NULL) = (failure_reason IS NULL)))`
- CHECK `event_mail_subject_check`: `CHECK (((btrim(subject) <> ''::text) AND (subject !~ '[\r\n]'::text)))`
- INDEX `event_mail_event_idx`: `btree (event_id)`

<a id="eventsevent_mail_credit_grant"></a>
### `events.event_mail_credit_grant`

Extra mail credits an administrator gives an event beyond its per-registration allowance.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `credits` | integer |  |  |  |
| `reason` | text |  |  |  |
| `granted_by_account_id` | uuid |  |  |  |
| `granted_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_mail_credit_grant_pkey`: `PRIMARY KEY (id)`
- FK `event_mail_credit_grant_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_mail_credit_grant_granted_by_account_id_fkey`: `FOREIGN KEY (granted_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_mail_credit_grant_credits_check`: `CHECK ((credits > 0))`
- CHECK `event_mail_credit_grant_reason_check`: `CHECK ((btrim(reason) <> ''::text))`

<a id="eventsevent_mail_recipient"></a>
### `events.event_mail_recipient`

Delivery log of a message: one row per registration written to (the address is looked up when sending), outcome and opens.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_mail_id` | uuid |  |  |  |
| `registration_id` | uuid |  |  |  |
| `mail_delivery_status_id` | smallint |  |  |  |
| `failure_reason` | text | yes |  | CONTACT |
| `delivered_at` | timestamp with time zone | yes |  |  |
| `failed_at` | timestamp with time zone | yes |  |  |
| `open_count` | integer |  | `0` |  |
| `first_opened_at` | timestamp with time zone | yes |  |  |
| `last_opened_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `event_mail_recipient_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_mail_recipient_event_mail_id_registration_id_key`: `UNIQUE (event_mail_id, registration_id)`
- FK `event_mail_recipient_event_mail_id_fkey`: `FOREIGN KEY (event_mail_id) REFERENCES events.event_mail(id) ON DELETE CASCADE`
- FK `event_mail_recipient_mail_delivery_status_id_fkey`: `FOREIGN KEY (mail_delivery_status_id) REFERENCES ref.mail_delivery_status(id)`
- FK `event_mail_recipient_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- CHECK `event_mail_recipient_open_count_check`: `CHECK ((open_count >= 0))`
- INDEX `event_mail_recipient_registration_idx`: `btree (registration_id)`

<a id="eventsevent_payment"></a>
### `events.event_payment`

A payment of a registration fee (in a team event: the team's fee, by its leader) or a stall fee: online order or offline claim, captured / failed / refunded; who must be refunded is derived (v_refund_queue).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `receipt_no` | citext |  |  | FINANCIAL |
| `registration_id` | uuid | yes |  |  |
| `stall_application_id` | uuid | yes |  |  |
| `event_team_id` | uuid | yes |  |  |
| `amount` | numeric(10,2) |  |  |  |
| `currency_code` | character(3) |  |  |  |
| `payment_channel_id` | smallint |  |  |  |
| `payment_status_id` | smallint |  |  |  |
| `gateway_order_id` | text | yes |  | FINANCIAL |
| `gateway_payment_id` | text | yes |  | FINANCIAL |
| `payment_reference` | text | yes |  | FINANCIAL |
| `proof_file_id` | uuid | yes |  |  |
| `attempts` | smallint |  | `0` |  |
| `webhook_verified` | boolean |  | `false` |  |
| `recorded_by_account_id` | uuid | yes |  |  |
| `verified_by_account_id` | uuid | yes |  |  |
| `superseded_at` | timestamp with time zone | yes |  |  |
| `captured_at` | timestamp with time zone | yes |  |  |
| `failed_at` | timestamp with time zone | yes |  |  |
| `refunded_at` | timestamp with time zone | yes |  |  |
| `refund_reference` | text | yes |  | FINANCIAL |
| `refund_note` | text | yes |  | IDENTITY |
| `refund_recorded_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_payment_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_payment_gateway_order_id_key`: `UNIQUE (gateway_order_id)`
- UNIQUE `event_payment_gateway_payment_id_key`: `UNIQUE (gateway_payment_id)`
- UNIQUE `event_payment_receipt_no_key`: `UNIQUE (receipt_no)`
- FK `event_payment_event_team_id_fkey`: `FOREIGN KEY (event_team_id) REFERENCES events.event_team(id)`
- FK `event_payment_payment_channel_id_fkey`: `FOREIGN KEY (payment_channel_id) REFERENCES ref.payment_channel(id)`
- FK `event_payment_payment_status_id_fkey`: `FOREIGN KEY (payment_status_id) REFERENCES ref.payment_status(id)`
- FK `event_payment_proof_file_id_fkey`: `FOREIGN KEY (proof_file_id) REFERENCES people.file_object(id)`
- FK `event_payment_recorded_by_account_id_fkey`: `FOREIGN KEY (recorded_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_payment_refund_recorded_by_account_id_fkey`: `FOREIGN KEY (refund_recorded_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_payment_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- FK `event_payment_stall_application_id_fkey`: `FOREIGN KEY (stall_application_id) REFERENCES events.stall_application(id)`
- FK `event_payment_verified_by_account_id_fkey`: `FOREIGN KEY (verified_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_payment_amount_check`: `CHECK ((amount > (0)::numeric))`
- CHECK `event_payment_attempts_check`: `CHECK ((attempts >= 0))`
- CHECK `event_payment_check`: `CHECK ((num_nonnulls(registration_id, stall_application_id) = 1))`
- CHECK `event_payment_check1`: `CHECK (((event_team_id IS NULL) OR (registration_id IS NOT NULL)))`
- CHECK `event_payment_check2`: `CHECK ((((refunded_at IS NULL) = (refund_recorded_by_account_id IS NULL)) AND ((refunded_at IS NULL) = (refund_reference IS NULL))))`
- CHECK `event_payment_receipt_no_check`: `CHECK ((receipt_no ~ '^RCP-[0-9]{4}-[0-9]{6,}$'::citext))`
- INDEX `event_payment_registration_idx`: `btree (registration_id)`
- INDEX `event_payment_stall_idx`: `btree (stall_application_id)`

<a id="eventsevent_prize_award"></a>
### `events.event_prize_award`

A prize awarded to a participant or a team.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `proposal_prize_id` | uuid |  |  |  |
| `registration_id` | uuid | yes |  |  |
| `event_team_id` | uuid | yes |  |  |
| `awarded_at` | timestamp with time zone |  | `now()` |  |
| `awarded_by_account_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `event_prize_award_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_prize_award_proposal_prize_id_event_team_id_key`: `UNIQUE (proposal_prize_id, event_team_id)`
- UNIQUE `event_prize_award_proposal_prize_id_registration_id_key`: `UNIQUE (proposal_prize_id, registration_id)`
- FK `event_prize_award_awarded_by_account_id_fkey`: `FOREIGN KEY (awarded_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_prize_award_event_team_id_fkey`: `FOREIGN KEY (event_team_id) REFERENCES events.event_team(id)`
- FK `event_prize_award_proposal_prize_id_fkey`: `FOREIGN KEY (proposal_prize_id) REFERENCES events.proposal_prize(id)`
- FK `event_prize_award_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- CHECK `event_prize_award_check`: `CHECK ((num_nonnulls(registration_id, event_team_id) = 1))`

<a id="eventsevent_proposal"></a>
### `events.event_proposal`

An event proposal by a club or a unit: type, dates, level, mode, participation, fees, capacity, duty leave, certificates; draft until submitted as an EVENT_PROPOSAL round (budget total = amount, flags for conditions); immutable once submitted; revised as a new proposal; the approved proposal is the event's fixed facts.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `proposal_code` | citext |  |  |  |
| `organising_org_unit_id` | uuid |  |  |  |
| `proposed_by_account_id` | uuid |  |  |  |
| `event_type_id` | smallint |  |  |  |
| `title` | text |  |  |  |
| `during` | tsrange |  |  |  |
| `event_level_id` | smallint |  |  |  |
| `event_mode_id` | smallint |  |  |  |
| `theme` | text |  |  |  |
| `objective` | text |  |  |  |
| `anticipated_outcomes` | text | yes |  |  |
| `description` | text | yes |  |  |
| `venue_text` | text | yes |  |  |
| `participation_type_id` | smallint |  |  |  |
| `min_team_size` | smallint | yes |  |  |
| `max_team_size` | smallint | yes |  |  |
| `is_paid` | boolean |  | `false` |  |
| `fee_individual` | numeric(10,2) | yes |  |  |
| `fee_team` | numeric(10,2) | yes |  |  |
| `approx_capacity` | integer |  |  |  |
| `capacity_fixed` | integer | yes |  |  |
| `duty_leave_scope_id` | smallint | yes |  |  |
| `gives_certificates` | boolean |  | `false` |  |
| `allow_extra_passes` | boolean |  | `false` |  |
| `max_extra_passes` | smallint |  | `0` |  |
| `facility_event_request_id` | uuid | yes |  |  |
| `revises_proposal_id` | uuid | yes |  |  |
| `instance_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_proposal_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_proposal_facility_event_request_id_key`: `UNIQUE (facility_event_request_id)`
- UNIQUE `event_proposal_instance_id_key`: `UNIQUE (instance_id)`
- UNIQUE `event_proposal_proposal_code_key`: `UNIQUE (proposal_code)`
- FK `event_proposal_duty_leave_scope_id_fkey`: `FOREIGN KEY (duty_leave_scope_id) REFERENCES ref.duty_leave_scope(id)`
- FK `event_proposal_event_level_id_fkey`: `FOREIGN KEY (event_level_id) REFERENCES ref.event_level(id)`
- FK `event_proposal_event_mode_id_fkey`: `FOREIGN KEY (event_mode_id) REFERENCES ref.event_mode(id)`
- FK `event_proposal_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.event_type(id)`
- FK `event_proposal_facility_event_request_id_fkey`: `FOREIGN KEY (facility_event_request_id) REFERENCES facility.event_request(id)`
- FK `event_proposal_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `event_proposal_organising_org_unit_id_fkey`: `FOREIGN KEY (organising_org_unit_id) REFERENCES org.org_unit(id)`
- FK `event_proposal_participation_type_id_fkey`: `FOREIGN KEY (participation_type_id) REFERENCES ref.participation_type(id)`
- FK `event_proposal_proposed_by_account_id_fkey`: `FOREIGN KEY (proposed_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_proposal_revises_proposal_id_fkey`: `FOREIGN KEY (revises_proposal_id) REFERENCES events.event_proposal(id)`
- CHECK `event_proposal_approx_capacity_check`: `CHECK ((approx_capacity >= 1))`
- CHECK `event_proposal_capacity_fixed_check`: `CHECK ((capacity_fixed >= 1))`
- CHECK `event_proposal_check`: `CHECK (((max_team_size IS NULL) OR (max_team_size >= COALESCE((min_team_size)::integer, 1))))`
- CHECK `event_proposal_check1`: `CHECK ((allow_extra_passes = (max_extra_passes > 0)))`
- CHECK `event_proposal_check2`: `CHECK (((instance_id IS NULL) = (facility_event_request_id IS NULL)))`
- CHECK `event_proposal_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `event_proposal_fee_individual_check`: `CHECK ((fee_individual > (0)::numeric))`
- CHECK `event_proposal_fee_team_check`: `CHECK ((fee_team > (0)::numeric))`
- CHECK `event_proposal_max_extra_passes_check`: `CHECK ((max_extra_passes >= 0))`
- CHECK `event_proposal_min_team_size_check`: `CHECK ((min_team_size >= 1))`
- CHECK `event_proposal_objective_check`: `CHECK ((btrim(objective) <> ''::text))`
- CHECK `event_proposal_proposal_code_check`: `CHECK ((proposal_code ~ '^EP-[0-9]{4}-[0-9]{3,}$'::citext))`
- CHECK `event_proposal_theme_check`: `CHECK ((btrim(theme) <> ''::text))`
- CHECK `event_proposal_title_check`: `CHECK (((char_length(btrim(title)) >= 3) AND (char_length(btrim(title)) <= 256)))`
- INDEX `event_proposal_proposer_idx`: `btree (proposed_by_account_id)`
- INDEX `event_proposal_unit_idx`: `btree (organising_org_unit_id)`

<a id="eventsevent_registration"></a>
### `events.event_registration`

One person's registration for one event: seat or waiting list, the organisers' decision, the ticket, withdrawal; what is owed and paid is derived from coupons and payments; status derived (v_registration).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `registration_code` | citext |  |  |  |
| `qr_token_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `ticket_issued_at` | timestamp with time zone | yes |  |  |
| `registered_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `waitlisted_at` | timestamp with time zone | yes |  |  |
| `promoted_at` | timestamp with time zone | yes |  |  |
| `decided_at` | timestamp with time zone | yes |  |  |
| `decided_by_account_id` | uuid | yes |  |  |
| `is_approved` | boolean | yes |  |  |
| `cancelled_at` | timestamp with time zone | yes |  |  |
| `cancelled_by_account_id` | uuid | yes |  |  |
| `registration_cancel_reason_id` | smallint | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_registration_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_registration_event_id_person_id_key`: `UNIQUE (event_id, person_id)`
- UNIQUE `event_registration_qr_token_hash_key`: `UNIQUE (qr_token_hash)`
- UNIQUE `event_registration_registration_code_key`: `UNIQUE (registration_code)`
- FK `event_registration_cancelled_by_account_id_fkey`: `FOREIGN KEY (cancelled_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_registration_decided_by_account_id_fkey`: `FOREIGN KEY (decided_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_registration_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- FK `event_registration_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- FK `event_registration_registration_cancel_reason_id_fkey`: `FOREIGN KEY (registration_cancel_reason_id) REFERENCES ref.registration_cancel_reason(id)`
- CHECK `event_registration_check`: `CHECK (((decided_at IS NULL) = (is_approved IS NULL)))`
- CHECK `event_registration_check1`: `CHECK (((cancelled_at IS NULL) = (registration_cancel_reason_id IS NULL)))`
- CHECK `event_registration_check2`: `CHECK (((promoted_at IS NULL) OR (waitlisted_at IS NOT NULL)))`
- CHECK `event_registration_qr_token_hash_check`: `CHECK ((octet_length(qr_token_hash) = 32))`
- INDEX `registration_person_idx`: `btree (person_id)`

<a id="eventsevent_round"></a>
### `events.event_round`

Rounds / sessions of an event, inside its dates.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `name` | text |  |  |  |
| `during` | tsrange |  |  |  |
| `event_round_type_id` | smallint |  |  |  |
| `description` | text | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_round_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_round_event_id_name_key`: `UNIQUE (event_id, name)`
- FK `event_round_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_round_event_round_type_id_fkey`: `FOREIGN KEY (event_round_type_id) REFERENCES ref.event_round_type(id)`
- CHECK `event_round_during_check`: `CHECK (((NOT isempty(during)) AND (NOT lower_inf(during)) AND (NOT upper_inf(during))))`
- CHECK `event_round_name_check`: `CHECK ((btrim(name) <> ''::text))`

<a id="eventsevent_setting"></a>
### `events.event_setting`

The one row of module settings an events administrator edits: club name / objective lengths, whether advisors must be faculty, proposal lead time, required proposal sections, concurrent proposals per proposer, guest-pass ceiling, what publishing needs, the feedback scale. No policy value is hard-coded in the module.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | boolean |  | `true` |  |
| `club_name_min_length` | smallint |  | `3` |  |
| `club_name_max_length` | smallint |  | `100` |  |
| `club_objective_min_length` | smallint |  | `50` |  |
| `advisor_must_be_faculty` | boolean |  | `true` |  |
| `proposal_min_lead_time` | interval |  | `'00:00:00'::interval` |  |
| `proposal_needs_audience` | boolean |  | `true` |  |
| `proposal_needs_coordinator` | boolean |  | `true` |  |
| `proposal_needs_sdg` | boolean |  | `true` |  |
| `max_open_proposals_per_proposer` | smallint | yes | `1` |  |
| `max_extra_passes_per_participant` | smallint |  | `20` |  |
| `publish_needs_description` | boolean |  | `true` |  |
| `publish_needs_contact` | boolean |  | `true` |  |
| `publish_needs_round` | boolean |  | `true` |  |
| `feedback_rating_max` | smallint |  | `10` |  |
| `max_open_club_changes` | smallint | yes | `1` |  |
| `primary_club_requires_office` | boolean |  | `true` |  |
| `currency_code` | character(3) |  | `'INR'::bpchar` |  |
| `min_payable_amount` | numeric(10,2) |  | `1` |  |
| `unpaid_registration_expiry` | interval | yes |  |  |
| `mail_credits_per_registration` | smallint |  | `3` |  |
| `mail_subject_max_length` | integer |  | `256` |  |
| `mail_body_max_length` | integer |  | `50000` |  |
| `mail_open_tracking` | boolean |  | `false` |  |
| `stall_feedback_max_points` | smallint |  | `10` |  |
| `round_checkin_opens_before` | interval |  | `'00:30:00'::interval` |  |
| `expense_bill_required_above` | numeric(12,2) | yes |  |  |
| `updated_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_setting_pkey`: `PRIMARY KEY (id)`
- FK `event_setting_updated_by_account_id_fkey`: `FOREIGN KEY (updated_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_setting_check`: `CHECK ((club_name_max_length >= club_name_min_length))`
- CHECK `event_setting_club_name_min_length_check`: `CHECK ((club_name_min_length >= 1))`
- CHECK `event_setting_club_objective_min_length_check`: `CHECK ((club_objective_min_length >= 1))`
- CHECK `event_setting_currency_code_check`: `CHECK ((currency_code ~ '^[A-Z]{3}$'::text))`
- CHECK `event_setting_expense_bill_required_above_check`: `CHECK ((expense_bill_required_above >= (0)::numeric))`
- CHECK `event_setting_feedback_rating_max_check`: `CHECK ((feedback_rating_max >= 2))`
- CHECK `event_setting_id_check`: `CHECK (id)`
- CHECK `event_setting_mail_body_max_length_check`: `CHECK ((mail_body_max_length >= 1))`
- CHECK `event_setting_mail_credits_per_registration_check`: `CHECK ((mail_credits_per_registration >= 0))`
- CHECK `event_setting_mail_subject_max_length_check`: `CHECK ((mail_subject_max_length >= 1))`
- CHECK `event_setting_max_extra_passes_per_participant_check`: `CHECK ((max_extra_passes_per_participant >= 0))`
- CHECK `event_setting_max_open_club_changes_check`: `CHECK ((max_open_club_changes >= 1))`
- CHECK `event_setting_max_open_proposals_per_proposer_check`: `CHECK ((max_open_proposals_per_proposer >= 1))`
- CHECK `event_setting_min_payable_amount_check`: `CHECK ((min_payable_amount >= (0)::numeric))`
- CHECK `event_setting_proposal_min_lead_time_check`: `CHECK ((proposal_min_lead_time >= '00:00:00'::interval))`
- CHECK `event_setting_round_checkin_opens_before_check`: `CHECK ((round_checkin_opens_before >= '00:00:00'::interval))`
- CHECK `event_setting_stall_feedback_max_points_check`: `CHECK ((stall_feedback_max_points >= 1))`
- CHECK `event_setting_unpaid_registration_expiry_check`: `CHECK ((unpaid_registration_expiry > '00:00:00'::interval))`

<a id="eventsevent_settlement"></a>
### `events.event_settlement`

The settlement of an event's accounts: the statement of its expenses submitted as an EVENT_SETTLEMENT round (amount = total spent; flag OVER_BUDGET); a returned one is corrected and submitted again.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `settlement_code` | citext |  |  |  |
| `event_id` | uuid |  |  |  |
| `remarks` | text | yes |  | FINANCIAL |
| `submitted_by_account_id` | uuid |  |  |  |
| `instance_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_settlement_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_settlement_instance_id_key`: `UNIQUE (instance_id)`
- UNIQUE `event_settlement_settlement_code_key`: `UNIQUE (settlement_code)`
- FK `event_settlement_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- FK `event_settlement_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `event_settlement_submitted_by_account_id_fkey`: `FOREIGN KEY (submitted_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `event_settlement_settlement_code_check`: `CHECK ((settlement_code ~ '^EST-[0-9]{4}-[0-9]{3,}$'::citext))`
- INDEX `event_settlement_event_idx`: `btree (event_id)`

<a id="eventsevent_sponsor"></a>
### `events.event_sponsor`

Sponsoring organisations known across events.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `name` | text |  |  | IDENTITY |
| `sponsor_type_id` | smallint |  |  |  |
| `contact_person_id` | uuid | yes |  |  |
| `logo_file_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_sponsor_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_sponsor_name_key`: `UNIQUE (name)`
- FK `event_sponsor_contact_person_id_fkey`: `FOREIGN KEY (contact_person_id) REFERENCES people.person(id)`
- FK `event_sponsor_logo_file_id_fkey`: `FOREIGN KEY (logo_file_id) REFERENCES people.file_object(id)`
- FK `event_sponsor_sponsor_type_id_fkey`: `FOREIGN KEY (sponsor_type_id) REFERENCES ref.sponsor_type(id)`
- CHECK `event_sponsor_name_check`: `CHECK ((btrim(name) <> ''::text))`

<a id="eventsevent_sponsorship"></a>
### `events.event_sponsorship`

A sponsor's commitment to an event (cash amount and / or in-kind items).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `sponsor_id` | uuid |  |  |  |
| `contribution_type_id` | smallint |  |  |  |
| `cash_amount` | numeric(12,2) | yes |  |  |
| `show_publicly` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `event_sponsorship_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_sponsorship_event_proposal_id_sponsor_id_key`: `UNIQUE (event_proposal_id, sponsor_id)`
- FK `event_sponsorship_contribution_type_id_fkey`: `FOREIGN KEY (contribution_type_id) REFERENCES ref.contribution_type(id)`
- FK `event_sponsorship_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `event_sponsorship_sponsor_id_fkey`: `FOREIGN KEY (sponsor_id) REFERENCES events.event_sponsor(id)`
- CHECK `event_sponsorship_cash_amount_check`: `CHECK ((cash_amount > (0)::numeric))`

<a id="eventsevent_stall"></a>
### `events.event_stall`

A stall of an event (ST<number>): set up and described by the organisers, or created by an approved application — then it only points at the application and holds the location (v_stall shows both alike).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `stall_code` | citext |  |  |  |
| `stall_name` | text | yes |  |  |
| `stall_type_id` | smallint | yes |  |  |
| `stall_category_id` | smallint | yes |  |  |
| `description` | text | yes |  |  |
| `business_name` | text | yes |  | IDENTITY |
| `owner_person_id` | uuid | yes |  |  |
| `stall_size_id` | smallint | yes |  |  |
| `custom_size` | text | yes |  |  |
| `location` | text | yes |  |  |
| `electricity_required` | boolean |  | `false` |  |
| `water_required` | boolean |  | `false` |  |
| `special_requirements` | text | yes |  |  |
| `stall_application_id` | uuid | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_stall_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_stall_stall_application_id_key`: `UNIQUE (stall_application_id)`
- UNIQUE `event_stall_stall_code_key`: `UNIQUE (stall_code)`
- FK `event_stall_created_by_account_id_fkey`: `FOREIGN KEY (created_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_stall_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_stall_owner_person_id_fkey`: `FOREIGN KEY (owner_person_id) REFERENCES people.person(id)`
- FK `event_stall_stall_application_id_fkey`: `FOREIGN KEY (stall_application_id) REFERENCES events.stall_application(id)`
- FK `event_stall_stall_category_id_fkey`: `FOREIGN KEY (stall_category_id) REFERENCES ref.stall_category(id)`
- FK `event_stall_stall_size_id_fkey`: `FOREIGN KEY (stall_size_id) REFERENCES ref.stall_size(id)`
- FK `event_stall_stall_type_id_fkey`: `FOREIGN KEY (stall_type_id) REFERENCES ref.stall_type(id)`
- CHECK `event_stall_check`: `CHECK (((stall_application_id IS NULL) = (stall_name IS NOT NULL)))`
- CHECK `event_stall_check1`: `CHECK (((stall_application_id IS NULL) OR ((num_nonnulls(stall_type_id, stall_category_id, description, business_name, owner_person_id, stall_size_id, custom_size, special_requirements) = 0) AND (NOT electricity_required) AND (NOT water_required))))`
- CHECK `event_stall_stall_code_check`: `CHECK ((stall_code ~ '^ST[0-9]{5,}$'::citext))`
- CHECK `event_stall_stall_name_check`: `CHECK ((btrim(stall_name) <> ''::text))`
- INDEX `event_stall_event_idx`: `btree (event_id)`

<a id="eventsevent_stall_fee"></a>
### `events.event_stall_fee`

What a stall of a category costs at an event (no row = free).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_id` | uuid |  |  |  |
| `stall_category_id` | smallint |  |  |  |
| `fee` | numeric(10,2) |  |  |  |

**Constraints & indexes**

- PK `event_stall_fee_pkey`: `PRIMARY KEY (event_id, stall_category_id)`
- FK `event_stall_fee_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_stall_fee_stall_category_id_fkey`: `FOREIGN KEY (stall_category_id) REFERENCES ref.stall_category(id)`
- CHECK `event_stall_fee_fee_check`: `CHECK ((fee >= (0)::numeric))`

<a id="eventsevent_stall_product"></a>
### `events.event_stall_product`

Products a stall offers.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_stall_id` | uuid |  |  |  |
| `name` | text |  |  |  |

**Constraints & indexes**

- PK `event_stall_product_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_stall_product_event_stall_id_name_key`: `UNIQUE (event_stall_id, name)`
- FK `event_stall_product_event_stall_id_fkey`: `FOREIGN KEY (event_stall_id) REFERENCES events.event_stall(id) ON DELETE CASCADE`
- CHECK `event_stall_product_name_check`: `CHECK ((btrim(name) <> ''::text))`

<a id="eventsevent_team"></a>
### `events.event_team`

A team of a team event: leader, finalised / withdrawn / disqualified; completeness derived from its members.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `name` | text |  |  |  |
| `leader_registration_id` | uuid |  |  |  |
| `looking_for_members` | boolean |  | `true` |  |
| `locked_at` | timestamp with time zone | yes |  |  |
| `withdrawn_at` | timestamp with time zone | yes |  |  |
| `disqualified_at` | timestamp with time zone | yes |  |  |
| `disqualified_by_account_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_team_pkey`: `PRIMARY KEY (id)`
- FK `event_team_disqualified_by_account_id_fkey`: `FOREIGN KEY (disqualified_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_team_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id)`
- FK `event_team_leader_registration_id_fkey`: `FOREIGN KEY (leader_registration_id) REFERENCES events.event_registration(id)`
- CHECK `event_team_check`: `CHECK (((disqualified_at IS NULL) = (disqualified_by_account_id IS NULL)))`
- CHECK `event_team_name_check`: `CHECK ((btrim(name) <> ''::text))`
- INDEX `event_team_name_uq`: `btree (event_id, lower(name))`

<a id="eventsevent_team_member"></a>
### `events.event_team_member`

Members of a team over time; a participant is in one live team.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_team_id` | uuid |  |  |  |
| `registration_id` | uuid |  |  |  |
| `joined_at` | timestamp with time zone |  | `now()` |  |
| `left_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `event_team_member_pkey`: `PRIMARY KEY (id)`
- FK `event_team_member_event_team_id_fkey`: `FOREIGN KEY (event_team_id) REFERENCES events.event_team(id) ON DELETE CASCADE`
- FK `event_team_member_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- CHECK `event_team_member_check`: `CHECK (((left_at IS NULL) OR (left_at >= joined_at)))`
- INDEX `event_team_member_one_live`: `btree (registration_id) WHERE (left_at IS NULL)`
- INDEX `event_team_member_team_idx`: `btree (event_team_id)`

<a id="eventsevent_type_points"></a>
### `events.event_type_points`

Points a club earns for a completed event of a type, valid for a period (POLICY).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_type_id` | smallint |  |  |  |
| `points` | smallint |  |  |  |
| `valid` | daterange |  | `daterange('2000-01-01'::date, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `event_type_points_pkey`: `PRIMARY KEY (id)`
- FK `event_type_points_event_type_id_fkey`: `FOREIGN KEY (event_type_id) REFERENCES ref.event_type(id)`
- CHECK `event_type_points_points_check`: `CHECK ((points >= 0))`
- CHECK `event_type_points_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `event_type_points_one`: `EXCLUDE USING gist (event_type_id WITH =, valid WITH &&)`

<a id="eventsevent_volunteer"></a>
### `events.event_volunteer`

Volunteers (may scan at a gate) and event managers (may manage the event) of an event.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `volunteer_role_id` | smallint |  |  |  |
| `can_scan` | boolean |  | `true` |  |
| `gate` | text | yes |  |  |
| `assigned_by_account_id` | uuid |  |  |  |
| `assigned_at` | timestamp with time zone |  | `now()` |  |
| `removed_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `event_volunteer_pkey`: `PRIMARY KEY (id)`
- UNIQUE `event_volunteer_event_id_person_id_key`: `UNIQUE (event_id, person_id)`
- FK `event_volunteer_assigned_by_account_id_fkey`: `FOREIGN KEY (assigned_by_account_id) REFERENCES iam.user_account(id)`
- FK `event_volunteer_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `event_volunteer_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- FK `event_volunteer_volunteer_role_id_fkey`: `FOREIGN KEY (volunteer_role_id) REFERENCES ref.volunteer_role(id)`

<a id="eventsextra_pass"></a>
### `events.extra_pass`

Guests a participant brings on their own pass.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `registration_id` | uuid |  |  |  |
| `guest_name` | text |  |  | IDENTITY |
| `guest_phone` | character varying(16) | yes |  | CONTACT |
| `relationship` | text | yes |  | RELATIONSHIP |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `extra_pass_pkey`: `PRIMARY KEY (id)`
- FK `extra_pass_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id) ON DELETE CASCADE`
- CHECK `extra_pass_guest_name_check`: `CHECK ((btrim(guest_name) <> ''::text))`
- CHECK `extra_pass_guest_phone_check`: `CHECK (((guest_phone)::text ~ '^\+[1-9][0-9]{7,14}$'::text))`

<a id="eventsfield_response"></a>
### `events.field_response`

A participant's answers to the event's extra questions (one row each).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `registration_id` | uuid |  |  |  |
| `event_custom_field_id` | uuid |  |  |  |
| `value` | text | yes |  | IDENTITY |
| `file_object_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `field_response_pkey`: `PRIMARY KEY (registration_id, event_custom_field_id)`
- FK `field_response_event_custom_field_id_fkey`: `FOREIGN KEY (event_custom_field_id) REFERENCES events.event_custom_field(id)`
- FK `field_response_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `field_response_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id) ON DELETE CASCADE`
- CHECK `field_response_check`: `CHECK ((num_nonnulls(value, file_object_id) = 1))`

<a id="eventspost_event_report"></a>
### `events.post_event_report`

The report filed after an event, in versions.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `version` | smallint |  |  |  |
| `file_object_id` | uuid |  |  |  |
| `summary` | text | yes |  |  |
| `actual_attendance` | integer | yes |  |  |
| `uploaded_by_account_id` | uuid |  |  |  |
| `uploaded_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `post_event_report_pkey`: `PRIMARY KEY (id)`
- UNIQUE `post_event_report_event_id_version_key`: `UNIQUE (event_id, version)`
- FK `post_event_report_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `post_event_report_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `post_event_report_uploaded_by_account_id_fkey`: `FOREIGN KEY (uploaded_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `post_event_report_actual_attendance_check`: `CHECK ((actual_attendance >= 0))`
- CHECK `post_event_report_version_check`: `CHECK ((version >= 1))`

<a id="eventsprimary_club"></a>
### `events.primary_club`

A student's primary club: one per student; by default a club in which they hold an office.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `student_id` | uuid |  |  |  |
| `club_org_unit_id` | uuid |  |  |  |
| `set_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `primary_club_pkey`: `PRIMARY KEY (student_id)`
- FK `primary_club_club_org_unit_id_fkey`: `FOREIGN KEY (club_org_unit_id) REFERENCES events.club(org_unit_id) ON DELETE CASCADE`
- FK `primary_club_student_id_fkey`: `FOREIGN KEY (student_id) REFERENCES people.student(id) ON DELETE CASCADE`

<a id="eventsproposal_attachment"></a>
### `events.proposal_attachment`

Files attached to an event proposal.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `file_object_id` | uuid |  |  |  |
| `description` | text | yes |  |  |

**Constraints & indexes**

- PK `proposal_attachment_pkey`: `PRIMARY KEY (event_proposal_id, file_object_id)`
- FK `proposal_attachment_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_attachment_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`

<a id="eventsproposal_audience"></a>
### `events.proposal_audience`

Who the proposed event is for.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `event_audience_kind_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `proposal_audience_pkey`: `PRIMARY KEY (event_proposal_id, event_audience_kind_id)`
- FK `proposal_audience_event_audience_kind_id_fkey`: `FOREIGN KEY (event_audience_kind_id) REFERENCES ref.event_audience_kind(id)`
- FK `proposal_audience_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`

<a id="eventsproposal_budget_item"></a>
### `events.proposal_budget_item`

The budget line by line (type, unit cost, quantity); the total is derived and is the approval round's amount.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `budget_item_type_id` | smallint |  |  |  |
| `description` | text |  |  |  |
| `unit_cost` | numeric(12,2) |  |  |  |
| `quantity` | numeric(10,2) |  | `1` |  |

**Constraints & indexes**

- PK `proposal_budget_item_pkey`: `PRIMARY KEY (id)`
- FK `proposal_budget_item_budget_item_type_id_fkey`: `FOREIGN KEY (budget_item_type_id) REFERENCES ref.budget_item_type(id)`
- FK `proposal_budget_item_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- CHECK `proposal_budget_item_description_check`: `CHECK ((btrim(description) <> ''::text))`
- CHECK `proposal_budget_item_quantity_check`: `CHECK ((quantity > (0)::numeric))`
- CHECK `proposal_budget_item_unit_cost_check`: `CHECK ((unit_cost >= (0)::numeric))`

<a id="eventsproposal_coordinator"></a>
### `events.proposal_coordinator`

Coordinators of the proposed event (people of the university).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `coordinator_role` | text |  |  |  |

**Constraints & indexes**

- PK `proposal_coordinator_pkey`: `PRIMARY KEY (event_proposal_id, person_id)`
- FK `proposal_coordinator_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_coordinator_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- CHECK `proposal_coordinator_coordinator_role_check`: `CHECK ((btrim(coordinator_role) <> ''::text))`

<a id="eventsproposal_funding"></a>
### `events.proposal_funding`

Expected sources of funds for the proposal.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `funding_source_id` | smallint |  |  |  |
| `expected_amount` | numeric(12,2) |  |  |  |
| `note` | text | yes |  |  |

**Constraints & indexes**

- PK `proposal_funding_pkey`: `PRIMARY KEY (id)`
- UNIQUE `proposal_funding_event_proposal_id_funding_source_id_key`: `UNIQUE (event_proposal_id, funding_source_id)`
- FK `proposal_funding_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_funding_funding_source_id_fkey`: `FOREIGN KEY (funding_source_id) REFERENCES ref.funding_source(id)`
- CHECK `proposal_funding_expected_amount_check`: `CHECK ((expected_amount > (0)::numeric))`

<a id="eventsproposal_partner"></a>
### `events.proposal_partner`

Collaborating clubs / units of a proposal.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `partner_org_unit_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `proposal_partner_pkey`: `PRIMARY KEY (event_proposal_id, partner_org_unit_id)`
- FK `proposal_partner_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_partner_partner_org_unit_id_fkey`: `FOREIGN KEY (partner_org_unit_id) REFERENCES org.org_unit(id)`

<a id="eventsproposal_prize"></a>
### `events.proposal_prize`

Prizes on offer.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `position` | smallint |  |  |  |
| `title` | text |  |  |  |
| `event_prize_type_id` | smallint |  |  |  |
| `amount` | numeric(12,2) | yes |  |  |
| `perks` | text | yes |  |  |

**Constraints & indexes**

- PK `proposal_prize_pkey`: `PRIMARY KEY (id)`
- UNIQUE `proposal_prize_event_proposal_id_position_title_key`: `UNIQUE (event_proposal_id, "position", title)`
- FK `proposal_prize_event_prize_type_id_fkey`: `FOREIGN KEY (event_prize_type_id) REFERENCES ref.event_prize_type(id)`
- FK `proposal_prize_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- CHECK `proposal_prize_amount_check`: `CHECK ((amount >= (0)::numeric))`
- CHECK `proposal_prize_position_check`: `CHECK (("position" >= 1))`
- CHECK `proposal_prize_title_check`: `CHECK ((btrim(title) <> ''::text))`

<a id="eventsproposal_sdg"></a>
### `events.proposal_sdg`

UN Sustainable Development Goals the proposed event serves.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `sdg_no` | smallint |  |  |  |

**Constraints & indexes**

- PK `proposal_sdg_pkey`: `PRIMARY KEY (event_proposal_id, sdg_no)`
- FK `proposal_sdg_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- CHECK `proposal_sdg_sdg_no_check`: `CHECK (((sdg_no >= 1) AND (sdg_no <= 17)))`

<a id="eventsproposal_speaker"></a>
### `events.proposal_speaker`

Resource persons / guest speakers: a person in the system or an outside name.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `person_id` | uuid | yes |  |  |
| `speaker_name` | text | yes |  | IDENTITY |
| `designation` | text | yes |  | EMPLOYMENT |
| `organisation` | text | yes |  | EMPLOYMENT |
| `cv_url` | text | yes |  | IDENTITY |

**Constraints & indexes**

- PK `proposal_speaker_pkey`: `PRIMARY KEY (id)`
- FK `proposal_speaker_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_speaker_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- CHECK `proposal_speaker_check`: `CHECK ((num_nonnulls(person_id, NULLIF(btrim(speaker_name), ''::text)) = 1))`
- CHECK `proposal_speaker_cv_url_check`: `CHECK ((cv_url ~ '^https?://'::text))`
- INDEX `proposal_speaker_person_uq`: `btree (event_proposal_id, person_id) WHERE (person_id IS NOT NULL)`

<a id="eventsproposal_visibility_role"></a>
### `events.proposal_visibility_role`

Kinds of people (student / employee / guardian) who may see and register for the event; no row = everyone.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `event_proposal_id` | uuid |  |  |  |
| `principal_kind_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `proposal_visibility_role_pkey`: `PRIMARY KEY (event_proposal_id, principal_kind_id)`
- FK `proposal_visibility_role_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_visibility_role_principal_kind_id_fkey`: `FOREIGN KEY (principal_kind_id) REFERENCES ref.principal_kind(id)`

<a id="eventsproposal_visibility_scope"></a>
### `events.proposal_visibility_scope`

For students: the schools / departments, programmes or batches the event is open to; no row = every student.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_proposal_id` | uuid |  |  |  |
| `org_unit_id` | uuid | yes |  |  |
| `program_id` | uuid | yes |  |  |
| `batch_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `proposal_visibility_scope_pkey`: `PRIMARY KEY (id)`
- FK `proposal_visibility_scope_batch_id_fkey`: `FOREIGN KEY (batch_id) REFERENCES academic.batch(id)`
- FK `proposal_visibility_scope_event_proposal_id_fkey`: `FOREIGN KEY (event_proposal_id) REFERENCES events.event_proposal(id) ON DELETE CASCADE`
- FK `proposal_visibility_scope_org_unit_id_fkey`: `FOREIGN KEY (org_unit_id) REFERENCES org.org_unit(id)`
- FK `proposal_visibility_scope_program_id_fkey`: `FOREIGN KEY (program_id) REFERENCES academic.program(id)`
- CHECK `proposal_visibility_scope_check`: `CHECK ((num_nonnulls(org_unit_id, program_id, batch_id) = 1))`
- INDEX `proposal_visibility_scope_uq`: `btree (event_proposal_id, COALESCE(org_unit_id, program_id, batch_id))`

<a id="eventsround_attendance"></a>
### `events.round_attendance`

Attendance at one session (round) of an event: one check-in per registration and round, by a scanning volunteer or an organiser, or imported; append-only.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `event_round_id` | uuid |  |  |  |
| `registration_id` | uuid |  |  |  |
| `marked_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `marked_by_account_id` | uuid |  |  |  |
| `scan_source_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `round_attendance_pkey`: `PRIMARY KEY (id)`
- UNIQUE `round_attendance_event_round_id_registration_id_key`: `UNIQUE (event_round_id, registration_id)`
- FK `round_attendance_event_round_id_fkey`: `FOREIGN KEY (event_round_id) REFERENCES events.event_round(id)`
- FK `round_attendance_marked_by_account_id_fkey`: `FOREIGN KEY (marked_by_account_id) REFERENCES iam.user_account(id)`
- FK `round_attendance_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- FK `round_attendance_scan_source_id_fkey`: `FOREIGN KEY (scan_source_id) REFERENCES ref.scan_source(id)`
- INDEX `round_attendance_registration_idx`: `btree (registration_id)`

<a id="eventssponsorship_item"></a>
### `events.sponsorship_item`

In-kind items promised by a sponsor, with delivery.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `sponsorship_id` | uuid |  |  |  |
| `item_name` | text |  |  |  |
| `quantity` | numeric(10,2) |  | `1` |  |
| `estimated_value` | numeric(12,2) | yes |  |  |
| `delivered_at` | timestamp with time zone | yes |  |  |
| `assigned_to_person_id` | uuid | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `sponsorship_item_pkey`: `PRIMARY KEY (id)`
- FK `sponsorship_item_assigned_to_person_id_fkey`: `FOREIGN KEY (assigned_to_person_id) REFERENCES people.person(id)`
- FK `sponsorship_item_sponsorship_id_fkey`: `FOREIGN KEY (sponsorship_id) REFERENCES events.event_sponsorship(id) ON DELETE CASCADE`
- CHECK `sponsorship_item_estimated_value_check`: `CHECK ((estimated_value >= (0)::numeric))`
- CHECK `sponsorship_item_item_name_check`: `CHECK ((btrim(item_name) <> ''::text))`
- CHECK `sponsorship_item_quantity_check`: `CHECK ((quantity > (0)::numeric))`

<a id="eventssponsorship_receipt"></a>
### `events.sponsorship_receipt`

Cash actually received against a sponsorship (append-only; never above the commitment).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `sponsorship_id` | uuid |  |  |  |
| `amount` | numeric(12,2) |  |  |  |
| `received_on` | date |  | `CURRENT_DATE` |  |
| `reference` | text | yes |  |  |
| `recorded_by_account_id` | uuid |  |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `sponsorship_receipt_pkey`: `PRIMARY KEY (id)`
- FK `sponsorship_receipt_recorded_by_account_id_fkey`: `FOREIGN KEY (recorded_by_account_id) REFERENCES iam.user_account(id)`
- FK `sponsorship_receipt_sponsorship_id_fkey`: `FOREIGN KEY (sponsorship_id) REFERENCES events.event_sponsorship(id)`
- CHECK `sponsorship_receipt_amount_check`: `CHECK ((amount > (0)::numeric))`

<a id="eventsstall_application"></a>
### `events.stall_application`

An application to run a stall at an event: one per applicant and event; approved or rejected by the organisers; approval creates the stall.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `applicant_person_id` | uuid |  |  |  |
| `stall_name` | text |  |  |  |
| `stall_type_id` | smallint |  |  |  |
| `stall_category_id` | smallint |  |  |  |
| `description` | text | yes |  | IDENTITY |
| `business_name` | text | yes |  | IDENTITY |
| `is_selling` | boolean |  | `false` |  |
| `price_range` | numrange | yes |  |  |
| `stall_size_id` | smallint |  |  |  |
| `custom_size` | text | yes |  |  |
| `electricity_required` | boolean |  | `false` |  |
| `additional_power_watts` | integer | yes |  |  |
| `table_required` | boolean |  | `false` |  |
| `chairs_count` | smallint |  | `0` |  |
| `special_setup_other` | text | yes |  | IDENTITY |
| `declarations_accepted_at` | timestamp with time zone |  |  |  |
| `applied_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `decided_at` | timestamp with time zone | yes |  |  |
| `decided_by_account_id` | uuid | yes |  |  |
| `is_approved` | boolean | yes |  |  |
| `rejection_reason` | text | yes |  | IDENTITY |

**Constraints & indexes**

- PK `stall_application_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_application_event_id_applicant_person_id_key`: `UNIQUE (event_id, applicant_person_id)`
- FK `stall_application_applicant_person_id_fkey`: `FOREIGN KEY (applicant_person_id) REFERENCES people.person(id)`
- FK `stall_application_decided_by_account_id_fkey`: `FOREIGN KEY (decided_by_account_id) REFERENCES iam.user_account(id)`
- FK `stall_application_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `stall_application_stall_category_id_fkey`: `FOREIGN KEY (stall_category_id) REFERENCES ref.stall_category(id)`
- FK `stall_application_stall_size_id_fkey`: `FOREIGN KEY (stall_size_id) REFERENCES ref.stall_size(id)`
- FK `stall_application_stall_type_id_fkey`: `FOREIGN KEY (stall_type_id) REFERENCES ref.stall_type(id)`
- CHECK `stall_application_additional_power_watts_check`: `CHECK ((additional_power_watts > 0))`
- CHECK `stall_application_chairs_count_check`: `CHECK ((chairs_count >= 0))`
- CHECK `stall_application_check`: `CHECK ((((decided_at IS NULL) = (is_approved IS NULL)) AND ((decided_at IS NULL) = (decided_by_account_id IS NULL))))`
- CHECK `stall_application_check1`: `CHECK (((is_approved IS NOT FALSE) OR (btrim(COALESCE(rejection_reason, ''::text)) <> ''::text)))`
- CHECK `stall_application_check2`: `CHECK (((price_range IS NULL) OR (is_selling AND (NOT isempty(price_range)) AND (lower(price_range) >= (0)::numeric))))`
- CHECK `stall_application_check3`: `CHECK (((additional_power_watts IS NULL) OR electricity_required))`
- CHECK `stall_application_stall_name_check`: `CHECK ((btrim(stall_name) <> ''::text))`

<a id="eventsstall_application_document"></a>
### `events.stall_application_document`

Documents attached to a stall application.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `stall_application_id` | uuid |  |  |  |
| `file_object_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `stall_application_document_pkey`: `PRIMARY KEY (id)`
- UNIQUE `stall_application_document_stall_application_id_file_object_key`: `UNIQUE (stall_application_id, file_object_id)`
- FK `stall_application_document_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `stall_application_document_stall_application_id_fkey`: `FOREIGN KEY (stall_application_id) REFERENCES events.stall_application(id) ON DELETE CASCADE`

<a id="eventsstall_application_setup"></a>
### `events.stall_application_setup`

Special set-ups a stall application asks for.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `stall_application_id` | uuid |  |  |  |
| `stall_setup_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `stall_application_setup_pkey`: `PRIMARY KEY (stall_application_id, stall_setup_id)`
- FK `stall_application_setup_stall_application_id_fkey`: `FOREIGN KEY (stall_application_id) REFERENCES events.stall_application(id) ON DELETE CASCADE`
- FK `stall_application_setup_stall_setup_id_fkey`: `FOREIGN KEY (stall_setup_id) REFERENCES ref.stall_setup(id)`

<a id="eventsstall_feedback"></a>
### `events.stall_feedback`

Visitors' anonymous feedback on a stall (no person, a date instead of a time).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_stall_id` | uuid |  |  |  |
| `comment` | text | yes |  | IDENTITY |
| `submitted_on` | date |  | `CURRENT_DATE` |  |

**Constraints & indexes**

- PK `stall_feedback_pkey`: `PRIMARY KEY (id)`
- FK `stall_feedback_event_stall_id_fkey`: `FOREIGN KEY (event_stall_id) REFERENCES events.event_stall(id)`
- CHECK `stall_feedback_comment_check`: `CHECK ((char_length(comment) <= 2000))`
- INDEX `stall_feedback_stall_idx`: `btree (event_stall_id)`

<a id="eventsstall_feedback_point"></a>
### `events.stall_feedback_point`

The scores of one stall feedback, each on the feedback scale.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `stall_feedback_id` | uuid |  |  |  |
| `point_no` | smallint |  |  |  |
| `score` | smallint |  |  |  |

**Constraints & indexes**

- PK `stall_feedback_point_pkey`: `PRIMARY KEY (stall_feedback_id, point_no)`
- FK `stall_feedback_point_stall_feedback_id_fkey`: `FOREIGN KEY (stall_feedback_id) REFERENCES events.stall_feedback(id) ON DELETE CASCADE`
- CHECK `stall_feedback_point_point_no_check`: `CHECK ((point_no >= 1))`
- CHECK `stall_feedback_point_score_check`: `CHECK ((score >= 1))`

<a id="eventsteam_invitation"></a>
### `events.team_invitation`

A leader's invitation to a participant to join the team; acceptance makes the member.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_team_id` | uuid |  |  |  |
| `invitee_registration_id` | uuid |  |  |  |
| `message` | text | yes |  | IDENTITY |
| `invited_at` | timestamp with time zone |  | `now()` |  |
| `expires_at` | timestamp with time zone | yes |  |  |
| `responded_at` | timestamp with time zone | yes |  |  |
| `is_accepted` | boolean | yes |  |  |

**Constraints & indexes**

- PK `team_invitation_pkey`: `PRIMARY KEY (id)`
- FK `team_invitation_event_team_id_fkey`: `FOREIGN KEY (event_team_id) REFERENCES events.event_team(id) ON DELETE CASCADE`
- FK `team_invitation_invitee_registration_id_fkey`: `FOREIGN KEY (invitee_registration_id) REFERENCES events.event_registration(id)`
- CHECK `team_invitation_check`: `CHECK (((responded_at IS NULL) = (is_accepted IS NULL)))`
- CHECK `team_invitation_message_check`: `CHECK ((char_length(message) <= 500))`
- INDEX `team_invitation_one_open`: `btree (event_team_id, invitee_registration_id) WHERE (responded_at IS NULL)`

<a id="eventsteam_join_request"></a>
### `events.team_join_request`

A participant's request to join a team; acceptance makes the member.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_team_id` | uuid |  |  |  |
| `registration_id` | uuid |  |  |  |
| `message` | text | yes |  | IDENTITY |
| `requested_at` | timestamp with time zone |  | `now()` |  |
| `responded_at` | timestamp with time zone | yes |  |  |
| `is_accepted` | boolean | yes |  |  |

**Constraints & indexes**

- PK `team_join_request_pkey`: `PRIMARY KEY (id)`
- FK `team_join_request_event_team_id_fkey`: `FOREIGN KEY (event_team_id) REFERENCES events.event_team(id) ON DELETE CASCADE`
- FK `team_join_request_registration_id_fkey`: `FOREIGN KEY (registration_id) REFERENCES events.event_registration(id)`
- CHECK `team_join_request_check`: `CHECK (((responded_at IS NULL) = (is_accepted IS NULL)))`
- CHECK `team_join_request_message_check`: `CHECK ((char_length(message) <= 500))`
- INDEX `team_join_request_one_open`: `btree (event_team_id, registration_id) WHERE (responded_at IS NULL)`

<a id="eventsvolunteer_application"></a>
### `events.volunteer_application`

An offer to volunteer at an event that takes applications; an organiser decides; acceptance makes the volunteer.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `event_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `note` | text | yes |  | IDENTITY |
| `applied_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `decided_at` | timestamp with time zone | yes |  |  |
| `decided_by_account_id` | uuid | yes |  |  |
| `is_accepted` | boolean | yes |  |  |
| `decision_note` | text | yes |  | IDENTITY |

**Constraints & indexes**

- PK `volunteer_application_pkey`: `PRIMARY KEY (id)`
- UNIQUE `volunteer_application_event_id_person_id_key`: `UNIQUE (event_id, person_id)`
- FK `volunteer_application_decided_by_account_id_fkey`: `FOREIGN KEY (decided_by_account_id) REFERENCES iam.user_account(id)`
- FK `volunteer_application_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES events.event(id) ON DELETE CASCADE`
- FK `volunteer_application_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- CHECK `volunteer_application_check`: `CHECK ((((decided_at IS NULL) = (is_accepted IS NULL)) AND ((decided_at IS NULL) = (decided_by_account_id IS NULL))))`

## Schema `pii` — Personal data (restricted)

<a id="piiaddress"></a>
### `pii.address`

Postal addresses (may be shared by family members).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `line1` | text |  |  | ADDRESS |
| `line2` | text | yes |  | ADDRESS |
| `locality` | text | yes |  | ADDRESS |
| `city_id` | integer |  |  |  |
| `postal_code` | character varying(12) |  |  | ADDRESS |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `address_pkey`: `PRIMARY KEY (id)`
- FK `address_city_id_fkey`: `FOREIGN KEY (city_id) REFERENCES ref.city(id)`
- CHECK `address_line1_check`: `CHECK ((btrim(line1) <> ''::text))`

<a id="piiperson_address"></a>
### `pii.person_address`

A person's address of each type over time.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `address_id` | uuid |  |  |  |
| `address_type_id` | smallint |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_address_pkey`: `PRIMARY KEY (id)`
- FK `person_address_address_id_fkey`: `FOREIGN KEY (address_id) REFERENCES pii.address(id)`
- FK `person_address_address_type_id_fkey`: `FOREIGN KEY (address_type_id) REFERENCES ref.address_type(id)`
- FK `person_address_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_address_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `person_address_no_overlap`: `EXCLUDE USING gist (person_id WITH =, address_type_id WITH =, valid WITH &&)`

<a id="piiperson_email"></a>
### `pii.person_email`

Email addresses of a person; globally unique; verified + login-enabled ones can be used to sign in.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `email` | citext |  |  | CONTACT |
| `contact_purpose_id` | smallint |  |  |  |
| `is_primary` | boolean |  | `false` |  |
| `is_login_enabled` | boolean |  | `false` |  |
| `verified_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_email_pkey`: `PRIMARY KEY (id)`
- UNIQUE `person_email_email_key`: `UNIQUE (email)`
- UNIQUE `person_email_id_person_id_key`: `UNIQUE (id, person_id)`
- FK `person_email_contact_purpose_id_fkey`: `FOREIGN KEY (contact_purpose_id) REFERENCES ref.contact_purpose(id)`
- FK `person_email_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_email_email_check`: `CHECK (((email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::citext) AND (length((email)::text) <= 254)))`
- CHECK `person_email_login_requires_verified`: `CHECK (((NOT is_login_enabled) OR (verified_at IS NOT NULL)))`
- INDEX `person_email_one_primary_uq`: `btree (person_id) WHERE is_primary`
- INDEX `person_email_person_idx`: `btree (person_id)`

<a id="piiperson_identity_document"></a>
### `pii.person_identity_document`

Government ID numbers, application-encrypted, with HMAC blind index. Collect only when required.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `id_document_type_id` | smallint |  |  |  |
| `number_ciphertext` | bytea |  |  | GOVERNMENT_ID (sensitive) |
| `number_hmac` | bytea |  |  | GOVERNMENT_ID (sensitive) |
| `number_last4` | character varying(4) |  |  | GOVERNMENT_ID (sensitive) |
| `expires_on` | date | yes |  | GOVERNMENT_ID (sensitive) |
| `verified_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_identity_document_pkey`: `PRIMARY KEY (id)`
- UNIQUE `person_identity_document_id_document_type_id_number_hmac_key`: `UNIQUE (id_document_type_id, number_hmac)`
- UNIQUE `person_identity_document_person_id_id_document_type_id_key`: `UNIQUE (person_id, id_document_type_id)`
- FK `person_identity_document_id_document_type_id_fkey`: `FOREIGN KEY (id_document_type_id) REFERENCES ref.id_document_type(id)`
- FK `person_identity_document_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_identity_document_number_hmac_check`: `CHECK ((octet_length(number_hmac) = 32))`

<a id="piiperson_phone"></a>
### `pii.person_phone`

Phone numbers (E.164) of a person.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `e164` | character varying(16) |  |  | CONTACT |
| `contact_purpose_id` | smallint |  |  |  |
| `is_primary` | boolean |  | `false` |  |
| `verified_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_phone_pkey`: `PRIMARY KEY (id)`
- UNIQUE `person_phone_id_person_id_key`: `UNIQUE (id, person_id)`
- UNIQUE `person_phone_person_id_e164_key`: `UNIQUE (person_id, e164)`
- FK `person_phone_contact_purpose_id_fkey`: `FOREIGN KEY (contact_purpose_id) REFERENCES ref.contact_purpose(id)`
- FK `person_phone_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_phone_e164_check`: `CHECK (((e164)::text ~ '^\+[1-9][0-9]{6,14}$'::text))`
- INDEX `person_phone_e164_idx`: `btree (e164)`
- INDEX `person_phone_one_primary_uq`: `btree (person_id) WHERE is_primary`

<a id="piiperson_photo"></a>
### `pii.person_photo`

Photographs of a person over time (one current).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `file_object_id` | uuid |  |  | PHOTO (sensitive) |
| `valid` | tstzrange |  | `tstzrange(now(), NULL::timestamp with time zone)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_photo_pkey`: `PRIMARY KEY (id)`
- UNIQUE `person_photo_file_object_id_key`: `UNIQUE (file_object_id)`
- FK `person_photo_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `person_photo_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_photo_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `person_photo_one_current`: `EXCLUDE USING gist (person_id WITH =, valid WITH &&)`

<a id="piiperson_profile"></a>
### `pii.person_profile`

1:1 sensitive demographics of a person (DOB, blood group, nationality).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `person_id` | uuid |  |  |  |
| `date_of_birth` | date | yes |  | DEMOGRAPHIC |
| `blood_group_id` | smallint | yes |  | HEALTH (sensitive) |
| `nationality_country_id` | smallint | yes |  | DEMOGRAPHIC |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `person_profile_pkey`: `PRIMARY KEY (person_id)`
- FK `person_profile_blood_group_id_fkey`: `FOREIGN KEY (blood_group_id) REFERENCES ref.blood_group(id)`
- FK `person_profile_nationality_country_id_fkey`: `FOREIGN KEY (nationality_country_id) REFERENCES ref.country(id)`
- FK `person_profile_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `person_profile_date_of_birth_check`: `CHECK ((date_of_birth > '1900-01-01'::date))`

## Schema `iam` — Identity & authentication

<a id="iamaccount_lockout"></a>
### `iam.account_lockout`

Lockout periods of an account.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `lockout_reason_id` | smallint |  |  |  |
| `period` | tstzrange |  |  |  |
| `released_at` | timestamp with time zone | yes |  |  |
| `released_by_account_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `account_lockout_pkey`: `PRIMARY KEY (id)`
- FK `account_lockout_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `account_lockout_lockout_reason_id_fkey`: `FOREIGN KEY (lockout_reason_id) REFERENCES ref.lockout_reason(id)`
- FK `account_lockout_released_by_account_id_fkey`: `FOREIGN KEY (released_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `account_lockout_check`: `CHECK (((released_at IS NULL) OR (released_at >= lower(period))))`
- CHECK `account_lockout_period_check`: `CHECK (((NOT isempty(period)) AND (NOT lower_inf(period))))`
- EXCLUDE `account_lockout_no_overlap`: `EXCLUDE USING gist (account_id WITH =, period WITH &&)`

<a id="iamauth_event"></a>
### `iam.auth_event` *(partitioned by month)*

Append-only authentication log (monthly partitions). Attempted identifiers stored only as HMAC.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `occurred_at` | timestamp with time zone |  | `now()` |  |
| `account_id` | uuid | yes |  |  |
| `auth_event_type_id` | smallint |  |  |  |
| `auth_failure_reason_id` | smallint | yes |  |  |
| `identifier_hmac` | bytea | yes |  |  |
| `session_id` | uuid | yes |  |  |
| `mfa_factor_id` | uuid | yes |  |  |
| `ip` | inet | yes |  | DEVICE_NETWORK |
| `user_agent` | text | yes |  | DEVICE_NETWORK |

**Constraints & indexes**

- PK `auth_event_pkey`: `PRIMARY KEY (id, occurred_at)`
- FK `auth_event_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE SET NULL`
- FK `auth_event_auth_event_type_id_fkey`: `FOREIGN KEY (auth_event_type_id) REFERENCES ref.auth_event_type(id)`
- FK `auth_event_auth_failure_reason_id_fkey`: `FOREIGN KEY (auth_failure_reason_id) REFERENCES ref.auth_failure_reason(id)`
- FK `auth_event_mfa_factor_id_fkey`: `FOREIGN KEY (mfa_factor_id) REFERENCES iam.mfa_factor(id) ON DELETE SET NULL`
- FK `auth_event_session_id_fkey`: `FOREIGN KEY (session_id) REFERENCES iam.user_session(id) ON DELETE SET NULL`
- CHECK `auth_event_identifier_hmac_check`: `CHECK ((octet_length(identifier_hmac) = 32))`
- INDEX `auth_event_account_idx`: `btree (account_id, occurred_at DESC)`
- INDEX `auth_event_identifier_idx`: `btree (identifier_hmac, occurred_at DESC)`

<a id="iammfa_factor"></a>
### `iam.mfa_factor`

Enrolled second factors of an account (supertype).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `mfa_factor_type_id` | smallint |  |  |  |
| `label` | text |  | `''::text` |  |
| `is_default` | boolean |  | `false` |  |
| `confirmed_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `mfa_factor_pkey`: `PRIMARY KEY (id)`
- FK `mfa_factor_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `mfa_factor_mfa_factor_type_id_fkey`: `FOREIGN KEY (mfa_factor_type_id) REFERENCES ref.mfa_factor_type(id)`
- CHECK `mfa_factor_check`: `CHECK (((NOT is_default) OR (confirmed_at IS NOT NULL)))`
- INDEX `mfa_factor_account_idx`: `btree (account_id)`
- INDEX `mfa_factor_one_default_uq`: `btree (account_id) WHERE is_default`

<a id="iammfa_otp_channel"></a>
### `iam.mfa_otp_channel`

Email/SMS OTP factor: which of the person's own contacts receives codes.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `factor_id` | uuid |  |  |  |
| `person_email_id` | uuid | yes |  |  |
| `person_phone_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `mfa_otp_channel_pkey`: `PRIMARY KEY (factor_id)`
- FK `mfa_otp_channel_factor_id_fkey`: `FOREIGN KEY (factor_id) REFERENCES iam.mfa_factor(id) ON DELETE CASCADE`
- FK `mfa_otp_channel_person_email_id_fkey`: `FOREIGN KEY (person_email_id) REFERENCES pii.person_email(id) ON DELETE CASCADE`
- FK `mfa_otp_channel_person_phone_id_fkey`: `FOREIGN KEY (person_phone_id) REFERENCES pii.person_phone(id) ON DELETE CASCADE`
- CHECK `mfa_otp_channel_check`: `CHECK ((num_nonnulls(person_email_id, person_phone_id) = 1))`

<a id="iammfa_recovery_code"></a>
### `iam.mfa_recovery_code`

Single-use MFA recovery codes (hashed).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `account_id` | uuid |  |  |  |
| `code_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `used_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `mfa_recovery_code_pkey`: `PRIMARY KEY (id)`
- UNIQUE `mfa_recovery_code_account_id_code_hash_key`: `UNIQUE (account_id, code_hash)`
- FK `mfa_recovery_code_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- CHECK `mfa_recovery_code_code_hash_check`: `CHECK ((octet_length(code_hash) = 32))`

<a id="iammfa_totp"></a>
### `iam.mfa_totp`

TOTP factor details (secret encrypted by the application).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `factor_id` | uuid |  |  |  |
| `secret_ciphertext` | bytea |  |  | CREDENTIAL (sensitive) |
| `digits` | smallint |  | `6` |  |
| `period_seconds` | smallint |  | `30` |  |

**Constraints & indexes**

- PK `mfa_totp_pkey`: `PRIMARY KEY (factor_id)`
- FK `mfa_totp_factor_id_fkey`: `FOREIGN KEY (factor_id) REFERENCES iam.mfa_factor(id) ON DELETE CASCADE`
- CHECK `mfa_totp_digits_check`: `CHECK ((digits = ANY (ARRAY[6, 8])))`
- CHECK `mfa_totp_period_seconds_check`: `CHECK (((period_seconds >= 15) AND (period_seconds <= 120)))`

<a id="iammfa_webauthn"></a>
### `iam.mfa_webauthn`

Passkey / security-key factor details.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `factor_id` | uuid |  |  |  |
| `credential_id` | bytea |  |  | CREDENTIAL (sensitive) |
| `public_key` | bytea |  |  | CREDENTIAL (sensitive) |
| `aaguid` | uuid | yes |  |  |
| `sign_count` | bigint |  | `0` |  |

**Constraints & indexes**

- PK `mfa_webauthn_pkey`: `PRIMARY KEY (factor_id)`
- UNIQUE `mfa_webauthn_credential_id_key`: `UNIQUE (credential_id)`
- FK `mfa_webauthn_factor_id_fkey`: `FOREIGN KEY (factor_id) REFERENCES iam.mfa_factor(id) ON DELETE CASCADE`
- CHECK `mfa_webauthn_sign_count_check`: `CHECK ((sign_count >= 0))`

<a id="iamotp_challenge"></a>
### `iam.otp_challenge`

Issued one-time codes (MFA, step-up, verification, reset).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid | yes |  |  |
| `otp_purpose_id` | smallint |  |  |  |
| `mfa_factor_id` | uuid | yes |  |  |
| `person_email_id` | uuid | yes |  |  |
| `person_phone_id` | uuid | yes |  |  |
| `code_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `attempt_count` | smallint |  | `0` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `expires_at` | timestamp with time zone |  |  |  |
| `consumed_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `otp_challenge_pkey`: `PRIMARY KEY (id)`
- FK `otp_challenge_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `otp_challenge_mfa_factor_id_fkey`: `FOREIGN KEY (mfa_factor_id) REFERENCES iam.mfa_factor(id) ON DELETE CASCADE`
- FK `otp_challenge_otp_purpose_id_fkey`: `FOREIGN KEY (otp_purpose_id) REFERENCES ref.otp_purpose(id)`
- FK `otp_challenge_person_email_id_fkey`: `FOREIGN KEY (person_email_id) REFERENCES pii.person_email(id) ON DELETE CASCADE`
- FK `otp_challenge_person_phone_id_fkey`: `FOREIGN KEY (person_phone_id) REFERENCES pii.person_phone(id) ON DELETE CASCADE`
- CHECK `otp_challenge_attempt_count_check`: `CHECK ((attempt_count >= 0))`
- CHECK `otp_challenge_check`: `CHECK ((num_nonnulls(mfa_factor_id, person_email_id, person_phone_id) = 1))`
- CHECK `otp_challenge_check1`: `CHECK ((expires_at > created_at))`
- CHECK `otp_challenge_code_hash_check`: `CHECK ((octet_length(code_hash) = 32))`
- INDEX `otp_challenge_account_idx`: `btree (account_id, created_at DESC)`

<a id="iampassword_history"></a>
### `iam.password_history`

Previous password hashes for the reuse policy.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `account_id` | uuid |  |  |  |
| `password_hash` | character varying(255) |  |  | CREDENTIAL (sensitive) |
| `set_at` | timestamp with time zone |  |  |  |
| `replaced_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `password_history_pkey`: `PRIMARY KEY (id)`
- FK `password_history_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- CHECK `password_history_check`: `CHECK ((replaced_at >= set_at))`
- INDEX `password_history_account_idx`: `btree (account_id, replaced_at DESC)`

<a id="iampassword_reset_token"></a>
### `iam.password_reset_token`

Self-service password reset tokens (hashed).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `token_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `requested_ip` | inet | yes |  | DEVICE_NETWORK |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `expires_at` | timestamp with time zone |  |  |  |
| `used_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `password_reset_token_pkey`: `PRIMARY KEY (id)`
- UNIQUE `password_reset_token_token_hash_key`: `UNIQUE (token_hash)`
- FK `password_reset_token_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- CHECK `password_reset_token_check`: `CHECK ((expires_at > created_at))`
- CHECK `password_reset_token_check1`: `CHECK (((used_at IS NULL) OR (used_at >= created_at)))`
- CHECK `password_reset_token_token_hash_check`: `CHECK ((octet_length(token_hash) = 32))`
- INDEX `password_reset_token_account_idx`: `btree (account_id)`

<a id="iamuser_account"></a>
### `iam.user_account`

Login account of a person (Django AUTH_USER_MODEL). username = UID. last_login is derived, not stored.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `username` | citext |  |  | IDENTITY |
| `password` | character varying(255) |  |  | CREDENTIAL (sensitive) |
| `account_status_id` | smallint |  |  |  |
| `is_superuser` | boolean |  | `false` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `user_account_pkey`: `PRIMARY KEY (id)`
- UNIQUE `user_account_person_id_key`: `UNIQUE (person_id)`
- UNIQUE `user_account_username_key`: `UNIQUE (username)`
- FK `user_account_account_status_id_fkey`: `FOREIGN KEY (account_status_id) REFERENCES ref.account_status(id)`
- FK `user_account_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id)`
- CHECK `user_account_username_check`: `CHECK ((username ~ '^[A-Za-z0-9._-]{3,64}$'::citext))`

<a id="iamuser_device"></a>
### `iam.user_device`

Devices seen for an account; trusted_until = "remember this device".

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `fingerprint_hash` | bytea |  |  | DEVICE_NETWORK |
| `name` | text | yes |  | DEVICE_NETWORK |
| `user_agent` | text | yes |  | DEVICE_NETWORK |
| `first_seen_at` | timestamp with time zone |  | `now()` |  |
| `trusted_until` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `user_device_pkey`: `PRIMARY KEY (id)`
- UNIQUE `user_device_account_id_fingerprint_hash_key`: `UNIQUE (account_id, fingerprint_hash)`
- FK `user_device_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- CHECK `user_device_fingerprint_hash_check`: `CHECK ((octet_length(fingerprint_hash) = 32))`

<a id="iamuser_session"></a>
### `iam.user_session`

Refresh-token sessions with rotation families and revocation.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `device_id` | uuid | yes |  |  |
| `family_id` | uuid |  |  |  |
| `refresh_token_hash` | bytea |  |  | CREDENTIAL (sensitive) |
| `ip` | inet | yes |  | DEVICE_NETWORK |
| `mfa_verified_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `expires_at` | timestamp with time zone |  |  |  |
| `revoked_at` | timestamp with time zone | yes |  |  |
| `session_revoke_reason_id` | smallint | yes |  |  |

**Constraints & indexes**

- PK `user_session_pkey`: `PRIMARY KEY (id)`
- UNIQUE `user_session_refresh_token_hash_key`: `UNIQUE (refresh_token_hash)`
- FK `user_session_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `user_session_device_id_fkey`: `FOREIGN KEY (device_id) REFERENCES iam.user_device(id) ON DELETE SET NULL`
- FK `user_session_session_revoke_reason_id_fkey`: `FOREIGN KEY (session_revoke_reason_id) REFERENCES ref.session_revoke_reason(id)`
- CHECK `user_session_check`: `CHECK ((expires_at > created_at))`
- CHECK `user_session_check1`: `CHECK (((revoked_at IS NULL) = (session_revoke_reason_id IS NULL)))`
- CHECK `user_session_refresh_token_hash_check`: `CHECK ((octet_length(refresh_token_hash) = 32))`
- INDEX `user_session_account_active_idx`: `btree (account_id) WHERE (revoked_at IS NULL)`
- INDEX `user_session_family_idx`: `btree (family_id)`
- INDEX `user_session_family_one_active_uq`: `btree (family_id) WHERE (revoked_at IS NULL)`

## Schema `authz` — Authorisation (RBAC)

<a id="authzaccount_permission"></a>
### `authz.account_permission`

Exceptional single-permission grant (must be justified).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `permission_id` | integer |  |  |  |
| `scope_org_unit_id` | uuid | yes |  |  |
| `include_descendants` | boolean |  | `true` |  |
| `valid` | tstzrange |  | `tstzrange(now(), NULL::timestamp with time zone)` |  |
| `granted_by_account_id` | uuid | yes |  |  |
| `reason` | text |  |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `account_permission_pkey`: `PRIMARY KEY (id)`
- FK `account_permission_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `account_permission_granted_by_account_id_fkey`: `FOREIGN KEY (granted_by_account_id) REFERENCES iam.user_account(id)`
- FK `account_permission_permission_id_fkey`: `FOREIGN KEY (permission_id) REFERENCES authz.permission(id)`
- FK `account_permission_scope_org_unit_id_fkey`: `FOREIGN KEY (scope_org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `account_permission_check`: `CHECK (((scope_org_unit_id IS NOT NULL) OR include_descendants))`
- CHECK `account_permission_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `account_permission_no_overlap`: `EXCLUDE USING gist (account_id WITH =, permission_id WITH =, COALESCE(scope_org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`
- INDEX `account_permission_account_idx`: `btree (account_id)`

<a id="authzaccount_role"></a>
### `authz.account_role`

Explicit, time-bound role grant to an account, globally or on an org-unit subtree.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `account_id` | uuid |  |  |  |
| `role_id` | integer |  |  |  |
| `scope_org_unit_id` | uuid | yes |  |  |
| `include_descendants` | boolean |  | `true` |  |
| `valid` | tstzrange |  | `tstzrange(now(), NULL::timestamp with time zone)` |  |
| `granted_by_account_id` | uuid | yes |  |  |
| `reason` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `account_role_pkey`: `PRIMARY KEY (id)`
- FK `account_role_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id) ON DELETE CASCADE`
- FK `account_role_granted_by_account_id_fkey`: `FOREIGN KEY (granted_by_account_id) REFERENCES iam.user_account(id)`
- FK `account_role_role_id_fkey`: `FOREIGN KEY (role_id) REFERENCES authz.role(id)`
- FK `account_role_scope_org_unit_id_fkey`: `FOREIGN KEY (scope_org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `account_role_check`: `CHECK (((scope_org_unit_id IS NOT NULL) OR include_descendants))`
- CHECK `account_role_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `account_role_no_overlap`: `EXCLUDE USING gist (account_id WITH =, role_id WITH =, COALESCE(scope_org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`
- INDEX `account_role_account_idx`: `btree (account_id)`
- INDEX `account_role_scope_idx`: `btree (scope_org_unit_id)`

<a id="authzaction"></a>
### `authz.action`

Verbs (access, view, create, update, delete, approve, review, export, assign).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |

**Constraints & indexes**

- PK `action_pkey`: `PRIMARY KEY (id)`
- UNIQUE `action_code_key`: `UNIQUE (code)`
- CHECK `action_code_check`: `CHECK ((code ~ '^[a-z][a-z0-9_]{1,30}$'::citext))`

<a id="authzapp_module"></a>
### `authz.app_module`

Application modules; each module registers its resources and permissions.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `description` | text | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `app_module_pkey`: `PRIMARY KEY (id)`
- UNIQUE `app_module_code_key`: `UNIQUE (code)`
- CHECK `app_module_code_check`: `CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::citext))`

<a id="authzdesignation_role"></a>
### `authz.designation_role`

Rule: holding a designation in an active assignment confers a role (at that unit or globally).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `designation_id` | smallint |  |  |  |
| `role_id` | integer |  |  |  |
| `scope_to_assignment_unit` | boolean |  | `true` |  |
| `include_descendants` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `designation_role_pkey`: `PRIMARY KEY (designation_id, role_id)`
- FK `designation_role_designation_id_fkey`: `FOREIGN KEY (designation_id) REFERENCES people.designation(id) ON DELETE CASCADE`
- FK `designation_role_role_id_fkey`: `FOREIGN KEY (role_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- CHECK `designation_role_check`: `CHECK ((scope_to_assignment_unit OR include_descendants))`

<a id="authzpermission"></a>
### `authz.permission`

resource × action. Code module.resource.action is derived (authz.v_permission_code).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `resource_id` | integer |  |  |  |
| `action_id` | smallint |  |  |  |
| `description` | text | yes |  |  |
| `is_scopable` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `permission_pkey`: `PRIMARY KEY (id)`
- UNIQUE `permission_resource_id_action_id_key`: `UNIQUE (resource_id, action_id)`
- FK `permission_action_id_fkey`: `FOREIGN KEY (action_id) REFERENCES authz.action(id)`
- FK `permission_resource_id_fkey`: `FOREIGN KEY (resource_id) REFERENCES authz.resource(id)`

<a id="authzposition_role"></a>
### `authz.position_role`

Rule: an active appointment to a position confers a role on that unit.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `position_type_id` | smallint |  |  |  |
| `role_id` | integer |  |  |  |
| `include_descendants` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `position_role_pkey`: `PRIMARY KEY (position_type_id, role_id)`
- FK `position_role_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id) ON DELETE CASCADE`
- FK `position_role_role_id_fkey`: `FOREIGN KEY (role_id) REFERENCES authz.role(id) ON DELETE CASCADE`

<a id="authzprincipal_kind_role"></a>
### `authz.principal_kind_role`

Rule: baseline role for every current employee / student / guardian.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `principal_kind_id` | smallint |  |  |  |
| `employee_category_id` | smallint | yes |  |  |
| `role_id` | integer |  |  |  |
| `scope_to_home_unit` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `principal_kind_role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `principal_kind_role_uq`: `UNIQUE NULLS NOT DISTINCT (principal_kind_id, employee_category_id, role_id)`
- FK `principal_kind_role_employee_category_id_fkey`: `FOREIGN KEY (employee_category_id) REFERENCES ref.employee_category(id)`
- FK `principal_kind_role_principal_kind_id_fkey`: `FOREIGN KEY (principal_kind_id) REFERENCES ref.principal_kind(id)`
- FK `principal_kind_role_role_id_fkey`: `FOREIGN KEY (role_id) REFERENCES authz.role(id) ON DELETE CASCADE`

<a id="authzresource"></a>
### `authz.resource`

Things a module protects. _module = the module itself (for access).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `app_module_id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |

**Constraints & indexes**

- PK `resource_pkey`: `PRIMARY KEY (id)`
- UNIQUE `resource_app_module_id_code_key`: `UNIQUE (app_module_id, code)`
- FK `resource_app_module_id_fkey`: `FOREIGN KEY (app_module_id) REFERENCES authz.app_module(id)`
- CHECK `resource_code_check`: `CHECK ((code ~ '^_?[a-z][a-z0-9_]{0,40}$'::citext))`

<a id="authzrole"></a>
### `authz.role`

Named bundle of permissions; requires_mfa forces MFA for holders.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `code` | citext |  |  |  |
| `name` | text |  |  |  |
| `description` | text | yes |  |  |
| `is_system` | boolean |  | `false` |  |
| `requires_mfa` | boolean |  | `false` |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `role_pkey`: `PRIMARY KEY (id)`
- UNIQUE `role_code_key`: `UNIQUE (code)`
- UNIQUE `role_name_key`: `UNIQUE (name)`
- CHECK `role_code_check`: `CHECK ((code ~ '^[A-Z][A-Z0-9_]{1,60}$'::citext))`

<a id="authzrole_conflict"></a>
### `authz.role_conflict`

Static separation of duties: roles that may not be held together.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `role_a_id` | integer |  |  |  |
| `role_b_id` | integer |  |  |  |
| `reason` | text | yes |  |  |

**Constraints & indexes**

- PK `role_conflict_pkey`: `PRIMARY KEY (role_a_id, role_b_id)`
- FK `role_conflict_role_a_id_fkey`: `FOREIGN KEY (role_a_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- FK `role_conflict_role_b_id_fkey`: `FOREIGN KEY (role_b_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- CHECK `role_conflict_check`: `CHECK ((role_a_id < role_b_id))`

<a id="authzrole_inheritance"></a>
### `authz.role_inheritance`

Senior role inherits all permissions of the junior role (acyclic).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `senior_role_id` | integer |  |  |  |
| `junior_role_id` | integer |  |  |  |

**Constraints & indexes**

- PK `role_inheritance_pkey`: `PRIMARY KEY (senior_role_id, junior_role_id)`
- FK `role_inheritance_junior_role_id_fkey`: `FOREIGN KEY (junior_role_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- FK `role_inheritance_senior_role_id_fkey`: `FOREIGN KEY (senior_role_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- CHECK `role_inheritance_check`: `CHECK ((senior_role_id <> junior_role_id))`

<a id="authzrole_permission"></a>
### `authz.role_permission`

Permissions contained in a role.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `role_id` | integer |  |  |  |
| `permission_id` | integer |  |  |  |

**Constraints & indexes**

- PK `role_permission_pkey`: `PRIMARY KEY (role_id, permission_id)`
- FK `role_permission_permission_id_fkey`: `FOREIGN KEY (permission_id) REFERENCES authz.permission(id) ON DELETE CASCADE`
- FK `role_permission_role_id_fkey`: `FOREIGN KEY (role_id) REFERENCES authz.role(id) ON DELETE CASCADE`
- INDEX `role_permission_permission_idx`: `btree (permission_id)`

## Schema `wf` — Approval workflow

<a id="wfapproval_action"></a>
### `wf.approval_action`

Append-only log of approve / sign / return / withdraw; the round's status is derived from it (wf.v_instance_state).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `instance_id` | uuid |  |  |  |
| `step_seq` | smallint | yes |  |  |
| `wf_action_type_id` | smallint |  |  |  |
| `actor_account_id` | uuid | yes |  |  |
| `acted_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `note` | text | yes |  | IDENTITY |
| `file_object_id` | uuid | yes |  |  |
| `target_account_id` | uuid | yes |  |  |
| `target_org_unit_id` | uuid | yes |  |  |
| `return_to_seq` | smallint | yes |  |  |
| `on_behalf_of_account_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `approval_action_pkey`: `PRIMARY KEY (id)`
- FK `approval_action_actor_account_id_fkey`: `FOREIGN KEY (actor_account_id) REFERENCES iam.user_account(id)`
- FK `approval_action_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `approval_action_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_action_instance_id_return_to_seq_fkey`: `FOREIGN KEY (instance_id, return_to_seq) REFERENCES wf.approval_step(instance_id, seq)`
- FK `approval_action_instance_id_step_seq_fkey`: `FOREIGN KEY (instance_id, step_seq) REFERENCES wf.approval_step(instance_id, seq)`
- FK `approval_action_on_behalf_of_account_id_fkey`: `FOREIGN KEY (on_behalf_of_account_id) REFERENCES iam.user_account(id)`
- FK `approval_action_target_account_id_fkey`: `FOREIGN KEY (target_account_id) REFERENCES iam.user_account(id)`
- FK `approval_action_target_org_unit_id_fkey`: `FOREIGN KEY (target_org_unit_id) REFERENCES org.org_unit(id)`
- FK `approval_action_wf_action_type_id_fkey`: `FOREIGN KEY (wf_action_type_id) REFERENCES ref.wf_action_type(id)`
- CHECK `approval_action_check`: `CHECK (((on_behalf_of_account_id IS NULL) OR (on_behalf_of_account_id <> actor_account_id)))`
- INDEX `action_actor_idx`: `btree (actor_account_id)`
- INDEX `action_instance_idx`: `btree (instance_id)`

<a id="wfapproval_chain"></a>
### `wf.approval_chain`

The approval chain of a document type — default, or overriding it for an org subtree — valid for a period.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `document_type_id` | smallint |  |  |  |
| `scope_org_unit_id` | uuid | yes |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `note` | text | yes |  |  |
| `allows_level_override` | boolean |  | `true` |  |
| `min_approved_levels` | smallint |  | `2` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `approval_chain_pkey`: `PRIMARY KEY (id)`
- UNIQUE `approval_chain_id_document_type_id_key`: `UNIQUE (id, document_type_id)`
- FK `approval_chain_document_type_id_fkey`: `FOREIGN KEY (document_type_id) REFERENCES wf.approval_document_type(id)`
- FK `approval_chain_scope_org_unit_id_fkey`: `FOREIGN KEY (scope_org_unit_id) REFERENCES org.org_unit(id)`
- CHECK `approval_chain_min_approved_levels_check`: `CHECK ((min_approved_levels >= 1))`
- CHECK `approval_chain_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `chain_one_per_scope`: `EXCLUDE USING gist (document_type_id WITH =, COALESCE(scope_org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, valid WITH &&)`

<a id="wfapproval_chain_stage"></a>
### `wf.approval_chain_stage`

One level of a chain, all configuration: who approves (permission at an org level / position / manager / named / committee), how many, when it applies (amount band, flag), self-approval rule, required file / signature, forwarding and return-to, deadline and timeout action; the signature stage is last.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `chain_id` | integer |  |  |  |
| `seq` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `wf_approver_kind_id` | smallint |  |  |  |
| `permission_id` | integer | yes |  |  |
| `anchor_org_unit_type_id` | smallint | yes |  |  |
| `anchor_is_owner` | boolean |  | `false` |  |
| `position_type_id` | smallint | yes |  |  |
| `reporting_line_type_id` | smallint | yes |  |  |
| `manager_level` | smallint | yes |  |  |
| `academic_body_id` | uuid | yes |  |  |
| `named_account_id` | uuid | yes |  |  |
| `required_approvals` | smallint | yes |  |  |
| `min_amount` | numeric(14,2) | yes |  |  |
| `max_amount` | numeric(14,2) | yes |  |  |
| `wf_flag_id` | smallint | yes |  |  |
| `flag_must_be_absent` | boolean |  | `false` |  |
| `wf_self_action_id` | smallint |  |  |  |
| `needs_file` | boolean |  | `false` |  |
| `allows_forward` | boolean |  | `false` |  |
| `allows_return_to` | boolean |  | `false` |  |
| `due_within` | interval | yes |  |  |
| `wf_timeout_action_id` | smallint |  |  |  |
| `is_signature` | boolean |  | `false` |  |
| `is_mandatory` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `approval_chain_stage_pkey`: `PRIMARY KEY (chain_id, seq)`
- UNIQUE `approval_chain_stage_chain_id_code_key`: `UNIQUE (chain_id, code)`
- FK `approval_chain_stage_academic_body_id_fkey`: `FOREIGN KEY (academic_body_id) REFERENCES academic.academic_body(id)`
- FK `approval_chain_stage_anchor_org_unit_type_id_fkey`: `FOREIGN KEY (anchor_org_unit_type_id) REFERENCES ref.org_unit_type(id)`
- FK `approval_chain_stage_chain_id_fkey`: `FOREIGN KEY (chain_id) REFERENCES wf.approval_chain(id) ON DELETE CASCADE`
- FK `approval_chain_stage_named_account_id_fkey`: `FOREIGN KEY (named_account_id) REFERENCES iam.user_account(id)`
- FK `approval_chain_stage_permission_id_fkey`: `FOREIGN KEY (permission_id) REFERENCES authz.permission(id)`
- FK `approval_chain_stage_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- FK `approval_chain_stage_reporting_line_type_id_fkey`: `FOREIGN KEY (reporting_line_type_id) REFERENCES ref.reporting_line_type(id)`
- FK `approval_chain_stage_wf_approver_kind_id_fkey`: `FOREIGN KEY (wf_approver_kind_id) REFERENCES ref.wf_approver_kind(id)`
- FK `approval_chain_stage_wf_flag_id_fkey`: `FOREIGN KEY (wf_flag_id) REFERENCES ref.wf_flag(id)`
- FK `approval_chain_stage_wf_self_action_id_fkey`: `FOREIGN KEY (wf_self_action_id) REFERENCES ref.wf_self_action(id)`
- FK `approval_chain_stage_wf_timeout_action_id_fkey`: `FOREIGN KEY (wf_timeout_action_id) REFERENCES ref.wf_timeout_action(id)`
- CHECK `approval_chain_stage_check`: `CHECK ((NOT (anchor_is_owner AND (anchor_org_unit_type_id IS NOT NULL))))`
- CHECK `approval_chain_stage_check1`: `CHECK (((max_amount IS NULL) OR (max_amount > COALESCE(min_amount, (0)::numeric))))`
- CHECK `approval_chain_stage_check2`: `CHECK (((NOT flag_must_be_absent) OR (wf_flag_id IS NOT NULL)))`
- CHECK `approval_chain_stage_due_within_check`: `CHECK ((due_within > '00:00:00'::interval))`
- CHECK `approval_chain_stage_manager_level_check`: `CHECK (((manager_level >= 1) AND (manager_level <= 5)))`
- CHECK `approval_chain_stage_min_amount_check`: `CHECK ((min_amount >= (0)::numeric))`
- CHECK `approval_chain_stage_required_approvals_check`: `CHECK ((required_approvals >= 1))`
- CHECK `approval_chain_stage_seq_check`: `CHECK ((seq >= 1))`

<a id="wfapproval_chain_stage_check"></a>
### `wf.approval_chain_stage_check`

Checklist items an approver of a level must tick before approving (mandatory or optional).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `chain_id` | integer |  |  |  |
| `seq` | smallint |  |  |  |
| `check_no` | smallint |  |  |  |
| `label` | text |  |  |  |
| `is_mandatory` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `approval_chain_stage_check_pkey`: `PRIMARY KEY (chain_id, seq, check_no)`
- FK `approval_chain_stage_check_chain_id_seq_fkey`: `FOREIGN KEY (chain_id, seq) REFERENCES wf.approval_chain_stage(chain_id, seq) ON DELETE CASCADE`
- CHECK `approval_chain_stage_check_check_no_check`: `CHECK ((check_no >= 1))`
- CHECK `approval_chain_stage_check_label_check`: `CHECK ((btrim(label) <> ''::text))`

<a id="wfapproval_comment"></a>
### `wf.approval_comment`

Reviewer remark on a round, optionally on a table / row / column with a suggested value; resolved by the submitter.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `instance_id` | uuid |  |  |  |
| `step_seq` | smallint |  |  |  |
| `author_account_id` | uuid |  |  |  |
| `target_table` | text | yes |  |  |
| `target_row_id` | uuid | yes |  |  |
| `target_column` | text | yes |  |  |
| `body` | text |  |  | IDENTITY |
| `suggested_value` | text | yes |  | IDENTITY |
| `wf_comment_status_id` | smallint |  |  |  |
| `resolved_by_account_id` | uuid | yes |  |  |
| `resolved_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `approval_comment_pkey`: `PRIMARY KEY (id)`
- FK `approval_comment_author_account_id_fkey`: `FOREIGN KEY (author_account_id) REFERENCES iam.user_account(id)`
- FK `approval_comment_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_comment_instance_id_step_seq_fkey`: `FOREIGN KEY (instance_id, step_seq) REFERENCES wf.approval_step(instance_id, seq)`
- FK `approval_comment_resolved_by_account_id_fkey`: `FOREIGN KEY (resolved_by_account_id) REFERENCES iam.user_account(id)`
- FK `approval_comment_wf_comment_status_id_fkey`: `FOREIGN KEY (wf_comment_status_id) REFERENCES ref.wf_comment_status(id)`
- CHECK `approval_comment_body_check`: `CHECK ((btrim(body) <> ''::text))`
- CHECK `approval_comment_check`: `CHECK (((target_row_id IS NULL) OR (target_table IS NOT NULL)))`
- CHECK `approval_comment_check1`: `CHECK (((target_column IS NULL) OR (target_table IS NOT NULL)))`
- CHECK `approval_comment_check2`: `CHECK (((suggested_value IS NULL) OR (target_column IS NOT NULL)))`
- CHECK `approval_comment_check3`: `CHECK (((resolved_at IS NULL) = (resolved_by_account_id IS NULL)))`
- INDEX `comment_instance_idx`: `btree (instance_id)`

<a id="wfapproval_consultation"></a>
### `wf.approval_consultation`

A question put to someone outside the chain by the submitter or a current approver, and the reply; never blocks the round.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `instance_id` | uuid |  |  |  |
| `asked_by_account_id` | uuid |  |  |  |
| `asked_account_id` | uuid |  |  |  |
| `question` | text |  |  | IDENTITY |
| `asked_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `reply` | text | yes |  | IDENTITY |
| `replied_at` | timestamp with time zone | yes |  |  |
| `reply_file_object_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `approval_consultation_pkey`: `PRIMARY KEY (id)`
- FK `approval_consultation_asked_account_id_fkey`: `FOREIGN KEY (asked_account_id) REFERENCES iam.user_account(id)`
- FK `approval_consultation_asked_by_account_id_fkey`: `FOREIGN KEY (asked_by_account_id) REFERENCES iam.user_account(id)`
- FK `approval_consultation_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_consultation_reply_file_object_id_fkey`: `FOREIGN KEY (reply_file_object_id) REFERENCES people.file_object(id)`
- CHECK `approval_consultation_check`: `CHECK ((asked_by_account_id <> asked_account_id))`
- CHECK `approval_consultation_check1`: `CHECK (((reply IS NULL) = (replied_at IS NULL)))`
- CHECK `approval_consultation_question_check`: `CHECK ((btrim(question) <> ''::text))`
- INDEX `approval_consultation_asked_idx`: `btree (asked_account_id)`
- INDEX `approval_consultation_instance_idx`: `btree (instance_id)`

<a id="wfapproval_delegation"></a>
### `wf.approval_delegation`

Standing delegation (out of office): for a bounded period the delegate may act wherever the delegator could, for one document type or all; actions record both.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `delegator_account_id` | uuid |  |  |  |
| `delegate_account_id` | uuid |  |  |  |
| `document_type_id` | smallint | yes |  |  |
| `valid` | tstzrange |  |  |  |
| `reason` | text | yes |  | IDENTITY |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `approval_delegation_pkey`: `PRIMARY KEY (id)`
- FK `approval_delegation_delegate_account_id_fkey`: `FOREIGN KEY (delegate_account_id) REFERENCES iam.user_account(id)`
- FK `approval_delegation_delegator_account_id_fkey`: `FOREIGN KEY (delegator_account_id) REFERENCES iam.user_account(id)`
- FK `approval_delegation_document_type_id_fkey`: `FOREIGN KEY (document_type_id) REFERENCES wf.approval_document_type(id)`
- CHECK `approval_delegation_check`: `CHECK ((delegator_account_id <> delegate_account_id))`
- CHECK `approval_delegation_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid)) AND (NOT upper_inf(valid))))`
- EXCLUDE `approval_delegation_one`: `EXCLUDE USING gist (delegator_account_id WITH =, COALESCE((document_type_id)::integer, 0) WITH =, valid WITH &&)`
- INDEX `approval_delegation_delegate_idx`: `btree (delegate_account_id)`

<a id="wfapproval_document_type"></a>
### `wf.approval_document_type`

A kind of document that goes through approval (CURRICULUM, INTERNAL_MARKS_REVISION …) and the permission needed to submit it.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `app_module_id` | smallint |  |  |  |
| `author_permission_id` | integer |  |  |  |
| `viewer_permission_id` | integer | yes |  |  |
| `allows_empty_chain` | boolean |  | `false` |  |
| `link_table` | text | yes |  |  |
| `link_document_column` | text | yes |  |  |
| `is_active` | boolean |  | `true` |  |

**Constraints & indexes**

- PK `approval_document_type_pkey`: `PRIMARY KEY (id)`
- UNIQUE `approval_document_type_code_key`: `UNIQUE (code)`
- FK `approval_document_type_app_module_id_fkey`: `FOREIGN KEY (app_module_id) REFERENCES authz.app_module(id)`
- FK `approval_document_type_author_permission_id_fkey`: `FOREIGN KEY (author_permission_id) REFERENCES authz.permission(id)`
- FK `approval_document_type_viewer_permission_id_fkey`: `FOREIGN KEY (viewer_permission_id) REFERENCES authz.permission(id)`
- CHECK `approval_document_type_check`: `CHECK (((link_table IS NULL) = (link_document_column IS NULL)))`
- CHECK `approval_document_type_code_check`: `CHECK ((code ~ '^[A-Z][A-Z0-9_]{1,60}$'::citext))`
- CHECK `approval_document_type_link_document_column_check`: `CHECK ((link_document_column ~ '^[a-z_0-9]+$'::text))`
- CHECK `approval_document_type_link_table_check`: `CHECK ((link_table ~ '^[a-z_]+\.[a-z_0-9]+$'::text))`

<a id="wfapproval_instance"></a>
### `wf.approval_instance`

One approval round of one document: owning unit, submitter, time. Created by wf.submit(); append-only.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `document_type_id` | smallint |  |  |  |
| `chain_id` | integer |  |  |  |
| `owner_org_unit_id` | uuid |  |  |  |
| `submitted_by_account_id` | uuid |  |  |  |
| `submitted_at` | timestamp with time zone |  | `clock_timestamp()` |  |
| `note` | text | yes |  | IDENTITY |
| `amount` | numeric(14,2) | yes |  |  |
| `subject_person_id` | uuid | yes |  |  |
| `revises_instance_id` | uuid | yes |  |  |
| `allows_level_override` | boolean |  | `false` |  |
| `min_approved_levels` | smallint |  | `2` |  |

**Constraints & indexes**

- PK `approval_instance_pkey`: `PRIMARY KEY (id)`
- FK `approval_instance_chain_id_document_type_id_fkey`: `FOREIGN KEY (chain_id, document_type_id) REFERENCES wf.approval_chain(id, document_type_id)`
- FK `approval_instance_chain_id_fkey`: `FOREIGN KEY (chain_id) REFERENCES wf.approval_chain(id)`
- FK `approval_instance_document_type_id_fkey`: `FOREIGN KEY (document_type_id) REFERENCES wf.approval_document_type(id)`
- FK `approval_instance_owner_org_unit_id_fkey`: `FOREIGN KEY (owner_org_unit_id) REFERENCES org.org_unit(id)`
- FK `approval_instance_revises_instance_id_fkey`: `FOREIGN KEY (revises_instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_instance_subject_person_id_fkey`: `FOREIGN KEY (subject_person_id) REFERENCES people.person(id)`
- FK `approval_instance_submitted_by_account_id_fkey`: `FOREIGN KEY (submitted_by_account_id) REFERENCES iam.user_account(id)`
- CHECK `approval_instance_amount_check`: `CHECK ((amount >= (0)::numeric))`
- CHECK `approval_instance_min_approved_levels_check`: `CHECK ((min_approved_levels >= 1))`
- INDEX `instance_owner_idx`: `btree (owner_org_unit_id)`
- INDEX `instance_submitter_idx`: `btree (submitted_by_account_id)`

<a id="wfapproval_instance_flag"></a>
### `wf.approval_instance_flag`

The flags a round was submitted with; level conditions are evaluated on them.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `instance_id` | uuid |  |  |  |
| `wf_flag_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `approval_instance_flag_pkey`: `PRIMARY KEY (instance_id, wf_flag_id)`
- FK `approval_instance_flag_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_instance_flag_wf_flag_id_fkey`: `FOREIGN KEY (wf_flag_id) REFERENCES ref.wf_flag(id)`

<a id="wfapproval_notice"></a>
### `wf.approval_notice`

Outbox of approval notices for the application to deliver (pending, reminder, escalated, forwarded, returned, rejected, approved); one of a kind per step, account and day.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `instance_id` | uuid |  |  |  |
| `step_seq` | smallint | yes |  |  |
| `wf_notice_kind_id` | smallint |  |  |  |
| `account_id` | uuid | yes |  |  |
| `notice_date` | date |  | `CURRENT_DATE` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `dispatched_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `approval_notice_pkey`: `PRIMARY KEY (id)`
- FK `approval_notice_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id)`
- FK `approval_notice_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id)`
- FK `approval_notice_wf_notice_kind_id_fkey`: `FOREIGN KEY (wf_notice_kind_id) REFERENCES ref.wf_notice_kind(id)`
- INDEX `approval_notice_once`: `btree (instance_id, COALESCE((step_seq)::integer, 0), wf_notice_kind_id, COALESCE(account_id, '00000000-0000-0000-0000-000000000000'::uuid), notice_date)`

<a id="wfapproval_step"></a>
### `wf.approval_step`

The stages of a round snapshotted at submission, with the anchor unit resolved (the actual department / school / university).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `instance_id` | uuid |  |  |  |
| `seq` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `wf_approver_kind_id` | smallint |  |  |  |
| `permission_id` | integer | yes |  |  |
| `anchor_org_unit_id` | uuid |  |  |  |
| `position_type_id` | smallint | yes |  |  |
| `required_approvals` | smallint | yes |  |  |
| `needs_file` | boolean |  | `false` |  |
| `allows_forward` | boolean |  | `false` |  |
| `allows_return_to` | boolean |  | `false` |  |
| `due_within` | interval | yes |  |  |
| `wf_timeout_action_id` | smallint |  |  |  |
| `is_signature` | boolean |  |  |  |
| `is_mandatory` | boolean |  | `false` |  |

**Constraints & indexes**

- PK `approval_step_pkey`: `PRIMARY KEY (instance_id, seq)`
- FK `approval_step_anchor_org_unit_id_fkey`: `FOREIGN KEY (anchor_org_unit_id) REFERENCES org.org_unit(id)`
- FK `approval_step_instance_id_fkey`: `FOREIGN KEY (instance_id) REFERENCES wf.approval_instance(id) ON DELETE CASCADE`
- FK `approval_step_permission_id_fkey`: `FOREIGN KEY (permission_id) REFERENCES authz.permission(id)`
- FK `approval_step_position_type_id_fkey`: `FOREIGN KEY (position_type_id) REFERENCES org.position_type(id)`
- FK `approval_step_wf_approver_kind_id_fkey`: `FOREIGN KEY (wf_approver_kind_id) REFERENCES ref.wf_approver_kind(id)`
- FK `approval_step_wf_timeout_action_id_fkey`: `FOREIGN KEY (wf_timeout_action_id) REFERENCES ref.wf_timeout_action(id)`
- CHECK `approval_step_required_approvals_check`: `CHECK ((required_approvals >= 1))`

<a id="wfapproval_step_assignee"></a>
### `wf.approval_step_assignee`

The named approvers of a step: resolved at submission (manager, named, committee members) or added by FORWARD / DELEGATE / ESCALATE; released when handed on.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `instance_id` | uuid |  |  |  |
| `seq` | smallint |  |  |  |
| `account_id` | uuid |  |  |  |
| `added_by_action_id` | bigint | yes |  |  |
| `released_by_action_id` | bigint | yes |  |  |

**Constraints & indexes**

- PK `approval_step_assignee_pkey`: `PRIMARY KEY (instance_id, seq, account_id)`
- FK `approval_step_assignee_account_id_fkey`: `FOREIGN KEY (account_id) REFERENCES iam.user_account(id)`
- FK `approval_step_assignee_added_by_action_id_fkey`: `FOREIGN KEY (added_by_action_id) REFERENCES wf.approval_action(id)`
- FK `approval_step_assignee_instance_id_seq_fkey`: `FOREIGN KEY (instance_id, seq) REFERENCES wf.approval_step(instance_id, seq) ON DELETE CASCADE`
- FK `approval_step_assignee_released_by_action_id_fkey`: `FOREIGN KEY (released_by_action_id) REFERENCES wf.approval_action(id)`
- INDEX `step_assignee_account_idx`: `btree (account_id)`

<a id="wfapproval_step_check"></a>
### `wf.approval_step_check`

Checklist items ticked by an approver on a step of a round.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `instance_id` | uuid |  |  |  |
| `seq` | smallint |  |  |  |
| `check_no` | smallint |  |  |  |
| `checked_by_account_id` | uuid |  |  |  |
| `checked_at` | timestamp with time zone |  | `clock_timestamp()` |  |

**Constraints & indexes**

- PK `approval_step_check_pkey`: `PRIMARY KEY (instance_id, seq, check_no, checked_by_account_id)`
- FK `approval_step_check_checked_by_account_id_fkey`: `FOREIGN KEY (checked_by_account_id) REFERENCES iam.user_account(id)`
- FK `approval_step_check_instance_id_seq_fkey`: `FOREIGN KEY (instance_id, seq) REFERENCES wf.approval_step(instance_id, seq) ON DELETE CASCADE`

## Schema `privacy` — DPDP privacy controls

<a id="privacybreach_affected_person"></a>
### `privacy.breach_affected_person`

Persons affected by a breach.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `incident_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |

**Constraints & indexes**

- PK `breach_affected_person_pkey`: `PRIMARY KEY (incident_id, person_id)`
- FK `breach_affected_person_incident_id_fkey`: `FOREIGN KEY (incident_id) REFERENCES privacy.breach_incident(id) ON DELETE CASCADE`
- FK `breach_affected_person_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`

<a id="privacybreach_incident"></a>
### `privacy.breach_incident`

Personal data breach register (§8(6)).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `title` | text |  |  |  |
| `description` | text |  |  | IDENTITY |
| `breach_severity_id` | smallint |  |  |  |
| `breach_status_id` | smallint |  |  |  |
| `occurred_from` | timestamp with time zone | yes |  |  |
| `detected_at` | timestamp with time zone |  |  |  |
| `board_notified_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `breach_incident_pkey`: `PRIMARY KEY (id)`
- FK `breach_incident_breach_severity_id_fkey`: `FOREIGN KEY (breach_severity_id) REFERENCES ref.breach_severity(id)`
- FK `breach_incident_breach_status_id_fkey`: `FOREIGN KEY (breach_status_id) REFERENCES ref.breach_status(id)`
- CHECK `breach_incident_check`: `CHECK (((occurred_from IS NULL) OR (occurred_from <= detected_at)))`
- CHECK `breach_incident_check1`: `CHECK (((board_notified_at IS NULL) OR (board_notified_at >= detected_at)))`

<a id="privacybreach_notification"></a>
### `privacy.breach_notification`

Breach intimations sent to affected persons.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `incident_id` | uuid |  |  |  |
| `person_id` | uuid |  |  |  |
| `contact_channel_id` | smallint |  |  |  |
| `sent_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `breach_notification_pkey`: `PRIMARY KEY (id)`
- FK `breach_notification_contact_channel_id_fkey`: `FOREIGN KEY (contact_channel_id) REFERENCES ref.contact_channel(id)`
- FK `breach_notification_incident_id_person_id_fkey`: `FOREIGN KEY (incident_id, person_id) REFERENCES privacy.breach_affected_person(incident_id, person_id) ON DELETE CASCADE`

<a id="privacyconsent"></a>
### `privacy.consent`

Consent acts per principal and purpose (§6); withdrawal closes the row; one active per purpose.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `principal_person_id` | uuid |  |  |  |
| `notice_id` | uuid |  |  |  |
| `purpose_id` | smallint |  |  |  |
| `given_by_person_id` | uuid |  |  |  |
| `consent_channel_id` | smallint |  |  |  |
| `consent_manager_ref` | text | yes |  |  |
| `ip` | inet | yes |  | DEVICE_NETWORK |
| `granted_at` | timestamp with time zone |  | `now()` |  |
| `withdrawn_at` | timestamp with time zone | yes |  |  |

**Constraints & indexes**

- PK `consent_pkey`: `PRIMARY KEY (id)`
- FK `consent_consent_channel_id_fkey`: `FOREIGN KEY (consent_channel_id) REFERENCES ref.consent_channel(id)`
- FK `consent_given_by_person_id_fkey`: `FOREIGN KEY (given_by_person_id) REFERENCES people.person(id)`
- FK `consent_notice_id_purpose_id_fkey`: `FOREIGN KEY (notice_id, purpose_id) REFERENCES privacy.notice_purpose(notice_id, purpose_id)`
- FK `consent_principal_person_id_fkey`: `FOREIGN KEY (principal_person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `consent_check`: `CHECK (((withdrawn_at IS NULL) OR (withdrawn_at >= granted_at)))`
- EXCLUDE `consent_one_active_per_purpose`: `EXCLUDE USING gist (principal_person_id WITH =, purpose_id WITH =, tstzrange(granted_at, withdrawn_at) WITH &&)`
- INDEX `consent_principal_idx`: `btree (principal_person_id)`

<a id="privacydata_element"></a>
### `privacy.data_element`

Personal-data inventory: column → category → erasure action. Drives exports, erasure and audit redaction.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | integer |  |  |  |
| `schema_name` | name |  |  |  |
| `table_name` | name |  |  |  |
| `column_name` | name |  |  |  |
| `data_category_id` | smallint |  |  |  |
| `erasure_action_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `data_element_pkey`: `PRIMARY KEY (id)`
- UNIQUE `data_element_schema_name_table_name_column_name_key`: `UNIQUE (schema_name, table_name, column_name)`
- FK `data_element_data_category_id_fkey`: `FOREIGN KEY (data_category_id) REFERENCES ref.data_category(id)`
- FK `data_element_erasure_action_id_fkey`: `FOREIGN KEY (erasure_action_id) REFERENCES ref.erasure_action(id)`

<a id="privacydata_principal_request"></a>
### `privacy.data_principal_request`

Rights requests: access, correction, erasure, grievance, nomination (§§11–14).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `person_id` | uuid |  |  |  |
| `dpr_request_type_id` | smallint |  |  |  |
| `submitted_by_person_id` | uuid |  |  |  |
| `details` | text | yes |  | IDENTITY |
| `submitted_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `data_principal_request_pkey`: `PRIMARY KEY (id)`
- FK `data_principal_request_dpr_request_type_id_fkey`: `FOREIGN KEY (dpr_request_type_id) REFERENCES ref.dpr_request_type(id)`
- FK `data_principal_request_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- FK `data_principal_request_submitted_by_person_id_fkey`: `FOREIGN KEY (submitted_by_person_id) REFERENCES people.person(id)`
- INDEX `data_principal_request_person_idx`: `btree (person_id)`

<a id="privacydata_processor"></a>
### `privacy.data_processor`

Third parties processing personal data on the university's behalf (§8(2)).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `name` | text |  |  |  |
| `country_id` | smallint |  |  |  |
| `dpa_signed_on` | date | yes |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `data_processor_pkey`: `PRIMARY KEY (id)`
- UNIQUE `data_processor_name_key`: `UNIQUE (name)`
- FK `data_processor_country_id_fkey`: `FOREIGN KEY (country_id) REFERENCES ref.country(id)`

<a id="privacydpr_request_event"></a>
### `privacy.dpr_request_event`

Status history of a rights request; current status is the latest event.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `request_id` | uuid |  |  |  |
| `dpr_status_id` | smallint |  |  |  |
| `actor_account_id` | uuid | yes |  |  |
| `note` | text | yes |  | IDENTITY |
| `occurred_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `dpr_request_event_pkey`: `PRIMARY KEY (id)`
- FK `dpr_request_event_actor_account_id_fkey`: `FOREIGN KEY (actor_account_id) REFERENCES iam.user_account(id)`
- FK `dpr_request_event_dpr_status_id_fkey`: `FOREIGN KEY (dpr_status_id) REFERENCES ref.dpr_status(id)`
- FK `dpr_request_event_request_id_fkey`: `FOREIGN KEY (request_id) REFERENCES privacy.data_principal_request(id) ON DELETE CASCADE`
- INDEX `dpr_request_event_request_idx`: `btree (request_id, occurred_at DESC)`

<a id="privacyerasure_log"></a>
### `privacy.erasure_log`

Evidence of erasure / anonymisation actions (§8(7)).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `person_id` | uuid | yes |  |  |
| `data_element_id` | integer |  |  |  |
| `erasure_action_id` | smallint |  |  |  |
| `request_id` | uuid | yes |  |  |
| `executed_by_account_id` | uuid | yes |  |  |
| `executed_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `erasure_log_pkey`: `PRIMARY KEY (id)`
- FK `erasure_log_data_element_id_fkey`: `FOREIGN KEY (data_element_id) REFERENCES privacy.data_element(id)`
- FK `erasure_log_erasure_action_id_fkey`: `FOREIGN KEY (erasure_action_id) REFERENCES ref.erasure_action(id)`
- FK `erasure_log_executed_by_account_id_fkey`: `FOREIGN KEY (executed_by_account_id) REFERENCES iam.user_account(id)`
- FK `erasure_log_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE SET NULL`
- FK `erasure_log_request_id_fkey`: `FOREIGN KEY (request_id) REFERENCES privacy.data_principal_request(id) ON DELETE SET NULL`
- INDEX `erasure_log_person_idx`: `btree (person_id)`

<a id="privacynominee"></a>
### `privacy.nominee`

Nominee who may exercise the principal's rights (§14).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `principal_person_id` | uuid |  |  |  |
| `nominee_person_id` | uuid |  |  |  |
| `valid` | daterange |  | `daterange(CURRENT_DATE, NULL::date)` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `nominee_pkey`: `PRIMARY KEY (id)`
- FK `nominee_nominee_person_id_fkey`: `FOREIGN KEY (nominee_person_id) REFERENCES people.person(id)`
- FK `nominee_principal_person_id_fkey`: `FOREIGN KEY (principal_person_id) REFERENCES people.person(id) ON DELETE CASCADE`
- CHECK `nominee_check`: `CHECK ((principal_person_id <> nominee_person_id))`
- CHECK `nominee_valid_check`: `CHECK (((NOT isempty(valid)) AND (NOT lower_inf(valid))))`
- EXCLUDE `nominee_one_active`: `EXCLUDE USING gist (principal_person_id WITH =, valid WITH &&)`

<a id="privacynotice_purpose"></a>
### `privacy.notice_purpose`

Purposes a notice describes; consent must reference one of these.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `notice_id` | uuid |  |  |  |
| `purpose_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `notice_purpose_pkey`: `PRIMARY KEY (notice_id, purpose_id)`
- FK `notice_purpose_notice_id_fkey`: `FOREIGN KEY (notice_id) REFERENCES privacy.privacy_notice(id) ON DELETE CASCADE`
- FK `notice_purpose_purpose_id_fkey`: `FOREIGN KEY (purpose_id) REFERENCES privacy.processing_purpose(id)`

<a id="privacypii_access_log"></a>
### `privacy.pii_access_log` *(partitioned by month)*

Who accessed whose personal data for which purpose (monthly partitions).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `accessed_at` | timestamp with time zone |  | `now()` |  |
| `accessor_account_id` | uuid | yes |  |  |
| `person_id` | uuid | yes |  |  |
| `data_category_id` | smallint |  |  |  |
| `purpose_id` | smallint |  |  |  |
| `request_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `pii_access_log_pkey`: `PRIMARY KEY (id, accessed_at)`
- FK `pii_access_log_accessor_account_id_fkey`: `FOREIGN KEY (accessor_account_id) REFERENCES iam.user_account(id) ON DELETE SET NULL`
- FK `pii_access_log_data_category_id_fkey`: `FOREIGN KEY (data_category_id) REFERENCES ref.data_category(id)`
- FK `pii_access_log_person_id_fkey`: `FOREIGN KEY (person_id) REFERENCES people.person(id) ON DELETE SET NULL`
- FK `pii_access_log_purpose_id_fkey`: `FOREIGN KEY (purpose_id) REFERENCES privacy.processing_purpose(id)`
- INDEX `pii_access_log_accessor_idx`: `btree (accessor_account_id, accessed_at DESC)`
- INDEX `pii_access_log_person_idx`: `btree (person_id, accessed_at DESC)`

<a id="privacyprivacy_notice"></a>
### `privacy.privacy_notice`

Published privacy notices per version and language (§5).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | uuid |  | `gen_random_uuid()` |  |
| `version` | character varying(20) |  |  |  |
| `language_id` | smallint |  |  |  |
| `content_sha256` | bytea |  |  |  |
| `file_object_id` | uuid | yes |  |  |
| `published_at` | timestamp with time zone | yes |  |  |
| `retired_at` | timestamp with time zone | yes |  |  |
| `created_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `privacy_notice_pkey`: `PRIMARY KEY (id)`
- UNIQUE `privacy_notice_version_language_id_key`: `UNIQUE (version, language_id)`
- FK `privacy_notice_file_object_id_fkey`: `FOREIGN KEY (file_object_id) REFERENCES people.file_object(id)`
- FK `privacy_notice_language_id_fkey`: `FOREIGN KEY (language_id) REFERENCES ref.language(id)`
- CHECK `privacy_notice_check`: `CHECK (((retired_at IS NULL) OR ((published_at IS NOT NULL) AND (retired_at > published_at))))`
- CHECK `privacy_notice_content_sha256_check`: `CHECK ((octet_length(content_sha256) = 32))`

<a id="privacyprocessing_purpose"></a>
### `privacy.processing_purpose`

Purposes of processing with legal basis and retention period.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | smallint |  |  |  |
| `code` | citext |  |  |  |
| `label` | text |  |  |  |
| `description` | text |  |  |  |
| `legal_basis_id` | smallint |  |  |  |
| `retention_period` | interval |  |  |  |
| `is_active` | boolean |  | `true` |  |
| `created_at` | timestamp with time zone |  | `now()` |  |
| `updated_at` | timestamp with time zone |  | `now()` |  |

**Constraints & indexes**

- PK `processing_purpose_pkey`: `PRIMARY KEY (id)`
- UNIQUE `processing_purpose_code_key`: `UNIQUE (code)`
- FK `processing_purpose_legal_basis_id_fkey`: `FOREIGN KEY (legal_basis_id) REFERENCES ref.legal_basis(id)`
- CHECK `processing_purpose_retention_period_check`: `CHECK ((retention_period > '00:00:00'::interval))`

<a id="privacyprocessor_purpose"></a>
### `privacy.processor_purpose`

Purposes for which each processor processes data.

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `processor_id` | uuid |  |  |  |
| `purpose_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `processor_purpose_pkey`: `PRIMARY KEY (processor_id, purpose_id)`
- FK `processor_purpose_processor_id_fkey`: `FOREIGN KEY (processor_id) REFERENCES privacy.data_processor(id) ON DELETE CASCADE`
- FK `processor_purpose_purpose_id_fkey`: `FOREIGN KEY (purpose_id) REFERENCES privacy.processing_purpose(id)`

<a id="privacypurpose_data_category"></a>
### `privacy.purpose_data_category`

Categories of personal data each purpose needs (data minimisation).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `purpose_id` | smallint |  |  |  |
| `data_category_id` | smallint |  |  |  |

**Constraints & indexes**

- PK `purpose_data_category_pkey`: `PRIMARY KEY (purpose_id, data_category_id)`
- FK `purpose_data_category_data_category_id_fkey`: `FOREIGN KEY (data_category_id) REFERENCES ref.data_category(id)`
- FK `purpose_data_category_purpose_id_fkey`: `FOREIGN KEY (purpose_id) REFERENCES privacy.processing_purpose(id) ON DELETE CASCADE`

<a id="privacyverifiable_parental_consent"></a>
### `privacy.verifiable_parental_consent`

Verification of guardian consent for a child (§9).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `consent_id` | uuid |  |  |  |
| `verification_method_id` | smallint |  |  |  |
| `verified_at` | timestamp with time zone |  | `now()` |  |
| `evidence_file_id` | uuid | yes |  |  |

**Constraints & indexes**

- PK `verifiable_parental_consent_pkey`: `PRIMARY KEY (consent_id)`
- FK `verifiable_parental_consent_consent_id_fkey`: `FOREIGN KEY (consent_id) REFERENCES privacy.consent(id) ON DELETE CASCADE`
- FK `verifiable_parental_consent_evidence_file_id_fkey`: `FOREIGN KEY (evidence_file_id) REFERENCES people.file_object(id)`
- FK `verifiable_parental_consent_verification_method_id_fkey`: `FOREIGN KEY (verification_method_id) REFERENCES ref.verification_method(id)`

## Schema `audit` — Audit trail

<a id="auditaudit_change"></a>
### `audit.audit_change` *(partitioned by month)*

One row per changed column; personal-data columns stored as [REDACTED].

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `audit_event_id` | bigint |  |  |  |
| `occurred_at` | timestamp with time zone |  |  |  |
| `column_name` | name |  |  |  |
| `old_value` | text | yes |  |  |
| `new_value` | text | yes |  |  |

**Constraints & indexes**

- PK `audit_change_pkey`: `PRIMARY KEY (audit_event_id, occurred_at, column_name)`
- FK `audit_change_audit_event_id_occurred_at_fkey`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey1`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202610(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey10`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202707(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey11`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202708(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey12`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202709(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey13`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202710(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey14`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_default(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey2`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202611(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey3`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202612(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey4`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202701(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey5`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202702(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey6`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202703(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey7`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202704(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey8`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202705(id, occurred_at)`
- FK `audit_change_audit_event_id_occurred_at_fkey9`: `FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event_202706(id, occurred_at)`

<a id="auditaudit_event"></a>
### `audit.audit_event` *(partitioned by month)*

One row per changed row: actor, action, entity, request context (monthly partitions, append-only).

| Column | Type | Nullable | Default | PII |
|---|---|---|---|---|
| `id` | bigint |  |  |  |
| `occurred_at` | timestamp with time zone |  | `now()` |  |
| `actor_account_id` | uuid | yes |  |  |
| `audit_action_id` | smallint |  |  |  |
| `entity_schema` | name |  |  |  |
| `entity_table` | name |  |  |  |
| `entity_id` | text |  |  |  |
| `request_id` | uuid | yes |  |  |
| `session_id` | uuid | yes |  |  |
| `client_ip` | inet | yes |  |  |
| `txid` | bigint |  | `txid_current()` |  |

**Constraints & indexes**

- PK `audit_event_pkey`: `PRIMARY KEY (id, occurred_at)`
- FK `audit_event_audit_action_id_fkey`: `FOREIGN KEY (audit_action_id) REFERENCES ref.audit_action(id)`
- INDEX `audit_event_actor_idx`: `btree (actor_account_id, occurred_at DESC)`
- INDEX `audit_event_entity_idx`: `btree (entity_schema, entity_table, entity_id, occurred_at DESC)`

## Views (derived data)

- `academic.v_assignment_student`
- `academic.v_attendance_summary`
- `academic.v_award_eligibility`
- `academic.v_backlog`
- `academic.v_batch`
- `academic.v_class_session`
- `academic.v_co_attainment`
- `academic.v_course_completion`
- `academic.v_credit_ledger`
- `academic.v_credit_load`
- `academic.v_current_term`
- `academic.v_curriculum_item`
- `academic.v_curriculum_status`
- `academic.v_enrollment_lineage`
- `academic.v_faculty_preference_status`
- `academic.v_faculty_workload`
- `academic.v_feedback_summary`
- `academic.v_guide_load`
- `academic.v_mentoring_status`
- `academic.v_offering_quota_usage`
- `academic.v_po_attainment`
- `academic.v_prerequisite_gap`
- `academic.v_program`
- `academic.v_promotion_eligibility`
- `academic.v_registration_scheme`
- `academic.v_section_teaching`
- `academic.v_soe`
- `academic.v_soe_exit`
- `academic.v_soe_header`
- `academic.v_student_enrollment_current`
- `academic.v_student_standing`
- `academic.v_student_timetable`
- `academic.v_student_timetable_clash`
- `academic.v_student_track_progress`
- `academic.v_syllabus_coverage`
- `academic.v_teaching_gap`
- `authz.v_account_permission_effective`
- `authz.v_account_role_effective`
- `authz.v_permission_code`
- `authz.v_role_closure`
- `events.v_attendance`
- `events.v_ccc_overview`
- `events.v_certificate_verify`
- `events.v_club`
- `events.v_club_change`
- `events.v_club_leaderboard`
- `events.v_club_officer_current`
- `events.v_club_points`
- `events.v_coupon_usage`
- `events.v_duty_leave_eligible`
- `events.v_event`
- `events.v_event_budget_actual`
- `events.v_event_change`
- `events.v_event_mail`
- `events.v_event_mail_credit`
- `events.v_event_settlement`
- `events.v_event_statistics`
- `events.v_gate_summary`
- `events.v_proposal_status`
- `events.v_refund_queue`
- `events.v_registration`
- `events.v_round_attendance`
- `events.v_sponsorship_status`
- `events.v_stall`
- `events.v_stall_application`
- `events.v_team`
- `events.v_ticket`
- `events.v_volunteer_activity`
- `events.v_volunteer_assignment`
- `exam.v_cgpa`
- `exam.v_component_score`
- `exam.v_current_result`
- `exam.v_division`
- `exam.v_effective_script_mark`
- `exam.v_exam_attempt`
- `exam.v_exam_eligibility`
- `exam.v_hall_ticket`
- `exam.v_provisional_result`
- `exam.v_question_paper_blueprint`
- `exam.v_rank_list`
- `exam.v_result_group_outcome`
- `exam.v_sgpa`
- `exam.v_student_co_score`
- `facility.v_asset_register`
- `facility.v_booking_status`
- `facility.v_booking_summary`
- `facility.v_displaced_hold`
- `facility.v_event_status`
- `facility.v_guest_stay_charge`
- `facility.v_guest_stay_status`
- `facility.v_key_access`
- `facility.v_key_custody`
- `facility.v_maintenance_due`
- `facility.v_parking_zone_usage`
- `facility.v_room_timeline`
- `facility.v_room_utilisation`
- `facility.v_space_inventory`
- `facility.v_timetable_gap`
- `facility.v_trip_status`
- `facility.v_trip_summary`
- `facility.v_vehicle_document_status`
- `facility.v_work_order_status`
- `iam.v_account_active_lockout`
- `iam.v_account_last_login`
- `iam.v_login_identifier`
- `org.v_current_appointment`
- `org.v_org_unit_tree`
- `people.v_employee_current`
- `people.v_person_display_name`
- `people.v_person_principal_kind`
- `people.v_student_current`
- `pii.v_person_age`
- `privacy.v_active_consent`
- `privacy.v_dpr_request_status`
- `privacy.v_minor_consent_gap`
- `research.v_scholar_status`
- `tms.v_grievance_register`
- `tms.v_grievance_summary`
- `tms.v_kb_article_stats`
- `tms.v_ticket_category`
- `tms.v_ticket_category_rollup`
- `tms.v_ticket_category_stats`
- `tms.v_ticket_consultation`
- `tms.v_ticket_handler_stats`
- `tms.v_ticket_participant`
- `tms.v_ticket_requester_timeline`
- `tms.v_ticket_sla`
- `tms.v_ticket_state`
- `tms.v_ticket_unrouted`

## Functions

| Function | Returns |
|---|---|
| `academic.allocate_sections(p_batch uuid, p_term uuid)` | integer |
| `academic.allot_electives(p_basket uuid, p_term uuid)` | integer |
| `academic.assert_curriculum_editable(p_curriculum uuid, p_what text)` | void |
| `academic.enrollment_pathway(p_enrollment uuid, p_period daterange)` | uuid |
| `academic.enrollment_term_no(p_enrollment uuid, p_term uuid)` | integer |
| `academic.is_pattern_week(p_from date, p_every smallint, p_date date)` | boolean |
| `academic.is_program_coordinator(p_account uuid, p_program uuid)` | boolean |
| `academic.is_working_day(p_date date, p_org_unit uuid)` | boolean |
| `academic.offering_quota_for(p_offering uuid, p_enrollment uuid)` | uuid |
| `academic.register_core_courses(p_batch uuid, p_term uuid)` | integer |
| `academic.registration_scheme_id(p_course_registration uuid)` | integer |
| `academic.request_attendance_leave(p_enrollment uuid, p_leave_type text, p_period daterange, p_reason text, p_document uuid, p_account uuid)` | uuid |
| `academic.submit_curriculum(p_curriculum uuid, p_account uuid, p_note text)` | uuid |
| `academic.week_patterns_meet(a_from date, a_every smallint, b_from date, b_every smallint)` | boolean |
| `authz.accessible_org_units(p_account uuid, p_code text)` | SETOF uuid |
| `authz.account_requires_mfa(p_account uuid)` | boolean |
| `authz.has_permission(p_account uuid, p_code text, p_target uuid)` | boolean |
| `events.amount_due(p_registration uuid)` | numeric |
| `events.amount_settled(p_registration uuid)` | numeric |
| `events.apply_club_change(p_request uuid)` | void |
| `events.apply_event_change(p_request uuid)` | void |
| `events.attended(p_registration uuid)` | boolean |
| `events.can_manage(p_account uuid, p_event uuid)` | boolean |
| `events.can_see(p_event uuid, p_person uuid)` | boolean |
| `events.cancel_event(p_event uuid, p_account uuid, p_reason text)` | void |
| `events.check_in_round(p_token text, p_round uuid, p_account uuid)` | bigint |
| `events.club_is_active(p_club uuid, p_at timestamp with time zone)` | boolean |
| `events.complete_event(p_event uuid, p_account uuid)` | void |
| `events.dispatch_mail(p_mail uuid, p_account uuid)` | integer |
| `events.expire_unpaid_registrations()` | integer |
| `events.feedback_token_for(p_registration uuid)` | text |
| `events.grant_duty_leave(p_event uuid, p_account uuid)` | integer |
| `events.is_club_officer(p_account uuid, p_club uuid, p_must_propose boolean)` | boolean |
| `events.is_current_employee(p_employee uuid)` | boolean |
| `events.is_current_student(p_student uuid)` | boolean |
| `events.is_paid(p_registration uuid)` | boolean |
| `events.is_teaching_employee(p_employee uuid)` | boolean |
| `events.issue_certificates(p_event uuid, p_kind text, p_account uuid)` | integer |
| `events.issue_ticket(p_registration uuid, p_account uuid)` | text |
| `events.mail_credits_total(p_event uuid)` | integer |
| `events.mail_credits_used(p_event uuid)` | integer |
| `events.mail_opened(p_recipient uuid)` | void |
| `events.may_propose_for(p_account uuid, p_unit uuid)` | boolean |
| `events.payer_registration(p_registration uuid)` | uuid |
| `events.people_inside(p_registration uuid)` | integer |
| `events.promote_waitlist(p_event uuid)` | integer |
| `events.publish_event(p_event uuid, p_account uuid)` | void |
| `events.record_refund(p_payment uuid, p_account uuid, p_reference text, p_note text)` | void |
| `events.redeem_coupon(p_registration uuid, p_code text, p_account uuid)` | numeric |
| `events.register(p_event uuid, p_account uuid)` | uuid |
| `events.registration_state(p_registration uuid)` | text |
| `events.run_mail_scheduler()` | integer |
| `events.scan(p_token text, p_direction text, p_account uuid, p_people integer, p_gate text)` | bigint |
| `events.seat_limit(p_event uuid)` | integer |
| `events.seats_taken(p_event uuid)` | integer |
| `events.stall_fee(p_application uuid)` | numeric |
| `events.submit_club_change(p_request uuid, p_account uuid)` | uuid |
| `events.submit_club_proposal(p_proposal uuid, p_account uuid)` | uuid |
| `events.submit_event_change(p_request uuid, p_account uuid)` | uuid |
| `events.submit_feedback(p_token text, p_rating integer, p_comment text)` | void |
| `events.submit_proposal(p_proposal uuid, p_account uuid)` | uuid |
| `events.submit_settlement(p_event uuid, p_account uuid, p_remarks text)` | uuid |
| `events.submit_stall_feedback(p_stall_code text, p_scores integer[], p_comment text)` | void |
| `events.team_size(p_team uuid)` | integer |
| `events.ticket_check(p_token text, p_account uuid)` | TABLE(registration_id uuid, registration_code citext, event_id uuid, person_id uuid, status text, pass_size integer, entered integer, exited integer, inside integer, may_enter integer) |
| `exam.is_eligible(p_course_registration uuid)` | boolean |
| `exam.registration_has_clash(p_course_registration uuid, p_exam_session uuid)` | boolean |
| `exam.registration_matches_schedule(p_exam_registration uuid, p_exam_schedule uuid)` | boolean |
| `exam.request_internal_mark_revision(p_component_mark uuid, p_revised numeric, p_reason text, p_employee uuid, p_account uuid)` | uuid |
| `exam.schedule_has_clash(p_schedule uuid, p_exam_session uuid, p_course_offering uuid, p_date date, p_start time without time zone, p_end time without time zone)` | boolean |
| `facility.allocation_headcount(p_allocation uuid, p_extra_request uuid)` | integer |
| `facility.asset_usable(p_asset uuid, p_what text)` | void |
| `facility.blocked(p_during tsrange, p_setup smallint, p_teardown smallint)` | tsrange |
| `facility.cancel_booking_group(p_group uuid, p_account uuid, p_reason text)` | integer |
| `facility.custodian_of(p_room uuid, p_date date)` | uuid |
| `facility.day_span(p_date date)` | tsrange |
| `facility.free_rooms(p_during tsrange, p_headcount integer, p_features text[], p_building uuid, p_room_type text)` | TABLE(room_id uuid, room_code citext, building_id uuid, room_type text, capacity smallint) |
| `facility.hold_source_table(h facility.room_hold)` | text |
| `facility.is_restricted(p_person uuid, p_kind text, p_at timestamp with time zone)` | boolean |
| `facility.linked_rooms(p_room uuid)` | SETOF uuid |
| `facility.materialise_timetable(p_term uuid)` | TABLE(created integer, existing integer, skipped integer, conflicts integer) |
| `facility.night_span(p_nights daterange)` | tsrange |
| `facility.occurrence_dates(p_from date, p_to date, p_recurrence text, p_every integer, p_weekdays integer[])` | SETOF date |
| `facility.outranks(p_type smallint, p_other smallint, p_room_type smallint, p_unit uuid, p_date date)` | boolean |
| `facility.policy_for(p_unit uuid, p_date date)` | facility.booking_policy |
| `facility.purpose_hold_type(p_purpose smallint)` | smallint |
| `facility.raise_work_order(p_account uuid, p_room uuid, p_asset uuid, p_category text, p_priority text, p_description text)` | uuid |
| `facility.reinstate_hold(p_hold uuid)` | void |
| `facility.release_no_shows()` | integer |
| `facility.request_booking(p_account uuid, p_purpose text, p_title text, p_rooms uuid[], p_dates date[], p_start time without time zone, p_end time without time zone, p_headcount integer, p_on_behalf_unit uuid, p_features text[], p_skip_conflicts boolean, p_note text, p_event uuid, p_rescheduled_from uuid)` | uuid |
| `facility.request_event(p_account uuid, p_title text, p_kind text, p_unit uuid, p_during tsrange, p_attendance integer, p_note text)` | uuid |
| `facility.request_guest_stay(p_account uuid, p_room uuid, p_guest uuid, p_category text, p_host_unit uuid, p_nights daterange, p_purpose text, p_headcount integer, p_host_employee uuid)` | uuid |
| `facility.request_trip(p_account uuid, p_unit uuid, p_purpose text, p_during tsrange, p_origin text, p_destination text, p_headcount integer, p_contact_phone text, p_note text, p_event uuid, p_origin_lat numeric, p_origin_lon numeric, p_destination_lat numeric, p_destination_lon numeric)` | uuid |
| `facility.room_is_free(p_room uuid, p_during tsrange, p_setup smallint, p_teardown smallint)` | boolean |
| `facility.room_parts(p_room uuid)` | SETOF uuid |
| `facility.room_reserved_for(p_room uuid, p_date date, p_person uuid, p_unit uuid, p_account uuid, OUT is_reserved boolean, OUT is_allowed boolean)` | record |
| `facility.rooms_under(p_floor uuid, p_building uuid)` | SETOF uuid |
| `facility.run_trip_escalations()` | TABLE(auto_approved integer, alerts integer) |
| `facility.span(p_date date, p_start time without time zone, p_end time without time zone)` | tsrange |
| `facility.transport_policy_for(p_unit uuid, p_date date)` | facility.transport_policy |
| `facility.vehicle_available(p_vehicle uuid, p_during tsrange, OUT ok boolean, OUT why text)` | record |
| `facility.work_order_is_closed(p_wo uuid)` | boolean |
| `iam.resolve_login(p_identifier text)` | uuid |
| `org.ancestors(p_unit uuid)` | TABLE(org_unit_id uuid, depth integer) |
| `org.descendants(p_unit uuid)` | TABLE(org_unit_id uuid, depth integer) |
| `org.nearest_of_type(p_unit uuid, p_type_code text)` | uuid |
| `tms.account_of_employee(p_employee uuid)` | uuid |
| `tms.available_actions(p_account uuid, p_ticket uuid)` | TABLE(event_code text, label text) |
| `tms.business_deadline(p_start timestamp with time zone, p_minutes integer)` | timestamp with time zone |
| `tms.business_minutes_between(p_from timestamp with time zone, p_to timestamp with time zone)` | integer |
| `tms.can_act(p_account uuid, p_ticket uuid)` | boolean |
| `tms.can_download(p_account uuid, p_file uuid)` | boolean |
| `tms.can_login(p_account uuid)` | boolean |
| `tms.can_report_compliance(p_account uuid, p_ticket uuid)` | boolean |
| `tms.can_view(p_account uuid, p_ticket uuid)` | boolean |
| `tms.category_ancestors(p_category uuid)` | TABLE(category_id uuid, depth integer) |
| `tms.category_subtree(p_category uuid)` | TABLE(category_id uuid, depth integer) |
| `tms.config()` | tms.helpdesk_setting |
| `tms.day_hours(p_date date)` | TABLE(opens time without time zone, closes time without time zone, reason text) |
| `tms.days_after(p_start timestamp with time zone, p_days integer, p_office boolean)` | timestamp with time zone |
| `tms.deadline_after(p_start timestamp with time zone, p_minutes integer, p_office boolean)` | timestamp with time zone |
| `tms.domain_is_open(p_domain smallint)` | boolean |
| `tms.eligible_assignees(p_leaf uuid, p_requester_account uuid)` | TABLE(employee_id uuid, level_id smallint, level_category_id uuid) |
| `tms.forum_seat(p_forum smallint, p_unit uuid)` | TABLE(academic_body_id uuid, employee_id uuid) |
| `tms.helpdesk_calendar(p_from date, p_to date)` | TABLE(on_date date, is_working boolean, opens time without time zone, closes time without time zone, reason text) |
| `tms.is_business_day(p_date date)` | boolean |
| `tms.is_business_moment(p_at timestamp with time zone)` | boolean |
| `tms.is_forum_member(p_account uuid, p_ticket uuid)` | boolean |
| `tms.is_respondent(p_ticket uuid, p_person uuid)` | boolean |
| `tms.is_workable(p_employee uuid)` | boolean |
| `tms.kb_articles_for(p_leaf uuid)` | SETOF tms.kb_article |
| `tms.level_candidate(p_ticket uuid, p_level smallint, p_leaf uuid)` | TABLE(employee_id uuid, category_id uuid) |
| `tms.level_holder(p_ticket uuid, p_level smallint, p_leaf uuid)` | TABLE(employee_id uuid, category_id uuid) |
| `tms.level_sla_minutes(p_priority smallint, p_level smallint, p_category uuid)` | integer |
| `tms.manual_level(p_route smallint, p_leaf uuid, p_unit uuid, p_employee uuid)` | TABLE(level_id smallint, category_id uuid) |
| `tms.minutes_left(p_from timestamp with time zone, p_to timestamp with time zone, p_office boolean)` | integer |
| `tms.next_escalation(p_ticket uuid)` | TABLE(employee_id uuid, level_id smallint, level_category_id uuid) |
| `tms.notice_accounts(p_code text, p_ticket uuid, p_event bigint)` | SETOF uuid |
| `tms.person_of_account(p_account uuid)` | uuid |
| `tms.person_of_employee(p_employee uuid)` | uuid |
| `tms.requester_shown_to(p_account uuid, p_ticket uuid)` | boolean |
| `tms.round_robin(p_leaf uuid, p_ticket uuid)` | uuid |
| `tms.run_scheduler(p_now timestamp with time zone, p_force boolean)` | TABLE(auto_referred integer, escalated integer, exhausted integer, overdue_notices integer, reminders integer, expired integer, auto_closed integer, holds_released integer, compliance_reminders integer, forum_action_alerts integer) |
| `tms.sla_office(p_priority smallint, p_category uuid)` | boolean |
| `tms.walk_route(p_ticket uuid, p_route smallint, p_leaf uuid, p_after_seq smallint, p_skip_employee uuid)` | TABLE(employee_id uuid, level_id smallint, level_category_id uuid) |
| `wf.act(p_instance uuid, p_action text, p_account uuid, p_note text, p_file uuid, p_target_account uuid, p_return_to_seq integer)` | bigint |
| `wf.can_act(p_account uuid, p_instance uuid)` | boolean |
| `wf.can_view(p_account uuid, p_instance uuid)` | boolean |
| `wf.document_of(p_instance uuid, OUT link_table text, OUT document_id uuid)` | record |
| `wf.is_eligible(p_account uuid, p_instance uuid, p_seq smallint)` | boolean |
| `wf.manager_account(p_person uuid, p_line_type smallint, p_level integer)` | uuid |
| `wf.notify_step(p_instance uuid, p_seq smallint, p_kind text)` | void |
| `wf.overridable_for(p_account uuid)` | TABLE(instance_id uuid, document_type text, current_step text, override_step text, submitted_at timestamp with time zone, owner_org_unit_id uuid, amount numeric, current_due_at timestamp with time zone, is_overdue boolean) |
| `wf.override_refusal(p_instance uuid, p_seq smallint)` | text |
| `wf.override_step(p_account uuid, p_instance uuid)` | smallint |
| `wf.pending_for(p_account uuid)` | TABLE(instance_id uuid, document_type text, current_step text, submitted_at timestamp with time zone, owner_org_unit_id uuid, amount numeric, current_due_at timestamp with time zone, is_overdue boolean) |
| `wf.run_timeouts()` | TABLE(reminded integer, escalated integer, auto_approved integer, auto_rejected integer) |
| `wf.step_anchor(p_instance uuid, p_seq smallint)` | uuid |
| `wf.submit(p_document_type text, p_owner_unit uuid, p_account uuid, p_note text, p_amount numeric, p_flags text[], p_subject_person uuid, p_assignees uuid[], p_revises uuid)` | uuid |
