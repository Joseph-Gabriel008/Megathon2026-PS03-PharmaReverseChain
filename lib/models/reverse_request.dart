class ReverseRequest {
  final String id;
  final String batchId;
  final String? batchNumber;
  final String? medicineName;
  final String retailerId;
  final String? distributorId;
  final int requestedQuantity;
  final String reason;
  final String status;
  final DateTime initiatedAt;
  final DateTime? pickupDate;
  final DateTime? completedAt;
  final String? pharmacyName;
  final String? proofUrl;

  const ReverseRequest({
    required this.id,
    required this.batchId,
    this.batchNumber,
    this.medicineName,
    required this.retailerId,
    this.distributorId,
    required this.requestedQuantity,
    required this.reason,
    required this.status,
    required this.initiatedAt,
    this.pickupDate,
    this.completedAt,
    this.pharmacyName,
    this.proofUrl,
  });

  factory ReverseRequest.fromJson(Map<String, dynamic> json) => ReverseRequest(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        batchNumber: json['medicine_batches']?['batch_number'] as String?,
        medicineName:
            json['medicine_batches']?['medicines']?['name'] as String?,
        retailerId: json['retailer_id'] as String,
        distributorId: json['distributor_id'] as String?,
        requestedQuantity: json['requested_quantity'] as int,
        reason: json['reason'] as String,
        status: json['status'] as String,
        initiatedAt: DateTime.parse(json['initiated_at'] as String),
        pickupDate: json['pickup_date'] != null
            ? DateTime.parse(json['pickup_date'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        pharmacyName: json['retailers']?['organizations']?['name'] as String?,
        proofUrl: json['proof_url'] as String?,
      );

  String get reasonLabel => switch (reason) {
        'EXPIRED' => 'Expired',
        'DAMAGED' => 'Damaged',
        'RECALLED' => 'Recalled',
        'OTHER' => 'Other',
        _ => reason,
      };

  String get statusLabel => switch (status) {
        'PENDING' => 'Pending',
        'ACCEPTED' => 'Accepted',
        'IN_TRANSIT' => 'In Transit',
        'COMPLETED' => 'Completed',
        'CANCELLED' => 'Cancelled',
        _ => status,
      };
}

class Pickup {
  final String id;
  final String reverseRequestId;
  final String distributorId;
  final DateTime? scheduledDate;
  final String pickupStatus;
  final int? actualQuantity;
  final String? notes;
  final String? handoverOtp;
  final String? pickupProofUrl;
  final ReverseRequest? reverseRequest;

  const Pickup({
    required this.id,
    required this.reverseRequestId,
    required this.distributorId,
    this.scheduledDate,
    required this.pickupStatus,
    this.actualQuantity,
    this.notes,
    this.handoverOtp,
    this.pickupProofUrl,
    this.reverseRequest,
  });

  static String generateOtp(String seed) {
    final code = (seed.hashCode.abs() % 900000) + 100000;
    return code.toString();
  }

  String get expectedOtp {
    if (handoverOtp != null && handoverOtp!.isNotEmpty) return handoverOtp!;
    final seed = reverseRequest?.batchId ?? id;
    return generateOtp(seed);
  }

  /// Evaluates the true lifecycle stage based on pickup and request statuses
  String get effectiveStage {
    final ps = pickupStatus.toUpperCase();
    final rs = reverseRequest?.status.toUpperCase() ?? '';
    if (ps == 'COMPLETED' || rs == 'COMPLETED') return 'COMPLETED';
    if (ps == 'COLLECTED' || rs == 'IN_TRANSIT' || actualQuantity != null) return 'COLLECTED';
    if (ps == 'SCHEDULED' || ps == 'ASSIGNED') return 'ASSIGNED';
    if (ps == 'ACCEPTED' || ps == 'IN_PROGRESS') return 'ACCEPTED';
    return 'ASSIGNED';
  }

  Pickup copyWith({
    String? id,
    String? reverseRequestId,
    String? distributorId,
    DateTime? scheduledDate,
    String? pickupStatus,
    int? actualQuantity,
    String? notes,
    String? handoverOtp,
    String? pickupProofUrl,
    ReverseRequest? reverseRequest,
  }) =>
      Pickup(
        id: id ?? this.id,
        reverseRequestId: reverseRequestId ?? this.reverseRequestId,
        distributorId: distributorId ?? this.distributorId,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        pickupStatus: pickupStatus ?? this.pickupStatus,
        actualQuantity: actualQuantity ?? this.actualQuantity,
        notes: notes ?? this.notes,
        handoverOtp: handoverOtp ?? this.handoverOtp,
        pickupProofUrl: pickupProofUrl ?? this.pickupProofUrl,
        reverseRequest: reverseRequest ?? this.reverseRequest,
      );

  factory Pickup.fromJson(Map<String, dynamic> json) => Pickup(
        id: json['id'] as String,
        reverseRequestId: json['reverse_request_id'] as String,
        distributorId: json['distributor_id'] as String,
        scheduledDate: json['scheduled_date'] != null
            ? DateTime.parse(json['scheduled_date'] as String)
            : null,
        pickupStatus: json['pickup_status'] as String,
        actualQuantity: json['actual_quantity'] as int?,
        notes: json['notes'] as String?,
        handoverOtp: json['handover_otp'] as String?,
        pickupProofUrl: json['pickup_proof_url'] as String?,
        reverseRequest: json['reverse_requests'] != null
            ? ReverseRequest.fromJson(
                json['reverse_requests'] as Map<String, dynamic>)
            : null,
      );
}
