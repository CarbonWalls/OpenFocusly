import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

// ============================== TOKENS ==============================

const white = Color(0xFFFFFFFF);
const black = Color(0xFF000000);
const clear = Color(0x00000000);

/// Central design tokens: radii, spacing, motion and type ramps.
/// Every visual surface in the app reads from here, so the whole UI can be
/// re-skinned from one place.
class Tk {
  // radii
  static const double rCard = 18;
  static const double rCardLg = 24;
  static const double rField = 13;
  static const double rChip = 10;
  static const double rIcon = 11;
  static const double rPill = 999;

  // spacing scale (4pt grid)
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;

  static const double gutter = 18;
  static const double gapList = 10;
  static const double gapForm = 12;
  static const double gapSection = 22;
  static const double tabBar = 60;

  // content caps keep line length readable on tablets / desktop / web
  static const double maxReading = 680;
  static const double maxColumns = 1040;
  static const double maxSingle = 560;
  static const double railWide = 900;
  static const double railMin = 720;

  // motion
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveBack = Curves.easeOutBack;

  // type ramp
  static const String font = 'HarmonyOS Sans';
  static const TextStyle display = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    height: 1.02,
    fontFamily: font,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    height: 1.1,
    fontFamily: font,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.15,
    fontFamily: font,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
    height: 1.2,
    fontFamily: font,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFamily: font,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: font,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    fontFamily: font,
  );
  static const TextStyle num = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    fontFeatures: [FontFeature.tabularFigures()],
    fontFamily: font,
  );
  static const TextStyle numLg = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.6,
    fontFeatures: [FontFeature.tabularFigures()],
    fontFamily: font,
  );
}

/// Elevation presets. Kept very soft: the app is a calm surface, not a toy.
class Shadow {
  static List<BoxShadow> of(
    Pal p, {
    double y = 8,
    double blur = 22,
    double a = .07,
  }) {
    if (p.dark) {
      return [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: a + .12),
          blurRadius: blur,
          offset: Offset(0, y * .5),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF1A2333).withValues(alpha: a),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
      BoxShadow(
        color: const Color(0xFF1A2333).withValues(alpha: a * .5),
        blurRadius: blur * .4,
        offset: const Offset(0, 2),
      ),
    ];
  }
}

