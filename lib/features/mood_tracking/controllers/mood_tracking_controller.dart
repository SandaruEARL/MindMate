import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';

// ── Mood Data Models ────────────────────────────────────────────────────────

class MoodData {
  const MoodData({required this.emoji, required this.label, required this.color});
  final String emoji;
  final String label;
  final Color color;
}

const List<MoodData> availableMoods = [
  MoodData(emoji: '😄', label: 'Great', color: Color(0xFF4CAF82)),
  MoodData(emoji: '🙂', label: 'Good', color: Color(0xFF6C63FF)),
  MoodData(emoji: '😐', label: 'Okay', color: Color(0xFFFFA726)),
  MoodData(emoji: '😔', label: 'Sad', color: Color(0xFF2196F3)),
  MoodData(emoji: '😞', label: 'Struggling', color: Color(0xFFE05C5C)),
  MoodData(emoji: '😠', label: 'Angry', color: Color(0xFFD32F2F)),
];

enum SpeakerType { assistant, user }

class ConversationTurn {
  ConversationTurn({required this.speaker, required this.text, this.isPreset = false});
  final SpeakerType speaker;
  final String text;
  final bool isPreset;
}

// ── Rule-Based Data ────────────────────────────────────────────────────────

const Map<String, List<String>> _presetQuestions = {
  'Great': [
    "Something good is happening — what's lighting you up today?",
    "Is there a person or moment behind that feeling?",
  ],
  'Good': [
    "Good is worth pausing on. What's been going right?",
    "Anything on your mind that you'd like to just talk through?",
  ],
  'Okay': [
    "Okay can mean a lot of things. What's your day actually been like?",
    "Is there something quietly weighing on you, even a little?",
    "How have you been sleeping lately?",
  ],
  'Sad': [
    "I'm glad you're here. Can you tell me what's been going on?",
    "How long have you been carrying this feeling?",
    "Is there one thing that's hurting the most right now?",
  ],
  'Struggling': [
    "Thank you for being honest about that. What's been the hardest part?",
    "Has something specific happened, or has it been building for a while?",
    "Is there anyone in your life who knows you're going through this?",
  ],
  'Angry': [
    "I hear you. What specifically triggered this anger?",
    "Is this a new feeling, or has it been building up over time?",
  ],
};

const Map<String, String> _presetClosings = {
  'Great': "That sounds wonderful. Hold onto this positive energy and use it to fuel the rest of your day! Keep shining, you're doing great.",
  'Good': "It's so important to recognize these good moments. Take a deep breath and let that feeling settle in. Wishing you a peaceful rest of your day.",
  'Okay': "It's completely fine to just be 'okay'. You don't always have to be at 100%. Take it easy today. I'm always here if you need to talk.",
  'Sad': "Thank you for sharing that with me. Please be gentle with yourself today. Remember that it's okay to feel this way, and feelings do pass. Take a slow breath. You are not alone.",
  'Struggling': "I hear how heavy this is for you right now. Please consider reaching out to a friend, family member, or using the emergency support if you feel overwhelmed. You don't have to carry this alone. Please take care of yourself.",
  'Angry': "It's completely valid to feel frustrated. Taking a moment to step away or do a breathing exercise can really help your nervous system reset. Remember to breathe. You can handle this.",
};

