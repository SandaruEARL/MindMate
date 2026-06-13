// sleep_content.dart
// All types, keyword corpus, and response content for the sleep module.
// Pure Dart — no Flutter imports.
//
// Architecture note (current):
//   The engine is a fast pre-filter only. It handles crisis, handoff,
//   exit/entry routing, meta-intents (repeat / affirmation / negation),
//   exit/entry routing, meta-intents (repeat / affirmation / negation),
//   and the bedtime routine structured card.
//   What remains:
//     • Types: SleepIntent, EmotionalTone, SleepResponse, SleepTip,
//              ChatMessage, IntentLog
//     • Corpus: crisisKeywords, handoffTriggers, directEntryKeywords,
//               exitKeywords, intentKeywords, toneKeywords
//     • Meta-intent variants: responseVariants (greeting, gratitude,
//               help, affirmation, negation, unknown)
//     • Chips: followUpSuggestions
//     • Routine: bedtimeRoutineSteps

import 'dart:math';

// ════════════════════════════════════════════════════════════════
// 1. TYPES
// ════════════════════════════════════════════════════════════════

enum SleepIntent {
  greeting,
  gratitude,
  repeat,
  help,
  affirmation,
  negation,
  cantSleep,
  bedtimeRoutine,
  sleepTips,
  screenTime,
  nap,
  wakeTime,
  sleepDuration,
  stressed,
  tired,
  frustrated,
  unknown,
}

enum EmotionalTone { stressed, tired, frustrated, neutral }

class SleepResponse {
  final String        message;
  final SleepIntent   intent;
  final EmotionalTone tone;
  final List<SleepTip>? tips;
  final List<String>?   routineSteps;
  final List<String>?   suggestions;
  final String?         handoffRoute;
  final bool            isCrisis;
  final double          confidence;

  const SleepResponse({
    required this.message,
    required this.intent,
    this.tone        = EmotionalTone.neutral,
    this.tips,
    this.routineSteps,
    this.suggestions,
    this.handoffRoute,
    this.isCrisis    = false,
    this.confidence  = 1.0,
  });
}

class SleepTip {
  final String emoji;
  final String title;
  final String body;

  const SleepTip({
    required this.emoji,
    required this.title,
    required this.body,
  });
}

class ChatMessage {
  final bool        isUser;
  final String      text;
  final DateTime    timestamp;
  final SleepIntent? intent;
  final double?     confidence;
  final bool        isNew;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.intent,
    this.confidence,
    this.isNew = false,
  }) : timestamp = DateTime.now();
}

class IntentLog {
  final DateTime    time;
  final String      input;
  final SleepIntent intent;
  final double      confidence;
  final EmotionalTone tone;

