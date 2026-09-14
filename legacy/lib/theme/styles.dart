import 'package:flutter/widgets.dart';
import 'pal.dart';

String fmt(double v) {
  if (!v.isFinite) return '0';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

double? numOf(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

TextStyle title(Pal p, {double s = 27}) => TextStyle(
    color: p.text,
    fontSize: s,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5);

TextStyle body(Pal p, {double s = 14, FontWeight w = FontWeight.w400}) =>
    TextStyle(color: p.text2, fontSize: s, fontWeight: w, height: 1.4);

TextStyle cap(Pal p) =>
    TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w500);

BoxDecoration box(Pal p, {double r = 16}) => BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: p.line),
      boxShadow: p.dark
          ? null
          : const [
              BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 18,
                  offset: Offset(0, 7))
            ],
    );
