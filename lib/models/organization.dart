class Organization {
  final String id;
  final String name;
  final String type; // PHARMACY | DISTRIBUTOR | MANUFACTURER | WASTE_FACILITY | REGULATOR
  final String licenseNumber;
  final String verificationStatus; // PENDING | VERIFIED | SUSPENDED
  final int? batchCount;

  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.licenseNumber,
    required this.verificationStatus,
    this.batchCount,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        licenseNumber: json['license_number'] as String,
        verificationStatus: json['verification_status'] as String,
        batchCount: json['batch_count'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'license_number': licenseNumber,
        'verification_status': verificationStatus,
      };

  String get typeLabel => switch (type) {
        'PHARMACY' => 'Pharmacy',
        'DISTRIBUTOR' => 'Distributor',
        'MANUFACTURER' => 'Manufacturer',
        'WASTE_FACILITY' => 'Waste Facility',
        'REGULATOR' => 'Regulator',
        _ => type,
      };
}
