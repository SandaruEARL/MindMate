import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mindmate/features/mood_tracking/services/mood_tracking_gemini_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';

// ── Mood data ─────────────────────────────────────────────────────────────────

class _Mood {
  const _Mood({required this.emoji, required this.label, required this.color});
  final String emoji;
  final String label;
  final Color color;
}

const _moods = [
  _Mood(emoji: '😄', label: 'Great', color: Color(0xFF4CAF82)),
  _Mood(emoji: '🙂', label: 'Good', color: Color(0xFF6C63FF)),
  _Mood(emoji: '😐', label: 'Okay', color: Color(0xFFFFA726)),
  _Mood(emoji: '😔', label: 'Sad', color: Color(0xFF2196F3)),
  _Mood(emoji: '😞', label: 'Struggling', color: Color(0xFFE05C5C)),
  _Mood(emoji: '😠', label: 'Angry', color: Color(0xFFD32F2F)),
];

// ── Conversation turn model ───────────────────────────────────────────────────

enum _Speaker { assistant, user }

class _Turn {
  _Turn({required this.speaker, required this.text, this.isPreset = false});
  final _Speaker speaker;
  final String text;
  final bool isPreset;
}

// ── MoodTrackingPage ──────────────────────────────────────────────────────────

class MoodTrackingPage extends StatefulWidget {
  const MoodTrackingPage({super.key});

  @override
  State<MoodTrackingPage> createState() => _MoodTrackingPageState();
}

class _MoodTrackingPageState extends State<MoodTrackingPage> {
  final MoodGeminiService _gemini = MoodGeminiService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final ScrollController _scrollController = ScrollController();

