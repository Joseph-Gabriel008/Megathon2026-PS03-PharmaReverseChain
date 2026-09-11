import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/data/mock_database.dart';
import 'package:mediloop/models/disposal_record.dart';

void main() {
  setUp(() {
    MockDatabase.instance.reset();
  });

  group('Disposal Forwarding & Waste Facility Queue Tests', () {
    test('Forwarding a batch to disposal registers in both manufacturer records and facility queue', () {
      final db = MockDatabase.instance;
      const testBatchId = 'batch-007'; // LEVO500-2026-031
      const wasteFacilityUuid = '44444444-0000-0000-0000-000000000001';
      const mfgId = '33333333-0000-0000-0000-000000000001';

      // 1. Manufacturer creates disposal record
      final scheduledDate = DateTime.now().add(const Duration(days: 7));
      final record = db.addDisposalRecord(
        batchId: testBatchId,
        manufacturerId: mfgId,
        wasteFacilityId: wasteFacilityUuid,
        disposalMethod: 'INCINERATION',
        quantityDestroyed: 75,
        scheduledDate: scheduledDate,
      );

      expect(record.status, equals('SCHEDULED'));
      expect(record.batchId, equals(testBatchId));

      // 2. Manufacturer transitions batch status to SENT_FOR_DESTRUCTION
      db.updateBatchStatus(
        batchId: testBatchId,
        newStatus: 'SENT_FOR_DESTRUCTION',
        actorId: 'user-mfg-01',
        organizationId: mfgId,
        eventType: 'DISPOSAL_SCHEDULED',
        quantity: 75,
        wasteFacilityId: wasteFacilityUuid,
      );

      // 3. Batch in MockDatabase now has SENT_FOR_DESTRUCTION
      final updatedBatch = db.getBatchById(testBatchId);
      expect(updatedBatch, isNotNull);
      expect(updatedBatch!.status, equals('SENT_FOR_DESTRUCTION'));

      // 4. Waste facility queries assigned batches using live UUID
      final assignedWithUuid = db.getAssignedToFacility(wasteFacilityUuid);
      expect(assignedWithUuid.any((b) => b.id == testBatchId), isTrue);

      // 5. Waste facility queries assigned batches using mock string ID
      final assignedWithMockId = db.getAssignedToFacility('org-facility-01');
      expect(assignedWithMockId.any((b) => b.id == testBatchId), isTrue);

      // 6. Manufacturer disposal records include the newly scheduled record
      final records = db.getDisposalRecords();
      expect(records.any((r) => r.batchId == testBatchId && r.status == 'SCHEDULED'), isTrue);
    });

    test('DisposalRecord.fromJson parses waste_facility format and fallback correctly', () {
      final postgrestJson = {
        'id': 'disp-001',
        'batch_id': 'batch-001',
        'medicine_batches': {'batch_number': 'TEST-BATCH-001'},
        'manufacturer_id': 'mfg-01',
        'waste_facility_id': '44444444-0000-0000-0000-000000000001',
        'waste_facility': {'name': 'BioClean Bio-Medical Waste Facility'},
        'disposal_method': 'INCINERATION',
        'actual_disposal_date': '2026-09-18T00:00:00.000',
        'quantity_destroyed': 100,
        'status': 'SCHEDULED',
        'certificate_id': null,
      };

      final record = DisposalRecord.fromJson(postgrestJson);
      expect(record.id, equals('disp-001'));
      expect(record.batchNumber, equals('TEST-BATCH-001'));
      expect(record.wasteFacilityName, equals('BioClean Bio-Medical Waste Facility'));
      expect(record.status, equals('SCHEDULED'));
    });
  });
}
