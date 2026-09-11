// lib/services/audit_service.dart
//
// Audit chain verification service.
// Fetches batch events and verifies the SHA-256 hash chain
// server-side (via verify_audit_chain RPC) or locally (via HashService).

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/batch_event.dart';
import '../services/hash_service.dart';
import '../core/constants.dart';
import '../data/mock_database.dart';

class AuditVerificationResult {
  final bool valid;
  final int eventsChecked;
  final String? issueDescription;
  final String? issueEventId;
  final String? issueEventType;

  const AuditVerificationResult({
    required this.valid,
    required this.eventsChecked,
    this.issueDescription,
    this.issueEventId,
    this.issueEventType,
  });

  factory AuditVerificationResult.fromRpc(Map<String, dynamic> data) {
    final issue = data['issue'] as Map<String, dynamic>?;
    return AuditVerificationResult(
      valid: data['valid'] as bool? ?? false,
      eventsChecked: data['events_checked'] as int? ?? 0,
      issueDescription: issue?['reason'] as String?,
      issueEventId: issue?['event_id'] as String?,
      issueEventType: issue?['event_type'] as String?,
    );
  }

  factory AuditVerificationResult.localVerify(List<BatchEvent> events) {
    if (events.isEmpty) {
      return const AuditVerificationResult(valid: true, eventsChecked: 0);
    }

    final rawEvents = events
        .map((e) => {
              'id': e.id,
              'batch_id': e.batchId,
              'event_type': e.eventType,
              'actor_id': e.actorId,
              'quantity': e.quantity,
              'new_status': e.newStatus,
              'previous_status': e.previousStatus,
              'timestamp': e.timestamp.toIso8601String(),
              'event_hash': e.eventHash,
              'previous_event_hash': e.previousEventHash,
            })
        .toList();

    final error = HashService.verifyChain(rawEvents);
    if (error == null) {
      return AuditVerificationResult(valid: true, eventsChecked: events.length);
    }
    return AuditVerificationResult(
      valid: false,
      eventsChecked: events.length,
      issueDescription: error,
    );
  }
}

class AuditService {
  final SupabaseClient _client;

  AuditService(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  // ─────────────────────────────────────────────────────────────────────────
  //  Fetch events
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<BatchEvent>> getEventsForBatch(String batchId) async {
    if (_isMock) {
      return MockDatabase.instance.getEventsForBatch(batchId);
    }
    try {
      final data = await _client
          .from('batch_events')
          .select('*, users(name), organizations(name)')
          .eq('batch_id', batchId)
          .order('timestamp', ascending: true);
      return (data as List).map((e) => BatchEvent.fromJson(e)).toList();
    } catch (e) {
      debugPrint('AuditService.getEventsForBatch: $e');
      return MockDatabase.instance.getEventsForBatch(batchId);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Verify chain
  // ─────────────────────────────────────────────────────────────────────────

  /// Verify the hash chain for a batch.
  /// Tries server-side RPC first; falls back to local HashService.
  Future<AuditVerificationResult> verifyChain(String batchId) async {
    if (_isMock) {
      final events = await getEventsForBatch(batchId);
      return AuditVerificationResult.localVerify(events);
    }

    try {
      final result = await _client.rpc('verify_audit_chain', params: {
        'p_batch_id': batchId,
      });
      return AuditVerificationResult.fromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e) {
      debugPrint('AuditService.verifyChain RPC failed, using local: $e');
      // Fall back to local verification
      final events = await getEventsForBatch(batchId);
      return AuditVerificationResult.localVerify(events);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Get all recent events (for admin audit log)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<BatchEvent>> getRecentEvents({int limit = 50}) async {
    if (_isMock) {
      final list = MockDatabase.instance.getAllEvents();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    }
    try {
      final data = await _client
          .from('batch_events')
          .select('*, users(name), organizations(name), medicine_batches(batch_number)')
          .order('timestamp', ascending: false)
          .limit(limit);
      return (data as List).map((e) => BatchEvent.fromJson(e)).toList();
    } catch (e) {
      debugPrint('AuditService.getRecentEvents: $e');
      return [];
    }
  }
}
