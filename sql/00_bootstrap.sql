-- =============================================================================
-- 00_bootstrap.sql
-- Extensions, schemas, group roles, shared utility functions.
-- Target: PostgreSQL 16+ (uuidv7() may replace gen_random_uuid() on PG 18).
-- Run as a superuser / database owner:  psql -v ON_ERROR_STOP=1 -f 00_bootstrap.sql
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

CREATE EXTENSION IF NOT EXISTS citext;      -- case-insensitive text (usernames, emails, codes)
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- gen_random_uuid(), digest(), hmac()
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- EXCLUDE constraints mixing "=" and range "&&"

-- -----------------------------------------------------------------------------
-- Schemas = security boundaries. Table names are unique across ALL schemas so
-- that Django (search_path + plain db_table) never sees a collision.
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS util;     -- generic helper functions
CREATE SCHEMA IF NOT EXISTS ref;      -- lookup / reference data
CREATE SCHEMA IF NOT EXISTS org;      -- organisation structure
CREATE SCHEMA IF NOT EXISTS people;   -- persons, employees, students (non-sensitive)
CREATE SCHEMA IF NOT EXISTS pii;      -- personal data (restricted)
CREATE SCHEMA IF NOT EXISTS academic; -- programmes, curriculum, sections, timetable, attendance
CREATE SCHEMA IF NOT EXISTS exam;     -- exam registration, planning, conduct, evaluation, results
CREATE SCHEMA IF NOT EXISTS research; -- doctoral / research degrees: supervision, committees, thesis, viva
CREATE SCHEMA IF NOT EXISTS iam;      -- accounts, credentials, MFA, sessions
CREATE SCHEMA IF NOT EXISTS authz;    -- RBAC catalogue, roles, grants
CREATE SCHEMA IF NOT EXISTS wf;       -- generic approval workflow (chains, steps, actions, comments)
CREATE SCHEMA IF NOT EXISTS facility; -- resource & facility management: occupancy ledger, bookings, assets, maintenance, guest house, fleet, keys
CREATE SCHEMA IF NOT EXISTS privacy;  -- DPDP Act 2023 controls
CREATE SCHEMA IF NOT EXISTS audit;    -- append-only audit trail

-- -----------------------------------------------------------------------------
-- Group roles (NOLOGIN). Real login users are granted membership in these.
--   intranet_owner     : owns objects, runs migrations (Django migrate user)
--   intranet_app       : Django runtime (DML; audit is insert-only)
--   intranet_analytics : read-only reporting, NO access to pii / iam secrets
--   intranet_dpo       : Data Protection Officer tooling (privacy + pii read)
-- -----------------------------------------------------------------------------
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['intranet_owner','intranet_app','intranet_analytics','intranet_dpo'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- util.set_updated_at(): BEFORE UPDATE trigger keeping updated_at current.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION util.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- util.attach_updated_at(regclass): convenience to attach the trigger.
CREATE OR REPLACE FUNCTION util.attach_updated_at(p_table regclass)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format(
    'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %s
       FOR EACH ROW EXECUTE FUNCTION util.set_updated_at()', p_table);
END $$;

-- util.create_monthly_partitions(parent, from_month, months): creates range
-- partitions [month, month+1) for partitioned log tables.
CREATE OR REPLACE FUNCTION util.create_monthly_partitions(
  p_parent regclass, p_from date, p_months int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  i int;
  m_start date;
  m_end date;
  part_name text;
  parent_schema text;
  parent_table text;
BEGIN
  SELECT n.nspname, c.relname INTO parent_schema, parent_table
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.oid = p_parent;

  FOR i IN 0 .. p_months - 1 LOOP
    m_start := (date_trunc('month', p_from) + make_interval(months => i))::date;
    m_end   := (m_start + interval '1 month')::date;
    part_name := format('%s_%s', parent_table, to_char(m_start, 'YYYYMM'));
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)',
      parent_schema, part_name, p_parent, m_start, m_end);
  END LOOP;
END $$;
