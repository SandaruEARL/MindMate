import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mindmate/core/constants/breathing_content.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';

/// BreathingController manages the Voice User Interface (VUI) for Breathing Exercises.
/// It strictly follows the Rule-Based Spoken Language System Architecture:
/// 1. User Input -> 2. NLU -> 3. Intent -> 4. Dialogue Manager -> 5. Response
class BreathingController extends ChangeNotifier {
  BreathingController({required this.vsync});

  final TickerProvider vsync;

  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  late final AnimationController circleController;
  late final Animation<double> circleAnim;

  // ── Exposed State ──
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  String? activeId;
  String phaseLabel = 'Choose an exercise';

  bool get isAnimating => activeId != null;

  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  final List<Map<String, dynamic>> exercises = [
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

  // ── Initialization ──

  Future<void> init({String? initialExerciseId}) async {
    circleController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 4),
    );
    circleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: circleController, curve: Curves.easeInOut),
    );

    await _initTts(skipGreeting: initialExerciseId != null);
    await _initStt();

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
      await speak('You are in Breathing Exercises. Which exercise would you like to start?');
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

  // ── Spoken Language System Pipeline ──

  // 1. USER INPUT (Speech-to-Text)
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

    await sttEngine.listen(
      onResult: (r) {
        recognizedText = r.recognizedWords;
        notifyListeners();
        if (r.finalResult && !isProcessing) {
          stopListening();
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
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

  // 2. NLU (Natural Language Understanding)
  // 3. INTENT (Categorization)
  // 4. DIALOGUE MANAGER (Routing logic)
  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "Didn't catch that. Try again.";
      notifyListeners();
      await speak("I didn't catch that. Please try again.");
      return;
    }

    String intent = 'UNKNOWN';
    Widget? navigationTarget;
    Map<String, dynamic>? exerciseToStart;

    final callKey = CrisisDetector.detectCallIntent(text);
    final mindfulnessId = MindfulnessDetector.detectSessionIntent(text);

    // NLU: Navigation Keywords
    if (callKey != null || CrisisDetector.isCrisis(text)) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (mindfulnessId != null) {
      intent = 'NAVIGATE_MINDFULNESS_SESSION';
    } else if (text.contains('home') || text.contains('go back') || text.contains('exit')) {
      intent = 'NAVIGATE_HOME';
    } else if (text.contains('emergency') || text.contains('crisis') || text.contains('urgent') || text.contains('support') || text.contains('call')) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (text.contains('sleep') || text.contains('rest') || text.contains('bedtime') || text.contains('hygiene') || text.contains('insomnia')) {
      intent = 'NAVIGATE_SLEEP';
    } else if (text.contains('mindful') || text.contains('meditat') || text.contains('aware') || text.contains('present')) {
      intent = 'NAVIGATE_MINDFULNESS';
    } else if (text.contains('mood') || text.contains('feeling') || text.contains('emotion') || text.contains('track')) {
      intent = 'NAVIGATE_MOOD';
    } 
    // NLU: Exercise Commands
    else if (text.contains('stop') || text.contains('cancel') || text.contains('pause')) {
      intent = 'STOP_EXERCISE';
    } else {
      final detectedExId = BreathingDetector.detectExerciseIntent(text);
      if (detectedExId != null) {
        intent = 'START_EXERCISE';
        exerciseToStart = exercises.firstWhere((e) => e['id'] == detectedExId);
      } else if (text.contains('help') || text.contains('what can i say')) {
        intent = 'HELP';
      }
    }

    // Dialogue Manager: Act on Intent
    switch (intent) {
      case 'NAVIGATE_HOME':
        await _stopExerciseForNavigation();
        speak('Going back to the home page.');
        if (_context != null && _context!.mounted) Navigator.of(_context!).popUntil((r) => r.isFirst);
        return;
      case 'NAVIGATE_EMERGENCY':
        await _stopExerciseForNavigation();
        navigationTarget = EmergencySupportPage(initialCallKey: callKey);
        speak('Opening Emergency Support.');
        break;
      case 'NAVIGATE_SLEEP':
        await _stopExerciseForNavigation();
        navigationTarget = const SleepVuiScreen();
        speak('Opening Sleep Hygiene.');
        break;
      case 'NAVIGATE_MINDFULNESS_SESSION':
        await _stopExerciseForNavigation();
        navigationTarget = MindfulnessPage(initialSessionId: mindfulnessId);
        speak('Starting mindfulness session.');
        break;
      case 'NAVIGATE_MINDFULNESS':
        await _stopExerciseForNavigation();
        navigationTarget = const MindfulnessPage();
        speak('Opening Mindfulness.');
        break;
      case 'NAVIGATE_MOOD':
        await _stopExerciseForNavigation();
        navigationTarget = const MoodTrackingPage();
        speak('Opening Mood Tracking.');
        break;
      case 'STOP_EXERCISE':
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
      case 'START_EXERCISE':
        if (exerciseToStart != null && !isAnimating) {
          statusLabel = 'Starting ${exerciseToStart['title']}';
          notifyListeners();
          runExercise(exerciseToStart);
        }
        return;
      case 'HELP':
        statusLabel = 'Try: Start Box Breathing';
        notifyListeners();
        await speak('You can say start box breathing, start 4 7 8 breathing, stop exercise, or navigate to other modules.');
        return;
      case 'UNKNOWN':
      default:
        statusLabel = 'Not sure. Try an exercise name.';
        notifyListeners();
        await speak('I heard "$text". Try saying start box breathing or stop exercise.');
        return;
    }

    // 5. RESPONSE (Navigation execution)
    if (_context != null && _context!.mounted && navigationTarget != null) {
      Navigator.of(_context!).pushReplacement(MaterialPageRoute(builder: (_) => navigationTarget!));
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

  // ── Exercise Runner ──

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
