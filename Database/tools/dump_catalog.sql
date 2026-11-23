-- Dumps the catalog (tables, columns, constraints, indexes, functions) as one JSON document; used by tools/make_docs.py
\pset tuples_only on
\pset format unaligned
SELECT json_build_object(
  'generated_at', now(),
  'server_version', current_setting('server_version'),
  'tables', (SELECT json_agg(t ORDER BY t.schema DESC, t.kind, t.name) FROM (
     SELECT n.nspname AS schema, c.relname AS name, c.relkind AS kind, obj_description(c.oid) AS comment,
            (SELECT json_agg(json_build_object('name', a.attname, 'type', format_type(a.atttypid, a.atttypmod), 'notnull', a.attnotnull,
                    'default', pg_get_expr(d.adbin, d.adrelid), 'identity', a.attidentity, 'comment', col_description(c.oid, a.attnum)) ORDER BY a.attnum)
             FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
             WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) AS columns,
            (SELECT json_agg(json_build_object('name', conname, 'type', contype, 'def', pg_get_constraintdef(oid)) ORDER BY contype, conname)
             FROM pg_constraint WHERE conrelid = c.oid) AS constraints,
            (SELECT json_agg(indexdef ORDER BY indexname) FROM pg_indexes i WHERE i.schemaname = n.nspname AND i.tablename = c.relname) AS indexes
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname IN ('public', 'research') AND c.relkind IN ('r', 'v')) t),
  'functions', (SELECT json_agg(json_build_object('name', p.proname, 'args', pg_get_function_arguments(p.oid), 'returns', pg_get_function_result(p.oid),
                    'comment', obj_description(p.oid, 'pg_proc')) ORDER BY p.proname)
                FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public' AND (p.proname LIKE 'fn\_%' OR p.proname LIKE 'demo\_%'))
);
