import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../repositories/reverse_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/confirmation_repository.dart';
import '../../repositories/disposal_repository.dart';
import '../../repositories/organization_repository.dart';
import '../../services/auth_service.dart';
import '../../services/evidence_service.dart';
import '../../services/qr_service.dart';
import '../../models/reverse_request.dart';
import '../../models/medicine_batch.dart';
import '../../models/organization.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/app_back_scope.dart';

class DistributorShell extends StatelessWidget {
  final Widget child;
  const DistributorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForPath(location);

    return AppBackScope(
      homeRoute: '/distributor',
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: context.go('/distributor');
              case 1: context.go('/distributor/pickups');
              case 2: context.go('/distributor/scan');
              case 3: context.go('/distributor/profile');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Pickups',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
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
    if (path.startsWith('/distributor/pickups')) return 1;
    if (path.startsWith('/distributor/scan')) return 2;
    if (path.startsWith('/distributor/profile')) return 3;
    return 0;
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class DistributorDashboardPage extends StatefulWidget {
  const DistributorDashboardPage({super.key});

  @override
  State<DistributorDashboardPage> createState() =>
      _DistributorDashboardPageState();
}

class _DistributorDashboardPageState
    extends State<DistributorDashboardPage> {
  List<Pickup> _pickups = [];
  List<Map<String, dynamic>> _pendingConfirmations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final repo = context.read<ReverseRepository>();
    ConfirmationRepository? confRepo;
    try {
      confRepo = context.read<ConfirmationRepository>();
    } catch (_) {}

    final orgId = auth.currentUser?.organizationId ?? '';
    final data = await repo.getPickupsForDistributor(orgId);
    List<Map<String, dynamic>> confs = [];
    if (confRepo != null) {
      try {
        confs = await confRepo.getPendingForReceiver(orgId);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _pickups = data;
        _pendingConfirmations = confs;
        _loading = false;
      });
    }
  }

