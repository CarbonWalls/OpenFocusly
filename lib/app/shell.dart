import 'package:flutter/widgets.dart';
import '../models/store.dart';
import 'nav.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';

const navItems = [
  ['home', 'home'],
  ['tag', 'counters'],
  ['clock', 'time'],
  ['note', 'notes'],
];

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: nav,
      builder: (_, __) {
        final p = ThemeScope.of(c).pal;
        final wide = MediaQuery.sizeOf(c).width >= 840;
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
              key: ValueKey('${nav.screen}-${nav.timeTab}'), child: child),
        );
        if (wide) {
          return Row(children: [
            const _Rail(),
            Container(width: 1, color: p.line),
            Expanded(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: SizedBox(width: double.infinity, child: body)))),
          ]);
        }
        return Column(children: [Expanded(child: body), const _Bottom()]);
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      width: 224,
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 20),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Center(child: IconX('bolt', size: 18, color: p.accent))),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('OpenFocusly',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800))),
            ])),
        for (final item in navItems) ...[
          _NavItem(item[0], item[1]),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        Container(height: 1, color: p.line),
        const SizedBox(height: 8),
        _NavItem('settings', 'settings'),
        const SizedBox(height: 4),
        _NavItem('info', 'info'),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  const _NavItem(this.icon, this.label);

  int get screen => label == 'home'
      ? 0
      : label == 'counters'
          ? 1
          : label == 'time'
              ? 2
              : label == 'notes'
                  ? 3
                  : label == 'settings'
                      ? 4
                      : 5;

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final active = nav.screen == screen;
    return Btn(
      on: () {
        store.vib();
        nav.jump(screen);
      },
      pad: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      child: Row(children: [
        IconX(icon, size: 18, color: active ? p.accent : p.text2),
        const SizedBox(width: 11),
        Expanded(
            child: Text(L.t(label),
                style: TextStyle(
                    color: active ? p.accent : p.text2,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
      ]),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom();

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: nav,
      builder: (_, __) {
        final items = [
          ...navItems,
          ['settings', 'settings']
        ];
        final p = ThemeScope.of(c).pal;
        final editorOpen = nav.screen == 6 || nav.screen == 7;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
              color: p.surface, border: Border(top: BorderSide(color: p.line))),
          padding: EdgeInsets.fromLTRB(5, editorOpen ? 3 : 5, 5, 5),
          child: SafeArea(
              top: false,
              child: Row(children: [
                for (final item in items)
                  Expanded(child: _BottomItem(item[0], item[1])),
              ])),
        );
      },
    );
  }
}

class _BottomItem extends StatelessWidget {
  final String icon, label;
  const _BottomItem(this.icon, this.label);

  int get screen => label == 'home'
      ? 0
      : label == 'counters'
          ? 1
          : label == 'time'
              ? 2
              : label == 'notes'
                  ? 3
                  : 4;

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final active = nav.screen == screen;
    return Btn(
      on: () {
        store.vib();
        nav.jump(screen);
      },
      pad: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: active ? p.accentSoft : const Color(0x00000000),
              borderRadius: BorderRadius.circular(99)),
          child: IconX(icon, size: 18, color: active ? p.accent : p.sub),
        ),
        const SizedBox(height: 2),
        Text(L.t(label),
            style: TextStyle(
                color: active ? p.accent : p.sub,
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}
