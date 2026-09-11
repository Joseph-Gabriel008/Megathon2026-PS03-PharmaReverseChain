import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/auth_service.dart';
import 'services/gemini_service.dart';
import 'services/fraud_detection_service.dart';
import 'services/storage_service.dart';
import 'services/batch_lifecycle_service.dart';
import 'services/qr_service.dart';
import 'services/audit_service.dart';
import 'services/notification_service.dart';
import 'services/certificate_service.dart';
import 'services/evidence_service.dart';
import 'services/route_policy_service.dart';
import 'repositories/batch_repository.dart';
import 'repositories/reverse_repository.dart';
import 'repositories/disposal_repository.dart';
import 'repositories/organization_repository.dart';
import 'repositories/evidence_repository.dart';
import 'repositories/confirmation_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const MediLoopApp());
}

class MediLoopApp extends StatelessWidget {
  const MediLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MultiProvider(
      providers: [
        // ── Core services ──────────────────────────────────────────────────
        ChangeNotifierProvider(
          create: (_) => AuthService(client),
        ),
        Provider(create: (_) => GeminiService()),
        Provider(create: (_) => FraudDetectionService(client)),
        Provider(create: (_) => StorageService(client)),

        // ── Repositories ──────────────────────────────────────────────────
        Provider(create: (_) => BatchRepository(client)),
        Provider(create: (_) => ReverseRepository(client)),
        Provider(create: (_) => DisposalRepository(client)),
        Provider(create: (_) => OrganizationRepository(client)),
        Provider(create: (_) => EvidenceRepository(client)),
        Provider(create: (_) => ConfirmationRepository(client)),

        // ── Production services ────────────────────────────────────────────
        Provider(create: (_) => BatchLifecycleService(client)),
        Provider(create: (_) => QrService(client)),
        Provider(create: (_) => AuditService(client)),
        Provider(create: (_) => NotificationService(client)),
        Provider(create: (_) => CertificateService(client)),
        Provider(create: (_) => RoutePolicyService()),
        Provider(
          create: (c) => EvidenceService(
            c.read<StorageService>(),
            c.read<EvidenceRepository>(),
          ),
        ),
      ],
      child: _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<AuthService>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MediLoop',
      debugShowCheckedModeBanner: false,
      theme: buildMediLoopTheme(),
      routerConfig: _router,
    );
  }
}
