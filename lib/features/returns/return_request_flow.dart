import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/router.dart';
import '../../models/medicine_batch.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/reverse_repository.dart';
import '../../repositories/confirmation_repository.dart';
import '../../services/auth_service.dart';
import '../../services/evidence_service.dart';
import '../../services/qr_service.dart';
import '../../services/gemini_service.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/lifecycle_pipeline.dart';

/// 4-step return request wizard.
class ReturnRequestFlow extends StatefulWidget {
  final String? initialBatchId;
  const ReturnRequestFlow({super.key, this.initialBatchId});

  @override
  State<ReturnRequestFlow> createState() => _ReturnRequestFlowState();
}

class _ReturnRequestFlowState extends State<ReturnRequestFlow> {
  int _step = 0;
  MedicineBatch? _selectedBatch;
  int _quantity = 0;
  String _reason = '';
  String? _proofImagePath;
  bool _qrVerified = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBatchId != null && widget.initialBatchId!.isNotEmpty) {
      _loadInitialBatch();
    }
  }

  Future<void> _loadInitialBatch() async {
    try {
      final repo = context.read<BatchRepository>();
      final b = await repo.getBatchById(widget.initialBatchId!);
      if (b != null && mounted) {
        setState(() {
          _selectedBatch = b;
          _quantity = b.currentQuantity;
          _step = 1;
        });
      }
    } catch (_) {}
  }

  void _handleBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.safePop(fallback: '/retailer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: MediLoopColors.paper,
        appBar: AppBar(
          title: Text(_stepTitle, style: MediLoopText.h4),
          leading: BackButton(onPressed: _handleBack),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / 5,
              backgroundColor: MediLoopColors.line,
              color: MediLoopColors.ink,
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _StepSelectBatch(
                  onSelect: (batch) {
                    setState(() {
                      _selectedBatch = batch;
                      _quantity = batch.currentQuantity;
                      _step = 1;
                    });
                  },
                ),
              1 => _StepQuantity(
                  batch: _selectedBatch!,
                  quantity: _quantity,
                  onChanged: (q) => setState(() => _quantity = q),
                  onNext: () => setState(() => _step = 2),
                ),
              2 => _StepReason(
                  onSelect: (r) {
                    setState(() {
                      _reason = r;
                      _step = 3;
                    });
                  },
                ),
              3 => _StepProof(
                  batch: _selectedBatch!,
                  onNext: (path, qrVerified) {
                    setState(() {
                      _proofImagePath = path;
                      _qrVerified = qrVerified;
                      _step = 4;
                    });
                  },
                ),
              4 => _StepReview(
                  batch: _selectedBatch!,
                  quantity: _quantity,
                  reason: _reason,
                  proofImagePath: _proofImagePath,
                  qrVerified: _qrVerified,
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
              _ => const SizedBox(),
            },
          ),
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        0 => 'Select batch',
        1 => 'Quantity',
        2 => 'Reason for return',
        3 => 'Attach proof',
        4 => 'Review & submit',
        _ => 'Return request',
      };

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      final reverseRepo = context.read<ReverseRepository>();
      final batchRepo = context.read<BatchRepository>();
      final evidenceService = context.read<EvidenceService>();
      final confRepo = context.read<ConfirmationRepository>();

      String? proofUrl;
      String? evidenceId;
      if (_proofImagePath != null) {
        final file = File(_proofImagePath!);
        final evidence = await evidenceService.submitEvidence(
          file: file,
          batchId: _selectedBatch!.id,
          actorId: auth.currentUser!.id,
          organizationId: auth.currentUser!.organizationId,
          qrVerified: _qrVerified,
          qrBatchIdFound: _qrVerified ? _selectedBatch!.id : null,
        );
        proofUrl = evidence.storagePath;
        evidenceId = evidence.id;
      }

      await reverseRepo.createRequest(
        batchId: _selectedBatch!.id,
        retailerId: auth.currentUser!.id,
        requestedQuantity: _quantity,
        reason: _reason,
        proofUrl: proofUrl,
      );

      // Create bilateral pending confirmation
      String? confirmationId;
      try {
        confirmationId = await confRepo.createPendingConfirmation(
          batchId: _selectedBatch!.id,
          requiredTransition: 'RETURN_INITIATED',
          senderOrgId: auth.currentUser!.organizationId,
          senderActorId: auth.currentUser!.id,
          senderEvidenceId: evidenceId,
        );
      } catch (e) {
        debugPrint('Pending confirmation notice: $e');
      }

      // Update batch status to RETURN_INITIATED (syncs to manufacturer pipeline & distributor in Supabase)
      await batchRepo.updateBatchStatus(
        batchId: _selectedBatch!.id,
        newStatus: 'RETURN_INITIATED',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'RETURN_INITIATED',
        quantity: _quantity,
        previousStatus: _selectedBatch!.status,
        confirmationId: confirmationId,
        evidenceId: evidenceId,
        originationPath: 'RETAIL_RETURN',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MediLoopColors.verified,
            content: Text('Return request submitted with tamper-evident proof. Synced to manufacturer & distributor.'),
          ),
        );
        context.safePop(fallback: '/retailer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text("Couldn't submit the return request: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─── Step 1: Select batch ─────────────────────────────────────────────────

class _StepSelectBatch extends StatefulWidget {
  final void Function(MedicineBatch) onSelect;
  const _StepSelectBatch({required this.onSelect});

  @override
  State<_StepSelectBatch> createState() => _StepSelectBatchState();
}

class _StepSelectBatchState extends State<_StepSelectBatch> {
  String _search = '';
  List<MedicineBatch> _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final repo = context.read<BatchRepository>();
    final all = await repo.getBatchesForPharmacy(auth.currentUser!.organizationId);
    if (!mounted) return;
    setState(() {
      // Only allow return initiation for batches physically still at pharmacy.
      // Any batch already in the return/disposal pipeline must NOT appear here.
      const returnable = {'ACTIVE', 'EXPIRED', 'EXPIRING_SOON'};
      _batches = all
          .where((b) => returnable.contains(b.status))
          .toList();
      // Sort: expired first, then expiring soon, then active
      _batches.sort((a, b) {
        int priority(MedicineBatch m) {
          if (m.isExpired) return 0;
          if (m.isExpiringSoon) return 1;
          return 2;
        }
        return priority(a).compareTo(priority(b));
      });
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _batches
        .where((b) =>
            _search.isEmpty ||
            b.displayName.toLowerCase().contains(_search.toLowerCase()) ||
            b.batchNumber.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name or batch number',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const EmptyState(
                      what: 'No eligible batches found.',
                      action:
                          'Only expired or expiring stock is shown here.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: MediLoopSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: MediLoopSpacing.sm),
                      itemBuilder: (_, i) => BatchCard(
                        batch: filtered[i],
                        onTap: () => widget.onSelect(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── Step 2: Quantity ──────────────────────────────────────────────────────

class _StepQuantity extends StatelessWidget {
  final MedicineBatch batch;
  final int quantity;
  final void Function(int) onChanged;
  final VoidCallback onNext;

  const _StepQuantity({
    required this.batch,
    required this.quantity,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MediLoopSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(batch.displayName, style: MediLoopText.h4),
                  const SizedBox(height: 4),
                  Text(batch.batchNumber, style: MediLoopText.batchCode),
                ],
              ),
            ),
          ),
          const SizedBox(height: MediLoopSpacing.xl),
          Text('Quantity to return', style: MediLoopText.label),
          const SizedBox(height: MediLoopSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                icon: Icons.remove,
                onTap: quantity > 1 ? () => onChanged(quantity - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$quantity',
                  style: MediLoopText.kpiNumber,
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onTap: quantity < batch.currentQuantity
                    ? () => onChanged(quantity + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Available: ${batch.currentQuantity} units',
              style: MediLoopText.caption,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                label: const Text('25%'),
                onPressed: () => onChanged(
                    (batch.currentQuantity * 0.25).ceil().clamp(1, batch.currentQuantity)),
              ),
              ActionChip(
                label: const Text('50%'),
                onPressed: () => onChanged(
                    (batch.currentQuantity * 0.50).ceil().clamp(1, batch.currentQuantity)),
              ),
              ActionChip(
                label: Text('All (${batch.currentQuantity})'),
                onPressed: () => onChanged(batch.currentQuantity),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: quantity > 0 ? onNext : null,
            child: const Text('Set quantity'),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null ? MediLoopColors.ink : MediLoopColors.line,
          ),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? MediLoopColors.ink
              : MediLoopColors.textMuted,
        ),
      ),
    );
  }
}

// ─── Step 3: Attach Proof ──────────────────────────────────────────────────

class _StepProof extends StatefulWidget {
  final MedicineBatch batch;
  final void Function(String imagePath, bool qrVerified) onNext;
  const _StepProof({required this.batch, required this.onNext});

  @override
  State<_StepProof> createState() => _StepProofState();
}

class _StepProofState extends State<_StepProof> {
  String? _imagePath;
  bool _qrVerified = false;
  bool _picking = false;
  bool _analyzing = false;
  String? _validationError;
  String? _packagingType;

  Future<void> _captureEvidence([ImageSource source = ImageSource.camera]) async {
    if (_picking || _analyzing) return;
    setState(() {
      _picking = true;
      _validationError = null;
    });
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null) {
        if (mounted) setState(() => _picking = false);
        return;
      }

      setState(() {
        _picking = false;
        _analyzing = true;
      });

      final imageFile = File(picked.path);

      // 1. QR code check
      final qrResult = await QrService.decodeFromFile(imageFile);
      final decodedBatchId =
          qrResult != null ? QrService.decodeBatchQr(qrResult) : null;

      bool verified = false;
      if (decodedBatchId == widget.batch.id) {
        verified = true;
      } else if (decodedBatchId != null) {
        if (mounted) {
          setState(() {
            _analyzing = false;
            _validationError =
                'QR / batch mismatch: The QR code belongs to a different batch ($decodedBatchId). Please photograph batch ${widget.batch.batchNumber}.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MediLoopColors.critical,
              content: Text(
                  'QR / batch mismatch. This photo cannot be attached to this batch.'),
            ),
          );
        }
        return;
      }

      // 2. AI Packaging & Medicine Strip Verification
      if (!mounted) return;
      final gemini = context.read<GeminiService>();
      final validation = await gemini.validateMedicinePackaging(
        imageFile,
        expectedMedicineName: widget.batch.medicineName,
        expectedBatchNumber: widget.batch.batchNumber,
      );

      if (!mounted) return;

      if (!validation.isValid) {
        setState(() {
          _imagePath = null;
          _qrVerified = false;
          _analyzing = false;
          _validationError = validation.message;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    validation.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // 3. Valid packaging
      setState(() {
        _imagePath = picked.path;
        _qrVerified = verified;
        _packagingType = validation.packagingType;
        _analyzing = false;
        _validationError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.verified,
            duration: const Duration(seconds: 3),
            content: Text(
              verified
                  ? '✓ Batch QR verified in medicine packaging frame.'
                  : '✓ Physical proof verified: ${_packagingType ?? "Medicine Strip"}. Cryptographically anchored.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Proof capture/validation error: $e');
      if (mounted) {
        setState(() {
          _analyzing = false;
          _validationError =
              'Failed to analyze packaging photo. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          _analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MediLoopSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MediLoopColors.ink.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MediLoopColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 18, color: MediLoopColors.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Capture a live photo of the batch packaging, blister strip, or bottle. '
                    'AI packaging inspection and SHA-256 cryptographic hashing are enforced under CDSCO return compliance.',
                    style:
                        MediLoopText.inter(size: 13, color: MediLoopColors.ink),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: MediLoopSpacing.lg),

          // Validation error alert banner
          if (_validationError != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MediLoopColors.criticalBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MediLoopColors.critical.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: MediLoopColors.critical, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Packaging Verification Failed',
                          style: TextStyle(
                            color: MediLoopColors.critical,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _validationError!,
                          style: const TextStyle(
                            color: MediLoopColors.textPrimary,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),
          ],

          // Image preview or placeholder
          GestureDetector(
            onTap: (_picking || _analyzing || _imagePath != null)
                ? null
                : () => _captureEvidence(ImageSource.camera),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: MediLoopColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _validationError != null
                      ? MediLoopColors.critical
                      : (_imagePath != null
                          ? MediLoopColors.verified
                          : MediLoopColors.line),
                  width: (_validationError != null || _imagePath != null)
                      ? 2
                      : 1,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: _imagePath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_imagePath!), fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _qrVerified
                                  ? MediLoopColors.verified
                                  : const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    _qrVerified
                                        ? Icons.qr_code_scanner
                                        : Icons.verified,
                                    size: 13,
                                    color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  _qrVerified
                                      ? 'QR Verified in Frame'
                                      : (_packagingType ?? 'Medicine Strip Verified'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_picking || _analyzing) ...[
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _analyzing
                                ? 'AI analyzing packaging...'
                                : 'Opening camera...',
                            style: MediLoopText.bodyMuted,
                          ),
                          if (_analyzing) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Verifying pharmaceutical blister strip & authenticity',
                              style: MediLoopText.caption,
                            ),
                          ],
                        ] else ...[
                          Icon(
                            _validationError != null
                                ? Icons.no_photography_outlined
                                : Icons.add_a_photo_outlined,
                            size: 36,
                            color: _validationError != null
                                ? MediLoopColors.critical
                                : MediLoopColors.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _validationError != null
                                ? 'Tap below to capture a valid medicine strip'
                                : 'Tap to photograph blister strip or packaging',
                            style: MediLoopText.bodyMuted,
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          const SizedBox(height: MediLoopSpacing.md),

          // Dual Camera & Gallery Capture Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(_imagePath == null ? 'Take Photo' : 'Retake'),
                  onPressed: (_picking || _analyzing)
                      ? null
                      : () => _captureEvidence(ImageSource.camera),
                ),
              ),
              const SizedBox(width: MediLoopSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Pick from Gallery'),
                  onPressed: (_picking || _analyzing)
                      ? null
                      : () => _captureEvidence(ImageSource.gallery),
                ),
              ),
            ],
          ),

          const SizedBox(height: MediLoopSpacing.xl),

          ElevatedButton(
            onPressed: (_imagePath != null &&
                    _validationError == null &&
                    !_analyzing)
                ? () => widget.onNext(_imagePath!, _qrVerified)
                : null,
            child: const Text('Continue with proof photo'),
          ),
          const SizedBox(height: MediLoopSpacing.lg),
        ],
      ),
    );
  }
}

// ─── Step 4: Reason ────────────────────────────────────────────────────────

class _StepReason extends StatelessWidget {
  final void Function(String) onSelect;

  const _StepReason({required this.onSelect});

  static const _reasons = [
    ('EXPIRED', Icons.event_busy_outlined, 'Expired'),
    ('DAMAGED', Icons.broken_image_outlined, 'Damaged'),
    ('RECALLED', Icons.campaign_outlined, 'Recalled'),
    ('OTHER', Icons.more_horiz, 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MediLoopSpacing.md),
      child: Column(
        children: _reasons
            .map((r) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: Card(
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(MediLoopRadius.card),
                      onTap: () => onSelect(r.$1),
                      child: Padding(
                        padding: const EdgeInsets.all(MediLoopSpacing.lg),
                        child: Row(
                          children: [
                            Icon(r.$2,
                                size: 24, color: MediLoopColors.ink),
                            const SizedBox(width: 16),
                            Text(r.$3, style: MediLoopText.h4),
                            const Spacer(),
                            const Icon(Icons.chevron_right,
                                color: MediLoopColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Step 5: Review ────────────────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  final MedicineBatch batch;
  final int quantity;
  final String reason;
  final String? proofImagePath;
  final bool qrVerified;
  final bool submitting;
  final VoidCallback onSubmit;

  const _StepReview({
    required this.batch,
    required this.quantity,
    required this.reason,
    this.proofImagePath,
    this.qrVerified = false,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MediLoopSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pipeline showing chain of custody
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined, size: 16, color: MediLoopColors.ink),
                      const SizedBox(width: 8),
                      Text('Chain of custody', style: MediLoopText.label),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MediLoopColors.accentBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MediLoopColors.accent.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Stage 2 of 6: Ongoing Return',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: MediLoopColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MediLoopSpacing.md),
                  const LifecyclePipeline(completedStage: 1, showDetails: true),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MediLoopColors.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MediLoopColors.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 15, color: MediLoopColors.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Submitting declares return with tamper-evident proof and awaits distributor bilateral confirmation.',
                            style: MediLoopText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MediLoopSpacing.md),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewRow('Medicine', batch.displayName),
                  _ReviewRow('Batch number', batch.batchNumber,
                      mono: true),
                  _ReviewRow('Quantity', '$quantity units'),
                  _ReviewRow('Reason', _reasonLabel(reason)),
                  _ReviewRow(
                    'Proof photo',
                    proofImagePath != null
                        ? (qrVerified ? '✓ QR Verified & Attached' : '✓ Physical Packaging Proof (SHA-256 Hashed)')
                        : '⚠ Not attached',
                  ),
                ],
              ),
            ),
          ),

          // Proof image thumbnail
          if (proofImagePath != null) ...[
            const SizedBox(height: MediLoopSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(proofImagePath!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          const SizedBox(height: MediLoopSpacing.lg),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('submit_return_btn'),
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit return request'),
            ),
          ),
          const SizedBox(height: MediLoopSpacing.xl),
        ],
      ),
    );
  }

  String _reasonLabel(String r) => switch (r) {
        'EXPIRED' => 'Expired',
        'DAMAGED' => 'Damaged',
        'RECALLED' => 'Recalled',
        _ => 'Other',
      };
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _ReviewRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: MediLoopText.labelMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? MediLoopText.batchCode
                      .copyWith(color: MediLoopColors.textPrimary)
                  : MediLoopText.body,
            ),
          ),
        ],
      ),
    );
  }
}
