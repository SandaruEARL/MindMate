// breathing_exercises_page.dart
// UI is unchanged from the previous version.
// Voice command support is now powered by BreathingVuiNotifier (Riverpod).
//
// FLOW:
//   Mic tap → STT → _checkVoiceNavigation() [NEW: navigation commands first]
//                        ↓ (if not a nav command)
//              BreathingVuiNotifier.handleVoiceCommand()
//                        ↓
//              BreathingVuiState.exerciseIdToStart != null → _runExercise()
//              BreathingVuiState.shouldStop == true        → stop animation
//              BreathingVuiState.statusLabel               → mic status text
//              BreathingVuiState.tips / suggestions        → (optional future UI)
//
// VOICE NAVIGATION (NEW — mirrors MoodTrackingPage._checkVoiceNavigation):
//   "go back" / "home" / "exit"  → pop to root (HomePage)
//   "emergency" / "crisis"       → EmergencySupportPage
//   "sleep" / "bedtime"          → SleepVuiScreen
//   "mindful" / "meditat"        → MindfulnessPage
//   "mood" / "how i feel"        → MoodTrackingPage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mindmate/core/constants/breathing_content.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_engine.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class BreathingExercisesPage extends ConsumerStatefulWidget {
  const BreathingExercisesPage({super.key});

  @override
  ConsumerState<BreathingExercisesPage> createState() =>
      _BreathingExercisesPageState();
}