  _Mood? _selectedMood;
  final List<_Turn> _turns = [];
  bool _isBotThinking = false;
  bool _isListening = false;
  bool _sttAvailable = false;
  bool _conversationEnded = false;
  bool _isNavigating = false;
  String _recognizedText = '';
  String _statusLabel = 'Tap the mic and speak';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initStt();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak('Tap how you are feeling right now.');
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) {
        debugPrint('[STT] $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusLabel = 'Error. Try again.';
          });
        }
      },
      onStatus: (s) {
        debugPrint('[STT] $s');
        if ((s == 'done' || s == 'notListening') && _isListening && mounted) {
          _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _gemini.resetSession();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Mood selection ────────────────────────────────────────────────────

  Future<void> _onMoodSelected(_Mood mood) async {
    if (_isBotThinking) return;

    setState(() {
      _selectedMood = mood;
      _turns.clear();
      _isBotThinking = false;
      _conversationEnded = false;
      _statusLabel = 'Tap the mic and speak';
    });

    await _tts.stop();
    await _tts.speak('You selected ${mood.label}.');

    final firstQuestion = _gemini.startSession(mood.label);
    _addAssistantTurn(firstQuestion, isPreset: true);
    await _tts.speak(firstQuestion);
    setState(() => _statusLabel = 'Tap the mic and speak');
  }

  // ── Voice input ───────────────────────────────────────────────────────

  Future<void> _onMicTap() =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    if (_isBotThinking || _conversationEnded) return;
    if (!_sttAvailable) {
      await _tts.speak('Speech recognition is not available on this device.');
      return;
    }

    await _tts.stop();
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusLabel = 'Listening…';
    });

    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _recognizedText = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    final spoken = _recognizedText.trim();
    setState(() {
      _isListening = false;
      _recognizedText = '';
      _statusLabel = spoken.isEmpty ? 'Tap the mic and speak' : 'Processing…';
    });

    if (spoken.isEmpty) {
      await _tts.speak("I didn't catch that. Please try again.");
      setState(() => _statusLabel = 'Tap the mic and speak');
      return;
    }

    // Navigation commands always take priority, regardless of mood selection state
    final navigated = await _checkVoiceNavigation(spoken);
    if (navigated) return;

    if (_selectedMood == null) {
      _Mood? matched;
      for (final m in _moods) {
        if (spoken.toLowerCase().contains(m.label.toLowerCase())) {
          matched = m;
          break;
        }
      }
      if (matched != null) {
        await _onMoodSelected(matched);
      } else {
        await _tts.speak(
          'I heard "$spoken" but please tap or say your mood: '
          'Great, Good, Okay, Sad, Struggling, or Angry.',
        );
        setState(() => _statusLabel = 'Tap the mic and speak');
      }
      return;
    }

    _addUserTurn(spoken, isPreset: _gemini.isPresetPhase);
    setState(() {
      _isBotThinking = true;
      _statusLabel = 'Processing…';
    });
    _scrollToBottom();

    final reply = await _gemini.chat(spoken);
    await _handleReply(reply);
  }

  // ── Voice navigation commands ─────────────────────────────────────────
  // Keywords map: each entry holds the keywords that trigger it, a spoken
  // confirmation, and either a page to push or a pop-to-home flag.

  Future<bool> _checkVoiceNavigation(String spoken) async {
    final t = spoken.toLowerCase();

    // "go back" / "home" / "go home" → pop back to HomePage
    if (t.contains('home') ||
        t.contains('go back') ||
        t.contains('back to home') ||
        t.contains('main menu') ||
        t.contains('main page')) {
      await _tts.stop();
      await _tts.speak('Going back to the home page.');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return true;
    }

    // Emergency
    if (t.contains('emergency') ||
        t.contains('crisis') ||
        t.contains('urgent') ||
        t.contains('help me')) {
      await _tts.stop();
      await _tts.speak('Opening Emergency Support.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencySupportPage()),
        );
      }
      return true;
    }

    // Breathing exercises
    if (t.contains('breath') ||
        t.contains('breathing') ||
        t.contains('relax') ||
        t.contains('calm')) {
      await _tts.stop();
      await _tts.speak('Opening Breathing Exercises.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BreathingExercisesPage()),
        );
      }
      return true;
    }

    // Mindfulness
    if (t.contains('mindful') ||
        t.contains('meditat') ||
        t.contains('mindfulness') ||
        t.contains('aware')) {
      await _tts.stop();
      await _tts.speak('Opening Mindfulness.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MindfulnessPage()),
        );
      }
      return true;
    }

    // Sleep hygiene
    if (t.contains('sleep') ||
        t.contains('bedtime') ||
        t.contains('hygiene') ||
        t.contains('insomnia') ||
        t.contains('rest')) {
      await _tts.stop();
      await _tts.speak('Opening Sleep Hygiene.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SleepVuiScreen()),
        );
      }
      return true;
    }

    return false; // not a navigation command — continue normal flow
  }

  Future<void> _handleReply(String reply) async {
    debugPrint('[MOOD] _handleReply called with: "$reply"');
    debugPrint('[MOOD] isNavigating: $_isNavigating');

    // Guard against multiple simultaneous navigation attempts
    if (_isNavigating) {
      debugPrint('[MOOD] Already navigating, ignoring reply');
      return;
    }

    // Upper-casing string to safely match keywords using .contains
    final upperReply = reply.toUpperCase();
    debugPrint('[MOOD] Checking upperReply: "$upperReply"');

    if (upperReply.contains('CRISIS')) {
      debugPrint('[MOOD] CRISIS detected!');
      _isNavigating = true;
      final msg =
          'I can hear that you are really struggling. Taking you to Emergency Support now.';

      _addAssistantTurn(msg, isPreset: false);
      _scrollToBottom();
      await _tts.speak(msg);

      if (!mounted) {
        debugPrint('[MOOD] Widget unmounted during TTS, aborting navigation');
        _isNavigating = false;
        return;
      }

      setState(() {
        _isBotThinking = false;
        _statusLabel = 'Tap the mic and speak';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF3F51B5),
          content: Text(
            'Navigating to /crisis',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Small delay to ensure UI state is settled before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) {
        debugPrint('[MOOD] Widget unmounted before navigation, aborting');
        _isNavigating = false;
        return;
      }

      debugPrint('[MOOD] Performing navigation to EmergencySupportPage');
      if (mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EmergencySupportPage()));
        debugPrint('[MOOD] Navigation completed, resetting guard');
      }

      _isNavigating = false;
      return;
    }

    if (upperReply.contains('HANDOFF:/BREATHING')) {
      debugPrint('[MOOD] HANDOFF:/BREATHING detected!');
      _isNavigating = true;
      final msg = 'Let me take you to Breathing Exercises.';

      _addAssistantTurn(msg, isPreset: false);
      _scrollToBottom();
      await _tts.speak(msg);

      if (!mounted) {
        debugPrint('[MOOD] Widget unmounted during TTS, aborting navigation');
        _isNavigating = false;
        return;
      }

      setState(() {
        _isBotThinking = false;
        _statusLabel = 'Tap the mic and speak';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF3F51B5),
          content: Text(
            'Navigating to /breathing',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Small delay to ensure UI state is settled before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) {
        debugPrint('[MOOD] Widget unmounted before navigation, aborting');
        _isNavigating = false;
        return;
      }

      debugPrint('[MOOD] Performing navigation to BreathingExercisesPage');
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BreathingExercisesPage()),
        );
        debugPrint('[MOOD] Navigation completed, resetting guard');
      }

      _isNavigating = false;
      return;
    }

    debugPrint('[MOOD] No sentinel detected, normal response handling');
    final isPresetReply = _gemini.isPresetPhase;
    final isEnded = _gemini.isConversationEnded;

    setState(() {
      _isBotThinking = false;
      _conversationEnded = isEnded;
      _statusLabel = isEnded ? 'Session complete' : 'Tap the mic and speak';
    });

    _addAssistantTurn(reply, isPreset: isPresetReply);
    _scrollToBottom();
    await _tts.speak(reply);
  }

  void _addAssistantTurn(String text, {bool isPreset = false}) {
    setState(
      () => _turns.add(
        _Turn(speaker: _Speaker.assistant, text: text, isPreset: isPreset),
      ),
    );
  }

  void _addUserTurn(String text, {bool isPreset = false}) {
    setState(
      () => _turns.add(
        _Turn(speaker: _Speaker.user, text: text, isPreset: isPreset),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = _selectedMood?.color ?? const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom Header matching Home Page ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Mood Tracking',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3F51B5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── TOP: Mood selector (3-column grid) ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _MoodSelectorGrid(
                moods: _moods,
                selected: _selectedMood,
                onSelect: _onMoodSelected,
                disabled: _isBotThinking,
              ),
            ),

            // ── PHASE LABEL ──────────────────────────────────────────────
            if (_selectedMood != null)
              _PhaseLabel(
                isPreset: _gemini.isPresetPhase,
                isEnded: _conversationEnded,
                accentColor: accentColor,
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(height: 1, color: Colors.black.withOpacity(0.05)),
            ),

            // ── MIDDLE: Conversational area ──────────────────────────────
            Expanded(
              child: _ConversationArea(
                turns: _turns,
                isBotThinking: _isBotThinking,
                selectedMood: _selectedMood,
                scrollController: _scrollController,
                isEnded: _conversationEnded,
                accentColor: accentColor,
              ),
            ),

            // ── BOTTOM: Mic Button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _conversationEnded
                  ? _EndedMessage(color: accentColor)
                  : VoiceMicButton(
                      isListening: _isListening,
                      onTap: _onMicTap,
                      statusLabel: _statusLabel,
                      recognizedText: _recognizedText,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MoodSelectorGrid (2-column layout) ───────────────────────────────────────
class _MoodSelectorGrid extends StatelessWidget {
  const _MoodSelectorGrid({
    required this.moods,
    required this.selected,
    required this.onSelect,
    required this.disabled,
  });

  final List<_Mood> moods;
  final _Mood? selected;
  final void Function(_Mood) onSelect;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < moods.length; i += 3) {
      final first = moods[i];
      final second = i + 1 < moods.length ? moods[i + 1] : null;
      final third = i + 2 < moods.length ? moods[i + 2] : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MoodCard3D(
                  mood: first,
                  isSelected: selected?.label == first.label,
                  disabled: disabled,
                  onTap: () => onSelect(first),
                ),
              ),
              const SizedBox(width: 12),
              second != null
                  ? Expanded(
                      child: _MoodCard3D(
                        mood: second,
                        isSelected: selected?.label == second.label,
                        disabled: disabled,
                        onTap: () => onSelect(second),
                      ),
                    )
                  : const Expanded(child: SizedBox()),
              if (second != null) const SizedBox(width: 12),
              third != null
                  ? Expanded(
                      child: _MoodCard3D(
                        mood: third,
                        isSelected: selected?.label == third.label,
                        disabled: disabled,
                        onTap: () => onSelect(third),
                      ),
                    )
                  : const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
      if (i + 3 < moods.length) rows.add(const SizedBox(height: 12));
    }

    return Column(children: rows);
  }
}

