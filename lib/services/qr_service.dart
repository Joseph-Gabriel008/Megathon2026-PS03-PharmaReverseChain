// lib/services/qr_service.dart
//
// QR encoding/decoding + full scan processing pipeline.
// QR codes in MediLoop encode ONLY the batch UUID:
//   Format: "MEDILOOP:BATCH:<uuid>"
// No customer data, no secrets, no organization info.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scan_context.dart';
import '../models/medicine_batch.dart';
import '../models/batch_event.dart';
import '../data/mock_database.dart';
import '../core/constants.dart';

class QrScanResult {
  final bool ok;
  final String? batchId;
  final String? batchNumber;
  final String? batchStatus;
  final String? expiryDate;
  final bool fraud;
  final String? fraudType;
  final String? fraudSeverity;
  final String? fraudDescription;
  final String? alertId;
  final String? error;
  final String? scanId;

  const QrScanResult({
    required this.ok,
    this.batchId,
    this.batchNumber,
    this.batchStatus,
    this.expiryDate,
    this.fraud = false,
    this.fraudType,
    this.fraudSeverity,
    this.fraudDescription,
    this.alertId,
    this.error,
    this.scanId,
  });

  bool get isCritical => fraudSeverity == 'CRITICAL';

  factory QrScanResult.fromRpc(Map<String, dynamic> data) => QrScanResult(
        ok: data['ok'] as bool? ?? false,
        batchId: data['batch_id'] as String?,
        batchNumber: data['batch_number'] as String?,
        batchStatus: data['batch_status'] as String?,
        expiryDate: data['expiry_date'] as String?,
        fraud: data['fraud'] as bool? ?? false,
        fraudType: data['fraud_type'] as String?,
        fraudSeverity: data['fraud_severity'] as String?,
        fraudDescription: data['fraud_description'] as String?,
        alertId: data['alert_id'] as String?,
        error: data['error'] as String?,
        scanId: data['scan_id'] as String?,
      );

  factory QrScanResult.error(String message) =>
      QrScanResult(ok: false, error: message);
}

class QrService {
  final SupabaseClient _client;

