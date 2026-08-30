import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';

class Progress extends StatelessWidget {
  final double value;
  const Progress({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final v = value.clamp(0.0, 1.0).toDouble();

    return Container(
      height: 6,
      decoration: BoxDecoration(
          color: p.surface2, borderRadius: BorderRadius.circular(99)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(99))),
      ),
    );
  }
}
