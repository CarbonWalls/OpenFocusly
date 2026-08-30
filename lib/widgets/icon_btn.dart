import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/icons.dart';
import 'btn.dart';

class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? on;
  final double size;

  const IconBtn({super.key, required this.icon, this.on, this.size = 19});

  @override
  Widget build(BuildContext c) => Btn(
        on: on,
        pad: const EdgeInsets.all(8),
        child: IconX(icon, size: size, color: ThemeScope.of(c).pal.text2),
      );
}
