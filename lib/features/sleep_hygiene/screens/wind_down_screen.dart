// wind_down_screen.dart
//
// A 4-step guided wind-down routine.
// Auto-advances through each step, narrates via TTS, and shows a
// circular countdown so the user always knows how long each step lasts.
//
// Usage (from SleepController):
//
//   Navigator.push(
//     _context!,
//     PageRouteBuilder(
//       pageBuilder: (_, __, ___) =>
//           WindDownScreen(ttsService: ttsService),
//       transitionsBuilder: (_, anim, __, child) =>
//           FadeTransition(opacity: anim, child: child),
//       transitionDuration: const Duration(milliseconds: 600),
//     ),
//   );

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/tts_service.dart';

// ── Step model ─────────────────────────────────────────────────────────────────

class _Step {
  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.durationSeconds,
    required this.narration,
  });
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  final int      durationSeconds;
  final String   narration;
}

const _kSteps = [
  _Step(
    icon:            Icons.lightbulb_outline_rounded,
    color:           Color(0xFFFFB300),
    title:           'Dim the lights',
    subtitle:        'Reduce brightness around you. Soft light tells your brain that sleep is near.',
    durationSeconds: 180,
    narration:       'Step one. Dim the lights around you. Soft light signals your brain that sleep is near. Take your time.',
  ),
  _Step(
    icon:            Icons.smartphone_rounded,
    color:           Color(0xFF5C6BC0),
    title:           'Put screens away',
    subtitle:        'Set your phone face-down. Blue light blocks melatonin for up to an hour.',
    durationSeconds: 120,
    narration:       'Step two. Put your screens away. Blue light suppresses melatonin and keeps your mind alert.',
  ),
  _Step(
    icon:            Icons.menu_book_rounded,
    color:           Color(0xFF26A69A),
    title:           'Unwind gently',
    subtitle:        'Read a book, stretch lightly, or take a warm shower.',
    durationSeconds: 120,
    narration:       'Step three. Do something gentle and screen-free. Light reading, stretching, or a warm shower all help your body shift into sleep mode.',
  ),
  _Step(
    icon:            Icons.air_rounded,
    color:           Color(0xFF42A5F5),
    title:           'Breathe slowly',
    subtitle:        'In for 4s - Hold 7s - Out for 8s. Repeat until calm.',
    durationSeconds: 60,
    narration:       'Final step. Breathe slowly. In for four, hold for seven, out for eight. Repeat until your body feels ready to sleep.',
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key, required this.ttsService});
  final TtsService ttsService;

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen>
    with TickerProviderStateMixin {

  static const Color _accent = Color(0xFF3F51B5);
  static const Color _bg     = Color(0xFFEEF0FB);

  int  _stepIndex   = 0;
  int  _secondsLeft = _kSteps[0].durationSeconds;
  bool _isDone      = false;

  Timer?                  _timer;
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  _Step get _step => _kSteps[_stepIndex];

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync:    this,
      duration: Duration(seconds: _step.durationSeconds),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startTimer();
    _narrate();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _advanceStep();
      }
    });
  }

  Future<void> _narrate() async {
    await widget.ttsService.speak(_step.narration);
  }

  // ── Step advance ───────────────────────────────────────────────────────────

  void _advanceStep() {
    _timer?.cancel();
    if (_stepIndex < _kSteps.length - 1) {
      setState(() {
        _stepIndex++;
        _secondsLeft           = _step.durationSeconds;
        _ringCtrl.duration     = Duration(seconds: _step.durationSeconds);
        _ringCtrl.reset();
        _ringCtrl.forward();
      });
      _narrate();
      _startTimer();
    } else {
      setState(() => _isDone = true);
      widget.ttsService.speak(
        'Well done. Your wind-down is complete. '
            'Get into bed and let sleep come naturally.',
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '${m}m ${r.toString().padLeft(2, '0')}s' : '${s}s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    widget.ttsService.stop();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _BlobBg(color: _step.color),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStepDots(),
                const SizedBox(height: 8),
                _isDone ? _buildDone() : _buildActiveStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              widget.ttsService.stop();
              Navigator.pop(context);
            },
            style: IconButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape:           const CircleBorder(),
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
          const SizedBox(width: 16),
          const Text(
            'Bedtime Routine',
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.bold,
              color:      _accent,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step progress dots ─────────────────────────────────────────────────────

  Widget _buildStepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kSteps.length, (i) {
        final done   = i < _stepIndex;
        final active = i == _stepIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width:  active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? _accent.withOpacity(0.5)
                : active
                ? _step.color
                : Colors.black.withOpacity(0.10),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // ── Active step ────────────────────────────────────────────────────────────

  Widget _buildActiveStep() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Circular countdown with icon
          ScaleTransition(
            scale: _pulseAnim,
            child: AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, __) => SizedBox(
                width:  200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value:           1.0 - _ringCtrl.value,
                        strokeWidth:     6,
                        backgroundColor: Colors.black.withOpacity(0.07),
                        valueColor:      AlwaysStoppedAnimation<Color>(_step.color),
                        strokeCap:       StrokeCap.round,
                      ),
                    ),
                    Container(
                      width:  158,
                      height: 158,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _step.color.withOpacity(0.10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_step.icon, size: 44, color: _step.color),
                          const SizedBox(height: 10),
                          Text(
                            _fmt(_secondsLeft),
                            style: TextStyle(
                              fontSize:   18,
                              fontWeight: FontWeight.bold,
                              color:      _step.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Step title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize:   26,
                fontWeight: FontWeight.bold,
                color:      Color(0xFF1A237E),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Text(
              _step.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:    Colors.black.withOpacity(0.50),
                height:   1.5,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Step counter label
          Text(
            'Step ${_stepIndex + 1} of ${_kSteps.length}',
            style: TextStyle(
              fontSize:   13,
              color:      Colors.black.withOpacity(0.30),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Skip
          if (_stepIndex < _kSteps.length - 1)
            TextButton.icon(
              onPressed: _advanceStep,
              icon:  const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Skip to next step'),
              style: TextButton.styleFrom(
                foregroundColor: _accent.withOpacity(0.55),
              ),
            ),
        ],
      ),
    );
  }

  // ── Done state ─────────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width:  130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.10),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              size:  60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Bedtime routine complete',
            style: TextStyle(
              fontSize:   24,
              fontWeight: FontWeight.bold,
              color:      Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Text(
              "Get into bed and let sleep come naturally. You've done everything right.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:    Colors.black.withOpacity(0.45),
                height:   1.5,
              ),
            ),
          ),
          const SizedBox(height: 44),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ── Background blobs ───────────────────────────────────────────────────────────

class _BlobBg extends StatelessWidget {
  const _BlobBg({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60, right: -60,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -80, left: -40,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.07),
            ),
          ),
        ),
      ],
    );
  }
}