// pmr_screen.dart
//
// Guided Progressive Muscle Relaxation.
// Cycles through 7 body regions: tense (7s) → release (8s) → next region.
// TTS narrates each phase. A glowing icon and horizontal progress track
// make the current state immediately obvious.
//
// Usage (from SleepController):
//
//   Navigator.push(
//     _context!,
//     PageRouteBuilder(
//       pageBuilder: (_, __, ___) =>
//           PmrScreen(ttsService: ttsService),
//       transitionsBuilder: (_, anim, __, child) =>
//           FadeTransition(opacity: anim, child: child),
//       transitionDuration: const Duration(milliseconds: 600),
//     ),
//   );

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/tts_service.dart';

// ── Region model ───────────────────────────────────────────────────────────────

class _Region {
  const _Region({
    required this.label,
    required this.icon,
    required this.tensionInstruction,
    required this.releaseInstruction,
    required this.tensionNarration,
    required this.releaseNarration,
  });
  final String   label;
  final IconData icon;
  final String   tensionInstruction;
  final String   releaseInstruction;
  final String   tensionNarration;
  final String   releaseNarration;
}

const _kRegions = [
  _Region(
    label:               'Feet',
    icon:                Icons.directions_walk_rounded,
    tensionInstruction:  'Curl your toes tightly downward',
    releaseInstruction:  'Let your feet go completely limp',
    tensionNarration:    'Curl your toes tightly. Hold the tension.',
    releaseNarration:    'Release. Let your feet go completely limp.',
  ),
  _Region(
    label:               'Calves',
    icon:                Icons.airline_seat_legroom_normal_rounded,
    tensionInstruction:  'Flex your calves by pointing toes up',
    releaseInstruction:  'Let your lower legs soften and drop',
    tensionNarration:    'Point your toes upward. Flex your calves. Hold.',
    releaseNarration:    'Release. Feel the tension melt away.',
  ),
  _Region(
    label:               'Thighs',
    icon:                Icons.airline_seat_recline_normal_rounded,
    tensionInstruction:  'Squeeze your thigh muscles together',
    releaseInstruction:  'Let your thighs release and feel heavy',
    tensionNarration:    'Squeeze your thighs. Hold the tension.',
    releaseNarration:    'Release. Let your legs feel heavy and warm.',
  ),
  _Region(
    label:               'Abdomen',
    icon:                Icons.self_improvement_rounded,
    tensionInstruction:  'Draw your stomach in and tighten it',
    releaseInstruction:  'Let your belly fully soften',
    tensionNarration:    'Draw in your stomach. Hold tight.',
    releaseNarration:    'Release. Let your belly soften completely.',
  ),
  _Region(
    label:               'Hands',
    icon:                Icons.back_hand_outlined,
    tensionInstruction:  'Make tight fists with both hands',
    releaseInstruction:  'Open your hands and let fingers uncurl',
    tensionNarration:    'Make tight fists. Squeeze hard.',
    releaseNarration:    'Open your hands. Feel the release spread through your fingers.',
  ),
  _Region(
    label:               'Shoulders',
    icon:                Icons.accessibility_new_rounded,
    tensionInstruction:  'Raise shoulders up toward your ears',
    releaseInstruction:  'Drop your shoulders completely',
    tensionNarration:    'Raise your shoulders up to your ears. Hold.',
    releaseNarration:    'Drop them. Feel the weight leave your shoulders.',
  ),
  _Region(
    label:               'Face',
    icon:                Icons.face_rounded,
    tensionInstruction:  'Scrunch your face - brow, eyes, jaw',
    releaseInstruction:  'Let your face go smooth and soft',
    tensionNarration:    'Scrunch your whole face tightly. Hold.',
    releaseNarration:    'Release. Let your face go completely smooth.',
  ),
];

const _kTensionSeconds = 7;
const _kReleaseSeconds = 8;

enum _Phase { tension, release }

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class PmrScreen extends StatefulWidget {
  const PmrScreen({super.key, required this.ttsService});
  final TtsService ttsService;

  @override
  State<PmrScreen> createState() => _PmrScreenState();
}

class _PmrScreenState extends State<PmrScreen> with TickerProviderStateMixin {

  static const Color _accent  = Color(0xFF3F51B5);
  static const Color _tension = Color(0xFFEF5350);
  static const Color _release = Color(0xFF66BB6A);
  static const Color _bg      = Color(0xFFEEF0FB);

  int    _regionIndex = 0;
  _Phase _phase       = _Phase.tension;
  int    _secondsLeft = _kTensionSeconds;
  bool   _isDone      = false;

  Timer?                  _timer;
  late AnimationController _glowCtrl;
  late AnimationController _countCtrl;
  late Animation<double>   _glowAnim;

  _Region get _region => _kRegions[_regionIndex];
  Color   get _phaseColor => _phase == _Phase.tension ? _tension : _release;

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _countCtrl = AnimationController(
      vsync:    this,
      duration: Duration(seconds: _kTensionSeconds),
    )..forward();

