import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Pulsing progress indicator widget ────────────────────────────────────────

class MindfulProgressIndicator extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final Color accentColor;

  const MindfulProgressIndicator({
    super.key,
    required this.progress,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<MindfulProgressIndicator> createState() =>
      _MindfulProgressIndicatorState();
}

class _MindfulProgressIndicatorState extends State<MindfulProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isPlaying) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MindfulProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.animateTo(0.0,
            duration: const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Breathing ripple rings
            if (widget.isPlaying) ...[
              Container(
                width: 110 + (45 * _pulseAnimation.value),
                height: 110 + (45 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor
                      .withOpacity(0.08 * (1.0 - _pulseAnimation.value)),
                ),
              ),
              Container(
                width: 110 + (25 * _pulseAnimation.value),
                height: 110 + (25 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor
                      .withOpacity(0.12 * (1.0 - _pulseAnimation.value)),
                ),
              ),
            ],

            // 2. Core icon circle (pulsing scale)
            Transform.scale(
              scale: widget.isPlaying ? _scaleAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor
                      .withOpacity(widget.isPlaying ? 0.25 : 0.12),
                  border: Border.all(
                    color: widget.accentColor
                        .withOpacity(widget.isPlaying ? 0.7 : 0.3),
                    width: 2,
                  ),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(
                                0.25 * _pulseAnimation.value),
                            blurRadius: 15.0,
                            spreadRadius: 2.0,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 52,
                  color: widget.accentColor
                      .withOpacity(widget.isPlaying ? 1.0 : 0.6),
                ),
              ),
            ),

            // 3. Progress arc
            if (widget.isPlaying || widget.progress > 0)
              SizedBox(
                width: 126,
                height: 126,
                child: CustomPaint(
                  painter: _CircularSessionProgressPainter(
                    progress: widget.progress,
                    color: widget.accentColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Circular progress arc CustomPainter ──────────────────────────────────────

class _CircularSessionProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularSessionProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2 - 2;

    // Background track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = strokeWidth - 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final hsl = HSLColor.fromColor(color);
      final lighterColor =
          hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();

      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 2 * math.pi - math.pi / 2,
        colors: [color, lighterColor, color],
        stops: const [0.0, 0.5, 1.0],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final double sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);

      // Glowing dot at end of arc
      final double endAngle = -math.pi / 2 + sweepAngle;
      final dotOffset = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      canvas.drawCircle(
        dotOffset,
        7.0,
        Paint()
          ..color = lighterColor.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
      );
      canvas.drawCircle(
        dotOffset,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularSessionProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
