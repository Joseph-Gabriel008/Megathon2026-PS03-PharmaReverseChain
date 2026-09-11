class Medicine {
  final String id;
  final String name;
  final String genericName;
  final String manufacturerId;
  final String? dosage;
  final String? strength;

  const Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.manufacturerId,
    this.dosage,
    this.strength,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        genericName: json['generic_name'] as String,
        manufacturerId: json['manufacturer_id'] as String,
        dosage: json['dosage'] as String?,
        strength: json['strength'] as String?,
      );
}

class MedicineBatch {
  final String id;
  final String medicineId;
  final String? medicineName;
  final String? genericName;
  final String batchNumber;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final int originalQuantity;
  final int currentQuantity;
  final String status;
  final String? pharmacyId;
  final String? pharmacyName;
  final String? distributorId;
  final String? manufacturerId;
  final String? wasteFacilityId;
  final String? qrCode;
  final DateTime? updatedAt;

  // ── Review 2 fields ────────────────────────────────────────────────────────
  /// RETAIL_RETURN | DISTRIBUTOR_SELF | MANUFACTURER_SELF
  final String? originationPath;

  /// UUID of the organization currently holding physical custody.
  final String? currentCustodianId;

  /// DECLARED | PENDING_VERIFICATION | VERIFIED | EXCEPTION | CERTIFIED
  final String verificationState;

  const MedicineBatch({
    required this.id,
    required this.medicineId,
    this.medicineName,
    this.genericName,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.originalQuantity,
    required this.currentQuantity,
    required this.status,
    this.pharmacyId,
    this.pharmacyName,
    this.distributorId,
    this.manufacturerId,
    this.wasteFacilityId,
    this.qrCode,
    this.updatedAt,
    this.originationPath,
    this.currentCustodianId,
    this.verificationState = 'DECLARED',
  });

  MedicineBatch copyWith({
    String? id,
    String? medicineId,
    String? medicineName,
    String? genericName,
    String? batchNumber,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    int? originalQuantity,
    int? currentQuantity,
    String? status,
    String? pharmacyId,
    String? pharmacyName,
    String? distributorId,
    String? manufacturerId,
    String? wasteFacilityId,
    String? qrCode,
    DateTime? updatedAt,
    String? originationPath,
    String? currentCustodianId,
    String? verificationState,
  }) =>
      MedicineBatch(
        id: id ?? this.id,
        medicineId: medicineId ?? this.medicineId,
        medicineName: medicineName ?? this.medicineName,
        genericName: genericName ?? this.genericName,
        batchNumber: batchNumber ?? this.batchNumber,
        manufacturingDate: manufacturingDate ?? this.manufacturingDate,
        expiryDate: expiryDate ?? this.expiryDate,
        originalQuantity: originalQuantity ?? this.originalQuantity,
        currentQuantity: currentQuantity ?? this.currentQuantity,
        status: status ?? this.status,
        pharmacyId: pharmacyId ?? this.pharmacyId,
        pharmacyName: pharmacyName ?? this.pharmacyName,
        distributorId: distributorId ?? this.distributorId,
        manufacturerId: manufacturerId ?? this.manufacturerId,
        wasteFacilityId: wasteFacilityId ?? this.wasteFacilityId,
        qrCode: qrCode ?? this.qrCode,
        updatedAt: updatedAt ?? this.updatedAt,
        originationPath: originationPath ?? this.originationPath,
        currentCustodianId: currentCustodianId ?? this.currentCustodianId,
        verificationState: verificationState ?? this.verificationState,
      );

