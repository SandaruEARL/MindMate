// mindfulness_gemini_service.dart
// Handles Gemini API calls for the mindfulness module.
//
// CALL STRATEGY — minimize free-tier usage:
//   • Only called when rule-based match is not found
//   • Conversation history capped at 6 turns (3 exchanges)
//   • maxOutputTokens: 150 -> short, cheap responses
//   • System prompt locks Gemini to mindfulness and wellbeing
//   • Returns plain text or "CRISIS" sentinel token

// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MindfulnessGeminiService {
  // ── Configuration ─────────────────────────────────────────────
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model   = 'gemini-2.5-flash';
  static final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey';

  // ── System prompt (sent on every call, but response is short) ─
  static const String _systemInstruction = '''
You are a calm, warm, and highly empathetic mindfulness and meditation guide inside a mental-health app called MindMate.
Your topic is mindfulness, meditation, breathing exercises, relaxation, stress management, and mental wellbeing for young adults aged 18-30.

STRICT RULES:
1. Reply in 1-2 sentences maximum. Keep your reply under 45 words. Never use bullet points or lists.
2. If the user mentions self-harm, suicide, or wanting to die, reply ONLY with the single word: CRISIS
3. If the user wants to start a meditation session (e.g. Body Scan, Loving Kindness, Focus, Gratitude, Beginner, Mindful Observation), explain that they can choose one from the screen or say "Start [session name]" (e.g., "Start Body Scan").
4. Keep the tone warm, soothing, compassionate, and reassuring.
5. Never mention that you are an AI, Gemini, or any other model.
6. Be empathetic and direct. Do not use conversational filler phrases like "Sure thing!" or "Great question!".
''';

  // ── Conversation history (kept small to save tokens) ──────────
  final List<Map<String, dynamic>> _history = [];

  // ── Public API ─────────────────────────────────────────────────

  /// Send [userMessage] to Gemini and return its reply.
  /// Returns plain text, or "CRISIS".
  /// Never throws — returns a safe fallback string on any error.
  Future<String> chat(String userMessage) async {
    // Append user turn
    print('[Mindfulness Gemini] → SENT: $userMessage');
    _history.add(_turn('user', userMessage));

    // Keep at most 6 turns (3 user + 3 model) to minimize token cost
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
        'maxOutputTokens': 150,   // hard cap
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
        print('[Mindfulness Gemini] HTTP ${response.statusCode}: ${response.body}');
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
      print('[Mindfulness Gemini] ← RECEIVED: $text');

      return text;
    } on Exception catch (e) {
      print('[Mindfulness Gemini] Exception: $e');
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
      "I'm here to support you. Would you like to start one of our guided meditations, or focus on your breathing?";
}
