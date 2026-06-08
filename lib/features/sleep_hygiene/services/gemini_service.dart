// gemini_service.dart
// Handles Gemini API calls for the sleep module.
//
// CALL STRATEGY — minimise free-tier usage:
//   • Only called when rule engine returns SleepIntent.unknown
//   • Conversation history capped at 6 turns (3 exchanges)
//   • maxOutputTokens: 200 → short, cheap responses
//   • System prompt locks Gemini to sleep topic only
//   • Returns plain text or one of these sentinel tokens:
//       "CRISIS"              → engine asks emergency confirmation
//       "HANDOFF:/breathing"  → engine asks breathing confirmation
//       "HANDOFF:/mindfulness"→ engine asks mindfulness confirmation
//       "HANDOFF:/mood"       → engine asks mood confirmation

// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/sleep_content.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model = 'gemini-3.1-flash-lite';
  static final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey';

  static const String _systemInstruction = '''
You are a calm, warm sleep assistant inside a mental-health app called MindMate.
Your ONLY topic is sleep hygiene and sleep wellbeing for adults aged 18-30.

STRICT RULES:
1. Reply in 1-2 SHORT sentences only. Each sentence must be complete. Never leave a sentence unfinished. Never use bullet points or lists.
2. If the user expresses any suicidal ideation, self-harm, not wanting to wake up, not wanting to breathe, wanting to disappear, wanting to die, or any crisis signal — reply ONLY with the single word: CRISIS
3. If the user clearly needs breathing exercises — reply ONLY with: HANDOFF:/breathing
4. If the user mentions stress, anxiety, feeling overwhelmed, panic, or needs mindfulness or meditation — reply ONLY with: HANDOFF:/mindfulness
5. If the user mentions mood, feelings, emotions, sadness, happiness tracking, or wants to log how they feel — reply ONLY with: HANDOFF:/mood
6. If the question is completely unrelated to sleep or mental wellbeing, reply ONLY with: "I can only help with sleep-related topics."
7. If asked who you are, reply ONLY with: "I'm your sleep assistant. Ask me about sleep tips, routines, or what to do when you can't sleep."
8. If the user says something friendly like "how are you", "I like you", "you're great", or similar, give a warm 1-sentence reply and redirect to sleep.
9. Never mention that you are an AI, Gemini, or any other model.
10. Be empathetic and direct. No filler phrases like "Great question!" or "Of course!".
''';

  final List<Map<String, dynamic>> _history = [];
  String _ageContext = '';

  Future<String> chat(String userMessage) async {
    print('[Gemini] → SENT: $userMessage');
    _history.add(_turn('user', userMessage));

    if (_history.length > 6) {
      _history.removeRange(0, _history.length - 6);
    }

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _fullSystemPrompt}
        ],
      },
      'contents': _history,
      'generationConfig': {
        'maxOutputTokens': 200,
        'temperature': 0.65,
        'topP': 0.9,
        'stopSequences': ['\n\n', '•', '-  '],
      },
      'safetySettings': [
        _safety('HARM_CATEGORY_HARASSMENT',        'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_HATE_SPEECH',       'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_DANGEROUS_CONTENT', 'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_SEXUALLY_EXPLICIT', 'BLOCK_ONLY_HIGH'),
      ],
    });

    const maxAttempts = 3;
    const retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 503 || response.statusCode == 429) {
          print('[Gemini] HTTP ${response.statusCode} on attempt ${attempt + 1}/$maxAttempts');
          if (attempt < maxAttempts - 1) {
            await Future.delayed(retryDelays[attempt]);
            continue;
          }
          return _fallback();
        }

        if (response.statusCode != 200) {
          print('[Gemini] HTTP ${response.statusCode}: ${response.body}');
          return _fallback();
        }

        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) return _fallback();

        final parts = (candidates[0]['content']?['parts'] as List?) ?? [];
        final text  = parts
            .map((p) => (p['text'] as String?) ?? '')
            .join('')
            .trim();

        if (text.isEmpty) return _fallback();

        _history.add(_turn('model', text));
        print('[Gemini] ← RECEIVED: $text');
        return text;

      } on Exception catch (e) {
        print('[Gemini] Exception on attempt ${attempt + 1}/$maxAttempts: $e');
        if (attempt < maxAttempts - 1) {
          await Future.delayed(retryDelays[attempt]);
        }
      }
    }

    return _fallback();
  }

  void injectContext({
    required String userMessage,
    required String assistantReply,
  }) {
    _history.add(_turn('user',  userMessage));
    _history.add(_turn('model', assistantReply));

    if (_history.length > 6) {
      _history.removeRange(0, _history.length - 6);
    }

    print('[Gemini] ↔ INJECTED: "$userMessage" → "$assistantReply"');
  }

  void popLast() {
    if (_history.length >= 2) {
      _history.removeRange(_history.length - 2, _history.length);
    }
  }

  void resetHistory() {
    _history.clear();
    _ageContext = '';
  }

  void setUserContext(int? age, String? issueType) {
    _ageContext = age != null
        ? SleepCorpus.ageContext(age, issueType)
        : '';
  }

  String get _fullSystemPrompt => _ageContext.isEmpty
      ? _systemInstruction
      : '$_ageContext\n\n$_systemInstruction';

  Map<String, dynamic> _turn(String role, String text) => {
    'role': role,
    'parts': [{'text': text}],
  };

  Map<String, dynamic> _safety(String category, String threshold) =>
      {'category': category, 'threshold': threshold};

  String _fallback() =>
      "I'm having a little trouble right now. "
          "Try asking about bedtime routines, screen time, or sleep tips.";
}