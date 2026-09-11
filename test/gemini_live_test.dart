import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/models/batch_event.dart';
import 'package:mediloop/services/gemini_service.dart';

void main() {
  test('GeminiService initialization and live AI features test', () async {
    final gemini = GeminiService();
    // ignore: avoid_print
    print('GeminiService.isInitialized: ${gemini.isInitialized}');
    expect(gemini.isInitialized, isTrue);

    final alert = FraudAlert(
      id: 'test-alert-001',
      batchId: '00000000-0000-0000-0000-000000000001',
      status: 'OPEN',
      alertType: 'DESTROYED_BATCH_REENTRY',
      severity: 'CRITICAL',
      batchNumber: 'PARA500-2026-001',
      medicineName: 'Paracetamol 500mg',
      description: 'Batch previously marked destroyed scanned at retail store',
      detectedAt: DateTime.now(),
    );

    final narrative = await gemini.generateFraudNarrative(alert);
    // ignore: avoid_print
    print('Live Gemini Fraud Narrative:\n$narrative');
    expect(narrative.isNotEmpty, isTrue);
  });
}
