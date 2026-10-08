-- =============================================================================
-- 02_org.sql — Organisation structure (schema: org)
--
-- One generic, self-referencing tree of organisational units replaces the
-- old separate FacultySchoolList / Department / CentralDepartment tables:
--
--   UNIVERSITY
--   ├── SCHOOL (faculty)  ── DEPARTMENT ── (any deeper academic unit)
--   └── CENTRAL_DEPARTMENT (HR, Finance, DRD, IT ...) ── SECTION / CELL
--
-- Which unit type may sit under which is data (org_unit_type_rule), enforced
-- by trigger together with cycle prevention. Ancestors/descendants are derived
-- with recursive CTEs (see 09_views_functions.sql) — no stored paths/closure.
--
-- org.appointment (who HEADS a unit) is created in 03_people.sql because it
-- references people.employee.
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = org, ref, public;

-- ------------------------------------------------------------------ org_unit --
CREATE TABLE org.org_unit (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_type_id smallint NOT NULL REFERENCES ref.org_unit_type(id),
  parent_id        uuid REFERENCES org.org_unit(id) ON DELETE RESTRICT,
  code             citext NOT NULL UNIQUE CHECK (code ~ '^[A-Za-z0-9_-]{2,32}$'),
  name             text   NOT NULL CHECK (btrim(name) <> ''),
  short_name       citext,
  description      text,
  established_on   date,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT org_unit_not_own_parent CHECK (parent_id IS DISTINCT FROM id),
  -- sibling names/short names are unique within the same parent
  CONSTRAINT org_unit_name_uq_per_parent UNIQUE NULLS NOT DISTINCT (parent_id, name),
  CONSTRAINT org_unit_short_name_uq      UNIQUE (short_name)
);
CREATE INDEX org_unit_parent_idx ON org.org_unit(parent_id);
CREATE INDEX org_unit_type_idx   ON org.org_unit(org_unit_type_id);
-- exactly one root (the university)
CREATE UNIQUE INDEX org_unit_single_root_uq ON org.org_unit ((true)) WHERE parent_id IS NULL;
SELECT util.attach_updated_at('org.org_unit');

-- ------------------------------------------------------- org_unit_type_rule --
-- Allowed parent → child type combinations.
CREATE TABLE org.org_unit_type_rule (
  parent_type_id smallint NOT NULL REFERENCES ref.org_unit_type(id),
  child_type_id  smallint NOT NULL REFERENCES ref.org_unit_type(id),
  PRIMARY KEY (parent_type_id, child_type_id)
);

-- Trigger: validate parent type rule and prevent cycles.
CREATE OR REPLACE FUNCTION org.org_unit_validate_tree()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_parent_type smallint;
  v_cycle boolean;
BEGIN
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT org_unit_type_id INTO v_parent_type FROM org.org_unit WHERE id = NEW.parent_id;

  IF NOT EXISTS (SELECT 1 FROM org.org_unit_type_rule
                 WHERE parent_type_id = v_parent_type AND child_type_id = NEW.org_unit_type_id) THEN
    RAISE EXCEPTION 'org_unit %: type % is not allowed under parent type %',
      NEW.code, NEW.org_unit_type_id, v_parent_type
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    WITH RECURSIVE up AS (
      SELECT id, parent_id FROM org.org_unit WHERE id = NEW.parent_id
      UNION ALL
      SELECT u.id, u.parent_id FROM org.org_unit u JOIN up ON u.id = up.parent_id
    ) CYCLE id SET is_cycle USING path
    SELECT EXISTS (SELECT 1 FROM up WHERE id = NEW.id) INTO v_cycle;
    IF v_cycle THEN
      RAISE EXCEPTION 'org_unit %: moving under % would create a cycle', NEW.code, NEW.parent_id
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_org_unit_validate_tree
  BEFORE INSERT OR UPDATE OF parent_id, org_unit_type_id ON org.org_unit
  FOR EACH ROW EXECUTE FUNCTION org.org_unit_validate_tree();

-- ---------------------------------------------------------- org_unit_contact --
-- Official contact points of a unit (office email, phone, website).
CREATE TABLE org.org_unit_contact (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id        uuid NOT NULL REFERENCES org.org_unit(id) ON DELETE CASCADE,
  contact_channel_id smallint NOT NULL REFERENCES ref.contact_channel(id),
  value              citext NOT NULL CHECK (btrim(value) <> ''),
  is_primary         boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_unit_id, contact_channel_id, value)
);
CREATE UNIQUE INDEX org_unit_contact_one_primary_uq
  ON org.org_unit_contact(org_unit_id, contact_channel_id) WHERE is_primary;
