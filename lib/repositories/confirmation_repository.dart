// lib/repositories/confirmation_repository.dart
//
// CRUD for the pending_confirmations table.
//
// Flow:
//   1. Sender (e.g. Pharmacy) submits evidence → createPendingConfirmation()
//      (sender_attested_at is set immediately on create)
//   2. Receiver (e.g. Distributor) scans QR, verifies → receiverConfirm()
//   3. Both sides attested → isBilaterallyConfirmed() returns true
//   4. Server RPC transition_batch_status() validates confirmation before
//      advancing the batch to the next state.

import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmationRepository {
  final SupabaseClient _client;

  ConfirmationRepository(this._client);

  // ─────────────────────────────────────────────────────────────────────────
  //  Create
  // ─────────────────────────────────────────────────────────────────────────

  /// Called by the sender (pharmacy / distributor / manufacturer) immediately
  /// when they submit their evidence. The sender is considered attested at
  /// creation time.
  ///
  /// Returns the confirmation ID to be stored locally while waiting for the
  /// receiver to confirm.
  Future<String> createPendingConfirmation({
    required String batchId,
    required String requiredTransition,
    required String senderOrgId,
    String? receiverOrgId,
    String? senderActorId,
    String? senderEvidenceId,
    Duration expiresIn = const Duration(hours: 2),
  }) async {
    try {
      final data = await _client
          .from('pending_confirmations')
          .insert({
            'batch_id':            batchId,
            'required_transition': requiredTransition,
            'sender_org_id':       senderOrgId,
            if (receiverOrgId  != null) 'receiver_org_id':    receiverOrgId,
            if (senderActorId  != null) 'sender_actor_id':    senderActorId,
            if (senderEvidenceId != null)
              'sender_evidence_fk': senderEvidenceId,
            'sender_attested_at':  DateTime.now().toIso8601String(),
            'expires_at':
                DateTime.now().add(expiresIn).toIso8601String(),
          })
          .select('id')
          .single();

      return data['id'] as String;
    } catch (_) {
      return 'conf_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Receiver confirmation
  // ─────────────────────────────────────────────────────────────────────────

  /// Called by the receiver (distributor / waste facility) after they
  /// have physically scanned the batch QR in-app and verified the quantity.
  Future<void> receiverConfirm({
    required String confirmationId,
    required String actorId,
    String? receiverEvidenceId,
  }) async {
    await _client
        .from('pending_confirmations')
        .update({
          'receiver_confirmed_at': DateTime.now().toIso8601String(),
          'receiver_actor_id':     actorId,
          if (receiverEvidenceId != null)
            'receiver_evidence_fk': receiverEvidenceId,
        })
        .eq('id', confirmationId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Queries
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if both sender and receiver have attested and the
  /// confirmation has not expired.
  Future<bool> isBilaterallyConfirmed(String confirmationId) async {
    try {
      final row = await _client
          .from('pending_confirmations')
          .select('sender_attested_at, receiver_confirmed_at, expires_at')
          .eq('id', confirmationId)
          .single();

      final hasExpired = row['expires_at'] != null &&
          DateTime.parse(row['expires_at'] as String).isBefore(DateTime.now());

      return !hasExpired &&
          row['sender_attested_at'] != null &&
          row['receiver_confirmed_at'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns all pending confirmations where this org is the expected receiver
  /// and the confirmation has not yet been completed or expired.
  Future<List<Map<String, dynamic>>> getPendingForReceiver(
      String receiverOrgId) async {
    try {
      final data = await _client
          .from('pending_confirmations')
          .select('''
            *,
            medicine_batches(batch_number, medicines(name))
          ''')
          .eq('receiver_org_id', receiverOrgId)
          .isFilter('receiver_confirmed_at', null)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Returns all pending confirmations initiated by this org
  /// (sender side — waiting for receiver).
  Future<List<Map<String, dynamic>>> getPendingForSender(
      String senderOrgId) async {
    try {
      final data = await _client
          .from('pending_confirmations')
          .select('''
            *,
            medicine_batches(batch_number, medicines(name))
          ''')
          .eq('sender_org_id', senderOrgId)
          .isFilter('receiver_confirmed_at', null)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Fetch a specific confirmation by batch ID (most recent).
  Future<Map<String, dynamic>?> getLatestForBatch(String batchId) async {
    try {
      final data = await _client
          .from('pending_confirmations')
          .select()
          .eq('batch_id', batchId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }
}
