class MoodQA {
  const MoodQA({
    required this.keywords,
    required this.question,
    required this.answer,
  });

  /// Keywords detected in user speech to match this Q&A
  final List<String> keywords;

  /// Display label for the question (shown in UI if needed)
  final String question;

  /// The answer the app speaks and displays
  final String answer;
}

const Map<String, List<MoodQA>> moodQAMap = {
  // ── GREAT ────────────────────────────────────────────────────────────────
  'Great': [
    MoodQA(
      // How do I keep this positive feeling going?
      keywords: ['keep', 'maintain', 'continue', 'positive', 'hold', 'sustain'],
      question: 'How do I keep this positive feeling going?',
      answer:
          'To hold onto this feeling, try to notice exactly what made today great — write it down or share it with someone. Positive emotions are more lasting when we consciously reflect on them. Do more of what created this moment.',
    ),
    MoodQA(
      // Should I share this good mood with others?
      keywords: ['share', 'spread', 'tell', 'others', 'friend', 'family'],
      question: 'Should I share this good mood with others?',
      answer:
          'Absolutely. Sharing joy actually amplifies it. Reach out to a friend or loved one, not just to tell them you are happy, but to make them feel included in your good day. That connection strengthens both of you.',
    ),
    MoodQA(
      // How can I use this energy productively?
      keywords: [
        'productive',
        'energy',
        'use',
        'channel',
        'focus',
        'accomplish',
      ],
      question: 'How can I use this energy productively?',
      answer:
          'High-mood moments are great for tackling tasks you usually avoid. Use this energy for something meaningful — a creative project, a hard conversation you have been delaying, or simply getting ahead on goals that matter to you.',
    ),
    MoodQA(
      // Will this feeling last?
      keywords: ['last', 'long', 'forever', 'stay', 'permanent', 'fade'],
      question: 'Will this feeling last?',
      answer:
          'Feelings naturally shift, and that is okay. Rather than worrying about it ending, try to be fully present in it right now. Mindfulness and gratitude practices can help you return to this state more often over time.',
    ),
    MoodQA(
      // How do I practice gratitude when I feel great?
      keywords: [
        'gratitude',
        'grateful',
        'thankful',
        'appreciate',
        'thankful',
        'blessed',
      ],
      question: 'How do I practice gratitude when I feel great?',
      answer:
          'When you feel great, gratitude goes even deeper. Take two minutes to write three specific things you are thankful for today — not general things, but exact moments. This trains your brain to notice the good more often.',
    ),
  ],

  // ── GOOD ─────────────────────────────────────────────────────────────────
  'Good': [
    MoodQA(
      // How can I feel even better?
      keywords: ['better', 'improve', 'boost', 'upgrade', 'lift', 'enhance'],
      question: 'How can I feel even better?',
      answer:
          'A good mood is a strong foundation. To build on it, try adding a small win to your day — a short walk, a kind message to someone, or finishing one task you have been putting off. Small actions compound into great feelings.',
    ),
    MoodQA(
      // Why do I feel good today?
      keywords: ['why', 'reason', 'cause', 'source', 'because', 'explain'],
      question: 'Why do I feel good today?',
      answer:
          'Pausing to identify the source of a good mood is a powerful habit. Think about what happened differently today — enough sleep, a positive interaction, progress on something meaningful? Understanding it helps you recreate it.',
    ),
    MoodQA(
      // Can I use this mood to help someone else?
      keywords: ['help', 'support', 'give', 'others', 'someone', 'contribute'],
      question: 'Can I use this mood to help someone else?',
      answer:
          'Yes, and it is one of the best things you can do. When we feel good, we have more emotional capacity to give. Reach out to someone who might need a kind word today. It will deepen your own sense of wellbeing too.',
    ),
    MoodQA(
      // How do I stay focused while feeling good?
      keywords: ['focus', 'concentrate', 'work', 'study', 'productive', 'task'],
      question: 'How do I stay focused while feeling good?',
      answer:
          'Good moods can sometimes make us restless. Channel it with a clear intention — pick one priority for the next hour and commit to it. Short focus blocks with breaks in between work well when your energy is high.',
    ),
    MoodQA(
      // Is it okay to just relax and enjoy this?
      keywords: ['relax', 'rest', 'enjoy', 'slow', 'unwind', 'pause'],
      question: 'Is it okay to just relax and enjoy this?',
      answer:
          'Absolutely. Rest is not wasted time — it is recovery. Enjoying a calm, good moment without forcing productivity is healthy. Give yourself full permission to simply be in this feeling without guilt.',
    ),
  ],

  // ── OKAY ─────────────────────────────────────────────────────────────────
  'Okay': [
    MoodQA(
      // Why do I just feel okay?
      keywords: ['why', 'reason', 'normal', 'fine', 'average', 'neutral'],
      question: 'Why do I just feel okay?',
      answer:
          'Feeling okay is completely normal and more common than we admit. It often means your nervous system is stable — not stressed, not elated. It can be a sign that nothing is wrong, just that today is a regular day.',
    ),
    MoodQA(
      // How do I lift my mood from okay to better?
      keywords: ['better', 'improve', 'lift', 'boost', 'change', 'shift'],
      question: 'How do I lift my mood from okay to better?',
      answer:
          'Small intentional actions can shift an okay day. Try stepping outside for ten minutes, listening to a song you love, or doing one thing purely for enjoyment. Do not wait to feel motivated — action creates the feeling.',
    ),
    MoodQA(
      // I feel bored and flat — is that okay?
      keywords: ['bored', 'boring', 'dull', 'flat', 'empty', 'nothing'],
      question: 'I feel bored and flat — is that okay?',
      answer:
          'Boredom and flatness are signals worth listening to. They often mean your mind is craving something new or meaningful. Try something small and different — a new route, a new recipe, or a conversation with someone unexpected.',
    ),
    MoodQA(
      // How do I find motivation when I feel just okay?
      keywords: [
        'motivation',
        'motivated',
        'drive',
        'purpose',
        'energy',
        'push',
      ],
      question: 'How do I find motivation when I feel just okay?',
      answer:
          'Motivation rarely comes before action — it usually follows it. Start with the smallest possible version of a task: two minutes of movement, one paragraph of writing, one email sent. Momentum builds from tiny starts.',
    ),
    MoodQA(
      // How do I make peace with feeling just okay?
      keywords: ['accept', 'peace', 'content', 'enough', 'okay', 'settle'],
      question: 'How do I make peace with feeling just okay?',
      answer:
          'Not every day needs to be remarkable. Being okay is a neutral, balanced state — and balance is healthy. Practice accepting the ordinary without labelling it as failure. Contentment often lives in these quiet, unremarkable moments.',
    ),
  ],

  // ── SAD ──────────────────────────────────────────────────────────────────
  'Sad': [
    MoodQA(
      // Why do I feel sad?
      keywords: ['why', 'reason', 'cause', 'wrong', 'happen', 'explain'],
      question: 'Why do I feel sad?',
      answer:
          'Sadness can come from loss, unmet needs, loneliness, or even tiredness. You do not always need a clear reason — sometimes the body carries emotions before the mind understands them. Being gentle with yourself right now is more important than finding an explanation.',
    ),
    MoodQA(
      // Is it okay to cry?
      keywords: ['cry', 'crying', 'tears', 'weep', 'sob', 'emotional'],
      question: 'Is it okay to cry?',
      answer:
          'Yes, crying is one of the most natural emotional releases we have. It signals that something matters to you, and it actually helps regulate stress hormones. Let yourself cry without judging it as weakness. It takes strength to feel.',
    ),
    MoodQA(
      // What can help me feel better?
      keywords: ['better', 'help', 'improve', 'lift', 'cheer', 'heal'],
      question: 'What can help me feel better?',
      answer:
          'Small physical actions help when emotion feels heavy. Try drinking a glass of water, stepping outside briefly, or lying down with slow deep breaths. Connection also helps — even a short text to someone you trust can ease sadness.',
    ),
    MoodQA(
      // Should I talk to someone about this?
      keywords: ['talk', 'someone', 'share', 'tell', 'speak', 'open'],
      question: 'Should I talk to someone about this?',
      answer:
          'Sharing sadness with a trusted person almost always helps. It does not need to be a long conversation — just saying out loud how you feel to someone who listens can lift a significant weight. You do not have to carry this alone.',
    ),
    MoodQA(
      // Will this sadness pass?
      keywords: ['pass', 'end', 'stop', 'last', 'long', 'temporary'],
      question: 'Will this sadness pass?',
      answer:
          'Yes. Emotions are temporary by nature — they move through us when we allow them to. Sadness that is acknowledged and expressed tends to resolve more gently than sadness that is pushed down. This will pass, even if it does not feel like it right now.',
    ),
  ],

  // ── STRUGGLING ───────────────────────────────────────────────────────────
  'Struggling': [
    MoodQA(
      // I feel overwhelmed — what do I do?
      keywords: [
        'overwhelmed',
        'overwhelm',
        'cope',
        'much',
        'handle',
        'pressure',
      ],
      question: 'I feel overwhelmed — what do I do?',
      answer:
          'When everything feels too much, the first step is to stop adding more. Put down the to-do list. Breathe slowly for one minute — in for four counts, out for six. You only need to handle the next ten minutes, not everything at once.',
    ),
    MoodQA(
      // How do I ask for help?
      keywords: ['help', 'support', 'ask', 'reach', 'someone', 'need'],
      question: 'How do I ask for help?',
      answer:
          'Asking for help is one of the bravest things you can do. You do not need to explain everything — simply saying "I am struggling and I could use some support" is enough. Most people want to help but wait to be invited in.',
    ),
    MoodQA(
      // I feel completely alone in this.
      keywords: ['alone', 'lonely', 'isolated', 'nobody', 'no one', 'myself'],
      question: 'I feel completely alone in this.',
      answer:
          'That feeling of isolation is one of the hardest parts of struggling. But you are not as alone as this moment makes you feel. Reaching out — even a short message — can break through that wall. If you have no one right now, MindMate is here with you.',
    ),
    MoodQA(
      // How do I get through this?
      keywords: ['through', 'survive', 'manage', 'forward', 'continue', 'keep'],
      question: 'How do I get through this?',
      answer:
          'One small step at a time. You do not have to solve everything today. Identify just one thing — one person to contact, one basic need to meet, one breath to take. Getting through hard times is built from very small moments of choosing to continue.',
    ),
    MoodQA(
      // Is it normal to feel this way?
      keywords: ['normal', 'common', 'others', 'everyone', 'wrong', 'strange'],
      question: 'Is it normal to feel this way?',
      answer:
          'Yes. Struggling does not mean something is fundamentally wrong with you. Many people experience periods of deep difficulty — they just rarely talk about it openly. What you are feeling is a human experience, and it does not define your future.',
    ),
  ],

  // ── ANGRY ────────────────────────────────────────────────────────────────
  'Angry': [
    MoodQA(
      // How do I calm down when I am angry?
      keywords: ['calm', 'cool', 'settle', 'down', 'relax', 'quiet'],
      question: 'How do I calm down when I am angry?',
      answer:
          'The fastest way to calm anger is to slow your breathing immediately. Breathe out longer than you breathe in — try four counts in, seven counts hold, eight counts out. This activates your nervous system\'s rest mode and physically reduces the anger response.',
    ),
    MoodQA(
      // Why am I so angry?
      keywords: ['why', 'reason', 'cause', 'triggered', 'source', 'angry'],
      question: 'Why am I so angry?',
      answer:
          'Anger is almost always a secondary emotion — underneath it is usually hurt, fear, or a sense of injustice. Ask yourself what need is not being met right now. Understanding the root cause helps you respond rather than just react.',
    ),
    MoodQA(
      // How do I express anger without causing harm?
      keywords: ['express', 'say', 'tell', 'communicate', 'confront', 'speak'],
      question: 'How do I express anger without causing harm?',
      answer:
          'Wait until the physical intensity drops before speaking. Then use "I feel" statements rather than accusations — "I feel hurt when this happens" lands differently than "you always do this." Expressing clearly and calmly is far more powerful than expressing loudly.',
    ),
    MoodQA(
      // How do I release this anger?
      keywords: ['release', 'outlet', 'discharge', 'vent', 'let', 'rid'],
      question: 'How do I release this anger?',
      answer:
          'Physical release works well — a brisk walk, running, or even scrubbing something vigorously can discharge the physical energy of anger. Journaling also helps: write exactly what you feel without filtering. You do not have to send it to anyone.',
    ),
    MoodQA(
      // I said something angry I regret — what now?
      keywords: ['regret', 'said', 'mistake', 'sorry', 'apologize', 'hurt'],
      question: 'I said something angry I regret — what now?',
      answer:
          'Acknowledging it quickly is the right move. A simple, genuine apology without over-explaining goes a long way. Say what you did, say you are sorry, and say what you will do differently. Then forgive yourself — anger is human, and so is repairing.',
    ),
  ],
};

/// Finds a matching [MoodQA] from the given mood's list based on keywords in [spokenText].
/// Returns null if no match is found.
MoodQA? findMatchingQA(String moodLabel, String spokenText) {
  final questions = moodQAMap[moodLabel];
  if (questions == null) return null;

  final lower = spokenText.toLowerCase();
  for (final qa in questions) {
    for (final keyword in qa.keywords) {
      if (lower.contains(keyword.toLowerCase())) {
        return qa;
      }
    }
  }
  return null;
}
