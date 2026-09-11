import 'package:flutter/material.dart';
import '../core/theme.dart';

class ComplianceFactor {
  final String title;
  final double score; // 0.0 to 1.0
  final String description;
  final IconData icon;

  const ComplianceFactor({
    required this.title,
    required this.score,
    required this.description,
    required this.icon,
  });
}

class ComplianceScoreWidget extends StatelessWidget {
  final double overallScore; // 0.0 to 100.0
  final String organizationName;
  final List<ComplianceFactor>? factors;
  final bool compact;

  const ComplianceScoreWidget({
    super.key,
    required this.overallScore,
    required this.organizationName,
    this.factors,
    this.compact = false,
  });

  Color _scoreColor(double score) {
    if (score >= 90) return MediLoopColors.verified;
    if (score >= 75) return MediLoopColors.attention;
    return MediLoopColors.critical;
  }

  String _scoreRating(double score) {
    if (score >= 95) return 'EXCELLENT';
    if (score >= 90) return 'GOOD';
    if (score >= 75) return 'NEEDS ATTENTION';
    return 'HIGH RISK';
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(overallScore);
    final rating = _scoreRating(overallScore);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MediLoopRadius.badge),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '${overallScore.toStringAsFixed(0)}% Compliance',
              style: MediLoopText.inter(
                size: 12,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    final defaultFactors = factors ?? [
      const ComplianceFactor(
        title: 'Audit Chain Integrity',
        score: 1.0,
        description: 'All cryptographic SHA-256 blocks valid',
        icon: Icons.link,
      ),
      const ComplianceFactor(
        title: 'On-Time Return Submissions',
        score: 0.94,
        description: 'Batches returned before critical expiry',
        icon: Icons.access_time,
      ),
      const ComplianceFactor(
        title: 'Quantity Reconciliation',
        score: 0.98,
        description: 'Zero physical vs documented discrepancies',
        icon: Icons.balance,
      ),
      const ComplianceFactor(
        title: 'Alert Resolution Velocity',
        score: 0.92,
        description: 'Flagged alerts investigated in < 24h',
        icon: Icons.speed,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MediLoopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Regulatory Compliance Score',
                          style: MediLoopText.labelMuted),
                      const SizedBox(height: 2),
                      Text(organizationName, style: MediLoopText.h4),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MediLoopRadius.badge),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    rating,
                    style: MediLoopText.inter(
                      size: 11,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.md),

            // Large gauge / progress bar
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  overallScore.toStringAsFixed(1),
                  style: MediLoopText.plexMono(
                    size: 36,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  ' / 100',
                  style: MediLoopText.inter(
                    size: 14,
                    color: MediLoopColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (overallScore / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: MediLoopColors.line,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: MediLoopSpacing.lg),

            // Factor breakdown
            Text('Factor Breakdown', style: MediLoopText.label),
            const SizedBox(height: MediLoopSpacing.sm),
            for (final f in defaultFactors) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(f.icon, size: 16, color: MediLoopColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(f.title, style: MediLoopText.body),
                              Text(
                                '${(f.score * 100).toStringAsFixed(0)}%',
                                style: MediLoopText.plexMono(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _scoreColor(f.score * 100),
                                ),
                              ),
                            ],
                          ),
                          Text(f.description,
                              style: MediLoopText.caption),
                        ],
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
}
