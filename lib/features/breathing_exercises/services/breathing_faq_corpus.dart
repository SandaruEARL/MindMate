// services/breathing_faq_corpus.dart
// Corpus: all types, keyword lists, and answers for the breathing FAQ layer.
// Pure Dart — no Flutter imports.

// ════════════════════════════════════════════════════════════════
// 1. TYPES
// ════════════════════════════════════════════════════════════════

enum BreathingFaqIntent {
  whatIsBreathing,
  mentalHealthBenefits,
  whatIsGuidedRelaxation,
  howOften,
  anxietyPanic,
  suggestForStress,
  suggestForAnxiety,
  suggestForSleep,
  suggestForAnger,
  suggestForPanic,
  emergencyRedirect,
  unknown,
}

class BreathingFaqResponse {
  final BreathingFaqIntent intent;
  final String message;
  final String? suggestedExerciseId;
  final bool requiresEmergency;
  final double confidence;

  const BreathingFaqResponse({
    required this.intent,
    required this.message,
    this.suggestedExerciseId,
    this.requiresEmergency = false,
    this.confidence = 1.0,
  });
}

// ════════════════════════════════════════════════════════════════
// 2. CORPUS
// ════════════════════════════════════════════════════════════════

class BreathingFaqCorpus {
  BreathingFaqCorpus._();

  // ── Exercise IDs ──────────────────────────────────────────────
  static const String idBox = 'box';
  static const String id478 = '478';
  static const String idDeep = 'deep';
  static const String idBodyScan = 'body_scan';

  // ── Emergency keywords ────────────────────────────────────────
  static const List<String> emergencyKeywords = [
    'suicid',
    'kill myself',
    'end my life',
    'want to die',
    'self harm',
    'hurt myself',
    'cutting',
    'overdose',
    'heart attack',
    'chest pain',
    'choking',
    'collapsing',
    'passing out',
    'crisis',
    'help me now',
    'call',
    '119',
    '1990',
    'ambulance',
  ];

  // ── FAQ keyword map ───────────────────────────────────────────
  static const Map<BreathingFaqIntent, List<String>> faqKeywords = {
    BreathingFaqIntent.whatIsBreathing: [
      'what are breathing exercises',
      'what is breathing exercise',
      'what is a breathing exercise',
      'define breathing exercise',
      'explain breathing exercise',
      'tell me about breathing exercises',
      'what is breathing technique',
      'what are breathing techniques',
      'how do breathing exercises work',
      'what is breathing',
    ],

    BreathingFaqIntent.mentalHealthBenefits: [
      'how do breathing exercises help mental health',
      'breathing and mental health',
      'breathing for mental health',
      'mental health benefits of breathing',
      'how does breathing help',
      'breathing exercise benefit',
      'why do breathing exercises help',
      'what do breathing exercises do',
      'breathing improve mental',
      'why is breathing good for you',
      'does breathing help depression',
      'does it help my mind',
    ],

    BreathingFaqIntent.whatIsGuidedRelaxation: [
      'what is guided relaxation',
      'what is guided meditation',
      'explain guided relaxation',
      'tell me about guided relaxation',
      'what is relaxation technique',
      'what are relaxation techniques',
      'how does guided relaxation work',
    ],

    BreathingFaqIntent.howOften: [
      'how often should i practice',
      'how often should i do breathing',
      'how many times a day',
      'how frequently',
      'daily practice',
      'how long should i practice',
      'how many minutes',
      'regular practice',
      'how often',
    ],

    BreathingFaqIntent.anxietyPanic: [
      'can breathing exercises help during anxiety',
      'can breathing help anxiety',
      'breathing for anxiety',
      'breathing for panic',
      'breathing during anxiety',
      'anxiety attack breathing',
      'panic attack breathing',
      'breathing help with panic',
      'breathing help with anxiety',
      'anxiety relief breathing',
      'help with anxiety',
      'help with panic',
    ],

    BreathingFaqIntent.suggestForStress: [
      'i am stressed',
      'i\'m stressed',
      'feeling stressed',
      'stressed out',
      'stress relief',
      'help me with stress',
      'need to relax',
      'can\'t relax',
      'help me calm down',
      'calm me down',
      'i feel tense',
      'wound up',
    ],

    BreathingFaqIntent.suggestForAnxiety: [
      'i am anxious',
      'i\'m anxious',
      'feeling anxious',
      'i have anxiety',
      'really anxious',
      'heart is racing',
      'my heart is racing',
      'chest feels tight',
      'i feel nervous',
      'i can\'t stop worrying',
    ],

    BreathingFaqIntent.suggestForSleep: [
      'can\'t sleep',
      'cant sleep',
      'cannot sleep',
      'trouble sleeping',
      'lying awake',
      'wide awake',
      'insomnia',
      'sleepless',
      'can\'t fall asleep',
      'help me sleep',
      'racing thoughts at night',
    ],

    BreathingFaqIntent.suggestForAnger: [
      'i am angry',
      'i\'m angry',
      'feeling angry',
      'so angry',
      'furious',
      'i am mad',
      'i\'m mad',
      'i feel irritated',
      'can\'t control anger',
      'losing my temper',
    ],

    BreathingFaqIntent.suggestForPanic: [
      'panic attack',
      'having a panic attack',
      'i\'m having a panic attack',
      'hyperventilating',
      'breathing too fast',
      'can\'t catch my breath',
      'short of breath',
      'gasping',
      'feel like dying',
    ],
  };

