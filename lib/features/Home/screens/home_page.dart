import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/Home/widgets/about_us_sheet.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../mindfulness/screens/mindfulness_page.dart';
import '../../mood_tracking/screens/mood_tracking_page.dart';
import '../../sleep_hygiene/screens/sleep_vui_screen.dart';

// ── Nav item data model ────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.keywords,
    required this.page,
    required this.speech,
  });

  final IconData icon;
  final String label;
  final Color color;
  final List<String> keywords;
  final Widget page;
  final String speech;
}

// ── Nav item definitions ───────────────────────────────────────────────────────

// Grid cards updated with vibrant colors to match the 3D image aesthetics
const _navItems = [
  _NavItem(
    icon: Icons.air,
    label: 'Breathing\nExercises',
    color: Color(0xFF3F51B5), // Cyan
    keywords: ['breath', 'relax', 'calm', 'exercise'],
    page: BreathingExercisesPage(),
    speech: 'Opening Breathing Exercises.',
  ),
  _NavItem(
    icon: Icons.bedtime_rounded,
    label: 'Sleep\nHygiene',
    color: Color(0xFF3F51B5), // Dark Blue
    keywords: ['sleep', 'rest', 'bedtime', 'hygiene', 'insomnia'],
    page: SleepVuiScreen(),
    speech: 'Opening Sleep Hygiene.',
  ),
  _NavItem(
    icon: Icons.self_improvement_rounded,
    label: 'Mindfulness\n& Meditation',
    color: Color(0xFF3F51B5), // Amber/Yellow
    keywords: ['mindful', 'meditat', 'aware', 'present'],
    page: MindfulnessPage(),
    speech: '',
  ),
  _NavItem(
    icon: Icons.mood_rounded,
    label: 'Mood\nTracking',
    color: Color(0xFF3F51B5), // Light Green
    keywords: ['mood', 'feeling', 'emotion', 'track'],
    page: MoodTrackingPage(),
    speech: 'Opening Mood Tracking.',
  ),
];

// Emergency card shown separately at the bottom
const _emergencyItem = _NavItem(
  icon: Icons.local_hospital_rounded,
  label: 'Emergency Support',
  color: Color(0xFFFF5252), // Bright Red
  keywords: ['emergency', 'crisis', 'urgent', 'support'],
  page: EmergencySupportPage(),
  speech: 'Opening Emergency Support.',
);

// ── HomePage ──────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _isListening = false;
  bool _sttAvailable = false;
  bool _isNavigating = false;
  String _recognizedText = '';
  String _statusLabel = 'Tap the mic and speak';

  @override
  void initState() {
    super.initState();
    _initStt();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await Future.delayed(const Duration(milliseconds: 600));
    await _speak(
      'Welcome to MindMate. Tap the microphone and tell me where you want to go.',
    );
  }

  Future<void> _initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) {
        debugPrint('STT error: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusLabel = 'Error. Try again.';
          });
        }
      },
      onStatus: (s) {
        debugPrint('STT status: $s');
        if ((s == 'done' || s == 'notListening') && _isListening && mounted) {
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

  Future<void> _onMicTap() =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      await _speak('Speech recognition is not available on this device.');
      return;
    }
    await _tts.stop();
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusLabel = 'Listening…';
    });
    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _recognizedText = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    if (_isNavigating) return;
    _isNavigating = true;
    await _stt.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusLabel = 'Processing…';
      });
    }
    await _navigate(_recognizedText.toLowerCase());
    _isNavigating = false;
  }

  Future<void> _navigate(String text) async {
    if (text.isEmpty) {
      setState(() => _statusLabel = "I didn't catch that. Try again.");
      await _speak("I didn't catch that. Please try again.");
      return;
    }

    final all = [..._navItems, _emergencyItem];
    final match = all.cast<_NavItem?>().firstWhere(
      (item) => item!.keywords.any(text.contains),
      orElse: () => null,
    );

    if (match != null) {
      await _pushRoute(
        label: 'Going to ${match.label.replaceAll('\n', ' ')}…',
        speech: match.speech,
        page: match.page,
      );
    } else {
      setState(() => _statusLabel = 'Not sure where to go. Try a module name.');
      await _speak(
        'I heard "$_recognizedText" but I\'m not sure where to navigate. '
        'Try saying Breathing Exercises, Sleep Hygiene, Mindfulness, '
        'Mood Tracking, or Emergency Support.',
      );
    }
  }

  Future<void> _pushRoute({
    required String label,
    required String speech,
    required Widget page,
  }) async {
    if (!mounted) return;
    setState(() => _statusLabel = label);
    if (speech.isNotEmpty) {
      await _speak(speech);
    }
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      await _speak('You are back on the home page.');
      if (mounted) setState(() => _statusLabel = 'Tap the mic and speak');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build grid rows: pairs of items, last row fills remaining slot with SizedBox
    final rows = <Widget>[];
    for (var i = 0; i < _navItems.length; i += 2) {
      final left = _navItems[i];
      final right = i + 1 < _navItems.length ? _navItems[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _NavCard3D(
                  item: left,
                  onTap: () => _pushRoute(
                    label: 'Going to ${left.label.replaceAll('\n', ' ')}…',
                    speech: left.speech,
                    page: left.page,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              right != null
                  ? Expanded(
                      child: _NavCard3D(
                        item: right,
                        onTap: () => _pushRoute(
                          label:
                              'Going to ${right.label.replaceAll('\n', ' ')}…',
                          speech: right.speech,
                          page: right.page,
                        ),
                      ),
                    )
                  : const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < _navItems.length) rows.add(const SizedBox(height: 14));
    }

    final e = _emergencyItem;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MindMate',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3F51B5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your voice-guided companion',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => showAboutUsSheet(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Color(0xFF3F51B5),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.groups_rounded, size: 24),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 2-column grid
                    ...rows,

                    const SizedBox(height: 14),

                    // Emergency card (3D Style)
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: _NavCard3D(
                          item: e,
                          isWide:
                              true, // adjust icon/text size for the wider button
                          onTap: () => _pushRoute(
                            label: 'Going to Emergency Support…',
                            speech: e.speech,
                            page: e.page,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Fixed mic button at bottom ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: VoiceMicButton(
                isListening: _isListening,
                onTap: _onMicTap,
                statusLabel: _statusLabel,
                recognizedText: _recognizedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── NavCard3D (Animated 3D Push Button) ───────────────────────────────────────

class _NavCard3D extends StatefulWidget {
  const _NavCard3D({
    required this.item,
    required this.onTap,
    this.isWide = false,
  });

  final _NavItem item;
  final VoidCallback onTap;
  final bool isWide;

  @override
  State<_NavCard3D> createState() => _NavCard3DState();
}

class _NavCard3DState extends State<_NavCard3D> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.item.color;

    // Calculates a darker color automatically to act as the 3D bottom edge shadow
    final hsl = HSLColor.fromColor(color);
    final shadowColor = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        // Ensure there's space beneath so the hard shadow is not clipped
        padding: const EdgeInsets.only(bottom: 6.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          // Translate down when pressed to simulate physics
          transform: Matrix4.translationValues(0, _isPressed ? 6.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isPressed
                ? [] // Shadow disappears when pressed flat
                : [
                    BoxShadow(
                      color: shadowColor,
                      offset: const Offset(0, 6), // Hard unblurred drop shadow
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                color: Colors.white,
                size: widget.isWide ? 28 : 32,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.item.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.isWide ? 14 : 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
