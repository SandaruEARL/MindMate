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
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';
import 'package:mindmate/features/mood_tracking/data/mood_qa_data.dart';

// ── Mood Data Models ────────────────────────────────────────────────────────

class MoodData {
  const MoodData({
    required this.emoji,
    required this.label,
    required this.color,
  });
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
  ConversationTurn({required this.speaker, required this.text});
  final SpeakerType speaker;
  final String text;
}

/// MoodTrackingController manages the VUI for Mood Tracking.
/// Flow: User selects mood → user asks questions (voice) → app answers → repeat indefinitely.
/// All Q&A is rule-based via keyword matching in mood_qa_data.dart — no external API.
class MoodTrackingController extends ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  // ── Exposed State ──
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  bool _hasFinalResult = false;
  bool isBotThinking = false;
  // Incremented on every startListening; stopListening ignores calls from old sessions.
  int _sessionId = 0;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  MoodData? selectedMood;
  final List<ConversationTurn> turns = [];

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
        // Intentionally empty — stopListening is driven only by onResult (finalResult=true)
        // or the user tapping the mic. The old pattern of calling stopListening() here
        // caused the double-processing bug (status 'done' fires after onResult already
        // consumed the session, resulting in a second _handleVoiceCommand call).
      },
    );
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  // ── Mood Selection ──

  Future<void> selectMood(MoodData mood) async {
    if (isBotThinking) return;

    selectedMood = mood;
    turns.clear();
    isBotThinking = false;
    statusLabel = 'Tap the mic and speak';
    notifyListeners();

    await speak('You selected ${mood.label}.');
  }

  void _addAssistantTurn(String text) {
    turns.add(ConversationTurn(speaker: SpeakerType.assistant, text: text));
    onScrollToBottom?.call();
    notifyListeners();
  }

  void _addUserTurn(String text) {
    turns.add(ConversationTurn(speaker: SpeakerType.user, text: text));
    onScrollToBottom?.call();
    notifyListeners();
  }

  // ── Mic Controls ──

  Future<void> onMicTap() async {
    isListening ? await stopListening() : await startListening();
  }

  Future<void> startListening() async {
    if (isBotThinking) return;
    if (!sttAvailable) {
      await speak('Speech recognition not available.');
      return;
    }
    await tts.stop();

    // Claim a new session. Any pending stopListening from the previous session
    // will see a mismatched id and bail out immediately.
    final mySession = ++_sessionId;

    isListening = true;
    _hasFinalResult = false;
    recognizedText = '';
    statusLabel = 'Listening…';
    notifyListeners();

    await sttEngine.listen(
      onResult: (r) {
        if (_sessionId != mySession) return; // stale callback — ignore
        recognizedText = r.recognizedWords;
        notifyListeners();
        if (r.finalResult && !_hasFinalResult && !isProcessing) {
          _hasFinalResult = true;
          stopListening(sessionId: mySession);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  // [sessionId] is passed by onResult so we can detect stale re-entrancy.
  // When called by the user tapping the mic (onMicTap), sessionId is omitted
  // and we proceed regardless (user intent always wins).
  Future<void> stopListening({int? sessionId}) async {
    // Reject stale automatic triggers (e.g. STT status 'done' arriving after
    // onResult already consumed this session).
    if (sessionId != null && sessionId != _sessionId) return;
    if (isProcessing) return;
    isProcessing = true;

    // Invalidate the session immediately so any subsequent STT callbacks
    // (status 'done', extra onResult) that arrive while we are processing
    // are silently dropped.
    _sessionId++;

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

  // ── Voice Command Pipeline: NLU → Intent → Dialogue Manager → Response ──

  Future<void> _handleVoiceCommand(String spoken) async {
    final t = spoken.toLowerCase();
    String intent = 'UNKNOWN';
    Widget? targetPage;

    final callKey = CrisisDetector.detectCallIntent(t);
    final breathingExId = BreathingDetector.detectExerciseIntent(t);
    final mindfulnessId = MindfulnessDetector.detectSessionIntent(t);

    // NLU: Navigation intents
    if (callKey != null || CrisisDetector.isCrisis(t)) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (breathingExId != null) {
      intent = 'NAVIGATE_BREATHING_EXERCISE';
    } else if (mindfulnessId != null) {
      intent = 'NAVIGATE_MINDFULNESS_SESSION';
    } else if (t.contains('home') ||
        t.contains('go back') ||
        t.contains('exit')) {
      intent = 'NAVIGATE_HOME';
    } else if (t.contains('emergency') ||
        t.contains('crisis') ||
        t.contains('suicide') ||
        t.contains('kill myself') ||
        t.contains('hurt myself') ||
        t.contains('urgent') ||
        t.contains('support') ||
        t.contains('call')) {
      intent = 'NAVIGATE_EMERGENCY';
    } else if (t.contains('sleep') ||
        t.contains('rest') ||
        t.contains('bedtime') ||
        t.contains('hygiene') ||
        t.contains('insomnia')) {
      intent = 'NAVIGATE_SLEEP';
    } else if (t.contains('mindful') ||
        t.contains('meditat') ||
        t.contains('aware') ||
        t.contains('present')) {
      intent = 'NAVIGATE_MINDFULNESS';
    } else if (t.contains('breath') ||
        t.contains('relax') ||
        t.contains('cant breathe') ||
        t.contains('panic') ||
        t.contains('calm') ||
        t.contains('exercise')) {
      intent = 'NAVIGATE_BREATHING';
    }

    // Dialogue Manager: handle navigation
    if (intent != 'UNKNOWN') {
      await tts.stop();
      switch (intent) {
        case 'NAVIGATE_HOME':
          speak('Going back to the home page.');
          if (_context != null && _context!.mounted) {
            Navigator.of(_context!).popUntil((r) => r.isFirst);
          }
          return;
        case 'NAVIGATE_EMERGENCY':
          targetPage = EmergencySupportPage(initialCallKey: callKey);
          _addAssistantTurn(
            'I can hear that you are really struggling. Taking you to Emergency Support now.',
          );
          speak('Taking you to Emergency Support now.');
          break;
        case 'NAVIGATE_SLEEP':
          targetPage = const SleepVuiScreen();
          speak('Opening Sleep Hygiene.');
          break;
        case 'NAVIGATE_MINDFULNESS_SESSION':
          targetPage = MindfulnessPage(initialSessionId: mindfulnessId);
          _addAssistantTurn('Starting mindfulness session.');
          speak('Starting mindfulness session.');
          break;
        case 'NAVIGATE_MINDFULNESS':
          targetPage = const MindfulnessPage();
          speak('Opening Mindfulness.');
          break;
        case 'NAVIGATE_BREATHING_EXERCISE':
          targetPage = BreathingExercisesPage(initialExerciseId: breathingExId);
          _addAssistantTurn('Starting breathing exercise.');
          speak('Starting breathing exercise.');
          break;
        case 'NAVIGATE_BREATHING':
          targetPage = const BreathingExercisesPage();
          speak('Opening Breathing Exercises.');
          break;
      }
      if (_context != null && _context!.mounted && targetPage != null) {
        Navigator.of(
          _context!,
        ).pushReplacement(MaterialPageRoute(builder: (_) => targetPage!));
      }
      return;
    }

    // Dialogue Manager: mood selection by voice (if not yet selected)
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
        // Return here — do NOT fall through to the Q&A block.
        return;
      } else {
        await speak(
          'I heard "$spoken" but please tap or say your mood: Great, Good, Okay, Sad, Struggling, or Angry.',
        );
        statusLabel = 'Tap the mic and speak';
        notifyListeners();
      }
      return;
    }

    // ── Main Q&A Flow ──────────────────────────────────────────────────────
    // User asks a question → keyword match in mood_qa_data → speak answer → loop

    _addUserTurn(spoken);
    isBotThinking = true;
    statusLabel = 'Processing…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    final matchedQA = findMatchingQA(selectedMood!.label, spoken);

    String reply;
    if (matchedQA != null) {
      reply = matchedQA.answer;
    } else {
      reply =
          'I did not understand that. Please try asking one of the questions shown above.';
    }

    isBotThinking = false;
    statusLabel = 'Tap the mic and speak';
    _addAssistantTurn(reply);
    await speak(reply);
  }

  @override
  void dispose() {
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
