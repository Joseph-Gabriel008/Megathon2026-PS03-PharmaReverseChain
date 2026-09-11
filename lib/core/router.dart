import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/retailer/retailer_shell.dart';
import '../features/distributor/distributor_shell.dart';
import '../features/manufacturer/manufacturer_shell.dart';
import '../features/facility/facility_shell.dart';
import '../features/admin/admin_shell.dart';
import '../features/batches/batch_detail_screen.dart';
import '../features/scanner/scan_screen.dart';
import '../features/returns/return_request_flow.dart';
import '../features/fraud/fraud_alert_center.dart';

String defaultHomeForRole(String? role) => switch (role) {
      'PHARMACY' => '/retailer',
      'DISTRIBUTOR' => '/distributor',
      'MANUFACTURER' => '/manufacturer',
      'WASTE_FACILITY' => '/facility',
      'REGULATOR' => '/admin',
      _ => '/login',
    };

extension SafeNavigationExtension on BuildContext {
  /// Safely pops the current route if a prior page exists on the navigator stack;
  /// otherwise safely navigates to [fallback] or the user's role-appropriate home.
  void safePop({String? fallback}) {
    if (canPop()) {
      pop();
      return;
    }

    if (fallback != null) {
      go(fallback);
      return;
    }

    try {
      final auth = read<AuthService>();
      go(defaultHomeForRole(auth.currentRole));
    } catch (_) {
      go('/login');
    }
  }
}

GoRouter buildRouter(AuthService authService, {GlobalKey<NavigatorState>? rootNavigatorKey}) {
  final rootKey = rootNavigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/login',
    refreshListenable: authService,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Route Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(MediLoopSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded,
                  size: 64, color: MediLoopColors.critical),
              const SizedBox(height: MediLoopSpacing.md),
              Text(
                'Route Not Found',
                style: MediLoopText.h3,
              ),
              const SizedBox(height: MediLoopSpacing.xs),
              Text(
                'The requested destination "${state.uri.path}" does not exist or access is restricted.',
                textAlign: TextAlign.center,
                style: MediLoopText.bodyMuted,
              ),
              const SizedBox(height: MediLoopSpacing.lg),
              ElevatedButton.icon(
                onPressed: () => context.safePop(),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Return to Safety'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final isLoggedIn = authService.isLoggedIn;
      final role = authService.currentRole;
      final isLoginRoute = state.matchedLocation == '/login';

      if (state.matchedLocation == '/' || state.matchedLocation.isEmpty) {
        return isLoggedIn ? defaultHomeForRole(role) : '/login';
      }

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn) {
        if (isLoginRoute) {
          return defaultHomeForRole(role);
        }

        final path = state.matchedLocation;

        // Strict role-based route boundaries:
        // Users can only access features belonging to their assigned role
        if (path.startsWith('/retailer') && role != 'PHARMACY') {
          return defaultHomeForRole(role);
        }
        if (path.startsWith('/return/new') && role != 'PHARMACY') {
          return defaultHomeForRole(role);
        }
        if (path.startsWith('/distributor') && role != 'DISTRIBUTOR') {
          return defaultHomeForRole(role);
        }
        if (path.startsWith('/manufacturer') && role != 'MANUFACTURER') {
          return defaultHomeForRole(role);
        }
        if (path.startsWith('/facility') && role != 'WASTE_FACILITY') {
          return defaultHomeForRole(role);
        }
        if (path.startsWith('/admin') && role != 'REGULATOR') {
          return defaultHomeForRole(role);
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Retailer ──────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            RetailerShell(child: child),
        routes: [
          GoRoute(
            path: '/retailer',
            builder: (context, state) => const RetailerDashboardPage(),
          ),
          GoRoute(
            path: '/retailer/batches',
            builder: (context, state) => RetailerBatchesPage(
              initialFilter: state.uri.queryParameters['filter'] ?? 'ALL',
            ),
          ),
          GoRoute(
            path: '/retailer/scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: '/retailer/returns',
            builder: (context, state) => const RetailerRequestsPage(),
          ),
          GoRoute(
            path: '/retailer/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Distributor ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            DistributorShell(child: child),
        routes: [
          GoRoute(
            path: '/distributor',
            builder: (context, state) => const DistributorDashboardPage(),
          ),
          GoRoute(
            path: '/distributor/pickups',
            builder: (context, state) => const DistributorPickupsPage(),
          ),
          GoRoute(
            path: '/distributor/scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: '/distributor/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Manufacturer ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            ManufacturerShell(child: child),
        routes: [
          GoRoute(
            path: '/manufacturer',
            builder: (context, state) => const ManufacturerDashboardPage(),
          ),
          GoRoute(
            path: '/manufacturer/batches',
            builder: (context, state) => const ManufacturerBatchesPage(),
          ),
          GoRoute(
            path: '/manufacturer/disposal',
            builder: (context, state) => const ManufacturerDisposalPage(),
          ),
          GoRoute(
            path: '/manufacturer/scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: '/manufacturer/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Facility ──────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            FacilityShell(child: child),
        routes: [
          GoRoute(
            path: '/facility',
            builder: (context, state) => const FacilityDashboardPage(),
          ),
          GoRoute(
            path: '/facility/assigned',
            builder: (context, state) => const FacilityAssignedPage(),
          ),
          GoRoute(
            path: '/facility/scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: '/facility/record',
            builder: (context, state) => const FacilityRecordPage(),
          ),
          GoRoute(
            path: '/facility/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Admin ─────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/organizations',
            builder: (context, state) => const AdminOrganizationsPage(),
          ),
          GoRoute(
            path: '/admin/batches',
            builder: (context, state) => const AdminBatchesPage(),
          ),
          GoRoute(
            path: '/admin/fraud',
            builder: (context, state) => const FraudAlertCenter(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AdminAuditPage(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── Shared ────────────────────────────────────────────────
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/batch/:id',
        builder: (context, state) => BatchDetailScreen(
          batchId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/return/new',
        builder: (context, state) => ReturnRequestFlow(
          initialBatchId: state.uri.queryParameters['batchId'],
        ),
      ),
    ],
  );
}
