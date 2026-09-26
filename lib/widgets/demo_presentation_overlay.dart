// lib/widgets/demo_presentation_overlay.dart
//
// Reusable polish widgets:
//   • LiveSyncPulse   — static "● LIVE · synced just now" label shown on data load
//   • AnimatedComplianceRing — arc gauge that animates from 0 → score on mount

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

// ─── Live Sync Pulse ─────────────────────────────────────────────────────────

/// Shows "● LIVE · synced just now" when data was freshly loaded.
/// The dot pulses via a single short animation that completes and stops —
/// test-safe because AnimationController is not looped indefinitely.
class LiveSyncPulse extends StatefulWidget {
  final DateTime syncedAt;
  final Color color;

  const LiveSyncPulse({
    super.key,
    required this.syncedAt,
    this.color = const Color(0xFF10B981),
  });

  @override
  State<LiveSyncPulse> createState() => _LiveSyncPulseState();
}

class _LiveSyncPulseState extends State<LiveSyncPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dot;

  @override
  void initState() {
    super.initState();
    // A single 1.6s pulse that plays once and stops — does not block pumpAndSettle.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _dot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _label {
    final s = DateTime.now().difference(widget.syncedAt).inSeconds;
    if (s < 10) return 'just now';
    if (s < 60) return '${s}s ago';
    final m = DateTime.now().difference(widget.syncedAt).inMinutes;
    return m < 60 ? '${m}m ago' : '${m ~/ 60}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dot,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: _dot.value,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE · synced $_label',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: widget.color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Compliance Ring ─────────────────────────────────────────────────

/// An arc-gauge that animates from 0 → [score] on first render via
/// TweenAnimationBuilder (forward-only, stops when done — test-safe).
class AnimatedComplianceRing extends StatelessWidget {
  /// Score in the range 0–100.
  final double score;

  /// Diameter of the ring widget.
  final double size;

  const AnimatedComplianceRing({
    super.key,
    required this.score,
    this.size = 72,
  });

  Color get _color {
    if (score >= 90) return MediLoopColors.verified;
    if (score >= 75) return MediLoopColors.attention;
    return MediLoopColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  color: _color,
                  trackColor: _color.withValues(alpha: 0.12),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: TextStyle(
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w800,
                      color: _color,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: size * 0.13,
                      fontWeight: FontWeight.w600,
                      color: _color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final strokeWidth = size.width * 0.1;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Background track
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc (forward-only from 12 o'clock)
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
