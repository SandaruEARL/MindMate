import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';

/// HomeController manages the Voice User Interface (VUI) for the Home Page.
/// It strictly follows the Rule-Based Spoken Language System Architecture:
/// 1. User Input -> 2. NLU -> 3. Intent -> 4. Dialogue Manager -> 5. Response
class HomeController extends ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  // ── Exposed State ──
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  // ── Initialization ──

  Future<void> init() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.48);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await Future.delayed(const Duration(milliseconds: 600));
    await speak(
      'Welcome to MindMate. Tap the microphone and tell me where you want to go.',
    );
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

  // ── Spoken Language System Pipeline ──

  // 1. USER INPUT (Speech-to-Text)
  Future<void> onMicTap() async {
    isListening ? await stopListening() : await startListening();
  }

  Future<void> startListening() async {
    if (!sttAvailable) {
      await speak('Speech recognition is not available on this device.');
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
      listenFor: const Duration(seconds: 30),
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

    if (recognizedText.isNotEmpty) {
      final textToProcess = recognizedText.toLowerCase();
      recognizedText = '';
      await _handleVoiceCommand(textToProcess);
    }

    isProcessing = false;
    notifyListeners();
  }

  // 2. NLU (Natural Language Understanding via Pattern Matching)
  // 3. INTENT (Categorization)
  // 4. DIALOGUE MANAGER (Routing logic)
  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "I didn't catch that. Try again.";
      notifyListeners();
      await speak("I didn't catch that. Please try again.");
      return;
    }

    String intent = 'UNKNOWN';
    Widget? targetPage;
    String speechResponse = '';

    final callKey = CrisisDetector.detectCallIntent(text);
    final breathingExId = BreathingDetector.detectExerciseIntent(text);
    final mindfulnessId = MindfulnessDetector.detectSessionIntent(text);

    // NLU: Scanning for keywords
    if (callKey != null || CrisisDetector.isCrisis(text)) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (breathingExId != null) {
      intent = 'NAVIGATE_BREATHING_EXERCISE';
    } else if (mindfulnessId != null) {
      intent = 'NAVIGATE_MINDFULNESS_SESSION';
    } else if (text.contains('breath') ||
        text.contains('relax') ||
        text.contains('calm') ||
        text.contains('exercise')) {
      intent = 'NAVIGATE_BREATHING';
    } else if (text.contains('sleep') ||
        text.contains('rest') ||
        text.contains('bedtime') ||
        text.contains('hygiene') ||
        text.contains('insomnia')) {
      intent = 'NAVIGATE_SLEEP';
    } else if (text.contains('mindful') ||
        text.contains('meditat') ||
        text.contains('aware') ||
        text.contains('present')) {
      intent = 'NAVIGATE_MINDFULNESS';
    } else if (text.contains('mood') ||
        text.contains('tracking') ||
        text.contains('track')) {
      intent = 'NAVIGATE_MOOD';
    } else if (text.contains('emergency') ||
        text.contains('crisis') ||
        text.contains('urgent') ||
        text.contains('support') ||
        text.contains('call')) {
      intent = 'NAVIGATE_EMERGENCY';
    }

    // Dialogue Manager: Act on Intent
    switch (intent) {
      case 'NAVIGATE_BREATHING_EXERCISE':
        targetPage = BreathingExercisesPage(initialExerciseId: breathingExId);
        speechResponse = 'Starting breathing exercise.';
        statusLabel = 'Going to Breathing Exercises…';
        break;
      case 'NAVIGATE_BREATHING':
        targetPage = const BreathingExercisesPage();
        speechResponse = 'Opening Breathing Exercises.';
        statusLabel = 'Going to Breathing Exercises…';
        break;
      case 'NAVIGATE_SLEEP':
        targetPage = const SleepVuiScreen();
        speechResponse = 'Opening Sleep Hygiene.';
        statusLabel = 'Going to Sleep Hygiene…';
        break;
      case 'NAVIGATE_MINDFULNESS_SESSION':
        targetPage = MindfulnessPage(initialSessionId: mindfulnessId);
        speechResponse = 'Starting mindfulness session.';
        statusLabel = 'Going to Mindfulness…';
        break;
      case 'NAVIGATE_MINDFULNESS':
        targetPage = const MindfulnessPage();
        speechResponse = 'Opening Mindfulness.';
        statusLabel = 'Going to Mindfulness…';
        break;
      case 'NAVIGATE_MOOD':
        targetPage = const MoodTrackingPage();
        speechResponse = 'Opening Mood Tracking.';
        statusLabel = 'Going to Mood Tracking…';
        break;
      case 'NAVIGATE_EMERGENCY':
        targetPage = EmergencySupportPage(initialCallKey: callKey);
        speechResponse = 'Opening Emergency Support.';
        statusLabel = 'Going to Emergency Support…';
        break;
      case 'UNKNOWN':
      default:
        statusLabel = 'Not sure where to go. Try a module name.';
        notifyListeners();
        await speak(
          'I heard "$text" but I\'m not sure where to navigate. '
          'Try saying Breathing Exercises, Sleep Hygiene, Mindfulness, '
          'Mood Tracking, or Emergency Support.',
        );
        return;
    }

    // 5. RESPONSE (System execution)
    notifyListeners();
    if (speechResponse.isNotEmpty) {
      await speak(speechResponse);
    }

    if (_context != null && _context!.mounted && targetPage != null) {
      await Navigator.push(
        _context!,
        MaterialPageRoute(builder: (_) => targetPage!),
      );
      await speak('You are back on the home page.');
      statusLabel = 'Tap the mic and speak';
      notifyListeners();
    }
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  // ── Manual Navigation Helper ──
  Future<void> pushRoute(String label, String speech, Widget page) async {
    statusLabel = label;
    notifyListeners();
    if (speech.isNotEmpty) {
      await speak(speech);
    }
    if (_context != null && _context!.mounted) {
      await Navigator.push(_context!, MaterialPageRoute(builder: (_) => page));
      await speak('You are back on the home page.');
      statusLabel = 'Tap the mic and speak';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
