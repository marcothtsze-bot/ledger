import 'dart:math';

import 'package:flutter/material.dart';

/// One wedge of a [DonutChart].
class DonutSegment {
  final double value;
  final Color color;
  const DonutSegment(this.value, this.color);
}

/// A ring chart (Insights "Spending by category") with an optional centre
/// widget. Drawn as stroked arcs so wedges read cleanly at any size.
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final double thickness;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.segments,
    this.size = 96,
    this.thickness = 16,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(segments, thickness),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double thickness;

  _DonutPainter(this.segments, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, seg) => s + seg.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );
    var start = -pi / 2; // 12 o'clock
    for (final seg in segments) {
      final sweep = seg.value / total * 2 * pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.thickness != thickness;
}
