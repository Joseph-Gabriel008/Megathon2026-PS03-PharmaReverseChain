import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/batch_event.dart';
import 'package:mediloop/services/hash_service.dart';
import 'package:mediloop/services/audit_service.dart';

void main() {
  group('Cryptographic Audit Chain & Tamper Detection Tests', () {
    test('SHA-256 hash generation is deterministic and non-empty', () {
      final hash1 = HashService.sha256Hash('test-input-payload');
      final hash2 = HashService.sha256Hash('test-input-payload');
      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
    });

    test('Computes valid sequential SHA-256 event hash chain', () {
      // Genesis block
      final genesisData = '{"batch_id":"b-1","type":"BATCH_CREATED"}';
      final genesisHash = HashService.computeEventHash(
        previousHash: '',
        eventData: genesisData,
      );
      expect(genesisHash.isNotEmpty, isTrue);

      // Block 1
      final block1Data = '{"batch_id":"b-1","type":"RETURN_INITIATED"}';
      final block1Hash = HashService.computeEventHash(
        previousHash: genesisHash,
        eventData: block1Data,
      );
      expect(block1Hash.isNotEmpty, isTrue);
      expect(block1Hash, isNot(equals(genesisHash)));

      // Block 2
      final block2Data = '{"batch_id":"b-1","type":"COLLECTED"}';
      final block2Hash = HashService.computeEventHash(
        previousHash: block1Hash,
        eventData: block2Data,
      );
      expect(block2Hash.isNotEmpty, isTrue);
      expect(block2Hash, isNot(equals(block1Hash)));
    });

    test('AuditVerificationResult.localVerify validates intact cryptographic chain', () {
      final e1Data = '{"batch_id":"b-1","event_type":"BATCH_CREATED","actor_id":"u-1","quantity":100,"new_status":"ACTIVE","timestamp":"2026-01-01T00:00:00.000"}';
      final h1 = HashService.computeEventHash(previousHash: '', eventData: e1Data);

      final e2Data = '{"batch_id":"b-1","event_type":"RETURN_INITIATED","actor_id":"u-1","quantity":100,"new_status":"RETURN_INITIATED","timestamp":"2026-01-02T00:00:00.000"}';
      final h2 = HashService.computeEventHash(previousHash: h1, eventData: e2Data);

      final events = [
        BatchEvent(
          id: 'evt-1',
          batchId: 'b-1',
          eventType: 'BATCH_CREATED',
          actorId: 'u-1',
          organizationId: 'org-1',
          quantity: 100,
          newStatus: 'ACTIVE',
          timestamp: DateTime.parse('2026-01-01T00:00:00.000'),
          eventHash: h1,
          previousEventHash: null,
        ),
        BatchEvent(
          id: 'evt-2',
          batchId: 'b-1',
          eventType: 'RETURN_INITIATED',
          actorId: 'u-1',
          organizationId: 'org-1',
          quantity: 100,
          previousStatus: 'ACTIVE',
          newStatus: 'RETURN_INITIATED',
          timestamp: DateTime.parse('2026-01-02T00:00:00.000'),
          eventHash: h2,
          previousEventHash: h1,
        ),
      ];

      final result = AuditVerificationResult.localVerify(events);
      expect(result.valid, isTrue);
      expect(result.eventsChecked, 2);
      expect(result.issueDescription, isNull);
    });

    test('AuditVerificationResult.localVerify catches tampered/corrupted hash block', () {
      final events = [
        BatchEvent(
          id: 'evt-1',
          batchId: 'b-1',
          eventType: 'BATCH_CREATED',
          actorId: 'u-1',
          organizationId: 'org-1',
          quantity: 100,
          newStatus: 'ACTIVE',
          timestamp: DateTime.parse('2026-01-01T00:00:00.000'),
          eventHash: 'valid-genesis-hash',
          previousEventHash: null,
        ),
        BatchEvent(
          id: 'evt-2',
          batchId: 'b-1',
          eventType: 'RETURN_INITIATED',
          actorId: 'u-1',
          organizationId: 'org-1',
          quantity: 100,
          previousStatus: 'ACTIVE',
          newStatus: 'RETURN_INITIATED',
          timestamp: DateTime.parse('2026-01-02T00:00:00.000'),
          // Broken chain: does not link back to evt-1's hash!
          eventHash: 'tampered-hash-value',
          previousEventHash: 'corrupted-previous-link',
        ),
      ];

      final result = AuditVerificationResult.localVerify(events);
      expect(result.valid, isFalse);
      expect(result.issueDescription, isNotNull);
    });
  });
}
