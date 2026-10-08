#!/usr/bin/env python3
"""
build_dfd.py — source of truth for the data-flow diagrams in docs/dfd/.

    python docs/dfd/build_dfd.py            # writes dfd-*.mmd, checks coverage,
                                            # refreshes the store index in docs/data-flow.md
    bash docs/dfd/render.sh                 # renders every .mmd to .png and .svg

Notation (Gane–Sarson style, drawn with Mermaid):
    rectangle        external entity  (left = source, right = sink; an entity
                                       that gives and receives appears twice)
    rounded box      process          (numbered; 1.1 is a part of process 1)
    cylinder         data store       (a group of tables of ONE schema)
    dashed box       a process drawn on another diagram
    arrow            data flow; a double-headed arrow = the process reads and writes

Layout rule: every diagram is three columns — sources, processes, stores/sinks.
A read (store -> process) is emitted as `process <--> store` with the arrowhead
at the store end hidden, so the store still sits in the right-hand column.

Every table of the 14 non-lookup schemas belongs to exactly one store below;
check_coverage() compares the registry with the CREATE TABLE statements in
sql/*.sql and fails on a missing, unknown or duplicated table, and on a store
that no Level-2 diagram shows.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DOC = REPO / "docs" / "data-flow.md"

INIT = ('%%{init: {"theme":"base","themeVariables":{"edgeLabelBackground":"#ffffff",'
        '"lineColor":"#52525b","fontSize":"14px"},'
        '"flowchart":{"wrappingWidth":560,"nodeSpacing":26,"rankSpacing":90}}}%%')

CLASSES = """
  classDef ext   fill:#f4f4f5,stroke:#3f3f46,stroke-width:1.5px,color:#18181b
  classDef proc  fill:#e0ecff,stroke:#1d4ed8,stroke-width:1.5px,color:#0b1b4a
  classDef store fill:#fff6d6,stroke:#a16207,stroke-width:1.5px,color:#3b2a00
  classDef agg   fill:#fffdf3,stroke:#a16207,stroke-width:1.5px,stroke-dasharray:6 3,color:#3b2a00
  classDef sys   fill:#1d4ed8,stroke:#0b1b4a,stroke-width:2px,color:#ffffff
  classDef off   fill:#ffffff,stroke:#1d4ed8,stroke-width:1.5px,stroke-dasharray:5 4,color:#0b1b4a
