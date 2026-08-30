import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/styles.dart';
import '../l10n/l10n.dart';
import 'btn.dart';

Future<bool> confirm(
    BuildContext context, String titleText, String message) async {
  final pal = ThemeScope.of(context).pal;
  final result = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    pageBuilder: (_, __, ___) => ThemeScope(
        pal: pal,
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: _Confirm(
                    pal: pal, titleText: titleText, message: message)))),
  ));
  return result ?? false;
}

class _Confirm extends StatelessWidget {
  final Pal pal;
  final String titleText;
  final String message;

  const _Confirm(
      {required this.pal, required this.titleText, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(22),
      decoration: box(p, r: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleText, style: title(p, s: 19)),
          const SizedBox(height: 8),
          Text(message, style: body(p)),
          const SizedBox(height: 19),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn(
                on: () => Navigator.pop(context, false),
                child: Text(L.t('cancel'), style: body(p, w: FontWeight.w600))),
            const SizedBox(width: 7),
            Btn(
                filled: true,
                on: () => Navigator.pop(context, true),
                child: const Text('OK',
                    style:
                        TextStyle(color: white, fontWeight: FontWeight.w700))),
          ]),
        ],
      ),
    );
  }
}
