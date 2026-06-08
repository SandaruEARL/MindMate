// screens/emergency_support_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mindmate/features/emergency_support/widget/voice_mic_button_emergency_support.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/emergency_contact.dart';
import '../services/call_service.dart';
import '../services/crisis_detector.dart';

class EmergencySupportPage extends StatefulWidget {
  const EmergencySupportPage({super.key});

  @override
  State<EmergencySupportPage> createState() => _EmergencySupportPageState();
}

class _EmergencySupportPageState extends State<EmergencySupportPage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _isListening = false;
  bool _sttAvailable = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  String _statusLabel = 'Tap the mic to speak';

  EmergencyContact? _pendingCall;

  final Map<String, String> _customNumbers = {};

  String _numberFor(EmergencyContact c) =>
      _customNumbers[c.key]?.isNotEmpty == true
      ? _customNumbers[c.key]!
      : c.defaultNumber;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSavedNumbers();
    _initTts();
    _initStt();
  }

  // ── Persistent storage ────────────────────────────────────────────────────

  Future<void> _loadSavedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> loaded = {};
    for (final c in emergencyContacts) {
      final saved = prefs.getString('emergency_number_${c.key}');
      if (saved != null && saved.isNotEmpty) {
        loaded[c.key] = saved;
      }
    }
    if (mounted) setState(() => _customNumbers.addAll(loaded));
  }

  Future<void> _saveNumber(String key, String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_number_$key', number);
  }

  // ── TTS / STT ─────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await Future.delayed(const Duration(milliseconds: 400));
    await _speak(
      'You are in Emergency Support. Help is available. '
      'You can say: call mental health hotline, call emergency services, '
      'or call Friend. Say back to return home.',
    );
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        if (mounted)
          setState(() {
            _isListening = false;
            _statusLabel = 'Error. Try again.';
          });
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if (s == 'done' && _isListening && mounted) {
          _stopListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _onMicTap() async {
    if (_isListening || _isProcessing) return;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      await _speak('Speech recognition not available.');
      return;
    }
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusLabel = 'Listening…';
    });
    await _stt.listen(
      onResult: (r) {
        debugPrint('🎤 result: ${r.recognizedWords} final=${r.finalResult}');
        if (!mounted) return;
        setState(() => _recognizedText = r.recognizedWords);
        if (r.finalResult && _isListening && !_isProcessing) {
          _stopListening();
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: false,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    if (_isProcessing) return;
    _isProcessing = true;
    await _stt.stop();
    await _tts.stop();
    if (mounted)
      setState(() {
        _isListening = false;
        _statusLabel = 'Processing…';
      });
    await Future.delayed(const Duration(milliseconds: 400));
    await _handleSpeech(_recognizedText.toLowerCase().trim());
    _isProcessing = false;
  }

  // ── Speech handler ────────────────────────────────────────────────────────

  Future<void> _handleSpeech(String text) async {
    debugPrint('🎤 handleSpeech: "$text"');

    if (text.isEmpty) {
      setState(() => _statusLabel = "Didn't catch that. Try again.");
      await _speak("I didn't catch that. Please try again.");
      return;
    }

    if (_pendingCall != null) {
      await _handleConfirmation(text);
      return;
    }

    if (CrisisDetector.isBackIntent(text)) {
      await _speak('Going back to home.');
      if (mounted) Navigator.pop(context);
      return;
    }

    final callKey = CrisisDetector.detectCallIntent(text);
    if (callKey != null) {
      if (callKey == 'unknown') {
        await _speak(
          'Which contact would you like to call? '
          'Say mental health hotline, Friend, or emergency services.',
        );
        setState(() => _statusLabel = 'Which contact?');
      } else {
        final contact = emergencyContacts.firstWhere(
          (c) => c.key == callKey,
          orElse: () => emergencyContacts.first,
        );
        await _askConfirmation(contact);
      }
      return;
    }

    setState(() => _statusLabel = 'Try: "call mental health hotline"');
    await _speak(
      'You can say: call mental health hotline, call emergency services, '
      'call Friend, or back.',
    );
    if (mounted) setState(() => _statusLabel = 'Tap the mic to speak');
  }

  // ── Confirmation flow ─────────────────────────────────────────────────────

  Future<void> _askConfirmation(EmergencyContact contact) async {
    final number = _numberFor(contact);
    if (number.isEmpty) {
      setState(() => _statusLabel = 'No number set');
      await _speak(
        'No number is set for ${contact.title}. '
        'Please tap the edit icon to add a number.',
      );
      if (mounted) setState(() => _statusLabel = 'Tap the mic to speak');
      return;
    }

    setState(() {
      _pendingCall = contact;
      _statusLabel = 'Say "confirm" or "cancel"';
    });

    await _speak(
      'Do you want me to call ${contact.title} at $number? '
      'Say confirm to call, or cancel.',
    );

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: contact.color.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: contact.color.withOpacity(0.12),
                      ),
                      child: Icon(contact.icon, color: contact.color, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Call ${contact.title}?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: contact.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: contact.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            color: contact.color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            number,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: contact.color,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (ctx, setDialogState) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              size: 16,
                              color: _isListening
                                  ? contact.color
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isListening
                                  ? 'Listening for your voice…'
                                  : 'Say "confirm" or "cancel"',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isListening
                                    ? contact.color
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleConfirmation('confirm');
                            },
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Confirm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: contact.color,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleConfirmation('cancel');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: contact.color.withOpacity(0.4),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Auto-start mic after dialog appears
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted && !_isListening && !_isProcessing) {
      await _startListening();
    }
  }

  Future<void> _handleConfirmation(String text) async {
    final contact = _pendingCall!;

    // Dismiss dialog if voice triggered
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (CrisisDetector.isConfirm(text)) {
      setState(() {
        _pendingCall = null;
        _statusLabel = 'Calling…';
      });
      await _speak('Calling ${contact.title} now.');
      await Future.delayed(const Duration(milliseconds: 500));
      final success = await CallService.call(_numberFor(contact));
      if (!success && mounted) {
        await _speak('Sorry, I could not open the dialer on this device.');
        setState(() => _statusLabel = 'Tap the mic to speak');
      }
    } else if (CrisisDetector.isCancel(text)) {
      // ── Fix: just dismiss dialog, stay on this page ──
      setState(() {
        _pendingCall = null;
        _statusLabel = 'Tap the mic to speak';
      });
      await _speak('Call cancelled. I am here if you need anything.');
    } else {
      await _speak(
        'Please say confirm to call ${contact.title}, or cancel to go back.',
      );
    }
  }

  Future<void> _onContactTap(EmergencyContact contact) async {
    await _askConfirmation(contact);
  }

  // ── Edit number dialog ────────────────────────────────────────────────────

  Future<void> _editNumber(EmergencyContact contact) async {
    final controller = TextEditingController(text: _numberFor(contact));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit number — ${contact.title}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            prefixIcon: Icon(Icons.phone),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newNumber = controller.text.trim();
              // ── Fix: save to SharedPreferences ──
              setState(() => _customNumbers[contact.key] = newNumber);
              await _saveNumber(contact.key, newNumber);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'Emergency Support',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fixed: Banner ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _Banner(pendingCall: _pendingCall),
              ),

              const SizedBox(height: 16),

              // ── Fixed: Section title ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Scrollable: Contact cards only ─────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                  children: [
                    ...emergencyContacts.map(
                      (c) => _ContactCard(
                        contact: c,
                        number: _numberFor(c),
                        isPending: _pendingCall?.key == c.key,
                        onTap: () => _onContactTap(c),
                        onEdit: () => _editNumber(c),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Fixed: Mic button at bottom ────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: VoiceMicButtonEmergencySupport(
              isListening: _isListening,
              onTap: _isListening ? _stopListening : _onMicTap,
              statusLabel: _statusLabel,
              recognizedText: _isListening ? _recognizedText : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({this.pendingCall});
  final EmergencyContact? pendingCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE05C5C).withOpacity(0.85),
            const Color(0xFFE05C5C).withOpacity(0.50),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🆘  You are not alone',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pendingCall != null
                ? 'Say "confirm" to call, or "cancel" to go back.'
                : 'Help is always available. Tap a contact or use your voice.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.number,
    required this.onTap,
    required this.onEdit,
    this.isPending = false,
  });

  final EmergencyContact contact;
  final String number;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasNumber = number.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPending
              ? contact.color.withOpacity(0.15)
              : contact.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: contact.color.withOpacity(isPending ? 0.5 : 0.2),
            width: isPending ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: contact.color.withOpacity(0.18),
              child: Icon(contact.icon, color: contact.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasNumber ? number : 'Tap ✏️ to add number',
                    style: TextStyle(
                      color: hasNumber ? contact.color : cs.onSurfaceVariant,
                      fontWeight: hasNumber
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: hasNumber ? 15 : 13,
                      fontStyle: hasNumber
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                  Text(
                    contact.subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              tooltip: 'Edit number',
            ),
            if (hasNumber)
              Icon(Icons.call_rounded, color: contact.color, size: 20),
          ],
        ),
      ),
    );
  }
}
