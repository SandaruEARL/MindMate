// tts_service.dart
// Offline TTS using flutter_tts package.
//
// Fixes in this version:
//   Fix 14 (revised) — stop() no longer resolves _speakCompleter
//            directly. Instead it calls _tts.stop() and lets the
//            setCancelHandler do the resolve. This means
//            awaitCompletion() genuinely waits for the hardware
//            audio session to close, not just for the stop() call
//            to return.
//   Fix D   — post-completion settle delay (500 ms) inside
//            awaitCompletion() so the mic never opens before
//            Android has fully released the audio focus.
//   Fix E   — speak() now calls awaitCompletion() (not a bare
//            stop() + 50 ms delay) before starting a new utterance,
//            so the cancel handler always fires and resolves the old
//            completer before the new one is created. This prevents
//            double-utterance races and mid-speech interruptions.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts           = FlutterTts();
  bool             _isInitialised = false;
  VoidCallback?    _completionCallback;

  bool             _isSpeaking    = false;
  Completer<void>? _speakCompleter;

  Future<void> initialise() async {
    if (_isInitialised) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // slightly slower — calming feel
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Natural completion
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      final c = _speakCompleter;
      _speakCompleter = null;
      if (c != null && !c.isCompleted) c.complete();
      _completionCallback?.call();
    });

    // Stopped / interrupted — also signals done so the mic is never blocked
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      final c = _speakCompleter;
      _speakCompleter = null;
      if (c != null && !c.isCompleted) c.complete();
    });

    // Error — treat as done so the mic is never blocked
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      final c = _speakCompleter;
      _speakCompleter = null;
      if (c != null && !c.isCompleted) c.complete();
    });

    _isInitialised = true;
  }

  /// Speaks [text], waiting for any in-progress utterance to fully close
  /// first. Using awaitCompletion() (not a bare stop() + short delay)
  /// ensures the cancel handler has fired and _speakCompleter has resolved
  /// before the new completer is created — no double-utterance races.
  Future<void> speak(String text) async {
    if (!_isInitialised) await initialise();

    if (_isSpeaking) {
      await _tts.stop();
      // awaitCompletion() blocks until the cancel handler fires,
      // then adds the 500 ms hardware-settle so the speaker goes
      // physically quiet before the new utterance starts.
      await awaitCompletion();
    }

    _isSpeaking     = true;
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
  }

  /// Stops TTS. Does NOT resolve the completer directly — the cancel
  /// handler does that, so awaitCompletion() sees the real hardware signal.
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      // _speakCompleter will be resolved by setCancelHandler, not here.
    }
  }

  /// Waits until TTS has fully finished (or been cancelled / errored).
  ///
  /// Fix D + E: adds a 500 ms settle after the completer resolves so
  /// Android has time to fully release audio focus before the mic opens.
  /// The same settle runs when already idle, covering the case where
  /// stop() was called just before awaitCompletion().
  Future<void> awaitCompletion() async {
    if (!_isSpeaking || _speakCompleter == null) {
      // Already idle — still settle in case stop() just fired and the
      // cancel handler hasn't run yet.
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    await _speakCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _isSpeaking     = false;
        _speakCompleter = null;
      },
    );

    // Post-completion settle — lets Android release audio focus
    // so the mic never opens while the speaker is still physically vibrating.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void onComplete(VoidCallback callback) {
    _completionCallback = callback;
  }
}