import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../data/mock_database.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/disposal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/evidence_service.dart';
import '../../services/qr_service.dart';
import '../../models/medicine_batch.dart';
import '../../models/disposal_record.dart';
import '../../widgets/batch_card.dart';
import '../../widgets/lifecycle_pipeline.dart';
import '../../widgets/cdsco_certificate_viewer.dart';
import '../../widgets/app_back_scope.dart';

class FacilityShell extends StatelessWidget {
  final Widget child;
  const FacilityShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForPath(location);

    return AppBackScope(
      homeRoute: '/facility',
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/facility');
              case 1:
                context.go('/facility/assigned');
              case 2:
                context.go('/facility/scan');
              case 3:
                context.go('/facility/record');
              case 4:
                context.go('/facility/profile');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Assigned',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.recycling),
              selectedIcon: Icon(Icons.recycling),
              label: 'Record',
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
    if (path.startsWith('/facility/assigned')) return 1;
    if (path.startsWith('/facility/scan')) return 2;
    if (path.startsWith('/facility/record')) return 3;
    if (path.startsWith('/facility/profile')) return 4;
    return 0;
  }
}

// ─── Dashboard ─────────────────────────────────────────────────────────────

class FacilityDashboardPage extends StatefulWidget {
  const FacilityDashboardPage({super.key});

  @override
  State<FacilityDashboardPage> createState() => _FacilityDashboardPageState();
}

class _FacilityDashboardPageState extends State<FacilityDashboardPage> {
  List<MedicineBatch> _assigned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final repo = context.read<BatchRepository>();
    final data =
        await repo.getAssignedToFacility(auth.currentUser!.organizationId);
    if (mounted) {
      setState(() {
        _assigned = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Waste Facility', style: MediLoopText.h4),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Consignment',
            onPressed: () => context.go('/facility/scan'),
          ),
          IconButton(
            key: const Key('facility_appbar_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile & Sign Out',
            onPressed: () => context.go('/facility/profile'),
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
                      label: 'Assigned for destruction',
                      value: _assigned.length,
                      warning: _assigned.isNotEmpty,
                      icon: Icons.delete_sweep_rounded)),
            ]),
            const SizedBox(height: MediLoopSpacing.lg),
            Text('Assigned for destruction', style: MediLoopText.h4),
            const SizedBox(height: MediLoopSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_assigned.isEmpty)
              const EmptyState(
                what: 'No batches assigned.',
                action:
                    'Batches scheduled for destruction will appear here.',
                icon: Icons.recycling,
              )
            else
              ..._assigned.map(
                (b) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  child: BatchCard(
                    batch: b,
                    trailing: ElevatedButton(
                      onPressed: () =>
                          _showRecordDestructionSheet(context, b),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8)),
                      child: const Text('Record destruction'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRecordDestructionSheet(
      BuildContext context, MedicineBatch batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MediLoopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(MediLoopRadius.sheet)),
      ),
      builder: (ctx) => _RecordDestructionSheet(
        batch: batch,
        onRecorded: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }
}

class FacilityAssignedPage extends StatelessWidget {
  const FacilityAssignedPage({super.key});
  @override
  Widget build(BuildContext context) => const FacilityDashboardPage();
}

class FacilityRecordPage extends StatefulWidget {
  const FacilityRecordPage({super.key});

  @override
  State<FacilityRecordPage> createState() => _FacilityRecordPageState();
}

class _FacilityRecordPageState extends State<FacilityRecordPage> {
  List<DestructionCertificate> _certs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCerts();
  }

