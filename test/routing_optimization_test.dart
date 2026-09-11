import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/core/router.dart';
import 'package:mediloop/features/returns/return_request_flow.dart';
import 'package:mediloop/features/retailer/retailer_shell.dart';
import 'package:mediloop/widgets/app_back_scope.dart';
import 'package:mediloop/services/auth_service.dart';
import 'package:mediloop/repositories/batch_repository.dart';
import 'package:mediloop/repositories/organization_repository.dart';
import 'package:mediloop/repositories/reverse_repository.dart';
import 'package:mediloop/repositories/disposal_repository.dart';
import 'package:mediloop/services/fraud_detection_service.dart';
import 'package:mediloop/services/gemini_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  group('Routing Optimization & Safe Navigation Tests', () {
    test('defaultHomeForRole returns accurate paths for all 5 roles', () {
      expect(defaultHomeForRole('PHARMACY'), '/retailer');
      expect(defaultHomeForRole('DISTRIBUTOR'), '/distributor');
      expect(defaultHomeForRole('MANUFACTURER'), '/manufacturer');
      expect(defaultHomeForRole('WASTE_FACILITY'), '/facility');
      expect(defaultHomeForRole('REGULATOR'), '/admin');
      expect(defaultHomeForRole(null), '/login');
      expect(defaultHomeForRole('UNKNOWN'), '/login');
    });

    testWidgets('Root path / redirects logged-in user to default role home',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer');

      router.go('/');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });

    testWidgets('Unmatched route displays friendly error screen with safe return button',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to an invalid path
      router.go('/nonexistent-path-12345');
      await tester.pumpAndSettle();

      // Check that error builder rendered without throwing
      expect(find.text('Route Not Found'), findsWidgets);
      expect(find.text('Return to Safety'), findsOneWidget);

      // Tapping Return to Safety safely navigates to role home
      await tester.tap(find.text('Return to Safety'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });

    testWidgets('ReturnRequestFlow BackButton at step 0 exits cleanly without GoError',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer');

      // Open /return/new via push (the optimized flow from Retailer Dashboard)
      router.push('/return/new');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReturnRequestFlow), findsOneWidget);

      // Tap the AppBar back button
      final backBtn = find.byType(BackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Successfully popped back to RetailerDashboardPage with 0 exceptions
      expect(find.byType(ReturnRequestFlow), findsNothing);
      expect(find.byType(RetailerDashboardPage), findsOneWidget);
    });

    testWidgets('Direct URL navigation to /return/new exits safely to /retailer via back button',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);
      router.go('/return/new');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReturnRequestFlow), findsOneWidget);

      // BackButton safely calls context.safePop(fallback: '/retailer') without throwing GoError
      final backBtn = find.byType(BackButton);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });

    testWidgets('System back / swipe gesture on sub-tab (/retailer/batches) navigates to home screen (/retailer)',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);
      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);
      router.go('/retailer/batches');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer/batches');

      // Simulate system back / swipe back gesture on sub-tab
      await (tester.binding as WidgetsBinding).handlePopRoute();
      await tester.pumpAndSettle();

      // Successfully navigated back to home screen (/retailer)
      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });

    testWidgets('System back gesture on home screen (/retailer) prompts exit confirmation popup and allows cancel',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);
      await authService.login('retailer@demo.com', 'Demo@2025');

      final router = buildRouter(authService);
      router.go('/retailer');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<ReverseRepository>(create: (_) => ReverseRepository(fakeClient)),
            Provider<DisposalRepository>(create: (_) => DisposalRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retailer');

      // Simulate system back / swipe back gesture on home screen
      await (tester.binding as WidgetsBinding).handlePopRoute();
      await tester.pumpAndSettle();

      // Exit confirmation popup should be displayed
      expect(find.text('Exit MediLoop?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Popup is dismissed and user safely remains on /retailer
      expect(find.text('Exit MediLoop?'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });

    testWidgets('AppBackScope invokes onExitConfirmed callback when Exit App is tapped',
        (WidgetTester tester) async {
      bool exitConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppBackScope(
            homeRoute: '/',
            onExitConfirmed: () async {
              exitConfirmed = true;
            },
            child: const Scaffold(body: Text('Home Content')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger back on root route
      await (tester.binding as WidgetsBinding).handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Exit MediLoop?'), findsOneWidget);
      await tester.tap(find.text('Exit App'));
      await tester.pumpAndSettle();

      expect(exitConfirmed, isTrue);
    });
  });
}
