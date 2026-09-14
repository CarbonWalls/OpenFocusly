import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../theme/pal.dart';

class Ring extends CustomPainter {
  final Pal p;
  final double ratio;

  Ring(this.p, this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = p.surface2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        Paint()
          ..color = p.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant Ring old) =>
      old.ratio != ratio || old.p.dark != p.dark;
}
