import 'package:flutter/widgets.dart';
import 'theme_scope.dart';

class IconX extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const IconX(this.name, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext c) => CustomPaint(
        size: Size.square(size),
        painter: _Painter(name, color ?? ThemeScope.of(c).pal.text),
      );
}

class _Painter extends CustomPainter {
  final String n;
  final Color c;

  _Painter(this.n, this.c);

  @override
  void paint(Canvas g, Size s) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final f = Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    final w = s.width, h = s.height;

    void l(double x1, double y1, double x2, double y2) =>
        g.drawLine(Offset(x1, y1), Offset(x2, y2), p);

    switch (n) {
      case 'home':
        g.drawPath(
            Path()
              ..moveTo(w * .15, h * .48)
              ..lineTo(w * .5, h * .2)
              ..lineTo(w * .85, h * .48),
            p);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .25, h * .43, w * .75, h * .82, const Radius.circular(2)),
            p);
        break;
      case 'tag':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .26, w * .82, h * .74, const Radius.circular(3)),
            p);
        l(w * .32, h * .5, w * .68, h * .5);
        break;
      case 'clock':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        l(w / 2, h / 2, w / 2, h * .3);
        l(w / 2, h / 2, w * .65, h * .56);
        break;
      case 'note':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .23, h * .15, w * .77, h * .85, const Radius.circular(3)),
            p);
        l(w * .35, h * .38, w * .65, h * .38);
        l(w * .35, h * .53, w * .65, h * .53);
        l(w * .35, h * .68, w * .56, h * .68);
        break;
      case 'settings':
        l(w * .18, h * .3, w * .82, h * .3);
        l(w * .18, h * .5, w * .82, h * .5);
        l(w * .18, h * .7, w * .82, h * .7);
        g.drawCircle(Offset(w * .62, h * .3), w * .055, f);
        g.drawCircle(Offset(w * .38, h * .5), w * .055, f);
        g.drawCircle(Offset(w * .58, h * .7), w * .055, f);
        break;
      case 'info':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h * .36), w * .025, f);
        l(w / 2, h * .48, w / 2, h * .69);
        break;
      case 'plus':
        l(w * .5, h * .22, w * .5, h * .78);
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'minus':
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'x':
        l(w * .27, h * .27, w * .73, h * .73);
        l(w * .73, h * .27, w * .27, h * .73);
        break;
      case 'check':
        l(w * .2, h * .53, w * .42, h * .74);
        l(w * .42, h * .74, w * .82, h * .29);
        break;
      case 'left':
        l(w * .62, h * .25, w * .36, h * .5);
        l(w * .36, h * .5, w * .62, h * .75);
        break;
      case 'right':
        l(w * .38, h * .25, w * .64, h * .5);
        l(w * .64, h * .5, w * .38, h * .75);
        break;
      case 'folder':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .13, h * .3, w * .87, h * .78, const Radius.circular(2)),
            p);
        l(w * .14, h * .42, w * .43, h * .42);
        l(w * .43, h * .42, w * .49, h * .3);
        break;
      case 'pin':
        g.drawCircle(Offset(w * .5, h * .34), w * .14, p);
        l(w * .5, h * .48, w * .5, h * .82);
        break;
      case 'trash':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .28, h * .29, w * .72, h * .82, const Radius.circular(2)),
            p);
        l(w * .22, h * .25, w * .78, h * .25);
        l(w * .42, h * .18, w * .58, h * .18);
        l(w * .42, h * .18, w * .42, h * .25);
        l(w * .58, h * .18, w * .58, h * .25);
        break;
      case 'play':
        g.drawPath(
            Path()
              ..moveTo(w * .36, h * .25)
              ..lineTo(w * .74, h * .5)
              ..lineTo(w * .36, h * .75)
              ..close(),
            f);
        break;
      case 'pause':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .3, h * .25, w * .43, h * .75, const Radius.circular(1)),
            f);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .57, h * .25, w * .7, h * .75, const Radius.circular(1)),
            f);
        break;
      case 'refresh':
        g.drawArc(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * .3),
            -.8, 4.7, false, p);
        l(w * .75, h * .26, w * .75, h * .43);
        l(w * .75, h * .26, w * .58, h * .29);
        break;
      case 'bolt':
        g.drawPath(
            Path()
              ..moveTo(w * .57, h * .12)
              ..lineTo(w * .3, h * .54)
              ..lineTo(w * .48, h * .54)
              ..lineTo(w * .41, h * .88)
              ..lineTo(w * .71, h * .42)
              ..lineTo(w * .53, h * .42)
              ..close(),
            f);
        break;
      case 'target':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .20, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .06, f);
        l(w * .78, h * .22, w * .58, h * .42);
        break;
      case 'more':
        g.drawCircle(Offset(w * .25, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .75, h * .5), w * .07, f);
        break;
      case 'moreV':
        g.drawCircle(Offset(w * .5, h * .25), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .75), w * .07, f);
        break;
      case 'calendar':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .22, w * .82, h * .82, const Radius.circular(3)),
            p);
        l(w * .18, h * .38, w * .82, h * .38);
        l(w * .34, h * .14, w * .34, h * .30);
        l(w * .66, h * .14, w * .66, h * .30);
        break;
      case 'down':
        l(w * .5, h * .22, w * .5, h * .78);
        l(w * .3, h * .6, w * .5, h * .78);
        l(w * .7, h * .6, w * .5, h * .78);
        break;
      default:
        g.drawCircle(Offset(w / 2, h / 2), w * .25, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => old.n != n || old.c != c;
}
