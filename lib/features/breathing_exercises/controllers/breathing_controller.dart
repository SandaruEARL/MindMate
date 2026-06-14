// controllers/breathing_controller.dart
// Integrates BreathingFaqDetector into the VUI pipeline alongside the
// existing exercise-selection and navigation logic.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';

// ── NEW IMPORTS ───────────────────────────────────────────────────────────────
import 'package:mindmate/features/breathing_exercises/services/breathing_faq_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_faq_corpus.dart';
// ─────────────────────────────────────────────────────────────────────────────

/// BreathingController manages the Voice User Interface (VUI) for Breathing Exercises.
class BreathingController extends ChangeNotifier {
  BreathingController({required this.vsync});

  final TickerProvider vsync;

  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  late final AnimationController circleController;
  late final Animation<double> circleAnim;

  // ── Exposed State ──────────────────────────────────────────────────────────
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  String? activeId;
  String phaseLabel = 'Choose an exercise';

  bool get isAnimating => activeId != null;

  // ── pending exercise from FAQ suggestion ────────────────────────────────────
  String? _pendingExerciseId;

  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  final List<Map<String, dynamic>> exercises = [
    {
      'id': BreathingFaqCorpus.idBox,
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
      'id': BreathingFaqCorpus.id478,
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
      'id': BreathingFaqCorpus.idDeep,
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
      'id': BreathingFaqCorpus.idBodyScan,
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

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init({String? initialExerciseId}) async {
    circleController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 4),
    );
    // FIXED: Corrected spelling from 'CurangedAnimation' to 'CurvedAnimation'
    circleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: circleController, curve: Curves.easeInOut),
    );

    await _initStt();
    await _initTts(skipGreeting: initialExerciseId != null);

    if (initialExerciseId != null) {
      final ex = exercises.firstWhere(
        (e) => e['id'] == initialExerciseId,
        orElse: () => <String, dynamic>{},
      );
      if (ex.isNotEmpty) {
        runExercise(ex);
      }
    }
  }

  Future<void> _initTts({bool skipGreeting = false}) async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);

    if (!skipGreeting) {
      await Future.delayed(const Duration(milliseconds: 500));
      await speak(
        'You are in Breathing Exercises. '
        'Which exercise would you like to start? '
        'You can also ask me a question or tell me how you are feeling.',
      );
    }
  }

  Future<void> _initStt() async {
    sttAvailable = await sttEngine.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        isListening = false;
        statusLabel = 'Error. Try again.';
        notifyListeners();
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if ((s == 'done' || s == 'notListening') && isListening) {
          stopListening();
        }
      },
    );
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  // ── Spoken Language System Pipeline ───────────────────────────────────────

  Future<void> onMicTap() async {
    isListening ? await stopListening() : await startListening();
  }

  Future<void> startListening() async {
    if (!sttAvailable) {
      await speak('Speech recognition not available.');
      return;
    }
    await tts.stop();
    isListening = true;
    recognizedText = '';
    statusLabel = 'Listening…';
    notifyListeners();

    // FIXED: Wrapped deprecated arguments inside modern SpeechListenOptions object
    await sttEngine.listen(
      onResult: (r) {
        recognizedText = r.recognizedWords;
        notifyListeners();
        if (r.finalResult && !isProcessing) {
          stopListening();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_US',
      ),
    );
  }

  Future<void> stopListening() async {
    if (isProcessing) return;
    isProcessing = true;
    await sttEngine.stop();
    isListening = false;
    statusLabel = 'Processing…';
    notifyListeners();

    final textToProcess = recognizedText.toLowerCase().trim();
    recognizedText = '';
    await _handleVoiceCommand(textToProcess);

    isProcessing = false;
    notifyListeners();
  }

  // ── NLU & DIALOGUE MANAGER ────────────────────────────────────────────────
  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "Didn't catch that. Try again.";
      notifyListeners();
      await speak("I didn't catch that. Please try again.");
      return;
    }

    // Layer 1: Crisis / Emergency
    final callKey = CrisisDetector.detectCallIntent(text);
    final isCrisis = CrisisDetector.isCrisis(text);
    final mindfulnessId = MindfulnessDetector.detectSessionIntent(text);

    if (callKey != null || isCrisis) {
      await _stopExerciseForNavigation();
      await speak('Opening Emergency Support.');
      _navigateTo(EmergencySupportPage(initialCallKey: callKey));
      return;
    }

    // Layer 2: Affirmation
    if (_pendingExerciseId != null && _isAffirmation(text)) {
      final pendingId = _pendingExerciseId!;
      _pendingExerciseId = null;
      final ex = exercises.firstWhere(
        (e) => e['id'] == pendingId,
        orElse: () => <String, dynamic>{},
      );
      if (ex.isNotEmpty && !isAnimating) {
        statusLabel = 'Starting ${ex['title']}';
        notifyListeners();
        runExercise(ex);
      }
      return;
    }

    _pendingExerciseId = null;

    // Layer 3: Navigation keywords
    if (text.contains('home') ||
        text.contains('go back') ||
        text.contains('exit')) {
      await _stopExerciseForNavigation();
      speak('Going back to the home page.');
      if (_context != null && _context!.mounted) {
        Navigator.of(_context!).pop();
      }
      return;
    }
    if (text.contains('emergency') ||
        text.contains('crisis') ||
        text.contains('urgent') ||
        text.contains('support') ||
        text.contains('call')) {
      await _stopExerciseForNavigation();
      await speak('Opening Emergency Support.');
      _navigateTo(EmergencySupportPage(initialCallKey: null));
      return;
    }
    if (text.contains('sleep') ||
        text.contains('rest') ||
        text.contains('bedtime') ||
        text.contains('hygiene') ||
        text.contains('insomnia')) {
      await _stopExerciseForNavigation();
      await speak('Opening Sleep Hygiene.');
      _navigateTo(const SleepVuiScreen());
      return;
    }
    if (mindfulnessId != null) {
      await _stopExerciseForNavigation();
      await speak('Starting mindfulness session.');
      _navigateTo(MindfulnessPage(initialSessionId: mindfulnessId));
      return;
    }
    if (text.contains('mindful') ||
        text.contains('meditat') ||
        text.contains('aware') ||
        text.contains('present')) {
      await _stopExerciseForNavigation();
      await speak('Opening Mindfulness.');
      _navigateTo(const MindfulnessPage());
      return;
    }
    if (text.contains('mood') ||
        text.contains('feeling') ||
        text.contains('emotion') ||
        text.contains('track')) {
      await _stopExerciseForNavigation();
      await speak('Opening Mood Tracking.');
      _navigateTo(const MoodTrackingPage());
      return;
    }

    // Layer 4: Exercise control
    if (text.contains('stop') ||
        text.contains('cancel') ||
        text.contains('pause')) {
      if (isAnimating) {
        circleController.stop();
        activeId = null;
        phaseLabel = 'Exercise stopped.';
        statusLabel = 'Tap the mic to speak';
        notifyListeners();
        await speak('Exercise stopped.');
      } else {
        await speak('There is no exercise running right now.');
      }
      return;
    }

    final detectedExId = BreathingDetector.detectExerciseIntent(text);
    if (detectedExId != null) {
      if (!isAnimating) {
        final ex = exercises.firstWhere((e) => e['id'] == detectedExId);
        statusLabel = 'Starting ${ex['title']}';
        notifyListeners();
        runExercise(ex);
      }
      return;
    }

    if (text.contains('help') || text.contains('what can i say')) {
      statusLabel = 'Try: "Start Box Breathing" or ask a question';
      notifyListeners();
      await speak(
        'You can say start box breathing, start 4 7 8 breathing, stop exercise, '
        'or ask questions like "what are breathing exercises" or '
        '"how do breathing exercises help mental health". '
        'You can also tell me how you are feeling.',
      );
      return;
    }

    // Layer 5: FAQ + emotional pain-point detection
    final faqResponse = BreathingFaqDetector.process(text);

    if (faqResponse.requiresEmergency) {
      await _stopExerciseForNavigation();
      statusLabel = 'Redirecting to Emergency Support…';
      notifyListeners();
      await speak(faqResponse.message);
      _navigateTo(const EmergencySupportPage());
      return;
    }

    if (faqResponse.intent != BreathingFaqIntent.unknown) {
      _pendingExerciseId = faqResponse.suggestedExerciseId;
      statusLabel = _faqStatusLabel(faqResponse.intent);
      notifyListeners();
      await speak(faqResponse.message);
      return;
    }

    // Layer 6: Complete fallback
    statusLabel = 'Not sure. Try an exercise name or ask a question.';
    notifyListeners();
    await speak(
      'Sorry, I have no idea about that. '
      'Try saying start box breathing, or ask me '
      '"what are breathing exercises".',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isAffirmation(String text) {
    final Set<String> targetTokens = {
      'yes',
      'yeah',
      'yep',
      'yup',
      'sure',
      'okay',
      'ok',
      'alright',
      'go ahead',
      'please do',
      'sounds good',
      'do it',
      'start it',
      "let's go",
      'lets go',
      'begin',
      'start',
      'absolutely',
      'definitely',
      'of course',
      'please',
      'go on',
    };

    final List<String> inputTokens = text.split(' ');

    for (final token in inputTokens) {
      if (targetTokens.contains(token)) return true;
    }

    return targetTokens.any((phrase) => text.contains(phrase));
  }

  String _faqStatusLabel(BreathingFaqIntent intent) {
    switch (intent) {
      case BreathingFaqIntent.suggestForStress:
      case BreathingFaqIntent.suggestForAnxiety:
      case BreathingFaqIntent.suggestForSleep:
      case BreathingFaqIntent.suggestForAnger:
      case BreathingFaqIntent.suggestForPanic:
      case BreathingFaqIntent.anxietyPanic:
        return 'Say "yes" to start the suggested exercise';
      case BreathingFaqIntent.emergencyRedirect:
        return 'Redirecting to Emergency Support…';
      default:
        return 'Tap the mic to speak';
    }
  }

  void _navigateTo(Widget page) {
    if (_context != null && _context!.mounted) {
      Navigator.of(_context!).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  Future<void> _stopExerciseForNavigation() async {
    if (isAnimating) {
      circleController.stop();
      activeId = null;
      phaseLabel = 'Exercise stopped.';
      notifyListeners();
    }
    await tts.stop();
  }

  // ── Exercise Runner ────────────────────────────────────────────────────────

  Future<void> runExercise(Map<String, dynamic> ex) async {
    if (isAnimating) return;

    activeId = ex['id'] as String;
    phaseLabel = 'Get ready…';
    notifyListeners();

    await speak(ex['voice'] as String);

    // INHALE
    phaseLabel = 'Inhale…';
    notifyListeners();
    circleController.duration = Duration(seconds: ex['inhale'] as int);
    await Future.wait([speak('Inhale'), circleController.forward(from: 0)]);
    if (!isAnimating) return;

    // HOLD
    if ((ex['hold'] as int) > 0) {
      phaseLabel = 'Hold…';
      notifyListeners();
      await speak('Hold');
      if (!isAnimating) return;
      final remaining = (ex['hold'] as int) - 2;
      if (remaining > 0) await Future.delayed(Duration(seconds: remaining));
      if (!isAnimating) return;
    }

    // EXHALE
    phaseLabel = 'Exhale…';
    notifyListeners();
    circleController.duration = Duration(seconds: ex['exhale'] as int);
    await Future.wait([
      speak('Exhale slowly'),
      circleController.reverse(from: 1),
    ]);
    if (!isAnimating) return;

    // PAUSE
    if ((ex['pause'] as int) > 0) {
      phaseLabel = 'Pause…';
      notifyListeners();
      await speak('Pause');
      if (!isAnimating) return;
      final remaining = (ex['pause'] as int) - 2;
      if (remaining > 0) await Future.delayed(Duration(seconds: remaining));
      if (!isAnimating) return;
    }

    // DONE
    activeId = null;
    phaseLabel = 'Great job! Tap an exercise to continue.';
    notifyListeners();
    await speak('Well done. You completed the session.');
  }

  @override
  void dispose() {
    circleController.dispose();
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
