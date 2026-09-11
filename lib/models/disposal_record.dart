class DisposalRecord {
  final String id;
  final String batchId;
  final String? batchNumber;
  final String manufacturerId;
  final String? wasteFacilityId;
  final String? wasteFacilityName;
  final String disposalMethod;
  final DateTime? actualDisposalDate;
  final int quantityDestroyed;
  final String status;
  final String? certificateId;

  const DisposalRecord({
    required this.id,
    required this.batchId,
    this.batchNumber,
    required this.manufacturerId,
    this.wasteFacilityId,
    this.wasteFacilityName,
    required this.disposalMethod,
    this.actualDisposalDate,
    required this.quantityDestroyed,
    required this.status,
    this.certificateId,
  });

  factory DisposalRecord.fromJson(Map<String, dynamic> json) => DisposalRecord(
        id: json['id'] as String,
        batchId: json['batch_id'] as String,
        batchNumber: json['medicine_batches']?['batch_number'] as String?,
        manufacturerId: json['manufacturer_id'] as String,
        wasteFacilityId: json['waste_facility_id'] as String?,
        wasteFacilityName: (json['waste_facility']?['name'] as String?) ??
            (json['waste_facilities']?['organizations']?['name'] as String?),
        disposalMethod: json['disposal_method'] as String,
        actualDisposalDate: json['actual_disposal_date'] != null
            ? DateTime.parse(json['actual_disposal_date'] as String)
            : null,
        quantityDestroyed: json['quantity_destroyed'] as int,
        status: json['status'] as String,
        certificateId: json['certificate_id'] as String?,
      );
}

class DestructionCertificate {
  final String id;
  final String disposalRecordId;
  final String? batchId;
  final String certificateNumber;
  final String? documentUrl;
  final String? documentHash;
  final String? verificationStatus; // PENDING | VERIFIED | REJECTED
  final DateTime issuedDate;
  final String hash;

  const DestructionCertificate({
    required this.id,
    required this.disposalRecordId,
    this.batchId,
    required this.certificateNumber,
    this.documentUrl,
    this.documentHash,
    this.verificationStatus,
    required this.issuedDate,
    required this.hash,
  });

  factory DestructionCertificate.fromJson(Map<String, dynamic> json) =>
      DestructionCertificate(
        id: json['id'] as String,
        disposalRecordId: json['disposal_record_id'] as String,
        batchId: json['batch_id'] as String?,
        certificateNumber: json['certificate_number'] as String,
        documentUrl: json['document_url'] as String?,
        documentHash: json['document_hash'] as String?,
        verificationStatus: json['verification_status'] as String?,
        issuedDate: DateTime.parse(json['issued_date'] as String),
        hash: json['hash'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'disposal_record_id': disposalRecordId,
        if (batchId != null) 'batch_id': batchId,
        'certificate_number': certificateNumber,
        if (documentUrl != null) 'document_url': documentUrl,
        if (documentHash != null) 'document_hash': documentHash,
        if (verificationStatus != null) 'verification_status': verificationStatus,
        'issued_date': issuedDate.toIso8601String(),
        'hash': hash,
      };
}