    _startPhase();
  }

  // ── Phase control ──────────────────────────────────────────────────────────

  Future<void> _startPhase() async {
    _timer?.cancel();

    // Reset count ring
    final phaseDuration = _phase == _Phase.tension
        ? _kTensionSeconds
        : _kReleaseSeconds;
    _countCtrl.duration = Duration(seconds: phaseDuration);
    _countCtrl.reset();
    _countCtrl.forward();

    // Narrate
    final text = _phase == _Phase.tension
        ? _region.tensionNarration
        : _region.releaseNarration;
    widget.ttsService.speak(text); // fire-and-forget — timer runs in parallel

    // Countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _nextPhase();
      }
    });
  }

  void _nextPhase() {
    _timer?.cancel();
    if (_phase == _Phase.tension) {
      setState(() {
        _phase       = _Phase.release;
        _secondsLeft = _kReleaseSeconds;
      });
      _startPhase();
    } else {
      if (_regionIndex < _kRegions.length - 1) {
        setState(() {
          _regionIndex++;
          _phase       = _Phase.tension;
          _secondsLeft = _kTensionSeconds;
        });
        _startPhase();
      } else {
        _timer?.cancel();
        setState(() => _isDone = true);
        widget.ttsService.speak(
          'Well done. Your whole body has released its tension. '
              'Allow sleep to come naturally now.',
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowCtrl.dispose();
    _countCtrl.dispose();
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
          _BlobBg(phaseColor: _phaseColor),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildProgressBar(),
                const SizedBox(height: 8),
                _isDone ? _buildDone() : _buildActiveRegion(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Progressive Muscle Relaxation',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      _accent,
                ),
              ),
              Text(
                'Tense and release each muscle group',
                style: TextStyle(
                  fontSize: 12,
                  color:    Colors.black.withOpacity(0.40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Region progress bar ────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_kRegions.length, (i) {
          final done   = i < _regionIndex;
          final active = i == _regionIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin:   const EdgeInsets.symmetric(horizontal: 2),
              height:   5,
              decoration: BoxDecoration(
                color: done
                    ? _accent.withOpacity(0.60)
                    : active
                    ? _phaseColor
                    : Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Active region ──────────────────────────────────────────────────────────

  Widget _buildActiveRegion() {
    final instruction = _phase == _Phase.tension
        ? _region.tensionInstruction
        : _region.releaseInstruction;
    final phaseLabel = _phase == _Phase.tension ? 'TENSE' : 'RELEASE';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Glowing icon circle with countdown ring
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [

                // Outer glow
                Container(
                  width:  200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _phaseColor.withOpacity(0.08 * _glowAnim.value),
                    boxShadow: [
                      BoxShadow(
                        color:      _phaseColor.withOpacity(0.20 * _glowAnim.value),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),

                // Count ring
                SizedBox(
                  width:  180,
                  height: 180,
                  child: AnimatedBuilder(
                    animation: _countCtrl,
                    builder: (_, __) => CircularProgressIndicator(
                      value:           1.0 - _countCtrl.value,
                      strokeWidth:     5,
                      backgroundColor: Colors.black.withOpacity(0.06),
                      valueColor:      AlwaysStoppedAnimation<Color>(_phaseColor),
                      strokeCap:       StrokeCap.round,
                    ),
                  ),
                ),

                // Inner content
                Container(
                  width:  140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _phaseColor.withOpacity(0.10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_region.icon, size: 40, color: _phaseColor),
                      const SizedBox(height: 8),
                      Text(
                        '${_secondsLeft}s',
                        style: TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.w300,
                          color:      _phaseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Phase badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color:        _phaseColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              phaseLabel,
              style: const TextStyle(
                color:       Colors.white,
                fontSize:    13,
                fontWeight:  FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Region name
          Text(
            _region.label,
            style: const TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.bold,
              color:      Color(0xFF1A237E),
            ),
          ),

          const SizedBox(height: 10),

          // Instruction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Text(
              instruction,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:    Colors.black.withOpacity(0.50),
                height:   1.5,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Scrollable region chip list
          _buildRegionChips(),
        ],
      ),
    );
  }

  Widget _buildRegionChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 24),
        itemCount:        _kRegions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder:      (_, i) {
          final done   = i < _regionIndex;
          final active = i == _regionIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: done
                  ? _accent.withOpacity(0.10)
                  : active
                  ? _phaseColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? _phaseColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              _kRegions[i].label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: active ? FontWeight.bold : FontWeight.w400,
                color: done
                    ? _accent.withOpacity(0.60)
                    : active
                    ? _phaseColor
                    : Colors.black.withOpacity(0.30),
              ),
            ),
          );
        },
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
              Icons.self_improvement_rounded,
              size:  60,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Fully relaxed',
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
              'Your whole body has released its tension. Allow sleep to come naturally now.',
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
  const _BlobBg({required this.phaseColor});
  final Color phaseColor;

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
              color: phaseColor.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -80, left: -40,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3F51B5).withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }
}