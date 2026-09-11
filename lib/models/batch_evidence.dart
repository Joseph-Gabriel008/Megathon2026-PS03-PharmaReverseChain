// lib/models/batch_evidence.dart
//
// First-class evidence object.
// Every proof photo, video, or document in MediLoop is a BatchEvidence record.
// Evidence is:
//   - Bound to a specific batch AND event.
//   - SHA-256 hashed from file bytes at capture time.
//   - QR-verified (decoded QR in the image must match the expected batch ID).
//   - Timestamped server-side (server_received_at) to prevent phone clock spoofing.

class BatchEvidence {
  final String id;
  final String batchId;
  final String? eventId;
  final String actorId;
  final String organizationId;
  final String? captureSessionId;

  /// PHOTO | VIDEO | DOCUMENT
  final String evidenceType;

  /// Storage path (relative in the certificates bucket).
  final String storagePath;

  final DateTime? clientCapturedAt;
  final DateTime serverReceivedAt;

  final double? latitude;
  final double? longitude;
  final String? deviceInfo;

  /// SHA-256 of the raw file bytes, computed client-side before upload.
  final String? evidenceSha256;

  /// Perceptual hash (set by Edge Function after upload).
  final String? perceptualHash;

  /// True if the batch QR code was successfully decoded from the evidence image.
  final bool qrVerified;

  /// The batch UUID extracted from the QR code in the image.
  final String? qrBatchIdFound;

  /// CAPTURED | QR_VERIFIED | VALIDATED | REJECTED | DUPLICATE_FLAGGED
  final String verificationStatus;

  final DateTime createdAt;

  const BatchEvidence({
    required this.id,
    required this.batchId,
    this.eventId,
    required this.actorId,
    required this.organizationId,
    this.captureSessionId,
    required this.evidenceType,
    required this.storagePath,
    this.clientCapturedAt,
    required this.serverReceivedAt,
    this.latitude,
    this.longitude,
    this.deviceInfo,
    this.evidenceSha256,
    this.perceptualHash,
    required this.qrVerified,
    this.qrBatchIdFound,
    required this.verificationStatus,
    required this.createdAt,
  });

  factory BatchEvidence.fromJson(Map<String, dynamic> json) => BatchEvidence(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        eventId: json['event_id'] as String?,
        actorId: json['actor_id'] as String,
        organizationId: json['organization_id'] as String,
        captureSessionId: json['capture_session_id'] as String?,
        evidenceType: json['evidence_type'] as String,
        storagePath: json['storage_path'] as String,
        clientCapturedAt: json['client_captured_at'] != null
            ? DateTime.parse(json['client_captured_at'] as String)
            : null,
        serverReceivedAt:
            DateTime.parse(json['server_received_at'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        deviceInfo: json['device_info'] as String?,
        evidenceSha256: json['evidence_sha256'] as String?,
        perceptualHash: json['perceptual_hash'] as String?,
        qrVerified: json['qr_verified'] as bool? ?? false,
        qrBatchIdFound: json['qr_batch_id_found'] as String?,
        verificationStatus:
            json['verification_status'] as String? ?? 'CAPTURED',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batch_id': batchId,
        if (eventId != null) 'event_id': eventId,
        'actor_id': actorId,
        'organization_id': organizationId,
        if (captureSessionId != null) 'capture_session_id': captureSessionId,
        'evidence_type': evidenceType,
        'storage_path': storagePath,
        if (clientCapturedAt != null)
          'client_captured_at': clientCapturedAt!.toIso8601String(),
        'server_received_at': serverReceivedAt.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (deviceInfo != null) 'device_info': deviceInfo,
        if (evidenceSha256 != null) 'evidence_sha256': evidenceSha256,
        if (perceptualHash != null) 'perceptual_hash': perceptualHash,
        'qr_verified': qrVerified,
        if (qrBatchIdFound != null) 'qr_batch_id_found': qrBatchIdFound,
        'verification_status': verificationStatus,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isValidated => verificationStatus == 'VALIDATED';
  bool get isDuplicateFlagged => verificationStatus == 'DUPLICATE_FLAGGED';
  bool get isRejected => verificationStatus == 'REJECTED';

  String get evidenceTypeLabel => switch (evidenceType) {
        'PHOTO' => 'Photograph',
        'VIDEO' => 'Video',
        'DOCUMENT' => 'Document',
        _ => evidenceType,
      };
}
