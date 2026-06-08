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

    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

/// Card displayed while a session is actively playing, showing
/// the session icon, title, subtitle, and live countdown timer.
class ActiveSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final AnimationController progressController;

  const ActiveSessionCard({
    super.key,
    required this.session,
    required this.progressController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = session['color'] as Color;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(session['icon'] as IconData, color: color),
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
                      color: color,
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
          'TAP PULSING CIRCLE TO STOP',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant.withOpacity(0.4),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
