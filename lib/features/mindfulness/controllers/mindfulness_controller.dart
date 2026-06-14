import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';
import 'package:mindmate/core/services/speech_to_text_service.dart';
import 'package:mindmate/core/services/tts_service.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';
import '../services/mindfulness_session_data.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';

/// MindfulnessController holds all business logic, state, and VUI handling
/// for the Mindfulness page. It is a [ChangeNotifier] so the UI can rebuild
/// reactively on state changes.
class MindfulnessController extends ChangeNotifier {
  MindfulnessController({required this.vsync});

  /// Must be provided by the owning [State] for AnimationController creation.
  final TickerProvider vsync;

  // ── External services ────────────────────────────────────────────────────
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();
  final AudioPlayer audioPlayer = AudioPlayer();

  late final AnimationController progressController;
  final List<Timer> _guidanceTimers = [];
  final List<Timer> _resumeTimers = [];

  // ── Pause / Resume state ──────────────────────────────────────────────────
  bool isPaused = false;
  Duration _pausedElapsed = Duration.zero;
  Duration _sessionDuration = const Duration(minutes: 5);
  List<Map<String, dynamic>> _sessionCues = [];
  bool _sessionPlayMusic = false;
  String _sessionTitle = '';

  // ── Exposed state ────────────────────────────────────────────────────────
  bool isPlaying = false;
  String sessionLabel = 'Tap a session to begin';

  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic and speak';

  /// VUI dialogue state machine.
  /// Values: 'idle', 'awaiting_meditation_choice',
  ///         'awaiting_reflection_response', 'awaiting_session_confirmation'
  String currentState = 'idle';

  /// Which emotion was detected in the last user utterance.
  String detectedEmotion = 'none';

  /// Which session was recommended and is awaiting user confirmation.
  String recommendedSession = '';

  /// Which content tab is displayed: 'chat', 'mindfulness', or 'guided'.
  String activeTab = 'chat';

  final List<MindfulnessMessage> chatHistory = [
    MindfulnessMessage(
      'Tap the microphone to talk to me, or choose a session below.',
      isUser: false,
    ),
  ];

