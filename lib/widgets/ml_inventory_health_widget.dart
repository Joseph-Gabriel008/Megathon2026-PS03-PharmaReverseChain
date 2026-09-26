// lib/widgets/ml_inventory_health_widget.dart
//
// ML-powered inventory health heatmap widget.
// Shows per-batch expiry risk tiers from the MlRiskService Batch Health Classifier
// and an AI-generated briefing from GeminiService.generateExpiryRiskBriefing.

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/medicine_batch.dart';
import '../services/ml_risk_service.dart';

class MlInventoryHealthWidget extends StatelessWidget {
  final BatchHealthSummary health;
  final String? aiBriefing;
  final bool isLoading;

  const MlInventoryHealthWidget({
    super.key,
    required this.health,
    this.aiBriefing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _LoadingCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiBriefingCard(briefing: aiBriefing, health: health),
        const SizedBox(height: 12),
        _RiskHeatmapRow(health: health),
        if (health.rankedBatches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HighRiskBatchList(rankedBatches: health.rankedBatches.take(3).toList()),
        ],
      ],
    );
  }
}

// ─── AI Briefing Card ─────────────────────────────────────────────────────────

class _AiBriefingCard extends StatelessWidget {
  final String? briefing;
  final BatchHealthSummary health;

  const _AiBriefingCard({required this.briefing, required this.health});

  @override
  Widget build(BuildContext context) {
    final hasCritical = health.critical > 0;
    final hasAtRisk = health.atRisk > 0;
    final color = hasCritical
        ? MediLoopColors.critical
        : hasAtRisk
            ? MediLoopColors.attention
            : MediLoopColors.verified;
    final bg = hasCritical
        ? MediLoopColors.criticalBg
        : hasAtRisk
            ? MediLoopColors.attentionBg
            : MediLoopColors.verifiedBg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasCritical
                      ? Icons.crisis_alert_rounded
                      : hasAtRisk
                          ? Icons.analytics_rounded
                          : Icons.verified_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ML Inventory Risk Briefing',
                style: MediLoopText.inter(
                  size: 12,
                  weight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasCritical ? 'CRITICAL' : hasAtRisk ? 'AT RISK' : 'HEALTHY',
                  style: MediLoopText.inter(
                    size: 9,
                    weight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (briefing != null && briefing!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              briefing!,
              style: MediLoopText.inter(
                size: 12.5,
                color: color.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Heatmap Row ──────────────────────────────────────────────────────────────

class _RiskHeatmapRow extends StatelessWidget {
  final BatchHealthSummary health;

  const _RiskHeatmapRow({required this.health});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TierBar(
          count: health.critical,
          label: 'Critical',
          color: MediLoopColors.critical,
          total: health.total,
        ),
        const SizedBox(width: 8),
        _TierBar(
          count: health.atRisk,
          label: 'At Risk',
          color: MediLoopColors.attention,
          total: health.total,
        ),
        const SizedBox(width: 8),
        _TierBar(
          count: health.watch,
          label: 'Watch',
          color: const Color(0xFFF59E0B),
          total: health.total,
        ),
        const SizedBox(width: 8),
        _TierBar(
          count: health.safe,
          label: 'Safe',
          color: MediLoopColors.verified,
          total: health.total,
        ),
      ],
    );
  }
}

class _TierBar extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final int total;

  const _TierBar({
    required this.count,
    required this.label,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;

    return Expanded(
      child: Column(
        children: [
          // Bar fill
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: MediLoopColors.lineLight,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      width: constraints.maxWidth * fraction,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: MediLoopText.inter(size: 10.5, color: MediLoopColors.textMuted),
              ),
              Text(
                count.toString(),
                style: MediLoopText.inter(
                  size: 11,
                  weight: FontWeight.w700,
                  color: count > 0 ? color : MediLoopColors.textSubtle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── High Risk Batch List ─────────────────────────────────────────────────────

class _HighRiskBatchList extends StatelessWidget {
  final List<({MedicineBatch batch, ExpiryRiskPrediction prediction})> rankedBatches;

  const _HighRiskBatchList({required this.rankedBatches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Expiry Risk Batches',
          style: MediLoopText.inter(
            size: 12,
            weight: FontWeight.w600,
            color: MediLoopColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...rankedBatches.map((item) => _RiskBatchRow(
              batch: item.batch,
              prediction: item.prediction,
            )),
      ],
    );
  }
}

class _RiskBatchRow extends StatelessWidget {
  final MedicineBatch batch;
  final ExpiryRiskPrediction prediction;

  const _RiskBatchRow({required this.batch, required this.prediction});

  Color get _tierColor => switch (prediction.tier) {
        BatchRiskTier.critical => MediLoopColors.critical,
        BatchRiskTier.atRisk => MediLoopColors.attention,
        BatchRiskTier.watch => const Color(0xFFF59E0B),
        BatchRiskTier.safe => MediLoopColors.verified,
      };

  String get _tierLabel => switch (prediction.tier) {
        BatchRiskTier.critical => 'CRITICAL',
        BatchRiskTier.atRisk => 'AT RISK',
        BatchRiskTier.watch => 'WATCH',
        BatchRiskTier.safe => 'SAFE',
      };

  @override
  Widget build(BuildContext context) {
    final pct = (prediction.probability * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MediLoopColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _tierColor.withValues(alpha: 0.2)),
          boxShadow: MediLoopShadows.card,
        ),
        child: Row(
          children: [
            // Risk indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tierColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.displayName,
                    style: MediLoopText.inter(
                      size: 13,
                      weight: FontWeight.w600,
                      color: MediLoopColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${batch.batchNumber} • ${prediction.daysToExpiry > 0 ? "Expires in ${prediction.daysToExpiry}d" : "EXPIRED ${prediction.daysToExpiry.abs()}d ago"}',
                    style: MediLoopText.inter(
                      size: 11,
                      color: MediLoopColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Risk percentage badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _tierColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    '$pct%',
                    style: MediLoopText.inter(
                      size: 13,
                      weight: FontWeight.w800,
                      color: _tierColor,
                    ),
                  ),
                  Text(
                    _tierLabel,
                    style: MediLoopText.inter(
                      size: 8.5,
                      weight: FontWeight.w700,
                      color: _tierColor,
                      letterSpacing: 0.3,
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
}

// ─── Loading placeholder ──────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: MediLoopColors.surface,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(color: MediLoopColors.line),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'ML model analyzing inventory...',
              style: MediLoopText.inter(size: 13, color: MediLoopColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
