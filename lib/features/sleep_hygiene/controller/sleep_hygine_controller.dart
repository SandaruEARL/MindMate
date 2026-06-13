// sleep_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import '../../../core/services/speech_to_text_service.dart';
import '../../../core/services/tts_service.dart';
import 'package:mindmate/features/emergency_support/services/crisis_detector.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_detector.dart';
import 'package:mindmate/features/mindfulness/services/mindfulness_detector.dart';


/// SleepController holds all business logic, state, and VUI handling
/// for the Sleep Hygiene page. It is a [ChangeNotifier] so the UI can rebuild
/// reactively on state changes.
class SleepController extends ChangeNotifier {
  SleepController({required this.vsync});

  final TickerProvider vsync;

  // ── External services ──────────────────────────────────────────────────────
  final TtsService ttsService = TtsService();
  final SpeechToTextService sttService = SpeechToTextService();

  // ── Exposed state ──────────────────────────────────────────────────────────
  bool isListening  = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel    = 'Tap the mic and speak';

  /// VUI dialogue state machine.
  /// Values: 'idle', 'awaiting_nav_confirmation'
  String currentState    = 'idle';
  String pendingNavRoute = '';

  // Tracks consecutive "didn't understand" fallback responses.
  // Resets to 0 whenever any recognizable intent is matched.
  int _consecutiveFallbacks = 0;

  /// Set when a response ends with "want to know about A, B, or C?".
  /// Holds a tag identifying which menu was offered, so a bare "yes"
  /// can be answered with "which one?" and a named topic can be
  /// dispatched directly.
  String pendingTopicContext = '';

  // ── Intake state ──────────────────────────────────────────────────────────
  // Phases: 'ask_issue' → 'ask_bedtime' → 'ask_waketime' → 'done'
  String intakePhase  = 'ask_issue';
  String userIssue    = ''; // 'onset' | 'maintenance' | 'early' | 'quality'
  String userBedtime  = '';
  String userWakeTime = '';

  final List<SleepMessage> chatHistory = [];

