// sleep_engine.dart
// Rule-based engine + Riverpod notifier for the sleep VUI module.
//
// Fixes applied (cumulative):
//   Fix 1  — Turn history window
//   Fix 2  — Affirmation routing via _lastOfferedAction
//   Fix 4  — Shared Gemini/engine context via injectContext()
//   Fix 5  — Persistent emotional tone with decay
//   Fix 6  — Dynamic suggestions (no repeated chips)
//   Fix 8  — Meta-intents require ≥2 keyword hits (negation only now)
//   Fix 10 — STT retry loop with voice prompt
//   Fix 11 — Intake phase (age + issue type) — now fires after intro, not on first user message
//   Fix 13 — _parseIssueType returns null on no match
//   Fix 14 — await TTS completion before opening mic
//   Fix 15 — issueType attempt cap (max 1 miss → default)
//   Fix 16 — No hybrid enrichment: conf < threshold → full Gemini only
//   Fix 17 — greeting/help/gratitude override only fires on meta-intents
//   Fix 18 — Numeric single-word STT guard
//   Fix 19 — Improved _isSttLowQuality
//   Fix 20 — NAV_CONFIRM: Gemini handoff/crisis → confirmation ask first
//   Fix 21 — Pending nav shortcut in notifier bypasses scoring pipeline
//   Fix 22 — Only negation uses 2-hit meta guard; affirmation uses 1
//   Fix 23 — Intake begins immediately after intro TTS, not on first user message

// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/sleep_content.dart';
import 'gemini_service.dart';
import 'speech_to_text_service.dart';
import 'tts_service.dart';

// IntakePhase.pending is removed — intake is now driven by the notifier
// immediately after the intro message, so 'pending' is no longer needed.
enum IntakePhase { age, issueType, complete }

class _PendingNav {
  final String route;
  final String confirmMsg;
  _PendingNav({required this.route, required this.confirmMsg});
}

// ════════════════════════════════════════════════════════════════
// 1. ENGINE
// ════════════════════════════════════════════════════════════════

class SleepEngine {

  String get moduleId => 'sleep';

  String get entryMessage =>
      "I'm your sleep assistant. Ask me about bedtime routines, "
          "what to do if you can't sleep, screen time, naps, "
          "sleep duration, or general sleep tips.";

  String get exitMessage =>
      'Sweet dreams! Come back any time you need sleep support.';

  final List<IntentLog>   _intentLog   = [];
  final List<_TurnRecord> _turnHistory = [];

  static const int _kMaxContext = 5;

  SleepIntent? get previousIntent =>
      _turnHistory.isEmpty ? null : _turnHistory.last.intent;

  String get _lastResponse =>
      _turnHistory.isEmpty ? '' : _turnHistory.last.response;

  void _pushTurn({
    required SleepIntent  intent,
    required String       input,
    required String       response,
    EmotionalTone         tone = EmotionalTone.neutral,
  }) {
    _turnHistory.add(_TurnRecord(
      intent:   intent,
      input:    input,
      response: response,
      tone:     tone,
    ));
    if (_turnHistory.length > _kMaxContext) _turnHistory.removeAt(0);
  }

  String? _lastOfferedAction;
  int     _issueTypeAttempts = 0;
  static const _kMaxIssueTypeAttempts = 1;

  EmotionalTone _currentTone = EmotionalTone.neutral;
  double        _toneDecay   = 0.0;

  int?        userAge;
  String?     sleepIssueType;

  // Starts at 'age' — the notifier begins intake right after the intro.
  IntakePhase intakePhase = IntakePhase.age;

  _PendingNav? pendingNav;

  List<IntentLog> get intentLog => List.unmodifiable(_intentLog);

  // ── Confirmation helpers ──────────────────────────────────────

  static String confirmationFor(String route) {
    switch (route) {
      case '/emergency':
        return "It sounds like you might need immediate support. "
            "Would you like me to connect you to the Emergency Support module?";
      case '/breathing':
        return "Would you like me to take you to the Breathing Exercises module?";
      case '/mindfulness':
        return "Would you like me to open the Mindfulness module for you?";
      case '/mood':
        return "Would you like me to take you to the Mood Tracking module?";
      default:
        return "Would you like me to take you to another module?";
    }
  }

  static String navConfirmedMessage(String route) {
    switch (route) {
      case '/emergency':   return 'Connecting you to Emergency Support now. Please hold on.';
      case '/breathing':   return 'Opening Breathing Exercises for you now.';
      case '/mindfulness': return 'Taking you to Mindfulness now.';
      case '/mood':        return 'Opening Mood Tracking for you now.';
      default:             return 'Taking you there now.';
    }
  }

