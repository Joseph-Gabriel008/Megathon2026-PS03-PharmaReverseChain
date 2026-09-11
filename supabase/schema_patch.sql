-- ============================================================
--  MediLoop — Schema Patch v2
--  Run AFTER schema.sql in your Supabase SQL editor.
--  This is fully additive — safe to apply on existing data.
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  1. EXTEND ENUMS
-- ────────────────────────────────────────────────────────────

ALTER TYPE batch_status ADD VALUE IF NOT EXISTS 'PICKUP_ASSIGNED';
ALTER TYPE alert_type ADD VALUE IF NOT EXISTS 'UNAUTHORIZED_MOVEMENT';
ALTER TYPE alert_type ADD VALUE IF NOT EXISTS 'CERTIFICATE_MISMATCH';

-- ────────────────────────────────────────────────────────────
--  2. ADD MISSING COLUMNS
-- ────────────────────────────────────────────────────────────

ALTER TABLE medicine_batches
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE fraud_alerts
  ADD COLUMN IF NOT EXISTS resolved_by    uuid REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS resolved_at    timestamptz,
  ADD COLUMN IF NOT EXISTS resolution_notes text,
  ADD COLUMN IF NOT EXISTS scan_context   text;

ALTER TABLE qr_scans
  ADD COLUMN IF NOT EXISTS scan_context  text,
  ADD COLUMN IF NOT EXISTS location_lat  double precision,
  ADD COLUMN IF NOT EXISTS location_lng  double precision,
  ADD COLUMN IF NOT EXISTS device_id     text;

ALTER TABLE destruction_certificates
  ADD COLUMN IF NOT EXISTS batch_id             uuid REFERENCES medicine_batches(id),
  ADD COLUMN IF NOT EXISTS document_hash        text,
  ADD COLUMN IF NOT EXISTS verification_status  text NOT NULL DEFAULT 'PENDING';

ALTER TABLE reverse_requests
  ADD COLUMN IF NOT EXISTS proof_url            text;

