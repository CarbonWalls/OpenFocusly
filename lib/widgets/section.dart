import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';

class Section extends StatelessWidget {
  final String text;
  const Section(this.text, {super.key});

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: cap(ThemeScope.of(c).pal)
                .copyWith(fontSize: 10, letterSpacing: 1.2)),
      );
}
