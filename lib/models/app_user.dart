class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // PHARMACY | DISTRIBUTOR | MANUFACTURER | WASTE_FACILITY | REGULATOR
  final String organizationId;
  final String? organizationName;
  final String status;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.organizationId,
    this.organizationName,
    this.status = 'ACTIVE',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        organizationId: json['organization_id'] as String,
        organizationName: json['organizations']?['name'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'organization_id': organizationId,
        'status': status,
      };

  String get roleLabel => switch (role) {
        'PHARMACY' => 'Pharmacy',
        'DISTRIBUTOR' => 'Distributor',
        'MANUFACTURER' => 'Manufacturer',
        'WASTE_FACILITY' => 'Waste Facility',
        'REGULATOR' => 'Admin',
        _ => role,
      };
}
