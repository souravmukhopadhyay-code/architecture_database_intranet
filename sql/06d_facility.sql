-- =============================================================================
-- 06d_facility.sql — Resource & facility management (schema: facility)
--   A centralised occupancy ledger for every physical resource of the
--   university, linked to academics (timetable, exams, vivas, convocations)
--   and non-academics (events, meetings, guests, maintenance), with bookings
--   approved through the wf engine (06b), configurable priority / pre-emption,
--   assets and maintenance, guest house, parking, fleet & transport, keys.
--
--   SPACE        org.floor, org.building.building_kind, org.room extras [02];
--                room_composition (combinable halls), custody (who manages a
--                room / floor / building / campus), space_allocation (who
--                occupies it), room_reservation_rule (reserved / private
--                rooms), room_service_window, blackout
--   LEDGER       room_hold — one row per use of a room, from every source
--                (timetable materialised per term, extra classes, exams,
--                vivas, convocations, bookings, guest stays, maintenance);
--                EXCLUDE on (room, blocked range); shadow holds for composed
--                rooms; hold_priority_rule → configurable pre-emption with
--                displacement and reinstatement
--   BOOKINGS     booking_policy, booking_restriction, event_request,
--                booking_group (GRP-YYYY-NNNN, recurring, multi-room),
--                booking_request (ROOM_BOOKING / ROOM_BOOKING_CHANGE rounds at
--                the custodian), booking_occurrence, booking_requirement,
--                booking_asset
--   ASSETS       vendor, asset (fixed or portable), service_contract,
--                asset_loan, asset_hold (EXCLUDE per asset)
--   MAINTENANCE  maintenance_schedule, work_order (WO-YYYY-NNNNN) ─<
--                work_order_event (append-only → derived status, SLA)
--   GUEST HOUSE  guest_stay (GUEST_STAY round), guest_tariff → derived charge
--   PARKING      parking_permit (zone capacity enforced)
--   FLEET        vehicle, vehicle_document, vehicle_service_window, driver,
--                driver_unavailability, transport_policy, trip_request
--                (TRIP_REQUEST / TRIP_REQUEST_URGENT rounds), trip_allocation
--                (EXCLUDE per vehicle and driver), trip_allocation_request
--                (pooling), trip, trip_rating, trip_alert
--   KEYS         key_item, key_issue (one holder at a time)
--   Derived views, wrappers and grants live in 09_views_functions.sql.
--
--   Time model: every span is a tsrange in campus-local time (one campus
--   time zone), so setup / teardown buffers can be applied inside the
--   EXCLUDE expression (timestamp + interval is IMMUTABLE).
-- =============================================================================

SET client_encoding = 'UTF8';   -- files are UTF-8; psql on Windows may default to WIN1252

SET search_path = facility, org, people, academic, exam, research, wf, authz, iam, pii, ref, public;

-- ################################################################### HELPERS ##

-- The range a hold really blocks: the use itself plus its buffers.
CREATE OR REPLACE FUNCTION facility.blocked(p_during tsrange, p_setup smallint, p_teardown smallint)
RETURNS tsrange LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT tsrange(lower(p_during) - make_interval(mins => COALESCE(p_setup, 0)),
                 upper(p_during) + make_interval(mins => COALESCE(p_teardown, 0)), '[)')
$$;

-- date + clock times → tsrange (end may be 24:00).
CREATE OR REPLACE FUNCTION facility.span(p_date date, p_start time, p_end time)
RETURNS tsrange LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT tsrange(p_date + p_start, p_date + p_end, '[)')
$$;

-- A whole day.
CREATE OR REPLACE FUNCTION facility.day_span(p_date date)
RETURNS tsrange LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT tsrange(p_date::timestamp, (p_date + 1)::timestamp, '[)')
$$;

-- Nights of a stay [check-in day, check-out day) → the room is held from
-- check-in noon to check-out noon (POLICY: the standard hotel day).
CREATE OR REPLACE FUNCTION facility.night_span(p_nights daterange)
RETURNS tsrange LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT tsrange(lower(p_nights) + time '12:00', upper(p_nights) + time '12:00', '[)')
$$;

-- ##################################################################### SPACE ##

-- A combinable hall: the parent room is the whole (e.g. auditorium), the parts
-- are its halves. One level only; parts belong to the parent's building. A
-- hold on the whole shadows every part (per-room EXCLUDE); a hold on a part
-- is checked against the whole under a row lock on the whole (room_hold).
CREATE TABLE facility.room_composition (
  parent_room_id  uuid NOT NULL REFERENCES org.room(id) ON DELETE CASCADE,
  part_room_id    uuid NOT NULL REFERENCES org.room(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (parent_room_id, part_room_id),
  UNIQUE (part_room_id),                         -- a part belongs to one whole
  CHECK (parent_room_id <> part_room_id)
);

CREATE OR REPLACE FUNCTION facility.room_composition_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT building_id FROM org.room WHERE id = NEW.parent_room_id) <> (SELECT building_id FROM org.room WHERE id = NEW.part_room_id) THEN
    RAISE EXCEPTION 'room_composition: a part must be in the same building as the whole' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM facility.room_composition WHERE part_room_id = NEW.parent_room_id)
     OR EXISTS (SELECT 1 FROM facility.room_composition WHERE parent_room_id = NEW.part_room_id) THEN
    RAISE EXCEPTION 'room_composition: only one level of composition (a part cannot itself be a whole)' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_composition_validate BEFORE INSERT OR UPDATE ON facility.room_composition
  FOR EACH ROW EXECUTE FUNCTION facility.room_composition_validate();

-- Parts of a room (empty for a simple room).
CREATE OR REPLACE FUNCTION facility.room_parts(p_room uuid)
RETURNS SETOF uuid LANGUAGE sql STABLE AS $$
  SELECT part_room_id FROM facility.room_composition WHERE parent_room_id = p_room
$$;

-- Rooms whose occupancy is tied to this room: itself, its parts, its whole.
CREATE OR REPLACE FUNCTION facility.linked_rooms(p_room uuid)
RETURNS SETOF uuid LANGUAGE sql STABLE AS $$
  SELECT p_room
  UNION SELECT part_room_id FROM facility.room_composition WHERE parent_room_id = p_room
  UNION SELECT parent_room_id FROM facility.room_composition WHERE part_room_id = p_room
$$;

-- Every room under a floor or a building.
CREATE OR REPLACE FUNCTION facility.rooms_under(p_floor uuid DEFAULT NULL, p_building uuid DEFAULT NULL)
RETURNS SETOF uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM org.room
  WHERE (p_floor IS NOT NULL AND floor_id = p_floor) OR (p_building IS NOT NULL AND building_id = p_building)
$$;

-- Who manages a space: the org unit (a BLOCK, a central department, a school,
-- a department …) in custody of a room, a floor, a building or a whole campus
-- for a period. The most specific custody wins (room > floor > building >
-- campus). The custodian is the owner of every booking round for the space —
-- its head (or whoever is granted the custodian role there) approves.
CREATE TABLE facility.custody (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      uuid REFERENCES org.room(id) ON DELETE CASCADE,
  floor_id     uuid REFERENCES org.floor(id) ON DELETE CASCADE,
  building_id  uuid REFERENCES org.building(id) ON DELETE CASCADE,
  campus_id    uuid REFERENCES org.campus(id) ON DELETE CASCADE,
  org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  valid        daterange NOT NULL DEFAULT daterange(current_date, NULL),
  note         text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_id, floor_id, building_id, campus_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT custody_one_per_target EXCLUDE USING gist (
    (COALESCE(room_id, floor_id, building_id, campus_id)) WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.custody');

-- The custodian unit of a room on a date (walks room → floor → building → campus).
CREATE OR REPLACE FUNCTION facility.custodian_of(p_room uuid, p_date date DEFAULT current_date)
RETURNS uuid LANGUAGE plpgsql STABLE AS $$
DECLARE v_unit uuid; v_floor uuid; v_building uuid; v_campus uuid;
BEGIN
  SELECT r.floor_id, r.building_id, b.campus_id INTO v_floor, v_building, v_campus
  FROM org.room r JOIN org.building b ON b.id = r.building_id WHERE r.id = p_room;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'custodian_of: unknown room %', p_room USING ERRCODE = 'no_data_found';
  END IF;
  SELECT c.org_unit_id INTO v_unit
  FROM facility.custody c
  WHERE c.valid @> p_date
    AND (c.room_id = p_room OR c.floor_id = v_floor OR c.building_id = v_building OR c.campus_id = v_campus)
  ORDER BY CASE WHEN c.room_id IS NOT NULL THEN 1 WHEN c.floor_id IS NOT NULL THEN 2 WHEN c.building_id IS NOT NULL THEN 3 ELSE 4 END
  LIMIT 1;
  IF v_unit IS NULL THEN
    RAISE EXCEPTION 'custodian_of: no unit is in custody of room % on %', p_room, p_date USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_unit;
END $$;

-- Who occupies a space: a room (office, lab, department classroom) allocated
-- to an org unit for a period, possibly shared (shares of one room sum to at
-- most 100 % on any day). Basis of the space inventory (v_space_inventory).
CREATE TABLE facility.space_allocation (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      uuid NOT NULL REFERENCES org.room(id) ON DELETE CASCADE,
  org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  valid        daterange NOT NULL DEFAULT daterange(current_date, NULL),
  share_pct    numeric(5,2) NOT NULL DEFAULT 100 CHECK (share_pct > 0 AND share_pct <= 100),
  note         text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT space_allocation_no_overlap EXCLUDE USING gist (room_id WITH =, org_unit_id WITH =, valid WITH &&)
);
CREATE INDEX space_allocation_unit_idx ON facility.space_allocation(org_unit_id);
SELECT util.attach_updated_at('facility.space_allocation');

CREATE OR REPLACE FUNCTION facility.space_allocation_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_day date; v_sum numeric;
BEGIN
  -- the shares in force on any day may not exceed 100 %: check every day on
  -- which the set of overlapping allocations changes (the start of NEW and the
  -- start of every other allocation inside NEW's validity)
  FOR v_day IN
    SELECT lower(NEW.valid)
    UNION SELECT lower(a.valid) FROM facility.space_allocation a
          WHERE a.room_id = NEW.room_id AND a.id <> NEW.id AND a.valid && NEW.valid AND NEW.valid @> lower(a.valid)
  LOOP
    SELECT COALESCE(sum(share_pct), 0) INTO v_sum FROM facility.space_allocation a
    WHERE a.room_id = NEW.room_id AND a.id <> NEW.id AND a.valid @> v_day;
    IF v_sum + NEW.share_pct > 100 THEN
      RAISE EXCEPTION 'space_allocation: shares of the room would exceed 100 %% on % (% + %)', v_day, v_sum, NEW.share_pct
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_space_allocation_validate BEFORE INSERT OR UPDATE ON facility.space_allocation
  FOR EACH ROW EXECUTE FUNCTION facility.space_allocation_validate();

-- Reserved / private rooms. While at least one rule covers a room (directly,
-- or through its floor / building) on the day of use, only a requester who
-- matches one of the rules may book it: the holder of a position (the
-- Vice-Chancellor's meeting room), members of an org unit and its
-- descendants (a department's own seminar room), holders of a permission, or
-- a named person (an individual grant, as in the old per-user room access).
-- Revoke = close the validity. Rooms without a rule are open to everyone who
-- may book at all (facility.booking.create).
CREATE TABLE facility.room_reservation_rule (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id           uuid REFERENCES org.room(id) ON DELETE CASCADE,
  floor_id          uuid REFERENCES org.floor(id) ON DELETE CASCADE,
  building_id       uuid REFERENCES org.building(id) ON DELETE CASCADE,
  position_type_id  smallint REFERENCES org.position_type(id),
  org_unit_id       uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  permission_id     int REFERENCES authz.permission(id),
  person_id         uuid REFERENCES people.person(id) ON DELETE CASCADE,
  valid             daterange NOT NULL DEFAULT daterange(current_date, NULL),
  granted_by_account_id uuid REFERENCES iam.user_account(id),
  note              text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_id, floor_id, building_id) = 1),
  CHECK (num_nonnulls(position_type_id, org_unit_id, permission_id, person_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid))
);
CREATE INDEX room_reservation_rule_room_idx ON facility.room_reservation_rule(room_id);
CREATE INDEX room_reservation_rule_person_idx ON facility.room_reservation_rule(person_id);
SELECT util.attach_updated_at('facility.room_reservation_rule');

-- Is the room reserved on the date, and if so does this requester (person,
-- acting for a unit, through an account) match a rule?
CREATE OR REPLACE FUNCTION facility.room_reserved_for(p_room uuid, p_date date, p_person uuid, p_unit uuid, p_account uuid,
                                                     OUT is_reserved boolean, OUT is_allowed boolean)
LANGUAGE plpgsql STABLE AS $$
DECLARE r record;
BEGIN
  is_reserved := false; is_allowed := false;
  FOR r IN
    SELECT rr.* FROM facility.room_reservation_rule rr
    JOIN org.room rm ON rm.id = p_room
    WHERE rr.valid @> p_date
      AND (rr.room_id = p_room OR rr.floor_id = rm.floor_id OR rr.building_id = rm.building_id)
  LOOP
    is_reserved := true;
    IF r.person_id = p_person THEN is_allowed := true;
    ELSIF r.position_type_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM org.appointment ap JOIN people.employee e ON e.id = ap.employee_id
        WHERE e.person_id = p_person AND ap.position_type_id = r.position_type_id AND ap.valid @> p_date) THEN is_allowed := true;
    ELSIF r.org_unit_id IS NOT NULL AND (
        (p_unit IS NOT NULL AND p_unit IN (SELECT org_unit_id FROM org.descendants(r.org_unit_id)))
        OR EXISTS (SELECT 1 FROM people.v_person_principal_kind k WHERE k.person_id = p_person
                   AND k.home_org_unit_id IN (SELECT org_unit_id FROM org.descendants(r.org_unit_id)))) THEN is_allowed := true;
    ELSIF r.permission_id IS NOT NULL AND p_account IS NOT NULL AND authz.has_permission(
        p_account, (SELECT code FROM authz.v_permission_code WHERE permission_id = r.permission_id), NULL) THEN is_allowed := true;
    END IF;
    EXIT WHEN is_allowed;
  END LOOP;
END $$;

-- ################################################################### LEDGER ##

-- Which kind of use may pre-empt which, optionally only for a room type or
-- within the custody of an org unit (and its descendants). No rule = no
-- pre-emption: the earlier hold wins and the later one is refused. The most
-- specific rule decides (type + unit > unit > type > global). The default
-- rules (10_seed_reference.sql) are POLICY.
CREATE TABLE facility.hold_priority_rule (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hold_type_id           smallint NOT NULL REFERENCES ref.hold_type(id),
  outranks_hold_type_id  smallint NOT NULL REFERENCES ref.hold_type(id),
  room_type_id           smallint REFERENCES ref.room_type(id),
  org_unit_id            uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  valid                  daterange NOT NULL DEFAULT daterange('2000-01-01', NULL),
  note                   text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (hold_type_id <> outranks_hold_type_id),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT hold_priority_rule_one EXCLUDE USING gist (
    hold_type_id WITH =, outranks_hold_type_id WITH =,
    (COALESCE(room_type_id, 0)) WITH =,
    (COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =, valid WITH &&)
);

CREATE OR REPLACE FUNCTION facility.hold_priority_rule_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM facility.hold_priority_rule r
             WHERE r.hold_type_id = NEW.outranks_hold_type_id AND r.outranks_hold_type_id = NEW.hold_type_id
               AND r.room_type_id IS NOT DISTINCT FROM NEW.room_type_id AND r.org_unit_id IS NOT DISTINCT FROM NEW.org_unit_id
               AND r.valid && NEW.valid AND r.id <> NEW.id) THEN
    RAISE EXCEPTION 'hold_priority_rule: the reverse rule already exists at this scope' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_hold_priority_rule_validate BEFORE INSERT OR UPDATE ON facility.hold_priority_rule
  FOR EACH ROW EXECUTE FUNCTION facility.hold_priority_rule_validate();

-- Does hold type A outrank hold type B for a room of this type in the custody
-- of this unit on this date?
CREATE OR REPLACE FUNCTION facility.outranks(p_type smallint, p_other smallint, p_room_type smallint, p_unit uuid, p_date date)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE v_wins boolean;
BEGIN
  -- the most specific rule about this pair decides, whichever way round it is written
  SELECT r.hold_type_id = p_type INTO v_wins
  FROM facility.hold_priority_rule r
  LEFT JOIN org.ancestors(p_unit) a ON a.org_unit_id = r.org_unit_id
  WHERE r.valid @> p_date
    AND ((r.hold_type_id = p_type AND r.outranks_hold_type_id = p_other) OR (r.hold_type_id = p_other AND r.outranks_hold_type_id = p_type))
    AND (r.room_type_id IS NULL OR r.room_type_id = p_room_type)
    AND (r.org_unit_id IS NULL OR a.org_unit_id IS NOT NULL)
  ORDER BY (r.room_type_id IS NOT NULL AND r.org_unit_id IS NOT NULL) DESC,
           (r.org_unit_id IS NOT NULL) DESC, a.depth NULLS LAST,
           (r.room_type_id IS NOT NULL) DESC
  LIMIT 1;
  RETURN COALESCE(v_wins, false);
END $$;

-- Planned maintenance / cleaning / renovation of a room: written to the
-- ledger as a MAINTENANCE hold. May belong to a work order, in which case
-- closing the work order releases it.
CREATE TABLE facility.room_service_window (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id                uuid NOT NULL REFERENCES org.room(id) ON DELETE CASCADE,
  room_service_type_id   smallint NOT NULL REFERENCES ref.room_service_type(id),
  during                 tsrange NOT NULL,
  note                   text,
  work_order_id          uuid,                                      -- FK added after facility.work_order
  created_by_account_id  uuid NOT NULL REFERENCES iam.user_account(id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during))
);
CREATE INDEX room_service_window_room_idx ON facility.room_service_window(room_id);
SELECT util.attach_updated_at('facility.room_service_window');

-- No bookings of a kind of room, or of a whole building, for a period
-- (examination weeks, a campus event, a security lockdown). Classes, exams
-- and other institutional holds are unaffected; booking requests are refused.
CREATE TABLE facility.blackout (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type_id           smallint REFERENCES ref.room_type(id),
  building_id            uuid REFERENCES org.building(id) ON DELETE CASCADE,
  during                 tsrange NOT NULL,
  reason                 text NOT NULL CHECK (btrim(reason) <> ''),
  created_by_account_id  uuid NOT NULL REFERENCES iam.user_account(id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_type_id, building_id) >= 1),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during))
);