  static List<String> confirmationChips(String route) =>
      const ['Yes please', 'No thanks'];

  // ── Intake ────────────────────────────────────────────────────

  String intakeQuestion() {
    switch (intakePhase) {
      case IntakePhase.age:
        return "And what is your age (18-30)?";
      case IntakePhase.issueType:
        return "Got it. What's your main sleep problem - "
            "trouble falling asleep, waking during the night, "
            "or feeling unrefreshed in the morning?";
      case IntakePhase.complete:
        return '';
    }
  }

  /// Returns true while intake is still in progress (caller should not
  /// run the main engine for this turn).
  bool handleIntake(String input) {
    if (intakePhase == IntakePhase.complete) return false;

    final t = input.toLowerCase().trim();

    if (intakePhase == IntakePhase.age) {
      final age = _parseAge(t);
      if (age != null) {
        userAge     = age;
        intakePhase = IntakePhase.issueType;
      }
      // Even if age not parsed we stay on age phase — the notifier will
      // re-ask the question.
      return true;
    }

    if (intakePhase == IntakePhase.issueType) {
      final parsed = _parseIssueType(t);
      if (parsed != null) {
        sleepIssueType     = parsed;
        _issueTypeAttempts = 0;
        intakePhase        = IntakePhase.complete;
      } else {
        _issueTypeAttempts++;
        if (_issueTypeAttempts >= _kMaxIssueTypeAttempts) {
          sleepIssueType     = 'unrefreshing';
          _issueTypeAttempts = 0;
          intakePhase        = IntakePhase.complete;
        }
      }
      return true;
    }

    return false;
  }

