import 'package:flutter/widgets.dart';

const white = Color(0xFFFFFFFF);
const clear = Color(0x00000000);

class Pal {
  final bool dark;
  const Pal(this.dark);

  Pal get pal => this;

  Color get bg => dark ? const Color(0xFF0C0E11) : const Color(0xFFF6F7F9);
  Color get surface => dark ? const Color(0xFF15181D) : const Color(0xFFFFFFFF);
  Color get surface2 =>
      dark ? const Color(0xFF1E2228) : const Color(0xFFF0F2F4);
  Color get line => dark ? const Color(0xFF2B3138) : const Color(0xFFDDE2E7);
  Color get text => dark ? const Color(0xFFF2F4F6) : const Color(0xFF171A1E);
  Color get text2 => dark ? const Color(0xFFB6BDC7) : const Color(0xFF535D68);
  Color get sub => dark ? const Color(0xFF808995) : const Color(0xFF7B8692);
  Color get accent => dark ? const Color(0xFF8DA4FF) : const Color(0xFF4D68F6);
  Color get accentSoft =>
      dark ? const Color(0xFF232D55) : const Color(0xFFEEF1FF);
  Color get bad => dark ? const Color(0xFFFF7F7F) : const Color(0xFFC34A4A);
}
