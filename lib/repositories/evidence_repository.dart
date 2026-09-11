// lib/repositories/evidence_repository.dart
//
// CRUD for batch_evidence table.
// Called by EvidenceService — not used directly by UI.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/batch_evidence.dart';

class EvidenceRepository {
  final SupabaseClient _client;

  EvidenceRepository(this._client);

  /// Insert a new evidence record immediately after upload.
  /// Returns the persisted BatchEvidence with server-assigned id and
  /// server_received_at timestamp.
  Future<BatchEvidence> createEvidence({
    required String batchId,
    required String actorId,
    required String organizationId,
    required String evidenceType,
    required String storagePath,
    required bool qrVerified,
    String? qrBatchIdFound,
    String? captureSessionId,
    double? latitude,
    double? longitude,
    String? evidenceSha256,
    String? deviceInfo,
    DateTime? clientCapturedAt,
  }) async {
    final payload = <String, dynamic>{
      'batch_id':         batchId,
      'actor_id':         actorId,
      'organization_id':  organizationId,
      'evidence_type':    evidenceType,
      'storage_path':     storagePath,
      'qr_verified':      qrVerified,
      'verification_status': qrVerified ? 'QR_VERIFIED' : 'CAPTURED',
      if (qrBatchIdFound  != null) 'qr_batch_id_found':  qrBatchIdFound,
      if (captureSessionId != null) 'capture_session_id': captureSessionId,
      if (latitude         != null) 'latitude':           latitude,
      if (longitude        != null) 'longitude':          longitude,
      if (evidenceSha256   != null) 'evidence_sha256':    evidenceSha256,
      if (deviceInfo       != null) 'device_info':        deviceInfo,
      if (clientCapturedAt != null)
        'client_captured_at': clientCapturedAt.toIso8601String(),
    };

    final data = await _client
        .from('batch_evidence')
        .insert(payload)
        .select()
        .single();

    return BatchEvidence.fromJson(data);
  }

  /// Link a created event_id back to an evidence record.
  /// Called after transition_batch_status() returns the new event_id.
  Future<void> linkEventId(String evidenceId, String eventId) async {
    await _client
        .from('batch_evidence')
        .update({'event_id': eventId})
        .eq('id', evidenceId);
  }

  /// Update the verification status of an evidence record.
  Future<void> updateVerificationStatus(
      String evidenceId, String status) async {
    await _client
        .from('batch_evidence')
        .update({'verification_status': status})
        .eq('id', evidenceId);
  }

  /// Fetch all evidence for a batch, newest first.
  Future<List<BatchEvidence>> getEvidenceForBatch(String batchId) async {
    final data = await _client
        .from('batch_evidence')
        .select()
        .eq('batch_id', batchId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => BatchEvidence.fromJson(e)).toList();
  }

  /// Fetch a single evidence record by id.
  Future<BatchEvidence?> getById(String evidenceId) async {
    final data = await _client
        .from('batch_evidence')
        .select()
        .eq('id', evidenceId)
        .maybeSingle();
    if (data == null) return null;
    return BatchEvidence.fromJson(data);
  }
}
