import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ── Preset questions per mood ─────────────────────────────────────────────────

const Map<String, List<String>> _presetQuestions = {
  'Great': [
    "Something good is happening — what's lighting you up today?",
    "Is there a person or moment behind that feeling?",
  ],
  'Good': [
    "Good is worth pausing on. What's been going right?",
    "Anything on your mind that you'd like to just talk through?",
  ],
  'Okay': [
    "Okay can mean a lot of things. What's your day actually been like?",
    "Is there something quietly weighing on you, even a little?",
    "How have you been sleeping lately?",
  ],
  'Sad': [
    "I'm glad you're here. Can you tell me what's been going on?",
    "How long have you been carrying this feeling?",
    "Is there one thing that's hurting the most right now?",
  ],
  'Struggling': [
    "Thank you for being honest about that. What's been the hardest part?",
    "Has something specific happened, or has it been building for a while?",
    "Is there anyone in your life who knows you're going through this?",
  ],
};

// ── Preset Q&A model ──────────────────────────────────────────────────────────

class _PresetQA {
  _PresetQA({required this.question, required this.answer});
  final String question;
  final String answer;
}

// ── MoodGeminiService ─────────────────────────────────────────────────────────

class MoodGeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model = 'gemini-2.5-flash-lite';
  static final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey';

  final List<Map<String, dynamic>> _history = [];
  final List<_PresetQA> _collectedAnswers = [];

  String _currentMoodLabel = '';
  List<String> _presetQList = [];
  int _presetIndex = 0;
  bool _presetPhase = true;
  bool _conversationEnded = false;
  int _geminiTurnCount = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  bool get isPresetPhase => _presetPhase;
  bool get isConversationEnded => _conversationEnded;
  int get totalPresetQuestions => _presetQList.length;
  int get currentPresetIndex => _presetIndex;

  // ── Public API ────────────────────────────────────────────────────────────

  String startSession(String moodLabel) {
    _currentMoodLabel = moodLabel;
    _history.clear();
    _collectedAnswers.clear();
    _presetQList = List<String>.from(
      _presetQuestions[moodLabel] ??
          [
            "Tell me what's going on for you right now.",
            "What's been weighing on your mind lately?",
          ],
    );
    _presetIndex = 0;
    _presetPhase = true;
    _conversationEnded = false;
    _geminiTurnCount = 0;
    return _presetQList.first;
  }

  Future<String> chat(String userMessage) async {
    if (_presetPhase) return _handlePresetAnswer(userMessage);
    if (_conversationEnded) return "I'm always here. Take care of yourself.";
    return await _sendToGemini(userMessage);
  }

  void resetSession() {
    _history.clear();
    _collectedAnswers.clear();
    _currentMoodLabel = '';
    _presetQList = [];
    _presetIndex = 0;
    _presetPhase = true;
    _conversationEnded = false;
    _geminiTurnCount = 0;
  }

  // ── Preset phase ──────────────────────────────────────────────────────────

  Future<String> _handlePresetAnswer(String userAnswer) async {
    _collectedAnswers.add(
      _PresetQA(question: _presetQList[_presetIndex], answer: userAnswer),
    );
    _presetIndex++;

    if (_presetIndex < _presetQList.length) {
      return _presetQList[_presetIndex];
    }

    // All presets done — build context and hand off to Gemini
    _presetPhase = false;
    _buildInitialHistory();
    return await _sendToGemini('Please respond based on what I shared.');
  }

  void _buildInitialHistory() {
    final buffer = StringBuffer();
    buffer.writeln('Mood: $_currentMoodLabel\n');
    for (final qa in _collectedAnswers) {
      buffer.writeln('Q: ${qa.question}');
      buffer.writeln('A: ${qa.answer}\n');
    }

    _history.add(_turn('user', buffer.toString().trim()));
    _history.add(
      _turn('model', 'I hear you. Thank you for sharing that with me.'),
    );
  }

  // ── Gemini API call ───────────────────────────────────────────────────────

  Future<String> _sendToGemini(String userMessage) async {
    _geminiTurnCount++;
    _history.add(_turn('user', userMessage));

    // Keep history lean
    if (_history.length > 10) {
      final priming = _history.take(2).toList();
      final recent = _history.skip(_history.length - 8).toList();
      _history
        ..clear()
        ..addAll(priming)
        ..addAll(recent);
    }

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _buildSystemPrompt(_geminiTurnCount)},
        ],
      },
      'contents': _history,
      'generationConfig': {
        'maxOutputTokens': 180,
        'temperature': 0.75,
        'topP': 0.90,
      },
      'safetySettings': [
        _safety('HARM_CATEGORY_HARASSMENT', 'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_DANGEROUS_CONTENT', 'BLOCK_ONLY_HIGH'),
      ],
    });

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return _fallback();

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return _fallback();

      final parts = (candidates[0]?['content']?['parts'] as List?) ?? [];
      final rawText = parts
          .map((p) => (p['text'] as String?) ?? '')
          .join('')
          .trim();
      if (rawText.isEmpty) return _fallback();

      // ── Sentinel detection ──────────────────────────────────────────────
      final upper = rawText.trim().toUpperCase();

      if (upper.startsWith('CRISIS')) {
        _history.add(_turn('model', 'CRISIS'));
        return 'CRISIS';
      }

      if (upper.startsWith('HANDOFF:/BREATHING')) {
        _history.add(_turn('model', 'HANDOFF:/breathing'));
        return 'HANDOFF:/breathing';
      }

      if (upper.startsWith('END:')) {
        final closing = _stripMarkdown(
          rawText.substring(rawText.indexOf(':') + 1).trim(),
        );
        _history.add(_turn('model', closing));
        _conversationEnded = true;
        return closing;
      }

      final cleaned = _stripMarkdown(rawText);
      _history.add(_turn('model', cleaned));
      return cleaned;
    } on Exception {
      return _fallback();
    }
  }

  // ── System prompt ─────────────────────────────────────────────────────────

  String _buildSystemPrompt(int turn) {
    final urgency = switch (turn) {
      1 =>
        '''
Turn 1: You just received the user's check-in answers. 
Pick the sharpest, most specific problem they mentioned. Acknowledge it in ONE sentence (no therapy-speak like "that's a lot to carry" or "it makes sense that"). Ask ONE practical question to understand it better.
Example acknowledgement style: "Exams in 2 weeks with no study plan yet — that's a real crunch." NOT "That sounds really stressful."
''',
      2 =>
        '''
Turn 2: You now have enough context. DO NOT ask more questions.
Give 2-3 concrete, specific actions they can take TODAY or THIS WEEK for their exact situation. Be direct like a smart friend, not a counsellor.
Then end warmly with: END: [your full message including the advice]
If the user asks "what should I do" or "what do I do now" — answer directly. Do not reflect the question back.
''',
      _ =>
        '''
You have enough context. Give direct, practical advice NOW. Do not ask questions.
End immediately with: END: [closing message with advice]
''',
    };

    return '''
You are MindMate — a smart, caring friend. NOT a therapist. NOT a counsellor.

The difference: a friend gives you real, direct advice. A therapist reflects your feelings back at you. You are the friend.

BANNED phrases (never say these):
- "That's a lot to carry"
- "It makes sense that you feel"  
- "I can understand why"
- "It sounds like"
- "It seems like"
- "That must be hard"
- Any sentence that just mirrors what they said back at them

INSTEAD — be specific and direct:
- "Okay, 2 weeks, 5 subjects — here's what I'd do."
- "The real issue here is X. Try this:"
- "Stop doing Y, start doing Z — here's why."

Rules:
- Max 10 sentences per reply.
- At most ONE question per reply, only if you genuinely need more info.
- If they ask "what do I do" or "what should I do" → answer immediately with specific steps. Never say "it makes sense that you're asking."
- If they mention suicide or self-harm → reply only: CRISIS
- If breathing would help → reply only: HANDOFF:/breathing

$urgency''';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _stripMarkdown(String text) => text
      .replaceAll(RegExp(r'\*{1,3}'), '')
      .replaceAll(RegExp(r'_{1,3}'), '')
      .replaceAll(RegExp(r'#+\s*'), '')
      .replaceAll(RegExp(r'`+'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  Map<String, dynamic> _turn(String role, String text) => {
    'role': role,
    'parts': [
      {'text': text},
    ],
  };

  Map<String, dynamic> _safety(String category, String threshold) => {
    'category': category,
    'threshold': threshold,
  };

  String _fallback() =>
      "I'm right here with you. Take a slow breath — you don't have to have it all figured out.";
}
