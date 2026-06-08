// breathing_content.dart
// All types, keyword corpus, and response content for the breathing module.
// Pure Dart — no Flutter imports.
// Mirrors the structure of sleep_content.dart for consistency.

import 'dart:math';

// ════════════════════════════════════════════════════════════════
// 1. TYPES
// ════════════════════════════════════════════════════════════════

/// Every meaningful thing a user can say in this module.
enum BreathingIntent {
  // ── Meta ──────────────────────────────────────────────────────
  greeting,
  gratitude,
  repeat,
  help,
  affirmation,
  negation,

  // ── Exercise selection ────────────────────────────────────────
  startBox, // Box Breathing  (4-4-4-4)
  start478, // 4-7-8 Breathing
  startDeep, // Deep Belly Breathing
  startBodyScan, // Body Scan Relaxation
  // ── Session control ───────────────────────────────────────────
  stop, // stop / cancel current exercise
  pause, // pause (future)
  resume, // resume (future)
  // ── Information requests ──────────────────────────────────────
  whatIsBox,
  whatIs478,
  whatIsDeep,
  whatIsBodyScan,
  listExercises, // "what exercises do you have?"
  howLong, // "how long does it take?"
  benefits, // "what are the benefits?"
  // ── Emotional context ─────────────────────────────────────────
  anxious,
  stressed,
  angry,
  cantSleep,
  panicAttack,

  // ── Fallback ─────────────────────────────────────────────────
  unknown,
}

enum BreathingEmotionalTone { anxious, stressed, angry, neutral }

/// The engine's structured reply to one turn of input.
class BreathingResponse {
  final String message;
  final BreathingIntent intent;
  final BreathingEmotionalTone tone;
  final String? exerciseId; // non-null → UI should start this exercise
  final List<BreathingTip>? tips;
  final List<String>? suggestions; // follow-up chips
  final bool shouldStop; // true → UI must stop current exercise
  final double confidence;

  const BreathingResponse({
    required this.message,
    required this.intent,
    this.tone = BreathingEmotionalTone.neutral,
    this.exerciseId,
    this.tips,
    this.suggestions,
    this.shouldStop = false,
    this.confidence = 1.0,
  });
}

class BreathingTip {
  final String emoji;
  final String title;
  final String body;
  const BreathingTip({
    required this.emoji,
    required this.title,
    required this.body,
  });
}

class BreathingIntentLog {
  final DateTime time;
  final String input;
  final BreathingIntent intent;
  final double confidence;
  final BreathingEmotionalTone tone;

  BreathingIntentLog({
    required this.input,
    required this.intent,
    required this.confidence,
    required this.tone,
  }) : time = DateTime.now();

  @override
  String toString() =>
      '[${time.hour}:${time.minute.toString().padLeft(2, '0')}] '
      'intent=${intent.name} conf=${confidence.toStringAsFixed(2)} '
      'tone=${tone.name} input="$input"';
}

// ════════════════════════════════════════════════════════════════
// 2. CORPUS
// ════════════════════════════════════════════════════════════════

class BreathingCorpus {
  BreathingCorpus._();

  static final _random = Random();
  static String pick(List<String> variants) =>
      variants[_random.nextInt(variants.length)];

  // ── Exercise ID constants (match BreathingExercisesPage) ──────
  static const String idBox = 'box';
  static const String id478 = '478';
  static const String idDeep = 'deep';
  static const String idBodyScan = 'body_scan';

  // ── Exit keywords ─────────────────────────────────────────────
  static const List<String> exitKeywords = [
    'exit',
    'back',
    'bye',
    'goodbye',
    'go back',
    'home',
    'leave',
    'done',
    'enough',
    'close',
    'quit',
  ];

