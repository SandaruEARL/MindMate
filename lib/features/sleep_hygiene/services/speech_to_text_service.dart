// speech_to_text_service.dart
//
// Fixes in this version:
//   Fix A — post-stop settle delay
//   Fix B — error_busy retry
//   Fix C — Completer-based result
//   Fix D — dictation mode
//   Fix E — localeId removed
//   Fix F — partialResults: true
//   Fix G — listenFor 15 s, pauseFor 3 s, safety timeout 18 s
//   Fix H — error fallback returns partial
//   Fix I — forceReset(): cancels stale session + re-initialises plugin,
//            called by the notifier on every screen entry so a previous
//            session's native audio lock is fully released before TTS starts.
//   Fix J — listeners wired BEFORE listen() to eliminate the race window
//            where status 'done' fires before statusListener is assigned.

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechException implements Exception {
  final String message;
  const SpeechException(this.message);
  @override
  String toString() => 'SpeechException: $message';
}

class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialised = false;

  Future<bool> initialise() async {
    if (_isInitialised) return true;
    _isInitialised = await _speech.initialize(
      onError:  (e) => print('[STT] init error: ${e.errorMsg} permanent=${e.permanent}'),
      onStatus: (s) => print('[STT] status: $s'),
    );
    return _isInitialised;
  }

  // Fix I — hard-reset the plugin.
  // Call this at screen entry (before TTS starts) to release any native
  // audio lock left over from a previous session.
  Future<void> forceReset() async {
    try {
      // cancel() is more forceful than stop() — no async result flush
      await _speech.cancel();
    } catch (_) {}

    // Clear stale listeners so they cannot fire during the upcoming TTS phase
    _speech.statusListener = null;
    _speech.errorListener  = null;

    // Re-initialise so the plugin starts with a clean native state
    _isInitialised = false;
    _isInitialised = await _speech.initialize(
      onError:  (e) => print('[STT] init error: ${e.errorMsg} permanent=${e.permanent}'),
      onStatus: (s) => print('[STT] status: $s'),
    );
  }

  Future<String> listen() async {
    if (!_isInitialised) {
      final ok = await initialise();
      if (!ok) {
        throw const SpeechException(
            'Speech recognition not available on this device.');
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    // Fix A: give Android's audio session time to fully release
    await Future.delayed(const Duration(milliseconds: 500));

    // Fix B: retry once on error_busy
    String result = await _listenOnce();
    if (result == '__busy__') {
      await Future.delayed(const Duration(milliseconds: 600));
      result = await _listenOnce();
      if (result == '__busy__') {
        throw const SpeechException(
            'Speech recognizer is busy. Please wait a moment and try again.');
      }
    }

    if (result.isEmpty) {
      throw const SpeechException(
          'No speech detected. Please tap the mic and speak.');
    }

    return result;
  }

  Future<String> _listenOnce() async {
    final completer = Completer<String>();
    String partial  = '';
    bool   resolved = false;

    void resolve(String value) {
      if (!resolved) {
        resolved = true;
        if (!completer.isCompleted) completer.complete(value);
      }
    }

    // Fix J — wire listeners BEFORE listen() so no status event is missed
    _speech.statusListener = (status) {
      print('[STT] status: $status');
      if ((status == 'done' || status == 'notListening') && !resolved) {
        resolve(partial);
      }
    };

    _speech.errorListener = (error) {
      print('[STT] error: ${error.errorMsg} permanent=${error.permanent}');
      if (!resolved) {
        if (error.errorMsg == 'error_busy') {
          resolve('__busy__');
        } else {
          // Fix H: return whatever partial we have
          resolve(partial.isNotEmpty ? partial : '');
        }
      }
    };

    await _speech.listen(
      onResult: (result) {
        partial = result.recognizedWords;           // Fix F
        if (result.finalResult) resolve(partial);
      },
      partialResults: true,                         // Fix F
      listenFor:      const Duration(seconds: 15),  // Fix G
      pauseFor:       const Duration(seconds: 3),   // Fix G
      listenMode:     stt.ListenMode.dictation,     // Fix D
      cancelOnError:  false,
      // Fix E: no localeId — device picks its own locale
    );

    // Fix G: safety timeout
    return completer.future.timeout(
      const Duration(seconds: 18),
      onTimeout: () {
        resolve(partial);
        return partial;
      },
    );
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  // Forceful abort — used by stopListening() in the notifier
  Future<void> cancel() async {
    try { await _speech.cancel(); } catch (_) {}
    _speech.statusListener = null;
    _speech.errorListener  = null;
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialised;
}