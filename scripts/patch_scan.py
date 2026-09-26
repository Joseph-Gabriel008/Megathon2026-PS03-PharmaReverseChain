content = open('lib/features/scanner/scan_screen.dart', 'r', encoding='utf-8').read()

ml_block = (
    "      // ML Model 1: Fraud Risk Scorer\n"
    "      final scannedOrgId = context.read<AuthService>().currentUser?.organizationId ?? '';\n"
    "      _mlFraudScore = MlRiskService.instance.scoreScan(\n"
    "        batch: batch,\n"
    "        scannedByOrgId: scannedOrgId,\n"
    "        context: _selectedContext,\n"
    "      );\n"
    "\n"
)

marker = "      // 1b. Cross-validate OCR extraction against DB"
idx = content.find(marker)
if idx == -1:
    # CRLF
    marker = "      // 1b. Cross-validate OCR extraction against DB"
    idx = content.find(marker)

if idx == -1:
    print("marker not found")
else:
    new_content = content[:idx] + ml_block + content[idx:]
    open('lib/features/scanner/scan_screen.dart', 'w', encoding='utf-8').write(new_content)
    print("patched ok, new size:", len(new_content))