-- ---------------------------------------------------------------- room_hold --
-- THE ledger. One row per use of one room for one span, written by triggers
-- from every source (never by hand): timetable entries (one row per class
-- date, materialised per term), extra classes, exam rooms, vivas,
-- convocations, booking occurrences, guest stays and service windows. The
-- blocked range (span + buffers) of active holds on one room never overlaps —
-- the gist EXCLUDE is the last word, whatever the application does. A hold on
-- a composed room shadows its parts through parent_hold_id (so a part is
-- never booked while the whole is); a hold on a part is checked against the
-- whole's real holds under a row lock on the whole (so the whole is never
-- booked while a part is, even by two sessions at once).
-- Pre-emption: a new hold that conflicts only with holds its type outranks
-- (facility.outranks) displaces them (is_active = false, displaced_by /
-- displaced_at kept) instead of failing; deleting the displacer reinstates
-- what is free again. Holds are immutable except for displacement.
CREATE TABLE facility.room_hold (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id                 uuid NOT NULL REFERENCES org.room(id),
  hold_type_id            smallint NOT NULL REFERENCES ref.hold_type(id),
  during                  tsrange NOT NULL,
  setup_minutes           smallint NOT NULL CHECK (setup_minutes >= 0),
  teardown_minutes        smallint NOT NULL CHECK (teardown_minutes >= 0),
  -- exactly one source (or a shadow of another hold)
  timetable_entry_id      uuid REFERENCES academic.timetable_entry(id) ON DELETE CASCADE,
  class_session_id        uuid REFERENCES academic.class_session(id) ON DELETE CASCADE,
  exam_schedule_id        uuid,                                       -- with room_id → exam.exam_room
  viva_id                 uuid REFERENCES research.viva(id) ON DELETE CASCADE,
  convocation_id          uuid REFERENCES exam.convocation(id) ON DELETE CASCADE,
  booking_occurrence_id   uuid,                                       -- FK added after facility.booking_occurrence
  guest_stay_id           uuid,                                       -- FK added after facility.guest_stay
  room_service_window_id  uuid REFERENCES facility.room_service_window(id) ON DELETE CASCADE,
  parent_hold_id          uuid REFERENCES facility.room_hold(id) ON DELETE CASCADE,
  -- displacement
  is_active               boolean NOT NULL DEFAULT true,
  displaced_by_hold_id    uuid REFERENCES facility.room_hold(id) DEFERRABLE INITIALLY DEFERRED,   -- set by the displacer's own BEFORE INSERT; cleared by its AFTER DELETE
  displaced_at            timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CONSTRAINT room_hold_one_source CHECK (
    (parent_hold_id IS NULL) = (num_nonnulls(timetable_entry_id, class_session_id, exam_schedule_id, viva_id, convocation_id,
                                             booking_occurrence_id, guest_stay_id, room_service_window_id) = 1)),
  CONSTRAINT room_hold_displacement CHECK (is_active = (displaced_at IS NULL) AND (displaced_by_hold_id IS NULL OR displaced_at IS NOT NULL)),   -- displaced_by NULL + displaced_at: the displacer is gone but the room is still taken
  CONSTRAINT room_hold_no_overlap EXCLUDE USING gist (
    room_id WITH =, facility.blocked(during, setup_minutes, teardown_minutes) WITH &&) WHERE (is_active),
  FOREIGN KEY (exam_schedule_id, room_id) REFERENCES exam.exam_room(exam_schedule_id, room_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX room_hold_timetable_date_uq ON facility.room_hold (timetable_entry_id, lower(during)) WHERE timetable_entry_id IS NOT NULL;
CREATE INDEX room_hold_room_time_idx ON facility.room_hold USING gist (room_id, during);
CREATE INDEX room_hold_parent_idx ON facility.room_hold(parent_hold_id);
CREATE INDEX room_hold_displaced_by_idx ON facility.room_hold(displaced_by_hold_id);
CREATE INDEX room_hold_session_idx ON facility.room_hold(class_session_id);
CREATE INDEX room_hold_occurrence_idx ON facility.room_hold(booking_occurrence_id);
CREATE INDEX room_hold_guest_stay_idx ON facility.room_hold(guest_stay_id);

-- Which source column feeds which hold type.
CREATE OR REPLACE FUNCTION facility.hold_source_table(h facility.room_hold)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN h.timetable_entry_id IS NOT NULL THEN 'academic.timetable_entry'
              WHEN h.class_session_id IS NOT NULL THEN 'academic.class_session'
              WHEN h.exam_schedule_id IS NOT NULL THEN 'exam.exam_room'
              WHEN h.viva_id IS NOT NULL THEN 'research.viva'
              WHEN h.convocation_id IS NOT NULL THEN 'exam.convocation'
              WHEN h.booking_occurrence_id IS NOT NULL THEN 'facility.booking_occurrence'
              WHEN h.guest_stay_id IS NOT NULL THEN 'facility.guest_stay'
              WHEN h.room_service_window_id IS NOT NULL THEN 'facility.room_service_window' END
$$;

-- (a) source ↔ hold type, default buffers, active room
CREATE OR REPLACE FUNCTION facility.room_hold_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_type record; v_parent facility.room_hold;
BEGIN
  SELECT * INTO v_type FROM ref.hold_type WHERE id = NEW.hold_type_id;
  IF NEW.parent_hold_id IS NOT NULL THEN
    SELECT * INTO v_parent FROM facility.room_hold WHERE id = NEW.parent_hold_id;
    IF v_parent.parent_hold_id IS NOT NULL THEN
      RAISE EXCEPTION 'room_hold: a shadow cannot shadow another shadow' USING ERRCODE = 'check_violation';
    END IF;
    NEW.hold_type_id := v_parent.hold_type_id; NEW.during := v_parent.during;
    NEW.setup_minutes := v_parent.setup_minutes; NEW.teardown_minutes := v_parent.teardown_minutes;
    NEW.is_active := v_parent.is_active; NEW.displaced_by_hold_id := v_parent.displaced_by_hold_id; NEW.displaced_at := v_parent.displaced_at;
  ELSE
    IF facility.hold_source_table(NEW) <> v_type.source_table THEN
      RAISE EXCEPTION 'room_hold: a % hold is written from %, not from %', v_type.code, v_type.source_table, facility.hold_source_table(NEW)
        USING ERRCODE = 'check_violation';
    END IF;
    NEW.setup_minutes := COALESCE(NEW.setup_minutes, v_type.default_setup_minutes);
    NEW.teardown_minutes := COALESCE(NEW.teardown_minutes, v_type.default_teardown_minutes);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM org.room WHERE id = NEW.room_id AND is_active) THEN
    RAISE EXCEPTION 'room_hold: the room is not active' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_hold_a_validate BEFORE INSERT ON facility.room_hold
  FOR EACH ROW EXECUTE FUNCTION facility.room_hold_validate();

-- (b) pre-emption: serialise on the composed room (the whole, or the room
-- itself), then lock every active hold the new one would collide with — on
-- the room (real holds and shadows of the whole) and, for a whole, the real
-- holds on its parts; if every one of them is outranked, displace them, else
-- refuse naming the blocker.
CREATE OR REPLACE FUNCTION facility.room_hold_preempt()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_blocked tsrange; v_room_type smallint; v_unit uuid; v_date date; r record; v_losers uuid[] := '{}';
BEGIN
  IF NOT NEW.is_active THEN RETURN NEW; END IF;
  PERFORM 1 FROM org.room WHERE id = COALESCE((SELECT parent_room_id FROM facility.room_composition WHERE part_room_id = NEW.room_id), NEW.room_id) FOR UPDATE;
  v_blocked := facility.blocked(NEW.during, NEW.setup_minutes, NEW.teardown_minutes);
  v_date := lower(NEW.during)::date;
  SELECT room_type_id INTO v_room_type FROM org.room WHERE id = NEW.room_id;
  BEGIN
    v_unit := facility.custodian_of(NEW.room_id, v_date);
  EXCEPTION WHEN no_data_found THEN v_unit := NULL;
  END;
  FOR r IN
    SELECT h.id, COALESCE(h.parent_hold_id, h.id) AS root_id, h.hold_type_id, h.room_id, t.code AS type_code
    FROM facility.room_hold h JOIN ref.hold_type t ON t.id = h.hold_type_id
    WHERE (h.room_id = NEW.room_id OR (h.room_id IN (SELECT facility.room_parts(NEW.room_id)) AND h.parent_hold_id IS NULL))
      AND h.is_active AND h.id <> NEW.id
      AND facility.blocked(h.during, h.setup_minutes, h.teardown_minutes) && v_blocked
      AND COALESCE(h.parent_hold_id, h.id) IS DISTINCT FROM COALESCE(NEW.parent_hold_id, NEW.id)
    FOR UPDATE OF h
  LOOP
    IF NOT facility.outranks(NEW.hold_type_id, r.hold_type_id, v_room_type, v_unit, v_date) THEN
      RAISE EXCEPTION 'room_hold: room % is held (% %) during %', (SELECT code FROM org.room WHERE id = r.room_id), r.type_code, r.root_id, NEW.during
        USING ERRCODE = 'exclusion_violation';
    END IF;
    v_losers := array_append(v_losers, r.root_id);
  END LOOP;
  IF cardinality(v_losers) > 0 THEN
    UPDATE facility.room_hold SET is_active = false, displaced_by_hold_id = NEW.id, displaced_at = now()
    WHERE id = ANY (v_losers) OR parent_hold_id = ANY (v_losers);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_hold_b_preempt BEFORE INSERT ON facility.room_hold
  FOR EACH ROW EXECUTE FUNCTION facility.room_hold_preempt();

-- (c) immutable except for displacement / reinstatement
CREATE OR REPLACE FUNCTION facility.room_hold_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.room_id <> OLD.room_id OR NEW.hold_type_id <> OLD.hold_type_id OR NEW.during <> OLD.during
     OR NEW.setup_minutes <> OLD.setup_minutes OR NEW.teardown_minutes <> OLD.teardown_minutes
     OR NEW.parent_hold_id IS DISTINCT FROM OLD.parent_hold_id
     OR facility.hold_source_table(NEW) IS DISTINCT FROM facility.hold_source_table(OLD)
     OR NEW.timetable_entry_id IS DISTINCT FROM OLD.timetable_entry_id OR NEW.class_session_id IS DISTINCT FROM OLD.class_session_id
     OR NEW.exam_schedule_id IS DISTINCT FROM OLD.exam_schedule_id OR NEW.viva_id IS DISTINCT FROM OLD.viva_id
     OR NEW.convocation_id IS DISTINCT FROM OLD.convocation_id OR NEW.booking_occurrence_id IS DISTINCT FROM OLD.booking_occurrence_id
     OR NEW.guest_stay_id IS DISTINCT FROM OLD.guest_stay_id OR NEW.room_service_window_id IS DISTINCT FROM OLD.room_service_window_id THEN
    RAISE EXCEPTION 'room_hold: a hold is never edited — delete the source and write it again' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_hold_c_immutable BEFORE UPDATE ON facility.room_hold
  FOR EACH ROW EXECUTE FUNCTION facility.room_hold_immutable();

-- (d) shadows: a hold on a composed room shadows each of its parts;
-- displacement is mirrored to the shadows.
CREATE OR REPLACE FUNCTION facility.room_hold_shadow()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.parent_hold_id IS NULL THEN
      INSERT INTO facility.room_hold (room_id, hold_type_id, during, setup_minutes, teardown_minutes, parent_hold_id)
      SELECT r, NEW.hold_type_id, NEW.during, NEW.setup_minutes, NEW.teardown_minutes, NEW.id
      FROM facility.room_parts(NEW.room_id) r;
    END IF;
  ELSIF NEW.parent_hold_id IS NULL AND (NEW.is_active <> OLD.is_active OR NEW.displaced_by_hold_id IS DISTINCT FROM OLD.displaced_by_hold_id) THEN
    UPDATE facility.room_hold SET is_active = NEW.is_active, displaced_by_hold_id = NEW.displaced_by_hold_id, displaced_at = NEW.displaced_at
    WHERE parent_hold_id = NEW.id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_room_hold_d_shadow AFTER INSERT OR UPDATE OF is_active, displaced_by_hold_id ON facility.room_hold
  FOR EACH ROW EXECUTE FUNCTION facility.room_hold_shadow();

-- (e) a displacer that goes away gives the room back: every hold it displaced
-- that is free again is reinstated; the rest stay displaced with the displacer
-- cleared (v_displaced_hold lists them for re-placement). Runs AFTER the
-- delete (the displacer must be gone for the EXCLUDE to let the loser back);
-- the deferred FK is satisfied by the time the transaction commits.
CREATE OR REPLACE FUNCTION facility.room_hold_release()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  IF OLD.parent_hold_id IS NOT NULL THEN RETURN NULL; END IF;
  FOR r IN SELECT * FROM facility.room_hold WHERE displaced_by_hold_id = OLD.id AND parent_hold_id IS NULL ORDER BY displaced_at LOOP
    BEGIN
      UPDATE facility.room_hold SET is_active = true, displaced_by_hold_id = NULL, displaced_at = NULL WHERE id = r.id;
    EXCEPTION WHEN exclusion_violation THEN
      UPDATE facility.room_hold SET displaced_by_hold_id = NULL WHERE id = r.id OR parent_hold_id = r.id;   -- still blocked by something else
    END;
  END LOOP;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_room_hold_e_release AFTER DELETE ON facility.room_hold
  FOR EACH ROW EXECUTE FUNCTION facility.room_hold_release();

-- Is the room free of active holds for the span (its own — including the
-- shadows of its whole — and, for a composed room, the real holds on its parts)?
CREATE OR REPLACE FUNCTION facility.room_is_free(p_room uuid, p_during tsrange, p_setup smallint DEFAULT 0, p_teardown smallint DEFAULT 0)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM facility.room_hold h
    WHERE (h.room_id = p_room OR (h.room_id IN (SELECT facility.room_parts(p_room)) AND h.parent_hold_id IS NULL)) AND h.is_active
      AND facility.blocked(h.during, h.setup_minutes, h.teardown_minutes) && facility.blocked(p_during, p_setup, p_teardown))
$$;

