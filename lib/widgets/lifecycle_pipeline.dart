import 'package:flutter/material.dart';
import '../core/theme.dart';

/// The chain-of-custody lifecycle pipeline.
///
/// Shows the 6 stages of the reverse chain with animated active beacon and glowing gradient nodes.
/// Stage map:
///   0 = Expired
///   1 = Returned
///   2 = Collected
///   3 = Verified
///   4 = Destroyed
///   5 = Certified
class LifecyclePipeline extends StatelessWidget {
  final int completedStage;
  final Map<String, int>? stageCounts;
  final bool animateLastStage;
  final bool showDetails;

  static const _stages = [
    _Stage(
      'Expired',
      Icons.warning_amber_rounded,
      'Quarantined past shelf-life at retail pharmacy',
    ),
    _Stage(
      'Returned',
      Icons.swap_horiz_rounded,
      'Proof photo captured & SHA-256 evidence sealed',
    ),
    _Stage(
      'Collected',
      Icons.local_shipping_outlined,
      'Intake confirmed with bilateral counterparty scan',
    ),
    _Stage(
      'Verified',
      Icons.verified_rounded,
      'Warehouse inventory & quantity reconciled',
    ),
    _Stage(
      'Destroyed',
      Icons.recycling_rounded,
      'Incinerated or neutralized at certified CPCB facility',
    ),
    _Stage(
      'Certified',
      Icons.workspace_premium_rounded,
      'Tamper-evident Certificate of Destruction issued',
    ),
  ];

  const LifecyclePipeline({
    super.key,
    required this.completedStage,
    this.stageCounts,
    this.animateLastStage = false,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 520) {
          return _HorizontalPipeline(
            completedStage: completedStage,
            stageCounts: stageCounts,
            animateLastStage: animateLastStage,
          );
        }
        return _VerticalPipeline(
          completedStage: completedStage,
          stageCounts: stageCounts,
          showDetails: showDetails,
        );
      },
    );
  }
}

class _HorizontalPipeline extends StatefulWidget {
  final int completedStage;
  final Map<String, int>? stageCounts;
  final bool animateLastStage;

  const _HorizontalPipeline({
    required this.completedStage,
    this.stageCounts,
    required this.animateLastStage,
  });

  @override
  State<_HorizontalPipeline> createState() => _HorizontalPipelineState();
}

class _HorizontalPipelineState extends State<_HorizontalPipeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animateLastStage) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < LifecyclePipeline._stages.length; i++) ...[
              _PipelineNode(
                stage: LifecyclePipeline._stages[i],
                completed: _isCompleted(i),
                isActive: i == widget.completedStage,
                isLast: i == LifecyclePipeline._stages.length - 1,
                count: widget.stageCounts?[LifecyclePipeline._stages[i].label],
              ),
              if (i < LifecyclePipeline._stages.length - 1)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: _ConnectorLine(completed: _isLineCompleted(i)),
                  ),
                ),
            ]
          ],
        );
      },
    );
  }

  bool _isCompleted(int index) {
    if (index < widget.completedStage) return true;
    if (index == widget.completedStage && widget.animateLastStage) {
      return _anim.value > 0.5;
    }
    return false;
  }

  bool _isLineCompleted(int index) =>
      index < widget.completedStage - 1 ||
      (index == widget.completedStage - 1 &&
          (!widget.animateLastStage || _anim.value > 0.5));
}

class _PipelineNode extends StatelessWidget {
  final _Stage stage;
  final bool completed;
  final bool isActive;
  final bool isLast;
  final int? count;

