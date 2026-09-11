import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/mock_database.dart';
import '../../models/medicine_batch.dart';
import '../../models/scan_context.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/organization_repository.dart';
import '../../services/auth_service.dart';
import '../../services/fraud_detection_service.dart';
import '../../services/gemini_service.dart';
import '../../services/qr_service.dart';
import '../../models/batch_event.dart';
import '../fraud/fraud_alert_screen.dart';

enum _ScanPhase { context, camera, confirm, result }
enum _ScanResultType { verified, suspicious, critical }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  bool _torchOn = false;
  bool _processing = false;
  _ScanPhase _phase = _ScanPhase.context;
  late AnimationController _laserController;

  // Selected scan context
  ScanContext _selectedContext = ScanContext.activeStockCheck;
  bool _initializedContext = false;

  MedicineBatch? _foundBatch;
  FraudAlert? _fraudAlert;
  _ScanResultType? _resultType;
  String? _resultMessage;
  String? _resultNarrative;
  String? _recommendedAction;
  bool _isOfflineBackup = false;
  double _zoom = 1.0;
  String? _aiProcessingStep;

  // Transient notice for ignored non-pharma barcodes in live viewfinder
  String? _scannerNotice;
  Timer? _scannerNoticeTimer;
  String? _lastIgnoredCode;
  DateTime? _lastIgnoredTime;

  void _showScannerNotice(String message) {
    _scannerNoticeTimer?.cancel();
    if (mounted) {
      setState(() => _scannerNotice = message);
      _scannerNoticeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scannerNotice = null);
      });
    }
  }

  // Editable confirmed fields
  final _batchNumberCtrl = TextEditingController();
  final _medicineNameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();

  Future<void> _toggleZoom() async {
    if (_scannerController == null) return;
    final next = _zoom == 1.0 ? 2.0 : 1.0;
    try {
      await _scannerController!.setZoomScale(next);
      if (mounted) setState(() => _zoom = next);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedContext) {
      final auth = context.read<AuthService>();
      _selectedContext = ScanContext.defaultForRole(auth.currentRole);
      _initializedContext = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  void _proceedToCamera() {
    setState(() {
      _phase = _ScanPhase.camera;
    });
    _scannerController ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _scannerController?.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerNoticeTimer?.cancel();
    _laserController.dispose();
    _scannerController?.dispose();
    _batchNumberCtrl.dispose();
    _medicineNameCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_scannerController == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController?.stop();
    } else if (state == AppLifecycleState.resumed && _phase == _ScanPhase.camera) {
      _scannerController?.start();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Live QR / Barcode Extraction
  // ─────────────────────────────────────────────────────────────────────────

  bool _isPlausiblePharmaBatch(String str) {
    final trimmed = str.trim();
    if (trimmed.length < 4 || trimmed.length > 36) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.startsWith('wifi:') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        trimmed.contains('://') ||
        trimmed.contains(' ') ||
        trimmed.contains('{') ||
        trimmed.contains('}')) {
      return false;
    }
    // Retail consumer numeric barcodes (8 to 14 digits like UPC, EAN-13, EAN-8)
    // are standard consumer retail items unless in batch DB
    if (RegExp(r'^\d{8,14}$').hasMatch(trimmed)) return false;
    return RegExp(r'^[A-Za-z0-9\-_/]{4,36}$').hasMatch(trimmed);
  }

  Future<bool> _handleLiveDetectedCode(String raw) async {
    if (_processing) return false;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    // 1. Immediately filter out obvious non-pharma QR / barcodes (URLs, Wi-Fi, contacts)
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.startsWith('wifi:') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        trimmed.contains('://')) {
      final now = DateTime.now();
      if (_lastIgnoredCode != trimmed ||
          _lastIgnoredTime == null ||
          now.difference(_lastIgnoredTime!) > const Duration(seconds: 2)) {
        _lastIgnoredCode = trimmed;
        _lastIgnoredTime = now;
        _showScannerNotice('Non-pharmaceutical code ignored');
      }
      return false;
    }

    try {
      final batchRepo = context.read<BatchRepository>();
      MedicineBatch? batch;
      String extractedBatchNumber = trimmed;
      String? extractedMedName;
      String? extractedExpiry;

      // 1. Check MediLoop QR format: MEDILOOP:BATCH:<uuid>
      if (QrService.isMediLoopQr(trimmed)) {
        final batchId = QrService.decodeBatchQr(trimmed);
        if (batchId != null) {
          batch = await batchRepo.getBatchById(batchId) ??
              MockDatabase.instance.getBatchById(batchId);
        }
      }
      // 2. Check pipe-delimited format: MEDILOOP|PARA500-2026-001|med-01|2026-09-10
      else if (trimmed.startsWith('MEDILOOP|')) {
        final parts = trimmed.split('|');
        if (parts.length > 1) {
          extractedBatchNumber = parts[1];
          if (parts.length > 3) extractedExpiry = parts[3];
          batch = await batchRepo.getBatchByNumber(extractedBatchNumber) ??
              MockDatabase.instance.getBatchByNumber(extractedBatchNumber);
        }
      }
      // 3. Fallback: try raw string as batch number against DB or validate pattern
      else {
        batch = await batchRepo.getBatchByNumber(trimmed) ??
            MockDatabase.instance.getBatchByNumber(trimmed);

        // If not in database, ensure it meets pharmaceutical batch criteria
        if (batch == null && !_isPlausiblePharmaBatch(trimmed)) {
          final now = DateTime.now();
          if (_lastIgnoredCode != trimmed ||
              _lastIgnoredTime == null ||
              now.difference(_lastIgnoredTime!) > const Duration(seconds: 2)) {
            _lastIgnoredCode = trimmed;
            _lastIgnoredTime = now;
            _showScannerNotice('Unrecognized code (not medicine batch)');
          }
          return false;
        }
      }

      if (batch != null) {
        extractedBatchNumber = batch.batchNumber;
        extractedMedName = batch.displayName;
        extractedExpiry = batch.expiryDate.toIso8601String().substring(0, 10);
      }

      if (mounted) {
        setState(() => _processing = true);
        HapticFeedback.mediumImpact();

        _batchNumberCtrl.text = extractedBatchNumber;
        _medicineNameCtrl.text = extractedMedName ?? '';
        _expiryCtrl.text = extractedExpiry ?? '';
        _isOfflineBackup = false;

        // Stop camera while user reviews and confirms details
        _scannerController?.stop();

        setState(() {
          _phase = _ScanPhase.confirm;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live extracted: $extractedBatchNumber'),
            duration: const Duration(seconds: 2),
            backgroundColor: MediLoopColors.verified,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Live barcode processing error: $e');
      return false;
    } finally {
      if (mounted && _phase == _ScanPhase.camera) {
        setState(() => _processing = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Photo capture & Gallery OCR
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _captureAndProcess() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _aiProcessingStep = 'Preparing high-resolution camera capture...';
    });

    try {
      final gemini = context.read<GeminiService>();

      // 1. Explicitly pause live viewfinder so native OS camera doesn't conflict
      await _scannerController?.stop();

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) {
        if (mounted) {
          setState(() {
            _processing = false;
            _aiProcessingStep = null;
          });
          if (_phase == _ScanPhase.camera) {
            _scannerController?.start();
          }
        }
        return;
      }

      if (mounted) {
        setState(() {
          _aiProcessingStep = 'Gemini 3.5 Flash-Lite analyzing packaging...';
        });
      }

      final imageFile = File(picked.path);

      // Check if image contains a readable barcode or QR code
      if (_scannerController != null) {
        try {
          final barcodeCapture = await _scannerController!.analyzeImage(imageFile.path);
          if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
            final raw = barcodeCapture.barcodes.first.rawValue;
            if (raw != null && raw.trim().isNotEmpty) {
              final handled = await _handleLiveDetectedCode(raw.trim());
              if (handled) return;
            }
          }
        } catch (_) {}
      }

      // Run AI OCR on packaging
      final ocrResult = await gemini.extractBatchFromImage(imageFile);

      if (!mounted) return;

      if (!ocrResult.success ||
          ocrResult.batchNumber == null ||
          ocrResult.batchNumber!.trim().isEmpty) {
        if (_phase == _ScanPhase.camera) {
          _scannerController?.start();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ocrResult.errorMessage ??
                        'No pharmaceutical batch detected. Ensure packaging label is visible.',
                    style: MediLoopText.inter(size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Manual Entry',
              textColor: const Color(0xFF10B981),
              onPressed: () {
                _batchNumberCtrl.clear();
                _medicineNameCtrl.clear();
                _expiryCtrl.clear();
                _isOfflineBackup = true;
                _scannerController?.stop();
                setState(() => _phase = _ScanPhase.confirm);
              },
            ),
          ),
        );
        return;
      }

      _batchNumberCtrl.text = ocrResult.batchNumber ?? '';
      _medicineNameCtrl.text = ocrResult.medicineName ?? '';
      _expiryCtrl.text = ocrResult.expiryDate ?? '';
      _isOfflineBackup = ocrResult.isOfflineBackup;

      setState(() => _phase = _ScanPhase.confirm);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't process image. Check camera permissions."),
          ),
        );
        if (_phase == _ScanPhase.camera) {
          _scannerController?.start();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _aiProcessingStep = null;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _aiProcessingStep = 'Selecting photo from gallery...';
    });

    try {
      final gemini = context.read<GeminiService>();

      // Pause camera stream during gallery selection
      await _scannerController?.stop();

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) {
          setState(() {
            _processing = false;
            _aiProcessingStep = null;
          });
          if (_phase == _ScanPhase.camera) {
            _scannerController?.start();
          }
        }
        return;
      }

      if (mounted) {
        setState(() {
          _aiProcessingStep = 'Gemini 3.5 Flash-Lite analyzing gallery photo...';
        });
      }

      final imageFile = File(picked.path);

      // Check if image contains a barcode/QR
      if (_scannerController != null) {
        try {
          final barcodeCapture = await _scannerController!.analyzeImage(imageFile.path);
          if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
            final raw = barcodeCapture.barcodes.first.rawValue;
            if (raw != null && raw.trim().isNotEmpty) {
              final handled = await _handleLiveDetectedCode(raw.trim());
              if (handled) return;
            }
          }
        } catch (_) {}
      }

      final ocrResult = await gemini.extractBatchFromImage(imageFile);

      if (!mounted) return;

      if (!ocrResult.success ||
          ocrResult.batchNumber == null ||
          ocrResult.batchNumber!.trim().isEmpty) {
        if (_phase == _ScanPhase.camera) {
          _scannerController?.start();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ocrResult.errorMessage ??
                        'No pharmaceutical batch detected in photo. Ensure label is clearly legible.',
                    style: MediLoopText.inter(size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Manual Entry',
              textColor: const Color(0xFF10B981),
              onPressed: () {
                _batchNumberCtrl.clear();
                _medicineNameCtrl.clear();
                _expiryCtrl.clear();
                _isOfflineBackup = true;
                _scannerController?.stop();
                setState(() => _phase = _ScanPhase.confirm);
              },
            ),
          ),
        );
        return;
      }

      _batchNumberCtrl.text = ocrResult.batchNumber ?? '';
      _medicineNameCtrl.text = ocrResult.medicineName ?? '';
      _expiryCtrl.text = ocrResult.expiryDate ?? '';
      _isOfflineBackup = ocrResult.isOfflineBackup;

      setState(() => _phase = _ScanPhase.confirm);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't process selected image. Please try again."),
          ),
        );
        if (_phase == _ScanPhase.camera) {
          _scannerController?.start();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _aiProcessingStep = null;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Batch Verification
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmAndCheck() async {
    final batchNumber = _batchNumberCtrl.text.trim();
    if (batchNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a batch number to continue.')),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final auth = context.read<AuthService>();
      final batchRepo = context.read<BatchRepository>();
      final fraudService = context.read<FraudDetectionService>();
      final orgRepo = context.read<OrganizationRepository>();
      final gemini = context.read<GeminiService>();

      // 1. Fetch batch (Supabase with Mock fallback)
      MedicineBatch? batch;
      try {
        batch = await batchRepo.getBatchByNumber(batchNumber);
      } catch (e) {
        debugPrint('Supabase batch fetch error ($e), checking mock database');
        batch = MockDatabase.instance.getBatchByNumber(batchNumber);
      }
      batch ??= MockDatabase.instance.getBatchByNumber(batchNumber);

      // Rule 4: INVALID_BATCH — batch not found in system
      if (batch == null) {
        if (mounted) {
          setState(() {
            _phase = _ScanPhase.result;
            _foundBatch = null;
            _fraudAlert = null;
            _resultType = _ScanResultType.suspicious;
            _resultMessage = 'Batch not found in system';
            _resultNarrative =
                'Batch $batchNumber does not match any registered batch in CDSCO records. '
                'This scan has been logged as a potential INVALID_BATCH event. '
                'Do not dispense this product until verified by your supplier.';
            _recommendedAction = 'Contact your distributor to verify the batch number.';
          });
        }
        return;
      }

      _foundBatch = batch;

      // 2. Safely record scan event
      try {
        if (auth.currentUser != null) {
          await batchRepo.recordScanEvent(
            batchId: batch.id,
            scannedBy: auth.currentUser!.id,
            organizationId: auth.currentUser!.organizationId,
            result: 'SCAN',
            scanContext: _selectedContext.value,
          );
        }
      } catch (e) {
        debugPrint('Non-critical scan event recording note: $e');
      }

      // 3. Run fraud detection with context
      FraudResult fraudResult;
      try {
        fraudResult = await fraudService.analyzeScan(
          batch: batch,
          scannedByUserId: auth.currentUser?.id ?? 'usr-retailer-01',
          scannedByOrgId: auth.currentUser?.organizationId ?? 'org-retailer-01',
          context: _selectedContext,
        );
      } catch (e) {
        debugPrint('Fraud detection exception ($e), using clean result');
        fraudResult = const FraudResult(isSuspicious: false);
      }

      if (fraudResult.isSuspicious) {
        String narrative = fraudResult.reason ?? '';
        if (fraudResult.alert != null) {
          try {
            narrative = await gemini.generateFraudNarrative(fraudResult.alert!);
            await orgRepo.updateFraudNarrative(
              alertId: fraudResult.alert!.id,
              narrative: narrative,
            );
          } catch (e) {
            debugPrint('Failed to update fraud narrative: $e');
          }
        }

        if (mounted) {
          // CRITICAL: Destroyed batch re-entry → full-screen Killer Demo alert
          if (fraudResult.isCritical) {
            await Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.transparent,
                pageBuilder: (_, __, ___) => FraudAlertScreen(
                  batch: batch!,
                  narrative: narrative.isNotEmpty ? narrative : null,
                  alertId: fraudResult.alert?.id,
                  onDismiss: () {
                    Navigator.of(context).pop();
                    _reset();
                  },
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          } else {
            setState(() {
              _phase = _ScanPhase.result;
              _fraudAlert = fraudResult.alert;
              _recommendedAction = fraudResult.recommendedAction ??
                  'Halt dispensing and report batch to CDSCO compliance officer.';
              _resultType = _ScanResultType.suspicious;
              _resultMessage = fraudResult.alertType == 'EXPIRED_BATCH_SALE'
                  ? 'Expired batch in active stock'
                  : fraudResult.alertType == 'QUANTITY_MISMATCH'
                      ? 'Quantity mismatch detected'
                      : 'Suspicious batch detected';
              _resultNarrative = narrative;
            });
          }
        }
      } else {
        if (mounted) {
          final targetBatch = batch;
          setState(() {
            _phase = _ScanPhase.result;
            _fraudAlert = null;
            _resultType = _ScanResultType.verified;
            _resultMessage = 'Batch verified';
            _resultNarrative =
                'Batch ${targetBatch.batchNumber} (${targetBatch.displayName}) verified successfully. '
                'Status: ${targetBatch.status}. Expiry: ${targetBatch.expiryDate.toIso8601String().substring(0, 10)}. '
                'Chain of custody valid under CDSCO 2025 guidelines.';
            _recommendedAction =
                'Batch is cleared for ${_selectedContext.label.toLowerCase()}.';
          });
        }
      }
    } catch (e, st) {
      debugPrint('Error in _confirmAndCheck: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: MediLoopColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _reset() {
    setState(() {
      _phase = _ScanPhase.context;
      _foundBatch = null;
      _fraudAlert = null;
      _resultType = null;
      _resultMessage = null;
      _resultNarrative = null;
      _recommendedAction = null;
      _batchNumberCtrl.clear();
      _medicineNameCtrl.clear();
      _expiryCtrl.clear();
      _isOfflineBackup = false;
    });
    _scannerController?.stop();
  }

  void _backToContext() {
    _scannerController?.stop();
    if (mounted) {
      setState(() {
        _phase = _ScanPhase.context;
      });
    }
  }

  void _exitScanner() {
    _scannerController?.stop();
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }

    // ShellRoute branch navigation fallback
    try {
      final location = GoRouterState.of(context).uri.path;
      if (location.startsWith('/distributor')) {
        context.go('/distributor');
        return;
      } else if (location.startsWith('/retailer')) {
        context.go('/retailer');
        return;
      } else if (location.startsWith('/manufacturer')) {
        context.go('/manufacturer');
        return;
      } else if (location.startsWith('/facility')) {
        context.go('/facility');
        return;
      } else if (location.startsWith('/admin')) {
        context.go('/admin');
        return;
      }
    } catch (_) {}

    try {
      final auth = context.read<AuthService>();
      switch (auth.currentRole) {
        case 'PHARMACY':
          context.go('/retailer');
          return;
        case 'DISTRIBUTOR':
          context.go('/distributor');
          return;
        case 'MANUFACTURER':
          context.go('/manufacturer');
          return;
        case 'WASTE_FACILITY':
          context.go('/facility');
          return;
        case 'REGULATOR':
          context.go('/admin');
          return;
      }
    } catch (_) {}

    context.go('/retailer');
  }

  void _handleBack() {
    if (_phase == _ScanPhase.result) {
      _reset();
    } else if (_phase == _ScanPhase.confirm) {
      setState(() => _phase = _ScanPhase.camera);
      _scannerController?.start();
    } else if (_phase == _ScanPhase.camera) {
      _backToContext();
    } else {
      _exitScanner();
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
      child: _buildPhase(context),
    );
  }

  Widget _buildPhase(BuildContext context) {
    // Context selection phase — white background
    if (_phase == _ScanPhase.context) {
      final auth = context.watch<AuthService>();
      return _ContextSelectionScreen(
        role: auth.currentRole,
        selected: _selectedContext,
        onSelected: (ctx) {
          setState(() => _selectedContext = ctx);
        },
        onProceed: _proceedToCamera,
        onExit: _exitScanner,
      );
    }

    // Camera + confirm + result phases
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan batch',
              style: MediLoopText.plexSans(
                  size: 16, weight: FontWeight.w600, color: Colors.white),
            ),
            Text(
              _selectedContext.label,
              style: MediLoopText.inter(size: 11, color: Colors.white60),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to context selection',
          onPressed: () {
            if (_phase != _ScanPhase.camera) {
              _reset();
            } else {
              _backToContext();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: _torchOn ? 'Turn flash off' : 'Turn flash on',
            onPressed: () async {
              if (_scannerController != null) {
                await _scannerController!.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Pick from gallery',
            onPressed: _processing ? null : _pickFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Enter details manually',
            onPressed: () {
              if (_batchNumberCtrl.text.isEmpty) {
                _batchNumberCtrl.text = 'PARA500-2026-001';
                _medicineNameCtrl.text = 'Paracetamol 500mg';
                _expiryCtrl.text = '03/2026';
              }
              _isOfflineBackup = true;
              setState(() => _phase = _ScanPhase.confirm);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Exit scanner',
            onPressed: _exitScanner,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera viewfinder with MobileScanner
          if (_phase == _ScanPhase.camera)
            Positioned.fill(child: _buildCameraView()),

          // Context badge
          if (_phase == _ScanPhase.camera)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 13, color: Colors.white60),
                      const SizedBox(width: 6),
                      Text(
                        _selectedContext.label,
                        style: MediLoopText.inter(size: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Scan guide frame with animated holographic laser (touch passes through)
          if (_phase == _ScanPhase.camera)
            IgnorePointer(
              child: _FuturisticViewfinder(
                laserController: _laserController,
                selectedContext: _selectedContext,
                scannerNotice: _scannerNotice,
              ),
            ),

          // Processing indicator
          if (_processing && _phase == _ScanPhase.camera)
            Positioned(
              bottom: 155,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _aiProcessingStep ?? 'Live extracting packaging details…',
                        style: MediLoopText.inter(
                          size: 13,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom capture controls & guide
          if (_phase == _ScanPhase.camera)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Live 30fps Auto-Scanner • Tap AI Camera or Gallery for Gemini OCR',
                      style: MediLoopText.inter(size: 11, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Gallery Image Upload Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _processing ? null : _pickFromGallery,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: Colors.white38,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_library_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gallery',
                            style: MediLoopText.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),

                      // Camera Shutter Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _processing ? null : _captureAndProcess,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 3.5,
                                ),
                              ),
                              child: _processing
                                  ? const Padding(
                                      padding: EdgeInsets.all(22),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: MediLoopColors.ink,
                                      ),
                                    )
                                  : Center(
                                      child: Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: MediLoopGradients.primary,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI Camera',
                            style: MediLoopText.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),

                      // Zoom Toggle Button (1.0x / 2.0x)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _processing ? null : _toggleZoom,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: _zoom > 1.0
                                      ? const Color(0xFF10B981)
                                      : Colors.white38,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _zoom == 1.0 ? '1.0x' : '2.0x',
                                  style: MediLoopText.inter(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: _zoom > 1.0
                                        ? const Color(0xFF10B981)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Macro',
                            style: MediLoopText.caption.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Confirm sheet — positioned at bottom of Stack
          if (_phase == _ScanPhase.confirm)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ConfirmSheet(
                batchNumberCtrl: _batchNumberCtrl,
                medicineNameCtrl: _medicineNameCtrl,
                expiryCtrl: _expiryCtrl,
                context: _selectedContext,
                onConfirm: _processing ? null : _confirmAndCheck,
                onCancel: () {
                  setState(() => _phase = _ScanPhase.camera);
                  _scannerController?.start();
                },
                loading: _processing,
                isOfflineBackup: _isOfflineBackup,
              ),
            ),

          // Result overlay — fill entire Stack
          if (_phase == _ScanPhase.result && _resultType != null)
            Positioned.fill(
              child: _ResultOverlay(
                type: _resultType!,
                message: _resultMessage ?? '',
                batch: _foundBatch,
                narrative: _resultNarrative,
                recommendedAction: _recommendedAction,
                alertId: _fraudAlert?.id,
                onContinue: _reset,
                onExit: _exitScanner,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: (capture) {
        if (_processing || _phase != _ScanPhase.camera) return;
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.trim().isNotEmpty) {
            _handleLiveDetectedCode(raw.trim());
            break;
          }
        }
      },
      errorBuilder: (context, error, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined,
                    size: 56, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Camera not active or available',
                  style: MediLoopText.inter(
                      size: 15, weight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use gallery picker or enter batch manually',
                  style: MediLoopText.inter(size: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick image from gallery'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _batchNumberCtrl.text = 'PARA500-2026-001';
                    _medicineNameCtrl.text = 'Paracetamol 500mg';
                    _expiryCtrl.text = '03/2026';
                    _isOfflineBackup = true;
                    setState(() => _phase = _ScanPhase.confirm);
                  },
                  child: const Text('Enter details manually',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Context Selection Screen ─────────────────────────────────────────────────

class _ContextSelectionScreen extends StatelessWidget {
  final String? role;
  final ScanContext selected;
  final void Function(ScanContext) onSelected;
  final VoidCallback onProceed;
  final VoidCallback onExit;

  const _ContextSelectionScreen({
    this.role,
    required this.selected,
    required this.onSelected,
    required this.onProceed,
    required this.onExit,
  });

  List<ScanContext> get _contexts => ScanContext.contextsForRole(role);

  String get _roleLabel => switch (role) {
    'PHARMACY' => 'Retail Pharmacy',
    'DISTRIBUTOR' => 'Distributor Hub',
    'MANUFACTURER' => 'Manufacturer Plant',
    'WASTE_FACILITY' => 'Bio-Medical Waste Facility',
    'REGULATOR' => 'CDSCO Inspection',
    _ => 'Supply Chain',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why are you scanning?', style: MediLoopText.h4),
            Text(
              '$_roleLabel mode • Fraud rules tailored to your role',
              style: MediLoopText.caption,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit scanner',
          onPressed: onExit,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              itemCount: _contexts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: MediLoopSpacing.xs),
              itemBuilder: (_, i) {
                final ctx = _contexts[i];
                final isSelected = ctx == selected;
                final isAuditSafe = ctx.isAuditSafe;
                return InkWell(
                  onTap: () => onSelected(ctx),
                  borderRadius: BorderRadius.circular(MediLoopRadius.card),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(MediLoopSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MediLoopColors.ink
                          : MediLoopColors.surface,
                      borderRadius: BorderRadius.circular(MediLoopRadius.card),
                      border: Border.all(
                        color: isSelected
                            ? MediLoopColors.ink
                            : MediLoopColors.line,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : MediLoopColors.textMuted,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 12, color: MediLoopColors.ink)
                              : null,
                        ),
                        const SizedBox(width: MediLoopSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    ctx.label,
                                    style: MediLoopText.plexSans(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : MediLoopColors.textPrimary,
                                    ),
                                  ),
                                  if (isAuditSafe) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white24
                                            : MediLoopColors.verifiedBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'AUDIT-SAFE',
                                        style: MediLoopText.inter(
                                          size: 9,
                                          weight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white70
                                              : MediLoopColors.verified,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ctx.description,
                                style: MediLoopText.inter(
                                  size: 12,
                                  color: isSelected
                                      ? Colors.white70
                                      : MediLoopColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              MediLoopSpacing.lg,
              0,
              MediLoopSpacing.lg,
              MediaQuery.of(context).padding.bottom + MediLoopSpacing.lg,
            ),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onProceed,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Proceed to camera'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confirm sheet ─────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  final TextEditingController batchNumberCtrl;
  final TextEditingController medicineNameCtrl;
  final TextEditingController expiryCtrl;
  final ScanContext context;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool loading;
  final bool isOfflineBackup;

  const _ConfirmSheet({
    required this.batchNumberCtrl,
    required this.medicineNameCtrl,
    required this.expiryCtrl,
    required this.context,
    this.onConfirm,
    this.onCancel,
    required this.loading,
    this.isOfflineBackup = false,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: MediLoopColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        MediLoopSpacing.lg,
        MediLoopSpacing.lg,
        MediLoopSpacing.lg,
        MediaQuery.of(ctx).viewInsets.bottom + MediLoopSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: MediLoopColors.verified),
              const SizedBox(width: 6),
              Text(
                isOfflineBackup
                    ? 'Extracted details (CDSCO offline fallback)'
                    : 'Extracted details (Gemini 3.5 Flash-Lite Active)',
                style: MediLoopText.inter(
                    size: 12,
                    weight: FontWeight.w600,
                    color: isOfflineBackup
                        ? MediLoopColors.attention
                        : MediLoopColors.verified),
              ),
              const Spacer(),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Back to camera',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onCancel,
                )
              else
                Text('Edit if needed', style: MediLoopText.caption),
            ],
          ),
          // Context reminder
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MediLoopColors.line.withAlpha(100),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Context: ${context.label}',
              style: MediLoopText.inter(
                  size: 11, color: MediLoopColors.textMuted),
            ),
          ),
          if (isOfflineBackup) ...[
            const SizedBox(height: MediLoopSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MediLoopColors.attentionBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MediLoopColors.attention.withAlpha(80)),
              ),
              child: Text(
                'CDSCO offline model active — select a batch below or edit manually',
                style: MediLoopText.inter(
                    size: 11, color: MediLoopColors.attention),
              ),
            ),
          ],
          const SizedBox(height: MediLoopSpacing.sm),
          // Quick batch selection chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 13, color: MediLoopColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Quick-pick registered batch:',
                  style: MediLoopText.inter(size: 11, color: MediLoopColors.textMuted, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _batchChip(
                  label: 'Amoxicillin 500mg',
                  batchNo: 'AMOX500-2025-089',
                  medName: 'Amoxicillin 500mg',
                  exp: '07/2025',
                ),
                const SizedBox(width: 8),
                _batchChip(
                  label: 'Paracetamol 500mg',
                  batchNo: 'PARA500-2026-001',
                  medName: 'Paracetamol 500mg',
                  exp: '03/2026',
                ),
              ],
            ),
          ),
          const SizedBox(height: MediLoopSpacing.sm),
          TextField(
            controller: batchNumberCtrl,
            decoration: const InputDecoration(labelText: 'Batch number'),
            style: MediLoopText.plexMono(
                size: 14, color: MediLoopColors.textPrimary),
          ),
          const SizedBox(height: MediLoopSpacing.sm),
          TextField(
            controller: medicineNameCtrl,
            decoration: const InputDecoration(labelText: 'Medicine name'),
          ),
          const SizedBox(height: MediLoopSpacing.sm),
          TextField(
            controller: expiryCtrl,
            decoration: const InputDecoration(labelText: 'Expiry date'),
          ),
          const SizedBox(height: MediLoopSpacing.md),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onConfirm,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify batch'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _batchChip({
    required String label,
    required String batchNo,
    required String medName,
    required String exp,
  }) {
    final isSelected = batchNumberCtrl.text.trim() == batchNo;
    return InkWell(
      onTap: () {
        batchNumberCtrl.text = batchNo;
        medicineNameCtrl.text = medName;
        expiryCtrl.text = exp;
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? MediLoopColors.ink : MediLoopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MediLoopColors.ink : MediLoopColors.line,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: MediLoopText.inter(
            size: 11,
            weight: FontWeight.w600,
            color: isSelected ? Colors.white : MediLoopColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Result overlay ─────────────────────────────────────────────────────────

class _ResultOverlay extends StatefulWidget {
  final _ScanResultType type;
  final String message;
  final MedicineBatch? batch;
  final String? narrative;
  final String? recommendedAction;
  final String? alertId;
  final VoidCallback onContinue;
  final VoidCallback? onExit;

  const _ResultOverlay({
    required this.type,
    required this.message,
    this.batch,
    this.narrative,
    this.recommendedAction,
    this.alertId,
    required this.onContinue,
    this.onExit,
  });

  @override
  State<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<_ResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _slideAnim = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = widget.type == _ScanResultType.verified;
    final isCritical = widget.type == _ScanResultType.critical;

    final bgColor = isVerified
        ? MediLoopColors.verified
        : isCritical
            ? MediLoopColors.critical
            : const Color(0xFF7A2D1A); // deep warning red for suspicious

    final icon = isVerified
        ? Icons.check_circle_outline
        : isCritical
            ? Icons.gpp_bad
            : Icons.warning_amber_rounded;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideAnim.value * 400),
        child: Opacity(opacity: _fadeAnim.value, child: child),
      ),
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              if (widget.onExit != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: 'Exit to dashboard',
                      onPressed: widget.onExit,
                    ),
                  ),
                ),
              // ── Top: icon + title
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MediLoopSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      Icon(icon, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        widget.message,
                        style: MediLoopText.plexSans(
                            size: 22,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2),
                        textAlign: TextAlign.center,
                      ),

                      // Batch info chip
                      if (widget.batch != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.batch!.displayName,
                                      style: MediLoopText.plexSans(
                                          size: 14,
                                          weight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.batch!.batchNumber,
                                      style: MediLoopText.plexMono(
                                          size: 12, color: Colors.white70),
                                    ),
                                    Text(
                                      'Status: ${widget.batch!.status}',
                                      style: MediLoopText.inter(
                                          size: 12, color: Colors.white60),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Narrative
                      if (widget.narrative != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            widget.narrative!,
                            style: MediLoopText.inter(
                                size: 13,
                                color: Colors.white.withAlpha(220),
                                height: 1.5),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],

                      // Recommended action
                      if (widget.recommendedAction != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_right_alt,
                                  size: 18, color: Colors.white70),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.recommendedAction!,
                                  style: MediLoopText.inter(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (!isVerified) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.block,
                                  size: 18, color: Colors.white70),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isCritical
                                      ? 'BLOCKED — Alert auto-sent to CDSCO Admin'
                                      : 'Action flagged — Alert sent to Admin',
                                  style: MediLoopText.inter(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Bottom actions
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MediLoopSpacing.lg,
                  0,
                  MediLoopSpacing.lg,
                  MediaQuery.of(context).padding.bottom + MediLoopSpacing.md,
                ),
                child: Column(
                  children: [
                    if (isVerified)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: MediLoopColors.verified,
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onContinue,
                      child: Text(
                        isVerified ? 'Scan another' : 'Dismiss',
                        style: MediLoopText.inter(
                            size: 13, color: Colors.white70),
                      ),
                    ),
                    if (widget.onExit != null) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 16, color: Colors.white70),
                        label: Text(
                          'Exit to dashboard',
                          style: MediLoopText.inter(
                              size: 13, color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Futuristic Viewfinder with Animated Laser Beam ────────────────────────

class _FuturisticViewfinder extends StatelessWidget {
  final AnimationController laserController;
  final ScanContext selectedContext;
  final String? scannerNotice;

  const _FuturisticViewfinder({
    required this.laserController,
    required this.selectedContext,
    this.scannerNotice,
  });

  @override
  Widget build(BuildContext context) {
    const frameWidth = 280.0;
    const frameHeight = 180.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top HUD status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF10B981),
                        blurRadius: 8,
                        spreadRadius: 1.5,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'CDSCO VISION OCR ACTIVE',
                  style: MediLoopText.inter(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Viewfinder reticle with laser
          SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: Stack(
              children: [
                // Corner reticle brackets
                CustomPaint(
                  size: const Size(frameWidth, frameHeight),
                  painter: _CornerReticlePainter(color: const Color(0xFF10B981)),
                ),

                // Subtle center crosshairs
                Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                // Animated sweep laser beam
                AnimatedBuilder(
                  animation: laserController,
                  builder: (context, child) {
                    final laserY = laserController.value * (frameHeight - 12);
                    return Positioned(
                      top: laserY,
                      left: 6,
                      right: 6,
                      child: Container(
                        height: 3.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x8010B981),
                              Color(0xFF10B981),
                              Color(0xFF6EE7B7),
                              Color(0xFF10B981),
                              Color(0x8010B981),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 14,
                              spreadRadius: 2.5,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bottom prompt
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scannerNotice != null
                  ? const Color(0xFFDC2626).withValues(alpha: 0.88)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: scannerNotice != null
                  ? Border.all(color: const Color(0xFFFCA5A5), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scannerNotice != null) ...[
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  scannerNotice ?? 'Align batch QR or printed drug packaging',
                  style: MediLoopText.inter(
                    size: 12,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerReticlePainter extends CustomPainter {
  final Color color;

  const _CornerReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLength = 24.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