  // ── Intent → keyword map (scoring engine) ─────────────────────
  static const Map<BreathingIntent, List<String>> intentKeywords = {
    BreathingIntent.greeting: [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good evening',
      'good night',
      'howdy',
      'sup',
      'hiya',
      'how are you',
      'how are u',
    ],

    BreathingIntent.gratitude: [
      'thanks',
      'thank you',
      'appreciate',
      'helpful',
      'that helped',
      'great help',
      'you are great',
      'you are amazing',
      'good job',
      'well done',
      'love this',
      'i like you',
    ],

    BreathingIntent.repeat: [
      'repeat',
      'say again',
      'say that again',
      'what did you say',
      'pardon',
      'come again',
      'once more',
      'can you repeat',
      'missed that',
      'one more time',
      'didn\'t catch',
    ],

    BreathingIntent.help: [
      'what can you do',
      'help',
      'how does this work',
      'what do you do',
      'options',
      'commands',
      'guide me',
      'show me',
      'i don\'t know',
      'what can i say',
      'what should i say',
      'features',
    ],

    BreathingIntent.affirmation: [
      'yes',
      'yeah',
      'yep',
      'yup',
      'sure',
      'okay',
      'ok',
      'alright',
      'go ahead',
      'please do',
      'sounds good',
      'do it',
      'tell me more',
      'continue',
      'go on',
      'absolutely',
      'definitely',
      'start it',
      'let\'s go',
      'lets go',
      'begin',
      'start',
    ],

    BreathingIntent.negation: [
      'no',
      'nope',
      'nah',
      'not really',
      'no thanks',
      'don\'t',
      'dont',
      'never mind',
      'nevermind',
      'skip',
      'not interested',
      'forget it',
      'not now',
      'maybe later',
      'stop',
      'cancel',
    ],

    // ── Exercise selection ───────────────────────────────────────
    BreathingIntent.startBox: [
      'box',
      'box breathing',
      'four four',
      '4 4 4 4',
      'square breathing',
      'tactical breathing',
      'military breathing',
      'start box',
      'do box',
      'try box',
      'box breath',
    ],

    BreathingIntent.start478: [
      '4 7 8',
      '478',
      'four seven eight',
      '4-7-8',
      'four seven',
      'start 4 7 8',
      'do 4 7 8',
      'try 4 7 8',
      'sleep breathing',
      'relaxation breathing',
      '478 breathing',
    ],

    BreathingIntent.startDeep: [
      'deep',
      'deep breathing',
      'belly breathing',
      'belly breath',
      'diaphragm',
      'diaphragmatic',
      'slow breathing',
      'slow breath',
      'start deep',
      'do deep',
      'try deep',
      'deep belly',
    ],

    BreathingIntent.startBodyScan: [
      'body scan',
      'body scan relaxation',
      'body awareness',
      'mindful breathing',
      'mindfulness breathing',
      'awareness breathing',
      'scan',
      'start body scan',
      'do body scan',
      'try body scan',
    ],

    // ── Session control ──────────────────────────────────────────
    BreathingIntent.stop: [
      'stop',
      'cancel',
      'end',
      'quit',
      'halt',
      'enough',
      'finish',
      'stop breathing',
      'cancel exercise',
      'stop exercise',
      'end exercise',
    ],

    // ── Information requests ─────────────────────────────────────
    BreathingIntent.whatIsBox: [
      'what is box',
      'what\'s box',
      'explain box',
      'tell me about box',
      'how does box work',
      'box breathing steps',
      'box technique',
    ],

    BreathingIntent.whatIs478: [
      'what is 4 7 8',
      'what\'s 4 7 8',
      'explain 4 7 8',
      'tell me about 4 7 8',
      'how does 4 7 8 work',
      '478 steps',
    ],

    BreathingIntent.whatIsDeep: [
      'what is deep',
      'what\'s deep breathing',
      'explain deep breathing',
      'tell me about deep breathing',
      'how does deep breathing work',
    ],

    BreathingIntent.whatIsBodyScan: [
      'what is body scan',
      'what\'s body scan',
      'explain body scan',
      'tell me about body scan',
      'how does body scan work',
    ],

    BreathingIntent.listExercises: [
      'what exercises',
      'list exercises',
      'what techniques',
      'options',
      'what do you have',
      'which exercises',
      'all exercises',
      'available exercises',
      'what breathing',
      'types of breathing',
    ],

    BreathingIntent.howLong: [
      'how long',
      'how many minutes',
      'duration',
      'time',
      'how long does it take',
      'quick',
      'fast',
    ],

    BreathingIntent.benefits: [
      'benefits',
      'why breathe',
      'what does it do',
      'does it help',
      'why should i',
      'effect',
      'science',
      'research',
      'proof',
    ],

    // ── Emotional context ────────────────────────────────────────
    BreathingIntent.anxious: [
      'anxious',
      'anxiety',
      'nervous',
      'worry',
      'worried',
      'panic',
      'panicking',
      'scared',
      'fear',
      'afraid',
      'overwhelmed',
      'heart racing',
      'chest tight',
      'can\'t breathe',
    ],

    BreathingIntent.stressed: [
      'stressed',
      'stress',
      'tense',
      'wound up',
      'on edge',
      'overwhelmed',
      'too much',
      'need to relax',
      'can\'t relax',
      'help me calm',
      'calm me',
      'calm down',
    ],

    BreathingIntent.angry: [
      'angry',
      'anger',
      'mad',
      'furious',
      'annoyed',
      'irritated',
      'frustrated',
      'rage',
      'upset',
      'pissed',
      'fed up',
    ],

    BreathingIntent.cantSleep: [
      'can\'t sleep',
      'cant sleep',
      'cannot sleep',
      'sleepless',
      'insomnia',
      'lying awake',
      'wide awake',
      'mind won\'t stop',
    ],

    BreathingIntent.panicAttack: [
      'panic attack',
      'having a panic',
      'panic',
      'hyperventilating',
      'hyperventilate',
      'breathing too fast',
      'can\'t catch breath',
      'short of breath',
      'gasping',
    ],
  };

