import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../repositories/batch_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/app_back_scope.dart';
import '../../repositories/reverse_repository.dart';
import '../../models/medicine_batch.dart';
import '../../models/reverse_request.dart';
import 'package:intl/intl.dart';

class RetailerShell extends StatelessWidget {
  final Widget child;
  const RetailerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForPath(location);

    return AppBackScope(
      homeRoute: '/retailer',
      child: Scaffold(
        body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/retailer');
            case 1: context.go('/retailer/batches');
            case 2: context.go('/retailer/scan');
            case 3: context.go('/retailer/returns');
            case 4: context.go('/retailer/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Batches',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Requests',
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
    if (path.startsWith('/retailer/batches')) return 1;
    if (path.startsWith('/retailer/scan')) return 2;
    if (path.startsWith('/retailer/returns')) return 3;
    if (path.startsWith('/retailer/profile')) return 4;
    return 0;
  }
}

// ─── Retailer Dashboard Page ──────────────────────────────────────────────

class RetailerDashboardPage extends StatefulWidget {
  const RetailerDashboardPage({super.key});

  @override
  State<RetailerDashboardPage> createState() => _RetailerDashboardPageState();
}

class _RetailerDashboardPageState extends State<RetailerDashboardPage> {
  Map<String, int> _stats = {};
  List<MedicineBatch> _recentBatches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final batchRepo = context.read<BatchRepository>();
      if (auth.currentUser != null) {
        final stats = await batchRepo.getPharmacyStats(
            auth.currentUser!.organizationId);
        final batches = await batchRepo.getBatchesForPharmacy(
            auth.currentUser!.organizationId);
        if (mounted) {
          setState(() {
            _stats = stats;
            _recentBatches = batches.take(4).toList();
          });
        }
      }
    } catch (_) {
      // Use default zeros on error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.currentUser?.organizationName ?? 'MediLoop',
              style: MediLoopText.h4,
            ),
            Text('Pharmacy', style: MediLoopText.caption),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            key: const Key('retailer_appbar_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Sign Out',
            onPressed: () => context.go('/retailer/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          children: [
            // Hero Welcome Banner
            Container(
              decoration: BoxDecoration(
                gradient: MediLoopGradients.hero,
                borderRadius: BorderRadius.circular(MediLoopRadius.card),
                boxShadow: MediLoopShadows.elevated,
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.currentUser?.organizationName ?? 'Apollo Pharmacy',
                              style: MediLoopText.plexSans(
                                size: 17,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'License DL-2024-8891 • CDSCO Zone IV',
                              style: MediLoopText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
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
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'ONLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reverse logistics mandate active • Expired stock must return within 30 days',
                          style: MediLoopText.inter(
                            size: 11.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: MediLoopSpacing.lg),

            // Section Header
            Row(
              children: [
                Text('Inventory & Reverse Pipeline', style: MediLoopText.h4),
                const Spacer(),
                Text(
                  'Realtime counts',
                  style: MediLoopText.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.sm),

            // KPI tiles
            _loading
                ? const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()))
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: MediLoopSpacing.sm,
                    mainAxisSpacing: MediLoopSpacing.sm,
                    childAspectRatio: 1.25,
                    children: [
                      KpiTile(
                        label: 'Expiring soon',
                        value: _stats['expiring_soon'] ?? 0,
                        warning: true,
                        icon: Icons.schedule_rounded,
                        onTap: () =>
                            context.go('/retailer/batches?filter=EXPIRING_SOON'),
                      ),
                      KpiTile(
                        label: 'Expired units',
                        value: _stats['expired'] ?? 0,
                        critical: true,
                        icon: Icons.warning_amber_rounded,
                        onTap: () =>
                            context.go('/retailer/batches?filter=EXPIRED'),
                      ),
                      KpiTile(
                        label: 'Pending returns',
                        value: _stats['pending_returns'] ?? 0,
                        warning: true,
                        icon: Icons.swap_horiz_rounded,
                        onTap: () => context.go('/retailer/returns'),
                      ),
                      KpiTile(
                        label: 'Completed returns',
                        value: _stats['completed'] ?? 0,
                        icon: Icons.verified_rounded,
                        onTap: () =>
                            context.go('/retailer/batches?filter=DESTROYED'),
                      ),
                    ],
                  ),

            const SizedBox(height: MediLoopSpacing.lg),

            // Primary action cards
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionButton(
                    id: 'scan_batch_btn',
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Batch',
                    subtitle: 'Check active / expired stock',
                    color: MediLoopColors.ink,
                    iconBg: MediLoopColors.accentBg,
                    iconColor: MediLoopColors.accent,
                    onTap: () => context.go('/retailer/scan'),
                  ),
                ),
                const SizedBox(width: MediLoopSpacing.sm),
                Expanded(
                  child: _PrimaryActionButton(
                    id: 'start_return_btn',
                    icon: Icons.swap_horiz_rounded,
                    label: 'Start Return',
                    subtitle: 'Initiate reverse logistics',
                    color: MediLoopColors.verified,
                    iconBg: MediLoopColors.verifiedBg,
                    iconColor: MediLoopColors.verified,
                    onTap: () => context.push('/return/new'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: MediLoopSpacing.xl),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Audit Activity', style: MediLoopText.h4),
                TextButton(
                  onPressed: () => context.go('/retailer/batches'),
                  child: const Text('View inventory →'),
                ),
              ],
            ),
            if (_recentBatches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No recent inventory activity.',
                    style: MediLoopText.caption,
                  ),
                ),
              )
            else
              ..._recentBatches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: _ActivityItem(
                    medicine: b.displayName,
                    batchNumber: b.batchNumber,
                    status: b.status,
                    expiryLabel: 'Exp ${DateFormat('dd MMM yyyy').format(b.expiryDate)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: MediLoopColors.surface,
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
          border: Border.all(color: MediLoopColors.line, width: 1),
          boxShadow: MediLoopShadows.card,
        ),
        child: InkWell(
          key: Key(widget.id),
          onHighlightChanged: (val) => setState(() => _isPressed = val),
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 24, color: widget.iconColor),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.label,
                  style: MediLoopText.plexSans(
                    size: 15,
                    weight: FontWeight.w700,
                    color: MediLoopColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: MediLoopText.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String medicine;
  final String batchNumber;
  final String status;
  final String expiryLabel;

  const _ActivityItem({
    required this.medicine,
    required this.batchNumber,
    required this.status,
    required this.expiryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MediLoopColors.surface,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(color: MediLoopColors.line, width: 1),
        boxShadow: MediLoopShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MediLoopColors.inactiveBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 20,
              color: MediLoopColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine,
                  style: MediLoopText.plexSans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: MediLoopColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        batchNumber,
                        style: MediLoopText.batchCode.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '•  $expiryLabel',
                        style: MediLoopText.caption.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: status, compact: true),
        ],
      ),
    );
  }
}

