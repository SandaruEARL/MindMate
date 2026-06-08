// breathing_engine.dart
// Rule-based intent engine + Riverpod notifier for the breathing module.
// Mirrors sleep_engine.dart structure exactly for consistency.
//
// ARCHITECTURE:
//   BreathingEngine   — pure Dart, no Flutter, fully testable
//   BreathingVuiState — immutable UI state
//   BreathingVuiNotifier — StateNotifier wiring engine → UI
//
// The notifier exposes one method: handleVoiceCommand(String).
// The UI calls this with raw recognised speech; the notifier
// resolves intent, updates state, and sets exerciseId when a
// technique should start.

// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindmate/core/constants/breathing_content.dart';

// ════════════════════════════════════════════════════════════════
// 1. ENGINE  (pure Dart)
// ════════════════════════════════════════════════════════════════

class BreathingEngine {
  // ── Internal context ─────────────────────────────────────────
  BreathingIntent? _previousIntent;
  String _lastResponse = '';
  final List<BreathingIntentLog> _intentLog = [];

  // Public accessors for debug / testing
  List<BreathingIntentLog> get intentLog => List.unmodifiable(_intentLog);
  BreathingIntent? get previousIntent => _previousIntent;

  // ── Entry message (spoken on screen open) ────────────────────
  String get entryMessage =>
      'Welcome to Breathing Exercises. '
      'Say a technique name like Box Breathing or 4-7-8, '
      'or say "list exercises" to hear all options.';

  // ── Main entry point ─────────────────────────────────────────
  BreathingResponse process(String input) {
    final text = _normalise(input);

    // Empty input
    if (text.isEmpty) {
      return _static(
        "I didn't hear anything. Please tap the mic and speak clearly.",
        BreathingIntent.unknown,
      );
    }

    // 1. Semantic scoring — score every intent
    final scores = _scoreAllIntents(text);
    final topIntent = scores.keys.first;
    final topScore = scores[topIntent]!;
    final confidence = (topScore / 5.0).clamp(0.0, 1.0);

    // 2. Emotional tone
    final tone = _detectTone(text);

    // 3. Log
    _log(input, topIntent, confidence, tone);

    // 4. Meta-intents that need engine state
    if (topIntent == BreathingIntent.repeat) return _handleRepeat();
    if (topIntent == BreathingIntent.affirmation) return _handleAffirmation();
    if (topIntent == BreathingIntent.negation) return _handleNegation();

    // 5. Below confidence → unknown
    if (confidence < 0.1) {
      final msg = BreathingCorpus.pick(
        BreathingCorpus.responseMessages[BreathingIntent.unknown]!,
      );
      _lastResponse = msg;
      return BreathingResponse(
        intent: BreathingIntent.unknown,
        message: msg,
        confidence: confidence,
      );
    }

    // 6. Build response
    final response = _buildResponse(topIntent, tone, confidence);
    _previousIntent = topIntent;
    _lastResponse = response.message;
    return response;
  }

  bool isExit(String input) =>
      BreathingCorpus.exitKeywords.any((kw) => _normalise(input).contains(kw));

  // ── Normalisation ────────────────────────────────────────────
  String _normalise(String input) => input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  // ── Tone detection ───────────────────────────────────────────
  BreathingEmotionalTone _detectTone(String t) {
    int best = 0;
    BreathingEmotionalTone result = BreathingEmotionalTone.neutral;
    for (final e in BreathingCorpus.toneKeywords.entries) {
      final hits = e.value.where((kw) => t.contains(kw)).length;
      if (hits > best) {
        best = hits;
        result = e.key;
      }
    }
    return result;
  }