  const _PipelineNode({
    required this.stage,
    required this.completed,
    required this.isActive,
    required this.isLast,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = completed
        ? MediLoopColors.ink
        : isActive
            ? MediLoopColors.accent
            : MediLoopColors.textMuted;

    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Node icon container with glow or border
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? MediLoopColors.ink
                  : isActive
                      ? MediLoopColors.accentBg
                      : MediLoopColors.surface,
              border: Border.all(
                color: completed
                    ? MediLoopColors.ink
                    : isActive
                        ? MediLoopColors.accent
                        : MediLoopColors.line,
                width: isActive ? 2.5 : 2,
              ),
              boxShadow: completed
                  ? [
                      BoxShadow(
                        color: MediLoopColors.ink.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : isActive
                      ? [
                          BoxShadow(
                            color: MediLoopColors.accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
            ),
            child: Icon(
              stage.icon,
              size: 15,
              color: completed
                  ? Colors.white
                  : isActive
                      ? MediLoopColors.accent
                      : MediLoopColors.textSubtle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            style: MediLoopText.plexSans(
              size: 11,
              weight: (completed || isActive) ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: (count! > 0 && (stage.label == 'Expired' || stage.label == 'Returned'))
                    ? MediLoopColors.attentionBg
                    : MediLoopColors.inactiveBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: MediLoopText.inter(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: (count! > 0 && (stage.label == 'Expired' || stage.label == 'Returned'))
                      ? MediLoopColors.attention
                      : MediLoopColors.textMuted,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: completed
                    ? MediLoopColors.verifiedBg
                    : isActive
                        ? MediLoopColors.accentBg
                        : MediLoopColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (completed
                          ? MediLoopColors.verified
                          : isActive
                              ? MediLoopColors.accent
                              : MediLoopColors.line)
                      .withValues(alpha: 0.3),
                  width: 0.6,
                ),
              ),
              child: Text(
                completed ? 'Done' : (isActive ? 'Active' : 'Pending'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: completed
                      ? MediLoopColors.verified
                      : isActive
                          ? MediLoopColors.accent
                          : MediLoopColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  final bool completed;

  const _ConnectorLine({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      decoration: BoxDecoration(
        color: completed ? MediLoopColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: completed
          ? null
          : CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MediLoopColors.line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + 5, 1), paint);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _VerticalPipeline extends StatelessWidget {
  final int completedStage;
  final Map<String, int>? stageCounts;
  final bool showDetails;

  const _VerticalPipeline({
    required this.completedStage,
    this.stageCounts,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < LifecyclePipeline._stages.length; i++) ...[
          _VerticalStageRow(
            stage: LifecyclePipeline._stages[i],
            completed: i < completedStage,
            isActive: i == completedStage,
            count: stageCounts?[LifecyclePipeline._stages[i].label],
            showDetails: showDetails,
          ),
          if (i < LifecyclePipeline._stages.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: SizedBox(
                height: showDetails ? 20 : 16,
                child: i < completedStage - 1
                    ? Container(
                        width: 2.5,
                        decoration: BoxDecoration(
                          color: MediLoopColors.ink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : CustomPaint(
                        painter: _VerticalDashedPainter(),
                        size: Size(2, showDetails ? 20 : 16),
                      ),
              ),
            ),
        ]
      ],
    );
  }
}

class _VerticalStageRow extends StatelessWidget {
  final _Stage stage;
  final bool completed;
  final bool isActive;
  final int? count;
  final bool showDetails;

  const _VerticalStageRow({
    required this.stage,
    required this.completed,
    required this.isActive,
    this.count,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = completed
        ? MediLoopColors.ink
        : isActive
            ? MediLoopColors.accent
            : MediLoopColors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? MediLoopColors.ink
                : isActive
                    ? MediLoopColors.accentBg
                    : MediLoopColors.surface,
            border: Border.all(
              color: completed
                  ? MediLoopColors.ink
                  : isActive
                      ? MediLoopColors.accent
                      : MediLoopColors.line,
              width: isActive ? 2.5 : 2,
            ),
            boxShadow: completed
                ? [
                    BoxShadow(
                      color: MediLoopColors.ink.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : isActive
                    ? [
                        BoxShadow(
                          color: MediLoopColors.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
          ),
          child: Icon(
            completed ? Icons.check_rounded : stage.icon,
            size: 15,
            color: completed
                ? Colors.white
                : isActive
                    ? MediLoopColors.accent
                    : MediLoopColors.textSubtle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stage.label,
                      style: MediLoopText.plexSans(
                        size: 13.5,
                        weight: (completed || isActive) ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (count! > 0 && (stage.label == 'Expired' || stage.label == 'Returned'))
                            ? MediLoopColors.attentionBg
                            : MediLoopColors.inactiveBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: MediLoopText.inter(
                          size: 11,
                          weight: FontWeight.w700,
                          color: (count! > 0 && (stage.label == 'Expired' || stage.label == 'Returned'))
                              ? MediLoopColors.attention
                              : MediLoopColors.textMuted,
                        ),
                      ),
                    ),
                  ] else ...[
                    _StatusBadge(
                      status: completed
                          ? 'COMPLETED'
                          : isActive
                              ? 'ONGOING'
                              : 'PENDING',
                    ),
                  ],
                ],
              ),
              if (showDetails) ...[
                const SizedBox(height: 3),
                Text(
                  stage.description,
                  style: MediLoopText.caption.copyWith(
                    color: isActive
                        ? MediLoopColors.ink
                        : MediLoopColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (status) {
      'COMPLETED' => (
          MediLoopColors.verifiedBg,
          MediLoopColors.verified,
          'Completed',
          Icons.check_circle_outline_rounded,
        ),
      'ONGOING' => (
          MediLoopColors.accentBg,
          MediLoopColors.accent,
          'Ongoing',
          Icons.sync_rounded,
        ),
      _ => (
          MediLoopColors.surface,
          MediLoopColors.textMuted,
          'Pending',
          Icons.hourglass_empty_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fg.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MediLoopColors.line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Stage {
  final String label;
  final IconData icon;
  final String description;

  const _Stage(this.label, this.icon, this.description);
}
