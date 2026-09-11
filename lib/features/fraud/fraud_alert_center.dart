import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../repositories/organization_repository.dart';
import '../../models/batch_event.dart';
import '../../widgets/batch_card.dart';

import '../../services/auth_service.dart';

class FraudAlertCenter extends StatefulWidget {
  const FraudAlertCenter({super.key});

  @override
  State<FraudAlertCenter> createState() => _FraudAlertCenterState();
}

class _FraudAlertCenterState extends State<FraudAlertCenter> {
  List<FraudAlert> _alerts = [];
  bool _loading = true;
  String? _severityFilter;
  String? _statusFilter;
  String? _typeFilter;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<OrganizationRepository>();
    final data = await repo.getFraudAlerts(
      severity: _severityFilter,
      status: _statusFilter,
      alertType: _typeFilter,
    );
    if (mounted) {
      setState(() {
        _alerts = data;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(FraudAlert alert, String newStatus) async {
    final repo = context.read<OrganizationRepository>();
    final auth = context.read<AuthService>();

    if (newStatus == 'RESOLVED' || newStatus == 'FALSE_POSITIVE') {
      final notes = await _showResolutionDialog(alert, newStatus);
      if (notes == null) return; // User cancelled

      await repo.updateFraudAlertStatus(
        alertId: alert.id,
        status: newStatus,
        resolvedBy: auth.currentUser?.id,
        resolutionNotes: notes,
      );
    } else {
      await repo.updateFraudAlertStatus(
        alertId: alert.id,
        status: newStatus,
      );
    }
    await _load();
  }

  Future<String?> _showResolutionDialog(FraudAlert alert, String newStatus) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          newStatus == 'RESOLVED' ? 'Resolve Alert' : 'Mark as False Positive',
          style: MediLoopText.h4,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document findings and corrective action for batch ${alert.batchNumber ?? alert.batchId}:',
              style: MediLoopText.bodyMuted,
            ),
            const SizedBox(height: MediLoopSpacing.sm),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter mandatory resolution notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Resolution notes are required.')),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(title: const Text('Fraud Alert Center')),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: MediLoopSpacing.md, vertical: MediLoopSpacing.sm),
            child: Row(
              children: [
                Text('Severity:', style: MediLoopText.caption),
                const SizedBox(width: 8),
                ...[null, 'CRITICAL', 'HIGH', 'MEDIUM'].map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(s ?? 'All'),
                      selected: _severityFilter == s,
                      onSelected: (_) {
                        setState(() => _severityFilter = s);
                        _load();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Status:', style: MediLoopText.caption),
                const SizedBox(width: 8),
                ...[null, 'OPEN', 'INVESTIGATING', 'RESOLVED'].map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(s ?? 'All'),
                      selected: _statusFilter == s,
                      onSelected: (_) {
                        setState(() => _statusFilter = s);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _alerts.isEmpty
                    ? const EmptyState(
                        what: 'No fraud alerts match the current filters.',
                        action: 'Clear filters or wait for new alerts.',
                        icon: Icons.security_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(MediLoopSpacing.md),
                        itemCount: _alerts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: MediLoopSpacing.sm),
                        itemBuilder: (_, i) {
                          final alert = _alerts[i];
                          return FraudAlertCard(
                            alert: alert,
                            expanded: _expandedId == alert.id,
                            onTap: () => setState(() =>
                                _expandedId =
                                    _expandedId == alert.id
                                        ? null
                                        : alert.id),
                            onAction: (action) =>
                                _updateStatus(alert, action),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
