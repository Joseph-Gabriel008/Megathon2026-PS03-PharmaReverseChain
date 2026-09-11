import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../data/mock_database.dart';
import '../models/organization.dart';
import '../models/batch_event.dart';

class OrganizationRepository {
  final SupabaseClient _client;

  OrganizationRepository(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  Future<List<Organization>> getAllOrganizations() async {
    if (_isMock) {
      return MockDatabase.instance.getWasteFacilities().map((f) => Organization(
        id: f['id'] as String,
        name: f['name'] as String,
        type: 'WASTE_FACILITY',
        licenseNumber: 'CPCB-BMW-2022',
        verificationStatus: 'VERIFIED',
      )).toList();
    }
    try {
      final data = await _client
          .from('organizations')
          .select('*')
          .order('name');
      return (data as List).map((e) => Organization.fromJson(e)).toList();
    } catch (_) {
      return MockDatabase.instance.getWasteFacilities().map((f) => Organization(
        id: f['id'] as String,
        name: f['name'] as String,
        type: 'WASTE_FACILITY',
        licenseNumber: 'CPCB-BMW-2022',
        verificationStatus: 'VERIFIED',
      )).toList();
    }
  }

  Future<Organization?> getOrganizationById(String id) async {
    try {
      final data = await _client
          .from('organizations')
          .select('*')
          .eq('id', id)
          .single();
      return Organization.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<List<FraudAlert>> getFraudAlerts({
    String? severity,
    String? status,
    String? alertType,
  }) async {
    if (_isMock) {
      return MockDatabase.instance.getFraudAlerts(severity: severity, status: status);
    }
    try {
      var query = _client.from('fraud_alerts').select('''
            *,
            medicine_batches(batch_number, medicines(name)),
            organizations(name)
          ''');

      if (severity != null) query = query.eq('severity', severity);
      if (status != null) query = query.eq('status', status);
      if (alertType != null) query = query.eq('alert_type', alertType);

      final data =
          await query.order('detected_at', ascending: false);
      return (data as List).map((e) => FraudAlert.fromJson(e)).toList();
    } catch (_) {
      return MockDatabase.instance.getFraudAlerts(severity: severity, status: status);
    }
  }

  Future<void> updateFraudAlertStatus({
    required String alertId,
    required String status,
    String? resolvedBy,
    String? resolutionNotes,
  }) async {
    MockDatabase.instance.updateFraudAlertStatus(
      alertId: alertId,
      status: status,
      resolvedBy: resolvedBy,
      resolutionNotes: resolutionNotes,
    );
    if (_isMock) return;
    try {
      final updates = <String, dynamic>{
        'status': status,
        if (resolvedBy != null) 'resolved_by': resolvedBy,
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
        if (status == 'RESOLVED' || status == 'FALSE_POSITIVE')
          'resolved_at': DateTime.now().toIso8601String(),
      };
      await _client
          .from('fraud_alerts')
          .update(updates)
          .eq('id', alertId);
    } catch (_) {}
  }

  Future<void> updateFraudNarrative({
    required String alertId,
    required String narrative,
  }) async {
    MockDatabase.instance.updateFraudNarrative(alertId, narrative);
    if (_isMock) return;
    try {
      await _client
          .from('fraud_alerts')
          .update({'ai_narrative': narrative})
          .eq('id', alertId);
    } catch (_) {}
  }
}
