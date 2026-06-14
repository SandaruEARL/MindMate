// services/breathing_detector.dart
// Detects which breathing exercise the user wants to start.
// Pure Dart — no Flutter imports.

import 'package:mindmate/features/breathing_exercises/services/breathing_faq_corpus.dart';

class BreathingDetector {
  BreathingDetector._();

  /// Returns an exercise ID if the text matches an exercise name, otherwise null.
  static String? detectExerciseIntent(String text) {
    final t = text.toLowerCase();

    if (t.contains('box') ||
        t.contains('square breathing') ||
        t.contains('tactical breathing')) {
      return BreathingFaqCorpus.idBox;
    }

    if (t.contains('4 7 8') ||
        t.contains('four seven eight') ||
        t.contains('478') ||
        t.contains('4-7-8')) {
      return BreathingFaqCorpus.id478;
    }

    if (t.contains('deep') || t.contains('belly')) {
      return BreathingFaqCorpus.idDeep;
    }

    if (t.contains('body scan') ||
        t.contains('scan relaxation') ||
        t.contains('body awareness')) {
      return BreathingFaqCorpus.idBodyScan;
    }

    return null;
  }
}
