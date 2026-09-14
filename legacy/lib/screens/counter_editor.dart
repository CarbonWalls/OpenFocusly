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
import '../widgets/sheet.dart';
import '../widgets/confirm.dart';

class CounterEditorScreen extends StatefulWidget {
  final Counter? counter;
  const CounterEditorScreen({super.key, this.counter});

  @override
  State<CounterEditorScreen> createState() => _CounterEditorState();
}

class _CounterEditorState extends State<CounterEditorScreen> {
  late final TextEditingController name,
      value,
      step,
      symbol,
      mult,
      moneyValue,
      moneyStep,
      goalV,
      goalM;

  String folder = '';
  String goalAction = 'continue';
  bool manualMoney = false;
  bool moneyEnabled = false;

  @override
  void initState() {
    super.initState();

    final c = widget.counter;

    name = TextEditingController(text: c?.name ?? '');
    value = TextEditingController(text: c == null ? '0' : fmt(c.value));
    step = TextEditingController(text: fmt(c?.step ?? 1));
    symbol = TextEditingController(text: c?.symbol ?? '€');
    mult = TextEditingController(text: fmt(c?.mult ?? 1));

    manualMoney = c?.moneyStep != null;
    moneyEnabled = c?.moneyEnabled ?? false;

    moneyValue = TextEditingController(
        text: c?.moneyValue == null ? '' : fmt(c!.moneyValue!));
    moneyStep = TextEditingController(
        text: c?.moneyStep == null ? '' : fmt(c!.moneyStep!));
    goalV = TextEditingController(text: c?.goalV == null ? '' : fmt(c!.goalV!));
    goalM = TextEditingController(text: c?.goalM == null ? '' : fmt(c!.goalM!));

    folder = c?.group ?? '';
    goalAction = c?.goalAction ?? 'continue';

    mult.addListener(_moneyChanged);
  }

