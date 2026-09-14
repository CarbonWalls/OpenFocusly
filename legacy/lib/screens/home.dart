import 'package:flutter/widgets.dart';
import '../models/store.dart';
import '../app/nav.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';
import '../widgets/icon_btn.dart';
import '../widgets/section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? L.t('morning')
        : hour < 18
            ? L.t('afternoon')
            : L.t('evening');
    final total = store.total();
    final notes = store.allNotes().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(greeting, style: cap(p)),
                              const SizedBox(height: 3),
                              Text('OpenFocusly', style: title(p, s: 31)),
                              const SizedBox(height: 4),
                              Text(L.t('tagline'), style: body(p)),
                            ])),
                        IconBtn(icon: 'settings', on: () => nav.go(4)),
                      ]),
                      const SizedBox(height: 28),
                      Section(L.t('overview')),
                      LayoutBuilder(builder: (_, constraints) {
                        final w = constraints.maxWidth;
                        final two = w >= 430;
                        final tile = two ? (w - 10) / 2 : w;
                        return Wrap(spacing: 10, runSpacing: 10, children: [
                          SizedBox(
                              width: tile,
                              child: _Metric(
                                  'tag',
                                  L.t('counters'),
                                  '${store.counters.length}',
                                  '${fmt(total)} ${L.t('total')}',
                                  () => nav.go(1))),
                          SizedBox(
                              width: tile,
                              child: _Metric(
                                  'clock',
                                  L.t('focus'),
                                  '25:00',
                                  L.t('readyToBegin'),
                                  () => nav.go(2, tab: 1))),
                          SizedBox(
                              width: two ? w : tile,
                              child: _Metric('note', L.t('notes'), '$notes',
                                  L.t('notesEvents'), () => nav.go(3))),
                        ]);
                      }),
                      const SizedBox(height: 24),
                      Section(L.t('focus')),
                      const _FocusTile(),
                      const SizedBox(height: 24),
                      Section(L.t('quickActions')),
                      _Quick(
                          icon: 'tag',
                          titleText: L.t('counters'),
                          sub: L.t('quickCountersSub'),
                          on: () => nav.go(1)),
                      const SizedBox(height: 9),
                      _Quick(
                          icon: 'clock',
                          titleText: L.t('calendar'),
                          sub: L.t('quickCalendarSub'),
                          on: () => nav.go(2, tab: 0)),
                      const SizedBox(height: 9),
                      _Quick(
                          icon: 'note',
                          titleText: L.t('notes'),
                          sub: L.t('quickNotesSub'),
                          on: () => nav.go(3)),
                    ]))),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String icon, titleText, value, sub;
  final VoidCallback on;

  const _Metric(this.icon, this.titleText, this.value, this.sub, this.on);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: on,
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(18),
            decoration: box(p),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: IconX(icon, size: 17, color: p.accent))),
              const SizedBox(height: 15),
              Text(value,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8)),
              const SizedBox(height: 4),
              Text(titleText,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(sub, style: cap(p)),
            ])));
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile();

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: () => nav.go(2, tab: 1),
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(17),
            decoration: box(p),
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(14)),
                  child:
                      Center(child: IconX('play', size: 20, color: p.accent))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(L.t('focusSession'),
                        style: TextStyle(
                            color: p.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(L.t('focusSessionSub'), style: cap(p)),
                  ])),
              Text('25:00',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ])));
  }
}

class _Quick extends StatelessWidget {
  final String icon, titleText, sub;
  final VoidCallback on;

  const _Quick(
      {required this.icon,
      required this.titleText,
      required this.sub,
      required this.on});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: on,
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: box(p, r: 14),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: IconX(icon, size: 17, color: p.text2))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(titleText,
                        style: TextStyle(
                            color: p.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: cap(p)),
                  ])),
              IconX('right', size: 16, color: p.sub),
            ])));
  }
}
