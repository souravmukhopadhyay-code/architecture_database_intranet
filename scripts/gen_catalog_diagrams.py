"""Regenerate the diagrams of docs/table-catalog.md from the live database.

    python scripts/gen_catalog_diagrams.py            # diagrams + catalog blocks
    python scripts/gen_catalog_diagrams.py --no-render # sources and blocks only

Writes docs/catalog-diagrams/:
  er-<group>.mmd / .png   one ER diagram per functional group (scripts/catalog_groups.py),
                          columns, keys and foreign keys read from the database
  schema-map.mmd / .png   schemas and the number of foreign keys between them
and renders them to PNG. (The DFDs are docs/data-flow.md, built by docs/dfd/build_dfd.py.)
Then rewrites the blocks between <!-- group:<id> --> and <!-- /group:<id> -->
in docs/table-catalog.md (diagram, one-line summary per table, the features of
docs/data-flow-features.md that read or write each table — taken from the DFD
specs, so run docs/dfd/build_dfd.py first — and the views and functions built
over the group).

Environment: PSQL (default D:\\pgtools\\pg17\\bin\\psql.exe), PGPORT (55432),
PGDATABASE (intranet), MMDC (path to mermaid-cli's mmdc; rendering is skipped
when it is missing).
"""
import importlib.util
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from catalog_groups import GROUPS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "catalog-diagrams")
CATALOG = os.path.join(ROOT, "docs", "table-catalog.md")
PSQL = os.environ.get("PSQL", r"D:\pgtools\pg17\bin\psql.exe")
PORT = os.environ.get("PGPORT", "55432")
DB = os.environ.get("PGDATABASE", "intranet")
MMDC = os.environ.get("MMDC", "")
SCHEMAS = ["org", "people", "academic", "exam", "research", "facility", "tms", "events", "pii", "iam", "authz", "wf", "privacy", "audit"]
SKIP_COLS = {"created_at", "updated_at"}

HEADER = """---
config:
  theme: base
  themeVariables:
    primaryColor: "#eef4ff"
    primaryBorderColor: "#1d4ed8"
    primaryTextColor: "#0b1b4a"
    lineColor: "#64748b"
    fontFamily: "Segoe UI, Arial, sans-serif"
---
"""


def q(sql):
    env = dict(os.environ, PGCLIENTENCODING="UTF8")
    r = subprocess.run([PSQL, "-X", "-At", "-F", "|", "-p", PORT, "-U", "postgres", "-d", DB, "-c", sql],
                       capture_output=True, text=True, encoding="utf-8", env=env)
    if r.returncode:
        sys.exit(r.stderr)
    return [l.split("|") for l in r.stdout.splitlines() if l]


def load():
    in_list = ",".join("'%s'" % s for s in SCHEMAS)
    cols = q("""
select n.nspname||'.'||c.relname, a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull,
       exists(select 1 from pg_constraint k where k.conrelid=c.oid and k.contype='p' and a.attnum=any(k.conkey)),
       exists(select 1 from pg_constraint k where k.conrelid=c.oid and k.contype='u' and a.attnum=any(k.conkey))
from pg_class c join pg_namespace n on n.oid=c.relnamespace
join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
where c.relkind in ('r','p') and not c.relispartition and n.nspname in (%s)
order by 1, a.attnum""" % in_list)
    fks = q("""
select cn.nspname||'.'||c.relname, fn.nspname||'.'||f.relname,
       (select string_agg(a.attname, ',' order by a.attnum) from pg_attribute a where a.attrelid=c.oid and a.attnum=any(k.conkey)),
       (select bool_or(not a.attnotnull) from pg_attribute a where a.attrelid=c.oid and a.attnum=any(k.conkey)),
       exists(select 1 from pg_constraint u where u.conrelid=c.oid and u.contype in ('p','u')
              and (select array_agg(x order by x) from unnest(u.conkey) x) = (select array_agg(x order by x) from unnest(k.conkey) x))
from pg_constraint k
join pg_class c on c.oid=k.conrelid join pg_namespace cn on cn.oid=c.relnamespace
join pg_class f on f.oid=k.confrelid join pg_namespace fn on fn.oid=f.relnamespace
where k.contype='f' and not c.relispartition and cn.nspname in (%s)
order by 1, 3""" % in_list)
    tables = {}
    for t, col, typ, nn, pk, uk in cols:
        tables.setdefault(t, []).append(dict(name=col, type=typ, notnull=nn == "t", pk=pk == "t", uk=uk == "t"))
    fk_list = [dict(src=s, dst=d, cols=c.split(","), nullable=n == "t", one=o == "t") for s, d, c, n, o in fks]
    return tables, fk_list


