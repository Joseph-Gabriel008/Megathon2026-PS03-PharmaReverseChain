// lib/services/fraud_detection_service.dart
//
// Rule-based fraud detection engine (client-side fallback).
// In production with Supabase: fraud detection runs server-side
// in the process_batch_scan() RPC function. This service runs
// locally as a fallback and for the mock database demo.
//
// Rules:
//   1. DESTROYED_BATCH_REENTRY   — CRITICAL
//   2. QUANTITY_MISMATCH         — HIGH
//   3. EXPIRED_BATCH_SALE        — HIGH
//   4. INVALID_BATCH             — MEDIUM
//   5. DUPLICATE_BATCH_SCAN      — HIGH
//   6. UNAUTHORIZED_MOVEMENT     — HIGH
//   7. CERTIFICATE_MISMATCH      — CRITICAL
//
// Important: Rules 1, 3, 5 are context-sensitive.
// Scan context AUDIT_VIEW / DISPOSAL_VERIFICATION skip fraud checks.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_batch.dart';
import '../models/batch_event.dart';
import '../models/scan_context.dart';
import '../data/mock_database.dart';
import '../core/constants.dart';

class FraudResult {
  final bool isSuspicious;
  final String? alertType;
  final String? severity;
  final String? reason;
  final FraudAlert? alert;
  final String? recommendedAction;

  const FraudResult({
    required this.isSuspicious,
    this.alertType,
    this.severity,
    this.reason,
    this.alert,
    this.recommendedAction,
  });

  bool get isCritical => severity == 'CRITICAL';
}

class FraudDetectionService {
  final SupabaseClient _client;