"""

# ----------------------------------------------------------------------------
# Data stores. Table-level stores: id -> (schema, [tables]).
# ----------------------------------------------------------------------------
STORES: dict[str, tuple[str, list[str]]] = {
    # org (11)
    "D2.1": ("org", ["org_unit", "org_unit_type_rule", "org_unit_contact", "org_unit_location"]),
    "D2.2": ("org", ["campus", "building", "floor", "room", "room_facility"]),
    "D2.3": ("org", ["position_type", "position_type_unit_type", "appointment"]),
    # people (9)
    "D3.1": ("people", ["person", "person_relationship"]),
    "D3.2": ("people", ["designation", "employee", "employee_assignment", "employee_reporting_line"]),
    "D3.3": ("people", ["student", "student_mentor"]),
    "D3.4": ("people", ["file_object"]),
    # pii (7)
    "D4.1": ("pii", ["person_profile"]),
    "D4.2": ("pii", ["person_email", "person_phone"]),
    "D4.3": ("pii", ["address", "person_address"]),
    "D4.4": ("pii", ["person_identity_document", "person_photo"]),
    # iam (13)
    "D5.1": ("iam", ["user_account"]),
    "D5.2": ("iam", ["password_history", "password_reset_token"]),
    "D5.3": ("iam", ["mfa_factor", "mfa_totp", "mfa_webauthn", "mfa_otp_channel", "mfa_recovery_code"]),
    "D5.4": ("iam", ["otp_challenge"]),
    "D5.5": ("iam", ["user_device", "user_session"]),
    "D5.6": ("iam", ["account_lockout"]),
    "D5.7": ("iam", ["auth_event"]),
    # authz (13)
    "D6.1": ("authz", ["app_module", "resource", "action", "permission"]),
    "D6.2": ("authz", ["role", "role_permission", "role_inheritance", "role_conflict"]),
    "D6.3": ("authz", ["account_role", "account_permission"]),
    "D6.4": ("authz", ["designation_role", "position_role", "principal_kind_role"]),
    # wf (7)
    "D7.1": ("wf", ["approval_document_type", "approval_chain", "approval_chain_stage", "approval_chain_stage_check"]),
    "D7.2": ("wf", ["approval_instance", "approval_instance_flag", "approval_step", "approval_step_assignee", "approval_step_check"]),
    "D7.3": ("wf", ["approval_action"]),
    "D7.4": ("wf", ["approval_comment", "approval_consultation"]),
    "D7.5": ("wf", ["approval_delegation"]),
    "D7.6": ("wf", ["approval_notice"]),
    # privacy (17)
    "D8.1": ("privacy", ["processing_purpose", "purpose_data_category", "data_element"]),
    "D8.2": ("privacy", ["privacy_notice", "notice_purpose"]),
    "D8.3": ("privacy", ["consent", "verifiable_parental_consent", "nominee"]),
    "D8.4": ("privacy", ["data_principal_request", "dpr_request_event"]),
    "D8.5": ("privacy", ["erasure_log"]),
    "D8.6": ("privacy", ["data_processor", "processor_purpose"]),
    "D8.7": ("privacy", ["breach_incident", "breach_affected_person", "breach_notification"]),
    "D8.8": ("privacy", ["pii_access_log"]),
    # audit (2)
    "D9.1": ("audit", ["audit_event", "audit_change"]),
    # academic — structure & curriculum (50)
    "D10.1": ("academic", ["program", "specialization", "program_coordinator", "program_outcome"]),
    "D10.2": ("academic", ["program_approval", "program_accreditation"]),
    "D10.3": ("academic", ["academic_year", "academic_term", "calendar_event"]),
    "D10.4": ("academic", ["batch", "batch_document", "batch_specialization", "batch_curriculum"]),
    "D10.5": ("academic", ["course", "course_component_hours", "course_prerequisite", "course_continuation",
                           "course_regulator_code", "course_room_requirement"]),
    "D10.6": ("academic", ["course_syllabus", "syllabus_unit", "course_outcome", "co_po_mapping"]),
    "D10.7": ("academic", ["grade_scale", "grade_band", "division_band", "relative_grade_cutoff"]),
    "D10.8": ("academic", ["evaluation_scheme", "evaluation_component", "evaluation_component_group",
                           "evaluation_part_rule", "evaluation_component_outcome", "attainment_policy"]),
    "D10.9": ("academic", ["curriculum", "curriculum_course", "elective_basket", "elective_basket_course",
                           "curriculum_pathway", "result_group"]),
    "D10.10": ("academic", ["award_rule", "award_rule_course", "promotion_rule", "attempt_allowance",
                            "credit_load_rule"]),
    "D10.11": ("academic", ["academic_body", "academic_body_member", "body_meeting", "body_meeting_attendee",
                            "body_resolution"]),
    "D10.12": ("academic", ["curriculum_approval"]),
    # academic — enrolment & lifecycle (18)
    "D11.1": ("academic", ["student_enrollment", "student_specialization", "student_pathway"]),
    "D11.2": ("academic", ["term_registration"]),
    "D11.3": ("academic", ["study_break", "disciplinary_case"]),
    "D11.4": ("academic", ["program_transfer", "enrollment_reentry"]),
    "D11.5": ("academic", ["course_equivalence", "external_provider", "external_course", "external_course_mapping"]),
    "D11.6": ("academic", ["credit_transfer"]),
    "D11.7": ("academic", ["track", "track_course", "student_track"]),
    "D11.8": ("academic", ["student_award"]),
    "D11.9": ("academic", ["credit_overload_approval"]),
    # academic — delivery (29)
    "D12.1": ("academic", ["course_offering", "offering_seat_quota"]),
    "D12.2": ("academic", ["section", "section_student", "section_representative"]),
    "D12.3": ("academic", ["elective_preference"]),
    "D12.4": ("academic", ["course_registration"]),
    "D12.5": ("academic", ["class_group", "class_group_member"]),
    "D12.6": ("academic", ["teaching_assignment", "faculty_course_preference"]),
    "D12.7": ("academic", ["time_slot", "faculty_unavailability", "workload_norm"]),
    "D12.8": ("academic", ["timetable_entry"]),
    "D12.9": ("academic", ["lesson_plan_item", "class_session", "class_session_topic"]),
    "D12.10": ("academic", ["attendance", "attendance_leave"]),
    "D12.11": ("academic", ["feedback_questionnaire", "feedback_question", "feedback_cycle",
                            "feedback_submission", "feedback_response"]),
    "D12.12": ("academic", ["mentoring_meeting"]),
    "D12.13": ("academic", ["supervised_work", "supervised_work_guide", "internship"]),
    # exam (32)
    "D13.1": ("exam", ["exam_session"]),
    "D13.2": ("exam", ["eligibility_hold", "attendance_condonation"]),
    "D13.3": ("exam", ["exam_registration"]),
    "D13.4": ("exam", ["paper_setter_assignment", "question_bank_item", "question_paper", "question_paper_item"]),
    "D13.5": ("exam", ["exam_schedule", "exam_room", "seat_allocation", "invigilation_duty", "examiner_panel"]),
    "D13.6": ("exam", ["exam_attendance", "ufm_case"]),
    "D13.7": ("exam", ["answer_script", "evaluator_assignment", "script_mark"]),
    "D13.8": ("exam", ["component_mark", "question_mark", "internal_mark_revision"]),
    "D13.9": ("exam", ["grace_policy", "grace_award", "result_moderation"]),
    "D13.10": ("exam", ["result_publication", "course_result"]),
    "D13.11": ("exam", ["revaluation_request"]),
    "D13.12": ("exam", ["marksheet", "certificate"]),
    "D13.13": ("exam", ["convocation", "prize", "prize_award"]),
    # research (8)
    "D14.1": ("research", ["supervision_norm", "supervisor_allocation"]),
    "D14.2": ("research", ["advisory_committee", "advisory_committee_member", "progress_review"]),
    "D14.3": ("research", ["thesis"]),
    "D14.4": ("research", ["thesis_examiner"]),
    "D14.5": ("research", ["viva"]),
    # facility (41)
    "D15.1": ("facility", ["room_composition", "custody", "space_allocation", "room_reservation_rule"]),
    "D15.2": ("facility", ["hold_priority_rule", "room_service_window", "blackout"]),
    "D15.3": ("facility", ["room_hold"]),
    "D15.4": ("facility", ["booking_policy", "booking_restriction"]),
    "D15.5": ("facility", ["event_request", "booking_group", "booking_request", "booking_requirement", "booking_occurrence"]),
    "D15.6": ("facility", ["vendor", "asset", "service_contract", "booking_asset", "asset_loan", "asset_hold"]),
    "D15.7": ("facility", ["maintenance_schedule", "work_order", "work_order_event"]),
    "D15.8": ("facility", ["guest_stay", "guest_tariff"]),
    "D15.9": ("facility", ["parking_permit"]),
    "D15.10": ("facility", ["vehicle", "vehicle_document", "vehicle_service_window", "driver", "driver_unavailability", "transport_policy"]),
    "D15.11": ("facility", ["trip_request", "trip_allocation", "trip_allocation_request", "trip", "trip_rating", "trip_alert"]),
    "D15.12": ("facility", ["key_item", "key_issue"]),
    # tms (12)
    "D16.1": ("tms", ["helpdesk_setting", "helpdesk_weekday", "helpdesk_day_override", "helpdesk_closure_type", "helpdesk_declaration", "helpdesk_file_type", "helpdesk_channel", "ticket_notice_rule"]),
    "D16.2": ("tms", ["ticket_category", "ticket_category_owner", "ticket_category_handler"]),
    "D16.3": ("tms", ["ticket_route", "ticket_route_level", "redressal_forum"]),
    "D16.4": ("tms", ["ticket", "ticket_number_counter", "ticket_academic_context", "ticket_respondent"]),
    "D16.5": ("tms", ["ticket_event", "ticket_event_file"]),
    "D16.6": ("tms", ["ticket_notification", "notice_opt_out"]),
    "D16.7": ("tms", ["kb_article", "kb_feedback"]),
    # events (74)
    "D17.1": ("events", ["club", "club_officer", "club_member", "club_application", "club_suspension", "club_calendar_item", "primary_club"]),
    "D17.2": ("events", ["club_proposal", "club_proposal_officer", "club_proposal_member", "club_proposal_attachment"]),
    "D17.3": ("events", ["event_proposal", "proposal_audience", "proposal_sdg", "proposal_partner", "proposal_speaker", "proposal_coordinator",
                         "proposal_budget_item", "proposal_funding", "proposal_prize", "proposal_attachment", "proposal_visibility_role",
                         "proposal_visibility_scope"]),
    "D17.4": ("events", ["event_sponsor", "event_sponsorship", "sponsorship_receipt", "sponsorship_item"]),
    "D17.5": ("events", ["event", "event_round", "event_faq", "event_link", "event_custom_field", "custom_field_option", "event_volunteer",
                         "post_event_report", "volunteer_application", "event_change_request"]),
    "D17.6": ("events", ["event_registration", "field_response", "extra_pass"]),
    "D17.7": ("events", ["event_team", "event_team_member", "team_invitation", "team_join_request"]),
    "D17.8": ("events", ["entry_scan", "round_attendance"]),
    "D17.9": ("events", ["event_prize_award", "event_certificate_template", "event_certificate"]),
    "D17.10": ("events", ["event_feedback_token", "event_feedback"]),
    "D17.11": ("events", ["event_type_points", "club_point_award", "club_tier", "event_setting"]),
    "D17.12": ("events", ["club_change_request", "club_change_officer", "club_change_member"]),
    "D17.13": ("events", ["event_coupon", "coupon_redemption", "event_payment", "event_expense", "event_settlement"]),
    "D17.14": ("events", ["event_mail", "event_mail_recipient", "event_mail_credit_grant"]),
    "D17.15": ("events", ["event_stall_fee", "stall_application", "stall_application_setup", "stall_application_document", "event_stall",
                          "event_stall_product", "stall_feedback", "stall_feedback_point"]),
}

# Schema-level stores (Level 1, and "somebody else's data" on a Level-2 diagram).
AGG: dict[str, tuple[str, str]] = {
    "D1": ("ref", "183 lookup tables · codes & rule flags · read by every process"),
    "D2": ("org", "units · buildings · floors · rooms · positions · appointments"),
    "D3": ("people", "person · employee · student · assignment · relationship · file"),
    "D4": ("pii", "profile · email · phone · address · ID document · photo"),
    "D5": ("iam", "account · MFA · session · lockout · auth_event"),
    "D6": ("authz", "permission · role · grants · derivation rules"),
    "D7": ("wf", "chains & levels · rounds · steps & assignees · actions · delegations · notices"),
    "D8": ("privacy", "purpose · notice · consent · requests · erasure · breach"),
    "D9": ("audit", "audit_event · audit_change"),
    "D10": ("academic — structure", "programme · calendar · batch · course · syllabus · scheme · curriculum"),
    "D11": ("academic — lifecycle", "enrollment · term registration · break · transfer · credits · award"),
    "D12": ("academic — delivery", "offering · section · registration · timetable · session · attendance"),
    "D13": ("exam", "registration · papers · marks · results · certificates"),
    "D14": ("research", "supervision · committee · thesis · examiners · viva"),
    "D15": ("facility", "occupancy ledger · bookings · assets · maintenance · guest house · fleet · keys"),
    "D16": ("tms", "category tree · handlers · owners · routes · redressal forums · tickets · respondents · timeline · notices · knowledge base"),
    "D17": ("events", "clubs · proposals · events · registrations · teams · gate log · payments · mail · stalls · certificates · points"),
    # not a database table: the Django backend's per-account cache (docs/design.md §5.5)
    "C1": ("Redis cache", "effective permission set per account · outside the database"),
}


def wrap(text: str, width: int = 27) -> str:
    """Break a ' · ' / space separated label into <br/> lines of about `width` characters."""
    out = []
    for part in text.split("<br/>"):
        line = ""
        for word in part.split(" "):
            if line and len(line) + 1 + len(word) > width:
                out.append(line)
                line = word
            else:
                line = f"{line} {word}".strip()
        out.append(line)
    # a line never starts with the separator dot
    fixed = []
    for ln in out:
        if ln.startswith("· "):
            ln = ln[2:]
        if ln.endswith(" ·"):
            ln = ln[:-2]
        fixed.append(ln)
    return "<br/>".join(x for x in fixed if x)


def nid(key: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "_", key)


class Diagram:
    def __init__(self, name, title, level, src=None, proc=None, stores=None, snk=None,
                 off_l=None, off_r=None, flows=None, system=None):
        self.name, self.title, self.level = name, title, level
        self.src, self.proc, self.snk = src or {}, proc or {}, snk or {}
        self.stores = stores or []
        self.off_l, self.off_r = off_l or {}, off_r or {}
        for k in [k for k in self.snk if re.fullmatch(r"P\d+", k)]:   # a sink that is another process
            self.off_r[k] = self.snk.pop(k)
        self.flows, self.system = flows or [], system

    # -- node kinds -----------------------------------------------------------
    def kind(self, key: str) -> str:
        if key in self.src: return "src"
        if key in self.snk: return "snk"
        if key in self.proc or (self.system and key == "0"): return "proc"
        if key in self.off_l: return "off_l"
        if key in self.off_r: return "off_r"
        if key in self.stores: return "store"
        raise KeyError(f"{self.name}: unknown node {key!r}")

    def emit(self) -> str:
        L = [INIT, f"%% {self.title}", "%% GENERATED by docs/dfd/build_dfd.py — edit the spec there, not this file.",
             "flowchart LR"]
        for k, v in self.src.items():
            L.append(f'  {nid(k)}["{wrap(v, 30)}"]:::ext')
        for k, v in self.off_l.items():
            L.append(f'  {nid(k)}("{wrap(v, 26)}"):::off')
        if self.system:
            L.append(f'  {nid("0")}(("{self.system}")):::sys')
        for k, v in self.proc.items():
            L.append(f'  {nid(k)}("<b>{k}</b><br/>{wrap(v, 26)}"):::proc')
        for k in self.stores:
            if k in STORES:
                schema, tables = STORES[k]
                L.append(f'  {nid(k)}[("<b>{k}</b> {schema}<br/>{wrap(" · ".join(tables), 34)}")]:::store')
            else:
                schema, text = AGG[k]
                cls = "store" if self.level == 1 else "agg"
                L.append(f'  {nid(k)}[("<b>{k}</b> {schema}<br/>{wrap(text, 34)}")]:::{cls}')
        for k, v in self.snk.items():
            L.append(f'  {nid(k)}["{wrap(v, 30)}"]:::ext')
        for k, v in self.off_r.items():
            L.append(f'  {nid(k)}("{wrap(v, 26)}"):::off')
        L.append("")
        hidden = []
        for i, f in enumerate(self.flows):
            a, b, label = f[0], f[1], f[2]
            rw = len(f) > 3 and f[3] == "rw"
            ka, kb = self.kind(a), self.kind(b)
            lab = wrap(label, 24)
            if ka in ("store", "off_r") and kb == "proc":          # read: keep the store on the right
                if rw:
                    raise ValueError(f"{self.name}: write {b}->{a} as (process, store, label, 'rw')")
                L.append(f'  {nid(b)} <-->|"{lab}"| {nid(a)}')
                hidden.append(i)
            elif rw:
                L.append(f'  {nid(a)} <-->|"{lab}"| {nid(b)}')
            else:
                if ka == "proc" and kb in ("src", "off_l"):
                    raise ValueError(f"{self.name}: flow {a}->{b} points back at a source; use a sink")
                L.append(f'  {nid(a)} -->|"{lab}"| {nid(b)}')
        if hidden:
            L.append("  linkStyle " + ",".join(map(str, hidden)) + " marker-end:none")
        L.append(CLASSES)
        return "\n".join(L)


# ----------------------------------------------------------------------------
# Diagrams
# ----------------------------------------------------------------------------
DIAGRAMS: list[Diagram] = []
add = DIAGRAMS.append

# ------------------------------------------------------------------ Level 0 --
add(Diagram(
    "dfd-0-context", "Level 0 — context diagram", 0,
    system="<b>0</b><br/>SGT Intranet<br/>Foundation<br/><br/>Django + PostgreSQL<br/>546 tables · 15 schemas",
    src={
        "STU": "Student",
        "GUA": "Guardian / nominee",
        "FAC": "Faculty",
        "ACA": "Academic administration<br/>HOD · Dean · coordinator<br/>Registrar · academic office",
        "EXC": "Examination cell<br/>Controller of Examinations",
        "ADM": "HR · core · access administrators",
        "DPO": "DPO / Grievance officer",
        "XAC": "External academics<br/>examiners · paper setters<br/>co-supervisors · industry mentors",
        "REG": "Regulators & accreditors<br/>UGC · AICTE · NMC … NAAC · NBA",
        "ABC": "Academic Bank of Credits<br/>MOOC platforms · universities",
        "FCM": "Facility · transport · guest-house staff<br/>custodians · maintenance · drivers",
        "MOD": "Other modules<br/>Finance · IPR · Events",
    },
    snk={
        "STU2": "Student",
        "GUA2": "Guardian / nominee",
        "FAC2": "Faculty",
        "ACA2": "Academic administration",
        "EXC2": "Examination cell",
        "ADM2": "HR · core · access administrators",
        "DPO2": "DPO · Auditor",
        "REG2": "Regulators & accreditors",
        "NAD": "NAD / DigiLocker",
        "DPB": "Data Protection Board",
        "MSG": "Email / SMS gateway<br/>(data processor)",
        "OBJ": "Object storage + KMS<br/>(data processor)",
        "FCM2": "Facility · transport · guest-house staff",
        "MOD2": "Other modules",
        "BI": "BI / analytics tools",
    },
    flows=[
        ("STU", "0", "credentials · term & exam registration · elective preferences · anonymous feedback · leave, revaluation & credit-transfer requests · consent · rights requests · room, vehicle & guest-room requests · helpdesk tickets · club applications · event proposals & registrations"),
        ("GUA", "0", "verified consent for a minor · rights requests"),
        ("FAC", "0", "lesson plan · attendance · topics covered · internal & script marks · question bank · course preferences · mentoring notes · helpdesk tickets raised and handled"),
        ("ACA", "0", "org units · programmes · calendar · curriculum (SOE) · batches · sections · approvals · standing & award decisions"),
        ("EXC", "0", "exam sessions · date sheet · seating · paper approval · moderation & grace · result publication · certificate issue"),
        ("ADM", "0", "persons · employees · postings · appointments · role grants"),
        ("DPO", "0", "purposes · notices · request handling · erasure · breach register"),
        ("XAC", "0", "question papers · examiner reports · practical & viva marks"),
        ("REG", "0", "approval letters · sanctioned seats · accreditation grades"),
        ("ABC", "0", "credit transactions · course certificates"),
        ("FCM", "0", "custody · reservation & priority rules · booking, event, stay & trip decisions · vehicle allocation · work orders · keys"),
        ("MOD", "0", "fee-due holds · module permissions · rows referencing org, people & accounts"),
        ("0", "STU2", "timetable · attendance % · hall ticket · results · standing · marksheets & certificates · ticket status · events open to me · event certificates"),
        ("0", "GUA2", "privacy notices · request status"),
        ("0", "FAC2", "rosters · timetable · workload · feedback summary · approvals pending · assigned tickets"),
        ("0", "ACA2", "SOE sheet · teaching gaps · promotion & award eligibility · CO / PO attainment"),
        ("0", "EXC2", "eligibility lists · provisional results · rank list · paper blueprint"),
        ("0", "ADM2", "effective roles & permissions"),
        ("0", "DPO2", "overdue requests · consent gaps · PII access log · audit trail"),
        ("0", "REG2", "OBE, workload & feedback reports"),
        ("0", "NAD", "certificates pushed (NAD reference returned)"),
        ("0", "DPB", "breach intimation"),
        ("0", "MSG", "OTP & notification messages"),
        ("0", "OBJ", "files · envelope-encrypted secrets"),
        ("0", "FCM2", "room timeline · free rooms · displaced classes · utilisation · trip status · overdue jobs · key custody"),
        ("0", "MOD2", "org tree · identities · permission checks"),
        ("0", "BI", "de-identified read-only data (no pii · iam · names)"),
    ]))

# ------------------------------------------------------------------ Level 1 --
add(Diagram(
    "dfd-1a-platform", "Level 1 (A) — platform, governance & helpdesk: processes 1–7 and 15", 1,
    src={
        "ACA": "Academic administration<br/>Registrar · HOD · Dean",
        "ADM": "Administrators<br/>HR · core · access",
        "USR": "Account holder<br/>student · employee · guardian",
        "DPO": "DPO / Grievance officer",
        "APP": "Any module request<br/>(Django middleware)",
    },
    off_l={"ACD": "<b>8–14, 16</b><br/>Academic, exam, research, facility & event processes<br/>(Level 1 B)"},
    proc={
        "1": "Maintain organisation structure & positions",
        "2": "Onboard & maintain people",
        "3": "Authenticate<br/>login · MFA · sessions",
        "4": "Authorise<br/>roles → permissions",
        "5": "Run approval workflow",
        "6": "Manage privacy & data-principal rights",
        "7": "Capture audit trail",
        "15": "Handle helpdesk tickets & grievances<br/>route · escalate · SLA · redressal forums",
    },
    stores=["D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D16"],
    snk={
        "USR2": "Account holder",
        "APP2": "Any module request",
        "MSG": "Email / SMS gateway",
        "DPB": "Data Protection Board",
        "DPO2": "DPO · Auditor",
    },
    flows=[
        ("ACA", "1", "units · rooms · appointments"),
        ("D1", "1", "unit types · nesting flags"),
        ("1", "D2", "org tree · rooms · holders", "rw"),

        ("ADM", "2", "person · employee · student · guardian link"),
        ("D2", "2", "posting unit"),
        ("2", "D3", "identity & roles played", "rw"),
        ("2", "D4", "contacts · DOB · documents", "rw"),
        ("2", "D5", "new account (pending activation)"),

        ("USR", "3", "identifier · password · MFA code · refresh token"),
        ("D4", "3", "login e-mail · OTP contact"),
        ("D6", "3", "role requires MFA?"),
        ("3", "D5", "credentials · sessions · auth events", "rw"),
        ("3", "MSG", "OTP message"),
        ("3", "USR2", "session tokens or generic error"),

        ("ADM", "4", "roles · explicit grants · derivation rules"),
        ("APP", "4", "account · permission code · target unit"),
        ("D2", "4", "appointments · unit ancestors"),
        ("D3", "4", "assignments · principal kind"),
        ("D5", "4", "account status · superuser"),
        ("4", "D6", "catalogue · grants", "rw"),
        ("4", "APP2", "allow / deny · accessible units"),

        ("ACA", "5", "submit · comment · approve · sign · return"),
        ("ACD", "5", "documents sent for approval"),
        ("D6", "5", "stage permission held at anchor unit?"),
        ("D2", "5", "department · school · university of the owner"),
        ("5", "D7", "rounds · steps · actions · comments", "rw"),

        ("USR", "6", "consent · withdrawal · rights request · nominee"),
        ("DPO", "6", "purposes · notices · decisions · breach entries"),
        ("6", "D8", "DPDP records", "rw"),
        ("6", "D4", "read age / minor · delete · anonymise", "rw"),
        ("6", "D3", "anonymise name"),
        ("6", "D5", "anonymise account"),
        ("6", "USR2", "notices · request status"),
        ("6", "DPB", "breach intimation"),
        ("6", "DPO2", "overdue requests · consent gaps"),

        ("APP", "7", "actor · request · session · client IP"),
        ("ACD", "7", "every row change"),
        ("D8", "7", "data_element: columns to redact"),
        ("7", "D9", "event + column changes (append-only)"),
        ("7", "DPO2", "who changed what, when"),

        ("USR", "15", "tickets · comments · clarification replies · ratings · reopen · referral · appeal · forum decisions"),
        ("ADM", "15", "helpdesk categories · handlers · owners · routes · forums · settings"),
        ("D2", "15", "responsible units · who holds each position"),
        ("D3", "15", "employees who handle tickets · students · mentors"),
        ("D4", "15", "the requester's own phone"),
        ("D6", "15", "create · assign · view · act permissions"),
        ("D10", "15", "holidays · batch · term · course · committees & resolutions"),
        ("15", "D16", "tickets · respondents · timeline · notices", "rw"),
        ("15", "USR2", "ticket status · assigned tickets"),
        ("15", "MSG", "ticket e-mails"),
    ]))

add(Diagram(
    "dfd-1b-academic", "Level 1 (B) — academic, examination, research, facilities & events: processes 8–14 and 16", 1,
    src={
        "REG": "Regulators & accreditors",
        "ACA": "Academic administration<br/>office · coordinator · HOD · Dean",
        "STU": "Student",
        "ABC": "ABC · MOOC platforms",
        "FAC": "Faculty",
        "EXC": "Examination cell",
        "XAC": "External academics",
        "RSD": "Research directorate",
        "FCM": "Facility · transport · guest-house staff",
    },
    proc={
        "8": "Define programmes, calendar & curriculum",
        "9": "Manage enrolment & student lifecycle",
        "10": "Deliver teaching<br/>timetable · attendance",
        "11": "Conduct examinations & publish results",
        "12": "Confer awards & issue certificates",
        "13": "Supervise research degrees",
        "14": "Manage facilities & transport<br/>rooms · bookings · assets · vehicles",
        "16": "Run clubs & events<br/>proposals · registrations · attendance",
    },
    stores=["D2", "D3", "D7", "D10", "D11", "D12", "D13", "D14", "D15", "D17"],
    snk={
        "ACA2": "Academic administration",
        "STU2": "Student",
        "FAC2": "Faculty",
        "EXC2": "Examination cell",
        "REG2": "Regulators & accreditors",
        "NAD": "NAD / DigiLocker",
        "FCM2": "Facility · transport · guest-house staff",
    },
    flows=[
        ("REG", "8", "approval letters · seats · accreditation grades"),
        ("ACA", "8", "programmes · calendar · courses · curriculum"),
        ("D2", "8", "academic units"),
        ("8", "D10", "regulations as data", "rw"),
        ("8", "D7", "SOE round ⇄ status (approved = frozen)", "rw"),
        ("8", "ACA2", "SOE sheet · CO–PO matrix"),

        ("ACA", "9", "enrolment · standing · breaks · transfers"),
        ("STU", "9", "term registration · credit-transfer claim · minor / honours choice"),
        ("ABC", "9", "credit transaction · certificate"),
        ("D3", "9", "student record"),
        ("D10", "9", "batch · curriculum & promotion rules"),
        ("D13", "9", "published results"),
        ("9", "D11", "enrolment history", "rw"),
        ("9", "STU2", "term no. · standing · backlog · credit ledger"),

        ("ACA", "10", "offerings · sections · faculty assignment"),
        ("STU", "10", "elective preferences · leave request · feedback"),
        ("FAC", "10", "attendance · lesson plan · topics · unavailability"),
        ("D2", "10", "rooms & facilities"),
        ("D10", "10", "curriculum items · L-T-P · holidays"),
        ("D11", "10", "enrollment · term no. · pathway · track"),
        ("10", "D12", "rosters · classes · attendance", "rw"),
        ("10", "D7", "leave round ⇄ decision", "rw"),
        ("10", "STU2", "timetable · attendance %"),
        ("10", "FAC2", "rosters · workload · feedback summary"),
        ("10", "ACA2", "teaching gaps · section-wise sheet"),

        ("EXC", "11", "sessions · date sheet · seating · publication"),
        ("STU", "11", "exam registration · revaluation request"),
        ("FAC", "11", "papers · marks · question bank"),
        ("XAC", "11", "papers · practical & viva marks"),
        ("D2", "11", "exam rooms"),
        ("D10", "11", "scheme · grade scale · attempt limits"),
        ("D12", "11", "registrations · attendance %"),
        ("11", "D13", "exam record", "rw"),
        ("11", "D7", "marks-revision round ⇄ decision", "rw"),
        ("11", "STU2", "hall ticket · results"),
        ("11", "EXC2", "provisional results · rank list"),
        ("11", "REG2", "CO / PO attainment"),

        ("EXC", "12", "award approval · certificate issue"),
        ("D14", "12", "accepted viva"),
        ("12", "D11", "award · closed enrollment", "rw"),
        ("12", "D13", "marksheet · certificate · convocation · prize", "rw"),
        ("12", "STU2", "marksheets · certificates"),
        ("12", "NAD", "certificate push"),

        ("RSD", "13", "supervisors · committee · reviews · viva"),
        ("XAC", "13", "examiner reports"),
        ("D3", "13", "designation (supervision norm)"),
        ("D11", "13", "doctoral enrollment"),
        ("13", "D14", "research record", "rw"),
        ("13", "ACA2", "scholar status"),

        ("FCM", "14", "custody · rules · policies · approvals · allocations · work orders · keys"),
        ("STU", "14", "room · vehicle · guest-room requests"),
        ("FAC", "14", "room · vehicle · guest-room requests"),
        ("D2", "14", "buildings · floors · rooms · custodian units"),
        ("D3", "14", "requester · driver · guest"),
        ("D12", "14", "timetable entries · class sessions"),
        ("D13", "14", "exam rooms · convocations"),
        ("D14", "14", "vivas"),
        ("14", "D15", "ledger · bookings · assets · trips · keys", "rw"),
        ("14", "D7", "booking / event / stay / trip round ⇄ decision", "rw"),
        ("14", "STU2", "booking & trip status"),
        ("14", "FAC2", "booking & trip status"),
        ("14", "ACA2", "displaced classes · space inventory"),
        ("14", "FCM2", "room timeline · utilisation · pending approvals · overdue jobs"),

        ("STU", "16", "club applications · event proposals · registrations · teams · feedback"),
        ("FAC", "16", "club proposals · endorsements · event management"),
        ("ACA", "16", "committee approvals · club oversight"),
        ("D2", "16", "club = org unit · advisor appointments"),
        ("D3", "16", "students · employees"),
        ("D15", "16", "venue & vehicle requests under the event package"),
        ("16", "D17", "clubs · proposals · events · registrations · gate log · certificates · points", "rw"),
        ("16", "D7", "club / event proposal round ⇄ decision", "rw"),
        ("16", "D12", "duty-leave requests"),
        ("16", "STU2", "events open to me · my registrations · certificates"),
        ("16", "FAC2", "proposals awaiting endorsement · event statistics"),
        ("16", "ACA2", "committee overview · club leaderboard"),
    ]))

# ------------------------------------------------------------------ Level 2 --
add(Diagram(
    "dfd-2-01-org-people", "Level 2 — processes 1 & 2: organisation and people", 2,
    src={
        "ACA": "Registrar / academic administration",
        "ADM": "HR administrator",
        "PER": "New employee · student · guardian",
    },
    proc={
        "1.1": "Maintain org-unit tree",
        "1.2": "Maintain campuses, buildings & rooms",
        "1.3": "Appoint position holders",
        "2.1": "Register person, contacts & documents",
        "2.2": "Record employment & posting",
        "2.3": "Set reporting & reviewing lines",
        "2.4": "Record student & mentor",
        "2.5": "Link guardian / family",
        "2.6": "Open user account",
        "2.7": "Derive current affiliation",
    },
    stores=["D1", "D2.1", "D2.2", "D2.3", "D3.1", "D3.2", "D3.3", "D3.4",
            "D4.1", "D4.2", "D4.3", "D4.4", "D5.1"],
    snk={"MOD": "Every module & report"},
    flows=[
        ("ACA", "1.1", "unit code · name · type · parent"),
        ("D1", "1.1", "org_unit_type · is_academic"),
        ("1.1", "D2.1", "unit · contacts · office location", "rw"),
        ("ACA", "1.2", "campus · building · room · capacity · facilities"),
        ("1.2", "D2.2", "locations", "rw"),
        ("ACA", "1.3", "position · employee · order ref · period"),
        ("D2.1", "1.3", "unit & its type"),
        ("1.3", "D2.3", "appointment (one holder at a time)", "rw"),

        ("PER", "2.1", "name · DOB · e-mail · phone · address · ID · photo"),
        ("2.1", "D3.1", "person"),
        ("2.1", "D4.1", "DOB · blood group · nationality"),
        ("2.1", "D4.2", "e-mail · phone"),
        ("2.1", "D4.3", "address"),
        ("2.1", "D4.4", "ID ciphertext + HMAC · photo"),
        ("2.1", "D3.4", "photo file metadata"),

        ("ADM", "2.2", "employee code · category · designation · unit · period"),
        ("D2.1", "2.2", "posting unit"),
        ("2.2", "D3.2", "employee · assignment (one primary)", "rw"),
        ("ADM", "2.3", "manager · line type · period"),
        ("2.3", "D3.2", "reporting line (no cycles)", "rw"),
        ("ADM", "2.4", "enrollment no. · status · mentor"),
        ("2.4", "D3.3", "student · mentor (one at a time)", "rw"),
        ("ADM", "2.5", "relationship · is guardian · emergency contact"),
        ("2.5", "D3.1", "person_relationship", "rw"),
        ("ADM", "2.6", "username = employee code / enrollment no."),
        ("2.6", "D5.1", "account · status PENDING_ACTIVATION"),

        ("D2.1", "2.7", "unit ancestors"),
        ("D3.2", "2.7", "primary assignment · managers"),
        ("D3.3", "2.7", "student · mentor"),
        ("D4.1", "2.7", "DOB"),
        ("2.7", "MOD", "v_org_unit_tree · v_employee_current · v_student_current · v_person_age"),
    ]))

add(Diagram(
    "dfd-2-03-authenticate", "Level 2 — process 3: authenticate", 2,
    src={
        "USR": "Account holder",
        "ADM": "Access administrator",
    },
    proc={
        "3.1": "Resolve identifier<br/>UID or verified e-mail",
        "3.2": "Check status & lockout",
        "3.3": "Verify password",
        "3.4": "Verify second factor",
        "3.5": "Open, rotate & revoke session",
        "3.6": "Reset / change password",
        "3.7": "Activate account & enrol MFA",
        "3.8": "Lock & release account",
    },
    stores=["D1", "D4.2", "D5.1", "D5.2", "D5.3", "D5.4", "D5.5", "D5.6", "D5.7", "D6"],
    snk={
        "USR2": "Account holder",
        "MSG": "Email / SMS gateway",
        "DJ": "Django auth backend",
    },
    flows=[
        ("USR", "3.1", "identifier typed"),
        ("D5.1", "3.1", "username"),
        ("D4.2", "3.1", "verified, login-enabled e-mail"),
        ("3.1", "D5.7", "unknown identifier (HMAC only)"),
        ("3.1", "DJ", "account id or none"),

        ("D1", "3.2", "account_status.can_login"),
        ("D5.1", "3.2", "account status"),
        ("D5.6", "3.2", "active lockout"),
        ("3.2", "USR2", "generic error"),

        ("USR", "3.3", "password"),
        ("D5.1", "3.3", "password hash"),
        ("3.3", "D5.7", "BAD_PASSWORD"),

        ("USR", "3.4", "TOTP · passkey · OTP · recovery code"),
        ("D6", "3.4", "role requires MFA?"),
        ("D5.3", "3.4", "confirmed factors"),
        ("D5.5", "3.4", "device trusted until"),
        ("3.4", "D5.4", "OTP challenge (hash)", "rw"),
        ("3.4", "MSG", "OTP to own e-mail / phone"),
        ("3.4", "D5.7", "MFA success / failure"),

        ("USR", "3.5", "refresh token · logout"),
        ("3.5", "D5.5", "device · session family · revoke", "rw"),
        ("3.5", "D5.7", "LOGIN_SUCCESS · refresh · reuse detected"),
        ("3.5", "USR2", "access + refresh tokens"),

        ("USR", "3.6", "reset request · new password"),
        ("3.6", "D5.2", "reset token (hash) · old hash", "rw"),
        ("3.6", "D5.1", "new password hash"),
        ("3.6", "D5.5", "revoke all sessions"),
        ("3.6", "MSG", "reset link"),

        ("USR", "3.7", "activation OTP · factor enrolment"),
        ("3.7", "D5.4", "EMAIL_VERIFY challenge", "rw"),
        ("3.7", "D4.2", "verified_at"),
        ("3.7", "D5.1", "status ACTIVE"),
        ("3.7", "D5.3", "factor · TOTP secret (encrypted) · passkey · recovery codes"),

        ("ADM", "3.8", "admin lock · release"),
        ("D5.7", "3.8", "failures in window"),
        ("3.8", "D5.6", "lockout period · released by", "rw"),
    ]))

add(Diagram(
    "dfd-2-04-authorise", "Level 2 — process 4: authorise", 2,
    src={
        "MOD": "Module owner<br/>(core · academics · exam · TMS …)",
        "ADM": "Access administrator",
        "APP": "Any module request",
    },
    proc={
        "4.1": "Register module, resources & permissions",
        "4.2": "Define roles, inheritance & conflicts",
        "4.3": "Set derivation rules",
        "4.4": "Grant role / permission explicitly",
        "4.5": "Resolve effective roles & permissions",
        "4.6": "Check permission<br/>has_permission()",
    },
    stores=["D2.1", "D2.3", "D3.1", "D3.2", "D3.3", "D5.1", "D6.1", "D6.2", "D6.3", "D6.4", "C1"],
    snk={
        "APP2": "Any module request",
        "P3": "<b>3</b> Authenticate",
        "P5": "<b>5</b> Approval workflow",
    },
    flows=[
        ("MOD", "4.1", "module · resource × action"),
        ("4.1", "D6.1", "permission (code derived)", "rw"),
        ("ADM", "4.2", "role · bundle · requires MFA · forbidden pairs"),
        ("D6.1", "4.2", "permissions"),
        ("4.2", "D6.2", "role · role_permission · inheritance · conflict", "rw"),
        ("ADM", "4.3", "designation · position · principal kind → role"),
        ("4.3", "D6.4", "rules (templates, never copied)", "rw"),
        ("ADM", "4.4", "account · role · scope unit · period · reason"),
        ("D6.2", "4.4", "role active? conflicts?"),
        ("D6.1", "4.4", "is_scopable"),
        ("4.4", "D6.3", "scoped, dated grant", "rw"),

        ("D6.3", "4.5", "explicit grants valid now"),
        ("D6.4", "4.5", "derivation rules"),
        ("D3.2", "4.5", "active assignments · designation"),
        ("D2.3", "4.5", "current appointments"),
        ("D3.3", "4.5", "current students"),
        ("D3.1", "4.5", "guardian relationships"),
        ("D6.2", "4.5", "role closure · role_permission"),
        ("4.5", "C1", "v_account_permission_effective"),
        ("4.5", "P3", "account requires MFA?"),

        ("APP", "4.6", "account · code · target unit"),
        ("D5.1", "4.6", "superuser · status can log in"),
        ("D2.1", "4.6", "ancestors / descendants of target"),
        ("C1", "4.6", "effective grants & scopes (or the views, uncached)"),
        ("4.6", "APP2", "true / false · accessible org units"),
        ("4.6", "P5", "may act on this step?"),
    ]))

add(Diagram(
    "dfd-2-05-workflow", "Level 2 — process 5: approval workflow", 2,
    src={
        "CFG": "Workflow administrator",
        "SUB": "Submitter<br/>coordinator · faculty · student",
        "REV": "Reviewer at the stage<br/>HOD · Dean · Dean Academics · Registrar",
    },
    proc={
        "5.1": "Configure document types, chains & levels<br/>approvers · conditions · deadlines · checklists · delegations",
        "5.2": "Submit document<br/>wf.submit()",
        "5.3": "List work pending for me",
        "5.4": "Comment, consult & resolve",
        "5.5": "Approve · sign · return · reject · forward · withdraw<br/>wf.act()",
        "5.6": "Derive round state",
        "5.7": "Run deadlines<br/>wf.run_timeouts()",
    },
    stores=["D2.1", "D3.2", "D3.4", "D6", "D7.1", "D7.2", "D7.3", "D7.4", "D7.5", "D7.6", "D10.12", "D10.11", "D12.10", "D13.8"],
    snk={
        "REV2": "Reviewer",
        "SUB2": "Submitter",
        "P8": "<b>8</b> Curriculum: status & freeze",
        "P10": "<b>10</b> Teaching: approved leave counts",
        "P11": "<b>11</b> Exam: revised mark counts",
    },
    flows=[
        ("CFG", "5.1", "document type · levels: who approves · how many · when it applies · deadline · checklist"),
        ("REV", "5.1", "standing delegation (out of office)"),
        ("D6", "5.1", "author & stage permissions"),
        ("5.1", "D7.1", "type · chain (default or subtree) · levels · checklist", "rw"),
        ("5.1", "D7.5", "delegation (bounded period)", "rw"),

        ("SUB", "5.2", "document · owner unit · note · amount · flags · named approvers"),
        ("D3.2", "5.2", "reporting line (the subject's manager)"),
        ("D10.11", "5.2", "committee members · quorum"),
        ("D6", "5.2", "author permission held?"),
        ("D7.1", "5.2", "most specific valid chain"),
        ("D2.1", "5.2", "nearest department · school · root"),
        ("5.2", "D7.2", "instance + flags + snapshot of the levels that apply + assignees"),
        ("5.2", "D7.6", "notice: a level is waiting"),
        ("5.2", "D10.12", "curriculum_approval link"),
        ("5.2", "D12.10", "attendance_leave request"),
        ("5.2", "D13.8", "internal_mark_revision request"),

        ("REV", "5.3", "my account"),
        ("D7.2", "5.3", "open rounds & current step"),
        ("D6", "5.3", "permission at anchor unit"),
        ("5.3", "REV2", "rounds awaiting my action"),

        ("REV", "5.4", "remark on table · row · column + suggested value · question to someone outside the chain"),
        ("SUB", "5.4", "accept / reject remark"),
        ("5.4", "D7.4", "comment (only resolved) · consultation (only answered)", "rw"),

        ("REV", "5.5", "action · note · file · ticked checklist · forward-to / return-to · approval out of turn by a higher level"),
        ("SUB", "5.5", "withdraw"),
        ("D7.2", "5.5", "current step · assignees · submitter"),
        ("D7.5", "5.5", "delegate standing in for an absent approver"),
        ("D6", "5.5", "eligible? (permission / position at the anchor; not the submitter, one step each)"),
        ("5.5", "D3.4", "signed document"),
        ("5.5", "D7.3", "action (append-only)"),
        ("5.5", "D7.2", "checklist ticks · assignee added / released"),
        ("5.5", "D7.6", "notices: next level · forwarded · returned · rejected · approved"),

        ("D7.2", "5.7", "current steps past their deadline"),
        ("5.7", "D7.3", "system actions: escalate · auto-approve · auto-reject"),
        ("5.7", "D7.6", "reminders"),

        ("D7.2", "5.6", "steps"),
        ("D7.3", "5.6", "actions"),
        ("5.6", "SUB2", "IN_PROGRESS · RETURNED · REJECTED · APPROVED · SIGNED · WITHDRAWN"),
        ("5.6", "P8", "v_curriculum_status"),
        ("5.6", "P10", "leave round complete"),
        ("5.6", "P11", "revision round complete"),
    ]))

add(Diagram(
    "dfd-2-06-privacy", "Level 2 — process 6: privacy and data-principal rights (DPDP Act 2023)", 2,
    src={
        "DPO": "DPO / Grievance officer",
        "PRI": "Data principal<br/>student · employee",
        "GUA": "Guardian / nominee",
        "APP": "Any module reading personal data",
        "JOB": "Scheduled retention sweep",
    },
    proc={
        "6.1": "Maintain purposes, inventory & processors",
        "6.2": "Publish privacy notice",
        "6.3": "Record & withdraw consent",
        "6.4": "Handle rights request",
        "6.5": "Erase / anonymise",
        "6.6": "Manage breach",
        "6.7": "Log access to personal data",
        "6.8": "Monitor compliance",
    },
    stores=["D3.1", "D3.2", "D3.4", "D4", "D5.1", "D8.1", "D8.2", "D8.3", "D8.4", "D8.5", "D8.6", "D8.7", "D8.8"],
    snk={
        "PRI2": "Data principal · guardian",
        "DPO2": "DPO / Grievance officer",
        "DPB": "Data Protection Board",
        "MSG": "Email / SMS gateway",
    },
    flows=[
        ("DPO", "6.1", "purpose · legal basis · retention · column → category → erasure action"),
        ("6.1", "D8.1", "purposes · data_element", "rw"),
        ("6.1", "D8.6", "processors & their purposes", "rw"),
        ("DPO", "6.2", "notice version · language · purposes"),
        ("D8.1", "6.2", "purposes"),
        ("6.2", "D8.2", "notice (SHA-256) · notice_purpose", "rw"),
        ("6.2", "D3.4", "notice file"),
        ("6.2", "PRI2", "notice in own language"),

        ("PRI", "6.3", "consent · withdrawal · nominee"),
        ("GUA", "6.3", "consent for a minor + verification evidence"),
        ("D8.2", "6.3", "purpose listed on the notice?"),
        ("D3.1", "6.3", "recorded guardian?"),
        ("D4", "6.3", "DOB → is minor"),
        ("6.3", "D8.3", "consent · parental verification · nominee", "rw"),
        ("6.3", "D3.4", "evidence file"),

        ("PRI", "6.4", "access · correction · erasure · grievance"),
        ("GUA", "6.4", "request on behalf"),
        ("DPO", "6.4", "acknowledge · decide · close"),
        ("6.4", "D8.4", "request + status events", "rw"),
        ("6.4", "PRI2", "access summary · status"),

        ("JOB", "6.5", "retention period elapsed"),
        ("D8.4", "6.5", "approved erasure request"),
        ("D8.1", "6.5", "erasure action per column"),
        ("D3.2", "6.5", "separation date"),
        ("6.5", "D4", "DELETE contacts · profile · documents"),
        ("6.5", "D3.1", "ANONYMISE name"),
        ("6.5", "D5.1", "random username · status ANONYMISED"),
        ("6.5", "D8.5", "evidence of every erasure"),

        ("DPO", "6.6", "incident · severity · affected persons"),
        ("6.6", "D8.7", "incident · affected · notifications", "rw"),
        ("6.6", "DPB", "intimation to the Board"),
        ("6.6", "MSG", "notice to each affected person"),

        ("APP", "6.7", "accessor · subject · category · purpose"),
        ("6.7", "D8.8", "access log (monthly partitions)"),

        ("D8.3", "6.8", "active consents"),
        ("D8.4", "6.8", "latest event · due date"),
        ("D8.8", "6.8", "who read whose data"),
        ("6.8", "DPO2", "v_dpr_request_status · v_minor_consent_gap · v_active_consent"),
    ]))

add(Diagram(
    "dfd-2-07-audit", "Level 2 — process 7: audit trail", 2,
    src={
        "OWN": "DB owner<br/>(migrations)",
        "MW": "Django middleware<br/>SET LOCAL app.*",
        "DML": "Any INSERT · UPDATE · DELETE<br/>on 307 audited tables",
        "TAM": "Anyone attempting UPDATE / DELETE on audit",
        "AUD": "Auditor · DPO",
    },
    proc={
        "7.1": "Attach capture trigger<br/>audit.enable_for_schemas()",
        "7.2": "Capture row change<br/>audit.capture()",
        "7.3": "Guard append-only<br/>audit.block_mutation()",
        "7.4": "Rotate monthly partitions",
        "7.5": "Review the trail",
    },
    stores=["D1", "D8.1", "D9.1"],
    snk={
        "TBL": "Audited tables<br/>(trg_audit_capture)",
        "REJ": "Statement rejected",
        "AUD2": "Auditor · DPO",
    },
    flows=[
        ("OWN", "7.1", "schemas to audit · logs to exclude"),
        ("7.1", "TBL", "AFTER row trigger"),
        ("MW", "7.2", "account · request · session · client IP"),
        ("DML", "7.2", "old row · new row · primary key"),
        ("D1", "7.2", "audit_action"),
        ("D8.1", "7.2", "columns with erasure action ≠ RETAIN_LEGAL"),
        ("7.2", "D9.1", "event + one row per changed column · erasable values as [REDACTED]"),
        ("TAM", "7.3", "UPDATE / DELETE"),
        ("7.3", "REJ", "insufficient_privilege"),
        ("OWN", "7.4", "create next months · drop expired"),
        ("7.4", "D9.1", "partitions (retention)", "rw"),
        ("AUD", "7.5", "entity · actor · period"),
        ("D9.1", "7.5", "events & changes"),
        ("7.5", "AUD2", "who changed which value, from what to what"),
    ]))

add(Diagram(
    "dfd-2-08-curriculum", "Level 2 — process 8: programmes, calendar and curriculum (SOE)", 2,
    src={
        "REG": "Regulators & accreditors",
        "ACA": "Academic office",
        "BOS": "Board of Studies / Academic Council",
        "CRD": "Programme coordinator",
    },
    proc={
        "8.1": "Define programme, specializations & outcomes",
        "8.2": "Record approvals & accreditation",
        "8.3": "Maintain academic calendar",
        "8.4": "Open batch (intake)",
        "8.5": "Record body meetings & resolutions",
        "8.6": "Maintain course catalogue & syllabus",
        "8.7": "Define grading & schemes of examination",
        "8.8": "Build curriculum version",
        "8.9": "Submit SOE & enforce the freeze",
    },
    stores=["D2.1", "D3.2", "D3.4", "D7", "D10.1", "D10.2", "D10.3", "D10.4", "D10.5", "D10.6",
            "D10.7", "D10.8", "D10.9", "D10.10", "D10.11", "D10.12"],
    snk={"ACA2": "Academic administration · reviewers"},
    flows=[
        ("ACA", "8.1", "programme · level · mode · duration · credits · coordinator · PO / PSO"),
        ("D2.1", "8.1", "offering unit (academic only)"),
        ("D3.2", "8.1", "coordinator (employee)"),
        ("8.1", "D10.1", "programme & outcomes", "rw"),

        ("REG", "8.2", "letter no. · sanctioned seats · grade · validity"),
        ("8.2", "D10.2", "approval · accreditation (one per body at a time)", "rw"),
        ("8.2", "D3.4", "letter file"),

        ("ACA", "8.3", "years · terms · holidays · registration & exam windows"),
        ("8.3", "D10.3", "calendar (no overlaps)", "rw"),

        ("ACA", "8.4", "programme × admission year · intake · documents"),
        ("D10.2", "8.4", "approved seats at year start"),
        ("D10.3", "8.4", "admission year"),
        ("D10.9", "8.4", "curriculum of the same programme"),
        ("8.4", "D10.4", "batch · specializations · curriculum link", "rw"),

        ("BOS", "8.5", "members · meeting · attendees · resolution"),
        ("8.5", "D10.11", "resolution (only with quorum)", "rw"),

        ("BOS", "8.6", "course · credits · L-T-P · prerequisites · syllabus units · COs"),
        ("D10.11", "8.6", "approving resolution"),
        ("D10.1", "8.6", "programme outcomes for CO–PO"),
        ("8.6", "D10.5", "course catalogue", "rw"),
        ("8.6", "D10.6", "syllabus version · CO · CO–PO mapping", "rw"),

        ("ACA", "8.7", "grade bands · divisions · components · weights · pass rules"),
        ("8.7", "D10.7", "grade scale (new policy = new scale)", "rw"),
        ("8.7", "D10.8", "scheme (weights total 100 %)", "rw"),

        ("CRD", "8.8", "courses per term · baskets · pathways · exits · promotion & load rules"),
        ("D10.5", "8.8", "courses"),
        ("D10.8", "8.8", "schemes"),
        ("D10.7", "8.8", "grade scale"),
        ("8.8", "D10.9", "curriculum items", "rw"),
        ("8.8", "D10.10", "award · promotion · attempt · credit-load rules", "rw"),

        ("CRD", "8.9", "submit_curriculum()"),
        ("D7", "8.9", "latest round state"),
        ("8.9", "D7", "new CURRICULUM round"),
        ("8.9", "D10.12", "round ↔ curriculum"),
        ("8.9", "D10.9", "frozen once APPROVED / SIGNED"),
        ("8.9", "ACA2", "v_soe · v_soe_exit · v_soe_header · v_curriculum_status"),
    ]))

add(Diagram(
    "dfd-2-09a-lifecycle", "Level 2 — process 9 (A): enrolment and student lifecycle", 2,
    src={
        "ACA": "Academic office",
        "STU": "Student",
        "DIS": "Discipline officer / committee",
    },
    proc={
        "9.1": "Enrol student in a batch",
        "9.2": "Record specialization & pathway",
        "9.3": "Register for the term",
        "9.4": "Decide academic standing",
        "9.5": "Approve break in study",
        "9.6": "Hear disciplinary case",
        "9.7": "Transfer programme / re-enter",
        "9.8": "Approve credit overload",
        "9.9": "Derive term, backlog & standing",
    },
    stores=["D1", "D3.3", "D10.3", "D10.4", "D10.9", "D10.10", "D10.11",
            "D11.1", "D11.2", "D11.3", "D11.4", "D11.8", "D11.9", "D13.10"],
    snk={
        "STU2": "Student",
        "ACA2": "Academic office · HOD",
    },
    flows=[
        ("ACA", "9.1", "student · batch · entry term · period · end reason"),
        ("D3.3", "9.1", "student record"),
        ("D10.4", "9.1", "batch & programme duration"),
        ("D1", "9.1", "enrollment_end_reason"),
        ("9.1", "D11.1", "enrollment (one active)", "rw"),

        ("STU", "9.2", "specialization · pathway choice"),
        ("D10.4", "9.2", "specializations offered to the batch"),
        ("D10.9", "9.2", "pathways of own curriculum"),
        ("9.2", "D11.1", "student_specialization · student_pathway", "rw"),

        ("STU", "9.3", "self-service registration"),
        ("ACA", "9.3", "office registration"),
        ("D10.3", "9.3", "term of the programme's calendar type"),
        ("D11.1", "9.3", "active enrollment · entry term"),
        ("D11.3", "9.3", "on a break when the term starts?"),
        ("D10.9", "9.3", "max duration (N + 2)"),
        ("D11.4", "9.3", "first enrollment of the lineage"),
        ("9.3", "D11.2", "term no. due (never edited)", "rw"),

        ("ACA", "9.4", "promoted · with backlog · detained"),
        ("D13.10", "9.4", "published results → backlog"),
        ("D10.10", "9.4", "promotion rule for the term"),
        ("9.4", "D11.2", "standing · decided by · when"),

        ("STU", "9.5", "application · reason"),
        ("ACA", "9.5", "approval · type · period"),
        ("9.5", "D11.3", "study_break (no overlap)", "rw"),

        ("DIS", "9.6", "report · decision · penalty"),
        ("D10.11", "9.6", "disciplinary committee"),
        ("9.6", "D11.3", "case · suspension as a study break", "rw"),

        ("ACA", "9.7", "close old · open new enrollment · approver"),
        ("D11.8", "9.7", "exit award · re-entry window"),
        ("D10.11", "9.7", "resolution"),
        ("9.7", "D11.1", "close with reason · open successor", "rw"),
        ("9.7", "D11.4", "transfer / re-entry link", "rw"),

        ("ACA", "9.8", "student · term · max credits · reason"),
        ("9.8", "D11.9", "overload approval", "rw"),

        ("D11.2", "9.9", "latest counted registration"),
        ("D11.3", "9.9", "breaks"),
        ("D11.4", "9.9", "lineage"),
        ("D13.10", "9.9", "latest results"),
        ("9.9", "STU2", "current term no. · is on break · must complete by"),
        ("9.9", "ACA2", "v_backlog · v_promotion_eligibility · v_student_standing"),
    ]))

add(Diagram(
    "dfd-2-09b-nep-credits", "Level 2 — process 9 (B): NEP 2020 credits, equivalence, minors and honours", 2,
    src={
        "BOS": "Board of Studies",
        "STU": "Student",
        "ABC": "ABC · MOOC platform · other university",
        "ACA": "Academic office",
    },
    proc={
        "9.10": "Approve course equivalence",
        "9.11": "Map external courses",
        "9.12": "Transfer credits in",
        "9.13": "Define minor / honours tracks",
        "9.14": "Join a track",
        "9.15": "Keep the credit ledger & CGPA",
        "9.16": "Derive completion & eligibility",
    },
    stores=["D2.1", "D3.4", "D4.4", "D10.5", "D10.8", "D10.9", "D10.10", "D10.11",
            "D11.1", "D11.4", "D11.5", "D11.6", "D11.7", "D13.10"],
    snk={
        "STU2": "Student",
        "ACA2": "Academic office",
        "P12": "<b>12</b> Awards & certificates",
        "P10": "<b>10</b> Course registration",
    },
    flows=[
        ("BOS", "9.10", "course B counts as course A · approver"),
        ("D10.11", "9.10", "resolution"),
        ("D10.5", "9.10", "both courses"),
        ("9.10", "D11.5", "course_equivalence (directional)", "rw"),

        ("BOS", "9.11", "provider · external course · credits · maps to course or category · period"),
        ("9.11", "D11.5", "provider · course · mapping (one at a time)", "rw"),

        ("STU", "9.12", "claim · completion date · grade point"),
        ("ABC", "9.12", "ABC transaction ref · certificate"),
        ("ACA", "9.12", "accept / reject"),
        ("D11.5", "9.12", "mapping valid on completion date"),
        ("D10.9", "9.12", "course / category in curriculum · transfer cap"),
        ("D4.4", "9.12", "APAAR / ABC ID (encrypted)"),
        ("9.12", "D3.4", "certificate file"),
        ("9.12", "D11.6", "credit_transfer", "rw"),

        ("ACA", "9.13", "track · type · credits · CGPA bar · courses"),
        ("D2.1", "9.13", "offering department"),
        ("D10.8", "9.13", "scheme per track course"),
        ("9.13", "D11.7", "track · track_course", "rw"),

        ("STU", "9.14", "track chosen"),
        ("D11.1", "9.14", "own programme & department"),
        ("D13.10", "9.14", "CGPA for the entry bar"),
        ("9.14", "D11.7", "student_track (one per type)", "rw"),

        ("D13.10", "9.15", "latest published result per course"),
        ("D11.6", "9.15", "accepted transfers"),
        ("D11.4", "9.15", "earlier enrollments"),
        ("D11.7", "9.15", "counts in CGPA?"),
        ("9.15", "STU2", "v_credit_ledger · exam.v_cgpa"),

        ("D11.5", "9.16", "equivalents"),
        ("D10.5", "9.16", "prerequisites"),
        ("D10.10", "9.16", "award rules & required courses"),
        ("D11.6", "9.16", "transferred courses"),
        ("9.16", "ACA2", "v_course_completion · v_prerequisite_gap · v_student_track_progress"),
        ("9.16", "P12", "v_award_eligibility"),
        ("9.16", "P10", "equivalent & track courses may be registered"),
    ]))

add(Diagram(
    "dfd-2-10a-term-setup", "Level 2 — process 10 (A): term set-up, registration and timetable", 2,
    src={
        "ACA": "HOD / academic office",
        "STU": "Student",
        "FAC": "Faculty",
        "SOL": "Timetable solver<br/>(Django)",
    },
    proc={
        "10.1": "Create offerings, sections & seat quotas",
        "10.2": "Allocate sections<br/>allocate_sections()",
        "10.3": "Register core courses<br/>register_core_courses()",
        "10.4": "Collect elective preferences",
        "10.5": "Allot electives<br/>allot_electives()",
        "10.6": "Register by choice / drop",
        "10.7": "Form class groups",
        "10.8": "Assign faculty",
        "10.9": "Build timetable",
    },
    stores=["D2.2", "D3", "D10", "D11", "D13.10", "D12.1", "D12.2", "D12.3", "D12.4",
            "D12.5", "D12.6", "D12.7", "D12.8"],
    snk={
        "ACA2": "HOD / academic office",
        "STU2": "Student",
        "FAC2": "Faculty",
    },
    flows=[
        ("ACA", "10.1", "course × term · teaching department · intake limit · sections · quotas"),
        ("D10", "10.1", "course · term · batch"),
        ("10.1", "D12.1", "offering · seat quota", "rw"),
        ("10.1", "D12.2", "section · capacity · class representative", "rw"),

        ("ACA", "10.2", "batch · term"),
        ("D11", "10.2", "enrollments active in the term"),
        ("D3", "10.2", "enrollment-number order"),
        ("10.2", "D12.2", "section_student (all or nothing)"),

        ("ACA", "10.3", "batch · term"),
        ("D10", "10.3", "fixed courses of each student's term"),
        ("D11", "10.3", "term no. · specialization · pathway"),
        ("D12.1", "10.3", "offerings of the term"),
        ("10.3", "D12.4", "registrations (re-runnable)"),

        ("STU", "10.4", "ranked choices in a basket"),
        ("D10", "10.4", "basket of own curriculum & term"),
        ("10.4", "D12.3", "elective_preference", "rw"),

        ("ACA", "10.5", "basket · term"),
        ("D12.3", "10.5", "preferences"),
        ("D13.10", "10.5", "CGPA (merit order)"),
        ("D12.1", "10.5", "intake limit · quota"),
        ("10.5", "D12.4", "registrations"),

        ("STU", "10.6", "equivalent · track · backlog course · drop"),
        ("D11", "10.6", "equivalence · track · overload approval"),
        ("D10", "10.6", "credit-load rule · continuation"),
        ("10.6", "D12.4", "registration status", "rw"),

        ("ACA", "10.7", "lab batches · elective groups · members"),
        ("D12.4", "10.7", "registered students"),
        ("D12.2", "10.7", "parent section"),
        ("10.7", "D12.5", "class_group · members", "rw"),

        ("FAC", "10.8", "ranked course preferences"),
        ("ACA", "10.8", "faculty × offering × class × L / T / P"),
        ("D3", "10.8", "teaching employees · designation"),
        ("D10", "10.8", "L-T-P hours of the course"),
        ("D12.5", "10.8", "groups"),
        ("10.8", "D12.6", "teaching_assignment (one primary)", "rw"),
        ("10.8", "ACA2", "v_teaching_gap · v_section_teaching · v_faculty_preference_status"),

        ("FAC", "10.9", "unavailability"),
        ("ACA", "10.9", "slot grid · workload norms"),
        ("SOL", "10.9", "proposed entries"),
        ("10.9", "D12.7", "slots · unavailability · workload norm", "rw"),
        ("D2.2", "10.9", "rooms · capacity · facilities"),
        ("D10", "10.9", "room requirement of the course"),
        ("D12.6", "10.9", "assignments & rosters"),
        ("10.9", "D12.8", "clash-free timetable entry", "rw"),
        ("10.9", "STU2", "v_student_timetable"),
        ("10.9", "FAC2", "own timetable · v_faculty_workload"),
    ]))

add(Diagram(
    "dfd-2-10b-teaching", "Level 2 — process 10 (B): classes, attendance, feedback and mentoring", 2,
    src={
        "FAC": "Faculty",
        "STU": "Student",
        "ACA": "HOD / academic office",
        "MEN": "Mentor / project guide",
    },
    proc={
        "10.10": "File lesson plan",
        "10.11": "Generate & record class sessions",
        "10.12": "Mark attendance",
        "10.13": "Apply for duty / medical leave",
        "10.14": "Derive attendance % & coverage",
        "10.15": "Run feedback cycle",
        "10.16": "Record mentoring meetings",
        "10.17": "Supervise projects & internships",
    },
    stores=["D3.1", "D3.2", "D3.3", "D3.4", "D7", "D10.3", "D10.6", "D12.4", "D12.6", "D12.8",
            "D12.9", "D12.10", "D12.11", "D12.12", "D12.13"],
    snk={
        "STU2": "Student",
        "FAC2": "Faculty · HOD",
        "P11": "<b>11</b> Exam eligibility",
    },
    flows=[
        ("FAC", "10.10", "ordered topics · planned hours & week"),
        ("D10.6", "10.10", "units of the current syllabus"),
        ("D12.6", "10.10", "own teaching assignment"),
        ("10.10", "D12.9", "lesson_plan_item", "rw"),

        ("FAC", "10.11", "status · substitute · extra class · topics covered"),
        ("D12.8", "10.11", "weekday · weeks · room"),
        ("D10.3", "10.11", "holidays → is_working_day()"),
        ("10.11", "D12.9", "class_session · class_session_topic", "rw"),

        ("FAC", "10.12", "present · absent · late per student"),
        ("D12.9", "10.12", "session was held?"),
        ("D12.4", "10.12", "roster of the class"),
        ("10.12", "D12.10", "attendance"),

        ("STU", "10.13", "leave type · period · reason · document"),
        ("10.13", "D3.4", "supporting document"),
        ("10.13", "D7", "ATTENDANCE_LEAVE round"),
        ("10.13", "D12.10", "attendance_leave (never edited)"),

        ("D12.10", "10.14", "marks · leave"),
        ("D12.9", "10.14", "held sessions · topics vs plan"),
        ("D7", "10.14", "leave round complete?"),
        ("10.14", "STU2", "v_attendance_summary"),
        ("10.14", "FAC2", "v_syllabus_coverage"),
        ("10.14", "P11", "attendance % per registration"),

        ("ACA", "10.15", "questionnaire · cycle · window"),
        ("STU", "10.15", "one submission + anonymous answers"),
        ("D12.4", "10.15", "registration of the term"),
        ("D12.6", "10.15", "class & teacher rated"),
        ("10.15", "D12.11", "submission (who) ∥ response (what) — never joined", "rw"),
        ("10.15", "FAC2", "v_feedback_summary"),

        ("MEN", "10.16", "meeting · summary · actions · concern flag"),
        ("D3.3", "10.16", "current mentorship"),
        ("10.16", "D12.12", "mentoring_meeting", "rw"),
        ("10.16", "FAC2", "v_mentoring_status"),

        ("MEN", "10.17", "title · guides · placement · report"),
        ("D12.4", "10.17", "registration of a supervised course"),
        ("D3.2", "10.17", "principal guide (employee)"),
        ("D3.1", "10.17", "external co-guide · industry mentor"),
        ("10.17", "D3.4", "offer letter · certificate · report"),
        ("10.17", "D12.13", "supervised work · guides · internship", "rw"),
        ("10.17", "FAC2", "v_guide_load"),
    ]))

add(Diagram(
    "dfd-2-11a-exam-conduct", "Level 2 — process 11 (A): exam planning and conduct", 2,
    src={
        "EXC": "Examination cell",
        "FIN": "Finance · discipline · HOD",
        "STU": "Student",
        "FAC": "Faculty<br/>setter · moderator · invigilator",
        "XAC": "External setter / examiner",
    },
    proc={
        "11.1": "Open exam session",
        "11.2": "Place holds & condone shortage",
        "11.3": "Check eligibility & register",
        "11.4": "Appoint setters & moderators",
        "11.5": "Maintain question bank",
        "11.6": "Set, moderate & approve paper",
        "11.7": "Publish date sheet",
        "11.8": "Plan rooms, seats, invigilators & panels",
        "11.9": "Conduct exam",
    },
    stores=["D2.2", "D3.1", "D3.2", "D3.4", "D10", "D12", "D13.1", "D13.2", "D13.3", "D13.4", "D13.5", "D13.6"],
    snk={
        "EXC2": "Examination cell",
        "STU2": "Student",
    },
    flows=[
        ("EXC", "11.1", "term · type · exam days · registration window"),
        ("D10", "11.1", "academic term"),
        ("11.1", "D13.1", "exam_session", "rw"),

        ("FIN", "11.2", "hold (fee dues · disciplinary) · release · condonation"),
        ("11.2", "D13.2", "hold (released, never deleted) · condonation", "rw"),

        ("STU", "11.3", "course · session · attempt type"),
        ("D12", "11.3", "course registration · attendance %"),
        ("D10", "11.3", "attendance threshold · max attempts · reappear chances"),
        ("D13.2", "11.3", "active hold · condonation"),
        ("D13.5", "11.3", "papers already on the date sheet (clash)"),
        ("11.3", "D13.3", "exam_registration", "rw"),
        ("11.3", "EXC2", "v_exam_eligibility"),

        ("EXC", "11.4", "setter · moderator per paper · due date"),
        ("D3.2", "11.4", "internal setter"),
        ("D3.1", "11.4", "external person"),
        ("11.4", "D13.4", "paper_setter_assignment (different people)", "rw"),

        ("FAC", "11.5", "question · marks · CO · Bloom · difficulty"),
        ("D10", "11.5", "course outcomes of the course"),
        ("11.5", "D13.4", "question_bank_item (reviewed by a second person)", "rw"),

        ("FAC", "11.6", "set · moderate"),
        ("XAC", "11.6", "set · moderate"),
        ("EXC", "11.6", "approve · print"),
        ("11.6", "D3.4", "confidential paper file"),
        ("11.6", "D13.4", "question_paper + items · status", "rw"),
        ("11.6", "EXC2", "v_question_paper_blueprint"),

        ("EXC", "11.7", "paper · date · time · approved set"),
        ("D13.1", "11.7", "session period"),
        ("D13.4", "11.7", "approved set of the same paper"),
        ("D13.3", "11.7", "registered students (clash)"),
        ("11.7", "D13.5", "exam_schedule", "rw"),

        ("EXC", "11.8", "rooms · seats · duties · examiner panel"),
        ("D2.2", "11.8", "rooms with exam capacity"),
        ("D3.2", "11.8", "invigilators · internal examiners"),
        ("D3.1", "11.8", "external examiners"),
        ("11.8", "D13.5", "exam_room · seat · duty · panel", "rw"),
        ("11.8", "STU2", "v_hall_ticket"),

        ("FAC", "11.9", "present · absent · unfair-means report"),
        ("EXC", "11.9", "UFM decision · penalty"),
        ("D13.5", "11.9", "paper & registered students"),
        ("11.9", "D13.6", "exam_attendance · ufm_case", "rw"),
    ]))

add(Diagram(
    "dfd-2-11b-exam-results", "Level 2 — process 11 (B): evaluation, results and attainment", 2,
    src={
        "EXC": "Examination cell",
        "FAC": "Faculty<br/>evaluator · course teacher",
        "XAC": "External examiner (panel)",
        "BRD": "Examination board",
        "STU": "Student",
    },
    proc={
        "11.10": "Code scripts & assign evaluators",
        "11.11": "Evaluate scripts",
        "11.12": "Enter internal, practical & viva marks",
        "11.13": "Apply grace & board moderation",
        "11.14": "Compute provisional result",
        "11.15": "Publish results",
        "11.16": "Revaluate & revise marks",
        "11.17": "Derive SGPA, CGPA, division & rank",
        "11.18": "Derive CO / PO attainment",
    },
    stores=["D7", "D10.6", "D10.7", "D10.8", "D11", "D13.4", "D13.5", "D13.6",
            "D13.7", "D13.8", "D13.9", "D13.10", "D13.11"],
    snk={
        "EXC2": "Examination cell",
        "STU2": "Student",
        "ACA2": "HOD · IQAC · regulators",
    },
    flows=[
        ("EXC", "11.10", "dummy codes · evaluator per round"),
        ("D13.6", "11.10", "student was present"),
        ("11.10", "D13.7", "answer_script (only code ↔ student link) · evaluator_assignment", "rw"),

        ("FAC", "11.11", "marks per script · per question"),
        ("D13.7", "11.11", "own assigned round · dummy code only"),
        ("D10.8", "11.11", "component maximum"),
        ("D13.4", "11.11", "question marks of the paper sat"),
        ("11.11", "D13.7", "script_mark (round added, never overwritten)"),
        ("11.11", "D13.8", "question_mark"),

        ("FAC", "11.12", "internal · assignment · quiz marks"),
        ("XAC", "11.12", "practical · viva marks"),
        ("D13.5", "11.12", "examiner panel of the paper"),
        ("D10.8", "11.12", "components of the course's scheme"),
        ("11.12", "D13.8", "component_mark", "rw"),

        ("BRD", "11.13", "± % per course · grace per attempt · reason"),
        ("11.13", "D13.9", "grace_award · result_moderation (within policy)", "rw"),

        ("D13.7", "11.14", "effective script mark (highest round)"),
        ("D13.8", "11.14", "component marks · approved revisions"),
        ("D13.9", "11.14", "grace · moderation"),
        ("D10.8", "11.14", "weights · best N of M · part minimums · internal-lead cap · rounding"),
        ("D10.7", "11.14", "grade band · relative cut-offs"),
        ("D7", "11.14", "revision round complete?"),
        ("11.14", "EXC2", "v_component_score · v_provisional_result"),

        ("EXC", "11.15", "publication · type · results"),
        ("11.15", "D13.10", "course_result (immutable) — marks behind it locked"),

        ("STU", "11.16", "recheck · revaluation · photocopy"),
        ("FAC", "11.16", "internal-marks revision request"),
        ("D13.10", "11.16", "a result is already published"),
        ("11.16", "D13.11", "revaluation_request", "rw"),
        ("11.16", "D13.8", "internal_mark_revision"),
        ("11.16", "D7", "INTERNAL_MARKS_REVISION round"),
        ("11.16", "D13.7", "new evaluation round"),

        ("D13.10", "11.17", "latest publication per attempt"),
        ("D11", "11.17", "lineage · transfers · tracks · result groups"),
        ("D10.7", "11.17", "division bands · % conversion"),
        ("11.17", "STU2", "v_current_result · v_sgpa · v_cgpa · v_division"),
        ("11.17", "EXC2", "v_rank_list · v_result_group_outcome"),

        ("D13.8", "11.18", "question-wise & component marks"),
        ("D13.4", "11.18", "question → course outcome"),
        ("D10.8", "11.18", "component → CO · attainment policy"),
        ("D10.6", "11.18", "CO–PO mapping & strength"),
        ("11.18", "ACA2", "v_student_co_score · v_co_attainment · v_po_attainment"),
    ]))

add(Diagram(
    "dfd-2-12-awards", "Level 2 — process 12: awards, certificates and convocation", 2,
    src={
        "ACA": "Academic office",
        "EXC": "Examination cell",
        "STU": "Student",
    },
    proc={
        "12.1": "Check award eligibility",
        "12.2": "Close enrollment & confer award",
        "12.3": "Issue marksheet",
        "12.4": "Issue certificate",
        "12.5": "Hold convocation",
        "12.6": "Award medals & prizes",
    },
    stores=["D1", "D2.2", "D3.4", "D10.10", "D11.1", "D11.6", "D11.8", "D13.10", "D13.12", "D13.13", "D14.5"],
    snk={
        "ACA2": "Academic office",
        "STU2": "Student",
        "NAD": "NAD / DigiLocker",
    },
    flows=[
        ("ACA", "12.1", "enrollment"),
        ("D10.10", "12.1", "award rule · min credits · required courses"),
        ("D13.10", "12.1", "credits earned"),
        ("D11.6", "12.1", "transferred credits"),
        ("12.1", "ACA2", "v_award_eligibility"),

        ("ACA", "12.2", "award rule · conferred on · approver"),
        ("D14.5", "12.2", "accepted viva (doctoral only)"),
        ("12.2", "D11.1", "close with end reason AWARD", "rw"),
        ("12.2", "D11.8", "student_award (one per enrollment)"),

        ("EXC", "12.3", "serial no. · original / duplicate"),
        ("D13.10", "12.3", "published results of the session"),
        ("12.3", "D3.4", "marksheet file"),
        ("12.3", "D13.12", "marksheet register"),
        ("12.3", "STU2", "marksheet"),

        ("STU", "12.4", "request · type"),
        ("EXC", "12.4", "issue · cancel · duplicate"),
        ("D1", "12.4", "certificate_type rules"),
        ("D11.8", "12.4", "conferred award"),
        ("D11.1", "12.4", "enrollment closed?"),
        ("12.4", "D3.4", "certificate file"),
        ("12.4", "D13.12", "serial · verification code · NAD reference", "rw"),
        ("12.4", "NAD", "certificate push"),
        ("12.4", "STU2", "certificate"),

        ("EXC", "12.5", "name · date · venue"),
        ("D2.2", "12.5", "room"),
        ("12.5", "D13.13", "convocation", "rw"),

        ("EXC", "12.6", "prize · rank position · citation"),
        ("D13.10", "12.6", "v_rank_list (derived rank)"),
        ("12.6", "D13.13", "prize · prize_award", "rw"),
        ("12.6", "STU2", "medal / prize"),
    ]))

add(Diagram(
    "dfd-2-13-research", "Level 2 — process 13: research degrees", 2,
    src={
        "RSD": "Research directorate",
        "SUP": "Supervisor · advisory committee",
        "SCH": "Research scholar",
        "XAC": "External examiner / expert",
    },
    proc={
        "13.1": "Set supervision norms",
        "13.2": "Allocate supervisors",
        "13.3": "Constitute advisory committee",
        "13.4": "Review progress",
        "13.5": "Track thesis milestones",
        "13.6": "Appoint examiners & record reports",
        "13.7": "Hold viva voce",
        "13.8": "Derive scholar status",
    },
    stores=["D2.2", "D3.1", "D3.2", "D3.4", "D11.1", "D13.10", "D14.1", "D14.2", "D14.3", "D14.4", "D14.5"],
    snk={
        "RSD2": "Research directorate · supervisor",
        "P12": "<b>12</b> Confer doctorate",
    },
    flows=[
        ("RSD", "13.1", "designation · max scholars · period"),
        ("D3.2", "13.1", "designations"),
        ("13.1", "D14.1", "supervision_norm", "rw"),

        ("RSD", "13.2", "scholar · role · supervisor · approver"),
        ("D11.1", "13.2", "doctoral enrollment"),
        ("D3.2", "13.2", "employee · current primary designation"),
        ("D3.1", "13.2", "external co-supervisor"),
        ("13.2", "D14.1", "supervisor_allocation (one principal · within norm)", "rw"),

        ("RSD", "13.3", "members · chair · external experts"),
        ("13.3", "D14.2", "committee · dated members (one chair)", "rw"),

        ("SUP", "13.4", "review no. · date · outcome · remarks"),
        ("D14.2", "13.4", "committee constituted by then"),
        ("13.4", "D14.2", "progress_review"),

        ("SCH", "13.5", "title · synopsis · thesis · similarity %"),
        ("D14.1", "13.5", "principal supervisor on the submission date"),
        ("13.5", "D3.4", "synopsis & thesis files"),
        ("13.5", "D14.3", "thesis · milestones in order", "rw"),

        ("RSD", "13.6", "internal / external examiners"),
        ("XAC", "13.6", "report · recommendation"),
        ("D14.1", "13.6", "nobody who ever supervised"),
        ("13.6", "D3.4", "report file"),
        ("13.6", "D14.4", "thesis_examiner", "rw"),

        ("RSD", "13.7", "date · room · outcome · approver"),
        ("D14.3", "13.7", "thesis submitted"),
        ("D14.4", "13.7", "all reports in · none blocking"),
        ("D2.2", "13.7", "room"),
        ("13.7", "D14.5", "viva", "rw"),

        ("D14.2", "13.8", "committee · reviews"),
        ("D14.3", "13.8", "thesis status"),
        ("D14.5", "13.8", "viva outcome"),
        ("D13.10", "13.8", "coursework credits"),
        ("13.8", "RSD2", "research.v_scholar_status"),
        ("13.8", "P12", "accepted viva on or before the award date"),
    ]))


add(Diagram(
    "dfd-2-14a-space-bookings", "Level 2 — process 14 (a): space, the occupancy ledger and room bookings", 2,
    src={
        "FAD": "Facility administrator",
        "CUS": "Custodian<br/>block head · department · booking desk",
        "REQ": "Requester<br/>student · employee · unit",
        "JOB": "Scheduled job<br/>(app.system_job)",
    },
    off_l={"ACD": "<b>10–13</b><br/>Teaching · exams · awards · research<br/>(timetable entries, sessions, exam rooms, convocations, vivas)",
           "EVT": "<b>16</b><br/>Clubs & events<br/>(venue package of a proposal or of a change)"},
    proc={
        "14.1": "Keep the space inventory<br/>floors · room use · composed halls · custody · allocation",
        "14.2": "Set booking rules<br/>reserved rooms · priority · policy · restrictions · blackouts · service windows",
        "14.3": "Maintain the occupancy ledger<br/>materialise timetable · displace · reinstate",
        "14.4": "Request a booking<br/>rooms × dates · series · features · tentative hold",
        "14.5": "Decide & use a booking<br/>approve · return · check in · release no-shows",
        "14.6": "Cancel & reschedule a booking",
        "14.7": "Book an event's venue package<br/>rooms · trips · one EVENT_REQUEST round",
        "14.8": "Find free rooms & report use<br/>free rooms · timeline · utilisation",
    },
    stores=["D2.2", "D6", "D7", "D12.8", "D12.9", "D13.5", "D13.13", "D14.5",
            "D15.1", "D15.2", "D15.3", "D15.4", "D15.5"],
    snk={
        "REQ2": "Requester",
        "CUS2": "Custodian · facility administrator",
        "ACA2": "Academic administration",
    },
    flows=[
        ("FAD", "14.1", "floors · room use & area · composed halls · custody · allocation shares"),
        ("D2.2", "14.1", "campuses · buildings · rooms"),
        ("14.1", "D2.2", "floor · room_use · area · accessibility · room features"),
        ("14.1", "D15.1", "room_composition · custody · space_allocation", "rw"),
        ("14.1", "CUS2", "space inventory (v_space_inventory)"),

        ("FAD", "14.2", "reserved rooms & who may book them · priority rules · booking policy · restricted persons · blackouts · service windows"),
        ("D2.2", "14.2", "rooms · floors · buildings a rule covers"),
        ("14.2", "D15.1", "room_reservation_rule", "rw"),
        ("14.2", "D15.2", "hold_priority_rule · room_service_window · blackout", "rw"),
        ("14.2", "D15.4", "booking_policy · booking_restriction", "rw"),
        ("14.2", "CUS2", "rules in force (policy_for() · room_reserved_for() · is_restricted())"),

        ("ACD", "14.3", "timetable per term · extra & cancelled classes · exam rooms · convocations · vivas"),
        ("D12.8", "14.3", "timetable_entry (slot · room · validity · pattern)"),
        ("D12.9", "14.3", "class_session (extra · cancelled)"),
        ("D13.5", "14.3", "exam_room · date sheet"),
        ("D13.13", "14.3", "convocation venue"),
        ("D14.5", "14.3", "viva venue"),
        ("D15.1", "14.3", "parts of a composed room · custodian"),
        ("D15.2", "14.3", "which use outranks which (outranks()) · service windows"),
        ("14.3", "D15.3", "room_hold (EXCLUDE per room · shadows · displacement · reinstate_hold())", "rw"),
        ("14.3", "ACA2", "displaced classes · timetable gaps (v_displaced_hold · v_timetable_gap)"),

        ("REQ", "14.4", "rooms × dates or a series (occurrence_dates()) · start / end · purpose · headcount · features · note (request_booking())"),
        ("D2.2", "14.4", "capacity · room features"),
        ("D15.1", "14.4", "custodian of each room (custodian_of()) · reservation rules"),
        ("D15.4", "14.4", "policy limits · restricted persons"),
        ("D15.2", "14.4", "blackouts"),
        ("D6", "14.4", "may book? backdating right?"),
        ("14.4", "D15.5", "group GRP-YYYY-NNNN · one request per custodian · requirements · occurrences", "rw"),
        ("14.4", "D7", "ROOM_BOOKING round owned by the custodian", "rw"),
        ("14.4", "D15.3", "tentative hold per occurrence"),
        ("14.4", "REQ2", "booking status (v_booking_status · v_booking_summary)"),

        ("CUS", "14.5", "approve · return · backdated booking"),
        ("REQ", "14.5", "check-in"),
        ("JOB", "14.5", "no-show run (release_no_shows())"),
        ("D6", "14.5", "may approve here?"),
        ("D15.4", "14.5", "check-in window · no-show grace"),
        ("14.5", "D7", "approve / return on the ROOM_BOOKING round", "rw"),
        ("14.5", "D15.5", "check-in · no-show cancellation", "rw"),
        ("14.5", "D15.3", "hold confirmed · freed on return or no-show"),
        ("14.5", "CUS2", "pending approvals"),
        ("14.5", "REQ2", "approved · returned · released"),

        ("REQ", "14.6", "cancel · reschedule to a new slot"),
        ("CUS", "14.6", "custodian cancellation"),
        ("D15.4", "14.6", "cancellation cut-off"),
        ("14.6", "D15.5", "cancelled occurrences · a new request naming the occurrence it replaces", "rw"),
        ("14.6", "D7", "ROOM_BOOKING_CHANGE round · open rounds withdrawn", "rw"),
        ("14.6", "D15.3", "holds released"),
        ("14.6", "REQ2", "cancelled / rescheduled (cancel_booking_group())"),

        ("REQ", "14.7", "event: title · dates · headcount · rooms · trips (request_event())"),
        ("EVT", "14.7", "the venue package of an event proposal · new dates of an approved change"),
        ("14.7", "D15.5", "event_request · its booking requests (waiting for the event's round)", "rw"),
        ("14.7", "D7", "EVENT_REQUEST round", "rw"),
        ("14.7", "REQ2", "event status (v_event_status)"),

        ("REQ", "14.8", "which rooms are free for these slots?"),
        ("D15.3", "14.8", "holds per room (room_is_free() · free_rooms())"),
        ("D2.2", "14.8", "rooms · capacity · features"),
        ("D15.1", "14.8", "composed halls (room_parts() · linked_rooms())"),
        ("14.8", "REQ2", "free rooms"),
        ("14.8", "CUS2", "room timeline · utilisation (v_room_timeline · v_room_utilisation)"),
    ]))

add(Diagram(
    "dfd-2-14b-assets-transport", "Level 2 — process 14 (b): assets, maintenance, guest house, transport, keys & parking", 2,
    src={
        "FAD": "Facility administrator",
        "CUS": "Custodian · store keeper",
        "REQ": "Requester<br/>student · employee · unit",
        "MNT": "Maintenance team · vendor",
        "GHM": "Guest-house manager",
        "TRN": "Transport office",
        "DRV": "Driver",
        "JOB": "Scheduled job<br/>(app.system_job)",
    },
    proc={
        "14.9": "Keep assets, vendors & contracts",
        "14.10": "Book & lend assets<br/>with a booking · loans · returns",
        "14.11": "Report & fix faults<br/>work orders · assignment · progress · closure",
        "14.12": "Plan preventive maintenance<br/>schedules · due list",
        "14.13": "Run the guest house<br/>tariffs · stays · check-in / out · charges",
        "14.14": "Request transport<br/>normal or urgent · approval",
        "14.15": "Allocate & run trips<br/>driver · vehicle · pooling · trip · ratings",
        "14.16": "Keep the fleet<br/>vehicles · documents · service · drivers · leave · policy",
        "14.17": "Escalate unallocated trips<br/>(system job)",
        "14.18": "Issue keys & access cards",
        "14.19": "Issue parking permits",
    },
    stores=["D2.2", "D3.1", "D3.2", "D3.4", "D4.4", "D6", "D7", "D15.2", "D15.3", "D15.5",
            "D15.6", "D15.7", "D15.8", "D15.9", "D15.10", "D15.11", "D15.12"],
    snk={
        "REQ2": "Requester",
        "CUS2": "Custodian · facility administrator",
        "MNT2": "Maintenance team",
        "GHM2": "Guest-house manager · Finance",
        "TRN2": "Transport office · driver",
    },
    flows=[
        ("FAD", "14.9", "assets · location · custodian · purchase & warranty · vendors · service contracts"),
        ("D2.2", "14.9", "room / location"),
        ("D3.4", "14.9", "contract file"),
        ("14.9", "D15.6", "vendor · asset · service_contract", "rw"),
        ("14.9", "CUS2", "asset register (v_asset_register)"),

        ("REQ", "14.10", "asset with a booking · loan request"),
        ("CUS", "14.10", "issue · return · condition"),
        ("D15.5", "14.10", "occurrence the asset is booked with"),
        ("D3.1", "14.10", "borrower"),
        ("D6", "14.10", "custodian's lending right"),
        ("14.10", "D15.6", "booking_asset · asset_loan → asset_hold (EXCLUDE; asset_usable())", "rw"),
        ("14.10", "REQ2", "loan status · due back"),

        ("REQ", "14.11", "fault report (raise_work_order())"),
        ("MNT", "14.11", "assignment · progress · closure note"),
        ("D3.1", "14.11", "reporter"),
        ("D3.2", "14.11", "technician"),
        ("D15.6", "14.11", "asset · vendor"),
        ("14.11", "D15.7", "work order WO-YYYY-NNNNN · append-only events", "rw"),
        ("14.11", "D15.2", "service window of the room (released on closure)"),
        ("14.11", "MNT2", "status · SLA due · overdue (v_work_order_status)"),
        ("14.11", "REQ2", "progress of my report"),

        ("FAD", "14.12", "preventive schedules: what · how often"),
        ("D15.6", "14.12", "assets"),
        ("14.12", "D15.7", "maintenance_schedule · last done", "rw"),
        ("14.12", "MNT2", "maintenance due (v_maintenance_due)"),

        ("REQ", "14.13", "guest · category · host unit · nights · purpose (request_guest_stay())"),
        ("GHM", "14.13", "tariffs · approve · check-in / out"),
        ("D3.1", "14.13", "guest (internal or external person)"),
        ("D2.2", "14.13", "guest rooms · beds"),
        ("14.13", "D7", "GUEST_STAY round ⇄ state", "rw"),
        ("14.13", "D15.8", "guest_stay · guest_tariff", "rw"),
        ("14.13", "D15.3", "nightly hold (night_span())"),
        ("14.13", "GHM2", "stay status · charge per stay (v_guest_stay_status · v_guest_stay_charge)"),

        ("REQ", "14.14", "purpose · window · from → to · party · contact · urgent · cancel (request_trip())"),
        ("D15.10", "14.14", "transport policy: lead time · urgent window · party size (transport_policy_for())"),
        ("D15.5", "14.14", "event the trip belongs to"),
        ("D6", "14.14", "may request · may approve"),
        ("14.14", "D7", "TRIP_REQUEST / TRIP_REQUEST_URGENT round ⇄ state · AUTO_APPROVE (system job)", "rw"),
        ("14.14", "D15.11", "trip_request", "rw"),
        ("14.14", "REQ2", "request status (v_trip_status)"),

        ("TRN", "14.15", "driver then vehicle · pooling · start / complete / close"),
        ("DRV", "14.15", "odometer · pickup photo"),
        ("REQ", "14.15", "rating after the trip"),
        ("D15.10", "14.15", "vehicle & driver free (vehicle_available()) · seats · service windows · driver leave"),
        ("D4.4", "14.15", "driving licence: class · expiry"),
        ("D3.4", "14.15", "pickup photo"),
        ("14.15", "D15.11", "allocation (EXCLUDE per driver & vehicle) · pooled requests · trip · ratings", "rw"),
        ("14.15", "TRN2", "trip summary (v_trip_summary)"),
        ("14.15", "REQ2", "driver · vehicle · trip status"),

        ("TRN", "14.16", "vehicles · documents · service windows · drivers · driver leave · transport policy"),
        ("D3.2", "14.16", "driver employee"),
        ("D4.4", "14.16", "driving licence document"),
        ("14.16", "D15.10", "vehicle · vehicle_document · vehicle_service_window · driver · driver_unavailability · transport_policy", "rw"),
        ("14.16", "TRN2", "document expiry (v_vehicle_document_status)"),

        ("JOB", "14.17", "periodic run (run_trip_escalations())"),
        ("D15.11", "14.17", "approved, unallocated requests near departure"),
        ("D15.10", "14.17", "escalation thresholds"),
        ("14.17", "D15.11", "trip_alert"),
        ("14.17", "TRN2", "escalation alerts"),

        ("CUS", "14.18", "keys · access cards · issue · return"),
        ("D3.1", "14.18", "holder"),
        ("D2.2", "14.18", "room · floor · building a key opens"),
        ("14.18", "D15.12", "key_item · key_issue (one holder at a time)", "rw"),
        ("14.18", "CUS2", "who holds what · who can open what (v_key_custody · v_key_access)"),

        ("FAD", "14.19", "permit: holder · vehicle · zone · validity"),
        ("D3.1", "14.19", "permit holder"),
        ("D2.2", "14.19", "parking zone bays"),
        ("14.19", "D15.9", "parking_permit (zone capacity · one per vehicle)", "rw"),
        ("14.19", "CUS2", "free bays (v_parking_zone_usage)"),
    ]))

add(Diagram(
    "dfd-2-15-helpdesk", "Level 2 — process 15: helpdesk & grievance redressal (TMS)", 2,
    src={
        "TAD": "Helpdesk administrator",
        "REQ": "Requester<br/>student · employee",
        "DSK": "Intake desk<br/>walk-in · phone · letter",
        "HND": "Handler · owner · route-level holder",
        "FRM": "Redressal forum<br/>SGRC · ICC · anti-ragging · Ombudsperson",
        "JOB": "Hourly scheduler<br/>(app.system_job)",
        "SND": "Notice sender (app)",
    },
    proc={
        "15.1": "Configure the helpdesk<br/>tree · routes · forums · handlers · policy",
        "15.2": "Raise a ticket<br/>route · open the clock",
        "15.3": "Work the ticket<br/>reply · note · clarify · hold · consult · reassign · transfer · resolve",
        "15.4": "Escalate<br/>next level of the route",
        "15.5": "Requester's answer<br/>accept · reopen · rate · withdraw · name a respondent",
        "15.6": "Grievance redressal<br/>refer · hear · decide · appeal · comply",
        "15.7": "Run the scheduler<br/>refer · escalate · release holds · compliance · remind · expire · close",
        "15.8": "Queue & deliver notices",
        "15.9": "Derive state, register & reports",
    },
    stores=["D2.1", "D2.3", "D3.2", "D3.3", "D3.4", "D4.2", "D5.1", "D6", "D10.3", "D10.4", "D10.5", "D10.11", "D11.1",
            "D16.1", "D16.2", "D16.3", "D16.4", "D16.5", "D16.6", "D16.7"],
    snk={
        "REQ2": "Requester",
        "HND2": "Handler · owner · unit head",
        "FRM2": "Forum members",
        "TAD2": "Helpdesk administrator · grievance cell",
        "MSG": "Email / SMS gateway",
    },
    flows=[
        ("TAD", "15.1", "tree · routes · forums · owners · handlers · declaration · file types · channels · settings · weekly hours · dated overrides · notice rules · help articles"),
        ("15.1", "D16.7", "help articles (dated publication)", "rw"),
        ("D16.7", "15.2", "help articles for the chosen leaf"),
        ("REQ", "15.2", "the article answered my question (anonymous)"),
        ("15.2", "D16.7", "kb_feedback (no person)"),
        ("D2.1", "15.1", "responsible units · handler scopes"),
        ("D2.3", "15.1", "positions valid for a unit type"),
        ("D3.2", "15.1", "employees"),
        ("15.1", "D16.1", "settings · weekdays · office closures · declaration · notice rules", "rw"),
        ("15.1", "D16.2", "category tree (inherited settings) · dated owners · scoped handler pools", "rw"),
        ("15.1", "D16.3", "routes and levels · redressal forums", "rw"),

        ("REQ", "15.2", "category · message type · subject · description · relief sought · incident date · phone · files · anonymous · academic context · respondent"),
        ("DSK", "15.2", "the same, recorded for the requester (channel)"),
        ("D5.1", "15.2", "requester account"),
        ("D6", "15.2", "create / intake / choose-assignee permission"),
        ("D4.2", "15.2", "the requester's own phone"),
        ("D3.3", "15.2", "student · mentor"),
        ("D11.1", "15.2", "the student's unit · own batches"),
        ("D16.2", "15.2", "active leaf · inherited route, forum and flags · handlers · owners"),
        ("D16.3", "15.2", "route levels · forum"),
        ("D2.3", "15.2", "who holds the position relative to the requester"),
        ("D16.1", "15.2", "declaration in force · office hours · Student TMS switch"),
        ("D10.3", "15.2", "university holidays · the term"),
        ("D10.4", "15.2", "batch"),
        ("D10.5", "15.2", "course"),
        ("D3.4", "15.2", "attached files"),
        ("15.2", "D16.4", "ticket TMS-YYYY-NNNNN · academic context · respondents"),
        ("15.2", "D16.5", "CREATED: first route level · due time (or REFERRED straight to a forum)"),

        ("HND", "15.3", "reply · internal note · clarification request · hold with a reason · consultation · reassignment · transfer · resolution · merge"),
        ("HND", "15.3", "consultation answer (the employee consulted)"),
        ("REQ", "15.3", "comment · clarification reply"),
        ("D16.5", "15.3", "current state (v_ticket_state)"),
        ("D6", "15.3", "scoped update permission"),
        ("D16.2", "15.3", "handlers serving the requester · new leaf"),
        ("15.3", "D16.5", "replied · noted · paused / resumed · reassigned · transferred · resolved · merged", "rw"),

        ("HND", "15.4", "escalation with a reason"),
        ("REQ", "15.4", "escalation of an overdue ticket"),
        ("D16.3", "15.4", "levels above the current one"),
        ("D16.2", "15.4", "owners · handlers"),
        ("D2.3", "15.4", "who holds the position today"),
        ("D3.3", "15.4", "the student's mentor"),
        ("15.4", "D16.5", "ESCALATED / RECUSED: next assignee · level · due time"),

        ("REQ", "15.5", "accept · reopen reason · rating 1–5 · withdrawal · respondent"),
        ("D16.1", "15.5", "reopen, rating and confirmation windows · max reopens"),
        ("15.5", "D16.5", "CONFIRMED · REOPENED · RATED · WITHDRAWN"),
        ("15.5", "D16.4", "respondent (append-only)"),

        ("REQ", "15.6", "referral · appeal"),
        ("HND", "15.6", "referral (any forum)"),
        ("FRM", "15.6", "hearing · clarification · decision with outcome · forwarding with a report"),
        ("D16.3", "15.6", "forum · time limit · appeal forum"),
        ("D10.11", "15.6", "the nearest committee · members · quorate resolution"),
        ("D2.3", "15.6", "Ombudsperson"),
        ("15.6", "D16.5", "REFERRED · APPEALED · FORUM_FORWARDED · FORUM_DECIDED · ACTION_TAKEN"),

        ("JOB", "15.7", "hourly run"),
        ("D16.5", "15.7", "clocks past due · pending clarifications · uncontested resolutions · unsettled grievances"),
        ("D16.1", "15.7", "auto-escalation · reminder / expiry · confirmation · auto-referral"),
        ("15.7", "D16.5", "AUTO_ESCALATED · ESCALATION_EXHAUSTED · OVERDUE_NOTICE · HOLD_EXPIRED · COMPLIANCE_REMINDER · CLARIFICATION_REMINDER / _EXPIRED · AUTO_CLOSED · AUTO_REFERRED"),

        ("D16.5", "15.8", "each new event"),
        ("D16.1", "15.8", "notice rules"),
        ("D16.4", "15.8", "respondents (never notified)"),
        ("SND", "15.8", "delivery outcome"),
        ("D16.6", "15.8", "opt-outs (mandatory notices still go)"),
        ("15.8", "D16.6", "one notice per recipient × channel; given up after the maximum attempts", "rw"),
        ("15.8", "MSG", "e-mail (address looked up when sending)"),
        ("15.8", "REQ2", "in-app notices"),
        ("15.8", "FRM2", "referrals · forwarded cases · overdue notices · late-action alerts (also to the VC)"),

        ("D16.4", "15.9", "raised facts"),
        ("D16.5", "15.9", "timeline"),
        ("15.9", "REQ2", "status · due time · requester timeline (no internal notes)"),
        ("15.9", "HND2", "my tickets · overdue · v_ticket_handler_stats · unit tickets"),
        ("D16.7", "15.9", "article feedback"),
        ("15.9", "TAD2", "v_ticket_category_stats · v_ticket_category_rollup · v_ticket_sla (attention) · v_ticket_unrouted · grievance register & return · v_kb_article_stats"),
    ]))

add(Diagram(
    "dfd-2-16a-clubs-proposals", "Level 2 — process 16 (a): clubs, sponsorship and event proposals", 2,
    src={
        "FAC": "Faculty<br/>advisor · proposer",
        "OFF": "Club officers · organisers",
        "STU": "Student",
        "CCC": "Central coordination committee",
        "ADM": "Events administrator",
        "SPN": "Sponsor",
    },
    off_l={"WFL": "<b>5</b><br/>Approval workflow<br/>(rounds, levels, decisions)"},
    off_r={"P14": "<b>14</b><br/>Facilities<br/>(venue package: rooms held, trips requested)"},
    proc={
        "16.1": "Propose a club<br/>parent unit · name · objective · advisors · first officers & members",
        "16.2": "Found the club on approval<br/>org unit · advisor appointments · officers · members",
        "16.3": "Run club membership<br/>applications · officers · suspensions · calendar · primary club",
        "16.4": "Change a club<br/>name · objective · advisor · officers · members · category",
        "16.5": "Draft an event proposal<br/>dates · fees · capacity · audience · speakers · budget · prizes · visibility",
        "16.6": "Submit the proposal<br/>approval round · venue package",
        "16.7": "Secure sponsorship<br/>sponsors · commitments · receipts · in-kind items",
        "16.8": "Configure the module<br/>settings · points per event type · tiers",
    },
    stores=["D2.1", "D2.3", "D3.1", "D3.3", "D3.4", "D7", "D17.1", "D17.2", "D17.3", "D17.4", "D17.11", "D17.12"],
    snk={
        "FAC2": "Proposer · advisor · officers",
        "STU2": "Student",
        "CCC2": "Committee",
    },
    flows=[
        ("FAC", "16.1", "club proposal: parent unit · name · objective · category · advisors · first officers & members · attachments (submit_club_proposal())"),
        ("D2.1", "16.1", "units that may have a club"),
        ("D3.3", "16.1", "current students"),
        ("D17.11", "16.1", "settings: name & objective length · advisor must be faculty · required offices"),
        ("16.1", "D17.2", "club_proposal + officers · members · attachments (frozen once submitted)", "rw"),
        ("16.1", "D7", "CLUB_PROPOSAL round · club category as a flag", "rw"),
        ("16.1", "FAC2", "proposal status"),

        ("WFL", "16.2", "CLUB_PROPOSAL round approved"),
        ("D17.2", "16.2", "the approved proposal"),
        ("16.2", "D2.1", "org unit of type CLUB"),
        ("16.2", "D2.3", "advisor / co-advisor appointments"),
        ("16.2", "D17.1", "club · first officers · first members"),
        ("16.2", "FAC2", "club founded (v_club)"),

        ("STU", "16.3", "application to join · primary club"),
        ("OFF", "16.3", "decide applications · officers · calendar items"),
        ("CCC", "16.3", "suspension"),
        ("D3.3", "16.3", "current students"),
        ("D17.11", "16.3", "settings: primary club needs an office?"),
        ("16.3", "D17.1", "members · applications · officers (one per office) · suspensions · calendar · primary club", "rw"),
        ("16.3", "STU2", "membership · application status"),
        ("16.3", "CCC2", "clubs and current officers (v_club_officer_current)"),

        ("OFF", "16.4", "change request: what changes · new name, objective, advisor, officers, members or category (submit_club_change())"),
        ("WFL", "16.4", "CLUB_CHANGE round approved → applied (apply_club_change())"),
        ("D17.11", "16.4", "settings: open changes per club"),
        ("16.4", "D17.12", "club_change_request + officer / member lines", "rw"),
        ("16.4", "D7", "CLUB_CHANGE round · the kind of change as flags", "rw"),
        ("16.4", "D17.1", "officers · members replaced on approval"),
        ("16.4", "D2.1", "renamed unit"),
        ("16.4", "D2.3", "advisor appointment replaced"),
        ("16.4", "FAC2", "change status (v_club_change)"),

        ("OFF", "16.5", "draft: type · dates · level · fees · capacity · audience · SDGs · partners · speakers · coordinators · budget · funding · prizes · visibility · attachments"),
        ("D17.1", "16.5", "who may propose for the club (may_propose_for()) · is it running (club_is_active())"),
        ("D3.1", "16.5", "speakers · coordinators"),
        ("D3.4", "16.5", "attachments"),
        ("D17.11", "16.5", "settings: lead time · required sections"),
        ("16.5", "D17.3", "event_proposal + its parts (a revision is a new proposal)", "rw"),
        ("16.5", "FAC2", "draft (v_proposal_status)"),

        ("OFF", "16.6", "submit (submit_proposal())"),
        ("D17.3", "16.6", "draft · budget total"),
        ("D17.11", "16.6", "settings: proposals under approval per proposer"),
        ("16.6", "D17.3", "submitted: frozen"),
        ("16.6", "D7", "EVENT_PROPOSAL round: amount = budget total · flags PAID_EVENT / EXTERNAL_GUESTS / SPONSORED", "rw"),
        ("16.6", "P14", "venue package on the same round: rooms held · trips requested"),
        ("16.6", "FAC2", "proposal status (v_proposal_status)"),

        ("OFF", "16.7", "sponsor · commitment · in-kind items · receipts"),
        ("SPN", "16.7", "money received · items delivered"),
        ("D17.3", "16.7", "the proposal sponsored"),
        ("16.7", "D17.4", "event_sponsor · event_sponsorship · sponsorship_receipt · sponsorship_item", "rw"),
        ("16.7", "FAC2", "committed against received (v_sponsorship_status)"),

        ("ADM", "16.8", "module settings"),
        ("CCC", "16.8", "points per event type · tiers"),
        ("16.8", "D17.11", "event_setting · event_type_points (dated) · club_tier", "rw"),
        ("16.8", "CCC2", "settings in force"),
    ]))

add(Diagram(
    "dfd-2-16b-running-events", "Level 2 — process 16 (b): running an event", 2,
    src={
        "OFF": "Organisers · advisor",
        "STU": "Student · participant",
        "VOL": "Volunteers at the gate",
    },
    off_l={"WFL": "<b>5</b><br/>Approval workflow<br/>(rounds, levels, decisions)"},
    proc={
        "16.9": "Publish & organise the event<br/>descriptions · window · rounds · FAQs · questions · cancel",
        "16.10": "Change an approved event<br/>dates · venue · capacity",
        "16.11": "Recruit volunteers<br/>sign-up · decision · duties",
        "16.12": "Register<br/>seat or waiting list · answers · guests · withdrawal",
        "16.13": "Form teams<br/>team · invitations · join requests · finalise",
        "16.14": "Issue tickets & scan the gate<br/>QR token · preview · in / out",
        "16.15": "Record session attendance<br/>check-in per round · imported sheet",
        "16.16": "Award prizes & certificates<br/>winners · templates · verification",
        "16.17": "Collect feedback & close<br/>one-time token · report · complete · points · duty leave",
    },
    stores=["D3.1", "D3.3", "D3.4", "D7", "D15", "D12.10", "D17.3", "D17.5", "D17.6", "D17.7",
            "D17.8", "D17.9", "D17.10", "D17.11"],
    snk={
        "STU2": "Student · participant",
        "OFF2": "Organisers · advisor",
        "VOL2": "Volunteers at the gate",
        "PUB": "Anyone verifying a certificate",
        "CCC2": "Committee",
    },
    flows=[
        ("WFL", "16.9", "EVENT_PROPOSAL round approved"),
        ("OFF", "16.9", "descriptions · contact · registration window · rounds · FAQs · links · custom questions · publish (publish_event()) · cancel (cancel_event())"),
        ("D17.3", "16.9", "the approved facts (type, dates, fees, capacity)"),
        ("D17.11", "16.9", "settings: what publishing needs"),
        ("D3.1", "16.9", "contact person"),
        ("16.9", "D17.5", "event · rounds · FAQs · links · custom fields & options", "rw"),
        ("16.9", "OFF2", "status: draft · published · ongoing · ended · completed · cancelled (v_event)"),
        ("16.9", "STU2", "published events open to me (can_see())"),

        ("OFF", "16.10", "change request: new dates · venue · capacity · reason (submit_event_change())"),
        ("WFL", "16.10", "EVENT_CHANGE round approved → applied (apply_event_change())"),
        ("D17.6", "16.10", "seats taken"),
        ("16.10", "D17.5", "event_change_request · rounds shifted", "rw"),
        ("16.10", "D7", "EVENT_CHANGE round · flags EVENT_RESCHEDULE / EVENT_VENUE_CHANGE / EVENT_CAPACITY_CHANGE", "rw"),
        ("16.10", "D17.3", "approved change: dates · venue · capacity rewritten"),
        ("16.10", "D15", "new venue package · the old one released"),
        ("16.10", "OFF2", "change status (v_event_change)"),

        ("STU", "16.11", "offer to volunteer"),
        ("OFF", "16.11", "accept / decline · assign duties (gate, scanning)"),
        ("D3.1", "16.11", "student or employee"),
        ("16.11", "D17.5", "volunteer_application · event_volunteer", "rw"),
        ("16.11", "VOL2", "my duties (v_volunteer_assignment)"),
        ("16.11", "OFF2", "volunteer activity (v_volunteer_activity)"),

        ("STU", "16.12", "registration · answers · guests · withdrawal (register())"),
        ("OFF", "16.12", "decide registrations where approval is needed · next from the waiting list (promote_waitlist())"),
        ("D17.5", "16.12", "open? window · seat limit (seat_limit() · seats_taken()) · visibility · questions"),
        ("D3.3", "16.12", "the student's programme · batch · school (visibility)"),
        ("D17.11", "16.12", "settings: guest-pass ceiling"),
        ("16.12", "D17.6", "registration (seat or waiting list) · answers · extra passes", "rw"),
        ("16.12", "STU2", "status: confirmed · waitlisted · pending payment (v_registration)"),

        ("STU", "16.13", "team · invitation · join request · answer · finalise · leave"),
        ("OFF", "16.13", "disqualify a team"),
        ("D17.6", "16.13", "live registrations of the event"),
        ("D17.5", "16.13", "team size limits (team_size())"),
        ("16.13", "D17.7", "event_team · members · invitations · join requests", "rw"),
        ("16.13", "STU2", "my team · incomplete team (v_team)"),

        ("STU", "16.14", "my ticket (issue_ticket(): the token is shown once)"),
        ("VOL", "16.14", "pass check · QR scan in / out (scan()) · people count · gate"),
        ("OFF", "16.14", "imported gate sheet"),
        ("D17.6", "16.14", "confirmed? · guests allowed · ticket hash"),
        ("D17.5", "16.14", "who may scan"),
        ("16.14", "D17.6", "ticket hash (replaced on reissue)"),
        ("16.14", "D17.8", "entry_scan (append-only)"),
        ("16.14", "STU2", "ticket: QR token, pass size (v_ticket)"),
        ("16.14", "VOL2", "scan preview: who may still enter (ticket_check()) · count at the gate"),
        ("16.14", "OFF2", "who is inside (people_inside() · v_gate_summary)"),

        ("VOL", "16.15", "session check-in by ticket (check_in_round())"),
        ("OFF", "16.15", "imported session sheet"),
        ("D17.5", "16.15", "rounds · who is on duty"),
        ("D17.6", "16.15", "confirmed registrations"),
        ("D17.11", "16.15", "settings: check-in opens before a session"),
        ("16.15", "D17.8", "round_attendance (append-only)"),
        ("16.15", "OFF2", "attendance per session (v_round_attendance · v_attendance)"),

        ("OFF", "16.16", "prize winners · certificate templates · issue (issue_certificates())"),
        ("D17.3", "16.16", "prize list"),
        ("D17.8", "16.16", "who attended (attended())"),
        ("D17.7", "16.16", "winning team"),
        ("D17.5", "16.16", "volunteers"),
        ("D3.4", "16.16", "certificate design files"),
        ("16.16", "D17.9", "prize awards · templates · certificates (serial · verification code)", "rw"),
        ("16.16", "STU2", "certificates"),
        ("16.16", "PUB", "certificate valid? (v_certificate_verify)"),

        ("STU", "16.17", "feedback with a one-time token (submit_feedback())"),
        ("OFF", "16.17", "report · complete the event (complete_event()) · duty leave (grant_duty_leave())"),
        ("D17.8", "16.17", "who attended"),
        ("D17.11", "16.17", "points per event type · feedback scale"),
        ("16.17", "D17.10", "feedback_token (used once) · feedback (no person)", "rw"),
        ("16.17", "D17.5", "post_event_report (versions) · completed_at"),
        ("16.17", "D3.4", "report files"),
        ("16.17", "D17.11", "club_point_award on completion"),
        ("16.17", "D12.10", "duty-leave requests for attendees & organisers (v_duty_leave_eligible)"),
        ("16.17", "CCC2", "committee overview · leaderboard · statistics (v_ccc_overview · v_club_leaderboard · v_event_statistics)"),
    ]))

add(Diagram(
    "dfd-2-16c-money-mail-stalls", "Level 2 — process 16 (c): fees, settlement, messages and stalls", 2,
    src={
        "STU": "Student · participant",
        "OFF": "Organisers",
        "ADM": "Events administrator",
        "GW": "Payment gateway<br/>(through the app)",
        "SND": "Mail sender (app)",
        "VIS": "Visitors (public)",
        "JOB": "Scheduled job<br/>(app.system_job)",
    },
    off_l={"WFL": "<b>5</b><br/>Approval workflow<br/>(rounds, levels, decisions)"},
    proc={
        "16.18": "Offer coupons<br/>create · redeem",
        "16.19": "Take payments<br/>online order · offline claim · verification · cash",
        "16.20": "Refund & expire<br/>refund queue · expiry of unpaid registrations",
        "16.21": "Record expenses & settle<br/>bills · settlement round",
        "16.22": "Write to registrants<br/>audience · schedule · credits · delivery",
        "16.23": "Apply for a stall<br/>fee · set-up · documents · decision",
        "16.24": "Run stalls & collect feedback<br/>stalls · products · public feedback",
    },
    stores=["D3.4", "D7", "D17.3", "D17.5", "D17.6", "D17.7", "D17.11", "D17.13", "D17.14", "D17.15"],
    snk={
        "STU2": "Student · participant",
        "OFF2": "Organisers",
        "ADM2": "Events administrator · accounts",
        "MSG": "Email gateway",
    },
    flows=[
        ("OFF", "16.18", "coupon: code · percentage or fixed · cap · minimum fee · limits · expiry"),
        ("STU", "16.18", "coupon code (redeem_coupon())"),
        ("D17.5", "16.18", "paid event?"),
        ("D17.6", "16.18", "the registration"),
        ("16.18", "D17.13", "event_coupon · coupon_redemption (discount fixed at redemption)", "rw"),
        ("16.18", "OFF2", "coupon usage (v_coupon_usage)"),
        ("16.18", "STU2", "amount due after the discount (amount_due())"),

        ("STU", "16.19", "online order · offline claim with proof"),
        ("GW", "16.19", "order captured / failed"),
        ("OFF", "16.19", "verify an offline payment · record cash"),
        ("D17.6", "16.19", "what is owed: fee · coupon (payer_registration())"),
        ("D17.7", "16.19", "complete team (the leader pays once)"),
        ("D17.15", "16.19", "stall fee owed (stall_fee())"),
        ("D17.11", "16.19", "settings: currency · minimum payable"),
        ("D3.4", "16.19", "payment proof"),
        ("16.19", "D17.13", "event_payment: open → captured / failed", "rw"),
        ("16.19", "STU2", "receipt · paid (is_paid() · amount_settled())"),

        ("ADM", "16.20", "refund recorded with its reference (record_refund())"),
        ("JOB", "16.20", "expiry run (expire_unpaid_registrations())"),
        ("D17.11", "16.20", "settings: when an unpaid registration expires"),
        ("D17.6", "16.20", "cancelled registrations with a captured payment · unpaid ones"),
        ("16.20", "D17.13", "refunded payment"),
        ("16.20", "D17.6", "unpaid registration expired"),
        ("16.20", "ADM2", "refund queue (v_refund_queue)"),

        ("OFF", "16.21", "expenses with bills · settlement (submit_settlement())"),
        ("WFL", "16.21", "EVENT_SETTLEMENT round decided (returned → corrected and resubmitted)"),
        ("D17.3", "16.21", "approved budget per head"),
        ("D17.11", "16.21", "settings: bill required above"),
        ("D3.4", "16.21", "bills"),
        ("16.21", "D17.13", "event_expense · event_settlement", "rw"),
        ("16.21", "D7", "EVENT_SETTLEMENT round: amount = total spent · flag OVER_BUDGET", "rw"),
        ("16.21", "ADM2", "budget against actual · settlement (v_event_budget_actual · v_event_settlement)"),

        ("OFF", "16.22", "message · audience · selection · schedule · cancel"),
        ("ADM", "16.22", "extra mail credits"),
        ("JOB", "16.22", "scheduler run (run_mail_scheduler() → dispatch_mail())"),
        ("SND", "16.22", "delivery outcome · opens (mail_opened())"),
        ("D17.6", "16.22", "recipients by registration state"),
        ("D17.11", "16.22", "settings: credits per registration · subject / body limits · open tracking"),
        ("16.22", "D17.14", "event_mail · recipients · outcomes · credit grants", "rw"),
        ("16.22", "MSG", "message (the address is looked up when sending — never stored)"),
        ("16.22", "OFF2", "delivery status · credits left (v_event_mail · v_event_mail_credit)"),

        ("STU", "16.23", "stall application · set-up needs · documents · declarations"),
        ("OFF", "16.23", "stall fees per category · decision"),
        ("D17.5", "16.23", "takes stalls? deadline · limit"),
        ("D3.4", "16.23", "documents"),
        ("D17.13", "16.23", "stall fee paid?"),
        ("16.23", "D17.15", "event_stall_fee · stall_application · set-up · documents · the stall on approval", "rw"),
        ("16.23", "STU2", "application status · stall code (v_stall_application)"),

        ("OFF", "16.24", "own stalls · locations · products · deactivate"),
        ("VIS", "16.24", "stall feedback: scores · comment (submit_stall_feedback())"),
        ("D17.11", "16.24", "settings: feedback points"),
        ("16.24", "D17.15", "event_stall · products · stall_feedback (anonymous)", "rw"),
        ("16.24", "OFF2", "stalls · feedback averages (v_stall)"),
    ]))

# ------------------------------------------------------------------ Level 3 --
# One diagram per feature = per Level-2 process, derived from the Level-2 specs
# above: the process, every flow it receives or sends, and whatever is at the
# other end (entities, stores, neighbouring processes drawn as off-page boxes).
# Nothing is redrawn by hand, so a feature can never disagree with its parent.
FEATURE_DOC = REPO / "docs" / "data-flow-features.md"
AREAS = [
    ("platform", "Platform — organisation, people, login, permissions, approvals, privacy, audit",
     ["dfd-2-01-org-people", "dfd-2-03-authenticate", "dfd-2-04-authorise", "dfd-2-05-workflow", "dfd-2-06-privacy", "dfd-2-07-audit"]),
    ("academic", "Academic — programmes, curriculum, student lifecycle, NEP credits, teaching",
     ["dfd-2-08-curriculum", "dfd-2-09a-lifecycle", "dfd-2-09b-nep-credits", "dfd-2-10a-term-setup", "dfd-2-10b-teaching"]),
    ("exam", "Examinations, awards and research degrees",
     ["dfd-2-11a-exam-conduct", "dfd-2-11b-exam-results", "dfd-2-12-awards", "dfd-2-13-research"]),
    ("facility", "Resource & facility management", ["dfd-2-14a-space-bookings", "dfd-2-14b-assets-transport"]),
    ("tms", "Helpdesk & grievance redressal (TMS)", ["dfd-2-15-helpdesk"]),
    ("events", "Clubs & event management", ["dfd-2-16a-clubs-proposals", "dfd-2-16b-running-events", "dfd-2-16c-money-mail-stalls"]),
]


def plain(text: str) -> str:
    return re.sub(r"<[^>]+>", "", text.replace("<br/>", " — ")).strip()


def feature_name(p: str) -> str:
    return "features/dfd-3-" + p.replace(".", "-")


def derive_features(level2: list[Diagram]) -> list[tuple[Diagram, Diagram, str]]:
    """(feature diagram, its Level-2 parent, process id) for every Level-2 process."""
    out = []
    for d in level2:
        for p, label in d.proc.items():
            src, snk, off_l, off_r, stores, flows = {}, {}, {}, {}, [], []
            for f in d.flows:
                if p not in f[:2]:
                    continue
                incoming = f[1] == p
                other = f[0] if incoming else f[1]
                key = other
                if other in d.src:
                    src[other] = d.src[other]
                elif other in d.snk:
                    snk[other] = d.snk[other]
                elif other in d.off_l:
                    off_l[other] = d.off_l[other]
                elif other in d.off_r:
                    off_r[other] = d.off_r[other]
                elif other in d.stores:
                    if other not in stores:
                        stores.append(other)
                elif other in d.proc:                       # a neighbouring step, drawn off-page
                    box = f"<b>{other}</b><br/>{d.proc[other].split('<br/>')[0]}"
                    key = other + ("_in" if incoming else "_out")
                    (off_l if incoming else off_r)[key] = box
                else:
                    raise KeyError(f"{d.name}: {other!r} on a flow of {p}")
                flows.append((key, p, *f[2:]) if incoming else (p, key, *f[2:]))
            fd = Diagram(feature_name(p), f"Level 3 — feature {p}: {plain(label.split('<br/>')[0])}", 3,
                         src=src, proc={p: label}, stores=stores, snk=snk, off_l=off_l, off_r=off_r, flows=flows)
            out.append((fd, d, p))
    return out


FEATURES = derive_features([d for d in DIAGRAMS if d.level == 2])
DIAGRAMS.extend(fd for fd, _, _ in FEATURES)


def catalog_anchor(schema: str, table: str) -> str:
    return f"table-catalog.md#t-{schema}-{table}".replace("_", "-")


def store_text(sid: str, linked: bool = True) -> str:
    if sid in STORES:
        schema, tables = STORES[sid]
        s = schema.split(" ")[0]
        names = " · ".join(f"[`{t}`]({catalog_anchor(s, t)})" if linked else f"`{t}`" for t in tables)
        return f"**{sid}** `{s}`: {names}"
    schema, text = AGG[sid]
    return f"**{sid}** `{schema}` (whole schema, drawn on its own process): {plain(text)}"


def table_features() -> dict[str, list[tuple[str, str, str]]]:
    """schema.table -> [(process id, feature title, R / W / RW)], for the table catalog."""
    res: dict[str, list[tuple[str, str, str]]] = {}
    for fd, _, p in FEATURES:
        title = plain(fd.proc[p].split("<br/>")[0])
        for sid in fd.stores:
            if sid not in STORES:
                continue
            r = any(f[0] == sid for f in fd.flows)
            w = any(f[1] == sid for f in fd.flows)
            rw = any(f[1] == sid and len(f) > 3 and f[3] == "rw" for f in fd.flows)
            mode = "RW" if rw or (r and w) else ("W" if w else "R")
            schema, tables = STORES[sid]
            for t in tables:
                res.setdefault(f"{schema.split(' ')[0]}.{t}", []).append((p, title, mode))
    return res


def features_doc() -> str:
    by_parent: dict[str, list] = {}
    for fd, d, p in FEATURES:
        by_parent.setdefault(d.name, []).append((fd, p))
    titles = {d.name: d.title for d in DIAGRAMS if d.level == 2}
    placed = {n for _, _, names in AREAS for n in names}
    missing = sorted(set(titles) - placed)
    if missing:
        raise SystemExit(f"AREAS: level-2 diagrams not in any area: {missing}")
    L = ["# Data flow — feature by feature (Level 3)", "",
         "<!-- GENERATED by docs/dfd/build_dfd.py — edit the Level-2 specs there, not this file. -->", "",
         f"Every feature of every module on its own diagram: **{len(FEATURES)} features** in "
         f"{len(AREAS)} areas. A feature is one step (process) of a Level-2 diagram in "
         "[`data-flow.md`](data-flow.md); its diagram shows that step alone with everything it "
         "receives, reads, writes and sends, and what is at the other end. Each one is derived from "
         "the Level-2 specification by `docs/dfd/build_dfd.py`, so it cannot disagree with its parent, "
         "and the same script checks that every table of the database is in a data store that some "
         "feature writes.", "",
         "Under each diagram: the flows in a table, then **every table the feature touches**, linked to "
         "its card in [`table-catalog.md`](table-catalog.md). The legend is the one of "
         "[`data-flow.md`](data-flow.md#how-to-read-the-diagrams); off-page boxes are the neighbouring "
         "steps of the same area or other processes, each with its own diagram here.", "",
         "Two gates sit on every write and are not repeated per feature: **4.x** decides whether the "
         "account may do it (`authz.has_permission()`), **7.x** records that it happened (`audit.capture()`).", "",
         "## Contents", ""]
    for aid, head, names in AREAS:
        n = sum(len(by_parent.get(x, [])) for x in names)
        L.append(f"- [{head}](#a-{aid}) — {n} features")
    for aid, head, names in AREAS:
        L += ["", "---", "", f'<a id="a-{aid}"></a>', f"## {head}", ""]
        L += ["| Feature | What it covers | Level 2 parent |", "|---|---|---|"]
        for name in names:
            for fd, p in by_parent.get(name, []):
                parts = fd.proc[p].split("<br/>")
                L.append(f"| [{p} · {plain(parts[0])}](#f-{p.replace('.', '-')}) | {plain(' — '.join(parts[1:])) or '—'} | "
                         f"[{plain(titles[name]).replace('Level 2 — ', '')}](dfd/{name}.png) |")
        for name in names:
            L += ["", f"### {plain(titles[name]).replace('Level 2 — ', '')}", "",
                  f"Whole process: [png](dfd/{name}.png) · [svg](dfd/{name}.svg)"]
            for fd, p in by_parent.get(name, []):
                parts = fd.proc[p].split("<br/>")
                base = fd.name
                L += ["", f'<a id="f-{p.replace(".", "-")}"></a>', f"#### {p} · {plain(parts[0])}", ""]
                if len(parts) > 1:
                    L += [f"*{plain(' · '.join(parts[1:]))}*", ""]
                L += [f"![Feature {p}](dfd/{base}.png)", "",
                      f"<sub>[svg](dfd/{base}.svg) · [mmd](dfd/{base}.mmd)</sub>", "",
                      "| Flow | With | What moves |", "|---|---|---|"]

                def who(k):
                    for dct in (fd.src, fd.snk, fd.off_l, fd.off_r):
                        if k in dct:
                            return plain(dct[k])
                    return k
                for f in fd.flows:
                    a, b, lab = f[0], f[1], plain(f[2])
                    rw = len(f) > 3 and f[3] == "rw"
                    if a == p:
                        other = b
                        kind = "reads & writes" if rw else ("writes →" if b in fd.stores else "sends →")
                    else:
                        other = a
                        kind = "← reads" if a in fd.stores else "← receives"
                    with_ = f"**{other}**" if other in fd.stores else who(other)
                    L.append(f"| {kind} | {with_} | {lab.replace('|', '/')} |")
                if fd.stores:
                    L += ["", "**Tables touched:**", ""]
                    L += [f"- {store_text(s)}" for s in fd.stores]
    L += ["", "---", "", "Regenerate: `python docs/dfd/build_dfd.py` (writes the `.mmd` files and this document), "
          "then `bash docs/dfd/render.sh` (renders every diagram, features included).", ""]
    return "\n".join(L)


# ----------------------------------------------------------------------------
def sql_tables() -> dict[str, str]:
    """table name -> schema, from the CREATE TABLE statements (partitions excluded)."""
    found = {}
    for f in sorted((REPO / "sql").glob("[01]*.sql")):
        for m in re.finditer(r"^\s*CREATE TABLE\s+(?:IF NOT EXISTS\s+)?([a-z_]+)\.([a-z_0-9]+)\s*(\(|PARTITION OF)",
                             f.read_text(encoding="utf-8"), re.M | re.I):
            if m.group(3).upper() != "PARTITION OF":
                found[m.group(2)] = m.group(1)
    return found


def check_coverage() -> list[str]:
    errors = []
    real = sql_tables()
    seen: dict[str, str] = {}
    for sid, (schema, tables) in STORES.items():
        for t in tables:
            if t in seen:
                errors.append(f"{t}: in both {seen[t]} and {sid}")
            seen[t] = sid
            if t not in real:
                errors.append(f"{sid}: {schema}.{t} is not a table in sql/*.sql")
            elif real[t] != schema.split(" ")[0]:
                errors.append(f"{sid}: {t} is in schema {real[t]}, not {schema}")
    for t, schema in real.items():
        if schema != "ref" and t not in seen:
            errors.append(f"{schema}.{t}: not in any data store")
    shown = {s for d in DIAGRAMS if d.level == 2 for s in d.stores}
    for sid in STORES:
        if sid not in shown:
            errors.append(f"{sid}: not shown on any Level-2 diagram")
    written = {f[1] for d in DIAGRAMS if d.level == 2 for f in d.flows if f[1] in STORES}
    for sid in STORES:
        if sid not in written:
            errors.append(f"{sid}: read but never written on any Level-2 diagram")
    for d in DIAGRAMS:
        used = {x for f in d.flows for x in f[:2]}
        for k in list(d.src) + list(d.snk) + list(d.proc) + d.stores + list(d.off_l) + list(d.off_r):
            if k not in used:
                errors.append(f"{d.name}: node {k} has no flow")
        for p in d.proc:
            ins = [f for f in d.flows if f[1] == p or (f[0] == p and len(f) > 3)]
            outs = [f for f in d.flows if f[0] == p]
            if not ins:
                errors.append(f"{d.name}: process {p} has no input (miracle)")
            if not outs:
                errors.append(f"{d.name}: process {p} has no output (black hole)")
    n_ref = sum(1 for s in real.values() if s == "ref")
    print(f"tables in sql/: {len(real)}  (ref lookups: {n_ref}, in stores: {len(seen)})")
    return errors


def store_index() -> str:
    where: dict[str, list[str]] = {}
    for d in DIAGRAMS:
        if d.level == 2:
            for s in d.stores:
                where.setdefault(s, []).append(d.name.replace("dfd-2-", ""))
    rows = ["| Store | Schema | Tables | Shown on |", "|---|---|---|---|"]
    for sid, (schema, tables) in STORES.items():
        rows.append(f"| **{sid}** | `{schema}` | " + ", ".join(f"`{t}`" for t in tables)
                    + " | " + ", ".join(where.get(sid, [])) + " |")
    return "\n".join(rows)


def main() -> int:
    (HERE / "features").mkdir(exist_ok=True)
    keep = {f"{fd.name.split('/')[-1]}.mmd" for fd, _, _ in FEATURES}
    for old in (HERE / "features").glob("*.mmd"):          # a feature that no longer exists
        if old.name not in keep:
            for ext in (".mmd", ".svg", ".png"):
                old.with_suffix(ext).unlink(missing_ok=True)
    for d in DIAGRAMS:
        (HERE / f"{d.name}.mmd").write_text(d.emit() + "\n", encoding="utf-8", newline="\n")
    FEATURE_DOC.write_text(features_doc(), encoding="utf-8", newline="\n")
    errors = check_coverage()
    for e in errors:
        print("ERROR", e)
    if DOC.exists():
        text = DOC.read_text(encoding="utf-8")
        new = re.sub(r"(<!-- stores:begin -->).*?(<!-- stores:end -->)",
                     lambda m: m.group(1) + "\n" + store_index() + "\n" + m.group(2), text, flags=re.S)
        if new != text:
            DOC.write_text(new, encoding="utf-8", newline="\n")
            print("refreshed the store index in docs/data-flow.md")
    print(f"{len(DIAGRAMS)} diagrams ({len(FEATURES)} feature diagrams), {len(STORES)} table-level stores, "
          f"{sum(len(d.proc) for d in DIAGRAMS if d.level == 2)} level-2 processes, "
          f"{sum(len(d.flows) for d in DIAGRAMS)} flows; {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
