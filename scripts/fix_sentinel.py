with open('lib/services/gemini_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Find bounds of the offline sentinel method
start_marker = '  String _offlineSentinelResponse(String question, List<FraudAlert> alerts, Map<String, int> systemStats) {'
end_marker_after = '  // ── AI-6: Smart Expiry Risk Narrative'

start_idx = c.find(start_marker)
end_idx = c.find(end_marker_after)

if start_idx == -1 or end_idx == -1:
    print('Markers not found')
    print('start:', start_idx, 'end:', end_idx)
else:
    # Replace the entire method
    new_method = (
        '  String _offlineSentinelResponse(String question, List<FraudAlert> alerts, Map<String, int> systemStats) {\n'
        '    // --- Offline Sentinel AI Engine v2 --- Rich multi-signal NL responder\n'
        '    final q = question.toLowerCase();\n'
        '    final openAlerts = alerts.where((a) => a.status == \'OPEN\').length;\n'
        '    final closedAlerts = alerts.where((a) => a.status == \'CLOSED\').length;\n'
        '    final criticals = alerts.where((a) => a.isCritical).length;\n'
        '    final reentryCount = alerts.where((a) => a.alertType == \'DESTROYED_BATCH_REENTRY\').length;\n'
        '    final expiredSaleCount = alerts.where((a) => a.alertType == \'EXPIRED_BATCH_SALE\').length;\n'
        '    final qtyMismatch = alerts.where((a) => a.alertType == \'QUANTITY_MISMATCH\').length;\n'
        '    final totalBatches = (systemStats[\'ACTIVE\'] ?? 0) + (systemStats[\'EXPIRED\'] ?? 0)\n'
        '        + (systemStats[\'EXPIRING_SOON\'] ?? 0);\n'
        '\n'
        '    if (q.contains(\'critical\') || q.contains(\'serious\') || q.contains(\'urgent\')) {\n'
        '      if (criticals == 0) return \'No critical alerts are currently active. All high-priority flags have been resolved or are under investigation.\';\n'
        '      final reText = reentryCount > 0 ? \'$reentryCount involve destroyed-batch reentry — a direct counterfeit risk. \' : \'\';\n'
        '      return \'$criticals critical alert${criticals > 1 ? "s require" : " requires"} immediate CDSCO inspector intervention. $reText\';\n'
        '    }\n'
        '    if (q.contains(\'reentry\') || q.contains(\'destroyed\') || q.contains(\'counterfeit\')) {\n'
        '      if (reentryCount == 0) return \'No destroyed-batch reentry events detected. The supply chain is free of known ghost-batch fraud.\';\n'
        '      return \'$reentryCount destroyed-batch reentry event${reentryCount > 1 ? "s were" : " was"} detected — a serious CDSCO violation indicating counterfeiting.\';\n'
        '    }\n'
        '    if (q.contains(\'expired\') || q.contains(\'expir\')) {\n'
        '      final expired = systemStats[\'EXPIRED\'] ?? 0;\n'
        '      final expiring = systemStats[\'EXPIRING_SOON\'] ?? 0;\n'
        '      final fraudText = expiredSaleCount > 0 ? \'$expiredSaleCount expired-batch sale fraud alert${expiredSaleCount > 1 ? "s" : ""} detected.\' : \'No expired-batch sale fraud detected currently.\';\n'
        '      return \'$expired batch${expired != 1 ? "es are" : " is"} expired and flagged for mandatory return. $expiring more expiring within 90 days. $fraudText\';\n'
        '    }\n'
        '    if (q.contains(\'open\') || q.contains(\'pending\') || q.contains(\'unresolved\')) {\n'
        '      if (openAlerts == 0) return \'All fraud alerts are resolved. The sentinel feed is clear with no open investigations.\';\n'
        '      final closedText = closedAlerts > 0 ? \'$closedAlerts have been resolved in this session. \' : \'\';\n'
        '      return \'$openAlerts alert${openAlerts > 1 ? "s are" : " is"} currently open and awaiting investigation. ${closedText}Prioritize critical alerts for immediate review.\';\n'
        '    }\n'
        '    if (q.contains(\'quantity\') || q.contains(\'mismatch\') || q.contains(\'diversion\')) {\n'
        '      if (qtyMismatch == 0) return \'No quantity mismatch alerts detected. All verified pickups match their return requests.\';\n'
        '      return \'$qtyMismatch quantity mismatch ${qtyMismatch > 1 ? "discrepancies were" : "discrepancy was"} detected. Immediate chain-of-custody audit is recommended.\';\n'
        '    }\n'
        '    if (q.contains(\'total\') || q.contains(\'how many\') || q.contains(\'count\') || q.contains(\'summary\')) {\n'
        '      return \'Supply chain: $totalBatches total batches — ${systemStats["ACTIVE"] ?? 0} ACTIVE, ${systemStats["EXPIRED"] ?? 0} EXPIRED, ${systemStats["EXPIRING_SOON"] ?? 0} EXPIRING SOON. ${alerts.length} fraud events, $openAlerts open, $criticals critical.\';\n'
        '    }\n'
        '    if (q.contains(\'safe\') || q.contains(\'clean\') || q.contains(\'compliant\')) {\n'
        '      if (openAlerts == 0 && criticals == 0) return \'Supply chain is currently clean. No open fraud alerts or critical flags detected.\';\n'
        '      return \'The supply chain has $openAlerts open alert${openAlerts != 1 ? "s" : ""} and $criticals critical flag${criticals != 1 ? "s" : ""}. Full compliance cannot be confirmed until these are resolved.\';\n'
        '    }\n'
        '    return \'Sentinel status: ${alerts.length} total events, $openAlerts open, $criticals critical. ${systemStats["EXPIRED"] ?? 0} expired, ${systemStats["EXPIRING_SOON"] ?? 0} expiring soon. Ask a specific question for a targeted analysis.\';\n'
        '  }\n'
        '\n'
    )
    c = c[:start_idx] + new_method + c[end_idx:]
    with open('lib/services/gemini_service.dart', 'w', encoding='utf-8') as f:
        f.write(c)
    print('Method replaced. New size:', len(c))