-- Put a displaced hold back by hand (after the displacer moved or the class
-- was re-placed); refused by the EXCLUDE if the room is still taken.
CREATE OR REPLACE FUNCTION facility.reinstate_hold(p_hold uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE facility.room_hold SET is_active = true, displaced_by_hold_id = NULL, displaced_at = NULL
  WHERE id = p_hold AND parent_hold_id IS NULL AND NOT is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'reinstate_hold: % is not a displaced hold', p_hold USING ERRCODE = 'no_data_found';
  END IF;
END $$;

-- ---------------------------------------------- org retrofits needing holds --
-- A room / floor / building cannot be deactivated while it has active holds
-- in the future, and cannot be activated under an inactive parent.
CREATE OR REPLACE FUNCTION org.room_activation_check()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT NEW.is_active AND OLD.is_active AND EXISTS (
       SELECT 1 FROM facility.room_hold h WHERE h.room_id = NEW.id AND h.is_active AND upper(h.during) > localtimestamp) THEN
    RAISE EXCEPTION 'room %: cannot deactivate a room with future holds', NEW.code USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.is_active AND (NOT (SELECT is_active FROM org.building WHERE id = NEW.building_id)
                        OR (NEW.floor_id IS NOT NULL AND NOT (SELECT is_active FROM org.floor WHERE id = NEW.floor_id))) THEN
    RAISE EXCEPTION 'room %: cannot be active under an inactive floor / building', NEW.code USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_room_activation_check BEFORE UPDATE OF is_active, floor_id, building_id ON org.room
  FOR EACH ROW EXECUTE FUNCTION org.room_activation_check();

CREATE OR REPLACE FUNCTION org.floor_activation_check()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT NEW.is_active AND OLD.is_active AND EXISTS (
       SELECT 1 FROM facility.room_hold h JOIN org.room r ON r.id = h.room_id
       WHERE r.floor_id = NEW.id AND h.is_active AND upper(h.during) > localtimestamp) THEN
    RAISE EXCEPTION 'floor %: cannot deactivate a floor whose rooms have future holds', NEW.code USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.is_active AND NOT (SELECT is_active FROM org.building WHERE id = NEW.building_id) THEN
    RAISE EXCEPTION 'floor %: cannot be active in an inactive building', NEW.code USING ERRCODE = 'check_violation';
  END IF;
  IF NOT NEW.is_active AND OLD.is_active THEN
    UPDATE org.room SET is_active = false WHERE floor_id = NEW.id AND is_active;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_floor_activation_check BEFORE UPDATE OF is_active ON org.floor
  FOR EACH ROW EXECUTE FUNCTION org.floor_activation_check();

CREATE OR REPLACE FUNCTION org.building_activation_check()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT NEW.is_active AND OLD.is_active THEN
    IF EXISTS (SELECT 1 FROM facility.room_hold h JOIN org.room r ON r.id = h.room_id
               WHERE r.building_id = NEW.id AND h.is_active AND upper(h.during) > localtimestamp) THEN
      RAISE EXCEPTION 'building %: cannot deactivate a building whose rooms have future holds', NEW.code USING ERRCODE = 'check_violation';
    END IF;
    UPDATE org.room SET is_active = false WHERE building_id = NEW.id AND is_active;
    UPDATE org.floor SET is_active = false WHERE building_id = NEW.id AND is_active;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_building_activation_check BEFORE UPDATE OF is_active ON org.building
  FOR EACH ROW EXECUTE FUNCTION org.building_activation_check();

-- ------------------------------------------------------- source writers --
-- Timetable: one hold per class date of a term, from every entry of an
-- offering of that term. Idempotent (existing dates are kept), skips
-- non-working days of the offering unit and dates whose generated session was
-- cancelled / rescheduled, and never aborts: a date the room is no longer
-- free on is reported as a conflict (v_timetable_gap shows them).
CREATE OR REPLACE FUNCTION facility.materialise_timetable(p_term uuid)
RETURNS TABLE (created int, existing int, skipped int, conflicts int) LANGUAGE plpgsql AS $$
DECLARE r record; v_period daterange; v_date date; v_type smallint;
BEGIN
  created := 0; existing := 0; skipped := 0; conflicts := 0;
  SELECT period INTO v_period FROM academic.academic_term WHERE id = p_term;
  IF v_period IS NULL THEN
    RAISE EXCEPTION 'materialise_timetable: unknown term %', p_term USING ERRCODE = 'no_data_found';
  END IF;
  v_type := ref.id_of('hold_type', 'TIMETABLE');
  FOR r IN
    SELECT te.id, te.room_id, te.valid, te.repeat_every_weeks, s.day_of_week, s.start_time, s.end_time, o.offering_org_unit_id
    FROM academic.timetable_entry te
    JOIN academic.time_slot s ON s.id = te.time_slot_id
    JOIN academic.teaching_assignment ta ON ta.id = te.teaching_assignment_id
    JOIN academic.course_offering o ON o.id = ta.course_offering_id AND o.academic_term_id = p_term
    WHERE te.valid && v_period
    -- co-teachers share one hold per class date: the primary teacher's entry owns it (then the
    -- earliest entry), so which entry holds the room never depends on the order rows happen to be read
    ORDER BY ta.is_primary DESC, te.created_at, te.id
  LOOP
    FOR v_date IN
      SELECT d::date FROM generate_series(greatest(lower(v_period), lower(r.valid)),
                                          least(upper(v_period), COALESCE(upper(r.valid), upper(v_period))) - 1, interval '1 day') d
      WHERE extract(isodow FROM d) = r.day_of_week
    LOOP
      IF NOT academic.is_pattern_week(lower(r.valid), r.repeat_every_weeks, v_date) THEN CONTINUE; END IF;
      IF EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = r.id AND lower(during) = v_date + r.start_time)
         OR EXISTS (SELECT 1 FROM facility.room_hold h WHERE h.room_id = r.room_id AND h.hold_type_id = v_type AND h.is_active
                    AND h.during = facility.span(v_date, r.start_time, r.end_time)) THEN   -- co-teachers share the class's hold
        existing := existing + 1; CONTINUE;
      END IF;
      IF NOT academic.is_working_day(v_date, r.offering_org_unit_id)
         OR EXISTS (SELECT 1 FROM academic.class_session cs JOIN ref.class_session_status st ON st.id = cs.class_session_status_id AND st.releases_room
                    WHERE cs.timetable_entry_id = r.id AND cs.session_date = v_date) THEN
        skipped := skipped + 1; CONTINUE;
      END IF;
      BEGIN
        INSERT INTO facility.room_hold (room_id, hold_type_id, during, timetable_entry_id)
        VALUES (r.room_id, v_type, facility.span(v_date, r.start_time, r.end_time), r.id);
        created := created + 1;
      EXCEPTION WHEN exclusion_violation THEN
        conflicts := conflicts + 1;
      END;
    END LOOP;
  END LOOP;
  RETURN NEXT;
END $$;

-- An entry whose slot / room / validity / pattern changes after materialisation
-- drops its holds and is materialised again for the terms it had holds in.
CREATE OR REPLACE FUNCTION academic.timetable_entry_rematerialise()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_term uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = NEW.id) THEN RETURN NULL; END IF;
  DELETE FROM facility.room_hold WHERE timetable_entry_id = NEW.id;
  FOR v_term IN
    SELECT DISTINCT o.academic_term_id FROM academic.teaching_assignment ta
    JOIN academic.course_offering o ON o.id = ta.course_offering_id WHERE ta.id = NEW.teaching_assignment_id
  LOOP
    PERFORM facility.materialise_timetable(v_term);
  END LOOP;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_timetable_entry_rematerialise AFTER UPDATE OF time_slot_id, room_id, valid, repeat_every_weeks ON academic.timetable_entry
  FOR EACH ROW EXECUTE FUNCTION academic.timetable_entry_rematerialise();

-- Class sessions: an extra class with its own room holds it (EXTRA_CLASS); a
-- cancelled / rescheduled session (status releases_room) frees the date's
-- hold, and a session put back on restores it.
CREATE OR REPLACE FUNCTION academic.class_session_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_releases boolean; v_entry record;
BEGIN
  SELECT releases_room INTO v_releases FROM ref.class_session_status WHERE id = NEW.class_session_status_id;
  IF NEW.timetable_entry_id IS NOT NULL THEN
    SELECT te.room_id, s.start_time, s.end_time INTO v_entry
    FROM academic.timetable_entry te JOIN academic.time_slot s ON s.id = te.time_slot_id WHERE te.id = NEW.timetable_entry_id;
    IF v_releases THEN
      DELETE FROM facility.room_hold WHERE timetable_entry_id = NEW.timetable_entry_id AND lower(during) = NEW.session_date + v_entry.start_time;
    ELSIF NOT EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = NEW.timetable_entry_id AND lower(during) = NEW.session_date + v_entry.start_time)
          AND EXISTS (SELECT 1 FROM facility.room_hold WHERE timetable_entry_id = NEW.timetable_entry_id) THEN   -- only once the term is materialised
      INSERT INTO facility.room_hold (room_id, hold_type_id, during, timetable_entry_id)
      VALUES (v_entry.room_id, ref.id_of('hold_type', 'TIMETABLE'), facility.span(NEW.session_date, v_entry.start_time, v_entry.end_time), NEW.timetable_entry_id);
    END IF;
  ELSE
    DELETE FROM facility.room_hold WHERE class_session_id = NEW.id;
    IF NEW.room_id IS NOT NULL AND NOT v_releases THEN
      INSERT INTO facility.room_hold (room_id, hold_type_id, during, class_session_id)
      VALUES (NEW.room_id, ref.id_of('hold_type', 'EXTRA_CLASS'), facility.span(NEW.session_date, NEW.start_time, NEW.end_time), NEW.id);
    END IF;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_class_session_hold AFTER INSERT OR UPDATE OF class_session_status_id, room_id, session_date, start_time, end_time ON academic.class_session
  FOR EACH ROW EXECUTE FUNCTION academic.class_session_hold();

-- Exam rooms: every room of a paper is held for the paper's span (with the
-- EXAM buffers); moving the paper re-writes its holds.
CREATE OR REPLACE FUNCTION exam.exam_room_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_s record;
BEGIN
  SELECT exam_date, start_time, end_time INTO v_s FROM exam.exam_schedule WHERE id = NEW.exam_schedule_id;
  INSERT INTO facility.room_hold (room_id, hold_type_id, during, exam_schedule_id)
  VALUES (NEW.room_id, ref.id_of('hold_type', 'EXAM'), facility.span(v_s.exam_date, v_s.start_time, v_s.end_time), NEW.exam_schedule_id);
  RETURN NULL;
END $$;
CREATE TRIGGER trg_exam_room_hold AFTER INSERT ON exam.exam_room
  FOR EACH ROW EXECUTE FUNCTION exam.exam_room_hold();

CREATE OR REPLACE FUNCTION exam.exam_schedule_rehold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM facility.room_hold WHERE exam_schedule_id = NEW.id;
  INSERT INTO facility.room_hold (room_id, hold_type_id, during, exam_schedule_id)
  SELECT er.room_id, ref.id_of('hold_type', 'EXAM'), facility.span(NEW.exam_date, NEW.start_time, NEW.end_time), NEW.id
  FROM exam.exam_room er WHERE er.exam_schedule_id = NEW.id;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_exam_schedule_rehold AFTER UPDATE OF exam_date, start_time, end_time ON exam.exam_schedule
  FOR EACH ROW EXECUTE FUNCTION exam.exam_schedule_rehold();

-- Vivas and convocations with a venue.
CREATE OR REPLACE FUNCTION research.viva_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM facility.room_hold WHERE viva_id = NEW.id;
  IF NEW.room_id IS NOT NULL THEN
    INSERT INTO facility.room_hold (room_id, hold_type_id, during, viva_id)
    VALUES (NEW.room_id, ref.id_of('hold_type', 'VIVA'), facility.span(NEW.held_on, NEW.start_time, NEW.end_time), NEW.id);
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_viva_hold AFTER INSERT OR UPDATE OF held_on, start_time, end_time, room_id ON research.viva
  FOR EACH ROW EXECUTE FUNCTION research.viva_hold();

CREATE OR REPLACE FUNCTION exam.convocation_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM facility.room_hold WHERE convocation_id = NEW.id;
  IF NEW.room_id IS NOT NULL THEN
    INSERT INTO facility.room_hold (room_id, hold_type_id, during, convocation_id)
    VALUES (NEW.room_id, ref.id_of('hold_type', 'CONVOCATION'),
            CASE WHEN NEW.start_time IS NULL THEN facility.day_span(NEW.held_on) ELSE facility.span(NEW.held_on, NEW.start_time, NEW.end_time) END, NEW.id);
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_convocation_hold AFTER INSERT OR UPDATE OF held_on, start_time, end_time, room_id ON exam.convocation
  FOR EACH ROW EXECUTE FUNCTION exam.convocation_hold();

-- Service windows.
CREATE OR REPLACE FUNCTION facility.room_service_window_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM facility.room_hold WHERE room_service_window_id = NEW.id;
  INSERT INTO facility.room_hold (room_id, hold_type_id, during, room_service_window_id)
  VALUES (NEW.room_id, ref.id_of('hold_type', 'MAINTENANCE'), NEW.during, NEW.id);
  RETURN NULL;
END $$;
CREATE TRIGGER trg_room_service_window_hold AFTER INSERT OR UPDATE OF room_id, during ON facility.room_service_window
  FOR EACH ROW EXECUTE FUNCTION facility.room_service_window_hold();

-- ################################################################# BOOKINGS ##

