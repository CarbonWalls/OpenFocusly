import 'package:flutter/widgets.dart';

const white = Color(0xFFFFFFFF);
const clear = Color(0x00000000);

double cardR = 24;
double sheetR = 28;
double fieldR = 14;
double chipR = 10;
double pillR = 999;
double iconboxR = 12;

double screenSpaceWide = 24;
double screenSpaceNarrow = 20;
double cardInner = 18; 
double gapList = 10;
double gapSection = 28;

Duration fastAnim = Duration(milliseconds: 140);
Duration baseAnim = Duration(milliseconds: 220);
Duration sheetAnim = Duration(milliseconds: 260);
Curve motionCurve = Curves.easeOutCubic;
double pressScale = 0.97;
Duration pressDuration = Duration(milliseconds: 120);

String fontFamily = 'HarmonyOS Sans'; 

TextStyle get display => TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8);
TextStyle get title => TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6);
TextStyle get titleS => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700);
TextStyle get body => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5);
TextStyle get caption => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500);
TextStyle get overline => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0);
TextStyle get numberXl => TextStyle(
    fontFamily: fontFamily,
    fontSize: 104,
    fontWeight: FontWeight.w800,
    letterSpacing: -4);

const white = Color(0xFFFFFFFF);
const clear = Color(0x00000000);

class Pal {
  final bool dark;
  const Pal(this.dark);

  Pal get pal => this;

  Color get bg => dark ? const Color(0xFF0C0E11) : const Color(0xFFFFFFFF);
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
