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
import 'package:mediloop/repositories/confirmation_repository.dart';
import 'package:mediloop/repositories/evidence_repository.dart';
import 'package:mediloop/services/evidence_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  testWidgets('Test logging into distributor dashboard and profile',
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
          Provider(create: (_) => ConfirmationRepository(fakeClient)),
          Provider(create: (_) => EvidenceRepository(fakeClient)),
          Provider(
            create: (c) => EvidenceService(
              c.read<StorageService>(),
              c.read<EvidenceRepository>(),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify on login
    expect(find.text('Secure Sign In'), findsOneWidget);

    // Login as distributor
    final err = await authService.login('distributor@demo.com', AppConstants.demoPassword);
    expect(err, isNull);
    expect(authService.isLoggedIn, isTrue);
    expect(authService.currentRole, 'DISTRIBUTOR');

    await tester.pumpAndSettle();

    // Verify redirected to Distributor Dashboard
    expect(find.text('Distributor Dashboard'), findsOneWidget);
    expect(find.text('Pending pickups'), findsOneWidget);

    // Navigate to profile tab
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    // Verify Profile page renders
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Suresh Menon, Logistics Lead'), findsOneWidget);
    expect(find.text('MedSupply Southern Logistics Hub'), findsOneWidget);
    expect(find.text('Distributor'), findsWidgets);
  });
}