  FraudDetectionService(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  // ─────────────────────────────────────────────────────────────────────────
  //  Main entry point — called on every scan event (OCR flow)
  // ─────────────────────────────────────────────────────────────────────────

  Future<FraudResult> analyzeScan({
    required MedicineBatch batch,
    required String scannedByUserId,
    required String scannedByOrgId,
    ScanContext context = ScanContext.inventoryCheck,
    int? expectedQuantity,
    int? actualQuantity,
  }) async {
    // Skip all fraud rules for audit/historical contexts
    if (context.isAuditSafe) {
      debugPrint('FraudDetectionService: Skipping rules for audit-safe context ${context.value}');
      return const FraudResult(isSuspicious: false);
    }

    // Rule 1: DESTROYED_BATCH_REENTRY (CRITICAL) ───────────────────────────
    if ((batch.isDestroyed) && context.triggersDestroyedReentry) {
      final alert = await _fireAlert(
        batchId: batch.id,
        alertType: 'DESTROYED_BATCH_REENTRY',
        severity: 'CRITICAL',
        description:
            'Batch ${batch.batchNumber} (${batch.displayName}) is marked as '
            '${batch.status} but was scanned for ${context.label} by '
            'organization $scannedByOrgId. '
            'This batch should never appear in active supply chain again.',
        organizationId: scannedByOrgId,
        scanContext: context.value,
      );
      return FraudResult(
        isSuspicious: true,
        alertType: 'DESTROYED_BATCH_REENTRY',
        severity: 'CRITICAL',
        reason: 'This batch (${batch.batchNumber}) has already been destroyed '
            'and certified. Its re-entry as active stock is a critical '
            'compliance violation under CDSCO regulations.',
        alert: alert,
        recommendedAction: 'Seize batch, do not dispense, contact CDSCO inspector.',
      );
    }

    // Rule 2: QUANTITY_MISMATCH (HIGH) ────────────────────────────────────
    if (expectedQuantity != null &&
        actualQuantity != null &&
        expectedQuantity != actualQuantity) {
      final diff = (expectedQuantity - actualQuantity).abs();
      final alert = await _fireAlert(
        batchId: batch.id,
        alertType: 'QUANTITY_MISMATCH',
        severity: 'HIGH',
        description:
            'Quantity mismatch for batch ${batch.batchNumber}: '
            'expected $expectedQuantity units, found $actualQuantity units '
            '(difference: $diff units). Organization: $scannedByOrgId.',
        organizationId: scannedByOrgId,
        scanContext: context.value,
      );
      return FraudResult(
        isSuspicious: true,
        alertType: 'QUANTITY_MISMATCH',
        severity: 'HIGH',
        reason: 'Expected $expectedQuantity units but found $actualQuantity units. '
            'A discrepancy of $diff units has been flagged for review.',
        alert: alert,
        recommendedAction: 'Halt pickup. Recount and re-verify before proceeding.',
      );
    }

    // Rule 3: EXPIRED_BATCH_SALE (HIGH) ───────────────────────────────────
    if (batch.isExpired &&
        (batch.status == 'ACTIVE' || batch.status == 'EXPIRING_SOON') &&
        (context == ScanContext.activeStockCheck ||
            context == ScanContext.inventoryCheck)) {
      final alert = await _fireAlert(
        batchId: batch.id,
        alertType: 'EXPIRED_BATCH_SALE',
        severity: 'HIGH',
        description:
            'Expired batch ${batch.batchNumber} '
            '(expired ${batch.expiryDate.toIso8601String().substring(0, 10)}) '
            'was scanned as active inventory. Return must be initiated immediately.',
        organizationId: scannedByOrgId,
        scanContext: context.value,
      );
      return FraudResult(
        isSuspicious: true,
        alertType: 'EXPIRED_BATCH_SALE',
        severity: 'HIGH',
        reason:
            'This batch expired on ${batch.expiryDate.toIso8601String().substring(0, 10)}. '
            'It cannot remain as active inventory under CDSCO regulations.',
        alert: alert,
        recommendedAction: 'Remove from shelf. Initiate return request immediately.',
      );
    }

    // Rule 4: INVALID_BATCH (MEDIUM) ──────────────────────────────────────
    // (Not directly applicable here since batch was found — handled in QrService
    //  and scan_screen when batch is null. Left as placeholder for direct call.)

    // Rule 5: DUPLICATE_BATCH_SCAN (HIGH) ─────────────────────────────────
    // Only checked if server is available (requires qr_scans table query)
    if (!_isMock) {
      final isDuplicate = await _checkDuplicateScan(
        batchId: batch.id,
        orgId: scannedByOrgId,
      );
      if (isDuplicate) {
        final alert = await _fireAlert(
          batchId: batch.id,
          alertType: 'DUPLICATE_BATCH_SCAN',
          severity: 'HIGH',
          description:
              'Batch ${batch.batchNumber} was scanned twice within 5 minutes '
              'by organization $scannedByOrgId. Possible double-counting or '
              'erroneous scan.',
          organizationId: scannedByOrgId,
          scanContext: context.value,
        );
        return FraudResult(
          isSuspicious: true,
          alertType: 'DUPLICATE_BATCH_SCAN',
          severity: 'HIGH',
          reason: 'This batch was scanned twice within 5 minutes by your organization.',
          alert: alert,
          recommendedAction: 'Verify physical stock count. Dismiss if accidental.',
        );
      }
    }

    // Rule 6: UNAUTHORIZED_MOVEMENT (HIGH) ────────────────────────────────
    // Scanned by an org that shouldn't have this batch at its current stage
    final unauthorizedReason = _checkUnauthorizedMovement(batch, scannedByOrgId, context);
    if (unauthorizedReason != null) {
      final alert = await _fireAlert(
        batchId: batch.id,
        alertType: 'UNAUTHORIZED_MOVEMENT',
        severity: 'HIGH',
        description: unauthorizedReason,
        organizationId: scannedByOrgId,
        scanContext: context.value,
      );
      return FraudResult(
        isSuspicious: true,
        alertType: 'UNAUTHORIZED_MOVEMENT',
        severity: 'HIGH',
        reason: 'Batch scanned by an organization that does not have custody of it '
            'at the current lifecycle stage.',
        alert: alert,
        recommendedAction: 'Do not proceed. Report to admin immediately.',
      );
    }

    return const FraudResult(isSuspicious: false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Rule 7: CERTIFICATE_MISMATCH — called explicitly during disposal
  // ─────────────────────────────────────────────────────────────────────────

  Future<FraudResult> checkCertificateMismatch({
    required String batchId,
    required String batchNumber,
    required String certificateNumber,
    required String disposalRecordId,
    required String organizationId,
  }) async {
    // Check for duplicate certificate number
    try {
      final existing = await _client
          .from('destruction_certificates')
          .select('id, disposal_record_id')
          .eq('certificate_number', certificateNumber)
          .neq('disposal_record_id', disposalRecordId);

      if ((existing as List).isNotEmpty) {
        final alert = await _fireAlert(
          batchId: batchId,
          alertType: 'CERTIFICATE_MISMATCH',
          severity: 'CRITICAL',
          description: 'Certificate number $certificateNumber is already '
              'registered for a different disposal record. '
              'Possible certificate forgery or data entry error.',
          organizationId: organizationId,
          scanContext: 'DISPOSAL_VERIFICATION',
        );
        return FraudResult(
          isSuspicious: true,
          alertType: 'CERTIFICATE_MISMATCH',
          severity: 'CRITICAL',
          reason: 'Certificate number $certificateNumber already exists in the system. '
              'Duplicate certificate numbers are a critical compliance violation.',
          alert: alert,
          recommendedAction: 'Stop disposal process. Obtain a unique certificate number.',
        );
      }
    } catch (e) {
      debugPrint('FraudDetectionService.checkCertificateMismatch: $e');
    }
    return const FraudResult(isSuspicious: false);
  }

  // ─── Rule 8: UNVERIFIED_TRANSITION (HIGH) ─────────────────────────────────
  /// Triggers when a transition requiring evidence or bilateral confirmation is rejected.
  Future<FraudResult> checkUnverifiedTransition({
    required String batchId,
    required String requestedStatus,
    required String organizationId,
    required String serverError,
  }) async {
    final alert = await _fireAlert(
      batchId: batchId,
      alertType: 'UNVERIFIED_TRANSITION',
      severity: 'HIGH',
      description: 'Attempted unverified transition to $requestedStatus rejected by server. Reason: $serverError',
      organizationId: organizationId,
    );
    return FraudResult(
      isSuspicious: true,
      alertType: 'UNVERIFIED_TRANSITION',
      severity: 'HIGH',
      reason: 'Transition to $requestedStatus requires verified cryptographic evidence or bilateral confirmation: $serverError',
      alert: alert,
      recommendedAction: 'Attach required tamper-evident evidence and await counterparty confirmation before retrying.',
    );
  }

  // ─── Rule 9: EVIDENCE_BATCH_MISMATCH (HIGH) ──────────────────────────────
  /// Fires when QR decoded from proof image does not match the expected batch ID.
  Future<FraudResult> checkEvidenceBatchMismatch({
    required String batchId,
    required String decodedBatchId,
    required String organizationId,
  }) async {
    final alert = await _fireAlert(
      batchId: batchId,
      alertType: 'EVIDENCE_BATCH_MISMATCH',
      severity: 'HIGH',
      description: 'Proof photo QR ($decodedBatchId) does not match expected batch ($batchId).',
      organizationId: organizationId,
    );
    return FraudResult(
      isSuspicious: true,
      alertType: 'EVIDENCE_BATCH_MISMATCH',
      severity: 'HIGH',
      reason: 'The QR code inside the uploaded evidence image belongs to a different batch ($decodedBatchId).',
      alert: alert,
      recommendedAction: 'Reject evidence. Capture new photo showing the physical QR code of batch $batchId.',
    );
  }

  // ─── Rule 10: EVIDENCE_REUSE (CRITICAL) ──────────────────────────────────
  /// Fires when perceptual hash duplicate or identical SHA-256 proof is detected.
  Future<FraudResult> checkEvidenceReuse({
    required String batchId,
    required String existingEvidenceId,
    required String organizationId,
  }) async {
    final alert = await _fireAlert(
      batchId: batchId,
      alertType: 'EVIDENCE_REUSE',
      severity: 'CRITICAL',
      description: 'Duplicate evidence detected. Matches existing record $existingEvidenceId.',
      organizationId: organizationId,
    );
    return FraudResult(
      isSuspicious: true,
      alertType: 'EVIDENCE_REUSE',
      severity: 'CRITICAL',
      reason: 'This evidence file or photograph has already been used in another verification. Reuse of photographic evidence is strictly prohibited.',
      alert: alert,
      recommendedAction: 'Halt process. Flag for regulatory investigation of falsified proof.',
    );
  }

  // ─── Rule 11: SINGLE_PARTY_CRITICAL_ACTION (HIGH) ────────────────────────
  /// Fires when an actor attempts to complete a handoff state unilaterally.
  Future<FraudResult> checkSinglePartyCriticalAction({
    required String batchId,
    required String attemptedStatus,
    required String organizationId,
  }) async {
    final alert = await _fireAlert(
      batchId: batchId,
      alertType: 'SINGLE_PARTY_CRITICAL_ACTION',
      severity: 'HIGH',
      description: 'Unilateral attempt to advance handoff to $attemptedStatus without bilateral counterparty attestation.',
      organizationId: organizationId,
    );
    return FraudResult(
      isSuspicious: true,
      alertType: 'SINGLE_PARTY_CRITICAL_ACTION',
      severity: 'HIGH',
      reason: 'State transition to $attemptedStatus requires independent two-sided attestation.',
      alert: alert,
      recommendedAction: 'Ensure counterparty scans and attests receipt before advancing.',
    );
  }

  // ─── Rule 12: CUSTODY_TIMEOUT (HIGH) ─────────────────────────────────────
  /// Fires when a batch remains in transit or handoff limbo exceeding SLA threshold (e.g. 48h).
  Future<FraudResult> checkCustodyTimeout({
    required MedicineBatch batch,
    required Duration durationInStatus,
    required String organizationId,
  }) async {
    final hours = durationInStatus.inHours;
    final alert = await _fireAlert(
      batchId: batch.id,
      alertType: 'CUSTODY_TIMEOUT',
      severity: 'HIGH',
      description: 'Batch ${batch.batchNumber} has been in ${batch.status} for $hours hours without counterparty intake.',
      organizationId: organizationId,
    );
    return FraudResult(
      isSuspicious: true,
      alertType: 'CUSTODY_TIMEOUT',
      severity: 'HIGH',
      reason: 'Batch has exceeded maximum custody handoff window ($hours hours). Potential diversion or lost consignment.',
      alert: alert,
      recommendedAction: 'Initiate inventory physical trace and contact custodian immediately.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Internal helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _checkDuplicateScan({
    required String batchId,
    required String orgId,
  }) async {
    try {
      final fiveMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      final rows = await _client
          .from('qr_scans')
          .select('id')
          .eq('batch_id', batchId)
          .eq('organization_id', orgId)
          .gte('timestamp', fiveMinutesAgo)
          .limit(2); // If 2+ scans in 5 min → duplicate
      return (rows as List).length >= 2;
    } catch (_) {
      return false;
    }
  }

  String? _checkUnauthorizedMovement(
    MedicineBatch batch,
    String scannedByOrgId,
    ScanContext context,
  ) {
    // Skip check for audit and non-critical contexts
    if (context.isAuditSafe) return null;

    // Pharmacy should only see ACTIVE/EXPIRING_SOON/EXPIRED/RETURN_INITIATED batches
    if (context == ScanContext.activeStockCheck ||
        context == ScanContext.returnInitiation) {
      if (batch.pharmacyId != null &&
          batch.pharmacyId != scannedByOrgId &&
          (batch.status == 'ACTIVE' || batch.status == 'EXPIRING_SOON' || batch.status == 'EXPIRED')) {
        return 'Batch ${batch.batchNumber} belongs to pharmacy ${batch.pharmacyId} '
            'but was scanned by organization $scannedByOrgId for ${context.label}. '
            'Unauthorized access to another pharmacy\'s inventory.';
      }
    }
    return null;
  }

  Future<FraudAlert?> _fireAlert({
    required String batchId,
    required String alertType,
    required String severity,
    required String description,
    required String organizationId,
    String? scanContext,
  }) async {
    // Mock database path
    if (_isMock) {
      return MockDatabase.instance.createFraudAlert(
        batchId: batchId,
        alertType: alertType,
        severity: severity,
        description: description,
        organizationId: organizationId,
      );
    }

    try {
      final result = await _client
          .from('fraud_alerts')
          .insert({
            'batch_id': batchId,
            'alert_type': alertType,
            'severity': severity,
            'description': description,
            'organization_id': organizationId,
            'status': 'OPEN',
            'detected_at': DateTime.now().toIso8601String(),
            'scan_context': scanContext,
          })
          .select('''
            *,
            medicine_batches(batch_number, medicines(name)),
            organizations(name)
          ''')
          .single();

      return FraudAlert.fromJson(result);
    } catch (e) {
      debugPrint('FraudDetectionService._fireAlert error: $e');
      return null;
    }
  }
}
