import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/disposal_record.dart';
import 'package:mediloop/services/certificate_service.dart';
import 'package:mediloop/services/hash_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('Destruction Certificate & Verification Tests', () {
    test('DestructionCertificate serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final cert = DestructionCertificate(
        id: 'cert-123',
        disposalRecordId: 'disp-456',
        batchId: 'batch-789',
        certificateNumber: 'CERT-2026-001',
        documentUrl: 'https://example.com/cert.pdf',
        documentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        verificationStatus: 'VERIFIED',
        issuedDate: now,
        hash: 'abc123hash',
      );

      final json = cert.toJson();
      expect(json['disposal_record_id'], 'disp-456');
      expect(json['batch_id'], 'batch-789');
      expect(json['certificate_number'], 'CERT-2026-001');
      expect(json['verification_status'], 'VERIFIED');

      final deserialized = DestructionCertificate.fromJson({
        'id': 'cert-123',
        'disposal_record_id': 'disp-456',
        'batch_id': 'batch-789',
        'certificate_number': 'CERT-2026-001',
        'document_url': 'https://example.com/cert.pdf',
        'document_hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'verification_status': 'VERIFIED',
        'issued_date': now.toIso8601String(),
        'hash': 'abc123hash',
      });

      expect(deserialized.id, cert.id);
      expect(deserialized.certificateNumber, cert.certificateNumber);
      expect(deserialized.verificationStatus, 'VERIFIED');
    });

    test('Certificate integrity hash generation includes all critical fields', () {
      const disposalRecordId = 'disp-001';
      const batchId = 'batch-001';
      const quantityDestroyed = 150;
      const method = 'HIGH_TEMP_INCINERATION';
      final destructionDate = DateTime.parse('2026-03-31T10:00:00.000Z');
      const certificateNumber = 'DISP-CERT-9901';

      final hashInput = '$disposalRecordId:$batchId:$quantityDestroyed:$method:'
          '${destructionDate.toIso8601String()}:$certificateNumber';
      final hash1 = HashService.sha256Hash(hashInput);
      final hash2 = HashService.sha256Hash(hashInput);

      expect(hash1, equals(hash2));
      expect(hash1.length, 64);

      // Any alteration to quantity or date changes the certificate hash
      final alteredInput = '$disposalRecordId:$batchId:149:$method:'
          '${destructionDate.toIso8601String()}:$certificateNumber';
      final alteredHash = HashService.sha256Hash(alteredInput);
      expect(hash1, isNot(equals(alteredHash)));
    });

    test('CertificateService mock completion generates valid certificate ID', () async {
      final certService = CertificateService(_FakeSupabaseClient());
      final result = await certService.completeDisposal(
        disposalRecordId: 'disp-test-01',
        certificateNumber: 'CERT-TEST-99',
        quantityDestroyed: 100,
        disposalDate: DateTime.now(),
      );

      expect(result.ok, isTrue);
      expect(result.certificateId, isNotNull);
      expect(result.error, isNull);
    });

    test('CertificateService static computeStringHash is deterministic SHA-256', () {
      final h1 = CertificateService.computeStringHash('mediloop-certificate-content');
      final h2 = CertificateService.computeStringHash('mediloop-certificate-content');
      expect(h1, equals(h2));
      expect(h1.length, 64);
    });
  });
}
