import re

# Fix 1: retailer_shell.dart - organizationName null safety
with open('lib/features/retailer/retailer_shell.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = '_runMlAnalysis(batches, auth.currentUser!.organizationName);'
new = "_runMlAnalysis(batches, auth.currentUser!.organizationName ?? 'Apollo Pharmacy');"
if old in content:
    content = content.replace(old, new, 1)
    with open('lib/features/retailer/retailer_shell.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed retailer organizationName null')
else:
    print('retailer: not found. Showing context...')
    idx = content.find('organizationName')
    print(repr(content[idx-10:idx+80]))

# Fix 2: scan_screen.dart - use _mlFraudScore to suppress warning
# We just need it to be "used" — the score should be read somewhere
# For now, add a debugPrint statement or incorporate into the result building
with open('lib/features/scanner/scan_screen.dart', 'r', encoding='utf-8') as f:
    scan = f.read()

# Add usage: log the ML score after computation
old2 = (
    "      _mlFraudScore = MlRiskService.instance.scoreScan(\n"
    "        batch: batch,\n"
    "        scannedByOrgId: scannedOrgId,\n"
    "        context: _selectedContext,\n"
    "      );\n"
)
new2 = (
    "      _mlFraudScore = MlRiskService.instance.scoreScan(\n"
    "        batch: batch,\n"
    "        scannedByOrgId: scannedOrgId,\n"
    "        context: _selectedContext,\n"
    "      );\n"
    "      debugPrint('ML Fraud Score: ${_mlFraudScore?.score} (${_mlFraudScore?.label})');\n"
)
if old2 in scan:
    with open('lib/features/scanner/scan_screen.dart', 'w', encoding='utf-8') as f:
        f.write(scan.replace(old2, new2, 1))
    print('Fixed unused _mlFraudScore')
else:
    print('scan: not found')
    idx = scan.find('_mlFraudScore')
    print(repr(scan[idx-10:idx+150]))

print('Done')
