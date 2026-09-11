import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/medicine_batch.dart';
import 'package:mediloop/models/disposal_record.dart';
import 'package:mediloop/repositories/disposal_repository.dart';
import 'package:mediloop/widgets/cdsco_certificate_viewer.dart';
import 'package:mediloop/widgets/batch_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('CDSCO Destruction Certificate & Enhanced Repository Tests', () {
    test('DisposalRepository fetches certificates and links to batch-006', () async {
      final disposalRepo = DisposalRepository(_FakeSupabaseClient());
      final certs = await disposalRepo.getCertificates();
      expect(certs.isNotEmpty, isTrue);

      final cert001 = certs.firstWhere((c) => c.certificateNumber == 'CDSCO-CERT-2026-004812');
      expect(cert001.batchId, 'batch-006');
      expect(cert001.hash.isNotEmpty, isTrue);

      final byBatch = await disposalRepo.getCertificateByBatchId('batch-006');
      expect(byBatch, isNotNull);
      expect(byBatch!.certificateNumber, 'CDSCO-CERT-2026-004812');
    });

    testWidgets('CdscoCertificateViewer renders Form 48 and compliance seals', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final cert = DestructionCertificate(
        id: 'cert-test-01',
        disposalRecordId: 'disp-test-01',
        batchId: 'batch-006',
        certificateNumber: 'CDSCO-CERT-2026-004812',
        verificationStatus: 'VERIFIED',
        issuedDate: DateTime(2026, 8, 27),
        hash: 'a8f3b9c2401f8d93e117b4c892e59123049bca71049281bfd8e90a12c418e244',
      );

      final batch = MedicineBatch(
        id: 'batch-006',
        batchNumber: 'CETR10-2024-003',
        medicineId: 'med-06',
        medicineName: 'Cetirizine 10mg',
        genericName: 'Cetirizine Hydrochloride',
        manufacturerId: 'org-manufacturer-01',
        manufacturingDate: DateTime(2024, 1, 1),
        expiryDate: DateTime(2025, 1, 1),
        originalQuantity: 150,
        currentQuantity: 150,
        status: 'DESTROYED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CdscoCertificateViewer(
              certificate: cert,
              batch: batch,
              facilityName: 'BioClean Bio-Medical Waste Facility',
              disposalMethod: 'High-Temperature Incineration (1100°C)',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('FORM 48 — CERTIFICATE OF DRUG DESTRUCTION'), findsOneWidget);
      expect(find.text('CDSCO-CERT-2026-004812'), findsOneWidget);
      expect(find.text('VERIFIED & DECOMMISSIONED'), findsOneWidget);
      expect(find.text('Cetirizine 10mg'), findsOneWidget);
    });
  });

  group('BatchCard Expiry Urgency Countdowns', () {
    testWidgets('Renders closed-loop decommissioned banner on DESTROYED batch', (tester) async {
      final destroyedBatch = MedicineBatch(
        id: 'batch-006',
        batchNumber: 'CETR10-2024-003',
        medicineId: 'med-06',
        medicineName: 'Cetirizine 10mg',
        manufacturerId: 'org-manufacturer-01',
        manufacturingDate: DateTime(2024, 1, 1),
        expiryDate: DateTime.now().subtract(const Duration(days: 100)),
        originalQuantity: 150,
        currentQuantity: 150,
        status: 'DESTROYED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchCard(batch: destroyedBatch),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CDSCO Closed-Loop Decommissioned'), findsOneWidget);
    });

    testWidgets('Renders EXPIRED banner on expired batch', (tester) async {
      final expiredBatch = MedicineBatch(
        id: 'batch-002',
        batchNumber: 'AMOX500-2025-089',
        medicineId: 'med-02',
        medicineName: 'Amoxicillin 500mg',
        manufacturerId: 'org-manufacturer-01',
        manufacturingDate: DateTime(2024, 1, 1),
        expiryDate: DateTime.now().subtract(const Duration(days: 45)),
        originalQuantity: 120,
        currentQuantity: 120,
        status: 'EXPIRED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchCard(batch: expiredBatch),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('EXPIRED 45 DAYS AGO'), findsOneWidget);
    });
  });
}
