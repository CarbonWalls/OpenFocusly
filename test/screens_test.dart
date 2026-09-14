// Golden-shot harness: renders real screens of the app to PNG so the UI can be
// reviewed without a device or a browser build.
//
//   flutter test --update-goldens test/screens_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart'
    show EventChannel, FontLoader, MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/widgets.dart';

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

String k([int back = 0]) =>
    app.dayKey(DateTime.now().subtract(Duration(days: back)));

void seed() {
  app.L.lang = 'en';
  final p = app.store.prefs;
  p.lang = 'en';
  p.theme = 'light';
  p.accent = 'indigo';
  p.vibration = true;
  p.sound = false;
  p.notesFolder = 'journal';
  p.notesFolderUri = '';
  p.focusMinutes = 25;

  app.store.counters = [
    app.Counter(
        id: 'c1',
        name: 'Reading pages',
        group: 'habits',
        value: 214,
        step: 10,
        goalV: 300,
        icon: 'note',
        pinned: true,
        order: 0,
        log: {k(6): 40, k(5): 30, k(4): 60, k(3): 20, k(2): 50, k(1): 30, k(0): 40}),
    app.Counter(
        id: 'c2',
        name: 'Sales',
        group: 'work',
        value: 1840,
        step: 20,
        mult: 1,
        moneyEnabled: true,
        symbol: '€',
        goalV: 2000,
        goalM: 2000,
        icon: 'chart',
        order: 1,
        log: {k(3): 220, k(2): 180, k(1): 340, k(0): 160}),
    app.Counter(
        id: 'c3',
        name: 'Water',
        group: 'health',
        value: 5,
        step: 1,
        goalV: 8,
        icon: 'target',
        pinned: true,
        order: 2,
        log: {k(2): 8, k(1): 7, k(0): 5}),
    app.Counter(
        id: 'c4',
        name: 'Push-ups',
        group: 'health',
        value: 62,
        step: 2,
        goalV: 100,
        goalAction: 'stop',
        icon: 'bolt',
        order: 3,
        log: {k(1): 40, k(0): 22}),
    app.Counter(
        id: 'c5',
        name: 'Coffee money',
        group: 'work',
        value: 34,
        step: 3.5,
        mult: 3.5,
        moneyEnabled: true,
        symbol: '€',
        icon: 'hash',
        order: 4,
        log: {k(4): 14, k(0): 3.5}),
    app.Counter(
        id: 'c6',
        name: 'Deep work hours',
        group: 'work',
        value: 12,
        step: 1,
        goalV: 20,
        icon: 'timer',
        order: 5,
        log: {k(2): 3, k(1): 4, k(0): 2}),
  ];

  app.store.notes = {
    k(0): [
      app.Note('n1',
          '# Weekly review\n\nShipped the counter redesign. **Three** goals are close.\n\n- [ ] write release notes\n- [ ] plan next sprint',
          DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          3,
          true,
          'journal',
          '',
          '',
          'weekly-review.md'),
      app.Note('n2', 'Call the dentist back',
          DateTime.now().subtract(const Duration(minutes: 40)).millisecondsSinceEpoch,
          1,
          false,
          'journal',
          '',
          '',
          'call-dentist.md'),
    ],
    k(1): [
      app.Note('n3',
          '# Timer design notes\n\nThe ring should *fill* as the session runs, and the end time matters more than the remaining time.\n\n```dart\nfinal ratio = 1 - remain / total;\n```',
          DateTime.now().subtract(const Duration(days: 1, hours: 2)).millisecondsSinceEpoch,
          2,
          false,
          'ideas',
          '',
          '',
          'timer-design-notes.md'),
    ],
    k(3): [
      app.Note('n4', 'Idea: streaks per counter, sparkline on the card',
          DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
          5,
          false,
          'ideas',
          '',
          '',
          'streaks.md'),
    ],
    k(8): [
      app.Note('n5', 'Focus session completed.\n\n25 min of deep work.',
          DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          0,
          false,
          'journal',
          '',
          '',
          'session.md'),
    ],
  };

  app.store.focusLog = {
    k(6): 25, k(5): 50, k(3): 25, k(2): 75, k(1): 25, k(0): 25
  };
  app.store.undos.clear();
  app.focus.reset();
  app.focus.setMinutes(25);
  app.nav.jump(0);
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

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 450));
  await expectLater(
      find.byType(app.OpenFocuslyApp), matchesGoldenFile('goldens/$name.png'));
}

