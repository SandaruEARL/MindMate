import 'package:mindmate/core/constants/breathing_content.dart';

class BreathingDetector {
  /// Scans the given text for keywords related to a specific breathing exercise.
  /// Returns the exercise ID if a match is found, otherwise null.
  static String? detectExerciseIntent(String text) {
    final t = text.toLowerCase();
    
    // Box Breathing
    if (t.contains('box') || t.contains('square breathing') || t.contains('tactical breathing')) {
      return BreathingCorpus.idBox;
    }
    
    // 4-7-8 Breathing
    if (t.contains('4 7 8') || t.contains('four seven eight') || t.contains('478')) {
      return BreathingCorpus.id478;
    }
    
    // Deep Belly Breathing
    if (t.contains('deep') || t.contains('belly')) {
      return BreathingCorpus.idDeep;
    }
    
    // Body Scan Relaxation
    if (t.contains('body scan') || t.contains('scan relaxation') || t.contains('scan')) {
      return BreathingCorpus.idBodyScan;
    }
    
    return null;
  }
}