  // ── BuildContext for navigation ────────────────────────────────────────────
  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  // ── Initialisation ─────────────────────────────────────────────────────────
  Future<void> init() async {
    await ttsService.initialise();
    await sttService.initialise();
    await sttService.forceReset();

    sttAvailable = sttService.isAvailable;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));

    intakePhase = 'ask_issue';
    const greeting =
        "Hi! I'm your Sleep Hygiene assistant. "
        "Before we start, I'd like to understand you a little better. "
        "What's your main sleep concern right now? "
        "Is it trouble falling asleep, waking up during the night, "
        "waking up too early, or feeling unrefreshed in the morning?";
    chatHistory.add(SleepMessage(greeting, isUser: false));
    await ttsService.speak(greeting);
    await ttsService.awaitCompletion();
  }

  // ── STT / Mic ──────────────────────────────────────────────────────────────

  Future<void> onMicTap() async {
    isListening ? await stopListening() : await startListening();
  }

  Future<void> startListening() async {
    if (!sttService.isAvailable) {
      await ttsService.speak('Speech recognition is not available on this device.');
      await ttsService.awaitCompletion();
      return;
    }

    isProcessing = false;

    await ttsService.stop();
    await ttsService.awaitCompletion();

    isListening    = true;
    recognizedText = '';
    statusLabel    = 'Listening…';
    notifyListeners();

    String result = '';
    try {
      result = await sttService.listen();
    } on SpeechException catch (e) {
      statusLabel = e.message;
      result = '';
    }

    recognizedText = result;
    notifyListeners();

    await stopListening();
  }

  Future<void> stopListening() async {
    if (isProcessing) return;
    isProcessing = true;
    await sttService.stop();
    isListening = false;
    statusLabel = 'Processing…';

    if (recognizedText.isNotEmpty) {
      chatHistory.add(SleepMessage(recognizedText, isUser: true));
      notifyListeners();
      final textToProcess = recognizedText.toLowerCase();
      recognizedText = '';
      await _handleVoiceCommand(textToProcess);
    } else {
      notifyListeners();
    }

    isProcessing = false;
    notifyListeners();
  }

  // ── Public entry point for chip taps ──────────────────────────────────────
  Future<void> sendTextCommand(String displayLabel, String command) async {
    if (isProcessing || isListening) return;
    isProcessing = true;
    statusLabel  = 'Processing…';
    chatHistory.add(SleepMessage(displayLabel, isUser: true));
    notifyListeners();
    await _handleVoiceCommand(command.toLowerCase());
    isProcessing = false;
    notifyListeners();
  }

  // ── Conversational helper ──────────────────────────────────────────────────
  Future<void> _speak(String response) async {
    chatHistory.add(SleepMessage(response, isUser: false));
    statusLabel = 'Speaking…';
    notifyListeners();

    await ttsService.speak(response);
    await ttsService.awaitCompletion();

    statusLabel = 'Tap the mic and speak';
    notifyListeners();
  }

  // ── Word-boundary matching helper ──────────────────────────────────────────
  //
  // text.contains('tired') would match "untired" or "retired".
  // This ensures we only match the word as a standalone token.
  bool _hasWord(String text, String word) {
    return RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(text);
  }

  // ── Question-form pre-check ────────────────────────────────────────────────
  //
  // Returns true if the utterance is clearly informational in nature.
  // Used to short-circuit emotional-state intents for definitional queries.
  bool _isQuestion(String text) {
    return text.startsWith('what')   ||
        text.startsWith('how')    ||
        text.startsWith('why')    ||
        text.startsWith('when')   ||
        text.startsWith('which')  ||
        text.startsWith('who')    ||
        text.startsWith('define') ||
        text.startsWith('explain')||
        text.startsWith('tell me about') ||
        text.startsWith('describe');
  }

  // ── Connector helper ────────────────────────────────────────────────────
  String _join(String a, String b, {String type = 'reason'}) {
    const connectors = {
      'reason':      ['So ', "That's why ", 'This means '],
      'contrast':    ['That said, ', 'But ', 'Even so, '],
      'elaboration': ['Because of this, ', 'Which means ', 'In other words, '],
      'addition':    ['And ', 'Also, ', 'On top of that, '],
    };
    final pick = connectors[type]!;
    final connector = pick[a.length % pick.length];
    return '$a $connector${b[0].toLowerCase()}${b.substring(1)}';
  }

  // ── Topic dispatch helper ───────────────────────────────────────────────
  //
  // Given a follow-up utterance and the context tag of the menu that was
  // just offered, speaks the matching topic's info. Returns true if a topic
  // was matched and handled, false otherwise (caller should ask again).
  Future<bool> _dispatchTopicChoice(String text, String context) async {
    switch (context) {
      case 'sleep_concepts': // offered by 4a
        if (text.contains('stage') || text.contains('rem') || text.contains('deep') || text.contains('cycle')) {
          await _speakSleepStages();
          return true;
        }
        if (text.contains('hygiene')) {
          await _speakSleepHygiene();
          return true;
        }
        if (text.contains('tip') || text.contains('better')) {
          await _speakGeneralTips();
          return true;
        }
        return false;

      case 'hygiene_areas': // offered by 4b
        if (text.contains('screen') || text.contains('phone') || text.contains('blue light')) {
          await _speakScreenTime();
          return true;
        }
        if (text.contains('caffeine') || text.contains('coffee') || text.contains('alcohol')) {
          await _speakCaffeineAlcohol();
          return true;
        }
        if (text.contains('routine') || text.contains('wind down') || text.contains('wind-down')) {
          await _speakWindDown();
          return true;
        }
        if (text.contains('environment') || text.contains('bedroom') || text.contains('room')) {
          await _speakSleepEnvironment();
          return true;
        }
        return false;

      default:
        return false;
    }
  }

  // ── Topic content (extracted so they're reusable from menus) ───────────

  Future<void> _speakSleepStages() async {
    final ack  = "Sleep actually cycles through stages roughly every 90 minutes.";
    final core = "Light sleep is the drift-off phase, deep sleep is when your body repairs itself and locks in memories, and REM is when most dreaming happens - key for emotional regulation and learning.";
    final bridge = _join(core,
        "cutting sleep short hits mood and memory the hardest, since you don't get to cycle through everything.",
        type: 'reason');
    await _speak('$ack $bridge');
  }

  Future<void> _speakSleepHygiene() async {
    final ack  = "Sleep hygiene is basically your sleep habits as a whole.";
    final core = "It covers your bedtime routine, your sleep environment, and daytime habits like caffeine, exercise, and screen time.";
    final bridge = _join(core,
        "it works by reinforcing your circadian rhythm - the internal clock that decides when you feel sleepy or alert.",
        type: 'elaboration');
    currentState = 'awaiting_topic_choice';
    pendingTopicContext = 'hygiene_areas';
    notifyListeners();
    final cta = "Want specific tips on screen time, caffeine and alcohol, your bedtime routine, or your sleep environment?";
    await _speak('$ack $bridge $cta');
  }

  Future<void> _speakGeneralTips() async {
    final ack  = "Happy to help - here's what I can talk about.";
    final core = "Bedtime routines, trouble falling asleep, screen time, naps, sleep duration, your sleep environment, caffeine and alcohol, exercise, or melatonin.";
    final cta  = "You can also say 'go back' to head home, or ask for Breathing Exercises, Mindfulness, or Mood Tracking. What sounds good?";
    await _speak('$ack $core $cta');
  }

  Future<void> _speakScreenTime() async {
    final ack  = "Screens before bed are genuinely one of the hardest habits to break.";
    final core = "Blue light blocks melatonin - the hormone that makes you feel sleepy.";
    final bridge = _join(core,
        "even 30 minutes off screens before bed makes a measurable difference.",
        type: 'reason');
    final cta = "Try switching to a book, light stretching, or a podcast instead.";
    await _speak('$ack $bridge $cta');
  }

  Future<void> _speakCaffeineAlcohol() async {
    final ack  = "What you eat and drink in the evening matters more than most people realise.";
    final core = "Caffeine has a 6-hour half-life - a 3pm coffee is still half-strength at 9pm.";
    final bridge = _join(core,
        "cutting off around 2pm is the single easiest win.",
        type: 'reason');
    final alcohol = "Alcohol's the other one - it helps you fall asleep faster but wrecks deep and REM sleep later in the night.";
    await _speak('$ack $bridge $alcohol');
  }

  Future<void> _speakWindDown() async {
    final ack  = "A solid wind-down routine is one of the best things for sleep hygiene.";
    final core = "Dim the lights about an hour before bed to kick off melatonin production, then at 30 minutes out stop screens and switch to reading, stretching, or a warm shower.";
    final bridge = _join(core,
        "the warm shower trick works because the temperature drop afterward mimics the natural dip that triggers sleep.",
        type: 'elaboration');
    final tip = "At 10 minutes, jot down any worries, then get into bed and focus on slow breathing.";
    await _speak('$ack $bridge $tip');
  }

  Future<void> _speakSleepEnvironment() async {
    final ack  = "Your bedroom setup matters more than people think.";
    final core = "The ideal room is cool, around 16 to 19 degrees, dark, and quiet - blackout curtains and white noise or earplugs help a lot.";
    final bridge = _join("Try to keep your bed for sleep only",
        "your brain builds a strong association between bed and sleep that way.",
        type: 'reason');
    await _speak('$ack $core $bridge');
  }

  // ── Intake handler ─────────────────────────────────────────────────────────