-- ────────────────────────────────────────────────────────────
--  3. ADDITIONAL INDEXES
-- ────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_batches_manufacturer_id   ON medicine_batches(manufacturer_id);
CREATE INDEX IF NOT EXISTS idx_batches_distributor_id    ON medicine_batches(distributor_id);
CREATE INDEX IF NOT EXISTS idx_batches_waste_facility_id ON medicine_batches(waste_facility_id);
CREATE INDEX IF NOT EXISTS idx_batches_updated_at        ON medicine_batches(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_batch_id     ON fraud_alerts(batch_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_batch_id         ON qr_scans(batch_id);
CREATE INDEX IF NOT EXISTS idx_qr_scans_org_id           ON qr_scans(organization_id);
CREATE INDEX IF NOT EXISTS idx_certs_cert_number         ON destruction_certificates(certificate_number);
CREATE INDEX IF NOT EXISTS idx_certs_batch_id            ON destruction_certificates(batch_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id     ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread      ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_reverse_batch_id          ON reverse_requests(batch_id);
CREATE INDEX IF NOT EXISTS idx_pickups_request_id        ON pickups(reverse_request_id);

-- ────────────────────────────────────────────────────────────
--  4. TRIGGERS: auto-update updated_at
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_batches_updated_at ON medicine_batches;
CREATE TRIGGER trg_batches_updated_at
  BEFORE UPDATE ON medicine_batches
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_orgs_updated_at ON organizations;
CREATE TRIGGER trg_orgs_updated_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ────────────────────────────────────────────────────────────
--  5. CANONICAL HASH FUNCTION
-- ────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION compute_event_hash(
  p_previous_hash text,
  p_batch_id      uuid,
  p_event_type    text,
  p_actor_id      uuid,
  p_quantity      int,
  p_new_status    text,
  p_timestamp     timestamptz
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_canonical text;
BEGIN
  v_canonical := p_previous_hash
    || '|' || p_batch_id::text
    || '|' || p_event_type
    || '|' || p_actor_id::text
    || '|' || p_quantity::text
    || '|' || p_new_status
    || '|' || to_char(p_timestamp AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
  RETURN encode(digest(v_canonical, 'sha256'), 'hex');
END;
$$;

-- ────────────────────────────────────────────────────────────
--  6. LIFECYCLE VALIDATION MAP
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS lifecycle_transitions (
  id           serial PRIMARY KEY,
  from_status  text NOT NULL,
  to_status    text NOT NULL,
  allowed_role text NOT NULL
);

TRUNCATE lifecycle_transitions;

INSERT INTO lifecycle_transitions (from_status, to_status, allowed_role) VALUES
  ('ACTIVE',               'EXPIRING_SOON',         '*'),
  ('ACTIVE',               'EXPIRED',               '*'),
  ('EXPIRING_SOON',        'EXPIRED',               '*'),
  ('ACTIVE',               'RETURN_INITIATED',      'PHARMACY'),
  ('EXPIRING_SOON',        'RETURN_INITIATED',      'PHARMACY'),
  ('EXPIRED',              'RETURN_INITIATED',      'PHARMACY'),
  ('RETURN_INITIATED',     'PICKUP_ASSIGNED',       'DISTRIBUTOR'),
  ('PICKUP_ASSIGNED',      'COLLECTED',             'DISTRIBUTOR'),
  ('COLLECTED',            'DISTRIBUTOR_VERIFIED',  'DISTRIBUTOR'),
  ('DISTRIBUTOR_VERIFIED', 'MANUFACTURER_RECEIVED', 'MANUFACTURER'),
  ('MANUFACTURER_RECEIVED','DISPOSAL_PENDING',      'MANUFACTURER'),
  ('DISPOSAL_PENDING',     'SENT_FOR_DESTRUCTION',  'MANUFACTURER'),
  ('SENT_FOR_DESTRUCTION', 'DESTROYED',             'WASTE_FACILITY'),
  ('DESTROYED',            'CLOSED',                'REGULATOR'),
  ('ACTIVE',               'CLOSED',                'REGULATOR'),
  ('EXPIRING_SOON',        'CLOSED',                'REGULATOR');

-- ────────────────────────────────────────────────────────────
--  7. NOTIFICATION HELPER
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_transition_notifications(
  p_batch_id   uuid,
  p_new_status text,
  p_org_id     uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_batch_number text;
BEGIN
  SELECT batch_number INTO v_batch_number FROM medicine_batches WHERE id = p_batch_id;

  CASE p_new_status
    WHEN 'RETURN_INITIATED' THEN
      INSERT INTO notifications (user_id, title, message, type, related_batch_id)
      SELECT u.id, 'New Return Request',
        'Batch ' || v_batch_number || ' requires pickup.',
        'RETURN_INITIATED', p_batch_id
      FROM users u WHERE u.role = 'DISTRIBUTOR';
    WHEN 'COLLECTED' THEN
      INSERT INTO notifications (user_id, title, message, type, related_batch_id)
      SELECT u.id, 'Batch Collected',
        'Batch ' || v_batch_number || ' has been collected.',
        'COLLECTED', p_batch_id
      FROM users u WHERE u.role = 'MANUFACTURER';
    WHEN 'MANUFACTURER_RECEIVED' THEN
      INSERT INTO notifications (user_id, title, message, type, related_batch_id)
      SELECT u.id, 'Batch at Manufacturer',
        'Batch ' || v_batch_number || ' received, pending disposal.',
        'MANUFACTURER_RECEIVED', p_batch_id
      FROM users u WHERE u.role = 'WASTE_FACILITY';
    WHEN 'DESTROYED' THEN
      INSERT INTO notifications (user_id, title, message, type, related_batch_id)
      SELECT u.id, 'Batch Destroyed',
        'Batch ' || v_batch_number || ' destroyed. Certificate required.',
        'DESTROYED', p_batch_id
      FROM users u WHERE u.role = 'REGULATOR';
    ELSE NULL;
  END CASE;
END;
$$;

-- Allow notifications insert
DROP POLICY IF EXISTS "system can insert notifications" ON notifications;
CREATE POLICY "system can insert notifications"
  ON notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────────
--  8. TRANSITION_BATCH_STATUS RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION transition_batch_status(
  p_batch_id   uuid,
  p_new_status text,
  p_event_type text,
  p_quantity   int  DEFAULT 0,
  p_metadata   jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_batch    medicine_batches%ROWTYPE;
  v_user     users%ROWTYPE;
  v_allowed  boolean := false;
  v_prev_hash text := '';
  v_ts       timestamptz := now();
  v_hash     text;
  v_event_id uuid;
BEGIN
  SELECT * INTO v_batch FROM medicine_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Batch not found'); END IF;

  SELECT * INTO v_user FROM users WHERE id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Unauthorized'); END IF;

  SELECT true INTO v_allowed
  FROM lifecycle_transitions
  WHERE from_status = v_batch.status::text
    AND to_status   = p_new_status
    AND (allowed_role = '*' OR allowed_role = v_user.role::text)
  LIMIT 1;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Transition ' || v_batch.status::text || ' to ' || p_new_status
               || ' not permitted for role ' || v_user.role::text
    );
  END IF;

  SELECT event_hash INTO v_prev_hash
  FROM batch_events WHERE batch_id = p_batch_id
  ORDER BY timestamp DESC LIMIT 1;
  IF v_prev_hash IS NULL THEN v_prev_hash := ''; END IF;

  v_hash := compute_event_hash(v_prev_hash, p_batch_id, p_event_type, auth.uid(), p_quantity, p_new_status, v_ts);

  UPDATE medicine_batches SET status = p_new_status::batch_status, updated_at = v_ts WHERE id = p_batch_id;

  INSERT INTO batch_events (
    batch_id, event_type, actor_id, organization_id,
    quantity, previous_status, new_status,
    timestamp, event_hash, previous_event_hash
  ) VALUES (
    p_batch_id, p_event_type, auth.uid(), v_user.organization_id,
    p_quantity, v_batch.status::text, p_new_status,
    v_ts, v_hash,
    CASE WHEN v_prev_hash = '' THEN NULL ELSE v_prev_hash END
  ) RETURNING id INTO v_event_id;

  PERFORM create_transition_notifications(p_batch_id, p_new_status, v_user.organization_id);

  RETURN jsonb_build_object('ok', true, 'event_id', v_event_id, 'event_hash', v_hash, 'new_status', p_new_status);
END;
$$;

-- ────────────────────────────────────────────────────────────
--  9. PROCESS_BATCH_SCAN RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION process_batch_scan(
  p_batch_id     uuid,
  p_scan_context text,
  p_device_id    text   DEFAULT NULL,
  p_location_lat double precision DEFAULT NULL,
  p_location_lng double precision DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_batch        medicine_batches%ROWTYPE;
  v_user         users%ROWTYPE;
  v_scan_id      uuid;
  v_fraud_type   text := NULL;
  v_fraud_sev    text := NULL;
  v_fraud_desc   text := NULL;
  v_recent_scan  boolean := false;
  v_alert_id     uuid := NULL;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Unauthorized'); END IF;

  SELECT * INTO v_batch FROM medicine_batches WHERE id = p_batch_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Batch not found', 'fraud_type', 'INVALID_BATCH');
  END IF;

  INSERT INTO qr_scans (batch_id, scanned_by, organization_id, result, scan_context, device_id, location_lat, location_lng)
  VALUES (p_batch_id, auth.uid(), v_user.organization_id, 'SCAN', p_scan_context, p_device_id, p_location_lat, p_location_lng)
  RETURNING id INTO v_scan_id;

  IF p_scan_context IN ('AUDIT_VIEW', 'DISPOSAL_VERIFICATION') THEN
    RETURN jsonb_build_object('ok', true, 'scan_id', v_scan_id, 'batch_status', v_batch.status, 'fraud', false);
  END IF;

  -- Rule 1: DESTROYED_BATCH_REENTRY
  IF v_batch.status IN ('DESTROYED', 'CLOSED') AND
     p_scan_context IN ('ACTIVE_STOCK_CHECK', 'RETURN_INITIATION', 'INVENTORY_CHECK') THEN
    v_fraud_type := 'DESTROYED_BATCH_REENTRY';
    v_fraud_sev  := 'CRITICAL';
    v_fraud_desc := 'Batch ' || v_batch.batch_number || ' (status: ' || v_batch.status ||
      ') scanned as active inventory by org ' || v_user.organization_id::text;
  END IF;

  -- Rule 3: EXPIRED_BATCH_SALE
  IF v_fraud_type IS NULL AND v_batch.expiry_date < CURRENT_DATE AND
     v_batch.status IN ('ACTIVE', 'EXPIRING_SOON') AND
     p_scan_context IN ('ACTIVE_STOCK_CHECK', 'INVENTORY_CHECK') THEN
    v_fraud_type := 'EXPIRED_BATCH_SALE';
    v_fraud_sev  := 'HIGH';
    v_fraud_desc := 'Expired batch ' || v_batch.batch_number ||
      ' (expired ' || v_batch.expiry_date::text || ') scanned as active inventory.';
  END IF;

  -- Rule 5: DUPLICATE_BATCH_SCAN
  IF v_fraud_type IS NULL THEN
    SELECT true INTO v_recent_scan
    FROM qr_scans
    WHERE batch_id = p_batch_id
      AND organization_id = v_user.organization_id
      AND id != v_scan_id
      AND timestamp > now() - interval '5 minutes'
    LIMIT 1;
    IF v_recent_scan THEN
      v_fraud_type := 'DUPLICATE_BATCH_SCAN';
      v_fraud_sev  := 'HIGH';
      v_fraud_desc := 'Batch ' || v_batch.batch_number || ' scanned twice within 5 minutes.';
    END IF;
  END IF;

  IF v_fraud_type IS NOT NULL THEN
    INSERT INTO fraud_alerts (batch_id, alert_type, severity, description, organization_id, status, scan_context)
    VALUES (p_batch_id, v_fraud_type::alert_type, v_fraud_sev::alert_severity, v_fraud_desc,
            v_user.organization_id, 'OPEN', p_scan_context)
    RETURNING id INTO v_alert_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'scan_id', v_scan_id, 'batch_status', v_batch.status,
    'batch_number', v_batch.batch_number, 'expiry_date', v_batch.expiry_date,
    'fraud', v_fraud_type IS NOT NULL, 'fraud_type', v_fraud_type,
    'fraud_severity', v_fraud_sev, 'fraud_description', v_fraud_desc, 'alert_id', v_alert_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
--  10. COMPLETE_PICKUP RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION complete_pickup(
  p_pickup_id       uuid,
  p_actual_quantity int,
  p_notes           text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_pickup  pickups%ROWTYPE;
  v_request reverse_requests%ROWTYPE;
  v_user    users%ROWTYPE;
  v_result  jsonb;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = auth.uid();
  IF v_user.role != 'DISTRIBUTOR' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Only distributors can complete pickups');
  END IF;
  SELECT * INTO v_pickup FROM pickups WHERE id = p_pickup_id FOR UPDATE;
  IF NOT FOUND OR v_pickup.distributor_id != v_user.organization_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pickup not found or unauthorized');
  END IF;
  SELECT * INTO v_request FROM reverse_requests WHERE id = v_pickup.reverse_request_id;

  UPDATE pickups SET pickup_status = 'COMPLETED', actual_quantity = p_actual_quantity, notes = p_notes
  WHERE id = p_pickup_id;
  UPDATE reverse_requests SET status = 'COMPLETED', completed_at = now()
  WHERE id = v_pickup.reverse_request_id;

  IF p_actual_quantity != v_request.requested_quantity THEN
    INSERT INTO fraud_alerts (batch_id, alert_type, severity, description, organization_id, status)
    SELECT b.id, 'QUANTITY_MISMATCH', 'HIGH',
      'Pickup qty mismatch for batch ' || b.batch_number ||
      ': expected ' || v_request.requested_quantity || ', received ' || p_actual_quantity,
      v_user.organization_id, 'OPEN'
    FROM reverse_requests rr JOIN medicine_batches b ON b.id = rr.batch_id
    WHERE rr.id = v_pickup.reverse_request_id;
  END IF;

  SELECT transition_batch_status(v_request.batch_id, 'COLLECTED', 'PICKUP_COMPLETED', p_actual_quantity) INTO v_result;
  RETURN jsonb_build_object('ok', true, 'transition', v_result);
END;
$$;

-- ────────────────────────────────────────────────────────────
--  11. COMPLETE_DISPOSAL RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION complete_disposal(
  p_disposal_record_id  uuid,
  p_certificate_number  text,
  p_quantity_destroyed  int,
  p_disposal_date       date,
  p_document_path       text DEFAULT NULL,
  p_document_hash       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_disposal disposal_records%ROWTYPE;
  v_user     users%ROWTYPE;
  v_cert_id  uuid;
  v_result   jsonb;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = auth.uid();
  IF v_user.role != 'WASTE_FACILITY' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Only waste facilities can complete disposals');
  END IF;
  SELECT * INTO v_disposal FROM disposal_records WHERE id = p_disposal_record_id FOR UPDATE;
  IF NOT FOUND OR v_disposal.waste_facility_id != v_user.organization_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Disposal record not found or unauthorized');
  END IF;
  IF p_quantity_destroyed > v_disposal.quantity_destroyed THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Quantity exceeds expected');
  END IF;

  -- Duplicate certificate check
  IF EXISTS (SELECT 1 FROM destruction_certificates
             WHERE certificate_number = p_certificate_number
             AND disposal_record_id != p_disposal_record_id) THEN
    INSERT INTO fraud_alerts (batch_id, alert_type, severity, description, organization_id, status)
    VALUES (v_disposal.batch_id, 'CERTIFICATE_MISMATCH', 'CRITICAL',
      'Duplicate certificate ' || p_certificate_number || ' detected.', v_user.organization_id, 'OPEN');
    RETURN jsonb_build_object('ok', false, 'error', 'Duplicate certificate — fraud alert created');
  END IF;

  INSERT INTO destruction_certificates (
    disposal_record_id, batch_id, certificate_number, issued_date,
    hash, document_hash, verification_status, document_url
  ) VALUES (
    p_disposal_record_id, v_disposal.batch_id, p_certificate_number, p_disposal_date,
    encode(digest(p_disposal_record_id::text || ':' || p_certificate_number || ':' || p_quantity_destroyed::text, 'sha256'), 'hex'),
    p_document_hash, 'VERIFIED', p_document_path
  ) RETURNING id INTO v_cert_id;

  UPDATE disposal_records SET
    status = 'COMPLETED', certificate_id = v_cert_id,
    actual_disposal_date = p_disposal_date, quantity_destroyed = p_quantity_destroyed
  WHERE id = p_disposal_record_id;

  SELECT transition_batch_status(v_disposal.batch_id, 'DESTROYED', 'DESTRUCTION_RECORDED', p_quantity_destroyed)
  INTO v_result;

  RETURN jsonb_build_object('ok', true, 'certificate_id', v_cert_id, 'transition', v_result);
END;
$$;

-- ────────────────────────────────────────────────────────────
--  12. VERIFY_AUDIT_CHAIN RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION verify_audit_chain(p_batch_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_event       batch_events%ROWTYPE;
  v_prev_hash   text := '';
  v_event_count int := 0;
BEGIN
  FOR v_event IN SELECT * FROM batch_events WHERE batch_id = p_batch_id ORDER BY timestamp ASC LOOP
    v_event_count := v_event_count + 1;
    IF v_event_count > 1 AND v_event.previous_event_hash IS DISTINCT FROM v_prev_hash THEN
      RETURN jsonb_build_object('valid', false, 'events_checked', v_event_count,
        'issue', jsonb_build_object('event_id', v_event.id, 'event_type', v_event.event_type,
                   'reason', 'Hash chain broken at this event'));
    END IF;
    v_prev_hash := v_event.event_hash;
  END LOOP;
  RETURN jsonb_build_object('valid', true, 'events_checked', v_event_count);
END;
$$;

-- ────────────────────────────────────────────────────────────
--  13. COMPLIANCE SCORE RPC
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_compliance_score(p_org_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total_batches   int;
  v_expired_unret   int;
  v_qty_mismatches  int;
  v_open_alerts     int;
  v_destroyed       int;
  v_overdue_returns int;
  v_score           numeric;
BEGIN
  SELECT count(*) INTO v_total_batches FROM medicine_batches
  WHERE (p_org_id IS NULL OR pharmacy_id = p_org_id OR manufacturer_id = p_org_id);
  IF v_total_batches = 0 THEN RETURN jsonb_build_object('score', 100, 'factors', '{}'::jsonb); END IF;

  SELECT count(*) INTO v_expired_unret FROM medicine_batches
  WHERE status = 'EXPIRED' AND (p_org_id IS NULL OR pharmacy_id = p_org_id);

  SELECT count(*) INTO v_qty_mismatches FROM fraud_alerts
  WHERE alert_type = 'QUANTITY_MISMATCH' AND status != 'FALSE_POSITIVE'
    AND (p_org_id IS NULL OR organization_id = p_org_id);

  SELECT count(*) INTO v_open_alerts FROM fraud_alerts
  WHERE status = 'OPEN' AND severity IN ('CRITICAL', 'HIGH')
    AND (p_org_id IS NULL OR organization_id = p_org_id);

  SELECT count(*) INTO v_destroyed FROM medicine_batches
  WHERE status IN ('DESTROYED', 'CLOSED')
    AND (p_org_id IS NULL OR manufacturer_id = p_org_id);

  SELECT count(*) INTO v_overdue_returns FROM medicine_batches
  WHERE status = 'EXPIRED' AND expiry_date < CURRENT_DATE - interval '30 days'
    AND (p_org_id IS NULL OR pharmacy_id = p_org_id);

  v_score := GREATEST(0, LEAST(100, round(
    100.0
    - (v_expired_unret::numeric / v_total_batches * 20)
    - (v_qty_mismatches * 3)
    - (v_open_alerts * 5)
    - (v_overdue_returns * 2)
  )));

  RETURN jsonb_build_object(
    'score', v_score,
    'total_batches', v_total_batches,
    'factors', jsonb_build_object(
      'expired_unreturned', v_expired_unret,
      'quantity_mismatches', v_qty_mismatches,
      'open_critical_alerts', v_open_alerts,
      'overdue_returns', v_overdue_returns,
      'destroyed_batches', v_destroyed
    )
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
--  14. TIGHTEN RLS — block direct batch status updates
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "batch update allowed for relevant roles" ON medicine_batches;

CREATE POLICY "only regulator can directly change batch status"
  ON medicine_batches FOR UPDATE
  TO authenticated
  USING (get_my_role() IN ('PHARMACY','DISTRIBUTOR','MANUFACTURER','WASTE_FACILITY','REGULATOR'))
  WITH CHECK (get_my_role() = 'REGULATOR');

-- Enable realtime on notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
