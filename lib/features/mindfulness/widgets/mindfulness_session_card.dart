import 'package:flutter/material.dart';

/// Reusable card widget for displaying a session (mindfulness or guided).
class MindfulnessSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const MindfulnessSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = session['color'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  session['icon'] as IconData,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card displayed while a session is actively playing or paused, showing
/// the session icon, title, subtitle, and live countdown timer.
class ActiveSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final AnimationController progressController;
  final bool isPaused;

  const ActiveSessionCard({
    super.key,
    required this.session,
    required this.progressController,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = session['color'] as Color;
    final pauseColor = const Color(0xFFFF9800); // amber for paused state

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isPaused ? pauseColor : color).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPaused ? pauseColor : color,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: (isPaused ? pauseColor : color).withOpacity(0.15),
                    child: Icon(
                      isPaused ? Icons.pause_rounded : session['icon'] as IconData,
                      color: isPaused ? pauseColor : color,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          session['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (isPaused) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: pauseColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: pauseColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              'PAUSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: pauseColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPaused
                          ? 'Say "continue" or "stop"'
                          : session['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPaused ? pauseColor.withOpacity(0.8) : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Live countdown timer
              AnimatedBuilder(
                animation: progressController,
                builder: (context, _) {
                  final total = progressController.duration ??
                      const Duration(minutes: 5);
                  final elapsed = total * progressController.value;
                  final remaining = total - elapsed;
                  final minutes = remaining.inMinutes;
                  final seconds =
                      (remaining.inSeconds % 60).toString().padLeft(2, '0');
                  return Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isPaused ? pauseColor : color,
                      letterSpacing: 1.0,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isPaused
              ? 'SAY "CONTINUE" TO RESUME · "STOP" TO END'
              : 'TAP MIC TO PAUSE · TAP CIRCLE TO STOP',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: (isPaused ? pauseColor : cs.onSurfaceVariant).withOpacity(0.5),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
