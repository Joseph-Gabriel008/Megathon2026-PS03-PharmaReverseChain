import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/medicine_batch.dart';
import 'package:mediloop/models/scan_context.dart';
import 'package:mediloop/services/fraud_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Standalone fake client for testing
class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('Fraud Detection Rules & Context-Aware Engine Tests', () {
    late FraudDetectionService fraudService;

    setUp(() {
      fraudService = FraudDetectionService(_FakeSupabaseClient());
    });

    test('Rule 1: Triggers CRITICAL alert on DESTROYED batch scanned in active context', () async {
      final now = DateTime.now();
      final destroyedBatch = MedicineBatch(
        id: 'destroyed-001',
        medicineId: 'med-01',
        batchNumber: 'DEST-999',
        manufacturingDate: now.subtract(const Duration(days: 500)),
        expiryDate: now.subtract(const Duration(days: 100)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'DESTROYED',
      );

      final result = await fraudService.analyzeScan(
        batch: destroyedBatch,
        scannedByUserId: 'usr-01',
        scannedByOrgId: 'org-01',
        context: ScanContext.activeStockCheck,
      );

      expect(result.isSuspicious, isTrue);
      expect(result.alertType, 'DESTROYED_BATCH_REENTRY');
      expect(result.severity, 'CRITICAL');
      expect(result.recommendedAction, contains('Seize batch'));
    });

    test('Context Awareness: AUDIT_VIEW skips DESTROYED_BATCH_REENTRY to prevent false positives', () async {
      final now = DateTime.now();
      final destroyedBatch = MedicineBatch(
        id: 'destroyed-001',
        medicineId: 'med-01',
        batchNumber: 'DEST-999',
        manufacturingDate: now.subtract(const Duration(days: 500)),
        expiryDate: now.subtract(const Duration(days: 100)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'DESTROYED',
      );

      final result = await fraudService.analyzeScan(
        batch: destroyedBatch,
        scannedByUserId: 'usr-regulator',
        scannedByOrgId: 'org-regulator',
        context: ScanContext.auditView,
      );

      expect(result.isSuspicious, isFalse);
      expect(result.alertType, isNull);
    });

    test('Rule 2: Triggers HIGH alert on QUANTITY_MISMATCH', () async {
      final now = DateTime.now();
      final batch = MedicineBatch(
        id: 'batch-001',
        medicineId: 'med-01',
        batchNumber: 'QTY-100',
        manufacturingDate: now.subtract(const Duration(days: 30)),
        expiryDate: now.add(const Duration(days: 300)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'ACTIVE',
      );

      final result = await fraudService.analyzeScan(
        batch: batch,
        scannedByUserId: 'usr-dist',
        scannedByOrgId: 'org-dist',
        context: ScanContext.distributorPickup,
        expectedQuantity: 100,
        actualQuantity: 80,
      );

      expect(result.isSuspicious, isTrue);
      expect(result.alertType, 'QUANTITY_MISMATCH');
      expect(result.severity, 'HIGH');
      expect(result.recommendedAction, contains('Recount'));
    });

    test('Rule 3: Triggers HIGH alert on EXPIRED batch scanned in active stock check', () async {
      final now = DateTime.now();
      final expiredBatch = MedicineBatch(
        id: 'exp-001',
        medicineId: 'med-01',
        batchNumber: 'EXP-123',
        manufacturingDate: now.subtract(const Duration(days: 400)),
        expiryDate: now.subtract(const Duration(days: 30)),
        originalQuantity: 50,
        currentQuantity: 50,
        status: 'ACTIVE',
      );

      final result = await fraudService.analyzeScan(
        batch: expiredBatch,
        scannedByUserId: 'usr-ret',
        scannedByOrgId: 'org-ret',
        context: ScanContext.activeStockCheck,
      );

      expect(result.isSuspicious, isTrue);
      expect(result.alertType, 'EXPIRED_BATCH_SALE');
      expect(result.severity, 'HIGH');
      expect(result.recommendedAction, contains('Remove from shelf'));
    });

    test('Verified scan: Legitimate active batch with matching details returns clean result', () async {
      final now = DateTime.now();
      final validBatch = MedicineBatch(
        id: 'valid-001',
        medicineId: 'med-01',
        batchNumber: 'VALID-777',
        manufacturingDate: now.subtract(const Duration(days: 30)),
        expiryDate: now.add(const Duration(days: 300)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'ACTIVE',
      );

      final result = await fraudService.analyzeScan(
        batch: validBatch,
        scannedByUserId: 'usr-ret',
        scannedByOrgId: 'org-ret',
        context: ScanContext.activeStockCheck,
      );

      expect(result.isSuspicious, isFalse);
      expect(result.alertType, isNull);
      expect(result.recommendedAction, isNull);
    });
  });
}