-- Booking rules for a unit's spaces (NULL unit = university default; the
-- nearest ancestor with a policy applies). Values are POLICY.
CREATE TABLE facility.booking_policy (
  id                                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id                       uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  valid                             daterange NOT NULL DEFAULT daterange('2000-01-01', NULL),
  min_duration_minutes              smallint NOT NULL CHECK (min_duration_minutes > 0),
  max_advance_days                  smallint NOT NULL CHECK (max_advance_days > 0),
  self_cancel_until_minutes_before  smallint NOT NULL CHECK (self_cancel_until_minutes_before >= 0),
  no_show_grace_minutes             smallint NOT NULL CHECK (no_show_grace_minutes >= 0),
  checkin_opens_minutes_before      smallint NOT NULL CHECK (checkin_opens_minutes_before >= 0),
  note                              text,
  created_at                        timestamptz NOT NULL DEFAULT now(),
  updated_at                        timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT booking_policy_one_per_scope EXCLUDE USING gist (
    (COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.booking_policy');

CREATE OR REPLACE FUNCTION facility.policy_for(p_unit uuid, p_date date DEFAULT current_date)
RETURNS facility.booking_policy LANGUAGE plpgsql STABLE AS $$
DECLARE v facility.booking_policy;
BEGIN
  SELECT p.* INTO v FROM facility.booking_policy p
  LEFT JOIN org.ancestors(p_unit) a ON a.org_unit_id = p.org_unit_id
  WHERE p.valid @> p_date AND (p.org_unit_id IS NULL OR a.org_unit_id IS NOT NULL)
  ORDER BY a.depth NULLS LAST LIMIT 1;
  IF v.id IS NULL THEN
    RAISE EXCEPTION 'booking_policy: no policy is configured' USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v;
END $$;

-- A person barred from a kind of resource (or from all) for a period —
-- misuse, no-shows, dues. Disciplinary personal data: registered, hidden from
-- analytics.
CREATE TABLE facility.booking_restriction (
  id                             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id                      uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  facility_resource_kind_id      smallint REFERENCES ref.facility_resource_kind(id),   -- NULL = every kind
  booking_restriction_reason_id  smallint NOT NULL REFERENCES ref.booking_restriction_reason(id),
  note                           text,
  valid                          tstzrange NOT NULL DEFAULT tstzrange(now(), NULL),
  imposed_by_account_id          uuid NOT NULL REFERENCES iam.user_account(id),
  created_at                     timestamptz NOT NULL DEFAULT now(),
  updated_at                     timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT booking_restriction_no_overlap EXCLUDE USING gist (
    person_id WITH =, (COALESCE(facility_resource_kind_id, 0)) WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.booking_restriction');

CREATE OR REPLACE FUNCTION facility.is_restricted(p_person uuid, p_kind text, p_at timestamptz DEFAULT now())
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM facility.booking_restriction r
    LEFT JOIN ref.facility_resource_kind k ON k.id = r.facility_resource_kind_id
    WHERE r.person_id = p_person AND r.valid @> p_at AND (r.facility_resource_kind_id IS NULL OR k.code = p_kind))
$$;

-- An event (conference, fest, convocation rehearsal …) as one package:
-- approved once through EVENT_REQUEST by the organising unit's head and the
-- university; its room, asset and vehicle requests carry event_request_id
-- and go to their own custodians when the event is approved.
CREATE TABLE facility.event_request (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title                   text NOT NULL CHECK (btrim(title) <> ''),
  organiser_person_id     uuid NOT NULL REFERENCES people.person(id),
  on_behalf_org_unit_id   uuid NOT NULL REFERENCES org.org_unit(id),
  event_kind_id           smallint NOT NULL REFERENCES ref.event_kind(id),
  during                  tsrange NOT NULL,
  expected_attendance     int CHECK (expected_attendance > 0),
  note                    text,
  instance_id             uuid NOT NULL UNIQUE REFERENCES wf.approval_instance(id),
  cancelled_at            timestamptz,
  cancelled_by_account_id uuid REFERENCES iam.user_account(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK ((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL))
);
CREATE INDEX event_request_unit_idx ON facility.event_request(on_behalf_org_unit_id);
SELECT util.attach_updated_at('facility.event_request');

CREATE OR REPLACE FUNCTION facility.event_request_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.title <> OLD.title OR NEW.organiser_person_id <> OLD.organiser_person_id OR NEW.on_behalf_org_unit_id <> OLD.on_behalf_org_unit_id
       OR NEW.event_kind_id <> OLD.event_kind_id OR NEW.during <> OLD.during OR NEW.instance_id <> OLD.instance_id
       OR NEW.expected_attendance IS DISTINCT FROM OLD.expected_attendance OR NEW.note IS DISTINCT FROM OLD.note THEN
      RAISE EXCEPTION 'event_request: a request is never edited; withdraw it and submit again' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF OLD.cancelled_at IS NOT NULL THEN
      RAISE EXCEPTION 'event_request: already cancelled' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  -- its own EVENT_REQUEST round, or the round of an event proposal — or of a change of an event's dates — (events module) that owns this package
  IF NOT EXISTS (SELECT 1 FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id AND dt.code IN ('EVENT_REQUEST', 'EVENT_PROPOSAL', 'EVENT_CHANGE')
                 WHERE i.id = NEW.instance_id AND i.owner_org_unit_id = NEW.on_behalf_org_unit_id) THEN
    RAISE EXCEPTION 'event_request: the round is not an EVENT_REQUEST / EVENT_PROPOSAL / EVENT_CHANGE round of the organising unit' USING ERRCODE = 'check_violation';
  END IF;
  IF facility.is_restricted(NEW.organiser_person_id, 'ROOM') THEN
    RAISE EXCEPTION 'event_request: the organiser is currently restricted from booking' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF upper(NEW.during) <= localtimestamp THEN
    RAISE EXCEPTION 'event_request: the event is in the past' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_event_request_validate BEFORE INSERT OR UPDATE ON facility.event_request
  FOR EACH ROW EXECUTE FUNCTION facility.event_request_validate();

-- Cancelling an event package cancels what is left of it: every future
-- occurrence of its room requests (freeing rooms and assets).
CREATE OR REPLACE FUNCTION facility.event_request_cancel()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
    UPDATE facility.booking_occurrence o
       SET cancelled_at = NEW.cancelled_at, cancelled_by_account_id = NEW.cancelled_by_account_id,
           booking_cancel_reason_id = ref.id_of('booking_cancel_reason', 'EVENT_CANCELLED')
    FROM facility.booking_request br
    WHERE br.id = o.booking_request_id AND br.event_request_id = NEW.id AND o.cancelled_at IS NULL AND upper(o.during) > localtimestamp;
  END IF;
  RETURN NULL;
END $$;

-- A set of bookings made together (N rooms × M dates, a recurring series):
-- one reference GRP-YYYY-NNNN for the requester, one request per custodian.
-- The group is only the reference: who asked, for what and for which event
-- are facts of its requests (v_booking_summary), not repeated here.
CREATE SEQUENCE facility.booking_group_seq;
CREATE TABLE facility.booking_group (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_ref            citext NOT NULL UNIQUE CHECK (group_ref ~ '^GRP-[0-9]{4}-[0-9]{4,}$'),      -- set on insert
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION facility.booking_group_ref()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.group_ref IS NULL THEN
    NEW.group_ref := format('GRP-%s-%s', to_char(current_date, 'YYYY'), lpad(nextval('facility.booking_group_seq')::text, 4, '0'));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_booking_group_ref BEFORE INSERT ON facility.booking_group
  FOR EACH ROW EXECUTE FUNCTION facility.booking_group_ref();

-- One booking request: who, for which unit, why (purpose → kind of hold and
-- priority), how many people, approved through a ROOM_BOOKING round owned by
-- the custodian of the rooms (one custodian per request; a group spans
-- custodians with one request each). Immutable: withdraw and submit again. A
-- reschedule is a new request that names the occurrence it replaces
-- (ROOM_BOOKING_CHANGE); its approval cancels the original. A request that
-- belongs to an event waits for the event's approval before its own round.
CREATE TABLE facility.booking_request (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_group_id              uuid REFERENCES facility.booking_group(id),
  event_request_id              uuid REFERENCES facility.event_request(id),
  requester_person_id           uuid NOT NULL REFERENCES people.person(id),
  on_behalf_org_unit_id         uuid REFERENCES org.org_unit(id),
  booking_purpose_id            smallint NOT NULL REFERENCES ref.booking_purpose(id),
  title                         text NOT NULL CHECK (btrim(title) <> ''),
  expected_headcount            int CHECK (expected_headcount > 0),
  note                          text,
  instance_id                   uuid UNIQUE REFERENCES wf.approval_instance(id),
  rescheduled_from_occurrence_id uuid,                                  -- FK added after booking_occurrence
  created_at                    timestamptz NOT NULL DEFAULT now(),
  CHECK (instance_id IS NOT NULL OR event_request_id IS NOT NULL)
);
CREATE INDEX booking_request_group_idx ON facility.booking_request(booking_group_id);
CREATE INDEX booking_request_event_idx ON facility.booking_request(event_request_id);
CREATE INDEX booking_request_requester_idx ON facility.booking_request(requester_person_id);

-- Required room features of a request (checked against org.room_facility).
CREATE TABLE facility.booking_requirement (
  booking_request_id  uuid NOT NULL REFERENCES facility.booking_request(id) ON DELETE CASCADE,
  room_feature_id     smallint NOT NULL REFERENCES ref.room_feature(id),
  PRIMARY KEY (booking_request_id, room_feature_id)
);

-- One room for one span of a request. Buffers default from the hold type.
-- Check-in (within the policy window) turns a no-show into a held booking;
-- cancellation frees the room and any assets at once.
CREATE TABLE facility.booking_occurrence (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id        uuid NOT NULL REFERENCES facility.booking_request(id) ON DELETE CASCADE,
  room_id                   uuid NOT NULL REFERENCES org.room(id),
  during                    tsrange NOT NULL,
  setup_minutes             smallint NOT NULL CHECK (setup_minutes >= 0),
  teardown_minutes          smallint NOT NULL CHECK (teardown_minutes >= 0),
  checked_in_at             timestamptz,
  checked_in_by_account_id  uuid REFERENCES iam.user_account(id),
  cancelled_at              timestamptz,
  cancelled_by_account_id   uuid REFERENCES iam.user_account(id),
  booking_cancel_reason_id  smallint REFERENCES ref.booking_cancel_reason(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK ((checked_in_at IS NULL) = (checked_in_by_account_id IS NULL)),
  CHECK ((cancelled_at IS NULL) = (booking_cancel_reason_id IS NULL) AND (cancelled_by_account_id IS NULL OR cancelled_at IS NOT NULL))   -- no account = a system reason
);
CREATE INDEX booking_occurrence_request_idx ON facility.booking_occurrence(booking_request_id);
CREATE INDEX booking_occurrence_room_idx ON facility.booking_occurrence USING gist (room_id, during);
SELECT util.attach_updated_at('facility.booking_occurrence');

ALTER TABLE facility.booking_request
  ADD FOREIGN KEY (rescheduled_from_occurrence_id) REFERENCES facility.booking_occurrence(id);
ALTER TABLE facility.room_hold
  ADD FOREIGN KEY (booking_occurrence_id) REFERENCES facility.booking_occurrence(id) ON DELETE CASCADE;

-- The kind of hold a request's purpose makes.
CREATE OR REPLACE FUNCTION facility.purpose_hold_type(p_purpose smallint)
RETURNS smallint LANGUAGE sql STABLE AS $$ SELECT hold_type_id FROM ref.booking_purpose WHERE id = p_purpose $$;

CREATE OR REPLACE FUNCTION facility.booking_request_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_inst record; v_orig record;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.instance_id IS NOT DISTINCT FROM OLD.instance_id OR OLD.instance_id IS NOT NULL
       OR NEW.booking_group_id IS DISTINCT FROM OLD.booking_group_id OR NEW.event_request_id IS DISTINCT FROM OLD.event_request_id
       OR NEW.requester_person_id <> OLD.requester_person_id OR NEW.on_behalf_org_unit_id IS DISTINCT FROM OLD.on_behalf_org_unit_id
       OR NEW.booking_purpose_id <> OLD.booking_purpose_id OR NEW.title <> OLD.title
       OR NEW.expected_headcount IS DISTINCT FROM OLD.expected_headcount OR NEW.note IS DISTINCT FROM OLD.note
       OR NEW.rescheduled_from_occurrence_id IS DISTINCT FROM OLD.rescheduled_from_occurrence_id THEN
      RAISE EXCEPTION 'booking_request: a request is never edited; withdraw it and submit again (only the round of an event booking is set later)'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'booking_request: requests are a record; withdraw or cancel instead' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF facility.is_restricted(NEW.requester_person_id, 'ROOM') THEN
    RAISE EXCEPTION 'booking_request: the requester is currently restricted from booking rooms' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.instance_id IS NOT NULL THEN
    SELECT i.owner_org_unit_id, i.submitted_by_account_id, dt.code AS doc INTO v_inst
    FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id WHERE i.id = NEW.instance_id;
    IF v_inst.doc IS NULL OR v_inst.doc NOT IN ('ROOM_BOOKING', 'ROOM_BOOKING_CHANGE') THEN
      RAISE EXCEPTION 'booking_request: the round is not a ROOM_BOOKING / ROOM_BOOKING_CHANGE round' USING ERRCODE = 'check_violation';
    END IF;
    IF (NEW.rescheduled_from_occurrence_id IS NOT NULL) <> (v_inst.doc = 'ROOM_BOOKING_CHANGE') THEN
      RAISE EXCEPTION 'booking_request: a reschedule goes through ROOM_BOOKING_CHANGE, a new booking through ROOM_BOOKING' USING ERRCODE = 'check_violation';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM iam.user_account WHERE id = v_inst.submitted_by_account_id AND person_id = NEW.requester_person_id)
       AND NOT authz.has_permission(v_inst.submitted_by_account_id, 'facility.booking.update', v_inst.owner_org_unit_id) THEN
      RAISE EXCEPTION 'booking_request: only the requester, or facility staff of the custodian, may submit on their behalf' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  IF NEW.rescheduled_from_occurrence_id IS NOT NULL THEN
    SELECT o.cancelled_at, s.status INTO v_orig
    FROM facility.booking_occurrence o JOIN facility.booking_request br ON br.id = o.booking_request_id
    LEFT JOIN wf.v_instance_state s ON s.instance_id = br.instance_id
    WHERE o.id = NEW.rescheduled_from_occurrence_id;
    IF v_orig.cancelled_at IS NOT NULL OR v_orig.status IS DISTINCT FROM 'APPROVED' THEN
      RAISE EXCEPTION 'booking_request: only an approved, uncancelled occurrence can be rescheduled' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_booking_request_validate BEFORE INSERT OR UPDATE OR DELETE ON facility.booking_request
  FOR EACH ROW EXECUTE FUNCTION facility.booking_request_validate();

CREATE OR REPLACE FUNCTION facility.booking_occurrence_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req record; v_room record; v_pol facility.booking_policy; v_res record; v_type record; v_unit uuid; v_actor_is_staff boolean;
BEGIN
  SELECT br.*, i.owner_org_unit_id, i.submitted_by_account_id, ev.instance_id AS event_instance_id, ev.on_behalf_org_unit_id AS event_unit_id
    INTO v_req
  FROM facility.booking_request br
  LEFT JOIN wf.approval_instance i ON i.id = br.instance_id
  LEFT JOIN facility.event_request ev ON ev.id = br.event_request_id
  WHERE br.id = NEW.booking_request_id;
  SELECT r.*, b.building_kind_id, u.is_bookable, u.is_guest_room, u.is_parking_zone INTO v_room
  FROM org.room r JOIN org.building b ON b.id = r.building_id LEFT JOIN ref.room_use u ON u.id = r.room_use_id WHERE r.id = NEW.room_id;
  v_unit := facility.custodian_of(NEW.room_id, lower(NEW.during)::date);

  IF TG_OP = 'UPDATE' THEN
    IF NEW.booking_request_id <> OLD.booking_request_id OR NEW.room_id <> OLD.room_id OR NEW.during <> OLD.during
       OR NEW.setup_minutes <> OLD.setup_minutes OR NEW.teardown_minutes <> OLD.teardown_minutes THEN
      RAISE EXCEPTION 'booking_occurrence: an occurrence is never moved; reschedule it (a new request) or cancel it' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF OLD.cancelled_at IS NOT NULL AND (NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at OR NEW.checked_in_at IS DISTINCT FROM OLD.checked_in_at) THEN
      RAISE EXCEPTION 'booking_occurrence: already cancelled' USING ERRCODE = 'check_violation';
    END IF;
    v_pol := facility.policy_for(v_unit, lower(NEW.during)::date);
    IF NEW.checked_in_at IS NOT NULL AND OLD.checked_in_at IS NULL THEN
      IF NEW.cancelled_at IS NOT NULL THEN
        RAISE EXCEPTION 'booking_occurrence: cannot check in a cancelled booking' USING ERRCODE = 'check_violation';
      END IF;
      IF (SELECT status FROM wf.v_instance_state WHERE instance_id = v_req.instance_id) IS DISTINCT FROM 'APPROVED' THEN
        RAISE EXCEPTION 'booking_occurrence: the booking is not approved' USING ERRCODE = 'check_violation';
      END IF;
      IF NEW.checked_in_at::timestamp < lower(NEW.during) - make_interval(mins => v_pol.checkin_opens_minutes_before)
         OR NEW.checked_in_at::timestamp >= upper(NEW.during) THEN
        RAISE EXCEPTION 'booking_occurrence: check-in opens % minutes before the start and closes at the end', v_pol.checkin_opens_minutes_before
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
    IF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
      -- a system reason (no-show sweep, reschedule) needs no account but a system job / the workflow;
      -- otherwise: self-cancellation until the policy cut-off, facility staff of the custodian at any time
      IF NEW.cancelled_by_account_id IS NULL THEN
        IF NOT (SELECT is_system FROM ref.booking_cancel_reason WHERE id = NEW.booking_cancel_reason_id)
           OR current_setting('app.system_job', true) IS DISTINCT FROM 'on' THEN
          RAISE EXCEPTION 'booking_occurrence: a cancellation without an account is a system job with a system reason' USING ERRCODE = 'insufficient_privilege';
        END IF;
        RETURN NEW;
      END IF;
      v_actor_is_staff := authz.has_permission(NEW.cancelled_by_account_id, 'facility.booking.update', v_unit)
                          OR (SELECT is_system FROM ref.booking_cancel_reason WHERE id = NEW.booking_cancel_reason_id)
                          OR EXISTS (SELECT 1 FROM facility.event_request ev WHERE ev.id = v_req.event_request_id AND ev.cancelled_at IS NOT NULL);   -- the whole event package was cancelled
      IF NOT v_actor_is_staff THEN
        IF NEW.cancelled_by_account_id <> v_req.submitted_by_account_id
           AND NOT EXISTS (SELECT 1 FROM iam.user_account WHERE id = NEW.cancelled_by_account_id AND person_id = v_req.requester_person_id) THEN
          RAISE EXCEPTION 'booking_occurrence: only the requester or the custodian''s staff may cancel' USING ERRCODE = 'insufficient_privilege';
        END IF;
        IF NEW.cancelled_at::timestamp > lower(NEW.during) - make_interval(mins => v_pol.self_cancel_until_minutes_before) THEN
          RAISE EXCEPTION 'booking_occurrence: self-cancellation closed % minutes before the start; ask the custodian', v_pol.self_cancel_until_minutes_before
            USING ERRCODE = 'check_violation';
        END IF;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- INSERT
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'booking_occurrence: unknown request' USING ERRCODE = 'foreign_key_violation';
  END IF;
  IF NOT v_room.is_active OR v_room.is_bookable IS FALSE OR v_room.is_guest_room OR v_room.is_parking_zone THEN
    RAISE EXCEPTION 'booking_occurrence: room % is not bookable', v_room.code USING ERRCODE = 'check_violation';
  END IF;
  IF v_req.instance_id IS NOT NULL AND v_unit <> v_req.owner_org_unit_id THEN
    RAISE EXCEPTION 'booking_occurrence: room % is in the custody of another unit than the request''s round (one custodian per request)', v_room.code
      USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM facility.booking_occurrence o WHERE o.booking_request_id = NEW.booking_request_id
             AND facility.custodian_of(o.room_id, lower(o.during)::date) <> v_unit) THEN
    RAISE EXCEPTION 'booking_occurrence: one request spans one custodian' USING ERRCODE = 'check_violation';
  END IF;
  IF v_req.expected_headcount > v_room.capacity THEN
    RAISE EXCEPTION 'booking_occurrence: % people do not fit in room % (capacity %)', v_req.expected_headcount, v_room.code, v_room.capacity
      USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM facility.booking_requirement q WHERE q.booking_request_id = NEW.booking_request_id
             AND NOT EXISTS (SELECT 1 FROM org.room_facility f WHERE f.room_id = NEW.room_id AND f.room_feature_id = q.room_feature_id)) THEN
    RAISE EXCEPTION 'booking_occurrence: room % lacks a required feature', v_room.code USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_res FROM facility.room_reserved_for(NEW.room_id, lower(NEW.during)::date, v_req.requester_person_id,
                                                      COALESCE(v_req.on_behalf_org_unit_id, v_req.event_unit_id), v_req.submitted_by_account_id);
  IF v_res.is_reserved AND NOT v_res.is_allowed THEN
    RAISE EXCEPTION 'booking_occurrence: room % is reserved; the requester does not match its reservation rules', v_room.code
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF EXISTS (SELECT 1 FROM facility.blackout bo WHERE bo.during && NEW.during
             AND (bo.room_type_id = v_room.room_type_id OR bo.building_id = v_room.building_id)) THEN
    RAISE EXCEPTION 'booking_occurrence: room % is under a booking blackout for that time', v_room.code USING ERRCODE = 'check_violation';
  END IF;
  v_pol := facility.policy_for(v_unit, lower(NEW.during)::date);
  IF upper(NEW.during) - lower(NEW.during) < make_interval(mins => v_pol.min_duration_minutes) THEN
    RAISE EXCEPTION 'booking_occurrence: a booking is at least % minutes', v_pol.min_duration_minutes USING ERRCODE = 'check_violation';
  END IF;
  IF lower(NEW.during)::date > current_date + v_pol.max_advance_days THEN
    RAISE EXCEPTION 'booking_occurrence: bookings open % days ahead', v_pol.max_advance_days USING ERRCODE = 'check_violation';
  END IF;
  IF lower(NEW.during) < localtimestamp
     AND NOT authz.has_permission(v_req.submitted_by_account_id, 'facility.booking.create_backdated', v_unit) THEN
    RAISE EXCEPTION 'booking_occurrence: the start is in the past (backdating needs facility.booking.create_backdated)' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_type FROM ref.hold_type WHERE id = facility.purpose_hold_type(v_req.booking_purpose_id);
  NEW.setup_minutes := COALESCE(NEW.setup_minutes, v_type.default_setup_minutes);
  NEW.teardown_minutes := COALESCE(NEW.teardown_minutes, v_type.default_teardown_minutes);
  RETURN NEW;
END $$;
CREATE TRIGGER trg_booking_occurrence_validate BEFORE INSERT OR UPDATE ON facility.booking_occurrence
  FOR EACH ROW EXECUTE FUNCTION facility.booking_occurrence_validate();

-- The ledger side: a tentative hold at insert (a pending request blocks the
-- slot, as in the old system); cancellation frees the room and the assets.
CREATE OR REPLACE FUNCTION facility.booking_occurrence_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO facility.room_hold (room_id, hold_type_id, during, setup_minutes, teardown_minutes, booking_occurrence_id)
    SELECT NEW.room_id, facility.purpose_hold_type(br.booking_purpose_id), NEW.during, NEW.setup_minutes, NEW.teardown_minutes, NEW.id
    FROM facility.booking_request br WHERE br.id = NEW.booking_request_id;
  ELSIF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
    DELETE FROM facility.room_hold WHERE booking_occurrence_id = NEW.id;
    DELETE FROM facility.asset_hold WHERE booking_asset_id IN (SELECT id FROM facility.booking_asset WHERE booking_occurrence_id = NEW.id);
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_booking_occurrence_hold AFTER INSERT OR UPDATE OF cancelled_at ON facility.booking_occurrence
  FOR EACH ROW EXECUTE FUNCTION facility.booking_occurrence_hold();
CREATE TRIGGER trg_event_request_cancel AFTER UPDATE OF cancelled_at ON facility.event_request
  FOR EACH ROW EXECUTE FUNCTION facility.event_request_cancel();

-- ############################################################ ASSETS ##

-- Suppliers and service providers (AMC, hire, repairs).
CREATE TABLE facility.vendor (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name               text NOT NULL UNIQUE CHECK (btrim(name) <> ''),
  contact_person_id  uuid REFERENCES people.person(id),
  gstin              citext CHECK (gstin ~ '^[0-9]{2}[A-Z0-9]{13}$'),
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('facility.vendor');

-- One physical asset, fixed (an air conditioner in a room) or portable (a
-- projector that can be booked with a room or lent out). Identity, location,
-- custodian unit, purchase and warranty, condition, condemnation.
CREATE TABLE facility.asset (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_tag              citext NOT NULL UNIQUE CHECK (asset_tag ~ '^[A-Za-z0-9/_-]{2,40}$'),
  asset_type_id          smallint NOT NULL REFERENCES ref.asset_type(id),
  name                   text NOT NULL CHECK (btrim(name) <> ''),
  room_id                uuid REFERENCES org.room(id),                -- where it is (store room for portable ones)
  custodian_org_unit_id  uuid NOT NULL REFERENCES org.org_unit(id),
  is_portable            boolean NOT NULL DEFAULT false,
  purchased_on           date,
  purchase_cost          numeric(12,2) CHECK (purchase_cost >= 0),
  warranty_until         date,
  asset_condition_id     smallint NOT NULL REFERENCES ref.asset_condition(id),
  is_active              boolean NOT NULL DEFAULT true,
  condemned_on           date,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (condemned_on IS NULL OR NOT is_active),
  CHECK (warranty_until IS NULL OR purchased_on IS NULL OR warranty_until >= purchased_on)
);
CREATE INDEX asset_room_idx ON facility.asset(room_id);
CREATE INDEX asset_custodian_idx ON facility.asset(custodian_org_unit_id);
SELECT util.attach_updated_at('facility.asset');

-- An AMC / service contract with a vendor for an asset, a type of asset or
-- a room's installations. One contract per target and vendor at a time.
CREATE TABLE facility.service_contract (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id        uuid REFERENCES facility.asset(id) ON DELETE CASCADE,
  asset_type_id   smallint REFERENCES ref.asset_type(id),
  room_id         uuid REFERENCES org.room(id) ON DELETE CASCADE,
  vendor_id       uuid NOT NULL REFERENCES facility.vendor(id),
  contract_ref    text NOT NULL CHECK (btrim(contract_ref) <> ''),
  valid           daterange NOT NULL,
  file_object_id  uuid REFERENCES people.file_object(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(asset_id, asset_type_id, room_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid) AND NOT upper_inf(valid)),
  CONSTRAINT service_contract_one_per_target EXCLUDE USING gist (
    (COALESCE(asset_id, room_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =,
    (COALESCE(asset_type_id, 0)) WITH =, vendor_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.service_contract');

-- A portable asset booked with a room booking (released with it).
CREATE TABLE facility.booking_asset (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_occurrence_id  uuid NOT NULL REFERENCES facility.booking_occurrence(id) ON DELETE CASCADE,
  asset_id               uuid NOT NULL REFERENCES facility.asset(id),
  created_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (booking_occurrence_id, asset_id)
);

-- A portable asset lent to a person (a camera for a field visit) by the
-- custodian unit's staff, for a period; returned early or late.
CREATE TABLE facility.asset_loan (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id                uuid NOT NULL REFERENCES facility.asset(id),
  borrower_person_id      uuid NOT NULL REFERENCES people.person(id),
  on_behalf_org_unit_id   uuid REFERENCES org.org_unit(id),
  during                  tsrange NOT NULL,
  issued_by_account_id    uuid NOT NULL REFERENCES iam.user_account(id),
  returned_at             timestamptz,
  returned_to_account_id  uuid REFERENCES iam.user_account(id),
  note                    text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK ((returned_at IS NULL) = (returned_to_account_id IS NULL)),
  CHECK (returned_at IS NULL OR returned_at::timestamp >= lower(during))
);
CREATE INDEX asset_loan_asset_idx ON facility.asset_loan(asset_id);
CREATE INDEX asset_loan_borrower_idx ON facility.asset_loan(borrower_person_id);
SELECT util.attach_updated_at('facility.asset_loan');

-- The asset ledger: one row per use of a portable asset; never two at once.
CREATE TABLE facility.asset_hold (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id          uuid NOT NULL REFERENCES facility.asset(id),
  during            tsrange NOT NULL,
  booking_asset_id  uuid REFERENCES facility.booking_asset(id) ON DELETE CASCADE,
  asset_loan_id     uuid REFERENCES facility.asset_loan(id) ON DELETE CASCADE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK (num_nonnulls(booking_asset_id, asset_loan_id) = 1),
  CONSTRAINT asset_hold_no_overlap EXCLUDE USING gist (asset_id WITH =, during WITH &&)
);

CREATE OR REPLACE FUNCTION facility.asset_usable(p_asset uuid, p_what text)
RETURNS void LANGUAGE plpgsql STABLE AS $$
DECLARE a record;
BEGIN
  SELECT s.*, c.is_serviceable INTO a FROM facility.asset s JOIN ref.asset_condition c ON c.id = s.asset_condition_id WHERE s.id = p_asset;
  IF NOT a.is_portable THEN
    RAISE EXCEPTION '%: asset % is not portable', p_what, a.asset_tag USING ERRCODE = 'check_violation';
  END IF;
  IF NOT a.is_active OR NOT a.is_serviceable THEN
    RAISE EXCEPTION '%: asset % is not in service', p_what, a.asset_tag USING ERRCODE = 'check_violation';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION facility.booking_asset_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_occ record;
BEGIN
  PERFORM facility.asset_usable(NEW.asset_id, 'booking_asset');
  SELECT * INTO v_occ FROM facility.booking_occurrence WHERE id = NEW.booking_occurrence_id;
  IF v_occ.cancelled_at IS NOT NULL THEN
    RAISE EXCEPTION 'booking_asset: the booking is cancelled' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_booking_asset_validate BEFORE INSERT ON facility.booking_asset
  FOR EACH ROW EXECUTE FUNCTION facility.booking_asset_validate();

CREATE OR REPLACE FUNCTION facility.booking_asset_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO facility.asset_hold (asset_id, during, booking_asset_id)
  SELECT NEW.asset_id, facility.blocked(o.during, o.setup_minutes, o.teardown_minutes), NEW.id
  FROM facility.booking_occurrence o WHERE o.id = NEW.booking_occurrence_id;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_booking_asset_hold AFTER INSERT ON facility.booking_asset
  FOR EACH ROW EXECUTE FUNCTION facility.booking_asset_hold();

CREATE OR REPLACE FUNCTION facility.asset_loan_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_unit uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.asset_id <> OLD.asset_id OR NEW.borrower_person_id <> OLD.borrower_person_id OR NEW.during <> OLD.during
       OR NEW.issued_by_account_id <> OLD.issued_by_account_id OR OLD.returned_at IS NOT NULL THEN
      RAISE EXCEPTION 'asset_loan: only the return may be recorded' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;
  PERFORM facility.asset_usable(NEW.asset_id, 'asset_loan');
  SELECT custodian_org_unit_id INTO v_unit FROM facility.asset WHERE id = NEW.asset_id;
  IF NOT authz.has_permission(NEW.issued_by_account_id, 'facility.asset_loan.create', v_unit) THEN
    RAISE EXCEPTION 'asset_loan: the issuer may not lend assets of this custodian' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF facility.is_restricted(NEW.borrower_person_id, 'ASSET') THEN
    RAISE EXCEPTION 'asset_loan: the borrower is currently restricted' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_asset_loan_validate BEFORE INSERT OR UPDATE ON facility.asset_loan
  FOR EACH ROW EXECUTE FUNCTION facility.asset_loan_validate();

CREATE OR REPLACE FUNCTION facility.asset_loan_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO facility.asset_hold (asset_id, during, asset_loan_id) VALUES (NEW.asset_id, NEW.during, NEW.id);
  ELSIF NEW.returned_at IS NOT NULL AND NEW.returned_at::timestamp < upper(NEW.during) THEN   -- returned early: free the rest
    UPDATE facility.asset_hold SET during = tsrange(lower(during), greatest(NEW.returned_at::timestamp, lower(during) + interval '1 minute'), '[)')
    WHERE asset_loan_id = NEW.id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_asset_loan_hold AFTER INSERT OR UPDATE OF returned_at ON facility.asset_loan
  FOR EACH ROW EXECUTE FUNCTION facility.asset_loan_hold();

-- ####################################################### MAINTENANCE ##

-- Preventive maintenance: what is serviced how often; the next due date is
-- derived (v_maintenance_due) from last_done_on, which closing a work order
-- of the schedule updates.
CREATE TABLE facility.maintenance_schedule (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id             uuid REFERENCES facility.asset(id) ON DELETE CASCADE,
  room_id              uuid REFERENCES org.room(id) ON DELETE CASCADE,
  maintenance_type_id  smallint NOT NULL REFERENCES ref.maintenance_type(id),
  every                interval NOT NULL CHECK (every > interval '0'),
  last_done_on         date,
  vendor_id            uuid REFERENCES facility.vendor(id),
  note                 text,
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(asset_id, room_id) = 1)
);
SELECT util.attach_updated_at('facility.maintenance_schedule');

-- A reported fault / job on a room or an asset: WO-YYYY-NNNNN, category,
-- priority (with its SLA), reporter, assignee (an employee or a vendor),
-- cost. Its status is the last of its append-only events
-- (v_work_order_status); once closed, nothing changes.
CREATE SEQUENCE facility.work_order_seq;
CREATE TABLE facility.work_order (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wo_no                    citext NOT NULL UNIQUE CHECK (wo_no ~ '^WO-[0-9]{4}-[0-9]{5,}$'),
  room_id                  uuid REFERENCES org.room(id),
  asset_id                 uuid REFERENCES facility.asset(id),
  work_order_category_id   smallint NOT NULL REFERENCES ref.work_order_category(id),
  work_order_priority_id   smallint NOT NULL REFERENCES ref.work_order_priority(id),
  reported_by_person_id    uuid NOT NULL REFERENCES people.person(id),
  description              text NOT NULL CHECK (btrim(description) <> ''),
  reported_at              timestamptz NOT NULL DEFAULT now(),
  assignee_employee_id     uuid REFERENCES people.employee(id),
  vendor_id                uuid REFERENCES facility.vendor(id),
  maintenance_schedule_id  uuid REFERENCES facility.maintenance_schedule(id),
  cost                     numeric(12,2) CHECK (cost >= 0),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_id, asset_id) >= 1)
);
CREATE INDEX work_order_room_idx ON facility.work_order(room_id);
CREATE INDEX work_order_asset_idx ON facility.work_order(asset_id);
CREATE INDEX work_order_assignee_idx ON facility.work_order(assignee_employee_id);
SELECT util.attach_updated_at('facility.work_order');

ALTER TABLE facility.room_service_window
  ADD FOREIGN KEY (work_order_id) REFERENCES facility.work_order(id) ON DELETE SET NULL;

CREATE TABLE facility.work_order_event (
  id                    bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  work_order_id         uuid NOT NULL REFERENCES facility.work_order(id) ON DELETE CASCADE,
  work_order_status_id  smallint NOT NULL REFERENCES ref.work_order_status(id),
  actor_account_id      uuid REFERENCES iam.user_account(id),        -- NULL = the reporter's own report (no account) / a job
  note                  text,
  occurred_at           timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (work_order_id, occurred_at)
);

CREATE OR REPLACE FUNCTION facility.work_order_is_closed(p_wo uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT s.is_terminal FROM facility.work_order_event e JOIN ref.work_order_status s ON s.id = e.work_order_status_id
                   WHERE e.work_order_id = p_wo ORDER BY e.occurred_at DESC, e.id DESC LIMIT 1), false)
$$;

CREATE OR REPLACE FUNCTION facility.work_order_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.wo_no IS NULL THEN
      NEW.wo_no := format('WO-%s-%s', to_char(current_date, 'YYYY'), lpad(nextval('facility.work_order_seq')::text, 5, '0'));
    END IF;
  ELSIF facility.work_order_is_closed(OLD.id) THEN
    RAISE EXCEPTION 'work_order: % is closed', OLD.wo_no USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.asset_id IS NOT NULL AND NEW.room_id IS NULL THEN
    NEW.room_id := (SELECT room_id FROM facility.asset WHERE id = NEW.asset_id);   -- where the asset stands, for the technician
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_work_order_validate BEFORE INSERT OR UPDATE ON facility.work_order
  FOR EACH ROW EXECUTE FUNCTION facility.work_order_validate();

CREATE OR REPLACE FUNCTION facility.work_order_event_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status record; v_wo record;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'work_order_event: events are append-only' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF facility.work_order_is_closed(NEW.work_order_id) THEN
    RAISE EXCEPTION 'work_order_event: the work order is closed' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_status FROM ref.work_order_status WHERE id = NEW.work_order_status_id;
  SELECT * INTO v_wo FROM facility.work_order WHERE id = NEW.work_order_id;
  IF v_status.code = 'ASSIGNED' AND v_wo.assignee_employee_id IS NULL AND v_wo.vendor_id IS NULL THEN
    RAISE EXCEPTION 'work_order_event: assign a technician or a vendor before marking ASSIGNED' USING ERRCODE = 'check_violation';
  END IF;
  IF v_status.is_terminal AND COALESCE(btrim(NEW.note), '') = '' THEN
    RAISE EXCEPTION 'work_order_event: closing needs a note (what was done / why not)' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_work_order_event_validate BEFORE INSERT OR UPDATE OR DELETE ON facility.work_order_event
  FOR EACH ROW EXECUTE FUNCTION facility.work_order_event_validate();

-- Closing a work order releases the rest of its service windows and marks
-- the preventive schedule done.
CREATE OR REPLACE FUNCTION facility.work_order_event_effects()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status record; v_schedule uuid;
BEGIN
  SELECT * INTO v_status FROM ref.work_order_status WHERE id = NEW.work_order_status_id;
  IF v_status.is_terminal THEN
    DELETE FROM facility.room_service_window WHERE work_order_id = NEW.work_order_id AND upper(during) > NEW.occurred_at::timestamp
      AND lower(during) > NEW.occurred_at::timestamp;
    UPDATE facility.room_service_window SET during = tsrange(lower(during), greatest(NEW.occurred_at::timestamp, lower(during) + interval '1 minute'), '[)')
    WHERE work_order_id = NEW.work_order_id AND upper(during) > NEW.occurred_at::timestamp;
    IF v_status.code = 'CLOSED' THEN
      SELECT maintenance_schedule_id INTO v_schedule FROM facility.work_order WHERE id = NEW.work_order_id;
      IF v_schedule IS NOT NULL THEN
        UPDATE facility.maintenance_schedule SET last_done_on = NEW.occurred_at::date WHERE id = v_schedule
          AND (last_done_on IS NULL OR last_done_on < NEW.occurred_at::date);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_work_order_event_effects AFTER INSERT ON facility.work_order_event
  FOR EACH ROW EXECUTE FUNCTION facility.work_order_event_effects();

-- ####################################################### GUEST HOUSE ##

-- A stay in a guest room (room_use GUEST_ROOM) by an internal or external
-- guest (a people.person), hosted by a unit / employee, approved through
-- GUEST_STAY (host unit head → guest house). Nights [check-in day, check-out
-- day) hold the room in the ledger. The charge is derived from guest_tariff
-- (v_guest_stay_charge); invoicing belongs to Finance.
CREATE TABLE facility.guest_stay (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id                   uuid NOT NULL REFERENCES org.room(id),
  guest_person_id           uuid NOT NULL REFERENCES people.person(id),
  guest_category_id         smallint NOT NULL REFERENCES ref.guest_category(id),
  host_org_unit_id          uuid NOT NULL REFERENCES org.org_unit(id),
  host_employee_id          uuid REFERENCES people.employee(id),
  nights                    daterange NOT NULL,
  purpose                   text NOT NULL CHECK (btrim(purpose) <> ''),
  headcount                 smallint NOT NULL DEFAULT 1 CHECK (headcount > 0),
  instance_id               uuid NOT NULL UNIQUE REFERENCES wf.approval_instance(id),
  checked_in_at             timestamptz,
  checked_out_at            timestamptz,
  cancelled_at              timestamptz,
  cancelled_by_account_id   uuid REFERENCES iam.user_account(id),
  booking_cancel_reason_id  smallint REFERENCES ref.booking_cancel_reason(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(nights) AND NOT lower_inf(nights) AND NOT upper_inf(nights)),
  CHECK (checked_out_at IS NULL OR checked_out_at >= checked_in_at),
  CHECK ((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL) AND (cancelled_at IS NULL) = (booking_cancel_reason_id IS NULL))
);
CREATE INDEX guest_stay_room_idx ON facility.guest_stay USING gist (room_id, nights);
CREATE INDEX guest_stay_guest_idx ON facility.guest_stay(guest_person_id);
SELECT util.attach_updated_at('facility.guest_stay');

ALTER TABLE facility.room_hold
  ADD FOREIGN KEY (guest_stay_id) REFERENCES facility.guest_stay(id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION facility.guest_stay_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_room record; v_cat record; v_kind text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.room_id <> OLD.room_id OR NEW.guest_person_id <> OLD.guest_person_id OR NEW.guest_category_id <> OLD.guest_category_id
       OR NEW.host_org_unit_id <> OLD.host_org_unit_id OR NEW.nights <> OLD.nights OR NEW.instance_id <> OLD.instance_id
       OR NEW.headcount <> OLD.headcount OR NEW.purpose <> OLD.purpose THEN
      RAISE EXCEPTION 'guest_stay: a stay is never edited; withdraw it and request again' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF OLD.cancelled_at IS NOT NULL THEN
      RAISE EXCEPTION 'guest_stay: already cancelled' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.checked_in_at IS NOT NULL AND OLD.checked_in_at IS NULL
       AND (SELECT status FROM wf.v_instance_state WHERE instance_id = NEW.instance_id) IS DISTINCT FROM 'APPROVED' THEN
      RAISE EXCEPTION 'guest_stay: the stay is not approved' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  SELECT r.*, u.is_guest_room INTO v_room FROM org.room r LEFT JOIN ref.room_use u ON u.id = r.room_use_id WHERE r.id = NEW.room_id;
  IF NOT COALESCE(v_room.is_guest_room, false) OR NOT v_room.is_active THEN
    RAISE EXCEPTION 'guest_stay: room % is not a guest room', v_room.code USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.headcount > v_room.capacity THEN
    RAISE EXCEPTION 'guest_stay: % guests do not fit in room % (% beds)', NEW.headcount, v_room.code, v_room.capacity USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_cat FROM ref.guest_category WHERE id = NEW.guest_category_id;
  SELECT string_agg(principal_kind, ',') INTO v_kind FROM people.v_person_principal_kind WHERE person_id = NEW.guest_person_id;
  IF v_cat.guest_kind <> 'ANY' AND NOT COALESCE(
       (v_cat.guest_kind = 'EMPLOYEE' AND v_kind LIKE '%EMPLOYEE%')
    OR (v_cat.guest_kind = 'STUDENT' AND v_kind LIKE '%STUDENT%')
    OR (v_cat.guest_kind = 'EXTERNAL' AND v_kind IS NULL), false) THEN
    RAISE EXCEPTION 'guest_stay: the guest is not % (category %)', v_cat.guest_kind, v_cat.code USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id AND dt.code = 'GUEST_STAY'
                 WHERE i.id = NEW.instance_id AND i.owner_org_unit_id = NEW.host_org_unit_id) THEN
    RAISE EXCEPTION 'guest_stay: the round is not a GUEST_STAY round of the host unit' USING ERRCODE = 'check_violation';
  END IF;
  IF facility.is_restricted(NEW.guest_person_id, 'GUEST_ROOM') THEN
    RAISE EXCEPTION 'guest_stay: the guest is currently restricted' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.host_employee_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM people.v_employee_current WHERE employee_id = NEW.host_employee_id) THEN
    RAISE EXCEPTION 'guest_stay: the host is not a current employee' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_guest_stay_validate BEFORE INSERT OR UPDATE ON facility.guest_stay
  FOR EACH ROW EXECUTE FUNCTION facility.guest_stay_validate();

CREATE OR REPLACE FUNCTION facility.guest_stay_hold()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO facility.room_hold (room_id, hold_type_id, during, guest_stay_id)
    VALUES (NEW.room_id, ref.id_of('hold_type', 'GUEST_STAY'), facility.night_span(NEW.nights), NEW.id);
  ELSIF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
    DELETE FROM facility.room_hold WHERE guest_stay_id = NEW.id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_guest_stay_hold AFTER INSERT OR UPDATE OF cancelled_at ON facility.guest_stay
  FOR EACH ROW EXECUTE FUNCTION facility.guest_stay_hold();

-- Nightly rate for a guest category in a room, or in every room of a use
-- (a category flagged complimentary is charged nothing). One rate per target
-- and category at a time. Rates are POLICY.
CREATE TABLE facility.guest_tariff (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id            uuid REFERENCES org.room(id) ON DELETE CASCADE,
  room_use_id        smallint REFERENCES ref.room_use(id),
  guest_category_id  smallint NOT NULL REFERENCES ref.guest_category(id),
  rate_per_night     numeric(10,2) NOT NULL CHECK (rate_per_night >= 0),
  currency           char(3) NOT NULL DEFAULT 'INR' CHECK (currency ~ '^[A-Z]{3}$'),
  valid              daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_id, room_use_id) = 1),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT guest_tariff_one_per_target EXCLUDE USING gist (
    (COALESCE(room_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =, (COALESCE(room_use_id, 0)) WITH =,
    guest_category_id WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.guest_tariff');

-- ############################################################ PARKING ##

-- A parking permit: a person's vehicle in a zone (a room of a PARKING
-- building, capacity = bays) for a period; a zone is never over-allocated.
CREATE TABLE facility.parking_permit (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_room_id             uuid NOT NULL REFERENCES org.room(id),
  person_id                uuid NOT NULL REFERENCES people.person(id) ON DELETE CASCADE,
  vehicle_registration_no  citext NOT NULL CHECK (vehicle_registration_no ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$'),
  parking_permit_type_id   smallint NOT NULL REFERENCES ref.parking_permit_type(id),
  valid                    daterange NOT NULL DEFAULT daterange(current_date, NULL),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT parking_permit_one_per_vehicle EXCLUDE USING gist ((upper(vehicle_registration_no::text)) WITH =, valid WITH &&)
);
CREATE INDEX parking_permit_zone_idx ON facility.parking_permit(zone_room_id);
CREATE INDEX parking_permit_person_idx ON facility.parking_permit(person_id);
SELECT util.attach_updated_at('facility.parking_permit');

CREATE OR REPLACE FUNCTION facility.parking_permit_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_room record; v_used int;
BEGIN
  SELECT r.*, u.is_parking_zone INTO v_room FROM org.room r LEFT JOIN ref.room_use u ON u.id = r.room_use_id WHERE r.id = NEW.zone_room_id;
  IF NOT COALESCE(v_room.is_parking_zone, false) OR NOT v_room.is_active THEN
    RAISE EXCEPTION 'parking_permit: % is not a parking zone', v_room.code USING ERRCODE = 'check_violation';
  END IF;
  -- bays in use on any day of the new permit (permits overlapping it)
  SELECT count(*) INTO v_used FROM facility.parking_permit p WHERE p.zone_room_id = NEW.zone_room_id AND p.id <> NEW.id AND p.valid && NEW.valid;
  IF v_used >= v_room.capacity THEN
    RAISE EXCEPTION 'parking_permit: zone % is full (% bays)', v_room.code, v_room.capacity USING ERRCODE = 'check_violation';
  END IF;
  IF facility.is_restricted(NEW.person_id, 'PARKING') THEN
    RAISE EXCEPTION 'parking_permit: the person is currently restricted' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_parking_permit_validate BEFORE INSERT OR UPDATE ON facility.parking_permit
  FOR EACH ROW EXECUTE FUNCTION facility.parking_permit_validate();

-- ###################################################### FLEET & TRANSPORT ##

-- A university vehicle: registration, type, fuel, seats, the minimum licence
-- class to drive it; retired vehicles stay for the trip history.
CREATE TABLE facility.vehicle (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_no       citext NOT NULL UNIQUE CHECK (registration_no ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}$'),
  vehicle_type_id       smallint NOT NULL REFERENCES ref.vehicle_type(id),
  fuel_type_id          smallint NOT NULL REFERENCES ref.fuel_type(id),
  make_model            text NOT NULL CHECK (btrim(make_model) <> ''),
  seats                 smallint NOT NULL CHECK (seats BETWEEN 1 AND 100),   -- passenger seats, excluding the driver
  min_licence_class_id  smallint NOT NULL REFERENCES ref.licence_class(id),
  custodian_org_unit_id uuid NOT NULL REFERENCES org.org_unit(id),          -- the transport office
  is_active             boolean NOT NULL DEFAULT true,
  retired_on            date,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CHECK (retired_on IS NULL OR NOT is_active)
);
SELECT util.attach_updated_at('facility.vehicle');

-- Registration certificate, insurance, PUC, fitness, permit … with their
-- validity; a trip is never allocated to a vehicle whose mandatory documents
-- do not cover it (v_vehicle_document_status shows what is due).
CREATE TABLE facility.vehicle_document (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id                uuid NOT NULL REFERENCES facility.vehicle(id) ON DELETE CASCADE,
  vehicle_document_type_id  smallint NOT NULL REFERENCES ref.vehicle_document_type(id),
  document_no               text NOT NULL CHECK (btrim(document_no) <> ''),
  valid                     daterange NOT NULL,
  file_object_id            uuid REFERENCES people.file_object(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid) AND NOT upper_inf(valid)),
  CONSTRAINT vehicle_document_one_current EXCLUDE USING gist (vehicle_id WITH =, vehicle_document_type_id WITH =, valid WITH &&)
);

-- Servicing / repair / off-road periods of a vehicle.
CREATE TABLE facility.vehicle_service_window (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id               uuid NOT NULL REFERENCES facility.vehicle(id) ON DELETE CASCADE,
  vehicle_service_type_id  smallint NOT NULL REFERENCES ref.vehicle_service_type(id),
  during                   tsrange NOT NULL,
  note                     text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CONSTRAINT vehicle_service_window_no_overlap EXCLUDE USING gist (vehicle_id WITH =, during WITH &&)
);

-- A driver: an employee with a driving licence (the licence is an identity
-- document of the person, with its expiry — never copied here) of a class.
CREATE TABLE facility.driver (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id          uuid NOT NULL UNIQUE REFERENCES people.employee(id),
  licence_document_id  uuid NOT NULL UNIQUE REFERENCES pii.person_identity_document(id),
  licence_class_id     smallint NOT NULL REFERENCES ref.licence_class(id),
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
SELECT util.attach_updated_at('facility.driver');

CREATE OR REPLACE FUNCTION facility.driver_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pii.person_identity_document d
                 JOIN ref.id_document_type t ON t.id = d.id_document_type_id AND t.code = 'DRIVING_LICENCE'
                 JOIN people.employee e ON e.person_id = d.person_id AND e.id = NEW.employee_id
                 WHERE d.id = NEW.licence_document_id AND d.expires_on IS NOT NULL) THEN
    RAISE EXCEPTION 'driver: the licence must be a DRIVING_LICENCE document of the employee with an expiry date' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_driver_validate BEFORE INSERT OR UPDATE ON facility.driver
  FOR EACH ROW EXECUTE FUNCTION facility.driver_validate();

-- Leave, sickness, other duty … (reason lookup; no free text about health).
CREATE TABLE facility.driver_unavailability (
  id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id                       uuid NOT NULL REFERENCES facility.driver(id) ON DELETE CASCADE,
  driver_unavailability_reason_id smallint NOT NULL REFERENCES ref.driver_unavailability_reason(id),
  during                          tsrange NOT NULL,
  created_at                      timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CONSTRAINT driver_unavailability_no_overlap EXCLUDE USING gist (driver_id WITH =, during WITH &&)
);

-- Transport rules (NULL unit = university default): what counts as urgent,
-- when an undecided request is auto-approved, when the alert goes out, the
-- largest party, the minimum notice. Values are POLICY.
CREATE TABLE facility.transport_policy (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id          uuid REFERENCES org.org_unit(id) ON DELETE CASCADE,
  valid                daterange NOT NULL DEFAULT daterange('2000-01-01', NULL),
  urgent_threshold     interval NOT NULL CHECK (urgent_threshold > interval '0'),      -- departure closer than this = urgent (skips the unit head)
  auto_approve_before  interval NOT NULL CHECK (auto_approve_before > interval '0'),   -- undecided this close to departure → system AUTO_APPROVE
  alert_before         interval NOT NULL CHECK (alert_before > interval '0'),          -- unallocated this close to departure → alert
  max_headcount        smallint NOT NULL CHECK (max_headcount BETWEEN 1 AND 100),
  min_notice           interval NOT NULL DEFAULT interval '0',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(valid) AND NOT lower_inf(valid)),
  CONSTRAINT transport_policy_one_per_scope EXCLUDE USING gist (
    (COALESCE(org_unit_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =, valid WITH &&)
);
SELECT util.attach_updated_at('facility.transport_policy');

CREATE OR REPLACE FUNCTION facility.transport_policy_for(p_unit uuid, p_date date DEFAULT current_date)
RETURNS facility.transport_policy LANGUAGE plpgsql STABLE AS $$
DECLARE v facility.transport_policy;
BEGIN
  SELECT p.* INTO v FROM facility.transport_policy p
  LEFT JOIN org.ancestors(p_unit) a ON a.org_unit_id = p.org_unit_id
  WHERE p.valid @> p_date AND (p.org_unit_id IS NULL OR a.org_unit_id IS NOT NULL)
  ORDER BY a.depth NULLS LAST LIMIT 1;
  IF v.id IS NULL THEN
    RAISE EXCEPTION 'transport_policy: no policy is configured' USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v;
END $$;

-- A request for a vehicle: who, for which unit, why, from where to where
-- (text + coordinates), departure → expected return, party size, a contact
-- number for the driver. Approved through TRIP_REQUEST (unit head →
-- transport) or, when departure is within the urgent threshold,
-- TRIP_REQUEST_URGENT (transport only). Immutable; cancellable until a
-- vehicle / driver is allocated.
CREATE TABLE facility.trip_request (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_person_id      uuid NOT NULL REFERENCES people.person(id),
  on_behalf_org_unit_id    uuid NOT NULL REFERENCES org.org_unit(id),
  trip_purpose_id          smallint NOT NULL REFERENCES ref.trip_purpose(id),
  event_request_id         uuid REFERENCES facility.event_request(id),
  during                   tsrange NOT NULL,                              -- departure → expected return
  origin_text              text NOT NULL CHECK (btrim(origin_text) <> ''),
  destination_text         text NOT NULL CHECK (btrim(destination_text) <> ''),
  origin_lat               numeric(9,6) CHECK (origin_lat BETWEEN -90 AND 90),
  origin_lon               numeric(9,6) CHECK (origin_lon BETWEEN -180 AND 180),
  destination_lat          numeric(9,6) CHECK (destination_lat BETWEEN -90 AND 90),
  destination_lon          numeric(9,6) CHECK (destination_lon BETWEEN -180 AND 180),
  estimated_km             numeric(7,1) CHECK (estimated_km >= 0),
  estimated_minutes        int CHECK (estimated_minutes >= 0),
  headcount                smallint NOT NULL CHECK (headcount BETWEEN 1 AND 100),
  contact_phone            varchar(16) NOT NULL CHECK (contact_phone ~ '^\+[1-9][0-9]{7,14}$'),   -- E.164
  note                     text,
  instance_id              uuid NOT NULL UNIQUE REFERENCES wf.approval_instance(id),
  cancelled_at             timestamptz,
  cancelled_by_account_id  uuid REFERENCES iam.user_account(id),
  trip_cancel_reason_id    smallint REFERENCES ref.trip_cancel_reason(id),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK ((origin_lat IS NULL) = (origin_lon IS NULL) AND (destination_lat IS NULL) = (destination_lon IS NULL)),
  CHECK ((cancelled_at IS NULL) = (cancelled_by_account_id IS NULL) AND (cancelled_at IS NULL) = (trip_cancel_reason_id IS NULL))
);
CREATE INDEX trip_request_unit_idx ON facility.trip_request(on_behalf_org_unit_id);
CREATE INDEX trip_request_requester_idx ON facility.trip_request(requester_person_id);
CREATE INDEX trip_request_during_idx ON facility.trip_request USING gist (during);
SELECT util.attach_updated_at('facility.trip_request');

-- Dispatch: a driver (first), then a vehicle, for a window covering the
-- request. Neither a driver nor a vehicle is ever double-allocated; the
-- vehicle's documents, the driver's licence (class, expiry), service windows
-- and unavailability are all checked. Token hashes let the driver start /
-- complete the trip from a link without a portal login. Released = undone
-- (re-allocated / cancelled) — kept for the record.
CREATE TABLE facility.trip_allocation (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_request_id          uuid NOT NULL REFERENCES facility.trip_request(id),
  driver_id                uuid NOT NULL REFERENCES facility.driver(id),
  vehicle_id               uuid REFERENCES facility.vehicle(id),       -- NULL until the vehicle is assigned (pending-driver stage)
  during                   tsrange NOT NULL,                             -- dispatch window (⊇ the request's)
  allocated_by_account_id  uuid NOT NULL REFERENCES iam.user_account(id),
  allocated_at             timestamptz NOT NULL DEFAULT now(),
  start_token_hash         bytea CHECK (octet_length(start_token_hash) = 32),
  complete_token_hash      bytea CHECK (octet_length(complete_token_hash) = 32),
  released_at              timestamptz,
  released_by_account_id   uuid REFERENCES iam.user_account(id),
  note                     text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT isempty(during) AND NOT lower_inf(during) AND NOT upper_inf(during)),
  CHECK ((released_at IS NULL) = (released_by_account_id IS NULL)),
  CONSTRAINT trip_allocation_driver_once EXCLUDE USING gist (driver_id WITH =, during WITH &&) WHERE (released_at IS NULL),
  CONSTRAINT trip_allocation_vehicle_once EXCLUDE USING gist (vehicle_id WITH =, during WITH &&) WHERE (released_at IS NULL AND vehicle_id IS NOT NULL)
);
CREATE UNIQUE INDEX trip_allocation_one_live ON facility.trip_allocation(trip_request_id) WHERE released_at IS NULL;
CREATE INDEX trip_allocation_vehicle_idx ON facility.trip_allocation(vehicle_id);
SELECT util.attach_updated_at('facility.trip_allocation');

-- Pooling: another approved request that rides on an existing allocation
-- (same direction, inside its window, seats permitting).
CREATE TABLE facility.trip_allocation_request (
  trip_allocation_id  uuid NOT NULL REFERENCES facility.trip_allocation(id) ON DELETE CASCADE,
  trip_request_id     uuid NOT NULL REFERENCES facility.trip_request(id),
  added_by_account_id uuid NOT NULL REFERENCES iam.user_account(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (trip_allocation_id, trip_request_id),
  UNIQUE (trip_request_id)
);

-- Everyone an allocation carries: its own request plus pooled ones.
CREATE OR REPLACE FUNCTION facility.allocation_headcount(p_allocation uuid, p_extra_request uuid DEFAULT NULL)
RETURNS int LANGUAGE sql STABLE AS $$
  SELECT COALESCE(sum(tr.headcount), 0)::int
  FROM facility.trip_request tr
  WHERE tr.cancelled_at IS NULL
    AND (tr.id = (SELECT trip_request_id FROM facility.trip_allocation WHERE id = p_allocation)
         OR tr.id IN (SELECT trip_request_id FROM facility.trip_allocation_request WHERE trip_allocation_id = p_allocation)
         OR tr.id = p_extra_request)
$$;

CREATE OR REPLACE FUNCTION facility.trip_request_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_inst record; v_pol facility.transport_policy;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.requester_person_id <> OLD.requester_person_id OR NEW.on_behalf_org_unit_id <> OLD.on_behalf_org_unit_id
       OR NEW.trip_purpose_id <> OLD.trip_purpose_id OR NEW.during <> OLD.during OR NEW.origin_text <> OLD.origin_text
       OR NEW.destination_text <> OLD.destination_text OR NEW.headcount <> OLD.headcount OR NEW.contact_phone <> OLD.contact_phone
       OR NEW.instance_id <> OLD.instance_id OR NEW.note IS DISTINCT FROM OLD.note OR NEW.event_request_id IS DISTINCT FROM OLD.event_request_id THEN
      RAISE EXCEPTION 'trip_request: a request is never edited; withdraw it and submit again' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
      IF EXISTS (SELECT 1 FROM facility.trip_allocation a WHERE a.trip_request_id = NEW.id AND a.released_at IS NULL)
         OR EXISTS (SELECT 1 FROM facility.trip_allocation_request ar JOIN facility.trip_allocation a ON a.id = ar.trip_allocation_id AND a.released_at IS NULL
                    WHERE ar.trip_request_id = NEW.id) THEN
        RAISE EXCEPTION 'trip_request: a vehicle is already allocated; ask the transport office to release it first' USING ERRCODE = 'check_violation';
      END IF;
    ELSIF OLD.cancelled_at IS NOT NULL THEN
      RAISE EXCEPTION 'trip_request: already cancelled' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  SELECT i.owner_org_unit_id, i.submitted_by_account_id, i.submitted_at, dt.code AS doc INTO v_inst
  FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id WHERE i.id = NEW.instance_id;
  IF v_inst.doc IS NULL OR v_inst.doc NOT IN ('TRIP_REQUEST', 'TRIP_REQUEST_URGENT') OR v_inst.owner_org_unit_id <> NEW.on_behalf_org_unit_id THEN
    RAISE EXCEPTION 'trip_request: the round is not a TRIP_REQUEST round of the requesting unit' USING ERRCODE = 'check_violation';
  END IF;
  v_pol := facility.transport_policy_for(NEW.on_behalf_org_unit_id);
  IF (v_inst.doc = 'TRIP_REQUEST_URGENT') <> (lower(NEW.during) < (v_inst.submitted_at + v_pol.urgent_threshold)::timestamp) THEN
    RAISE EXCEPTION 'trip_request: departure within % of submission is urgent (TRIP_REQUEST_URGENT), later is not', v_pol.urgent_threshold
      USING ERRCODE = 'check_violation';
  END IF;
  IF lower(NEW.during) < (v_inst.submitted_at + v_pol.min_notice)::timestamp THEN
    RAISE EXCEPTION 'trip_request: departure is in the past or within the minimum notice of %', v_pol.min_notice USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.headcount > v_pol.max_headcount THEN
    RAISE EXCEPTION 'trip_request: at most % people per request', v_pol.max_headcount USING ERRCODE = 'check_violation';
  END IF;
  IF facility.is_restricted(NEW.requester_person_id, 'VEHICLE') THEN
    RAISE EXCEPTION 'trip_request: the requester is currently restricted from booking vehicles' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM iam.user_account WHERE id = v_inst.submitted_by_account_id AND person_id = NEW.requester_person_id)
     AND NOT authz.has_permission(v_inst.submitted_by_account_id, 'facility.trip.update', NEW.on_behalf_org_unit_id) THEN
    RAISE EXCEPTION 'trip_request: only the requester, or transport staff, may submit on their behalf' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_trip_request_validate BEFORE INSERT OR UPDATE ON facility.trip_request
  FOR EACH ROW EXECUTE FUNCTION facility.trip_request_validate();

-- Is the vehicle roadworthy for the window: active, every mandatory document
-- valid throughout, no service window?
CREATE OR REPLACE FUNCTION facility.vehicle_available(p_vehicle uuid, p_during tsrange, OUT ok boolean, OUT why text)
LANGUAGE plpgsql STABLE AS $$
DECLARE v record;
BEGIN
  ok := true;
  SELECT * INTO v FROM facility.vehicle WHERE id = p_vehicle;
  IF NOT v.is_active THEN ok := false; why := 'vehicle is not active'; RETURN; END IF;
  SELECT 'document ' || t.code || ' does not cover the trip' INTO why
  FROM ref.vehicle_document_type t
  WHERE t.is_mandatory_for_trip AND t.is_active
    AND NOT EXISTS (SELECT 1 FROM facility.vehicle_document d WHERE d.vehicle_id = p_vehicle AND d.vehicle_document_type_id = t.id
                    AND d.valid @> daterange(lower(p_during)::date, upper(p_during)::date, '[]'))
  ORDER BY t.sort_order LIMIT 1;
  IF why IS NOT NULL THEN ok := false; RETURN; END IF;
  IF EXISTS (SELECT 1 FROM facility.vehicle_service_window w WHERE w.vehicle_id = p_vehicle AND w.during && p_during) THEN
    ok := false; why := 'vehicle is in service'; RETURN;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION facility.trip_allocation_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_req record; v_drv record; v_veh record; v_avail record; v_status text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.trip_request_id <> OLD.trip_request_id OR NEW.driver_id <> OLD.driver_id OR NEW.during <> OLD.during
       OR (OLD.vehicle_id IS NOT NULL AND NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id) THEN
      RAISE EXCEPTION 'trip_allocation: release the allocation and allocate again' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF OLD.released_at IS NOT NULL THEN
      RAISE EXCEPTION 'trip_allocation: already released' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.released_at IS NOT NULL AND EXISTS (SELECT 1 FROM facility.trip t WHERE t.trip_allocation_id = NEW.id AND t.started_at IS NOT NULL) THEN
      RAISE EXCEPTION 'trip_allocation: the trip has started' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  SELECT tr.*, s.status INTO v_req FROM facility.trip_request tr JOIN wf.v_instance_state s ON s.instance_id = tr.instance_id WHERE tr.id = NEW.trip_request_id;
  IF TG_OP = 'INSERT' OR NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id THEN
    IF v_req.status <> 'APPROVED' OR v_req.cancelled_at IS NOT NULL THEN
      RAISE EXCEPTION 'trip_allocation: the request is not approved (%)', COALESCE(v_req.status, 'cancelled') USING ERRCODE = 'check_violation';
    END IF;
    IF NOT (NEW.during @> v_req.during) THEN
      RAISE EXCEPTION 'trip_allocation: the dispatch window must cover the requested %', v_req.during USING ERRCODE = 'check_violation';
    END IF;
    IF NOT authz.has_permission(NEW.allocated_by_account_id, 'facility.trip_allocation.assign', v_req.on_behalf_org_unit_id) THEN
      RAISE EXCEPTION 'trip_allocation: the allocator is not transport staff' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT d.*, doc.expires_on, lc.rank AS licence_rank INTO v_drv
    FROM facility.driver d JOIN pii.person_identity_document doc ON doc.id = d.licence_document_id
    JOIN ref.licence_class lc ON lc.id = d.licence_class_id WHERE d.id = NEW.driver_id;
    IF NOT v_drv.is_active THEN
      RAISE EXCEPTION 'trip_allocation: the driver is not active' USING ERRCODE = 'check_violation';
    END IF;
    IF v_drv.expires_on < upper(NEW.during)::date THEN
      RAISE EXCEPTION 'trip_allocation: the driver''s licence expires on %, before the trip ends', v_drv.expires_on USING ERRCODE = 'check_violation';
    END IF;
    IF EXISTS (SELECT 1 FROM facility.driver_unavailability u WHERE u.driver_id = NEW.driver_id AND u.during && NEW.during) THEN
      RAISE EXCEPTION 'trip_allocation: the driver is unavailable then' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.vehicle_id IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.vehicle_id IS NULL) THEN
    SELECT v.*, lc.rank AS min_rank INTO v_veh FROM facility.vehicle v JOIN ref.licence_class lc ON lc.id = v.min_licence_class_id WHERE v.id = NEW.vehicle_id;
    SELECT * INTO v_avail FROM facility.vehicle_available(NEW.vehicle_id, NEW.during);
    IF NOT v_avail.ok THEN
      RAISE EXCEPTION 'trip_allocation: %', v_avail.why USING ERRCODE = 'check_violation';
    END IF;
    IF v_veh.seats < facility.allocation_headcount(NEW.id, NEW.trip_request_id) THEN
      RAISE EXCEPTION 'trip_allocation: % seats for % passengers', v_veh.seats, facility.allocation_headcount(NEW.id, NEW.trip_request_id)
        USING ERRCODE = 'check_violation';
    END IF;
    IF (SELECT lc.rank FROM facility.driver d JOIN ref.licence_class lc ON lc.id = d.licence_class_id WHERE d.id = NEW.driver_id) < v_veh.min_rank THEN
      RAISE EXCEPTION 'trip_allocation: the driver''s licence class does not cover this vehicle' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_trip_allocation_validate BEFORE INSERT OR UPDATE ON facility.trip_allocation
  FOR EACH ROW EXECUTE FUNCTION facility.trip_allocation_validate();

CREATE OR REPLACE FUNCTION facility.trip_allocation_request_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_alloc record; v_req record; v_seats int;
BEGIN
  SELECT a.*, v.seats INTO v_alloc FROM facility.trip_allocation a LEFT JOIN facility.vehicle v ON v.id = a.vehicle_id WHERE a.id = NEW.trip_allocation_id;
  SELECT tr.*, s.status INTO v_req FROM facility.trip_request tr JOIN wf.v_instance_state s ON s.instance_id = tr.instance_id WHERE tr.id = NEW.trip_request_id;
  IF v_alloc.released_at IS NOT NULL OR v_alloc.vehicle_id IS NULL THEN
    RAISE EXCEPTION 'trip_allocation_request: pooling needs a live allocation with a vehicle' USING ERRCODE = 'check_violation';
  END IF;
  IF v_req.status <> 'APPROVED' OR v_req.cancelled_at IS NOT NULL THEN
    RAISE EXCEPTION 'trip_allocation_request: the pooled request is not approved' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM facility.trip_allocation a WHERE a.trip_request_id = NEW.trip_request_id AND a.released_at IS NULL) THEN
    RAISE EXCEPTION 'trip_allocation_request: the request already has its own allocation' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (v_alloc.during @> v_req.during) THEN
    RAISE EXCEPTION 'trip_allocation_request: the pooled trip must fit inside the allocation window' USING ERRCODE = 'check_violation';
  END IF;
  IF v_alloc.seats < facility.allocation_headcount(NEW.trip_allocation_id, NEW.trip_request_id) THEN
    RAISE EXCEPTION 'trip_allocation_request: not enough seats' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT authz.has_permission(NEW.added_by_account_id, 'facility.trip_allocation.assign', v_req.on_behalf_org_unit_id) THEN
    RAISE EXCEPTION 'trip_allocation_request: only transport staff pool trips' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_trip_allocation_request_validate BEFORE INSERT OR UPDATE ON facility.trip_allocation_request
  FOR EACH ROW EXECUTE FUNCTION facility.trip_allocation_request_validate();

-- What happened on the road: start (odometer, pickup photo), completion,
-- closure by the transport office.
CREATE TABLE facility.trip (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_allocation_id    uuid NOT NULL UNIQUE REFERENCES facility.trip_allocation(id),
  started_at            timestamptz,
  start_odometer_km     int CHECK (start_odometer_km >= 0),
  pickup_photo_file_id  uuid REFERENCES people.file_object(id),
  completed_at          timestamptz,
  end_odometer_km       int CHECK (end_odometer_km >= 0),
  closed_at             timestamptz,
  closed_by_account_id  uuid REFERENCES iam.user_account(id),
  note                  text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CHECK ((started_at IS NULL) = (start_odometer_km IS NULL)),
  CHECK (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at AND end_odometer_km IS NOT NULL)),
  CHECK (end_odometer_km IS NULL OR end_odometer_km >= start_odometer_km),
  CHECK ((closed_at IS NULL) = (closed_by_account_id IS NULL) AND (closed_at IS NULL OR completed_at IS NOT NULL))
);
SELECT util.attach_updated_at('facility.trip');

CREATE OR REPLACE FUNCTION facility.trip_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_alloc record;
BEGIN
  SELECT * INTO v_alloc FROM facility.trip_allocation WHERE id = NEW.trip_allocation_id;
  IF v_alloc.released_at IS NOT NULL OR v_alloc.vehicle_id IS NULL THEN
    RAISE EXCEPTION 'trip: the allocation has no vehicle or was released' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.closed_at IS NOT NULL THEN
      RAISE EXCEPTION 'trip: closed trips are final' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.started_at IS NOT NULL AND (NEW.started_at <> OLD.started_at OR NEW.start_odometer_km <> OLD.start_odometer_km) THEN
      RAISE EXCEPTION 'trip: the start is recorded once' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.closed_at IS NOT NULL AND NOT authz.has_permission(NEW.closed_by_account_id, 'facility.trip.update',
         (SELECT on_behalf_org_unit_id FROM facility.trip_request WHERE id = v_alloc.trip_request_id)) THEN
      RAISE EXCEPTION 'trip: only transport staff close a trip' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_trip_validate BEFORE INSERT OR UPDATE ON facility.trip
  FOR EACH ROW EXECUTE FUNCTION facility.trip_validate();

-- Feedback after a completed trip: passengers rate the driver, the driver
-- rates the passengers (1–5, one each per trip).
CREATE TABLE facility.trip_rating (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id             uuid NOT NULL REFERENCES facility.trip(id) ON DELETE CASCADE,
  rating_role_id      smallint NOT NULL REFERENCES ref.rating_role(id),
  rated_by_person_id  uuid NOT NULL REFERENCES people.person(id),
  rating              smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment             text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trip_id, rating_role_id, rated_by_person_id)
);

CREATE OR REPLACE FUNCTION facility.trip_rating_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_trip record; v_role text; v_is_passenger boolean; v_is_driver boolean;
BEGIN
  SELECT t.completed_at, a.driver_id, a.id AS allocation_id INTO v_trip
  FROM facility.trip t JOIN facility.trip_allocation a ON a.id = t.trip_allocation_id WHERE t.id = NEW.trip_id;
  IF v_trip.completed_at IS NULL THEN
    RAISE EXCEPTION 'trip_rating: the trip is not complete' USING ERRCODE = 'check_violation';
  END IF;
  SELECT code INTO v_role FROM ref.rating_role WHERE id = NEW.rating_role_id;
  v_is_passenger := EXISTS (SELECT 1 FROM facility.trip_request tr WHERE tr.requester_person_id = NEW.rated_by_person_id
                            AND (tr.id = (SELECT trip_request_id FROM facility.trip_allocation WHERE id = v_trip.allocation_id)
                                 OR tr.id IN (SELECT trip_request_id FROM facility.trip_allocation_request WHERE trip_allocation_id = v_trip.allocation_id)));
  v_is_driver := EXISTS (SELECT 1 FROM facility.driver d JOIN people.employee e ON e.id = d.employee_id
                         WHERE d.id = v_trip.driver_id AND e.person_id = NEW.rated_by_person_id);
  IF (v_role = 'PASSENGER' AND NOT v_is_passenger) OR (v_role = 'DRIVER' AND NOT v_is_driver) THEN
    RAISE EXCEPTION 'trip_rating: only the trip''s passengers and driver may rate it' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_trip_rating_validate BEFORE INSERT OR UPDATE ON facility.trip_rating
  FOR EACH ROW EXECUTE FUNCTION facility.trip_rating_validate();

-- Alerts raised by the escalation job (run_trip_escalations [09]): one of a
-- kind per request.
CREATE TABLE facility.trip_alert (
  id                  bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  trip_request_id     uuid NOT NULL REFERENCES facility.trip_request(id) ON DELETE CASCADE,
  trip_alert_type_id  smallint NOT NULL REFERENCES ref.trip_alert_type(id),
  raised_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trip_request_id, trip_alert_type_id)
);

-- ############################################################## KEYS ##

-- A physical key or access card opening a room, a floor or a building; kept
-- by a custodian unit; lost / replaced handling.
CREATE TABLE facility.key_item (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key_code                  citext NOT NULL UNIQUE CHECK (key_code ~ '^[A-Za-z0-9/_-]{2,40}$'),
  key_kind_id               smallint NOT NULL REFERENCES ref.key_kind(id),
  room_id                   uuid REFERENCES org.room(id) ON DELETE CASCADE,
  floor_id                  uuid REFERENCES org.floor(id) ON DELETE CASCADE,
  building_id               uuid REFERENCES org.building(id) ON DELETE CASCADE,
  custodian_org_unit_id     uuid NOT NULL REFERENCES org.org_unit(id),
  is_active                 boolean NOT NULL DEFAULT true,
  lost_reported_at          timestamptz,
  replaced_by_key_item_id   uuid REFERENCES facility.key_item(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(room_id, floor_id, building_id) = 1),
  CHECK (replaced_by_key_item_id IS NULL OR NOT is_active),
  CHECK (replaced_by_key_item_id IS DISTINCT FROM id)
);
SELECT util.attach_updated_at('facility.key_item');

-- The issue register: who holds which key from when; one holder at a time;
-- returns recorded against the issue.
CREATE TABLE facility.key_issue (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key_item_id             uuid NOT NULL REFERENCES facility.key_item(id),
  holder_person_id        uuid NOT NULL REFERENCES people.person(id),
  issued_by_account_id    uuid NOT NULL REFERENCES iam.user_account(id),
  issued_at               timestamptz NOT NULL DEFAULT now(),
  due_back_at             timestamptz,
  returned_at             timestamptz,
  returned_to_account_id  uuid REFERENCES iam.user_account(id),
  note                    text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CHECK ((returned_at IS NULL) = (returned_to_account_id IS NULL)),
  CHECK (returned_at IS NULL OR returned_at >= issued_at),
  CHECK (due_back_at IS NULL OR due_back_at > issued_at),
  CONSTRAINT key_issue_one_holder EXCLUDE USING gist (key_item_id WITH =, tstzrange(issued_at, returned_at, '[)') WITH &&)
);
CREATE INDEX key_issue_holder_idx ON facility.key_issue(holder_person_id);
SELECT util.attach_updated_at('facility.key_issue');

CREATE OR REPLACE FUNCTION facility.key_issue_validate()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_key record;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.key_item_id <> OLD.key_item_id OR NEW.holder_person_id <> OLD.holder_person_id OR NEW.issued_at <> OLD.issued_at
       OR NEW.issued_by_account_id <> OLD.issued_by_account_id OR OLD.returned_at IS NOT NULL THEN
      RAISE EXCEPTION 'key_issue: only the return (and the due date) may be recorded' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;
  SELECT * INTO v_key FROM facility.key_item WHERE id = NEW.key_item_id;
  IF NOT v_key.is_active OR v_key.lost_reported_at IS NOT NULL THEN
    RAISE EXCEPTION 'key_issue: key % is not in service', v_key.key_code USING ERRCODE = 'check_violation';
  END IF;
  IF NOT authz.has_permission(NEW.issued_by_account_id, 'facility.key.issue', v_key.custodian_org_unit_id) THEN
    RAISE EXCEPTION 'key_issue: the issuer is not a key custodian of %', v_key.key_code USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF facility.is_restricted(NEW.holder_person_id, 'KEY') THEN
    RAISE EXCEPTION 'key_issue: the holder is currently restricted' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_key_issue_validate BEFORE INSERT OR UPDATE ON facility.key_issue
  FOR EACH ROW EXECUTE FUNCTION facility.key_issue_validate();

-- ################################################## WORKFLOW HOOKS (wf) ##

-- Before an action: nobody approves a booking whose every occurrence has
-- already ended (the old "no action on expired").
CREATE OR REPLACE FUNCTION facility.approval_action_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_type record; v_doc text;
BEGIN
  SELECT * INTO v_type FROM ref.wf_action_type WHERE id = NEW.wf_action_type_id;
  IF NOT v_type.completes_step THEN RETURN NEW; END IF;
  SELECT dt.code INTO v_doc FROM wf.approval_instance i JOIN wf.approval_document_type dt ON dt.id = i.document_type_id WHERE i.id = NEW.instance_id;
  IF v_doc IN ('ROOM_BOOKING', 'ROOM_BOOKING_CHANGE') AND NOT EXISTS (
       SELECT 1 FROM facility.booking_occurrence o JOIN facility.booking_request br ON br.id = o.booking_request_id
       WHERE br.instance_id = NEW.instance_id AND o.cancelled_at IS NULL AND upper(o.during) > localtimestamp) THEN
    RAISE EXCEPTION 'wf.approval_action: this booking has expired (every occurrence has ended)' USING ERRCODE = 'check_violation';
  END IF;
  IF v_doc = 'GUEST_STAY' AND EXISTS (SELECT 1 FROM facility.guest_stay g WHERE g.instance_id = NEW.instance_id AND upper(g.nights) <= current_date) THEN
    RAISE EXCEPTION 'wf.approval_action: this stay has passed' USING ERRCODE = 'check_violation';
  END IF;
  IF v_doc IN ('TRIP_REQUEST', 'TRIP_REQUEST_URGENT') AND EXISTS (
       SELECT 1 FROM facility.trip_request t WHERE t.instance_id = NEW.instance_id AND (t.cancelled_at IS NOT NULL OR upper(t.during) <= localtimestamp)) THEN
    RAISE EXCEPTION 'wf.approval_action: this trip request is cancelled or expired' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_facility_action_guard BEFORE INSERT ON wf.approval_action
  FOR EACH ROW EXECUTE FUNCTION facility.approval_action_guard();

-- After an action: a closed round (RETURN / WITHDRAW) releases the tentative
-- holds; an approved reschedule cancels the original occurrence; an approved
-- event submits its waiting room requests to their custodians.
CREATE OR REPLACE FUNCTION facility.approval_action_effects()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_type record; v_state record; v_req record; v_orig uuid; v_unit uuid;
BEGIN
  SELECT * INTO v_type FROM ref.wf_action_type WHERE id = NEW.wf_action_type_id;
  SELECT * INTO v_state FROM wf.v_instance_state WHERE instance_id = NEW.instance_id;
  IF v_type.closes_instance THEN
    DELETE FROM facility.room_hold WHERE booking_occurrence_id IN (
      SELECT o.id FROM facility.booking_occurrence o JOIN facility.booking_request br ON br.id = o.booking_request_id
      WHERE br.instance_id = NEW.instance_id
         OR (br.instance_id IS NULL AND br.event_request_id = (SELECT id FROM facility.event_request WHERE instance_id = NEW.instance_id)));
    DELETE FROM facility.asset_hold WHERE booking_asset_id IN (
      SELECT ba.id FROM facility.booking_asset ba JOIN facility.booking_occurrence o ON o.id = ba.booking_occurrence_id
      JOIN facility.booking_request br ON br.id = o.booking_request_id
      WHERE br.instance_id = NEW.instance_id
         OR (br.instance_id IS NULL AND br.event_request_id = (SELECT id FROM facility.event_request WHERE instance_id = NEW.instance_id)));
    DELETE FROM facility.room_hold WHERE guest_stay_id IN (SELECT id FROM facility.guest_stay WHERE instance_id = NEW.instance_id);
    RETURN NULL;
  END IF;
  IF v_state.status = 'APPROVED' THEN
    IF v_state.document_type = 'ROOM_BOOKING_CHANGE' THEN
      SELECT rescheduled_from_occurrence_id INTO v_orig FROM facility.booking_request WHERE instance_id = NEW.instance_id;
      UPDATE facility.booking_occurrence
         SET cancelled_at = now(), cancelled_by_account_id = COALESCE(NEW.actor_account_id, v_state.submitted_by_account_id),
             booking_cancel_reason_id = ref.id_of('booking_cancel_reason', 'RESCHEDULED')
       WHERE id = v_orig AND cancelled_at IS NULL;
    ELSIF v_state.document_type IN ('EVENT_REQUEST', 'EVENT_PROPOSAL', 'EVENT_CHANGE') THEN      -- a facility package of its own, or one owned by an event proposal / a change of its dates
      FOR v_req IN
        SELECT br.*, (SELECT facility.custodian_of(o.room_id, lower(o.during)::date) FROM facility.booking_occurrence o
                      WHERE o.booking_request_id = br.id ORDER BY lower(o.during) LIMIT 1) AS custodian
        FROM facility.booking_request br JOIN facility.event_request ev ON ev.id = br.event_request_id
        WHERE ev.instance_id = NEW.instance_id AND br.instance_id IS NULL
      LOOP
        IF v_req.custodian IS NULL THEN CONTINUE; END IF;
        UPDATE facility.booking_request SET instance_id = wf.submit('ROOM_BOOKING', v_req.custodian, v_state.submitted_by_account_id, v_req.note)
        WHERE id = v_req.id;
      END LOOP;
    END IF;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_facility_action_effects AFTER INSERT ON wf.approval_action
  FOR EACH ROW EXECUTE FUNCTION facility.approval_action_effects();
