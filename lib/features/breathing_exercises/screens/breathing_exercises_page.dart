// screens/breathing_exercises_page.dart
import 'package:flutter/material.dart';
import 'package:mindmate/core/widgets/voice_mic_button.dart';
import '../controllers/breathing_controller.dart';

class BreathingExercisesPage extends StatefulWidget {
  final String? initialExerciseId;
  const BreathingExercisesPage({super.key, this.initialExerciseId});

  @override
  State<BreathingExercisesPage> createState() => _BreathingExercisesPageState();
}

class _BreathingExercisesPageState extends State<BreathingExercisesPage>
    with SingleTickerProviderStateMixin {
  late final BreathingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BreathingController(vsync: this);
    _controller.init(initialExerciseId: widget.initialExerciseId);
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
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
            title: const Text(
              'Breathing Exercises',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: cs.onSurface,
          ),
          body: Column(
            children: [
              // ── Scrollable content ───────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Breathing circle ───────────────────────────
                      Center(
                        child: Column(
                          children: [
                            ScaleTransition(
                              scale: _controller.circleAnim,
                              child: Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(
                                        0xFF4CAF82,
                                      ).withValues(alpha: 0.6),
                                      const Color(
                                        0xFF4CAF82,
                                      ).withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.air_rounded,
                                  size: 70,
                                  color: Color(0xFF4CAF82),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                _controller.phaseLabel,
                                key: ValueKey(_controller.phaseLabel),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        'Techniques',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Exercise cards ─────────────────
                      ..._controller.exercises.map((ex) {
                        final color = ex['color'] as Color;
                        final isThisActive = _controller.activeId == ex['id'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withValues(alpha: 0.25),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Icon(Icons.self_improvement, color: color),
                            ),
                            title: Text(
                              ex['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(ex['subtitle'] as String),
                            trailing: isThisActive
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: color,
                                    ),
                                  )
                                : Icon(
                                    Icons.play_arrow_rounded,
                                    color: _controller.isAnimating
                                        ? color.withValues(alpha: 0.35)
                                        : color,
                                  ),
                            onTap: _controller.isAnimating
                                ? null
                                : () => _controller.runExercise(ex),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Fixed mic button at bottom ───────────────────────────
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
        );
      },
    );
  }
}
