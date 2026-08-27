import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'lang.dart';
import 'store.dart';
import 'theme.dart';
import 'screens.dart';

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    await L.load();
    await store.init();
    if (L.langs.containsKey(store.prefs.lang)) L.lang = store.prefs.lang;
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
      animation: Listenable.merge([store as Listenable, nav as Listenable]),
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WidgetsApp(
    debugShowCheckedModeBanner: false,
    color: const Color(0xFF4D68F6),
    home: const Root(),
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
      return PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      );
    },
  ));
}
