// Overflow torture: mounts the app on every screen at several widths and
// heights and fails on ANY rendering exception (RenderFlex overflow,
// unbounded constraints, intrinsic-size errors, ...). Runs much faster
// than goldens and catches the defects screenshots only hint at.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show EventChannel, FontLoader, MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import 'package:openfocusly/main.dart' as app;

const fontsDir = '/root/flutter/bin/cache/artifacts/material_fonts/';

Future<void> registerFonts() async {
  for (final family in ['Roboto', 'HarmonyOS Sans']) {
    final loader = FontLoader(family);
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
      'Roboto-Italic.ttf',
    ]) {
      final f = File(fontsDir + file);
      if (!f.existsSync()) continue;
      final bytes = Uint8List.fromList(f.readAsBytesSync());
      loader.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await loader.load();
  }
}

String k([int back = 0]) => app.dayKey(fixedNow.subtract(Duration(days: back)));

final fixedNow = DateTime(2026, 9, 15, 9, 42);

void seedFull() {
  app.clock = () => fixedNow;
  app.L.lang = 'en';
  final p = app.store.prefs;
  p.lang = 'en';
  p.theme = 'light';
  p.accent = 'indigo';
  p.notesFolder = '';
  p.notesFolderUri = '';

  app.store.counters = [
    app.Counter(
        id: 'c1',
        name: 'Reading pages with a genuinely very long display name',
        group: 'habits',
        value: 214,
        step: 10,
        goalV: 300,
        icon: 'note',
        pinned: true,
        order: 0,
        log: {k(1): 30, k(0): 40}),
    app.Counter(
        id: 'c2',
        name: 'Sales',
        group: 'work',
        value: 1840,
        step: 20,
        mult: 1,
        moneyEnabled: true,
        symbol: '\u20ac',
        goalV: 2000,
        goalM: 2000,
        icon: 'chart',
        order: 1,
        log: {k(1): 340, k(0): 160}),
    app.Counter(
        id: 'c3',
        name: 'Water',
        group: 'health',
        value: 5,
        step: 1,
        goalV: 8,
        icon: 'target',
        order: 2,
        log: {k(0): 5}),
    app.Counter(
        id: 'c4',
        name: 'Deep work hours',
        group: 'work',
        value: 12,
        step: 0.5,
        goalV: 20,
        icon: 'clock',
        pinned: true,
        stopped: true,
        order: 3,
        log: {k(1): 4, k(0): 2}),
  ];

  app.store.notes = {
    k(0): [
      app.Note('n1', 'Weekly review\nShipped the counter redesign. ' * 8,
          fixedNow.millisecondsSinceEpoch, 0, true, 'journal'),
      app.Note('n2', 'x\nshort', fixedNow.millisecondsSinceEpoch - 3600000, 1,
          false, 'ideas'),
    ],
    k(1): [
      app.Note(
          'n3',
          'A note with an extremely long title that must ellipsize '
              'without breaking the row layout anywhere\nbody',
          fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          2,
          false,
          ''),
    ],
  };
  app.store.focusLog = {
    k(0): 25,
    k(1): 50,
    k(2): 0,
    k(3): 75,
  };
  app.store.undos.clear();
  app.focus.reset();
  app.focus.setMinutes(25);
  app.store.touch();
}

Future<void> mount(WidgetTester t, double w, double h) async {
  t.view.physicalSize = Size(w * 2.75, h * 2.75);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  await t.pumpWidget(const app.OpenFocuslyApp());
  await t.pump(const Duration(milliseconds: 120));
  await t.pump(const Duration(milliseconds: 650));
}

void main() {
  const saf = MethodChannel('saf');

  setUpAll(() async {
    await registerFonts();
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(saf, (call) async => null);
    messenger.setMockStreamHandler(const EventChannel('saf/volume'),
        MockStreamHandler.inline(onListen: (args, events) {}));
  });

  tearDownAll(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(saf, null);
  });

  final sizes = <(double, double)>[
    (320, 568), // smallest realistic phone
    (393, 852), // pixel-ish
    (428, 926), // big phone, landscape-ish tall
    (600, 900), // small tablet portrait (below rail)
    (720, 800), // rail kicks in
    (768, 1024), // tablet
    (1180, 820), // desktop
    (1600, 700), // short desktop
    (393, 852), // rerun after wide to catch sticky state
  ];

  for (final (w, h) in sizes) {
    for (final screen in [0, 1, 2, 3, 4]) {
      testWidgets('screen $screen @ ${w.toInt()}x${h.toInt()}', (t) async {
        final errors = <Object>[];
        final dumps = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details.exception);
          dumps.add(details.toString());
        };
        try {
          seedFull();
          app.nav.jump(screen, tab: screen == 2 ? 1 : 0);
          await mount(t, w, h);
          await t.pump(const Duration(milliseconds: 400));
          // also flip the Time screen tabs if that's what we're on
          if (screen == 2) {
            app.nav.jump(2, tab: 0);
            await t.pump(const Duration(milliseconds: 400));
          }
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors, isEmpty,
            reason: 'rendering errors at ${w}x$h on screen $screen\n'
                '${dumps.join("\n----\n")}');
      });
    }
  }

  testWidgets('detail + editors render at tiny width', (t) async {
    final errors = <Object>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    try {
      seedFull();
      app.nav.jump(1);
      await mount(t, 320, 568);
      app.nav.openCounterDetail(app.store.counters.first);
      await t.pump(const Duration(milliseconds: 500));
      app.nav.openCounterEditor();
      await t.pump(const Duration(milliseconds: 500));
    } finally {
      FlutterError.onError = prev;
    }
    expect(errors, isEmpty, reason: 'detail/editor overflow at 320px');
  });
}