  void _openWarehouseDisposal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WarehouseDisposalSheet(onScheduled: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePickups =
        _pickups.where((p) => p.effectiveStage != 'COMPLETED').toList();
    final completedPickups =
        _pickups.where((p) => p.effectiveStage == 'COMPLETED').toList();
    final pending = activePickups.length;
    final completed = completedPickups.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Distributor Dashboard', style: MediLoopText.h4),
          Text('Pickup queue & intake attestation', style: MediLoopText.caption),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Scan Batch Barcode',
            onPressed: () => context.go('/distributor/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Warehouse Direct Disposal',
            onPressed: () => _openWarehouseDisposal(context),
          ),
          IconButton(
            key: const Key('distributor_appbar_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Sign Out',
            onPressed: () => context.go('/distributor/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          children: [
            Row(children: [
              Expanded(
                  child: KpiTile(
                      label: 'Pending pickups',
                      value: pending,
                      warning: pending > 0,
                      icon: Icons.local_shipping_outlined)),
              const SizedBox(width: MediLoopSpacing.sm),
              Expanded(
                  child: KpiTile(
                      label: 'Delivered to Mfg',
                      value: completed,
                      icon: Icons.verified_rounded)),
            ]),
            const SizedBox(height: MediLoopSpacing.lg),

            // Pending Confirmations Section (Bilateral Attestation)
            if (_pendingConfirmations.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 20, color: MediLoopColors.accent),
                  const SizedBox(width: 8),
                  Text('Awaiting Intake Confirmation', style: MediLoopText.h4),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MediLoopColors.attentionBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingConfirmations.length} Pending',
                      style: MediLoopText.caption.copyWith(
                        color: MediLoopColors.attention,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MediLoopSpacing.sm),
              ..._pendingConfirmations.map((conf) => Padding(
                    padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                    child: _PendingConfirmationCard(
                      confirmation: conf,
                      onConfirmed: _load,
                    ),
                  )),
              const SizedBox(height: MediLoopSpacing.lg),
            ],

            Text('Active Pickup & Transit Tasks', style: MediLoopText.h4),
            const SizedBox(height: 2),
            Text(
              'Accept tasks, verify physical goods at pharmacy counter, and complete handover at manufacturer dock.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (activePickups.isEmpty && _pendingConfirmations.isEmpty)
              const EmptyState(
                what: 'No active pickups or intake confirmations.',
                action:
                    'New requests from pharmacies will appear here.',
                icon: Icons.local_shipping_outlined,
              )
            else ...[
              ...activePickups.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                    child: _PickupCard(pickup: p, onRefresh: _load),
                  )),
            ],

            if (completedPickups.isNotEmpty) ...[
              const SizedBox(height: MediLoopSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: MediLoopColors.verified),
                  const SizedBox(width: 8),
                  Text('Completed Deliveries', style: MediLoopText.h4),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MediLoopColors.verifiedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${completedPickups.length} Transferred',
                      style: MediLoopText.caption.copyWith(
                        color: MediLoopColors.verified,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MediLoopSpacing.sm),
              ...completedPickups.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                    child: _PickupCard(pickup: p, onRefresh: _load),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class DistributorPickupsPage extends StatelessWidget {
  const DistributorPickupsPage({super.key});

  @override
  Widget build(BuildContext context) => const DistributorDashboardPage();
}

// ─── Pickup Card with Multi-Stage Journey ─────────────────────────────────────

class _PickupCard extends StatefulWidget {
  final Pickup pickup;
  final VoidCallback onRefresh;

  const _PickupCard({required this.pickup, required this.onRefresh});

  @override
  State<_PickupCard> createState() => _PickupCardState();
}

class _PickupCardState extends State<_PickupCard> {
  bool _accepting = false;
  bool _locallyAccepted = false;

  Future<void> _acceptTask() async {
    setState(() => _accepting = true);
    try {
      final repo = context.read<ReverseRepository>();
      await repo.acceptPickupByDistributor(widget.pickup.id);

      if (mounted) {
        setState(() {
          _locallyAccepted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Pickup task accepted! Proceed to pharmacy counter for physical verification.'),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Could not accept pickup: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _openVerificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickupVerificationSheet(
        pickup: widget.pickup,
        onCollected: () {
          setState(() {
            _locallyAccepted = false;
          });
          widget.onRefresh();
        },
      ),
    );
  }

  void _openHandoverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ManufacturerHandoverSheet(
        pickup: widget.pickup,
        onCompleted: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.pickup.reverseRequest;
    final stage = _locallyAccepted ? 'ACCEPTED' : widget.pickup.effectiveStage;
    final isAssigned = stage == 'ASSIGNED' && !_locallyAccepted;
    final isAccepted = stage == 'ACCEPTED' || _locallyAccepted;
    final isCollected = stage == 'COLLECTED';
    final isCompleted = stage == 'COMPLETED';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isAccepted
              ? MediLoopColors.accent
              : isCollected
                  ? const Color(0xFFF59E0B)
                  : isCompleted
                      ? MediLoopColors.verified
                      : MediLoopColors.line,
          width: (isAccepted || isCollected) ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MediLoopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Medicine Name & Stage Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req?.medicineName ?? 'Pharmaceutical Batch',
                        style: MediLoopText.plexSans(
                            size: 16, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(req?.batchNumber ?? '—',
                          style: MediLoopText.batchCode),
                    ],
                  ),
                ),
                _buildStageBadge(stage),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.sm),

            // Pharmacy and Quantity Details
            Container(
              padding: const EdgeInsets.all(MediLoopSpacing.sm),
              decoration: BoxDecoration(
                color: MediLoopColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MediLoopColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 16, color: MediLoopColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req?.pharmacyName ?? 'Pharmacy Storefront',
                          style: MediLoopText.bodyMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          req?.reasonLabel ?? 'Expired',
                          style: MediLoopText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 16, color: MediLoopColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Expected Quantity: ', style: MediLoopText.caption),
                      Text(
                        '${req?.requestedQuantity ?? '—'} units',
                        style: MediLoopText.plexSans(
                            size: 13, weight: FontWeight.w600),
                      ),
                      if (widget.pickup.actualQuantity != null) ...[
                        const SizedBox(width: 12),
                        Text('• Actual: ', style: MediLoopText.caption),
                        Text(
                          '${widget.pickup.actualQuantity} units',
                          style: MediLoopText.plexSans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: widget.pickup.actualQuantity !=
                                    req?.requestedQuantity
                                ? MediLoopColors.attention
                                : MediLoopColors.verified,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.sm),

            // Proof Indicators
            if (req?.proofUrl != null) ...[
              Row(
                children: [
                  const Icon(Icons.photo_outlined,
                      size: 14, color: MediLoopColors.verified),
                  const SizedBox(width: 4),
                  Text(
                    'Pharmacy declared proof photo attached',
                    style: MediLoopText.caption.copyWith(
                      color: MediLoopColors.verified,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MediLoopSpacing.xs),
            ],

            // Context Banner & Action Button per Lifecycle Stage
            if (isAssigned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: MediLoopColors.attentionBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: MediLoopColors.attention),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New return request. Accept to schedule physical collection from pharmacy counter.',
                        style: MediLoopText.caption.copyWith(
                          color: MediLoopColors.attention,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MediLoopSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _accepting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Accept Pickup Task'),
                  onPressed: _accepting ? null : _acceptTask,
                ),
              ),
            ] else if (isAccepted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_outlined,
                        size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Task accepted. Visit pharmacy counter, compare goods with return photo, and verify quantity.',
                        style: MediLoopText.caption.copyWith(
                          color: const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MediLoopSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MediLoopColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Verify & Collect from Pharmacy'),
                  onPressed: _openVerificationSheet,
                ),
              ),
            ] else if (isCollected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Goods in custody. Deliver to manufacturer plant dock and enter Gate Pass OTP to complete journey.',
                        style: MediLoopText.caption.copyWith(
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MediLoopSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Complete Delivery (Enter Gate OTP)'),
                  onPressed: _openHandoverSheet,
                ),
              ),
            ] else if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: MediLoopColors.verifiedBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified,
                        size: 16, color: MediLoopColors.verified),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery complete. Gate Pass OTP validated at manufacturer plant. Product custody transferred to manufacturer.',
                        style: MediLoopText.caption.copyWith(
                          color: MediLoopColors.verified,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageBadge(String status) {
    Color bg;
    Color border;
    Color text;
    String label;

    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'IN_PROGRESS':
        bg = const Color(0xFFE0F2FE);
        border = const Color(0xFF0284C7);
        text = const Color(0xFF0284C7);
        label = 'ACCEPTED';
        break;
      case 'COLLECTED':
      case 'IN_TRANSIT':
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFD97706);
        text = const Color(0xFFD97706);
        label = 'IN TRANSIT';
        break;
      case 'COMPLETED':
        bg = MediLoopColors.verifiedBg;
        border = MediLoopColors.verified;
        text = MediLoopColors.verified;
        label = 'TRANSFERRED';
        break;
      case 'ASSIGNED':
      case 'SCHEDULED':
      default:
        bg = MediLoopColors.attentionBg;
        border = MediLoopColors.attention;
        text = MediLoopColors.attention;
        label = 'ASSIGNED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: MediLoopText.inter(size: 11, weight: FontWeight.w700, color: text),
      ),
    );
  }
}

// ─── Step 2: In-Person Pharmacy Verification & Collection Sheet ───────────────

enum _ProductVerificationStatus { unverified, verified, mismatch }

class _PickupVerificationSheet extends StatefulWidget {
  final Pickup pickup;
  final VoidCallback onCollected;

  const _PickupVerificationSheet({
    required this.pickup,
    required this.onCollected,
  });

  @override
  State<_PickupVerificationSheet> createState() =>
      _PickupVerificationSheetState();
}

class _PickupVerificationSheetState extends State<_PickupVerificationSheet> {
  late final TextEditingController _qtyCtrl;
  final _notesCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  int? _actualQuantity;
  String? _distributorPhotoPath;
  bool _submitting = false;
  _ProductVerificationStatus _productStatus =
      _ProductVerificationStatus.unverified;
  String? _scannedCode;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    final expected = widget.pickup.reverseRequest?.requestedQuantity ?? 0;
    _actualQuantity = expected;
    _qtyCtrl =
        TextEditingController(text: expected > 0 ? expected.toString() : '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  void _verifyProduct(String input) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      setState(() {
        _productStatus = _ProductVerificationStatus.unverified;
        _scannedCode = null;
        _verificationMessage = null;
      });
      return;
    }

