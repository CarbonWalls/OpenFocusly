import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../models/store.dart';
import '../models/prefs.dart';
import 'nav.dart';
import 'shell.dart';
import '../screens/home.dart';
import '../screens/counters.dart';
import '../screens/counter_editor.dart';
import '../screens/counter_detail.dart';
import '../screens/time.dart';
import '../screens/notes.dart';
import '../screens/note_editor.dart';
import '../screens/settings.dart';
import '../screens/info.dart';
import '../theme/pal.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  void initState() {
    super.initState();
    nav.readyUp();
  }

  Widget page() {
    switch (nav.screen) {
      case 1:
        return const CountersScreen();
      case 2:
        return const TimeScreen();
      case 3:
        return const NotesScreen();
      case 4:
        return const SettingsScreen();
      case 5:
        return const InfoScreen();
      case 6:
        return CounterEditorScreen(counter: nav.editingCounter);
      case 7:
        return NoteEditorScreen(
            note: nav.editingNote, initialDate: nav.editingNoteDate);
      case 8:
        final vc = nav.viewingCounter;
        if (vc == null || !store.counterExists(vc.id))
          return const CountersScreen();
        return CounterDetailScreen(counter: vc);
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, nav]),
      builder: (_, __) {
        final brightness = ui.PlatformDispatcher.instance.platformBrightness;
        final dark = store.prefs.theme == 'dark' ||
            (store.prefs.theme == 'system' && brightness == ui.Brightness.dark);
        final p = Pal(dark);
        return ThemeScope(
          pal: p,
          child: PopScope(
            canPop: nav.canExit,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) nav.back();
            },
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: body(p),
                child: Container(
                  color: p.bg,
                  child: SafeArea(
                    child: nav.ready
                        ? Shell(child: page())
                        : Center(
                            child: IconX('bolt', size: 30, color: p.accent)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
