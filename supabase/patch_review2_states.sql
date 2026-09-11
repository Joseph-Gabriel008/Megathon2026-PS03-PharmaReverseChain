-- ============================================================
-- MediLoop — Review 2 Schema Patch: States + Columns
-- Purpose: Add new lifecycle states, multi-origin columns,
--          bilateral confirmation, and evidence tables.
-- Run AFTER schema.sql and schema_patch.sql.
-- Idempotent: safe to run multiple times.
-- ============================================================

-- ─── 1. Extend batch_status enum ─────────────────────────────────────────────

-- Note: Postgres requires a separate ADD VALUE call per value.
-- IF NOT EXISTS guard requires Postgres 14+.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'RETURN_DECLARED' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'RETURN_DECLARED';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'MFG_DIRECT_DISPOSAL' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'MFG_DIRECT_DISPOSAL';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'DIST_DIRECT_DISPOSAL' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'DIST_DIRECT_DISPOSAL';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'DESTRUCTION_RECORDED' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'DESTRUCTION_RECORDED';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'CERTIFICATION_PENDING' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'CERTIFICATION_PENDING';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'CERTIFIED' AND enumtypid = 'batch_status'::regtype) THEN
    ALTER TYPE batch_status ADD VALUE 'CERTIFIED';
  END IF;
END $$;

-- ─── 2. New columns on medicine_batches ──────────────────────────────────────

ALTER TABLE medicine_batches
  ADD COLUMN IF NOT EXISTS origination_path text
    CHECK (origination_path IN ('RETAIL_RETURN', 'DISTRIBUTOR_SELF', 'MANUFACTURER_SELF')),
  ADD COLUMN IF NOT EXISTS current_custodian uuid REFERENCES organizations(id),
  ADD COLUMN IF NOT EXISTS verification_state text NOT NULL DEFAULT 'DECLARED'
    CHECK (verification_state IN ('DECLARED', 'PENDING_VERIFICATION', 'VERIFIED', 'EXCEPTION', 'CERTIFIED'));

-- Audit/random audit columns
ALTER TABLE medicine_batches
  ADD COLUMN IF NOT EXISTS audit_flag   boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS audit_status text
    CHECK (audit_status IN ('REQUIRED', 'IN_PROGRESS', 'PASSED', 'DISCREPANCY'));

-- ─── 3. New lifecycle_transitions rows ───────────────────────────────────────

-- Pharmacy → RETURN_DECLARED (replaces direct RETURN_INITIATED as single step)
INSERT INTO lifecycle_transitions (from_status, to_status, allowed_role)
VALUES
  ('ACTIVE',               'RETURN_DECLARED',      'PHARMACY'),
  ('EXPIRING_SOON',        'RETURN_DECLARED',      'PHARMACY'),
  ('EXPIRED',              'RETURN_DECLARED',      'PHARMACY'),
  -- Distributor bilateral-confirm advances RETURN_DECLARED → RETURN_INITIATED
  ('RETURN_DECLARED',      'RETURN_INITIATED',     'DISTRIBUTOR'),
  -- Manufacturer own-stock disposal
  ('ACTIVE',               'MFG_DIRECT_DISPOSAL',  'MANUFACTURER'),
  ('EXPIRING_SOON',        'MFG_DIRECT_DISPOSAL',  'MANUFACTURER'),
  ('EXPIRED',              'MFG_DIRECT_DISPOSAL',  'MANUFACTURER'),
  ('MFG_DIRECT_DISPOSAL',  'SENT_FOR_DESTRUCTION', 'MANUFACTURER'),
  -- Distributor warehouse disposal
  ('ACTIVE',               'DIST_DIRECT_DISPOSAL', 'DISTRIBUTOR'),
  ('EXPIRING_SOON',        'DIST_DIRECT_DISPOSAL', 'DISTRIBUTOR'),
  ('EXPIRED',              'DIST_DIRECT_DISPOSAL', 'DISTRIBUTOR'),
  ('DIST_DIRECT_DISPOSAL', 'SENT_FOR_DESTRUCTION', 'DISTRIBUTOR'),
  -- New destruction certification chain
  ('DESTROYED',            'DESTRUCTION_RECORDED', 'WASTE_FACILITY'),
  ('DESTRUCTION_RECORDED', 'CERTIFICATION_PENDING','WASTE_FACILITY'),
  ('CERTIFICATION_PENDING','CERTIFIED',            'WASTE_FACILITY'),
  -- Regulator can close certified
  ('CERTIFIED',            'CLOSED',               'REGULATOR')
ON CONFLICT DO NOTHING;

