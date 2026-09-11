-- ============================================================
-- MediLoop — Review 2 RPC Patch: Updated transition_batch_status()
-- Purpose: Extend server-side transition guard with evidence,
--          bilateral confirmation, multi-origin, and
--          verification_state management.
-- Run AFTER patch_review2_states.sql.
-- ============================================================

CREATE OR REPLACE FUNCTION transition_batch_status(
  p_batch_id           uuid,
  p_new_status         text,
  p_event_type         text,
  p_quantity           int     DEFAULT 0,
  p_metadata           jsonb   DEFAULT '{}'::jsonb,
  p_waste_facility_id  uuid    DEFAULT NULL,
  p_origination_path   text    DEFAULT NULL,
  p_confirmation_id    uuid    DEFAULT NULL,
  p_evidence_id        uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_batch       medicine_batches%ROWTYPE;
  v_user        users%ROWTYPE;
  v_allowed     boolean := false;
  v_evidence    batch_evidence%ROWTYPE;
  v_prev_hash   text    := '';
  v_ts          timestamptz := now();
  v_hash        text;
  v_event_id    uuid;
  v_new_vstate  text;
BEGIN
  -- ── 1. Authoritative batch read (server lock, not client-supplied state) ──
  SELECT * INTO v_batch FROM medicine_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Batch not found');
  END IF;

  -- ── 2. Authoritative user read ────────────────────────────────────────────
  SELECT * INTO v_user FROM users WHERE id = auth.uid();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Unauthorized');
  END IF;

  -- ── 3. Lifecycle transition check ─────────────────────────────────────────
  SELECT true INTO v_allowed
  FROM lifecycle_transitions
  WHERE from_status  = v_batch.status::text
    AND to_status    = p_new_status
    AND (allowed_role = '*' OR allowed_role = v_user.role::text)
  LIMIT 1;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Transition ' || v_batch.status::text || '→' || p_new_status
               || ' not permitted for role ' || v_user.role::text
    );
  END IF;

  -- ── 4. Evidence requirement for high-risk transitions ─────────────────────
  IF p_new_status IN (
    'RETURN_DECLARED', 'MFG_DIRECT_DISPOSAL', 'DIST_DIRECT_DISPOSAL',
    'DESTRUCTION_RECORDED', 'CERTIFIED'
  ) THEN
    IF p_evidence_id IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Evidence is required for transition to ' || p_new_status
      );
    END IF;

    SELECT * INTO v_evidence FROM batch_evidence
    WHERE id = p_evidence_id AND batch_id = p_batch_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Evidence record not found for this batch'
      );
    END IF;

    IF NOT v_evidence.qr_verified THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Evidence QR verification is required before this transition'
      );
    END IF;
  END IF;

  -- ── 5. Bilateral confirmation check for physical handoff transitions ───────
  IF p_new_status IN ('RETURN_INITIATED', 'COLLECTED', 'DISTRIBUTOR_VERIFIED') THEN
    IF p_confirmation_id IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Bilateral confirmation required for transition to ' || p_new_status
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pending_confirmations
      WHERE id                  = p_confirmation_id
        AND batch_id            = p_batch_id
        AND sender_attested_at  IS NOT NULL
        AND receiver_confirmed_at IS NOT NULL
        AND expires_at          > now()
    ) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Bilateral confirmation is incomplete, expired, or does not match this batch'
      );
    END IF;
  END IF;

  -- ── 6. Derive new verification_state ──────────────────────────────────────
  v_new_vstate := CASE
    WHEN p_new_status IN ('RETURN_DECLARED', 'MFG_DIRECT_DISPOSAL', 'DIST_DIRECT_DISPOSAL')
      THEN 'DECLARED'
    WHEN p_new_status IN (
      'RETURN_INITIATED', 'PICKUP_ASSIGNED', 'COLLECTED',
      'DISTRIBUTOR_VERIFIED', 'MANUFACTURER_RECEIVED',
      'DISPOSAL_PENDING', 'SENT_FOR_DESTRUCTION', 'DESTROYED',
      'DESTRUCTION_RECORDED', 'CERTIFICATION_PENDING'
    ) THEN 'VERIFIED'
    WHEN p_new_status = 'CERTIFIED'  THEN 'CERTIFIED'
    WHEN p_new_status = 'CLOSED'     THEN 'CERTIFIED'
    ELSE v_batch.verification_state
  END;

  -- ── 7. Build event hash (includes evidence reference) ─────────────────────
  SELECT event_hash INTO v_prev_hash
  FROM batch_events WHERE batch_id = p_batch_id
  ORDER BY timestamp DESC LIMIT 1;
  IF v_prev_hash IS NULL THEN v_prev_hash := ''; END IF;

  v_hash := compute_event_hash(
    v_prev_hash, p_batch_id, p_event_type, auth.uid(),
    p_quantity, p_new_status, v_ts
  );

  -- ── 8. Atomic batch state update ──────────────────────────────────────────
  UPDATE medicine_batches SET
    status            = p_new_status::batch_status,
    updated_at        = v_ts,
    verification_state = v_new_vstate,
    waste_facility_id = COALESCE(p_waste_facility_id, waste_facility_id),
    origination_path  = COALESCE(p_origination_path,  origination_path),
    current_custodian = v_user.organization_id
  WHERE id = p_batch_id;

  -- ── 9. Create audit event ─────────────────────────────────────────────────
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

  -- ── 10. Link evidence to event + mark VALIDATED ───────────────────────────
  IF p_evidence_id IS NOT NULL THEN
    UPDATE batch_evidence
    SET event_id           = v_event_id,
        verification_status = 'VALIDATED'
    WHERE id = p_evidence_id;
  END IF;

  -- ── 11. Mark bilateral confirmation as consumed ───────────────────────────
  IF p_confirmation_id IS NOT NULL THEN
    UPDATE pending_confirmations
    SET expires_at = now()    -- close out the window
    WHERE id = p_confirmation_id;
  END IF;

  -- ── 12. Notifications ────────────────────────────────────────────────────
  PERFORM create_transition_notifications(p_batch_id, p_new_status, v_user.organization_id);

  RETURN jsonb_build_object(
    'ok',             true,
    'event_id',       v_event_id,
    'event_hash',     v_hash,
    'new_status',     p_new_status,
    'verification',   v_new_vstate
  );
END;
$$;

-- ─── Helper: create_capture_session RPC ──────────────────────────────────────

CREATE OR REPLACE FUNCTION create_capture_session(
  p_batch_id  uuid,
  p_actor_id  uuid,
  p_expires_at timestamptz DEFAULT (now() + interval '15 minutes')
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id uuid;
BEGIN
  -- Close any open sessions for this batch+actor
  UPDATE capture_sessions SET status = 'CLOSED'
  WHERE batch_id = p_batch_id AND actor_id = p_actor_id AND status = 'OPEN';

  INSERT INTO capture_sessions (batch_id, actor_id, status, expires_at)
  VALUES (p_batch_id, p_actor_id, 'OPEN', p_expires_at)
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object('session_id', v_session_id);
END;
$$;
