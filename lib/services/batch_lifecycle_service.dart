// lib/services/batch_lifecycle_service.dart
//
// Central, deterministic batch state machine.
// Flutter uses this for UI validation; the authoritative check
// runs server-side in the transition_batch_status() PostgreSQL function.
//
// Architecture hierarchy:
//   Database RPC = Source of Truth
//   ↓
//   BatchLifecycleService = Client-side mirror (for UI pre-validation)
//   ↓
//   Individual screens = Navigate to correct action

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

/// The complete valid transition map.
/// Key   = current (from) status
/// Value = set of (to_status, required_role) pairs
///
/// Role '*' means any authenticated role can trigger (e.g., expiry auto-update).
const Map<String, List<_Transition>> _validTransitions = {
  'ACTIVE': [
    _Transition('EXPIRING_SOON', '*'),
    _Transition('EXPIRED', '*'),
    _Transition('RETURN_INITIATED', 'PHARMACY'),
    _Transition('RETURN_DECLARED', 'PHARMACY'),
    _Transition('MFG_DIRECT_DISPOSAL', 'MANUFACTURER'),
    _Transition('CLOSED', 'REGULATOR'),
  ],
  'EXPIRING_SOON': [
    _Transition('EXPIRED', '*'),
    _Transition('RETURN_INITIATED', 'PHARMACY'),
    _Transition('RETURN_DECLARED', 'PHARMACY'),
    _Transition('MFG_DIRECT_DISPOSAL', 'MANUFACTURER'),
    _Transition('CLOSED', 'REGULATOR'),
  ],
  'EXPIRED': [
    _Transition('RETURN_INITIATED', 'PHARMACY'),
    _Transition('RETURN_DECLARED', 'PHARMACY'),
    _Transition('MFG_DIRECT_DISPOSAL', 'MANUFACTURER'),
    _Transition('DIST_DIRECT_DISPOSAL', 'DISTRIBUTOR'),
  ],
  'RETURN_DECLARED': [
    _Transition('RETURN_INITIATED', 'DISTRIBUTOR'),
  ],
  'RETURN_INITIATED': [
    _Transition('PICKUP_ASSIGNED', 'DISTRIBUTOR'),
  ],
  'PICKUP_ASSIGNED': [
    _Transition('COLLECTED', 'DISTRIBUTOR'),
  ],
  'COLLECTED': [
    _Transition('DISTRIBUTOR_VERIFIED', 'DISTRIBUTOR'),
  ],
  'DISTRIBUTOR_VERIFIED': [
    _Transition('MANUFACTURER_RECEIVED', 'MANUFACTURER'),
  ],
  'MANUFACTURER_RECEIVED': [
    _Transition('DISPOSAL_PENDING', 'MANUFACTURER'),
  ],
  'DISPOSAL_PENDING': [
    _Transition('SENT_FOR_DESTRUCTION', 'MANUFACTURER'),
  ],
  'SENT_FOR_DESTRUCTION': [
    _Transition('DESTROYED', 'WASTE_FACILITY'),
  ],
  'DESTROYED': [
    _Transition('DESTRUCTION_RECORDED', 'WASTE_FACILITY'),
    _Transition('CLOSED', 'REGULATOR'),
  ],
  'DESTRUCTION_RECORDED': [
    _Transition('CERTIFICATION_PENDING', 'WASTE_FACILITY'),
  ],
  'CERTIFICATION_PENDING': [
    _Transition('CERTIFIED', 'WASTE_FACILITY'),
  ],
  'CERTIFIED': [
    _Transition('CLOSED', 'REGULATOR'),
  ],
  'MFG_DIRECT_DISPOSAL': [
    _Transition('SENT_FOR_DESTRUCTION', 'MANUFACTURER'),
  ],
  'DIST_DIRECT_DISPOSAL': [
    _Transition('SENT_FOR_DESTRUCTION', 'DISTRIBUTOR'),
  ],
  // CLOSED is terminal — no transitions
};

class _Transition {
  final String toStatus;
  final String role; // '*' = any role
  const _Transition(this.toStatus, this.role);
}

class LifecycleValidationResult {
  final bool allowed;
  final String? reason;
  const LifecycleValidationResult.ok() : allowed = true, reason = null;
  const LifecycleValidationResult.denied(String r) : allowed = false, reason = r;
}

class BatchTransitionResult {
  final bool ok;
  final String? error;
  final String? newStatus;
  final String? eventHash;

  const BatchTransitionResult.success({required this.newStatus, required this.eventHash})
      : ok = true, error = null;
  const BatchTransitionResult.failure(String e)
      : ok = false, error = e, newStatus = null, eventHash = null;
}

class BatchLifecycleService {
  final SupabaseClient _client;

  BatchLifecycleService(this._client);

  // ─────────────────────────────────────────────────────────────────────────
  //  Client-side pre-validation (fast, for UI)
  // ─────────────────────────────────────────────────────────────────────────

  /// Deterministic static transition validation.
  static bool isValidTransition(String fromStatus, String toStatus, String userRole) {
    final allowed = _validTransitions[fromStatus] ?? [];
    return allowed.any((t) =>
      t.toStatus == toStatus && (t.role == '*' || t.role == userRole)
    );
  }