-- ─── 4. Bilateral confirmation table ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS pending_confirmations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id              uuid NOT NULL REFERENCES medicine_batches(id) ON DELETE CASCADE,
  required_transition   text NOT NULL,
  sender_org_id         uuid NOT NULL REFERENCES organizations(id),
  receiver_org_id       uuid REFERENCES organizations(id),

  sender_attested_at    timestamptz,
  sender_actor_id       uuid,
  sender_evidence_id    uuid,   -- FK to batch_evidence added after that table is created

  receiver_confirmed_at timestamptz,
  receiver_actor_id     uuid,
  receiver_evidence_id  uuid,

  expires_at            timestamptz NOT NULL DEFAULT (now() + interval '2 hours'),
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pending_confirmations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sender can create confirmation" ON pending_confirmations;
CREATE POLICY "sender can create confirmation"
  ON pending_confirmations FOR INSERT TO authenticated
  WITH CHECK (sender_org_id = get_my_org_id());

DROP POLICY IF EXISTS "involved parties can read confirmation" ON pending_confirmations;
CREATE POLICY "involved parties can read confirmation"
  ON pending_confirmations FOR SELECT TO authenticated
  USING (
    sender_org_id = get_my_org_id()
    OR receiver_org_id = get_my_org_id()
    OR get_my_role() = 'REGULATOR'
  );

DROP POLICY IF EXISTS "receiver can confirm" ON pending_confirmations;
CREATE POLICY "receiver can confirm"
  ON pending_confirmations FOR UPDATE TO authenticated
  USING (receiver_org_id = get_my_org_id())
  WITH CHECK (receiver_org_id = get_my_org_id());

-- ─── 5. Evidence (first-class object) table ──────────────────────────────────

CREATE TABLE IF NOT EXISTS batch_evidence (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id            uuid NOT NULL REFERENCES medicine_batches(id) ON DELETE CASCADE,
  event_id            uuid,   -- FK to batch_events set after event created
  actor_id            uuid NOT NULL,
  organization_id     uuid NOT NULL REFERENCES organizations(id),
  capture_session_id  text,

  evidence_type       text NOT NULL CHECK (evidence_type IN ('PHOTO', 'VIDEO', 'DOCUMENT')),
  storage_path        text NOT NULL,

  client_captured_at  timestamptz,
  server_received_at  timestamptz NOT NULL DEFAULT now(),

  latitude            double precision,
  longitude           double precision,
  device_info         text,

  evidence_sha256     text,
  perceptual_hash     text,

  qr_verified         boolean NOT NULL DEFAULT false,
  qr_batch_id_found   text,

  verification_status text NOT NULL DEFAULT 'CAPTURED'
    CHECK (verification_status IN (
      'CAPTURED', 'QR_VERIFIED', 'VALIDATED', 'REJECTED', 'DUPLICATE_FLAGGED'
    )),

  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS batch_evidence_batch_id_idx ON batch_evidence(batch_id);
CREATE INDEX IF NOT EXISTS batch_evidence_phash_idx    ON batch_evidence(perceptual_hash)
  WHERE perceptual_hash IS NOT NULL;

ALTER TABLE batch_evidence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "actor can insert evidence" ON batch_evidence;
CREATE POLICY "actor can insert evidence"
  ON batch_evidence FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid());

DROP POLICY IF EXISTS "involved parties can read evidence" ON batch_evidence;
CREATE POLICY "involved parties can read evidence"
  ON batch_evidence FOR SELECT TO authenticated
  USING (organization_id = get_my_org_id() OR get_my_role() = 'REGULATOR');

DROP POLICY IF EXISTS "system can update evidence" ON batch_evidence;
CREATE POLICY "system can update evidence"
  ON batch_evidence FOR UPDATE TO authenticated
  USING (actor_id = auth.uid() OR get_my_role() = 'REGULATOR');

-- Add FK from pending_confirmations to batch_evidence now that table exists
ALTER TABLE pending_confirmations
  ADD COLUMN IF NOT EXISTS sender_evidence_fk   uuid REFERENCES batch_evidence(id),
  ADD COLUMN IF NOT EXISTS receiver_evidence_fk uuid REFERENCES batch_evidence(id);

-- ─── 6. Capture sessions table ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS capture_sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id    uuid NOT NULL REFERENCES medicine_batches(id) ON DELETE CASCADE,
  actor_id    uuid NOT NULL,
  status      text NOT NULL DEFAULT 'OPEN'
    CHECK (status IN ('OPEN', 'CLOSED', 'EXPIRED')),
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '15 minutes'),
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE capture_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "actor can manage own session" ON capture_sessions;
CREATE POLICY "actor can manage own session"
  ON capture_sessions FOR ALL TO authenticated
  USING (actor_id = auth.uid())
  WITH CHECK (actor_id = auth.uid());

-- ─── 7. Extend disposal_records for destruction upgrade ──────────────────────

ALTER TABLE disposal_records
  ADD COLUMN IF NOT EXISTS video_evidence_url         text,
  ADD COLUMN IF NOT EXISTS destruction_verification   text NOT NULL DEFAULT 'PENDING'
    CHECK (destruction_verification IN ('PENDING', 'SECOND_APPROVED', 'REJECTED')),
  ADD COLUMN IF NOT EXISTS second_approver_id         uuid,
  ADD COLUMN IF NOT EXISTS second_approved_at         timestamptz;
