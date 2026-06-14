class MoodQA {
  const MoodQA({
    required this.keywords,
    required this.question,
    required this.answer,
  });

  final List<String> keywords;
  final String question;
  final String answer;
}

const Map<String, List<MoodQA>> moodQAMap = {
  // ── GREAT ────────────────────────────────────────────────────────────────
  'Great': [
    MoodQA(
      keywords: ['keep', 'positive', 'maintain', 'hold', 'sustain'],
      question: 'How do I keep this positive feeling going?',
      answer:
          'To hold onto this feeling, take a moment to notice exactly what made today great — write it down or share it with someone. Positive emotions become more lasting when you consciously reflect on them. Do more of what created this moment.',
    ),
    MoodQA(
      keywords: ['share', 'Should', 'good mood', 'spread', 'tell', 'others'],
      question: 'Should I share this good mood with others?',
      answer:
          'Sharing joy amplifies it. Reach out to a friend or loved one — not just to say you are happy, but to make them feel included in your good day. That connection strengthens both of you.',
    ),
    MoodQA(
      keywords: [
        'How can I',
        'productive',
        'productively',
        'this energy',
        'that energy',
        'energy',
        'accomplish',
        'channel',
      ],
      question: 'How can I use this energy productively?',
      answer:
          'High-mood moments are great for tackling things you usually avoid. Use this energy for something meaningful — a creative project, a difficult conversation you have been delaying, or getting ahead on a goal that matters to you.',
    ),
    MoodQA(
      keywords: ['Will this', 'last', 'permanent', 'fade', 'forever'],
      question: 'Will this feeling last?',
      answer:
          'Feelings naturally shift, and that is okay. Rather than worrying about it ending, try to be fully present in it right now. Gratitude practices support you in returning to this kind of state more often over time.',
    ),
    MoodQA(
      keywords: [
        'How do I practise',
        'I feel great',
        'grateful',
        'gratitude',
        'thankful',
        'appreciate',
      ],
      question: 'How do I practise gratitude when I feel great?',
      answer:
          'When you feel great, gratitude goes even deeper. Take two minutes to write three specific things you are thankful for today — not general things, but exact moments. This trains your brain to notice the good more often.',
    ),
  ],

  // ── GOOD ─────────────────────────────────────────────────────────────────
  'Good': [
    MoodQA(
      keywords: [
        'even better',
        'How can I',
        'better',
        'improve',
        'boost',
        'enhance',
      ],
      question: 'How can I feel even better?',
      answer:
          'A good mood is a strong foundation. To build on it, try adding a small win to your day — a short walk, a kind message to someone, or finishing one task you have been putting off. Small actions compound into great feelings.',
    ),
    MoodQA(
      keywords: ['Why do I', 'good today', 'reason', 'cause', 'because'],
      question: 'Why do I feel good today?',
      answer:
          'Pausing to identify the source of a good mood is a powerful habit. Think about what happened differently today — enough sleep, a positive interaction, progress on something meaningful? Understanding it supports you in recreating it.',
    ),
    MoodQA(
      keywords: [
        'Can I',
        'give',
        'kind',
        'generous',
        'someone',
        'support them',
      ],
      question: 'Can I support someone else with this mood?',
      answer:
          'When you feel good, you have more emotional capacity to give. Reach out to someone who might need a kind word today. Acts of generosity deepen your own sense of wellbeing too.',
    ),
    MoodQA(
      keywords: [
        'How do I',
        'feeling good',
        'focus',
        'concentrate',
        'study',
        'work',
        'stay focused',
      ],
      question: 'How do I stay focused while feeling good?',
      answer:
          'Good moods can sometimes make us restless. Channel it with a clear intention — pick one priority for the next hour and commit to it. Short focus blocks with breaks in between work well when your energy is high.',
    ),
    MoodQA(
      keywords: [
        'Is it okay',
        'just enjoy',
        'enjoy',
        'savour',
        'slow',
        'unwind',
      ],
      question: 'Is it okay to just enjoy this feeling?',
      answer:
          'Absolutely. Enjoying a calm, good moment without forcing productivity is healthy. Give yourself full permission to simply be in this feeling without guilt. Rest is not wasted time — it is recovery.',
    ),
  ],

  // ── OKAY ─────────────────────────────────────────────────────────────────
  'Okay': [
    MoodQA(
      keywords: ['why', 'feel okay', 'normal', 'neutral', 'average'],
      question: 'Why do I just feel okay?',
      answer:
          'Feeling okay is completely normal and more common than we admit. It often means your nervous system is stable — not stressed, not elated. It can be a sign that nothing is wrong, just that today is a regular day.',
    ),
    MoodQA(
      keywords: ['better', 'How do I lift', 'improve', 'lift', 'shift'],
      question: 'How do I lift my mood from okay to better?',
      answer:
          'Small intentional actions can shift an okay day. Try stepping outside for ten minutes, listening to a song you love, or doing one thing purely for enjoyment. Do not wait to feel motivated — action creates the feeling.',
    ),
    MoodQA(
      keywords: ['I feel bored', 'bored', 'boring', 'dull', 'flat'],
      question: 'I feel bored and flat — is that okay?',
      answer:
          'Boredom and flatness are signals worth listening to. They often mean your mind is craving something new or meaningful. Try something small and different — a new route, a new recipe, or a conversation with someone unexpected.',
    ),
    MoodQA(
      keywords: [
        'How do I find',
        'motivation',
        'motivated',
        'drive',
        'purpose',
      ],
      question: 'How do I find motivation when I feel just okay?',
      answer:
          'Motivation rarely comes before action — it usually follows it. Start with the smallest possible version of a task: two minutes of movement, one paragraph of writing, one email sent. Momentum builds from tiny starts.',
    ),
    MoodQA(
      keywords: ['How do I make', 'accept', 'content', 'enough', 'ordinary'],
      question: 'How do I make peace with feeling just okay?',
      answer:
          'Not every day needs to be remarkable. Being okay is a neutral, balanced state — and balance is healthy. Contentment often lives in these quiet, unremarkable moments. Allow yourself to appreciate them.',
    ),
  ],

  // ── SAD ──────────────────────────────────────────────────────────────────
  'Sad': [
    MoodQA(
      keywords: [
        'feel sad',
        'Why do I feel',
        'why',
        'reason',
        'cause',
        'wrong',
      ],
      question: 'Why do I feel sad?',
      answer:
          'Sadness can come from loss, unmet needs, loneliness, or even tiredness. You do not always need a clear reason — sometimes the body carries emotions before the mind understands them. Being gentle with yourself right now is more important than finding an explanation.',
    ),
    MoodQA(
      keywords: ['cry', 'Is it okay', 'okay to cry', 'crying', 'tears', 'weep'],
      question: 'Is it okay to cry?',
      answer:
          'Yes, crying is one of the most natural emotional releases we have. It signals that something matters to you, and it actually helps regulate stress hormones. Let yourself cry without judging it as weakness. It takes strength to feel.',
    ),
    MoodQA(
      keywords: [
        'What can',
        'cheer',
        'heal',
        'recover',
        'feel better',
        'better',
        'lighter',
      ],
      question: 'What can ease this sadness?',
      answer:
          'Small physical actions work well when emotion feels heavy. Try drinking a glass of water, stepping outside briefly, or lying down and taking slow deep breaths. Connection also works — even a short text to someone you trust can ease sadness.',
    ),
    MoodQA(
      keywords: [
        'talk',
        'Should I talk',
        'share',
        'someone about this',
        'tell',
        'speak',
      ],
      question: 'Should I talk to someone about this?',
      answer:
          'Sharing sadness with a trusted person almost always works. It does not need to be a long conversation — just saying out loud how you feel to someone who listens can lift a significant weight. You do not have to carry this alone.',
    ),
    MoodQA(
      keywords: ['Will this', 'sadness', 'pass', 'over', 'end', 'temporary'],
      question: 'Will this sadness pass?',
      answer:
          'Yes. Emotions are temporary by nature — they move through us when we allow them to. Sadness that is acknowledged and expressed tends to resolve more gently than sadness that is pushed down. This will pass, even if it does not feel like it right now.',
    ),
  ],

  // ── STRUGGLING ───────────────────────────────────────────────────────────
  'Struggling': [
    MoodQA(
      keywords: [
        'overwhelmed',
        'I feel overwhelmed',
        'too much',
        'handle',
        'pressure',
      ],
      question: 'I feel overwhelmed — what do I do?',
      answer:
          'When everything feels too much, the first step is to stop adding more. Put down the to-do list. Breathe out slowly for a count of six. You only need to handle the next ten minutes, not everything at once.',
    ),
    MoodQA(
      keywords: ['ask', 'reach out', 'contact', 'someone', 'person', 'support'],
      question: 'How do I reach out to someone for support?',
      answer:
          'Reaching out is one of the bravest things you can do. You do not need to explain everything — simply saying "I am struggling and I could use some support" is enough. Most people want to support you but wait to be invited in.',
    ),
    MoodQA(
      keywords: [
        'I feel completely',
        'alone',
        'lonely',
        'isolated',
        'disconnected',
      ],
      question: 'I feel completely alone in this.',
      answer:
          'That feeling of isolation is one of the hardest parts of struggling. But you are not as alone as this moment makes you feel. Reaching out — even a short message — can break through that wall. MindMate is here with you right now.',
    ),
    MoodQA(
      keywords: [
        'How do I get',
        'through',
        'survive',
        'forward',
        'manage',
        'through this',
      ],
      question: 'How do I get through this?',
      answer:
          'One small step at a time. You do not have to solve everything today. Identify just one thing — one person to contact, one basic need to meet, one slow breath to take. Getting through hard times is built from very small moments of choosing to continue.',
    ),
    MoodQA(
      keywords: ['normal', 'Is it normal', 'common', 'everyone', 'strange'],
      question: 'Is it normal to feel this way?',
      answer:
          'Yes. Struggling does not mean something is fundamentally wrong with you. Many people experience periods of deep difficulty — they just rarely talk about it openly. What you are feeling is a human experience, and it does not define your future.',
    ),
  ],

  // ── ANGRY ────────────────────────────────────────────────────────────────
  'Angry': [
    MoodQA(
      keywords: [
        'cool',
        'How do I cool',
        'when I am angry',
        'down',
        'settle',
        'soothe',
      ],
      question: 'How do I cool down when I am angry?',
      answer:
          'The fastest way to reduce anger is to slow your breathing immediately. Breathe out longer than you breathe in — try four counts in, then eight counts out. This activates your nervous system\'s rest mode and physically lowers the anger response.',
    ),
    MoodQA(
      keywords: ['why', 'reason', 'Why am i', 'so angry', 'triggered', 'cause'],
      question: 'Why am I so angry?',
      answer:
          'Anger is almost always a secondary emotion — underneath it is usually hurt, fear, or a sense of injustice. Ask yourself what need is not being met right now. Understanding the root cause supports you in responding rather than just reacting.',
    ),
    MoodQA(
      keywords: ['express', 'communicate', 'say', 'tell'],
      question: 'How do I express anger without causing harm?',
      answer:
          'Wait until the physical intensity drops before speaking. Then use "I feel" statements rather than accusations — "I feel hurt when this happens" lands differently than "you always do this." Expressing clearly and calmly is far more powerful than expressing loudly.',
    ),
    MoodQA(
      keywords: [
        'How do I',
        'release',
        'this anger',
        'anger',
        'outlet',
        'vent',
      ],
      question: 'How do I release this anger?',
      answer:
          'Physical outlets work well — a brisk walk, running, or scrubbing something vigorously can discharge the energy of anger. Journaling also works: write exactly what you feel without filtering. You do not have to send it to anyone.',
    ),
    MoodQA(
      keywords: [
        'regret',
        'I said',
        'sorry',
        'what now',
        'apologize',
        'snapped',
        'something angry',
        'something',
      ],
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