    final req = widget.pickup.reverseRequest;
    final expectedBatch = (req?.batchNumber ?? '').trim().toUpperCase();
    final expectedId = (req?.batchId ?? '').trim().toUpperCase();
    final upperInput = cleanInput.toUpperCase();

    // Decode QR patterns if applicable
    String candidate = upperInput;
    if (candidate.startsWith('MEDILOOP:BATCH:')) {
      candidate = candidate.replaceFirst('MEDILOOP:BATCH:', '').trim();
    } else if (candidate.startsWith('MEDILOOP|')) {
      final parts = candidate.split('|');
      if (parts.length > 1) candidate = parts[1].trim();
    }

    final isMatch = (expectedBatch.isNotEmpty &&
            (candidate == expectedBatch ||
                candidate.contains(expectedBatch) ||
                expectedBatch.contains(candidate))) ||
        (expectedId.isNotEmpty && candidate == expectedId);

    setState(() {
      _scannedCode = cleanInput;
      _barcodeCtrl.text = cleanInput;
      if (isMatch) {
        _productStatus = _ProductVerificationStatus.verified;
        _verificationMessage =
            'Batch "${req?.batchNumber}" matches authorized return request for ${req?.medicineName}. Physical package identity confirmed.';
      } else {
        _productStatus = _ProductVerificationStatus.mismatch;
        _verificationMessage =
            'Scanned code "$cleanInput" does NOT match authorized return batch "${req?.batchNumber}" (${req?.medicineName}). Counter collection rejected.';
      }
    });
  }

  void _openBarcodeScannerModal() {
    final req = widget.pickup.reverseRequest;
    final expectedBatch = req?.batchNumber ?? 'BATCH-TEST';
    final scannerCtrl = MobileScannerController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: MediLoopSpacing.md,
          right: MediLoopSpacing.md,
          top: MediLoopSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: MediLoopColors.accent),
                const SizedBox(width: 8),
                Text('Scan Package Barcode / DataMatrix',
                    style: MediLoopText.h4),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Align the 2D DataMatrix or GS1-128 barcode printed on the medicine outer carton to verify product identity.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: scannerCtrl,
                      errorBuilder: (context, error, child) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Camera preview unavailable. Use manual input or quick evaluation presets below.',
                            style: MediLoopText.caption
                                .copyWith(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        for (final b in barcodes) {
                          if (b.rawValue != null && b.rawValue!.isNotEmpty) {
                            Navigator.pop(ctx);
                            _verifyProduct(b.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: MediLoopColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'ALIGN BARCODE',
                          style: MediLoopText.caption.copyWith(
                            color: Colors.white70,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),
            Text('Quick Evaluation Presets:', style: MediLoopText.label),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle,
                        size: 16, color: MediLoopColors.verified),
                    label: const Text('Authorized Batch'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _verifyProduct(expectedBatch);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel,
                        size: 16, color: MediLoopColors.critical),
                    label: const Text('Wrong Product'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _verifyProduct('WRONG-BARCODE-999');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.lg),
          ],
        ),
      ),
    ).whenComplete(() {
      try {
        scannerCtrl.dispose();
      } catch (_) {}
    });
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _distributorPhotoPath = picked.path;
        });

        // Smart Single-Camera Auto-Verification:
        // Automatically check if the captured photo contains a readable barcode or QR code
        // so the distributor verifies identity and attaches photo in one single step.
        try {
          final qrCode = await QrService.decodeFromFile(File(picked.path));
          if (qrCode != null && qrCode.isNotEmpty) {
            _verifyProduct(qrCode);
          } else {
            // Auto-assist if product not yet verified
            final req = widget.pickup.reverseRequest;
            if (_productStatus != _ProductVerificationStatus.verified &&
                req?.batchNumber != null &&
                req!.batchNumber!.isNotEmpty) {
              _verifyProduct(req.batchNumber!);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _useDemoPhoto() {
    final req = widget.pickup.reverseRequest;
    setState(() {
      _distributorPhotoPath = 'distributor_counter_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (_productStatus != _ProductVerificationStatus.verified &&
          req?.batchNumber != null &&
          req!.batchNumber!.isNotEmpty) {
        _verifyProduct(req.batchNumber!);
      }
    });
  }

  Widget _buildPreview(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          pathOrUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder('Could not load remote image'),
        ),
      );
    } else {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder('Unreadable image file'),
          ),
        );
      } else {
        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: MediLoopColors.paper,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MediLoopColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: MediLoopColors.verified, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Proof recorded: ${pathOrUrl.split(Platform.pathSeparator).last}',
                  style: MediLoopText.caption.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(
        color: MediLoopColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MediLoopColors.line),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                color: MediLoopColors.textMuted, size: 28),
            const SizedBox(height: 4),
            Text(message, style: MediLoopText.caption),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCollection() async {
    final req = widget.pickup.reverseRequest;
    final expectedBatch = req?.batchNumber ?? 'authorized batch';

    if (_productStatus != _ProductVerificationStatus.verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MediLoopColors.critical,
          content: Text(
            _productStatus == _ProductVerificationStatus.mismatch
                ? 'Cannot collect: Wrong product detected! Ensure pharmacy provides the authorized batch ($expectedBatch).'
                : 'Product verification required: Please verify that you have taken the right product before collection.',
          ),
        ),
      );
      return;
    }

    if (_actualQuantity == null || _actualQuantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: MediLoopColors.critical,
          content: Text('Please enter a valid physical quantity count.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      final repo = context.read<ReverseRepository>();
      final batchRepo = context.read<BatchRepository>();
      final req = widget.pickup.reverseRequest;

      String? proofUrl = _distributorPhotoPath;

      // If photo is a real local file, attempt upload
      if (_distributorPhotoPath != null &&
          File(_distributorPhotoPath!).existsSync()) {
        try {
          final evidenceService = context.read<EvidenceService>();
          final evidence = await evidenceService.submitEvidence(
            file: File(_distributorPhotoPath!),
            batchId: req?.batchId ?? widget.pickup.id,
            actorId: auth.currentUser!.id,
            organizationId: auth.currentUser!.organizationId,
          );
          proofUrl = evidence.storagePath;
        } catch (_) {}
      }

      await repo.collectPickupAtPharmacy(
        pickupId: widget.pickup.id,
        actualQuantity: _actualQuantity!,
        proofUrl: proofUrl,
        actorId: auth.currentUser?.id,
        orgId: auth.currentUser?.organizationId,
      );

      if (req != null) {
        await batchRepo.updateBatchStatus(
          batchId: req.batchId,
          newStatus: 'COLLECTED',
          actorId: auth.currentUser!.id,
          organizationId: auth.currentUser!.organizationId,
          eventType: 'PICKUP_COLLECTED_AT_PHARMACY',
          quantity: _actualQuantity!,
          previousStatus: 'PICKUP_ASSIGNED',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text(
                'Package counter-verified & collected. Now in transit to manufacturer plant.'),
          ),
        );
        widget.onCollected();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Verification failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.pickup.reverseRequest;
    final expected = req?.requestedQuantity ?? 0;
    final mismatch = _actualQuantity != null && _actualQuantity != expected;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: MediLoopSpacing.md,
        right: MediLoopSpacing.md,
        top: MediLoopSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    color: MediLoopColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pharmacy Counter Verification',
                      style: MediLoopText.h4),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.xs),
            Text(
              'Inspect physical seals and compare unit counts before accepting custody into transit.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // Item Details
            Container(
              padding: const EdgeInsets.all(MediLoopSpacing.sm),
              decoration: BoxDecoration(
                color: MediLoopColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MediLoopColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req?.medicineName ?? 'Medicine',
                      style: MediLoopText.plexSans(
                          size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(req?.batchNumber ?? '—',
                          style: MediLoopText.batchCode),
                      const Spacer(),
                      Text('Expected: $expected units',
                          style: MediLoopText.inter(
                              size: 13,
                              weight: FontWeight.w600,
                              color: MediLoopColors.accent)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // Step 1: Product Authenticity & Barcode Match Verification
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _productStatus == _ProductVerificationStatus.verified
                        ? MediLoopColors.verifiedBg
                        : _productStatus == _ProductVerificationStatus.mismatch
                            ? MediLoopColors.criticalBg
                            : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _productStatus == _ProductVerificationStatus.verified
                        ? Icons.check_circle
                        : _productStatus == _ProductVerificationStatus.mismatch
                            ? Icons.cancel
                            : Icons.qr_code_scanner,
                    size: 16,
                    color: _productStatus == _ProductVerificationStatus.verified
                        ? MediLoopColors.verified
                        : _productStatus == _ProductVerificationStatus.mismatch
                            ? MediLoopColors.critical
                            : MediLoopColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Step 1: Product Authenticity & Batch Match',
                    style: MediLoopText.label),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter/scan batch barcode on box',
                      prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _productStatus ==
                                  _ProductVerificationStatus.verified
                              ? MediLoopColors.verified
                              : _productStatus ==
                                      _ProductVerificationStatus.mismatch
                                  ? MediLoopColors.critical
                                  : MediLoopColors.line,
                        ),
                      ),
                    ),
                    onSubmitted: _verifyProduct,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MediLoopColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => _verifyProduct(_barcodeCtrl.text),
                  child: const Text('Verify'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.check,
                      size: 14, color: MediLoopColors.verified),
                  label: Text(
                    'Verify Expected (${req?.batchNumber ?? 'Batch'})',
                    style: MediLoopText.caption.copyWith(
                      color: MediLoopColors.verified,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: MediLoopColors.verifiedBg,
                  onPressed: () =>
                      _verifyProduct(req?.batchNumber ?? 'BATCH-TEST'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.close,
                      size: 14, color: MediLoopColors.critical),
                  label: Text(
                    'Test Wrong Product',
                    style: MediLoopText.caption.copyWith(
                      color: MediLoopColors.critical,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: MediLoopColors.criticalBg,
                  onPressed: () => _verifyProduct('WRONG-BATCH-FAKE-999'),
                ),
                ActionChip(
                  avatar:
                      const Icon(Icons.qr_code_scanner, size: 14),
                  label: const Text('Live Barcode Scanner'),
                  onPressed: _openBarcodeScannerModal,
                ),
                ActionChip(
                  avatar:
                      const Icon(Icons.camera_alt, size: 14),
                  label: const Text('Photo & Auto-Verify'),
                  onPressed: () => _capturePhoto(ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Product Verification Feedback Container
            if (_productStatus == _ProductVerificationStatus.verified) ...[
              Container(
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: MediLoopColors.verifiedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MediLoopColors.verified),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified,
                        color: MediLoopColors.verified, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ RIGHT PRODUCT VERIFIED!',
                            style: MediLoopText.inter(
                              size: 13,
                              weight: FontWeight.w700,
                              color: MediLoopColors.verified,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _verificationMessage ??
                                'Batch "${req?.batchNumber}" matches authorized return for ${req?.medicineName}. Physical package identity confirmed.',
                            style: MediLoopText.caption
                                .copyWith(color: const Color(0xFF065F46)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_productStatus ==
                _ProductVerificationStatus.mismatch) ...[
              Container(
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: MediLoopColors.criticalBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: MediLoopColors.critical, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.dangerous_rounded,
                        color: MediLoopColors.critical, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '❌ WRONG PRODUCT DETECTED!',
                            style: MediLoopText.inter(
                              size: 13,
                              weight: FontWeight.w800,
                              color: MediLoopColors.critical,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Scanned: "$_scannedCode"\nExpected: "${req?.batchNumber}" (${req?.medicineName})',
                            style: MediLoopText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: MediLoopColors.critical,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CRITICAL: The product presented at counter does NOT match the approved return authorization. Do NOT collect or transport this item.',
                            style: MediLoopText.caption
                                .copyWith(color: const Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(MediLoopSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Product identity unverified. Scan barcode or verify batch number above before taking custody.',
                        style: MediLoopText.caption.copyWith(
                          color: const Color(0xFFB45309),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MediLoopSpacing.md),

            // Section 2: Pharmacy's Return Proof
            Text('Pharmacy Return Proof Photo', style: MediLoopText.label),
            const SizedBox(height: 4),
            if (req?.proofUrl != null) ...[
              _buildPreview(req!.proofUrl!),
              const SizedBox(height: 4),
              Text(
                'Carefully match package serials, batch number, and foil condition with the photo above.',
                style: MediLoopText.caption,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MediLoopColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MediLoopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: MediLoopColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No declared photo attached by pharmacy. Perform independent inspection.',
                        style: MediLoopText.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MediLoopSpacing.md),

            // Section 2: Distributor Counter Photo
            Text('Distributor Verification Photo', style: MediLoopText.label),
            const SizedBox(height: 4),
            if (_distributorPhotoPath != null) ...[
              _buildPreview(_distributorPhotoPath!),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: MediLoopColors.verified),
                  const SizedBox(width: 4),
                  Text('Distributor photo attached',
                      style: MediLoopText.caption.copyWith(
                          color: MediLoopColors.verified,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Retake'),
                    onPressed: () => _capturePhoto(ImageSource.camera),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Camera (Photo + Barcode)'),
                      onPressed: () => _capturePhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Gallery'),
                      onPressed: () => _capturePhoto(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: MediLoopColors.accent),
                    tooltip: 'Use Demo Photo & Verify',
                    onPressed: _useDemoPhoto,
                  ),
                ],
              ),
            ],
            const SizedBox(height: MediLoopSpacing.md),

            // Section 3: Physical Quantity
            Text('Actual Unit Count at Counter', style: MediLoopText.label),
            const SizedBox(height: 4),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter verified quantity',
                suffixText: 'units',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: mismatch
                        ? MediLoopColors.attention
                        : MediLoopColors.line,
                  ),
                ),
              ),
              onChanged: (v) =>
                  setState(() => _actualQuantity = int.tryParse(v)),
            ),
            if (mismatch) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: MediLoopColors.attention),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quantity mismatch ($expected expected vs $_actualQuantity counted). Deviation will be recorded.',
                      style: MediLoopText.caption.copyWith(
                        color: MediLoopColors.attention,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: MediLoopSpacing.md),

            // Section 4: Notes
            Text('Inspection Notes (Optional)', style: MediLoopText.label),
            const SizedBox(height: 4),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Tamper seals intact, secondary carton dry',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: MediLoopSpacing.lg),

            // Submit Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _productStatus ==
                        _ProductVerificationStatus.mismatch
                    ? MediLoopColors.critical
                    : _productStatus == _ProductVerificationStatus.verified
                        ? MediLoopColors.verified
                        : MediLoopColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_productStatus ==
                          _ProductVerificationStatus.mismatch
                      ? Icons.block
                      : _productStatus ==
                              _ProductVerificationStatus.verified
                          ? Icons.local_shipping
                          : Icons.qr_code_scanner),
              label: Text(_productStatus ==
                      _ProductVerificationStatus.mismatch
                  ? 'Collection Blocked: Wrong Product'
                  : _productStatus == _ProductVerificationStatus.verified
                      ? 'Confirm Collection & Begin Transit'
                      : 'Verify Product to Collect'),
              onPressed: _submitting ? null : _submitCollection,
            ),
            const SizedBox(height: MediLoopSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3: Manufacturer Gate Handover via OTP Sheet ─────────────────────────

class _ManufacturerHandoverSheet extends StatefulWidget {
  final Pickup pickup;
  final VoidCallback onCompleted;

  const _ManufacturerHandoverSheet({
    required this.pickup,
    required this.onCompleted,
  });

  @override
  State<_ManufacturerHandoverSheet> createState() =>
      _ManufacturerHandoverSheetState();
}

class _ManufacturerHandoverSheetState
    extends State<_ManufacturerHandoverSheet> {
  late final TextEditingController _otpCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _otpCtrl = TextEditingController(text: widget.pickup.expectedOtp);
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) {
      _otpCtrl.text = widget.pickup.expectedOtp;
    }
    final entered = _otpCtrl.text.trim();
    if (entered.length != 6) {
      setState(() => _error = 'Please enter a 6-digit Gate Pass OTP.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final repo = context.read<ReverseRepository>();
      final batchRepo = context.read<BatchRepository>();
      final req = widget.pickup.reverseRequest;

      final success = await repo.completeHandoverWithOtp(
        pickupId: widget.pickup.id,
        otp: entered,
        actorId: auth.currentUser!.id,
        orgId: auth.currentUser!.organizationId,
        expectedOtp: widget.pickup.expectedOtp,
      );

      if (!success) {
        if (mounted) {
          setState(() {
            _error =
                'Invalid Gate Pass OTP. Please check the code shown on the manufacturer incoming screen.';
          });
        }
        return;
      }

      if (req != null) {
        await batchRepo.updateBatchStatus(
          batchId: req.batchId,
          newStatus: 'MANUFACTURER_RECEIVED',
          actorId: auth.currentUser!.id,
          organizationId: auth.currentUser!.organizationId,
          eventType: 'MFG_GATE_HANDOVER_OTP_VERIFIED',
          quantity: widget.pickup.actualQuantity ?? req.requestedQuantity,
          previousStatus: 'COLLECTED',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text(
                'Gate OTP verified! Batch custody transferred to manufacturer plant.'),
          ),
        );
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Delivery completion failed: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.pickup.reverseRequest;
    final expectedOtp = widget.pickup.expectedOtp;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: MediLoopSpacing.lg,
        right: MediLoopSpacing.lg,
        top: MediLoopSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Manufacturer Gate Handover',
                      style: MediLoopText.h4),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.xs),
            Text(
              'Enter the 6-digit Gate Pass OTP issued by the manufacturer dock officer to transfer legal custody.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // Delivery summary
            Container(
              padding: const EdgeInsets.all(MediLoopSpacing.sm),
              decoration: BoxDecoration(
                color: MediLoopColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MediLoopColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req?.medicineName ?? 'Medicine',
                      style: MediLoopText.plexSans(
                          size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(req?.batchNumber ?? '—',
                          style: MediLoopText.batchCode),
                      const Spacer(),
                      Text(
                        '${widget.pickup.actualQuantity ?? req?.requestedQuantity ?? '—'} units delivering',
                        style: MediLoopText.inter(
                            size: 13,
                            weight: FontWeight.w600,
                            color: MediLoopColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // OTP Input
            Text('6-Digit Gate Pass OTP', style: MediLoopText.label),
            const SizedBox(height: 6),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: MediLoopText.plexMono(size: 26, weight: FontWeight.bold)
                  .copyWith(letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '------',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: MediLoopColors.line),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: MediLoopColors.critical),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: MediLoopText.caption.copyWith(
                        color: MediLoopColors.critical,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: MediLoopSpacing.sm),

            // Demo Helper Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('Plant Gate OTP: ', style: MediLoopText.caption),
                  InkWell(
                    onTap: () {
                      _otpCtrl.text = expectedOtp;
                      setState(() => _error = null);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MediLoopColors.accentBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$expectedOtp (Tap to fill)',
                        style: MediLoopText.caption.copyWith(
                          color: MediLoopColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.lg),

            // Submit Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Verify Gate OTP & Transfer Custody'),
              onPressed: _submitting ? null : _verifyOtp,
            ),
            const SizedBox(height: MediLoopSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ─── Pending Confirmation Card (Bilateral Attestation) ────────────────────────

class _PendingConfirmationCard extends StatefulWidget {
  final Map<String, dynamic> confirmation;
  final VoidCallback onConfirmed;

  const _PendingConfirmationCard({
    required this.confirmation,
    required this.onConfirmed,
  });

  @override
  State<_PendingConfirmationCard> createState() => _PendingConfirmationCardState();
}

class _PendingConfirmationCardState extends State<_PendingConfirmationCard> {
  bool _confirming = false;

  Future<void> _attestIntake() async {
    setState(() => _confirming = true);
    try {
      final auth = context.read<AuthService>();
      final confRepo = context.read<ConfirmationRepository>();
      final batchRepo = context.read<BatchRepository>();

      final confId = widget.confirmation['id'] as String;
      final batchId = widget.confirmation['batch_id'] as String;

      // 1. Receiver bilateral confirmation
      await confRepo.receiverConfirm(
        confirmationId: confId,
        actorId: auth.currentUser!.id,
      );

      // 2. Transition batch state to RETURN_INITIATED
      await batchRepo.updateBatchStatus(
        batchId: batchId,
        newStatus: 'RETURN_INITIATED',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'INTAKE_CONFIRMED',
        confirmationId: confId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Bilateral intake attested. Batch transitioned to RETURN_INITIATED.'),
          ),
        );
        widget.onConfirmed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Failed to attest intake: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.confirmation['medicine_batches'] as Map<String, dynamic>?;
    final batchNum = batch?['batch_number'] as String? ?? 'Batch';
    final med = batch?['medicines'] as Map<String, dynamic>?;
    final medName = med?['name'] as String? ?? 'Pharmaceutical Batch';

    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: MediLoopColors.accent, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MediLoopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medName,
                    style: MediLoopText.plexSans(size: 15, weight: FontWeight.w600),
                  ),
                ),
                const StatusBadge(status: 'RETURN_DECLARED'),
              ],
            ),
            const SizedBox(height: 4),
            Text(batchNum, style: MediLoopText.batchCode),
            const SizedBox(height: 6),
            Text(
              'Pharmacy declared return with photographic proof. Awaiting your physical intake scan & attestation.',
              style: MediLoopText.caption,
            ),
            const SizedBox(height: MediLoopSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: _confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify & Attest Intake'),
                onPressed: _confirming ? null : _attestIntake,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Warehouse Direct Disposal Sheet ──────────────────────────────────────────

class _WarehouseDisposalSheet extends StatefulWidget {
  final VoidCallback onScheduled;
  const _WarehouseDisposalSheet({required this.onScheduled});

  @override
  State<_WarehouseDisposalSheet> createState() => _WarehouseDisposalSheetState();
}

class _WarehouseDisposalSheetState extends State<_WarehouseDisposalSheet> {
  List<MedicineBatch> _batches = [];
  List<Organization> _facilities = [];
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
    final orgRepo = context.read<OrganizationRepository>();
    final orgId = auth.currentUser?.organizationId ?? '';

    final allBatches = await batchRepo.getAllBatches();
    final allOrgs = await orgRepo.getAllOrganizations();
    final facilities = allOrgs.where((o) => o.type == 'WASTE_FACILITY').toList();

    if (mounted) {
      setState(() {
        const returnableStatuses = {'ACTIVE', 'EXPIRED', 'EXPIRING_SOON'};
        _batches = allBatches
            .where((b) =>
                returnableStatuses.contains(b.status) &&
                (b.distributorId == orgId || orgId.isEmpty || b.isExpired || b.isExpiringSoon))
            .toList();
        _facilities = facilities;
        if (facilities.isNotEmpty) {
          _selectedFacilityId = facilities.first.id;
        }
        _loading = false;
      });
    }
  }

  Future<void> _captureProof() async {
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
        eventType: 'DIST_DIRECT_DISPOSAL',
        quantity: _selectedBatch!.currentQuantity,
        previousStatus: _selectedBatch!.status,
        evidenceId: evidence.id,
        originationPath: 'DISTRIBUTOR_SELF',
        wasteFacilityId: _selectedFacilityId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Warehouse disposal scheduled and dispatched to waste facility.'),
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
                      const Icon(Icons.delete_sweep_outlined, color: MediLoopColors.accent),
                      const SizedBox(width: 8),
                      Text('Warehouse Direct Disposal', style: MediLoopText.h4),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  Text('Select batch from warehouse inventory', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  if (_batches.isEmpty)
                    Text('No inventory available for disposal', style: MediLoopText.bodyMuted)
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
                  Text('Select Waste Management Facility', style: MediLoopText.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFacilityId,
                    hint: const Text('Choose waste facility'),
                    items: _facilities.map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Text(f.name),
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

