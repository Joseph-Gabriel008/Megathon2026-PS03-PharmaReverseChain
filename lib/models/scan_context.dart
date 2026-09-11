// lib/models/scan_context.dart
//
// Scan context enum — determines WHY a QR scan is happening.
// The fraud engine uses this to avoid false positives:
// e.g., scanning a DESTROYED batch for an AUDIT_VIEW is legitimate,
// but scanning it as ACTIVE_STOCK_CHECK is CRITICAL fraud.

enum ScanContext {
  activeStockCheck,
  returnInitiation,
  distributorPickup,
  manufacturerReceipt,
  facilityReceipt,
  disposalVerification,
  inventoryCheck,
  auditView;

  String get value => switch (this) {
        ScanContext.activeStockCheck => 'ACTIVE_STOCK_CHECK',
        ScanContext.returnInitiation => 'RETURN_INITIATION',
        ScanContext.distributorPickup => 'DISTRIBUTOR_PICKUP',
        ScanContext.manufacturerReceipt => 'MANUFACTURER_RECEIPT',
        ScanContext.facilityReceipt => 'FACILITY_RECEIPT',
        ScanContext.disposalVerification => 'DISPOSAL_VERIFICATION',
        ScanContext.inventoryCheck => 'INVENTORY_CHECK',
        ScanContext.auditView => 'AUDIT_VIEW',
      };

  String get label => switch (this) {
        ScanContext.activeStockCheck => 'Active stock check',
        ScanContext.returnInitiation => 'Return initiation',
        ScanContext.distributorPickup => 'Distributor pickup',
        ScanContext.manufacturerReceipt => 'Manufacturer receipt',
        ScanContext.facilityReceipt => 'Facility receipt',
        ScanContext.disposalVerification => 'Disposal verification',
        ScanContext.inventoryCheck => 'Inventory check',
        ScanContext.auditView => 'Audit / historical view',
      };

  String get description => switch (this) {
        ScanContext.activeStockCheck =>
          'Checking this batch as available stock for sale',
        ScanContext.returnInitiation => 'Initiating a reverse logistics return',
        ScanContext.distributorPickup => 'Confirming pickup of returned batch',
        ScanContext.manufacturerReceipt => 'Receiving batch at manufacturer',
        ScanContext.facilityReceipt => 'Receiving batch at waste facility',
        ScanContext.disposalVerification => 'Verifying batch before destruction',
        ScanContext.inventoryCheck => 'General inventory check',
        ScanContext.auditView => 'Historical audit view only — not a transaction',
      };

  /// Contexts where a destroyed batch re-entry is a fraud signal
  bool get triggersDestroyedReentry =>
      this == ScanContext.activeStockCheck ||
      this == ScanContext.returnInitiation ||
      this == ScanContext.inventoryCheck;

  /// Contexts that are legitimate even for destroyed batches
  bool get isAuditSafe =>
      this == ScanContext.auditView ||
      this == ScanContext.disposalVerification;

  static ScanContext fromValue(String v) =>
      ScanContext.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ScanContext.inventoryCheck,
      );

  /// Returns the scan contexts allowed for a specific user role.
  static List<ScanContext> contextsForRole(String? role) => switch (role) {
        'PHARMACY' => const [
            ScanContext.activeStockCheck,
            ScanContext.returnInitiation,
            ScanContext.inventoryCheck,
          ],
        'DISTRIBUTOR' => const [
            ScanContext.distributorPickup,
            ScanContext.inventoryCheck,
          ],
        'MANUFACTURER' => const [
            ScanContext.manufacturerReceipt,
            ScanContext.inventoryCheck,
            ScanContext.auditView,
          ],
        'WASTE_FACILITY' => const [
            ScanContext.facilityReceipt,
            ScanContext.disposalVerification,
            ScanContext.auditView,
          ],
        'REGULATOR' => const [
            ScanContext.auditView,
            ScanContext.activeStockCheck,
            ScanContext.inventoryCheck,
          ],
        _ => const [
            ScanContext.activeStockCheck,
            ScanContext.inventoryCheck,
          ],
      };

  /// Returns the primary default scan context for a role.
  static ScanContext defaultForRole(String? role) => switch (role) {
        'PHARMACY' => ScanContext.activeStockCheck,
        'DISTRIBUTOR' => ScanContext.distributorPickup,
        'MANUFACTURER' => ScanContext.manufacturerReceipt,
        'WASTE_FACILITY' => ScanContext.disposalVerification,
        'REGULATOR' => ScanContext.auditView,
        _ => ScanContext.activeStockCheck,
      };
}