  // ── Emotional tone → keywords ─────────────────────────────────
  static const Map<BreathingEmotionalTone, List<String>> toneKeywords = {
    BreathingEmotionalTone.anxious: [
      'anxious',
      'anxiety',
      'nervous',
      'panic',
      'scared',
      'fear',
      'worried',
      'overwhelmed',
      'heart racing',
      'chest tight',
    ],
    BreathingEmotionalTone.stressed: [
      'stressed',
      'stress',
      'tense',
      'wound up',
      'on edge',
      'too much',
      'can\'t relax',
    ],
    BreathingEmotionalTone.angry: [
      'angry',
      'mad',
      'furious',
      'irritated',
      'frustrated',
      'rage',
    ],
  };

  // ── Follow-up suggestions ─────────────────────────────────────
  static const Map<BreathingIntent, List<String>> followUpSuggestions = {
    BreathingIntent.startBox: ['Start 4-7-8', 'What is box breathing?', 'Stop'],
    BreathingIntent.start478: ['Start box breathing', 'What is 4-7-8?', 'Stop'],
    BreathingIntent.startDeep: [
      'Start box breathing',
      'Tell me the benefits',
      'Stop',
    ],
    BreathingIntent.startBodyScan: [
      'Start deep breathing',
      'What is body scan?',
      'Stop',
    ],
    BreathingIntent.anxious: [
      'Start 4-7-8',
      'Start box breathing',
      'What helps anxiety?',
    ],
    BreathingIntent.stressed: [
      'Start box breathing',
      'Start deep breathing',
      'Tell me benefits',
    ],
    BreathingIntent.angry: [
      'Start deep breathing',
      'Start 4-7-8',
      'Tell me benefits',
    ],
    BreathingIntent.cantSleep: [
      'Start 4-7-8',
      'Start deep breathing',
      'Tell me benefits',
    ],
    BreathingIntent.panicAttack: [
      'Start 4-7-8',
      'Start box breathing',
      'Tell me benefits',
    ],
    BreathingIntent.listExercises: [
      'Start box breathing',
      'Start 4-7-8',
      'What are the benefits?',
    ],
    BreathingIntent.benefits: [
      'Start box breathing',
      'Start 4-7-8',
      'List exercises',
    ],
    BreathingIntent.howLong: [
      'Start box breathing',
      'Start 4-7-8',
      'List exercises',
    ],
  };