  int? _parseAge(String t) {
    final match = RegExp(r'\b(1[89]|2[0-9]|30)\b').firstMatch(t);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  String? _parseIssueType(String t) {
    if (t.contains('fall')    || t.contains('onset')        ||
        t.contains('falling') || t.contains('cant sleep')   ||
        t.contains("can't sleep")) return 'onset';

    if (t.contains('wak')     || t.contains('middle')       ||
        t.contains('night')   || t.contains('keep waking')  ||
        t.contains('wake up')) return 'maintenance';

    if (t.contains('refresh') || t.contains('tired')        ||
        t.contains('groggy')  || t.contains('morning')      ||
        t.contains('unrefresh') || t.contains('rest'))       return 'unrefreshing';

    if (t.contains('frustrat') || t.contains('stress')      ||
        t.contains('anxious')  || t.contains('anxiety')     ||
        t.contains('worried')  || t.contains('worry')       ||
        t.contains('upset')    || t.contains('restless')    ||
        t.contains('hard')     || t.contains('difficult')   ||
        t.contains('problem')  || t.contains('issue'))       return 'onset';

    return null;
  }

  // ── Main entry point ──────────────────────────────────────────

  SleepResponse process(String input) {
    final text = _normalise(input);

    if (text.isEmpty) {
      return _staticResponse(
        "I didn't hear anything. Please tap the mic and speak clearly.",
        SleepIntent.unknown,
      );
    }

    // 1. Crisis
    if (_isCrisis(text)) {
      const msg = "It sounds like you might need immediate support. "
          "Would you like me to connect you to the Emergency Support module?";
      _log(input, SleepIntent.unknown, 1.0, EmotionalTone.neutral);
      _pushTurn(intent: SleepIntent.unknown, input: input, response: msg);
      pendingNav = _PendingNav(route: '/emergency', confirmMsg: msg);
      return SleepResponse(
        intent:      SleepIntent.unknown,
        message:     msg,
        suggestions: const ['Yes please', 'No thanks'],
        confidence:  1.0,
      );
    }

    // 2. Rule-based handoff
    final handoff = _checkHandoff(text);
    if (handoff != null) {
      final msg = confirmationFor(handoff);
      _log(input, SleepIntent.unknown, 1.0, EmotionalTone.neutral);
      _pushTurn(intent: SleepIntent.unknown, input: input, response: msg);
      pendingNav = _PendingNav(route: handoff, confirmMsg: msg);
      return SleepResponse(
        intent:      SleepIntent.unknown,
        message:     msg,
        suggestions: confirmationChips(handoff),
        confidence:  1.0,
      );
    }

    // 3. Tone
    final tone = _effectiveTone(_detectTone(text));

    // 4. Score intents
    final scores     = _scoreAllIntents(text);
    final topIntent  = scores.keys.first;
    final topScore   = scores[topIntent]!;
    final confidence = (topScore / 5.0).clamp(0.0, 1.0);

    _log(input, topIntent, confidence, tone);

    // 5. Meta-intents
    if (topIntent == SleepIntent.repeat)      return _handleRepeat(input);
    if (topIntent == SleepIntent.affirmation) return _handleAffirmation(input, tone);
    if (topIntent == SleepIntent.negation)    return _handleNegation(input);

    // 6. Greeting / gratitude / help
    if (const {
      SleepIntent.greeting,
      SleepIntent.gratitude,
      SleepIntent.help,
    }.contains(topIntent)) {
      // Check if a topic intent also scored — if so, let it win
      final topicIntents = scores.entries.where((e) =>
      !const {
        SleepIntent.greeting, SleepIntent.gratitude, SleepIntent.help,
        SleepIntent.repeat, SleepIntent.affirmation, SleepIntent.negation,
        SleepIntent.unknown,
      }.contains(e.key)
      );

      if (topicIntents.isNotEmpty) {
        // Re-route to the top topic intent instead
        final topTopic = topicIntents.first;
        final topicConfidence = (topTopic.value / 5.0).clamp(0.0, 1.0);
        if (topicConfidence >= 0.10) {
          final response = _buildRoutingSignal(topTopic.key, tone, topicConfidence);
          _pushTurn(intent: topTopic.key, input: input, response: response.message, tone: tone);
          return response;
        }
      }

      final msg = SleepCorpus.pick(SleepCorpus.responseVariants[topIntent]!);
      _pushTurn(intent: topIntent, input: input, response: msg, tone: tone);
      return SleepResponse(intent: topIntent, message: msg, confidence: 1.0);
    }

    // 7. Below threshold → Gemini
    if (confidence < 0.10) {
      return SleepResponse(
        intent:     SleepIntent.unknown,
        message:    '',
        confidence: confidence,
      );
    }

    // 8. Topic intent → routing signal
    final response = _buildRoutingSignal(topIntent, tone, confidence);
    _pushTurn(intent: topIntent, input: input,
        response: response.message, tone: tone);
    return response;
  }

  bool isDirectEntry(String input) => SleepCorpus.directEntryKeywords
      .any((kw) => _normalise(input).contains(kw));

  bool isExit(String input) => SleepCorpus.exitKeywords
      .any((kw) => _normalise(input).contains(kw));

  String _normalise(String input) => input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _isCrisis(String t) =>
      SleepCorpus.crisisKeywords.any((kw) => t.contains(kw));

  String? _checkHandoff(String t) {
    for (final e in SleepCorpus.handoffTriggers.entries) {
      if (e.value.any((kw) => t.contains(kw))) return e.key;
    }
    return null;
  }

  EmotionalTone _detectTone(String t) {
    int           best   = 0;
    EmotionalTone result = EmotionalTone.neutral;
    for (final e in SleepCorpus.toneKeywords.entries) {
      final hits = e.value.where((kw) => t.contains(kw)).length;
      if (hits > best) { best = hits; result = e.key; }
    }
    return result;
  }

  EmotionalTone _effectiveTone(EmotionalTone detectedTone) {
    if (detectedTone != EmotionalTone.neutral) {
      _currentTone = detectedTone;
      _toneDecay   = 0.0;
    } else {
      _toneDecay = (_toneDecay + 0.4).clamp(0.0, 1.0);
      if (_toneDecay >= 1.0) _currentTone = EmotionalTone.neutral;
    }
    return _currentTone;
  }

  // Fix 22: only negation uses the 2-hit guard
  static const _kMetaMinHits = 2;
  static const _kMetaIntents = {SleepIntent.negation};

  Map<SleepIntent, int> _scoreAllIntents(String t) {
    final scores = <SleepIntent, int>{};
    for (final e in SleepCorpus.intentKeywords.entries) {
      final hits = e.value.where((kw) => t.contains(kw)).length;
      if (hits == 0) continue;
      final effectiveHits =
      (_kMetaIntents.contains(e.key) && hits < _kMetaMinHits) ? 0 : hits;
      if (effectiveHits > 0) scores[e.key] = effectiveHits;
    }
    if (scores.isEmpty) return {SleepIntent.unknown: 0};
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  SleepResponse _handleRepeat(String input) {
    if (_lastResponse.isEmpty) {
      const msg = "There's nothing to repeat yet. Ask me something first.";
      _pushTurn(intent: SleepIntent.repeat, input: input, response: msg);
      return _staticResponse(msg, SleepIntent.repeat);
    }
    _pushTurn(intent: SleepIntent.repeat, input: input, response: _lastResponse);
    return _staticResponse(_lastResponse, SleepIntent.repeat);
  }

  SleepResponse _handleAffirmation(String input, EmotionalTone tone) {
    if (pendingNav != null) {
      final nav = pendingNav!;
      pendingNav = null;
      final msg = navConfirmedMessage(nav.route);
      _pushTurn(intent: SleepIntent.affirmation, input: input,
          response: msg, tone: tone);
      return SleepResponse(
        intent:       SleepIntent.unknown,
        message:      msg,
        handoffRoute: nav.route,
        confidence:   1.0,
      );
    }

    if (_lastOfferedAction != null) {
      final action = _lastOfferedAction!;
      _lastOfferedAction = null;

      if (action.toLowerCase().contains('breath')) {
        const msg = 'Great — taking you to the breathing exercise now.';
        _pushTurn(intent: SleepIntent.affirmation, input: input,
            response: msg, tone: tone);
        return SleepResponse(
          intent:       SleepIntent.unknown,
          message:      msg,
          handoffRoute: '/breathing',
          confidence:   1.0,
        );
      }
      if (action.toLowerCase().contains('medit')) {
        const msg = 'Perfect — opening the guided meditation.';
        _pushTurn(intent: SleepIntent.affirmation, input: input,
            response: msg, tone: tone);
        return SleepResponse(
          intent:       SleepIntent.unknown,
          message:      msg,
          handoffRoute: '/mindfulness',
          confidence:   1.0,
        );
      }
      if (action.toLowerCase().contains('routine')) {
        const msg = 'Here is your 30-minute wind-down routine.';
        _pushTurn(intent: SleepIntent.affirmation, input: input,
            response: msg, tone: tone);
        return SleepResponse(
          intent:       SleepIntent.bedtimeRoutine,
          message:      msg,
          routineSteps: SleepCorpus.bedtimeRoutineSteps,
          confidence:   1.0,
        );
      }
    }

    if (previousIntent != null) {
      final followUp = _buildFollowUp(previousIntent!);
      if (followUp != null) {
        _pushTurn(intent: SleepIntent.affirmation, input: input,
            response: followUp.message, tone: tone);
        return followUp;
      }
    }

    // Nothing for the engine to resolve — let Gemini honour its own offer.
    return SleepResponse(
      intent:     SleepIntent.affirmation,
      message:    '',
      confidence: 1.0,
    );
  }

  SleepResponse _handleNegation(String input) {
    if (pendingNav != null) {
      pendingNav = null;
      const msg = "No problem. I'm here whenever you need anything else.";
      _pushTurn(intent: SleepIntent.negation, input: input, response: msg);
      return _staticResponse(msg, SleepIntent.negation);
    }
    final msg = SleepCorpus.pick(
        SleepCorpus.responseVariants[SleepIntent.negation]!);
    _lastOfferedAction = null;
    _pushTurn(intent: SleepIntent.negation, input: input, response: msg);
    return _staticResponse(msg, SleepIntent.negation);
  }

  SleepResponse? _buildFollowUp(SleepIntent intent) {
    switch (intent) {
      case SleepIntent.cantSleep:
        return SleepResponse(
          intent:      SleepIntent.cantSleep,
          message:     'Would you like to try a breathing exercise? '
              'It can help calm your nervous system right now.',
          suggestions: const ['Yes, try breathing', 'Give me more tips', 'No thanks'],
          confidence:  1.0,
        );
      case SleepIntent.stressed:
        return SleepResponse(
          intent:      SleepIntent.stressed,
          message:     "Since you're still stressed, I can walk you through "
              'box breathing or take you to the breathing module. '
              'Which would you prefer?',
          suggestions: const ['Box breathing', 'Breathing module', 'Something else'],
          confidence:  1.0,
        );
      default:
        return null;
    }
  }

  SleepResponse _buildRoutingSignal(
      SleepIntent intent, EmotionalTone tone, double confidence) {

    if (intent == SleepIntent.bedtimeRoutine) {
      const msg = "Here's a simple 30-minute wind-down plan for tonight.";
      final suggestions = _dynamicSuggestions(intent);
      if (suggestions.isNotEmpty) _lastOfferedAction = suggestions.first;
      return SleepResponse(
        intent:       intent,
        message:      msg,
        tone:         tone,
        routineSteps: SleepCorpus.bedtimeRoutineSteps,
        suggestions:  suggestions.isEmpty ? null : suggestions,
        confidence:   confidence,
      );
    }

    final suggestions = _dynamicSuggestions(intent);
    if (suggestions.isNotEmpty) _lastOfferedAction = suggestions.first;
    return SleepResponse(
      intent:      intent,
      message:     '',
      tone:        tone,
      suggestions: suggestions.isEmpty ? null : suggestions,
      confidence:  confidence,
    );
  }

  static final Map<String, SleepIntent> _suggestionIntentMap = {
    'Yes, try breathing' : SleepIntent.cantSleep,
    'Give me more tips'  : SleepIntent.cantSleep,
    'No thanks'          : SleepIntent.negation,
    'Box breathing'      : SleepIntent.stressed,
    'Breathing module'   : SleepIntent.stressed,
    'Something else'     : SleepIntent.unknown,
    'Bedtime routine'    : SleepIntent.bedtimeRoutine,
    'Sleep duration'     : SleepIntent.sleepDuration,
    'Screen time tips'   : SleepIntent.screenTime,
    'Nap advice'         : SleepIntent.nap,
    'General sleep tips' : SleepIntent.sleepTips,
  };

  List<String> _dynamicSuggestions(SleepIntent intent) {
    final base = SleepCorpus.followUpSuggestions[intent];
    if (base == null || base.isEmpty) return const [];
    final recentIntents = _turnHistory.map((t) => t.intent).toSet();
    final filtered = base.where((s) {
      final mappedIntent = _suggestionIntentMap[s];
      if (mappedIntent == null) return true;
      return !recentIntents.contains(mappedIntent);
    }).toList();
    return (filtered.length >= 2 ? filtered : base).take(3).toList();
  }

  SleepResponse _staticResponse(String message, SleepIntent intent) =>
      SleepResponse(intent: intent, message: message, confidence: 1.0);

  String handoffMessage(String route) => navConfirmedMessage(route);

  void _log(String input, SleepIntent intent, double conf, EmotionalTone tone) {
    final entry = IntentLog(
        input: input, intent: intent, confidence: conf, tone: tone);
    if (_intentLog.length >= 50) _intentLog.removeAt(0);
    _intentLog.add(entry);
    print(entry.toString());
  }

  void reset() {
    _turnHistory.clear();
    _lastOfferedAction = null;
    _currentTone       = EmotionalTone.neutral;
    _toneDecay         = 0.0;
    _intentLog.clear();
    userAge            = null;
    sleepIssueType     = null;
    intakePhase        = IntakePhase.age;   // ready for immediate intake
    _issueTypeAttempts = 0;
    pendingNav         = null;
  }
}

// ════════════════════════════════════════════════════════════════
// SUPPORT
// ════════════════════════════════════════════════════════════════

class _TurnRecord {
  final SleepIntent   intent;
  final String        input;
  final String        response;
  final EmotionalTone tone;
  const _TurnRecord({
    required this.intent,
    required this.input,
    required this.response,
    required this.tone,
  });
}

extension SleepResponseCopyWith on SleepResponse {
  SleepResponse copyWith({
    SleepIntent?    intent,
    String?         message,
    EmotionalTone?  tone,
    List<SleepTip>? tips,
    List<String>?   routineSteps,
    List<String>?   suggestions,
    double?         confidence,
    bool?           isCrisis,
    String?         handoffRoute,
  }) {
    return SleepResponse(
      intent:       intent       ?? this.intent,
      message:      message      ?? this.message,
      tone:         tone         ?? this.tone,
      tips:         tips         ?? this.tips,
      routineSteps: routineSteps ?? this.routineSteps,
      suggestions:  suggestions  ?? this.suggestions,
      confidence:   confidence   ?? this.confidence,
      isCrisis:     isCrisis     ?? this.isCrisis,
      handoffRoute: handoffRoute ?? this.handoffRoute,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 2. VUI STATE
// ════════════════════════════════════════════════════════════════

enum SleepVuiStatus { idle, listening, processing, speaking, error }

class SleepVuiState {
  final SleepVuiStatus    status;
  final List<ChatMessage> history;
  final List<SleepTip>?   tips;
  final List<String>?     routineSteps;
  final List<String>?     suggestions;
  final String?           errorMessage;
  final bool              hasMicPermission;
  final String?           pendingRoute;
  final SleepIntent?      lastIntent;
  final double            lastConfidence;
  final bool              shouldExit;

  const SleepVuiState({
    this.status           = SleepVuiStatus.idle,
    this.history          = const [],
    this.tips,
    this.routineSteps,
    this.suggestions,
    this.errorMessage,
    this.hasMicPermission = false,
    this.pendingRoute,
    this.lastIntent,
    this.lastConfidence   = 0.0,
    this.shouldExit       = false,
  });

  SleepVuiState copyWith({
    SleepVuiStatus?    status,
    List<ChatMessage>? history,
    List<SleepTip>?    tips,
    List<String>?      routineSteps,
    List<String>?      suggestions,
    String?            errorMessage,
    bool?              hasMicPermission,
    String?            pendingRoute,
    SleepIntent?       lastIntent,
    double?            lastConfidence,
    bool               clearCards = false,
    bool               clearRoute = false,
    bool?              shouldExit,
  }) {
    return SleepVuiState(
      status:           status           ?? this.status,
      history:          history          ?? this.history,
      tips:             clearCards ? null : (tips         ?? this.tips),
      routineSteps:     clearCards ? null : (routineSteps ?? this.routineSteps),
      suggestions:      clearCards ? null : (suggestions  ?? this.suggestions),
      errorMessage:     errorMessage     ?? this.errorMessage,
      hasMicPermission: hasMicPermission ?? this.hasMicPermission,
      pendingRoute:     clearRoute ? null : (pendingRoute ?? this.pendingRoute),
      lastIntent:       lastIntent       ?? this.lastIntent,
      lastConfidence:   lastConfidence   ?? this.lastConfidence,
      shouldExit:       shouldExit       ?? this.shouldExit,
    );
  }

  SleepVuiState withMessage(ChatMessage msg) =>
      copyWith(history: [...history, msg]);
}

// ════════════════════════════════════════════════════════════════
// 3. NOTIFIER
// ════════════════════════════════════════════════════════════════

class SleepVuiNotifier extends StateNotifier<SleepVuiState> {
  final SleepEngine         _engine;
  final SpeechToTextService _stt;
  final GeminiService       _gemini;
  final TtsService          _tts;

  SleepVuiNotifier(this._engine, this._stt, this._gemini, this._tts)
      : super(const SleepVuiState()) {
    _init();
  }

  // ── Startup: intro → immediate intake ────────────────────────

  Future<void> _init() async {
    _engine.reset();
    _gemini.resetHistory();

    _engine.intakePhase = IntakePhase.complete;

    state = const SleepVuiState();

    try { await _stt.forceReset(); } catch (_) {}

    final micStatus = await Permission.microphone.status;
    state = state.copyWith(hasMicPermission: micStatus.isGranted);

    try {
      await _tts.initialise();
    } catch (_) {}

    state = state.copyWith(status: SleepVuiStatus.idle);

    injectWelcomeMessage(
      'Ask any question related to sleep hygiene, bedtime routines',
    );

    try {
      await _tts.speak('Ask any question related to sleep hygiene, bedtime routines');
    } catch (_) {}

  }

  void injectWelcomeMessage(String text) {
    state = state.withMessage(ChatMessage(isUser: false, text: text));
  }


  // ── Voice turn ────────────────────────────────────────────────

  Future<void> startVoiceTurn() async {
    if (!state.hasMicPermission) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        state = state.copyWith(
          status:       SleepVuiStatus.error,
          errorMessage: 'Microphone permission is required for voice input.',
        );
        return;
      }
      state = state.copyWith(hasMicPermission: true);
    }

    await _tts.stop();
    await _tts.awaitCompletion();
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(status: SleepVuiStatus.listening, errorMessage: null);

    String userText;
    try {
      userText = await _stt.listen();
    } catch (e) {
      state = state.copyWith(
        status:       SleepVuiStatus.error,
        errorMessage: e.toString().replaceFirst('SpeechException: ', ''),
      );
      return;
    }

    if (_isSttLowQuality(userText)) {
      state = state.copyWith(status: SleepVuiStatus.speaking, errorMessage: null);
      await _tts.speak("Sorry, I didn't understand that. Please say it again.");
      state = state.copyWith(status: SleepVuiStatus.listening);
      try {
        userText = await _stt.listen();
      } catch (e) {
        state = state.copyWith(
          status:       SleepVuiStatus.error,
          errorMessage: 'Microphone error. Please tap the mic to try again.',
        );
        return;
      }
      if (_isSttLowQuality(userText)) {
        state = state.copyWith(status: SleepVuiStatus.speaking);
        await _tts.speak(
            "I'm having trouble hearing you. Please try again later.");
        state = state.copyWith(status: SleepVuiStatus.idle);
        return;
      }
    }

    await _handleInput(userText, isVoice: true);
  }

  static const _sttWhitelist = {
    'hi', 'hey', 'hello', 'howdy', 'sup',
    'yes', 'yeah', 'yep', 'yup', 'sure', 'ok', 'okay', 'alright',
    'fine', 'great', 'perfect', 'definitely', 'absolutely', 'please',
    'no', 'nope', 'nah', 'stop', 'cancel', 'never',
    'repeat', 'again', 'help', 'exit', 'bye', 'thanks', 'thank',
    'continue', 'go', 'back', 'quit', 'done',
  };

  static const _sttJunkPhrases = {
    // question fragments
    'what is', 'what are', 'what was', 'what were', 'what the',
    'what do', 'what does', 'what did', 'what if', 'what about',
    'how is', 'how are', 'how was', 'how do', 'how does',
    'how did', 'how come', 'why is', 'why are', 'why do',
    'why does', 'who is', 'who are', 'who was', 'where is',
    'where are', 'when is', 'when are', 'can you', 'could you',
    'would you', 'should i', 'can i', 'do i', 'is it',
    'is there', 'are you', 'are there',

    // filler/incomplete
    'i mean', 'i think', 'i know', 'i dont', 'i don',
    'i do', 'i just', 'i was', 'i am', 'i want',
    'it is', 'it was', 'it the', 'so i', 'so um',
    'so uh', 'like um', 'like uh', 'like i', 'like the',
    'you know', 'you see', 'um okay', 'uh okay', 'um so',
    'uh so', 'well i', 'well um', 'well uh', 'okay so',
    'okay um', 'just um', 'just uh', 'just a', 'just the',
    'kind of', 'sort of', 'a bit', 'a lot', 'a little',
    'the um', 'the uh', 'and um', 'and uh', 'but um',
    'but uh', 'or um', 'or uh',
  };

  bool _isSttLowQuality(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    if (_sttJunkPhrases.contains(trimmed)) return true;
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    if (wordCount >= 2) return false;
    if (_sttWhitelist.contains(trimmed)) return false;
    if (int.tryParse(trimmed) != null) return false;
    return true;
  }

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _handleInput(text.trim(), isVoice: false);
  }

  Future<void> sendSuggestion(String suggestion) async =>
      sendTextMessage(suggestion);

  Future<void> stopListening() async {
    await _stt.cancel();   // forceful abort, clears stale listeners
    state = state.copyWith(status: SleepVuiStatus.idle);
  }

  void clearPendingRoute() => state = state.copyWith(clearRoute: true);

  // ── Core input handler ────────────────────────────────────────

  Future<void> _handleInput(String input, {required bool isVoice}) async {

    if (state.shouldExit) state = state.copyWith(shouldExit: false);

    if (_engine.isExit(input)) {
      final msg = _engine.exitMessage;
      state = state
          .withMessage(ChatMessage(isUser: true, text: input))
          .withMessage(ChatMessage(isUser: false, text: msg))
          .copyWith(status: SleepVuiStatus.speaking);
      if (isVoice) await _tts.speak(msg);
      state = state.copyWith(status: SleepVuiStatus.idle, shouldExit: true);
      return;
    }

    state = state
        .withMessage(ChatMessage(isUser: true, text: input))
        .copyWith(status: SleepVuiStatus.processing, clearCards: true);

    // ── Intake (age → issueType → complete) ────────────────────
    if (_engine.intakePhase != IntakePhase.complete) {
      _engine.handleIntake(input);

      if (_engine.intakePhase == IntakePhase.complete) {
        _gemini.setUserContext(_engine.userAge, _engine.sleepIssueType);

      } else {
        return;
      }
    }

    // ── Fix 21: pending nav shortcut ───────────────────────────
    if (_engine.pendingNav != null) {
      final t     = input.trim().toLowerCase();
      final isYes = t.contains('yes')     || t.contains('yeah')   ||
          t.contains('sure')    || t.contains('ok')     ||
          t.contains('okay')    || t.contains('please')  ||
          t.contains('yep')     || t.contains('yup')    ||
          t.contains('alright') || t.contains('fine');
      final isNo  = t.contains('no')      || t.contains('nah')    ||
          t.contains('nope')    || t.contains('cancel')  ||
          t.contains('don\'t')  || t.contains('dont');

      if (isYes || isNo) {
        final nav = _engine.pendingNav!;
        _engine.pendingNav = null;

        if (isYes) {
          final msg = SleepEngine.navConfirmedMessage(nav.route);
          final response = SleepResponse(
            intent:       SleepIntent.unknown,
            message:      msg,
            handoffRoute: nav.route,
            confidence:   1.0,
          );
          await _executeHandoff(response, isVoice: isVoice);
        } else {
          const msg = "No problem. I'm here whenever you need anything else.";
          state = state
              .withMessage(ChatMessage(isUser: false, text: msg))
              .copyWith(status: SleepVuiStatus.speaking);
          if (isVoice) await _tts.speak(msg);
          state = state.copyWith(status: SleepVuiStatus.idle);
        }
        return;
      }
    }

    // ── Engine pre-filter ───────────────────────────────────────
    SleepResponse engineResponse = _engine.process(input);

    if (_engine.userAge != null) {
      _gemini.setUserContext(_engine.userAge, _engine.sleepIssueType);
    }

    // Engine set a new pendingNav (crisis or rule-based handoff)
    if (_engine.pendingNav != null && engineResponse.handoffRoute == null) {
      final msg = engineResponse.message;
      state = state
          .withMessage(ChatMessage(
        isUser:     false,
        text:       msg,
        intent:     engineResponse.intent,
        confidence: engineResponse.confidence,
      ))
          .copyWith(
        status:      SleepVuiStatus.speaking,
        suggestions: engineResponse.suggestions,
      );
      if (isVoice) await _tts.speak(msg);
      state = state.copyWith(status: SleepVuiStatus.idle);
      return;
    }

    // Confirmed handoff from engine affirmation path
    if (engineResponse.handoffRoute != null) {
      await _executeHandoff(engineResponse, isVoice: isVoice);
      return;
    }

    // Engine owns this response (meta-intents + routine)
    final engineOwnsResponse = engineResponse.message.isNotEmpty &&
        (engineResponse.routineSteps != null ||
            const {
              SleepIntent.repeat,
              SleepIntent.affirmation,
              SleepIntent.negation,
              SleepIntent.greeting,
              SleepIntent.gratitude,
              SleepIntent.help,
            }.contains(engineResponse.intent));

    if (engineOwnsResponse) {
      _gemini.injectContext(
        userMessage:    input,
        assistantReply: engineResponse.message,
      );
    } else {
      // Full Gemini — yield one frame so processing status renders the pill
      state = state.copyWith(status: SleepVuiStatus.processing);
      await Future.delayed(const Duration(milliseconds: 32));
      final geminiReply = await _gemini.chat(input);

      if (geminiReply == 'CRISIS') {
        const route = '/emergency';
        const msg   = "It sounds like you might need immediate support. "
            "Would you like me to connect you to the Emergency Support module?";
        _engine.pendingNav = _PendingNav(route: route, confirmMsg: msg);
        state = state
            .withMessage(ChatMessage(isUser: false, text: msg))
            .copyWith(
          status:      SleepVuiStatus.speaking,
          suggestions: const ['Yes please', 'No thanks'],
        );
        if (isVoice) await _tts.speak(msg);
        state = state.copyWith(status: SleepVuiStatus.idle);
        return;

      } else if (geminiReply.startsWith('HANDOFF:')) {
        final route = geminiReply.replaceFirst('HANDOFF:', '');
        final msg   = SleepEngine.confirmationFor(route);
        _engine.pendingNav = _PendingNav(route: route, confirmMsg: msg);
        state = state
            .withMessage(ChatMessage(isUser: false, text: msg))
            .copyWith(
          status:      SleepVuiStatus.speaking,
          suggestions: SleepEngine.confirmationChips(route),
        );
        if (isVoice) await _tts.speak(msg);
        state = state.copyWith(status: SleepVuiStatus.idle);
        return;

      } else {
        engineResponse = engineResponse.copyWith(message: geminiReply);
      }
    }

    // Normal response
    state = state
        .withMessage(ChatMessage(
      isUser:     false,
      text:       engineResponse.message,
      intent:     engineResponse.intent,
      confidence: engineResponse.confidence,
    ))
        .copyWith(
      status:         SleepVuiStatus.speaking,
      tips:           engineResponse.tips,
      routineSteps:   engineResponse.routineSteps,
      suggestions:    engineResponse.suggestions,
      lastIntent:     engineResponse.intent,
      lastConfidence: engineResponse.confidence,
    );

    if (isVoice) await _tts.speak(engineResponse.message);
    state = state.copyWith(status: SleepVuiStatus.idle);
  }

  Future<void> _executeHandoff(
      SleepResponse response, {required bool isVoice}) async {
    final msg = response.message.isNotEmpty
        ? response.message
        : 'Taking you there now.';

    print('[NAV] executeHandoff → ${response.handoffRoute} "$msg"');

    state = state
        .withMessage(ChatMessage(
      isUser:     false,
      text:       msg,
      intent:     response.intent,
      confidence: response.confidence,
    ))
        .copyWith(
      status:     SleepVuiStatus.speaking,
      clearCards: true,
    );

    if (isVoice) await _tts.speak(msg);

    // Set pendingRoute AFTER speaking so ref.listen fires on a clean frame
    state = state.copyWith(
      status:       SleepVuiStatus.idle,
      pendingRoute: response.handoffRoute,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 4. PROVIDERS
// ════════════════════════════════════════════════════════════════

final speechToTextServiceProvider =
Provider<SpeechToTextService>((_) => SpeechToTextService());

final ttsServiceProvider =
Provider<TtsService>((_) => TtsService());

final sleepEngineProvider =
Provider<SleepEngine>((_) => SleepEngine());

final geminiServiceProvider =
Provider<GeminiService>((_) => GeminiService());

final sleepVuiNotifierProvider =
StateNotifierProvider<SleepVuiNotifier, SleepVuiState>(
      (ref) => SleepVuiNotifier(
    ref.read(sleepEngineProvider),
    ref.read(speechToTextServiceProvider),
    ref.read(geminiServiceProvider),
    ref.read(ttsServiceProvider),
  ),
);