// optical_pattern_painter.dart
//
// Three CustomPainter implementations for the sleep relaxation screen.
// All accept an [animValue] (0.0 – 1.0, driven by AnimationController)
// and a [speed] multiplier so the controller snippet can slow them down
// over time for the wind-down effect.
//
// Color palette: dark navy (#0A0E2A) + soft-blue rings (#4A90D9 / #A8C8F0)

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Shared palette ─────────────────────────────────────────────────────────
const Color kNavyBg    = Color(0xFF0A0E2A);
const Color kBlueDeep  = Color(0xFF1E3A6E);
const Color kBlueMid   = Color(0xFF4A90D9);
const Color kBlueSoft  = Color(0xFFA8C8F0);
const Color kWhiteSoft = Color(0xFFE8F0FF);

// ══════════════════════════════════════════════════════════════════════════════
// 1. SPIRAL VORTEX
// ══════════════════════════════════════════════════════════════════════════════
class SpiralVortexPainter extends CustomPainter {
  const SpiralVortexPainter({required this.animValue});
  final double animValue; // 0.0 – 1.0, loops

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final maxR = math.sqrt(cx * cx + cy * cy);

    // Rotation angle driven by animValue
    final rotation = animValue * 2 * math.pi;

    const int arms     = 40;   // number of spiral arms
    const int rings    = 20;   // rings per arm
    const double twist = 4.5;  // how tightly the arms twist inward

    for (int arm = 0; arm < arms; arm++) {
      final baseAngle = (arm / arms) * 2 * math.pi + rotation;

      for (int ring = 0; ring < rings; ring++) {
        final t    = ring / rings;                  // 0 (centre) → 1 (edge)
        final r    = t * maxR;
        final ang  = baseAngle + t * twist * math.pi;

        final x1 = cx + r * math.cos(ang);
        final y1 = cy + r * math.sin(ang);

        final r2   = ((ring + 1) / rings) * maxR;
        final ang2 = baseAngle + ((ring + 1) / rings) * twist * math.pi;
        final x2   = cx + r2 * math.cos(ang2);
        final y2   = cy + r2 * math.sin(ang2);

        // Alternate colours for the op-art stripe effect
        final color = (arm + ring).isEven ? kBlueMid : kNavyBg;

        final paint = Paint()
          ..color       = color
          ..strokeWidth = (maxR / rings) * 0.85
          ..strokeCap   = StrokeCap.butt
          ..style       = PaintingStyle.stroke;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }

    // Soft radial gradient overlay to fade the edges
    final grad = Paint()
      ..shader = RadialGradient(
        colors: [
          kNavyBg.withOpacity(0.0),
          kNavyBg.withOpacity(0.0),
          kNavyBg.withOpacity(0.6),
          kNavyBg.withOpacity(1.0),
        ],
        stops: const [0.0, 0.55, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawRect(Offset.zero & size, grad);
  }

  @override
  bool shouldRepaint(SpiralVortexPainter old) => old.animValue != animValue;
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. EXPANDING CONCENTRIC CIRCLES
// ══════════════════════════════════════════════════════════════════════════════
class ConcentricCirclesPainter extends CustomPainter {
  const ConcentricCirclesPainter({required this.animValue});
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final maxR = math.sqrt(cx * cx + cy * cy);

    // Fill background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = kNavyBg,
    );

    const int totalRings = 28;
    const double ringSpacing = 1.0 / totalRings;

    for (int i = 0; i < totalRings; i++) {
      // Each ring moves outward as animValue increases
      final phase  = (i * ringSpacing + animValue) % 1.0;
      final radius = phase * maxR;

      // Thickness tapers as it expands (feels like a pulse wave)
      final strokeW = (1.0 - phase) * 14 + 1.5;

      // Colour fades from soft white at centre to deep blue at edge
      final color = Color.lerp(kWhiteSoft, kBlueDeep, phase)!
          .withOpacity((1.0 - phase) * 0.9 + 0.1);

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color       = color
          ..strokeWidth = strokeW
          ..style       = PaintingStyle.stroke
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(ConcentricCirclesPainter old) =>
      old.animValue != animValue;
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. RADIAL MANDALA / PETAL BLOOM
// ══════════════════════════════════════════════════════════════════════════════
class RadialMandalaPainter extends CustomPainter {
  const RadialMandalaPainter({required this.animValue});
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final maxR = math.min(cx, cy) * 0.92;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = kNavyBg,
    );

    canvas.save();
    canvas.translate(cx, cy);

    const int layers = 6;
    const int petals = 12;

    for (int layer = 0; layer < layers; layer++) {
      final layerT   = layer / layers;
      final layerR   = (layerT + 0.15) * maxR;
      // Counter-rotate alternate layers for the kaleidoscope feel
      final rotation = animValue * 2 * math.pi * (layer.isEven ? 1 : -1)
          + layer * math.pi / petals;

      canvas.save();
      canvas.rotate(rotation);

      for (int p = 0; p < petals; p++) {
        final angle  = (p / petals) * 2 * math.pi;
        final color  = Color.lerp(kBlueSoft, kBlueMid, layerT)!
            .withOpacity(0.55 - layerT * 0.15);

        // Each petal is a small arc (oval sector)
        final petalW = layerR * 0.38;
        final petalH = layerR * 0.22;

        canvas.save();
        canvas.rotate(angle);
        canvas.translate(0, -layerR * 0.5);

        final rect = Rect.fromCenter(
          center: Offset.zero,
          width:  petalW,
          height: petalH,
        );

        // Outline
        canvas.drawOval(
          rect,
          Paint()
            ..color       = color
            ..style       = PaintingStyle.fill,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..color       = kBlueSoft.withOpacity(0.25)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        canvas.restore();
      }

      canvas.restore();
    }

    // Centre glow dot
    canvas.drawCircle(
      Offset.zero,
      maxR * 0.06,
      Paint()
        ..color      = kWhiteSoft.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(RadialMandalaPainter old) =>
      old.animValue != animValue;
}