  factory MedicineBatch.fromJson(Map<String, dynamic> json) => MedicineBatch(
        id: json['id'] as String,
        medicineId: json['medicine_id'] as String,
        medicineName: json['medicines']?['name'] as String?,
        genericName: json['medicines']?['generic_name'] as String?,
        batchNumber: json['batch_number'] as String,
        manufacturingDate:
            DateTime.parse(json['manufacturing_date'] as String),
        expiryDate: DateTime.parse(json['expiry_date'] as String),
        originalQuantity: json['original_quantity'] as int,
        currentQuantity: json['current_quantity'] as int,
        status: json['status'] as String,
        pharmacyId: json['pharmacy_id'] as String?,
        pharmacyName: json['pharmacies']?['name'] as String?,
        distributorId: json['distributor_id'] as String?,
        manufacturerId: json['manufacturer_id'] as String?,
        wasteFacilityId: json['waste_facility_id'] as String?,
        qrCode: json['qr_code'] as String?,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        originationPath: json['origination_path'] as String?,
        currentCustodianId: json['current_custodian'] as String?,
        verificationState:
            json['verification_state'] as String? ?? 'DECLARED',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicine_id': medicineId,
        'batch_number': batchNumber,
        'manufacturing_date': manufacturingDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
        'original_quantity': originalQuantity,
        'current_quantity': currentQuantity,
        'status': status,
        'pharmacy_id': pharmacyId,
        'distributor_id': distributorId,
        'manufacturer_id': manufacturerId,
        if (wasteFacilityId != null) 'waste_facility_id': wasteFacilityId,
        'qr_code': qrCode,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (originationPath != null) 'origination_path': originationPath,
        if (currentCustodianId != null) 'current_custodian': currentCustodianId,
        'verification_state': verificationState,
      };

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      !isExpired &&
      expiryDate.isBefore(DateTime.now().add(const Duration(days: 90)));
  bool get isDestroyed => const {
    'DESTROYED', 'DESTRUCTION_RECORDED', 'CERTIFICATION_PENDING', 'CERTIFIED', 'CLOSED',
  }.contains(status);

  // ── Review 2: verification state helpers ─────────────────────────────────
  bool get isVerified     => verificationState == 'VERIFIED' || verificationState == 'CERTIFIED';
  bool get isCertified    => verificationState == 'CERTIFIED';
  bool get isException    => verificationState == 'EXCEPTION';
  bool get isDeclaredOnly => verificationState == 'DECLARED';

  // ── Origin path helpers ───────────────────────────────────────────────────
  bool get isRetailReturn     => originationPath == 'RETAIL_RETURN';
  bool get isDistributorSelf  => originationPath == 'DISTRIBUTOR_SELF';
  bool get isManufacturerSelf => originationPath == 'MANUFACTURER_SELF';

  String get expiryStatusCalculated {
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return 'EXPIRED';
    if (expiryDate.isBefore(now.add(const Duration(days: 90)))) {
      return 'EXPIRING_SOON';
    }
    return 'ACTIVE';
  }

  String get displayName => medicineName ?? 'Unknown Medicine';

  // Pipeline step index (0-based)
  int get pipelineStage => switch (status) {
        'ACTIVE' || 'EXPIRING_SOON' => 0,
        'EXPIRED' => 1,
        'RETURN_DECLARED' || 'RETURN_INITIATED' || 'MFG_DIRECT_DISPOSAL' || 'DIST_DIRECT_DISPOSAL' => 2,
        'IN_TRANSIT' || 'PICKUP_ASSIGNED' => 3,
        'COLLECTED' || 'DISTRIBUTOR_VERIFIED' => 4,
        'MANUFACTURER_RECEIVED' || 'DISPOSAL_PENDING' => 5,
        'SENT_FOR_DESTRUCTION' || 'DESTROYED' || 'DESTRUCTION_RECORDED' => 6,
        'CERTIFICATION_PENDING' || 'CERTIFIED' || 'CLOSED' => 7,
        _ => 0,
      };
}

/// Result of Gemini OCR scan
class BatchOcrResult {
  final String? batchNumber;
  final String? medicineName;
  final String? expiryDate;
  final bool success;
  final String? errorMessage;
  final bool isOfflineBackup;

  const BatchOcrResult({
    this.batchNumber,
    this.medicineName,
    this.expiryDate,
    required this.success,
    this.errorMessage,
    this.isOfflineBackup = false,
  });
}