def load_flows():
    """schema.table -> [(feature id, title, R / W / RW)] from the DFD specs (docs/dfd/build_dfd.py)."""
    path = os.path.join(ROOT, "docs", "dfd", "build_dfd.py")
    spec = importlib.util.spec_from_file_location("build_dfd", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["build_dfd"] = mod
    spec.loader.exec_module(mod)
    return mod


def features_block(dfd):
    """Level 3 index for the catalog: every feature, by area, with the catalog groups it reads or writes."""
    group_of, title_of = {}, {}
    for schema, gid, title, _intro, names in GROUPS:
        title_of[gid] = title
        for n in names:
            group_of[schema + "." + n] = gid
    per_feature = {}
    for t, uses in dfd.table_features().items():
        for p, _title, mode in uses:
            per_feature.setdefault(p, {}).setdefault(group_of[t], set()).add(mode)
    parent = {p: d.name for _fd, d, p in dfd.FEATURES}
    lines = ["Every step of every Level-2 diagram has its own feature diagram (Level 3) in "
             "[`data-flow-features.md`](data-flow-features.md): **%d features**. The table lists them by area with the "
             "groups of this catalog whose tables each one reads (R) or writes (W) — at data-store level, as drawn." % len(dfd.FEATURES), ""]
    for aid, head, names in dfd.AREAS:
        lines += ["**%s**" % head, "", "| Feature | Catalog groups it reads / writes |", "|---|---|"]
        for _fd, d, p in dfd.FEATURES:
            if d.name not in names:
                continue
            title = dfd.plain(_fd.proc[p].split("<br/>")[0])
            groups = per_feature.get(p, {})
            cell = " · ".join("[%s](#g-%s) %s" % (title_of[g], g, "RW" if "RW" in m or {"R", "W"} <= m else "".join(sorted(m)))
                              for g, m in sorted(groups.items(), key=lambda x: [g for _s, g, *_r in GROUPS].index(x[0])))
            lines.append("| [%s · %s](data-flow-features.md#f-%s) | %s |" % (p, title, p.replace(".", "-"), cell or "other schemas only (shown on its diagram)"))
        lines.append("")
    return "\n".join(lines).rstrip()


def load_derived():
    """schema.table -> views over it; schema.table -> (non-trigger) functions whose body names it."""
    in_list = ",".join("'%s'" % s for s in SCHEMAS)
    views = q(r"""
select distinct tn.nspname||'.'||t.relname, vn.nspname||'.'||v.relname
from pg_depend d join pg_rewrite r on r.oid = d.objid
join pg_class v on v.oid = r.ev_class join pg_namespace vn on vn.oid = v.relnamespace
join pg_class t on t.oid = d.refobjid join pg_namespace tn on tn.oid = t.relnamespace
where d.classid = 'pg_rewrite'::regclass and d.refclassid = 'pg_class'::regclass and v.oid <> t.oid
  and v.relkind in ('v','m') and t.relkind in ('r','p') and tn.nspname in (%s)""" % in_list)
    funcs = q(r"""
select distinct tn.nspname||'.'||t.relname, n.nspname||'.'||p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
join pg_class t on t.relkind in ('r','p') and not t.relispartition
join pg_namespace tn on tn.oid = t.relnamespace and tn.nspname in (%s)
where p.prokind = 'f' and p.prorettype <> 'trigger'::regtype and n.nspname in (%s, 'ref', 'util')
  and p.prosrc ~ ('\m' || tn.nspname || '\.' || t.relname || '\M')""" % (in_list, in_list))
    v, f = {}, {}
    for t, x in views:
        v.setdefault(t, set()).add(x)
    for t, x in funcs:
        f.setdefault(t, set()).add(x)
    return v, f


def short_type(t):
    base = t.split("(")[0].strip()
    arr = base.endswith("[]")
    base = base.rstrip("[]")
    m = {"uuid": "uuid", "smallint": "int", "integer": "int", "bigint": "bigint", "numeric": "numeric",
         "text": "text", "citext": "text", "character varying": "text", "character": "char", "boolean": "bool",
         "date": "date", "timestamp with time zone": "timestamp", "timestamp without time zone": "timestamp",
         "time without time zone": "time", "daterange": "daterange", "tstzrange": "tsrange", "int4range": "intrange",
         "jsonb": "jsonb", "json": "json", "bytea": "bytes", "inet": "inet", "interval": "interval"}
    s = m.get(base, re.sub(r"\W+", "_", base))
    return s + "_list" if arr else s


def alias(t):
    return "t_" + t.split(".", 1)[1]


def rel_name(target, own_schema):
    s, n = target.split(".", 1)
    return n if s == own_schema else target


def check_groups(tables):
    seen = {}
    for schema, gid, _title, _intro, names in GROUPS:
        for n in names:
            full = schema + "." + n
            if full not in tables:
                sys.exit("catalog_groups: %s is not a table" % full)
            if full in seen:
                sys.exit("catalog_groups: %s in %s and %s" % (full, seen[full], gid))
            seen[full] = gid
    missing = sorted(t for t in tables if t not in seen)
    if missing:
        sys.exit("catalog_groups: tables without a group: %s" % ", ".join(missing))
    return seen


def er_source(schema, names, tables, fks):
    members = {schema + "." + n for n in names}
    fk_by_col = {}
    for f in fks:
        if f["src"] in members:
            for c in f["cols"]:
                fk_by_col.setdefault((f["src"], c), []).append(f["dst"])
    inner = [f for f in fks if f["src"] in members and f["dst"] in members]
    indeg = {}
    for f in inner:
        if f["src"] != f["dst"]:
            indeg[f["dst"]] = indeg.get(f["dst"], 0) + 1
    direction = "LR" if len(members) <= 5 else "TB"
    out = [HEADER, "erDiagram", "  direction " + direction]
    for n in names:
        t = schema + "." + n
        cls = ":::hub" if indeg.get(t, 0) >= 3 else ""
        out.append('  %s["%s"]%s {' % (alias(t), t, cls))
        for c in tables[t]:
            if c["name"] in SKIP_COLS:
                continue
            keys = []
            if c["pk"]:
                keys.append("PK")
            targets = fk_by_col.get((t, c["name"]), [])
            if targets:
                keys.append("FK")
            if c["uk"] and not c["pk"]:
                keys.append("UK")
            line = "    %s %s" % (short_type(c["type"]), c["name"])
            if keys:
                line += " " + ", ".join(keys)
            notes = [("→ " + rel_name(d, schema)) for d in dict.fromkeys(targets) if d not in members]
            if not c["notnull"] and not c["pk"]:
                notes.append("optional")
            if notes:
                line += ' "%s"' % "; ".join(notes)
            out.append(line)
        out.append("  }")
    for f in inner:
        left = "|o" if f["nullable"] else "||"
        right = "o|" if f["one"] else "o{"
        out.append('  %s %s--%s %s : "%s"' % (alias(f["dst"]), left, right, alias(f["src"]), ", ".join(f["cols"])))
    out.append("  classDef hub fill:#fff6d6,stroke:#a16207,stroke-width:2px")
    return "\n".join(out) + "\n"


def schema_map(tables, fks):
    counts = {}
    for s in SCHEMAS + ["ref"]:
        counts[s] = sum(1 for t in tables if t.startswith(s + ".")) if s != "ref" else None
    edges = {}
    ref_in = {}
    for f in fks:
        a, b = f["src"].split(".")[0], f["dst"].split(".")[0]
        if b == "ref":
            ref_in[a] = ref_in.get(a, 0) + 1
        elif a != b:
            edges[(a, b)] = edges.get((a, b), 0) + 1
    label = {"org": "organisation", "people": "persons & roles", "academic": "programmes → attendance",
             "exam": "examination & results", "research": "research degrees", "facility": "rooms, bookings, assets, fleet", "tms": "helpdesk tickets & SLA", "events": "clubs, events, registrations", "pii": "restricted personal data",
             "iam": "accounts & sessions", "authz": "roles & permissions", "wf": "approval workflow",
             "privacy": "DPDP controls", "audit": "change trail"}
    out = [HEADER, "flowchart LR"]
    for s in SCHEMAS:
        out.append('  %s["<b>%s</b><br/>%s<br/>%d tables"]:::%s' % (
            s, s, label[s], counts[s], "core" if s in ("org", "people") else ("sec" if s in ("pii", "iam", "privacy", "audit") else "dom")))
    for (a, b), n in sorted(edges.items(), key=lambda x: -x[1]):
        out.append('  %s -->|"%d FK"| %s' % (a, n, b))
    out.append("  classDef core fill:#fff6d6,stroke:#a16207,stroke-width:2px,color:#3b2a00")
    out.append("  classDef dom fill:#eef4ff,stroke:#1d4ed8,stroke-width:1.5px,color:#0b1b4a")
    out.append("  classDef sec fill:#fdecec,stroke:#b91c1c,stroke-width:1.5px,color:#450a0a")
    return "\n".join(out) + "\n", sum(ref_in.values())


def render(path):
    if not MMDC or not os.path.exists(MMDC):
        return False
    png = path[:-4] + ".png"
    r = subprocess.run([MMDC, "-i", path, "-o", png, "-b", "white", "-s", "2", "--size", "2000", "-q"], capture_output=True, text=True,
                       shell=MMDC.lower().endswith(".cmd"))
    if r.returncode:
        sys.exit("mmdc failed for %s:\n%s" % (path, r.stderr[-1500:]))
    return True


def first_sentence(card):
    m = re.search(r"\*\*Why it exists:\*\*\s*(.+)", card)
    if not m:
        return ""
    text = m.group(1).strip()
    s = re.split(r"(?<!e\.g)(?<!i\.e)(?<!etc)(?<!vs)\.\s+(?=[A-Z`(*])", text, maxsplit=1)[0].rstrip(". ")
    if len(s) > 170:
        # prefer a natural break (dash, colon, semicolon) between 50 and 170 characters, outside ( ) and ` `
        best = None
        for mm in re.finditer(r"\s+—\s+|:\s+|;\s+", s):
            head = s[:mm.start()]
            if 50 <= len(head) <= 170 and head.count("(") == head.count(")") and head.count("`") % 2 == 0:
                best = head
        if best is None:
            head = s[:170].rsplit(" ", 1)[0]
            if head.count("(") > head.count(")"):
                head = head[:head.rfind("(")].rstrip()
            if head.count("`") % 2:
                head = head[:head.rfind("`")].rstrip()
            best = head.rstrip(",;:— ") + " …"
        s = best
    return s[0].upper() + s[1:] if s else s


def group_block(schema, gid, names, tables, fks, doc, flows, views, funcs):
    members = {schema + "." + n for n in names}
    lines = ["![ER diagram — %s](catalog-diagrams/er-%s.png)" % (gid, gid), "",
             "<sub>Every column of every table in this group, from the live schema (`created_at` / `updated_at` omitted). "
             "Lines are foreign keys inside the group; a note `→ table` is a foreign key to another group; amber = the group's hub. "
             "Source: [`catalog-diagrams/er-%s.mmd`](catalog-diagrams/er-%s.mmd).</sub>" % (gid, gid), "",
             "| Table | What it holds | Links outside this group | Data flow — features that read (R) / write (W) its data store |",
             "|---|---|---|---|"]
    for n in names:
        t = schema + "." + n
        m = re.search(r"^#{3,4} `%s`\n(.*?)(?=^#|\Z)" % re.escape(t), doc, re.S | re.M)
        summary = first_sentence(m.group(1)) if m else ""
        outs = sorted({f["dst"] for f in fks if f["src"] == t and f["dst"] not in members and not f["dst"].startswith("ref.")})
        nref = len({f["dst"] for f in fks if f["src"] == t and f["dst"].startswith("ref.")})
        link = ", ".join("`%s`" % rel_name(o, schema) for o in outs)
        if nref:
            link += ("; " if link else "") + "%d lookup%s" % (nref, "" if nref == 1 else "s")
        feats = " · ".join("[%s](data-flow-features.md#f-%s) %s" % (p, p.replace(".", "-"), mode)
                           for p, _title, mode in sorted(flows.get(t, []), key=lambda x: [int(y) for y in x[0].split(".")]))
        if not feats:
            sys.exit("%s: no feature in docs/dfd/build_dfd.py reads or writes it" % t)
        lines.append("| [`%s`](#t-%s) | %s | %s | %s |" % (n, t.replace(".", "-").replace("_", "-"), summary.replace("|", "\\|"),
                                                       link or "—", feats))
    gv = sorted({x for t in members for x in views.get(t, ())})
    gf = sorted({x for t in members for x in funcs.get(t, ())})
    lines += ["",
              "**Views over this group** (derived, never stored): " + (" · ".join("`%s`" % x for x in gv) or "none") + "  ",
              "**Functions that read or write it:** " + (" · ".join("`%s()`" % x for x in gf) or "none — only its constraints and triggers")]
    return "\n".join(lines)


def main():
    render_on = "--no-render" not in sys.argv
    os.makedirs(OUT, exist_ok=True)
    tables, fks = load()
    check_groups(tables)
    written = []
    for schema, gid, _title, _intro, names in GROUPS:
        p = os.path.join(OUT, "er-%s.mmd" % gid)
        open(p, "w", encoding="utf-8").write(er_source(schema, names, tables, fks))
        written.append(p)
    src, nref = schema_map(tables, fks)
    p = os.path.join(OUT, "schema-map.mmd")
    open(p, "w", encoding="utf-8").write(src)
    written.append(p)
    if render_on:
        for p in written:
            render(p)
            print("rendered", os.path.basename(p))
    doc = open(CATALOG, encoding="utf-8").read()
    dfd = load_flows()
    flows = dfd.table_features()
    views, funcs = load_derived()
    changed = 0
    pat = re.compile(r"(<!-- features -->\n).*?(<!-- /features -->)", re.S)
    if pat.search(doc):
        block = features_block(dfd)
        doc = pat.sub(lambda m: m.group(1) + block + "\n" + m.group(2), doc)
        changed += 1
    for schema, gid, _title, _intro, names in GROUPS:
        pat = re.compile(r"(<!-- group:%s -->\n).*?(<!-- /group:%s -->)" % (gid, gid), re.S)
        if pat.search(doc):
            block = group_block(schema, gid, names, tables, fks, doc, flows, views, funcs)
            doc = pat.sub(lambda m: m.group(1) + block + "\n" + m.group(2), doc)
            changed += 1
    open(CATALOG, "w", encoding="utf-8").write(doc)
    print("%d tables, %d foreign keys (%d to ref lookups); %d catalog blocks refreshed" % (len(tables), len(fks), nref, changed))


if __name__ == "__main__":
    main()