  IntentLog({
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

class SleepCorpus {
  SleepCorpus._();

  static final _random = Random();

  static String pick(List<String> variants) =>
      variants[_random.nextInt(variants.length)];

  // ── Crisis ────────────────────────────────────────────────────
  static const List<String> crisisKeywords = [
    "don't want to wake up",
    "never wake up",
    "sleep forever",
    "wish i wouldn't wake",
    "not wake up",
    "sleep and not wake",
    "go to sleep forever",
  ];

  // ── Handoff triggers ──────────────────────────────────────────
  static const Map<String, List<String>> handoffTriggers = {
    '/breathing': [
      'i feel anxious', "i'm anxious", 'im anxious', 'help me relax',
      'calm me down', 'i am panicking', 'having a panic', 'panic attack',
      'anxious at night', 'anxiety before bed',
      'go to breathing', 'open breathing', 'breathing exercise',
      'breathing exercises', 'take me to breathing', 'go breathing',
      'breathing module', 'start breathing',
    ],
    '/mindfulness': [
      'meditate before bed', 'guided meditation',
      'meditation for sleep', 'open meditation',
      'go to mindfulness', 'open mindfulness', 'mindfulness module',
      'take me to mindfulness', 'go mindfulness', 'start mindfulness',
      'go to meditation', 'take me to meditation',
    ],
    '/mood': [
      'go to mood', 'open mood', 'mood tracking', 'mood module',
      'take me to mood', 'track my mood', 'go mood',
      'mood tracker', 'start mood tracking',
    ],
    '/emergency': [
      'emergency', 'crisis', 'emergency support',
      'go to emergency', 'open emergency', 'take me to emergency',
    ],
  };

  // ── Direct entry ──────────────────────────────────────────────
  static const List<String> directEntryKeywords = [
    'sleep module', 'sleep hygiene', 'sleep tips', 'bedtime help',
    'open sleep', 'go to sleep module', 'help me sleep', 'sleep support',
    'sleep health', 'sleep problems', 'sleeping problems', 'sleep issues',
    'sleeping issues', 'talk about sleep', 'sleep advice',
  ];

  // ── Exit ──────────────────────────────────────────────────────
  static const List<String> exitKeywords = [
    'exit', 'back', 'bye', 'goodbye', 'stop', 'quit',
    'go back', 'home', 'leave', 'done', 'enough', 'close',
  ];

  // ── Intent keyword map ────────────────────────────────────────
  // Used for routing only.
  static const Map<SleepIntent, List<String>> intentKeywords = {

    SleepIntent.greeting: [
      'hi', 'hello', 'hey', 'good morning', 'good evening',
      'good night', 'howdy', "what's up", 'whats up', 'greetings',
      'sup', 'hiya', 'how are you', 'how are u', 'how r you', 'how r u',
    ],

    SleepIntent.gratitude: [
      'thanks', 'thank you', 'thank you so much', 'cheers',
      'appreciate it', 'appreciate that', 'helpful', 'that helped',
      'that was helpful', 'great help', 'i like you', 'love this',
      "you're great", 'you are great', "you're helpful", 'you are helpful',
      "you're amazing", 'you are amazing', 'good job', 'well done',
    ],

    SleepIntent.repeat: [
      'repeat', 'repeat that', 'say again', 'say that again',
      'what did you say', 'pardon', 'come again', 'once more',
      'can you repeat', "didn't catch that", 'missed that', 'one more time',
    ],

    SleepIntent.help: [
      'what can you do', 'help', 'how does this work', 'what do you do',
      'what can i ask', 'what should i say', 'options', 'commands',
      'features', 'capabilities', 'guide me',
      "i don't know what to say", 'i dont know what to say',
      'show me what you can do',
    ],

    SleepIntent.affirmation: [
      'yes', 'yeah', 'yep', 'yup', 'sure', 'okay', 'ok',
      'alright', 'go ahead', 'please do', 'sounds good', 'do it',
      'tell me more', 'continue', 'go on', 'i would like that',
      'that sounds good', 'absolutely', 'definitely',
    ],

    // Requires ≥2 keyword hits (engine enforces _kMetaMinHits = 2)
    SleepIntent.negation: [
      'not really', 'no thanks', 'never mind', 'nevermind',
      'not interested', 'forget it', 'not now', 'maybe later',
      'no need', 'that is fine', "don't need that", 'dont need that',
      'skip that', 'not helpful', 'that didnt help', "that didn't help",
    ],

    SleepIntent.cantSleep: [
      "can't sleep", "cant sleep", "cannot sleep", "trouble sleeping",
      "hard to sleep", "difficulty sleeping", "lying awake", "awake all night",
      "been awake", "no sleep", "couldn't sleep", "couldn't fall asleep",
      "sleepless", "sleepless night", "insomnia", "tossing and turning",
      "wake up at night", "waking up at night", "keep waking",
      "waking up middle", "middle of the night", "can't fall asleep",
      "cant fall asleep", "unable to sleep", "not able to sleep",
      "restless at night", "sleep won't come", "mind won't stop",
      "mind wont stop", "racing thoughts at night", "wide awake",
      "staring at ceiling", "lying in bed awake", "can't drift off",
      "sleep deprivation", "no rest", "not rested", "didn't sleep",
      "eyes won't close", "hours in bed",
    ],

    SleepIntent.screenTime: [
      "phone before bed", "screen before bed", "blue light",
      "watching tv before bed", "scrolling before bed",
      "social media at night", "phone at night", "laptop before bed",
      "tablet before bed", "screen time at night", "too much screen",
      "phone in bed", "scrolling in bed", "device before sleep",
      "blue light glasses", "screen affecting sleep", "tv in bedroom",
      "computer at night", "doom scrolling", "doomscrolling",
      "tiktok before bed", "instagram before bed", "youtube before bed",
    ],

    SleepIntent.bedtimeRoutine: [
      "bedtime routine", "bed time routine", "before bed routine",
      "night routine", "sleep routine", "going to bed",
      "get ready for sleep", "prepare for sleep", "wind down",
      "winding down", "night time routine", "pre-sleep routine",
      "what to do before bed", "calm down before sleep",
      "relax before bed", "routine for sleep", "habits before bed",
      "bedtime ritual", "evening routine", "nighttime habit",
      "sleep preparation", "how to prepare for bed",
    ],

    SleepIntent.nap: [
      "nap", "napping", "afternoon sleep", "daytime sleep", "power nap",
      "short sleep", "sleep during day", "midday nap", "lunchtime sleep",
      "should i nap", "is napping good", "nap too long", "long nap",
      "cant stop napping", "sleep in afternoon", "daytime napping",
      "siesta", "20 minute nap", "quick nap", "nap affecting sleep",
    ],

    SleepIntent.sleepDuration: [
      "how many hours", "hours of sleep", "8 hours", "7 hours",
      "6 hours", "5 hours", "enough sleep", "how long should i sleep",
      "how much sleep", "too little sleep", "not enough sleep",
      "optimal sleep", "recommended sleep", "sleep needs",
      "sleep requirements", "sleep duration", "sleep amount",
      "sleeping too little", "sleeping too much", "oversleeping",
      "sleep debt", "catching up on sleep", "catch up on sleep",
    ],

    SleepIntent.wakeTime: [
      "wake up time", "wake time", "alarm", "morning routine",
      "consistent wake", "same wake time", "fix wake time",
      "waking up too early", "can't wake up", "cant wake up",
      "hard to wake", "sleeping through alarm", "circadian",
      "circadian rhythm", "body clock", "internal clock",
      "sleep schedule", "irregular sleep", "sleep pattern",
      "consistent bedtime", "fix sleep schedule", "reset sleep",
      "social jetlag", "weekend sleep",
    ],

    SleepIntent.sleepTips: [
      "sleep tips", "sleep advice", "how to sleep", "sleep better",
      "improve sleep", "good sleep", "sleep hygiene tips", "sleep habits",
      "sleep quality", "deep sleep", "better rest", "poor sleep",
      "fix my sleep", "sleeping badly", "bad sleep", "not sleeping well",
      "sleep improvement", "healthy sleep", "what helps sleep",
      "tips for sleeping", "sleep hacks", "sleep suggestions",
      "general sleep advice", "sleep environment", "bedroom for sleep",
      "caffeine and sleep", "alcohol and sleep", "exercise and sleep",
      "melatonin", "cool room", "dark room", "white noise",
      "sleep hygiene",
      "about sleep hygiene",
      "what is sleep hygiene",
      "you know about sleep",
      "know about sleep",
      "tell me about sleep",
      "explain sleep",
      "do you know about sleep",
      "what do you know about sleep",
      "teach me about sleep",
      "sleep information",
      "sleep science",
      "sleep facts",
      "general sleep tips",
      "overview of sleep",
    ],

    SleepIntent.stressed: [
      "stressed", "stress", "so stressed", "overwhelmed", "can't relax",
      "cant relax", "tense", "wound up", "worked up", "on edge",
      "mind is racing", "too much on my mind", "worried", "worrying",
      "anxious", "anxiety", "nervous", "restless",
    ],

    SleepIntent.tired: [
      "tired", "exhausted", "drained", "worn out", "fatigued",
      "sleepy", "drowsy", "so tired", "really tired", "dead tired",
      "running on empty", "no energy", "low energy", "burned out",
      "burnout", "can't keep eyes open", "cant keep eyes open",
    ],

    SleepIntent.frustrated: [
      "frustrated", "annoyed", "irritated", "fed up", "angry",
      "this isn't working", "nothing helps", "nothing works",
      "i give up", "sick of this", "hate this",
      "why can't i sleep", "why cant i sleep", "so annoying",
    ],
  };

  // ── Emotional tone keyword map ────────────────────────────────
  static const Map<EmotionalTone, List<String>> toneKeywords = {
    EmotionalTone.stressed: [
      "stressed", "overwhelmed", "anxious", "worried", "worrying",
      "on edge", "tense", "wound up", "mind is racing",
    ],
    EmotionalTone.tired: [
      "tired", "exhausted", "drained", "worn out", "fatigued",
      "sleepy", "drowsy", "burned out", "no energy",
    ],
    EmotionalTone.frustrated: [
      "frustrated", "annoyed", "fed up", "nothing works",
      "nothing helps", "i give up", "sick of this",
    ],
  };

  // ════════════════════════════════════════════════════════════════
  // 3. META-INTENT RESPONSE VARIANTS
  // Only used for: greeting, gratitude, help, affirmation,
  //               negation, unknown.
  // ════════════════════════════════════════════════════════════════

  static const Map<SleepIntent, List<String>> responseVariants = {

    SleepIntent.greeting: [
      "Hello! I'm your sleep assistant. You can ask me about bedtime routines, "
          "why you can't sleep, screen time habits, naps, or general sleep tips.",
      "Hey there! Ready to help with your sleep. What's on your mind — "
          "trouble falling asleep, a bedtime routine, or something else?",
      "Hi! I'm here to help you sleep better. Ask me anything about sleep hygiene, "
          "routines, naps, or what to do when your mind won't switch off.",
      "I'm here and ready! What's going on with your sleep?",
    ],

    SleepIntent.gratitude: [
      "You're welcome! Sleep well tonight.",
      "Glad that helped. Feel free to ask anything else.",
      "Of course! Come back anytime you need sleep support.",
      "Happy to help. Wishing you a restful night.",
    ],

    SleepIntent.help: [
      "Here's what I can help with: trouble falling asleep, bedtime routines, "
          "screen time before bed, nap advice, how many hours of sleep you need, "
          "and fixing your wake time. Just ask naturally.",
      "You can ask me things like: 'I can't sleep', 'give me a bedtime routine', "
          "'is napping bad?', 'how much sleep do I need?', or 'help with screen time'.",
      "I specialise in sleep hygiene. Try asking about: insomnia, bedtime wind-down, "
          "blue light, power naps, sleep duration, or wake schedules.",
    ],

    SleepIntent.affirmation: [
      "Great, let's continue.",
      "Alright, here we go.",
      "Sure thing.",
      "Okay, I'll go ahead.",
    ],

    SleepIntent.negation: [
      "No problem, let me know if there's anything else.",
      "Alright, I'm here whenever you need me.",
      "Got it. Just say the word if you'd like help with something.",
    ],

    SleepIntent.unknown: [
      "I didn't quite catch that. Try asking about trouble sleeping, "
          "a bedtime routine, screen time, naps, or sleep duration.",
      "Not sure I understood. You can say things like 'I can't sleep' "
          "or 'give me sleep tips' and I'll help.",
      "Could you rephrase that? I'm best with questions about sleep — "
          "routines, insomnia, naps, wake times, and screen habits.",
    ],
  };

  // ════════════════════════════════════════════════════════════════
  // 4. FOLLOW-UP SUGGESTION CHIPS
  // Shown after each response. Engine picks based on intent.
  // ════════════════════════════════════════════════════════════════

  static const Map<SleepIntent, List<String>> followUpSuggestions = {
    SleepIntent.cantSleep: [
      "Try a breathing exercise",
      "Give me a bedtime routine",
      "Tips on screen time",
    ],
    SleepIntent.bedtimeRoutine: [
      "What about screen time?",
      "How many hours do I need?",
      "Help, I still can't sleep",
    ],
    SleepIntent.screenTime: [
      "Give me a bedtime routine",
      "I still can't sleep",
      "Tell me about blue light",
    ],
    SleepIntent.nap: [
      "What's the best wake time?",
      "How much sleep do I need?",
      "General sleep tips",
    ],
    SleepIntent.sleepDuration: [
      "Help me fix my wake time",
      "I can't sleep anyway",
      "Give me sleep tips",
    ],
    SleepIntent.wakeTime: [
      "Give me a bedtime routine",
      "How much sleep do I need?",
      "General sleep tips",
    ],
    SleepIntent.sleepTips: [
      "I can't sleep tonight",
      "Give me a bedtime routine",
      "What about naps?",
    ],
    SleepIntent.stressed: [
      "Try a breathing exercise",
      "Give me a bedtime routine",
      "Tips for racing thoughts",
    ],
    SleepIntent.tired: [
      "How much sleep do I need?",
      "Give me sleep tips",
      "Fix my sleep schedule",
    ],
    SleepIntent.frustrated: [
      "What actually works for sleep?",
      "Try a bedtime routine",
      "Help me with screen time",
    ],
  };

  // ════════════════════════════════════════════════════════════════
  // 5. BEDTIME ROUTINE STEPS
  // Shown as a structured card — the one place engine still owns content.
  // ════════════════════════════════════════════════════════════════

  static const List<String> bedtimeRoutineSteps = [
    'T-30 min — Dim all lights in your room',
    'T-25 min — Put your phone in another room',
    'T-20 min — Light stretching or gentle yoga (5 min)',
    'T-15 min — Warm shower or wash your face',
    'T-10 min — Read a physical book or journal',
    'T-0       — Lights off, eyes closed',
  ];

  // ════════════════════════════════════════════════════════════════
  // 6. LOCAL CONTEXT STRING
  // Gives age + issue-type context.
  // ════════════════════════════════════════════════════════════════

  static String ageContext(int age, String? issueType) {
    final ageGroup = age <= 21
        ? 'a university student aged $age (18–21). '
        'Likely concerns: irregular schedule, academic stress, '
        'shared living noise, late-night social habits.'
        : age <= 25
        ? 'a young professional aged $age (22–25). '
        'Likely concerns: first-job stress, new-city adjustment, '
        'heavy screen time.'
        : 'a young adult aged $age (26–30). '
        'Likely concerns: workplace pressure, relationship stress, '
        'possible early parenting sleep disruption.';

    final issueLabel = issueType == 'onset'
        ? 'trouble falling asleep'
        : issueType == 'maintenance'
        ? 'waking during the night'
        : issueType == 'unrefreshing'
        ? 'unrefreshing sleep'
        : 'general sleep issues';

    return 'The user is $ageGroup '
        'Primary sleep concern: $issueLabel. '
        'Tailor tone and examples to this profile. '
        'Keep language relatable, avoid clinical jargon.';
  }
}