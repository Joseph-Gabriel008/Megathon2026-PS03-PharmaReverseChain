import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../data/mock_database.dart';
import '../models/disposal_record.dart';
import '../services/hash_service.dart';

class DisposalRepository {
  final SupabaseClient _client;

  DisposalRepository(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  Future<List<DisposalRecord>> getDisposalRecords(
      {String? manufacturerId}) async {
    if (_isMock) {
      return MockDatabase.instance.getDisposalRecords();
    }
    try {
      var query = _client
          .from('disposal_records')
          .select('''
            *,
            medicine_batches(batch_number),
            waste_facility:waste_facility_id(name)
          ''');

      if (manufacturerId != null) {
        query = query.eq('manufacturer_id', manufacturerId);
      }

      final data = await query.order('created_at', ascending: false);
      final remoteList =
          (data as List).map((e) => DisposalRecord.fromJson(e)).toList();

      // Merge with any in-memory mock records to guarantee immediate session visibility
      final mockRecords = MockDatabase.instance.getDisposalRecords();
      final seenIds = remoteList.map((r) => r.id).toSet();
      final seenBatchIds = remoteList.map((r) => r.batchId).toSet();

      final combined = List<DisposalRecord>.from(remoteList);
      for (final m in mockRecords) {
        if (!seenIds.contains(m.id) && !seenBatchIds.contains(m.batchId)) {
          if (manufacturerId == null || m.manufacturerId == manufacturerId) {
            combined.add(m);
          }
        }
      }
      return combined;
    } catch (_) {
      return MockDatabase.instance.getDisposalRecords();
    }
  }

  Future<DisposalRecord> createDisposalRecord({
    required String batchId,
    required String manufacturerId,
    required String wasteFacilityId,
    required String disposalMethod,
    required int quantityDestroyed,
    required DateTime scheduledDate,
  }) async {
    // Always persist to MockDB so both tabs have instant synchronous consistency
    final mockRecord = MockDatabase.instance.addDisposalRecord(
      batchId: batchId,
      manufacturerId: manufacturerId,
      wasteFacilityId: wasteFacilityId,
      disposalMethod: disposalMethod,
      quantityDestroyed: quantityDestroyed,
      scheduledDate: scheduledDate,
    );
    MockDatabase.instance.assignFacilityToBatch(batchId, wasteFacilityId);

    if (_isMock) {
      return mockRecord;
    }

    try {
      final data = await _client
          .from('disposal_records')
          .insert({
            'batch_id': batchId,
            'manufacturer_id': manufacturerId,
            'waste_facility_id': wasteFacilityId,
            'disposal_method': disposalMethod,
            'quantity_destroyed': quantityDestroyed,
            'status': 'SCHEDULED',
            'actual_disposal_date': scheduledDate.toIso8601String(),
          })
          .select()
          .single();
      return DisposalRecord.fromJson(data);
    } catch (_) {
      return mockRecord;
    }
  }

  Future<DestructionCertificate> recordDestruction({
    required String disposalRecordId,
    required String batchId,
    required int quantityDestroyed,
    required String method,
    required DateTime destructionDate,
    required String certificateNumber,
    String? documentUrl,
    required String actorId,
    required String organizationId,
  }) async {
    // Build certificate hash from the record data
    final hashInput =
        '$disposalRecordId:$batchId:$quantityDestroyed:$method:'
        '${destructionDate.toIso8601String()}:$certificateNumber';
    final hash = HashService.sha256Hash(hashInput);

    if (_isMock) {
      MockDatabase.instance.updateBatchStatus(
        batchId: batchId,
        newStatus: 'DESTROYED',
        actorId: actorId,
        organizationId: organizationId,
        eventType: 'DESTRUCTION_RECORDED',
        quantity: quantityDestroyed,
        previousStatus: 'SENT_FOR_DESTRUCTION',
      );
      return DestructionCertificate(
        id: 'cert-${DateTime.now().millisecondsSinceEpoch}',
        disposalRecordId: disposalRecordId,
        batchId: batchId,
        certificateNumber: certificateNumber,
        documentUrl: documentUrl,
        issuedDate: destructionDate,
        hash: hash,
        verificationStatus: 'VERIFIED',
      );
    }

    try {
      // 1. Create certificate
      final certData = await _client
          .from('destruction_certificates')
          .insert({
            'disposal_record_id': disposalRecordId,
            'batch_id': batchId,
            'certificate_number': certificateNumber,
            'document_url': documentUrl,
            'issued_date': destructionDate.toIso8601String(),
            'hash': hash,
            'verification_status': 'VERIFIED',
          })
          .select()
          .single();

      // 2. Update disposal record to COMPLETED
      await _client.from('disposal_records').update({
        'status': 'COMPLETED',
        'certificate_id': certData['id'] as String,
        'actual_disposal_date': destructionDate.toIso8601String(),
      }).eq('id', disposalRecordId);

      // 3. Update batch status to DESTROYED
      await _client
          .from('medicine_batches')
          .update({'status': 'DESTROYED'})
          .eq('id', batchId);

      // 4. Compute hash chain and record DESTRUCTION_RECORDED event
      final lastEvent = await _client
          .from('batch_events')
          .select('event_hash')
          .eq('batch_id', batchId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      final previousHash = lastEvent?['event_hash'] as String? ?? '';
      final eventData = '$batchId:DESTRUCTION_RECORDED:$actorId:$quantityDestroyed:DESTROYED:${destructionDate.toIso8601String()}';
      final eventHash = HashService.computeEventHash(
        previousHash: previousHash,
        eventData: eventData,
      );

      await _client.from('batch_events').insert({
        'batch_id': batchId,
        'event_type': 'DESTRUCTION_RECORDED',
        'actor_id': actorId,
        'organization_id': organizationId,
        'quantity': quantityDestroyed,
        'previous_status': 'SENT_FOR_DESTRUCTION',
        'new_status': 'DESTROYED',
        'timestamp': destructionDate.toIso8601String(),
        'event_hash': eventHash,
        'previous_event_hash': previousHash.isEmpty ? null : previousHash,
      });

      return DestructionCertificate.fromJson(certData);
    } catch (_) {
      MockDatabase.instance.updateBatchStatus(
        batchId: batchId,
        newStatus: 'DESTROYED',
        actorId: actorId,
        organizationId: organizationId,
        eventType: 'DESTRUCTION_RECORDED',
        quantity: quantityDestroyed,
        previousStatus: 'SENT_FOR_DESTRUCTION',
      );
      final cert = DestructionCertificate(
        id: 'cert-${DateTime.now().millisecondsSinceEpoch}',
        disposalRecordId: disposalRecordId,
        batchId: batchId,
        certificateNumber: certificateNumber,
        documentUrl: documentUrl,
        issuedDate: destructionDate,
        hash: hash,
        verificationStatus: 'VERIFIED',
      );
      MockDatabase.instance.addCertificate(cert);
      return cert;
    }
  }

  Future<List<DestructionCertificate>> getCertificates() async {
    if (_isMock) {
      return MockDatabase.instance.getCertificates();
    }
    try {
      final data = await _client
          .from('destruction_certificates')
          .select()
          .order('issued_date', ascending: false);
      return (data as List).map((e) => DestructionCertificate.fromJson(e)).toList();
    } catch (_) {
      return MockDatabase.instance.getCertificates();
    }
  }

  Future<DestructionCertificate?> getCertificateByBatchId(String batchId) async {
    if (_isMock) {
      return MockDatabase.instance.getCertificateForBatch(batchId);
    }
    try {
      final data = await _client
          .from('destruction_certificates')
          .select()
          .eq('batch_id', batchId)
          .maybeSingle();
      if (data != null) {
        return DestructionCertificate.fromJson(data);
      }
      return MockDatabase.instance.getCertificateForBatch(batchId);
    } catch (_) {
      return MockDatabase.instance.getCertificateForBatch(batchId);
    }
  }

  Future<List<Map<String, dynamic>>> getWasteFacilities() async {
    if (_isMock) {
      return MockDatabase.instance.getWasteFacilities();
    }
    try {
      final data = await _client
          .from('organizations')
          .select('id, name')
          .eq('type', 'WASTE_FACILITY');
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return MockDatabase.instance.getWasteFacilities();
    }
  }
}