  // ── BuildContext for navigation (set by the page) ─────────────────────────
  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  /// Sets the active content tab and triggers a rebuild.
  void setActiveTab(String tab) {
    activeTab = tab;
    notifyListeners();
  }


  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init({String? initialSessionId}) async {
    progressController = AnimationController(
      vsync: vsync,
      duration: const Duration(minutes: 5),
    );
    progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSessionComplete();
      }
    });

    await _initStt();
    await _initTts(skipGreeting: initialSessionId != null);

    if (initialSessionId != null) {
      final sessionName = _getSessionName(initialSessionId);
      currentState = 'awaiting_session_confirmation';
      recommendedSession = initialSessionId;
      activeTab = 'chat'; // Automatically switch to chat tab so the user sees the message!
      notifyListeners();
      await speakConversationalResponse(
        'I see you might need some help right now. You can do the $sessionName program, could I start this for you or not?',
      );
    }
  }

  String _getSessionName(String id) {
    if (id == 'body_scan') return 'Body Scan';
    final all = [...kMindfulnessSessions, ...kGuidedMeditationSessions];
    final match = all.where((s) => s['id'] == id).firstOrNull;
    if (match != null) return match['title'] as String;
    return 'Meditation';
  }

  Future<void> _initTts({bool skipGreeting = false}) async {
    await tts.setLanguage('en-US');
    await _restoreNormalTtsSettings();
    tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      if (_context != null && isPlaying) stopSession();
    });
    await tts.awaitSpeakCompletion(true);
    tts.setCompletionHandler(() {});
    if (!skipGreeting) {
      await Future.delayed(const Duration(milliseconds: 300));

      final allTitles = [
        ...kMindfulnessSessions.map((s) => s['title'] as String),
        ...kGuidedMeditationSessions.map((s) => s['title'] as String),
      ].join(', ');
      await tts.speak(
        'You are in the Mindfulness and Meditation page. Choose a session. Available sessions are: $allTitles',
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

  // ── TTS helpers ───────────────────────────────────────────────────────────

  Future<void> _restoreNormalTtsSettings() async {
    await tts.setSpeechRate(0.45); // Set to a normal, natural conversational speed
    await tts.setPitch(0.9); // Slightly naturalized pitch
    await tts.setVolume(1.0);
  }

  // ── STT / Mic ─────────────────────────────────────────────────────────────

  Future<void> onMicTap() async {
    // If mic is already open, always stop it first (regardless of session state)
    if (isListening) {
      await stopListening();
      return;
    }
    if (isPlaying) {
      // Pause the session then start listening for a voice command
      await pauseSession();
      await Future.delayed(const Duration(milliseconds: 400));
      await startListening();
      return;
    }
    if (isPaused) {
      // Session is paused – tap mic to speak a command
      await startListening();
      return;
    }
    // Normal idle state
    await startListening();
  }

  Future<void> startListening() async {
    if (!sttAvailable) {
      await tts.speak('Speech recognition is not available on this device.');
      return;
    }
    
    // Forcefully reset processing state if the user manually interrupts
    isProcessing = false;
    await tts.stop();
    
    isListening = true;
    recognizedText = '';
    statusLabel = 'Listening…';
    notifyListeners();

    await sttEngine.cancel(); // Clear any broken or hanging STT states
    await sttEngine.listen(
      onResult: (r) {
        recognizedText = r.recognizedWords;
        notifyListeners();
        // Auto-stop when the engine confirms the utterance is complete.
        // isProcessing guard prevents a double-trigger from onStatus.
        if (r.finalResult && !isProcessing) {
          stopListening();
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    if (isProcessing) return;
    isProcessing = true;
    await sttEngine.stop();
    isListening = false;
    statusLabel = 'Processing…';
    if (recognizedText.isNotEmpty) {
      chatHistory.add(MindfulnessMessage(recognizedText, isUser: true));
      notifyListeners();
      
      final textToProcess = recognizedText.toLowerCase();
      recognizedText = ''; // Clear early to prevent duplicate async triggers
      await _handleVoiceCommand(textToProcess);
    } else {
      notifyListeners();
    }
    
    isProcessing = false;
    notifyListeners();
  }

  // ── Conversational helper ─────────────────────────────────────────────────

  Future<void> speakConversationalResponse(String response) async {
    chatHistory.add(MindfulnessMessage(response, isUser: false));
    activeTab = 'chat'; // Automatically switch to the chat tab to show the response
    statusLabel = 'Speaking answer…';
    notifyListeners();
    await tts.stop(); // Stop any overlapping/queued speech before speaking
    await _restoreNormalTtsSettings(); // Ensure speech rate and pitch are normal for conversational responses
    await tts.speak(response);

    // If the controller is expecting an answer, automatically turn the microphone back on!
    // But ONLY if the user hasn't already manually turned it on by interrupting us!
    if (!isListening) {
      if (currentState != 'idle' && _context != null && _context!.mounted) {
        await Future.delayed(const Duration(milliseconds: 1000)); // Delay to allow TTS to release audio focus
        await startListening();
      } else {
        statusLabel = 'Press microphone to talk';
        notifyListeners();
      }
    }
  }

  // ── Voice command handler ─────────────────────────────────────────────────

  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "I didn't catch that. Try again.";
      notifyListeners();
      await tts.speak("I didn't catch that. Please try again.");
      return;
    }

    // 0. In-session voice commands (highest priority when paused mid-session)
    if (isPaused) {
      if (text.contains('stop') || text.contains('close') || text.contains('end') || text.contains('exit') || text.contains('quit')) {
        await stopSessionAndGoBack();
        return;
      }
      if (text.contains('continue') || text.contains('resume') || text.contains('carry on') || text.contains('go on') || text.contains('keep going') || text.contains('start again') || text.contains('play')) {
        statusLabel = 'Resuming session…';
        notifyListeners();
        await tts.speak('Resuming your session now.');
        await resumeSession();
        return;
      }
      if (text.contains('pause')) {
        // Already paused – just confirm
        await tts.speak('Session is already paused. Say continue to resume or stop to end.');
        return;
      }
      // Unrecognised command while paused – prompt user
      await tts.speak('Session is paused. Say continue to resume, or stop to close the meditation.');
      return;
    }

    // 1. Crisis / Self-Harm detection (always first, always highest priority)
    final callKey = CrisisDetector.detectCallIntent(text);
    if (callKey != null || CrisisDetector.isCrisis(text)) {
      statusLabel = 'Redirecting to Emergency Support…';
      notifyListeners();
      const msg =
          'I hear how much pain you are in, and I want you to be safe. '
          'I am redirecting you to our emergency support page immediately. Please connect with a professional. You are not alone.';
      chatHistory.add(MindfulnessMessage(msg, isUser: false));
      await tts.speak(msg);
      if (_context != null && _context!.mounted) {
        Navigator.push(
          _context!,
          MaterialPageRoute(builder: (_) => EmergencySupportPage(initialCallKey: callKey)),
        );
      }
      return;
    }

    // 1b. Breathing Exercise detection (Global routing)
    final breathingExId = BreathingDetector.detectExerciseIntent(text);
    if (breathingExId != null) {
      statusLabel = 'Redirecting to Breathing Exercises…';
      notifyListeners();
      await tts.speak('Starting breathing exercise.');
      if (_context != null && _context!.mounted) {
        Navigator.push(
          _context!,
          MaterialPageRoute(builder: (_) => BreathingExercisesPage(initialExerciseId: breathingExId)),
        );
      }
      return;
    }

    // 1c. CROSS-MODULE MENTIONS (Generic Navigation)
    if (text.contains('sleep') || text.contains('rest') || text.contains('bedtime') || text.contains('hygiene') || text.contains('insomnia')) {
      statusLabel = 'Redirecting to Sleep Hygiene…';
      notifyListeners();
      tts.speak('Opening Sleep Hygiene.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const SleepVuiScreen()));
      }
      return;
    }

    if (text.contains('mood') || text.contains('feeling') || text.contains('emotion') || text.contains('track')) {
      statusLabel = 'Redirecting to Mood Tracking…';
      notifyListeners();
      tts.speak('Opening Mood Tracking.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const MoodTrackingPage()));
      }
      return;
    }

    if (text.contains('breath') || text.contains('relax') || text.contains('calm') || text.contains('exercise')) {
      statusLabel = 'Redirecting to Breathing Exercises…';
      notifyListeners();
      tts.speak('Opening Breathing Exercises.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const BreathingExercisesPage()));
      }
      return;
    }

    if (text.contains('emergency') || text.contains('crisis') || text.contains('urgent') || text.contains('support') || text.contains('call')) {
      statusLabel = 'Redirecting to Emergency Support…';
      notifyListeners();
      tts.speak('Opening Emergency Support.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const EmergencySupportPage()));
      }
      return;
    }
    // ── Psychoeducation & info queries (Local-First to save API Quota) ──────
    // Placed here so that users can ask questions even while the app is waiting for a yes/no!

    if (text.contains('what is mindfulness') || text.contains('explain mindfulness')) {
      await speakConversationalResponse(
        'Mindfulness is the practice of being fully present in the current moment, without judgment. '
        'It helps you observe your thoughts, feelings, and sensations gently, which can reduce stress and increase emotional balance. '
        'Would you like to start a meditation session now, or ask another question?',
      );
      return;
    }
    if (text.contains('what is meditation') || text.contains('explain meditation') || text.contains('why should i meditate') || text.contains('benefits of meditation')) {
      await speakConversationalResponse(
        'Regular meditation helps calm your nervous system, improves your focus, reduces stress and anxiety, and builds emotional resilience. '
        'It is a gentle way to care for your mind. '
        'Would you like to try one of our guided meditations now, or ask something else?',
      );
      return;
    }

    if (text.contains('what is loving kindness') || text.contains('explain loving kindness') || text.contains('compassion meditation')) {
      await speakConversationalResponse(
        'Loving Kindness meditation involves sending wishes of safety, happiness, and peace to yourself, your loved ones, and eventually all living beings. '
        'It helps cultivate compassion and reduce negative emotions. '
        'Would you like to start the Loving Kindness session now, or ask another question?',
      );
      return;
    }
    if (text.contains('what is mindful observation') || text.contains('explain mindful observation')) {
      await speakConversationalResponse(
        'Mindful Observation is a practice where you focus your visual attention on a single object in front of you. '
        'It grounds you in the physical present and slows down rapid thoughts. '
        'Would you like to start the Mindful Observation session now, or ask another question?',
      );
      return;
    }
    if (text.contains('what is anxiety') || text.contains('how to manage anxiety') || text.contains('help with anxiety')) {
      await speakConversationalResponse(
        'Anxiety is a natural response to stress, but it can feel overwhelming. '
        'You can manage it by taking slow, deep breaths, grounding yourself in the present, or doing our Beginner Meditation. '
        'Would you like me to start the Beginner Meditation for you now?',
      );
      return;
    }
    if (text.contains('what is stress') || text.contains('how to manage stress') || text.contains('help with stress')) {
      await speakConversationalResponse(
        'Stress is how your body responds to daily challenges and pressures. '
        'You can manage it by setting boundaries, taking deep breaths, and using a Mindful Observation session or breathing exercises to relax your muscles. '
        'Would you like to try a meditation session now, or ask something else?',
      );
      return;
    }
    if (text.contains('what is depression') || text.contains('help with depression') || text.contains('explain depression')) {
      await speakConversationalResponse(
        'Depression is a common mental health challenge that can feel like a heavy weight, causing sadness or loss of interest. '
        'Please know that you are not alone, and speaking to a professional or a loved one is a courageous first step. '
        'We also have a Loving Kindness meditation for comfort, or I can guide you to our Emergency Support page. '
        'Would you like to view our Emergency contacts, or start a meditation?',
      );
      return;
    }
    if (text.contains('what can i say') || text.contains('features') || text.contains('how does this work') || text.contains('help')) {
      await speakConversationalResponse(
        'You can say, "Start Loving Kindness", "Start Focus", "Start Gratitude", "Start Mindful Observation", or "Start Beginner Meditation". '
        'You can also ask questions like, "What is mindfulness?", "How do I manage anxiety?", or say "Go back". '
        'What would you like to do now?',
      );
      return;
    }


    // 2. State: awaiting_reflection_response
    if (currentState == 'awaiting_reflection_response') {
      currentState = 'idle';
      if (text.contains('better') ||
          text.contains('good') ||
          text.contains('relaxed') ||
          text.contains('calm') ||
          text.contains('fine') ||
          text.contains('peace') ||
          text.contains('well') ||
          text.contains('happy') ||
          text.contains('great')) {
        await speakConversationalResponse(
          'I am so glad to hear that! Keep carrying this peace and warmth with you as you go about your day.',
        );
      } else {
        await speakConversationalResponse(
          'That is completely okay, healing takes time. Would you like to try another session, or just talk to me?',
        );
      }
      return;
    }

    // 3. State: awaiting_session_confirmation
    if (currentState == 'awaiting_session_confirmation') {
      final isYes = text.contains('yes') ||
          text.contains('sure') ||
          text.contains('okay') ||
          text.contains('ok') ||
          text.contains('start') ||
          text.contains('play') ||
          text.contains('begin') ||
          text.contains('go') ||
          text.contains('let') ||
          text.contains('do it') ||
          text.contains('please');
      final isNo = text.contains('no') ||
          text.contains('not now') ||
          text.contains('skip') ||
          text.contains('later') ||
          text.contains('cancel');

      if (isYes) {
        currentState = 'idle';
        await _startRecommendedSession();
      } else if (isNo) {
        currentState = 'idle';
        recommendedSession = '';
        notifyListeners();
        final allTitles = [
          ...kMindfulnessSessions.map((s) => s['title'] as String),
          ...kGuidedMeditationSessions.map((s) => s['title'] as String),
        ].join(', ');
        await speakConversationalResponse(
          'That is completely fine. Available sessions are: $allTitles. Which one would you like to try?',
        );
      } else {
        await speakConversationalResponse(
          'Just say yes to start the session, or no if you would prefer not to right now.',
        );
      }
      return;
    }

    // 4. State: awaiting_meditation_choice (manual selection by name)
    if (currentState == 'awaiting_meditation_choice') {
      currentState = 'idle';
      final detectedSession = MindfulnessDetector.detectSessionIntent(text);
      if (detectedSession != null) {
        recommendedSession = detectedSession;
        await _startRecommendedSession();
      } else if (text.contains('one') || text.contains('first')) {
        chatHistory.add(MindfulnessMessage('Starting Beginner Meditation…', isUser: false));
        notifyListeners();
        await runBeginnerMeditation();
      } else {
        await speakConversationalResponse(
          'I did not catch which session you want. You can say Loving Kindness, Focus, Gratitude, Mindful Observation, or Beginner Meditation.',
        );
      }
      return;
    }

    // ── Emotion detection (suggest + confirm) ────────────────────────────────

    // 5. Anxiety / Panic
    if (text.contains('panic') || text.contains('scared') || text.contains('cannot breathe') ||
        text.contains('heart is racing') || text.contains('fear') || text.contains('terrified') ||
        text.contains('anxious') || text.contains('anxiety') || text.contains('nervous') ||
        text.contains('worry') || text.contains('worried')) {
      detectedEmotion = 'anxiety';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'beginner';
      notifyListeners();
      await speakConversationalResponse(
        'I hear that you are feeling anxious. '
        'Beginner Meditation is a great way to calm your nervous system step by step through slow breathing and release exercises. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 6. Stress / Overwhelm
    if (text.contains('stressed') || text.contains('overwhelmed') || text.contains('pressure') ||
        text.contains('exhausted') || text.contains('tense') || text.contains('stress') ||
        text.contains('overwhelm') || text.contains('burnout') || text.contains('burnt out')) {
      detectedEmotion = 'stress';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'mindful_observation';
      notifyListeners();
      await speakConversationalResponse(
        'I hear that you are carrying a lot right now. '
        'Mindful Observation is a gentle way to release stress and ground yourself in the present moment, letting go of tension. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 6b. Tired / Relax / Unwind
    if (text.contains('tired') || text.contains('relax') || text.contains('relaxing') ||
        text.contains('unwind') || text.contains('need a break')) {
      detectedEmotion = 'stress';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'mindful_observation';
      notifyListeners();
      await speakConversationalResponse(
        'Taking a break is so important. '
        'A Mindful Observation session will gently anchor your mind to the present moment and quiet racing thoughts. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 7. Sleep
    if (text.contains('sleep') || text.contains('insomnia') || text.contains('bedtime') ||
        text.contains('restless') || text.contains('cannot sleep') || text.contains('can not sleep') ||
        text.contains('awake') || text.contains('falling asleep')) {
      detectedEmotion = 'sleep';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'loving_kindness';
      notifyListeners();
      await speakConversationalResponse(
        'Trouble sleeping is very common. '
        'Loving Kindness meditation is perfect for bedtime — it quiets worried thoughts and replaces them with warmth and safety. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 8. Sadness / Loneliness
    if (text.contains('sad') || text.contains('lonely') || text.contains('depressed') ||
        text.contains('unhappy') || text.contains('crying') || text.contains('hopeless') ||
        text.contains('grief') || text.contains('heartbroken') || text.contains('numb') ||
        text.contains('empty')) {
      detectedEmotion = 'sad';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'loving_kindness';
      notifyListeners();
      await speakConversationalResponse(
        'I am sorry you are feeling this way. You are not alone. '
        'Loving Kindness meditation builds self-compassion and a sense of connection, which research shows reduces sadness and loneliness. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 8b. Anger / Frustration
    if (text.contains('angry') || text.contains('anger') || text.contains('frustrated') ||
        text.contains('frustration') || text.contains('irritated') || text.contains('irritable') ||
        text.contains('furious') || text.contains('rage')) {
      detectedEmotion = 'anger';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'mindful_observation';
      notifyListeners();
      await speakConversationalResponse(
        'I understand you are feeling frustrated. '
        'Mindful Observation can help by grounding you in the present and releasing the physical tension that comes with intense emotions. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 8c. Focus / Concentration
    if (text.contains('cannot focus') || text.contains('can not focus') || text.contains('distracted') ||
        text.contains('mind is wandering') || text.contains('cannot concentrate') ||
        text.contains('can not concentrate') || text.contains('procrastinat')) {
      detectedEmotion = 'focus';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'focus_concentration';
      notifyListeners();
      await speakConversationalResponse(
        'Difficulty focusing is a sign your mind needs a reset. '
        'The Focus and Concentration meditation trains your attention to return to a single point, rebuilding your ability to concentrate. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 8d. Low self-esteem / Self-criticism / Loneliness
    if (text.contains('hate myself') || text.contains('worthless') || text.contains('not good enough') ||
        text.contains('failure') || text.contains('i failed') || text.contains('self doubt') ||
        text.contains('low confidence') || text.contains('insecure') || text.contains('lonely') ||
        text.contains('alone') || text.contains('love my self') || text.contains('love myself') ||
        text.contains('need some love')) {
      detectedEmotion = 'sad';
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'loving_kindness';
      notifyListeners();
      await speakConversationalResponse(
        'Those feelings are hard to carry. '
        'The Loving Kindness meditation is specifically designed to build self-compassion and replace self-critical thoughts with warmth. '
        'Would you like me to start it for you?',
      );
      return;
    }

    // 8e. Gratitude / Positivity
    if (text.contains('grateful') || text.contains('thankful') || text.contains('blessed') ||
        text.contains('appreciate') || text.contains('gratitude')) {
      currentState = 'awaiting_session_confirmation';
      recommendedSession = 'gratitude';
      notifyListeners();
      await speakConversationalResponse(
        'That is a beautiful state of mind. '
        'The Gratitude Meditation will deepen that feeling and help you carry it with you throughout your day. '
        'Would you like me to start it for you?',
      );
      return;
    }


    // ── Tab switching ────────────────────────────────────────────────────────
    if (text.contains('open mindfulness') || text.contains('show mindfulness')) {
      activeTab = 'mindfulness';
      statusLabel = 'Showing Mindfulness Sessions';
      notifyListeners();
      await speakConversationalResponse('Opening mindfulness sessions. Which one would you like to start?');
      return;
    }
    if (text.contains('open guided') || text.contains('show guided') || text.contains('open guidance') || text.contains('show guidance')) {
      activeTab = 'guided';
      statusLabel = 'Showing Guided Meditations';
      notifyListeners();
      await speakConversationalResponse('Opening guided meditations. Which one would you like to start?');
      return;
    }

    // ── Direct session start commands ────────────────────────────────────────
    final detectedSession = MindfulnessDetector.detectSessionIntent(text);
    if (detectedSession != null) {
      statusLabel = 'Starting session…';
      notifyListeners();
      recommendedSession = detectedSession;
      await _startRecommendedSession();
      return;
    }
    
    if (text.contains('stop') || text.contains('pause') || text.contains('cancel')) {
      statusLabel = 'Stopping practice…';
      notifyListeners();
      await stopSession();
    } else if (text.contains('back') || text.contains('home') || text.contains('exit')) {
      statusLabel = 'Going back…';
      notifyListeners();
      await tts.speak('Going back to the home page.');
      if (_context != null && _context!.mounted) Navigator.pop(_context!);
    } else {
      // Local fallback (API removed)
      statusLabel = 'Processing locally…';
      notifyListeners();
      
      if (text.contains('mindfulness') || text.contains('meditation') || text.contains('meditate')) {
        currentState = 'awaiting_meditation_choice';
        notifyListeners();
        await speakConversationalResponse(
          'Mindfulness and meditation can help calm your nervous system. '
          'We have sessions like Beginner Meditation, Focus, Loving Kindness, Gratitude, and Mindful Observation. '
          'Which session would you like to start?',
        );
        return;
      } else if (text.contains('anxiety')) {
        await speakConversationalResponse('Anxiety is a natural response to stress. You can manage it by taking slow, deep breaths. Would you like to try the Beginner Meditation?');
      } else if (text.contains('stress')) {
        await speakConversationalResponse('Stress is how your body responds to pressures. You can manage it by taking deep breaths. Would you like to try a meditation?');
      } else {
        chatHistory.add(const MindfulnessMessage(
          "I am sorry, I didn't catch that. Try saying 'Start Loving Kindness' or ask me about mindfulness.",
          isUser: false,
        ));
        statusLabel = 'Waiting for input';
        notifyListeners();
        await tts.speak("I am sorry, I didn't catch that. Try saying 'Start Loving Kindness' or ask me about mindfulness.");
      }
    }
  }

  // ── Session runners ───────────────────────────────────────────────────────

  Future<void> _startRecommendedSession() async {
    switch (recommendedSession) {
      case 'body_scan':
        chatHistory.add(MindfulnessMessage('Starting Body Scan…', isUser: false));
        notifyListeners();
        await runBodyScan();
        break;
      case 'loving_kindness':
        chatHistory.add(MindfulnessMessage('Starting Loving Kindness…', isUser: false));
        notifyListeners();
        await runLovingKindness();
        break;
      case 'anxiety_reduction':
        chatHistory.add(MindfulnessMessage('Starting Anxiety Reduction…', isUser: false));
        notifyListeners();
        await runAnxietyReduction();
        break;
      case 'focus_concentration':
        chatHistory.add(MindfulnessMessage('Starting Focus & Concentration…', isUser: false));
        notifyListeners();
        await runFocusConcentration();
        break;
      case 'gratitude':
        chatHistory.add(MindfulnessMessage('Starting Gratitude Meditation…', isUser: false));
        notifyListeners();
        await runGratitudeMeditation();
        break;
      case 'mindful_observation':
        chatHistory.add(MindfulnessMessage('Starting Mindful Observation…', isUser: false));
        notifyListeners();
        await runMindfulObservation();
        break;
      case 'beginner':
      default:
        chatHistory.add(MindfulnessMessage('Starting Beginner Meditation…', isUser: false));
        notifyListeners();
        await runBeginnerMeditation();
        break;
    }
  }

  Future<void> runBodyScan() => _startSession(
        title: 'Body Scan',
        duration: const Duration(minutes: 5),
        cues: kBodyScanCues,
        playMusic: true,
      );

  Future<void> runMindfulObservation() => _startSession(
        title: 'Mindful Observation',
        duration: const Duration(minutes: 3),
        cues: kMindfulObservationCues,
      );

  Future<void> runLovingKindness() => _startSession(
        title: 'Loving Kindness',
        duration: const Duration(minutes: 5),
        cues: kLovingKindnessCues,
      );

  Future<void> runBeginnerMeditation() => _startSession(
        title: 'Beginner Meditation',
        duration: const Duration(minutes: 5),
        cues: kBeginnerMeditationCues,
      );

  Future<void> runAnxietyReduction() => _startSession(
        title: 'Anxiety Reduction',
        duration: const Duration(minutes: 5),
        cues: kAnxietyReductionCues,
      );

  Future<void> runFocusConcentration() => _startSession(
        title: 'Focus & Concentration',
        duration: const Duration(minutes: 5),
        cues: kFocusConcentrationCues,
      );

  Future<void> runGratitudeMeditation() => _startSession(
        title: 'Gratitude Meditation',
        duration: const Duration(minutes: 5),
        cues: kGratitudeMeditationCues,
      );

  Future<void> _startSession({
    required String title,
    required Duration duration,
    required List<Map<String, dynamic>> cues,
    bool playMusic = true,
  }) async {
    if (isPlaying) return;
    _clearGuidanceTimers();
    _clearResumeTimers();

    // Save for potential pause/resume
    _sessionTitle = title;
    _sessionDuration = duration;
    _sessionCues = cues;
    _sessionPlayMusic = playMusic;
    _pausedElapsed = Duration.zero;
    isPaused = false;

    isPlaying = true;
    sessionLabel = '$title in progress…';
    activeTab = 'chat';
    notifyListeners();

    progressController.duration = duration;
    progressController.reset();
    progressController.forward();

    if (playMusic) {
      try {
        await audioPlayer.play(AssetSource('sounds/smooth.mp3'));
        await audioPlayer.setVolume(0.4);
      } catch (e) {
        debugPrint('Error playing background audio: $e');
      }
    }

    // Calm, slow speech settings for meditation guidance
    await tts.setSpeechRate(0.20);
    await tts.setPitch(0.85);
    await tts.setVolume(0.65);

    for (final cue in cues) {
      final offset = cue['offset'] as Duration;
      final cueText = cue['text'] as String;

      if (offset == Duration.zero) {
        await tts.speak(cueText);
      } else {
        final timer = Timer(offset, () async {
          if (isPlaying) await tts.speak(cueText);
        });
        _guidanceTimers.add(timer);
      }
    }
  }

  // ── Pause ─────────────────────────────────────────────────────────────────

  Future<void> pauseSession() async {
    if (!isPlaying) return;
    _clearGuidanceTimers();
    _clearResumeTimers();
    await tts.stop();
    await audioPlayer.pause();
    progressController.stop();
    _pausedElapsed = _sessionDuration * progressController.value;
    isPlaying = false;
    isPaused = true;
    sessionLabel = 'Session paused. Say "continue" to resume or "stop" to end.';
    statusLabel = 'Listening…';
    notifyListeners();
  }

  // ── Resume ────────────────────────────────────────────────────────────────

  Future<void> resumeSession() async {
    if (!isPaused) return;
    isPaused = false;
    isPlaying = true;
    sessionLabel = '$_sessionTitle in progress…';
    activeTab = 'chat';
    notifyListeners();

    await audioPlayer.resume();

    // Meditation TTS settings
    await tts.setSpeechRate(0.20);
    await tts.setPitch(0.85);
    await tts.setVolume(0.65);

    // Restart progress from where we left off
    final remainingDuration = _sessionDuration - _pausedElapsed;
    progressController.duration = remainingDuration;
    progressController.forward();

    // Re-schedule only the cues that haven't fired yet
    for (final cue in _sessionCues) {
      final cueOffset = cue['offset'] as Duration;
      if (cueOffset <= _pausedElapsed) continue; // already played
      final delay = cueOffset - _pausedElapsed;
      final t = Timer(delay, () async {
        if (isPlaying) await tts.speak(cue['text'] as String);
      });
      _resumeTimers.add(t);
    }
  }

  // ── Stop (full) ───────────────────────────────────────────────────────────

  Future<void> stopSession() async {
    _clearGuidanceTimers();
    _clearResumeTimers();
    await tts.stop();
    await _restoreNormalTtsSettings();
    await audioPlayer.stop();
    progressController.stop();
    progressController.reset();
    isPlaying = false;
    isPaused = false;
    _pausedElapsed = Duration.zero;
    sessionLabel = 'Session stopped.';
    currentState = 'idle';
    notifyListeners();
  }

  /// Stop the session and return to the main Mindfulness & Meditation page view.
  /// Stays on this page — does NOT navigate away.
  Future<void> stopSessionAndGoBack() async {
    await tts.stop();
    await stopSession();
    // Reset to the main page view (chat tab with Mindfulness / Guided buttons)
    activeTab = 'chat';
    sessionLabel = 'Tap a session to begin';
    notifyListeners();
    await tts.speak('Meditation closed. You can choose another session whenever you are ready.');
  }

  Future<void> _onSessionComplete() async {
    _clearGuidanceTimers();
    _clearResumeTimers();
    isPlaying = false;
    isPaused = false;
    sessionLabel = 'Session complete. How do you feel now?';
    chatHistory.add(MindfulnessMessage('Session complete. Well done.', isUser: false));
    notifyListeners();
    await tts.speak('Session complete. Well done... How do you feel now?');
    currentState = 'awaiting_reflection_response';
    notifyListeners();
    await Future.delayed(const Duration(seconds: 4));
    await _restoreNormalTtsSettings();
    await audioPlayer.stop();
  }

  void _clearGuidanceTimers() {
    for (final t in _guidanceTimers) {
      t.cancel();
    }
    _guidanceTimers.clear();
  }

  void _clearResumeTimers() {
    for (final t in _resumeTimers) {
      t.cancel();
    }
    _resumeTimers.clear();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _clearGuidanceTimers();
    _clearResumeTimers();
    tts.stop();
    sttEngine.stop();
    audioPlayer.stop();
    audioPlayer.dispose();
    progressController.dispose();
    super.dispose();
  }
}


// ── Simple message model ──────────────────────────────────────────────────────

class MindfulnessMessage {
  final String text;
  final bool isUser;
  const MindfulnessMessage(this.text, {required this.isUser});
}
