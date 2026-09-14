import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';

class Btn extends StatelessWidget {
  final Widget child;
  final VoidCallback? on;
  final bool filled;
  final EdgeInsets pad;
  final double radius;

  const Btn({
    super.key,
    required this.child,
    this.on,
    this.filled = false,
    this.pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = 10,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: on,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: filled ? p.accent : clear,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}