/// MoodTrackingController manages the Voice User Interface (VUI) for Mood Tracking.
/// It strictly follows the Rule-Based Spoken Language System Architecture:
/// 1. User Input -> 2. NLU -> 3. Intent -> 4. Dialogue Manager -> 5. Response
class MoodTrackingController extends ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  // ── Exposed State ──
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  bool isBotThinking = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  MoodData? selectedMood;
  final List<ConversationTurn> turns = [];

  bool conversationEnded = false;
  bool isPresetPhase = true;
  int _presetIndex = 0;
  List<String> _currentPresetQList = [];

  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;
  VoidCallback? onScrollToBottom;

  // ── Initialization ──

  Future<void> init() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    await speak('Tap how you are feeling right now.');
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

  // ── UI Actions ──

  Future<void> selectMood(MoodData mood) async {
    if (isBotThinking) return;

    selectedMood = mood;
    turns.clear();
    isBotThinking = false;
    conversationEnded = false;
    isPresetPhase = true;
    _presetIndex = 0;
    _currentPresetQList = List<String>.from(
      _presetQuestions[mood.label] ?? [
        "Tell me what's going on for you right now.",
        "What's been weighing on your mind lately?",
      ],
    );

    statusLabel = 'Tap the mic and speak';
    notifyListeners();

    await speak('You selected ${mood.label}.');

    final firstQuestion = _currentPresetQList.first;
    _addAssistantTurn(firstQuestion, isPreset: true);
    await speak(firstQuestion);
  }

  void _addAssistantTurn(String text, {bool isPreset = false}) {
    turns.add(ConversationTurn(speaker: SpeakerType.assistant, text: text, isPreset: isPreset));
    onScrollToBottom?.call();
    notifyListeners();
  }

  void _addUserTurn(String text) {
    turns.add(ConversationTurn(speaker: SpeakerType.user, text: text, isPreset: isPresetPhase));
    onScrollToBottom?.call();
    notifyListeners();
  }

  // ── Spoken Language System Pipeline ──

  // 1. USER INPUT (Speech-to-Text)
  Future<void> onMicTap() async {
    isListening ? await stopListening() : await startListening();
  }

  Future<void> startListening() async {
    if (isBotThinking || conversationEnded) return;
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
    
    final spoken = recognizedText.trim();
    recognizedText = '';
    statusLabel = spoken.isEmpty ? 'Tap the mic and speak' : 'Processing…';
    notifyListeners();

    if (spoken.isEmpty) {
      await speak("I didn't catch that. Please try again.");
      statusLabel = 'Tap the mic and speak';
    } else {
      await _handleVoiceCommand(spoken);
    }

    isProcessing = false;
    notifyListeners();
  }

  // 2. NLU (Natural Language Understanding)
  // 3. INTENT (Categorization)
  // 4. DIALOGUE MANAGER (Routing & Rule-based conversation logic)
  Future<void> _handleVoiceCommand(String spoken) async {
    final t = spoken.toLowerCase();
    String intent = 'UNKNOWN';
    Widget? targetPage;

    final callKey = CrisisDetector.detectCallIntent(t);
    final breathingExId = BreathingDetector.detectExerciseIntent(t);

    // NLU: Navigation Keywords
    if (callKey != null || CrisisDetector.isCrisis(t)) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (breathingExId != null) {
      intent = 'NAVIGATE_BREATHING_EXERCISE';
    } else if (t.contains('home') || t.contains('go back') || t.contains('exit')) {
      intent = 'NAVIGATE_HOME';
    } else if (t.contains('emergency') || t.contains('crisis') || t.contains('suicide') || t.contains('kill myself') || t.contains('hurt myself')) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (t.contains('sleep') || t.contains('bedtime')) {
      intent = 'NAVIGATE_SLEEP';
    } else if (t.contains('mindful') || t.contains('meditat')) {
      intent = 'NAVIGATE_MINDFULNESS';
    } else if (t.contains('breath') || t.contains('relax') || t.contains('cant breathe') || t.contains('panic')) {
      intent = 'NAVIGATE_BREATHING';
    }

    // Dialogue Manager: Act on Navigation Intents
    if (intent != 'UNKNOWN') {
      await tts.stop();
      switch (intent) {
        case 'NAVIGATE_HOME':
          await speak('Going back to the home page.');
          if (_context != null && _context!.mounted) Navigator.of(_context!).popUntil((r) => r.isFirst);
          return;
        case 'NAVIGATE_EMERGENCY':
          targetPage = EmergencySupportPage(initialCallKey: callKey);
          _addAssistantTurn('I can hear that you are really struggling. Taking you to Emergency Support now.', isPreset: false);
          await speak('Taking you to Emergency Support now.');
          break;
        case 'NAVIGATE_SLEEP':
          targetPage = const SleepVuiScreen();
          await speak('Opening Sleep Hygiene.');
          break;
        case 'NAVIGATE_MINDFULNESS':
          targetPage = const MindfulnessPage();
          await speak('Opening Mindfulness.');
          break;
        case 'NAVIGATE_BREATHING_EXERCISE':
          targetPage = BreathingExercisesPage(initialExerciseId: breathingExId);
          _addAssistantTurn('Starting breathing exercise.', isPreset: false);
          await speak('Starting breathing exercise.');
          break;
        case 'NAVIGATE_BREATHING':
          targetPage = const BreathingExercisesPage();
          _addAssistantTurn('Let me take you to Breathing Exercises.', isPreset: false);
          await speak('Let me take you to Breathing Exercises.');
          break;
      }
      if (_context != null && _context!.mounted && targetPage != null) {
        Navigator.of(_context!).pushReplacement(MaterialPageRoute(builder: (_) => targetPage!));
      }
      return;
    }

    // Dialogue Manager: Mood Selection Check
    if (selectedMood == null) {
      MoodData? matched;
      for (final m in availableMoods) {
        if (t.contains(m.label.toLowerCase())) {
          matched = m;
          break;
        }
      }
      if (matched != null) {
        await selectMood(matched);
      } else {
        await speak('I heard "$spoken" but please tap or say your mood: Great, Good, Okay, Sad, Struggling, or Angry.');
        statusLabel = 'Tap the mic and speak';
        notifyListeners();
      }
      return;
    }

    // Dialogue Manager: Continue preset conversation
    _addUserTurn(spoken);
    isBotThinking = true;
    statusLabel = 'Processing…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    String reply = '';
    if (isPresetPhase) {
      _presetIndex++;
      if (_presetIndex < _currentPresetQList.length) {
        reply = _currentPresetQList[_presetIndex];
      } else {
        isPresetPhase = false;
        conversationEnded = true;
        reply = _presetClosings[selectedMood!.label] ?? "Thank you for sharing. Please take care of yourself today. I am always here for you.";
      }
    } else if (conversationEnded) {
      reply = "I'm always here. Take care of yourself.";
    }

    // 5. RESPONSE
    isBotThinking = false;
    statusLabel = conversationEnded ? 'Session complete' : 'Tap the mic and speak';
    _addAssistantTurn(reply, isPreset: isPresetPhase);
    await speak(reply);
  }

  @override
  void dispose() {
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
