import 'package:flutter/material.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import 'package:mindmate/features/Home/widgets/about_us_sheet.dart';
import 'package:mindmate/features/breathing_exercises/screens/breathing_exercises_page.dart';
import 'package:mindmate/features/emergency_support/screens/emergency_support_page.dart';
import 'package:mindmate/features/mindfulness/screens/mindfulness_page.dart';
import 'package:mindmate/features/mood_tracking/screens/mood_tracking_page.dart';
import 'package:mindmate/features/sleep_hygiene/screens/sleep_vui_screen.dart';

import '../controllers/home_controller.dart';

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

const _emergencyItem = _NavItem(
  icon: Icons.local_hospital_rounded,
  label: 'Emergency Support',
  color: Color(0xFFFF5252), // Bright Red
  keywords: ['emergency', 'crisis', 'urgent', 'support', 'call'],
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
  final HomeController _controller = HomeController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.attachContext(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  onTap: () => _controller.pushRoute(
                    'Going to ${left.label.replaceAll('\n', ' ')}…',
                    left.speech,
                    left.page,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              right != null
                  ? Expanded(
                      child: _NavCard3D(
                        item: right,
                        onTap: () => _controller.pushRoute(
                          'Going to ${right.label.replaceAll('\n', ' ')}…',
                          right.speech,
                          right.page,
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        ...rows,
                        const SizedBox(height: 14),
                        Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: _NavCard3D(
                              item: e,
                              isWide: true,
                              onTap: () => _controller.pushRoute(
                                'Going to Emergency Support…',
                                e.speech,
                                e.page,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: VoiceMicButton(
                    isListening: _controller.isListening,
                    onTap: _controller.onMicTap,
                    statusLabel: _controller.statusLabel,
                    recognizedText: _controller.recognizedText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.only(bottom: 6.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, _isPressed ? 6.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: shadowColor,
                      offset: const Offset(0, 6),
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