// ── MoodCard3D (Animated 3D Push Button) ──────────────────────────────────────
class _MoodCard3D extends StatefulWidget {
  const _MoodCard3D({
    required this.mood,
    required this.isSelected,
    required this.disabled,
    required this.onTap,
  });

  final _Mood mood;
  final bool isSelected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_MoodCard3D> createState() => _MoodCard3DState();
}

class _MoodCard3DState extends State<_MoodCard3D> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.mood.color;
    final hsl = HSLColor.fromColor(color);
    final shadowColor = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();

    final effectivelyPressed = _isPressed || widget.isSelected;

    return GestureDetector(
      onTapDown: widget.disabled
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.disabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(
            0,
            effectivelyPressed ? 6.0 : 0.0,
            0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: effectivelyPressed
                ? []
                : [
                    BoxShadow(
                      color: widget.isSelected
                          ? Colors.transparent
                          : shadowColor,
                      offset: const Offset(0, 6),
                      blurRadius: 0,
                    ),
                  ],
            border: widget.isSelected
                ? null
                : Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.mood.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.mood.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: widget.isSelected ? Colors.white : color,
                    letterSpacing: 0.3,
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

// ── PhaseLabel ────────────────────────────────────────────────────────────────
class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({
    required this.isPreset,
    required this.isEnded,
    required this.accentColor,
  });

  final bool isPreset;
  final bool isEnded;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (isEnded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              'Session complete',
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (!isPreset) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              'MindMate is here for you',
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 4);
  }
}

