-- =============================================================================
-- gen_data_dictionary.sql — Introspects the live catalog and emits tab-separated
-- rows consumed by gen_data_dictionary.py to (re)build docs/data-dictionary.md.
--
-- Usage (after applying sql/00.. sql/11 to a database):
--   psql -d intranet -f scripts/gen_data_dictionary.sql > /tmp/dict.tsv
--   python scripts/gen_data_dictionary.py /tmp/dict.tsv docs/data-dictionary.md
--
-- Re-run this whenever a table/column/view/function is added, renamed or
-- removed in sql/*.sql. If you add a new schema, add it to every ARRAY[...]
-- below (keep the schemas in the same order everywhere).
-- =============================================================================

\pset format unaligned
\pset tuples_only on
\pset fieldsep '\t'

-- T: tables ; C: columns ; K: constraints ; I: indexes ; V: views ; F: functions
SELECT 'T', n.nspname, c.relname, coalesce(obj_description(c.oid,'pg_class'),''), c.relkind
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ref','org','people','academic','exam','research','facility','tms','events','pii','iam','authz','wf','privacy','audit') AND c.relkind IN ('r','p') AND NOT c.relispartition
ORDER BY array_position(ARRAY['ref','org','people','academic','exam','research','facility','tms','events','pii','iam','authz','wf','privacy','audit'], n.nspname::text), c.relname;

SELECT 'C', n.nspname, c.relname, a.attname, format_type(a.atttypid,a.atttypmod), CASE WHEN a.attnotnull THEN 'NOT NULL' ELSE '' END,
       coalesce(pg_get_expr(d.adbin,d.adrelid),''),
       coalesce((SELECT dc.code||CASE WHEN dc.is_sensitive THEN ' (sensitive)' ELSE '' END FROM privacy.data_element de JOIN ref.data_category dc ON dc.id=de.data_category_id
                 WHERE de.schema_name=n.nspname AND de.table_name=c.relname AND de.column_name=a.attname),'')
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
WHERE n.nspname IN ('ref','org','people','academic','exam','research','facility','tms','events','pii','iam','authz','wf','privacy','audit') AND c.relkind IN ('r','p') AND NOT c.relispartition
ORDER BY n.nspname, c.relname, a.attnum;

SELECT 'K', n.nspname, c.relname, con.contype, con.conname, replace(pg_get_constraintdef(con.oid), E'\n', ' ')
FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ref','org','people','academic','exam','research','facility','tms','events','pii','iam','authz','wf','privacy','audit') AND c.relkind IN ('r','p') AND NOT c.relispartition AND con.contype <> 'n'
ORDER BY n.nspname, c.relname, con.contype, con.conname;

SELECT 'I', n.nspname, c.relname, i.relname, replace(pg_get_indexdef(i.oid), E'\n',' ')
FROM pg_index x JOIN pg_class c ON c.oid=x.indrelid JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ref','org','people','academic','exam','research','facility','tms','events','pii','iam','authz','wf','privacy','audit') AND c.relkind IN ('r','p') AND NOT c.relispartition
  AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = i.oid)
ORDER BY 2,3,4;

SELECT 'V', n.nspname, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('org','people','academic','exam','research','facility','tms','events','pii','iam','authz','privacy') AND c.relkind='v' ORDER BY 2,3;

SELECT 'F', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('org','iam','authz','academic','exam','research','facility','tms','events','wf') AND p.prokind='f' AND pg_get_function_result(p.oid) <> 'trigger' ORDER BY 2,3;