class _BreathingExercisesPageState extends ConsumerState<BreathingExercisesPage>
    with SingleTickerProviderStateMixin {
  // ── TTS ────────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();

  // ── STT ────────────────────────────────────────────────────────────────────
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _isListening = false;
  bool _sttAvailable = false;
  bool _isProcessing = false;
  String _recognizedText = '';

  // ── Breathing animation ────────────────────────────────────────────────────
  late AnimationController _circleController;
  late Animation<double> _circleAnim;

  String? _activeId;
  bool _isMounted = true;
  String _phaseLabel = 'Choose an exercise';

  bool get _isAnimating => _activeId != null;

  // ── Exercise definitions ───────────────────────────────────────────────────
  // IDs must match BreathingCorpus constants.
  final List<Map<String, dynamic>> _exercises = [
    {
      'id': BreathingCorpus.idBox,
      'title': 'Box Breathing',
      'subtitle': 'Inhale 4s · Hold 4s · Exhale 4s · Hold 4s',
      'inhale': 4,
      'hold': 4,
      'exhale': 4,
      'pause': 4,
      'color': const Color(0xFF6C63FF),
      'voice': 'Box breathing. Inhale, hold, exhale, hold.',
    },
    {
      'id': BreathingCorpus.id478,
      'title': '4-7-8 Breathing',
      'subtitle': 'Inhale 4s · Hold 7s · Exhale 8s',
      'inhale': 4,
      'hold': 7,
      'exhale': 8,
      'pause': 0,
      'color': const Color(0xFF4CAF82),
      'voice': '4 7 8 breathing. Relax and focus on your breath.',
    },
    {
      'id': BreathingCorpus.idDeep,
      'title': 'Deep Belly Breathing',
      'subtitle': 'Slow inhale and long exhale',
      'inhale': 4,
      'hold': 0,
      'exhale': 6,
      'pause': 0,
      'color': const Color(0xFF2196F3),
      'voice': 'Deep breathing. Relax your body.',
    },
    {
      'id': BreathingCorpus.idBodyScan,
      'title': 'Body Scan Relaxation',
      'subtitle': 'Mindful breathing with awareness',
      'inhale': 5,
      'hold': 2,
      'exhale': 6,
      'pause': 0,
      'color': const Color(0xFFFF9800),
      'voice': 'Body scan. Bring awareness to your body.',
    },
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _circleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeInOut),
    );

    _initTts();
    _initStt();
  }

  @override
  void dispose() {
    _isMounted = false;
    _circleController.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  // ── React to state changes from the notifier ───────────────────────────────
  //
  // Called in build() via ref.listen. When the notifier sets
  // exerciseIdToStart or shouldStop, we act here and clear the flag.

  void _handleVuiState(BreathingVuiState? previous, BreathingVuiState next) {
    // ── Start exercise via voice ─────────────────────────────────
    if (next.exerciseIdToStart != null &&
        next.exerciseIdToStart != previous?.exerciseIdToStart) {
      final id = next.exerciseIdToStart!;
      // Clear the flag immediately to prevent re-triggering
      ref.read(breathingVuiNotifierProvider.notifier).clearAction();

      final ex = _exercises.firstWhere((e) => e['id'] == id, orElse: () => {});
      if (ex.isNotEmpty && !_isAnimating) {
        // Speak the engine's status label then start the exercise
        _speak(ref.read(breathingVuiNotifierProvider).statusLabel).then((_) {
          _runExercise(ex);
        });
      }
    }

    // ── Stop exercise via voice ──────────────────────────────────
    if (next.shouldStop && !(previous?.shouldStop ?? false)) {
      ref.read(breathingVuiNotifierProvider.notifier).clearAction();
      if (_isAnimating) {
        _circleController.stop();
        _safeSetState(() {
          _activeId = null;
          _phaseLabel = 'Exercise stopped.';
        });
        _speak('Exercise stopped.');
      }
    }
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setErrorHandler((msg) => debugPrint('[TTS ERROR] $msg'));

    await Future.delayed(const Duration(milliseconds: 500));
    if (_isMounted) {
      // Use the engine's entry message for consistency
      await _speak(ref.read(breathingEngineProvider).entryMessage);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isMounted) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  // ── STT ────────────────────────────────────────────────────────────────────

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        if (mounted)
          setState(() {
            _isListening = false;
          });
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if ((s == 'done' || s == 'notListening') && _isListening && mounted) {
          _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _onMicTap() =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      await _speak('Speech recognition is not available on this device.');
      return;
    }
    await _tts.stop();

    _safeSetState(() {
      _isListening = true;
      _recognizedText = '';
    });

    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _recognizedText = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    if (_isProcessing) return;
    _isProcessing = true;

    await _stt.stop();
    _safeSetState(() => _isListening = false);

    final raw = _recognizedText;

    // ── [NEW] Voice navigation takes priority over everything else ──
    final navigated = await _checkVoiceNavigation(raw);
    if (navigated) {
      _isProcessing = false;
      return;
    }

    // ── Hand raw text to the engine via the notifier ─────────────
    // Speak the engine's response message
    final notifier = ref.read(breathingVuiNotifierProvider.notifier);
    notifier.handleVoiceCommand(raw, isAnimating: _isAnimating);

    // Speak the engine's reply aloud
    final engineResponse = ref.read(breathingVuiNotifierProvider);
    // We speak the statusLabel only for informational responses;
    // exercise start messages are spoken inside _runExercise.
    if (engineResponse.exerciseIdToStart == null &&
        !engineResponse.shouldStop) {
      // Retrieve the last engine message via the engine directly for TTS
      final engine = ref.read(breathingEngineProvider);
      final response = engine.process(raw);
      await _speak(response.message);
    }

    _isProcessing = false;
  }

  // ── [NEW] Voice navigation handler ────────────────────────────────────────
  //
  // Mirrors MoodTrackingPage._checkVoiceNavigation() exactly.
  // Returns true if a navigation command was detected and handled,
  // so _stopListening() can skip all engine processing.
  //
  // Supported commands:
  //   "go back" / "home" / "exit" / "go home" → pop to root (HomePage)
  //   "emergency" / "crisis" / "urgent"        → EmergencySupportPage
  //   "sleep" / "bedtime" / "insomnia"         → SleepVuiScreen
  //   "mindful" / "meditat" / "mindfulness"    → MindfulnessPage
  //   "mood" / "how i feel" / "mood tracking"  → MoodTrackingPage
  //
  // If an exercise is running, it is stopped cleanly before navigating.

  Future<bool> _checkVoiceNavigation(String spoken) async {
    final t = spoken.toLowerCase();

    // "go back" / "home" / "exit" → pop to root (HomePage)
    if (t.contains('home') ||
        t.contains('go back') ||
        t.contains('back to home') ||
        t.contains('main menu') ||
        t.contains('main page') ||
        t.contains('exit') ||
        t.contains('leave') ||
        t.contains('go home')) {
      await _stopExerciseForNavigation();
      await _speak('Going back to the home page.');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return true;
    }

    // Emergency / crisis
    if (t.contains('emergency') ||
        t.contains('crisis') ||
        t.contains('urgent') ||
        t.contains('help me')) {
      await _stopExerciseForNavigation();
      await _speak('Opening Emergency Support.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencySupportPage()),
        );
      }
      return true;
    }

    // Sleep hygiene
    if (t.contains('sleep') ||
        t.contains('bedtime') ||
        t.contains('insomnia') ||
        t.contains('sleep hygiene') ||
        t.contains('rest')) {
      await _stopExerciseForNavigation();
      await _speak('Opening Sleep Hygiene.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SleepVuiScreen()),
        );
      }
      return true;
    }

    // Mindfulness / meditation
    if (t.contains('mindful') ||
        t.contains('meditat') ||
        t.contains('mindfulness') ||
        t.contains('aware')) {
      await _stopExerciseForNavigation();
      await _speak('Opening Mindfulness.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MindfulnessPage()),
        );
      }
      return true;
    }

    // Mood tracking
    if (t.contains('mood') ||
        t.contains('how i feel') ||
        t.contains('mood tracking') ||
        t.contains('track my mood') ||
        t.contains('feelings')) {
      await _stopExerciseForNavigation();
      await _speak('Opening Mood Tracking.');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MoodTrackingPage()),
        );
      }
      return true;
    }

    return false; // not a navigation command — continue normal engine flow
  }

  /// Cleanly stops any running exercise before navigating away,
  /// so the animation controller and state are consistent.
  Future<void> _stopExerciseForNavigation() async {
    if (_isAnimating) {
      _circleController.stop();
      _safeSetState(() {
        _activeId = null;
        _phaseLabel = 'Exercise stopped.';
      });
    }
    await _tts.stop();
  }

  // ── Breathing runner (unchanged from previous version) ────────────────────

  Future<void> _runExercise(Map<String, dynamic> ex) async {
    if (_isAnimating) return;

    _safeSetState(() {
      _activeId = ex['id'] as String;
      _phaseLabel = 'Get ready…';
    });

    await _speak(ex['voice'] as String);
    if (!_isMounted) return;

    // INHALE
    _safeSetState(() => _phaseLabel = 'Inhale…');
    _circleController.duration = Duration(seconds: ex['inhale'] as int);
    await Future.wait([_speak('Inhale'), _circleController.forward(from: 0)]);
    if (!_isMounted || !_isAnimating) return;

    // HOLD
    if ((ex['hold'] as int) > 0) {
      _safeSetState(() => _phaseLabel = 'Hold…');
      await _speak('Hold');
      if (!_isMounted || !_isAnimating) return;
      final remaining = (ex['hold'] as int) - 2;
      if (remaining > 0) await Future.delayed(Duration(seconds: remaining));
      if (!_isMounted || !_isAnimating) return;
    }

    // EXHALE
    _safeSetState(() => _phaseLabel = 'Exhale…');
    _circleController.duration = Duration(seconds: ex['exhale'] as int);
    await Future.wait([
      _speak('Exhale slowly'),
      _circleController.reverse(from: 1),
    ]);
    if (!_isMounted || !_isAnimating) return;

    // PAUSE (box breathing only)
    if ((ex['pause'] as int) > 0) {
      _safeSetState(() => _phaseLabel = 'Pause…');
      await _speak('Pause');
      if (!_isMounted || !_isAnimating) return;
      final remaining = (ex['pause'] as int) - 2;
      if (remaining > 0) await Future.delayed(Duration(seconds: remaining));
      if (!_isMounted || !_isAnimating) return;
    }

    // DONE
    _safeSetState(() {
      _activeId = null;
      _phaseLabel = 'Great job! Tap again to continue.';
    });
    ref.read(breathingVuiNotifierProvider.notifier).onExerciseComplete();
    await _speak('Well done. You completed the session.');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) setState(fn);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // React to engine state changes (exercise start / stop signals)
    ref.listen<BreathingVuiState>(
      breathingVuiNotifierProvider,
      _handleVuiState,
    );

    // Read status label from notifier
    final vuiState = ref.watch(breathingVuiNotifierProvider);
    final statusLabel = vuiState.statusLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breathing Exercises'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Column(
        children: [
          // ── Scrollable content ───────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Breathing circle ───────────────────────────
                  Center(
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _circleAnim,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF4CAF82).withOpacity(0.6),
                                  const Color(0xFF4CAF82).withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.air_rounded,
                              size: 70,
                              color: Color(0xFF4CAF82),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            _phaseLabel,
                            key: ValueKey(_phaseLabel),
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Techniques',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Exercise cards (unchanged) ─────────────────
                  ..._exercises.map((ex) {
                    final color = ex['color'] as Color;
                    final isThisActive = _activeId == ex['id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Icon(Icons.self_improvement, color: color),
                        ),
                        title: Text(
                          ex['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(ex['subtitle'] as String),
                        trailing: isThisActive
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: color,
                                ),
                              )
                            : Icon(
                                Icons.play_arrow_rounded,
                                color: _isAnimating
                                    ? color.withOpacity(0.35)
                                    : color,
                              ),
                        onTap: _isAnimating ? null : () => _runExercise(ex),
                      ),
                    );
                  }),

                  // ── Tips card (shown after voice command) ──────
                  if (vuiState.tips != null && vuiState.tips!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...vuiState.tips!.map(
                      (tip) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF82).withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4CAF82).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tip.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tip.body,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Suggestion chips (follow-ups) ──────────────
                  if (vuiState.suggestions != null &&
                      vuiState.suggestions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vuiState.suggestions!.map((s) {
                        return ActionChip(
                          label: Text(s),
                          onPressed: _isAnimating
                              ? null
                              : () {
                                  // Treat chip tap as a voice command
                                  ref
                                      .read(
                                        breathingVuiNotifierProvider.notifier,
                                      )
                                      .handleVoiceCommand(
                                        s,
                                        isAnimating: _isAnimating,
                                      );
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),

          // ── Fixed mic button at bottom ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: VoiceMicButton(
              isListening: _isListening,
              onTap: _onMicTap,
              statusLabel: statusLabel,
              recognizedText: _recognizedText,
            ),
          ),
        ],
      ),
    );
  }
}
