import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_database.dart';
import '../../models/medicine_batch.dart';

/// Full-screen critical fraud alert — the "Killer Demo" moment.
/// Shown when a DESTROYED batch is scanned at the pharmacy.
class FraudAlertScreen extends StatefulWidget {
  final MedicineBatch batch;
  final String? narrative;
  final String? alertId;
  final VoidCallback onDismiss;

  const FraudAlertScreen({
    super.key,
    required this.batch,
    this.narrative,
    this.alertId,
    required this.onDismiss,
  });

  @override
  State<FraudAlertScreen> createState() => _FraudAlertScreenState();
}

class _FraudAlertScreenState extends State<FraudAlertScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: _pulseAnim.value * 1.6,
                      colors: [
                        const Color(0xFFDC2626).withValues(alpha: 0.45),
                        const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => CustomPaint(
                  painter: _PulsingRingPainter(_pulseAnim.value),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          const Color(0xFFDC2626),
                          const Color(0xFFEF4444),
                          _pulseAnim.value,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: _pulseAnim.value * 0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'CRITICAL FRAUD ALERT',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: _pulseAnim.value),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.gpp_bad_rounded, size: 48, color: Color(0xFFEF4444)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'DESTROYED BATCH REENTRY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This batch was certified as destroyed',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          _AlertRow(label: 'Medicine', value: widget.batch.displayName, valueColor: Colors.white),
                          const Divider(color: Colors.white12, height: 12),
                          _AlertRow(label: 'Batch', value: widget.batch.batchNumber, valueColor: const Color(0xFFFCA5A5), mono: true),
                          const Divider(color: Colors.white12, height: 12),
                          _AlertRow(label: 'Status', value: '\u26D4 DESTROYED', valueColor: const Color(0xFFEF4444)),
                          const Divider(color: Colors.white12, height: 12),
                          _AlertRow(
                            label: 'Detected',
                            value: DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' '),
                            valueColor: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.narrative != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFFCA5A5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.narrative!,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_reported)
                          ElevatedButton.icon(
                            key: const Key('fraud_report_regulator_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _reportToRegulator,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text(
                              'Report to Regulator (CDSCO)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Reported \u2014 Admin has been notified',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const Key('fraud_dismiss_btn'),
                          onPressed: widget.onDismiss,
                          child: const Text('Dismiss', style: TextStyle(fontSize: 14, color: Colors.white38)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reportToRegulator() {
    HapticFeedback.heavyImpact();
    MockDatabase.instance.createFraudAlert(
      batchId: widget.batch.id,
      alertType: 'DESTROYED_BATCH_REENTRY',
      severity: 'CRITICAL',
      description: 'Batch ${widget.batch.batchNumber} marked as DESTROYED was scanned '
          'as active retail inventory. Possible illicit diversion or counterfeit reuse.',
      organizationId: 'org-retailer-01',
    );
    setState(() => _reported = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert reported to CDSCO Sentinel Hub'),
        backgroundColor: Color(0xFF065F46),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool mono;

  const _AlertRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
        Flexible(
          child: Text(
            value,
            style: mono
                ? TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13, color: valueColor, fontWeight: FontWeight.w600)
                : TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PulsingRingPainter extends CustomPainter {
  final double progress;
  _PulsingRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      paint.color = const Color(0xFFDC2626).withValues(alpha: (1 - t) * 0.25);
      canvas.drawCircle(center, maxRadius * t, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsingRingPainter oldDelegate) => oldDelegate.progress != progress;
}
