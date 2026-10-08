"""Render docs/data-dictionary.md from the tab-separated catalog dump produced
by gen_data_dictionary.sql.

Usage:
    psql -d intranet -f scripts/gen_data_dictionary.sql > /tmp/dict.tsv
    python scripts/gen_data_dictionary.py /tmp/dict.tsv docs/data-dictionary.md

Regenerate after any change to a table, column, view or function. Do not
hand-edit docs/data-dictionary.md — edits will be lost on the next run.
"""
import sys
import collections

src, out = sys.argv[1], sys.argv[2]
T = []
C = collections.defaultdict(list)
K = collections.defaultdict(list)
I = collections.defaultdict(list)
V = []
F = []
for line in open(src, encoding='utf-8'):
    p = line.rstrip('\n').split('\t')
    if p[0] == 'T': T.append(p[1:])
    elif p[0] == 'C': C[(p[1], p[2])].append(p[3:])
    elif p[0] == 'K': K[(p[1], p[2])].append(p[3:])
    elif p[0] == 'I': I[(p[1], p[2])].append(p[3:])
    elif p[0] == 'V': V.append(p[1:])
    elif p[0] == 'F': F.append(p[1:])

kind = {'p': 'PK', 'u': 'UNIQUE', 'f': 'FK', 'c': 'CHECK', 'x': 'EXCLUDE', 't': 'CONSTRAINT TRIGGER'}
ORDER = 'pufcxt'


def kind_rank(ct):
    return ORDER.index(ct) if ct in ORDER else len(ORDER)


def esc(s):
    return s.replace('|', '\\|')


# Keep this list, and the ARRAY[...] lists in gen_data_dictionary.sql, in sync
# with the schemas created in sql/00_bootstrap.sql.
schemas = ['ref', 'org', 'people', 'academic', 'exam', 'research', 'facility', 'tms', 'events', 'pii', 'iam', 'authz', 'wf', 'privacy', 'audit']
desc = {'ref': 'Lookups', 'org': 'Organisation', 'people': 'People',
        'academic': 'Academic structure, curriculum, timetable & attendance', 'exam': 'Examination', 'research': 'Doctoral research: supervision, committees, thesis, viva',
        'facility': 'Resource & facility management: occupancy ledger, bookings, assets, maintenance, guest house, parking, fleet, keys',
        'events': 'Events & clubs: clubs, proposals, events, registrations, teams, gate scans, certificates, feedback, club points',
        'tms': 'Helpdesk (TMS): tickets, category tree, escalation ladder, business-hours SLA, notices',
        'pii': 'Personal data (restricted)', 'iam': 'Identity & authentication', 'authz': 'Authorisation (RBAC)', 'wf': 'Approval workflow',
        'privacy': 'DPDP privacy controls', 'audit': 'Audit trail'}
o = ['# Data dictionary\n',
     '> Generated from the live PostgreSQL catalog after running `sql/00`–`sql/12`. '
     'Do not edit by hand; regenerate with `scripts/gen_data_dictionary.{sql,py}` after schema changes.\n',
     f'**{len(T)} tables · {len(V)} views · {len(F)} functions** across {len(schemas)} schemas. '
     'The **PII** column shows the `privacy.data_element` category. Every column with a PII category is written '
     'as `[REDACTED]` in the audit trail unless its erasure action is RETAIN_LEGAL (marks, results, attendance); `(sensitive)` marks the higher-risk categories.\n',
     '## Contents\n']
for s in schemas:
    ts = [t for t in T if t[0] == s]
    o.append(f'- **{s}** — {desc[s]}: ' + ', '.join(f'[`{t[1]}`](#{s}{t[1]})' for t in ts))
o.append('')
for s in schemas:
    o.append(f'## Schema `{s}` — {desc[s]}\n')
    for sch, tbl, comment, rk in [t for t in T if t[0] == s]:
        o.append(f'<a id="{s}{tbl}"></a>\n### `{s}.{tbl}`' + (' *(partitioned by month)*' if rk == 'p' else '') + '\n')
        if comment:
            o.append(comment + '\n')
        o.append('| Column | Type | Nullable | Default | PII |')
        o.append('|---|---|---|---|---|')
        for col, typ, nn, dflt, pii in C[(s, tbl)]:
            o.append(f'| `{col}` | {esc(typ)} | {"" if nn else "yes"} | {("`" + esc(dflt) + "`") if dflt else ""} | {pii} |')
        if K[(s, tbl)] or I[(s, tbl)]:
            o.append('\n**Constraints & indexes**\n')
            for ct, name, d in sorted(K[(s, tbl)], key=lambda x: kind_rank(x[0])):
                o.append(f'- {kind.get(ct, ct)} `{name}`: `{d}`')
            for name, d in I[(s, tbl)]:
                o.append(f'- INDEX `{name}`: `{d.split(" USING ", 1)[-1]}`')
        o.append('')
o.append('## Views (derived data)\n')
o += [f'- `{s}.{v}`' for s, v in V]
o.append('\n## Functions\n')
o.append('| Function | Returns |')
o.append('|---|---|')
o += [f'| `{s}.{f}({esc(args)})` | {esc(res)} |' for s, f, args, res in F]
open(out, 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print('written', out, len(o), 'lines')