SELECT util.attach_updated_at('org.org_unit_contact');

-- ---------------------------------------------------- campus / building ------
-- Physical locations shared by all modules (club "blocks", seminar halls ...).
CREATE TABLE org.campus (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        citext NOT NULL UNIQUE,
  name        text   NOT NULL UNIQUE,
  city_id     int REFERENCES ref.city(id),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('org.campus');

CREATE TABLE org.building (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campus_id         uuid NOT NULL REFERENCES org.campus(id),
  code              citext NOT NULL,                 -- e.g. 'A' for "Block A"
  name              text   NOT NULL,
  building_kind_id  smallint NOT NULL REFERENCES ref.building_kind(id),   -- BUILDING, or an OPEN_AREA (grounds, courts) / PARKING lot whose "rooms" are its zones
  is_active         boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campus_id, code),
  UNIQUE (campus_id, name)
);
SELECT util.attach_updated_at('org.building');

-- Floors of a building (level 0 = ground; negative = basement).
CREATE TABLE org.floor (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  building_id  uuid NOT NULL REFERENCES org.building(id) ON DELETE CASCADE,
  code         citext NOT NULL,                  -- 'G', '1', 'B1'
  name         text   NOT NULL,
  level        smallint NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (building_id, code),
  UNIQUE (building_id, level)
);
SELECT util.attach_updated_at('org.floor');

-- Rooms inside a building: classrooms, labs, seminar/exam halls. Shared by the
-- academic timetable, exam seating and (later) Resource Management bookings.
CREATE TABLE org.room (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  building_id   uuid NOT NULL REFERENCES org.building(id),
  floor_id      uuid REFERENCES org.floor(id),                    -- NULL = single-level structure / open area
  code          citext NOT NULL,                 -- e.g. 'A-204'
  name          text,
  room_type_id  smallint NOT NULL REFERENCES ref.room_type(id),
  room_use_id   smallint REFERENCES ref.room_use(id),             -- FICM-style use classification (space inventory); NULL = unclassified
  capacity      smallint NOT NULL CHECK (capacity > 0),          -- teaching seats (parking zone: bays; guest room: beds)
  chairs        smallint CHECK (chairs >= 0),                    -- loose seating, if different from capacity
  exam_capacity smallint CHECK (exam_capacity > 0),             -- seats with exam spacing; NULL = not an exam venue
  area_sqm      numeric(8,2) CHECK (area_sqm > 0),
  is_accessible boolean NOT NULL DEFAULT false,                  -- step-free / wheelchair accessible
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (building_id, code)
);
SELECT util.attach_updated_at('org.room');

-- A room's floor must be a floor of its own building.
CREATE OR REPLACE FUNCTION org.room_floor_check()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.floor_id IS NOT NULL AND (SELECT building_id FROM org.floor WHERE id = NEW.floor_id) <> NEW.building_id THEN
    RAISE EXCEPTION 'room %: the floor belongs to another building', NEW.code USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_floor_check BEFORE INSERT OR UPDATE OF floor_id, building_id ON org.room
  FOR EACH ROW EXECUTE FUNCTION org.room_floor_check();

-- Where a unit's office is (a unit can have offices in several buildings).
CREATE TABLE org.org_unit_location (
  org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id) ON DELETE CASCADE,
  building_id  uuid NOT NULL REFERENCES org.building(id),
  office_room  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (org_unit_id, building_id)
);
SELECT util.attach_updated_at('org.org_unit_location');

-- ------------------------------------------------------------ position_type --
-- Single-holder leadership positions of a unit (HEAD, DEAN, VC, REGISTRAR,
-- DPO, GRIEVANCE_OFFICER ...). Multi-holder responsibilities are ROLES (authz).
CREATE TABLE org.position_type (
  id          smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  code        citext NOT NULL UNIQUE,
  label       text   NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  smallint NOT NULL DEFAULT 0
);

-- Which unit types may carry which positions (e.g. DEAN → SCHOOL).
CREATE TABLE org.position_type_unit_type (
  position_type_id smallint NOT NULL REFERENCES org.position_type(id),
  org_unit_type_id smallint NOT NULL REFERENCES ref.org_unit_type(id),
  PRIMARY KEY (position_type_id, org_unit_type_id)
);
