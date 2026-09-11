import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/organization_repository.dart';
import '../../models/batch_event.dart';
import '../../models/organization.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/lifecycle_pipeline.dart';
import '../../widgets/status_badge.dart';
import '../../services/gemini_service.dart';
import '../../services/audit_service.dart';
import '../../services/auth_service.dart';
import '../../models/medicine_batch.dart';
import '../../widgets/app_back_scope.dart';
import 'package:intl/intl.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.of(context).size.width;

    // Sidebar layout for tablet/desktop
    if (screenWidth >= 768) {
      return AppBackScope(
        homeRoute: '/admin',
        child: Scaffold(
          body: Row(
            children: [
              _AdminSidebar(currentPath: location),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    // Bottom nav for mobile
    return AppBackScope(
      homeRoute: '/admin',
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indexForPath(location),
          onDestinationSelected: (i) {
            switch (i) {
              case 0: context.go('/admin');
              case 1: context.go('/admin/organizations');
              case 2: context.go('/admin/batches');
              case 3: context.go('/admin/fraud');
              case 4: context.go('/admin/audit');
              case 5: context.go('/admin/profile');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Sentinel',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_outlined),
              selectedIcon: Icon(Icons.business),
              label: 'Orgs',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Batches',
            ),
            NavigationDestination(
              icon: Icon(Icons.gpp_bad_outlined),
              selectedIcon: Icon(Icons.gpp_bad),
              label: 'Fraud',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Audit',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _indexForPath(String path) {
    if (path.startsWith('/admin/organizations')) return 1;
    if (path.startsWith('/admin/batches')) return 2;
    if (path.startsWith('/admin/fraud')) return 3;
    if (path.startsWith('/admin/audit')) return 4;
    if (path.startsWith('/admin/profile')) return 5;
    return 0;
  }
}

class _AdminSidebar extends StatelessWidget {
  final String currentPath;

  const _AdminSidebar({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: MediLoopColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(MediLoopSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text('MediLoop', style: MediLoopText.plexSans(
                    size: 14, weight: FontWeight.w600)),
                Text('Admin', style: MediLoopText.caption),
              ],
            ),
          ),
          const Divider(),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Sentinel Hub',
            path: '/admin',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.business_outlined,
            label: 'Organizations',
            path: '/admin/organizations',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.inventory_2_outlined,
            label: 'Batches',
            path: '/admin/batches',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.gpp_bad_outlined,
            label: 'Fraud Alerts',
            path: '/admin/fraud',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.history_outlined,
            label: 'Audit',
            path: '/admin/audit',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            path: '/admin/profile',
            currentPath: currentPath,
          ),
          const Spacer(),
          const Divider(),
          Material(
            color: Colors.transparent,
            child: ListTile(
              key: const Key('admin_sidebar_logout_button'),
              leading: const Icon(Icons.logout_rounded, color: MediLoopColors.critical, size: 20),
              title: Text(
                'Sign Out',
                style: MediLoopText.inter(
                  size: 13,
                  weight: FontWeight.w600,
                  color: MediLoopColors.critical,
                ),
              ),
              dense: true,
              onTap: () async {
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  bool get _isSelected => currentPath.startsWith(path) &&
      (path == '/admin' ? currentPath == '/admin' : true);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _isSelected ? MediLoopColors.line : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: _isSelected
                    ? MediLoopColors.ink
                    : MediLoopColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: MediLoopText.inter(
                  size: 13,
                  weight: _isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: _isSelected
                      ? MediLoopColors.ink
                      : MediLoopColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Dashboard ─────────────────────────────────────────────────────────

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, int> _stageCounts = {};
  int _orgCount = 0;
  int _activeBatches = 0;
  int _expiredBatches = 0;
  int _openAlerts = 0;
  List<FraudAlert> _alerts = [];
  bool _loading = true;
  RealtimeChannel? _fraudChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToFraudAlerts();
  }

  @override
  void dispose() {
    _fraudChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final batchRepo = context.read<BatchRepository>();
      final orgRepo = context.read<OrganizationRepository>();

      final stageCounts = await batchRepo.getSystemStats();
      final alerts = await orgRepo.getFraudAlerts(status: 'OPEN');
      final orgs = await orgRepo.getAllOrganizations();

      final activeBatches = stageCounts.entries
          .where((e) =>
              !['DESTROYED', 'CLOSED'].contains(e.key))
          .fold(0, (sum, e) => sum + e.value);

      if (mounted) {
        setState(() {
          _stageCounts = stageCounts;
          _alerts = alerts;
          _orgCount = orgs.length;
          _activeBatches = activeBatches;
          _expiredBatches = stageCounts['EXPIRED'] ?? 0;
          _openAlerts = alerts.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminDashboard _load note: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _subscribeToFraudAlerts() {
    try {
      _fraudChannel = Supabase.instance.client
          .channel('fraud_alerts_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'fraud_alerts',
            callback: (payload) async {
              // New alert arrived — add to top of list and generate narrative
              final newAlert =
                  FraudAlert.fromJson(payload.newRecord);

              if (mounted) {
                setState(() {
                  _alerts = [newAlert, ..._alerts];
                  _openAlerts++;
                });

                // Generate AI narrative for the new alert
                final gemini = context.read<GeminiService>();
                final orgRepo = context.read<OrganizationRepository>();
                final narrative =
                    await gemini.generateFraudNarrative(newAlert);
                await orgRepo.updateFraudNarrative(
                    alertId: newAlert.id, narrative: narrative);

                // Update the card in the list with the narrative
                if (mounted) {
                  setState(() {
                    _alerts = _alerts.map((a) {
                      if (a.id == newAlert.id) {
                        return FraudAlert.fromJson({
                          ...payload.newRecord,
                          'ai_narrative': narrative,
                        });
                      }
                      return a;
                    }).toList();
                  });
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Admin realtime alert note: $e');
    }
  }

  // Pipeline stage counts mapped to pipeline stages (0-5)
  Map<String, int> get _pipelineStageCounts {
    return {
      'Expired': (_stageCounts['EXPIRED'] ?? 0) +
          (_stageCounts['EXPIRING_SOON'] ?? 0),
      'Returned': (_stageCounts['RETURN_INITIATED'] ?? 0) +
          (_stageCounts['PICKUP_ASSIGNED'] ?? 0),
      'Collected': (_stageCounts['COLLECTED'] ?? 0) +
          (_stageCounts['IN_TRANSIT'] ?? 0),
      'Verified': (_stageCounts['DISTRIBUTOR_VERIFIED'] ?? 0) +
          (_stageCounts['MANUFACTURER_RECEIVED'] ?? 0),
      'Destroyed': (_stageCounts['DESTROYED'] ?? 0) +
          (_stageCounts['SENT_FOR_DESTRUCTION'] ?? 0) +
          (_stageCounts['DESTRUCTION_RECORDED'] ?? 0),
      'Certified': (_stageCounts['CERTIFIED'] ?? 0) +
          (_stageCounts['CLOSED'] ?? 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CDSCO Sentinel Hub',
                  style: MediLoopText.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: MediLoopColors.verifiedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MediLoopColors.verified.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE RADAR',
                        style: MediLoopText.inter(
                          size: 9.5,
                          weight: FontWeight.w800,
                          color: MediLoopColors.verified,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              'Realtime National Drug Disposal Mandate Monitor',
              style: MediLoopText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          IconButton(
            key: const Key('admin_dashboard_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Sign Out',
            onPressed: () => context.go('/admin/profile'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                children: [
                  // Hero: System-wide Pipeline Funnel
                  Container(
                    decoration: BoxDecoration(
                      color: MediLoopColors.surface,
                      borderRadius: BorderRadius.circular(MediLoopRadius.card),
                      border: Border.all(color: MediLoopColors.line, width: 1),
                      boxShadow: MediLoopShadows.card,
                    ),
                    padding: const EdgeInsets.all(MediLoopSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MediLoopColors.accentBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.hub_rounded,
                                size: 18,
                                color: MediLoopColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reverse Chain Pipeline — Pan-India',
                                    style: MediLoopText.plexSans(
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: MediLoopColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'Live batch volume progressing across all 6 custody stages',
                                    style: MediLoopText.caption.copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: MediLoopColors.accentBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MediLoopColors.accent.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                '${_pipelineStageCounts.values.fold(0, (a, b) => a + b)} Batches',
                                style: MediLoopText.caption.copyWith(
                                  color: MediLoopColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MediLoopSpacing.lg),
                        LifecyclePipeline(
                          completedStage: 6,
                          stageCounts: _pipelineStageCounts,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MediLoopSpacing.md),

                  // KPI grid with direct interactive navigation
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: MediLoopSpacing.sm,
                    mainAxisSpacing: MediLoopSpacing.sm,
                    childAspectRatio: 1.3,
                    children: [
                      KpiTile(
                        label: 'Registered entities',
                        value: _orgCount,
                        icon: Icons.apartment_rounded,
                        onTap: () => context.go('/admin/organizations'),
                      ),
                      KpiTile(
                        label: 'Active batches',
                        value: _activeBatches,
                        icon: Icons.inventory_2_rounded,
                        onTap: () => context.go('/admin/batches'),
                      ),
                      KpiTile(
                        label: 'Expired batches',
                        value: _expiredBatches,
                        warning: true,
                        icon: Icons.warning_amber_rounded,
                        onTap: () => context.go('/admin/batches'),
                      ),
                      KpiTile(
                        label: 'Open fraud alerts',
                        value: _openAlerts,
                        critical: true,
                        icon: Icons.gpp_bad_rounded,
                        onTap: () => context.go('/admin/fraud'),
                      ),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.lg),

                  // Fraud alert feed header
                  Row(
                    children: [
                      Text(
                        'Live Fraud Sentinel Feed',
                        style: MediLoopText.h4.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      if (_openAlerts > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: MediLoopColors.criticalBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_openAlerts ACTIVE',
                            style: MediLoopText.inter(
                              size: 10,
                              weight: FontWeight.w800,
                              color: MediLoopColors.critical,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (_openAlerts > 0)
                        TextButton(
                          onPressed: () => context.go('/admin/fraud'),
                          child: const Text('Open Center →'),
                        ),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.sm),

                  if (_alerts.isEmpty)
                    const EmptyState(
                      what: 'Sentinel Radar Clean',
                      action:
                          'No active fraud alerts detected across the supply chain. New security events stream here in real time.',
                      icon: Icons.shield_outlined,
                    )
                  else ...[
                    ..._alerts.take(5).map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: MediLoopSpacing.sm),
                            child: FraudAlertCard(
                              alert: a,
                              onTap: () => context.go('/admin/fraud'),
                            ),
                          ),
                        ),
                    if (_alerts.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: MediLoopSpacing.xs),
                        child: Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: Text('View all ${_alerts.length} alerts in Fraud Center'),
                            onPressed: () => context.go('/admin/fraud'),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: MediLoopSpacing.lg),
                ],
              ),
            ),
    );
  }
}

// ─── Stub admin pages ──────────────────────────────────────────────────────────

class AdminOrganizationsPage extends StatefulWidget {
  const AdminOrganizationsPage({super.key});

  @override
  State<AdminOrganizationsPage> createState() =>
      _AdminOrganizationsPageState();
}

class _AdminOrganizationsPageState extends State<AdminOrganizationsPage> {
  List<Organization> _orgs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<OrganizationRepository>();
    final data = await repo.getAllOrganizations();
    if (mounted) {
      setState(() {
        _orgs = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orgs.isEmpty
              ? const EmptyState(
                  what: 'No organizations registered.',
                  action: 'Organizations will appear here once onboarded.',
                  icon: Icons.business_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(MediLoopSpacing.md),
                  itemCount: _orgs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: MediLoopSpacing.sm),
                  itemBuilder: (_, i) {
                    final org = _orgs[i];
                    return Card(
                      child: ListTile(
                        title: Text(org.name, style: MediLoopText.h4),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(org.typeLabel, style: MediLoopText.bodyMuted),
                            Text(org.licenseNumber,
                                style: MediLoopText.batchCode),
                          ],
                        ),
                        trailing: StatusBadge(
                            status: org.verificationStatus, compact: true),
                      ),
                    );
                  },
                ),
    );
  }
}

class AdminBatchesPage extends StatefulWidget {
  const AdminBatchesPage({super.key});

  @override
  State<AdminBatchesPage> createState() => _AdminBatchesPageState();
}

class _AdminBatchesPageState extends State<AdminBatchesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<MedicineBatch> _batches = [];
  bool _loading = true;
  String _selectedStatus = 'ALL';

  static const List<String> _statusOptions = [
    'ALL',
    'ACTIVE',
    'EXPIRING_SOON',
    'EXPIRED',
    'RETURN_INITIATED',
    'PICKUP_ASSIGNED',
    'COLLECTED',
    'MANUFACTURER_RECEIVED',
    'DISPOSAL_PENDING',
    'SENT_FOR_DESTRUCTION',
    'DESTROYED',
    'CERTIFIED',
  ];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _loading = true);
    final repo = context.read<BatchRepository>();
    final data = await repo.getAdminBatches(
      statusFilter: _selectedStatus == 'ALL' ? null : _selectedStatus,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _batches = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('All Batches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MediLoopSpacing.md,
              vertical: MediLoopSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search batch #, medicine name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadBatches();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MediLoopSpacing.md,
                  vertical: 10,
                ),
                filled: true,
                fillColor: MediLoopColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  borderSide: const BorderSide(color: MediLoopColors.line),
                ),
              ),
              onSubmitted: (_) => _loadBatches(),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: MediLoopSpacing.md,
              vertical: 4,
            ),
            child: Row(
              children: _statusOptions.map((s) {
                final isSelected = _selectedStatus == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(s.replaceAll('_', ' ')),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedStatus = s);
                      _loadBatches();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: MediLoopSpacing.xs),
          const Divider(height: 1),

          // Count row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MediLoopSpacing.md,
              vertical: 6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_batches.length} batches found',
                  style: MediLoopText.caption,
                ),
                Text(
                  _selectedStatus == 'ALL' ? 'Showing all stages' : _selectedStatus,
                  style: MediLoopText.caption,
                ),
              ],
            ),
          ),

          // Batches list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _batches.isEmpty
                    ? const EmptyState(
                        what: 'No batches found.',
                        action: 'Try adjusting your search or stage filters.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBatches,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(MediLoopSpacing.md),
                          itemCount: _batches.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: MediLoopSpacing.sm),
                          itemBuilder: (_, i) {
                            final batch = _batches[i];
                            return BatchCard(
                              batch: batch,
                              onTap: () => context.push('/batch/${batch.id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  List<BatchEvent> _events = [];
  List<MedicineBatch> _batches = [];
  String? _selectedBatchId;
  AuditVerificationResult? _verificationResult;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    final batchRepo = context.read<BatchRepository>();
    final auditService = context.read<AuditService>();

    final batches = await batchRepo.getAllBatches();
    List<BatchEvent> events;

    if (_selectedBatchId != null) {
      events = await auditService.getEventsForBatch(_selectedBatchId!);
    } else {
      events = await auditService.getRecentEvents(limit: 50);
    }

    if (mounted) {
      setState(() {
        _batches = batches;
        _events = events;
        _loading = false;
      });
    }
  }

  Future<void> _onBatchSelected(String? batchId) async {
    setState(() {
      _selectedBatchId = batchId;
      _verificationResult = null;
      _loading = true;
    });

    final auditService = context.read<AuditService>();
    List<BatchEvent> events;
    if (batchId != null) {
      events = await auditService.getEventsForBatch(batchId);
    } else {
      events = await auditService.getRecentEvents(limit: 50);
    }

    if (mounted) {
      setState(() {
        _events = events;
        _loading = false;
      });
    }
  }

  Future<void> _verifySelectedChain() async {
    if (_selectedBatchId == null) return;
    setState(() => _verifying = true);

    try {
      final auditService = context.read<AuditService>();
      final result = await auditService.verifyChain(_selectedBatchId!);
      if (mounted) {
        setState(() {
          _verificationResult = result;
          _verifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Cryptographic Audit Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _onBatchSelected(_selectedBatchId),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter / Selection card
          Card(
            margin: const EdgeInsets.all(MediLoopSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audit Scope', style: MediLoopText.label),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedBatchId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MediLoopRadius.card),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Recent System Events (Global Stream)'),
                      ),
                      ..._batches.map(
                        (b) => DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text('${b.batchNumber} — ${b.displayName}'),
                        ),
                      ),
                    ],
                    onChanged: _onBatchSelected,
                  ),

                  // Verify button for specific batch
                  if (_selectedBatchId != null) ...[
                    const SizedBox(height: MediLoopSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _verifying ? null : _verifySelectedChain,
                        icon: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.shield_outlined, size: 18),
                        label: Text(_verifying
                            ? 'Computing SHA-256 Hashes...'
                            : 'Verify Batch Hash Chain'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Verification banner if result available
          if (_verificationResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MediLoopSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                decoration: BoxDecoration(
                  color: _verificationResult!.valid
                      ? MediLoopColors.verifiedBg
                      : MediLoopColors.criticalBg,
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  border: Border.all(
                    color: _verificationResult!.valid
                        ? MediLoopColors.verified
                        : MediLoopColors.critical,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _verificationResult!.valid
                          ? Icons.verified
                          : Icons.gpp_bad,
                      color: _verificationResult!.valid
                          ? MediLoopColors.verified
                          : MediLoopColors.critical,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _verificationResult!.valid
                                ? 'SHA-256 Hash Chain Verified Intact'
                                : 'Audit Chain Discrepancy Detected',
                            style: MediLoopText.inter(
                              size: 14,
                              weight: FontWeight.w700,
                              color: _verificationResult!.valid
                                  ? MediLoopColors.verified
                                  : MediLoopColors.critical,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _verificationResult!.valid
                                ? 'All ${_verificationResult!.eventsChecked} cryptographic blocks validated.'
                                : (_verificationResult!.issueDescription ??
                                    'Block hash mismatch identified.'),
                            style: MediLoopText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: MediLoopSpacing.sm),

          // Events Timeline
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const EmptyState(
                        what: 'No audit events found.',
                        action: 'Events are automatically created as batches move.',
                        icon: Icons.history_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(MediLoopSpacing.md),
                        itemCount: _events.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: MediLoopSpacing.sm),
                        itemBuilder: (_, i) {
                          final event = _events[i];
                          final isFraud = event.eventType == 'FRAUD_DETECTED';

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(MediLoopSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          event.eventTypeLabel,
                                          style: MediLoopText.inter(
                                            size: 14,
                                            weight: FontWeight.w600,
                                            color: isFraud
                                                ? MediLoopColors.critical
                                                : MediLoopColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM, HH:mm')
                                            .format(event.timestamp),
                                        style: MediLoopText.caption,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${event.actorName ?? 'Operator'} · ${event.organizationName ?? 'System'}',
                                    style: MediLoopText.bodyMuted,
                                  ),
                                  if (event.quantity > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Quantity: ${event.quantity} units',
                                      style: MediLoopText.caption,
                                    ),
                                  ],
                                  if (event.previousStatus != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        StatusBadge(
                                          status: event.previousStatus!,
                                          compact: true,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: 12,
                                            color: MediLoopColors.textMuted,
                                          ),
                                        ),
                                        StatusBadge(
                                          status: event.newStatus,
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 6),
                                  // Cryptographic Hash Display
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_outline,
                                        size: 13,
                                        color: MediLoopColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          event.eventHash.isNotEmpty
                                              ? 'Hash: ${event.eventHash}'
                                              : 'Genesis Block',
                                          style: MediLoopText.hashText,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (event.previousEventHash != null &&
                                      event.previousEventHash!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.link,
                                          size: 13,
                                          color: MediLoopColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Prev: ${event.previousEventHash}',
                                            style: MediLoopText.hashText,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

