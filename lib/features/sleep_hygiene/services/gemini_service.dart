// gemini_service.dart
// Handles Gemini API calls for the sleep module.
//
// CALL STRATEGY — minimise free-tier usage:
//   • Only called when rule engine returns SleepIntent.unknown
//   • Conversation history capped at 6 turns (3 exchanges)
//   • maxOutputTokens: 80  → short, cheap responses
//   • System prompt locks Gemini to sleep topic only
//   • Returns plain text or one of two sentinel tokens:
//       "CRISIS"          → engine routes to crisis screen
//       "HANDOFF:/route"  → engine routes to another module

// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // ── Configuration ─────────────────────────────────────────────
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model   = 'gemini-2.5-flash';
  static final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey';

  // ── System prompt (sent on every call, but response is short) ─
  static const String _systemInstruction = '''
You are a calm, warm sleep assistant inside a mental-health app called MindMate.
Your ONLY topic is sleep hygiene and sleep wellbeing for adults aged 18-30.

STRICT RULES:
1. Reply in 1-2 sentences maximum. Never use bullet points or lists.
2. If the user mentions self-harm, suicide, or not wanting to wake up, reply ONLY with the single word: CRISIS
3. If the user clearly needs breathing exercises or guided meditation, reply ONLY with: HANDOFF:/breathing or HANDOFF:/meditation
4. If the question is completely unrelated to sleep or mental wellbeing, reply ONLY with: "I can only help with sleep-related topics."
5. If asked who you are, reply ONLY with: "I'm your sleep assistant. Ask me about sleep tips, routines, or what to do when you can't sleep."
6. If the user says something friendly like "how are you", "I like you", "you're great", or similar, give a warm 1-sentence reply and redirect to sleep. Example: "Thanks, that's kind! What sleep question can I help you with tonight?"
7. Never mention that you are an AI, Gemini, or any other model.
8. Be empathetic and direct. No filler phrases like "Great question!" or "Of course!".
''';

  // ── Conversation history (kept small to save tokens) ──────────
  // Each entry: { 'role': 'user'|'model', 'parts': [{'text': '...'}] }
  final List<Map<String, dynamic>> _history = [];

  // ── Public API ─────────────────────────────────────────────────

  /// Send [userMessage] to Gemini and return its reply.
  /// Returns plain text, "CRISIS", or "HANDOFF:/route".
  /// Never throws — returns a safe fallback string on any error.
  Future<String> chat(String userMessage) async {
    // Append user turn
    print('[Gemini] → SENT: $userMessage');
    _history.add(_turn('user', userMessage));

    // Keep at most 6 turns (3 user + 3 model) to minimise token cost
    if (_history.length > 6) {
      _history.removeRange(0, _history.length - 6);
    }

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ],
      },
      'contents': _history,
      'generationConfig': {
        'maxOutputTokens': 150,   // hard cap — keeps cost low
        'temperature':    0.65,
        'topP':           0.9,
        'stopSequences':  [],
      },
      'safetySettings': [
        _safety('HARM_CATEGORY_HARASSMENT',        'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_HATE_SPEECH',       'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_DANGEROUS_CONTENT', 'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_SEXUALLY_EXPLICIT', 'BLOCK_ONLY_HIGH'),
      ],
    });

    try {
      final response = await http
          .post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      )
          .timeout(const Duration(seconds: 12));

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

      // Store model reply in history for context on next call
      _history.add(_turn('model', text));
      print('[Gemini] ← RECEIVED: $text');

      return text;
    } on Exception catch (e) {
      print('[Gemini] Exception: $e');
      return _fallback();
    }
  }

  /// Clear conversation history — call when the module is exited.
  void resetHistory() => _history.clear();

  // ── Helpers ───────────────────────────────────────────────────

  Map<String, dynamic> _turn(String role, String text) => {
    'role': role,
    'parts': [
      {'text': text}
    ],
  };

  Map<String, dynamic> _safety(String category, String threshold) =>
      {'category': category, 'threshold': threshold};

  String _fallback() =>
      "I'm having a little trouble right now. "
          "Try asking about bedtime routines, screen time, or sleep tips.";

}