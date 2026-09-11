import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediloop/core/router.dart';
import 'package:mediloop/features/scanner/scan_screen.dart';


import 'package:mediloop/models/scan_context.dart';
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
  group('Role-Based Access Control (RBAC) Tests', () {
    test('ScanContext.contextsForRole strictly isolates contexts per role', () {
      final pharmacyContexts = ScanContext.contextsForRole('PHARMACY');
      expect(pharmacyContexts, contains(ScanContext.activeStockCheck));
      expect(pharmacyContexts, contains(ScanContext.returnInitiation));
      expect(pharmacyContexts, isNot(contains(ScanContext.distributorPickup)));
      expect(pharmacyContexts, isNot(contains(ScanContext.disposalVerification)));

      final distributorContexts = ScanContext.contextsForRole('DISTRIBUTOR');
      expect(distributorContexts, contains(ScanContext.distributorPickup));
      expect(distributorContexts, isNot(contains(ScanContext.activeStockCheck)));
      expect(distributorContexts, isNot(contains(ScanContext.disposalVerification)));

      final facilityContexts = ScanContext.contextsForRole('WASTE_FACILITY');
      expect(facilityContexts, contains(ScanContext.disposalVerification));
      expect(facilityContexts, contains(ScanContext.facilityReceipt));
      expect(facilityContexts, isNot(contains(ScanContext.returnInitiation)));
      expect(facilityContexts, isNot(contains(ScanContext.activeStockCheck)));
    });

    testWidgets('ScanScreen displays only distributor features when logged in as distributor',
        (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      // Log in as distributor
      await authService.login('distributor@demo.com', 'Demo@2025');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            Provider<BatchRepository>(create: (_) => BatchRepository(fakeClient)),
            Provider<OrganizationRepository>(create: (_) => OrganizationRepository(fakeClient)),
            Provider<FraudDetectionService>(create: (_) => FraudDetectionService(fakeClient)),
            Provider<GeminiService>(create: (_) => GeminiService()),
          ],
          child: const MaterialApp(
            home: ScanScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Distributor mode banner
      expect(find.textContaining('Distributor Hub mode'), findsOneWidget);

      // Should show Distributor Pickup
      expect(find.text('Distributor pickup'), findsOneWidget);

      // Should NOT show Retailer or Waste Facility specific options
      expect(find.text('Active stock check'), findsNothing);
      expect(find.text('Return initiation'), findsNothing);
      expect(find.text('Disposal verification'), findsNothing);
    });

    testWidgets('Router blocks cross-role navigation', (WidgetTester tester) async {
      final fakeClient = _FakeClient();
      final authService = AuthService(fakeClient);

      // Log in as Retailer (PHARMACY)
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

      // Initial route for retailer is /retailer
      expect(router.routeInformationProvider.value.uri.path, '/retailer');

      // Attempt unauthorized navigation to /distributor
      router.go('/distributor');
      await tester.pumpAndSettle();

      // Router guard redirects back to /retailer
      expect(router.routeInformationProvider.value.uri.path, '/retailer');

      // Attempt unauthorized navigation to /admin
      router.go('/admin');
      await tester.pumpAndSettle();

      // Router guard redirects back to /retailer
      expect(router.routeInformationProvider.value.uri.path, '/retailer');
    });
  });
}