Future<void> go(WidgetTester t, int screen, {int tab = 0}) async {
  app.nav.jump(screen, tab: tab);
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 350));
}

void main() {
  const saf = MethodChannel('saf');

  setUpAll(() async {
    await registerFonts();
    final messenger = TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(saf, (call) async => null);
    messenger.setMockStreamHandler(
        const EventChannel('saf/volume'),
        MockStreamHandler.inline(onListen: (args, events) {}));
  });

  testWidgets('screens', (t) async {
    seed();
    await mount(t);

    await shot(t, '01_home');

    app.nav.openCounterEditor();
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, '02_counter_editor');
    app.nav.back();
    await t.pump(const Duration(milliseconds: 400));

    await go(t, 1);
    await shot(t, '03_counters');

    app.nav.openCounterDetail(app.store.counters.first);
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, '04_detail');
    app.nav.back();
    await t.pump(const Duration(milliseconds: 400));

    await go(t, 2, tab: 1);
    await shot(t, '05_focus');
    await go(t, 2, tab: 0);
    await shot(t, '06_calendar');

    await go(t, 3);
    await shot(t, '07_notes');

    app.nav.openNoteEditor(app.store.notes.values.first.first);
    await t.pump(const Duration(milliseconds: 500));
    await shot(t, '08_note_editor');
    app.nav.back();
    await t.pump(const Duration(milliseconds: 400));

    await go(t, 4);
    await shot(t, '09_settings');
    await go(t, 5);
    await shot(t, '10_info');

    // dark theme, same key screens
    app.store.prefs.theme = 'dark';
    app.store.touch();
    await go(t, 0);
    // ignore: avoid_print
    print('GEO dark ${t.getRect(find.byType(app.Page).first)} shell ${t.getRect(find.byType(app.Shell))}');
    await shot(t, '11_dark_home');
    await go(t, 1);
    await shot(t, '12_dark_counters');
    await go(t, 2, tab: 1);
    await shot(t, '13_dark_focus');
    await go(t, 3);
    await shot(t, '14_dark_notes');
    app.store.prefs.accent = 'moss';
    app.store.touch();
    await shot(t, '15_dark_moss');
    app.store.prefs.theme = 'light';
    app.store.prefs.accent = 'indigo';
    app.store.touch();

    // sheet + toast
    await go(t, 1);
    final ctx = t.element(find.byType(app.Root));
    // ignore: unawaited_futures
    app.menuSheet(ctx, 'Sort by', const [
      app.MenuItem('name', 'Name', icon: 'tag'),
      app.MenuItem('value', 'Value', icon: 'chart', checked: true),
      app.MenuItem('recent', 'Recent', icon: 'history'),
      app.MenuItem('del', 'Delete everything', icon: 'trash', danger: true),
    ]);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 300));
    await shot(t, '16_sheet');
    Navigator.of(ctx).popUntil((r) => r.isFirst);
    await t.pump(const Duration(milliseconds: 400));

    // wide layout
    seed();
    await mount(t, w: 1180, h: 820);
    await shot(t, '17_wide_home');
    await go(t, 1);
    await shot(t, '18_wide_counters');
    await go(t, 3);
    await shot(t, '19_wide_notes');

    // empty states
    app.store.counters = [];
    app.store.notes = {};
    app.store.focusLog = {};
    app.store.touch();
    await go(t, 1);
    await shot(t, '20_empty_counters');
    await go(t, 3);
    await shot(t, '21_empty_notes');
    await go(t, 0);
    await shot(t, '22_empty_home');
  });
}