class RetailerBatchesPage extends StatefulWidget {
  final String initialFilter;
  const RetailerBatchesPage({super.key, this.initialFilter = 'ALL'});

  @override
  State<RetailerBatchesPage> createState() => _RetailerBatchesPageState();
}

class _RetailerBatchesPageState extends State<RetailerBatchesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MedicineBatch> _batches = [];
  bool _loading = true;
  late String _filter;
  String _sortOption = 'EXPIRY_ASC';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  @override
  void didUpdateWidget(RetailerBatchesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() => _filter = widget.initialFilter);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final repo = context.read<BatchRepository>();
    final orgId = auth.currentUser?.organizationId ?? '';
    final list = await repo.getBatchesForPharmacy(orgId);

    if (mounted) {
      setState(() {
        _batches = list;
        _loading = false;
      });
    }
  }

  List<MedicineBatch> get _filteredBatches {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<MedicineBatch> list = _batches.where((b) {
      if (q.isNotEmpty) {
        final matchesQuery = b.displayName.toLowerCase().contains(q) ||
            b.batchNumber.toLowerCase().contains(q) ||
            (b.genericName?.toLowerCase().contains(q) ?? false);
        if (!matchesQuery) return false;
      }

      switch (_filter) {
        case 'EXPIRING_SOON':
          return b.isExpiringSoon && !b.isExpired;
        case 'EXPIRED':
          return b.isExpired;
        case 'RETURN_INITIATED':
          return b.status == 'RETURN_INITIATED';
        case 'ACTIVE':
          return b.status == 'ACTIVE' && !b.isExpired;
        case 'DESTROYED':
          return b.status == 'DESTROYED';
        default:
          return true;
      }
    }).toList();

    switch (_sortOption) {
      case 'EXPIRY_ASC':
        list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      case 'NAME_ASC':
        list.sort((a, b) => a.displayName.compareTo(b.displayName));
      case 'QTY_DESC':
        list.sort((a, b) => b.currentQuantity.compareTo(a.currentQuantity));
    }
    return list;
  }

  int _countFor(String filter) {
    switch (filter) {
      case 'EXPIRING_SOON':
        return _batches.where((b) => b.isExpiringSoon && !b.isExpired).length;
      case 'EXPIRED':
        return _batches.where((b) => b.isExpired).length;
      case 'ACTIVE':
        return _batches.where((b) => b.status == 'ACTIVE' && !b.isExpired).length;
      case 'RETURN_INITIATED':
        return _batches.where((b) => b.status == 'RETURN_INITIATED').length;
      case 'DESTROYED':
        return _batches.where((b) => b.status == 'DESTROYED').length;
      default:
        return _batches.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBatches;

    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('My Pharmacy Batches'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Batches',
            initialValue: _sortOption,
            onSelected: (val) => setState(() => _sortOption = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'EXPIRY_ASC',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Soonest Expiry First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'NAME_ASC',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Medicine Name (A–Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'QTY_DESC',
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Quantity (High to Low)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MediLoopSpacing.md,
              MediLoopSpacing.sm,
              MediLoopSpacing.md,
              MediLoopSpacing.xs,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search medicine, batch number...',
                hintStyle: MediLoopText.caption,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MediLoopColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MediLoopColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MediLoopColors.ink),
                ),
              ),
            ),
          ),

          // Multi-status filter chips with counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: MediLoopSpacing.md,
              vertical: MediLoopSpacing.xs,
            ),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All', _countFor('ALL')),
                _buildFilterChip('EXPIRING_SOON', 'Expiring Soon', _countFor('EXPIRING_SOON')),
                _buildFilterChip('EXPIRED', 'Expired', _countFor('EXPIRED')),
                _buildFilterChip('ACTIVE', 'Active', _countFor('ACTIVE')),
                _buildFilterChip('RETURN_INITIATED', 'In Return', _countFor('RETURN_INITIATED')),
                _buildFilterChip('DESTROYED', 'Destroyed', _countFor('DESTROYED')),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? EmptyState(
                        what: _searchCtrl.text.isNotEmpty
                            ? 'No matches for "${_searchCtrl.text}".'
                            : 'No batches found.',
                        action: _searchCtrl.text.isNotEmpty
                            ? 'Try searching by a different name or batch number.'
                            : 'No batches match the selected category.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(MediLoopSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: MediLoopSpacing.sm),
                          itemBuilder: (_, i) {
                            final batch = filtered[i];
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/retailer/scan'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Stock'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class RetailerRequestsPage extends StatefulWidget {
  const RetailerRequestsPage({super.key});

  @override
  State<RetailerRequestsPage> createState() => _RetailerRequestsPageState();
}

class _RetailerRequestsPageState extends State<RetailerRequestsPage> {
  List<ReverseRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final repo = context.read<ReverseRepository>();
    final orgId = auth.currentUser?.organizationId ?? '';
    final list = await repo.getRequestsForPharmacy(orgId);

    if (mounted) {
      setState(() {
        _requests = list;
        _loading = false;
      });
    }
  }

  void _showProofInspectionDialog(
      BuildContext context, String proofUrl, String batchNumber) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MediLoopRadius.card)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: MediLoopSpacing.md, vertical: 12),
                color: const Color(0xFF1E3A8A),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Physical Packaging Proof — $batchNumber',
                        style: MediLoopText.inter(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: proofUrl.startsWith('http')
                            ? Image.network(
                                proofUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  color: MediLoopColors.inactiveBg,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 36,
                                      color: MediLoopColors.textMuted),
                                ),
                              )
                            : Image.file(
                                File(proofUrl),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  color: MediLoopColors.inactiveBg,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 36,
                                      color: MediLoopColors.textMuted),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(MediLoopSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.security_rounded,
                                    size: 15, color: Color(0xFF15803D)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tamper-Evident Packaging Proof Anchored',
                                    style: MediLoopText.inter(
                                        size: 12.5,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Physical photo captured at pharmacy counter. Encrypted and anchored into CDSCO compliant custody vault.',
                              style: MediLoopText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofThumbnail(String? proofUrl, String batchNumber) {
    if (proofUrl == null || proofUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () => _showProofInspectionDialog(context, proofUrl, batchNumber),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: proofUrl.startsWith('http')
                    ? Image.network(
                        proofUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MediLoopColors.inactiveBg,
                          child: const Icon(Icons.shield_outlined,
                              size: 20, color: MediLoopColors.textMuted),
                        ),
                      )
                    : Image.file(
                        File(proofUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MediLoopColors.inactiveBg,
                          child: const Icon(Icons.shield_outlined,
                              size: 20, color: MediLoopColors.textMuted),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 13, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Text(
                        'Photo Proof Attached',
                        style: MediLoopText.inter(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Anchored in Supabase Vault · Tap to inspect',
                    style: MediLoopText.caption.copyWith(
                        fontSize: 10,
                        color: MediLoopColors.accent,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MediLoopColors.textMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Return Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const EmptyState(
                  what: 'No return requests.',
                  action:
                      'Tap "New Return" to initiate reverse logistics for expired stock.',
                  icon: Icons.swap_horiz_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(MediLoopSpacing.md),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MediLoopSpacing.sm),
                    itemBuilder: (_, i) {
                      final req = _requests[i];
                      final batchCode = req.batchNumber ?? req.batchId;
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
                                      req.medicineName ?? 'Medicine Batch',
                                      style: MediLoopText.h4,
                                    ),
                                  ),
                                  StatusBadge(
                                    status: req.status == 'PENDING'
                                        ? 'RETURN_INITIATED'
                                        : req.status,
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                batchCode,
                                style: MediLoopText.batchCode,
                              ),
                              const SizedBox(height: MediLoopSpacing.sm),
                              const Divider(height: 1),
                              const SizedBox(height: MediLoopSpacing.sm),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Quantity: ${req.requestedQuantity} units',
                                    style: MediLoopText.body,
                                  ),
                                  Text(
                                    'Reason: ${req.reasonLabel}',
                                    style: MediLoopText.bodyMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Initiated ${DateFormat('dd MMM yyyy, HH:mm').format(req.initiatedAt)}',
                                style: MediLoopText.caption,
                              ),
                              _buildProofThumbnail(req.proofUrl, batchCode),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        context.push('/batch/${req.batchId}'),
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 13),
                                    label: const Text('View Audit Trail'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      textStyle: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/return/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Return'),
      ),
    );
  }
}

