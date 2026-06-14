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
          'Say police, ambulance, fire and rescue, mental health hotline, or friend.',
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
        'You can say: call police, call ambulance, call fire and rescue, '
        'call mental health hotline, or call friend. Say back to return home.',
      );
    }
  }

  Future<void> _initStt() async {
    sttAvailable = await sttEngine.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        // Force full reset regardless of isProcessing
        isListening = false;
        isProcessing = false;
        statusLabel = 'Tap the mic to speak';
        notifyListeners();
      },
      onStatus: (s) {
        debugPrint(
          'STT status: $s | isListening: $isListening | isProcessing: $isProcessing',
        );
        if (s == 'done' || s == 'notListening') {
          isListening = false; // ← stop blinking immediately
          notifyListeners();
          if (!isProcessing) {
            stopListening();
          }
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
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
    isListening = false; // ← always reset UI first
    notifyListeners();

    if (isProcessing) return;
    isProcessing = true;
    await sttEngine.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    statusLabel = 'Processing…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    if (recognizedText.trim().isEmpty) {
      // Nothing was heard — skip processing, just reset
      statusLabel = 'Tap the mic to speak';
      isProcessing = false;
      notifyListeners();
      return;
    }

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
          'Say police, ambulance, fire and rescue, mental health hotline, or friend.',
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
      'You can say: call police, call ambulance, call fire and rescue, '
      'call mental health hotline, or call friend. Say back to return home.',
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
    statusLabel = 'Tap mic, then say "confirm" or "cancel"';
    notifyListeners();

    await speak(
      'Do you want me to call ${contact.title} '
      'Tap the microphone, then say confirm to call, or cancel.',
    );
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
      // Didn't catch a valid confirm/cancel — ask user to tap and try again
      statusLabel = 'Tap mic, then say "confirm" or "cancel"';
      notifyListeners();
      await speak(
        'Sorry, I didn\'t catch that. Tap the microphone and say confirm to call ${contact.title}, or cancel.',
      );
    }
  }

  @override
  void dispose() {
    tts.stop();
    sttEngine.stop();
    super.dispose();
  }
}
