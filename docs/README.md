# Documentation index

Every document of the new intranet database, grouped by what it is for. The
repository's own [`README.md`](../README.md) explains how to build and verify
the database; [`CLAUDE.md`](../CLAUDE.md) and [`SKILL.md`](../SKILL.md) are
the rules for changing it.

## Layout

```
new intranet db/
  README.md  CLAUDE.md  SKILL.md     overview, build & verify, rules for changes
  sql/                               the database: 00–11 foundation, 12 tms, 13 events,
                                     90–91 illustrative SGT data, 97–99 smoke tests
  scripts/                           generators and checks for the documents below
  docs/
    README.md                        this index
    *.md                             foundation documents (below)
    catalog-diagrams/                ER diagrams of the table catalog (generated)
    dfd/                             data-flow diagrams and their builder (generated);
                                     dfd/features/ = one diagram per feature (Level 3)
    tms/                             the helpdesk & grievance redressal module
    events/                          the clubs & events module
```

## Foundation — design

| Document | What it is |
|---|---|
| [design.md](design.md) | The foundation's design: principles, schema map, ER diagrams, the flows (onboarding, login, authorisation, approvals, modules), Django mapping |
| [user-access-design.md](user-access-design.md) | User management, login (UID or e-mail, MFA) and permission-based roles |
| [soe-permission-design.md](soe-permission-design.md) | The Statement of Examination in the permission-based model |
| [module-integration.md](module-integration.md) | Worked examples: central departments, how TMS, Resource Management and Events attach, configuring an approval |

## Foundation — reference (generated from the live database)

| Document | What it is | Regenerate with |
|---|---|---|
| [table-catalog.md](table-catalog.md) | Every table: why it exists, what it connects to, an ER diagram per group, the features that read / write it, the views and functions over each group | `dfd/build_dfd.py`, then `scripts/gen_catalog_diagrams.py`; checked by `scripts/check_table_catalog.py` |
| [data-dictionary.md](data-dictionary.md) | Every table, column, constraint, view and function | `scripts/gen_data_dictionary.{sql,py}` |
| [data-flow.md](data-flow.md) | Data-flow diagrams: context, processes, stores; the guards per step | `dfd/build_dfd.py`, then `dfd/render.sh` |
| [data-flow-features.md](data-flow-features.md) | Level 3: one data-flow diagram per feature (170), by module — inputs, outputs and every table read or written | `dfd/build_dfd.py`, then `dfd/render.sh` |

## Compliance and audit

| Document | What it is |
|---|---|
| [dpdp-compliance.md](dpdp-compliance.md) | DPDP Act 2023 mapped to tables and constraints; the POLICY items (retention, legal basis) |
| [audit-2026-10-01.md](audit-2026-10-01.md) | Audit of the whole database (1 October 2026): duplication, normalisation, DPDP, documents against the live structure — fixed, accepted by design, open |

## Modules

| Module | Design | Backend plan |
|---|---|---|
| Helpdesk & student grievance redressal (`tms`, `sql/12_tms.sql`) | [tms/tms-design.md](tms/tms-design.md) — flows, UGC alignment, committees, configuration, parity with the old UMS | [tms/tms-backend-plan.md](tms/tms-backend-plan.md) |
| Clubs & events (`events`, `sql/13_events.sql`) | `design.md` §4.1k and `table-catalog.md` §15 | [events/events-backend-plan.md](events/events-backend-plan.md) |

## Presentation

| Document | What it is |
|---|---|
| [academic-flow.md](academic-flow.md) (+ `.png`, `.svg`) | The academic flow on one slide |

## Conventions

- Generated documents are never edited by hand; change the SQL and regenerate.
- A module keeps its documents in `docs/<module>/`. Its tables are still
  described in the shared `table-catalog.md`, `data-flow.md`,
  `data-flow-features.md` and `data-dictionary.md`.
- Illustrative data (`sql/9x_example_*.sql`) is not part of the build; the
  smoke tests (`sql/97`–`99`) build their own data and roll back.
