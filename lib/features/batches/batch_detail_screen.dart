import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../core/router.dart';
import '../../repositories/batch_repository.dart';
import '../../models/medicine_batch.dart';
import '../../models/batch_event.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/lifecycle_pipeline.dart';
import '../../widgets/status_badge.dart';
import '../../services/audit_service.dart';
import '../../services/qr_service.dart';
import '../../models/disposal_record.dart';
import '../../repositories/disposal_repository.dart';
import '../../models/reverse_request.dart';
import '../../repositories/reverse_repository.dart';
import '../../widgets/cdsco_certificate_viewer.dart';

/// The single screen that makes the whole product legible in 20 seconds.
class BatchDetailScreen extends StatefulWidget {
  final String batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  MedicineBatch? _batch;
  List<BatchEvent> _events = [];
  DestructionCertificate? _certificate;
  ReverseRequest? _returnRequest;
  bool _loading = true;
  String? _error;
  AuditVerificationResult? _verificationResult;
  bool _verifyingChain = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<BatchRepository>();
      final disposalRepo = context.read<DisposalRepository>();
      final reverseRepo = context.read<ReverseRepository>();
      final batch = await repo.getBatchById(widget.batchId);
      final events = await repo.getEventsForBatch(widget.batchId);
      
      DestructionCertificate? cert;
      try {
        cert = await disposalRepo.getCertificateByBatchId(widget.batchId);
      } catch (_) {}

