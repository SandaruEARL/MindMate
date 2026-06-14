import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/emergency_contact.dart';
import '../services/call_service.dart';
import '../services/crisis_detector.dart';

/// EmergencySupportController manages the Voice User Interface (VUI) for Emergency Support.
/// It strictly follows the Rule-Based Spoken Language System Architecture:
/// 1. User Input -> 2. NLU -> 3. Intent -> 4. Dialogue Manager -> 5. Response
class EmergencySupportController extends ChangeNotifier {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText sttEngine = stt.SpeechToText();

  // ── Exposed State ──
  bool isListening = false;
  bool sttAvailable = false;
  bool isProcessing = false;
  String recognizedText = '';
  String statusLabel = 'Tap the mic to speak';

  EmergencyContact? pendingCall;
  final Map<String, String> customNumbers = {};

  BuildContext? _context;
  void attachContext(BuildContext ctx) => _context = ctx;

  String numberFor(EmergencyContact c) =>
      customNumbers[c.key]?.isNotEmpty == true
      ? customNumbers[c.key]!
      : c.defaultNumber;

  // ── Initialization ──

  Future<void> init([String? initialCallKey]) async {
    await _loadSavedNumbers();
    await _initTts(skipWelcome: initialCallKey != null);
    await _initStt();

    if (initialCallKey != null) {
      if (initialCallKey == 'unknown') {
        statusLabel = 'Which contact?';
        notifyListeners();
        await speak(
          'Which contact would you like to call? '
          'Say mental health hotline, Friend, or emergency services.',
        );
      } else {
        final contact = emergencyContacts.firstWhere(
          (c) => c.key == initialCallKey,
          orElse: () => emergencyContacts.first,
        );
        onContactTap(contact);
      }
    }
  }

