// services/crisis_detector.dart

class CrisisDetector {
  CrisisDetector._();

  // ── Crisis keywords ───────────────────────────────────────────────────────
  static const List<String> _crisisKeywords = [
    'suicide',
    'suicidal',
    'kill myself',
    'end my life',
    'take my life',
    'want to die',
    'wanna die',
    'better off dead',
    'not worth living',
    'dont want to live',
    'no reason to live',
    'wish i was dead',
    'wish i were dead',
    'sleep forever',
    'never wake up',
    'dont want to wake up',
    'hurt myself',
    'harm myself',
    'self harm',
    'cutting myself',
    'hopeless',
    'no hope',
    'cant go on',
    'cant take it anymore',
    'cant handle this',
    'give up on life',
    'nothing to live for',
    'in crisis',
    'mental breakdown',
    'breaking down',
    'falling apart',
    'losing my mind',
    'cant cope',
    'end it all',
    'make it stop',
    'too much pain',
    'no way out',
    'cant breathe',
    'trapped',
    'feel like dying',
    'dont want to be here',
    'disappear forever',
    'nobody cares',
    'all alone',
    'completely alone',
  ];

  // ── Contact keyword map ───────────────────────────────────────────────────
  static const Map<String, List<String>> _contactKeywords = {
    'police': [
      'police',
      'cop',
      'cops',
      'officer',
      'law enforcement',
      'law',
      'crime',
      'criminal',
      'robbery',
      'robbed',
      'theft',
      'stolen',
      'burglar',
      'break in',
      'intruder',
      'assault',
      'attacked',
      'being attacked',
      'someone attacking',
      'threat',
      'threatened',
      'danger',
      'in danger',
      'unsafe',
      'help police',
      'need police',
      'call police',
      'send police',
      'harassment',
      'stalker',
      'stalking',
      'kidnap',
      'kidnapping',
      'missing person',
      '119',
    ],
    'ambulance': [
      'ambulance',
      'medical',
      'medical help',
      'medical emergency',
      'injured',
      'injury',
      'bleeding',
      'heavy bleeding',
      'cant stop bleeding',
      'accident',
      'car accident',
      'road accident',
      'unconscious',
      'not breathing',
      'stopped breathing',
      'heart attack',
      'chest pain',
      'stroke',
      'seizure',
      'convulsion',
      'overdose',
      'drug overdose',
      'poisoned',
      'poisoning',
      'fainted',
      'passed out',
      'collapsed',
      'broken bone',
      'fracture',
      'severe pain',
      'suwa seriya',
      'need doctor',
      'need medical',
      'send ambulance',
      'call ambulance',
      '1990',
    ],
    'fire': [
      'fire',
      'on fire',
      'house fire',
      'building fire',
      'fire started',
      'burning',
      'something burning',
      'everything burning',
      'flames',
      'smoke',
      'lot of smoke',
      'gas leak',
      'explosion',
      'exploded',
      'rescue',
      'trapped in fire',
      'stuck in fire',
      'fire department',
      'fire service',
      'fire brigade',
      'call fire',
      'send fire',
      'need fire',
      '110',
    ],
    'mental_health': [
      'mental',
      'mental issue',
      'mental problem',
      'mental health',
      'hotline',
      'mental health hotline',
      'mental health line',
      'counselor',
      'counsellor',
      'therapist',
      'psychiatrist',
      'psychologist',
      'talk to someone',
      'need to talk',
      'someone to talk',
      'emotional support',
      'mental support',
      'psychological help',
      'mental crisis',
      'feeling down',
      'feeling low',
      'very sad',
      'extremely sad',
      'depressed',
      'depression',
      'anxiety',
      'anxious',
      'panic attack',
      'panicking',
      'overwhelmed',
      'stressed out',
      'cannot function',
      'mental help',
      'emotional help',
      'need support',
      'need counseling',
      'need therapy',
      'mental line',
      '1926',
    ],
    'friend': [
      'friend',
      'my friend',
      'call friend',
      'trusted friend',
      'close friend',
      'best friend',
      'befrienders',
      'suicide prevention',
      'suicide',
      'suicidal',
      'suicidal thoughts',
      'thinking about suicide',
      'end my life',
      'take my life',
      'kill myself',
      'want to die',
      'wanna die',
      'feel like dying',
      'hopeless',
      'no hope left',
      'cant go on',
      'cant do this anymore',
      'no reason to live',
      'nothing to live for',
      'give up',
      'giving up',
      'done with life',
      'life is meaningless',
      'dont want to exist',
      'want to disappear',
    ],
  };

  // ── Back keywords ─────────────────────────────────────────────────────────
  static const List<String> _backWords = [
    'back',
    'go back',
    'return',
    'home',
    'exit',
    'leave',
    'close',
    'bye',
    'goodbye',
    'go home',
    'take me back',
    'never mind',
    'nevermind',
    'cancel that',
  ];

  // ── Confirm / cancel ──────────────────────────────────────────────────────
  static const List<String> _confirmWords = [
    'confirm',
    // 'yes',
    // 'yeah',
    // 'yep',
    // 'yup',
    // 'ok',
    // 'okay',
    // 'sure',
    // 'do it',
    // 'call',
    // 'call now',
    // 'proceed',
    // 'go ahead',
    // 'please call',
    // 'dial',
    // 'dial now',
    // 'make the call',
  ];

  static const List<String> _cancelWords = [
    'cancel',
    // 'no',
    // 'nope',
    // 'nah',
    // 'stop',
    // 'never mind',
    // 'nevermind',
    // 'dont',
    // 'do not',
    // 'dont call',
    // 'abort',
    // 'go back',
    // 'not now',
    // 'not yet',
    // 'wait',
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  static bool isCrisis(String input) {
    final t = input.toLowerCase();
    return _crisisKeywords.any((kw) => t.contains(kw));
  }

  /// Returns a contact key, 'unknown' for generic call, or null for no match.
  static String? detectCallIntent(String input) {
    final t = input.toLowerCase();

    // Check specific contact keywords
    for (final entry in _contactKeywords.entries) {
      if (entry.value.any((kw) => t.contains(kw))) {
        return entry.key;
      }
    }

    // Generic call word with no specific contact
    if (t.contains('call') ||
        t.contains('dial') ||
        t.contains('help') ||
        t.contains('emergency') ||
        t.contains('i need help') ||
        t.contains('please help')) {
      return 'unknown';
    }

    return null;
  }

  static bool isBackIntent(String input) {
    final t = input.toLowerCase();
    return _backWords.any((kw) => t.contains(kw));
  }

  static bool isConfirm(String input) {
    final t = input.toLowerCase();
    return _confirmWords.any((kw) => t.contains(kw));
  }

  static bool isCancel(String input) {
    final t = input.toLowerCase();
    return _cancelWords.any((kw) => t.contains(kw));
  }
}