// ── ConversationArea ──────────────────────────────────────────────────────────
class _ConversationArea extends StatelessWidget {
  const _ConversationArea({
    required this.turns,
    required this.isBotThinking,
    required this.selectedMood,
    required this.scrollController,
    required this.isEnded,
    required this.accentColor,
  });

  final List<_Turn> turns;
  final bool isBotThinking;
  final _Mood? selectedMood;
  final ScrollController scrollController;
  final bool isEnded;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (selectedMood == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 56,
                color: Colors.black.withOpacity(0.15),
              ),
              const SizedBox(height: 24),
              Text(
                'Select a mood above to begin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'or tap the mic and say how you feel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      children: [
        ...turns.map((turn) => _buildTurn(turn, accentColor)),
        if (isBotThinking) _buildThinkingIndicator(accentColor),
      ],
    );
  }

  Widget _buildTurn(_Turn turn, Color accentColor) {
    if (turn.speaker == _Speaker.assistant) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 12),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: accentColor,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  turn.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  turn.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildThinkingIndicator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 36),
      child: _ThinkingDots(color: accentColor),
    );
  }
}

// ── EndedMessage ──────────────────────────────────────────────────────────────
class _EndedMessage extends StatelessWidget {
  const _EndedMessage({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            'Take care of yourself today',
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ThinkingDots ──────────────────────────────────────────────────────────────
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.color});
  final Color color;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(3, (i) {
            final phase = (i / 3);
            final t = (_ctrl.value - phase + 1.0) % 1.0;
            final scale = 0.6 + 0.8 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
