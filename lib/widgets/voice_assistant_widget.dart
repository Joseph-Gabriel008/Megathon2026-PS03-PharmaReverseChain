import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/gemini_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MediLoop AI Voice Assistant
//  A floating, persistent AI companion that:
//    • Reads (dictates) screen content aloud via TTS
//    • Listens to voice queries via STT
//    • Answers using Gemini (with strong offline fallback)
//    • Remembers the last dictated context for follow-up questions
//    • Fully synced across app shells & dashboards
// ─────────────────────────────────────────────────────────────────────────────

// ── State Enum (Public) ───────────────────────────────────────────────────────

enum AssistantState {
  idle,
  speaking,
  listening,
  thinking,
}

// ── Controller ───────────────────────────────────────────────────────────────

class VoiceAssistantController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  AssistantState _state = AssistantState.idle;
  String? _lastSpoken;
  String? _transcript;
  String? _aiResponse;
  bool _sttAvailable = false;
  bool _isVisible = false;

  AssistantState get state => _state;
  String? get lastSpoken => _lastSpoken;
  String? get transcript => _transcript;
  String? get aiResponse => _aiResponse;
  bool get isVisible => _isVisible;
  bool get isSpeaking => _state == AssistantState.speaking;
  bool get isListening => _state == AssistantState.listening;
  bool get isThinking => _state == AssistantState.thinking;
  bool get sttAvailable => _sttAvailable;

  /// Shared screen context for follow-up Q&A and dictation
  String _screenContext = 'MediLoop pharmaceutical reverse logistics dashboard.';
  String get screenContext => _screenContext;

  VoiceAssistantController() {
    _initTts();
    _initStt();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.50);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() {
        if (_state == AssistantState.speaking) {
          _state = AssistantState.idle;
          notifyListeners();
        }
      });
      _tts.setErrorHandler((_) {
        _state = AssistantState.idle;
        notifyListeners();
      });
    } catch (_) {}
  }

  Future<void> _initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (_) {
          _state = AssistantState.idle;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (_) {
      _sttAvailable = false;
    }
  }

  void show() {
    _isVisible = true;
    notifyListeners();
  }

  void hide() {
    _isVisible = false;
    stopAll();
    notifyListeners();
  }

  void toggle() => _isVisible ? hide() : show();

  /// Sets the context text from the current screen for dictation & Q&A
  void setScreenContext(String context) {
    if (_screenContext != context) {
      _screenContext = context;
      notifyListeners();
    }
  }

  /// Sets user transcript text manually (e.g. from text input or suggestions)
  void setTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  /// Reads the provided text aloud
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      _state = AssistantState.speaking;
      _lastSpoken = text;
      notifyListeners();
      await _tts.speak(text);
    } catch (_) {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  /// Reads the current screen context aloud
  Future<void> dictateScreen() async {
    await speak(_screenContext);
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _state = AssistantState.idle;
    notifyListeners();
  }

  /// Starts listening for a voice query
  Future<void> startListening() async {
    if (!_sttAvailable) return;
    try {
      await _tts.stop();
      _state = AssistantState.listening;
      _transcript = null;
      _aiResponse = null;
      notifyListeners();

      await _stt.listen(
        onResult: (result) {
          _transcript = result.recognizedWords;
          notifyListeners();
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (_) {
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _state = AssistantState.idle;
    notifyListeners();
  }

  /// Submits a query to Gemini with the current screen context and reads the response
  Future<void> submitQuestion(String question, GeminiService gemini) async {
    final q = question.trim();
    if (q.isEmpty) return;

    _transcript = q;
    _state = AssistantState.thinking;
    _aiResponse = null;
    notifyListeners();

    try {
      final answer = await gemini.assistantQuery(
        question: q,
        screenContext: _screenContext,
      );

      _aiResponse = answer;
      _state = AssistantState.idle;
      notifyListeners();

      // Speak answer aloud
      await speak(answer);
    } catch (_) {
      _aiResponse = 'I encountered an issue processing your request. Please try again.';
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  /// Sends the current transcript to Gemini and reads the answer
  Future<void> askGemini(GeminiService gemini) async {
    final question = _transcript?.trim();
    if (question == null || question.isEmpty) return;
    await submitQuestion(question, gemini);
  }

  Future<void> stopAll() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (_stt.isListening) {
      try {
        await _stt.stop();
      } catch (_) {}
    }
    _state = AssistantState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

// ── Overlay Widget ────────────────────────────────────────────────────────────

/// Wraps any screen or shell body with the persistent floating AI orb & expandable panel.
class VoiceAssistantOverlay extends StatelessWidget {
  final Widget? child;
  const VoiceAssistantOverlay({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<VoiceAssistantController?>(context);
    if (ctrl == null) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (child != null) child!,
        if (ctrl.isVisible) const _AssistantPanel(),
        Positioned(
          bottom: 84,
          right: 16,
          child: _OrbButton(ctrl: ctrl),
        ),
      ],
    );
  }
}

// Backward-compatible alias
class VoiceAssistantFab extends StatelessWidget {
  const VoiceAssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return const VoiceAssistantOverlay();
  }
}

// ── Floating Orb Button ───────────────────────────────────────────────────────

class _OrbButton extends StatefulWidget {
  final VoiceAssistantController ctrl;
  const _OrbButton({required this.ctrl});

  @override
  State<_OrbButton> createState() => _OrbButtonState();
}

class _OrbButtonState extends State<_OrbButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final isActive = ctrl.isSpeaking || ctrl.isListening || ctrl.isThinking;

    Color orbColor = const Color(0xFF2563EB);
    IconData orbIcon = Icons.auto_awesome;

    if (ctrl.isSpeaking) {
      orbColor = MediLoopColors.verified;
      orbIcon = Icons.volume_up_rounded;
    } else if (ctrl.isListening) {
      orbColor = MediLoopColors.critical;
      orbIcon = Icons.mic_rounded;
    } else if (ctrl.isThinking) {
      orbColor = MediLoopColors.attention;
      orbIcon = Icons.psychology_rounded;
    } else if (ctrl.isVisible) {
      orbColor = MediLoopColors.accent;
      orbIcon = Icons.auto_awesome;
    }

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) {
        return Transform.scale(
          scale: isActive ? _scale.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => ctrl.toggle(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [orbColor, orbColor.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: orbColor.withValues(alpha: 0.45),
                blurRadius: isActive ? 24 : 14,
                spreadRadius: isActive ? 4 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(orbIcon, color: Colors.white, size: 24),
              if (isActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assistant Panel ───────────────────────────────────────────────────────────

class _AssistantPanel extends StatefulWidget {
  const _AssistantPanel();

  @override
  State<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<_AssistantPanel> {
  final _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VoiceAssistantController>();
    final gemini = context.read<GeminiService>();

    return Positioned(
      bottom: 148,
      right: 14,
      left: 14,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: MediLoopColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MediLoopColors.accent.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: MediLoopColors.ink.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(context, ctrl),
                const Divider(height: 1, color: MediLoopColors.line),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status chip
                      _buildStatusChip(ctrl),
                      const SizedBox(height: 12),

                      // Transcript or response
                      if (ctrl.transcript != null || ctrl.aiResponse != null)
                        _buildResponseBubble(ctrl),

                      if (ctrl.transcript == null && ctrl.aiResponse == null)
                        _buildWelcomeText(ctrl, gemini),

                      const SizedBox(height: 14),

                      // Text input row for typing questions (essential for demos!)
                      _buildTextInputRow(ctrl, gemini),

                      const SizedBox(height: 10),

                      // Action buttons (Read Screen, Mic, Stop)
                      _buildActionRow(context, ctrl, gemini),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VoiceAssistantController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MediLoopColors.accent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MediLoopColors.accentBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: MediLoopColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MediLoop AI Voice Companion',
                  style: MediLoopText.inter(
                    size: 14,
                    weight: FontWeight.w700,
                    color: MediLoopColors.ink,
                  ),
                ),
                Text(
                  'CDSCO Reverse Logistics & Sentinel Intelligence',
                  style: MediLoopText.inter(
                    size: 10.5,
                    color: MediLoopColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: MediLoopColors.textSubtle,
            tooltip: 'Close Assistant',
            onPressed: ctrl.hide,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(VoiceAssistantController ctrl) {
    final (label, color, icon) = switch (ctrl.state) {
      AssistantState.speaking => ('Speaking aloud…', MediLoopColors.verified, Icons.volume_up_rounded),
      AssistantState.listening => ('Listening…', MediLoopColors.critical, Icons.mic_rounded),
      AssistantState.thinking => ('Thinking with Gemini…', MediLoopColors.attention, Icons.psychology_rounded),
      AssistantState.idle => ('Ready · Synced with Screen', MediLoopColors.accent, Icons.auto_awesome),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusDot(color: color, animate: ctrl.state != AssistantState.idle),
              const SizedBox(width: 6),
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: MediLoopText.inter(
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (ctrl.isSpeaking)
          TextButton.icon(
            onPressed: ctrl.stopSpeaking,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 14, color: MediLoopColors.critical),
            label: Text('Stop Voice', style: MediLoopText.inter(size: 11, color: MediLoopColors.critical)),
          ),
      ],
    );
  }

  Widget _buildWelcomeText(VoiceAssistantController ctrl, GeminiService gemini) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can I assist your audit?',
          style: MediLoopText.inter(
            size: 13.5,
            weight: FontWeight.w600,
            color: MediLoopColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap "Read Screen" to dictate live data, use the microphone, or select a quick query below.',
          style: MediLoopText.inter(
            size: 12,
            color: MediLoopColors.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        // Quick suggestion chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SuggestionChip(
              label: 'Is Tablet Expired?',
              icon: Icons.schedule_rounded,
              onTap: () => ctrl.submitQuestion('Is the tablet expired or fresh?', gemini),
            ),
            _SuggestionChip(
              label: 'Is Serial Disposed?',
              icon: Icons.delete_sweep_rounded,
              onTap: () => ctrl.submitQuestion('Is the tablet with that serial number got disposed?', gemini),
            ),
            _SuggestionChip(
              label: 'Freshness Analysis',
              icon: Icons.science_rounded,
              onTap: () => ctrl.submitQuestion('Help in the analysis of the tablet whether it is expired or fresh.', gemini),
            ),
            _SuggestionChip(
              label: 'Dictate Screen',
              icon: Icons.volume_up_rounded,
              onTap: () => ctrl.dictateScreen(),
            ),
            _SuggestionChip(
              label: 'Fraud Status',
              icon: Icons.shield_outlined,
              onTap: () => ctrl.submitQuestion('What are the current fraud alerts and supply chain risks?', gemini),
            ),
            _SuggestionChip(
              label: 'Expired Batches',
              icon: Icons.warning_amber_rounded,
              onTap: () => ctrl.submitQuestion('What expired medicines require urgent return or disposal?', gemini),
            ),
            _SuggestionChip(
              label: 'CDSCO Compliance',
              icon: Icons.gavel_rounded,
              onTap: () => ctrl.submitQuestion('Explain CDSCO compliance requirements for reverse logistics.', gemini),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResponseBubble(VoiceAssistantController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctrl.transcript != null) ...[
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 13, color: MediLoopColors.textSubtle),
              const SizedBox(width: 5),
              Text(
                'Question',
                style: MediLoopText.inter(size: 11, weight: FontWeight.w600, color: MediLoopColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MediLoopColors.lineLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ctrl.transcript!,
              style: MediLoopText.inter(size: 12.5, color: MediLoopColors.ink, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (ctrl.aiResponse != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: MediLoopColors.accent),
                  const SizedBox(width: 5),
                  Text(
                    'MediLoop AI Response',
                    style: MediLoopText.inter(size: 11, weight: FontWeight.w600, color: MediLoopColors.accent),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded, size: 16, color: MediLoopColors.accent),
                tooltip: 'Replay Speech',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => ctrl.speak(ctrl.aiResponse!),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MediLoopColors.accentBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MediLoopColors.accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              ctrl.aiResponse!,
              style: MediLoopText.inter(size: 12.5, color: MediLoopColors.ink, height: 1.45),
            ),
          ),
        ],
        if (ctrl.isThinking)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MediLoopColors.attention),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini Sentinel is analyzing screen data…',
                  style: MediLoopText.inter(size: 12, color: MediLoopColors.attention),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextInputRow(VoiceAssistantController ctrl, GeminiService gemini) {
    return Container(
      decoration: BoxDecoration(
        color: MediLoopColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MediLoopColors.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 16, color: MediLoopColors.textSubtle),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: MediLoopText.inter(size: 12.5),
              decoration: const InputDecoration(
                hintText: 'Type question or command…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  ctrl.submitQuestion(val, gemini);
                  _inputCtrl.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            color: MediLoopColors.accent,
            onPressed: () {
              final val = _inputCtrl.text;
              if (val.trim().isNotEmpty) {
                ctrl.submitQuestion(val, gemini);
                _inputCtrl.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    VoiceAssistantController ctrl,
    GeminiService gemini,
  ) {
    return Row(
      children: [
        // Read screen aloud
        Expanded(
          child: _ActionButton(
            icon: ctrl.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            label: ctrl.isSpeaking ? 'Stop Audio' : 'Dictate Screen',
            color: ctrl.isSpeaking ? MediLoopColors.critical : MediLoopColors.verified,
            onTap: () {
              if (ctrl.isSpeaking) {
                ctrl.stopSpeaking();
              } else {
                ctrl.dictateScreen();
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Mic — listen
        Expanded(
          child: _ActionButton(
            icon: ctrl.isListening ? Icons.stop_rounded : Icons.mic_rounded,
            label: ctrl.isListening ? 'Listening… Tap to Stop' : 'Voice Query',
            color: ctrl.isListening ? MediLoopColors.critical : MediLoopColors.accent,
            onTap: () async {
              if (ctrl.isListening) {
                await ctrl.stopListening();
                if (ctrl.transcript != null) {
                  await ctrl.askGemini(gemini);
                }
              } else {
                await ctrl.startListening();
              }
            },
          ),
        ),

        if (ctrl.transcript != null && !ctrl.isThinking && ctrl.aiResponse == null) ...[
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.send_rounded,
            label: 'Ask AI',
            color: MediLoopColors.accent,
            onTap: () => ctrl.askGemini(gemini),
          ),
        ],
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _StatusDot({required this.color, required this.animate});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MediLoopColors.lineLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MediLoopColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: MediLoopColors.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: MediLoopText.inter(
                size: 11.5,
                weight: FontWeight.w600,
                color: MediLoopColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: MediLoopText.inter(
                size: 10.5,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
