// Smoke test: the app boots, seeded counters render, and the wide
// counters page lays out as a two-column grid (guarding the rail-width
// breakpoint). Full visual coverage lives in screens_test.dart.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show EventChannel, FontLoader, MethodChannel;
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

void seed() {
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
        name: 'Reading pages',
        group: 'habits',
        value: 214,
        step: 10,
        goalV: 300,
        icon: 'note',
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
  ];
  app.store.notes = {};
  app.store.focusLog = {};
  app.store.undos.clear();
  app.focus.reset();
  app.nav.jump(1);
  app.store.touch();
}

Future<void> mount(WidgetTester t, {double w = 393, double h = 852}) async {
  t.view.physicalSize = Size(w * 2.75, h * 2.75);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  await t.pumpWidget(const app.OpenFocuslyApp());
  await t.pump(const Duration(milliseconds: 120));
  await t.pump(const Duration(milliseconds: 700));
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

  testWidgets('counters page renders seeded cards', (t) async {
    seed();
    await mount(t);
    expect(find.text('Reading pages'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('wide counters page lays cards out in two columns', (t) async {
    seed();
    await mount(t, w: 1180, h: 820);
    await t.pump(const Duration(milliseconds: 800));

    // First row cards share a y but differ in x -> side by side.
    final a = t.getTopLeft(find.text('Reading pages'));
    final b = t.getTopLeft(find.text('Sales'));
    expect(a.dy.roundToDouble(), moreOrLessEquals(b.dy.roundToDouble(), epsilon: 2));
    expect(b.dx, greaterThan(a.dx + 300));

    // The third card wraps to a second row below the first.
    final c = t.getTopLeft(find.text('Water'));
    expect(c.dy, greaterThan(a.dy + 60));
  });

  testWidgets('narrow counters page keeps a single column', (t) async {
    seed();
    await mount(t, w: 393, h: 852);
    await t.pump(const Duration(milliseconds: 800));

    final a = t.getTopLeft(find.text('Reading pages'));
    final b = t.getTopLeft(find.text('Sales'));
    expect(b.dx.roundToDouble(), moreOrLessEquals(a.dx.roundToDouble(), epsilon: 2));
    expect(b.dy, greaterThan(a.dy + 60));
  });
}
