class MindfulnessDetector {
  /// Scans the given text for keywords related to a specific mindfulness session.
  /// Returns the session ID if a match is found, otherwise null.
  /// 
  /// Note: "Body Scan" is specifically excluded here because it is handled by 
  /// BreathingDetector and routed to the Breathing Exercises page globally.
  static String? detectSessionIntent(String text) {
    final t = text.toLowerCase();
    
    // Mindful Observation
    if (t.contains('observation') || t.contains('mindful observation') || t.contains('observe')) {
      return 'mindful_observation';
    }
    
    // Loving Kindness
    if (t.contains('loving') || t.contains('kindness') || t.contains('compassion') || t.contains('love')) {
      return 'loving_kindness';
    }
    
    // Beginner Meditation
    if (t.contains('beginner') || (t.contains('start') && t.contains('meditation'))) {
      return 'beginner';
    }
    
    // Anxiety Reduction
    if (t.contains('anxiety') || t.contains('reduction') || t.contains('panic attack')) {
      return 'anxiety_reduction';
    }
    
    // Focus & Concentration
    if (t.contains('focus') || t.contains('concentration') || t.contains('attention')) {
      return 'focus_concentration';
    }
    
    // Gratitude Meditation
    if (t.contains('gratitude') || t.contains('thankful') || t.contains('blessings') || t.contains('thank')) {
      return 'gratitude';
    }
    
    return null;
  }
}
