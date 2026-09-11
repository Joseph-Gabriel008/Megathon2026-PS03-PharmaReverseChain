import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/reverse_request.dart';

void main() {
  group('Distributor Pickup effectiveStage Lifecycle Mapping', () {
    test('effectiveStage resolves IN_PROGRESS + ACCEPTED correctly to ACCEPTED', () {
      final req = ReverseRequest(
        id: 'rev-1',
        batchId: 'batch-1',
        retailerId: 'org-pharmacy',
        requestedQuantity: 20,
        status: 'ACCEPTED',
        reason: 'EXPIRED',
        batchNumber: 'BATCH-AMOX-01',
        medicineName: 'Amoxicillin 500mg',
        initiatedAt: DateTime.now(),
      );

      final pickup = Pickup(
        id: 'pickup-1',
        reverseRequestId: 'rev-1',
        pickupStatus: 'IN_PROGRESS',
        distributorId: 'dist-user',
        scheduledDate: DateTime.now(),
        reverseRequest: req,
      );

      expect(pickup.effectiveStage, 'ACCEPTED');
    });

    test('effectiveStage resolves IN_TRANSIT correctly to COLLECTED', () {
      final req = ReverseRequest(
        id: 'rev-2',
        batchId: 'batch-2',
        retailerId: 'org-pharmacy',
        requestedQuantity: 50,
        status: 'IN_TRANSIT',
        reason: 'RECALLED',
        batchNumber: 'BATCH-MET-02',
        medicineName: 'Metformin 850mg',
        initiatedAt: DateTime.now(),
      );

      final pickup = Pickup(
        id: 'pickup-2',
        reverseRequestId: 'rev-2',
        pickupStatus: 'IN_PROGRESS',
        distributorId: 'dist-user',
        actualQuantity: 50,
        scheduledDate: DateTime.now(),
        reverseRequest: req,
      );

      expect(pickup.effectiveStage, 'COLLECTED');
    });

    test('effectiveStage resolves COMPLETED correctly to COMPLETED', () {
      final req = ReverseRequest(
        id: 'rev-3',
        batchId: 'batch-3',
        retailerId: 'org-pharmacy',
        requestedQuantity: 10,
        status: 'COMPLETED',
        reason: 'DAMAGED',
        batchNumber: 'BATCH-PARA-03',
        medicineName: 'Paracetamol 650mg',
        initiatedAt: DateTime.now(),
      );

      final pickup = Pickup(
        id: 'pickup-3',
        reverseRequestId: 'rev-3',
        pickupStatus: 'COMPLETED',
        distributorId: 'dist-user',
        actualQuantity: 10,
        scheduledDate: DateTime.now(),
        reverseRequest: req,
      );

      expect(pickup.effectiveStage, 'COMPLETED');
    });

    test('effectiveStage defaults to ASSIGNED when newly scheduled', () {
      final req = ReverseRequest(
        id: 'rev-4',
        batchId: 'batch-4',
        retailerId: 'org-pharmacy',
        requestedQuantity: 30,
        status: 'PENDING',
        reason: 'EXPIRED',
        batchNumber: 'BATCH-AZI-04',
        medicineName: 'Azithromycin 250mg',
        initiatedAt: DateTime.now(),
      );

      final pickup = Pickup(
        id: 'pickup-4',
        reverseRequestId: 'rev-4',
        pickupStatus: 'SCHEDULED',
        distributorId: 'dist-user',
        scheduledDate: DateTime.now(),
        reverseRequest: req,
      );

      expect(pickup.effectiveStage, 'ASSIGNED');
    });
  });

  group('Distributor Counter Product Verification Match Logic Tests', () {
    test('Product verification accepts exact or normalized batch number match', () {
      final expectedBatch = 'AMOX-2024-001';
      final scannedRight = 'amox-2024-001';
      final scannedQr = 'MEDILOOP:BATCH:AMOX-2024-001';
      final scannedPipe = 'MEDILOOP|AMOX-2024-001|med-01|2026-12-31';

      bool matches(String input, String expected) {
        final upper = input.trim().toUpperCase();
        final exp = expected.trim().toUpperCase();
        String candidate = upper;
        if (candidate.startsWith('MEDILOOP:BATCH:')) {
          candidate = candidate.replaceFirst('MEDILOOP:BATCH:', '').trim();
        } else if (candidate.startsWith('MEDILOOP|')) {
          final parts = candidate.split('|');
          if (parts.length > 1) candidate = parts[1].trim();
        }
        return candidate == exp || candidate.contains(exp) || exp.contains(candidate);
      }

      expect(matches(scannedRight, expectedBatch), isTrue);
      expect(matches(scannedQr, expectedBatch), isTrue);
      expect(matches(scannedPipe, expectedBatch), isTrue);
      expect(matches('WRONG-BATCH-999', expectedBatch), isFalse);
    });
  });
}