  Future<void> _loadSavedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in emergencyContacts) {
      final saved = prefs.getString('emergency_number_${c.key}');
      if (saved != null && saved.isNotEmpty) {
        customNumbers[c.key] = saved;
      }
    }
    notifyListeners();
  }

  Future<void> saveNumber(String key, String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_number_$key', number);
    customNumbers[key] = number;
    notifyListeners();
  }

  Future<void> _initTts({bool skipWelcome = false}) async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    if (!skipWelcome) {
      await Future.delayed(const Duration(milliseconds: 400));
      await speak(
        'You are in Emergency Support. Help is available. '
        'You can say: call mental health hotline, call emergency services, '
        'or call Friend. Say back to return home.',
      );
    }
  }

  Future<void> _initStt() async {
    sttAvailable = await sttEngine.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        isListening = false;
        statusLabel = 'Error. Try again.';
        notifyListeners();
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if (s == 'done' && isListening) {
          stopListening();
        }
      },
    );
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await tts.stop();

    final completer = Completer<void>();
    tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    tts.setCancelHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    tts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.complete();
    });

    await tts.speak(text);
    await completer.future;
  }

  // ── Spoken Language System Pipeline ──

  // 1. USER INPUT (Speech-to-Text)
  Future<void> onMicTap() async {
    if (isListening || isProcessing) return;
    await startListening();
  }

  Future<void> startListening() async {
    if (!sttAvailable) {
      await speak('Speech recognition not available.');
      return;
    }

    if (sttEngine.isListening) {
      await sttEngine.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await tts.stop();
    await Future.delayed(
      const Duration(milliseconds: 300),
    ); // buffer after TTS release
    isListening = true;
    recognizedText = '';
    statusLabel = 'Listening…';
    notifyListeners();

    await sttEngine.listen(
      onResult: (r) {
        recognizedText = r.recognizedWords;
        notifyListeners();
        if (r.finalResult && isListening && !isProcessing) {
          stopListening();
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
    if (isProcessing) return;
    isProcessing = true;
    await sttEngine.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    isListening = false;
    statusLabel = 'Processing…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    await _handleVoiceCommand(recognizedText.toLowerCase().trim());
    isProcessing = false;
    notifyListeners();
  }

  // 2. NLU (Pattern Matching via CrisisDetector)
  // 3. INTENT (Categorization)
  // 4. DIALOGUE MANAGER (Routing logic)
  Future<void> _handleVoiceCommand(String text) async {
    if (text.isEmpty) {
      statusLabel = "Didn't catch that. Try again.";
      notifyListeners();
      await speak("I didn't catch that. Please try again.");
      return;
    }

    // Contextual Routing: If we are already awaiting confirmation
    if (pendingCall != null) {
      await handleConfirmation(text);
      return;
    }

    // NLU & Intent: Check for "Back" intent
    if (CrisisDetector.isBackIntent(text)) {
      await speak('Going back to home.');
      if (_context != null && _context!.mounted) Navigator.pop(_context!);
      return;
    }

    // NLU & Intent: Check for "Call" intent
    final callKey = CrisisDetector.detectCallIntent(text);

    // Dialogue Manager: Act on Intent
    if (callKey != null) {
      if (callKey == 'unknown') {
        // 5. RESPONSE
        statusLabel = 'Which contact?';
        notifyListeners();
        await speak(
          'Which contact would you like to call? '
          'Say mental health hotline, Friend, or emergency services.',
        );
      } else {
        // 5. RESPONSE (Trigger confirmation flow)
        final contact = emergencyContacts.firstWhere(
          (c) => c.key == callKey,
          orElse: () => emergencyContacts.first,
        );
        onContactTap(contact);
      }
      return;
    }

    // Default Fallback
    statusLabel = 'Try: "call mental health hotline"';
    notifyListeners();
    await speak(
      'You can say: call mental health hotline, call emergency services, '
      'call Friend, or back.',
    );
    statusLabel = 'Tap the mic to speak';
    notifyListeners();
  }

  // ── Confirmation Flow (Dialogue State: Awaiting Confirmation) ──

  void onContactTap(EmergencyContact contact) {
    askConfirmation(contact);
  }

  Future<void> askConfirmation(EmergencyContact contact) async {
    final number = numberFor(contact);
    if (number.isEmpty) {
      statusLabel = 'No number set';
      notifyListeners();
      await speak(
        'No number is set for ${contact.title}. '
        'Please tap the edit icon to add a number.',
      );
      statusLabel = 'Tap the mic to speak';
      notifyListeners();
      return;
    }

    pendingCall = contact;
    statusLabel = 'Say "confirm" or "cancel"';
    notifyListeners();

    await speak(
      'Do you want me to call ${contact.title} at $number? '
      'Say confirm to call, or cancel.',
    );

    // Auto-start mic for confirmation
    await Future.delayed(const Duration(milliseconds: 400));
    if (!isListening && !isProcessing) {
      await startListening();
    }
  }

  Future<void> handleConfirmation(String text) async {
    final contact = pendingCall!;

    if (CrisisDetector.isConfirm(text)) {
      pendingCall = null;
      statusLabel = 'Calling…';
      notifyListeners();

      await speak('Calling ${contact.title} now.');
      await Future.delayed(const Duration(milliseconds: 500));
      final success = await CallService.call(numberFor(contact));
      if (!success) {
        await speak('Sorry, I could not open the dialer on this device.');
        statusLabel = 'Tap the mic to speak';
        notifyListeners();
      }
    } else if (CrisisDetector.isCancel(text)) {
      pendingCall = null;
      statusLabel = 'Tap the mic to speak';
      notifyListeners();
      await speak('Call cancelled. I am here if you need anything.');
    } else {
      // Didn't catch a valid confirm/cancel — re-prompt and listen again
      statusLabel = 'Say "confirm" or "cancel"';
      notifyListeners();
      await speak(
        'Sorry, I didn\'t catch that. Please say confirm to call ${contact.title}, or cancel.',
      );

      await Future.delayed(const Duration(milliseconds: 400));
      if (!isListening && !isProcessing) {
        await startListening();
      }
    }
  }

  @override
  void dispose() {
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
