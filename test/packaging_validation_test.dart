import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/services/gemini_service.dart';

void main() {
  group('PackagingValidationResult & Gemini Packaging Validation Tests', () {
    test('Non-pharmaceutical image filename triggers invalid packaging rejection', () async {
      final gemini = GeminiService();

      // Create a temporary file with a non-medicine name
      final tempDir = await Directory.systemTemp.createTemp('mediloop_test_');
      final nonMedFile = File('${tempDir.path}/coffee_mug_photo.jpg');
      await nonMedFile.writeAsBytes(List.filled(2048, 42));

      final result = await gemini.validateMedicinePackaging(nonMedFile);

      // The offline rule engine or fallback should reject non-medicine items
      // When filename doesn't contain pharma keywords or contains non-med keywords
      expect(result.isValid, isFalse);
      expect(result.packagingType, equals('Not Medicine'));
      expect(result.message, contains('Non-pharmaceutical'));

      // Clean up
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Medicine strip image filename triggers valid packaging approval', () async {
      final gemini = GeminiService();

      final tempDir = await Directory.systemTemp.createTemp('mediloop_test_');
      final medStripFile = File('${tempDir.path}/amoxicillin_blister_strip.jpg');
      await medStripFile.writeAsBytes(List.filled(4096, 42));

      final result = await gemini.validateMedicinePackaging(medStripFile);

      expect(result.isValid, isTrue);
      expect(result.packagingType, contains('Strip'));
      expect(result.message, contains('Physical packaging proof recorded'));

      // Clean up
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Tiny corrupted or empty file is rejected as low resolution', () async {
      final gemini = GeminiService();

      final tempDir = await Directory.systemTemp.createTemp('mediloop_test_');
      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.writeAsBytes([1, 2, 3]); // Only 3 bytes

      final result = await gemini.validateMedicinePackaging(emptyFile);

      expect(result.isValid, isFalse);
      expect(result.message, contains('low resolution or empty'));

      // Clean up
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
  });
}
