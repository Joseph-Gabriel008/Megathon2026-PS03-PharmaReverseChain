content = open('lib/features/admin/admin_shell.dart', 'r', encoding='utf-8').read()

# Check for CRLF vs LF
has_crlf = '\r\n' in content
print("CRLF:", has_crlf)
nl = '\r\n' if has_crlf else '\n'

# 1. Add sentinel fields after RealtimeChannel? _fraudChannel;
old1 = "  List<FraudAlert> _alerts = [];" + nl + "  bool _loading = true;" + nl + "  RealtimeChannel? _fraudChannel;"
new1 = (
    "  List<FraudAlert> _alerts = [];" + nl
    + "  bool _loading = true;" + nl
    + "  RealtimeChannel? _fraudChannel;" + nl
    + nl
    + "  // Sentinel AI query fields" + nl
    + "  final _sentinelCtrl = TextEditingController();" + nl
    + "  String? _sentinelAnswer;" + nl
    + "  bool _sentinelLoading = false;"
)
if old1 in content:
    content = content.replace(old1, new1, 1)
    print("Fields patched")
else:
    print("Fields NOT found")

# 2. Add dispose
old2 = "    _fraudChannel?.unsubscribe();" + nl + "    super.dispose();"
new2 = "    _fraudChannel?.unsubscribe();" + nl + "    _sentinelCtrl.dispose();" + nl + "    super.dispose();"
if old2 in content:
    content = content.replace(old2, new2, 1)
    print("Dispose patched")
else:
    print("Dispose NOT found")

# 3. Insert Sentinel widget before fraud alert feed
pad = "                  "
sentinel_widget = (
    pad + "// \u2500\u2500 Sentinel AI Query Panel \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500" + nl
    + pad + "Container(" + nl
    + pad + "  decoration: BoxDecoration(" + nl
    + pad + "    color: MediLoopColors.surface," + nl
    + pad + "    borderRadius: BorderRadius.circular(MediLoopRadius.card)," + nl
    + pad + "    border: Border.all(color: MediLoopColors.line)," + nl
    + pad + "    boxShadow: MediLoopShadows.card," + nl
    + pad + "  )," + nl
    + pad + "  padding: const EdgeInsets.all(MediLoopSpacing.md)," + nl
    + pad + "  child: Column(" + nl
    + pad + "    crossAxisAlignment: CrossAxisAlignment.start," + nl
    + pad + "    children: [" + nl
    + pad + "      Row(children: [" + nl
    + pad + "        Container(width: 28, height: 28," + nl
    + pad + "          decoration: BoxDecoration(color: MediLoopColors.accentBg, borderRadius: BorderRadius.circular(8))," + nl
    + pad + "          child: const Icon(Icons.auto_awesome, size: 14, color: MediLoopColors.accent))," + nl
    + pad + "        const SizedBox(width: 8)," + nl
    + pad + "        Text('Sentinel AI', style: MediLoopText.inter(size: 13.5, weight: FontWeight.w700, color: MediLoopColors.ink))," + nl
    + pad + "        const SizedBox(width: 6)," + nl
    + pad + "        Text('Ask anything about the supply chain', style: MediLoopText.caption.copyWith(fontSize: 11))," + nl
    + pad + "      ])," + nl
    + pad + "      const SizedBox(height: 10)," + nl
    + pad + "      Row(children: [" + nl
    + pad + "        Expanded(child: TextField(" + nl
    + pad + "          controller: _sentinelCtrl," + nl
    + pad + "          decoration: InputDecoration(" + nl
    + pad + "            hintText: 'e.g. How many critical alerts this week?'," + nl
    + pad + "            hintStyle: MediLoopText.inter(size: 13, color: MediLoopColors.textSubtle)," + nl
    + pad + "            filled: true, fillColor: MediLoopColors.paper," + nl
    + pad + "            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MediLoopColors.line))," + nl
    + pad + "            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)," + nl
    + pad + "          )," + nl
    + pad + "          style: MediLoopText.inter(size: 13, color: MediLoopColors.ink)," + nl
    + pad + "          onSubmitted: (_) => _askSentinel()," + nl
    + pad + "        ))," + nl
    + pad + "        const SizedBox(width: 8)," + nl
    + pad + "        FilledButton(" + nl
    + pad + "          onPressed: _sentinelLoading ? null : _askSentinel," + nl
    + pad + "          style: FilledButton.styleFrom(backgroundColor: MediLoopColors.accent, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))," + nl
    + pad + "          child: _sentinelLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 18, color: Colors.white)," + nl
    + pad + "        )," + nl
    + pad + "      ])," + nl
    + pad + "      if (_sentinelAnswer != null) ...[ " + nl
    + pad + "        const SizedBox(height: 10)," + nl
    + pad + "        Container(" + nl
    + pad + "          padding: const EdgeInsets.all(12)," + nl
    + pad + "          decoration: BoxDecoration(color: MediLoopColors.accentBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: MediLoopColors.accent.withValues(alpha: 0.2)))," + nl
    + pad + "          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [" + nl
    + pad + "            const Icon(Icons.auto_awesome, size: 14, color: MediLoopColors.accent)," + nl
    + pad + "            const SizedBox(width: 8)," + nl
    + pad + "            Expanded(child: Text(_sentinelAnswer!, style: MediLoopText.inter(size: 13, color: MediLoopColors.ink, height: 1.4)))," + nl
    + pad + "          ])," + nl
    + pad + ")," + nl
    + pad + "      ]," + nl
    + pad + "    ]," + nl
    + pad + "  )," + nl
    + pad + ")," + nl
    + pad + "const SizedBox(height: MediLoopSpacing.lg)," + nl
    + nl
)

old3 = pad + "// Fraud alert feed header" + nl + pad + "Row("
if old3 in content:
    content = content.replace(old3, sentinel_widget + pad + "// Fraud alert feed header" + nl + pad + "Row(", 1)
    print("Sentinel widget inserted")
else:
    print("Fraud header NOT found. Looking...")
    idx = content.find("Fraud alert feed header")
    print("Context:", repr(content[idx-30:idx+50]))

# 4. Add _askSentinel method before @override build
ask_method = (
    "  Future<void> _askSentinel() async {" + nl
    + "    final question = _sentinelCtrl.text.trim();" + nl
    + "    if (question.isEmpty) return;" + nl
    + "    setState(() => _sentinelLoading = true);" + nl
    + "    try {" + nl
    + "      final gemini = context.read<GeminiService>();" + nl
    + "      final answer = await gemini.sentinelQuery(question: question, alerts: _alerts, systemStats: _stageCounts);" + nl
    + "      if (mounted) setState(() { _sentinelAnswer = answer; _sentinelLoading = false; });" + nl
    + "    } catch (e) {" + nl
    + "      if (mounted) setState(() { _sentinelAnswer = 'Sentinel offline: ' + e.toString(); _sentinelLoading = false; });" + nl
    + "    }" + nl
    + "  }" + nl
    + nl
)

old4 = "  @override" + nl + "  Widget build(BuildContext context) {" + nl + "    return Scaffold("
if old4 in content:
    content = content.replace(old4, ask_method + old4, 1)
    print("_askSentinel method added")
else:
    print("build method not found")

open('lib/features/admin/admin_shell.dart', 'w', encoding='utf-8').write(content)
print("Saved, size:", len(content))