  /// Deterministic rejection explanation.
  static String? getTransitionError(String fromStatus, String toStatus, String userRole) {
    if (isValidTransition(fromStatus, toStatus, userRole)) return null;
    final transitions = _validTransitions[fromStatus];
    if (transitions == null || !transitions.any((t) => t.toStatus == toStatus)) {
      return 'Invalid transition from $fromStatus to $toStatus.';
    }
    return 'Role $userRole is not authorized for transition from $fromStatus to $toStatus.';
  }

  /// Check whether a transition is valid for a given role (UI guard only).
  LifecycleValidationResult canTransition({
    required String fromStatus,
    required String toStatus,
    required String userRole,
  }) {
    if (isValidTransition(fromStatus, toStatus, userRole)) {
      return const LifecycleValidationResult.ok();
    }
    return LifecycleValidationResult.denied(
      getTransitionError(fromStatus, toStatus, userRole) ??
          'Cannot transition from $fromStatus to $toStatus with role $userRole.',
    );
  }

  /// Returns all valid next statuses for a user's role from a current status.
  List<String> nextStatuses({required String currentStatus, required String userRole}) {
    return (_validTransitions[currentStatus] ?? [])
        .where((t) => t.role == '*' || t.role == userRole)
        .map((t) => t.toStatus)
        .toList();
  }

  /// Whether a status is terminal (no further transitions possible).
  bool isTerminal(String status) => status == 'CLOSED';

  /// Whether a batch has been destroyed.
  bool isDestroyed(String status) =>
      status == 'DESTROYED' ||
      status == 'DESTRUCTION_RECORDED' ||
      status == 'CERTIFICATION_PENDING' ||
      status == 'CERTIFIED' ||
      status == 'CLOSED';

  // ─────────────────────────────────────────────────────────────────────────
  //  Server-side transition (authoritative, atomic via RPC)
  // ─────────────────────────────────────────────────────────────────────────

  /// Call the server-side `transition_batch_status` RPC.
  /// This is the ONLY way to change batch status in production.
  /// The RPC validates role, enforces the transition map, records the
  /// event, and computes the server-side hash atomically.
  Future<BatchTransitionResult> transitionBatch({
    required String batchId,
    required String newStatus,
    required String eventType,
    int quantity = 0,
    AppUser? currentUser,
  }) async {
    // Client-side pre-validation (fast fail, better UX)
    if (currentUser != null) {
      final fromStatus = await _getCurrentStatus(batchId);
      if (fromStatus != null) {
        final preCheck = canTransition(
          fromStatus: fromStatus,
          toStatus: newStatus,
          userRole: currentUser.role,
        );
        if (!preCheck.allowed) {
          return BatchTransitionResult.failure(preCheck.reason!);
        }
      }
    }

    try {
      final result = await _client.rpc('transition_batch_status', params: {
        'p_batch_id':   batchId,
        'p_new_status': newStatus,
        'p_event_type': eventType,
        'p_quantity':   quantity,
      });

      final data = result as Map<String, dynamic>;
      if (data['ok'] == true) {
        return BatchTransitionResult.success(
          newStatus: data['new_status'] as String? ?? newStatus,
          eventHash: data['event_hash'] as String?,
        );
      } else {
        return BatchTransitionResult.failure(
          data['error'] as String? ?? 'Transition failed',
        );
      }
    } catch (e) {
      debugPrint('BatchLifecycleService.transitionBatch error: $e');
      // Offline fallback — only for non-critical reads in demo mode
      return BatchTransitionResult.failure(
        'Server unavailable. Critical transitions require server confirmation.',
      );
    }
  }

  Future<String?> _getCurrentStatus(String batchId) async {
    try {
      final data = await _client
          .from('medicine_batches')
          .select('status')
          .eq('id', batchId)
          .single();
      return data['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Expiry status calculation (deterministic, no AI)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calculate what the expiry-based status SHOULD be from the real date.
  /// The stored `status` may lag — this is the authoritative expiry state.
  static String calculateExpiryStatus(DateTime expiryDate, {int warningDays = 90}) {
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return 'EXPIRED';
    if (expiryDate.isBefore(now.add(Duration(days: warningDays)))) return 'EXPIRING_SOON';
    return 'ACTIVE';
  }

  /// Returns true if a batch's stored status is stale vs real expiry.
  static bool isExpiryStatusStale(DateTime expiryDate, String storedStatus) {
    if (storedStatus == 'DESTROYED' ||
        storedStatus == 'DESTRUCTION_RECORDED' ||
        storedStatus == 'CERTIFICATION_PENDING' ||
        storedStatus == 'CERTIFIED' ||
        storedStatus == 'CLOSED') {
      return false;
    }
    if (storedStatus == 'RETURN_INITIATED' ||
        storedStatus == 'RETURN_DECLARED' ||
        storedStatus == 'COLLECTED' ||
        storedStatus == 'DISTRIBUTOR_VERIFIED' ||
        storedStatus == 'MANUFACTURER_RECEIVED' ||
        storedStatus == 'DISPOSAL_PENDING' ||
        storedStatus == 'SENT_FOR_DESTRUCTION' ||
        storedStatus == 'MFG_DIRECT_DISPOSAL' ||
        storedStatus == 'DIST_DIRECT_DISPOSAL') {
      return false; // Already past expiry detection, in reverse chain
    }
    final calculated = calculateExpiryStatus(expiryDate);
    return calculated != storedStatus &&
        (calculated == 'EXPIRED' || calculated == 'EXPIRING_SOON');
  }
}
