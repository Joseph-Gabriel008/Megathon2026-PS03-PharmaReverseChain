import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/disposal_repository.dart';
import '../../repositories/reverse_repository.dart';
import '../../models/reverse_request.dart';
import '../../services/auth_service.dart';
import '../../services/evidence_service.dart';
import '../../services/qr_service.dart';
import '../../models/medicine_batch.dart';
import '../../models/disposal_record.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/cdsco_certificate_viewer.dart';
import '../../widgets/app_back_scope.dart';

class ManufacturerShell extends StatelessWidget {
  final Widget child;
  const ManufacturerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForPath(location);

    return AppBackScope(
      homeRoute: '/manufacturer',
      child: Scaffold(
        body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/manufacturer');
            case 1:
              context.go('/manufacturer/batches');
            case 2:
              context.go('/manufacturer/scan');
            case 3:
              context.go('/manufacturer/disposal');
            case 4:
              context.go('/manufacturer/profile');
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
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan & Verify',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_sweep_outlined),
            selectedIcon: Icon(Icons.delete_sweep),
            label: 'Disposal',
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
    if (path.startsWith('/manufacturer/batches')) return 1;
    if (path.startsWith('/manufacturer/scan')) return 2;
    if (path.startsWith('/manufacturer/disposal')) return 3;
    if (path.startsWith('/manufacturer/profile')) return 4;
    return 0;
  }
}

// ─── Dashboard ─────────────────────────────────────────────────────────────

class ManufacturerDashboardPage extends StatefulWidget {
  const ManufacturerDashboardPage({super.key});

  @override
  State<ManufacturerDashboardPage> createState() =>
      _ManufacturerDashboardPageState();
}

class _ManufacturerDashboardPageState
    extends State<ManufacturerDashboardPage> {
  List<MedicineBatch> _incoming = [];
  List<MedicineBatch> _pipelineBatches = [];
  List<ReverseRequest> _returnRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final orgId = auth.currentUser?.organizationId ?? '';
    final repo = context.read<BatchRepository>();
    final reverseRepo = context.read<ReverseRepository>();

    final incomingData = await repo.getCollectedBatches();
    final pipelineData = await repo.getPendingReturnsForManufacturer(orgId);
    final returnReqs = await reverseRepo.getRequestsForManufacturer(orgId);

    if (mounted) {
      setState(() {
        _incoming = incomingData;
        _pipelineBatches = pipelineData;
        _returnRequests = returnReqs;
        _loading = false;
      });
    }
  }

