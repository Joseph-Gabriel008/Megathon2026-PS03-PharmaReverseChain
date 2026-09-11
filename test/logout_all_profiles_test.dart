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

Widget _buildTestApp({required AuthService authService}) {
  final router = buildRouter(authService);
  final fakeClient = _FakeClient();

  return MultiProvider(
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
  );
}

void main() {
  testWidgets('Pharmacy / Retailer: profile logout with cancel and confirm',
      (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as pharmacy/retailer
    final err = await authService.login('retailer@demo.com', AppConstants.demoPassword);
    expect(err, isNull);
    await tester.pumpAndSettle();

    // Go to profile tab
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Sign out of MediLoop'), findsOneWidget);

    // Tap logout button -> confirmation dialog appears
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    expect(find.text('Sign Out of MediLoop'), findsOneWidget);
    expect(find.byKey(const Key('logout_cancel_button')), findsOneWidget);

    // Cancel logout
    await tester.tap(find.byKey(const Key('logout_cancel_button')));
    await tester.pumpAndSettle();

    // Still on profile and still logged in
    expect(find.text('My Profile'), findsOneWidget);
    expect(authService.isLoggedIn, isTrue);

    // Tap AppBar logout icon button
    await tester.tap(find.byKey(const Key('profile_appbar_logout_button')));
    await tester.pumpAndSettle();

    // Confirm logout
    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pumpAndSettle();

    // Verify logged out and back to login screen
    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });

  testWidgets('Distributor: profile logout flow', (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as distributor
    await authService.login('distributor@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Go to profile tab
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);

    // Tap logout button and confirm
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pumpAndSettle();

    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });

  testWidgets('Manufacturer: profile logout flow', (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as manufacturer
    await authService.login('manufacturer@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Go to profile tab
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);

    // Tap logout and confirm
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pumpAndSettle();

    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });

  testWidgets('Waste Facility: profile logout flow', (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as facility
    await authService.login('facility@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Go to profile tab
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);

    // Tap logout and confirm
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pumpAndSettle();

    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });

  testWidgets('Admin: navigates to profile and logs out successfully',
      (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as admin
    await authService.login('admin@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Verify on Admin Dashboard
    expect(find.text('CDSCO Sentinel Hub'), findsOneWidget);

    // Tap profile tab in navigation bar
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();

    // Verify Admin is on Profile page
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Inspector Rajesh Sharma'), findsOneWidget);

    // Tap logout and confirm
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pumpAndSettle();

    // Verify logged out and returned to login screen
    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });

  testWidgets('Admin: direct logout from desktop sidebar',
      (WidgetTester tester) async {
    final authService = AuthService(_FakeClient());
    await tester.pumpWidget(_buildTestApp(authService: authService));
    await tester.pumpAndSettle();

    // Login as admin
    await authService.login('admin@demo.com', AppConstants.demoPassword);
    await tester.pumpAndSettle();

    // Tap sidebar logout button
    await tester.tap(find.byKey(const Key('admin_sidebar_logout_button')));
    await tester.pumpAndSettle();

    // Verify immediately logged out to login screen
    expect(authService.isLoggedIn, isFalse);
    expect(find.text('Secure Sign In'), findsOneWidget);
  });
}