  // ── Tips per intent ───────────────────────────────────────────
  static const Map<BreathingIntent, List<BreathingTip>> intentTips = {
    BreathingIntent.startBox: [
      BreathingTip(
        emoji: '📦',
        title: 'Box Breathing — 4-4-4-4',
        body:
            'Inhale 4 sec → Hold 4 sec → Exhale 4 sec → Hold 4 sec. '
            'Used by US Navy SEALs to regulate stress under pressure.',
      ),
      BreathingTip(
        emoji: '🧠',
        title: 'Why it works',
        body:
            'The equal-length holds activate your parasympathetic nervous '
            'system, slowing heart rate within 60 seconds.',
      ),
    ],
    BreathingIntent.start478: [
      BreathingTip(
        emoji: '💤',
        title: '4-7-8 — Natural tranquiliser',
        body:
            'Inhale 4 sec → Hold 7 sec → Exhale 8 sec. '
            'The long exhale triggers your body\'s relaxation response.',
      ),
      BreathingTip(
        emoji: '🌙',
        title: 'Best for sleep',
        body:
            'Practise 4-7-8 when lying in bed. '
            'The extended exhale drops your heart rate and signals sleep.',
      ),
    ],
    BreathingIntent.startDeep: [
      BreathingTip(
        emoji: '🫁',
        title: 'Belly breathing',
        body:
            'Place one hand on your belly. Breathe so only your hand rises '
            '— not your chest. This activates the diaphragm fully.',
      ),
      BreathingTip(
        emoji: '✅',
        title: 'Easiest to learn',
        body:
            'Deep belly breathing requires no counting and is the '
            'foundation of all other breathing techniques.',
      ),
    ],
    BreathingIntent.startBodyScan: [
      BreathingTip(
        emoji: '🧘',
        title: 'Breath + awareness',
        body:
            'Body Scan pairs slow breathing with attention to each body part. '
            'Start at your feet and work upward on each exhale.',
      ),
      BreathingTip(
        emoji: '🌿',
        title: 'Releases muscle tension',
        body:
            'As you exhale and scan each area, consciously relax that muscle. '
            'Most people hold tension they\'re unaware of.',
      ),
    ],
    BreathingIntent.anxious: [
      BreathingTip(
        emoji: '🌬️',
        title: 'Exhale longer than inhale',
        body:
            'A ratio of 1:2 (e.g. inhale 4, exhale 8) immediately '
            'engages the vagus nerve and reduces anxiety.',
      ),
      BreathingTip(
        emoji: '🫀',
        title: 'Slows heart rate',
        body:
            'Controlled breathing directly lowers cortisol and adrenaline. '
            'Effects start within 90 seconds.',
      ),
    ],
    BreathingIntent.stressed: [
      BreathingTip(
        emoji: '📦',
        title: 'Box breathing for stress',
        body:
            'The 4-4-4-4 rhythm interrupts your stress loop by giving '
            'your mind a structured focus.',
      ),
    ],
    BreathingIntent.angry: [
      BreathingTip(
        emoji: '🌊',
        title: 'Slow the exhale',
        body:
            'Anger raises arousal. A slow 6-8 second exhale activates '
            'the brake on your nervous system within minutes.',
      ),
    ],
    BreathingIntent.panicAttack: [
      BreathingTip(
        emoji: '🆘',
        title: 'Ground yourself first',
        body:
            'Name 5 things you can see. Then start 4-7-8 breathing. '
            'Grounding stops the panic spiral before breathing helps.',
      ),
      BreathingTip(
        emoji: '🫁',
        title: 'Breathe from the belly',
        body:
            'Panic causes chest breathing. Put your hand on your belly '
            'and breathe so it rises — this stops hyperventilation.',
      ),
    ],
  };