// Returns true if the utterance was consumed by the intake flow.

  Future<bool> _handleIntake(String text) async {
    switch (intakePhase) {

      case 'ask_issue':
        if (text.contains('fall') || text.contains('onset') ||
            text.contains('cannot sleep') || text.contains("can't sleep") ||
            text.contains('drift off') || text.contains('get to sleep')) {
          userIssue = 'onset';
        } else if (text.contains('wak') ||
            text.contains('stay asleep')         ||
            text.contains('middle of the night') ||
            text.contains('during the night')    ||
            text.contains('through the night')   ||
            text.contains('night waking')        ||
            text.contains('wake up at night')) {
          userIssue = 'maintenance';
        } else if (text.contains('early') || text.contains('too soon') ||
            text.contains('before alarm')) {
          userIssue = 'early';
        } else if (text.contains('unrefreshed') || text.contains('tired') ||
            text.contains('groggy') || text.contains('quality') ||
            text.contains('rested')) {
          userIssue = 'quality';
        } else {
          await _speak(
            "I didn't quite catch that. Could you say: "
                "trouble falling asleep, waking during the night, "
                "waking too early, or feeling unrefreshed?",
          );
          return true;
        }
        intakePhase = 'ask_bedtime';
        notifyListeners();
        await _speak("Got it. Around what time do you usually go to bed?");
        return true;

      case 'ask_bedtime':
        userBedtime = text.trim().isEmpty ? 'an unspecified time' : text;
        intakePhase = 'ask_waketime';
        notifyListeners();
        await _speak("And what time do you usually need to wake up?");
        return true;

      case 'ask_waketime':
        userWakeTime = text.trim().isEmpty ? 'an unspecified time' : text;
        intakePhase = 'done';
        notifyListeners();
        final personal =
            "Thanks — that really helps. So you're heading to bed around $userBedtime "
            "and up around $userWakeTime, with ${_issueSummary()} as your main concern. "
            "I'll keep all of that in mind. What would you like help with first?";
        await _speak(personal);
        return true;
    }
    return false;
  }

  String _issueSummary() {
    switch (userIssue) {
      case 'onset':       return 'trouble falling asleep';
      case 'maintenance': return 'waking during the night';
      case 'early':       return 'waking too early';
      case 'quality':     return 'feeling unrefreshed';
      default:            return 'sleep quality';
    }
  }

  /// Returns a personalised context line to prepend to advice, based on
  /// what the user told us during intake.
  String _contextPrefix() {
    if (userIssue.isEmpty) return '';
    switch (userIssue) {
      case 'onset':
        return "Since your main issue is falling asleep, this is especially relevant for you. ";
      case 'maintenance':
        return "Given that you're waking during the night, pay extra attention to this. ";
      case 'early':
        return "For someone waking too early, this is worth noting. ";
      case 'quality':
        return "Since you're feeling unrefreshed, sleep quality is key here. ";
      default:
        return '';
    }
  }

  // ── Voice command handler ──────────────────────────────────────────────────

  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "I didn't catch that. Try again.";
      notifyListeners();
      await ttsService.speak("I didn't catch that. Please try again.");
      await ttsService.awaitCompletion();
      return;
    }

    // ── 0. Crisis detection — always first, even during intake ────────────────
    final callKey = CrisisDetector.detectCallIntent(text);
    if (callKey != null || CrisisDetector.isCrisis(text)) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Emergency Support…';
      notifyListeners();
      const msg =
          'I hear how much pain you are in, and I want you to be safe. '
          'I am redirecting you to our emergency support page immediately. '
          'Please connect with a professional. You are not alone.';
      await _speak(msg);
      if (_context != null && _context!.mounted) {
        Navigator.push(
          _context!,
          MaterialPageRoute(builder: (_) => EmergencySupportPage(initialCallKey: callKey)),
        );
      }
      return;
    }

    // ── 0.5. Breathing Exercises global routing ────────────────────────────────
    final breathingExId = BreathingDetector.detectExerciseIntent(text);
    if (breathingExId != null) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Breathing Exercises…';
      notifyListeners();
      await _speak('Starting breathing exercise.');
      if (_context != null && _context!.mounted) {
        Navigator.push(
          _context!,
          MaterialPageRoute(builder: (_) => BreathingExercisesPage(initialExerciseId: breathingExId)),
        );
      }
      return;
    }

    // ── 0.6. Mindfulness Sessions global routing ────────────────────────────────
    final mindfulnessId = MindfulnessDetector.detectSessionIntent(text);
    if (mindfulnessId != null) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Mindfulness…';
      notifyListeners();
      await _speak('Starting mindfulness session.');
      if (_context != null && _context!.mounted) {
        Navigator.push(
          _context!,
          MaterialPageRoute(builder: (_) => MindfulnessPage(initialSessionId: mindfulnessId)),
        );
      }
      return;
    }

    // ── 0.7. CROSS-MODULE MENTIONS — navigate to other modules ────────────────
    if (text.contains('breath') || text.contains('relax') || text.contains('calm') || text.contains('exercise')) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Breathing Exercises…';
      notifyListeners();
      chatHistory.add(const SleepMessage('Opening Breathing Exercises.', isUser: false));
      ttsService.speak('Opening Breathing Exercises.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const BreathingExercisesPage()));
      }
      return;
    }

    if (text.contains('mindful') || text.contains('meditat') || text.contains('aware') || text.contains('present')) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Mindfulness…';
      notifyListeners();
      chatHistory.add(const SleepMessage('Opening Mindfulness.', isUser: false));
      ttsService.speak('Opening Mindfulness.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const MindfulnessPage()));
      }
      return;
    }

    if (text.contains('mood') || text.contains('feeling') || text.contains('emotion') || text.contains('track')) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Mood Tracking…';
      notifyListeners();
      chatHistory.add(const SleepMessage('Opening Mood Tracking.', isUser: false));
      ttsService.speak('Opening Mood Tracking.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const MoodTrackingPage()));
      }
      return;
    }

    if (text.contains('emergency') || text.contains('crisis') || text.contains('urgent') || text.contains('support') || text.contains('call')) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Redirecting to Emergency Support…';
      notifyListeners();
      chatHistory.add(const SleepMessage('Opening Emergency Support.', isUser: false));
      ttsService.speak('Opening Emergency Support.');
      if (_context != null && _context!.mounted) {
        Navigator.push(_context!, MaterialPageRoute(builder: (_) => const EmergencySupportPage()));
      }
      return;
    }

    // ── 1. Intake phase (runs until intake is complete) ───────────────────────
    if (intakePhase != 'done') {
      final handled = await _handleIntake(text);
      if (handled) return;
    }

    // ── 2. Awaiting nav confirmation ───────────────────────────────────────
    // ── 2. Awaiting nav confirmation ───────────────────────────────────────
    if (currentState == 'awaiting_nav_confirmation') {
      final isYes = text.contains('yes')     || text.contains('sure')    ||
          text.contains('okay')    || text.contains('ok')      ||
          text.contains('please')  || text.contains('yep')     ||
          text.contains('yup')     || text.contains('alright') ||
          text.contains('go')      || text.contains('fine');
      final isNo  = text.contains('no')      || text.contains('nah')     ||
          text.contains('nope')    || text.contains('cancel')  ||
          text.contains('not now') || text.contains('later');

      if (isYes) {
        _consecutiveFallbacks = 0;
        currentState = 'idle';
        await _navigateTo(pendingNavRoute);
        pendingNavRoute = '';
      } else if (isNo) {
        _consecutiveFallbacks = 0;
        currentState    = 'idle';
        pendingNavRoute = '';
        notifyListeners();
        await _speak(
          "No problem. I'm here whenever you need anything else. "
              "Just ask me about sleep tips, bedtime routines, or anything related to better sleep.",
        );
      } else {
        _consecutiveFallbacks = 0;
        await _speak('Just say yes to continue, or no if you prefer to stay here.');
      }
      return;
    }

    // ── 2.5. Awaiting topic choice ─────────────────────────────────────────
    if (currentState == 'awaiting_topic_choice') {
      final context = pendingTopicContext;
      currentState = 'idle';
      // Don't clear pendingTopicContext here yet

      final isYes = text.contains('yes')  || text.contains('sure') ||
          text.contains('okay') || text.contains('ok')   ||
          text.contains('please') || text.contains('yep')  ||
          text.contains('yup')  || text.contains('alright');
      final isNo  = text.contains('no')   || text.contains('nah')  ||
          text.contains('nope') || text.contains('not now') ||
          text.contains('later');

      if (isNo) {
        pendingTopicContext = ''; // Clear only on definitive exit
        _consecutiveFallbacks = 0;
        await _speak(
          "No problem. I'm here whenever you need anything else. "
              "Just ask me about sleep tips, bedtime routines, or anything related to better sleep.",
        );
        return;
      }

      final handled = await _dispatchTopicChoice(text, context);
      if (handled) {
        pendingTopicContext = ''; // Clear only on definitive exit
        _consecutiveFallbacks = 0;
        return;
      }

      if (isYes) {
        _consecutiveFallbacks = 0;
        currentState = 'awaiting_topic_choice';
        pendingTopicContext = context; // Restore (was never cleared)
        notifyListeners();
        await _speak("Sure - which one would you like to hear about?");
        return;
      }

      pendingTopicContext = ''; // Clear only when falling through
      // Unrecognised reply: fall through to normal intent matching below.
    }

    // ── 3. Back / exit / stop — checked before any topic intents ──────────
    if (_hasWord(text, 'back') || _hasWord(text, 'home') ||
        _hasWord(text, 'exit') || _hasWord(text, 'quit') ||
        _hasWord(text, 'leave')) {
      _consecutiveFallbacks = 0;
      statusLabel = 'Going back…';
      notifyListeners();
      await ttsService.speak('Going back to the home page. Sweet dreams!');
      await ttsService.awaitCompletion();
      if (_context != null && _context!.mounted) Navigator.pop(_context!);
      return;
    }

    if (_hasWord(text, 'stop')  || _hasWord(text, 'pause') ||
        _hasWord(text, 'quiet') || _hasWord(text, 'mute')) {
      _consecutiveFallbacks = 0;
      await ttsService.stop();
      await ttsService.awaitCompletion();
      statusLabel = 'Tap the mic and speak';
      notifyListeners();
      return;
    }

    // ── 4. DEFINITIONAL / INFORMATIONAL intents ────────────────────────────
    // These must come before ALL symptom/state intents so that question-form
    // utterances ("what is sleep", "explain REM") are never misrouted to an
    // emotional-state rule that happens to share a keyword.

    // 4a. What is sleep (bare concept — not "sleep hygiene", handled below)
    if (_isQuestion(text) &&
        (text.contains('what is sleep') ||
            text.contains('define sleep')  ||
            text.contains('explain sleep') ||
            (text.contains('what does sleep') && !text.contains('hygiene'))) &&
        !text.contains('hygiene')) {
      _consecutiveFallbacks = 0;

      final ack  = "Good question - sleep is more than just rest.";
      final core = "It's a recurring state where your brain consolidates memories and your body repairs itself, with growth hormone released along the way.";
      currentState = 'awaiting_topic_choice';
      pendingTopicContext = 'sleep_concepts';
      notifyListeners();
      final cta  = "Want to know about sleep stages, sleep hygiene, or tips for sleeping better?";
      await _speak('$ack $core $cta');
      return;
    }

    // 4b. What is sleep hygiene
    if (text.contains('what is sleep hygiene')  ||
        text.contains('explain sleep hygiene')  ||
        text.contains('sleep hygiene meaning')  ||
        text.contains('define sleep hygiene')   ||
        text.contains('sleep hygiene refers')   ||
        text.contains('sleep hygiene is')       ||
        text.contains('sleep hygiene means')) {
      _consecutiveFallbacks = 0;
      final ack  = "Sleep hygiene is basically your sleep habits as a whole.";
      final core = "It covers your bedtime routine, your sleep environment, and daytime habits like caffeine, exercise, and screen time.";

      final bridge = _join(core,
          "it works by reinforcing your circadian rhythm - the internal clock that decides when you feel sleepy or alert.",
          type: 'elaboration');
      currentState = 'awaiting_topic_choice';
      pendingTopicContext = 'hygiene_areas';
      notifyListeners();
      final cta = "Want specific tips on screen time, caffeine and alcohol, your bedtime routine, or your sleep environment?";
      await _speak('$ack $bridge $cta');
      return;

    }

    // 4c. Circadian rhythm
    if (text.contains('circadian')       ||
        text.contains('body clock')      ||
        text.contains('internal clock')  ||
        text.contains('sleep wake cycle')) {
      _consecutiveFallbacks = 0;
      final ack  = "Your circadian rhythm is basically your body's internal clock.";
      final core = "It's driven mainly by light - morning sunlight is the strongest signal that resets it each day.";
      final bridge = _join(core,
          "shift work, late nights, or jet lag throw it off and lead to poor sleep and daytime fatigue.",
          type: 'reason');
      final tip = "The fix is simple: wake at the same time daily and get outside in the morning.";
      await _speak('$ack $bridge $tip');
      return;
    }

    // 4d. REM / sleep stages
    if (text.contains('rem sleep')       || text.contains('sleep stages')   ||
        text.contains('deep sleep')       || text.contains('light sleep')    ||
        text.contains('sleep cycle')      ||
        text.contains('what happens when i sleep')) {
      _consecutiveFallbacks = 0;
      final ack  = "Sleep actually cycles through stages roughly every 90 minutes.";
      final core = "Light sleep is the drift-off phase, deep sleep is when your body repairs itself and locks in memories, and REM is when most dreaming happens - key for emotional regulation and learning.";
      final bridge = _join(core,
          "cutting sleep short hits mood and memory the hardest, since you don't get to cycle through everything.",
          type: 'reason');
      await _speak('$ack $bridge');
      return;
    }

    // 4e. Insomnia (informational framing)
    if (text.contains('insomnia')                     ||
        text.contains('chronic sleep problem')        ||
        text.contains('always have trouble sleeping') ||
        text.contains('never sleep well')             ||
        text.contains('sleep disorder')) {
      _consecutiveFallbacks = 0;
      final ack  = "Insomnia means trouble falling or staying asleep, at least three nights a week for over three months.";
      final core = "The most effective long-term fix is CBT-I, Cognitive Behavioural Therapy for Insomnia - it outperforms sleeping pills and has no side effects.";
      final bridge = _join(core,
          "good sleep hygiene is the foundation it's built on.",
          type: 'elaboration');
      final cta = "If this has been going on a while, a healthcare professional is worth talking to - but I can help with practical tips for tonight too.";
      await _speak('$ack $bridge $cta');
      return;
    }

    // 4f. Sleep duration (informational — "how many hours", "how long")
    if (text.contains('how many hours')            ||
        text.contains('how long should i sleep')   ||
        text.contains('sleep duration')            ||
        text.contains('enough sleep')              ||
        text.contains('too much sleep')            ||
        text.contains('oversleeping')              ||
        text.contains('8 hours')                   ||
        text.contains('7 hours')                   ||
        text.contains('9 hours')) {
      _consecutiveFallbacks = 0;
      final ack  = "Most adults need 7 to 9 hours a night.";
      final core = "Teens need more, around 8 to 10, and younger kids even more than that.";
      final bridge = _join("Quality matters as much as quantity",
          "7 hours of deep, uninterrupted sleep beats 9 fragmented hours.",
          type: 'contrast');
      await _speak('$ack $core $bridge');
      return;
    }

    // 4g. Sleep schedule / consistency (informational)
    if (text.contains('sleep schedule')              ||
        text.contains('sleep time')                  ||
        text.contains('consistent sleep')            ||
        text.contains('same sleep time')             ||
        text.contains('wake time')                   ||
        text.contains('bedtime routine')             ||
        text.contains('sleep routine')               ||
        text.contains('nighttime routine')           ||
        (text.contains('what time') && (text.contains('sleep') || text.contains('bed') || text.contains('wake'))) ||
        (text.contains('consistent') && (text.contains('sleep') || text.contains('bed') || text.contains('wake'))) ||
        (text.contains('same time') && (text.contains('sleep') || text.contains('bed') || text.contains('wake')))) {
      _consecutiveFallbacks = 0;
      final ack  = "Consistency is honestly the biggest lever for sleep quality.";
      final core = "Going to bed and waking at the same time every day, weekends included, trains your circadian rhythm to feel sleepy at the right time.";
      final bridge = _join(core,
          "work backwards from your wake time and build a 30-minute wind-down before it - dim lights, no screens, something calming.",
          type: 'addition');
      await _speak('$ack $bridge');
      return;
    }
    
    // ── 6. SYMPTOM / STATE intents ─────────────────────────────────────────
    // These use _hasWord() for short emotional keywords so that a bare word
    // like "tired" in "what is sleep" can never fire here if the question-form
    // pre-check above catches it first. For multi-word phrases, contains() is
    // still fine since there is no ambiguity.

    // 6a. Can't fall asleep / sleep onset
    if (text.contains('cannot fall asleep')    ||
        text.contains("can't fall asleep")     ||
        text.contains('trouble falling asleep')||
        text.contains('hard to fall asleep')   ||
        text.contains('falling asleep')        ||
        text.contains('cannot sleep')          ||
        text.contains("can't sleep")           ||
        text.contains('lying awake')           ||
        text.contains('wide awake')            ||
        text.contains('mind is racing')        ||
        text.contains('racing thoughts')       ||
        text.contains('thoughts keep me awake')) {

      _consecutiveFallbacks = 0;
      final prefix = _contextPrefix();
      final ack  = "Lying awake with a busy mind is genuinely one of the hardest things.";
      final tip1 = "Try 4-7-8 breathing: in for 4, hold for 7, out for 8.";
      final bridge = _join(tip1,
          "it activates your parasympathetic nervous system — your body's actual off switch.",
          type: 'elaboration');
      final extra = "Also try a body scan — lie still and work through each muscle from toes upward, releasing tension as you go.";
      await _speak('$prefix$ack $bridge $extra');
      return;
    }

    // 6b. Waking during the night
    if (text.contains('keep waking')          ||
        text.contains('wake up at night')     ||
        text.contains('waking up')            ||
        text.contains('wake in the middle')   ||
        text.contains('middle of the night')  ||
        text.contains('cannot stay asleep')   ||
        text.contains("can't stay asleep")    ||
        text.contains('sleep is broken')      ||
        text.contains('light sleeper')) {
      _consecutiveFallbacks = 0;
      final ack  = "Waking up mid-night is frustrating.";
      final core = "Keep your room around 18 degrees - your body temperature naturally drops during deep sleep.";
      final bridge = _join("Avoid alcohol too",
          "it fragments sleep in the second half of the night.",
          type: 'reason');
      final cta = "If you do wake up, skip the phone - the light makes it much harder to drift back off. Slow breathing and relaxing each muscle works better.";
      await _speak('$ack $core $bridge $cta');
      return;
    }

    // 6c. Feeling unrefreshed
    if (text.contains('unrefreshed')              ||
        text.contains('still tired')              ||
        _hasWord(text, 'groggy')                  ||
        text.contains('tired in the morning')     ||
        text.contains('wake up tired')            ||
        text.contains('not rested')               ||
        text.contains('exhausted in the morning') ||
        text.contains('sleep is not helping')     ||
        text.contains('sleep does not help')) {
      _consecutiveFallbacks = 0;
      final ack  = "Waking up tired even after a full night usually points to sleep quality, not just quantity.";
      final core = "A consistent wake time, even on weekends, anchors your internal clock.";
      final bridge = _join(core,
          "limiting caffeine after 2pm helps too, since it has about a 6-hour half-life.",
          type: 'addition');
      final tip = "Getting natural light within 30 minutes of waking also resets your rhythm for the next night.";
      await _speak('$ack $bridge $tip');
      return;
    }

    // 6d. Anxiety / stress affecting sleep
    if (_hasWord(text, 'anxious')      || _hasWord(text, 'anxiety')     ||
        _hasWord(text, 'stressed')     || _hasWord(text, 'stress')      ||
        _hasWord(text, 'worried')      || _hasWord(text, 'worry')       ||
        _hasWord(text, 'nervous')      || _hasWord(text, 'overthinking')||
        _hasWord(text, 'overthink')    || _hasWord(text, 'restless')    ||
        _hasWord(text, 'panicking')    || _hasWord(text, 'panic')) {
      _consecutiveFallbacks = 0;
      final prefix = _contextPrefix();
      final ack  = "That sounds exhausting — anxiety is one of the biggest reasons people can't switch off at night.";
      final core = "Try progressive muscle relaxation: starting from your toes, tense each muscle group for 5 seconds, then release.";
      final tip  = "Pair that with a consistent wind-down — warm shower, dim lights, slow breathing — and your nervous system learns it's safe to let go.";
      await _speak('$prefix$ack $core $tip');
      return;
    }

    // 6e. Feeling tired / sleepy RIGHT NOW
    // Uses _hasWord() so "what is sleep" or "sleep tips" never matches here.
    // Also guarded by NOT _isQuestion() as a secondary safety net.
    if (!_isQuestion(text) &&
        (_hasWord(text, 'tired')         ||
            _hasWord(text, 'sleepy')        ||
            _hasWord(text, 'drowsy')        ||
            _hasWord(text, 'exhausted')     ||
            text.contains('need to sleep') ||
            text.contains('ready for bed'))) {

      _consecutiveFallbacks = 0;
      final prefix = _contextPrefix();
      final ack  = "Sounds like your body's ready for rest — that's a good sign.";
      final core = "Head to bed now rather than pushing through it; that sleepy window can pass quickly.";
      final tip  = "Phone down, lights dim, and give yourself permission to actually sleep.";
      final extra = "If your mind starts racing, try 4-7-8 breathing until it settles.";
      await _speak('$prefix$ack $core $tip $extra');
      return;

    }

    // ── 7. TOPIC intents ───────────────────────────────────────────────────

    // 7a. Naps
    if (_hasWord(text, 'nap')          || text.contains('napping')       ||
        text.contains('afternoon sleep')|| text.contains('daytime sleep') ||
        text.contains('power nap')) {
      _consecutiveFallbacks = 0;
      final ack  = "Naps can actually help if you time them right.";
      final core = "The sweet spot is 10 to 20 minutes, before 3pm - long enough for a boost, short enough to skip deep sleep.";
      final bridge = _join(core,
          "needing naps over 30 minutes regularly often means your night sleep isn't enough.",
          type: 'contrast');
      await _speak('$ack $bridge');
      return;
    }

    // 7b. Screen time / blue light
    if (_hasWord(text, 'screen')              || _hasWord(text, 'phone')         ||
        text.contains('blue light')           || text.contains('social media')   ||
        text.contains('scrolling')            || _hasWord(text, 'laptop')        ||
        _hasWord(text, 'tablet')              || text.contains('tv before bed')  ||
        text.contains('television before bed')|| text.contains('watching before bed')) {
      _consecutiveFallbacks = 0;
      final ack  = "Screens before bed are genuinely one of the hardest habits to break.";
      final core = "Blue light blocks melatonin - the hormone that makes you feel sleepy.";
      final bridge = _join(core,
          "even 30 minutes off screens before bed makes a measurable difference.",
          type: 'reason');
      final cta = "Try switching to a book, light stretching, or a podcast instead.";
      await _speak('$ack $bridge $cta');
      return;
    }

    // 7c. Sleep environment / bedroom
    if (_hasWord(text, 'bedroom')          || text.contains('environment')      ||
        text.contains('room temperature')  || text.contains('too hot')          ||
        text.contains('too cold')          || _hasWord(text, 'noise')           ||
        _hasWord(text, 'noisy')            || text.contains('dark room')        ||
        text.contains('light in my room')  || _hasWord(text, 'mattress')        ||
        _hasWord(text, 'pillow')) {
      _consecutiveFallbacks = 0;
      final ack  = "Your bedroom setup matters more than people think.";
      final core = "The ideal room is cool, around 16 to 19 degrees, dark, and quiet - blackout curtains and white noise or earplugs help a lot.";
      final bridge = _join("Try to keep your bed for sleep only",
          "your brain builds a strong association between bed and sleep that way.",
          type: 'reason');
      await _speak('$ack $core $bridge');
      return;
    }

    // 7d. Caffeine / alcohol / food
    if (_hasWord(text, 'caffeine')            || _hasWord(text, 'coffee')          ||
        _hasWord(text, 'tea')                 || _hasWord(text, 'alcohol')         ||
        text.contains('drinking before bed')  ||
        text.contains('drinking alcohol')     ||
        text.contains('eating before bed')    ||
        text.contains('food before bed')      ||
        text.contains('late meal')            ||
        text.contains('snack before bed')) {
      _consecutiveFallbacks = 0;
      await _speak(
        'What you consume in the hours before bed matters a lot. '
            'Caffeine has a half-life of around 6 hours, so a coffee at 3pm still has half its effect at 9pm. '
            'Try to avoid caffeine after 2pm. '
            'Alcohol may help you fall asleep faster, but it significantly disrupts the second half of your sleep cycle, reducing deep and REM sleep. '
            'Avoid heavy meals within 2 to 3 hours of bedtime, as digestion can keep you awake.',
      );
      return;
    }

    // 7e. Exercise and sleep
    if (_hasWord(text, 'exercise')         || _hasWord(text, 'workout')         ||
        _hasWord(text, 'gym')              || text.contains('physical activity') ||
        _hasWord(text, 'running')          || _hasWord(text, 'sport')) {
      _consecutiveFallbacks = 0;
      final ack  = "Exercise is one of the best things you can do for sleep.";
      final core = "It deepens sleep and helps you fall asleep faster.";
      final bridge = _join("Timing matters though",
          "vigorous workouts within 2 hours of bed raise your heart rate and temperature, making it harder to wind down.",
          type: 'contrast');
      final tip = "Morning or early afternoon sessions tend to work best.";
      await _speak('$ack $core $bridge $tip');
      return;
    }

    // 7f. Melatonin / supplements
    if (_hasWord(text, 'melatonin')         || _hasWord(text, 'supplement')      ||
        text.contains('sleeping pill')       || text.contains('sleep aid')        ||
        text.contains('medication for sleep')|| _hasWord(text, 'valerian')        ||
        _hasWord(text, 'magnesium')) {
      _consecutiveFallbacks = 0;
      final ack  = "Melatonin is a hormone your body already makes when it gets dark.";
      final core = "A small dose, around 0.5 to 1 milligram, an hour before bed can help shift your timing - especially for jet lag or shift work.";
      final bridge = _join(core,
          "it's not a sedative, so it works best paired with good habits and a dark room.",
          type: 'contrast');
      final cta = "For any sleep meds or supplements, check with your doctor first.";
      await _speak('$ack $bridge $cta');
      return;
    }

    // 7g. Bedtime routine / wind down
    if (text.contains('wind down')                  ||
        text.contains('wind-down')                  ||
        text.contains('what should i do before bed')||
        text.contains('pre-sleep')                  ||
        text.contains('prepare for sleep')          ||
        text.contains('get ready for sleep')        ||
        text.contains('relax before bed')           ||
        text.contains('before bed routine')) {
      _consecutiveFallbacks = 0;
      final ack  = "A solid wind-down routine is one of the best things for sleep hygiene.";
      final core = "Dim the lights about an hour before bed to kick off melatonin production, then at 30 minutes out stop screens and switch to reading, stretching, or a warm shower.";
      final bridge = _join(core,
          "the warm shower trick works because the temperature drop afterward mimics the natural dip that triggers sleep.",
          type: 'elaboration');
      final tip = "At 10 minutes, jot down any worries, then get into bed and focus on slow breathing.";
      await _speak('$ack $bridge $tip');
      return;
    }

    // 7h. General tips / help
    if (text.contains('sleep tips')        || text.contains('help me sleep')    ||
        text.contains('improve my sleep')  || text.contains('sleep better')     ||
        text.contains('how to sleep')      || text.contains('what can i say')   ||
        text.contains('what can i ask')    || text.contains('features')         ||
        text.contains('what can you')      || text.contains('what do you')      ||
        text.contains('what else')         || text.contains('what should i ask')||
        _hasWord(text, 'help')) {
      _consecutiveFallbacks = 0;
      final ack  = "Happy to help - here's what I can talk about.";
      final core = "Bedtime routines, trouble falling asleep, screen time, naps, sleep duration, your sleep environment, caffeine and alcohol, exercise, or melatonin.";
      final cta  = "You can also say 'go back' to head home, or ask for Breathing Exercises, Mindfulness, or Mood Tracking. What sounds good?";
      await _speak('$ack $core $cta');
      return;
    }

    // ── 8. Fallback ────────────────────────────────────────────────────────
    statusLabel = 'Waiting for input';
    notifyListeners();

    _consecutiveFallbacks++;

    if (_consecutiveFallbacks > 2) {
      _consecutiveFallbacks = 0;
      const msg =
          "Sorry, I think the information is not present in my current database. "
          "Sorry, try another common question.";
      chatHistory.add(const SleepMessage(msg, isUser: false));
      notifyListeners();
      await ttsService.speak(msg);
      await ttsService.awaitCompletion();
    } else {
      const msg =
          "I am sorry, I didn't catch that. Could you please repeat the question? "
          "Try asking about sleep tips, bedtime routines, screen time, naps, or say 'help' to see everything I can do.";
      chatHistory.add(const SleepMessage(msg, isUser: false));
      notifyListeners();
      await ttsService.speak(
        "I am sorry, I didn't catch that. Could you please repeat the question?",
      );
      await ttsService.awaitCompletion();
    }
  }

  // ── Navigation helper ──────────────────────────────────────────────────────

  Future<void> _navigateTo(String route) async {
    if (_context == null || !_context!.mounted) return;
    Widget? page;
    String  msg  = '';
    switch (route) {
      case '/emergency':
        page = const EmergencySupportPage();
        msg  = 'Opening Emergency Support now.';
        break;
      case '/breathing':
        page = const BreathingExercisesPage();
        msg  = 'Opening Breathing Exercises for you now.';
        break;
      case '/mindfulness':
        page = const MindfulnessPage();
        msg  = 'Taking you to Mindfulness now.';
        break;
      case '/mood':
        page = const MoodTrackingPage();
        msg  = 'Opening Mood Tracking for you now.';
        break;
    }
    if (page != null) {
      chatHistory.add(SleepMessage(msg, isUser: false));
      notifyListeners();
      await ttsService.speak(msg);
      await ttsService.awaitCompletion();
      Navigator.push(_context!, MaterialPageRoute(builder: (_) => page!));
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    ttsService.stop();
    sttService.cancel();
    super.dispose();
  }
}

// ── Message model ──────────────────────────────────────────────────────────────

class SleepMessage {
  final String text;
  final bool   isUser;
  const SleepMessage(this.text, {required this.isUser});
}