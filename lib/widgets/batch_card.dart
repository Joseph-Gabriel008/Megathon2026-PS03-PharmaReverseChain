import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/medicine_batch.dart';
import '../models/batch_event.dart';
import 'status_badge.dart';

/// Dynamic interactive Batch card with gradient accent strip and micro-animation on press.
class BatchCard extends StatefulWidget {
  final MedicineBatch batch;
  final String? orgType;
  final VoidCallback? onTap;
  final Widget? trailing;

  const BatchCard({
    super.key,
    required this.batch,
    this.orgType,
    this.onTap,
    this.trailing,
  });

  @override
  State<BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<BatchCard> {
  bool _isPressed = false;

  Color _getStatusAccentColor(String status) {
    if (widget.batch.isExpired) return MediLoopColors.critical;
    if (widget.batch.isExpiringSoon) return MediLoopColors.attention;
    return switch (status) {
      'DESTROYED' || 'CLOSED' || 'DISTRIBUTOR_VERIFIED' => MediLoopColors.verified,
      'EXPIRED' => MediLoopColors.critical,
      'EXPIRING_SOON' || 'RETURN_INITIATED' || 'DISPOSAL_PENDING' => MediLoopColors.attention,
      'IN_TRANSIT' => MediLoopColors.accent,
      _ => MediLoopColors.ink,
    };
  }

  @override
  Widget build(BuildContext context) {
    final expiryStr = DateFormat('dd MMM yyyy').format(widget.batch.expiryDate);
    final accentColor = _getStatusAccentColor(widget.batch.status);

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: MediLoopColors.surface,
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
          border: Border.all(color: MediLoopColors.line, width: 1),
          boxShadow: MediLoopShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent status gradient strip
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onHighlightChanged: (val) => setState(() => _isPressed = val),
                    onTap: widget.onTap ?? () => context.push('/batch/${widget.batch.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MediLoopSpacing.md,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.batch.displayName,
                                      style: MediLoopText.plexSans(
                                        size: 16,
                                        weight: FontWeight.w600,
                                        color: MediLoopColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: MediLoopColors.inactiveBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            widget.batch.batchNumber,
                                            style: MediLoopText.batchCode.copyWith(fontSize: 12),
                                          ),
                                        ),
                                        if (widget.orgType != null) ...[
                                          const SizedBox(width: 6),
                                          RoleTag(type: widget.orgType!, small: true),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(status: widget.batch.status, compact: true),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: MediLoopColors.lineLight,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _MetaChip(
                                icon: Icons.event_rounded,
                                label: 'Exp $expiryStr',
                                warning: widget.batch.isExpiringSoon,
                                critical: widget.batch.isExpired,
                              ),
                              const SizedBox(width: 14),
                              _MetaChip(
                                icon: Icons.inventory_2_outlined,
                                label: '${widget.batch.currentQuantity} units',
                              ),
                              if (widget.trailing != null) ...[
                                const Spacer(),
                                widget.trailing!,
                              ],
                            ],
                          ),
                          if (widget.batch.isExpired ||
                              widget.batch.isExpiringSoon ||
                              widget.batch.status == 'DESTROYED') ...[
                            const SizedBox(height: 8),
                            _buildExpiryUrgencyBanner(widget.batch),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryUrgencyBanner(MedicineBatch batch) {
    if (batch.status == 'DESTROYED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 13, color: Color(0xFF16A34A)),
            const SizedBox(width: 5),
            Text(
              'CDSCO Closed-Loop Decommissioned',
              style: MediLoopText.caption.copyWith(
                color: const Color(0xFF15803D),
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );
    }

    final diff = batch.expiryDate.difference(DateTime.now()).inDays;
    if (batch.isExpired) {
      final daysAgo = diff.abs();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MediLoopColors.criticalBg,
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: MediLoopColors.critical.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 13, color: MediLoopColors.critical),
            const SizedBox(width: 5),
            Text(
              'EXPIRED ${daysAgo == 0 ? "TODAY" : "$daysAgo DAYS AGO"} — Prohibited from sale',
              style: MediLoopText.caption.copyWith(
                color: MediLoopColors.critical,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );
    }

    if (batch.isExpiringSoon) {
      final isUrgent = diff <= 30;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isUrgent ? const Color(0xFFFEF2F2) : MediLoopColors.attentionBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isUrgent
                ? MediLoopColors.critical.withValues(alpha: 0.4)
                : MediLoopColors.attention.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 13,
              color:
                  isUrgent ? MediLoopColors.critical : MediLoopColors.attention,
            ),
            const SizedBox(width: 5),
            Text(
              diff <= 0
                  ? 'Expires today'
                  : 'Expires in $diff days — Return recommended',
              style: MediLoopText.caption.copyWith(
                color:
                    isUrgent ? MediLoopColors.critical : const Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;
  final bool critical;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.warning = false,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = MediLoopColors.textMuted;
    if (critical) {
      color = MediLoopColors.critical;
    } else if (warning) {
      color = MediLoopColors.attention;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: MediLoopText.inter(
            size: 12,
            weight: (warning || critical) ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Animated KPI Tile with rolling number counter, icon badge, and soft glow
class KpiTile extends StatelessWidget {
  final String label;
  final int value;
  final bool warning;
  final bool critical;
  final IconData? icon;
  final VoidCallback? onTap;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.warning = false,
    this.critical = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor = MediLoopColors.ink;
    Color bgColor = MediLoopColors.surface;
    Color iconBg = MediLoopColors.inactiveBg;
    IconData displayIcon = icon ?? Icons.analytics_outlined;

    if (critical && value > 0) {
      themeColor = MediLoopColors.critical;
      iconBg = MediLoopColors.criticalBg;
      displayIcon = Icons.warning_rounded;
    } else if (warning && value > 0) {
      themeColor = MediLoopColors.attention;
      iconBg = MediLoopColors.attentionBg;
      displayIcon = Icons.schedule_rounded;
    }

    final content = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(
          color: (critical && value > 0)
              ? MediLoopColors.critical.withValues(alpha: 0.3)
              : (warning && value > 0)
                  ? MediLoopColors.attention.withValues(alpha: 0.3)
                  : MediLoopColors.line,
          width: 1,
        ),
        boxShadow: MediLoopShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(displayIcon, size: 17, color: themeColor),
              ),
              if (critical && value > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MediLoopColors.criticalBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'URGENT',
                    style: MediLoopText.inter(
                      size: 9.5,
                      weight: FontWeight.w700,
                      color: MediLoopColors.critical,
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: MediLoopColors.textMuted.withValues(alpha: 0.6),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Rolling number rollup animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedVal, child) {
              return Text(
                '${animatedVal.round()}',
                style: MediLoopText.kpiNumber.copyWith(
                  color: themeColor,
                  fontSize: 26,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MediLoopText.labelMuted.copyWith(fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Fraud alert card with emergency crimson accent and AI forensic narrative styling
class FraudAlertCard extends StatelessWidget {
  final FraudAlert alert;
  final bool expanded;
  final void Function(String action)? onAction;
  final VoidCallback? onTap;

  const FraudAlertCard({
    super.key,
    required this.alert,
    this.expanded = false,
    this.onAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = alert.isCritical
        ? MediLoopColors.critical
        : alert.severity == 'HIGH'
            ? MediLoopColors.attention
            : MediLoopColors.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: MediLoopColors.surface,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(
          color: alert.isCritical
              ? MediLoopColors.critical.withValues(alpha: 0.35)
              : MediLoopColors.line,
          width: alert.isCritical ? 1.5 : 1,
        ),
        boxShadow: alert.isCritical
            ? MediLoopShadows.glow(MediLoopColors.critical, opacity: 0.12, blur: 12)
            : MediLoopShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left border accent
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: borderColor,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [borderColor, borderColor.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(MediLoopSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            StatusBadge(status: alert.severity, compact: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert.alertTypeLabel,
                                style: MediLoopText.plexSans(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                  color: MediLoopColors.ink,
                                ),
                              ),
                            ),
                            StatusBadge(status: alert.status, compact: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Batch + org info
                        Row(
                          children: [
                            if (alert.batchNumber != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MediLoopColors.inactiveBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  alert.batchNumber!,
                                  style: MediLoopText.batchCode.copyWith(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (alert.medicineName != null)
                              Expanded(
                                child: Text(
                                  alert.medicineName!,
                                  style: MediLoopText.bodyMuted.copyWith(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: MediLoopSpacing.sm),
                        // AI narrative box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: alert.isCritical
                                ? MediLoopColors.criticalBg.withValues(alpha: 0.6)
                                : MediLoopColors.paper,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: alert.isCritical
                                  ? MediLoopColors.critical.withValues(alpha: 0.2)
                                  : MediLoopColors.line,
                            ),
                          ),
                          child: Text(
                            alert.aiNarrative ?? alert.description,
                            style: MediLoopText.inter(
                              size: 13,
                              color: alert.isCritical
                                  ? MediLoopColors.textPrimary
                                  : MediLoopColors.textMuted,
                              height: 1.35,
                            ),
                            maxLines: expanded ? null : 3,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: MediLoopSpacing.sm),
                        // Timestamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13, color: MediLoopColors.textSubtle),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimestamp(alert.detectedAt),
                                  style: MediLoopText.caption,
                                ),
                              ],
                            ),
                            if (!expanded)
                              Text(
                                'Tap to inspect →',
                                style: MediLoopText.caption.copyWith(
                                  color: MediLoopColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        // Action buttons (in expanded view)
                        if (expanded && onAction != null) ...[
                          const SizedBox(height: MediLoopSpacing.md),
                          const Divider(),
                          const SizedBox(height: MediLoopSpacing.sm),
                          _ActionRow(status: alert.status, onAction: onAction!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}

class _ActionRow extends StatelessWidget {
  final String status;
  final void Function(String action) onAction;

  const _ActionRow({required this.status, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (status == 'OPEN')
          _ActionButton(
            label: 'Investigate',
            onTap: () => onAction('INVESTIGATING'),
          ),
        if (status == 'OPEN' || status == 'INVESTIGATING')
          _ActionButton(
            label: 'Resolve',
            primary: true,
            onTap: () => onAction('RESOLVED'),
          ),
        if (status == 'OPEN')
          _ActionButton(
            label: 'Mark false positive',
            onTap: () => onAction('FALSE_POSITIVE'),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: MediLoopColors.verified,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(label),
    );
  }
}

/// Empty state with modern illustration container
class EmptyState extends StatelessWidget {
  final String what;
  final String action;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.what,
    required this.action,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MediLoopSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MediLoopColors.inactiveBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: MediLoopColors.textMuted),
            ),
            const SizedBox(height: MediLoopSpacing.md),
            Text(what,
                style: MediLoopText.h4, textAlign: TextAlign.center),
            const SizedBox(height: MediLoopSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(action,
                  style: MediLoopText.bodyMuted, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MediLoopSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MediLoopColors.criticalBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: MediLoopColors.critical),
            ),
            const SizedBox(height: MediLoopSpacing.md),
            Text(message,
                style: MediLoopText.body, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: MediLoopSpacing.md),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
