import 'dart:convert';
import 'package:flutter/services.dart';
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
import '../widgets/field.dart';
import '../widgets/header.dart';
import '../widgets/sheet.dart';
import '../features/timer/sound_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> goals(BuildContext context) async {
    final p = ThemeScope.of(context).pal;

    final valueCtrl = TextEditingController(
        text: store.prefs.goalV == null ? '' : fmt(store.prefs.goalV!));
    final moneyCtrl = TextEditingController(
        text: store.prefs.goalM == null ? '' : fmt(store.prefs.goalM!));

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('goals'), style: title(p, s: 20)),
          const SizedBox(height: 14),
          Field(
              ctrl: valueCtrl, label: L.t('value'), type: TextInputType.number),
          const SizedBox(height: 8),
          Field(
              ctrl: moneyCtrl, label: L.t('money'), type: TextInputType.number),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn(
                on: () => Navigator.pop(context),
                child: Text(L.t('cancel'), style: body(p, w: FontWeight.w600))),
            const SizedBox(width: 6),
            Btn(
                filled: true,
                on: () {
                  store.prefs.goalV = numOf(valueCtrl.text);
                  store.prefs.goalM = numOf(moneyCtrl.text);
                  store.touch();
                  Navigator.pop(context);
                },
                child: Text(L.t('save'),
                    style: const TextStyle(
                        color: white, fontWeight: FontWeight.w700))),
          ]),
        ]));
  }

  Future<void> backup() async {
    try {
      final uri = await Store.channel.invokeMethod<String>(
          'create', {'name': 'openfocusly.json', 'mime': 'application/json'});
      if (uri == null) return;

      await Store.channel.invokeMethod('write', {
        'uri': uri,
        'bytes': Uint8List.fromList(utf8.encode(jsonEncode(store.toJson())))
      });
    } catch (_) {}
  }

  Future<void> restore() async {
    try {
      final uri = await Store.channel
          .invokeMethod<String>('open', {'mime': 'application/json'});
      if (uri == null) return;

      final bytes =
          await Store.channel.invokeMethod<Uint8List>('read', {'uri': uri});
      if (bytes == null) return;

      store.load(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      store.touch();
    } catch (_) {}
  }

  Future<void> pickLanguage(BuildContext context) async {
    final p = ThemeScope.of(context).pal;
    final codes = await L.available();

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('language'), style: title(p, s: 20)),
          const SizedBox(height: 12),
          for (final code in codes)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Btn(
                    on: () async {
                      await L.init(code, (c) async {
                        try {
                          final raw = await rootBundle
                              .loadString('assets/lang/$c.json');
                          final map = jsonDecode(raw) as Map<String, dynamic>;
                          return map.map((k, v) => MapEntry(k, v.toString()));
                        } catch (_) {
                          return {};
                        }
                      });
                      store.prefs.lang = code;
                      store.touch();
                      if (context.mounted) Navigator.pop(context);
                    },
                    pad: EdgeInsets.zero,
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: L.lang == code ? p.accentSoft : p.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: L.lang == code ? p.accent : p.line)),
                        child: Row(children: [
                          Expanded(
                              child: Text(code,
                                  style: TextStyle(
                                      color: L.lang == code ? p.accent : p.text,
                                      fontWeight: FontWeight.w600))),
                          if (L.lang == code)
                            IconX('check', size: 15, color: p.accent),
                        ])))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            Header(titleText: L.t('settings'), back: true),
            _SetCard(L.t('appearance'), [
              _SetRow(
                  L.t('theme'),
                  _Seg(
                      value: store.prefs.theme,
                      values: const ['light', 'dark', 'system'],
                      labels: [L.t('light'), L.t('dark'), L.t('system')],
                      on: (value) {
                        store.prefs.theme = value;
                        store.touch();
                      })),
              _SetRow(
                  L.t('language'),
                  Btn(
                      on: () => pickLanguage(context),
                      pad: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(L.lang,
                            style: TextStyle(
                                color: ThemeScope.of(context).pal.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(width: 6),
                        IconX('down',
                            size: 14, color: ThemeScope.of(context).pal.sub),
                      ]))),
            ]),
            _SetCard(L.t('controls'), [
              _SetToggle(
                  titleText: L.t('vibration'),
                  value: store.prefs.vibration,
                  on: (v) {
                    store.prefs.vibration = v;
                    store.touch();
                  }),
              _SetToggle(
                  titleText: L.t('sound'),
                  value: store.prefs.sound,
                  on: (v) {
                    store.prefs.sound = v;
                    store.touch();
                  }),
              Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                  child: Text(L.t('soundSub'),
                      style: cap(ThemeScope.of(context).pal))),
            ]),
            _SetCard(L.t('notifications'), [
              const Padding(
                padding: EdgeInsets.fromLTRB(15, 5, 15, 12),
                child: SoundPicker(),
              ),
            ]),
            _SetCard(L.t('goals'), [
              _SetAction(
                  'target',
                  L.t('goals'),
                  '${store.prefs.goalV == null ? '—' : fmt(store.prefs.goalV!)}  •  ${store.prefs.goalM == null ? '—' : '${fmt(store.prefs.goalM!)}€'}',
                  () => goals(context)),
            ]),
            _SetCard(L.t('data'), [
              _SetAction('up', L.t('backup'), L.t('backupSub'), backup),
              _SetAction('down', L.t('restore'), L.t('restoreSub'), restore),
            ]),
            _SetCard(L.t('about'), [
              _SetAction(
                  'info', L.t('about'), L.t('aboutSub'), () => nav.go(5)),
            ]),
          ],
        );
      },
    );
  }
}