  // ── FAQ answers ───────────────────────────────────────────────
  static const Map<BreathingFaqIntent, String> faqAnswers = {
    BreathingFaqIntent.whatIsBreathing:
        'Breathing exercises are simple techniques that help you control and '
        'slow down your breathing. They reduce stress, improve focus, and help '
        'you feel calmer. Techniques like Box Breathing and 4-7-8 give your '
        'body a structured way to activate its natural relaxation response.',

    BreathingFaqIntent.mentalHealthBenefits:
        'Breathing exercises calm your nervous system directly. When you breathe '
        'slowly and deliberately, your heart rate drops, cortisol levels fall, '
        'and your body shifts into a calmer state. '
        'Regular practice can reduce anxiety, lift mood, and help you feel more '
        'in control of your emotions.',

    BreathingFaqIntent.whatIsGuidedRelaxation:
        'Guided relaxation is a technique where you follow spoken instructions '
        'to relax your mind and body step by step. This app walks you through '
        'breathing patterns and body awareness to help reduce tension. '
        'Body Scan Relaxation is a great example you can try here.',

    BreathingFaqIntent.howOften:
        'Even 5 to 10 minutes of breathing practice each day can make a real '
        'difference. Short daily sessions build the habit and make it easier '
        'to use these techniques when you need them. '
        'Consistency matters more than duration.',

    BreathingFaqIntent.anxietyPanic:
        'Yes, breathing exercises are one of the fastest tools during anxiety '
        'or panic. Slow deep breathing lowers your heart rate and helps you '
        'regain control. The 4-7-8 technique is especially effective. '
        'Would you like to try it?',

    BreathingFaqIntent.suggestForStress:
        'Stress responds very well to structured breathing. Box Breathing is '
        'the best choice — four equal phases of 4 seconds each to interrupt '
        'your stress loop. Shall I start Box Breathing for you?',

    BreathingFaqIntent.suggestForAnxiety:
        'For anxiety, the 4-7-8 technique works quickly. Inhale for 4 seconds, '
        'hold for 7, and exhale slowly for 8. '
        'Want to start 4-7-8 Breathing now?',

    BreathingFaqIntent.suggestForSleep:
        '4-7-8 Breathing is specifically designed to help you fall asleep. '
        'The long exhale signals your body to wind down. '
        'Shall I guide you through it?',

    BreathingFaqIntent.suggestForAnger:
        'When anger spikes, a slow deep breath with a long exhale brings your '
        'arousal level down quickly. '
        'Want me to start Deep Belly Breathing for you?',

    BreathingFaqIntent.suggestForPanic:
        'If you are having a panic attack, start 4-7-8 breathing right now. '
        'Inhale for 4, hold for 7, exhale for 8. This works within 2 to 3 cycles. '
        'Shall I guide you through it?',

    BreathingFaqIntent.emergencyRedirect:
        'It sounds like you may need urgent support right now. '
        'I am redirecting you to Emergency Support.',

    BreathingFaqIntent.unknown:
        'Sorry, I have no idea about that. You can ask me things like '
        'what are breathing exercises, or how do breathing exercises help '
        'mental health. You can also tell me how you are feeling.',
  };

  // ── Suggested exercise per intent ─────────────────────────────
  static const Map<BreathingFaqIntent, String> suggestionToExerciseId = {
    BreathingFaqIntent.suggestForStress: idBox,
    BreathingFaqIntent.suggestForAnxiety: id478,
    BreathingFaqIntent.suggestForSleep: id478,
    BreathingFaqIntent.suggestForAnger: idDeep,
    BreathingFaqIntent.suggestForPanic: id478,
    BreathingFaqIntent.anxietyPanic: id478,
  };
}
