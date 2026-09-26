// lib/services/ml_risk_service.dart
//
// MediLoop ML Risk Engine — client-side, deterministic, zero-dependency.
//
// Model 1: FRAUD_RISK_SCORER — 0-100 scan risk score, 8 weighted signals
// Model 2: EXPIRY_RISK_PREDICTOR — probability a batch expires unsold
// Model 3: BATCH_HEALTH_CLASSIFIER — portfolio-level inventory health tiers

import 'package:flutter/foundation.dart';
import '../models/medicine_batch.dart';
import '../models/scan_context.dart';

// ─── Output Types ─────────────────────────────────────────────────────────────

enum BatchRiskTier { safe, watch, atRisk, critical }

class FraudRiskScore {
  final int score;
  final Map<String, int> signalBreakdown;
  final String label;
  final String? topReason;

  const FraudRiskScore({
    required this.score,
    required this.signalBreakdown,
    required this.label,
    this.topReason,
  });

  bool get isHighRisk => score >= 60;
  bool get isCriticalRisk => score >= 85;
}

class ExpiryRiskPrediction {
  final double probability;
  final String recommendation;
  final BatchRiskTier tier;
  final int daysToExpiry;
  final int? recommendReturnIn;

  const ExpiryRiskPrediction({
    required this.probability,
    required this.recommendation,
    required this.tier,
    required this.daysToExpiry,
    this.recommendReturnIn,
  });
}

class BatchHealthSummary {
  final int safe;
  final int watch;
  final int atRisk;
  final int critical;
  final int total;
  final List<({MedicineBatch batch, ExpiryRiskPrediction prediction})> rankedBatches;

  const BatchHealthSummary({
    required this.safe,
    required this.watch,
    required this.atRisk,
    required this.critical,
    required this.total,
    required this.rankedBatches,
  });

  double get riskPercentage =>
      total == 0 ? 0 : (atRisk + critical) / total * 100;
}

// ─── ML Risk Service ──────────────────────────────────────────────────────────

class MlRiskService {
  static final MlRiskService instance = MlRiskService._();
  MlRiskService._();

  // ─── Model 1: Fraud Risk Scorer ───────────────────────────────────────────

  static const Map<String, int> _signalWeights = {
    'already_destroyed': 40,
    'already_expired_active': 25,
    'wrong_org_custody': 20,
    'quantity_near_zero': 10,
    'no_verification_state': 7,
    'stale_since_days': 5,
  };

  FraudRiskScore scoreScan({
    required MedicineBatch batch,
    required String scannedByOrgId,
    required ScanContext context,
    int? daysSinceLastUpdate,
  }) {
    final breakdown = <String, int>{};
    int total = 0;
    String? topReason;

    if (batch.isDestroyed && context.triggersDestroyedReentry) {
      final s = _signalWeights['already_destroyed']!;
      breakdown['already_destroyed'] = s;
      total += s;
      topReason ??=
          'Batch marked as destroyed — re-entry into supply chain is a critical fraud signal';
    }

    if (batch.isExpired &&
        (batch.status == 'ACTIVE' || batch.status == 'EXPIRING_SOON')) {
      final s = _signalWeights['already_expired_active']!;
      breakdown['already_expired_active'] = s;
      total += s;
      topReason ??=
          'Batch is past expiry but database status is still ACTIVE — stale record or deliberate suppression';
    }

    if (batch.pharmacyId != null &&
        batch.pharmacyId != scannedByOrgId &&
        const {'ACTIVE', 'EXPIRING_SOON', 'EXPIRED'}.contains(batch.status) &&
        (context == ScanContext.activeStockCheck ||
            context == ScanContext.inventoryCheck)) {
      final s = _signalWeights['wrong_org_custody']!;
      breakdown['wrong_org_custody'] = s;
      total += s;
      topReason ??=
          'Batch belongs to a different pharmacy — unauthorized custody';
    }

    if (batch.currentQuantity <= 2 && batch.originalQuantity > 10) {
      final s = _signalWeights['quantity_near_zero']!;
      breakdown['quantity_near_zero'] = s;
      total += s;
      topReason ??=
          'Only ${batch.currentQuantity} units remain of ${batch.originalQuantity} — possible diversion';
    }

    if (batch.isDeclaredOnly && batch.isExpired) {
      final s = _signalWeights['no_verification_state']!;
      breakdown['no_verification_state'] = s;
      total += s;
      topReason ??=
          'Batch expired without ever passing a verification checkpoint';
    }

    if (daysSinceLastUpdate != null &&
        daysSinceLastUpdate > 14 &&
        const {'IN_TRANSIT', 'PICKUP_ASSIGNED', 'COLLECTED'}
            .contains(batch.status)) {
      final excess = (daysSinceLastUpdate - 14).clamp(0, 30);
      final s = ((_signalWeights['stale_since_days']! * excess / 30))
          .round()
          .clamp(0, _signalWeights['stale_since_days']!);
      if (s > 0) {
        breakdown['stale_since_days'] = s;
        total += s;
        topReason ??=
            'Batch stuck in ${batch.status} for $daysSinceLastUpdate days — possible diversion';
      }
    }

    total = total.clamp(0, 100);

    final label = switch (total) {
      >= 85 => 'CRITICAL RISK',
      >= 60 => 'HIGH RISK',
      >= 30 => 'ELEVATED',
      >= 10 => 'LOW RISK',
      _ => 'CLEAN',
    };

    debugPrint(
        'MlRiskService: score=$total batch=${batch.batchNumber} [${breakdown.keys.join(", ")}]');

    return FraudRiskScore(
      score: total,
      signalBreakdown: breakdown,
      label: label,
      topReason: topReason,
    );
  }