class _SetCard extends StatelessWidget {
  final String titleText;
  final List<Widget> children;

  const _SetCard(this.titleText, this.children);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: box(p, r: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
            child: Text(titleText.toUpperCase(),
                style: cap(p).copyWith(fontSize: 10, letterSpacing: 1.1))),
        ...children,
      ]),
    );
  }
}

class _SetRow extends StatelessWidget {
  final String labelText;
  final Widget child;

  const _SetRow(this.labelText, this.child);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 5, 10, 10),
      child: Row(children: [
        Expanded(
            child: Text(labelText,
                style: TextStyle(
                    color: p.text, fontWeight: FontWeight.w600, fontSize: 13))),
        child,
      ]),
    );
  }
}

class _SetToggle extends StatelessWidget {
  final String titleText;
  final bool value;
  final ValueChanged<bool> on;

  const _SetToggle({
    required this.titleText,
    required this.value,
    required this.on,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => on(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
        child: Row(children: [
          Expanded(
              child: Text(titleText,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
          Container(
            width: 42,
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: value ? p.accent : p.surface2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: value ? p.accent : p.line)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: white, shape: BoxShape.circle)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SetAction extends StatelessWidget {
  final String icon, titleText, sub;
  final VoidCallback on;

  const _SetAction(this.icon, this.titleText, this.sub, this.on);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Btn(
        on: on,
        pad: const EdgeInsets.fromLTRB(15, 9, 15, 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: p.surface2, borderRadius: BorderRadius.circular(10)),
              child: Center(child: IconX(icon, size: 17, color: p.text2))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(titleText,
                    style: TextStyle(
                        color: p.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(sub, style: cap(p)),
              ])),
          IconX('right', size: 16, color: p.sub),
        ]));
  }
}

class _Seg extends StatelessWidget {
  final String value;
  final List<String> values;
  final List<String> labels;
  final ValueChanged<String> on;

  const _Seg({
    required this.value,
    required this.values,
    required this.labels,
    required this.on,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: p.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < values.length; i++)
          Btn(
              on: () => on(values[i]),
              pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              radius: 8,
              child: Text(labels[i],
                  style: TextStyle(
                      color: value == values[i] ? p.text : p.sub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
