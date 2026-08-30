import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../models/store.dart';
import '../models/counter.dart';
import '../app/nav.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';
import '../theme/pal.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';
import '../widgets/icon_btn.dart';
import '../widgets/sheet.dart';

class _WatchEntry {
  final String label;
  final int ms;
  _WatchEntry(this.label, this.ms);
}

class CounterDetailScreen extends StatefulWidget {
  final Counter counter;
  const CounterDetailScreen({super.key, required this.counter});

  @override
  State<CounterDetailScreen> createState() => _CounterDetailState();
}

class _CounterDetailState extends State<CounterDetailScreen> {
  bool keepScreen = false;
  bool vibration = true;
  bool sound = false;
  bool stopwatch = false;
  bool fullscreen = false;
  bool volumeButtons = false;

  StreamSubscription<dynamic>? volumeSubscription;
  Timer? watchTimer;
  int elapsedMs = 0;
  DateTime? startedAt;
  final List<_WatchEntry> watchHistory = [];

  @override
  void initState() {
    super.initState();
    vibration = store.prefs.vibration;
    sound = store.prefs.sound;

    volumeSubscription = const EventChannel('saf/volume')
        .receiveBroadcastStream()
        .listen((event) {
      if (!volumeButtons || !mounted) return;
      if (event == 'up') _bump();
      if (event == 'down') _bump(-widget.counter.step);
    });
  }

  @override
  void dispose() {
    watchTimer?.cancel();
    volumeSubscription?.cancel();
    _setScreenOn(false);
    if (fullscreen) _setFullscreen(false);
    super.dispose();
  }

  Future<void> _setScreenOn(bool e) async {
    try {
      await Store.channel.invokeMethod('setKeepScreenOn', {'enabled': e});
    } catch (_) {}
  }

  Future<void> _setFullscreen(bool e) async {
    try {
      await Store.channel.invokeMethod('setFullscreen', {'enabled': e});
    } catch (_) {}
  }

  String _fmtWatch(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final mm = ms % 1000;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${mm.toString().padLeft(3, '0')}';
  }

  void _bump([double? delta]) {
    if (widget.counter.stopped) return;

    final d = delta ?? widget.counter.step;

    if (vibration) store.vib();

    if (stopwatch && startedAt != null) {
      final now = DateTime.now();
      watchHistory.add(_WatchEntry(
          d > 0 ? '+' : '-', now.difference(startedAt!).inMilliseconds));
      startedAt = now;
      elapsedMs = 0;
    }

    store.bump(widget.counter, d);
  }

  void _toggleStopwatch() {
    setState(() {
      stopwatch = !stopwatch;
      if (stopwatch) {
        startedAt = DateTime.now();
        elapsedMs = 0;
        watchTimer?.cancel();
        watchTimer = Timer.periodic(const Duration(milliseconds: 47), (_) {
          if (!mounted || startedAt == null) return;
          setState(() =>
              elapsedMs = DateTime.now().difference(startedAt!).inMilliseconds);
        });
      } else {
        watchTimer?.cancel();
      }
    });
  }

