import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../models/store.dart';
import '../models/counter.dart';
import '../app/nav.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';
import '../widgets/icon_btn.dart';
import '../widgets/field.dart';
import '../widgets/header.dart';
import '../widgets/progress.dart';
import '../widgets/sheet.dart';
import '../widgets/confirm.dart';

class CountersScreen extends StatefulWidget {
  const CountersScreen({super.key});

  @override
  State<CountersScreen> createState() => _CountersState();
}

class _CountersState extends State<CountersScreen> {
  final TextEditingController q = TextEditingController();
  String folder = '';

  @override
  void initState() {
    super.initState();
    q.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    q.removeListener(_changed);
    q.dispose();
    super.dispose();
  }

  List<Counter> get list {
    final query = q.text.trim().toLowerCase();
    final out = store.counters.where((c) {
      final fm = folder.isEmpty || c.group == folder;
      final tm = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.group.toLowerCase().contains(query);
      return fm && tm;
    }).toList();

    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return a.order.compareTo(b.order);
    });
    return out;
  }

  double progressFor(Counter c) {
    final values = <double>[];
    if (c.goalV != null && c.goalV! > 0)
      values.add((c.value / c.goalV!).clamp(0.0, 1.0).toDouble());
    if (c.moneyEnabled && c.mult != 0 && c.goalM != null && c.goalM! > 0)
      values.add((c.money / c.goalM!).clamp(0.0, 1.0).toDouble());
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> chooseFolder() async {
    await sheet<void>(context, StatefulBuilder(
      builder: (ctx, setState) {
        final p = ThemeScope.of(ctx).pal;
        final newFolderCtrl = TextEditingController();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('selectFolder'), style: title(p, s: 20)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Field(ctrl: newFolderCtrl, hint: L.t('newFolder'))),
            IconBtn(
                icon: 'plus',
                on: () {
                  final name = newFolderCtrl.text.trim();
                  if (name.isNotEmpty) {
                    setState(() => store.counters
                        .add(Counter(id: uid(), name: '', group: name)));
                  }
                }),
          ]),
          _Group(
              name: L.t('all'),
              active: folder.isEmpty,
              on: () {
                setState(() => folder = '');
                Navigator.pop(context);
              }),
          for (final g in store.groups)
            Dismissible(
              key: ValueKey('g-$g'),
              direction: DismissDirection.horizontal,
              onDismissed: (dir) {
                store.counters.removeWhere((c) => c.group == g);
                store.touch();
              },
              background: Container(color: p.bad.withValues(alpha: .1)),
              child: GestureDetector(
                onLongPress: () {},
                child: _Group(
                  name: g,
                  active: folder == g,
                  on: () {
                    setState(() => folder = g);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          const SizedBox(height: 5),
          Text(L.t('foldersAutoSub'), style: cap(p)),
        ]);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        final p = ThemeScope.of(context).pal;
        final l = list;

        return Column(children: [
          Header(
              titleText: folder.isEmpty ? L.t('counters') : folder,
              sub: '${l.length} ${L.t('items')}',
              back: true,
              actions: [
                IconBtn(icon: 'folder', on: chooseFolder),
                IconBtn(icon: 'plus', on: () => nav.openCounterEditor()),
              ]),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
              child: Row(children: [
                Expanded(child: Field(ctrl: q, hint: L.t('search'))),
                const SizedBox(width: 7),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${store.counters.length}',
                        style: TextStyle(
                            color: p.accent, fontWeight: FontWeight.w800))),
              ])),
          Expanded(
            child: l.isEmpty
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                  color: p.accentSoft,
                                  borderRadius: BorderRadius.circular(18)),
                              child: Center(
                                  child:
                                      IconX('tag', size: 24, color: p.accent))),
                          const SizedBox(height: 13),
                          Text(L.t('noCounters'), style: title(p, s: 17)),
                          const SizedBox(height: 5),
                          Text(L.t('noCountersSub'),
                              style: cap(p), textAlign: TextAlign.center),
                          const SizedBox(height: 15),
                          Btn(
                              filled: true,
                              on: () => nav.openCounterEditor(),
                              child: Text(L.t('new'),
                                  style: const TextStyle(
                                      color: white,
                                      fontWeight: FontWeight.w800))),
                        ])))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
                    itemCount: l.length,
                    itemBuilder: (_, index) {
                      final c = l[index];
                      final progress = progressFor(c);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(c.id),
                          direction: DismissDirection.horizontal,
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              c.pinned = !c.pinned;
                              store.touch();
                              return false;
                            }
                            final ok =
                                await confirm(context, L.t('delete'), c.name);
                            if (!ok) return false;
                            store.removeCounter(c.id);
                            return true;
                          },
                          background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 22),
                              decoration: BoxDecoration(
                                  color: p.accentSoft,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                IconX('pin', size: 18, color: p.accent),
                                const SizedBox(width: 8),
                                Text(c.pinned ? L.t('unpin') : L.t('pin'),
                                    style: TextStyle(
                                        color: p.accent,
                                        fontWeight: FontWeight.w800)),
                              ])),
                          secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 22),
                              decoration: BoxDecoration(
                                  color: p.bad.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(14)),
                              child: IconX('trash', size: 18, color: p.bad)),
                          child: _CounterCard(
                            counter: c,
                            progress: progress,
                            onTap: () => nav.openCounterDetail(c),
                            onMinus: c.stopped
                                ? null
                                : () {
                                    store.vib();
                                    store.bump(c, -c.step);
                                  },
                            onPlus: c.stopped
                                ? null
                                : () {
                                    store.vib();
                                    store.bump(c, c.step);
                                  },
                            onReset: () {
                              c.value = 0;
                              if (c.usesManualMoney) c.moneyValue = 0;
                              c.stopped = false;
                              store.touch();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

class _CounterCard extends StatelessWidget {
  final Counter counter;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onReset;

  const _CounterCard({
    required this.counter,
    required this.progress,
    required this.onTap,
    required this.onMinus,
    required this.onPlus,
    required this.onReset,
  });

  String _compact(double value) {
    final a = value.abs();
    if (a >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}b';
    if (a >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (a >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return fmt(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 9),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line)),
      child: Row(children: [
        Expanded(
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(counter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: p.text,
                                    fontWeight: FontWeight.w800))),
                        if (counter.pinned) ...[
                          const SizedBox(width: 5),
                          IconX('pin', size: 12, color: p.accent)
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(_compact(counter.value),
                                        style: TextStyle(
                                            color: p.text,
                                            fontSize: 27,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1)))),
                            if (counter.moneyEnabled && counter.mult != 0) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(
                                      '${counter.symbol}${_compact(counter.money)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: cap(p))),
                            ],
                          ]),
                      if (counter.goalV != null ||
                          (counter.moneyEnabled && counter.goalM != null)) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Progress(value: progress)),
                          const SizedBox(width: 6),
                          Text('${(progress * 100).round()}%',
                              style: TextStyle(
                                  color: p.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ],
                    ]))),
        const SizedBox(width: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconBtn(icon: 'minus', on: onMinus, size: 17),
          IconBtn(icon: 'plus', on: onPlus, size: 17),
          IconBtn(icon: 'refresh', on: onReset, size: 17),
        ]),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  final String name;
  final bool active;
  final VoidCallback on;

  const _Group({required this.name, required this.active, required this.on});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Btn(
          on: on,
          pad: EdgeInsets.zero,
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: active ? p.accentSoft : p.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? p.accent : p.line)),
              child: Row(children: [
                IconX('folder', size: 16, color: active ? p.accent : p.text2),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(name,
                        style: TextStyle(
                            color: active ? p.accent : p.text,
                            fontWeight: FontWeight.w600))),
                if (active) IconX('check', size: 15, color: p.accent),
              ]))),
    );
  }
}
