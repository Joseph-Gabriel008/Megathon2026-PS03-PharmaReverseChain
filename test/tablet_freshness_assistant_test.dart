import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/data/mock_database.dart';
import 'package:mediloop/services/gemini_service.dart';

void main() {
  late GeminiService gemini;
  late MockDatabase db;

  setUp(() {
    gemini = GeminiService();
    db = MockDatabase.instance;
    db.reset();
  });

  group('Tablet Freshness Analysis Tests', () {
    test('Calculates high freshness for active batch', () {
      final batch = db.getBatchByNumber('AZITH250-2026-112')!;
      final result = gemini.calculateTabletFreshness(batch);

      expect(result.isExpired, isFalse);
      expect(result.isDisposed, isFalse);
      expect(result.isSafeToDispense, isTrue);
      expect(result.freshnessPercentage, greaterThan(60.0));
      expect(result.freshnessGrade, equals('PEAK_FRESH'));
      expect(result.spokenSummary, contains('FRESH and SAFE'));
    });

    test('Calculates 0% freshness for expired batch', () {
      final batch = db.getBatchByNumber('AMOX500-2025-089')!;
      final result = gemini.calculateTabletFreshness(batch);

      expect(result.isExpired, isTrue);
      expect(result.isDisposed, isFalse);
      expect(result.isSafeToDispense, isFalse);
      expect(result.freshnessPercentage, equals(0.0));
      expect(result.freshnessGrade, equals('EXPIRED'));
      expect(result.spokenSummary, contains('EXPIRED'));
      expect(result.cdscoRecommendation, contains('QUARANTINE IMMEDIATELY'));
    });

    test('Identifies disposed and destroyed batch', () {
      final batch = db.getBatchByNumber('CETR10-2024-003')!;
      final result = gemini.calculateTabletFreshness(batch);

      expect(result.isDisposed, isTrue);
      expect(result.freshnessGrade, equals('DISPOSED'));
      expect(result.isSafeToDispense, isFalse);
      expect(result.spokenSummary, contains('officially disposed and destroyed'));
      expect(result.cdscoRecommendation, contains('OFFICIALLY DISPOSED'));
    });

    test('Calculates expiring soon status correctly', () {
      final batch = db.getBatchByNumber('METF500-2026-042')!;
      final result = gemini.calculateTabletFreshness(batch);

      expect(result.isExpiringSoon, isTrue);
      expect(result.isExpired, isFalse);
      expect(result.freshnessGrade, equals('EXPIRING_SOON'));
      expect(result.spokenSummary, contains('EXPIRING SOON'));
    });
  });

  group('AI Assistant Q&A Tablet Sync Tests', () {
    test('Answers specific expiry question for PARA500-2026-001', () async {
      final answer = await gemini.assistantQuery(
        question: 'is the tablet PARA500-2026-001 expired?',
        screenContext: 'Retailer Dashboard',
      );

      expect(answer, contains('NOT expired'));
      expect(answer, contains('FRESH'));
    });

    test('Answers specific expiry question for expired AMOX500-2025-089', () async {
      final answer = await gemini.assistantQuery(
        question: 'is tablet with serial number AMOX500-2025-089 expired?',
        screenContext: 'Retailer Dashboard',
      );

      expect(answer, contains('EXPIRED'));
      expect(answer, contains('0%'));
    });

    test('Answers specific disposal question for destroyed CETR10-2024-003', () async {
      final answer = await gemini.assistantQuery(
        question: 'is the tablet with that serial number CETR10-2024-003 got disposed?',
        screenContext: 'Retailer Dashboard',
      );

      expect(answer, contains('officially disposed and destroyed'));
      expect(answer, contains('Certificate of Destruction'));
    });

    test('Answers disposal question for active batch PARA500-2026-001', () async {
      final answer = await gemini.assistantQuery(
        question: 'is the tablet with serial number PARA500-2026-001 got disposed?',
        screenContext: 'Retailer Dashboard',
      );

      expect(answer, contains('NOT been disposed'));
      expect(answer, contains('active inventory'));
    });

    test('Resolves tablet freshness analysis query', () async {
      final answer = await gemini.assistantQuery(
        question: 'help in the analysis of the tablet whether it is expired or fresh',
        screenContext: 'Retailer Dashboard',
      );

      expect(answer, contains('Freshness Analysis'));
      expect(answer, contains('fresh batches safe for dispensing'));
      expect(answer, contains('expired'));
    });

    test('Uses screenContext to answer contextual "is the tablet expired?" question', () async {
      final answer = await gemini.assistantQuery(
        question: 'is the tablet expired?',
        screenContext: 'Batch Detail Passport for PARA500-2026-001 - Paracetamol 500mg',
      );

      expect(answer, contains('NOT expired'));
      expect(answer, contains('FRESH'));
    });

    test('Uses screenContext to answer contextual disposal question', () async {
      final answer = await gemini.assistantQuery(
        question: 'is the tablet with that serial number got disposed?',
        screenContext: 'Batch Detail Passport for CETR10-2024-003 - Cetirizine 10mg',
      );

      expect(answer, contains('officially disposed and destroyed'));
    });
  });
}