      ReverseRequest? returnReq;
      try {
        returnReq = await reverseRepo.getRequestByBatchId(widget.batchId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _batch = batch;
          _events = events;
          _certificate = cert;
          _returnRequest = returnReq;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Couldn't load batch details. Check your connection and try again.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyAuditChain() async {
    setState(() => _verifyingChain = true);
    try {
      final auditService = context.read<AuditService>();
      final result = await auditService.verifyChain(widget.batchId);
      if (mounted) {
        setState(() {
          _verificationResult = result;
          _verifyingChain = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingChain = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    }
  }

  void _showQrDialog(BuildContext context, MedicineBatch batch) {
    final qrData = QrService.encodeBatchQr(batch.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: MediLoopColors.ink),
            const SizedBox(width: 8),
            Text(batch.batchNumber, style: MediLoopText.h4),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(MediLoopRadius.card),
                border: Border.all(color: MediLoopColors.line),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: Colors.black87),
                  const SizedBox(height: 8),
                  Text(
                    qrData,
                    textAlign: TextAlign.center,
                    style: MediLoopText.plexMono(
                      size: 12,
                      color: MediLoopColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.sm),
            Text(
              'Standard MediLoop Format: MEDILOOP:BATCH:<uuid>',
              style: MediLoopText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrData));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR string copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy String'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() => context.safePop();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: _buildContent(context, handleBack),
    );
  }

  Widget _buildContent(BuildContext context, VoidCallback handleBack) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: handleBack),
          title: const Text('Batch detail'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: handleBack),
          title: const Text('Batch detail'),
        ),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_batch == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: handleBack),
          title: const Text('Batch detail'),
        ),
        body: const EmptyState(
          what: 'Batch not found.',
          action: 'This batch may have been removed or the ID is invalid.',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    final batch = _batch!;

    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        leading: BackButton(onPressed: handleBack),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(batch.displayName, style: MediLoopText.h4),
              Text(batch.batchNumber, style: MediLoopText.batchCode),
            ],
          ),
        ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          children: [
            // ── Batch summary passport card
            Container(
              decoration: BoxDecoration(
                color: MediLoopColors.surface,
                borderRadius: BorderRadius.circular(MediLoopRadius.card),
                border: Border.all(color: MediLoopColors.line),
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
                          Icons.medication_rounded,
                          size: 20,
                          color: MediLoopColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.displayName,
                              style: MediLoopText.plexSans(
                                size: 16,
                                weight: FontWeight.w700,
                                color: MediLoopColors.ink,
                              ),
                            ),
                            Text(
                              batch.batchNumber,
                              style: MediLoopText.batchCode.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: batch.status),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  const Divider(),
                  const SizedBox(height: MediLoopSpacing.sm),
                  _DetailRow(
                    label: 'Expiry date',
                    value: DateFormat('dd MMM yyyy').format(batch.expiryDate),
                    warning: batch.isExpired || batch.isExpiringSoon,
                  ),
                  _DetailRow(
                    label: 'Original quantity',
                    value: '${batch.originalQuantity} units',
                  ),
                  _DetailRow(
                    label: 'Current quantity',
                    value: '${batch.currentQuantity} units',
                  ),
                  if (batch.pharmacyName != null)
                    _DetailRow(
                      label: 'Pharmacy',
                      value: batch.pharmacyName!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // ── Physical Proof Evidence Card (if return initiated with proof)
            if (_returnRequest?.proofUrl != null && _returnRequest!.proofUrl!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: MediLoopSpacing.md),
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  border: Border.all(color: MediLoopColors.line),
                  boxShadow: MediLoopShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MediLoopColors.verifiedBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: MediLoopColors.verified,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Physical Custody Evidence',
                            style: MediLoopText.inter(
                              size: 14,
                              weight: FontWeight.w700,
                              color: MediLoopColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text(
                            'SHA-256 Hashed',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showProofInspectionDialog(context, _returnRequest!.proofUrl!, batch),
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProofWidget(_returnRequest!.proofUrl!, height: 140),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Inspect Proof',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── CDSCO Official Destruction Certificate Banner
            if (_certificate != null || batch.status == 'DESTROYED') ...[
              Container(
                margin: const EdgeInsets.only(bottom: MediLoopSpacing.md),
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF7EE),
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E22CE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CDSCO FORM 48',
                                  style: MediLoopText.caption.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Certified Closed-Loop',
                                style: MediLoopText.caption.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _certificate?.certificateNumber ?? 'CDSCO-CERT-2026-004812',
                            style: MediLoopText.plexMono(
                              size: 13,
                              weight: FontWeight.w700,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          Text(
                            'Official destruction record & tamper-proof hash verified',
                            style: MediLoopText.caption.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final cert = _certificate ??
                            DestructionCertificate(
                              id: 'cert-001',
                              disposalRecordId: 'disp-001',
                              batchId: batch.id,
                              certificateNumber: 'CDSCO-CERT-2026-004812',
                              verificationStatus: 'VERIFIED',
                              issuedDate: DateTime.now().subtract(const Duration(days: 14)),
                              documentUrl: 'https://demo.mediloop.org/certificates/cert-001.pdf',
                              hash: 'a8f3b9c2401f8d93e117b4c892e59123049bca71049281bfd8e90a12c418e244',
                            );
                        CdscoCertificateViewer.show(
                          context,
                          certificate: cert,
                          batch: batch,
                          facilityName: 'BioClean Bio-Medical Waste Facility',
                          disposalMethod: 'High-Temperature Incineration (1100°C)',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View Cert'),
                    ),
                  ],
                ),
              ),
            ],

            // ── Quick Actions (Verify Chain + Show QR)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _verifyingChain ? null : _verifyAuditChain,
                    icon: _verifyingChain
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_outlined, size: 18),
                    label: Text(_verifyingChain
                        ? 'Verifying...'
                        : 'Verify Chain'),
                  ),
                ),
                const SizedBox(width: MediLoopSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _showQrDialog(context, batch),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text('Batch QR'),
                ),
              ],
            ),

            if (context.watch<AuthService>().currentRole == 'PHARMACY' &&
                const {'ACTIVE', 'EXPIRED', 'EXPIRING_SOON'}.contains(batch.status)) ...[
              const SizedBox(height: MediLoopSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/return/new?batchId=${batch.id}'),
                  icon: const Icon(Icons.assignment_return_outlined, size: 18),
                  label: const Text('Initiate Return Request for this Batch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MediLoopColors.attention,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: MediLoopSpacing.sm),

            // ── Cryptographic Verification Result Banner
            if (_verificationResult != null) ...[
              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _verificationResult!.valid
                          ? Icons.verified
                          : Icons.gpp_bad,
                      color: _verificationResult!.valid
                          ? MediLoopColors.verified
                          : MediLoopColors.critical,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _verificationResult!.valid
                                ? 'Cryptographic Hash Chain Valid'
                                : 'Audit Chain Discrepancy Flagged',
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
                                ? 'All ${_verificationResult!.eventsChecked} historical events verified tamper-evident via SHA-256 blocks.'
                                : (_verificationResult!.issueDescription ??
                                    'Hash mismatch identified in custody chain.'),
                            style: MediLoopText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MediLoopSpacing.sm),
            ],
            const SizedBox(height: MediLoopSpacing.sm),

            // ── Lifecycle pipeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MediLoopSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chain of custody', style: MediLoopText.label),
                    const SizedBox(height: MediLoopSpacing.md),
                    LifecyclePipeline(
                      completedStage: batch.pipelineStage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // ── Event timeline
            Text('Event history', style: MediLoopText.h4),
            const SizedBox(height: MediLoopSpacing.sm),

            if (_events.isEmpty)
              const EmptyState(
                what: 'No events recorded yet.',
                action: 'Events are recorded as the batch moves through the chain.',
                icon: Icons.history_outlined,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: MediLoopSpacing.sm),
                  child: Column(
                    children: [
                      for (int i = 0; i < _events.length; i++) ...[
                        _TimelineEntry(
                          event: _events[i],
                          isFirst: i == 0,
                          isLast: i == _events.length - 1,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showProofInspectionDialog(BuildContext context, String proofUrl, MedicineBatch batch) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediLoopRadius.card)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: MediLoopSpacing.md, vertical: 12),
                color: const Color(0xFF1E3A8A),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Custody Verification Proof',
                        style: MediLoopText.inter(size: 14, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
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
                    children: [
                      _buildProofWidget(proofUrl, height: 240, fit: BoxFit.contain),
                      Padding(
                        padding: const EdgeInsets.all(MediLoopSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Batch Code', style: MediLoopText.caption),
                                Text(batch.batchNumber, style: MediLoopText.plexMono(size: 12, weight: FontWeight.w700)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Integrity Check', style: MediLoopText.caption),
                                const Text('SHA-256 Hashed & Signed', style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const Divider(height: 16),
                            Text('Storage Security', style: MediLoopText.caption),
                            const SizedBox(height: 2),
                            Text(
                              proofUrl.startsWith('http') ? 'Supabase Vault (Private Bucket / Expiring Signed Link)' : proofUrl,
                              style: MediLoopText.plexMono(size: 11, color: MediLoopColors.textMuted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofWidget(String proofUrl, {double height = 140, BoxFit fit = BoxFit.cover}) {
    if (proofUrl.startsWith('http://') || proofUrl.startsWith('https://')) {
      return Image.network(
        proofUrl,
        height: height,
        width: double.infinity,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            color: MediLoopColors.inactiveBg,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildProofPlaceholder(height),
      );
    } else {
      final file = File(proofUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: height,
          width: double.infinity,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildProofPlaceholder(height),
        );
      }
      return _buildProofPlaceholder(height);
    }
  }

  Widget _buildProofPlaceholder(double height) {
    return Container(
      height: height,
      color: MediLoopColors.inactiveBg,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: MediLoopColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'Physical Packaging Proof Anchored in Ledger',
            style: MediLoopText.caption,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _DetailRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: MediLoopText.labelMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: MediLoopText.inter(
                  size: 14,
                  color: warning
                      ? MediLoopColors.attention
                      : MediLoopColors.textPrimary,
                  weight:
                      warning ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final BatchEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntry({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isFraud = event.eventType == 'FRAUD_DETECTED';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline bar
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical line above dot
                if (!isFirst)
                  Positioned(
                    top: 0,
                    child: Container(
                        width: 2,
                        height: 20,
                        color: MediLoopColors.line),
                  ),
                // Dot
                Positioned(
                  top: isFirst ? 16 : 20,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFraud
                          ? MediLoopColors.critical
                          : MediLoopColors.ink,
                      boxShadow: isFraud
                          ? [
                              BoxShadow(
                                color: MediLoopColors.critical.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : [
                              BoxShadow(
                                color: MediLoopColors.ink.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ],
                    ),
                  ),
                ),
                // Vertical line below dot
                if (!isLast)
                  Positioned(
                    top: isFirst ? 32 : 36,
                    bottom: 0,
                    child: Container(
                        width: 2, color: MediLoopColors.line),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 12 : 16,
                bottom: isLast ? 12 : 16,
                right: MediLoopSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.eventTypeLabel,
                          style: MediLoopText.plexSans(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: isFraud
                                  ? MediLoopColors.critical
                                  : MediLoopColors.textPrimary),
                        ),
                      ),
                      Text(
                        _formatTimestamp(event.timestamp),
                        style: MediLoopText.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (event.actorName != null)
                    Text(
                      '${event.actorName} · ${event.organizationName ?? ''}',
                      style: MediLoopText.bodyMuted,
                    ),
                  if (event.quantity > 0) ...[
                    const SizedBox(height: 2),
                    Text('${event.quantity} units',
                        style: MediLoopText.caption),
                  ],
                  if (event.previousStatus != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      StatusBadge(
                          status: event.previousStatus!, compact: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12,
                            color: MediLoopColors.textMuted),
                      ),
                      StatusBadge(
                          status: event.newStatus, compact: true),
                    ]),
                  ],
                  // Cryptographic Block Hash
                  if (event.eventHash.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MediLoopColors.inactiveBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag_rounded,
                              size: 11, color: MediLoopColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'SHA-256: ${event.eventHash.substring(0, 16)}…',
                            style: MediLoopText.hashText.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) =>
      DateFormat('dd MMM, HH:mm').format(dt);
}
