import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/core/constants.dart';
import 'package:mediloop/core/router.dart';
import 'package:mediloop/services/auth_service.dart';
import 'package:mediloop/services/gemini_service.dart';
import 'package:mediloop/services/fraud_detection_service.dart';
import 'package:mediloop/services/storage_service.dart';
import 'package:mediloop/services/batch_lifecycle_service.dart';
import 'package:mediloop/services/qr_service.dart';
import 'package:mediloop/services/audit_service.dart';
import 'package:mediloop/services/notification_service.dart';
import 'package:mediloop/services/certificate_service.dart';
import 'package:mediloop/repositories/batch_repository.dart';
import 'package:mediloop/repositories/reverse_repository.dart';
import 'package:mediloop/repositories/disposal_repository.dart';
import 'package:mediloop/repositories/organization_repository.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  testWidgets('Test clicking Verify batch on confirm sheet',
      (WidgetTester tester) async {
    final fakeClient = _FakeClient();
    final authService = AuthService(fakeClient);
    final router = buildRouter(authService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          Provider(create: (_) => GeminiService()),
          Provider(create: (_) => FraudDetectionService(fakeClient)),
          Provider(create: (_) => StorageService(fakeClient)),
          Provider(create: (_) => BatchLifecycleService(fakeClient)),
          Provider(create: (_) => QrService(fakeClient)),
          Provider(create: (_) => AuditService(fakeClient)),
          Provider(create: (_) => NotificationService(fakeClient)),
          Provider(create: (_) => CertificateService(fakeClient)),
          Provider(create: (_) => BatchRepository(fakeClient)),
          Provider(create: (_) => ReverseRepository(fakeClient)),
          Provider(create: (_) => DisposalRepository(fakeClient)),
          Provider(create: (_) => OrganizationRepository(fakeClient)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Login as retailer
    await authService.login('retailer@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Navigate to /retailer/scan
    router.go('/retailer/scan');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Why are you scanning?'), findsOneWidget);
    // Proceed to camera with default selected context
    await tester.tap(find.text('Proceed to camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap manual entry icon to open confirm sheet
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Confirm sheet is visible with batch number and quick-select chips
    expect(find.text('Verify batch'), findsOneWidget);
    expect(find.text('PARA500-2026-001'), findsOneWidget);
    expect(find.text('Paracetamol 500mg'), findsWidgets);

    // Tap quick-select chip for Amoxicillin
    expect(find.text('Amoxicillin 500mg'), findsOneWidget);
    await tester.tap(find.text('Amoxicillin 500mg'));
    await tester.pump();

    // Verify text field updated
    expect(find.text('AMOX500-2025-089'), findsOneWidget);

    // Tap quick-select chip back to Paracetamol
    await tester.tap(find.text('Paracetamol 500mg').first);
    await tester.pump();
    expect(find.text('PARA500-2026-001'), findsOneWidget);

    // Tap 'Verify batch'
    await tester.tap(find.text('Verify batch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Check result phase displayed
    expect(find.text('Batch verified'), findsOneWidget);
  });

  test('GeminiService intelligent offline packaging extraction tests', () async {
    final gemini = GeminiService();
    // Test with simulated image filenames
    final amoxResult = await gemini.extractBatchFromImage(File('amox_strip_photo.jpg'));
    expect(amoxResult.batchNumber, 'AMOX500-2025-089');
    expect(amoxResult.medicineName, 'Amoxicillin 500mg');
    expect(amoxResult.isOfflineBackup, true);

    final metfResult = await gemini.extractBatchFromImage(File('metformin_box.png'));
    expect(metfResult.batchNumber, 'METF500-2026-042');
    expect(metfResult.medicineName, 'Metformin 500mg');

    final atorResult = await gemini.extractBatchFromImage(File('atorvastatin_20mg.jpg'));
    expect(atorResult.batchNumber, 'ATOR20-2025-015');
    expect(atorResult.medicineName, 'Atorvastatin 20mg');
  });

  test('GeminiService rejects non-pharmaceutical images in offline fallback', () async {
    final gemini = GeminiService();

    // Rejection of non-pharma keyword images
    final deskResult = await gemini.extractBatchFromImage(File('desk_workspace.jpg'));
    expect(deskResult.success, isFalse);
    expect(deskResult.batchNumber, isNull);
    expect(deskResult.medicineName, isNull);
    expect(deskResult.errorMessage, isNotNull);

    final mugResult = await gemini.extractBatchFromImage(File('coffee_mug_photo.png'));
    expect(mugResult.success, isFalse);
    expect(mugResult.batchNumber, isNull);

    // Random non-medicine photo
    final randomResult = await gemini.extractBatchFromImage(File('random_room_wall.jpg'));
    expect(randomResult.success, isFalse);
    expect(randomResult.batchNumber, isNull);
  });

  test('QrService and batch decoding tests', () {
    const rawQr = 'MEDILOOP:BATCH:aaaaaaaa-0000-0000-0000-000000000001';
    expect(QrService.isMediLoopQr(rawQr), isTrue);
    expect(QrService.decodeBatchQr(rawQr), 'aaaaaaaa-0000-0000-0000-000000000001');

    const pipeQr = 'MEDILOOP|PARA500-2026-001|med-01|2026-09-10';
    final parts = pipeQr.split('|');
    expect(parts[1], 'PARA500-2026-001');
  });
}