String fmt(double v) {
  if (!v.isFinite) return '0';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String fmtK(double v) {
  final a = v.abs();
  if (a >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}b';
  if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}m';
  if (a >= 100000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (a >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  return fmt(v);
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String uid() =>
    '${nowT().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(9999).toRadixString(36)}';

double? numOf(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String two(int n) => n.toString().padLeft(2, '0');

String fmtClock(int seconds) => '${seconds ~/ 60}:${two(seconds % 60)}';

String fmtClockLong(int seconds) =>
    '${seconds ~/ 3600}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';

/// The app's single clock. Production reads the wall clock; the golden-test
/// harness pins [clock] to a fixed instant so relative times, day buckets and
/// greetings render identically on every run.
DateTime Function()? clock;
DateTime nowT() => (clock ?? DateTime.now)();

/// "now / 4m / 14:32 / yesterday / 12 Mar" — notes, history, day lists.
String relTime(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = nowT();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return L.t('now');
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (d.day == now.day && d.month == now.month && d.year == now.year) {
    return '${two(d.hour)}:${two(d.minute)}';
  }
  final yester = now.subtract(const Duration(days: 1));
  if (d.day == yester.day && d.month == yester.month && d.year == yester.year) {
    return L.t('yesterday');
  }
  final m = monthNames()[d.month - 1];
  return d.year == now.year ? '${d.day} $m' : '${d.day} $m ${d.year}';
}

List<String> monthNames() => L.lang == 'it'
    ? const [
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic',
      ]
    : const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

List<String> weekdayNames() => L.lang == 'it'
    ? const ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom']
    : const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

String fullDate(DateTime d) =>
    '${weekdayNames()[d.weekday - 1]} ${d.day} ${monthNames()[d.month - 1]}';

String initials(String s) {
  final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  if (parts.isEmpty) return '#';
  if (parts.length == 1) {
    final w = parts.first;
    return w.substring(0, math.min(2, w.length)).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

// ============================== PALETTE ==============================

/// Named accent seeds. The app is neutral by default and takes a single hue,
/// so the whole interface shifts together from Settings.
class Accent {
  final String key, label;
  final Color light, dark, tintLight, tintDark;
  const Accent(
    this.key,
    this.label,
    this.light,
    this.dark,
    this.tintLight,
    this.tintDark,
  );

  static const Accent def = Accent(
    'indigo',
    'Indigo',
    Color(0xFF3B5BDB),
    Color(0xFF6E9BFF),
    Color(0xFFE9EEFF),
    Color(0xFF18243E),
  );

  static const List<Accent> all = [
    def,
    Accent(
      'teal',
      'Teal',
      Color(0xFF0B7285),
      Color(0xFF4CD0E0),
      Color(0xFFDCF3F6),
      Color(0xFF102A31),
    ),
    Accent(
      'violet',
      'Violet',
      Color(0xFF6741D8),
      Color(0xFFA78BFA),
      Color(0xFFEFEBFF),
      Color(0xFF211A3C),
    ),
    Accent(
      'amber',
      'Amber',
      Color(0xFFB26A00),
      Color(0xFFF5B14C),
      Color(0xFFFFF3DC),
      Color(0xFF33260F),
    ),
    Accent(
      'rose',
      'Rose',
      Color(0xFFC2255C),
      Color(0xFFF97FA6),
      Color(0xFFFFEAF1),
      Color(0xFF341A24),
    ),
    Accent(
      'moss',
      'Moss',
      Color(0xFF3B7A3B),
      Color(0xFF8FD08A),
      Color(0xFFE7F4E6),
      Color(0xFF1A2A1B),
    ),
  ];

  static Accent byKey(String k) =>
      all.firstWhere((a) => a.key == k, orElse: () => all.first);
}

class Pal {
  final bool dark;
  final Accent seed;
  const Pal(this.dark, [this.seed = Accent.def]);

  Color get bg => dark ? const Color(0xFF0C0E12) : const Color(0xFFF2F4F8);
  Color get surface => dark ? const Color(0xFF151920) : const Color(0xFFFFFFFF);
  Color get surface2 =>
      dark ? const Color(0xFF1C222B) : const Color(0xFFECF0F5);
  Color get surface3 =>
      dark ? const Color(0xFF242C37) : const Color(0xFFE2E8F0);
  Color get line => dark ? const Color(0xFF272F3A) : const Color(0xFFE1E6ED);
  Color get lineStrong =>
      dark ? const Color(0xFF38424F) : const Color(0xFFCBD3DE);
  Color get text => dark ? const Color(0xFFF3F5F9) : const Color(0xFF12161D);
  Color get text2 => dark ? const Color(0xFFB3BCC9) : const Color(0xFF525E6E);
  Color get sub => dark ? const Color(0xFF7B8697) : const Color(0xFF8590A0);
  Color get accent => dark ? seed.dark : seed.light;
  Color get accentSoft => dark ? seed.tintDark : seed.tintLight;
  Color get accentInk =>
      dark ? const Color(0xFF0C0E12) : const Color(0xFFFFFFFF);
  Color get good => dark ? const Color(0xFF5BD48A) : const Color(0xFF14804A);
  Color get warn => dark ? const Color(0xFFF5B14C) : const Color(0xFFA8660A);
  Color get bad => dark ? const Color(0xFFFF6B70) : const Color(0xFFD63B40);
  Color get gold => dark ? const Color(0xFFF7C95B) : const Color(0xFFB77A16);

  /// Soft gradient used by hero surfaces (home header, focus, detail).
  List<Color> get hero => dark ? [surface2, surface] : [accentSoft, surface];

  Color get scrim => Color(0xB3000000);

  Pal get pal => this;

  Pal withAccent(Accent a) => Pal(dark, a);
  Color get bgTop => dark ? const Color(0xFF12151A) : const Color(0xFFFAFBFD);

  /// Note accent colours stay legible on both surfaces.
  Color noteInk(int i) {
    const light = [
      Color(0xFF9AA3AF),
      Color(0xFFB08900),
      Color(0xFF2F6FCC),
      Color(0xFF5B52D6),
      Color(0xFFB9398A),
      Color(0xFF14804A),
    ];
    const darker = [
      Color(0xFF7A8494),
      Color(0xFFF5B14C),
      Color(0xFF6E9BFF),
      Color(0xFFA78BFA),
      Color(0xFFF97FA6),
      Color(0xFF5BD48A),
    ];
    final c = dark ? darker : light;
    return c[i.clamp(0, c.length - 1)];
  }

  Color noteFill(int i) => noteInk(i).withValues(alpha: dark ? .16 : .10);
}

class ThemeScope extends InheritedWidget {
  final Pal pal;
  const ThemeScope({super.key, required this.pal, required super.child});
  static Pal of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeScope>()?.pal ??
      const Pal(false);

  @override
  bool updateShouldNotify(ThemeScope old) =>
      old.pal.dark != pal.dark || old.pal.seed.key != pal.seed.key;
}

// text presets bound to the palette
TextStyle title(Pal p, {double s = 26, Color? c}) =>
    Tk.h1.copyWith(color: c ?? p.text, fontSize: s);
TextStyle body(
  Pal p, {
  double s = 14,
  FontWeight w = FontWeight.w400,
  Color? c,
}) =>
    Tk.body.copyWith(color: c ?? p.text2, fontSize: s, fontWeight: w);
TextStyle cap(Pal p, {Color? c}) =>
    Tk.label.copyWith(color: c ?? p.sub, fontSize: 12);
TextStyle over(Pal p, {Color? c}) =>
    Tk.micro.copyWith(color: c ?? p.sub, fontSize: 10.5);
TextStyle numStyle(Pal p, {double s = 30, Color? c}) =>
    Tk.num.copyWith(color: c ?? p.text, fontSize: s);

/// Card surface: 1px border plus a very soft ambient shadow.
BoxDecoration box(Pal p, {double r = Tk.rCard, bool raised = true}) =>
    BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: p.line, width: 1),
      boxShadow: raised ? Shadow.of(p) : null,
    );

class MarkdownAutoCloseFormatter extends TextInputFormatter {
  static const _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;

    final insertedLen = newValue.text.length - oldValue.text.length;
    if (insertedLen > 3) return newValue;

    final cursor = newValue.selection.baseOffset;
    if (cursor <= 0) return newValue;

    final inserted = newValue.text.substring(cursor - insertedLen, cursor);
    final before = newValue.text.substring(0, cursor);
    final after =
        cursor < newValue.text.length ? newValue.text.substring(cursor) : '';

    if (inserted == '`' && before.endsWith('``')) {
      final newText =
          '${newValue.text.substring(0, cursor - 2)}\n```\n```$after';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor - 1),
      );
    }

    if (inserted == '`') {
      if (after.startsWith('`')) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before`$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    if (inserted == '*' || inserted == '~') {
      if (before.endsWith(inserted)) return newValue;
      if (after.startsWith(inserted)) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before$inserted$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    if (_pairs.containsKey(inserted)) {
      final closing = _pairs[inserted]!;
      if (after.startsWith(closing)) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before$closing$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    return newValue;
  }
}

const noteColors = <Color>[
  Color(0xFFF0F2F4),
  Color(0xFFFFF0B5),
  Color(0xFFDDEAFE),
  Color(0xFFE4E8FF),
  Color(0xFFF6DBEE),
  Color(0xFFDDF4E6),
];

Color noteColor(int index) => noteColors[index.clamp(0, noteColors.length - 1)];

String trimNoteName(String s, {int max = 30}) {
  final clean = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return L.t('untitled');
  if (clean.length <= max) return clean;
  final cut = clean.substring(0, max - 1);
  final lastSpace = cut.lastIndexOf(' ');
  final stem = lastSpace > max * .55 ? cut.substring(0, lastSpace) : cut;
  return '${stem.trim()}…';
}

String fmtTs(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String z(int n) => n.toString().padLeft(2, '0');
  return '${z(d.day)}/${z(d.month)}/${d.year} ${z(d.hour)}:${z(d.minute)}';
}

const it = {
  'home': 'Home',
  'counters': 'Contatori',
  'time': 'Tempo',
  'notes': 'Note',
  'settings': 'Impostazioni',
  'info': 'Info',
  'calendar': 'Calendario',
  'focus': 'Focus',
  'search': 'Cerca…',
  'name': 'Nome',
  'group': 'Cartella',
  'value': 'Valore',
  'step': 'Incremento',
  'symbol': 'Simbolo',
  'mult': 'Moltiplicatore',
  'goals': 'Obiettivi',
  'theme': 'Tema',
  'language': 'Lingua',
  'light': 'Chiaro',
  'dark': 'Scuro',
  'system': 'Sistema',
  'vibration': 'Vibrazione',
  'sound': 'Suono',
  'backup': 'Backup JSON',
  'restore': 'Ripristina',
  'new': 'Nuovo contatore',
  'edit': 'Modifica contatore',
  'save': 'Salva',
  'cancel': 'Annulla',
  'delete': 'Elimina',
  'addNote': 'Aggiungi nota',
  'noCounters': 'Nessun contatore',
  'noCountersSub': 'Aggiungi il tuo primo contatore per iniziare.',
  'noNotes': 'Nessuna nota',
  'morning': 'Buongiorno',
  'afternoon': 'Buon pomeriggio',
  'evening': 'Buonasera',
  'start': 'Avvia',
  'pause': 'Pausa',
  'reset': 'Azzera',
  'minutes': 'min',
  'moneyStep': 'Denaro per incremento',
  'manualMoney': 'Denaro indipendente',
  'goalAction': 'Quando raggiungi un obiettivo',
  'continue': 'Continua',
  'stop': 'Ferma',
  'resetGoal': 'Azzera',
  'selectFolder': 'Scegli cartella',
  'newFolder': 'Nuova cartella',
  'editor': 'Editor',
  'preview': 'Anteprima',
  'markdown': 'Markdown',
  'exportMarkdown': 'Esporta Markdown',
  'importMarkdown': 'Importa Markdown',
  'backupNotes': 'Backup note',
  'noFolder': 'Nessuna cartella',
  'counterStateStopped': 'Obiettivo raggiunto · fermo',
  'money': 'Denaro',
  'overview': 'Panoramica',
  'quickActions': 'Azioni rapide',
  'readyToBegin': 'Pronto a iniziare',
  'notesEvents': 'Note ed eventi',
  'focusSession': 'Sessione focus',
  'focusSessionSub': 'Avvia una sessione calma da 25 minuti.',
  'quickCountersSub': 'Tieni il conto con un tap.',
  'quickCalendarSub': 'Rivedi il giorno e i tuoi eventi.',
  'quickNotesSub': 'Tieni idee e promemoria a portata.',
  'tagline': 'Un posto calmo per contare, concentrarti e riflettere.',
  'total': 'totale',
  'items': 'elementi',
  'all': 'Tutte',
  'foldersAutoSub': 'le cartelle derivano dai tuoi contatori.',
  'untitled': 'senza titolo',
  'options': 'opzioni',
  'keepScreenOn': 'mantieni schermo acceso',
  'stopwatch': 'cronometro',
  'stopStopwatch': 'ferma cronometro',
  'watchHistory': 'cronologia azioni',
  'clearHistory': 'svuota',
  'noHistory': 'nessuna azione',
  'delay': 'ritardo',
  'volumeButtons': 'usa tasti volume',
  'fullscreen': 'schermo intero',
  'exitFullscreen': 'esci da schermo intero',
  'editCounter': 'modifica contatore',
  'noteOptions': 'opzioni nota',
  'properties': 'proprietà',
  'open': 'apri',
  'folder': 'cartella',
  'changeFolder': 'cambia cartella',
  'nothingPlanned': 'Niente in programma.',
  'searchNotesEvents': 'Cerca note ed eventi',
  'searchResults': 'Risultati',
  'size': 'dimensione',
  'path': 'percorso',
  'modified': 'modificata',
  'identity': 'identità',
  'running': 'In corso',
  'ready': 'Pronto',
  'weekdays': 'L,M,M,G,V,S,D',
  'monthsShort': 'gen,feb,mar,apr,mag,giu,lug,ago,set,ott,nov,dic',
  'pin': 'fissa',
  'unpin': 'sblocca',
  'counterStopped': 'Obiettivo raggiunto · fermo',
  'appearance': 'Aspetto',
  'controls': 'Controlli',
  'data': 'Dati',
  'about': 'Info',
  'aboutSub': 'Contatori, focus, calendario e note in uno spazio tranquillo.',
  'backupSub': 'Salva tutti i dati come JSON.',
  'restoreSub': 'Ripristina un backup JSON.',
  'soundSub': 'metti plus.mp3 / minus.mp3 in assets/audio',
  'enableMoney': 'Abilita denaro',
  'goalValue': 'Obiettivo valore',
  'goalMoney': 'Obiettivo denaro',
  'selectFolderToStart': 'Scegli una cartella per iniziare',
  'close': 'Chiudi',
};

const en = {
  'home': 'Home',
  'counters': 'Counters',
  'time': 'Time',
  'notes': 'Notes',
  'settings': 'Settings',
  'info': 'Info',
  'calendar': 'Calendar',
  'focus': 'Focus',
  'search': 'Search…',
  'name': 'Name',
  'group': 'Folder',
  'value': 'Value',
  'step': 'Step',
  'symbol': 'Symbol',
  'mult': 'Multiplier',
  'goals': 'Goals',
  'theme': 'Theme',
  'language': 'Language',
  'light': 'Light',
  'dark': 'Dark',
  'system': 'System',
  'vibration': 'Vibration',
  'sound': 'Sound',
  'backup': 'JSON backup',
  'restore': 'Restore',
  'new': 'New counter',
  'edit': 'Edit counter',
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'addNote': 'Add note',
  'noCounters': 'No counters',
  'noCountersSub': 'Add your first counter to get started.',
  'noNotes': 'No notes',
  'morning': 'Good morning',
  'afternoon': 'Good afternoon',
  'evening': 'Good evening',
  'start': 'Start',
  'pause': 'Pause',
  'reset': 'Reset',
  'minutes': 'min',
  'moneyStep': 'Money per increment',
  'manualMoney': 'Independent money',
  'goalAction': 'When you reach a goal',
  'continue': 'Continue',
  'stop': 'Stop',
  'resetGoal': 'Reset',
  'selectFolder': 'Choose folder',
  'newFolder': 'New folder',
  'editor': 'Editor',
  'preview': 'Preview',
  'markdown': 'Markdown',
  'exportMarkdown': 'Export Markdown',
  'importMarkdown': 'Import Markdown',
  'backupNotes': 'Notes backup',
  'noFolder': 'No folder',
  'counterStateStopped': 'Goal reached · stopped',
  'money': 'Money',
  'overview': 'Overview',
  'quickActions': 'Quick actions',
  'readyToBegin': 'Ready to begin',
  'notesEvents': 'Notes & events',
  'focusSession': 'Focus session',
  'focusSessionSub': 'Start a calm 25 minute session.',
  'quickCountersSub': 'Track a number with one tap.',
  'quickCalendarSub': 'Review the day and your events.',
  'quickNotesSub': 'Keep ideas and reminders nearby.',
  'tagline': 'A calm place to track, focus and reflect.',
  'total': 'total',
  'items': 'items',
  'all': 'All',
  'foldersAutoSub': 'folders are derived from your counters.',
  'untitled': 'untitled',
  'options': 'options',
  'keepScreenOn': 'keep screen on',
  'stopwatch': 'stopwatch',
  'stopStopwatch': 'stop stopwatch',
  'watchHistory': 'action history',
  'clearHistory': 'clear',
  'noHistory': 'no actions yet',
  'delay': 'delay',
  'volumeButtons': 'use volume keys',
  'fullscreen': 'fullscreen',
  'exitFullscreen': 'exit fullscreen',
  'editCounter': 'edit counter',
  'noteOptions': 'note options',
  'properties': 'properties',
  'open': 'open',
  'folder': 'folder',
  'changeFolder': 'change folder',
  'nothingPlanned': 'Nothing planned here.',
  'searchNotesEvents': 'Search notes and events',
  'searchResults': 'Search results',
  'size': 'size',
  'path': 'path',
  'modified': 'modified',
  'identity': 'identity',
  'running': 'Running',
  'ready': 'Ready',
  'weekdays': 'M,T,W,T,F,S,S',
  'monthsShort': 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec',
  'pin': 'pin',
  'unpin': 'unpin',
  'counterStopped': 'Goal reached · stopped',
  'appearance': 'Appearance',
  'controls': 'Controls',
  'data': 'Data',
  'about': 'About',
  'aboutSub':
      'Counters, focus sessions, calendar events and notes in one quiet workspace.',
  'backupSub': 'Save all current data as JSON.',
  'restoreSub': 'Restore an existing JSON backup.',
  'soundSub': 'drop plus.mp3 / minus.mp3 in assets/audio',
  'enableMoney': 'Enable money',
  'goalValue': 'Goal value',
  'goalMoney': 'Goal money',
  'selectFolderToStart': 'Choose a folder to start',
  'close': 'Close',
};

// ============================== MODELS ==============================

class Counter {
  String id, name, group, symbol;
  double value, step, mult;
  double? moneyValue, moneyStep;
  bool moneyEnabled;
  double? goalV, goalM;
  String goalAction;
  bool pinned, stopped;
  int order;

  /// Glyph used on the card avatar so counters are scannable at a glance.
  String icon;

  /// dayKey -> net signed delta applied that day. Powers "today",
  /// sparklines and streaks. Optional on disk: old saves simply start empty.
  Map<String, double> log;

  Counter({
    required this.id,
    required this.name,
    this.group = '',
    this.symbol = '€',
    this.value = 0,
    this.step = 1,
    this.mult = 1,
    this.moneyValue,
    this.moneyStep,
    this.moneyEnabled = false,
    this.goalV,
    this.goalM,
    this.goalAction = 'continue',
    this.pinned = false,
    this.stopped = false,
    this.order = 0,
    this.icon = 'tag',
    Map<String, double>? log,
  }) : log = log ?? {};

  static const List<String> glyphs = [
    'tag',
    'bolt',
    'target',
    'flame',
    'star',
    'hash',
    'note',
    'chart',
    'timer',
    'music',
    'layers',
    'sparkle',
  ];

  bool get usesManualMoney => moneyEnabled && moneyStep != null;

  double get money => !moneyEnabled || mult == 0
      ? 0
      : (usesManualMoney ? (moneyValue ?? 0) : value * mult);

  void ensureMoneySeed() {
    if (usesManualMoney && moneyValue == null) moneyValue = value * mult;
  }

  double get today => log[dayKey(nowT())] ?? 0;

  bool get hasGoal =>
      (goalV != null && goalV! > 0) ||
      (moneyEnabled && goalM != null && goalM! > 0);

  /// 0..1 across every configured goal (value and/or money).
  double get goalRatio {
    final values = <double>[];
    if (goalV != null && goalV! > 0) {
      values.add((value / goalV!).clamp(0.0, 1.0).toDouble());
    }
    if (moneyEnabled && mult != 0 && goalM != null && goalM! > 0) {
      values.add((money / goalM!).clamp(0.0, 1.0).toDouble());
    }
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int get goalPct => (goalRatio * 100).round();

  /// Steps still missing before the nearest unfinished goal.
  int get stepsLeft {
    final targets = <double>[];
    if (goalV != null && goalV! > 0 && value < goalV!)
      targets.add(goalV! - value);
    if (moneyEnabled && goalM != null && goalM! > 0 && money < goalM!) {
      final perUnit = usesManualMoney ? (moneyStep ?? 0) : mult;
      if (perUnit != 0) targets.add((goalM! - money) / perUnit);
    }
    if (targets.isEmpty) return 0;
    final per = step == 0 ? 1 : step.abs();
    return (targets.reduce((a, b) => a < b ? a : b) / per).ceil();
  }

  /// Last [n] daily totals, oldest first, including empty days.
  List<double> trail([int n = 14]) {
    final now = nowT();
    final out = <double>[];
    for (var i = n - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      out.add(log[dayKey(d)] ?? 0);
    }
    return out;
  }

  int get streak {
    var hits = 0;
    final now = nowT();
    for (var i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final v = log[dayKey(d)] ?? 0;
      if (v != 0) {
        hits++;
        continue;
      }
      if (i == 0) continue; // today may still be empty
      break;
    }
    return hits;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'symbol': symbol,
        'value': value,
        'step': step,
        'mult': mult,
        'moneyValue': moneyValue,
        'moneyStep': moneyStep,
        'moneyEnabled': moneyEnabled,
        'goalV': goalV,
        'goalM': goalM,
        'goalAction': goalAction,
        'pinned': pinned,
        'stopped': stopped,
        'order': order,
        if (icon != 'tag') 'icon': icon,
        if (log.isNotEmpty) 'log': log,
      };

  factory Counter.fromJson(Map<String, dynamic> j) => Counter(
        id: j['id'] as String? ?? uid(),
        name: j['name'] as String? ?? 'Counter',
        group: j['group'] as String? ?? '',
        symbol: j['symbol'] as String? ?? '€',
        value: (j['value'] as num? ?? 0).toDouble(),
        step: (j['step'] as num? ?? 1).toDouble(),
        mult: (j['mult'] as num? ?? 1).toDouble(),
        moneyValue: (j['moneyValue'] as num?)?.toDouble(),
        moneyStep: (j['moneyStep'] as num?)?.toDouble(),
        moneyEnabled: j['moneyEnabled'] as bool? ??
            ((j['moneyStep'] as num?) != null || (j['goalM'] as num?) != null),
        goalV: (j['goalV'] as num?)?.toDouble(),
        goalM: (j['goalM'] as num?)?.toDouble(),
        goalAction: j['goalAction'] as String? ?? 'continue',
        pinned: j['pinned'] as bool? ?? false,
        stopped: j['stopped'] as bool? ?? false,
        order: (j['order'] as num? ?? 0).toInt(),
        icon: j['icon'] as String? ?? 'tag',
        log: (j['log'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()),
        ),
      )..ensureMoneySeed();
}

class Note {
  String id, text;
  int ts, color;
  bool pinned;
  String folder, folderUri, uri, fileName;

  Note(
    this.id,
    this.text,
    this.ts, [
    this.color = 0,
    this.pinned = false,
    this.folder = '',
    this.folderUri = '',
    this.uri = '',
    this.fileName = '',
  ]);

  String get name {
    final first = text.split('\n').first.trim();
    final cleanedFirst = first.replaceFirst(RegExp(r'^#+\s*'), '');
    if (first.startsWith('#')) return cleanedFirst;
    if (fileName.trim().isNotEmpty) {
      return fileName.replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
    }
    return cleanedFirst;
  }

  /// First line without its markdown heading marker.
  String get heading {
    final first = text.replaceAll('\r\n', '\n').split('\n').first.trim();
    return first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  }

  /// Body without the title line — used for tile previews.
  String get preview {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final rest = lines.length > 1 ? lines.skip(1).toList() : <String>[];
    final clean = rest
        .join(' ')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'[*_~>#]'), '')
        .replaceAll(RegExp(r'\[[ xX]\]'), '')
        .replaceAll(RegExp(r'(?:^|\s)[-+]\s+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty || clean == heading) return '';
    return clean;
  }

  int get words => text
      .replaceAll(RegExp(r'[`*_>#~]'), ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': text,
        'ts': ts,
        'c': color,
        'pinned': pinned,
        'folder': folder,
        'folderUri': folderUri,
        'uri': uri,
        'fileName': fileName,
      };

  factory Note.fromJson(Map<String, dynamic> j, {String fallbackFolder = ''}) =>
      Note(
        j['id'] as String? ?? uid(),
        j['x'] as String? ?? '',
        (j['ts'] as num? ?? nowT().millisecondsSinceEpoch).toInt(),
        (j['c'] as num? ?? 0).toInt(),
        j['pinned'] as bool? ?? false,
        j['folder'] as String? ?? fallbackFolder,
        j['folderUri'] as String? ?? '',
        j['uri'] as String? ?? '',
        j['fileName'] as String? ?? '',
      );
}

class Prefs {
  Prefs();

  String theme = 'system';
  String lang = 'it';
  bool vibration = true;
  bool sound = false;
  double? goalV, goalM;
  String notesFolder = '';
  String notesFolderUri = '';
  String accent = 'indigo';
  int focusMinutes = 25;
  bool focusAutoNote = true;
  bool focusKeepScreenOn = true;
  int homeLayout = 0;
  String focusSoundUri = '';

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'lang': lang,
        'vib': vibration,
        'sound': sound,
        'ggV': goalV,
        'ggM': goalM,
        'notesFolder': notesFolder,
        'notesFolderUri': notesFolderUri,
        'accent': accent,
        'focusMinutes': focusMinutes,
        'focusAutoNote': focusAutoNote,
        'focusKeepScreenOn': focusKeepScreenOn,
        'homeLayout': homeLayout,
        'focusSoundUri': focusSoundUri,
      };

  factory Prefs.fromJson(Map<String, dynamic> j) {
    final p = Prefs();
    p.theme = j['theme'] as String? ?? 'system';
    p.lang = j['lang'] as String? ?? 'it';
    p.vibration = j['vib'] as bool? ?? true;
    p.sound = j['sound'] as bool? ?? false;
    p.goalV = (j['ggV'] as num?)?.toDouble();
    p.goalM = (j['ggM'] as num?)?.toDouble();
    p.notesFolder = j['notesFolder'] as String? ?? '';
    p.notesFolderUri = j['notesFolderUri'] as String? ?? '';
    p.accent = j['accent'] as String? ?? 'indigo';
    p.focusMinutes = (j['focusMinutes'] as num? ?? 25).toInt().clamp(1, 180);
    p.focusAutoNote = j['focusAutoNote'] as bool? ?? true;
    p.focusKeepScreenOn = j['focusKeepScreenOn'] as bool? ?? true;
    p.homeLayout = (j['homeLayout'] as num? ?? 0).toInt();
    return p;
  }
}

class _Deleted {
  final Counter counter;
  final int index;
  _Deleted(this.counter, this.index);
}

/// One recorded counter change — the base for undo and the action feed.
class Undo {
  final String counterId, label;
  final double delta;
  final int ts;
  final double prevValue, prevMoney;
  final bool prevStopped;
  Undo(
    this.counterId,
    this.label,
    this.delta,
    this.ts,
    this.prevValue,
    this.prevMoney,
    this.prevStopped,
  );
}

class Store extends ChangeNotifier {
  static const channel = MethodChannel('saf');

  List<Counter> counters = [];
  Map<String, List<Note>> notes = {};
  Prefs prefs = Prefs();
  String? dir;
  Timer? saveTimer;

  /// dayKey -> minutes of completed focus.
  Map<String, double> focusLog = {};
  final List<Undo> undos = [];
  final List<_Deleted> trash = [];
  bool dirtySave = false;
  int savedAt = 0;

  Future<void> init() async {
    try {
      // Never block the first frame on the platform side.
      dir = await channel
          .invokeMethod<String>('filesDir')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (dir != null) {
      final f = File('$dir/state.json');
      if (await f.exists()) {
        try {
          load(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        } catch (_) {}
      }
    }

    if (prefs.notesFolderUri.trim().isNotEmpty) {
      await syncNotesFolder(prefs.notesFolder, prefs.notesFolderUri);
    }

    notifyListeners();
  }

  void touch() {
    dirtySave = true;
    notifyListeners();
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 350), save);
  }

  Future<void> save() async {
    if (dir == null) return;
    try {
      await File('$dir/state.json').writeAsString(jsonEncode(toJson()));
      dirtySave = false;
      savedAt = nowT().millisecondsSinceEpoch;
    } catch (_) {}
  }

  Map<String, dynamic> toJson() => {
        'counters': counters.map((e) => e.toJson()).toList(),
        'notes': notes.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'prefs': prefs.toJson(),
        'focus': focusLog,
      };

  void load(Map<String, dynamic> j) {
    counters = (j['counters'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Counter.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final raw = Map<String, dynamic>.from(j['notes'] as Map? ?? {});
    notes = {};
    for (final entry in raw.entries) {
      notes[entry.key] = (entry.value as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => Note.fromJson(
              Map<String, dynamic>.from(e),
              fallbackFolder: 'generale',
            ),
          )
          .toList();
    }

    focusLog = (j['focus'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()),
    );

    prefs = Prefs.fromJson(Map<String, dynamic>.from(j['prefs'] as Map? ?? {}));
  }

  // ---------- platform / files ----------

  Future<Map<String, dynamic>?> pickNotesFolder() async {
    final result = await channel.invokeMethod<dynamic>('pickDirectory');
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  Future<String?> writeNoteFile({
    required String treeUri,
    required String fileName,
    required String content,
    String? existingUri,
  }) async {
    try {
      final result = await channel.invokeMethod<dynamic>('writeTextFile', {
        'treeUri': treeUri,
        'fileName': fileName,
        'content': content,
        'existingUri': existingUri,
      });
      return result is String
          ? result
          : (result is Map ? result['uri'] as String? : null);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> noteFileInfo(String uri) async {
    try {
      final result = await channel.invokeMethod<dynamic>('documentInfo', {
        'uri': uri,
      });
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (_) {}
    return null;
  }

  static Future<String?> pickAudio() async {
    try {
      return await channel.invokeMethod<String>('pickAudioFile');
    } catch (_) {
      return null;
    }
  }

  static Future<void> playChime(String uri) async {
    if (uri.trim().isEmpty) return;
    try {
      await channel.invokeMethod('playNotificationSound', {'uri': uri});
    } catch (_) {}
  }

  static Future<void> setVolumeKeys(bool enabled) async {
    try {
      await channel.invokeMethod('setVolumeButtons', {'enabled': enabled});
    } catch (_) {}
  }

  Future<bool> deleteNoteFile(String uri) async {
    try {
      final result = await channel.invokeMethod<dynamic>('deleteDocument', {
        'uri': uri,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listNotesFiles(String treeUri) async {
    try {
      final result = await channel.invokeMethod<dynamic>('listMarkdownFiles', {
        'treeUri': treeUri,
      });
      if (result is List) {
        return result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<String?> readNoteFile(String uri) async {
    try {
      final result = await channel.invokeMethod<dynamic>('readTextFile', {
        'uri': uri,
      });
      return result is String ? result : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncNotesFolder(String folderName, String treeUri) async {
    if (treeUri.trim().isEmpty) return;

    final files = await listNotesFiles(treeUri);
    final knownUris = <String>{};

    for (final list in notes.values) {
      for (final n in list) if (n.uri.isNotEmpty) knownUris.add(n.uri);
    }

    var changed = false;

    for (final file in files) {
      final uri = (file['uri'] as String? ?? '').trim();
      final name = (file['name'] as String? ?? 'nota.md').trim();
      final modified = (file['lastModified'] as num?)?.toInt() ??
          nowT().millisecondsSinceEpoch;

      if (uri.isEmpty || knownUris.contains(uri)) continue;

      final text = await readNoteFile(uri);
      if (text == null) continue;

      final key = dayKey(DateTime.fromMillisecondsSinceEpoch(modified));
      final n = Note(
        uid(),
        text,
        modified,
        0,
        false,
        folderName,
        treeUri,
        uri,
        name,
      );

      (notes[key] ??= []).add(n);
      knownUris.add(uri);
      changed = true;
    }

    if (changed) touch();
  }

  // ---------- feedback ----------

  void vib([bool strong = false]) {
    if (!prefs.vibration) return;
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void sfx([bool up = true]) {
    if (!prefs.sound) return;
    SystemSound.play(up ? SystemSoundType.click : SystemSoundType.tick);
  }

  // ---------- derived data ----------

  double total() => counters.fold(0.0, (a, c) => a + c.value);
  double money() => counters.fold(0.0, (a, c) => a + c.money);

  double get todayDelta => counters.fold(0.0, (a, c) => a + c.today);

  int get focusToday => (focusLog[dayKey(nowT())] ?? 0).round();

  int get focusWeek {
    var sum = 0.0;
    for (var i = 0; i < 7; i++) {
      sum += focusLog[dayKey(nowT().subtract(Duration(days: i)))] ?? 0;
    }
    return sum.round();
  }

  /// Focus minutes per day, oldest first.
  List<double> focusTrail([int n = 14]) {
    final out = <double>[];
    for (var i = n - 1; i >= 0; i--) {
      out.add(
        focusLog[dayKey(nowT().subtract(Duration(days: i)))] ?? 0,
      );
    }
    return out;
  }

  List<Note> get todayNotes => notes[dayKey(nowT())] ?? const <Note>[];

  int get doneGoals => counters
      .where((c) => c.goalV != null && c.goalV! > 0 && c.value >= c.goalV!)
      .length;

  List<double> weekTrail() {
    final now = nowT();
    final out = <double>[];
    for (var i = 6; i >= 0; i--) {
      final k = dayKey(now.subtract(Duration(days: i)));
      var sum = 0.0;
      for (final c in counters) {
        sum += (c.log[k] ?? 0).abs();
      }
      sum += focusLog[k] ?? 0;
      out.add(sum);
    }
    return out;
  }

  int get weekStreak {
    var hits = 0;
    final now = nowT();
    for (var i = 6; i >= 0; i--) {
      final k = dayKey(now.subtract(Duration(days: i)));
      final active =
          (focusLog[k] ?? 0) > 0 || counters.any((c) => (c.log[k] ?? 0) != 0);
      if (active) hits++;
    }
    return hits;
  }

  List<String> get groups {
    final values = <String>{};
    for (final c in counters) {
      final g = c.group.trim();
      if (g.isNotEmpty) values.add(g);
    }
    final out = values.toList();
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  bool counterExists(String id) => counters.any((c) => c.id == id);

  Counter? byId(String id) {
    for (final c in counters) {
      if (c.id == id) return c;
    }
    return null;
  }

  void removeCounter(String id) {
    counters.removeWhere((c) => c.id == id);
    touch();
  }

  void setOrder(String id, int order) {
    final c = byId(id);
    if (c != null) {
      c.order = order;
      touch();
    }
  }

  List<String> get noteFolders {
    final values = <String>{};
    for (final list in notes.values) {
      for (final n in list) {
        final f = n.folder.trim();
        if (f.isNotEmpty) values.add(f);
      }
    }
    final out = values.toList();
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  List<Note> allNotes([String? folder]) {
    final out = <Note>[];
    for (final v in notes.values) {
      for (final n in v) {
        if (folder == null || folder.isEmpty || n.folder == folder) out.add(n);
      }
    }
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.ts.compareTo(a.ts);
    });
    return out;
  }

  // ---------- mutations ----------

  void bump(Counter c, double delta, {bool silent = false}) {
    if (delta == 0 || c.stopped) return;

    final beforeValue = c.value;
    final beforeMoney = c.money;
    final beforeStopped = c.stopped;

    undos.add(
      Undo(
        c.id,
        delta > 0 ? '+' : '-',
        delta,
        nowT().millisecondsSinceEpoch,
        beforeValue,
        beforeMoney,
        beforeStopped,
      ),
    );
    if (undos.length > 40) undos.removeAt(0);

    c.value += delta;

    final key = dayKey(nowT());
    c.log[key] = (c.log[key] ?? 0) + delta;

    if (c.usesManualMoney) {
      c.ensureMoneySeed();
      c.moneyValue = (c.moneyValue ?? 0) + delta * (c.moneyStep ?? 0);
    }

    final valueGoalHit = c.goalV != null &&
        c.goalV! > 0 &&
        beforeValue < c.goalV! &&
        c.value >= c.goalV!;
    final moneyGoalHit = c.goalM != null &&
        c.goalM! > 0 &&
        beforeMoney < c.goalM! &&
        c.money >= c.goalM!;

    if (valueGoalHit || moneyGoalHit) {
      switch (c.goalAction) {
        case 'stop':
          c.stopped = true;
          break;
        case 'reset':
          c.value = 0;
          if (c.usesManualMoney) c.moneyValue = 0;
          c.stopped = false;
          break;
      }
      if (!silent) {
        goalPulse = c.id;
        goalPulseAt = nowT().millisecondsSinceEpoch;
      }
    }

    touch();
  }

  String? goalPulse;
  int goalPulseAt = 0;

  bool canUndo(Counter c) => undos.isNotEmpty && undos.last.counterId == c.id;

  Counter? undo() {
    if (undos.isEmpty) return null;
    final a = undos.removeLast();
    final c = byId(a.counterId);
    if (c == null) return null;
    final key = dayKey(DateTime.fromMillisecondsSinceEpoch(a.ts));
    c.log[key] = (c.log[key] ?? 0) - a.delta;
    if (c.log[key] == 0) c.log.remove(key);
    c.value = a.prevValue;
    c.stopped = a.prevStopped;
    if (c.usesManualMoney) c.moneyValue = a.prevMoney;
    touch();
    return c;
  }

  void logFocus(int minutes) {
    final k = dayKey(nowT());
    focusLog[k] = (focusLog[k] ?? 0) + minutes;
    touch();
  }

  Note addNote(
    String key,
    String text,
    int color, {
    String folder = '',
    String folderUri = '',
    String uri = '',
  }) {
    final f = folder.trim().isEmpty
        ? (prefs.notesFolder.isEmpty ? 'generale' : prefs.notesFolder)
        : folder.trim();
    final fu = folderUri.isEmpty ? prefs.notesFolderUri : folderUri;

    final baseName =
        text.split('\n').first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    final n = Note(
      uid(),
      text,
      nowT().millisecondsSinceEpoch,
      color,
      false,
      f,
      fu,
      uri,
      safeName.isEmpty ? 'nota.md' : '$safeName.md',
    );

    (notes[key] ??= []).add(n);
    prefs.notesFolder = f;
    prefs.notesFolderUri = fu;
    touch();
    return n;
  }

  void editNote(String key, Note n, String text, int color, {String? folder}) {
    n.text = text;
    n.color = color;
    if (folder != null && folder.trim().isNotEmpty) n.folder = folder.trim();
    prefs.notesFolder = n.folder;
    touch();
  }

  void deleteNote(String key, String id) {
    notes[key]?.removeWhere((e) => e.id == id);
    touch();
  }

  Future<bool> deleteNoteById(String id, {bool deleteFile = false}) async {
    Note? target;

    for (final list in notes.values) {
      final index = list.indexWhere((e) => e.id == id);
      if (index >= 0) {
        target = list[index];
        break;
      }
    }

    for (final list in notes.values) {
      list.removeWhere((e) => e.id == id);
    }
    touch();

    if (deleteFile && target != null && target.uri.isNotEmpty) {
      final ok = await deleteNoteFile(target.uri);
      return ok;
    }

    return true;
  }

  void restoreLast() {
    if (trash.isEmpty) return;
    final d = trash.removeLast();
    if (counterExists(d.counter.id)) return;
    counters.insert(d.index.clamp(0, counters.length).toInt(), d.counter);
    touch();
  }

  void wipeData() {
    counters = [];
    notes = {};
    focusLog = {};
    undos.clear();
    touch();
  }
}

final store = Store();

// ============================== NAV ==============================

class Nav extends ChangeNotifier {
  int screen = 0, timeTab = 0;

  /// 1 = forward, -1 = backward. Drives the slide+fade page transition.
  int dir = 1;
  bool ready = false;
  Counter? editingCounter;
  Counter? viewingCounter;
  Note? editingNote;
  DateTime? editingNoteDate;

  final history = <List<int>>[];

  bool get canExit => history.isEmpty && screen == 0 && timeTab == 0;
  bool get isTab => screen <= 4;

  void readyUp() {
    ready = true;
    notifyListeners();
  }

  void _push(int s, int tab) {
    history.add([screen, timeTab]);
    dir = 1;
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void go(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab) return;
    _push(s, tab);
  }

  void openCounterDetail(Counter counter) {
    viewingCounter = counter;
    _push(8, 0);
  }

  void openCounterEditor([Counter? counter]) {
    editingCounter = counter;
    _push(6, 0);
  }

  void openNoteEditor([Note? note, DateTime? date]) {
    editingNote = note;
    editingNoteDate = date;
    _push(7, 0);
  }

  void jump(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab && history.isEmpty) return;
    final forward = s > (history.isEmpty ? screen : history.last[0]);
    history.clear();
    editingCounter = null;
    viewingCounter = null;
    editingNote = null;
    editingNoteDate = null;
    dir = forward ? 1 : -1;
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void back() {
    dir = -1;

    if (screen == 2 && timeTab == 1) {
      timeTab = 0;
      notifyListeners();
      return;
    }

    if (history.isNotEmpty) {
      final p = history.removeLast();
      screen = p[0];
      timeTab = p[1];

      if (screen == 8 &&
          (viewingCounter == null ||
              !store.counterExists(viewingCounter!.id))) {
        viewingCounter = null;
        screen = 1;
        timeTab = 0;
      }

      notifyListeners();
      return;
    }

    if (screen != 0) {
      screen = 0;
      timeTab = 0;
      editingCounter = null;
      viewingCounter = null;
      editingNote = null;
      editingNoteDate = null;
      notifyListeners();
    }
  }

  void setTab(int v) => setTimeTab(v);

  void setTimeTab(int v) {
    if (timeTab == v) return;
    timeTab = v;
    notifyListeners();
  }
}

final nav = Nav();

// ============================== L10N ==============================

/// Extra keys added with the interface refresh; [L.t] checks these first and
/// then falls back to the original [it] / [en] dictionaries.
const it2 = {
  'now': 'adesso',
  'yesterday': 'ieri',
  'today': 'oggi',
  'week': 'settimana',
  'streak': 'serie',
  'activity': 'attività',
  'left': 'rimasti',
  'toGoal': 'al objetivo',
  'add': 'aggiungi',
  'duplicate': 'duplica',
  'sort': 'ordina',
  'sortManual': 'manuale',
  'sortName': 'nome',
  'sortValue': 'valore',
  'sortRecent': 'recenti',
  'ungrouped': 'senza cartella',
  'folders': 'cartelle',
  'showAll': 'tutti',
  'clear': 'pulisci',
  'undo': 'annulla',
  'ready': 'pronto',
  'nameHint': 'es. Pagine lette',
  'soundSub': 'Suono sui pulsanti + e −',
  'privacyLead':
      'Tutto resta su questo dispositivo: contatori, note e timer sono file che controlli tu.',
  'privacyNet': "L'app non chiede mai il permesso internet.",
  'keepOnTitle': 'Schermo sempre acceso',
  'appName': 'OpenFocusly',
  'appTag': 'contatori, focus, note.',
  'autoNote': 'Nota automatica',
  'autoNoteSub': 'Crea una nota al termine di ogni sessione.',
  'chime': 'Suono di fine',
  'chimeCustom': 'File personalizzato',
  'chimeNone': 'Nessun file audio',
  'color': 'Colore',
  'dangerSub': 'Cancella contatori, note e timer. Non è reversibile.',
  'defaultLength': 'Durata predefinita',
  'deleteFile': 'Elimina il file',
  'deleted': 'Eliminato',
  'done': 'fatte',
  'error': 'Errore',
  'export': 'Esporta note',
  'exportSub': 'Tutte le note in un unico notes.md',
  'feedback': 'Feedback',
  'goalActionSub': 'Cosa succede quando un obiettivo è raggiunto.',
  'icon': 'Icona',
  'import': 'Importa note',
  'importSub': 'Da un file markdown',
  'keepOnSub': 'Impedisce allo schermo di spegnersi',
  'moneySub': 'Mostra il totale in denaro sulla card',
  'next': 'successivo',
  'noNotesSub': 'Scrivi il primo pensiero della giornata.',
  'pinned': 'Fissate',
  'prev': 'precedente',
  'privacySub2': 'Nessun account, nessuna rete, nessuna analisi.',
  'refresh': 'Aggiorna',
  'restored': 'Backup ripristinato',
  'sessions': 'sessioni',
  'stopped': 'In pausa',
  'vibrationSub': 'Piccole vibrazioni sui tocchi',
  'whatsNew': 'Novità',
  'month': 'mese',
  'undone': 'azione annullata',
  'saved': 'salvato',
  'saving': 'salvataggio…',
  'backupOk': 'backup creato',
  'backupFail': 'backup fallito',
  'restoreOk': 'dati ripristinati',
  'restoreFail': 'ripristino fallito',
  'exportOk': 'markdown esportato',
  'exportFail': 'esportazione fallita',
  'importOk': 'note importate',
  'importFail': 'importazione fallita',
  'focusDone': 'sessione completata',
  'focusStart': 'inizia focus',
  'endsAt': 'finisce alle',
  'presets': 'rapidi',
  'duration': 'durata',
  'autoLog': 'nota automatica',
  'focusSub': 'un blocco di tempo pulito, senza distrazioni.',
  'focusSubShort': 'senza distrazioni.',
  'focusTotal': 'totali oggi',
  'minutesShort': 'min',
  'recent': 'recenti',
  'viewAll': 'vedi tutti',
  'pinnedCounters': 'in evidenza',
  'topCounters': 'in movimento',
  'noActivity': 'nessuna attività',
  'noActivitySub': 'toca un contatore per iniziare.',
  'goalReached': 'obiettivo raggiunto',
  'resume': 'riprendi',
  'quickAdd': 'aggiungi rapido',
  'words': 'parole',
  'characters': 'caratteri',
  'readMode': 'lettura',
  'writeMode': 'scrittura',
  'accent': 'colore',
  'accentSub': 'tinta principale dell\'interfaccia.',
  'themeSub': 'chiaro, scuro o sistema.',
  'dataSub': 'tutto resta sul tuo dispositivo.',
  'danger': 'zona pericolosa',
  'deleteAll': 'elimina tutto',
  'deleteAllSub': 'rimuove contatori, note e serie.',
  'deleteAllQ':
      'vuoi davvero eliminare tutti i dati? non è possibile tornare indietro.',
  'version': 'versione',
  'privacy': 'privato e locale',
  'privacySub': 'nessun account, nessuna rete, nessuna analisi.',
  'featureCounters': 'contatori con obiettivi e serie',
  'featureFocus': 'timer di focus e calendario',
  'featureNotes': 'note markdown in file .md reali',
  'featureOffline': 'funziona offline, sempre',
  'madeWith': 'costruito con flutter',
  'longPressOptions': 'tieni premuto per le opzioni',
  'swipeActions': 'scorri per bloccare o eliminare',
  'searchAll': 'cerca in tutto',
  'noResults': 'nessun risultato',
  'noResultsSub': 'prova con un altro termine.',
  'todayPlan': 'il tuo oggi',
  'notesToday': 'note di oggi',
  'weekFocus': 'focus degli ultimi 7 giorni',
  'count': 'conta',
  'focusTab': 'focus',
  'totalMoney': 'denaro totale',
  'editNote': 'modifica nota',
  'newNote': 'nuova nota',
  'date': 'data',
  'changeDate': 'cambia data',
  'colour': 'colore',
  'folderExists': 'usa questa cartella',
  'keepOn': 'schermo sempre acceso',
  'tapAnywhere': 'toca ovunque per +',
  'steps': 'passi',
  'history': 'azioni',
  'lastDays': 'ultimi giorni',
  'showLess': 'mostra meno',
  'hide': 'nascondi',
  'collapse': 'comprimi',
};

const en2 = {
  'now': 'now',
  'yesterday': 'yesterday',
  'today': 'today',
  'week': 'week',
  'streak': 'streak',
  'activity': 'activity',
  'left': 'left',
  'toGoal': 'to goal',
  'add': 'add',
  'duplicate': 'duplicate',
  'sort': 'sort',
  'sortManual': 'manual',
  'sortName': 'name',
  'sortValue': 'value',
  'sortRecent': 'recent',
  'ungrouped': 'no folder',
  'folders': 'folders',
  'showAll': 'all',
  'clear': 'clear',
  'undo': 'undo',
  'ready': 'ready',
  'nameHint': 'e.g. Pages read',
  'appName': 'OpenFocusly',
  'soundSub': 'Click on the + and − buttons',
  'privacyLead':
      'Everything stays on this device: counters, notes and timer data are files you control.',
  'privacyNet': 'The app never asks for internet permission.',
  'keepOnTitle': 'Keep screen on',
  'appTag': 'counters, focus, notes.',
  'autoNote': 'Auto note',
  'autoNoteSub': 'Creates a note when a session ends.',
  'chime': 'Completion sound',
  'chimeCustom': 'Custom file',
  'chimeNone': 'No audio file',
  'color': 'Colour',
  'dangerSub': 'Erases counters, notes and timer data. Cannot be undone.',
  'defaultLength': 'Default length',
  'deleteFile': 'Delete file',
  'deleted': 'Deleted',
  'done': 'done',
  'error': 'Error',
  'export': 'Export notes',
  'exportSub': 'All notes into a single notes.md',
  'feedback': 'Feedback',
  'folderExists': 'use this folder',
  'goalActionSub': 'What happens when a goal is reached.',
  'icon': 'Icon',
  'import': 'Import notes',
  'importSub': 'From a markdown file',
  'keepOnSub': 'Keeps the screen awake',
  'moneySub': 'Shows a money total on the card',
  'next': 'next',
  'noNotesSub': 'Write today’s first thought.',
  'pinned': 'Pinned',
  'prev': 'previous',
  'privacySub2': 'No account, no network, no analytics.',
  'refresh': 'Refresh',
  'restored': 'Backup restored',
  'sessions': 'sessions',
  'stopped': 'Paused',
  'vibrationSub': 'Light buzz on taps',
  'whatsNew': 'What’s new',
  'month': 'month',
  'undone': 'action undone',
  'saved': 'saved',
  'saving': 'saving…',
  'backupOk': 'backup created',
  'backupFail': 'backup failed',
  'restoreOk': 'data restored',
  'restoreFail': 'restore failed',
  'exportOk': 'markdown exported',
  'exportFail': 'export failed',
  'importOk': 'notes imported',
  'importFail': 'import failed',
  'focusDone': 'session complete',
  'focusStart': 'start focus',
  'endsAt': 'ends at',
  'presets': 'quick',
  'duration': 'duration',
  'autoLog': 'auto note',
  'focusSub': 'one clean block of time, no distractions.',
  'focusSubShort': 'no distractions.',
  'focusTotal': 'today',
  'minutesShort': 'min',
  'recent': 'recent',
  'viewAll': 'view all',
  'pinnedCounters': 'pinned',
  'topCounters': 'in motion',
  'noActivity': 'no activity yet',
  'noActivitySub': 'tap a counter to get started.',
  'goalReached': 'goal reached',
  'resume': 'resume',
  'quickAdd': 'quick add',
  'words': 'words',
  'characters': 'characters',
  'readMode': 'read',
  'writeMode': 'write',
  'accent': 'accent',
  'accentSub': 'the colour the whole app takes.',
  'themeSub': 'light, dark or system.',
  'dataSub': 'everything stays on your device.',
  'danger': 'danger zone',
  'deleteAll': 'delete everything',
  'deleteAllSub': 'removes counters, notes and streaks.',
  'deleteAllQ': 'really delete all data? this cannot be undone.',
  'version': 'version',
  'privacy': 'private and local',
  'privacySub': 'no account, no network, no analytics.',
  'featureCounters': 'counters with goals and streaks',
  'featureFocus': 'focus timer and calendar',
  'featureNotes': 'markdown notes as real .md files',
  'featureOffline': 'works offline, always',
  'madeWith': 'built with flutter',
  'longPressOptions': 'long press for options',
  'swipeActions': 'swipe to pin or delete',
  'searchAll': 'search everything',
  'noResults': 'nothing found',
  'noResultsSub': 'try a different word.',
  'todayPlan': 'your today',
  'notesToday': 'notes today',
  'weekFocus': 'focus, last 7 days',
  'count': 'count',
  'focusTab': 'focus',
  'totalMoney': 'total money',
  'editNote': 'edit note',
  'newNote': 'new note',
  'date': 'date',
  'changeDate': 'change date',
  'colour': 'colour',
  'keepOn': 'keep screen on',
  'tapAnywhere': 'tap anywhere for +',
  'steps': 'steps',
  'history': 'actions',
  'lastDays': 'last days',
  'showLess': 'show less',
  'hide': 'hide',
  'collapse': 'collapse',
};

class L {
  static String lang = 'it';
  static String t(String k) {
    final extra = lang == 'en' ? en2[k] : it2[k];
    if (extra != null) return extra;
    return (lang == 'en' ? en[k] : it[k]) ?? k;
  }

  /// Localised "n things" with the singular form used for 1.
  static String n(String key, int value) => '$value ${t(key)}';
}

// ============================== TOASTS ==============================

class _ToastItem {
  final String text, icon;
  final bool bad;
  final String? actionLabel;
  final VoidCallback? onAction;
  _ToastItem(this.text, this.icon, this.bad, this.actionLabel, this.onAction);
}

/// Tiny overlay feed for confirmations (backup, restore, undo, errors).
class Toasts {
  OverlayState? _overlay;
  final List<OverlayEntry> _live = [];

  void attach(OverlayState o) => _overlay = o;

  void show(
    String text, {
    String icon = 'check',
    bool bad = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = _overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastLayer(
        item: _ToastItem(text, icon, bad, null, null),
        onDismissed: () {
          entry.remove();
          _live.remove(entry);
        },
      ),
    );

    if (_live.length > 2) {
      final old = _live.removeAt(0);
      old.remove();
    }

    overlay.insert(entry);
    _live.add(entry);
  }

  void clear() {
    for (final e in _live.toList()) {
      e.remove();
    }
    _live.clear();
  }
}

final toasts = Toasts();

class _ToastLayer extends StatefulWidget {
  final _ToastItem item;
  final VoidCallback onDismissed;
  const _ToastLayer({required this.item, required this.onDismissed});

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    Future.delayed(
      widget.item.actionLabel == null
          ? const Duration(milliseconds: 2400)
          : const Duration(milliseconds: 4600),
      () {
        if (mounted) setState(() => _shown = false);
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) widget.onDismissed();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSlide(
            duration: Tk.base,
            curve: Tk.curve,
            offset: _shown ? Offset.zero : const Offset(0, .6),
            child: AnimatedOpacity(
              duration: Tk.fast,
              opacity: _shown ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tk.gutter),
                child: GestureDetector(
                  onTap: widget.onDismissed,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: p.dark ? p.surface3 : const Color(0xFF1D242F),
                      borderRadius: BorderRadius.circular(Tk.rPill),
                      boxShadow: Shadow.of(p, y: 12, blur: 26, a: .18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconX(
                          widget.item.icon,
                          size: 16,
                          color:
                              widget.item.bad ? p.bad : const Color(0xFF7FE0A8),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            widget.item.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF4F6FA),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.item.actionLabel != null) ...[
                          const SizedBox(width: 10),
                          Pressable(
                            subtle: true,
                            radius: Tk.rPill,
                            pad: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            bg: const Color(0xFFFFFFFF).withValues(alpha: .12),
                            on: () {
                              widget.item.onAction?.call();
                              widget.onDismissed();
                            },
                            child: Text(
                              widget.item.actionLabel!,
                              style: const TextStyle(
                                color: Color(0xFFF4F6FA),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================== ICONS ==============================

/// Hand-drawn 24px grid icon set. Stroke-first, round caps, single weight —
/// one coherent language instead of a mix of filled and outlined marks.
class IconX extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final double weight;

  const IconX(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.weight = 1.7,
  });

  @override
  Widget build(BuildContext c) => CustomPaint(
        size: Size.square(size),
        painter: _Painter(name, color ?? ThemeScope.of(c).pal.text, weight),
      );
}

class _Painter extends CustomPainter {
  final String n;
  final Color c;
  final double weight;

  _Painter(this.n, this.c, this.weight);

  @override
  void paint(Canvas g, Size s) {
    final sc = s.width / 24;
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = weight * sc * .92
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final f = Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    double X(double v) => v * sc;
    double Y(double v) => v * sc;
    void l(double x1, double y1, double x2, double y2) =>
        g.drawLine(Offset(X(x1), Y(y1)), Offset(X(x2), Y(y2)), p);
    void r(double x1, double y1, double x2, double y2, [double rad = 2.5]) =>
        g.drawRRect(
          RRect.fromLTRBR(
            X(x1),
            Y(y1),
            X(x2),
            Y(y2),
            Radius.circular(rad * sc),
          ),
          p,
        );
    void o(double cx, double cy, double rr, [bool fill = false]) =>
        g.drawCircle(Offset(X(cx), Y(cy)), rr * sc, fill ? f : p);
    void arc(double cx, double cy, double rr, double start, double sweep) =>
        g.drawArc(
          Rect.fromCircle(center: Offset(X(cx), Y(cy)), radius: rr * sc),
          start,
          sweep,
          false,
          p,
        );
    void poly(List<double> pts, {bool close = true, bool fill = false}) {
      final path = Path()..moveTo(X(pts[0]), Y(pts[1]));
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(X(pts[i]), Y(pts[i + 1]));
      }
      if (close) path.close();
      g.drawPath(path, fill ? f : p);
    }

    switch (n) {
      case 'home':
        poly([4, 11, 12, 4, 20, 11], close: false);
        r(6, 10.5, 18, 20, 2);
        l(10.5, 20, 10.5, 14.5);
        l(13.5, 20, 13.5, 14.5);
        l(10.5, 14.5, 13.5, 14.5);
        break;
      case 'tag':
        g.drawPath(
          Path()
            ..moveTo(X(4.6), Y(12.2))
            ..lineTo(X(4.6), Y(6.6))
            ..quadraticBezierTo(X(4.6), Y(4.6), X(6.6), Y(4.6))
            ..lineTo(X(12.2), Y(4.6))
            ..lineTo(X(19.4), Y(11.8))
            ..quadraticBezierTo(X(20.2), Y(12.6), X(19.4), Y(13.4))
            ..lineTo(X(13.4), Y(19.4))
            ..quadraticBezierTo(X(12.6), Y(20.2), X(11.8), Y(19.4))
            ..close(),
          p,
        );
        o(8.6, 8.6, 1.15, true);
        break;
      case 'clock':
      case 'timerOff':
        o(12, 12, 8.4);
        l(12, 12, 12, 7.2);
        l(12, 12, 15.4, 13.6);
        break;
      case 'note':
        r(5.5, 3.5, 18.5, 20.5, 2.5);
        l(8.5, 8, 15.5, 8);
        l(8.5, 12, 15.5, 12);
        l(8.5, 16, 12.8, 16);
        break;
      case 'settings':
        l(4, 7.5, 20, 7.5);
        l(4, 12, 20, 12);
        l(4, 16.5, 20, 16.5);
        o(15, 7.5, 1.9, true);
        o(8.5, 12, 1.9, true);
        o(13.5, 16.5, 1.9, true);
        break;
      case 'info':
        o(12, 12, 8.6);
        o(12, 8.1, .85, true);
        l(12, 11.4, 12, 16.4);
        break;
      case 'alert':
        o(12, 12, 8.6);
        l(12, 7.6, 12, 13);
        o(12, 16.2, .85, true);
        break;
      case 'plus':
        l(12, 5, 12, 19);
        l(5, 12, 19, 12);
        break;
      case 'minus':
        l(5, 12, 19, 12);
        break;
      case 'x':
      case 'close':
        l(6.4, 6.4, 17.6, 17.6);
        l(17.6, 6.4, 6.4, 17.6);
        break;
      case 'check':
        poly([5, 12.6, 9.8, 17.2, 19, 7.2], close: false);
        break;
      case 'left':
      case 'chevronLeft':
        poly([15, 5.5, 9, 12, 15, 18.5], close: false);
        break;
      case 'right':
      case 'chevronRight':
        poly([9, 5.5, 15, 12, 9, 18.5], close: false);
        break;
      case 'up':
        l(12, 5, 12, 19);
        l(6.2, 10.6, 12, 5);
        l(17.8, 10.6, 12, 5);
        break;
      case 'down':
        l(12, 19, 12, 5);
        l(6.2, 13.4, 12, 19);
        l(17.8, 13.4, 12, 19);
        break;
      case 'folder':
        poly([4, 8.5, 9.5, 8.5, 11.5, 11, 20, 11], close: false);
        r(4, 8.5, 20, 19.5, 2.5);
        break;
      case 'folderOpen':
        poly([4, 8.5, 9.5, 8.5, 11.5, 11, 20, 11], close: false);
        poly([4, 19.5, 6.5, 13.5, 22, 13.5, 19.5, 19.5], close: true);
        break;
      case 'pin':
        poly([
          9,
          3.5,
          15,
          3.5,
          14,
          9.5,
          16.5,
          12,
          7.5,
          12,
          10,
          9.5,
        ], close: true);
        l(12, 12, 12, 20.5);
        break;
      case 'trash':
        r(6.5, 8, 17.5, 20, 2);
        l(4.5, 8, 19.5, 8);
        l(9.5, 5.5, 14.5, 5.5);
        l(9.5, 5.5, 9.5, 8);
        l(14.5, 5.5, 14.5, 8);
        l(10, 11.5, 10, 16.5);
        l(14, 11.5, 14, 16.5);
        break;
      case 'play':
        poly([8.5, 6, 18, 12, 8.5, 18], close: true, fill: true);
        break;
      case 'pause':
        r(7.5, 6, 10.2, 18, 1.2);
        r(13.8, 6, 16.5, 18, 1.2);
        break;
      case 'stop':
        r(7, 7, 17, 17, 2);
        break;
      case 'refresh':
        arc(12, 12.4, 8.2, -1.13, 5.0);
        poly([15.6, 2.4, 18.8, 5.4, 14.6, 7.4], close: true, fill: true);
        break;
      case 'bolt':
        poly(
          [13.6, 3, 7, 13, 11.4, 13, 10.4, 21, 17, 10.6, 12.6, 10.6],
          close: true,
          fill: true,
        );
        break;
      case 'target':
        o(12, 12, 8.4);
        o(12, 12, 4.4);
        o(12, 12, 1, true);
        break;
      case 'more':
        o(6, 12, 1.15, true);
        o(12, 12, 1.15, true);
        o(18, 12, 1.15, true);
        break;
      case 'moreV':
        o(12, 5.6, 1.15, true);
        o(12, 12, 1.15, true);
        o(12, 18.4, 1.15, true);
        break;
      case 'calendar':
        r(4, 6, 20, 20, 2.5);
        l(4, 10, 20, 10);
        l(8.5, 4, 8.5, 7.5);
        l(15.5, 4, 15.5, 7.5);
        o(8.5, 14.2, .95, true);
        l(12, 13.6, 15.5, 13.6);
        l(12, 17, 15.5, 17);
        break;
      case 'search':
        o(11, 11, 6.4);
        l(15.8, 15.8, 20, 20);
        break;
      case 'sun':
        o(12, 12, 4.4);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          l(
            12 + math.cos(a) * 7,
            12 + math.sin(a) * 7,
            12 + math.cos(a) * 9.6,
            12 + math.sin(a) * 9.6,
          );
        }
        break;
      case 'moon':
        final outer = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(X(12.4), Y(12.6)), radius: 8.6 * sc),
          );
        final bite = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(X(17.6), Y(8.0)), radius: 7.8 * sc),
          );
        g.drawPath(
          ui.Path.combine(ui.PathOperation.difference, outer, bite),
          f,
        );
        break;
      case 'auto':
        r(4, 4, 20, 20, 3);
        g.save();
        g.clipPath(Path()..addRect(Rect.fromLTWH(X(4), Y(4), X(8), Y(16))));
        g.drawRRect(
          RRect.fromLTRBR(X(4), Y(4), X(20), Y(20), Radius.circular(3 * sc)),
          f,
        );
        g.restore();
        r(4, 4, 20, 20, 3);
        break;
      case 'globe':
        o(12, 12, 8.4);
        l(3.6, 12, 20.4, 12);
        arc(12, 12, 8.4, -1.9, 3.8);
        g.save();
        g.drawOval(
          Rect.fromCenter(
            center: Offset(X(12), Y(12)),
            width: X(7.4),
            height: Y(16.8),
          ),
          p,
        );
        g.restore();
        break;
      case 'vibrate':
        r(8.5, 4.5, 15.5, 19.5, 2.5);
        l(4.5, 9, 4.5, 15);
        l(19.5, 9, 19.5, 15);
        break;
      case 'speaker':
      case 'sound':
        poly([
          4,
          9.5,
          8,
          9.5,
          12.5,
          5.5,
          12.5,
          18.5,
          8,
          14.5,
          4,
          14.5,
        ], close: true);
        arc(13.5, 12, 5.4, -1.05, 2.1);
        arc(13.5, 12, 8.4, -1.05, 2.1);
        break;
      case 'mute':
        poly([
          4,
          9.5,
          8,
          9.5,
          12.5,
          5.5,
          12.5,
          18.5,
          8,
          14.5,
          4,
          14.5,
        ], close: true);
        l(16, 9.8, 20.5, 14.2);
        l(20.5, 9.8, 16, 14.2);
        break;
      case 'upload':
        l(12, 4.5, 12, 14.5);
        poly([7.6, 8.9, 12, 4.5, 16.4, 8.9], close: false);
        r(4, 16, 20, 20.5, 2.5);
        break;
      case 'download':
        l(12, 14.5, 12, 4.5);
        poly([7.6, 10.1, 12, 14.5, 16.4, 10.1], close: false);
        r(4, 16, 20, 20.5, 2.5);
        break;
      case 'edit':
        poly([
          4.5,
          19.5,
          5.4,
          15.8,
          15.8,
          5.4,
          18.6,
          8.2,
          8.2,
          18.6,
        ], close: true);
        l(14, 7.2, 16.8, 10);
        break;
      case 'eye':
        eyePath(g, p, sc);
        o(12, 12, 2.9);
        break;
      case 'eyeOff':
        eyePath(g, p, sc);
        l(4.8, 19.2, 19.2, 4.8);
        break;
      case 'history':
        arc(12, 12.5, 8, 0.6, 4.6);
        poly([4.2, 11.4, 4.2, 15.6, 8.4, 15.6], close: false);
        l(12, 8.4, 12, 12.6);
        l(12, 12.6, 15.4, 14.4);
        break;
      case 'flame':
        poly([
          12,
          3.5,
          16.5,
          8.5,
          17.8,
          13,
          12,
          20.5,
          6.2,
          13,
          7.5,
          8.5,
        ], close: true);
        arc(12, 14.5, 3.2, 0.2, 2.9);
        break;
      case 'chart':
        l(4, 20, 20, 20);
        r(5.5, 12.5, 8.5, 18, 1);
        r(10.8, 8, 13.8, 18, 1);
        r(16, 4.5, 19, 18, 1);
        break;
      case 'sparkle':
        poly(
          [
            12,
            3.5,
            13.6,
            9.2,
            19.5,
            11,
            13.6,
            12.8,
            12,
            18.5,
            10.4,
            12.8,
            4.5,
            11,
            10.4,
            9.2,
          ],
          close: true,
          fill: true,
        );
        o(18.5, 17.5, 1.1, true);
        break;
      case 'star':
        poly([
          12,
          4,
          14.4,
          9.4,
          20.3,
          9.9,
          15.8,
          13.7,
          17.2,
          19.5,
          12,
          16.3,
          6.8,
          19.5,
          8.2,
          13.7,
          3.7,
          9.9,
          9.6,
          9.4,
        ], close: true);
        break;
      case 'layers':
        poly([12, 3.8, 20.5, 8.4, 12, 13, 3.5, 8.4], close: true);
        l(4.6, 12.4, 4.6, 15.6);
        poly([12, 13.4, 20.5, 15.6, 12, 20.4, 3.5, 15.6], close: true);
        break;
      case 'copy':
        r(8.5, 8.5, 20, 20, 2.5);
        poly([4.5, 15.5, 4.5, 4.5, 15.5, 4.5], close: false);
        break;
      case 'shield':
        poly([
          12,
          3.5,
          19.5,
          6.4,
          19.5,
          12.5,
          12,
          20.5,
          4.5,
          12.5,
          4.5,
          6.4,
        ], close: true);
        poly([8.8, 11.8, 11.4, 14.4, 15.6, 9.6], close: false);
        break;
      case 'link':
        g.save();
        g.translate(X(12), Y(12));
        g.rotate(-.7854);
        g.drawRRect(
          RRect.fromLTRBR(
            -9.2 * sc,
            -3.2 * sc,
            -1.2 * sc,
            3.2 * sc,
            Radius.circular(3.2 * sc),
          ),
          p,
        );
        g.drawRRect(
          RRect.fromLTRBR(
            1.2 * sc,
            -3.2 * sc,
            9.2 * sc,
            3.2 * sc,
            Radius.circular(3.2 * sc),
          ),
          p,
        );
        g.restore();
        break;
      case 'bold':
        arc(10.5, 8.4, 3.4, -1.6, 3.2);
        arc(10.5, 15.6, 4, 0, 3.2);
        l(6.5, 5, 6.5, 19);
        l(6.5, 12.2, 10.5, 12.2);
        break;
      case 'italic':
        l(9, 5, 17, 5);
        l(7, 19, 15, 19);
        l(14, 5, 10, 19);
        break;
      case 'code':
        poly([8.6, 7, 4, 12, 8.6, 17], close: false);
        poly([15.4, 7, 20, 12, 15.4, 17], close: false);
        break;
      case 'list':
        o(5.2, 7, 1, true);
        o(5.2, 12, 1, true);
        o(5.2, 17, 1, true);
        l(9, 7, 19.5, 7);
        l(9, 12, 19.5, 12);
        l(9, 17, 16, 17);
        break;
      case 'heading':
        l(6, 19, 6, 5);
        l(15, 19, 15, 5);
        l(6, 12, 15, 12);
        l(17.5, 8, 20.5, 8);
        l(20.5, 8, 18, 19);
        break;
      case 'quote':
        poly([5, 12, 5, 6.5, 10.5, 6.5, 10.5, 12], close: false);
        l(10.5, 12, 7, 18);
        poly([13.5, 12, 13.5, 6.5, 19, 6.5, 19, 12], close: false);
        l(19, 12, 15.5, 18);
        break;
      case 'strike':
        g.drawPath(
          Path()
            ..moveTo(X(8), Y(7.6))
            ..cubicTo(X(16.5), Y(5.4), X(17), Y(11), X(12), Y(12))
            ..cubicTo(X(7), Y(13), X(7.6), Y(18.6), X(16.2), Y(16.4)),
          p,
        );
        l(4.5, 12, 19.5, 12);
        break;
      case 'grid':
        r(4, 4, 11, 11, 2);
        r(13, 4, 20, 11, 2);
        r(4, 13, 11, 20, 2);
        r(13, 13, 20, 20, 2);
        break;
      case 'rows':
        r(4, 4.5, 20, 10, 2);
        r(4, 12, 20, 17.5, 2);
        break;
      case 'palette':
        arc(12, 12.5, 8.4, -2.9, 4.6);
        poly([17.5, 6.5, 20.4, 9.4, 15.5, 12.5], close: true);
        o(9, 9.5, 1.1, true);
        o(7.6, 13.5, 1.1, true);
        o(11, 16.6, 1.1, true);
        break;
      case 'hash':
        l(9, 4.5, 7, 19.5);
        l(17, 4.5, 15, 19.5);
        l(5, 9.5, 20, 9.5);
        l(4.2, 14.8, 19.2, 14.8);
        break;
      case 'sort':
        l(5, 7, 15, 7);
        l(5, 12, 12, 12);
        l(5, 17, 9, 17);
        poly([18.6, 8.4, 18.6, 17.4], close: false);
        poly([16.6, 15.4, 18.6, 18, 20.6, 15.4], close: false);
        break;
      case 'filter':
        poly([
          4,
          5.5,
          20,
          5.5,
          14,
          12.5,
          14,
          19,
          10,
          17,
          10,
          12.5,
        ], close: true);
        break;
      case 'keyboard':
        r(3, 6.5, 21, 17.5, 2.5);
        o(6.5, 10.5, .8, true);
        o(9.8, 10.5, .8, true);
        o(13.1, 10.5, .8, true);
        o(16.4, 10.5, .8, true);
        l(8, 14.2, 16, 14.2);
        break;
      case 'music':
        o(7.5, 17, 2.9);
        l(10.4, 17, 10.4, 5.5);
        l(10.4, 5.5, 18, 4);
        l(18, 4, 18, 8.4);
        break;
      case 'keys':
        o(8.5, 9, 3.4);
        l(11, 11.4, 15, 15.4);
        l(13.4, 17, 15, 15.4);
        l(16.6, 13.8, 18.2, 15.4);
        break;
      case 'lock':
        r(5.5, 10.5, 18.5, 20, 2.5);
        arc(12, 10.5, 4, 3.14, 3.14);
        l(8, 10.5, 8, 8);
        l(16, 10.5, 16, 8);
        o(12, 15, 1.1, true);
        break;
      case 'bell':
        poly([6.5, 16.5, 6.5, 11, 12, 4.5, 17.5, 11, 17.5, 16.5], close: false);
        l(4.5, 16.5, 19.5, 16.5);
        arc(12, 19, 2.4, 0, 3.14);
        break;
      case 'drag':
        o(9.5, 6.5, 1.05, true);
        o(14.5, 6.5, 1.05, true);
        o(9.5, 12, 1.05, true);
        o(14.5, 12, 1.05, true);
        o(9.5, 17.5, 1.05, true);
        o(14.5, 17.5, 1.05, true);
        break;
      case 'hourglass':
        poly([6.5, 4, 17.5, 4, 12, 12, 17.5, 20, 6.5, 20, 12, 12], close: true);
        break;
      case 'check_circle':
        o(12, 12, 8.6);
        poly([8, 12.3, 11, 15.2, 16.4, 9.2], close: false);
        break;
      case 'split':
        r(4, 4.5, 11, 11.5, 2);
        r(13, 12.5, 20, 19.5, 2);
        l(11, 8, 16, 8);
        l(16, 8, 16, 12.5);
        break;
      case 'expand':
        poly([4, 9.5, 4, 4, 9.5, 4], close: false);
        poly([14.5, 4, 20, 4, 20, 9.5], close: false);
        poly([20, 14.5, 20, 20, 14.5, 20], close: false);
        poly([9.5, 20, 4, 20, 4, 14.5], close: false);
        break;
      case 'contract':
        poly([9.5, 4, 9.5, 9.5, 4, 9.5], close: false);
        poly([14.5, 4, 14.5, 9.5, 20, 9.5], close: false);
        poly([20, 14.5, 14.5, 14.5, 14.5, 20], close: false);
        poly([4, 14.5, 9.5, 14.5, 9.5, 20], close: false);
        break;
      case 'dot':
        o(12, 12, 3.2, true);
        break;
      default:
        o(12, 12, 7);
        l(12, 8.5, 12, 12);
        l(12, 12, 15, 14);
    }
  }

  static void eyePath(Canvas g, Paint p, double sc) {
    g.drawPath(
      Path()
        ..moveTo(3.2 * sc, 12 * sc)
        ..quadraticBezierTo(12 * sc, 5 * sc, 20.8 * sc, 12 * sc)
        ..quadraticBezierTo(12 * sc, 19 * sc, 3.2 * sc, 12 * sc)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.n != n || old.c != c || old.weight != weight;
}

// ============================== PRIMITIVES ==============================

/// The one interactive primitive everything is built on: press feedback,
/// hover state, keyboard focus ring, cursor and semantics.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? on;
  final VoidCallback? onLong;
  final VoidCallback? onLongStart;
  final VoidCallback? onLongEnd;
  final EdgeInsets pad;
  final double radius;
  final Color? bg;
  final Color? border;
  final bool filled;
  final bool subtle;
  final double scale;
  final String? sem;
  final Alignment? align;

  const Pressable({
    super.key,
    required this.child,
    this.on,
    this.onLong,
    this.onLongStart,
    this.onLongEnd,
    this.pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = Tk.rChip,
    this.bg,
    this.border,
    this.filled = false,
    this.subtle = false,
    this.scale = .975,
    this.sem,
    this.align,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  final FocusNode _fn = FocusNode();
  bool _down = false, _hover = false, _kb = false;

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  bool get _enabled => widget.on != null || widget.onLong != null;

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final base = widget.filled ? p.accent : (widget.bg ?? clear);
    final pressed = widget.filled
        ? Color.alphaBlend(const Color(0x22000000), base)
        : Color.alphaBlend(
            (widget.subtle ? p.text : p.accent).withValues(alpha: .08),
            base,
          );
    final shown = _down
        ? pressed
        : (_hover && !_down
            ? Color.alphaBlend(
                (widget.subtle ? p.text : p.accent).withValues(alpha: .055),
                base,
              )
            : base);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.sem,
      child: Focus(
        focusNode: _fn,
        canRequestFocus: _enabled,
        debugLabel: 'pressable:${widget.sem ?? ''}',
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            setState(() => _down = true);
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent &&
              (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            setState(() => _down = false);
            widget.on?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (has) {
          _kb = FocusManager.instance.highlightMode ==
              FocusHighlightMode.traditional;
          if (!has && _down) {
            setState(() => _down = false);
          } else if (has) {
            setState(() {});
          }
        },
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() {
            _kb = false;
            _hover = true;
          }),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.on,
            onLongPress: widget.onLong,
            onLongPressStart: widget.onLongStart == null
                ? null
                : (_) => widget.onLongStart!(),
            onLongPressEnd:
                widget.onLongEnd == null ? null : (_) => widget.onLongEnd!(),
            onLongPressCancel: widget.onLongEnd,
            onTapDown: _enabled
                ? (_) {
                    _fn.requestFocus();
                    setState(() => _down = true);
                  }
                : null,
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            child: AnimatedScale(
              duration: _down ? Tk.instant : Tk.fast,
              curve: Tk.curve,
              scale: _down && _enabled ? widget.scale : 1,
              child: AnimatedContainer(
                duration: Tk.fast,
                curve: Tk.curve,
                alignment: widget.align,
                padding: widget.pad,
                decoration: BoxDecoration(
                  color: shown,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: widget.border != null
                      ? Border.all(color: widget.border!)
                      : (_kb && _fn.hasFocus
                          ? Border.all(color: p.accent, width: 1.6)
                          : null),
                  boxShadow: widget.filled
                      ? [
                          BoxShadow(
                            color: p.accent.withValues(alpha: _down ? .16 : .3),
                            blurRadius: _down ? 8 : 16,
                            offset: Offset(0, _down ? 2 : 5),
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Btn extends StatelessWidget {
  final Widget child;
  final VoidCallback? on;
  final VoidCallback? onLong;
  final bool filled;
  final EdgeInsets pad;
  final double radius;
  final Color? bg;
  final Color? border;
  final String? sem;

  const Btn({
    super.key,
    required this.child,
    this.on,
    this.onLong,
    this.filled = false,
    this.pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = 11,
    this.bg,
    this.border,
    this.sem,
  });

  @override
  Widget build(BuildContext c) => Pressable(
        on: on,
        onLong: onLong,
        filled: filled,
        pad: pad,
        radius: radius,
        bg: bg,
        border: border,
        sem: sem,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: filled
                ? ThemeScope.of(c).pal.accentInk
                : ThemeScope.of(c).pal.text,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          child: child,
        ),
      );
}

/// 44x44 minimum touch target with a visible label for screen readers.
class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? on;
  final VoidCallback? onLong;
  final double size;
  final String? sem;
  final Color? color;
  final Color? bg;
  final bool ring;

  const IconBtn({
    super.key,
    required this.icon,
    this.on,
    this.onLong,
    this.size = 19,
    this.sem,
    this.color,
    this.bg,
    this.ring = false,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: on,
      onLong: onLong,
      subtle: true,
      sem: sem ?? icon,
      radius: Tk.rPill,
      pad: const EdgeInsets.all(11),
      bg: bg,
      child: IconX(
        icon,
        size: size,
        color: color ?? (bg == null ? p.text2 : p.text),
      ),
    );
  }
}

/// Rounded square icon holder — the app's visual signature.
class IconTile extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color, bg;
  final double radius;
  const IconTile(
    this.icon, {
    super.key,
    this.size = 38,
    this.color,
    this.bg,
    this.radius = Tk.rIcon,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? p.accentSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: IconX(
          icon,
          size: size * .47,
          color: color ?? p.accent,
          weight: 1.8,
        ),
      ),
    );
  }
}

/// Tappable surface card.
class Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? on;
  final VoidCallback? onLong;
  final VoidCallback? onLongStart;
  final VoidCallback? onLongEnd;
  final EdgeInsets pad;
  final double radius;
  final Color? bg;
  final bool border;
  final String? sem;

  const Card({
    super.key,
    required this.child,
    this.on,
    this.onLong,
    this.onLongStart,
    this.onLongEnd,
    this.pad = const EdgeInsets.all(14),
    this.radius = Tk.rCard,
    this.bg,
    this.border = true,
    this.sem,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final body = Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: p.line) : null,
        boxShadow: Shadow.of(p),
      ),
      child: child,
    );
    if (on == null && onLong == null) return body;
    return Pressable(
      on: on,
      onLong: onLong,
      sem: sem,
      radius: radius,
      subtle: true,
      pad: EdgeInsets.zero,
      bg: bg ?? p.surface,
      child: body,
    );
  }
}

// ---------------- inputs ----------------

class Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String? hint;
  final String? label;
  final String? icon;
  final TextInputType? type;
  final int maxLines;
  final bool clear;
  final String? sem;
  final VoidCallback? onSubmit;
  final TextInputAction? action;
  final FocusNode? focus;
  final List<TextInputFormatter>? formatter;
  final int? maxChars;
  final String? suffix;
  final bool alignEnd;

  const Field({
    super.key,
    required this.ctrl,
    this.hint,
    this.label,
    this.icon,
    this.type,
    this.maxLines = 1,
    this.clear = false,
    this.sem,
    this.onSubmit,
    this.action,
    this.focus,
    this.maxChars,
    this.formatter,
    this.suffix,
    this.alignEnd = false,
  });

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final FocusNode node = widget.focus ?? FocusNode();
  bool _ownsNode = true;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focus == null;
    widget.ctrl.addListener(_changed);
    node.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_changed);
    node.removeListener(_changed);
    if (_ownsNode) node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final active = node.hasFocus;
    final filled = widget.ctrl.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: over(p).copyWith(fontSize: 10)),
          const SizedBox(height: 5),
        ],
        AnimatedContainer(
          duration: Tk.fast,
          padding: EdgeInsets.symmetric(
            horizontal: widget.icon == null ? 12 : 10,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active ? p.surface : p.surface2,
            borderRadius: BorderRadius.circular(Tk.rField),
            border: Border.all(
              color: active ? p.accent : p.line,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: .13),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                IconX(widget.icon!, size: 16, color: active ? p.accent : p.sub),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      if (!filled && widget.hint != null)
                        IgnorePointer(
                          child: Text(
                            widget.hint!,
                            style: body(p, c: p.sub, s: 14),
                          ),
                        ),
                      EditableText(
                        controller: widget.ctrl,
                        focusNode: node,
                        style: TextStyle(
                          fontFamily: Tk.font,
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        cursorColor: p.accent,
                        backgroundCursorColor: p.sub,
                        keyboardType: widget.type,
                        textInputAction: widget.action,
                        onEditingComplete: widget.onSubmit,
                        maxLines: widget.maxLines,
                        minLines: widget.maxLines > 1 ? widget.maxLines : null,
                        inputFormatters: [
                          ...?widget.formatter,
                          if (widget.maxChars != null)
                            LengthLimitingTextInputFormatter(widget.maxChars),
                        ],
                        textAlign:
                            widget.alignEnd ? TextAlign.end : TextAlign.start,
                        enableInteractiveSelection: true,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 6),
                Text(widget.suffix!, style: cap(p, c: p.sub)),
                const SizedBox(width: 4),
              ],
              if (widget.clear && filled)
                Pressable(
                  sem: L.t('clear'),
                  subtle: true,
                  radius: Tk.rPill,
                  pad: const EdgeInsets.all(5),
                  on: () => widget.ctrl.clear(),
                  child: IconX('x', size: 14, color: p.sub),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// iOS-style switch with a springy knob.
class Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> on;
  final String? sem;
  const Toggle({super.key, required this.value, required this.on, this.sem});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Pressable(
      radius: Tk.rPill,
      pad: EdgeInsets.zero,
      sem: sem,
      on: () => on(!value),
      child: Semantics(
        toggled: value,
        child: AnimatedContainer(
          duration: Tk.base,
          curve: Tk.curve,
          width: 46,
          height: 27,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? p.accent : p.surface3,
            borderRadius: BorderRadius.circular(Tk.rPill),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: .28),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: AnimatedAlign(
            duration: Tk.base,
            curve: Tk.curveBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: white,
                shape: BoxShape.circle,
                boxShadow: Shadow.of(p, y: 2, blur: 5, a: .18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control with a sliding pill behind the labels.
class Segmented extends StatelessWidget {
  final int value;
  final List<String> labels;
  final List<String>? icons;
  final ValueChanged<int> on;
  final double? width;
  final String? sem;

  const Segmented({
    super.key,
    required this.value,
    required this.labels,
    required this.on,
    this.icons,
    this.width,
    this.sem,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final n = labels.length;
    return Container(
      width: width,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.line),
      ),
      child: LayoutBuilder(
        builder: (_, q) {
          final cell = (q.maxWidth - 6) / n;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Tk.base,
                curve: Tk.curve,
                left: 3 + cell * value,
                top: 3,
                bottom: 3,
                width: cell,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: Shadow.of(p, y: 1, blur: 4, a: .09),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Pressable(
                        on: () => on(i),
                        subtle: true,
                        radius: 7,
                        pad: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 7,
                        ),
                        sem: sem ?? labels[i],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (icons != null) ...[
                              IconX(
                                icons![i],
                                size: 13,
                                color: value == i ? p.text : p.sub,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: value == i ? p.text : p.sub,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal filter / action chips.
class Chip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool active;
  final VoidCallback on;
  final VoidCallback? onLong;
  final Color? color;
  final Widget? trailing;

  const Chip({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
    required this.on,
    this.onLong,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final ink = color ?? (active ? p.accent : p.text2);
    return Pressable(
      on: on,
      onLong: onLong,
      subtle: true,
      radius: Tk.rPill,
      pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      bg: active ? p.accentSoft : p.surface,
      border: active ? p.accent.withValues(alpha: .55) : p.line,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconX(icon!, size: 13, color: ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  final List<Widget> children;
  final double pad;
  const ChipRow(this.children, {super.key, this.pad = Tk.gutter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

// ---------------- data display ----------------

class Progress extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  final bool glow;
  const Progress({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final v = value.clamp(0.0, 1.0).toDouble();
    final ink = color ?? p.accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tk.rPill),
      child: Container(
        height: height,
        color: p.surface3.withValues(alpha: p.dark ? .55 : .8),
        child: Stack(
          children: [
            AnimatedFractionallySizedBox(
              duration: Tk.slow,
              curve: Tk.curve,
              widthFactor: v,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.alphaBlend(white.withValues(alpha: .22), ink),
                      ink,
                    ],
                  ),
                  boxShadow: glow
                      ? [
                          BoxShadow(
                            color: ink.withValues(alpha: .45),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radial progress with a gradient sweep — focus timer and goal rings.
class Ring extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final bool tick;
  final Widget? child;

  const Ring({
    super.key,
    required this.value,
    this.size = 200,
    this.stroke = 10,
    this.color,
    this.tick = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              p,
              value.clamp(0.0, 1.0).toDouble(),
              stroke,
              color ?? p.accent,
              tick,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Pal p;
  final double v;
  final double stroke;
  final Color ink;
  final bool tick;

  _RingPainter(this.p, this.v, this.stroke, this.ink, this.tick);

  @override
  void paint(Canvas g, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - stroke / 2 - 1;

    g.drawCircle(
      c,
      r,
      Paint()
        ..color = p.surface3.withValues(alpha: p.dark ? .5 : .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (v > 0) {
      final rect = Rect.fromCircle(center: c, radius: r);
      g.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..shader = SweepGradient(
            colors: [ink.withValues(alpha: .55), ink, ink],
            startAngle: 0,
            endAngle: math.pi * 2,
            tileMode: TileMode.clamp,
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );

      final end = -math.pi / 2 + 2 * math.pi * v;
      g.drawCircle(
        Offset(c.dx + math.cos(end) * r, c.dy + math.sin(end) * r),
        stroke * .62,
        Paint()
          ..color = ink
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    if (tick) {
      final t = Paint()
        ..color = p.sub.withValues(alpha: .5)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 60; i++) {
        final a = i * math.pi / 30 - math.pi / 2;
        final long = i % 5 == 0;
        final r1 = r - stroke - 5;
        final r2 = r1 - (long ? 5 : 2.6);
        g.drawLine(
          Offset(c.dx + math.cos(a) * r1, c.dy + math.sin(a) * r1),
          Offset(c.dx + math.cos(a) * r2, c.dy + math.sin(a) * r2),
          t,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v ||
      old.p.dark != p.dark ||
      old.p.seed.key != p.seed.key ||
      old.ink != ink;
}

/// Daily trail: positive bars up, negative down, zero as a faint tick.
class Trail extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color? color;
  final bool rounded;
  const Trail(
    this.values, {
    super.key,
    this.height = 34,
    this.color,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _TrailPainter(values, color ?? p.accent, p),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final List<double> v;
  final Color ink;
  final Pal p;
  _TrailPainter(this.v, this.ink, this.p);

  @override
  void paint(Canvas g, Size s) {
    if (v.isEmpty) return;
    final n = v.length;
    final slot = s.width / n;
    final bw = math.min(9.0, math.max(3.5, slot * .58));
    double peak = 0;
    double low = 0;
    for (final e in v) {
      if (e > peak) peak = e;
      if (e < low) low = e;
    }
    final maxAbs = math.max(peak, low.abs());
    if (maxAbs == 0) {
      final flat = Paint()
        ..color = p.surface3
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      g.drawLine(Offset(0, s.height - 2), Offset(s.width, s.height - 2), flat);
      return;
    }
    final scale = (s.height - 4) / maxAbs;
    for (var i = 0; i < n; i++) {
      final e = v[i];
      final cx = slot * i + slot / 2;
      final h = e == 0 ? 2.5 : math.max(3.0, e.abs() * scale);
      final paint = Paint()
        ..color = e < 0
            ? p.bad.withValues(alpha: .9)
            : (i == n - 1 ? ink : ink.withValues(alpha: i == n - 2 ? .8 : .55));
      g.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw / 2, s.height - 2.5, bw, 2.5),
          const Radius.circular(2),
        ),
        Paint()..color = p.surface3,
      );
      final rect = e < 0
          ? Rect.fromLTWH(cx - bw / 2, s.height - h, bw, h)
          : Rect.fromLTWH(cx - bw / 2, s.height - h, bw, h);
      g.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bw / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.v != v || old.ink != ink || old.p.dark != p.dark;
}

/// Counts to a new number instead of snapping, with a small pop.
class AnimatedNum extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String Function(double)? label;
  final Color? color;
  final Duration duration;

  const AnimatedNum(
    this.value, {
    super.key,
    this.style,
    this.label,
    this.color,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  State<AnimatedNum> createState() => _AnimatedNumState();
}

class _AnimatedNumState extends State<AnimatedNum>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Tween<double>? _t;

  @override
  void didUpdateWidget(covariant AnimatedNum old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _t = Tween(begin: old.value, end: widget.value);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final show = _t == null
        ? widget.value
        : _t!.evaluate(CurvedAnimation(parent: _c, curve: Tk.curve));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final bump = 1 + math.sin(_c.value * math.pi) * .045;
        return Transform.scale(
          scale: bump,
          child: Text(
            widget.label?.call(show) ?? fmtK(show),
            style: (widget.style ?? Tk.num).copyWith(
              color: widget.color ?? p.text,
            ),
          ),
        );
      },
    );
  }
}

/// Compact stat block: label, big number, optional trail.
class Stat extends StatelessWidget {
  final String label, value;
  final String? sub;
  final String? icon;
  final List<double>? trail;
  final VoidCallback? on;
  final Color? ink;

  const Stat({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.icon,
    this.trail,
    this.on,
    this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final accent = ink ?? p.accent;
    return Card(
      on: on,
      sem: label,
      pad: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconX(icon!, size: 13, color: p.sub),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: over(p).copyWith(fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Tk.num.copyWith(
                color: p.text,
                fontSize: 26,
                letterSpacing: -1,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cap(p),
            ),
          ],
          if (trail != null && trail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Trail(trail!, height: 26, color: accent),
          ],
        ],
      ),
    );
  }
}

// ============================== CHROME ==============================

class Header extends StatelessWidget {
  final String titleText;
  final String? sub;
  final bool back;
  final List<Widget> actions;
  final Widget? leading;
  final double size;
  final String? eyebrow;

  const Header({
    super.key,
    required this.titleText,
    this.sub,
    this.back = false,
    this.actions = const [],
    this.leading,
    this.size = 25,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tk.gutter, 12, Tk.s3, 12),
      child: Row(
        children: [
          if (back)
            Pressable(
              on: nav.back,
              sem: L.t('cancel'),
              radius: Tk.rPill,
              subtle: true,
              pad: const EdgeInsets.all(9),
              bg: p.surface,
              border: p.line,
              child: IconX('left', size: 17, color: p.text),
            ),
          if (back) const SizedBox(width: 10),
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: over(p).copyWith(fontSize: 9.5, color: p.accent),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: title(p, s: size),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cap(p),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsets pad;
  const Section(
    this.text, {
    super.key,
    this.trailing,
    this.pad = const EdgeInsets.fromLTRB(Tk.gutter, 0, Tk.gutter, 8),
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: pad,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: over(p).copyWith(fontSize: 10),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon, titleText, sub;
  final String? cta;
  final VoidCallback? on;

  const EmptyState({
    super.key,
    required this.icon,
    required this.titleText,
    required this.sub,
    this.cta,
    this.on,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [p.accentSoft, p.surface],
                  stops: const [.45, 1],
                ),
                border: Border.all(color: p.line),
              ),
              child: Center(
                child: IconX(icon, size: 30, color: p.accent, weight: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titleText,
              style: title(p, s: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(sub, style: body(p, s: 13), textAlign: TextAlign.center),
            if (cta != null && on != null) ...[
              const SizedBox(height: 18),
              PrimaryBtn(label: cta!, on: on!),
            ],
          ],
        ),
      ),
    );
  }
}

class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback on;
  final String? icon;
  final bool full;
  final bool danger;

  const PrimaryBtn({
    super.key,
    required this.label,
    required this.on,
    this.icon,
    this.full = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final ink = danger ? p.bad : p.accent;
    return Pressable(
      on: on,
      filled: true,
      radius: 13,
      pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      bg: danger ? p.bad : ink,
      child: Row(
        mainAxisAlignment:
            full ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconX(icon!, size: 17, color: p.accentInk),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: p.accentInk,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -.2,
            ),
          ),
        ],
      ),
    );
  }
}

class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback on;
  final String? icon;
  final bool full;
  const GhostBtn({
    super.key,
    required this.label,
    required this.on,
    this.icon,
    this.full = false,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: on,
      radius: 13,
      pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      bg: p.surface,
      border: p.line,
      child: Row(
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            full ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (icon != null) ...[
            IconX(icon!, size: 16, color: p.text2),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: p.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class Fab extends StatelessWidget {
  final String icon;
  final String? label;
  final VoidCallback on;
  const Fab({super.key, required this.icon, this.label, required this.on});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: on,
      filled: true,
      radius: label == null ? Tk.rPill : 17,
      pad: EdgeInsets.symmetric(
        horizontal: label == null ? 17 : 18,
        vertical: label == null ? 17 : 15,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconX(icon, size: 21, color: p.accentInk, weight: 2),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: TextStyle(
                color: p.accentInk,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centres content to a readable column and floats a FAB above it.
class Page extends StatelessWidget {
  final Widget? header;
  final Widget child;
  final List<Widget> chrome;
  final Widget? fab;
  final Widget? footer;
  final double max;
  final bool bottomPad;

  const Page({
    super.key,
    this.header,
    required this.child,
    this.chrome = const [],
    this.fab,
    this.footer,
    this.max = Tk.maxSingle,
    this.bottomPad = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (header != null) header!,
        ...chrome,
        Expanded(
          child: Stack(
            children: [
              child,
              if (fab != null)
                Positioned(
                  right: Tk.gutter,
                  bottom: bottomPad ? Tk.s5 : Tk.s3,
                  child: fab!,
                ),
            ],
          ),
        ),
        if (footer != null) footer!,
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: body,
      ),
    );
  }
}

// ---------------- sheets & dialogs ----------------

Future<T?> sheet<T>(
  BuildContext context,
  Widget child, {
  String? title,
  double max = 520,
}) {
  final pal = ThemeScope.of(context).pal;
  return Navigator.of(context)
      .push<T>(_SheetRoute<T>(pal: pal, child: child, title: title, max: max));
}

class _SheetRoute<T> extends PopupRoute<T> {
  final Pal pal;
  final Widget child;
  final String? title;
  final double max;
  final _Drag = ValueNotifier<double>(0);

  _SheetRoute({
    required this.pal,
    required this.child,
    this.title,
    this.max = 520,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismissing';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      DefaultTextStyle(
        style: body(pal),
        child: ThemeScope(
          pal: pal,
          child: _SheetBody(
            animation: animation,
            drag: _Drag,
            close: () => Navigator.of(context).pop(),
            title: title,
            max: max,
            child: child,
          ),
        ),
      );
}

class _SheetBody extends StatelessWidget {
  final Animation<double> animation;
  final ValueNotifier<double> drag;
  final VoidCallback close;
  final Widget child;
  final String? title;
  final double max;

  const _SheetBody({
    required this.animation,
    required this.drag,
    required this.close,
    required this.child,
    this.title,
    this.max = 520,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final height = MediaQuery.sizeOf(context).height;
    final cap = math.min(max.isFinite ? max : height, height * .9);

    return AnimatedBuilder(
      animation: Listenable.merge([animation, drag]),
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(animation.value);
        final d = drag.value;
        final shift = (1 - t) * 320 + d;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: close,
                child: ColoredBox(
                  color: const Color(0xFF05070A).withValues(alpha: .55 * t),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: math.max(
                    0,
                    MediaQuery.viewInsetsOf(context).bottom == 0
                        ? 0
                        : MediaQuery.viewInsetsOf(context).bottom * 0,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: cap, maxWidth: 640),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 18 * t,
                        sigmaY: 18 * t,
                        tileMode: TileMode.decal,
                      ),
                      child: GestureDetector(
                        onVerticalDragUpdate: (d2) =>
                            drag.value = math.max(0, drag.value + d2.delta.dy),
                        onVerticalDragEnd: (d2) {
                          if (drag.value > 90 ||
                              (d2.velocity.pixelsPerSecond.dy > 550 &&
                                  drag.value > 24)) {
                            close();
                          } else {
                            drag.value = 0;
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          transform: Matrix4.translationValues(0, shift, 0),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              p.surface.withValues(alpha: .94),
                              p.bg,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(26),
                            ),
                            border: Border(top: BorderSide(color: p.line)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF05070A)
                                    .withValues(alpha: p.dark ? .5 : .16),
                                blurRadius: 40,
                                offset: const Offset(0, -12),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 9, 20, 26),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: p.lineStrong,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                                if (title != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    title!,
                                    style: title == null
                                        ? null
                                        : Tk.h2.copyWith(color: p.text),
                                  ),
                                ] else
                                  const SizedBox(height: 14),
                                child,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MenuItem {
  final String key, label, icon;
  final bool danger;
  final bool checked;
  final String? sub;
  const MenuItem(
    this.key,
    this.label, {
    this.icon = 'right',
    this.danger = false,
    this.checked = false,
    this.sub,
  });
}

/// Standard bottom menu used for every options sheet in the app.
Future<String?> menuSheet(
  BuildContext context,
  String title,
  List<MenuItem> items,
) async {
  return sheet<String>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Tk.h2.copyWith(color: ThemeScope.of(context).pal.text),
        ),
        const SizedBox(height: 12),
        for (final it in items) _MenuRow(it),
      ],
    ),
    title: null,
  );
}

class _MenuRow extends StatelessWidget {
  final MenuItem item;
  const _MenuRow(this.item);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        on: () => Navigator.pop(context, item.key),
        subtle: item.danger,
        sem: item.label,
        radius: 13,
        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        bg: item.danger
            ? p.bad.withValues(alpha: .10)
            : (item.checked ? p.accentSoft : p.surface2),
        border: item.checked ? p.accent.withValues(alpha: .5) : p.line,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    (item.danger ? p.bad : (item.checked ? p.accent : p.text2))
                        .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: IconX(
                  item.checked ? 'check' : item.icon,
                  size: 15,
                  color:
                      item.danger ? p.bad : (item.checked ? p.accent : p.text2),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: item.danger ? p.bad : p.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.sub!, style: cap(p)),
                    ),
                ],
              ),
            ),
            if (!item.checked) IconX('right', size: 15, color: p.sub),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String titleText,
  String message, {
  String confirmLabel = '',
  bool danger = true,
}) async {
  final pal = ThemeScope.of(context).pal;
  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x88000000),
      transitionDuration: Tk.fast,
      reverseTransitionDuration: Tk.fast,
      pageBuilder: (_, __, ___) => ThemeScope(
        pal: pal,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _Confirm(
              pal: pal,
              titleText: titleText,
              message: message,
              confirmLabel: confirmLabel.isEmpty
                  ? (danger ? L.t('delete') : 'OK')
                  : confirmLabel,
              danger: danger,
            ),
          ),
        ),
      ),
      transitionsBuilder: (_, a, __, who) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(
            begin: .94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: Tk.curve)),
          child: who,
        ),
      ),
    ),
  );
  return result ?? false;
}

class _Confirm extends StatelessWidget {
  final Pal pal;
  final String titleText;
  final String message;
  final String confirmLabel;
  final bool danger;

  const _Confirm({
    required this.pal,
    required this.titleText,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
        boxShadow: Shadow.of(p, y: 18, blur: 44, a: .22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconX(
                danger ? 'alert' : 'info',
                size: 17,
                color: danger ? p.bad : p.accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(titleText, style: Tk.h3.copyWith(color: p.text)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(message, style: body(p, s: 13.5)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GhostBtn(
                  label: L.t('cancel'),
                  on: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  on: () => Navigator.pop(context, true),
                  filled: true,
                  bg: danger ? p.bad : p.accent,
                  radius: 13,
                  pad: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    confirmLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.accentInk,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================== FOCUS ENGINE ==============================

/// Lives above the Time tab: a session keeps running while you browse notes or
/// counters, and Home reflects it.
class FocusEngine extends ChangeNotifier {
  static const presets = [5, 10, 15, 25, 45, 60];

  int durationSec;
  int _remainMs;
  int? _endAt;
  bool running = false;
  Timer? _ticker;
  bool _wake = false;

  /// Increments each completed session (for a subtle celebration animation).
  int completions = 0;

  FocusEngine()
      : durationSec = 25 * 60,
        _remainMs = 25 * 60 * 1000;

  int get remainMs => running
      ? math.max(0, _endAt! - nowT().millisecondsSinceEpoch)
      : _remainMs;

  int get secondsLeft => (remainMs / 1000).ceil();

  /// 0 -> full, counts up as the session progresses.
  double get ratio => durationSec == 0
      ? 0
      : (1 - remainMs / (durationSec * 1000)).clamp(0.0, 1.0).toDouble();

  String get endClock {
    if (!running) return '';
    final at = nowT().add(Duration(milliseconds: remainMs));
    return '${two(at.hour)}:${two(at.minute)}';
  }

  bool isPreset(int minutes) => durationSec == minutes * 60 && !running;

  void setMinutes(int minutes) {
    setSeconds(minutes * 60);
  }

  void setSeconds(int seconds) {
    final next = seconds.clamp(60, 24 * 3600);
    if (next == durationSec && !running) return;
    durationSec = next;
    if (!running) _remainMs = durationSec * 1000;
    store.prefs.focusMinutes = (durationSec / 60).round();
    store.touch();
    notifyListeners();
  }

  void nudge(int seconds) {
    setSeconds(durationSec + seconds);
  }

  Future<void> toggle() async {
    store.vib();
    store.sfx(!running);
    if (running) {
      _pause();
      return;
    }
    if (remainMs <= 0) _remainMs = durationSec * 1000;
    _endAt = nowT().millisecondsSinceEpoch + remainMs;
    running = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    await _wakeLock(true);
    notifyListeners();
  }

  void _pause() {
    _remainMs = remainMs;
    running = false;
    _endAt = null;
    _ticker?.cancel();
    _wakeLock(false);
    notifyListeners();
  }

  void reset() {
    running = false;
    _endAt = null;
    _remainMs = durationSec * 1000;
    _ticker?.cancel();
    _wakeLock(false);
    store.vib();
    notifyListeners();
  }

  void _tick() {
    if (!running) return;
    if (remainMs > 0) {
      notifyListeners();
      return;
    }
    _complete();
  }

  void _complete() {
    final minutes = (durationSec / 60).round();
    running = false;
    _endAt = null;
    _ticker?.cancel();
    _remainMs = durationSec * 1000;
    completions++;
    _wakeLock(false);

    if (store.prefs.focusSoundUri.isNotEmpty)
      Store.playChime(store.prefs.focusSoundUri);
    store.logFocus(minutes);
    if (store.prefs.focusAutoNote) {
      store.addNote(
        dayKey(nowT()),
        'Focus session completed.\n\n$minutes min of deep work.',
        3,
        folder: store.prefs.notesFolder.isEmpty
            ? 'generale'
            : store.prefs.notesFolder,
      );
    }
    store.vib(true);
    store.sfx(true);
    toasts.show('${L.t('focusDone')} · $minutes ${L.t('minutesShort')}');
    notifyListeners();
  }

  Future<void> _wakeLock(bool on) async {
    if (_wake == on) return;
    _wake = on;
    try {
      await Store.channel.invokeMethod('setKeepScreenOn', {'enabled': on});
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final focus = FocusEngine();

Future<void> setScreenOn(bool e) async {
  try {
    await Store.channel.invokeMethod('setKeepScreenOn', {'enabled': e});
  } catch (_) {}
}

Future<void> setFullscreen(bool e) async {
  try {
    await Store.channel.invokeMethod('setFullscreen', {'enabled': e});
  } catch (_) {}
}

class TimeWheel extends StatefulWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String label;

  const TimeWheel(
      {super.key,
      required this.value,
      required this.max,
      required this.onChanged,
      required this.label});

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.value);
  }

  @override
  void didUpdateWidget(covariant TimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.hasClients) {
      _controller.animateToItem(
        widget.value,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 130,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            useMagnifier: true,
            magnification: 1.2,
            overAndUnderCenterOpacity: 0.4,
            perspective: 0.005,
            onSelectedItemChanged: (index) => widget.onChanged(index),
            controller: _controller,
            physics: const FixedExtentScrollPhysics(),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max + 1,
              builder: (context, index) {
                final selected = index == widget.value;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 24 : 18,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? p.accent : p.text2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: cap(p)),
      ],
    );
  }
}

// ============================== SHELL ==============================

const navItems = [
  ['home', 'home'],
  ['tag', 'counters'],
  ['clock', 'time'],
  ['note', 'notes'],
  ['settings', 'settings'],
];

int screenOf(String label) => switch (label) {
      'home' => 0,
      'counters' => 1,
      'time' => 2,
      'notes' => 3,
      'settings' => 4,
      _ => 5,
    };

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: nav,
      builder: (_, __) {
        final width = MediaQuery.sizeOf(c).width;
        final wide = width >= Tk.railMin;

        final body = _PageSwap(
          swapKey: ValueKey('${nav.screen}-${nav.timeTab}'),
          dir: nav.dir,
          child: child,
        );

        if (wide) {
          return Row(
            children: [
              _Rail(compact: width < Tk.railWide),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Tk.maxColumns),
                    child: SizedBox(
                      width: double.infinity,
                      child: _Chrome(body),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: _Chrome(body)),
            _BottomSlot(show: nav.isTab),
          ],
        );
      },
    );
  }
}

/// Adds a hairline scrollbar on pointer platforms and keeps overscroll tidy.
class _Chrome extends StatelessWidget {
  final Widget child;
  const _Chrome(this.child);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _AppScrollBehavior(),
      child: ScrollOverlay(child: child),
    );
  }
}

class _AppScrollBehavior extends ScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}

/// Minimal overlay scrollbar: listens for scroll updates from any descendant
/// and paints a 3px hairline that fades out when idle.
class ScrollOverlay extends StatefulWidget {
  final Widget child;
  const ScrollOverlay({super.key, required this.child});

  @override
  State<ScrollOverlay> createState() => _ScrollOverlayState();
}

class _ScrollOverlayState extends State<ScrollOverlay> {
  double _top = 0, _height = 1, _viewport = 1, _extent = 1;
  int? _stamp;
  Timer? _fade;

  bool _onMetrics(ScrollUpdateNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final m = n.metrics;
      final extent = m.maxScrollExtent - m.minScrollExtent;
      if (extent > 24) {
        setState(() {
          _viewport = m.viewportDimension;
          _extent = extent;
          _height = (_viewport * _viewport / (extent + _viewport))
              .clamp(28.0, m.viewportDimension.toDouble())
              .toDouble();
          _top = m.pixels.clamp(0.0, extent).toDouble() *
              (_viewport - _height) /
              extent;
        });
      }
      _stamp = nowT().microsecondsSinceEpoch;
      _fade?.cancel();
      _fade = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _stamp = null);
      });
    }
    return false;
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final visible = _stamp != null && (_extent > 24);
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: _onMetrics,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: 3,
            top: 6,
            bottom: 6,
            width: 4,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: Tk.base,
                opacity: visible ? 1 : 0,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Tk.fast,
                      curve: Tk.curve,
                      top: _top,
                      height: _height,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.text.withValues(alpha: .24),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Directional slide + fade between screens.

class _PageSwap extends StatelessWidget {
  final Widget child;
  final int dir;

  /// Keys the *content*, not the switcher: the switcher has to survive the
  /// navigation for its entrance animation to actually run.
  final Key swapKey;
  const _PageSwap({
    required this.child,
    required this.dir,
    required this.swapKey,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Tk.curve,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (who, a) {
        final curved = CurvedAnimation(parent: a, curve: Tk.curve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(.055 * dir, 0),
              end: Offset.zero,
            ).animate(curved),
            child: who,
          ),
        );
      },
      child: KeyedSubtree(key: swapKey, child: child),
    );
  }
}

class _Rail extends StatelessWidget {
  final bool compact;
  const _Rail({this.compact = false});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final width = compact ? 78.0 : 208.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 18),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.accent, p.accentSoft]),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: .32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(child: IconX('bolt', size: 17, color: white)),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OpenFocusly',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                          ),
                        ),
                        Text(
                          'v2.1',
                          style: over(p).copyWith(
                            fontSize: 9,
                            color: p.sub.withValues(alpha: .8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PrimaryBtn(
                label: L.t('new'),
                icon: 'plus',
                full: true,
                on: () {
                  store.vib();
                  nav.openCounterEditor();
                },
              ),
            ),
          for (final item in navItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _RailItem(item[0], item[1], compact: compact),
            ),
          const Spacer(),
          Container(height: 1, color: p.line),
          const SizedBox(height: 8),
          _RailItem('info', 'info', compact: compact),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String icon, label;
  final bool compact;
  const _RailItem(this.icon, this.label, {this.compact = false});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final target = screenOf(label);
    final active = nav.screen == target ||
        (target == 4 && nav.screen == 5) ||
        (target == 1 && nav.screen == 8);

    return Pressable(
      on: () {
        store.vib();
        nav.jump(target);
      },
      sem: L.t(label),
      subtle: true,
      radius: 12,
      pad: EdgeInsets.symmetric(horizontal: compact ? 0 : 10, vertical: 10),
      align: compact ? Alignment.center : Alignment.centerLeft,
      bg: active ? p.accentSoft : clear,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active && !compact)
            Container(
              width: 3,
              height: 17,
              margin: const EdgeInsets.only(right: 9),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          IconX(
            icon,
            size: 18,
            color: active ? p.accent : p.text2,
            weight: 1.8,
          ),
          if (!compact) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                L.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? p.accent : p.text2,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The tab bar retracts when a screen is pushed, so full-height surfaces
/// (counter detail, note editor) own the whole viewport.
class _BottomSlot extends StatelessWidget {
  final bool show;
  const _BottomSlot({required this.show});

  @override
  Widget build(BuildContext c) {
    return ClipRect(
      child: AnimatedSize(
        duration: Tk.base,
        curve: Tk.curve,
        alignment: Alignment.bottomCenter,
        child: show ? _BottomBar(screen: nav.screen) : const SizedBox.shrink(),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  /// Passed in so the bar is rebuilt on navigation (a `const` instance would
  /// be skipped by the framework and freeze the highlight).
  final int screen;
  const _BottomBar({required this.screen});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final current = screen <= 4 ? screen : (screen == 5 ? 4 : -1);

    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.dark ? .96 : .92),
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (_, q) {
              final cell = q.maxWidth / navItems.length;
              return Stack(
                children: [
                  if (current >= 0)
                    AnimatedPositioned(
                      duration: Tk.base,
                      curve: Tk.curve,
                      left: cell * current + (cell - 52) / 2,
                      top: 6,
                      child: AnimatedContainer(
                        duration: Tk.base,
                        height: 32,
                        width: 52,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(Tk.rPill),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < navItems.length; i++)
                        Expanded(
                          child: _BottomItem(
                            navItems[i][0],
                            navItems[i][1],
                            active: i == current,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final String icon, label;
  final bool active;
  const _BottomItem(this.icon, this.label, {required this.active});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: () {
        store.vib();
        nav.jump(screenOf(label));
      },
      sem: L.t(label),
      subtle: true,
      radius: 14,
      pad: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconX(
            icon,
            size: 19,
            color: active ? p.accent : p.sub,
            weight: active ? 2 : 1.7,
          ),
          const SizedBox(height: 3),
          Text(
            L.t(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? p.accent : p.sub,
              fontSize: 9.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== HOME ==============================

String get greeting {
  final h = nowT().hour;
  if (h < 5) return L.t('evening');
  if (h < 12) return L.t('morning');
  if (h < 18) return L.t('afternoon');
  return L.t('evening');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final counters = store.counters;
    final notes = store.allNotes();
    final fresh = counters.isEmpty && notes.isEmpty;

    if (fresh) {
      return Page(
        max: Tk.maxReading,
        header: Header(titleText: L.t('home'), sub: fullDate(nowT())),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tk.gutter, 8, Tk.gutter, 110),
          children: [
            const SizedBox(height: 26),
            EmptyState(
              icon: 'bolt',
              titleText: L.t('appTag'),
              sub: L.t('aboutSub'),
              cta: L.t('new'),
              on: () {
                store.vib();
                nav.openCounterEditor();
              },
            ),
            const SizedBox(height: 26),
            _PrivacyCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    icon: 'note',
                    label: L.t('newNote'),
                    on: () => nav.jump(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhostBtn(
                    icon: 'clock',
                    label: L.t('focus'),
                    on: () => nav.jump(2, tab: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final pinned = counters.where((e) => e.pinned).toList();
    final goals = counters.where((e) => e.hasGoal && e.goalRatio < 1).toList()
      ..sort((a, b) => b.goalRatio.compareTo(a.goalRatio));
    final movers = counters.where((e) => e.today != 0).toList()
      ..sort((a, b) => b.today.abs().compareTo(a.today.abs()));
    final trail = store.weekTrail();
    final peak = trail.isEmpty ? 0.0 : trail.reduce((a, b) => a > b ? a : b);

    final wide = MediaQuery.sizeOf(c).width >= Tk.railMin;

    final todayBlock = <Widget>[
      // ---- today ----
      Card(
        pad: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.t('today').toUpperCase(),
                        style: over(p).copyWith(fontSize: 9.5),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmt(store.todayDelta.abs()),
                            style: Tk.num.copyWith(
                              color: p.text,
                              fontSize: 34,
                              letterSpacing: -1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '${counters.where((e) => e.today != 0).length} ${L.t('counters').toLowerCase()}',
                              style: cap(p),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _TodayRing(
                  ratio: goals.isEmpty
                      ? 0
                      : goals
                              .map((e) => e.goalRatio)
                              .reduce((a, b) => a + b) /
                          goals.length,
                  count: goals.length,
                ),
              ],
            ),
            if (peak > 0) ...[
              const SizedBox(height: 14),
              Trail(trail, height: 40),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    Text(
                      weekdayNames()[
                          nowT().subtract(Duration(days: 6 - i)).weekday -
                              1][0],
                      style: over(p).copyWith(
                        fontSize: 8.5,
                        color: i == 6 ? p.accent : p.sub,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: Tk.gapSection),
    ];

    final focusBlock = <Widget>[
      // ---- focus ----
      Section(L.t('focus')),
      const _FocusCard(),
      const SizedBox(height: Tk.gapSection),
    ];

    final pinnedBlock = <Widget>[
      if (pinned.isNotEmpty) ...[
        Section(
          L.t('pinnedCounters'),
          trailing: Pressable(
            subtle: true,
            radius: Tk.rPill,
            pad: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            on: () => nav.jump(1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  L.t('viewAll'),
                  style: cap(p, c: p.accent).copyWith(fontSize: 11.5),
                ),
                const SizedBox(width: 3),
                IconX('right', size: 12, color: p.accent),
              ],
            ),
          ),
        ),
        for (final ct in pinned)
          Padding(
            padding: const EdgeInsets.only(bottom: Tk.gapList),
            child: QuickCounterRow(counter: ct),
          ),
        const SizedBox(height: Tk.gapSection - Tk.gapList),
      ],
    ];

    final goalsBlock = <Widget>[
      if (goals.isNotEmpty) ...[
        Section(L.t('goals')),
        Card(
          pad: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Column(
            children: [
              for (var i = 0; i < math.min(goals.length, 4); i++) ...[
                if (i > 0) const _Hairline(),
                _GoalRow(counter: goals[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: Tk.gapSection),
      ],
    ];

    final moversBlock = <Widget>[
      if (movers.isNotEmpty) ...[
        Section(L.t('topCounters')),
        Card(
          pad: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              for (var i = 0; i < math.min(movers.length, 5); i++) ...[
                if (i > 0) const _Hairline(),
                _MoverRow(counter: movers[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: Tk.gapSection),
      ],
    ];

    final notesBlock = <Widget>[
      if (notes.isNotEmpty) ...[
        Section(
          L.t('notes'),
          trailing: Text('${notes.length}', style: cap(p, c: p.sub)),
        ),
        Card(
          pad: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(
            children: [
              for (final n in notes.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: NoteRow(
                    note: n,
                    on: () => showNoteEditor(c, n),
                    onLong: () => noteMenu(c, n),
                  ),
                ),
              if (notes.length > 3)
                Pressable(
                  subtle: true,
                  radius: 12,
                  pad: const EdgeInsets.symmetric(vertical: 10),
                  on: () => nav.jump(3),
                  child: Center(
                    child: Text(
                      '${L.t('viewAll')} · ${notes.length}',
                      style: cap(p, c: p.accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];

    final tailBlock = <Widget>[
      const SizedBox(height: Tk.s4),
      const _PrivacyCard(compact: true),
    ];

    return AnimatedBuilder(
      animation: focus,
      builder: (_, __) => Page(
        max: wide ? Tk.maxColumns : Tk.maxReading,
        header: Header(
          eyebrow: fullDate(nowT()),
          titleText: greeting,
          size: 24,
          actions: [
            IconBtn(
              icon: 'settings',
              sem: L.t('settings'),
              on: () => nav.jump(4),
            ),
          ],
        ),
        child: wide
            ? ListView(
                padding:
                    const EdgeInsets.fromLTRB(Tk.gutter, 6, Tk.gutter, 112),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...todayBlock,
                            ...focusBlock,
                            ...notesBlock,
                          ],
                        ),
                      ),
                      const SizedBox(width: Tk.gapList),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...pinnedBlock,
                            ...goalsBlock,
                            ...moversBlock,
                            ...tailBlock,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : ListView(
                padding:
                    const EdgeInsets.fromLTRB(Tk.gutter, 6, Tk.gutter, 112),
                children: [
                  ...todayBlock,
                  ...focusBlock,
                  ...pinnedBlock,
                  ...goalsBlock,
                  ...moversBlock,
                  ...notesBlock,
                  ...tailBlock,
                ],
              ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(height: 1, color: p.line),
    );
  }
}

class _TodayRing extends StatelessWidget {
  final double ratio;
  final int count;
  const _TodayRing({required this.ratio, required this.count});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Ring(value: ratio, size: 62, stroke: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(
                  color: p.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count > 0)
                Text(
                  '$count ${L.t('goals').toLowerCase()}',
                  style: over(p).copyWith(fontSize: 7.5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return AnimatedBuilder(
      animation: focus,
      builder: (_, __) {
        final live = focus.running;
        return Card(
          pad: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Ring(
                    value: live ? focus.ratio : 0,
                    size: 66,
                    stroke: 6,
                    color: live ? p.accent : p.sub,
                  ),
                  IconX(
                    live ? 'clock' : 'play',
                    size: 20,
                    color: live ? p.accent : p.text2,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live
                          ? fmtClock(focus.secondsLeft)
                          : '${(focus.durationSec / 60).round()} ${L.t('minutesShort')}',
                      style: Tk.num.copyWith(
                        color: live ? p.text : p.text2,
                        fontSize: 27,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      live
                          ? '${L.t('endsAt')} ${focus.endClock} · ${store.focusToday} ${L.t('minutesShort')} ${L.t('today')}'
                          : L.t('focusSubShort'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cap(p),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                on: focus.toggle,
                filled: true,
                radius: Tk.rPill,
                pad: EdgeInsets.symmetric(
                  horizontal: live ? 16 : 14,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconX(
                      live ? 'pause' : 'play',
                      size: 15,
                      color: p.accentInk,
                      weight: 2,
                    ),
                    if (!live) ...[
                      const SizedBox(width: 7),
                      Text(
                        L.t('start'),
                        style: TextStyle(
                          color: p.accentInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact counter row with inline +/- — used on Home.
class QuickCounterRow extends StatelessWidget {
  final Counter counter;
  const QuickCounterRow({super.key, required this.counter});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Card(
      pad: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      radius: Tk.rCard,
      on: () => nav.openCounterDetail(counter),
      sem: counter.name,
      child: Row(
        children: [
          IconTile(counter.icon, size: 34),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      fmtK(counter.value),
                      style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
                    ),
                    if (counter.moneyEnabled &&
                        (counter.usesManualMoney || counter.mult != 0)) ...[
                      const SizedBox(width: 7),
                      Text(
                        '· ${counter.symbol} ${fmtK(counter.money)}',
                        style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
                      ),
                    ],
                    if (counter.hasGoal) ...[
                      const SizedBox(width: 7),
                      Text(
                        '${counter.goalPct}%',
                        style: cap(p, c: p.accent).copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (counter.today != 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${counter.today > 0 ? '+' : ''}${fmtK(counter.today)}',
                style: TextStyle(
                  color: counter.today > 0 ? p.good : p.bad,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          _MiniBtn(
            icon: 'minus',
            on: () {
              store.bump(counter, -counter.step);
              store.sfx(false);
            },
          ),
          const SizedBox(width: 2),
          _MiniBtn(
            icon: 'plus',
            filled: true,
            on: () {
              store.bump(counter, counter.step);
              store.sfx(true);
            },
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String icon;
  final VoidCallback on;
  final bool filled;
  const _MiniBtn({required this.icon, required this.on, this.filled = false});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: on,
      sem: icon,
      subtle: !filled,
      filled: filled,
      radius: 10,
      pad: const EdgeInsets.all(9),
      bg: filled ? p.accent : p.surface2,
      border: filled ? null : p.line,
      child: IconX(
        icon,
        size: 15,
        color: filled ? p.accentInk : p.text2,
        weight: 2,
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final Counter counter;
  const _GoalRow({required this.counter});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: () => nav.openCounterDetail(counter),
      subtle: true,
      radius: 12,
      pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  counter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${fmtK(counter.value)} / ${fmtK(counter.goalV ?? counter.goalM ?? 0)}',
                style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
              ),
              const SizedBox(width: 8),
              Text(
                '${counter.goalPct}%',
                style: TextStyle(
                  color: p.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Progress(value: counter.goalRatio, height: 5),
        ],
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  final Counter counter;
  const _MoverRow({required this.counter});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final up = counter.today > 0;
    return Pressable(
      on: () => nav.openCounterDetail(counter),
      subtle: true,
      radius: 12,
      pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        children: [
          IconX(
            up ? 'up' : 'down',
            size: 15,
            color: up ? p.good : p.bad,
            weight: 2,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              counter.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${up ? '+' : ''}${fmtK(counter.today)}',
            style: TextStyle(
              color: up ? p.good : p.bad,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Trail(counter.trail(7), height: 18, color: p.accent),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final bool compact;
  const _PrivacyCard({this.compact = false});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 13,
        vertical: compact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: p.accentSoft.withValues(alpha: p.dark ? .5 : .7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          IconX(compact ? 'lock' : 'shield', size: 16, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compact ? L.t('privacySub') : L.t('privacy'),
              style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== COUNTERS ==============================

class CountersScreen extends StatefulWidget {
  const CountersScreen({super.key});

  @override
  State<CountersScreen> createState() => _CountersState();
}

class _CountersState extends State<CountersScreen> {
  final TextEditingController q = TextEditingController();
  String folder = '';
  String sort = 'manual';
  bool searchOpen = false;

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

    switch (sort) {
      case 'name':
        out.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'value':
        out.sort((a, b) => b.value.compareTo(a.value));
        break;
      case 'recent':
        out.sort((a, b) => b.today.abs().compareTo(a.today.abs()));
        break;
      default:
        out.sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return a.order.compareTo(b.order);
        });
    }
    return out;
  }

  Future<void> pickSort() async {
    final picked = await menuSheet(context, L.t('sort'), [
      MenuItem(
        'manual',
        L.t('sortManual'),
        icon: 'drag',
        checked: sort == 'manual',
      ),
      MenuItem('name', L.t('sortName'), icon: 'list', checked: sort == 'name'),
      MenuItem(
        'value',
        L.t('sortValue'),
        icon: 'chart',
        checked: sort == 'value',
      ),
      MenuItem(
        'recent',
        L.t('sortRecent'),
        icon: 'history',
        checked: sort == 'recent',
      ),
    ]);
    if (picked != null) setState(() => sort = picked);
  }

  Future<void> manageFolders() async {
    final groups = store.groups;
    final items = <MenuItem>[
      MenuItem('', L.t('all'), icon: 'layers', checked: folder.isEmpty),
      for (final g in groups)
        MenuItem(
          g,
          g,
          icon: 'folder',
          checked: folder == g,
          sub:
              '${store.counters.where((c) => c.group == g).length} ${L.t('counters').toLowerCase()}',
        ),
      const MenuItem('__new', '—', icon: 'plus'),
    ];
    items.last = MenuItem('__new', L.t('newFolder'), icon: 'plus');

    final picked = await menuSheet(context, L.t('folders'), items);
    if (picked == null) return;

    if (picked == '__new') {
      final name = await promptText(
        context,
        L.t('newFolder'),
        hint: L.t('group'),
      );
      if (name != null && name.trim().isNotEmpty) {
        setState(() => folder = name.trim());
      }
      return;
    }
    setState(() => folder = picked);
  }

  @override
  Widget build(BuildContext c) {
    final items = list;
    final query = q.text.trim();

    final chips = <Widget>[
      Chip(
        label: L.t('all'),
        icon: 'layers',
        active: folder.isEmpty,
        on: () => setState(() => folder = ''),
      ),
      for (final g in store.groups)
        Chip(
          label: g,
          icon: 'folder',
          active: folder == g,
          on: () => setState(() => folder = folder == g ? '' : g),
        ),
      Chip(
        label: L.t('folders'),
        icon: 'plus',
        active: false,
        on: manageFolders,
      ),
    ];

    return Page(
      max: store.counters.isNotEmpty &&
              MediaQuery.sizeOf(c).width >= Tk.railMin
          ? Tk.maxColumns
          : Tk.maxSingle,
      header: Header(
        titleText: L.t('counters'),
        size: 24,
        sub:
            '${store.counters.length} · ${fmtK(store.total())}${store.counters.any((e) => e.moneyEnabled) ? '  ·  ${fmtK(store.money())} €' : ''}',
        actions: [
          IconBtn(
            icon: searchOpen ? 'x' : 'search',
            sem: L.t('search'),
            on: () {
              setState(() => searchOpen = !searchOpen);
              if (!searchOpen) q.clear();
            },
          ),
          IconBtn(icon: 'sort', sem: L.t('sort'), on: pickSort),
        ],
      ),
      chrome: [
        AnimatedSize(
          duration: Tk.base,
          curve: Tk.curve,
          alignment: Alignment.topCenter,
          child: searchOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tk.gutter,
                    0,
                    Tk.gutter,
                    10,
                  ),
                  child: Field(
                    ctrl: q,
                    icon: 'search',
                    hint: L.t('search'),
                    clear: true,
                    sem: L.t('search'),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChipRow(chips),
        ),
      ],
      fab: store.counters.isEmpty
          ? null
          : Fab(
              icon: 'plus',
              label: items.isEmpty ? L.t('new') : null,
              on: () {
                store.vib();
                nav.openCounterEditor();
              },
            ),
      child: items.isEmpty
          ? EmptyState(
              icon: 'tag',
              titleText: query.isNotEmpty || folder.isNotEmpty
                  ? L.t('noResults')
                  : L.t('noCounters'),
              sub: query.isNotEmpty || folder.isNotEmpty
                  ? L.t('noResultsSub')
                  : L.t('noCountersSub'),
              cta: L.t('new'),
              on: () => nav.openCounterEditor(),
            )
          : MediaQuery.sizeOf(c).width >= Tk.railMin
              ? _CounterGrid(items: items)
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(Tk.gutter, 2, Tk.gutter, 112),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Tk.gapList),
                  itemBuilder: (_, i) => CounterCard(counter: items[i]),
                ),
    );
  }
}

/// Two balanced columns once the content pane is wide enough: cards keep
/// a readable aspect instead of stretching into full-width banners. Falls
/// back to the plain list when the rail leaves less than a column pair.
/// Cards in the same row align heights; an odd last card sits alone at
/// half width by design.
class _CounterGrid extends StatelessWidget {
  final List<Counter> items;
  const _CounterGrid({required this.items});

  @override
  Widget build(BuildContext c) {
    return LayoutBuilder(
      builder: (c, box) {
        if (box.maxWidth < 680) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Tk.gutter, 2, Tk.gutter, 112),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Tk.gapList),
            itemBuilder: (_, i) => CounterCard(counter: items[i]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(Tk.gutter, 2, Tk.gutter, 112),
          itemCount: (items.length + 1) ~/ 2,
          itemBuilder: (_, i) {
            final a = items[i * 2];
            final hasB = i * 2 + 1 < items.length;
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Tk.gapList),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: CounterCard(counter: a)),
                    const SizedBox(width: Tk.gapList),
                    Expanded(
                      child: hasB
                          ? CounterCard(counter: items[i * 2 + 1])
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CounterCard extends StatelessWidget {
  final Counter counter;
  final bool enabled;
  const CounterCard({super.key, required this.counter, this.enabled = true});

  Future<void> menu(BuildContext c) async {
    final picked = await menuSheet(c, counter.name, [
      MenuItem(
        'pin',
        counter.pinned ? L.t('unpin') : L.t('pin'),
        icon: 'pin',
        checked: counter.pinned,
      ),
      MenuItem('edit', L.t('edit'), icon: 'edit'),
      MenuItem('dup', L.t('duplicate'), icon: 'copy'),
      MenuItem('reset', L.t('reset'), icon: 'refresh'),
      MenuItem('del', L.t('delete'), icon: 'trash', danger: true),
    ]);
    if (picked == null) return;
    switch (picked) {
      case 'pin':
        counter.pinned = !counter.pinned;
        store.touch();
        break;
      case 'edit':
        nav.openCounterEditor(counter);
        break;
      case 'dup':
        final copy = Counter(
          id: uid(),
          name: '${counter.name} 2',
          group: counter.group,
          symbol: counter.symbol,
          value: 0,
          step: counter.step,
          mult: counter.mult,
          moneyEnabled: counter.moneyEnabled,
          moneyStep: counter.moneyStep,
          goalV: counter.goalV,
          goalM: counter.goalM,
          goalAction: counter.goalAction,
          icon: counter.icon,
          order: store.counters.length,
        );
        store.counters.add(copy);
        store.touch();
        toasts.show(L.t('duplicate'), icon: 'copy');
        break;
      case 'reset':
        store.bump(counter, -counter.value);
        break;
      case 'del':
        deleteWithUndo(counter);
        break;
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;

    if (!enabled) {
      return IgnorePointer(ignoring: true, child: _card(c, p, controls: false));
    }

    return Dismissible(
      key: ValueKey('c-${counter.id}-edit'),
      direction: DismissDirection.horizontal,
      background: const _SwipeBg(icon: 'pin', labelKey: 'pin'),
      secondaryBackground: const _SwipeBg(
        icon: 'trash',
        labelKey: 'delete',
        end: true,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          counter.pinned = !counter.pinned;
          store.touch();
          toasts.show(counter.pinned ? L.t('pin') : L.t('unpin'), icon: 'pin');
          return false;
        }
        deleteWithUndo(counter);
        return false;
      },
      child: _card(c, p),
    );
  }

  Widget _card(BuildContext c, Pal p, {bool controls = true}) {
    final money =
        counter.moneyEnabled && (counter.usesManualMoney || counter.mult != 0);
    return Card(
      pad: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      on: enabled ? () => nav.openCounterDetail(counter) : null,
      onLong: enabled ? () => menu(c) : null,
      sem: counter.name,
      child: Column(
        children: [
          Row(
            children: [
              IconTile(counter.icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                        if (counter.pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: IconX('pin', size: 13, color: p.accent),
                          ),
                        if (counter.stopped)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: IconX('pause', size: 13, color: p.warn),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedNum(
                          counter.value,
                          style: Tk.num.copyWith(
                            color: p.text,
                            fontSize: 21,
                            letterSpacing: -.8,
                          ),
                        ),
                        if (money) ...[
                          const SizedBox(width: 9),
                          Text(
                            '· ${counter.symbol} ${fmtK(counter.money)}',
                            style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
                          ),
                        ],
                        const Spacer(),
                        if (counter.today != 0)
                          Text(
                            '${counter.today > 0 ? '+' : ''}${fmtK(counter.today)} ${L.t('today')}',
                            style: TextStyle(
                              color: counter.today > 0 ? p.good : p.bad,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (controls) const SizedBox(width: 8),
              if (controls)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniBtn(
                      icon: 'minus',
                      on: () {
                        store.bump(counter, -counter.step);
                        store.sfx(false);
                      },
                    ),
                    const SizedBox(height: 5),
                    _MiniBtn(
                      icon: 'plus',
                      filled: true,
                      on: () {
                        store.bump(counter, counter.step);
                        store.sfx(true);
                      },
                    ),
                  ],
                ),
            ],
          ),
          if (counter.hasGoal) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(child: Progress(value: counter.goalRatio, height: 5)),
                const SizedBox(width: 9),
                Text(
                  '${counter.goalPct}%',
                  style: TextStyle(
                    color: counter.goalRatio >= 1 ? p.good : p.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  counter.goalRatio >= 1
                      ? L.t('goalReached')
                      : '${counter.stepsLeft} ${L.t('steps')}',
                  style: over(p).copyWith(fontSize: 9),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

void deleteWithUndo(Counter counter) {
  final index = store.counters.indexOf(counter);
  if (index < 0) return;
  store.counters.removeAt(index);
  store.trash.add(_Deleted(counter, index));
  store.touch();
  store.vib(true);
  toasts.show(
    '${counter.name} · ${L.t('delete')}',
    icon: 'trash',
    bad: true,
    actionLabel: L.t('undo'),
    onAction: store.restoreLast,
  );
}

class _SwipeBg extends StatelessWidget {
  final String icon, labelKey;
  final bool end;
  const _SwipeBg({
    required this.icon,
    required this.labelKey,
    this.end = false,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final ink = end ? p.bad : p.accent;
    return Container(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: end ? 18 : 16),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: p.dark ? .18 : .12),
        borderRadius: BorderRadius.circular(Tk.rCard),
        border: Border.all(color: ink.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisAlignment:
            end ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (end) ...[
            Text(
              L.t(labelKey),
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconX(icon, size: 17, color: ink),
          if (!end) ...[
            const SizedBox(width: 8),
            Text(
              L.t(labelKey),
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small single-line text prompt in a sheet (folder names, symbols…).
Future<String?> promptText(
  BuildContext context,
  String titleText, {
  String? hint,
  String initial = '',
}) {
  final ctrl = TextEditingController(text: initial);
  return sheet<String>(
    context,
    StatefulBuilder(
      builder: (c, set) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Field(
              ctrl: ctrl,
              hint: hint,
              clear: true,
              onSubmit: () => Navigator.pop(c, ctrl.text),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    label: L.t('cancel'),
                    on: () => Navigator.pop(c),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PrimaryBtn(
                    full: true,
                    label: L.t('save'),
                    on: () => Navigator.pop(c, ctrl.text),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
    title: titleText,
  );
}

// ============================== COUNTER DETAIL ==============================

class CounterDetailScreen extends StatefulWidget {
  final Counter counter;
  const CounterDetailScreen({super.key, required this.counter});

  @override
  State<CounterDetailScreen> createState() => _CounterDetailState();
}

class _CounterDetailState extends State<CounterDetailScreen> {
  bool keepScreen = false;
  bool fullscreen = false;
  bool volumeButtons = false;
  bool stopwatch = false;
  int mult = 1;

  StreamSubscription<dynamic>? volumeSubscription;
  Timer? watchTimer;
  Timer? repeat;
  int elapsedMs = 0;
  DateTime? startedAt;
  final List<_WatchEntry> watchHistory = [];
  final List<_Pop> _pops = [];
  int _popId = 0;

  Counter get counter => widget.counter;

  @override
  void initState() {
    super.initState();
    volumeSubscription =
        const EventChannel('saf/volume').receiveBroadcastStream().listen(
      (event) {
        if (!volumeButtons || !mounted) return;
        if (event == 'up') _bump();
        if (event == 'down') _bump(-counter.step);
      },
      onError: (_) {
        // Older builds have no volume stream; the on-screen buttons still work.
      },
    );
  }

  @override
  void dispose() {
    watchTimer?.cancel();
    repeat?.cancel();
    volumeSubscription?.cancel();
    if (keepScreen) setScreenOn(false);
    if (fullscreen) setFullscreen(false);
    if (volumeButtons) Store.setVolumeKeys(false);
    super.dispose();
  }

  String _fmtWatch(int ms) =>
      '${two(ms ~/ 60000)}:${two((ms % 60000) ~/ 1000)}.${(ms % 1000).toString().padLeft(3, '0')}';

  void _bump([double? delta]) {
    if (counter.stopped) return;
    final d = (delta ?? counter.step) * mult;
    store.vib();
    store.sfx(d > 0);

    if (stopwatch && startedAt != null) {
      final now = nowT();
      watchHistory.add(
        _WatchEntry(
          d > 0 ? '+' : '-',
          now.difference(startedAt!).inMilliseconds,
        ),
      );
      startedAt = now;
      elapsedMs = 0;
    }

    store.bump(counter, d);

    setState(() => _pops.add(_Pop(_popId++, d, Offset(0, 0))));
  }

  void _startRepeat([double? delta]) {
    _bump(delta);
    repeat?.cancel();
    repeat = Timer.periodic(
      const Duration(milliseconds: 170),
      (_) => _bump(delta),
    );
  }

  void _stopRepeat() {
    repeat?.cancel();
    repeat = null;
  }

  void _toggleStopwatch() {
    setState(() {
      stopwatch = !stopwatch;
      if (stopwatch) {
        startedAt = nowT();
        elapsedMs = 0;
        watchTimer?.cancel();
        watchTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
          if (!mounted || startedAt == null) return;
          setState(
            () => elapsedMs = nowT().difference(startedAt!).inMilliseconds,
          );
        });
      } else {
        watchTimer?.cancel();
      }
    });
  }

  Future<void> _watchSheet() async {
    final p = ThemeScope.of(context).pal;
    await sheet<void>(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (watchHistory.isEmpty)
            Text(L.t('noHistory'), style: cap(p))
          else
            for (final e in watchHistory.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(
                      e.label,
                      style: TextStyle(
                        color: e.label == '+' ? p.good : p.bad,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        L.t('steps'),
                        style: cap(p).copyWith(fontSize: 11.5),
                      ),
                    ),
                    Text(
                      _fmtWatch(e.ms),
                      style: numStyle(p, s: 14).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          if (watchHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            GhostBtn(
              icon: 'trash',
              label: L.t('clearHistory'),
              on: () {
                watchHistory.clear();
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
      title: L.t('watchHistory'),
    );
  }

  Future<void> _menu() async {
    final picked = await menuSheet(context, counter.name, [
      MenuItem('edit', L.t('edit'), icon: 'edit'),
      MenuItem(
        'pin',
        counter.pinned ? L.t('unpin') : L.t('pin'),
        icon: 'pin',
        checked: counter.pinned,
      ),
      MenuItem(
        'stop',
        counter.stopped ? L.t('resume') : L.t('pause'),
        icon: counter.stopped ? 'play' : 'pause',
      ),
      MenuItem('reset', L.t('reset'), icon: 'refresh'),
      MenuItem('watch', L.t('stopwatch'), icon: 'timer', checked: stopwatch),
      MenuItem('screen', L.t('keepOn'), icon: 'sun', checked: keepScreen),
      MenuItem('full', L.t('fullscreen'), icon: 'expand', checked: fullscreen),
      MenuItem(
        'keys',
        L.t('volumeButtons'),
        icon: 'keys',
        checked: volumeButtons,
      ),
      MenuItem('del', L.t('delete'), icon: 'trash', danger: true),
    ]);
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'edit':
        nav.openCounterEditor(counter);
        break;
      case 'pin':
        counter.pinned = !counter.pinned;
        store.touch();
        break;
      case 'stop':
        counter.stopped = !counter.stopped;
        store.touch();
        break;
      case 'reset':
        store.bump(counter, -counter.value);
        break;
      case 'watch':
        _toggleStopwatch();
        break;
      case 'screen':
        setState(() => keepScreen = !keepScreen);
        setScreenOn(keepScreen);
        break;
      case 'full':
        setState(() => fullscreen = !fullscreen);
        setFullscreen(fullscreen);
        break;
      case 'keys':
        setState(() => volumeButtons = !volumeButtons);
        Store.setVolumeKeys(volumeButtons);
        break;
      case 'del':
        deleteWithUndo(counter);
        nav.back();
        break;
    }
  }

  /// Day-by-day history for the last two weeks, oldest at the top.
  Widget _history(Pal p) {
    final now = nowT();
    final vals = counter.trail(14);
    var mx = 0.0;
    for (final v in vals) {
      mx = math.max(mx, v.abs());
    }
    final rows = <Widget>[];
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == 0) continue;
      final day = now.subtract(Duration(days: vals.length - 1 - i));
      final name = weekdayNames()[day.weekday - 1];
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(
        Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                '${name.substring(0, 3)} ${day.day}',
                style: over(p).copyWith(fontSize: 9.5, color: p.sub),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, q) {
                  final w = mx == 0
                      ? 0.0
                      : (q.maxWidth * (v.abs() / mx).clamp(0.05, 1.0));
                  return SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.surface3,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        if (w > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: w,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: v < 0
                                    ? p.bad
                                    : (i == vals.length - 1
                                        ? p.accent
                                        : p.accent.withValues(alpha: .55)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              child: Text(
                fmtK(v),
                textAlign: TextAlign.right,
                style: over(p).copyWith(
                  fontSize: 9.5,
                  color: v < 0 ? p.bad : p.text2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Section(L.t('lastDays')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 14, 14, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final money =
        counter.moneyEnabled && (counter.usesManualMoney || counter.mult != 0);

    return Page(
      max: Tk.maxSingle,
      header: Header(
        titleText: counter.name,
        sub: counter.group.isEmpty ? L.t('noFolder') : counter.group,
        size: 20,
        back: true,
        leading: IconTile(counter.icon, size: 34),
        actions: [
          IconBtn(
            icon: 'edit',
            sem: L.t('edit'),
            on: () => nav.openCounterEditor(counter),
          ),
          IconBtn(icon: 'moreV', sem: L.t('options'), on: _menu),
        ],
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 20),
            children: [
              // ---- hero number, tap anywhere ----
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (_) => _bump(),
                onLongPressStart: (_) => _startRepeat(),
                onLongPressEnd: (_) => _stopRepeat(),
                onLongPressCancel: _stopRepeat,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Tk.rCardLg),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: p.hero,
                    ),
                    border: Border.all(color: p.line),
                    boxShadow: Shadow.of(p, y: 14, blur: 34, a: .09),
                  ),
                  child: Column(
                    children: [
                      AnimatedNum(
                        counter.value,
                        style: Tk.numLg.copyWith(
                          color: counter.stopped ? p.sub : p.text,
                          fontSize: 82,
                        ),
                        label: (v) => fmtK(v),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${L.t('step')} ${fmt(counter.step)}'
                        '${counter.moneyEnabled ? '  ·  +${counter.symbol}${fmt(counter.usesManualMoney ? (counter.moneyStep ?? 0) : counter.step * counter.mult)}' : ''}'
                        '${mult > 1 ? '  ×$mult' : ''}',
                        style: cap(p, c: p.text2),
                      ),
                      if (money) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconX('tag', size: 13, color: p.gold),
                            const SizedBox(width: 6),
                            Text(
                              '${counter.symbol} ${fmtK(counter.money)}',
                              style: TextStyle(
                                color: p.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Column(
                          children: [
                            if (counter.hasGoal) ...[
                              Progress(
                                value: counter.goalRatio,
                                height: 6,
                                glow: counter.goalRatio > .8,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    counter.goalRatio >= 1
                                        ? L.t('goalReached')
                                        : '${counter.stepsLeft} ${L.t('steps')} · ${L.t('toGoal')}',
                                    style: cap(p).copyWith(fontSize: 11),
                                  ),
                                  Text(
                                    '${counter.goalPct}%',
                                    style: TextStyle(
                                      color: counter.goalRatio >= 1
                                          ? p.good
                                          : p.accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                L.t('tapAnywhere'),
                                style: cap(p).copyWith(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ---- step multipliers ----
              Row(
                children: [
                  for (final m in const [1, 2, 5, 10])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Chip(
                        label: '×$m',
                        active: mult == m,
                        on: () {
                          store.vib();
                          setState(() => mult = m);
                        },
                      ),
                    ),
                  const Spacer(),
                  if (store.canUndo(counter))
                    Chip(
                      label: L.t('undo'),
                      icon: 'refresh',
                      on: () {
                        store.undo();
                        store.vib();
                        toasts.show(L.t('undone'), icon: 'refresh');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // ---- today + trail ----
              Card(
                pad: const EdgeInsets.fromLTRB(14, 13, 14, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('today').toUpperCase(),
                            style: over(p).copyWith(fontSize: 9.5),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${counter.today > 0 ? '+' : ''}${fmtK(counter.today)}',
                                style: Tk.num.copyWith(
                                  fontSize: 22,
                                  color: counter.today == 0
                                      ? p.sub
                                      : (counter.today > 0 ? p.good : p.bad),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${L.t('streak')} ${counter.streak}d',
                                  style: cap(p),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 128,
                      child: Trail(
                        counter.trail(14),
                        height: 40,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              ),
              if (stopwatch) ...[
                const SizedBox(height: 12),
                Card(
                  on: _watchSheet,
                  child: Row(
                    children: [
                      IconX('timer', size: 17, color: p.accent),
                      const SizedBox(width: 11),
                      Text(
                        L.t('watchHistory'),
                        style: TextStyle(
                          color: p.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmtWatch(elapsedMs),
                        style: numStyle(p, s: 15).copyWith(
                          color: p.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _history(p),
              if (counter.stopped) ...[
                const SizedBox(height: 12),
                Card(
                  bg: p.warn.withValues(alpha: .12),
                  border: false,
                  child: Row(
                    children: [
                      IconX('pause', size: 17, color: p.warn),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          L.t('stopped'),
                          style: TextStyle(
                            color: p.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Chip(
                        label: L.t('resume'),
                        icon: 'play',
                        active: true,
                        on: () {
                          counter.stopped = false;
                          store.touch();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // tap feedback
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  for (final f in _pops)
                    _PopFx(pop: f, done: () => _pops.remove(f)),
                ],
              ),
            ),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 14),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                on: () {
                  _stopRepeat();
                  _bump(-counter.step * mult);
                },
                onLongStart: () => _startRepeat(-counter.step * mult),
                onLongEnd: _stopRepeat,
                radius: 16,
                bg: p.surface,
                border: p.lineStrong,
                pad: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: IconX('minus', size: 26, color: p.text2, weight: 2.2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CtrlToggle(
              icon: 'timer',
              active: stopwatch,
              on: _toggleStopwatch,
              label: L.t('stopwatch'),
            ),
            const SizedBox(width: 6),
            _CtrlToggle(
              icon: 'sun',
              active: keepScreen,
              label: L.t('keepOn'),
              on: () {
                setState(() => keepScreen = !keepScreen);
                setScreenOn(keepScreen);
              },
            ),
            const SizedBox(width: 6),
            _CtrlToggle(
              icon: 'expand',
              active: fullscreen,
              label: L.t('fullscreen'),
              on: () {
                setState(() => fullscreen = !fullscreen);
                setFullscreen(fullscreen);
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Pressable(
                on: () {
                  _stopRepeat();
                  _bump();
                },
                onLongStart: () => _startRepeat(),
                onLongEnd: _stopRepeat,
                radius: 16,
                filled: true,
                pad: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconX('plus', size: 26, color: p.accentInk, weight: 2.4),
                      const SizedBox(width: 8),
                      Text(
                        fmt(counter.step * mult),
                        style: TextStyle(
                          color: p.accentInk,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchEntry {
  final String label;
  final int ms;
  _WatchEntry(this.label, this.ms);
}

class _Pop {
  final int id;
  final double delta;
  final Offset at;
  _Pop(this.id, this.delta, this.at);
}

class _PopFx extends StatefulWidget {
  final _Pop pop;
  final VoidCallback done;
  const _PopFx({required this.pop, required this.done});

  @override
  State<_PopFx> createState() => _PopFxState();
}

class _PopFxState extends State<_PopFx> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..forward().whenComplete(() {
      if (mounted) setState(widget.done);
    });

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final up = widget.pop.delta > 0;
    return Align(
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(c.value);
          return Transform.translate(
            offset: Offset(0, -60 * t),
            child: Opacity(
              opacity: (1 - c.value).clamp(0.0, 1.0).toDouble(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (up ? p.accent : p.bad).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(Tk.rPill),
                  border: Border.all(
                    color: (up ? p.accent : p.bad).withValues(alpha: .5),
                  ),
                ),
                child: Text(
                  '${up ? '+' : ''}${fmt(widget.pop.delta)}',
                  style: TextStyle(
                    color: up ? p.accent : p.bad,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CtrlToggle extends StatelessWidget {
  final String icon, label;
  final bool active;
  final VoidCallback on;
  const _CtrlToggle({
    required this.icon,
    required this.on,
    this.active = false,
    required this.label,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Pressable(
      on: on,
      sem: label,
      radius: 14,
      pad: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      bg: active ? p.accentSoft : p.surface,
      border: active ? p.accent : p.line,
      child: IconX(icon, size: 19, color: active ? p.accent : p.text2),
    );
  }
}

// ============================== COUNTER EDITOR ==============================

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

  static const symbols = [
    '€',
    '\$',
    '£',
    '¥',
    '₹',
    '₩',
    'zł',
    'kr',
    'CHF',
    '%',
  ];

  String folder = '';
  String glyph = 'tag';
  String goalAction = 'continue';
  bool manualMoney = false;
  bool moneyEnabled = false;

  final _num = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'));

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
    glyph = c?.icon ?? 'tag';

    moneyValue = TextEditingController(
      text: c?.moneyValue == null ? '' : fmt(c!.moneyValue!),
    );
    moneyStep = TextEditingController(
      text: c?.moneyStep == null ? '' : fmt(c!.moneyStep!),
    );
    goalV = TextEditingController(text: c?.goalV == null ? '' : fmt(c!.goalV!));
    goalM = TextEditingController(text: c?.goalM == null ? '' : fmt(c!.goalM!));

    folder = c?.group ?? '';
    goalAction = c?.goalAction ?? 'continue';

    for (final ctrl in [
      name,
      value,
      step,
      symbol,
      mult,
      moneyValue,
      moneyStep,
      goalV,
      goalM,
    ]) {
      ctrl.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      name,
      value,
      step,
      symbol,
      mult,
      moneyValue,
      moneyStep,
      goalV,
      goalM,
    ]) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }

  double get vValue => numOf(value.text) ?? 0;
  double get vStep => numOf(step.text) ?? 1;
  double get vMult => numOf(mult.text) ?? 1;
  bool get valid => name.text.trim().isNotEmpty;

  Counter preview() => Counter(
        id: 'preview',
        name: name.text.trim().isEmpty ? L.t('name') : name.text.trim(),
        group: folder,
        symbol: symbol.text.trim().isEmpty ? '€' : symbol.text.trim(),
        value: vValue,
        step: vStep,
        mult: vMult,
        moneyEnabled: moneyEnabled,
        moneyValue: manualMoney ? (numOf(moneyValue.text) ?? 0) : null,
        moneyStep: manualMoney ? (numOf(moneyStep.text) ?? 0) : null,
        goalV: numOf(goalV.text),
        goalM: numOf(goalM.text),
        goalAction: goalAction,
        icon: glyph,
        log: widget.counter?.log,
      );

  void save() {
    if (!valid) return;
    final c = widget.counter;
    final nextValue = vValue;
    final nextMult = vMult;

    if (nextMult == 0) {
      moneyEnabled = false;
      manualMoney = false;
    }

    final nextMoneyValue = manualMoney ? (numOf(moneyValue.text) ?? 0) : null;
    final nextMoneyStep = manualMoney ? (numOf(moneyStep.text) ?? 0) : null;

    if (c == null) {
      final created = Counter(
        id: uid(),
        name: name.text.trim(),
        group: folder.trim(),
        symbol: symbol.text.trim().isEmpty ? '€' : symbol.text.trim(),
        value: nextValue,
        step: vStep,
        mult: nextMult,
        moneyEnabled: moneyEnabled,
        moneyValue: nextMoneyValue,
        moneyStep: nextMoneyStep,
        goalV: numOf(goalV.text),
        goalM: numOf(goalM.text),
        goalAction: goalAction,
        order: store.counters.length,
        icon: glyph,
      );
      created.ensureMoneySeed();
      store.counters.add(created);
      store.touch();
      toasts.show(L.t('save'), icon: 'check');
    } else {
      c.name = name.text.trim();
      c.group = folder.trim();
      c.symbol = symbol.text.trim().isEmpty ? '€' : symbol.text.trim();
      c.value = nextValue;
      c.step = vStep;
      c.mult = nextMult;
      c.moneyEnabled = moneyEnabled;
      c.moneyValue = nextMoneyValue;
      c.moneyStep = nextMoneyStep;
      c.ensureMoneySeed();
      c.goalV = numOf(goalV.text);
      c.goalM = numOf(goalM.text);
      c.goalAction = goalAction;
      c.icon = glyph;
      store.touch();
      toasts.show(L.t('save'), icon: 'check');
    }

    nav.back();
  }

  Future<void> pickFolder() async {
    final picked = await menuSheet(
      context,
      L.t('group'),
      [
        MenuItem('', L.t('noFolder'), icon: 'x', checked: folder.isEmpty),
        for (final g in store.groups)
          MenuItem(g, g, icon: 'folder', checked: folder == g),
        const MenuItem('__new', '—', icon: 'plus'),
      ]..last = MenuItem('__new', L.t('newFolder'), icon: 'plus'),
    );

    if (picked == null) return;
    if (picked == '__new') {
      final text = await promptText(
        context,
        L.t('newFolder'),
        hint: L.t('group'),
      );
      if (text != null && text.trim().isNotEmpty)
        setState(() => folder = text.trim());
      return;
    }
    setState(() => folder = picked);
  }

  Future<void> remove() async {
    final c = widget.counter;
    if (c == null) return;
    if (!await confirm(context, L.t('delete'), c.name)) return;
    deleteWithUndo(c);
    nav.back();
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final previewCounter = preview();

    return Page(
      max: Tk.maxSingle,
      header: Header(
        titleText: widget.counter == null ? L.t('new') : L.t('edit'),
        sub: widget.counter == null ? L.t('quickAdd') : null,
        size: 22,
        back: true,
        actions: [
          if (widget.counter != null)
            IconBtn(icon: 'trash', sem: L.t('delete'), on: remove),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 24),
        children: [
          // ---- live preview ----
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  L.t('preview').toUpperCase(),
                  style: over(p).copyWith(fontSize: 9.5),
                ),
              ),
              CounterCard(counter: previewCounter, enabled: false),
            ],
          ),
          const SizedBox(height: Tk.gapSection),

          _EditorCard(
            titleText: L.t('name'),
            children: [
              Field(
                ctrl: name,
                hint: L.t('nameHint'),
                icon: 'edit',
                action: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Text(L.t('symbol'), style: over(p).copyWith(fontSize: 9.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Field(ctrl: symbol, hint: '€', maxChars: 4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in symbols)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: s,
                                active: symbol.text == s,
                                on: () => symbol.text = s,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(L.t('group'), style: over(p).copyWith(fontSize: 9.5)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    label: folder.isEmpty ? L.t('noFolder') : folder,
                    icon: 'folder',
                    active: folder.isNotEmpty,
                    on: pickFolder,
                  ),
                  for (final g in store.groups.take(5))
                    if (g != folder)
                      Chip(
                        label: g,
                        icon: 'folder',
                        on: () => setState(() => folder = g),
                      ),
                  Chip(label: L.t('newFolder'), icon: 'plus', on: pickFolder),
                ],
              ),
              const SizedBox(height: 14),
              Text(L.t('icon'), style: over(p).copyWith(fontSize: 9.5)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final g in Counter.glyphs)
                    Pressable(
                      on: () => setState(() => glyph = g),
                      sem: g,
                      radius: 11,
                      pad: const EdgeInsets.all(9),
                      bg: glyph == g ? p.accentSoft : p.surface2,
                      border: glyph == g ? p.accent : p.line,
                      child: IconX(
                        g,
                        size: 18,
                        color: glyph == g ? p.accent : p.text2,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Tk.gapForm),

          _EditorCard(
            titleText: L.t('count'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Field(
                      ctrl: value,
                      label: L.t('value'),
                      type: TextInputType.number,
                      formatter: [_num],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Field(
                      ctrl: step,
                      label: L.t('step'),
                      type: TextInputType.number,
                      formatter: [_num],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in const [
                    '1',
                    '2',
                    '5',
                    '10',
                    '25',
                    '50',
                    '100',
                  ])
                    Chip(
                      label: '+$s',
                      active: (numOf(step.text) ?? -1) == (numOf(s) ?? -2),
                      on: () => step.text = s,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Tk.gapForm),

          _EditorCard(
            titleText: L.t('money'),
            trailing: Toggle(
              value: moneyEnabled,
              sem: L.t('money'),
              on: (v) => setState(() {
                moneyEnabled = v;
                if (v && manualMoney && moneyValue.text.isEmpty) {
                  moneyValue.text = fmt(vValue * vMult);
                }
              }),
            ),
            children: [
              if (!moneyEnabled)
                Text(L.t('moneySub'), style: cap(p))
              else ...[
                Field(
                  ctrl: mult,
                  label: L.t('mult'),
                  type: TextInputType.number,
                  formatter: [_num],
                  suffix:
                      '${symbol.text.isEmpty ? '€' : symbol.text} / ${L.t('step')}',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Toggle(
                        value: manualMoney,
                        sem: L.t('manualMoney'),
                        on: (v) => setState(() {
                          manualMoney = v;
                          if (v && moneyValue.text.isEmpty) {
                            moneyValue.text = fmt(vValue * vMult);
                            moneyStep.text = fmt(vMult);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: Text(L.t('manualMoney'), style: cap(p, c: p.text)),
                    ),
                  ],
                ),
                if (manualMoney) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Field(
                          ctrl: moneyStep,
                          label: L.t('moneyStep'),
                          type: TextInputType.number,
                          formatter: [_num],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Field(
                          ctrl: moneyValue,
                          label: L.t('money'),
                          type: TextInputType.number,
                          formatter: [_num],
                        ),
                      ),
                    ],
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Text(
                          '= ${symbol.text.isEmpty ? '€' : symbol.text} ',
                          style: cap(p, c: p.text2),
                        ),
                        Text(
                          fmtK(previewCounter.money),
                          style: TextStyle(
                            color: p.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: Tk.gapForm),

          _EditorCard(
            titleText: L.t('goals'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Field(
                      ctrl: goalV,
                      label: L.t('goalValue'),
                      type: TextInputType.number,
                      formatter: [_num],
                      hint: '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: moneyEnabled
                        ? Field(
                            ctrl: goalM,
                            label: L.t('goalMoney'),
                            type: TextInputType.number,
                            formatter: [_num],
                            hint: '—',
                          )
                        : Opacity(
                            opacity: .4,
                            child: Field(
                              ctrl: goalM,
                              label: L.t('goalMoney'),
                              type: TextInputType.number,
                              hint: L.t('money'),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(L.t('goalAction'), style: over(p).copyWith(fontSize: 9.5)),
              const SizedBox(height: 7),
              Segmented(
                value: switch (goalAction) {
                  'stop' => 1,
                  'reset' => 2,
                  _ => 0,
                },
                labels: [L.t('continue'), L.t('stop'), L.t('reset')],
                icons: const ['play', 'pause', 'refresh'],
                on: (i) => setState(
                  () => goalAction = const ['continue', 'stop', 'reset'][i],
                ),
              ),
              const SizedBox(height: 10),
              Text(L.t('goalActionSub'), style: cap(p).copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
      footer: _SaveBar(valid: valid, onSave: save, onCancel: nav.back),
    );
  }
}

class _EditorCard extends StatelessWidget {
  final String titleText;
  final List<Widget> children;
  final Widget? trailing;
  const _EditorCard({
    required this.titleText,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: box(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titleText.toUpperCase(),
                  style: over(p).copyWith(fontSize: 9.5),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool valid;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  const _SaveBar({
    required this.valid,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .92),
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(Tk.gutter, 10, Tk.gutter, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GhostBtn(label: L.t('cancel'), on: onCancel),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Opacity(
                opacity: valid ? 1 : .45,
                child: Pressable(
                  on: valid ? onSave : null,
                  filled: true,
                  radius: 13,
                  pad: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconX('check', size: 16, color: p.accentInk, weight: 2.2),
                      const SizedBox(width: 8),
                      Text(
                        L.t('save'),
                        style: TextStyle(
                          color: p.accentInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== TIME (focus + calendar) ==============================

class TimeScreen extends StatelessWidget {
  const TimeScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final focusTab = nav.timeTab == 1;

    return Page(
      max: focusTab ? Tk.maxSingle : Tk.maxColumns,
      header: Header(
        titleText: L.t('time'),
        size: 24,
        sub: focusTab ? L.t('focusSub') : L.t('calendar'),
        actions: [
          IconBtn(
            icon: focusTab ? 'calendar' : 'clock',
            sem: L.t('time'),
            on: () => nav.setTab(focusTab ? 0 : 1),
          ),
        ],
      ),
      chrome: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Segmented(
              value: focusTab ? 1 : 0,
              labels: [L.t('calendar'), L.t('focus')],
              icons: const ['calendar', 'clock'],
              width: 240,
              on: (i) => nav.setTab(i),
            ),
          ),
        ),
      ],
      child: AnimatedSwitcher(
        duration: Tk.base,
        switchInCurve: Tk.curve,
        switchOutCurve: Tk.curve,
        child: focusTab
            ? const FocusPane(key: ValueKey('focus'))
            : const CalendarPane(key: ValueKey('cal')),
      ),
    );
  }
}

// ------------------------------- focus pane -------------------------------

class FocusPane extends StatelessWidget {
  const FocusPane({super.key});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return AnimatedBuilder(
      animation: focus,
      builder: (_, __) {
        final live = focus.running;
        return ListView(
          padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 112),
          children: [
            Card(
              pad: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              child: Column(
                children: [
                  Text(
                    (live ? L.t('focus') : L.t('ready')).toUpperCase(),
                    style: over(p).copyWith(fontSize: 9.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 216,
                    height: 216,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Ring(
                          value: focus.ratio,
                          size: 216,
                          stroke: 11,
                          tick: true,
                          color: live ? p.accent : p.lineStrong,
                        ),
                        SizedBox(
                          width: 150,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fmtClock(focus.secondsLeft),
                                style: Tk.num.copyWith(
                                  fontSize: 46,
                                  color: p.text,
                                  letterSpacing: -2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                live
                                    ? '${L.t('endsAt')} ${focus.endClock}'
                                    : '${focus.completions} ${L.t('done').toLowerCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: cap(p).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!live)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final m in FocusEngine.presets)
                            Chip(
                              label: '$m${L.t('minutesShort')}',
                              active: focus.durationSec == m * 60,
                              on: () {
                                store.vib();
                                focus.setMinutes(m);
                              },
                            ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Pressable(
                        on: focus.reset,
                        sem: L.t('reset'),
                        radius: Tk.rPill,
                        bg: p.surface2,
                        border: p.line,
                        pad: const EdgeInsets.all(14),
                        child: IconX('refresh', size: 19, color: p.text2),
                      ),
                      const SizedBox(width: 12),
                      Pressable(
                        on: focus.toggle,
                        filled: true,
                        sem: live ? L.t('pause') : L.t('start'),
                        radius: Tk.rPill,
                        pad: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconX(
                              live ? 'pause' : 'play',
                              size: 19,
                              color: p.accentInk,
                              weight: 2.2,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              live ? L.t('pause') : L.t('start'),
                              style: TextStyle(
                                color: p.accentInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Pressable(
                        on: () => focus.nudge(5 * 60),
                        sem: '+5',
                        radius: Tk.rPill,
                        bg: p.surface2,
                        border: p.line,
                        pad: const EdgeInsets.all(14),
                        child: IconX('plus', size: 19, color: p.text2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tk.gapSection),
            Section(L.t('today')),
            Row(
              children: [
                Expanded(
                  child: Stat(
                    label: L.t('focus'),
                    value: '${store.focusToday}',
                    sub: L.t('minutesShort'),
                    icon: 'clock',
                  ),
                ),
                const SizedBox(width: Tk.gapList),
                Expanded(
                  child: Stat(
                    label: L.t('done'),
                    value: '${focus.completions}',
                    sub: L.t('sessions'),
                    icon: 'check_circle',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tk.gapList),
            Card(
              pad: const EdgeInsets.fromLTRB(14, 13, 14, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          L.t('week'),
                          style: over(p).copyWith(fontSize: 9.5),
                        ),
                      ),
                      Text(
                        '${store.focusWeek} ${L.t('minutesShort')}',
                        style: cap(p, c: p.text2).copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Trail(store.focusTrail(14), height: 46),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Text(
                          weekdayNames()[
                              nowT().subtract(Duration(days: 6 - i)).weekday -
                                  1][0],
                          style: over(p).copyWith(
                            fontSize: 8.5,
                            color: i == 6 ? p.accent : p.sub,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tk.gapSection),
            _FocusOptions(),
          ],
        );
      },
    );
  }
}

class _FocusOptions extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    return Card(
      pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          _opt(
            c,
            icon: 'note',
            label: L.t('autoNote'),
            sub: L.t('autoNoteSub'),
            value: store.prefs.focusAutoNote,
            on: (v) {
              store.prefs.focusAutoNote = v;
              store.touch();
            },
          ),
          const _Hairline(),
          _opt(
            c,
            icon: 'sun',
            label: L.t('keepOnTitle'),
            sub: L.t('keepOnSub'),
            value: store.prefs.focusKeepScreenOn,
            on: (v) {
              store.prefs.focusKeepScreenOn = v;
              store.touch();
            },
          ),
          const _Hairline(),
          _opt(
            c,
            icon: 'speaker',
            label: L.t('chime'),
            sub: store.prefs.focusSoundUri.isEmpty
                ? L.t('chimeNone')
                : L.t('chimeCustom'),
            value: null,
            on: () async {
              final uri = await Store.pickAudio();
              if (uri == null) return;
              store.prefs.focusSoundUri = uri;
              store.touch();
              toasts.show(L.t('saved'), icon: 'speaker');
            },
          ),
        ],
      ),
    );
  }

  Widget _opt(
    BuildContext c, {
    required String icon,
    required String label,
    required String sub,
    required bool? value,
    required Function on,
  }) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          IconX(icon, size: 17, color: p.text2),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: cap(p).copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (value == null)
            IconX('right', size: 15, color: p.sub)
          else
            Toggle(value: value, sem: label, on: (v) => on(v)),
        ],
      ),
    );
  }
}

// ------------------------------ calendar pane ------------------------------

class CalendarPane extends StatefulWidget {
  const CalendarPane({super.key});

  @override
  State<CalendarPane> createState() => _CalendarPaneState();
}

class _CalendarPaneState extends State<CalendarPane> {
  late DateTime month = nowT();
  String day = dayKey(nowT());

  Future<void> openDay(String key) async {
    store.vib();
    setState(() {
      day = key;
      if (key.substring(0, 7) != '${month.year}-${two(month.month)}') {
        final d = DateTime.parse(key);
        month = DateTime(d.year, d.month);
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final now = nowT();
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // sunday-first grid
    final notes = store.notes;
    final focusLog = store.focusLog;

    final dayNotes = notes[day] ?? const <Note>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 112),
      children: [
        Card(
          pad: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconBtn(
                    icon: 'left',
                    sem: L.t('prev'),
                    size: 34,
                    on: () => setState(
                      () => month = DateTime(month.year, month.month - 1),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${monthNames()[month.month - 1]} ${month.year}',
                            style: TextStyle(
                              color: p.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.2,
                            ),
                          ),
                          if (month.year == now.year &&
                              month.month == now.month)
                            Text(
                              L.t('today'),
                              style: over(p).copyWith(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconBtn(
                    icon: 'right',
                    sem: L.t('next'),
                    size: 34,
                    on: () => setState(
                      () => month = DateTime(month.year, month.month + 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final w in weekdayNames())
                    Expanded(
                      child: Center(
                        child: Text(
                          w[0],
                          style: over(p).copyWith(fontSize: 9.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row * 7 - lead < days; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: () {
                            final n = row * 7 + col - lead + 1;
                            if (n < 1 || n > days)
                              return const SizedBox(height: 54);
                            final key =
                                '${month.year}-${two(month.month)}-${two(n)}';
                            final isToday = now.year == month.year &&
                                now.month == month.month &&
                                now.day == n;
                            return _DayCell(
                              dayNum: n,
                              keyName: key,
                              selected: key == day,
                              today: isToday,
                              notes: (notes[key] ?? const <Note>[]).length,
                              minutes: (focusLog[key] ?? 0).round(),
                              on: () => openDay(key),
                            );
                          }(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Tk.gapSection),
        Section(
          fullDate(DateTime.parse(day)),
          trailing: Text('${dayNotes.length}', style: cap(p, c: p.sub)),
        ),
        if (dayNotes.isEmpty)
          Card(
            on: () => showNoteEditor(c, null, date: DateTime.parse(day)),
            pad: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Row(
              children: [
                IconX('note', size: 18, color: p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.t('newNote'),
                        style: TextStyle(
                          color: p.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L.t('noNotesSub'),
                        style: cap(p).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconX('plus', size: 17, color: p.accent),
              ],
            ),
          )
        else
          for (final n in dayNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: Tk.gapList),
              child: NoteRow(
                note: n,
                on: () => showNoteEditor(c, n),
                onLong: () => noteMenu(c, n),
              ),
            ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int dayNum, notes, minutes;
  final String keyName;
  final bool selected, today;
  final VoidCallback on;
  const _DayCell({
    required this.dayNum,
    required this.keyName,
    required this.notes,
    required this.minutes,
    required this.selected,
    required this.today,
    required this.on,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final heat = minutes == 0 ? 0.0 : math.min(1, minutes / 90);

    return Pressable(
      on: on,
      sem: keyName,
      subtle: true,
      radius: 12,
      pad: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: Tk.fast,
        curve: Tk.curve,
        height: 54,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected
              ? p.accent
              : heat > 0
                  ? p.accentSoft.withValues(alpha: .35 + heat * .55)
                  : p.surface2.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: today && !selected ? p.accent : clear,
            width: today ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                color: selected ? p.accentInk : (today ? p.accent : p.text2),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (minutes > 0)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? p.accentInk : p.accent,
                    ),
                  ),
                for (var i = 0; i < math.min(notes, 3); i++) ...[
                  const SizedBox(width: 2.5),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          selected ? p.accentInk : p.gold.withValues(alpha: .9),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== NOTES ==============================

Future<bool> ensureNotesFolder(BuildContext context) async {
  if (store.prefs.notesFolderUri.trim().isNotEmpty) return true;
  final result = await store.pickNotesFolder();
  if (result == null) return false;

  final name = (result['name'] as String? ?? '').trim();
  final uri = (result['uri'] as String? ?? '').trim();
  if (name.isEmpty || uri.isEmpty) return false;

  store.prefs.notesFolder = name;
  store.prefs.notesFolderUri = uri;
  await store.syncNotesFolder(name, uri);
  store.touch();
  toasts.show(name, icon: 'folderOpen');
  return true;
}

Future<void> showNoteEditor(
  BuildContext context,
  Note? note, {
  DateTime? date,
}) async {
  if (note == null && !await ensureNotesFolder(context)) return;
  nav.openNoteEditor(note, date);
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesState();
}

class _NotesState extends State<NotesScreen> {
  final q = TextEditingController();
  String folder = '';
  bool pinnedOnly = false;
  bool searchOpen = false;

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

  List<Note> get list {
    final query = q.text.trim().toLowerCase();
    return store.allNotes(folder).where((n) {
      if (pinnedOnly && !n.pinned) return false;
      if (query.isEmpty) return true;
      return n.text.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> chooseFolder() async {
    final result = await store.pickNotesFolder();
    if (result == null) return;

    final name = (result['name'] as String? ?? '').trim();
    final uri = (result['uri'] as String? ?? '').trim();
    if (name.isEmpty || uri.isEmpty) return;

    await store.syncNotesFolder(name, uri);
    store.touch();
    if (!mounted) return;
    setState(() {});
    toasts.show('${L.t('folder')}: $name', icon: 'folderOpen');
  }

  Future<void> refresh() async {
    if (store.prefs.notesFolderUri.trim().isEmpty) {
      await chooseFolder();
      return;
    }
    final before = store.allNotes().length;
    await store.syncNotesFolder(
      store.prefs.notesFolder,
      store.prefs.notesFolderUri,
    );
    final after = store.allNotes().length;
    toasts.show(
      after > before ? '+${after - before}' : L.t('noNotes'),
      icon: after > before ? 'download' : 'refresh',
    );
  }

  Future<void> exportAll() async {
    final lines = <String>[];
    for (final note in store.allNotes()) {
      lines.addAll([
        '---',
        'title: "${trimNoteName(note.text, max: 80)}"',
        'folder: "${note.folder}"',
        'pinned: ${note.pinned}',
        '---',
        note.text,
        '',
      ]);
    }
    try {
      final uri = await Store.channel.invokeMethod<String>('create', {
        'name': 'notes.md',
        'mime': 'text/markdown',
      });
      if (uri == null) return;
      await Store.channel.invokeMethod('write', {
        'uri': uri,
        'bytes': Uint8List.fromList(utf8.encode(lines.join('\n'))),
      });
      toasts.show('notes.md', icon: 'check_circle');
    } catch (_) {
      toasts.show(L.t('error'), icon: 'alert', bad: true);
    }
  }

  Future<void> menu() async {
    final picked = await menuSheet(context, L.t('notes'), [
      MenuItem(
        'folder',
        L.t('folder'),
        icon: 'folder',
        sub: store.prefs.notesFolder,
      ),
      MenuItem('refresh', L.t('refresh'), icon: 'refresh'),
      MenuItem('export', L.t('export'), icon: 'download'),
      MenuItem('new', L.t('newNote'), icon: 'plus'),
    ]);
    switch (picked) {
      case 'folder':
        chooseFolder();
        break;
      case 'refresh':
        refresh();
        break;
      case 'export':
        exportAll();
        break;
      case 'new':
        showNoteEditor(context, null);
        break;
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final items = list;
    final query = q.text.trim();

    var lastDay = '';

    return Page(
      max: Tk.maxSingle,
      header: Header(
        titleText: L.t('notes'),
        size: 24,
        sub: store.prefs.notesFolder.isEmpty
            ? L.t('noFolder')
            : store.prefs.notesFolder,
        actions: [
          IconBtn(
            icon: searchOpen ? 'x' : 'search',
            sem: L.t('search'),
            on: () {
              setState(() => searchOpen = !searchOpen);
              if (!searchOpen) q.clear();
            },
          ),
          IconBtn(icon: 'moreV', sem: L.t('options'), on: menu),
        ],
      ),
      chrome: [
        AnimatedSize(
          duration: Tk.base,
          curve: Tk.curve,
          alignment: Alignment.topCenter,
          child: searchOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tk.gutter,
                    0,
                    Tk.gutter,
                    10,
                  ),
                  child: Field(
                    ctrl: q,
                    icon: 'search',
                    hint: L.t('search'),
                    clear: true,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChipRow([
            Chip(
              label: L.t('all'),
              icon: 'layers',
              active: folder.isEmpty,
              on: () => setState(() => folder = ''),
            ),
            Chip(
              label: L.t('pinned'),
              icon: 'pin',
              active: pinnedOnly,
              on: () => setState(() => pinnedOnly = !pinnedOnly),
            ),
            for (final f in store.noteFolders)
              Chip(
                label: f,
                icon: 'folder',
                active: folder == f,
                on: () => setState(() => folder = folder == f ? '' : f),
              ),
          ]),
        ),
      ],
      fab: store.notes.isEmpty
          ? null
          : Fab(
              icon: 'plus',
              label: items.isEmpty ? L.t('newNote') : null,
              on: () {
                store.vib();
                showNoteEditor(c, null);
              },
            ),
      child: items.isEmpty
          ? EmptyState(
              icon: 'note',
              titleText: query.isNotEmpty ? L.t('noResults') : L.t('noNotes'),
              sub: query.isNotEmpty ? L.t('noResultsSub') : L.t('noNotesSub'),
              cta: L.t('newNote'),
              on: () => showNoteEditor(c, null),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(Tk.gutter, 2, Tk.gutter, 112),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final n = items[i];
                final day = dayKey(DateTime.fromMillisecondsSinceEpoch(n.ts));
                final showDay = day != lastDay;
                lastDay = day;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDay)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : 12,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dayLabel(n.ts),
                                style: over(p).copyWith(
                                  fontSize: 9.5,
                                  color:
                                      day == dayKey(nowT()) ? p.accent : p.sub,
                                ),
                              ),
                            ),
                            Text(
                              '${store.notes[day]?.length ?? 0}',
                              style: cap(p, c: p.sub).copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: showDay ? 0 : Tk.gapList,
                      ),
                      child: NoteRow(
                        note: n,
                        on: () => showNoteEditor(c, n),
                        onLong: () => noteMenu(c, n),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

String _dayLabel(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final today = dayKey(nowT());
  if (dayKey(d) == today) return L.t('today');
  if (dayKey(d) == dayKey(nowT().subtract(const Duration(days: 1)))) {
    return L.t('yesterday');
  }
  return fullDate(d);
}

/// One note: used by the notes list, the calendar and the home feed.
class NoteRow extends StatelessWidget {
  final Note note;
  final VoidCallback on;
  final VoidCallback? onLong;
  const NoteRow({super.key, required this.note, required this.on, this.onLong});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final ink = p.noteInk(note.color);

    return Dismissible(
      key: ValueKey('n-${note.id}'),
      direction: DismissDirection.horizontal,
      background: const _NoteSwipe(
        icon: 'pin',
        labelKey: 'pin',
        colorKey: 'accent',
      ),
      secondaryBackground: const _NoteSwipe(
        icon: 'trash',
        labelKey: 'delete',
        colorKey: 'bad',
        end: true,
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          note.pinned = !note.pinned;
          store.vib();
          store.touch();
          toasts.show(note.pinned ? L.t('pin') : L.t('unpin'), icon: 'pin');
          return false;
        }
        deleteNoteWithUndo(c, note);
        return false;
      },
      child: Card(
        on: on,
        onLong: onLong,
        sem: trimNoteName(note.heading.isEmpty ? note.text : note.heading),
        pad: const EdgeInsets.fromLTRB(13, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 3.5,
              height: 40,
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trimNoteName(
                            note.heading.isEmpty ? note.text : note.heading,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.15,
                          ),
                        ),
                      ),
                      if (note.pinned) ...[
                        const SizedBox(width: 6),
                        IconX('pin', size: 13, color: ink),
                      ],
                    ],
                  ),
                  if (note.preview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      note.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: cap(p).copyWith(height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        relTime(note.ts),
                        style: over(p).copyWith(fontSize: 9, color: p.sub),
                      ),
                      if (note.folder.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '·',
                          style: over(p).copyWith(fontSize: 9, color: p.sub),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          note.folder,
                          style: over(p).copyWith(fontSize: 9, color: p.sub),
                        ),
                      ],
                      const Spacer(),
                      if (note.words > 0)
                        Text(
                          '${note.words} ${L.t('words').toLowerCase()}',
                          style: over(p).copyWith(fontSize: 9, color: p.sub),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconX('right', size: 15, color: p.sub),
          ],
        ),
      ),
    );
  }
}

class _NoteSwipe extends StatelessWidget {
  final String icon, labelKey, colorKey;
  final bool end;
  const _NoteSwipe({
    required this.icon,
    required this.labelKey,
    required this.colorKey,
    this.end = false,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final ink = colorKey == 'bad' ? p.bad : p.accent;
    return Container(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: p.dark ? .18 : .12),
        borderRadius: BorderRadius.circular(Tk.rCard),
        border: Border.all(color: ink.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisAlignment:
            end ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (end) ...[
            Text(
              L.t(labelKey),
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconX(icon, size: 17, color: ink),
          if (!end) ...[
            const SizedBox(width: 8),
            Text(
              L.t(labelKey),
              style: TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void deleteNoteWithUndo(BuildContext c, Note note) {
  final key = dayKey(DateTime.fromMillisecondsSinceEpoch(note.ts));
  final index = store.notes[key]?.indexWhere((e) => e.id == note.id) ?? -1;
  if (index < 0) return;
  store.notes[key]!.removeAt(index);
  store.touch();
  store.vib(true);
  toasts.show(
    '${trimNoteName(note.heading.isEmpty ? note.text : note.heading)} · ${L.t('delete')}',
    icon: 'trash',
    bad: true,
    actionLabel: L.t('undo'),
    onAction: () {
      final list = store.notes[key] ??= [];
      list.insert(index.clamp(0, list.length).toInt(), note);
      store.touch();
    },
  );
}

Future<void> noteMenu(BuildContext c, Note note) async {
  final picked = await menuSheet(
    c,
    trimNoteName(note.heading.isEmpty ? note.text : note.heading),
    [
      MenuItem(
        'pin',
        note.pinned ? L.t('unpin') : L.t('pin'),
        icon: 'pin',
        checked: note.pinned,
      ),
      MenuItem('edit', L.t('edit'), icon: 'edit'),
      MenuItem('open', L.t('preview'), icon: 'eye'),
      MenuItem('date', L.t('today'), icon: 'calendar'),
      MenuItem('del', L.t('delete'), icon: 'trash', danger: true),
    ],
  );
  if (picked == null || !c.mounted) return;
  switch (picked) {
    case 'pin':
      note.pinned = !note.pinned;
      store.touch();
      break;
    case 'edit':
    case 'open':
      showNoteEditor(c, note);
      break;
    case 'date':
      final day = await pickDaySheet(c);
      if (day != null) {
        final oldKey = dayKey(DateTime.fromMillisecondsSinceEpoch(note.ts));
        store.notes[oldKey]?.remove(note);
        note.ts = day.millisecondsSinceEpoch;
        (store.notes[dayKey(day)] ??= []).add(note);
        store.touch();
        toasts.show(fullDate(day), icon: 'calendar');
      }
      break;
    case 'del':
      deleteNoteWithUndo(c, note);
      break;
  }
}

/// Day picker sheet used to move a note to another date.
Future<DateTime?> pickDaySheet(BuildContext c) {
  final now = nowT();
  return sheet<DateTime>(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var i = 0; i < 14; i++)
              () {
                final d = now.subtract(Duration(days: i));
                return Chip(
                  label: '${d.day}',
                  icon: 'calendar',
                  active: dayKey(d) == dayKey(now),
                  on: () => Navigator.pop(c, DateTime(d.year, d.month, d.day)),
                );
              }(),
          ],
        ),
      ],
    ),
    title: L.t('calendar'),
  );
}

// ============================== NOTE EDITOR ==============================

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final DateTime? initialDate;
  const NoteEditorScreen({super.key, this.note, this.initialDate});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditorScreen> {
  final titleCtrl = TextEditingController();
  late final LiveMarkdownController body;
  final titleFocus = FocusNode();
  final bodyFocus = FocusNode();
  Timer? saveTimer;
  late String folder;
  late DateTime targetDate;
  late int color;
  bool preview = false;
  bool readOnly = false;
  bool dirty = false;
  int savedAt = 0;

  Note? get note => widget.note;

  @override
  void initState() {
    super.initState();
    final parts =
        note?.text.replaceAll('\r\n', '\n').split('\n') ?? const <String>[];
    titleCtrl.text = parts.isEmpty
        ? ''
        : parts.first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    body = LiveMarkdownController(
      text: parts.length <= 1 ? '' : parts.skip(1).join('\n'),
    );
    folder = note?.folder ?? store.prefs.notesFolder;
    targetDate = widget.initialDate ??
        (note == null ? nowT() : DateTime.fromMillisecondsSinceEpoch(note!.ts));
    color = note?.color ?? 0;

    titleCtrl.addListener(_changed);
    body.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      dirty = true;
      savedAt = 0;
    });
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) save(silent: true);
    });
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    titleCtrl.removeListener(_changed);
    body.removeListener(_changed);
    titleFocus.dispose();
    bodyFocus.dispose();
    titleCtrl.dispose();
    body.dispose();
    super.dispose();
  }

  String get text {
    final heading = titleCtrl.text.trim();
    final b = body.text.trimRight();
    if (heading.isEmpty) return b;
    return b.isEmpty ? heading : '$heading\n$b';
  }

  Future<void> save({bool silent = false}) async {
    if (titleCtrl.text.trim().isEmpty && body.text.trim().isEmpty) return;

    if (store.prefs.notesFolderUri.trim().isEmpty) {
      if (!await ensureNotesFolder(context)) return;
    }

    final heading = titleCtrl.text.trim();
    final safeBase = heading.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = '${safeBase.isEmpty ? 'nota' : safeBase}.md';
    final content = text;
    final key = dayKey(targetDate);

    final uri = await store.writeNoteFile(
      treeUri: store.prefs.notesFolderUri,
      fileName: fileName,
      content: content,
      existingUri: note?.uri == null || note!.uri.isEmpty ? null : note!.uri,
    );

    if (note == null) {
      final created = store.addNote(
        key,
        content,
        color,
        folder: folder.isEmpty ? store.prefs.notesFolder : folder,
        folderUri: store.prefs.notesFolderUri,
        uri: uri ?? '',
      );
      created.fileName = fileName;
      created.ts = targetDate.millisecondsSinceEpoch;
    } else {
      if (uri != null && uri.isNotEmpty) note!.uri = uri;
      note!.fileName = fileName;
      note!.folder = folder.isEmpty ? note!.folder : folder;
      note!.folderUri = store.prefs.notesFolderUri;
      final oldKey = dayKey(DateTime.fromMillisecondsSinceEpoch(note!.ts));
      if (oldKey != key) {
        store.notes[oldKey]?.remove(note!);
        (store.notes[key] ??= []).add(note!);
      }
      note!.ts = targetDate.millisecondsSinceEpoch;
      store.editNote(key, note!, content, color, folder: note!.folder);
    }

    store.touch();
    if (mounted) {
      setState(() {
        dirty = false;
        savedAt = nowT().millisecondsSinceEpoch;
      });
    }
    if (!silent) toasts.show(L.t('saved'), icon: 'check');
  }

  Future<void> close() async {
    saveTimer?.cancel();
    await save(silent: true);
    nav.back();
  }

  Future<void> menu() async {
    final picked = await menuSheet(context, trimNoteName(text), [
      MenuItem(
        'pin',
        note?.pinned == true ? L.t('unpin') : L.t('pin'),
        icon: 'pin',
        checked: note?.pinned == true,
      ),
      MenuItem('folder', L.t('folder'), icon: 'folder', sub: folder),
      MenuItem(
        'date',
        L.t('calendar'),
        icon: 'calendar',
        sub: fullDate(targetDate),
      ),
      MenuItem('color', L.t('color'), icon: 'palette'),
      MenuItem('props', L.t('info'), icon: 'info'),
      if (note != null)
        MenuItem('del', L.t('delete'), icon: 'trash', danger: true),
    ]);
    if (picked == null) return;
    switch (picked) {
      case 'pin':
        await save(silent: true);
        setState(() {
          if (note != null) note!.pinned = !note!.pinned;
        });
        store.touch();
        break;
      case 'folder':
        final f = await promptText(
          context,
          L.t('folder'),
          hint: store.prefs.notesFolder,
          initial: folder,
        );
        if (f != null) setState(() => folder = f.trim());
        break;
      case 'date':
        final d = await pickDaySheet(context);
        if (d != null) setState(() => targetDate = d);
        break;
      case 'color':
        final pickedColor = await sheet<int>(
          context,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < 6; i++)
                Pressable(
                  on: () => Navigator.pop(context, i),
                  sem: '$i',
                  radius: Tk.rPill,
                  pad: EdgeInsets.zero,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThemeScope.of(context).pal.noteFill(i),
                      border: Border.all(
                        color: color == i
                            ? ThemeScope.of(context).pal.text
                            : ThemeScope.of(context).pal.line,
                        width: color == i ? 2.4 : 1,
                      ),
                    ),
                    child: color == i
                        ? IconX(
                            'check',
                            size: 18,
                            color: ThemeScope.of(context).pal.noteInk(i),
                          )
                        : null,
                  ),
                ),
            ],
          ),
          title: L.t('color'),
        );
        if (pickedColor != null) setState(() => color = pickedColor);
        break;
      case 'props':
        showNoteProperties(context, text, folder, targetDate, note);
        break;
      case 'del':
        if (note == null) return;
        if (!await confirm(context, L.t('delete'), trimNoteName(text))) return;
        final n = note!;
        final key = dayKey(DateTime.fromMillisecondsSinceEpoch(n.ts));
        store.notes[key]?.remove(n);
        store.touch();
        nav.back();
        toasts.show(L.t('delete'), icon: 'trash', bad: true);
        break;
    }
  }

  /// Wrap the current selection with a markdown marker.
  void _wrap(String before, [String? after]) {
    final sel = body.selection;
    final t = body.text;
    if (!sel.isValid || sel.isCollapsed) {
      final insert = '$before${after ?? before}$before';
      final at = sel.isValid ? sel.start : t.length;
      body.value = TextEditingValue(
        text: t.replaceRange(at, at, insert),
        selection: TextSelection.collapsed(offset: at + before.length),
      );
      return;
    }
    final start = sel.start.clamp(0, t.length).toInt();
    final end = sel.end.clamp(0, t.length).toInt();
    final inner = t.substring(math.min(start, end), math.max(start, end));
    final out = t.replaceRange(start, end, '$before$inner${after ?? before}');
    body.value = TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(
        offset: end + before.length + (after ?? before).length,
      ),
    );
  }

  void _prefixLine(String prefix) {
    final t = body.text;
    final sel = body.selection;
    if (!sel.isValid) return;
    var start = sel.start.clamp(0, t.length).toInt();
    while (start > 0 && t[start - 1] != '\n') {
      start--;
    }
    body.value = TextEditingValue(
      text: t.replaceRange(start, start, prefix),
      selection: TextSelection.collapsed(offset: start + prefix.length),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;

    return Page(
      max: Tk.maxReading,
      header: Header(
        back: true,
        eyebrow: fullDate(targetDate),
        titleText: note == null ? L.t('newNote') : trimNoteName(text, max: 22),
        size: 19,
        actions: [
          IconBtn(
            icon: preview ? 'edit' : 'eye',
            sem: L.t('preview'),
            on: () => setState(() => preview = !preview),
          ),
          IconBtn(icon: 'moreV', sem: L.t('options'), on: menu),
        ],
      ),
      chrome: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tk.gutter, 0, Tk.gutter, 6),
          child: Stack(
            children: [
              EditableText(
                controller: titleCtrl,
                focusNode: titleFocus,
                readOnly: readOnly,
                maxLines: 2,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: Tk.font,
                  color: p.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
                cursorColor: p.accent,
                backgroundCursorColor: p.sub,
                enableInteractiveSelection: true,
              ),
              if (titleCtrl.text.isEmpty)
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      L.t('name'),
                      style: TextStyle(
                        color: p.sub,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tk.gutter, 0, Tk.gutter, 10),
          child: Row(
            children: [
              Chip(
                label: folder.isEmpty ? L.t('noFolder') : folder,
                icon: 'folder',
                on: () async {
                  final f = await promptText(
                    c,
                    L.t('folder'),
                    hint: store.prefs.notesFolder,
                    initial: folder,
                  );
                  if (f != null) setState(() => folder = f.trim());
                },
              ),
              const SizedBox(width: 7),
              Chip(
                label: fullDate(targetDate).split(' ').take(3).join(' '),
                icon: 'calendar',
                on: () async {
                  final d = await pickDaySheet(c);
                  if (d != null) setState(() => targetDate = d);
                },
              ),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.noteFill(color),
                  border: Border.all(color: p.line),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
      child: preview || readOnly
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 40),
              child: MarkdownPreview(source: text),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Tk.gutter - 4,
                0,
                Tk.gutter - 4,
                40,
              ),
              child: EditableText(
                controller: body,
                focusNode: bodyFocus,
                readOnly: readOnly,
                showCursor: true,
                inputFormatters: [MarkdownAutoCloseFormatter()],
                style: TextStyle(
                  fontFamily: Tk.font,
                  color: p.text,
                  fontSize: 15,
                  height: 1.62,
                ),
                cursorColor: p.accent,
                backgroundCursorColor: p.sub,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                enableInteractiveSelection: true,
              ),
            ),
      footer: preview
          ? null
          : _NoteToolbar(
              on: (kind) {
                switch (kind) {
                  case 'bold':
                    _wrap('**');
                    break;
                  case 'italic':
                    _wrap('*');
                    break;
                  case 'strike':
                    _wrap('~~');
                    break;
                  case 'code':
                    _wrap('`');
                    break;
                  case 'heading':
                    _prefixLine('# ');
                    break;
                  case 'list':
                    _prefixLine('- ');
                    break;
                  case 'quote':
                    _prefixLine('> ');
                    break;
                  case 'check':
                    _prefixLine('- [ ] ');
                    break;
                  case 'link':
                    _wrap('[', '](url)');
                    break;
                }
                setState(() {});
              },
              words: text.trim().isEmpty
                  ? 0
                  : text.trim().split(RegExp(r'\s+')).length,
              saved: !dirty,
            ),
    );
  }
}

class _NoteToolbar extends StatelessWidget {
  final ValueChanged<String> on;
  final int words;
  final bool saved;
  const _NoteToolbar({
    required this.on,
    required this.words,
    required this.saved,
  });

  static const _keys = [
    'bold',
    'italic',
    'strike',
    'heading',
    'list',
    'check',
    'quote',
    'code',
    'link',
  ];

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .94),
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in _keys)
                      Pressable(
                        on: () => on(k),
                        sem: k,
                        subtle: true,
                        radius: 10,
                        pad: const EdgeInsets.all(9),
                        child: IconX(k, size: 16, color: p.text2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconX(
              saved ? 'check' : 'refresh',
              size: 12,
              color: saved ? p.good : p.sub,
            ),
            const SizedBox(width: 4),
            Text('$words', style: over(p).copyWith(fontSize: 10, color: p.sub)),
          ],
        ),
      ),
    );
  }
}

Future<void> showNoteProperties(
  BuildContext c,
  String text,
  String folder,
  DateTime date,
  Note? note,
) async {
  final words =
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  await sheet<void>(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _prop(c, 'note', note == null ? '—' : '${note.id}'),
        _prop(c, 'folder', folder.isEmpty ? store.prefs.notesFolder : folder),
        _prop(c, 'calendar', fullDate(date)),
        _prop(c, 'words', '$words'),
        _prop(c, 'size', '${text.length} B'),
        _prop(c, 'file', note?.fileName ?? '—'),
        if (note != null && note.uri.isNotEmpty) ...[
          const SizedBox(height: 10),
          GhostBtn(
            icon: 'trash',
            label: L.t('deleteFile'),
            on: () async {
              final ok = await store.deleteNoteFile(note.uri);
              Navigator.pop(c);
              toasts.show(
                ok ? L.t('delete') : L.t('error'),
                icon: ok ? 'check' : 'alert',
                bad: !ok,
              );
            },
          ),
        ],
      ],
    ),
    title: L.t('info'),
  );
}

Widget _prop(BuildContext c, String key, String value) {
  final p = ThemeScope.of(c).pal;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(L.t(key), style: cap(p, c: p.sub).copyWith(fontSize: 11)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: p.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text});

  bool _nearRange(int position, int start, int end, {int distance = 1}) =>
      position >= start - distance && position <= end + distance;

  TextStyle _markerStyle(TextStyle base, {required bool visible}) =>
      base.copyWith(
        color: const Color(0x00000000),
        fontSize: 0,
        height: 0,
      );

  List<InlineSpan> _renderInline(
      String line, int lineStart, TextStyle base, Color accent) {
    final spans = <InlineSpan>[];

    final patterns = <RegExp>[
      RegExp(r'\*\*[^*]+\*\*'),
      RegExp(r'(?<!\*)\*[^*]+\*(?!\*)'),
      RegExp(r'~~[^~]+~~'),
      RegExp(r'`[^`]+`'),
      RegExp(r'\[[^\]]+\]\([^\)]+\)'),
    ];

    final matches = <RegExpMatch>[];
    for (final re in patterns) matches.addAll(re.allMatches(line));
    matches.sort((a, b) => a.start.compareTo(b.start));

    var cursor = 0;
    var lastEnd = -1;

    for (final m in matches) {
      if (m.start < lastEnd) continue;

      if (m.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, m.start), style: base));
      }

      final token = m.group(0)!;
      final absStart = lineStart + m.start;
      final absEnd = lineStart + m.end;

      final active = selection.isCollapsed &&
          _nearRange(selection.start, absStart, absEnd);

      String marker;
      String content;
      TextStyle contentStyle = base;
      int close = -1;

      if (token.startsWith('**')) {
        marker = '**';
        content = token.substring(2, token.length - 2);
        contentStyle = base.copyWith(fontWeight: FontWeight.w800);
      } else if (token.startsWith('~~')) {
        marker = '~~';
        content = token.substring(2, token.length - 2);
        contentStyle = base.copyWith(decoration: TextDecoration.lineThrough);
      } else if (token.startsWith('`')) {
        marker = '`';
        content = token.substring(1, token.length - 1);
        contentStyle = base.copyWith(fontFamily: 'monospace');
      } else if (token.startsWith('[')) {
        close = token.indexOf('](');
        marker = '';
        content = token.substring(1, close);
        contentStyle =
            base.copyWith(decoration: TextDecoration.underline, color: accent);
      } else {
        marker = '*';
        content = token.substring(1, token.length - 1);
        contentStyle = base.copyWith(fontStyle: FontStyle.italic);
      }

      if (marker.isNotEmpty) {
        spans.add(
            TextSpan(text: marker, style: _markerStyle(base, visible: active)));
      }

      spans.add(TextSpan(text: content, style: contentStyle));

      if (token.startsWith('`')) {
        spans.add(
            TextSpan(text: '`', style: _markerStyle(base, visible: active)));
      } else if (token.startsWith('[')) {
        final closeParen = token.lastIndexOf(')');
        if (close > 0 && closeParen > close) {
          final urlText = token.substring(close + 2, closeParen);
          spans.add(
              TextSpan(text: '](', style: _markerStyle(base, visible: active)));
          spans.add(TextSpan(
              text: urlText, style: _markerStyle(base, visible: active)));
          spans.add(
              TextSpan(text: ')', style: _markerStyle(base, visible: active)));
        }
      } else if (marker.isNotEmpty) {
        spans.add(
            TextSpan(text: marker, style: _markerStyle(base, visible: active)));
      }

      cursor = m.end;
      lastEnd = m.end;
    }

    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: base));
    }

    return spans;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final p = ThemeScope.of(context).pal;
    final base = style ?? TextStyle(color: p.text, fontSize: 15, height: 1.5);

    final spans = <InlineSpan>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');

    var offset = 0;
    var fenced = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = offset;
      final lineEnd = offset + line.length;

      final caret = selection.start.clamp(0, text.length).toInt();
      final nearLine = _nearRange(caret, lineStart, lineEnd, distance: 1);

      final fenceMatch = RegExp(r'^```(\w*)\s*$').firstMatch(line.trim());

      if (fenceMatch != null) {
        fenced = !fenced;
        spans.add(TextSpan(
            text: line,
            style: base.copyWith(
                fontFamily: 'monospace', color: nearLine ? p.text : p.text2)));
      } else if (fenced) {
        spans.add(TextSpan(
            text: line,
            style: base.copyWith(fontFamily: 'monospace', color: p.text2)));
      } else {
        final heading =
            RegExp(r'^(#{1,6})\s+(.*?)(?:\s+(#+))?$').firstMatch(line);

        if (heading != null) {
          final opening = heading.group(1)!;
          final gap = RegExp(r'^#{1,6}(\s+)').firstMatch(line)?.group(1) ?? ' ';
          final content = heading.group(2)!;
          final closing = heading.group(3);

          final openingStart = lineStart;
          final openingEnd = openingStart + opening.length + gap.length;
          final closingStart = closing == null ? -1 : lineEnd - closing.length;
          final closingEnd = closing == null ? -1 : lineEnd;

          final collapsed = selection.isCollapsed;

          final revealOpening = collapsed &&
              _nearRange(caret, openingStart, openingEnd, distance: 1);
          final revealClosing = closing != null &&
              collapsed &&
              _nearRange(caret, closingStart, closingEnd, distance: 1);

          final size = switch (opening.length) {
            1 => 29.0,
            2 => 24.0,
            3 => 20.0,
            4 => 18.0,
            _ => 16.5,
          };

          spans.add(TextSpan(
              text: opening,
              style: _markerStyle(base, visible: revealOpening)));
          spans.add(TextSpan(
              text: gap, style: _markerStyle(base, visible: revealOpening)));
          spans.add(TextSpan(
              text: content,
              style: base.copyWith(
                  fontSize: size, fontWeight: FontWeight.w800, height: 1.3)));

          if (closing != null) {
            spans.add(TextSpan(
                text: ' ', style: _markerStyle(base, visible: revealClosing)));
            spans.add(TextSpan(
                text: closing,
                style: _markerStyle(base, visible: revealClosing)));
          }
        } else {
          spans.addAll(_renderInline(line, lineStart, base, p.accent));
        }
      }

      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: base));
      }

      offset = lineEnd + 1;
    }

    return TextSpan(style: base, children: spans);
  }
}

class MarkdownPreview extends StatelessWidget {
  final String source;
  const MarkdownPreview({super.key, required this.source});

  List<InlineSpan> _inline(String text, Pal p) {
    final spans = <InlineSpan>[];

    final patterns = <RegExp>[
      RegExp(r'\*\*[^*]+\*\*'),
      RegExp(r'(?<!\*)\*[^*]+\*(?!\*)'),
      RegExp(r'~~[^~]+~~'),
      RegExp(r'`[^`]+`'),
      RegExp(r'\[[^\]]+\]\([^\)]+\)'),
    ];

    final matches = <RegExpMatch>[];
    for (final re in patterns) matches.addAll(re.allMatches(text));
    matches.sort((a, b) => a.start.compareTo(b.start));

    var cursor = 0;
    var lastEnd = -1;

    for (final m in matches) {
      if (m.start < lastEnd) continue;

      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }

      final token = m.group(0)!;

      if (token.startsWith('**')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(color: p.text, fontWeight: FontWeight.w800)));
      } else if (token.startsWith('~~')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(
                color: p.text2, decoration: TextDecoration.lineThrough)));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
                color: p.text,
                fontFamily: 'monospace',
                backgroundColor: p.surface2)));
      } else if (token.startsWith('[')) {
        final close = token.indexOf('](');
        final label = token.substring(1, close);
        spans.add(TextSpan(
            text: label,
            style: TextStyle(
                color: p.accent, decoration: TextDecoration.underline)));
      } else {
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(color: p.text, fontStyle: FontStyle.italic)));
      }

      cursor = m.end;
      lastEnd = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final lines = source.replaceAll('\r\n', '\n').split('\n');

    if (source.trim().isEmpty) return const SizedBox(height: 6);

    final children = <Widget>[];
    var fenced = false;
    final codeBuf = <String>[];

    void flushCode() {
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: p.surface2, borderRadius: BorderRadius.circular(8)),
        child: RichText(
            text: TextSpan(
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.5),
                children: [
              TextSpan(
                  text: codeBuf.join('\n'), style: TextStyle(color: p.text2))
            ])),
      ));
      codeBuf.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      final fence = RegExp(r'^```(\w*)\s*$').firstMatch(line.trim());

      if (fence != null) {
        if (!fenced)
          fenced = true;
        else {
          fenced = false;
          flushCode();
        }
        continue;
      }

      if (fenced) {
        codeBuf.add(line);
        continue;
      }

      if (line.isEmpty) {
        children.add(const SizedBox(height: 5));
        continue;
      }

      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        children.add(Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(heading.group(2)!,
                style: title(p,
                    s: level == 1
                        ? 22
                        : level == 2
                            ? 18
                            : 15))));
        continue;
      }

      final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        children
            .add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ',
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
          Expanded(
              child: RichText(
                  text: TextSpan(
                      style: body(p), children: _inline(bullet.group(1)!, p)))),
        ]));
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        children.add(Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.only(left: 9),
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.accent, width: 2))),
            child: RichText(
                text: TextSpan(
                    style: body(p), children: _inline(quote.group(1)!, p)))));
        continue;
      }

      children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
              text: TextSpan(style: body(p), children: _inline(line, p)))));
    }

    if (fenced) flushCode();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

// ============================== SETTINGS ==============================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const version = '2.1';

  Future<void> backup(BuildContext c) async {
    try {
      final uri = await Store.channel.invokeMethod<String>('create', {
        'name': 'openfocusly.json',
        'mime': 'application/json',
      });
      if (uri == null) return;
      await Store.channel.invokeMethod('write', {
        'uri': uri,
        'bytes': Uint8List.fromList(utf8.encode(jsonEncode(store.toJson()))),
      });
      toasts.show(L.t('backupOk'), icon: 'check_circle');
    } catch (_) {
      toasts.show(L.t('error'), icon: 'alert', bad: true);
    }
  }

  Future<void> restore(BuildContext c) async {
    if (!await confirm(c, L.t('restore'), L.t('restoreSub'), danger: true))
      return;
    try {
      final uri = await Store.channel.invokeMethod<String>('open', {
        'mime': 'application/json',
      });
      if (uri == null) return;
      final bytes = await Store.channel.invokeMethod<Uint8List>('read', {
        'uri': uri,
      });
      if (bytes == null) return;
      store.load(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      store.touch();
      toasts.show(L.t('restored'), icon: 'check_circle');
    } catch (_) {
      toasts.show(L.t('error'), icon: 'alert', bad: true);
    }
  }

  Future<void> wipe(BuildContext c) async {
    if (!await confirm(
      c,
      L.t('deleteAll'),
      L.t('dangerSub'),
      danger: true,
      confirmLabel: L.t('delete'),
    )) return;
    store.wipeData();
    nav.jump(0);
    toasts.show(L.t('deleted'), icon: 'trash', bad: true);
  }

  Future<void> pickNotesFolder(BuildContext c) async {
    final result = await store.pickNotesFolder();
    if (result == null) return;
    final name = (result['name'] as String? ?? '').trim();
    final uri = (result['uri'] as String? ?? '').trim();
    if (name.isEmpty || uri.isEmpty) return;
    store.prefs.notesFolder = name;
    store.prefs.notesFolderUri = uri;
    await store.syncNotesFolder(name, uri);
    store.touch();
    toasts.show('$name', icon: 'folderOpen');
  }

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final prefs = store.prefs;

    return Page(
      max: Tk.maxSingle,
      header: Header(
        titleText: L.t('settings'),
        size: 24,
        sub: 'OpenFocusly $version',
        actions: [
          IconBtn(icon: 'info', sem: L.t('info'), on: () => nav.jump(5)),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 112),
        children: [
          // ---------- appearance ----------
          Section(L.t('appearance')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(c, L.t('theme')),
                const SizedBox(height: 8),
                Segmented(
                  value: switch (prefs.theme) {
                    'light' => 1,
                    'dark' => 2,
                    _ => 0,
                  },
                  labels: [L.t('system'), L.t('light'), L.t('dark')],
                  icons: const ['auto', 'sun', 'moon'],
                  on: (i) {
                    prefs.theme = const ['system', 'light', 'dark'][i];
                    store.touch();
                    store.vib();
                  },
                ),
                const SizedBox(height: 18),
                _label(c, L.t('accent')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final a in Accent.all)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: Pressable(
                          on: () {
                            prefs.accent = a.key;
                            store.touch();
                            store.vib();
                          },
                          sem: a.label,
                          radius: Tk.rPill,
                          pad: EdgeInsets.zero,
                          child: AnimatedContainer(
                            duration: Tk.fast,
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.dark ? a.dark : a.light,
                              border: Border.all(
                                color: prefs.accent == a.key ? p.text : clear,
                                width: 2.4,
                              ),
                            ),
                            child: prefs.accent == a.key
                                ? IconX(
                                    'check',
                                    size: 15,
                                    color: p.dark
                                        ? const Color(0xFF0B1020)
                                        : white,
                                    weight: 2.6,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _label(c, L.t('language')),
                const SizedBox(height: 8),
                Segmented(
                  value: prefs.lang == 'en' ? 1 : 0,
                  labels: const ['Italiano', 'English'],
                  icons: const ['globe', 'globe'],
                  on: (i) {
                    L.lang = i == 1 ? 'en' : 'it';
                    prefs.lang = L.lang;
                    store.touch();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: Tk.gapSection),

          // ---------- feedback ----------
          Section(L.t('feedback')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                SetRow(
                  icon: 'vibrate',
                  label: L.t('vibration'),
                  sub: L.t('vibrationSub'),
                  trailing: Toggle(
                    value: prefs.vibration,
                    sem: L.t('vibration'),
                    on: (v) {
                      prefs.vibration = v;
                      store.touch();
                      if (v) store.vib(true);
                    },
                  ),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'speaker',
                  label: L.t('sound'),
                  sub: L.t('soundSub'),
                  trailing: Toggle(
                    value: prefs.sound,
                    sem: L.t('sound'),
                    on: (v) {
                      prefs.sound = v;
                      store.touch();
                      if (v) store.sfx(true);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tk.gapSection),

          // ---------- focus ----------
          Section(L.t('focus')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${L.t('defaultLength')} · ${prefs.focusMinutes}${L.t('minutesShort')}',
                        style: cap(p, c: p.text2),
                      ),
                    ),
                    IconBtn(
                      icon: 'minus',
                      sem: '-',
                      size: 32,
                      on: () {
                        prefs.focusMinutes = math.max(
                          1,
                          prefs.focusMinutes - 5,
                        );
                        focus.setMinutes(prefs.focusMinutes);
                        store.touch();
                      },
                    ),
                    const SizedBox(width: 4),
                    IconBtn(
                      icon: 'plus',
                      sem: '+',
                      size: 32,
                      on: () {
                        prefs.focusMinutes = math.min(
                          180,
                          prefs.focusMinutes + 5,
                        );
                        focus.setMinutes(prefs.focusMinutes);
                        store.touch();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final m in FocusEngine.presets)
                      Chip(
                        label: '$m${L.t('minutesShort')}',
                        active: prefs.focusMinutes == m,
                        on: () {
                          prefs.focusMinutes = m;
                          focus.setMinutes(m);
                          store.touch();
                          store.vib();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const _Hairline(),
                SetRow(
                  icon: 'note',
                  label: L.t('autoNote'),
                  sub: L.t('autoNoteSub'),
                  trailing: Toggle(
                    value: prefs.focusAutoNote,
                    sem: L.t('autoNote'),
                    on: (v) {
                      prefs.focusAutoNote = v;
                      store.touch();
                    },
                  ),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'sun',
                  label: L.t('keepOnTitle'),
                  sub: L.t('keepOnSub'),
                  trailing: Toggle(
                    value: prefs.focusKeepScreenOn,
                    sem: L.t('keepOnTitle'),
                    on: (v) {
                      prefs.focusKeepScreenOn = v;
                      store.touch();
                    },
                  ),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'bell',
                  label: L.t('chime'),
                  sub: prefs.focusSoundUri.isEmpty
                      ? L.t('chimeNone')
                      : L.t('chimeCustom'),
                  chevron: true,
                  on: () async {
                    final uri = await Store.pickAudio();
                    if (uri == null) return;
                    prefs.focusSoundUri = uri;
                    store.touch();
                    Store.playChime(uri);
                    toasts.show(L.t('saved'), icon: 'bell');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: Tk.gapSection),

          // ---------- notes ----------
          Section(L.t('notes')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                SetRow(
                  icon: 'folder',
                  label: L.t('folder'),
                  sub: prefs.notesFolder.isEmpty
                      ? L.t('noFolder')
                      : prefs.notesFolder,
                  chevron: true,
                  on: () => pickNotesFolder(c),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'download',
                  label: L.t('export'),
                  sub: L.t('exportSub'),
                  chevron: true,
                  on: () => _exportNotes(c),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'upload',
                  label: L.t('import'),
                  sub: L.t('importSub'),
                  chevron: true,
                  on: () => _importNotes(c),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tk.gapSection),

          // ---------- data ----------
          Section(L.t('data')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                SetRow(
                  icon: 'download',
                  label: L.t('backup'),
                  sub: L.t('backupSub'),
                  chevron: true,
                  on: () => backup(c),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'upload',
                  label: L.t('restore'),
                  sub: L.t('restoreSub'),
                  chevron: true,
                  on: () => restore(c),
                ),
                const _Hairline(),
                SetRow(
                  icon: 'shield',
                  label: L.t('privacy'),
                  sub: L.t('privacySub'),
                  chevron: true,
                  on: () => nav.jump(5),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tk.gapSection),

          // ---------- danger ----------
          Section(L.t('danger')),
          Card(
            bg: p.bad.withValues(alpha: p.dark ? .10 : .06),
            border: false,
            pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: SetRow(
              icon: 'trash',
              ink: p.bad,
              label: L.t('deleteAll'),
              sub: L.t('dangerSub'),
              chevron: true,
              on: () => wipe(c),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Pressable(
              subtle: true,
              radius: Tk.rPill,
              pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              on: () => nav.jump(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconX('info', size: 13, color: p.sub),
                  const SizedBox(width: 7),
                  Text(
                    'OpenFocusly $version · ${store.counters.length} · ${store.allNotes().length}',
                    style: cap(p, c: p.sub).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext c, String t) {
    final p = ThemeScope.of(c).pal;
    return Text(t.toUpperCase(), style: over(p).copyWith(fontSize: 9.5));
  }

  Future<void> _exportNotes(BuildContext c) async {
    final lines = <String>[];
    for (final note in store.allNotes()) {
      lines.addAll([
        '---',
        'title: "${trimNoteName(note.text, max: 80).replaceAll('"', "'")}"',
        'folder: "${note.folder}"',
        'pinned: ${note.pinned}',
        '---',
        note.text,
        '',
      ]);
    }
    try {
      final uri = await Store.channel.invokeMethod<String>('create', {
        'name': 'notes.md',
        'mime': 'text/markdown',
      });
      if (uri == null) return;
      await Store.channel.invokeMethod('write', {
        'uri': uri,
        'bytes': Uint8List.fromList(utf8.encode(lines.join('\n'))),
      });
      toasts.show('notes.md', icon: 'check_circle');
    } catch (_) {
      toasts.show(L.t('error'), icon: 'alert', bad: true);
    }
  }

  Future<void> _importNotes(BuildContext c) async {
    try {
      final uri = await Store.channel.invokeMethod<String>('open', {
        'mime': 'text/markdown',
      });
      if (uri == null) return;
      final bytes = await Store.channel.invokeMethod<Uint8List>('read', {
        'uri': uri,
      });
      if (bytes == null) return;
      final raw = utf8.decode(bytes);
      var added = 0;
      for (final block in raw.split('---')) {
        final t = block.trim();
        if (t.isEmpty || t.startsWith('title:') || t.startsWith('folder:'))
          continue;
        if (t.length < 2) continue;
        store.addNote(
          dayKey(nowT()),
          t,
          0,
          folder: store.prefs.notesFolder,
          folderUri: store.prefs.notesFolderUri,
        );
        added++;
      }
      store.touch();
      toasts.show('+$added', icon: 'check_circle');
    } catch (_) {
      toasts.show(L.t('error'), icon: 'alert', bad: true);
    }
  }
}

class SetRow extends StatelessWidget {
  final String icon, label;
  final String? sub;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? on;
  final Color? ink;
  const SetRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.chevron = false,
    this.on,
    this.ink,
  });

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final color = ink ?? p.text;
    return Pressable(
      on: on,
      subtle: on != null,
      radius: 12,
      pad: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      child: Row(
        children: [
          IconX(icon, size: 18, color: ink ?? p.text2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: cap(p).copyWith(fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing != null)
            trailing!
          else if (chevron)
            IconX('right', size: 16, color: p.sub),
        ],
      ),
    );
  }
}

// ============================== INFO ==============================

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Page(
      max: Tk.maxReading,
      header: Header(titleText: L.t('info'), size: 24, back: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Tk.gutter, 4, Tk.gutter, 112),
        children: [
          Card(
            pad: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.accent, p.accent.withValues(alpha: .6)],
                        ),
                        boxShadow: Shadow.of(p, y: 8, blur: 18, a: .22),
                      ),
                      child: IconX(
                        'bolt',
                        size: 22,
                        color: p.accentInk,
                        weight: 2,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('appName'),
                            style: TextStyle(
                              color: p.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          Text(
                            'v${SettingsScreen.version} · ${L.t('appTag')}',
                            style: cap(p).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(L.t('aboutSub'), style: body(p).copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: Tk.gapSection),
          Section(L.t('featureCounters')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                const SetRow(
                  icon: 'tag',
                  label: 'Counters',
                  sub: 'Goals, money, streaks, 7-day trails, volume keys',
                ),
                const _Hairline(),
                const SetRow(
                  icon: 'clock',
                  label: 'Focus',
                  sub:
                      'Timer that survives tab changes, wake lock, chime, auto note',
                ),
                const _Hairline(),
                const SetRow(
                  icon: 'note',
                  label: 'Notes',
                  sub:
                      'Markdown with live preview, saved as .md in your own folder',
                ),
                const _Hairline(),
                const SetRow(
                  icon: 'calendar',
                  label: 'Calendar',
                  sub: 'Every day, with its notes and its focus minutes',
                ),
              ],
            ),
          ),
          const SizedBox(height: Tk.gapSection),
          Section(L.t('privacy')),
          Card(
            pad: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L.t('privacyLead'), style: body(p).copyWith(height: 1.5)),
                const SizedBox(height: 12),
                for (final r in [
                  ['lock', L.t('privacySub2')],
                  ['shield', L.t('privacyNet')],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      IconX(r[0], size: 15, color: p.accent),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                              Text(r[1], style: cap(p).copyWith(fontSize: 11))),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tk.gapSection),
          PrimaryBtn(
            full: true,
            icon: 'link',
            label: 'GitHub · CarbonWalls/openfocusly',
            on: () async {
              try {
                await Store.channel.invokeMethod('openLink', {
                  'url': 'https://github.com/CarbonWalls/openfocusly',
                });
              } catch (_) {
                toasts.show('github.com/CarbonWalls/openfocusly', icon: 'link');
              }
            },
          ),
          const SizedBox(height: 10),
          GhostBtn(
            full: true,
            icon: 'sparkle',
            label: L.t('whatsNew'),
            on: () => _whatsNew(c),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              'OpenFocusly · GPLv3',
              style: cap(p, c: p.sub).copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _whatsNew(BuildContext c) async {
    final p = ThemeScope.of(c).pal;
    await sheet<void>(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in const [
            'New design system: press, hover and focus feedback everywhere.',
            'Focus timer now keeps running when you change tab, with a live card on Home.',
            'Home is a real dashboard: today, goals, movers, recent notes.',
            'Swipe counters and notes to pin or delete — with undo.',
            'Volume buttons can count on the counter screen.',
            'Accent colours, better dark mode, note colours that stay readable.',
            'Markdown notes: live preview, formatting toolbar, autosave.',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: IconX(
                      'check',
                      size: 13,
                      color: p.accent,
                      weight: 2.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(line, style: body(p).copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
      title: L.t('whatsNew'),
    );
  }
}

// ============================== ROOT ==============================

class Root extends StatefulWidget {
  final List<LocalizationsDelegate<dynamic>> delegates;
  const Root({super.key, this.delegates = const []});

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
    await store.init();

    if (store.prefs.lang == 'en' || store.prefs.lang == 'it') {
      L.lang = store.prefs.lang;
    }

    focus.setMinutes(store.prefs.focusMinutes);
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
          note: nav.editingNote,
          initialDate: nav.editingNoteDate,
        );
      case 8:
        final vc = nav.viewingCounter;
        if (vc == null || !store.counterExists(vc.id)) {
          return const CountersScreen();
        }
        return CounterDetailScreen(counter: vc);
      default:
        return const HomeScreen();
    }
  }

  bool? _chromeDark;

  void _systemChrome(Pal p) {
    if (_chromeDark == p.dark) return;
    _chromeDark = p.dark;
    final style = SystemUiOverlayStyle(
      statusBarColor: clear,
      systemNavigationBarColor: p.surface,
      statusBarIconBrightness: p.dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: p.dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          p.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: p.line,
    );
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, nav, focus]),
      builder: (_, __) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        final dark = store.prefs.theme == 'dark' ||
            (store.prefs.theme == 'system' && brightness == Brightness.dark);
        final p = Pal(dark, Accent.byKey(store.prefs.accent));

        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        if (overlay != null) toasts.attach(overlay);
        _systemChrome(p);

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
                child: ColoredBox(
                  color: p.bg,
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      const SingleActivator(LogicalKeyboardKey.escape):
                          const _BackIntent(),
                      const SingleActivator(
                        LogicalKeyboardKey.digit1,
                        control: true,
                      ): const GoIntent(
                        0,
                      ),
                      const SingleActivator(
                        LogicalKeyboardKey.digit2,
                        control: true,
                      ): const GoIntent(
                        1,
                      ),
                      const SingleActivator(
                        LogicalKeyboardKey.digit3,
                        control: true,
                      ): const GoIntent(
                        2,
                      ),
                      const SingleActivator(
                        LogicalKeyboardKey.digit4,
                        control: true,
                      ): const GoIntent(
                        3,
                      ),
                      const SingleActivator(
                        LogicalKeyboardKey.digit5,
                        control: true,
                      ): const GoIntent(
                        4,
                      ),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _BackIntent: CallbackAction<_BackIntent>(
                          onInvoke: (_) {
                            nav.back();
                            return null;
                          },
                        ),
                        GoIntent: CallbackAction<GoIntent>(
                          onInvoke: (i) {
                            nav.jump(i.screen);
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        autofocus: true,
                        skipTraversal: true,
                        child: SafeArea(
                          bottom: false,
                          child: nav.ready
                              ? Shell(child: page())
                              : const _Splash(),
                        ),
                      ),
                    ),
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

class _BackIntent extends Intent {
  const _BackIntent();
}

class GoIntent extends Intent {
  final int screen;
  const GoIntent(this.screen);
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Center(
        child: Opacity(
          opacity: v,
          child: Transform.scale(
            scale: .88 + .12 * v,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.accent, p.accent.withValues(alpha: .55)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: .38),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(child: IconX('bolt', size: 28, color: white)),
            ),
          ),
        ),
      ),
    );
  }
}

class OpenFocuslyApp extends StatelessWidget {
  const OpenFocuslyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: const Color(0xFF3B5BDB),
      home: const Root(),
      localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('it')],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: Tk.base,
        reverseTransitionDuration: Tk.fast,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) =>
            child,
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpenFocuslyApp());
}