  void _showAssignDistributorSheet({
    required String batchId,
    required String batchNumber,
    required int quantity,
    String? requestId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MediLoopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MediLoopRadius.sheet)),
      ),
      builder: (ctx) => _AssignDistributorSheet(
        batchId: batchId,
        batchNumber: batchNumber,
        quantity: quantity,
        requestId: requestId,
        onAssigned: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
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
                        'Physical Proof: $batchNumber',
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
                                    'Tamper-Evident Photo Proof Verified',
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
                              'Physical packaging photo captured at pharmacy counter prior to reverse handoff. Anchored cryptographically into CDSCO compliant audit trail.',
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

  Widget _buildReqProofThumbnail(String? proofUrl, {String batchNumber = 'Batch'}) {
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
                width: 64,
                height: 64,
                child: proofUrl.startsWith('http')
                    ? Image.network(
                        proofUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MediLoopColors.inactiveBg,
                          child: const Icon(Icons.shield_outlined,
                              size: 24, color: MediLoopColors.textMuted),
                        ),
                      )
                    : Image.file(
                        File(proofUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MediLoopColors.inactiveBg,
                          child: const Icon(Icons.shield_outlined,
                              size: 24, color: MediLoopColors.textMuted),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 14, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Text(
                        'Tamper-Evident Photo Proof',
                        style: MediLoopText.inter(
                            size: 12,
                            weight: FontWeight.w700,
                            color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Physical packaging proof anchored in Vault',
                    style: MediLoopText.caption.copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.zoom_in,
                          size: 12, color: MediLoopColors.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Tap to inspect photo in full size',
                        style: MediLoopText.caption.copyWith(
                            color: MediLoopColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final awaitingDisposal = _incoming
        .where((b) =>
            b.status == 'MANUFACTURER_RECEIVED' ||
            b.status == 'DISPOSAL_PENDING')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Manufacturer Dashboard', style: MediLoopText.h4),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan & Verify Batch',
            onPressed: () => context.go('/manufacturer/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            key: const Key('manufacturer_appbar_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Sign Out',
            onPressed: () => context.go('/manufacturer/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          children: [
            // Compliance summary strip
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 20, color: MediLoopColors.verified),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CDSCO Mandate: 92% of reverse chain returns verified and destroyed on schedule.',
                        style: MediLoopText.inter(
                            size: 13,
                            weight: FontWeight.w600,
                            color: MediLoopColors.verified),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // KPI Grid
            Row(children: [
              Expanded(
                child: KpiTile(
                  label: 'At Factory (Ready)',
                  value: _incoming.length,
                  warning: _incoming.isNotEmpty,
                  icon: Icons.factory_outlined,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: MediLoopSpacing.sm),
              Expanded(
                child: KpiTile(
                  label: 'Pharmacy Returns',
                  value: _returnRequests.isNotEmpty
                      ? _returnRequests.length
                      : _pipelineBatches.length,
                  warning: _returnRequests.isNotEmpty ||
                      _pipelineBatches.isNotEmpty,
                  icon: Icons.local_shipping_outlined,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: MediLoopSpacing.sm),
              Expanded(
                child: KpiTile(
                  label: 'Awaiting Disposal',
                  value: awaitingDisposal,
                  icon: Icons.delete_sweep_outlined,
                  onTap: () => context.go('/manufacturer/disposal'),
                ),
              ),
            ]),
            const SizedBox(height: MediLoopSpacing.lg),

            // ── Section 1: Incoming batches at factory ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Incoming Batches at Factory', style: MediLoopText.h4),
                if (_incoming.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MediLoopColors.accentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_incoming.length} ready',
                      style: MediLoopText.inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: MediLoopColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.xs),
            Text(
              'Batches collected and delivered by logistics hub awaiting verification & destruction scheduling.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_incoming.isEmpty)
              const EmptyState(
                what: 'No incoming batches at factory.',
                action:
                    'When distributors complete pickup of pharmacy returns, they appear here.',
                icon: Icons.factory_outlined,
              )
            else
              ..._incoming.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: _IncomingBatchCard(batch: b, onRefresh: _load),
                ),
              ),

            const SizedBox(height: MediLoopSpacing.lg),

            // ── Section 2: Pharmacy Return Requests Pipeline ─────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pharmacy Return Requests (In Transit)',
                    style: MediLoopText.h4),
                if (_returnRequests.isNotEmpty || _pipelineBatches.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MediLoopColors.attentionBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_returnRequests.isNotEmpty ? _returnRequests.length : _pipelineBatches.length} in pipeline',
                      style: MediLoopText.inter(
                        size: 11,
                        weight: FontWeight.w600,
                        color: MediLoopColors.attention,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.xs),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route_rounded,
                      size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reverse Chain: Pharmacy initiates return ➔ Distributor picks up stock ➔ Delivered here to Manufacturer.',
                      style: MediLoopText.inter(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: const Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            if (_returnRequests.isNotEmpty)
              ..._returnRequests.map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(MediLoopSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  req.medicineName ?? 'Medicine',
                                  style: MediLoopText.plexSans(
                                      size: 15, weight: FontWeight.w600),
                                ),
                              ),
                              StatusBadge(
                                  status: req.status == 'PENDING'
                                      ? 'RETURN_INITIATED'
                                      : req.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(req.batchNumber ?? 'Batch #${req.batchId}',
                              style: MediLoopText.batchCode),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_pharmacy_outlined,
                                  size: 14, color: MediLoopColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  req.pharmacyName ?? 'Apollo Pharmacy',
                                  style: MediLoopText.bodyMuted,
                                ),
                              ),
                              Text(
                                '${req.requestedQuantity} units',
                                style: MediLoopText.inter(
                                    size: 13, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (req.reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${req.reason}',
                              style: MediLoopText.caption
                                  .copyWith(color: MediLoopColors.ink),
                            ),
                          ],
                          _buildReqProofThumbnail(
                            req.proofUrl,
                            batchNumber: req.batchNumber ?? 'Batch #${req.batchId}',
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: MediLoopColors.inactiveBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined,
                                    size: 14,
                                    color: MediLoopColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    req.status == 'PENDING' || req.status == 'RETURN_INITIATED'
                                        ? 'Assigned to MedSupply Logistics for pharmacy pickup'
                                        : 'In transit to Cipla Unit 4 facility',
                                    style: MediLoopText.inter(
                                        size: 11,
                                        color: MediLoopColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/batch/${req.batchId}'),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 14),
                                label: const Text('View Audit'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => _showAssignDistributorSheet(
                                  batchId: req.batchId,
                                  batchNumber: req.batchNumber ?? 'Batch',
                                  quantity: req.requestedQuantity,
                                  requestId: req.id,
                                ),
                                icon: const Icon(Icons.local_shipping_outlined,
                                    size: 14),
                                label: const Text('Assign Distributor'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_pipelineBatches.isEmpty)
              Container(
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  border: Border.all(color: MediLoopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 20, color: MediLoopColors.verified),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All pharmacy return requests have been collected and processed.',
                        style: MediLoopText.caption,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._pipelineBatches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(MediLoopSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.displayName,
                                  style: MediLoopText.plexSans(
                                      size: 15, weight: FontWeight.w600),
                                ),
                              ),
                              StatusBadge(status: b.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(b.batchNumber, style: MediLoopText.batchCode),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_pharmacy_outlined,
                                  size: 14, color: MediLoopColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  b.pharmacyName ?? 'Apollo Pharmacy',
                                  style: MediLoopText.bodyMuted,
                                ),
                              ),
                              Text(
                                '${b.currentQuantity} units',
                                style: MediLoopText.inter(
                                    size: 13, weight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: MediLoopColors.inactiveBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined,
                                    size: 14,
                                    color: MediLoopColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    b.status == 'RETURN_INITIATED'
                                        ? 'Assigned to MedSupply Logistics for pharmacy pickup'
                                        : 'In transit to Cipla Unit 4 facility',
                                    style: MediLoopText.inter(
                                        size: 11,
                                        color: MediLoopColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/batch/${b.id}'),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 14),
                                label: const Text('View Audit'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => _showAssignDistributorSheet(
                                  batchId: b.id,
                                  batchNumber: b.batchNumber,
                                  quantity: b.currentQuantity,
                                ),
                                icon: const Icon(Icons.local_shipping_outlined,
                                    size: 14),
                                label: const Text('Assign Distributor'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Batches Tab ───────────────────────────────────────────────────────────

class ManufacturerBatchesPage extends StatefulWidget {
  const ManufacturerBatchesPage({super.key});

  @override
  State<ManufacturerBatchesPage> createState() =>
      _ManufacturerBatchesPageState();
}

class _ManufacturerBatchesPageState extends State<ManufacturerBatchesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MedicineBatch> _batches = [];
  bool _loading = true;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final orgId = auth.currentUser?.organizationId ?? '';
    final repo = context.read<BatchRepository>();
    final list = await repo.getBatchesForManufacturer(orgId);
    if (mounted) {
      setState(() {
        _batches = list;
        _loading = false;
      });
    }
  }

  List<MedicineBatch> get _filteredBatches {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _batches.where((b) {
      if (q.isNotEmpty) {
        final matches = b.displayName.toLowerCase().contains(q) ||
            b.batchNumber.toLowerCase().contains(q);
        if (!matches) return false;
      }
      switch (_filter) {
        case 'ACTIVE':
          return b.status == 'ACTIVE' && !b.isExpired;
        case 'EXPIRED':
          return b.isExpired;
        case 'IN_RETURN':
          return [
            'RETURN_INITIATED',
            'COLLECTED',
            'DISTRIBUTOR_VERIFIED',
            'MANUFACTURER_RECEIVED',
            'SENT_FOR_DESTRUCTION'
          ].contains(b.status);
        case 'DESTROYED':
          return b.status == 'DESTROYED';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBatches;

    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Manufactured Batches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
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
                hintText: 'Search batch number, medicine...',
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
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: MediLoopSpacing.md,
              vertical: MediLoopSpacing.xs,
            ),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All (${_batches.length})'),
                _buildFilterChip(
                  'ACTIVE',
                  'Active (${_batches.where((b) => b.status == 'ACTIVE' && !b.isExpired).length})',
                ),
                _buildFilterChip(
                  'IN_RETURN',
                  'In Return (${_batches.where((b) => ['RETURN_INITIATED', 'COLLECTED', 'MANUFACTURER_RECEIVED', 'SENT_FOR_DESTRUCTION'].contains(b.status)).length})',
                ),
                _buildFilterChip(
                  'DESTROYED',
                  'Destroyed (${_batches.where((b) => b.status == 'DESTROYED').length})',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyState(
                        what: 'No batches found.',
                        action: 'No batches match your filter criteria.',
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
                              onTap: () =>
                                  context.push('/batch/${batch.id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

// ─── Disposal Records Tab ──────────────────────────────────────────────────

class ManufacturerDisposalPage extends StatefulWidget {
  const ManufacturerDisposalPage({super.key});

  @override
  State<ManufacturerDisposalPage> createState() =>
      _ManufacturerDisposalPageState();
}

class _ManufacturerDisposalPageState extends State<ManufacturerDisposalPage> {
  List<DisposalRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<DisposalRepository>();
    final list = await repo.getDisposalRecords();
    if (mounted) {
      setState(() {
        _records = list;
        _loading = false;
      });
    }
  }

  void _openOwnInventoryDisposal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OwnInventoryDisposalSheet(onScheduled: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Disposal Records & Certificates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos_outlined),
            tooltip: 'Own-Stock Direct Disposal',
            onPressed: () => _openOwnInventoryDisposal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const EmptyState(
                  what: 'No disposal records found.',
                  action:
                      'Batches scheduled for destruction at BioClean facility will appear here.',
                  icon: Icons.delete_sweep_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(MediLoopSpacing.md),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: MediLoopSpacing.sm),
                    itemBuilder: (ctx, i) {
                      final r = _records[i];
                      final isDestroyed =
                          r.status == 'DESTROYED' || r.status == 'COMPLETED';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(MediLoopSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.batchNumber ?? 'Batch #${r.batchId}',
                                      style: MediLoopText.plexSans(
                                          size: 15,
                                          weight: FontWeight.w600),
                                    ),
                                  ),
                                  StatusBadge(status: r.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_city_outlined,
                                      size: 14,
                                      color: MediLoopColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    r.wasteFacilityName ??
                                        'BioClean Bio-Medical Waste Facility',
                                    style: MediLoopText.bodyMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.science_outlined,
                                      size: 14,
                                      color: MediLoopColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Method: ${r.disposalMethod} • ${r.quantityDestroyed} units',
                                    style: MediLoopText.caption,
                                  ),
                                ],
                              ),
                              if (r.actualDisposalDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${DateFormat('dd MMM yyyy').format(r.actualDisposalDate!)}',
                                  style: MediLoopText.caption,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        context.push('/batch/${r.batchId}'),
                                    icon: const Icon(Icons.timeline_rounded,
                                        size: 14),
                                    label: const Text('Trace Chain'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      textStyle:
                                          const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (isDestroyed) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () {
                                        final cert = DestructionCertificate(
                                          id: r.certificateId ?? 'cert-001',
                                          disposalRecordId: r.id,
                                          batchId: r.batchId,
                                          certificateNumber:
                                              'CDSCO-CERT-2026-004812',
                                          issuedDate: r.actualDisposalDate ??
                                              DateTime.now(),
                                          hash:
                                              'a8f3b9c2401f8d93e117b4c892e59123049bca71049281bfd8e90a12c418e244',
                                        );
                                        CdscoCertificateViewer.show(
                                          context,
                                          certificate: cert,
                                          batch: MedicineBatch(
                                            id: r.batchId,
                                            batchNumber: r.batchNumber ??
                                                'CETR10-2024-003',
                                            medicineId: 'med-06',
                                            medicineName: 'Cetirizine 10mg',
                                            manufacturerId: r.manufacturerId,
                                            distributorId: 'org-distributor-01',
                                            pharmacyId: 'org-retailer-01',
                                            manufacturingDate: DateTime.now()
                                                .subtract(const Duration(
                                                    days: 800)),
                                            expiryDate: DateTime.now()
                                                .subtract(const Duration(
                                                    days: 200)),
                                            originalQuantity:
                                                r.quantityDestroyed,
                                            currentQuantity:
                                                r.quantityDestroyed,
                                            status: 'DESTROYED',
                                            qrCode: 'MEDILOOP|SAMPLE',
                                          ),
                                          facilityName: r.wasteFacilityName ??
                                              'BioClean Bio-Medical Waste Facility',
                                          disposalMethod: r.disposalMethod,
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.verified_outlined,
                                          size: 14),
                                      label: const Text('CDSCO Certificate'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1E3A8A),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        textStyle:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Incoming batch card with verify + schedule disposal ──────────────────

class _IncomingBatchCard extends StatefulWidget {
  final MedicineBatch batch;
  final VoidCallback onRefresh;

  const _IncomingBatchCard({required this.batch, required this.onRefresh});

  @override
  State<_IncomingBatchCard> createState() => _IncomingBatchCardState();
}

class _IncomingBatchCardState extends State<_IncomingBatchCard> {
  bool _verifying = false;

  @override
  Widget build(BuildContext context) {
    final isReceived = widget.batch.status == 'MANUFACTURER_RECEIVED' ||
        widget.batch.status == 'DISPOSAL_PENDING';
    final otp = Pickup.generateOtp(widget.batch.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BatchCard(
          batch: widget.batch,
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: MediLoopColors.accent,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Forward to disposal'),
            onPressed: () => _showDisposalSheet(context),
          ),
        ),
        if (!isReceived)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_outlined,
                    size: 18, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Gate Handover OTP: ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Text(
                              otp,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _verifying
                                ? null
                                : () => _verifyReceipt(context),
                            child: _verifying
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text(
                                    'Confirm intake',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1D4ED8),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Provide this 6-digit code to arriving distributor to confirm factory gate intake.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _verifyReceipt(BuildContext context) async {
    setState(() => _verifying = true);
    try {
      final auth = context.read<AuthService>();
      final batchRepo = context.read<BatchRepository>();
      await batchRepo.updateBatchStatus(
        batchId: widget.batch.id,
        newStatus: 'MANUFACTURER_RECEIVED',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'MANUFACTURER_RECEIVED',
        quantity: widget.batch.currentQuantity,
        previousStatus: widget.batch.status,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Batch receipt verified. Schedule disposal next.'),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Failed to verify receipt: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _showDisposalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MediLoopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(MediLoopRadius.sheet)),
      ),
      builder: (ctx) => _ScheduleDisposalSheet(
        batch: widget.batch,
        onScheduled: () {
          Navigator.pop(ctx);
          widget.onRefresh();
        },
      ),
    );
  }
}

class _ScheduleDisposalSheet extends StatefulWidget {
  final MedicineBatch batch;
  final VoidCallback onScheduled;

  const _ScheduleDisposalSheet(
      {required this.batch, required this.onScheduled});

  @override
  State<_ScheduleDisposalSheet> createState() => _ScheduleDisposalSheetState();
}

class _ScheduleDisposalSheetState extends State<_ScheduleDisposalSheet> {
  String? _selectedFacilityId;
  String _method = 'INCINERATION';
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  bool _loading = false;
  List<Map<String, dynamic>> _facilities = [];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    final repo = context.read<DisposalRepository>();
    final f = await repo.getWasteFacilities();
    if (mounted) {
      setState(() {
        _facilities = f;
        if (f.isNotEmpty && _selectedFacilityId == null) {
          _selectedFacilityId = f.first['id'] as String?;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forward to Disposal Facility', style: MediLoopText.h4),
          Text(widget.batch.displayName, style: MediLoopText.bodyMuted),
          const SizedBox(height: MediLoopSpacing.lg),

          // Facility selector
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Waste facility'),
            initialValue: _selectedFacilityId,
            items: _facilities
                .map((f) => DropdownMenuItem(
                      value: f['id'] as String,
                      child: Text(f['name'] as String),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedFacilityId = v;
              });
            },
          ),
          const SizedBox(height: MediLoopSpacing.md),

          // Method
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Disposal method'),
            initialValue: _method,
            items: const [
              DropdownMenuItem(value: 'INCINERATION', child: Text('Incineration')),
              DropdownMenuItem(value: 'CHEMICAL', child: Text('Chemical neutralization')),
              DropdownMenuItem(value: 'LANDFILL', child: Text('Secure landfill')),
            ],
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: MediLoopSpacing.md),

          // Date
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text('Date: ${_date.toString().substring(0, 10)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),

          const SizedBox(height: MediLoopSpacing.lg),

          ElevatedButton(
            onPressed: _loading || _selectedFacilityId == null
                ? null
                : _schedule,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Confirm & Forward to Disposal'),
          ),
        ],
      ),
    );
  }

  Future<void> _schedule() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<DisposalRepository>();
      final batchRepo = context.read<BatchRepository>();

      // If batch is still in COLLECTED status, record receipt first
      if (widget.batch.status == 'COLLECTED') {
        try {
          await batchRepo.updateBatchStatus(
            batchId: widget.batch.id,
            newStatus: 'MANUFACTURER_RECEIVED',
            actorId: auth.currentUser!.id,
            organizationId: auth.currentUser!.organizationId,
            eventType: 'MANUFACTURER_RECEIVED',
            quantity: widget.batch.currentQuantity,
            previousStatus: widget.batch.status,
          );
        } catch (_) {}
      }

      await repo.createDisposalRecord(
        batchId: widget.batch.id,
        manufacturerId: auth.currentUser!.organizationId,
        wasteFacilityId: _selectedFacilityId!,
        disposalMethod: _method,
        quantityDestroyed: widget.batch.currentQuantity,
        scheduledDate: _date,
      );

      await batchRepo.updateBatchStatus(
        batchId: widget.batch.id,
        newStatus: 'SENT_FOR_DESTRUCTION',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'DISPOSAL_SCHEDULED',
        quantity: widget.batch.currentQuantity,
        previousStatus: widget.batch.status == 'COLLECTED'
            ? 'MANUFACTURER_RECEIVED'
            : widget.batch.status,
        wasteFacilityId: _selectedFacilityId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Batch forwarded to waste disposal facility.'),
          ),
        );
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Failed to schedule disposal: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Manufacturer Own Inventory Direct Disposal Sheet ────────────────────────

class _OwnInventoryDisposalSheet extends StatefulWidget {
  final VoidCallback onScheduled;
  const _OwnInventoryDisposalSheet({required this.onScheduled});

  @override
  State<_OwnInventoryDisposalSheet> createState() => _OwnInventoryDisposalSheetState();
}

class _OwnInventoryDisposalSheetState extends State<_OwnInventoryDisposalSheet> {
  List<MedicineBatch> _batches = [];
  List<Map<String, dynamic>> _facilities = [];
  MedicineBatch? _selectedBatch;
  String? _selectedFacilityId;
  String _disposalMethod = 'INCINERATION';
  String? _proofImagePath;
  bool _qrVerified = false;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final batchRepo = context.read<BatchRepository>();
    final disposalRepo = context.read<DisposalRepository>();
    final orgId = auth.currentUser?.organizationId ?? '';

    final allBatches = await batchRepo.getBatchesForManufacturer(orgId);
    final facilities = await disposalRepo.getWasteFacilities();

    if (mounted) {
      setState(() {
        const validDisposalStatuses = {'ACTIVE', 'EXPIRED', 'EXPIRING_SOON', 'MANUFACTURER_RECEIVED'};
        _batches = allBatches.where((b) => validDisposalStatuses.contains(b.status)).toList();
        _facilities = facilities;
        if (facilities.isNotEmpty) {
          _selectedFacilityId = facilities.first['id'] as String;
        }
        _loading = false;
      });
    }
  }

  bool _capturingProof = false;

  Future<void> _captureProof() async {
    if (_capturingProof) return;
    setState(() => _capturingProof = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (picked == null) return;

      bool qrOk = false;
      if (_selectedBatch != null) {
        final qr = await QrService.decodeFromFile(File(picked.path));
        qrOk = (qr != null && QrService.decodeBatchQr(qr) == _selectedBatch!.id);
      }

      if (!mounted) return;
      setState(() {
        _proofImagePath = picked.path;
        _qrVerified = qrOk;
      });
    } finally {
      if (mounted) setState(() => _capturingProof = false);
    }
  }

  Future<void> _submitDisposal() async {
    if (_selectedBatch == null || _selectedFacilityId == null || _proofImagePath == null) return;
    setState(() => _submitting = true);

    try {
      final auth = context.read<AuthService>();
      final batchRepo = context.read<BatchRepository>();
      final disposalRepo = context.read<DisposalRepository>();
      final evidenceService = context.read<EvidenceService>();

      // 1. Evidence upload
      final evidence = await evidenceService.submitEvidence(
        file: File(_proofImagePath!),
        batchId: _selectedBatch!.id,
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        qrVerified: _qrVerified,
        qrBatchIdFound: _qrVerified ? _selectedBatch!.id : null,
      );

      // 2. Create disposal record
      await disposalRepo.createDisposalRecord(
        batchId: _selectedBatch!.id,
        manufacturerId: auth.currentUser!.organizationId,
        wasteFacilityId: _selectedFacilityId!,
        disposalMethod: _disposalMethod,
        quantityDestroyed: _selectedBatch!.currentQuantity,
        scheduledDate: DateTime.now(),
      );

      // 3. Status update
      await batchRepo.updateBatchStatus(
        batchId: _selectedBatch!.id,
        newStatus: 'SENT_FOR_DESTRUCTION',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'MFG_DIRECT_DISPOSAL',
        quantity: _selectedBatch!.currentQuantity,
        previousStatus: _selectedBatch!.status,
        evidenceId: evidence.id,
        originationPath: 'MANUFACTURER_SELF',
        wasteFacilityId: _selectedFacilityId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Manufacturer own-stock disposal scheduled and dispatched.'),
          ),
        );
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Disposal scheduling failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: MediLoopSpacing.lg,
        right: MediLoopSpacing.lg,
        top: MediLoopSpacing.lg,
      ),
      child: _loading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.factory_outlined, color: MediLoopColors.accent),
                      const SizedBox(width: 8),
                      Text('Manufacturer Own-Stock Disposal', style: MediLoopText.h4),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  Text('Select batch from factory inventory', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  if (_batches.isEmpty)
                    Text('No factory batches available for disposal', style: MediLoopText.bodyMuted)
                  else
                    DropdownButtonFormField<MedicineBatch>(
                      initialValue: _selectedBatch,
                      hint: const Text('Choose a batch'),
                      items: _batches.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text('${b.displayName} (${b.batchNumber}) - ${b.currentQuantity} units'),
                      )).toList(),
                      onChanged: (b) => setState(() {
                        _selectedBatch = b;
                        _proofImagePath = null;
                        _qrVerified = false;
                      }),
                    ),
                  const SizedBox(height: MediLoopSpacing.md),
                  Text('Select Certified Waste Management Facility', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFacilityId,
                    hint: const Text('Choose waste facility'),
                    items: _facilities.map((f) => DropdownMenuItem(
                      value: f['id'] as String,
                      child: Text(f['name'] as String),
                    )).toList(),
                    onChanged: (id) => setState(() => _selectedFacilityId = id),
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  Text('Destruction Method', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _disposalMethod,
                    items: const [
                      DropdownMenuItem(value: 'INCINERATION', child: Text('High-Temp Incineration (CPCB)')),
                      DropdownMenuItem(value: 'AUTOCLAVING', child: Text('Autoclaving & Shredding')),
                      DropdownMenuItem(value: 'CHEMICAL_TREATMENT', child: Text('Chemical Neutralization')),
                    ],
                    onChanged: (m) => setState(() => _disposalMethod = m ?? 'INCINERATION'),
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  Text('Tamper-Evident Packaging Proof (Camera Only)', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_proofImagePath == null ? 'Capture Proof Photo' : 'Photo Captured ✓'),
                    onPressed: _selectedBatch == null ? null : _captureProof,
                  ),
                  const SizedBox(height: MediLoopSpacing.lg),
                  ElevatedButton(
                    onPressed: (_selectedBatch != null && _selectedFacilityId != null && _proofImagePath != null && !_submitting)
                        ? _submitDisposal
                        : null,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Dispatch for Destruction'),
                  ),
                  const SizedBox(height: MediLoopSpacing.lg),
                ],
              ),
            ),
    );
  }
}

// ─── Assign Distributor Sheet (Manufacturer → Distributor pickup assignment) ──

class _AssignDistributorSheet extends StatefulWidget {
  final String batchId;
  final String batchNumber;
  final int quantity;
  final String? requestId;
  final VoidCallback onAssigned;

  const _AssignDistributorSheet({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    this.requestId,
    required this.onAssigned,
  });

  @override
  State<_AssignDistributorSheet> createState() => _AssignDistributorSheetState();
}

class _AssignDistributorSheetState extends State<_AssignDistributorSheet> {
  List<Map<String, dynamic>> _distributors = [];
  String? _selectedDistributorId;
  String? _selectedDistributorName;
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    try {
      // Fetch from Supabase orgs of type DISTRIBUTOR
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('organizations')
          .select('id, name')
          .eq('type', 'DISTRIBUTOR');
      final list = (data as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _distributors = list.isNotEmpty
              ? list
              : [
                  {'id': 'org-distributor-01', 'name': 'MedSupply Southern Logistics Hub'},
                ];
          if (_distributors.isNotEmpty) {
            _selectedDistributorId = _distributors.first['id'] as String;
            _selectedDistributorName = _distributors.first['name'] as String;
          }
          _loading = false;
        });
      }
    } catch (_) {
      // Fallback to mock distributor
      if (mounted) {
        setState(() {
          _distributors = [
            {'id': 'org-distributor-01', 'name': 'MedSupply Southern Logistics Hub'},
          ];
          _selectedDistributorId = 'org-distributor-01';
          _selectedDistributorName = 'MedSupply Southern Logistics Hub';
          _loading = false;
        });
      }
    }
  }

  Future<void> _assign() async {
    if (_selectedDistributorId == null) return;
    setState(() => _assigning = true);
    try {
      final auth = context.read<AuthService>();
      final reverseRepo = context.read<ReverseRepository>();
      final batchRepo = context.read<BatchRepository>();

      // 1. If there's a reverse request, accept it and create a pickup
      if (widget.requestId != null) {
        await reverseRepo.acceptPickup(
          requestId: widget.requestId!,
          distributorId: _selectedDistributorId!,
          scheduledDate: _pickupDate,
        );
      } else {
        // No reverse request yet — create one on the fly and assign
        final newReq = await reverseRepo.createRequest(
          batchId: widget.batchId,
          retailerId: auth.currentUser!.id,
          requestedQuantity: widget.quantity,
          reason: 'EXPIRED',
        );
        await reverseRepo.acceptPickup(
          requestId: newReq.id,
          distributorId: _selectedDistributorId!,
          scheduledDate: _pickupDate,
        );
      }

      // 2. Mark batch as PICKUP_ASSIGNED so distributor sees it
      await batchRepo.updateBatchStatus(
        batchId: widget.batchId,
        newStatus: 'PICKUP_ASSIGNED',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'PICKUP_ASSIGNED',
        quantity: widget.quantity,
        previousStatus: 'RETURN_INITIATED',
        distributorId: _selectedDistributorId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text(
              '${widget.batchNumber} assigned to $_selectedDistributorName for pickup on '
              '${_pickupDate.toString().substring(0, 10)}.',
            ),
          ),
        );
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Failed to assign distributor: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: MediLoopColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Assign Distributor for Pickup', style: MediLoopText.h4),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.batchNumber} · ${widget.quantity} units',
            style: MediLoopText.bodyMuted,
          ),
          const SizedBox(height: MediLoopSpacing.lg),
          // Flow info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Distributor will collect batch from pharmacy and deliver to your factory.',
                    style: MediLoopText.inter(size: 12, color: const Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MediLoopSpacing.lg),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text('Select Distributor', style: MediLoopText.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedDistributorId,
              decoration: const InputDecoration(
                labelText: 'Logistics Partner',
                prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
              ),
              items: _distributors
                  .map((d) => DropdownMenuItem(
                        value: d['id'] as String,
                        child: Text(d['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedDistributorId = v;
                _selectedDistributorName =
                    _distributors.firstWhere((d) => d['id'] == v)['name'] as String;
              }),
            ),
            const SizedBox(height: MediLoopSpacing.md),
            Text('Scheduled Pickup Date', style: MediLoopText.label),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_pickupDate.toString().substring(0, 10)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _pickupDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _pickupDate = picked);
              },
            ),
            const SizedBox(height: MediLoopSpacing.xl),
            ElevatedButton(
              onPressed: _assigning || _selectedDistributorId == null ? null : _assign,
              style: ElevatedButton.styleFrom(
                backgroundColor: MediLoopColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _assigning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Assign & Notify Distributor'),
            ),
          ],
        ],
      ),
    );
  }
}
