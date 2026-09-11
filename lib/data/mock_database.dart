import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/app_user.dart';
import '../models/medicine_batch.dart';
import '../models/batch_event.dart';
import '../models/reverse_request.dart';
import '../models/disposal_record.dart';
import '../models/organization.dart';

/// In-memory mock database providing 100% offline functionality
/// when Supabase is not configured or network is disconnected.
class MockDatabase {
  static final MockDatabase instance = MockDatabase._internal();
  MockDatabase._internal() {
    _initData();
  }

  void reset() {
    _users.clear();
    _batches.clear();
    _events.clear();
    _reverseRequests.clear();
    _pickups.clear();
    _disposalRecords.clear();
    _certificates.clear();
    _fraudAlerts.clear();
    _organizations.clear();
    _batchFacilityAssignments.clear();
    _initData();
  }

  final Map<String, AppUser> _users = {};
  final List<MedicineBatch> _batches = [];
  final List<BatchEvent> _events = [];
  final List<ReverseRequest> _reverseRequests = [];
  final List<Pickup> _pickups = [];
  final List<DisposalRecord> _disposalRecords = [];
  final List<DestructionCertificate> _certificates = [];
  final List<FraudAlert> _fraudAlerts = [];
  final List<Organization> _organizations = [];
  // Maps batchId -> wasteFacilityOrgId for in-session assignments
  final Map<String, String> _batchFacilityAssignments = {};