  QrService(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  // ─────────────────────────────────────────────────────────────────────────
  //  QR encoding / decoding
  // ─────────────────────────────────────────────────────────────────────────

  static const String _prefix = 'MEDILOOP:BATCH:';

  /// Encode a batch UUID into the MediLoop QR payload.
  static String encodeBatchQr(String batchId) => '$_prefix$batchId';

  /// Decode a QR payload. Returns the batch UUID or null if invalid format.
  static String? decodeBatchQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith(_prefix)) {
      final uuid = trimmed.substring(_prefix.length);
      // Basic UUID format check
      if (RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(uuid)) {
        return uuid;
      }
    }
    // Also accept raw batch numbers for OCR flow compatibility
    return null;
  }

  /// Determine if a raw string is a MediLoop QR code.
  static bool isMediLoopQr(String raw) => raw.trim().startsWith(_prefix);

  /// Decode a QR code from a still image file (for proof-photo validation).
  /// Uses MobileScannerController.analyzeImage().
  /// Returns the raw QR string, or null if no QR was found.
  static Future<String?> decodeFromFile(File imageFile) async {
    try {
      final controller = MobileScannerController();
      final result = await controller.analyzeImage(imageFile.path);
      await controller.dispose();
      return result?.barcodes.firstOrNull?.rawValue;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Full scan processing pipeline
  // ─────────────────────────────────────────────────────────────────────────

  /// Process a QR scan server-side (calls process_batch_scan RPC).
  ///
  /// Flow:
  ///   1. Decode QR → batch UUID
  ///   2. Call process_batch_scan RPC
  ///   3. RPC: record scan, run fraud rules, return result
  ///   4. Return QrScanResult
  ///
  /// For offline/mock: runs local fraud checks instead.
  Future<QrScanResult> processScan({
    required String qrPayload,
    required ScanContext context,
    String? deviceId,
    double? locationLat,
    double? locationLng,
  }) async {
    // 1. Extract batch ID from QR
    final batchId = decodeBatchQr(qrPayload);
    if (batchId == null) {
      return QrScanResult.error(
        'Invalid QR code format. Expected MEDILOOP:BATCH:<uuid>.',
      );
    }

    if (_isMock) {
      return _processMockScan(batchId: batchId, context: context);
    }

    try {
      final result = await _client.rpc('process_batch_scan', params: {
        'p_batch_id':     batchId,
        'p_scan_context': context.value,
        'p_device_id':    deviceId,
        'p_location_lat': locationLat,
        'p_location_lng': locationLng,
      });

      return QrScanResult.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e) {
      debugPrint('QrService.processScan error: $e');
      return _processMockScan(batchId: batchId, context: context);
    }
  }

  /// Process a scan by batch number (OCR flow — no QR code available).
  Future<QrScanResult> processScanByBatchNumber({
    required String batchNumber,
    required ScanContext context,
  }) async {
    // Fetch batch ID for the given batch number
    try {
      if (!_isMock) {
        final data = await _client
            .from('medicine_batches')
            .select('id')
            .eq('batch_number', batchNumber)
            .single();
        final batchId = data['id'] as String;
        return processScan(
          qrPayload: encodeBatchQr(batchId),
          context: context,
        );
      }
    } catch (_) {}

    // Mock path
    final batch = MockDatabase.instance.getBatchByNumber(batchNumber);
    if (batch == null) {
      return QrScanResult.error('Batch $batchNumber not found in system.');
    }
    return _processMockScanFromBatch(batch: batch, context: context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Offline/Mock scan processing (mirrors server RPC logic)
  // ─────────────────────────────────────────────────────────────────────────

  Future<QrScanResult> _processMockScan({
    required String batchId,
    required ScanContext context,
  }) async {
    final batch = MockDatabase.instance.getBatchById(batchId);
    if (batch == null) {
      return QrScanResult(
        ok: false,
        error: 'Batch not found',
        fraud: true,
        fraudType: 'INVALID_BATCH',
        fraudSeverity: 'MEDIUM',
        fraudDescription: 'Batch ID $batchId does not exist in the system.',
      );
    }
    return _processMockScanFromBatch(batch: batch, context: context);
  }

  QrScanResult _processMockScanFromBatch({
    required MedicineBatch batch,
    required ScanContext context,
  }) {
    // Skip fraud for audit contexts
    if (context.isAuditSafe) {
      return QrScanResult(
        ok: true,
        batchId: batch.id,
        batchNumber: batch.batchNumber,
        batchStatus: batch.status,
        fraud: false,
      );
    }

    // Rule 1: DESTROYED_BATCH_REENTRY
    if ((batch.status == 'DESTROYED' || batch.status == 'CLOSED') &&
        context.triggersDestroyedReentry) {
      return QrScanResult(
        ok: true,
        batchId: batch.id,
        batchNumber: batch.batchNumber,
        batchStatus: batch.status,
        fraud: true,
        fraudType: 'DESTROYED_BATCH_REENTRY',
        fraudSeverity: 'CRITICAL',
        fraudDescription:
            'Batch ${batch.batchNumber} has status ${batch.status} but was '
            'scanned for ${context.label}. This is a critical fraud signal.',
      );
    }

    // Rule 3: EXPIRED_BATCH_SALE
    if (batch.expiryDate.isBefore(DateTime.now()) &&
        (batch.status == 'ACTIVE' || batch.status == 'EXPIRING_SOON') &&
        (context == ScanContext.activeStockCheck ||
            context == ScanContext.inventoryCheck)) {
      return QrScanResult(
        ok: true,
        batchId: batch.id,
        batchNumber: batch.batchNumber,
        batchStatus: batch.status,
        fraud: true,
        fraudType: 'EXPIRED_BATCH_SALE',
        fraudSeverity: 'HIGH',
        fraudDescription:
            'Batch ${batch.batchNumber} expired on '
            '${batch.expiryDate.toIso8601String().substring(0, 10)} '
            'but is recorded as ${batch.status} inventory.',
      );
    }

    return QrScanResult(
      ok: true,
      batchId: batch.id,
      batchNumber: batch.batchNumber,
      batchStatus: batch.status,
      fraud: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Fetch fraud alert details for a scan result (for narrative generation)
  // ─────────────────────────────────────────────────────────────────────────

  Future<FraudAlert?> getAlertById(String alertId) async {
    try {
      final data = await _client.from('fraud_alerts').select('''
        *,
        medicine_batches(batch_number, medicines(name)),
        organizations(name)
      ''').eq('id', alertId).single();
      return FraudAlert.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