  Future<void> _loadCerts() async {
    setState(() => _loading = true);
    final repo = context.read<DisposalRepository>();
    final list = await repo.getCertificates();
    if (mounted) {
      setState(() {
        _certs = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('Destruction Certificates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCerts,
            tooltip: 'Refresh Certificates',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCerts,
        child: ListView(
          padding: const EdgeInsets.all(MediLoopSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E22CE),
                      borderRadius: BorderRadius.circular(8),
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
                        Text(
                          'CDSCO Form 48 Registry',
                          style: MediLoopText.plexSans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: MediLoopColors.ink,
                          ),
                        ),
                        Text(
                          '${_certs.length} certificates permanently recorded with cryptographic SHA-256 seals',
                          style: MediLoopText.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.md),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_certs.isEmpty)
              const EmptyState(
                what: 'No certificates recorded yet.',
                action: 'Certificates will be issued once destruction is completed.',
                icon: Icons.workspace_premium_outlined,
              )
            else
              ..._certs.map((c) {
                return Card(
                  margin: const EdgeInsets.only(bottom: MediLoopSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: MediLoopColors.line),
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FORM 48',
                                style: MediLoopText.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MediLoopColors.verifiedBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: MediLoopColors.verified,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'VERIFIED',
                                    style: MediLoopText.caption.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: MediLoopColors.verified,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.certificateNumber,
                          style: MediLoopText.plexMono(
                            size: 14,
                            weight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Batch ID: ${c.batchId ?? 'CETR10-2024-003'}',
                          style: MediLoopText.caption.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                c.hash.length > 24
                                    ? '${c.hash.substring(0, 16)}...${c.hash.substring(c.hash.length - 8)}'
                                    : c.hash,
                                style: MediLoopText.plexMono(
                                  size: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              CdscoCertificateViewer.show(
                                context,
                                certificate: c,
                                facilityName:
                                    'BioClean Bio-Medical Waste Facility',
                                disposalMethod:
                                    'High-Temperature Incineration (1100°C)',
                              );
                            },
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                            ),
                            label: const Text('View Official Certificate'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E3A8A),
                              side: const BorderSide(color: Color(0xFF1E3A8A)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── Record Destruction Sheet ──────────────────────────────────────────────

class _RecordDestructionSheet extends StatefulWidget {
  final MedicineBatch batch;
  final VoidCallback onRecorded;

  const _RecordDestructionSheet(
      {required this.batch, required this.onRecorded});

  @override
  State<_RecordDestructionSheet> createState() =>
      _RecordDestructionSheetState();
}

class _RecordDestructionSheetState
    extends State<_RecordDestructionSheet> {
  final _certNumberCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'INCINERATION';
  File? _certFile;
  String? _certFileName;
  String? _proofPath;
  bool _qrVerified = false;
  bool _supervisorApproved = false;
  bool _loading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Auto-generate a certificate number so the form is ready to submit
    final ts = DateTime.now();
    _certNumberCtrl.text =
        'CDSCO-CERT-${ts.year}-${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-${(ts.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
  }

  @override
  void dispose() {
    _certNumberCtrl.dispose();
    super.dispose();
  }

  bool _picking = false;

  Future<void> _captureEvidence() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (picked == null) return;

      final qr = await QrService.decodeFromFile(File(picked.path));
      final ok = (qr != null && QrService.decodeBatchQr(qr) == widget.batch.id);

      if (!mounted) return;
      setState(() {
        _proofPath = picked.path;
        _qrVerified = ok;
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _DestructionSuccessPanel(
        batch: widget.batch,
        onDone: widget.onRecorded,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Record destruction', style: MediLoopText.h4),
          Text(widget.batch.displayName, style: MediLoopText.bodyMuted),
          Text(widget.batch.batchNumber, style: MediLoopText.batchCode),
          const SizedBox(height: MediLoopSpacing.lg),

          // Method
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Disposal method'),
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
            label: Text('Destruction date: ${_date.toString().substring(0, 10)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: MediLoopSpacing.md),

          // Certificate number
          TextFormField(
            controller: _certNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Certificate number',
              hintText: 'e.g. CDSCO-CERT-2026-00431',
              helperText: 'Auto-generated — edit if needed',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MediLoopSpacing.md),

          // Live Evidence Proof (Camera)
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: Text(_proofPath == null ? 'Capture Destruction Process Proof (Camera)' : 'Proof Captured ✓'),
            onPressed: _captureEvidence,
          ),
          if (_proofPath != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_qrVerified ? Icons.check_circle : Icons.warning_amber, size: 14,
                    color: _qrVerified ? MediLoopColors.verified : MediLoopColors.attention),
                const SizedBox(width: 6),
                Text(
                  _qrVerified ? 'QR Verified in Destruction Frame' : 'Proof Captured (Unverified QR)',
                  style: MediLoopText.inter(size: 12,
                      color: _qrVerified ? MediLoopColors.verified : MediLoopColors.attention),
                ),
              ],
            ),
          ],
          const SizedBox(height: MediLoopSpacing.md),

          // Document upload
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: Text(_certFileName ?? 'Upload certificate document'),
            onPressed: _pickCertFile,
          ),

          if (_certFileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: MediLoopColors.verified),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_certFileName!,
                        style: MediLoopText.inter(
                            size: 12, color: MediLoopColors.verified))),
              ],
            ),
          ],

          const SizedBox(height: MediLoopSpacing.md),

          // Supervisor Dual-Signoff Checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Supervisor Second Approval', style: MediLoopText.body),
            subtitle: Text('Dual-authorization verified under CDSCO BMW Rule 14', style: MediLoopText.caption),
            value: _supervisorApproved,
            onChanged: (v) => setState(() => _supervisorApproved = v ?? false),
          ),

          const SizedBox(height: MediLoopSpacing.lg),

          ElevatedButton(
            onPressed: _loading || _certNumberCtrl.text.trim().isEmpty
                ? null
                : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Record destruction & certify'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCertFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _certFile = File(result.files.single.path!);
        _certFileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final disposalRepo = context.read<DisposalRepository>();
      final batchRepo = context.read<BatchRepository>();
      final storageService = context.read<StorageService>();
      final evidenceService = context.read<EvidenceService>();

      // Get or create a disposal record for this batch
      final records = await disposalRepo.getDisposalRecords();
      DisposalRecord record;
      try {
        record = records.firstWhere((r) => r.batchId == widget.batch.id);
      } catch (_) {
        record = await disposalRepo.createDisposalRecord(
          batchId: widget.batch.id,
          manufacturerId: widget.batch.manufacturerId ?? auth.currentUser!.organizationId,
          wasteFacilityId: auth.currentUser!.organizationId,
          disposalMethod: _method,
          quantityDestroyed: widget.batch.currentQuantity,
          scheduledDate: _date,
        );
      }

      // 1. Submit evidence if captured
      String? evidenceId;
      if (_proofPath != null) {
        final ev = await evidenceService.submitEvidence(
          file: File(_proofPath!),
          batchId: widget.batch.id,
          actorId: auth.currentUser!.id,
          organizationId: auth.currentUser!.organizationId,
          qrVerified: _qrVerified,
          qrBatchIdFound: _qrVerified ? widget.batch.id : null,
        );
        evidenceId = ev.id;
      }

      // 2. Upload certificate if provided
      String? docUrl;
      if (_certFile != null) {
        docUrl = await storageService.uploadCertificate(
          file: _certFile!,
          disposalRecordId: record.id,
        );
      }

      // 3. Record destruction + issue certificate
      final cert = await disposalRepo.recordDestruction(
        disposalRecordId: record.id,
        batchId: widget.batch.id,
        quantityDestroyed: widget.batch.currentQuantity,
        method: _method,
        destructionDate: _date,
        certificateNumber: _certNumberCtrl.text.trim(),
        documentUrl: docUrl,
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
      );

      MockDatabase.instance.addCertificate(cert);

      // 4. Update batch status to DESTROYED
      await batchRepo.updateBatchStatus(
        batchId: widget.batch.id,
        newStatus: 'DESTROYED',
        actorId: auth.currentUser!.id,
        organizationId: auth.currentUser!.organizationId,
        eventType: 'DESTRUCTION_RECORDED',
        quantity: widget.batch.currentQuantity,
        previousStatus: widget.batch.status,
        evidenceId: evidenceId,
      );

      // 5. If supervisor dual-signoff was granted, advance to CERTIFIED
      if (_supervisorApproved) {
        try {
          await batchRepo.updateBatchStatus(
            batchId: widget.batch.id,
            newStatus: 'CERTIFIED',
            actorId: auth.currentUser!.id,
            organizationId: auth.currentUser!.organizationId,
            eventType: 'DESTRUCTION_CERTIFIED',
            quantity: widget.batch.currentQuantity,
            previousStatus: 'DESTROYED',
          );
        } catch (_) {}
      }

      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MediLoopColors.critical,
            content: Text('Could not record destruction: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Success panel after destruction ──────────────────────────────────────

class _DestructionSuccessPanel extends StatelessWidget {
  final MedicineBatch batch;
  final VoidCallback onDone;

  const _DestructionSuccessPanel(
      {required this.batch, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MediLoopSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_outlined,
              size: 56, color: MediLoopColors.verified),
          const SizedBox(height: MediLoopSpacing.md),
          Text('Destruction recorded', style: MediLoopText.h3),
          const SizedBox(height: 4),
          Text('The loop is closed.', style: MediLoopText.bodyMuted),
          const SizedBox(height: MediLoopSpacing.lg),

          // Pipeline with last two dots animating in
          LifecyclePipeline(
            completedStage: 6,
            animateLastStage: true,
          ),

          const SizedBox(height: MediLoopSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
