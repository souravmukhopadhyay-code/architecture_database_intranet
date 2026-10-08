"""Check docs/table-catalog.md against the live database.

    python scripts/check_table_catalog.py            # exit 1 on a real gap
    python scripts/check_table_catalog.py --verbose  # also list extra mentions

Fails when a table has no card (or a ref lookup no row in section 1), or when
a card's "Connects to →" / "Referenced by ←" line misses a foreign key.
Mentions that are not foreign keys (views, self references, tables named for
context) are listed only with --verbose. Same settings as gen_catalog_diagrams.py.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "docs", "table-catalog.md")
PSQL = os.environ.get("PSQL", r"D:\pgtools\pg17\bin\psql.exe")
PORT = os.environ.get("PGPORT", "55432")
DB = os.environ.get("PGDATABASE", "intranet")
SCH = ("org", "people", "academic", "exam", "research", "facility", "tms", "events", "pii", "iam", "authz", "wf", "privacy", "audit")


def q(sql):
    r = subprocess.run([PSQL, "-X", "-At", "-F", "|", "-p", PORT, "-U", "postgres", "-d", DB, "-c", sql],
                       capture_output=True, text=True, encoding="utf-8")
    if r.returncode:
        sys.exit(r.stderr)
    return [l.split("|") for l in r.stdout.splitlines() if l]


tables = [r[0] for r in q("""select n.nspname||'.'||c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where c.relkind in ('r','p') and not c.relispartition and n.nspname in ('ref',%s)""" % ",".join("'%s'" % s for s in SCH))]
fks = q("""select distinct cn.nspname||'.'||c.relname, fn.nspname||'.'||f.relname
    from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace cn on cn.oid=c.relnamespace
    join pg_class f on f.oid=k.confrelid join pg_namespace fn on fn.oid=f.relnamespace
    where k.contype='f' and not c.relispartition and not f.relispartition and cn.nspname in (%s)""" % ",".join("'%s'" % s for s in SCH))
outgoing, incoming = {}, {}
for src, dst in fks:
    if src != dst:
        outgoing.setdefault(src, set()).add(dst)
        if not dst.startswith("ref."):
            incoming.setdefault(dst, set()).add(src)

doc = open(CATALOG, encoding="utf-8").read()
cards = dict(re.findall(r"^#{3,4} `([a-z_]+\.[a-z_]+)`\n(.*?)(?=^#|\Z)", doc, re.S | re.M))
ref_sec = doc[doc.index("## 1. `ref`"):doc.index("## 2. `org`")]
ref_rows = set(re.findall(r"^\| `([a-z_]+)` \|", ref_sec, re.M))
name_re = re.compile(r"`((?:%s|ref)\.[a-z_]+)`" % "|".join(SCH))

errors, notes = [], []
for t in sorted(tables):
    if t.startswith("ref."):
        if t[4:] not in ref_rows:
            errors.append("%s: no row in section 1" % t)
        continue
    card = cards.get(t)
    if card is None:
        errors.append("%s: no card" % t)
        continue
    con = re.search(r"\*\*Connects to →\*\*(.*)", card)
    ref = re.search(r"\*\*Referenced by ←\*\*(.*)", card)
    con_set = set(name_re.findall(con.group(1))) if con else set()
    ref_set = set(name_re.findall(ref.group(1))) if ref else set()
    miss_out = {d for d in outgoing.get(t, set()) - con_set if not d.startswith("ref.")}
    miss_in = incoming.get(t, set()) - ref_set
    if miss_out:
        errors.append("%s: Connects to misses %s" % (t, ", ".join(sorted(miss_out))))
    if miss_in:
        errors.append("%s: Referenced by misses %s" % (t, ", ".join(sorted(miss_in))))
    extra = {x for x in (con_set - outgoing.get(t, set())) | (ref_set - incoming.get(t, set())) if not x.startswith("ref.")}
    if extra:
        notes.append("%s: also mentions %s" % (t, ", ".join(sorted(extra))))
for c in sorted(set(cards) - set(tables)):
    errors.append("%s: card for a table that does not exist" % c)

if "--verbose" in sys.argv:
    print("\n".join(notes))
print("\n".join(errors))
print("%d tables, %d cards, %d lookup rows; %d gap(s)" % (len(tables), len(cards), len(ref_rows), len(errors)))
sys.exit(1 if errors else 0)
