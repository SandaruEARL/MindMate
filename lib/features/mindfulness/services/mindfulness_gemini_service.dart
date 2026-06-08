import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// MindfulnessGeminiService provides the conversational backend for the MindMate VUI.
///
/// Speech Interface Assignment Requirements Satisfied:
/// 1. NATURAL CONVERSATION: Dynamically processes user spoken queries in a multi-turn
///    dialogue structure, avoiding rigid hardcoded paths.
/// 2. CONTEXT AWARENESS: Automatically appends the previous conversation turns
///    (up to 6 messages) to maintain flow and follow-up reference.
/// 3. EMPATHY: Guided by system instructions to deliver soothing, sensitive, and
///    compassionate responses suited for mental health support.
/// 4. PSYCHOEDUCATION: Answers general mental wellbeing questions (e.g., "what is mindfulness")
///    safely and accurately.
/// 5. MENTAL HEALTH SUPPORT: Operates in a hybrid system where safety-critical tasks
///    are hardcoded while conversational queries leverage the LLM.
class MindfulnessGeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _model = 'gemini-flash-latest';
  static final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey';

  // System prompt constraints the model to behave as a warm, concise voice assistant.
  static const String _systemInstruction = '''
You are a calm, warm, and highly empathetic mindfulness and meditation guide inside a mental-health app called MindMate.
Your topic is mindfulness, meditation, breathing exercises, relaxation, stress management, and mental wellbeing for young adults aged 18-30.

STRICT RULES:
1. Reply in 1-2 sentences maximum. Keep your reply under 45 words. Never use bullet points or lists (they do not read well over TTS).
2. If the user mentions self-harm, suicide, or wanting to die, reply ONLY with the single word: CRISIS
3. If the user wants to start a meditation session (e.g. Body Scan, Loving Kindness, Focus, Gratitude, Beginner, Mindful Observation), explain that they can choose one from the screen or say "Start [session name]" (e.g., "Start Body Scan").
4. Keep the tone warm, soothing, compassionate, and reassuring.
5. Never mention that you are an AI, Gemini, or any other model.
6. Be empathetic and direct. Do not use conversational filler phrases like "Sure thing!" or "Great question!".
''';

  // Session dialogue history for context awareness
  final List<Map<String, dynamic>> _history = [];

  /// Sends the user's message to Gemini with conversation context and returns the response.
  Future<String> generateResponse(String userMessage) async {
    print('[MindfulnessGeminiService] Sending: $userMessage');
    _history.add(_turn('user', userMessage));

    // Maintain conversation context (keep last 6 turns)
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
        'maxOutputTokens': 150,
        'temperature': 0.65,
        'topP': 0.9,
      },
      'safetySettings': [
        _safety('HARM_CATEGORY_HARASSMENT', 'BLOCK_ONLY_HIGH'),
        _safety('HARM_CATEGORY_HATE_SPEECH', 'BLOCK_ONLY_HIGH'),
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        
        print('[MindfulnessGeminiService] HTTP ERROR ${response.statusCode}: ${response.body}');
        throw Exception('Gemini API returned status code ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates returned from Gemini');
      }

      final parts = (candidates[0]['content']?['parts'] as List?) ?? [];
      final text = parts.map((p) => (p['text'] as String?) ?? '').join('').trim();

      if (text.isEmpty) {
        throw Exception('Empty text response from Gemini');
      }

      // Add model reply to history
      _history.add(_turn('model', text));
      print('[MindfulnessGeminiService] Received: $text');
      return text;
    } catch (e) {
      print('[MindfulnessGeminiService] Error calling Gemini API: $e');
      rethrow;
    }
  }

  /// Clears conversation history context.
  void resetHistory() => _history.clear();

  Map<String, dynamic> _turn(String role, String text) => {
        'role': role,
        'parts': [
          {'text': text}
        ],
      };

  Map<String, dynamic> _safety(String category, String threshold) =>
      {'category': category, 'threshold': threshold};
}
