// lib/services/route_policy_service.dart
//
// Configurable route/policy engine.
//
// Validates that a requested transition is permitted given the
// batch's origination_path, current_custodian, and requesting role.
//
// This is a client-side pre-validation mirror of the server-side
// logic in transition_batch_status(). It exists to give UIs
// early feedback without a round-trip.
//
// Security note: this is a convenience check, not a security control.
// The authoritative enforcement lives in the Supabase RPC.

class RoutePolicyService {
  // ─────────────────────────────────────────────────────────────────────────
  //  Valid roles per origination path
  // ─────────────────────────────────────────────────────────────────────────

  /// Roles that are allowed to touch a batch with each origination path.
  static const Map<String, List<String>> _originPermittedRoles = {
    'RETAIL_RETURN': [
      'PHARMACY', 'DISTRIBUTOR', 'MANUFACTURER', 'WASTE_FACILITY', 'REGULATOR',
    ],
    'DISTRIBUTOR_SELF': [
      'DISTRIBUTOR', 'WASTE_FACILITY', 'REGULATOR',
    ],
    'MANUFACTURER_SELF': [
      'MANUFACTURER', 'WASTE_FACILITY', 'REGULATOR',
    ],
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  Validation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns null if the route is valid, or an error reason string.
  ///
  /// [originationPath] — value of medicine_batches.origination_path.
  ///                     Pass null if the batch has no path set yet.
  /// [requestingRole]  — AppUser.role of the actor requesting the transition.
  /// [fromStatus]      — current batch status.
  /// [toStatus]        — requested next status.
  static String? validateRoute({
    required String? originationPath,
    required String requestingRole,
    required String fromStatus,
    required String toStatus,
  }) {
    // No origination path set yet — no route constraint applies.
    if (originationPath == null) return null;

    // Role check for the given origin.
    final permitted = _originPermittedRoles[originationPath];
    if (permitted != null && !permitted.contains(requestingRole)) {
      return 'Role $requestingRole is not permitted on '
          'origination path $originationPath.';
    }

    // Pharmacy-originated batches must follow the full chain.
    // They cannot skip directly to SENT_FOR_DESTRUCTION.
    if (originationPath == 'RETAIL_RETURN' &&
        toStatus == 'SENT_FOR_DESTRUCTION' &&
        fromStatus != 'DISPOSAL_PENDING') {
      return 'Retail-return batches must complete the full '
          'distributor → manufacturer → waste facility path. '
          'Direct routing to destruction is not permitted.';
    }

    return null; // valid
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Origin path mapping
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps a user role to the correct origination_path value when
  /// that role is initiating a new waste disposal case.
  static String originationPathFor(String role) => switch (role) {
        'PHARMACY'     => 'RETAIL_RETURN',
        'DISTRIBUTOR'  => 'DISTRIBUTOR_SELF',
        'MANUFACTURER' => 'MANUFACTURER_SELF',
        _ => 'RETAIL_RETURN',
      };

  // ─────────────────────────────────────────────────────────────────────────
  //  Status helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// True if the given status represents a DECLARED (single-party claim) event.
  static bool isDeclared(String status) => const {
        'RETURN_DECLARED',
        'MFG_DIRECT_DISPOSAL',
        'DIST_DIRECT_DISPOSAL',
      }.contains(status);

  /// True if the given status requires bilateral confirmation to advance.
  static bool requiresBilateralConfirmation(String status) => const {
        'RETURN_INITIATED',
        'COLLECTED',
        'DISTRIBUTOR_VERIFIED',
      }.contains(status);

  /// True if the given status requires evidence before transition.
  static bool requiresEvidence(String status) => const {
        'RETURN_DECLARED',
        'MFG_DIRECT_DISPOSAL',
        'DIST_DIRECT_DISPOSAL',
        'DESTRUCTION_RECORDED',
        'CERTIFIED',
      }.contains(status);

  /// The human-readable verification label for display in the Digital
  /// Medicine Passport and admin views.
  static String verificationLabel(String verificationState) =>
      switch (verificationState) {
        'DECLARED'            => 'Declared',
        'PENDING_VERIFICATION'=> 'Pending Verification',
        'VERIFIED'            => 'Verified',
        'EXCEPTION'           => 'Exception',
        'CERTIFIED'           => 'Certified',
        _ => verificationState,
      };
}
