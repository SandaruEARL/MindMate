// speech_to_text_service.dart
//
// Fixes in this version:
//   Fix A — post-stop settle delay: waits 500 ms after stop() before
//            calling listen() so Android's speech recognizer fully
//            releases its audio session. Primary guard against
//            error_busy and TTS echo transcription.
//   Fix B — error_busy retry: if _listenOnce() returns '__busy__' it
//            waits another 500 ms and retries once before throwing.
//   Fix C — Completer-based result: replaces the racy polling loop
//            with a Completer<String> resolved by whichever fires
//            first: finalResult, status done/notListening, or error.
//   Fix D — dictation mode replaces confirmation mode: streams results
//            continuously and finalises naturally with full sentences
//            instead of waiting for a deliberate command-style pause.
//   Fix E — localeId removed: lets the device use its own locale so
//            non-US accents are recognised accurately.
//   Fix F — partialResults: true keeps the partial buffer fresh
//            throughout so the timeout fallback returns the full
//            recognised text seen so far, not just the last chunk.
//   Fix G — listenFor raised to 15 s, pauseFor to 3 s: covers longer
//            sleep-related sentences and tolerates natural in-sentence
//            pauses without premature cutoff. Safety timeout raised to
//            18 s to match.
//   Fix H — error fallback returns partial (not '') so any words
//            already recognised are not thrown away on a non-busy error.

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
      onError: (error) {
        // ignore: avoid_print
        print('[STT] init error: ${error.errorMsg} permanent=${error.permanent}');
      },
      onStatus: (status) {
        // ignore: avoid_print
        print('[STT] status: $status');
      },
    );
    return _isInitialised;
  }

  Future<String> listen() async {
    if (!_isInitialised) {
      final ok = await initialise();
      if (!ok) {
        throw const SpeechException(
            'Speech recognition not available on this device.');
      }
    }

    // Ensure any previous session is fully stopped before starting a new one
    if (_speech.isListening) {
      await _speech.stop();
    }

    // Fix A: give Android's speech engine time to fully release audio focus.
    // 500 ms covers mid-range Android hardware and physical speaker ring-off
    // that causes echo transcription of the previous TTS utterance.
    await Future.delayed(const Duration(milliseconds: 500));

    // Fix B: retry once on error_busy with a longer back-off
    String result = await _listenOnce();
    if (result == '__busy__') {
      await Future.delayed(const Duration(milliseconds: 500));
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

  // Fix C + D + E + F + G + H: improved single listen attempt.
  // Returns '__busy__' on error_busy so the caller can retry.
  // Returns ''         only when truly nothing was heard.
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

    await _speech.listen(
      onResult: (result) {
        // Fix F: keep partial fresh on every callback
        partial = result.recognizedWords;
        if (result.finalResult) resolve(partial);
      },
      // Fix F: partialResults keeps the buffer updated between callbacks
      partialResults: true,
      // Fix G: longer window for natural sleep-topic sentences
      listenFor:      const Duration(seconds: 15),
      pauseFor:       const Duration(seconds: 3),
      // Fix D: dictation streams continuously — correct mode for sentences
      listenMode:     stt.ListenMode.dictation,
      // Fix E: no localeId — device picks its own locale for best accuracy
      cancelOnError:  false,
    );

    // Status changes drive completion when onResult doesn't fire a final.
    // Assigned after listen() to avoid overwriting the package's own handler.
    _speech.statusListener = (status) {
      // ignore: avoid_print
      print('[STT] status: $status');
      if ((status == 'done' || status == 'notListening') && !resolved) {
        resolve(partial);
      }
    };

    // Error handler — surfaces busy vs other errors
    _speech.errorListener = (error) {
      // ignore: avoid_print
      print('[STT] error: ${error.errorMsg} permanent=${error.permanent}');
      if (!resolved) {
        if (error.errorMsg == 'error_busy') {
          resolve('__busy__');
        } else {
          // Fix H: return whatever partial we have — don't discard recognised words
          resolve(partial.isNotEmpty ? partial : '');
        }
      }
    };

    // Fix G: safety timeout — 18 s covers listenFor + pauseFor + margin
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

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialised;
}