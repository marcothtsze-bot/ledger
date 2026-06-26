import 'dart:math';

import 'package:flutter/material.dart';

/// A thin trend polyline (Home header net-worth sparkline). Values are
/// normalised to fit the available height with a little vertical padding.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 40,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(values, color, strokeWidth, fill: false),
      ),
    );
  }
}

/// A filled area chart with a stroked top line (Insights net-worth trend).
class AreaChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const AreaChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(values, color, 2, fill: true)),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;

  _LinePainter(this.values, this.color, this.strokeWidth, {required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final top = size.height * 0.15;
    final bottom = size.height * 0.9;
    final dx = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final norm = (values[i] - minV) / range;
      return Offset(dx * i, bottom - norm * (bottom - top));
    }

    final line = Path()..moveTo(0, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    if (fill) {
      final area = Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size);
      canvas.drawPath(area, fillPaint);
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.color != color || old.fill != fill;
}
