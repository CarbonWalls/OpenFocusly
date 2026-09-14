import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';

Future<T?> sheet<T>(BuildContext context, Widget child) {
  final pal = ThemeScope.of(context).pal;
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x88000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, animation, __) =>
        _Sheet(pal: pal, child: child, animation: animation),
  ));
}

class _Sheet extends StatelessWidget {
  final Pal pal;
  final Widget child;
  final Animation<double> animation;

  const _Sheet(
      {required this.pal, required this.child, required this.animation});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.line,
                        borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 14),
                ThemeScope(pal: p, child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
