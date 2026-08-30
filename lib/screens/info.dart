import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/header.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Header(titleText: L.t('info'), back: true),
        Center(
            child: Container(
                padding: const EdgeInsets.all(22),
                decoration: box(p, r: 20),
                child: Column(children: [
                  IconX('bolt', size: 30, color: p.accent),
                  const SizedBox(height: 14),
                  Text('OpenFocusly', style: title(p, s: 22)),
                  const SizedBox(height: 5),
                  Text(L.t('aboutSub'), style: cap(p)),
                  const SizedBox(height: 14),
                  Text(L.t('tagline'),
                      style: body(p), textAlign: TextAlign.center),
                ]))),
      ],
    );
  }
}