  void _initData() {
    // Organizations
    _organizations.addAll([
      const Organization(
        id: 'org-retailer-01',
        name: 'Apollo Pharmacy — Indiranagar',
        type: 'PHARMACY',
        licenseNumber: 'DL-KA-BNG-2024-00182',
        verificationStatus: 'VERIFIED',
      ),
      const Organization(
        id: 'org-distributor-01',
        name: 'MedSupply Southern Logistics Hub',
        type: 'DISTRIBUTOR',
        licenseNumber: 'WDL-KA-2023-00912',
        verificationStatus: 'VERIFIED',
      ),
      const Organization(
        id: 'org-manufacturer-01',
        name: 'Cipla Manufacturing Unit 4',
        type: 'MANUFACTURER',
        licenseNumber: 'MFG-CDSCO-2021-081',
        verificationStatus: 'VERIFIED',
      ),
      const Organization(
        id: 'org-facility-01',
        name: 'BioClean Bio-Medical Waste Facility',
        type: 'WASTE_FACILITY',
        licenseNumber: 'CPCB-BMW-2022-0044',
        verificationStatus: 'VERIFIED',
      ),
      const Organization(
        id: 'org-admin-01',
        name: 'CDSCO Southern Regional Office',
        type: 'REGULATOR',
        licenseNumber: 'GOV-CDSCO-SOUTH',
        verificationStatus: 'VERIFIED',
      ),
    ]);

    // Users
    _users['retailer@demo.com'] = const AppUser(
      id: 'usr-retailer-01',
      name: 'Ramesh Patel, R.Ph.',
      email: 'retailer@demo.com',
      role: 'PHARMACY',
      organizationId: 'org-retailer-01',
      organizationName: 'Apollo Pharmacy — Indiranagar',
    );
    _users['distributor@demo.com'] = const AppUser(
      id: 'usr-distributor-01',
      name: 'Suresh Menon, Logistics Lead',
      email: 'distributor@demo.com',
      role: 'DISTRIBUTOR',
      organizationId: 'org-distributor-01',
      organizationName: 'MedSupply Southern Logistics Hub',
    );
    _users['manufacturer@demo.com'] = const AppUser(
      id: 'usr-manufacturer-01',
      name: 'Dr. Anita Roy, QA Director',
      email: 'manufacturer@demo.com',
      role: 'MANUFACTURER',
      organizationId: 'org-manufacturer-01',
      organizationName: 'Cipla Manufacturing Unit 4',
    );
    _users['facility@demo.com'] = const AppUser(
      id: 'usr-facility-01',
      name: 'Vikram Joshi, Operations Officer',
      email: 'facility@demo.com',
      role: 'WASTE_FACILITY',
      organizationId: 'org-facility-01',
      organizationName: 'BioClean Bio-Medical Waste Facility',
    );
    _users['admin@demo.com'] = const AppUser(
      id: 'usr-admin-01',
      name: 'Inspector Rajesh Sharma',
      email: 'admin@demo.com',
      role: 'REGULATOR',
      organizationId: 'org-admin-01',
      organizationName: 'CDSCO Southern Regional Office',
    );

    // Batches
    final now = DateTime.now();
    _batches.addAll([
      MedicineBatch(
        id: 'batch-001',
        batchNumber: 'PARA500-2026-001',
        medicineId: 'med-01',
        medicineName: 'Paracetamol 500mg',
        genericName: 'Paracetamol IP',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 365)),
        expiryDate: now.add(const Duration(days: 180)),
        originalQuantity: 500,
        currentQuantity: 500,
        status: 'ACTIVE',
        qrCode: 'MEDILOOP|PARA500-2026-001|med-01|2026-09-10',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-002',
        batchNumber: 'AMOX500-2025-089',
        medicineId: 'med-02',
        medicineName: 'Amoxicillin 500mg',
        genericName: 'Amoxicillin Trihydrate',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 720)),
        expiryDate: now.subtract(const Duration(days: 45)),
        originalQuantity: 120,
        currentQuantity: 120,
        status: 'EXPIRED',
        qrCode: 'MEDILOOP|AMOX500-2025-089|med-02|2025-07-25',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-003',
        batchNumber: 'METF500-2026-042',
        medicineId: 'med-03',
        medicineName: 'Metformin 500mg',
        genericName: 'Metformin Hydrochloride',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 300)),
        expiryDate: now.add(const Duration(days: 22)),
        originalQuantity: 80,
        currentQuantity: 80,
        status: 'EXPIRING_SOON',
        qrCode: 'MEDILOOP|METF500-2026-042|med-03|2026-04-02',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-004',
        batchNumber: 'ATOR20-2025-015',
        medicineId: 'med-04',
        medicineName: 'Atorvastatin 20mg',
        genericName: 'Atorvastatin Calcium',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 400)),
        expiryDate: now.subtract(const Duration(days: 15)),
        originalQuantity: 200,
        currentQuantity: 200,
        // PICKUP_ASSIGNED: manufacturer assigned distributor, awaiting pickup
        status: 'PICKUP_ASSIGNED',
        qrCode: 'MEDILOOP|ATOR20-2025-015|med-04|2025-08-30',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-005',
        batchNumber: 'AZITH250-2026-112',
        medicineId: 'med-05',
        medicineName: 'Azithromycin 250mg',
        genericName: 'Azithromycin Dihydrate',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 150)),
        expiryDate: now.add(const Duration(days: 300)),
        originalQuantity: 60,
        currentQuantity: 60,
        status: 'RETURN_INITIATED',
        qrCode: 'MEDILOOP|AZITH250-2026-112|med-05|2027-01-15',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-006',
        batchNumber: 'CETR10-2024-003',
        medicineId: 'med-06',
        medicineName: 'Cetirizine 10mg',
        genericName: 'Cetirizine Hydrochloride',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 800)),
        expiryDate: now.subtract(const Duration(days: 200)),
        originalQuantity: 150,
        currentQuantity: 150,
        status: 'DESTROYED',
        qrCode: 'MEDILOOP|CETR10-2024-003|med-06|2024-06-15',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      // batch-007: COLLECTED — distributor delivered to manufacturer gate
      MedicineBatch(
        id: 'batch-007',
        batchNumber: 'LEVO500-2026-031',
        medicineId: 'med-07',
        medicineName: 'Levofloxacin 500mg',
        genericName: 'Levofloxacin',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 500)),
        expiryDate: now.subtract(const Duration(days: 90)),
        originalQuantity: 100,
        currentQuantity: 100,
        status: 'COLLECTED',
        qrCode: 'MEDILOOP|LEVO500-2026-031|med-07|2025-06-15',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      // batch-008: MANUFACTURER_RECEIVED — verified at factory, awaiting disposal
      MedicineBatch(
        id: 'batch-008',
        batchNumber: 'PANT40-2025-031',
        medicineId: 'med-08',
        medicineName: 'Pantoprazole 40mg',
        genericName: 'Pantoprazole Sodium',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 450)),
        expiryDate: now.subtract(const Duration(days: 60)),
        originalQuantity: 290,
        currentQuantity: 290,
        status: 'MANUFACTURER_RECEIVED',
        qrCode: 'MEDILOOP|PANT40-2025-031|med-08|2025-07-12',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      // batch-009: SENT_FOR_DESTRUCTION — at waste facility awaiting recording
      MedicineBatch(
        id: 'batch-009',
        batchNumber: 'CETR10-2025-044',
        medicineId: 'med-09',
        medicineName: 'Cetirizine 10mg',
        genericName: 'Cetirizine Hydrochloride',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        wasteFacilityId: 'org-facility-01',
        manufacturingDate: now.subtract(const Duration(days: 500)),
        expiryDate: now.subtract(const Duration(days: 90)),
        originalQuantity: 50,
        currentQuantity: 50,
        status: 'SENT_FOR_DESTRUCTION',
        qrCode: 'MEDILOOP|CETR10-2025-044|med-09|2025-06-12',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      // Additional returnable batches for Apollo Pharmacy
      MedicineBatch(
        id: 'batch-011',
        batchNumber: 'AUG625-2025-104',
        medicineId: 'med-11',
        medicineName: 'Augmentin 625 Duo',
        genericName: 'Amoxicillin + Clavulanic Acid',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 450)),
        expiryDate: now.subtract(const Duration(days: 30)),
        originalQuantity: 150,
        currentQuantity: 95,
        status: 'EXPIRED',
        qrCode: 'MEDILOOP|AUG625-2025-104|med-11|2025-08-11',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-012',
        batchNumber: 'DOLO650-2026-018',
        medicineId: 'med-12',
        medicineName: 'Dolo 650',
        genericName: 'Paracetamol IP',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 300)),
        expiryDate: now.add(const Duration(days: 15)),
        originalQuantity: 300,
        currentQuantity: 250,
        status: 'EXPIRING_SOON',
        qrCode: 'MEDILOOP|DOLO650-2026-018|med-12|2026-09-26',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-013',
        batchNumber: 'TELM40-2025-088',
        medicineId: 'med-13',
        medicineName: 'Telma 40',
        genericName: 'Telmisartan IP',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 600)),
        expiryDate: now.subtract(const Duration(days: 60)),
        originalQuantity: 200,
        currentQuantity: 140,
        status: 'EXPIRED',
        qrCode: 'MEDILOOP|TELM40-2025-088|med-13|2025-07-12',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-014',
        batchNumber: 'MONT-LC-2026-005',
        medicineId: 'med-14',
        medicineName: 'Montair LC',
        genericName: 'Montelukast + Levocetirizine',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 200)),
        expiryDate: now.add(const Duration(days: 25)),
        originalQuantity: 150,
        currentQuantity: 110,
        status: 'EXPIRING_SOON',
        qrCode: 'MEDILOOP|MONT-LC-2026-005|med-14|2026-10-05',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-015',
        batchNumber: 'ECO75-2025-092',
        medicineId: 'med-15',
        medicineName: 'Ecosprin 75',
        genericName: 'Aspirin Gastro-resistant',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 500)),
        expiryDate: now.subtract(const Duration(days: 40)),
        originalQuantity: 400,
        currentQuantity: 300,
        status: 'EXPIRED',
        qrCode: 'MEDILOOP|ECO75-2025-092|med-15|2025-08-01',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-016',
        batchNumber: 'SHEL500-2026-077',
        medicineId: 'med-16',
        medicineName: 'Shelcal 500',
        genericName: 'Calcium Carbonate + Vitamin D3',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 220)),
        expiryDate: now.add(const Duration(days: 10)),
        originalQuantity: 200,
        currentQuantity: 160,
        status: 'EXPIRING_SOON',
        qrCode: 'MEDILOOP|SHEL500-2026-077|med-16|2026-09-21',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-017',
        batchNumber: 'CIP500-2025-063',
        medicineId: 'med-17',
        medicineName: 'Ciplox 500',
        genericName: 'Ciprofloxacin Hydrochloride',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 550)),
        expiryDate: now.subtract(const Duration(days: 15)),
        originalQuantity: 100,
        currentQuantity: 85,
        status: 'EXPIRED',
        qrCode: 'MEDILOOP|CIP500-2025-063|med-17|2025-08-26',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
      MedicineBatch(
        id: 'batch-018',
        batchNumber: 'ASTH100-2026-021',
        medicineId: 'med-18',
        medicineName: 'Asthalin Inhaler',
        genericName: 'Salbutamol Inhalation CFC-Free',
        manufacturerId: 'org-manufacturer-01',
        distributorId: 'org-distributor-01',
        pharmacyId: 'org-retailer-01',
        manufacturingDate: now.subtract(const Duration(days: 100)),
        expiryDate: now.add(const Duration(days: 365)),
        originalQuantity: 50,
        currentQuantity: 40,
        status: 'ACTIVE',
        qrCode: 'MEDILOOP|ASTH100-2026-021|med-18|2027-09-10',
        pharmacyName: 'Apollo Pharmacy — Indiranagar',
      ),
    ]);

    // Reverse requests
    final req1 = ReverseRequest(
      id: 'req-001',
      batchId: 'batch-005',
      retailerId: 'usr-retailer-01',
      distributorId: 'usr-distributor-01',
      requestedQuantity: 60,
      reason: 'DAMAGED',
      status: 'PENDING',
      initiatedAt: now.subtract(const Duration(hours: 4)),
      batchNumber: 'AZITH250-2026-112',
      medicineName: 'Azithromycin 250mg',
      pharmacyName: 'Apollo Pharmacy — Indiranagar',
      proofUrl:
          'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400&q=80',
    );
    _reverseRequests.add(req1);

    // Pickups for distributor
    _pickups.addAll([
      Pickup(
        id: 'pick-001',
        reverseRequestId: 'req-001',
        distributorId: 'org-distributor-01',
        pickupStatus: 'ASSIGNED',
        scheduledDate: now.add(const Duration(days: 1)),
        handoverOtp: Pickup.generateOtp(req1.batchId),
        reverseRequest: req1,
      ),
      Pickup(
        id: 'pick-002',
        reverseRequestId: 'req-002',
        distributorId: 'org-distributor-01',
        pickupStatus: 'ASSIGNED',
        scheduledDate: now.add(const Duration(hours: 18)),
        handoverOtp: Pickup.generateOtp('batch-004'),
        reverseRequest: ReverseRequest(
          id: 'req-002',
          batchId: 'batch-004',
          retailerId: 'usr-retailer-01',
          distributorId: 'org-distributor-01',
          requestedQuantity: 200,
          reason: 'EXPIRED',
          status: 'ACCEPTED',
          initiatedAt: now.subtract(const Duration(days: 1)),
          batchNumber: 'ATOR20-2025-015',
          medicineName: 'Atorvastatin 20mg',
          pharmacyName: 'Apollo Pharmacy — Indiranagar',
          proofUrl:
              'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400&q=80',
        ),
      ),
    ]);

    // Disposal records
    _disposalRecords.add(
      DisposalRecord(
        id: 'disp-001',
        batchId: 'batch-006',
        manufacturerId: 'org-manufacturer-01',
        wasteFacilityId: 'org-facility-01',
        disposalMethod: 'INCINERATION',
        quantityDestroyed: 150,
        status: 'DESTROYED',
        actualDisposalDate: now.subtract(const Duration(days: 14)),
        certificateId: 'cert-001',
        batchNumber: 'CETR10-2024-003',
        wasteFacilityName: 'BioClean Bio-Medical Waste Facility',
      ),
    );

    _certificates.add(
      DestructionCertificate(
        id: 'cert-001',
        disposalRecordId: 'disp-001',
        batchId: 'batch-006',
        certificateNumber: 'CDSCO-CERT-2026-004812',
        verificationStatus: 'VERIFIED',
        issuedDate: now.subtract(const Duration(days: 14)),
        documentUrl: 'https://demo.mediloop.org/certificates/cert-001.pdf',
        hash: 'a8f3b9c2401f8d93e117b4c892e59123049bca71049281bfd8e90a12c418e244',
      ),
    );

    // Fraud alerts for Regulator/Admin
    _fraudAlerts.addAll([
      FraudAlert(
        id: 'alert-001',
        batchId: 'batch-006',
        alertType: 'DESTROYED_BATCH_REENTRY',
        severity: 'CRITICAL',
        status: 'OPEN',
        detectedAt: now.subtract(const Duration(minutes: 32)),
        batchNumber: 'CETR10-2024-003',
        medicineName: 'Cetirizine 10mg',
        organizationName: 'Apollo Pharmacy — Indiranagar',
        description: 'Batch CETR10-2024-003 marked as DESTROYED (Cert #CDSCO-CERT-2026-004812) scanned as active retail inventory.',
        aiNarrative: 'Batch CETR10-2024-003 was previously certified as destroyed via high-temperature incineration on 2026-08-27. It has now reappeared in active retail inventory at Apollo Pharmacy. This represents a critical chain-of-custody breach suggesting either illicit diversion of waste stock or counterfeit packaging reuse.',
      ),
      FraudAlert(
        id: 'alert-002',
        batchId: 'batch-002',
        alertType: 'QUANTITY_MISMATCH',
        severity: 'HIGH',
        status: 'INVESTIGATING',
        detectedAt: now.subtract(const Duration(hours: 3)),
        batchNumber: 'AMOX500-2025-089',
        medicineName: 'Amoxicillin 500mg',
        organizationName: 'MedSupply Southern Logistics Hub',
        description: 'Quantity mismatch: Return manifest declared 120 strips; physical distributor pickup verified 90 strips (Discrepancy: 30 strips).',
        aiNarrative: 'A discrepancy of 30 strips was recorded between retailer return manifest and distributor physical intake for batch AMOX500-2025-089. Discrepancies exceeding 10% warrant immediate physical recount and reconciliation under CDSCO Rule 65.',
      ),
    ]);

    // Initial event hash chain for batch-001
    String prevHash = '';
    final eventsRaw = [
      {'type': 'MANUFACTURED', 'actor': 'usr-manufacturer-01', 'org': 'org-manufacturer-01', 'qty': 500, 'prev': 'PLANNED', 'new': 'ACTIVE', 'daysAgo': 365},
      {'type': 'DISTRIBUTED', 'actor': 'usr-distributor-01', 'org': 'org-distributor-01', 'qty': 500, 'prev': 'ACTIVE', 'new': 'IN_TRANSIT', 'daysAgo': 350},
      {'type': 'RECEIVED_BY_RETAILER', 'actor': 'usr-retailer-01', 'org': 'org-retailer-01', 'qty': 500, 'prev': 'IN_TRANSIT', 'new': 'ACTIVE', 'daysAgo': 345},
    ];

    for (int i = 0; i < eventsRaw.length; i++) {
      final e = eventsRaw[i];
      final ts = now.subtract(Duration(days: e['daysAgo'] as int));
      final payload = json.encode({
        'batch_id': 'batch-001',
        'event_type': e['type'],
        'actor_id': e['actor'],
        'quantity': e['qty'],
        'new_status': e['new'],
        'timestamp': ts.toIso8601String(),
      });
      final hash = sha256.convert(utf8.encode('$prevHash:$payload')).toString();
      _events.add(BatchEvent(
        id: 'evt-00${i + 1}',
        batchId: 'batch-001',
        eventType: e['type'] as String,
        actorId: e['actor'] as String,
        actorName: _users.values.firstWhere((u) => u.id == e['actor']).name,
        organizationId: e['org'] as String,
        organizationName: _organizations.firstWhere((o) => o.id == e['org']).name,
        quantity: e['qty'] as int,
        previousStatus: e['prev'] as String,
        newStatus: e['new'] as String,
        timestamp: ts,
        eventHash: hash,
        previousEventHash: prevHash.isEmpty ? null : prevHash,
      ));
      prevHash = hash;
    }
  }

  // ─── Query methods ────────────────────────────────────────────────────────

  AppUser? getUser(String email) => _users[email];
  AppUser? getUserById(String id) => _users.values.firstWhere((u) => u.id == id);

  List<MedicineBatch> getBatchesForPharmacy(String pharmacyId) =>
      _batches.toList();

  List<MedicineBatch> getBatchesForManufacturer(String manufacturerId) =>
      _batches
          .where((b) =>
              b.manufacturerId == manufacturerId || manufacturerId.isEmpty)
          .toList();

  List<MedicineBatch> getPendingReturnsForManufacturer(String manufacturerId) =>
      _batches
          .where((b) =>
              (b.manufacturerId == manufacturerId || manufacturerId.isEmpty) &&
              ['RETURN_INITIATED', 'IN_TRANSIT', 'PENDING', 'PICKUP_ASSIGNED'].contains(b.status))
          .toList();

  List<ReverseRequest> getRequestsForManufacturer(String manufacturerId) =>
      _reverseRequests.toList();

  List<MedicineBatch> getCollectedBatches() =>
      _batches.where((b) => [
        'COLLECTED',
        'DISTRIBUTOR_VERIFIED',
        'MANUFACTURER_RECEIVED',
        'DISPOSAL_PENDING',
      ].contains(b.status)).toList();

  /// Returns batches assigned to this facility — either pre-seeded ones or
  /// those the manufacturer assigned in-session.
  List<MedicineBatch> getAssignedToFacility(String facilityId) {
    return _batches.where((b) {
      if (!['SENT_FOR_DESTRUCTION', 'DISPOSAL_PENDING'].contains(b.status)) {
        return false;
      }
      // Check if explicitly assigned to this facility in-session
      final assignedTo = _batchFacilityAssignments[b.id];
      if (assignedTo != null) {
        final isSame = assignedTo == facilityId ||
            (assignedTo == '44444444-0000-0000-0000-000000000001' &&
                facilityId == 'org-facility-01') ||
            (assignedTo == 'org-facility-01' &&
                facilityId == '44444444-0000-0000-0000-000000000001');
        return isSame;
      }
      // Fall-back: all sent-for-destruction batches are visible to any facility
      return true;
    }).toList();
  }

  /// Assign a batch to a specific waste facility in-session.
  void assignFacilityToBatch(String batchId, String facilityOrgId) {
    _batchFacilityAssignments[batchId] = facilityOrgId;
  }

  List<MedicineBatch> getAllBatches() => _batches.toList();

  MedicineBatch? getBatchByNumber(String number) {
    try {
      return _batches.firstWhere((b) => b.batchNumber.toLowerCase() == number.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }

  MedicineBatch? getBatchById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BatchEvent> getEventsForBatch(String batchId) =>
      _events.where((e) => e.batchId == batchId).toList();

  List<BatchEvent> getAllEvents() => _events.toList();

  Map<String, int> getPharmacyStats() {
    return {
      'expiring_soon': _batches.where((b) => b.isExpiringSoon && !b.isExpired).length,
      'expired': _batches.where((b) => b.isExpired).length,
      'pending_returns': _batches.where((b) => b.status == 'RETURN_INITIATED').length,
      'completed': _batches.where((b) => b.isDestroyed).length,
    };
  }

  Map<String, int> getSystemStats() {
    final counts = <String, int>{};
    for (final b in _batches) {
      counts[b.status] = (counts[b.status] ?? 0) + 1;
    }
    return counts;
  }

  void updateBatchStatus({
    required String batchId,
    required String newStatus,
    required String actorId,
    required String organizationId,
    required String eventType,
    int quantity = 0,
    String? previousStatus,
    String? wasteFacilityId,
  }) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx != -1) {
      final old = _batches[idx];
      _batches[idx] = old.copyWith(status: newStatus);
      // Track facility assignment when scheduling for destruction
      if (wasteFacilityId != null) {
        _batchFacilityAssignments[batchId] = wasteFacilityId;
      }

      final prevEvent = _events.where((e) => e.batchId == batchId).lastOrNull;
      final prevHash = prevEvent?.eventHash ?? '';
      final payload = json.encode({
        'batch_id': batchId,
        'event_type': eventType,
        'actor_id': actorId,
        'quantity': quantity,
        'new_status': newStatus,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final hash = sha256.convert(utf8.encode('$prevHash:$payload')).toString();

      _events.add(BatchEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        batchId: batchId,
        eventType: eventType,
        actorId: actorId,
        actorName: 'Authorized Operator',
        organizationId: organizationId,
        organizationName: 'Authorized Entity',
        quantity: quantity,
        previousStatus: previousStatus ?? old.status,
        newStatus: newStatus,
        timestamp: DateTime.now(),
        eventHash: hash,
        previousEventHash: prevHash.isEmpty ? null : prevHash,
      ));
    }
  }

  List<ReverseRequest> getRequestsForPharmacy(String pharmacyId) =>
      _reverseRequests.toList();

  List<ReverseRequest> getPendingRequests() =>
      _reverseRequests.where((r) => r.status == 'PENDING').toList();

  List<Pickup> getPickupsForDistributor(String distributorId) =>
      _pickups.toList();

  ReverseRequest createReverseRequest({
    required String batchId,
    required String retailerId,
    required int requestedQuantity,
    required String reason,
    String? proofUrl,
  }) {
    final batch = getBatchById(batchId);
    final req = ReverseRequest(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      batchId: batchId,
      retailerId: retailerId,
      requestedQuantity: requestedQuantity,
      reason: reason,
      status: 'PENDING',
      initiatedAt: DateTime.now(),
      batchNumber: batch?.batchNumber,
      medicineName: batch?.medicineName,
      pharmacyName: 'Apollo Pharmacy — Indiranagar',
      proofUrl: proofUrl,
    );
    _reverseRequests.insert(0, req);
    _pickups.insert(
      0,
      Pickup(
        id: 'pick-${DateTime.now().millisecondsSinceEpoch}',
        reverseRequestId: req.id,
        distributorId: 'org-distributor-01',
        pickupStatus: 'SCHEDULED',
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        reverseRequest: req,
      ),
    );
    return req;
  }

  /// Mock accept pickup — called when manufacturer assigns a distributor.
  void acceptPickupMock({
    required String requestId,
    required String distributorId,
    required DateTime scheduledDate,
  }) {
    final idx = _reverseRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final old = _reverseRequests[idx];
      _reverseRequests[idx] = ReverseRequest(
        id: old.id,
        batchId: old.batchId,
        retailerId: old.retailerId,
        distributorId: distributorId,
        requestedQuantity: old.requestedQuantity,
        reason: old.reason,
        status: 'ACCEPTED',
        initiatedAt: old.initiatedAt,
        batchNumber: old.batchNumber,
        medicineName: old.medicineName,
        pharmacyName: old.pharmacyName,
        proofUrl: old.proofUrl,
      );
      // Also update or create the pickup record
      final pickIdx = _pickups.indexWhere((p) => p.reverseRequestId == requestId);
      final updatedReq = _reverseRequests[idx];
      final otp = Pickup.generateOtp(updatedReq.batchId);
      if (pickIdx != -1) {
        final oldPick = _pickups[pickIdx];
        _pickups[pickIdx] = oldPick.copyWith(
          distributorId: distributorId,
          pickupStatus: 'ASSIGNED',
          scheduledDate: scheduledDate,
          handoverOtp: otp,
          reverseRequest: updatedReq,
        );
      } else {
        _pickups.insert(
          0,
          Pickup(
            id: 'pick-${DateTime.now().millisecondsSinceEpoch}',
            reverseRequestId: requestId,
            distributorId: distributorId,
            pickupStatus: 'ASSIGNED',
            scheduledDate: scheduledDate,
            handoverOtp: otp,
            reverseRequest: updatedReq,
          ),
        );
      }
    }
  }

  /// Distributor accepts the assigned pickup task
  void acceptPickupByDistributorMock(String pickupId) {
    final idx = _pickups.indexWhere((p) => p.id == pickupId);
    if (idx != -1) {
      final p = _pickups[idx];
      _pickups[idx] = p.copyWith(pickupStatus: 'ACCEPTED');
    }
  }

  /// Distributor collects the batch at the pharmacy counter with photo proof
  void collectPickupAtPharmacyMock({
    required String pickupId,
    required int actualQuantity,
    String? proofUrl,
    String? actorId,
    String? orgId,
  }) {
    final pickIdx = _pickups.indexWhere((p) => p.id == pickupId);
    if (pickIdx != -1) {
      final old = _pickups[pickIdx];
      _pickups[pickIdx] = old.copyWith(
        pickupStatus: 'COLLECTED',
        actualQuantity: actualQuantity,
        pickupProofUrl: proofUrl,
      );
      if (old.reverseRequest != null) {
        final reqIdx = _reverseRequests.indexWhere(
            (r) => r.id == old.reverseRequestId);
        if (reqIdx != -1) {
          final oldReq = _reverseRequests[reqIdx];
          _reverseRequests[reqIdx] = ReverseRequest(
            id: oldReq.id,
            batchId: oldReq.batchId,
            retailerId: oldReq.retailerId,
            distributorId: oldReq.distributorId,
            requestedQuantity: oldReq.requestedQuantity,
            reason: oldReq.reason,
            status: 'IN_TRANSIT',
            initiatedAt: oldReq.initiatedAt,
            batchNumber: oldReq.batchNumber,
            medicineName: oldReq.medicineName,
            pharmacyName: oldReq.pharmacyName,
            proofUrl: proofUrl ?? oldReq.proofUrl,
          );
        }
        // Update batch status to COLLECTED
        updateBatchStatus(
          batchId: old.reverseRequest!.batchId,
          newStatus: 'COLLECTED',
          actorId: actorId ?? 'usr-distributor-01',
          organizationId: orgId ?? 'org-distributor-01',
          eventType: 'PICKUP_COLLECTED_AT_PHARMACY',
          quantity: actualQuantity,
          previousStatus: 'PICKUP_ASSIGNED',
        );
      }
    }
  }

  /// Manufacturer Gate Delivery: Verify 6-digit OTP and complete journey
  bool completeHandoverWithOtpMock({
    required String pickupId,
    required String otp,
    required String actorId,
    required String orgId,
    String? expectedOtp,
  }) {
    final cleanOtp = otp.trim();
    if (cleanOtp == '123456') {
      _applyMockHandoverCompletion(pickupId, actorId, orgId);
      return true;
    }
    if (expectedOtp != null && cleanOtp == expectedOtp.trim()) {
      _applyMockHandoverCompletion(pickupId, actorId, orgId);
      return true;
    }

    final pickIdx = _pickups.indexWhere(
        (p) => p.id == pickupId || p.reverseRequestId == pickupId);
    if (pickIdx == -1) {
      return false;
    }
    final pick = _pickups[pickIdx];
    final expected = pick.expectedOtp.trim();
    if (expected != cleanOtp &&
        cleanOtp != '123456' &&
        (expectedOtp == null || cleanOtp != expectedOtp.trim())) {
      return false;
    }

    _applyMockHandoverCompletion(pickupId, actorId, orgId);
    return true;
  }

  void _applyMockHandoverCompletion(
      String pickupId, String actorId, String orgId) {
    final pickIdx = _pickups.indexWhere(
        (p) => p.id == pickupId || p.reverseRequestId == pickupId);
    if (pickIdx == -1) return;

    final pick = _pickups[pickIdx];
    _pickups[pickIdx] = pick.copyWith(pickupStatus: 'COMPLETED');

    if (pick.reverseRequest != null) {
      final reqIdx = _reverseRequests.indexWhere(
          (r) => r.id == pick.reverseRequestId);
      if (reqIdx != -1) {
        final oldReq = _reverseRequests[reqIdx];
        _reverseRequests[reqIdx] = ReverseRequest(
          id: oldReq.id,
          batchId: oldReq.batchId,
          retailerId: oldReq.retailerId,
          distributorId: oldReq.distributorId,
          requestedQuantity: oldReq.requestedQuantity,
          reason: oldReq.reason,
          status: 'COMPLETED',
          initiatedAt: oldReq.initiatedAt,
          completedAt: DateTime.now(),
          batchNumber: oldReq.batchNumber,
          medicineName: oldReq.medicineName,
          pharmacyName: oldReq.pharmacyName,
          proofUrl: oldReq.proofUrl,
        );
      }

      // Transition batch status to MANUFACTURER_RECEIVED
      updateBatchStatus(
        batchId: pick.reverseRequest!.batchId,
        newStatus: 'MANUFACTURER_RECEIVED',
        actorId: actorId,
        organizationId: orgId,
        eventType: 'MFG_GATE_HANDOVER_OTP_VERIFIED',
        quantity: pick.actualQuantity ?? pick.reverseRequest!.requestedQuantity,
        previousStatus: 'COLLECTED',
      );
    }
  }

  /// Legacy helper
  void completePickupMock({
    required String pickupId,
    required int actualQuantity,
  }) {
    collectPickupAtPharmacyMock(
      pickupId: pickupId,
      actualQuantity: actualQuantity,
    );
  }



  List<DisposalRecord> getDisposalRecords() => _disposalRecords.toList();

  /// Persist a disposal record in-session so facility can record destruction.
  DisposalRecord addDisposalRecord({
    required String batchId,
    required String manufacturerId,
    required String wasteFacilityId,
    required String disposalMethod,
    required int quantityDestroyed,
    required DateTime scheduledDate,
  }) {
    final record = DisposalRecord(
      id: 'disp-${DateTime.now().millisecondsSinceEpoch}',
      batchId: batchId,
      manufacturerId: manufacturerId,
      wasteFacilityId: wasteFacilityId,
      disposalMethod: disposalMethod,
      quantityDestroyed: quantityDestroyed,
      status: 'SCHEDULED',
      actualDisposalDate: scheduledDate,
    );
    _disposalRecords.add(record);
    return record;
  }

  List<Map<String, dynamic>> getWasteFacilities() {
    return _organizations
        .where((o) => o.type == 'WASTE_FACILITY')
        .map((o) => {'id': o.id, 'name': o.name})
        .toList();
  }

  List<FraudAlert> getFraudAlerts({String? severity, String? status}) {
    var list = _fraudAlerts.toList();
    if (severity != null) list = list.where((a) => a.severity == severity).toList();
    if (status != null) list = list.where((a) => a.status == status).toList();
    return list;
  }

  void updateFraudNarrative(String alertId, String narrative) {
    final idx = _fraudAlerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      final old = _fraudAlerts[idx];
      _fraudAlerts[idx] = FraudAlert(
        id: old.id,
        batchId: old.batchId,
        alertType: old.alertType,
        severity: old.severity,
        status: old.status,
        detectedAt: old.detectedAt,
        batchNumber: old.batchNumber,
        medicineName: old.medicineName,
        organizationName: old.organizationName,
        description: old.description,
        aiNarrative: narrative,
      );
    }
  }

  void updateFraudAlertStatus({
    required String alertId,
    required String status,
    String? resolvedBy,
    String? resolutionNotes,
  }) {
    final idx = _fraudAlerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      final old = _fraudAlerts[idx];
      _fraudAlerts[idx] = old.copyWith(
        status: status,
        resolvedBy: resolvedBy,
        resolvedAt: status == 'RESOLVED' || status == 'FALSE_POSITIVE'
            ? DateTime.now()
            : null,
        resolutionNotes: resolutionNotes,
      );
    }
  }

  /// Create a fraud alert in the mock database (mirrors _fireAlert in FraudDetectionService).
  FraudAlert? createFraudAlert({
    required String batchId,
    required String alertType,
    required String severity,
    required String description,
    required String organizationId,
  }) {
    final batch = getBatchById(batchId);
    final org = _organizations.firstWhere(
      (o) => o.id == organizationId,
      orElse: () => const Organization(
        id: '', name: 'Unknown', type: 'PHARMACY',
        licenseNumber: '', verificationStatus: 'VERIFIED',
      ),
    );
    final alert = FraudAlert(
      id: 'alert-${DateTime.now().millisecondsSinceEpoch}',
      batchId: batchId,
      alertType: alertType,
      severity: severity,
      status: 'OPEN',
      detectedAt: DateTime.now(),
      batchNumber: batch?.batchNumber,
      medicineName: batch?.medicineName,
      organizationName: org.name,
      description: description,
    );
    _fraudAlerts.insert(0, alert);
    return alert;
  }

  /// Record a scan event (mirrors BatchRepository.recordScanEvent in mock mode).
  void recordScanEvent({
    required String batchId,
    required String scannedBy,
    required String organizationId,
    String result = 'SCAN',
    String? scanContext,
  }) {
    // No-op for mock — could track in a list if needed
  }

  /// Get all destruction certificates
  List<DestructionCertificate> getCertificates() {
    return List.unmodifiable(_certificates);
  }

  /// Get destruction certificate for a specific batch ID
  DestructionCertificate? getCertificateForBatch(String batchId) {
    for (final cert in _certificates) {
      if (cert.batchId == batchId) return cert;
    }
    // Also check through disposal records
    final disp = _disposalRecords.cast<DisposalRecord?>().firstWhere(
      (d) => d?.batchId == batchId,
      orElse: () => null,
    );
    if (disp != null && disp.certificateId != null) {
      for (final cert in _certificates) {
        if (cert.id == disp.certificateId) return cert;
      }
    }
    return null;
  }

  /// Add a newly issued certificate
  void addCertificate(DestructionCertificate cert) {
    _certificates.insert(0, cert);
  }
}
