import 'package:flutter/material.dart';
import '../core/theme.dart';

/// StatusBadge — always icon + color + text. Never color alone.
/// Features smooth glassmorphic styling and animated pulsing dots for critical/attention states.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;
  final bool pulse;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.pulse = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    final shouldPulse = pulse && _shouldPulse(status);
    final bgColor = config.color.withAlpha(20);
    final borderColor = config.color.withAlpha(60);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3.5 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MediLoopRadius.badge),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shouldPulse) ...[
            _PulsingDot(color: config.color, size: compact ? 6 : 7),
            const SizedBox(width: 5),
          ] else ...[
            Icon(config.icon, size: compact ? 12 : 14, color: config.color),
            const SizedBox(width: 4.5),
          ],
          Text(
            config.label,
            style: MediLoopText.inter(
              size: compact ? 11 : 12,
              weight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldPulse(String status) => switch (status) {
        'CRITICAL' || 'OPEN' || 'EXPIRING_SOON' || 'INVESTIGATING' => true,
        _ => false,
      };

  _BadgeConfig _getConfig(String status) => switch (status) {
        'ACTIVE' => _BadgeConfig(
            Icons.check_circle_outline,
            MediLoopColors.ink,
            'Active'),
        'EXPIRING_SOON' => _BadgeConfig(
            Icons.schedule_outlined,
            MediLoopColors.attention,
            'Expiring soon'),
        'EXPIRED' => _BadgeConfig(
            Icons.warning_amber_rounded,
            MediLoopColors.attention,
            'Expired'),
        'RETURN_INITIATED' => _BadgeConfig(
            Icons.swap_horiz_rounded,
            MediLoopColors.attention,
            'Return initiated'),
        'IN_TRANSIT' => _BadgeConfig(
            Icons.local_shipping_outlined,
            MediLoopColors.accent,
            'In transit'),
        'COLLECTED' => _BadgeConfig(
            Icons.inventory_2_outlined,
            MediLoopColors.ink,
            'Collected'),
        'DISTRIBUTOR_VERIFIED' => _BadgeConfig(
            Icons.verified_rounded,
            MediLoopColors.verified,
            'Distributor verified'),
        'MANUFACTURER_RECEIVED' => _BadgeConfig(
            Icons.factory_outlined,
            MediLoopColors.ink,
            'At manufacturer'),
        'DISPOSAL_PENDING' => _BadgeConfig(
            Icons.hourglass_top_rounded,
            MediLoopColors.attention,
            'Disposal pending'),
        'SENT_FOR_DESTRUCTION' => _BadgeConfig(
            Icons.delete_sweep_outlined,
            MediLoopColors.attention,
            'Sent for destruction'),
        'DESTROYED' => _BadgeConfig(
            Icons.recycling_rounded,
            MediLoopColors.verified,
            'Destroyed'),
        'CLOSED' => _BadgeConfig(
            Icons.lock_outline_rounded,
            MediLoopColors.verified,
            'Certified closed'),
        // Return request statuses
        'PENDING' => _BadgeConfig(
            Icons.hourglass_empty_rounded,
            MediLoopColors.attention,
            'Pending'),
        'ACCEPTED' => _BadgeConfig(
            Icons.thumb_up_alt_outlined,
            MediLoopColors.verified,
            'Accepted'),
        'COMPLETED' => _BadgeConfig(
            Icons.check_circle_rounded,
            MediLoopColors.verified,
            'Completed'),
        'CANCELLED' => _BadgeConfig(
            Icons.cancel_outlined,
            MediLoopColors.critical,
            'Cancelled'),
        // Fraud severities
        'CRITICAL' => _BadgeConfig(
            Icons.gpp_bad_rounded,
            MediLoopColors.critical,
            'Critical'),
        'HIGH' => _BadgeConfig(
            Icons.warning_rounded,
            MediLoopColors.attention,
            'High'),
        'MEDIUM' => _BadgeConfig(
            Icons.info_outline_rounded,
            MediLoopColors.textMuted,
            'Medium'),
        'LOW' => _BadgeConfig(
            Icons.low_priority_rounded,
            MediLoopColors.textMuted,
            'Low'),
        // Fraud alert statuses
        'OPEN' => _BadgeConfig(
            Icons.radio_button_on,
            MediLoopColors.critical,
            'Open'),
        'INVESTIGATING' => _BadgeConfig(
            Icons.search_rounded,
            MediLoopColors.attention,
            'Investigating'),
        'RESOLVED' => _BadgeConfig(
            Icons.verified_rounded,
            MediLoopColors.verified,
            'Resolved'),
        'FALSE_POSITIVE' => _BadgeConfig(
            Icons.rule_rounded,
            MediLoopColors.textMuted,
            'False positive'),
        // Org verification
        'VERIFIED' => _BadgeConfig(
            Icons.verified_user_rounded,
            MediLoopColors.verified,
            'Verified'),
        'SUSPENDED' => _BadgeConfig(
            Icons.block_rounded,
            MediLoopColors.critical,
            'Suspended'),
        _ => _BadgeConfig(
            Icons.help_outline_rounded,
            MediLoopColors.textMuted,
            status),
      };
}

class _BadgeConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _BadgeConfig(this.icon, this.color, this.label);
}

/// Animated pulsating beacon dot
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: _opacityAnimation.value),
                  ),
                ),
              );
            },
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Org/role tag chip with subtle pill gradient and sleek font
class RoleTag extends StatelessWidget {
  final String type;
  final bool small;

  const RoleTag({super.key, required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 10,
        vertical: small ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: MediLoopColors.inactiveBg,
        borderRadius: BorderRadius.circular(MediLoopRadius.badge),
        border: Border.all(color: MediLoopColors.line, width: 0.8),
      ),
      child: Text(
        _label,
        style: MediLoopText.inter(
          size: small ? 10.5 : 11.5,
          weight: FontWeight.w600,
          color: MediLoopColors.textMuted,
        ),
      ),
    );
  }

  String get _label => switch (type) {
        'PHARMACY' => 'Pharmacy',
        'DISTRIBUTOR' => 'Distributor',
        'MANUFACTURER' => 'Manufacturer',
        'WASTE_FACILITY' => 'Waste Facility',
        'REGULATOR' => 'Regulator',
        _ => type,
      };
}