  Future<void> _watchSheet() async {
    final p = ThemeScope.of(context).pal;

    await sheet<void>(context, StatefulBuilder(builder: (ctx, set) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(L.t('watchHistory'), style: title(p, s: 19))),
          Btn(
              on: () => set(() => watchHistory.clear()),
              child: Text(L.t('clearHistory'),
                  style: TextStyle(color: p.bad, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        if (watchHistory.isEmpty) Text(L.t('noHistory'), style: cap(p)),
        for (var i = watchHistory.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: p.surface2, borderRadius: BorderRadius.circular(9)),
              child: Row(children: [
                Text('#${i + 1}',
                    style: TextStyle(
                        color: p.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Text(watchHistory[i].label,
                    style:
                        TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${L.t('delay')} ${_fmtWatch(watchHistory[i].ms)}',
                    style: TextStyle(
                        color: p.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ]);
    }));
  }

  Future<void> _options() async {
    final p = ThemeScope.of(context).pal;

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('options'), style: title(p, s: 19)),
          const SizedBox(height: 8),
          _MenuAction(
              icon: 'bolt',
              label: L.t('keepScreenOn'),
              onTap: () {
                Navigator.pop(context);
                setState(() => keepScreen = !keepScreen);
                _setScreenOn(keepScreen);
              }),
          _MenuAction(
              icon: 'clock',
              label: stopwatch ? L.t('stopStopwatch') : L.t('stopwatch'),
              onTap: () {
                Navigator.pop(context);
                _toggleStopwatch();
              }),
          if (stopwatch)
            _MenuAction(
                icon: 'note',
                label: L.t('watchHistory'),
                onTap: () {
                  Navigator.pop(context);
                  _watchSheet();
                }),
          _MenuAction(
              icon: 'target',
              label: '${L.t('vibration')}: ${vibration ? 'on' : 'off'}',
              onTap: () {
                Navigator.pop(context);
                setState(() => vibration = !vibration);
              }),
          _MenuAction(
              icon: 'play',
              label: '${L.t('sound')}: ${sound ? 'on' : 'off'}',
              onTap: () {
                Navigator.pop(context);
                setState(() => sound = !sound);
              }),
          _MenuAction(
              icon: 'plus',
              label: L.t('volumeButtons'),
              onTap: () {
                Navigator.pop(context);
                setState(() => volumeButtons = !volumeButtons);
              }),
          _MenuAction(
              icon: 'moreV',
              label: fullscreen ? L.t('exitFullscreen') : L.t('fullscreen'),
              onTap: () {
                Navigator.pop(context);
                setState(() => fullscreen = !fullscreen);
                _setFullscreen(fullscreen);
              }),
          _MenuAction(
              icon: 'settings',
              label: L.t('editCounter'),
              onTap: () {
                Navigator.pop(context);
                nav.openCounterEditor(widget.counter);
              }),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Column(children: [
      SizedBox(
          height: 52,
          child: Row(children: [
            IconBtn(icon: 'left', on: nav.back, size: 20),
            Expanded(
                child: Text(widget.counter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
            IconBtn(icon: 'moreV', on: _options, size: 19),
          ])),
      Expanded(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _bump,
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (stopwatch)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_fmtWatch(elapsedMs),
                          style: TextStyle(
                              color: p.sub,
                              fontSize: 13,
                              fontWeight: FontWeight.w700))),
                if (widget.counter.stopped)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(L.t('counterStopped'),
                          style: TextStyle(
                              color: p.bad,
                              fontSize: 12,
                              fontWeight: FontWeight.w700))),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(fmt(widget.counter.value),
                        style: TextStyle(
                            color: p.text,
                            fontSize: 112,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -5))),
                const SizedBox(height: 22),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _CounterButton(
                      icon: 'minus', onTap: () => _bump(-widget.counter.step)),
                  const SizedBox(width: 14),
                  _CounterButton(
                      icon: 'plus',
                      label: '+${fmt(widget.counter.step)}',
                      primary: true,
                      onTap: _bump),
                ]),
                if (widget.counter.moneyEnabled && widget.counter.mult != 0) ...[
                  const SizedBox(height: 14),
                  Text('${widget.counter.symbol}${fmt(widget.counter.money)}',
                      style: TextStyle(
                          color: p.sub, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ]))),
    ]);
  }
}

class _CounterButton extends StatelessWidget {
  final String icon;
  final String? label;
  final bool primary;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
      filled: primary,
      on: onTap,
      radius: 16,
      pad: const EdgeInsets.symmetric(vertical: 22, horizontal: 32),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconX(icon, size: 28, color: primary ? white : p.text2),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(label!,
              style: TextStyle(
                  color: primary ? white : p.text2,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ]),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Btn(
          on: onTap,
          pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(children: [
            IconX(icon, size: 16, color: danger ? p.bad : p.text2),
            const SizedBox(width: 9),
            Text(label,
                style: TextStyle(
                    color: danger ? p.bad : p.text,
                    fontWeight: FontWeight.w700)),
          ])),
    );
  }
}