  void _moneyChanged() {
    final enabled = (numOf(mult.text) ?? 0) != 0;

    if (!enabled && moneyEnabled) {
      if (mounted) {
        setState(() {
          moneyEnabled = false;
          manualMoney = false;
        });
      } else {
        moneyEnabled = false;
        manualMoney = false;
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    mult.removeListener(_moneyChanged);
    for (final c in [
      name,
      value,
      step,
      symbol,
      mult,
      moneyValue,
      moneyStep,
      goalV,
      goalM
    ]) c.dispose();
    super.dispose();
  }

  Future<void> pickFolder() async {
    final p = ThemeScope.of(context).pal;
    final newFolderCtrl = TextEditingController();

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('selectFolder'), style: title(p, s: 20)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Field(ctrl: newFolderCtrl, hint: L.t('newFolder'))),
            IconBtn(
                icon: 'plus',
                on: () {
                  final n = newFolderCtrl.text.trim();
                  if (n.isNotEmpty) {
                    setState(() => folder = n);
                    store.touch();
                    Navigator.pop(context);
                  }
                }),
          ]),
          const SizedBox(height: 10),
          _Group(
              name: L.t('noFolder'),
              active: folder.isEmpty,
              on: () {
                setState(() => folder = '');
                Navigator.pop(context);
              }),
          for (final g in store.groups)
            _Group(
                name: g,
                active: folder == g,
                on: () {
                  setState(() => folder = g);
                  Navigator.pop(context);
                }),
        ]));
  }

  void save() {
    final n = name.text.trim();
    if (n.isEmpty) return;

    final c = widget.counter;

    final nextValue = numOf(value.text) ?? 0;
    final nextStep = numOf(step.text) ?? 1;
    final nextMult = numOf(mult.text) ?? 1;

    if (nextMult == 0) {
      moneyEnabled = false;
      manualMoney = false;
    }

    final nextMoneyValue = manualMoney ? (numOf(moneyValue.text) ?? 0) : null;
    final nextMoneyStep = manualMoney ? (numOf(moneyStep.text) ?? 0) : null;

    if (c == null) {
      final order =
          store.counters.fold<int>(0, (m, e) => math.max(m, e.order + 1));

      store.counters.add(Counter(
        id: uid(),
        name: n,
        group: folder,
        value: nextValue,
        step: nextStep,
        symbol: symbol.text.trim().isEmpty ? '€' : symbol.text.trim(),
        mult: nextMult,
        moneyValue: nextMoneyValue,
        moneyStep: nextMoneyStep,
        moneyEnabled: moneyEnabled,
        goalV: numOf(goalV.text),
        goalM: moneyEnabled ? numOf(goalM.text) : null,
        goalAction: goalAction,
        order: order,
      ));
    } else {
      c.name = n;
      c.group = folder;
      c.value = nextValue;
      c.step = nextStep;
      c.symbol = symbol.text.trim().isEmpty ? c.symbol : symbol.text.trim();
      c.mult = nextMult;
      c.moneyValue = nextMoneyValue;
      c.moneyStep = nextMoneyStep;
      c.moneyEnabled = moneyEnabled;
      c.goalV = numOf(goalV.text);
      c.goalM = moneyEnabled ? numOf(goalM.text) : null;
      c.goalAction = goalAction;
      c.stopped = false;
      c.ensureMoneySeed();
    }

    store.touch();
    nav.back();
  }

  Future<void> remove() async {
    final c = widget.counter;
    if (c == null) return;
    if (!await confirm(context, L.t('delete'), c.name)) return;
    store.removeCounter(c.id);
    nav.back();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Header(
            titleText: widget.counter == null ? L.t('new') : L.t('edit'),
            back: true,
            actions: [
              if (widget.counter != null) IconBtn(icon: 'trash', on: remove)
            ]),
        _EditorCard(
            titleText: L.t('identity'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Field(ctrl: name, label: L.t('name')),
              const SizedBox(height: 9),
              GestureDetector(
                  onTap: pickFolder,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                          color: p.surface2,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: p.line)),
                      child: Row(children: [
                        IconX('folder', size: 17, color: p.accent),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(L.t('group'), style: cap(p)),
                              const SizedBox(height: 3),
                              Text(folder.isEmpty ? L.t('noFolder') : folder,
                                  style: TextStyle(
                                      color: p.text,
                                      fontWeight: FontWeight.w700)),
                            ])),
                        IconX('right', size: 15, color: p.sub),
                      ]))),
            ])),
        const SizedBox(height: 10),
        _EditorCard(
            titleText: L.t('value'),
            child: Row(children: [
              Expanded(
                  child: Field(
                      ctrl: value,
                      label: L.t('value'),
                      type: TextInputType.number)),
              const SizedBox(width: 9),
              Expanded(
                  child: Field(
                      ctrl: step,
                      label: L.t('step'),
                      type: TextInputType.number)),
            ])),
        const SizedBox(height: 10),
        if ((numOf(mult.text) ?? 0) != 0)
          _EditorCard(
              titleText: L.t('money'),
              child: Column(children: [
                GestureDetector(
                    onTap: () => setState(() => moneyEnabled = !moneyEnabled),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: moneyEnabled ? p.accentSoft : p.surface2,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: moneyEnabled ? p.accent : p.line)),
                        child: Row(children: [
                          IconX(moneyEnabled ? 'check' : 'tag',
                              size: 16,
                              color: moneyEnabled ? p.accent : p.text2),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(L.t('enableMoney'),
                                  style: TextStyle(
                                      color: p.text,
                                      fontWeight: FontWeight.w700))),
                        ]))),
                if (moneyEnabled) ...[
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: Field(ctrl: symbol, label: L.t('symbol'))),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Field(
                            ctrl: mult,
                            label: L.t('mult'),
                            type: TextInputType.number)),
                  ]),
                  const SizedBox(height: 9),
                  GestureDetector(
                      onTap: () => setState(() => manualMoney = !manualMoney),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                              color: manualMoney ? p.accentSoft : p.surface2,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                  color: manualMoney ? p.accent : p.line)),
                          child: Row(children: [
                            IconX(manualMoney ? 'check' : 'tag',
                                size: 16,
                                color: manualMoney ? p.accent : p.text2),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(L.t('manualMoney'),
                                    style: TextStyle(
                                        color: p.text,
                                        fontWeight: FontWeight.w700))),
                          ]))),
                  if (manualMoney) ...[
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(
                          child: Field(
                              ctrl: moneyValue,
                              label: L.t('money'),
                              type: TextInputType.number)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Field(
                              ctrl: moneyStep,
                              label: L.t('moneyStep'),
                              type: TextInputType.number)),
                    ]),
                  ],
                ],
              ])),
        const SizedBox(height: 10),
        _EditorCard(
            titleText: L.t('goals'),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Field(
                        ctrl: goalV,
                        label: L.t('goalValue'),
                        type: TextInputType.number)),
                if (moneyEnabled && (numOf(mult.text) ?? 0) != 0) ...[
                  const SizedBox(width: 9),
                  Expanded(
                      child: Field(
                          ctrl: goalM,
                          label: L.t('goalMoney'),
                          type: TextInputType.number)),
                ],
              ]),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 7),
                  decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: p.line)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L.t('goalAction'), style: cap(p)),
                        const SizedBox(height: 5),
                        Row(children: [
                          for (final option in const [
                            'continue',
                            'stop',
                            'reset'
                          ])
                            Expanded(
                                child: Btn(
                                    on: () =>
                                        setState(() => goalAction = option),
                                    filled: goalAction == option,
                                    radius: 9,
                                    pad: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 5),
                                    child: Text(
                                        option == 'reset'
                                            ? L.t('resetGoal')
                                            : L.t(option),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: goalAction == option
                                                ? white
                                                : p.text2,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800)))),
                        ]),
                      ])),
            ])),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(
              child: Btn(
                  on: nav.back,
                  child: Center(
                      child: Text(L.t('cancel'),
                          style: body(p, w: FontWeight.w700))))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: Btn(
                  filled: true,
                  on: save,
                  child: Center(
                      child: Text(L.t('save'),
                          style: const TextStyle(
                              color: white, fontWeight: FontWeight.w800))))),
        ]),
      ],
    );
  }
}

class _EditorCard extends StatelessWidget {
  final String titleText;
  final Widget child;

  const _EditorCard({required this.titleText, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titleText.toUpperCase(),
            style: cap(p).copyWith(letterSpacing: 1.2, fontSize: 10)),
        const SizedBox(height: 9),
        child,
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
