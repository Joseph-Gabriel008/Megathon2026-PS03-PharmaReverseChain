import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/features/scanner/scan_screen.dart';
import 'package:mediloop/services/auth_service.dart';
import 'package:mediloop/repositories/batch_repository.dart';
import 'package:mediloop/repositories/organization_repository.dart';
import 'package:mediloop/services/fraud_detection_service.dart';
import 'package:mediloop/services/gemini_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  testWidgets('ScanScreen transitions between context and camera, and handles back/exit',
      (WidgetTester tester) async {
    final fakeClient = _FakeClient();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(
            create: (_) => AuthService(fakeClient),
          ),
          Provider<BatchRepository>(
            create: (_) => BatchRepository(fakeClient),
          ),
          Provider<OrganizationRepository>(
            create: (_) => OrganizationRepository(fakeClient),
          ),
          Provider<FraudDetectionService>(
            create: (_) => FraudDetectionService(fakeClient),
          ),
          Provider<GeminiService>(
            create: (_) => GeminiService(),
          ),
        ],
        child: const MaterialApp(
          home: ScanScreen(),
        ),
      ),
    );

    await tester.pump();

    // 1. Initial screen is Context Selection phase
    expect(find.text('Why are you scanning?'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Proceed to camera'), findsOneWidget);

    // 2. Tap "Proceed to camera"
    await tester.tap(find.text('Proceed to camera'));
    await tester.pump();

    // 3. Now in camera phase
    expect(find.text('Scan batch'), findsOneWidget);
    // Back arrow button and close button are present in camera AppBar
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 4. Tap the back arrow button to return to context selection
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();

    // Verified back in context selection screen
    expect(find.text('Why are you scanning?'), findsOneWidget);
  });
}
