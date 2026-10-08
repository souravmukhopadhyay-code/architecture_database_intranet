-- =============================================================================
-- 08_audit.sql — Append-only, column-level audit trail (schema: audit)
--
-- audit_event  : one row per changed row (who / when / what entity / request)
-- audit_change : one row per changed column (4NF — no JSON diff blobs)
--
-- Context is passed from Django per transaction:
--   SET LOCAL app.account_id = '<uuid>';  SET LOCAL app.request_id = '<uuid>';
--   SET LOCAL app.session_id = '<uuid>';  SET LOCAL app.client_ip  = '1.2.3.4';
--
-- DPDP: values of erasable personal-data columns (privacy.data_element with an
-- erasure action other than RETAIN_LEGAL — names, contacts, credentials…) are
-- written as '[REDACTED]': the audit proves THAT they changed without becoming
-- a second copy that erasure cannot reach. Legally-retained values (marks,
-- results, enrollment numbers) are kept, because tamper-evidence is their point.
-- Retention = DROP old monthly partitions (UPDATE/DELETE are blocked).
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = audit, privacy, ref, public;

CREATE TABLE audit.audit_event (
  id                bigint GENERATED ALWAYS AS IDENTITY,
  occurred_at       timestamptz NOT NULL DEFAULT now(),
  actor_account_id  uuid,                 -- no FK: audit must outlive accounts
  audit_action_id   smallint NOT NULL REFERENCES ref.audit_action(id),
  entity_schema     name NOT NULL,
  entity_table      name NOT NULL,
  entity_id         text NOT NULL,        -- primary key value(s), '|' separated if composite
  request_id        uuid,
  session_id        uuid,
  client_ip         inet,
  txid              bigint NOT NULL DEFAULT txid_current(),
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE INDEX audit_event_entity_idx ON audit.audit_event(entity_schema, entity_table, entity_id, occurred_at DESC);
CREATE INDEX audit_event_actor_idx  ON audit.audit_event(actor_account_id, occurred_at DESC);
CREATE TABLE audit.audit_event_default PARTITION OF audit.audit_event DEFAULT;
SELECT util.create_monthly_partitions('audit.audit_event', current_date, 13);

CREATE TABLE audit.audit_change (
  audit_event_id  bigint NOT NULL,
  occurred_at     timestamptz NOT NULL,
  column_name     name NOT NULL,
  old_value       text,
  new_value       text,
  PRIMARY KEY (audit_event_id, occurred_at, column_name),
  FOREIGN KEY (audit_event_id, occurred_at) REFERENCES audit.audit_event(id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE TABLE audit.audit_change_default PARTITION OF audit.audit_change DEFAULT;
SELECT util.create_monthly_partitions('audit.audit_change', current_date, 13);

-- ------------------------------------------------------------ capture trigger --
CREATE OR REPLACE FUNCTION audit.capture()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
  v_old        jsonb := CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END;
  v_new        jsonb := CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END;
  v_row        jsonb := COALESCE(v_new, v_old);
  v_pk_cols    text[];
  v_entity_id  text;
  v_event_id   bigint;
  v_at         timestamptz := now();
  v_col        text;
  v_o          text;
  v_n          text;
  v_redacted   text[];
BEGIN
  SELECT array_agg(a.attname::text ORDER BY k.ord)
    INTO v_pk_cols
  FROM pg_index i
  CROSS JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS k(attnum, ord)
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum
  WHERE i.indrelid = TG_RELID AND i.indisprimary;

  SELECT string_agg(v_row ->> c, '|') INTO v_entity_id FROM unnest(v_pk_cols) AS c;

  -- Redact personal data that can be erased (DELETE / ANONYMISE). Values the
  -- university must retain by law anyway (RETAIN_LEGAL — marks, results,
  -- enrollment numbers) stay visible: for those, "who changed 40 to 70" is the
  -- whole point of the audit, and keeping them does not defeat erasure.
  SELECT array_agg(de.column_name::text) INTO v_redacted
  FROM privacy.data_element de
  JOIN ref.erasure_action ea ON ea.id = de.erasure_action_id
  WHERE de.schema_name = TG_TABLE_SCHEMA AND de.table_name = TG_TABLE_NAME
    AND ea.code <> 'RETAIN_LEGAL';

  INSERT INTO audit.audit_event (occurred_at, actor_account_id, audit_action_id,
                                 entity_schema, entity_table, entity_id,
                                 request_id, session_id, client_ip)
  VALUES (v_at,
          NULLIF(current_setting('app.account_id', true), '')::uuid,
          (SELECT id FROM ref.audit_action WHERE code = TG_OP),
          TG_TABLE_SCHEMA, TG_TABLE_NAME, COALESCE(v_entity_id, '?'),
          NULLIF(current_setting('app.request_id', true), '')::uuid,
          NULLIF(current_setting('app.session_id', true), '')::uuid,
          NULLIF(current_setting('app.client_ip', true), '')::inet)
  RETURNING id INTO v_event_id;

  FOR v_col IN SELECT jsonb_object_keys(v_row) LOOP
    CONTINUE WHEN v_col IN ('created_at', 'updated_at');
    v_o := v_old ->> v_col;
    v_n := v_new ->> v_col;
    CONTINUE WHEN TG_OP = 'UPDATE' AND v_o IS NOT DISTINCT FROM v_n;
    CONTINUE WHEN v_o IS NULL AND v_n IS NULL;
    IF v_col = ANY (COALESCE(v_redacted, '{}')) THEN
      v_o := CASE WHEN v_o IS NOT NULL THEN '[REDACTED]' END;
      v_n := CASE WHEN v_n IS NOT NULL THEN '[REDACTED]' END;
    END IF;
    INSERT INTO audit.audit_change (audit_event_id, occurred_at, column_name, old_value, new_value)
    VALUES (v_event_id, v_at, v_col, v_o, v_n);
  END LOOP;

  RETURN NULL;  -- AFTER trigger
END $$;

-- ---------------------------------------------------------- append-only guard --
CREATE OR REPLACE FUNCTION audit.block_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit tables are append-only (% on %.% refused)', TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME
    USING ERRCODE = 'insufficient_privilege';
END $$;

CREATE TRIGGER trg_audit_event_append_only BEFORE UPDATE OR DELETE ON audit.audit_event
  FOR EACH ROW EXECUTE FUNCTION audit.block_mutation();
CREATE TRIGGER trg_audit_change_append_only BEFORE UPDATE OR DELETE ON audit.audit_change
  FOR EACH ROW EXECUTE FUNCTION audit.block_mutation();

-- ------------------------------------------------------- attach to all tables --
-- Every base/partitioned table in the audited schemas, except high-volume logs
-- that are themselves audit trails.
CREATE OR REPLACE FUNCTION audit.enable_for_schemas(p_schemas text[], p_exclude text[])
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
  r record;
  n int := 0;
BEGIN
  FOR r IN
    SELECT c.oid::regclass AS tbl
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = ANY (p_schemas)
      AND c.relkind IN ('r', 'p')
      AND NOT c.relispartition
      AND (ns.nspname || '.' || c.relname) <> ALL (p_exclude)
      AND NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = c.oid AND t.tgname = 'trg_audit_capture')
  LOOP
    EXECUTE format('CREATE TRIGGER trg_audit_capture AFTER INSERT OR UPDATE OR DELETE ON %s
                      FOR EACH ROW EXECUTE FUNCTION audit.capture()', r.tbl);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

SELECT audit.enable_for_schemas(
  ARRAY['ref','org','people','academic','exam','research','facility','pii','iam','authz','wf','privacy'],
  ARRAY['iam.auth_event', 'iam.otp_challenge', 'iam.user_session', 'iam.user_device',
        'privacy.pii_access_log', 'wf.approval_action', 'wf.approval_notice',
        'facility.room_hold', 'facility.asset_hold']);   -- holds are written by triggers from audited sources
