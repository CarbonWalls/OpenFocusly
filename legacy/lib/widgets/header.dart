import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';
import '../app/nav.dart';
import 'icon_btn.dart';

class Header extends StatelessWidget {
  final String titleText;
  final String? sub;
  final bool back;
  final List<Widget> actions;

  const Header({
    super.key,
    required this.titleText,
    this.sub,
    this.back = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
      child: Row(children: [
        if (back) IconBtn(icon: 'left', on: nav.back),
        if (back) const SizedBox(width: 7),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titleText, style: title(p)),
            if (sub != null)
              Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(sub!, style: cap(p))),
          ]),
        ),
        ...actions,
      ]),
    );
  }
}