  // ── Response messages ─────────────────────────────────────────
  static const Map<BreathingIntent, List<String>> responseMessages = {
    BreathingIntent.greeting: [
      'Hello! I\'m your breathing guide. Say a technique name like '
          '"Box Breathing" or "4-7-8" and I\'ll start it for you.',
      'Hey there! Ready to guide your breathing. '
          'Say "list exercises" to hear your options, or just name one to begin.',
      'Hi! Tell me how you\'re feeling or name a technique and we\'ll begin.',
    ],

    BreathingIntent.gratitude: [
      'You\'re welcome! Keep breathing well.',
      'Glad that helped. Your breathing is in good hands.',
      'Of course! Come back any time you need a breathing session.',
      'Happy to help. Keep up the practice.',
    ],

    BreathingIntent.help: [
      'You can say: "Start box breathing", "Start 4-7-8", '
          '"Start deep breathing", or "Start body scan". '
          'You can also say "Stop" to end a session, or ask "What is box breathing?"',
      'Try saying a technique name to begin — Box, 4-7-8, Deep, or Body Scan. '
          'Say "list exercises" to hear all options. Say "Stop" to end a session.',
    ],

    BreathingIntent.affirmation: [
      'Great, let\'s begin.',
      'Alright, starting now.',
      'Sure thing.',
      'Okay, here we go.',
    ],

    BreathingIntent.negation: [
      'No problem. Say a technique name whenever you\'re ready.',
      'Alright, I\'m here when you need me.',
      'Got it. Just say the word.',
    ],

    BreathingIntent.stop: [
      'Exercise stopped. Well done for trying.',
      'Stopping now. You can start another exercise any time.',
      'Session ended. Take a moment to notice how you feel.',
    ],

    BreathingIntent.listExercises: [
      'I have four techniques: Box Breathing, 4-7-8 Breathing, '
          'Deep Belly Breathing, and Body Scan Relaxation. '
          'Which would you like to start?',
      'Your options are: Box Breathing for focus and calm, '
          '4-7-8 for sleep and deep relaxation, '
          'Deep Belly Breathing for stress, and '
          'Body Scan for mindful awareness. Which one?',
    ],

    BreathingIntent.howLong: [
      'Box Breathing takes about 2 minutes for one full cycle. '
          '4-7-8 takes about 1 minute. Deep Belly and Body Scan are flexible — '
          'you control the duration.',
      'Most sessions are 1–5 minutes. Even one cycle of 4-7-8 '
          'takes under 20 seconds and has a noticeable calming effect.',
    ],

    BreathingIntent.benefits: [
      'Controlled breathing directly lowers cortisol, slows heart rate, '
          'activates the parasympathetic nervous system, and reduces anxiety '
          'within 60–90 seconds. The effects compound with daily practice.',
      'Breathing exercises reduce anxiety, lower blood pressure, improve focus, '
          'and help with sleep. The vagus nerve is the key — slow exhalation '
          'stimulates it directly.',
    ],

    BreathingIntent.whatIsBox: [
      'Box Breathing uses four equal phases: inhale for 4 seconds, '
          'hold for 4, exhale for 4, hold for 4. '
          'It\'s used by the military and emergency services to stay calm under pressure.',
    ],

    BreathingIntent.whatIs478: [
      '4-7-8 Breathing: inhale for 4 seconds, hold for 7, exhale for 8. '
          'The long hold and slow exhale trigger a strong relaxation response. '
          'It\'s especially effective for falling asleep.',
    ],

    BreathingIntent.whatIsDeep: [
      'Deep Belly Breathing means breathing from the diaphragm, '
          'not the chest. Your belly should rise on the inhale and fall on the exhale. '
          'It\'s the foundation of all breathing techniques.',
    ],

    BreathingIntent.whatIsBodyScan: [
      'Body Scan Relaxation pairs slow breathing with mindful awareness of each '
          'body part, starting from your feet and moving upward. '
          'On each exhale, you consciously relax that area.',
    ],

    BreathingIntent.anxious: [
      'When you\'re anxious, the best move is to extend your exhale. '
          'I recommend starting 4-7-8 breathing right now — shall I begin?',
      'Anxiety responds really well to breathing. '
          'The 4-7-8 technique is your best option here. Ready to start?',
    ],

    BreathingIntent.stressed: [
      'Stress and breathing are directly linked. Box breathing is '
          'the quickest reset for a stressed mind — want to try it?',
      'For stress, Box Breathing or Deep Belly Breathing both work well. '
          'Which would you like to start?',
    ],

    BreathingIntent.angry: [
      'Anger raises your arousal level. A slow Deep Belly Breath '
          'with a long exhale can bring it down quickly — shall I start?',
      'For anger, I recommend Deep Belly Breathing or 4-7-8. '
          'The long exhale directly slows your heart rate. Ready?',
    ],

    BreathingIntent.cantSleep: [
      '4-7-8 Breathing is specifically designed to help you fall asleep. '
          'The long exhale signals your body to wind down — shall I start?',
      'For sleeplessness, 4-7-8 is your best option. '
          'Try it lying in bed with your eyes closed. Want to begin?',
    ],

    BreathingIntent.panicAttack: [
      'If you\'re having a panic attack, start with 4-7-8 breathing right now. '
          'Inhale for 4, hold for 7, exhale for 8. '
          'Shall I guide you through it?',
      'For a panic attack, breathing is the fastest tool. '
          'Let\'s do 4-7-8 together — it works within 2–3 cycles. Ready?',
    ],

    BreathingIntent.unknown: [
      'I didn\'t catch that. Try saying a technique name like '
          '"Box Breathing", "4-7-8", "Deep Breathing", or "Body Scan".',
      'Not sure I understood. You can say "List exercises" to hear your options, '
          'or name a technique to start.',
      'Could you rephrase? Try saying "Start box breathing" or '
          '"I feel anxious" and I\'ll suggest the right technique.',
    ],
  };

  // ── Emotional tone prefixes ───────────────────────────────────
  static const Map<BreathingEmotionalTone, List<String>> tonePrefixes = {
    BreathingEmotionalTone.anxious: [
      'I can hear that you\'re anxious — let\'s slow your breathing down right now. ',
      'Anxiety responds quickly to breathing. Here\'s what to do. ',
    ],
    BreathingEmotionalTone.stressed: [
      'Stress and breathing are tightly connected. Let\'s reset together. ',
      'When stress hits, controlled breathing is the fastest reset. ',
    ],
    BreathingEmotionalTone.angry: [
      'Let\'s bring your nervous system down with a slow breath. ',
      'Anger fades faster than you think with the right breathing. ',
    ],
  };

  // ── Exercise ID that each intent should trigger ───────────────
  static const Map<BreathingIntent, String> intentToExerciseId = {
    BreathingIntent.startBox: idBox,
    BreathingIntent.start478: id478,
    BreathingIntent.startDeep: idDeep,
    BreathingIntent.startBodyScan: idBodyScan,
  };
}
