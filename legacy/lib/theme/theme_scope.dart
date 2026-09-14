import 'package:flutter/widgets.dart';
import 'pal.dart';

class ThemeScope extends InheritedWidget {
  final Pal pal;
  const ThemeScope({super.key, required this.pal, required super.child});

  static Pal of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeScope>()!.pal;

  @override
  bool updateShouldNotify(ThemeScope old) => old.pal.dark != pal.dark;
}
