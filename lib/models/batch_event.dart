class BatchEvent {
  final String id;
  final String batchId;
  final String eventType;
  final String actorId;
  final String? actorName;
  final String organizationId;
  final String? organizationName;
  final int quantity;
  final String? previousStatus;
  final String newStatus;
  final DateTime timestamp;
  final String eventHash;
  final String? previousEventHash;

  const BatchEvent({
    required this.id,
    required this.batchId,
    required this.eventType,
    required this.actorId,
    this.actorName,
    required this.organizationId,
    this.organizationName,
    required this.quantity,
    this.previousStatus,
    required this.newStatus,
    required this.timestamp,
    required this.eventHash,
    this.previousEventHash,
  });

  factory BatchEvent.fromJson(Map<String, dynamic> json) => BatchEvent(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        eventType: json['event_type'] as String,
        actorId: json['actor_id'] as String,
        actorName: json['users']?['name'] as String?,
        organizationId: json['organization_id'] as String,
        organizationName: json['organizations']?['name'] as String?,
        quantity: json['quantity'] as int? ?? 0,
        previousStatus: json['previous_status'] as String?,
        newStatus: json['new_status'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventHash: json['event_hash'] as String? ?? '',
        previousEventHash: json['previous_event_hash'] as String?,
      );

  String get eventTypeLabel => switch (eventType) {
        'BATCH_CREATED' => 'Batch Created',
        'RETURN_INITIATED' => 'Return Initiated',
        'PICKUP_ACCEPTED' => 'Pickup Accepted',
        'PICKUP_COMPLETED' => 'Pickup Completed',
        'QUANTITY_VERIFIED' => 'Quantity Verified',
        'MANUFACTURER_RECEIVED' => 'Received at Manufacturer',
        'DISPOSAL_SCHEDULED' => 'Disposal Scheduled',
        'DESTRUCTION_RECORDED' => 'Destruction Recorded',
        'CERTIFICATE_UPLOADED' => 'Certificate Uploaded',
        'FRAUD_DETECTED' => 'Fraud Detected',
        'SCAN_EVENT' => 'Batch Scanned',
        _ => eventType,
      };
}

class FraudAlert {
  final String id;
  final String batchId;
  final String? batchNumber;
  final String? medicineName;
  final String alertType;
  final String severity; // CRITICAL | HIGH | MEDIUM | LOW
  final String description;
  final String? aiNarrative;
  final String status; // OPEN | INVESTIGATING | RESOLVED | FALSE_POSITIVE
  final DateTime detectedAt;
  final String? organizationId;
  final String? organizationName;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  const FraudAlert({
    required this.id,
    required this.batchId,
    this.batchNumber,
    this.medicineName,
    required this.alertType,
    required this.severity,
    required this.description,
    this.aiNarrative,
    required this.status,
    required this.detectedAt,
    this.organizationId,
    this.organizationName,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
  });

  FraudAlert copyWith({
    String? id,
    String? batchId,
    String? batchNumber,
    String? medicineName,
    String? alertType,
    String? severity,
    String? description,
    String? aiNarrative,
    String? status,
    DateTime? detectedAt,
    String? organizationId,
    String? organizationName,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) =>
      FraudAlert(
        id: id ?? this.id,
        batchId: batchId ?? this.batchId,
        batchNumber: batchNumber ?? this.batchNumber,
        medicineName: medicineName ?? this.medicineName,
        alertType: alertType ?? this.alertType,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        aiNarrative: aiNarrative ?? this.aiNarrative,
        status: status ?? this.status,
        detectedAt: detectedAt ?? this.detectedAt,
        organizationId: organizationId ?? this.organizationId,
        organizationName: organizationName ?? this.organizationName,
        resolvedBy: resolvedBy ?? this.resolvedBy,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      );

  factory FraudAlert.fromJson(Map<String, dynamic> json) => FraudAlert(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        batchNumber: json['medicine_batches']?['batch_number'] as String?,
        medicineName:
            json['medicine_batches']?['medicines']?['name'] as String?,
        alertType: json['alert_type'] as String,
        severity: json['severity'] as String,
        description: json['description'] as String,
        aiNarrative: json['ai_narrative'] as String?,
        status: json['status'] as String,
        detectedAt: DateTime.parse(json['detected_at'] as String),
        organizationId: json['organization_id'] as String?,
        organizationName: json['organizations']?['name'] as String?,
        resolvedBy: json['resolved_by'] as String?,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        resolutionNotes: json['resolution_notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batch_id': batchId,
        'alert_type': alertType,
        'severity': severity,
        'description': description,
        'ai_narrative': aiNarrative,
        'status': status,
        'detected_at': detectedAt.toIso8601String(),
        if (resolvedBy != null) 'resolved_by': resolvedBy,
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      };

  String get alertTypeLabel => switch (alertType) {
        'DESTROYED_BATCH_REENTRY' => 'Destroyed Batch Re-entry',
        'QUANTITY_MISMATCH' => 'Quantity Mismatch',
        'EXPIRED_BATCH_SALE' => 'Expired Batch Active',
        'INVALID_BATCH' => 'Invalid Batch',
        'DUPLICATE_BATCH_SCAN' => 'Duplicate Scan',
        'UNAUTHORIZED_MOVEMENT' => 'Unauthorized Movement',
        'CERTIFICATE_MISMATCH' => 'Certificate Mismatch',
        _ => alertType,
      };

  String get severityLabel => switch (severity) {
        'CRITICAL' => 'Critical',
        'HIGH' => 'High',
        'MEDIUM' => 'Medium',
        'LOW' => 'Low',
        _ => severity,
      };

  String get statusLabel => switch (status) {
        'OPEN' => 'Open',
        'INVESTIGATING' => 'Investigating',
        'RESOLVED' => 'Resolved',
        'FALSE_POSITIVE' => 'False Positive',
        _ => status,
      };

  bool get isCritical => severity == 'CRITICAL';
}