  // ─── Model 2: Expiry Risk Predictor ───────────────────────────────────────

  ExpiryRiskPrediction predictExpiryRisk(MedicineBatch batch) {
    final now = DateTime.now();
    final daysToExpiry = batch.expiryDate.difference(now).inDays;

    if (daysToExpiry <= 0) {
      final isStillActive =
          batch.status == 'ACTIVE' || batch.status == 'EXPIRING_SOON';
      return ExpiryRiskPrediction(
        probability: isStillActive ? 0.98 : 0.6,
        recommendation: isStillActive
            ? '⛔ Immediately remove from shelf and initiate return request'
            : 'Return in progress — verify pickup is scheduled',
        tier: BatchRiskTier.critical,
        daysToExpiry: daysToExpiry,
      );
    }

    final quantityRatio = batch.originalQuantity > 0
        ? batch.currentQuantity / batch.originalQuantity
        : 0.0;

    const k = 0.035;
    final pTime = _sigmoid(k * (60 - daysToExpiry));

    final combined = (pTime * 0.7 + quantityRatio * 0.3).clamp(0.0, 1.0);

    double statusModifier = 1.0;
    if (batch.status == 'RETURN_INITIATED' ||
        batch.status == 'RETURN_DECLARED') {
      statusModifier = 0.3;
    } else if (batch.status == 'EXPIRING_SOON') {
      statusModifier = 1.2;
    }

    final probability = (combined * statusModifier).clamp(0.0, 1.0);

    final tier = switch (probability) {
      >= 0.75 => BatchRiskTier.critical,
      >= 0.50 => BatchRiskTier.atRisk,
      >= 0.25 => BatchRiskTier.watch,
      _ => BatchRiskTier.safe,
    };

    int? recommendReturnIn;
    if (tier == BatchRiskTier.critical || tier == BatchRiskTier.atRisk) {
      recommendReturnIn = (daysToExpiry - 7).clamp(0, daysToExpiry);
    }

    return ExpiryRiskPrediction(
      probability: probability,
      recommendation: _buildRecommendation(
        tier: tier,
        daysToExpiry: daysToExpiry,
        probability: probability,
        recommendReturnIn: recommendReturnIn,
        batchNumber: batch.batchNumber,
      ),
      tier: tier,
      daysToExpiry: daysToExpiry,
      recommendReturnIn: recommendReturnIn,
    );
  }

  double _sigmoid(double x) => 1.0 / (1.0 + _approxExp(-x));

  double _approxExp(double x) {
    if (x > 20) return double.maxFinite;
    if (x < -20) return 0.0;
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= x / i;
      result += term;
    }
    return result < 0 ? 0.0 : result;
  }

  String _buildRecommendation({
    required BatchRiskTier tier,
    required int daysToExpiry,
    required double probability,
    required int? recommendReturnIn,
    required String batchNumber,
  }) {
    final pct = (probability * 100).round();
    return switch (tier) {
      BatchRiskTier.critical =>
        '🚨 $pct% expiry risk for $batchNumber. Return must be initiated immediately — expires in $daysToExpiry days.',
      BatchRiskTier.atRisk =>
        '⚠️ $pct% expiry risk. Initiate return within ${recommendReturnIn ?? daysToExpiry} days to meet CDSCO deadline.',
      BatchRiskTier.watch =>
        '📋 $pct% expiry risk. Monitor $batchNumber — return recommended within ${(daysToExpiry - 7).clamp(0, daysToExpiry)} days.',
      BatchRiskTier.safe =>
        '✅ Low expiry risk ($pct%). $batchNumber is within safe sell-through window.',
    };
  }

  // ─── Model 3: Batch Health Classifier ────────────────────────────────────

  static const _pipelineStatuses = {
    'RETURN_INITIATED', 'RETURN_DECLARED', 'IN_TRANSIT', 'COLLECTED',
    'DISTRIBUTOR_VERIFIED', 'MANUFACTURER_RECEIVED', 'DISPOSAL_PENDING',
    'SENT_FOR_DESTRUCTION', 'DESTROYED', 'DESTRUCTION_RECORDED',
    'CERTIFICATION_PENDING', 'CERTIFIED', 'CLOSED',
  };

  BatchHealthSummary classifyInventoryHealth(List<MedicineBatch> batches) {
    int safe = 0, watch = 0, atRisk = 0, critical = 0;
    final ranked =
        <({MedicineBatch batch, ExpiryRiskPrediction prediction})>[];

    for (final batch in batches) {
      if (_pipelineStatuses.contains(batch.status)) continue;

      final prediction = predictExpiryRisk(batch);
      ranked.add((batch: batch, prediction: prediction));

      switch (prediction.tier) {
        case BatchRiskTier.safe:
          safe++;
        case BatchRiskTier.watch:
          watch++;
        case BatchRiskTier.atRisk:
          atRisk++;
        case BatchRiskTier.critical:
          critical++;
      }
    }

    ranked.sort((a, b) =>
        b.prediction.probability.compareTo(a.prediction.probability));

    return BatchHealthSummary(
      safe: safe,
      watch: watch,
      atRisk: atRisk,
      critical: critical,
      total: ranked.length,
      rankedBatches: ranked,
    );
  }
}
