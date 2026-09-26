import re

with open('lib/services/gemini_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unnecessary ! on non-nullable params (String? params after null check)
# Replace `expectedMedicineName!` with `expectedMedicineName` (already checked != null)
content = content.replace(
    "if (expectedMedicineName != null) 'Expected medicine: ' + expectedMedicineName!,",
    "if (expectedMedicineName != null) 'Expected medicine: $expectedMedicineName',",
)
content = content.replace(
    "if (expectedBatchNumber != null) 'Expected batch: ' + expectedBatchNumber!,",
    "if (expectedBatchNumber != null) 'Expected batch: $expectedBatchNumber',",
)

# Convert string concatenations to interpolations in the new methods (lines 650+)
# Do it by rewriting the key prompt/string sections using interpolation

# Fix ctx usage in prompt
content = content.replace(
    "          + (ctx.isNotEmpty ? 'Context: ' + ctx + ' ' : '')\n",
    "          + (ctx.isNotEmpty ? 'Context: $ctx ' : '')\n",
)

# Fix sentinelQuery method string concatenations
# Replace common patterns like: 'text' + variable + 'text' -> 'text$variable text'
# For the alertSummary line
old_alert = "          final alertSummary = alerts.take(20).map((a) =>\n          '[' + a.severity + '] ' + a.alertTypeLabel + ' Batch ' + (a.batchNumber ?? '?') + ' ' + a.status).join(', ');\n"
new_alert = "          final alertSummary = alerts.take(20).map((a) =>\n          '[${a.severity}] ${a.alertTypeLabel} Batch ${a.batchNumber ?? \"?\"} ${a.status}').join(', ');\n"
# Don't use Python format strings with dart interpolation - just do direct replacement
content = content.replace(
    "          '[' + a.severity + '] ' + a.alertTypeLabel + ' Batch ' + (a.batchNumber ?? '?') + ' ' + a.status).join(', ');",
    "          '[\\${a.severity}] \\${a.alertTypeLabel} Batch \\${a.batchNumber ?? \"?\"} \\${a.status}').join(', ');"
)

old_stats = "          final statsText = systemStats.entries.map((e) => e.key + ': ' + e.value.toString()).join(', ');\n"
new_stats = "          final statsText = systemStats.entries.map((e) => '\\${e.key}: \\${e.value}').join(', ');\n"
content = content.replace(
    "          final statsText = systemStats.entries.map((e) => e.key + ': ' + e.value.toString()).join(', ');",
    "          final statsText = systemStats.entries.map((e) => '\\${e.key}: \\${e.value}').join(', ');"
)

old_prompt = "          final prompt = 'CDSCO Sentinel AI analytics assistant. Answer question using ONLY the data. 2-4 sentences. Do not invent data.\\n'\n          'Stats: ' + statsText + '\\nAlerts: ' + alertSummary + '\\nQuestion: ' + question + '\\nAnswer:';"
new_prompt = "          final prompt = 'CDSCO Sentinel AI analytics assistant. Answer question using ONLY the data. 2-4 sentences. Do not invent data.\\n'\n          'Stats: \\$statsText\\nAlerts: \\$alertSummary\\nQuestion: \\$question\\nAnswer:';"
content = content.replace(
    "          final prompt = 'CDSCO Sentinel AI analytics assistant. Answer question using ONLY the data. 2-4 sentences. Do not invent data.\\n'\n          'Stats: ' + statsText + '\\nAlerts: ' + alertSummary + '\\nQuestion: ' + question + '\\nAnswer:';",
    "          final prompt = 'CDSCO Sentinel AI analytics assistant. Answer question using ONLY the data. 2-4 sentences. Do not invent data.\\n'\n          'Stats: \\$statsText\\nAlerts: \\$alertSummary\\nQuestion: \\$question\\nAnswer:';"
)

# Fix offline sentinel response
old_offline1 = "    return criticals.toString() + ' critical alerts require immediate CDSCO inspector action.';"
new_offline1 = "    return '\\${criticals} critical alerts require immediate CDSCO inspector action.';"
content = content.replace(old_offline1, new_offline1)

old_offline2 = "    return openAlerts.toString() + ' alerts are currently open and awaiting investigation.';"
new_offline2 = "    return '\\${openAlerts} alerts are currently open and awaiting investigation.';"
content = content.replace(old_offline2, new_offline2)

old_offline3 = "    return (systemStats['EXPIRED'] ?? 0).toString() + ' batches are EXPIRED. '\n        + (systemStats['ACTIVE'] ?? 0).toString() + ' are ACTIVE in the system.';"
new_offline3 = "    return '\\${systemStats[\"EXPIRED\"] ?? 0} batches are EXPIRED. \\${systemStats[\"ACTIVE\"] ?? 0} are ACTIVE in the system.';"
content = content.replace(
    "    return (systemStats['EXPIRED'] ?? 0).toString() + ' batches are EXPIRED. '\n        + (systemStats['ACTIVE'] ?? 0).toString() + ' are ACTIVE in the system.';",
    "    return '\\${systemStats[\"EXPIRED\"] ?? 0} batches are EXPIRED. \\${systemStats[\"ACTIVE\"] ?? 0} are ACTIVE in the system.';"
)

# Fix expiry briefing offline method string concatenations
old_b1 = "      return 'All inventory at ' + organizationName + ' is within CDSCO compliance.';"
new_b1 = "    return 'All inventory at \\$organizationName is within CDSCO compliance.';"
content = content.replace(old_b1, new_b1)

old_b2 = "    if (expiredCount > 0) parts.add(expiredCount.toString() + ' batch' + (expiredCount > 1 ? 'es' : '') + ' have expired and must be returned immediately');"
new_b2 = "    if (expiredCount > 0) parts.add('\\${expiredCount} batch\\${expiredCount > 1 ? \"es\" : \"\"} have expired and must be returned immediately');"
content = content.replace(old_b2, new_b2)

old_b3 = "    if (expiringCount > 0) parts.add(expiringCount.toString() + ' batch' + (expiringCount > 1 ? 'es are' : ' is') + ' expiring within 90 days');"
new_b3 = "    if (expiringCount > 0) parts.add('\\${expiringCount} batch\\${expiringCount > 1 ? \"es are\" : \" is\"} expiring within 90 days');"
content = content.replace(old_b3, new_b3)

old_b4 = "    return parts.join('. ') + '. ML risk engine flags ' + criticalRiskCount.toString() + ' as critical priority.';"
new_b4 = "    return '\\${parts.join(\". \")}. ML risk engine flags \\$criticalRiskCount as critical priority.';"
content = content.replace(old_b4, new_b4)

# Fix expiry briefing prompt concatenation
old_ep = (
    "      final prompt = 'Generate a 2-sentence compliance briefing for ' + organizationName + '. '\n"
    "          + expiredCount.toString() + ' expired batches in active stock, ' + expiringCount.toString() + ' expiring within 90 days, '\n"
    "          + criticalRiskCount.toString() + ' flagged critical by ML model. Be factual and action-oriented.';"
)
new_ep = (
    "      final prompt = 'Generate a 2-sentence compliance briefing for \\$organizationName. '\n"
    "          '\\$expiredCount expired batches in active stock, \\$expiringCount expiring within 90 days, '\n"
    "          '\\$criticalRiskCount flagged critical by ML model. Be factual and action-oriented.';"
)
content = content.replace(old_ep, new_ep)

# Fix ml_inventory_health_widget.dart string concatenation
with open('lib/widgets/ml_inventory_health_widget.dart', 'r', encoding='utf-8') as f:
    widget_content = f.read()

# Line ~345: 
old_w = "batch.batchNumber +\n                        ' • ${prediction.daysToExpiry > 0 ? "
# Already uses interpolation, just find the actual string + concat issue
idx = widget_content.find(" + ' • '")
if idx != -1:
    print('Found string concat in widget at index:', idx)
    print(repr(widget_content[idx-80:idx+80]))
else:
    print('No string concat found in widget')

with open('lib/services/gemini_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Gemini service fixed. Size:', len(content))
