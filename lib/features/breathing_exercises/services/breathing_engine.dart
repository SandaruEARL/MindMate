// services/breathing_engine.dart
// Riverpod state notifier for the breathing module.
// Wires BreathingFaqDetector output into UI state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_faq_corpus.dart';
import 'package:mindmate/features/breathing_exercises/services/breathing_faq_detector.dart';

// ════════════════════════════════════════════════════════════════
// 1. VUI STATE
// ════════════════════════════════════════════════════════════════

class BreathingVuiState {
  final String statusLabel;
  final String? exerciseIdToStart;
  final bool shouldStop;

  const BreathingVuiState({
    this.statusLabel = 'Tap the mic to choose an exercise',
    this.exerciseIdToStart,
    this.shouldStop = false,
  });

  BreathingVuiState copyWith({
    String? statusLabel,
    String? exerciseIdToStart,
    bool? shouldStop,
    bool clearAction = false,
  }) {
    return BreathingVuiState(
      statusLabel: statusLabel ?? this.statusLabel,
      exerciseIdToStart: clearAction
          ? null
          : (exerciseIdToStart ?? this.exerciseIdToStart),
      shouldStop: shouldStop ?? this.shouldStop,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 2. NOTIFIER
// ════════════════════════════════════════════════════════════════

class BreathingVuiNotifier extends StateNotifier<BreathingVuiState> {
  BreathingVuiNotifier() : super(const BreathingVuiState());

  void handleVoiceCommand(String rawText, {required bool isAnimating}) {
    if (rawText.trim().isEmpty) {
      state = state.copyWith(statusLabel: "I didn't catch that. Try again.");
      return;
    }

    final text = rawText.toLowerCase();

    // Stop command when exercise is running
    if (isAnimating &&
        (text.contains('stop') ||
            text.contains('cancel') ||
            text.contains('end') ||
            text.contains('quit'))) {
      state = BreathingVuiState(
        statusLabel: 'Exercise stopped.',
        shouldStop: true,
      );
      return;
    }

    // Run FAQ detector
    final response = BreathingFaqDetector.process(rawText);

    state = BreathingVuiState(
      statusLabel: response.suggestedExerciseId != null
          ? 'Starting ${_idToTitle(response.suggestedExerciseId!)}…'
          : response.message,
      exerciseIdToStart: response.suggestedExerciseId,
      shouldStop: false,
    );
  }

  void clearAction() {
    state = state.copyWith(clearAction: true, shouldStop: false);
  }

  void onExerciseComplete() {
    state = const BreathingVuiState(
      statusLabel: 'Tap the mic to choose an exercise',
    );
  }

  String _idToTitle(String id) {
    switch (id) {
      case BreathingFaqCorpus.idBox:
        return 'Box Breathing';
      case BreathingFaqCorpus.id478:
        return '4-7-8 Breathing';
      case BreathingFaqCorpus.idDeep:
        return 'Deep Belly Breathing';
      case BreathingFaqCorpus.idBodyScan:
        return 'Body Scan Relaxation';
      default:
        return id;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// 3. PROVIDERS
// ════════════════════════════════════════════════════════════════

final breathingVuiNotifierProvider =
    StateNotifierProvider<BreathingVuiNotifier, BreathingVuiState>(
      (_) => BreathingVuiNotifier(),
    );
