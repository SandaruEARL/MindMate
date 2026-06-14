// services/breathing_faq_detector.dart
// Simple keyword-based FAQ detector. Pure Dart — no Flutter imports.

import 'package:mindmate/features/breathing_exercises/services/breathing_faq_corpus.dart';

class BreathingFaqDetector {
  BreathingFaqDetector._();

  static BreathingFaqResponse process(String rawInput) {
    final text = _normalise(rawInput);

    if (text.isEmpty) return _unknown();

    // Step 1: Emergency check — highest priority
    for (final kw in BreathingFaqCorpus.emergencyKeywords) {
      if (text.contains(kw)) {
        return BreathingFaqResponse(
          intent: BreathingFaqIntent.emergencyRedirect,
          message: BreathingFaqCorpus
              .faqAnswers[BreathingFaqIntent.emergencyRedirect]!,
          requiresEmergency: true,
          confidence: 1.0,
        );
      }
    }

    // Step 2: Score every intent by keyword hits
    // Longer phrases score higher because we add word count as weight
    BreathingFaqIntent? bestIntent;
    int bestScore = 0;

    for (final entry in BreathingFaqCorpus.faqKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          score += keyword.split(' ').length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestIntent = entry.key;
      }
    }

    // Step 3: Return result or fallback
    if (bestIntent == null || bestScore < 1) return _unknown();

    return BreathingFaqResponse(
      intent: bestIntent,
      message:
          BreathingFaqCorpus.faqAnswers[bestIntent] ??
          BreathingFaqCorpus.faqAnswers[BreathingFaqIntent.unknown]!,
      suggestedExerciseId:
          BreathingFaqCorpus.suggestionToExerciseId[bestIntent],
      confidence: (bestScore / 5.0).clamp(0.0, 1.0),
    );
  }

  static String _normalise(String input) => input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static BreathingFaqResponse _unknown() => BreathingFaqResponse(
    intent: BreathingFaqIntent.unknown,
    message: BreathingFaqCorpus.faqAnswers[BreathingFaqIntent.unknown]!,
    confidence: 0.0,
  );
}
