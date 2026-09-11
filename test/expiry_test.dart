import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/services/batch_lifecycle_service.dart';
import 'package:mediloop/models/medicine_batch.dart';

void main() {
  group('Batch Expiry Calculation & Validation Tests', () {
    test('Calculates ACTIVE when expiry date is well in the future', () {
      final futureDate = DateTime.now().add(const Duration(days: 180));
      final status = BatchLifecycleService.calculateExpiryStatus(futureDate);
      expect(status, 'ACTIVE');
    });

    test('Calculates EXPIRING_SOON when expiry date is within warning window', () {
      final soonDate = DateTime.now().add(const Duration(days: 30));
      final status = BatchLifecycleService.calculateExpiryStatus(soonDate, warningDays: 90);
      expect(status, 'EXPIRING_SOON');
    });

    test('Calculates EXPIRED when expiry date is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final status = BatchLifecycleService.calculateExpiryStatus(pastDate);
      expect(status, 'EXPIRED');
    });

    test('Detects stale status when stored status is ACTIVE but date is expired', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final isStale = BatchLifecycleService.isExpiryStatusStale(pastDate, 'ACTIVE');
      expect(isStale, isTrue);
    });

    test('Batches in reverse chain or DESTROYED are not flagged as stale', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 50));
      expect(BatchLifecycleService.isExpiryStatusStale(pastDate, 'DESTROYED'), isFalse);
      expect(BatchLifecycleService.isExpiryStatusStale(pastDate, 'RETURN_INITIATED'), isFalse);
      expect(BatchLifecycleService.isExpiryStatusStale(pastDate, 'COLLECTED'), isFalse);
      expect(BatchLifecycleService.isExpiryStatusStale(pastDate, 'DISPOSAL_PENDING'), isFalse);
    });

    test('MedicineBatch model expiry getters work deterministically', () {
      final now = DateTime.now();
      final expiredBatch = MedicineBatch(
        id: 'test-01',
        medicineId: 'med-01',
        batchNumber: 'EXP-001',
        manufacturingDate: now.subtract(const Duration(days: 400)),
        expiryDate: now.subtract(const Duration(days: 1)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'ACTIVE',
      );

      expect(expiredBatch.isExpired, isTrue);
      expect(expiredBatch.isExpiringSoon, isFalse);
      expect(expiredBatch.expiryStatusCalculated, 'EXPIRED');

      final soonBatch = MedicineBatch(
        id: 'test-02',
        medicineId: 'med-02',
        batchNumber: 'SOON-002',
        manufacturingDate: now.subtract(const Duration(days: 100)),
        expiryDate: now.add(const Duration(days: 45)),
        originalQuantity: 50,
        currentQuantity: 50,
        status: 'ACTIVE',
      );

      expect(soonBatch.isExpired, isFalse);
      expect(soonBatch.isExpiringSoon, isTrue);
      expect(soonBatch.expiryStatusCalculated, 'EXPIRING_SOON');
    });
  });
}