  // ── Semantic scoring ─────────────────────────────────────────
  Map<BreathingIntent, int> _scoreAllIntents(String t) {
    final scores = <BreathingIntent, int>{};
    for (final e in BreathingCorpus.intentKeywords.entries) {
      final hits = e.value.where((kw) => t.contains(kw)).length;
      if (hits > 0) scores[e.key] = hits;
    }
    if (scores.isEmpty) return {BreathingIntent.unknown: 0};
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  // ── Meta-intent handlers ─────────────────────────────────────

  BreathingResponse _handleRepeat() {
    if (_lastResponse.isEmpty) {
      return _static(
        "There's nothing to repeat yet. Say a technique name to begin.",
        BreathingIntent.repeat,
      );
    }
    return _static(_lastResponse, BreathingIntent.repeat);
  }

  BreathingResponse _handleAffirmation() {
    // If previous intent suggested an exercise, start it
    if (_previousIntent != null) {
      final id = BreathingCorpus.intentToExerciseId[_previousIntent];
      if (id != null) {
        final msg = BreathingCorpus.pick(
          BreathingCorpus.responseMessages[BreathingIntent.affirmation]!,
        );
        _lastResponse = msg;
        return BreathingResponse(
          intent: _previousIntent!,
          message: msg,
          exerciseId: id,
          confidence: 1.0,
        );
      }
    }
    final msg = BreathingCorpus.pick(
      BreathingCorpus.responseMessages[BreathingIntent.affirmation]!,
    );
    _lastResponse = msg;
    return _static(msg, BreathingIntent.affirmation);
  }

  BreathingResponse _handleNegation() {
    // Check if "stop" is in negation context — treat as BreathingIntent.stop
    final msg = BreathingCorpus.pick(
      BreathingCorpus.responseMessages[BreathingIntent.negation]!,
    );
    _lastResponse = msg;
    _previousIntent = null;
    return _static(msg, BreathingIntent.negation);
  }

  // ── Response builder ─────────────────────────────────────────
  BreathingResponse _buildResponse(
    BreathingIntent intent,
    BreathingEmotionalTone tone,
    double confidence,
  ) {
    // --- STOP intent: no exerciseId, shouldStop = true
    if (intent == BreathingIntent.stop) {
      final msg = BreathingCorpus.pick(
        BreathingCorpus.responseMessages[BreathingIntent.stop]!,
      );
      _lastResponse = msg;
      return BreathingResponse(
        intent: BreathingIntent.stop,
        message: msg,
        shouldStop: true,
        confidence: confidence,
      );
    }

    // --- Pick message
    final messages = BreathingCorpus.responseMessages[intent];
    String message = messages != null
        ? BreathingCorpus.pick(messages)
        : BreathingCorpus.pick(
            BreathingCorpus.responseMessages[BreathingIntent.unknown]!,
          );

    // Prepend tone prefix for emotional intents
    if (tone != BreathingEmotionalTone.neutral &&
        ![
          BreathingIntent.greeting,
          BreathingIntent.gratitude,
          BreathingIntent.help,
        ].contains(intent)) {
      final prefixes = BreathingCorpus.tonePrefixes[tone];
      if (prefixes != null) {
        message = BreathingCorpus.pick(prefixes) + message;
      }
    }

    // --- Resolve exerciseId
    // Direct selection intents → immediate start
    final exerciseId = BreathingCorpus.intentToExerciseId[intent];

    // --- Emotional intents suggest an exercise but ask confirmation
    // (exerciseId will be null; user says "yes" → affirmation handler starts it)
    // Store the emotional intent as previous so affirmation can resolve it.
    // For emotional intents, we map them to their recommended exercise intent:
    final recommendedIntent = _emotionalToRecommendedIntent(intent);
    if (recommendedIntent != null) {
      _previousIntent = recommendedIntent;
    }

    // --- Tips and suggestions
    final tips = BreathingCorpus.intentTips[intent];
    final suggestions = BreathingCorpus.followUpSuggestions[intent];

    _lastResponse = message;

    return BreathingResponse(
      intent: intent,
      message: message,
      tone: tone,
      exerciseId:
          exerciseId, // non-null only for startBox/start478/startDeep/startBodyScan
      tips: tips,
      suggestions: suggestions,
      confidence: confidence,
    );
  }

  /// Maps emotional intents to the exercise intent that should start
  /// if the user says "yes" afterward.
  BreathingIntent? _emotionalToRecommendedIntent(BreathingIntent intent) {
    switch (intent) {
      case BreathingIntent.anxious:
      case BreathingIntent.cantSleep:
      case BreathingIntent.panicAttack:
        return BreathingIntent.start478;
      case BreathingIntent.stressed:
        return BreathingIntent.startBox;
      case BreathingIntent.angry:
        return BreathingIntent.startDeep;
      default:
        return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────

  BreathingResponse _static(String message, BreathingIntent intent) {
    _lastResponse = message;
    return BreathingResponse(intent: intent, message: message, confidence: 1.0);
  }

  void _log(
    String input,
    BreathingIntent intent,
    double confidence,
    BreathingEmotionalTone tone,
  ) {
    final entry = BreathingIntentLog(
      input: input,
      intent: intent,
      confidence: confidence,
      tone: tone,
    );
    _intentLog.add(entry);
    print(entry.toString());
  }
}

// ════════════════════════════════════════════════════════════════
// 2. VUI STATE
// ════════════════════════════════════════════════════════════════

/// What the UI needs to know at any moment.
class BreathingVuiState {
  final String statusLabel;
  final List<BreathingTip>? tips;
  final List<String>? suggestions;

  // When non-null, the UI must start this exercise immediately.
  final String? exerciseIdToStart;

  // When true, the UI must stop the current exercise.
  final bool shouldStop;

  const BreathingVuiState({
    this.statusLabel = 'Tap the mic to choose an exercise',
    this.tips,
    this.suggestions,
    this.exerciseIdToStart,
    this.shouldStop = false,
  });

  BreathingVuiState copyWith({
    String? statusLabel,
    List<BreathingTip>? tips,
    List<String>? suggestions,
    String? exerciseIdToStart,
    bool? shouldStop,
    bool clearCards = false,
    bool clearAction = false,
  }) {
    return BreathingVuiState(
      statusLabel: statusLabel ?? this.statusLabel,
      tips: clearCards ? null : (tips ?? this.tips),
      suggestions: clearCards ? null : (suggestions ?? this.suggestions),
      exerciseIdToStart: clearAction
          ? null
          : (exerciseIdToStart ?? this.exerciseIdToStart),
      shouldStop: shouldStop ?? this.shouldStop,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 3. NOTIFIER
// ════════════════════════════════════════════════════════════════

/// Receives raw voice text from the UI and maps it to state changes.
/// The UI is responsible for actually starting/stopping exercises —
/// the notifier only resolves intent and sets flags.
class BreathingVuiNotifier extends StateNotifier<BreathingVuiState> {
  final BreathingEngine _engine;

  BreathingVuiNotifier(this._engine) : super(const BreathingVuiState());

  /// Call this with the raw recognised speech string.
  /// [isAnimating] — pass the current exercise-running state
  /// so the engine can handle stop commands correctly.
  void handleVoiceCommand(String rawText, {required bool isAnimating}) {
    if (rawText.trim().isEmpty) {
      state = state.copyWith(
        statusLabel: "I didn't catch that. Try again.",
        clearAction: true,
      );
      return;
    }

    // If an exercise is running, intercept stop before normal processing
    final normalised = rawText.toLowerCase();
    if (isAnimating &&
        (normalised.contains('stop') ||
            normalised.contains('cancel') ||
            normalised.contains('end') ||
            normalised.contains('quit'))) {
      state = state.copyWith(
        statusLabel: 'Exercise stopped.',
        shouldStop: true,
        clearCards: true,
        clearAction: true,
      );
      return;
    }

    // Normal engine processing
    final response = _engine.process(rawText);

    state = BreathingVuiState(
      statusLabel: response.exerciseId != null
          ? 'Starting ${_idToTitle(response.exerciseId!)}…'
          : _intentToStatus(response.intent, response.message),
      tips: response.tips,
      suggestions: response.suggestions,
      exerciseIdToStart: response.exerciseId,
      shouldStop: response.shouldStop,
    );
  }

  /// Call after the UI has consumed exerciseIdToStart or shouldStop
  /// to clear those one-shot flags.
  void clearAction() {
    state = state.copyWith(clearAction: true, shouldStop: false);
  }

  /// Call when the exercise finishes naturally.
  void onExerciseComplete() {
    state = state.copyWith(
      statusLabel: 'Tap the mic to choose an exercise',
      clearAction: true,
      clearCards: false,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _idToTitle(String id) {
    switch (id) {
      case BreathingCorpus.idBox:
        return 'Box Breathing';
      case BreathingCorpus.id478:
        return '4-7-8 Breathing';
      case BreathingCorpus.idDeep:
        return 'Deep Belly Breathing';
      case BreathingCorpus.idBodyScan:
        return 'Body Scan Relaxation';
      default:
        return id;
    }
  }

  String _intentToStatus(BreathingIntent intent, String fallback) {
    switch (intent) {
      case BreathingIntent.stop:
        return 'Exercise stopped.';
      case BreathingIntent.unknown:
        return 'Not recognised. Try a technique name.';
      case BreathingIntent.listExercises:
        return 'Tap the mic to choose an exercise';
      case BreathingIntent.help:
        return 'Tap the mic to choose an exercise';
      default:
        return 'Tap the mic to choose an exercise';
    }
  }
}

// ════════════════════════════════════════════════════════════════
// 4. PROVIDERS
// ════════════════════════════════════════════════════════════════

final breathingEngineProvider = Provider<BreathingEngine>(
  (_) => BreathingEngine(),
);

final breathingVuiNotifierProvider =
    StateNotifierProvider<BreathingVuiNotifier, BreathingVuiState>(
      (ref) => BreathingVuiNotifier(ref.read(breathingEngineProvider)),
    );
