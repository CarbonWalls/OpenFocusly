import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

const white = Color(0xFFFFFFFF);
const clear = Color(0x00000000);

String fmt(double v) {
  if (!v.isFinite) return '0';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String uid() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(9999).toRadixString(36)}';

double? numOf(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

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

class Counter {
  String id, name, group, symbol;
  double value, step, mult;
  double? moneyValue, moneyStep;
  bool moneyEnabled;
  double? goalV, goalM;
  String goalAction;
  bool pinned, stopped;
  int order;

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
  });

  bool get usesManualMoney => moneyEnabled && moneyStep != null;

  double get money => !moneyEnabled || mult == 0
      ? 0
      : (usesManualMoney ? (moneyValue ?? 0) : value * mult);

  void ensureMoneySeed() {
    if (usesManualMoney && moneyValue == null) moneyValue = value * mult;
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
      )..ensureMoneySeed();
}

class Note {
  String id, text;
  int ts, color;
  bool pinned;
  String folder, folderUri, uri, fileName;

  Note(this.id, this.text, this.ts,
      [this.color = 0,
      this.pinned = false,
      this.folder = '',
      this.folderUri = '',
      this.uri = '',
      this.fileName = '']);

  String get name {
    final first = text.split('\n').first.trim();
    final cleanedFirst = first.replaceFirst(RegExp(r'^#+\s*'), '');
    if (first.startsWith('#')) return cleanedFirst;
    if (fileName.trim().isNotEmpty)
      return fileName.replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
    return cleanedFirst;
  }

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
        (j['ts'] as num? ?? DateTime.now().millisecondsSinceEpoch).toInt(),
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

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'lang': lang,
        'vib': vibration,
        'sound': sound,
        'ggV': goalV,
        'ggM': goalM,
        'notesFolder': notesFolder,
        'notesFolderUri': notesFolderUri,
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
    return p;
  }
}

class Store extends ChangeNotifier {
  static const channel = MethodChannel('saf');

  List<Counter> counters = [];
  Map<String, List<Note>> notes = {};
  Prefs prefs = Prefs();
  String? dir;
  Timer? saveTimer;

  Future<void> init() async {
    try {
      dir = await channel.invokeMethod<String>('filesDir');
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
    notifyListeners();
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 350), save);
  }

  Future<void> save() async {
    if (dir == null) return;
    try {
      await File('$dir/state.json').writeAsString(jsonEncode(toJson()));
    } catch (_) {}
  }

  Map<String, dynamic> toJson() => {
        'counters': counters.map((e) => e.toJson()).toList(),
        'notes':
            notes.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'prefs': prefs.toJson(),
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
          .map((e) => Note.fromJson(Map<String, dynamic>.from(e),
              fallbackFolder: 'generale'))
          .toList();
    }

    prefs = Prefs.fromJson(Map<String, dynamic>.from(j['prefs'] as Map? ?? {}));
  }

  Future<Map<String, dynamic>?> pickNotesFolder() async {
    final result = await channel.invokeMethod<dynamic>('pickDirectory');
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  Future<String?> writeNoteFile(
      {required String treeUri,
      required String fileName,
      required String content,
      String? existingUri}) async {
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
      final result =
          await channel.invokeMethod<dynamic>('documentInfo', {'uri': uri});
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (_) {}
    return null;
  }

  Future<bool> deleteNoteFile(String uri) async {
    try {
      final result =
          await channel.invokeMethod<dynamic>('deleteDocument', {'uri': uri});
      return result == true;
    } catch (e) {
      print('[saf] deleteNoteFile error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listNotesFiles(String treeUri) async {
    try {
      final result = await channel
          .invokeMethod<dynamic>('listMarkdownFiles', {'treeUri': treeUri});
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
      final result =
          await channel.invokeMethod<dynamic>('readTextFile', {'uri': uri});
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
          DateTime.now().millisecondsSinceEpoch;

      if (uri.isEmpty || knownUris.contains(uri)) continue;

      final text = await readNoteFile(uri);
      if (text == null) continue;

      final key = dayKey(DateTime.fromMillisecondsSinceEpoch(modified));
      final n =
          Note(uid(), text, modified, 0, false, folderName, treeUri, uri, name);

      (notes[key] ??= []).add(n);
      knownUris.add(uri);
      changed = true;
    }

    if (changed) touch();
  }

  void vib() {
    if (prefs.vibration) HapticFeedback.mediumImpact();
  }

  double total() => counters.fold(0.0, (a, c) => a + c.value);
  double money() => counters.fold(0.0, (a, c) => a + c.money);

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

  void removeCounter(String id) {
    counters.removeWhere((c) => c.id == id);
    touch();
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

  void bump(Counter c, double delta) {
    if (delta == 0 || c.stopped) return;

    final beforeValue = c.value;
    final beforeMoney = c.money;

    c.value += delta;

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
    }

    touch();
  }

  Note addNote(String key, String text, int color,
      {String folder = '', String folderUri = '', String uri = ''}) {
    final f = folder.trim().isEmpty
        ? (prefs.notesFolder.isEmpty ? 'generale' : prefs.notesFolder)
        : folder.trim();
    final fu = folderUri.isEmpty ? prefs.notesFolderUri : folderUri;

    final baseName =
        text.split('\n').first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    final n = Note(uid(), text, DateTime.now().millisecondsSinceEpoch, color,
        false, f, fu, uri, safeName.isEmpty ? 'nota.md' : '$safeName.md');

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
      if (!ok) {
        print('[saf] delete file failed: ${target.uri}');
      }
      return ok;
    }

    return true;
  }
}

final store = Store();

class Nav extends ChangeNotifier {
  int screen = 0, timeTab = 0;
  bool ready = false;
  Counter? editingCounter;
  Counter? viewingCounter;
  Note? editingNote;
  DateTime? editingNoteDate;

  final history = <List<int>>[];

  bool get canExit => history.isEmpty && screen == 0 && timeTab == 0;

  void readyUp() {
    ready = true;
    notifyListeners();
  }

  void go(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab) return;
    history.add([screen, timeTab]);
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void openCounterDetail(Counter counter) {
    history.add([screen, timeTab]);
    viewingCounter = counter;
    screen = 8;
    timeTab = 0;
    notifyListeners();
  }

  void openCounterEditor([Counter? counter]) {
    history.add([screen, timeTab]);
    editingCounter = counter;
    screen = 6;
    timeTab = 0;
    notifyListeners();
  }

  void openNoteEditor([Note? note, DateTime? date]) {
    history.add([screen, timeTab]);
    editingNote = note;
    editingNoteDate = date;
    screen = 7;
    timeTab = 0;
    notifyListeners();
  }

  void jump(int s, {int tab = 0}) {
    if (screen == s && timeTab == tab && history.isEmpty) return;
    history.clear();
    editingCounter = null;
    viewingCounter = null;
    editingNote = null;
    editingNoteDate = null;
    screen = s;
    timeTab = s == 2 ? tab : 0;
    notifyListeners();
  }

  void back() {
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

  void setTimeTab(int v) {
    if (timeTab == v) return;
    timeTab = v;
    notifyListeners();
  }
}

final nav = Nav();

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

class L {
  static String lang = 'it';
  static String t(String k) => (lang == 'en' ? en[k] : it[k]) ?? k;
}

class Pal {
  final bool dark;
  const Pal(this.dark);

  Pal get pal => this;

  Color get bg => dark ? const Color(0xFF0C0E11) : const Color(0xFFF6F7F9);
  Color get surface => dark ? const Color(0xFF15181D) : const Color(0xFFFFFFFF);
  Color get surface2 =>
      dark ? const Color(0xFF1E2228) : const Color(0xFFF0F2F4);
  Color get line => dark ? const Color(0xFF2B3138) : const Color(0xFFDDE2E7);
  Color get text => dark ? const Color(0xFFF2F4F6) : const Color(0xFF171A1E);
  Color get text2 => dark ? const Color(0xFFB6BDC7) : const Color(0xFF535D68);
  Color get sub => dark ? const Color(0xFF808995) : const Color(0xFF7B8692);
  Color get accent => dark ? const Color(0xFF8DA4FF) : const Color(0xFF4D68F6);
  Color get accentSoft =>
      dark ? const Color(0xFF232D55) : const Color(0xFFEEF1FF);
  Color get bad => dark ? const Color(0xFFFF7F7F) : const Color(0xFFC34A4A);
}

class ThemeScope extends InheritedWidget {
  final Pal pal;
  const ThemeScope({super.key, required this.pal, required super.child});

  static Pal of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeScope>()!.pal;

  @override
  bool updateShouldNotify(ThemeScope old) => old.pal.dark != pal.dark;
}

TextStyle title(Pal p, {double s = 27}) => TextStyle(
    color: p.text,
    fontSize: s,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5);

TextStyle body(Pal p, {double s = 14, FontWeight w = FontWeight.w400}) =>
    TextStyle(color: p.text2, fontSize: s, fontWeight: w, height: 1.4);

TextStyle cap(Pal p) =>
    TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w500);

BoxDecoration box(Pal p, {double r = 16}) => BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: p.line),
      boxShadow: p.dark
          ? null
          : const [
              BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 18,
                  offset: Offset(0, 7))
            ],
    );

class IconX extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const IconX(this.name, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext c) => CustomPaint(
        size: Size.square(size),
        painter: _Painter(name, color ?? ThemeScope.of(c).pal.text),
      );
}

class _Painter extends CustomPainter {
  final String n;
  final Color c;

  _Painter(this.n, this.c);

  @override
  void paint(Canvas g, Size s) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final f = Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    final w = s.width, h = s.height;

    void l(double x1, double y1, double x2, double y2) =>
        g.drawLine(Offset(x1, y1), Offset(x2, y2), p);

    switch (n) {
      case 'home':
        g.drawPath(
            Path()
              ..moveTo(w * .15, h * .48)
              ..lineTo(w * .5, h * .2)
              ..lineTo(w * .85, h * .48),
            p);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .25, h * .43, w * .75, h * .82, const Radius.circular(2)),
            p);
        break;
      case 'tag':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .26, w * .82, h * .74, const Radius.circular(3)),
            p);
        l(w * .32, h * .5, w * .68, h * .5);
        break;
      case 'clock':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        l(w / 2, h / 2, w / 2, h * .3);
        l(w / 2, h / 2, w * .65, h * .56);
        break;
      case 'note':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .23, h * .15, w * .77, h * .85, const Radius.circular(3)),
            p);
        l(w * .35, h * .38, w * .65, h * .38);
        l(w * .35, h * .53, w * .65, h * .53);
        l(w * .35, h * .68, w * .56, h * .68);
        break;
      case 'settings':
        l(w * .18, h * .3, w * .82, h * .3);
        l(w * .18, h * .5, w * .82, h * .5);
        l(w * .18, h * .7, w * .82, h * .7);
        g.drawCircle(Offset(w * .62, h * .3), w * .055, f);
        g.drawCircle(Offset(w * .38, h * .5), w * .055, f);
        g.drawCircle(Offset(w * .58, h * .7), w * .055, f);
        break;
      case 'info':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h * .36), w * .025, f);
        l(w / 2, h * .48, w / 2, h * .69);
        break;
      case 'plus':
        l(w * .5, h * .22, w * .5, h * .78);
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'minus':
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'x':
        l(w * .27, h * .27, w * .73, h * .73);
        l(w * .73, h * .27, w * .27, h * .73);
        break;
      case 'check':
        l(w * .2, h * .53, w * .42, h * .74);
        l(w * .42, h * .74, w * .82, h * .29);
        break;
      case 'left':
        l(w * .62, h * .25, w * .36, h * .5);
        l(w * .36, h * .5, w * .62, h * .75);
        break;
      case 'right':
        l(w * .38, h * .25, w * .64, h * .5);
        l(w * .64, h * .5, w * .38, h * .75);
        break;
      case 'folder':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .13, h * .3, w * .87, h * .78, const Radius.circular(2)),
            p);
        l(w * .14, h * .42, w * .43, h * .42);
        l(w * .43, h * .42, w * .49, h * .3);
        break;
      case 'pin':
        g.drawCircle(Offset(w * .5, h * .34), w * .14, p);
        l(w * .5, h * .48, w * .5, h * .82);
        break;
      case 'trash':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .28, h * .29, w * .72, h * .82, const Radius.circular(2)),
            p);
        l(w * .22, h * .25, w * .78, h * .25);
        l(w * .42, h * .18, w * .58, h * .18);
        l(w * .42, h * .18, w * .42, h * .25);
        l(w * .58, h * .18, w * .58, h * .25);
        break;
      case 'play':
        g.drawPath(
            Path()
              ..moveTo(w * .36, h * .25)
              ..lineTo(w * .74, h * .5)
              ..lineTo(w * .36, h * .75)
              ..close(),
            f);
        break;
      case 'pause':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .3, h * .25, w * .43, h * .75, const Radius.circular(1)),
            f);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .57, h * .25, w * .7, h * .75, const Radius.circular(1)),
            f);
        break;
      case 'refresh':
        g.drawArc(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * .3),
            -.8, 4.7, false, p);
        l(w * .75, h * .26, w * .75, h * .43);
        l(w * .75, h * .26, w * .58, h * .29);
        break;
      case 'bolt':
        g.drawPath(
            Path()
              ..moveTo(w * .57, h * .12)
              ..lineTo(w * .3, h * .54)
              ..lineTo(w * .48, h * .54)
              ..lineTo(w * .41, h * .88)
              ..lineTo(w * .71, h * .42)
              ..lineTo(w * .53, h * .42)
              ..close(),
            f);
        break;
      case 'target':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .20, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .06, f);
        l(w * .78, h * .22, w * .58, h * .42);
        break;
      case 'more':
        g.drawCircle(Offset(w * .25, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .75, h * .5), w * .07, f);
        break;
      case 'moreV':
        g.drawCircle(Offset(w * .5, h * .25), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .75), w * .07, f);
        break;
      case 'calendar':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .22, w * .82, h * .82, const Radius.circular(3)),
            p);
        l(w * .18, h * .38, w * .82, h * .38);
        l(w * .34, h * .14, w * .34, h * .30);
        l(w * .66, h * .14, w * .66, h * .30);
        break;
      case 'down':
        l(w * .5, h * .22, w * .5, h * .78);
        l(w * .3, h * .6, w * .5, h * .78);
        l(w * .7, h * .6, w * .5, h * .78);
        break;
      default:
        g.drawCircle(Offset(w / 2, h / 2), w * .25, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => old.n != n || old.c != c;
}

class Btn extends StatelessWidget {
  final Widget child;
  final VoidCallback? on;
  final bool filled;
  final EdgeInsets pad;
  final double radius;

  const Btn(
      {super.key,
      required this.child,
      this.on,
      this.filled = false,
      this.pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      this.radius = 10});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: on,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: filled ? p.accent : clear,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? on;
  final double size;

  const IconBtn({super.key, required this.icon, this.on, this.size = 19});

  @override
  Widget build(BuildContext c) => Btn(
        on: on,
        pad: const EdgeInsets.all(8),
        child: IconX(icon, size: size, color: ThemeScope.of(c).pal.text2),
      );
}

class Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String? hint;
  final String? label;
  final TextInputType? type;
  final int maxLines;

  const Field(
      {super.key,
      required this.ctrl,
      this.hint,
      this.label,
      this.type,
      this.maxLines = 1});

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  final FocusNode node = FocusNode();

  @override
  void initState() {
    super.initState();
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
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final active = node.hasFocus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
            color: active ? p.accent : p.line, width: active ? 1.2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.label != null) Text(widget.label!, style: cap(p)),
        if (widget.label != null) const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: Stack(children: [
            if (widget.ctrl.text.isEmpty && widget.hint != null)
              IgnorePointer(
                child: Text(widget.hint!, style: body(p)),
              ),
            EditableText(
              controller: widget.ctrl,
              focusNode: node,
              style: TextStyle(color: p.text, fontSize: 14),
              cursorColor: p.accent,
              backgroundCursorColor: p.sub,
              keyboardType: widget.type,
              maxLines: widget.maxLines,
              minLines: widget.maxLines > 1 ? widget.maxLines : null,
              enableInteractiveSelection: true,
            ),
          ]),
        ),
      ]),
    );
  }
}

class Progress extends StatelessWidget {
  final double value;
  const Progress({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final v = value.clamp(0.0, 1.0).toDouble();

    return Container(
      height: 6,
      decoration: BoxDecoration(
          color: p.surface2, borderRadius: BorderRadius.circular(99)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(99))),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String titleText;
  final String? sub;
  final bool back;
  final List<Widget> actions;

  const Header(
      {super.key,
      required this.titleText,
      this.sub,
      this.back = false,
      this.actions = const []});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
      child: Row(children: [
        if (back) IconBtn(icon: 'left', on: nav.back),
        if (back) const SizedBox(width: 7),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titleText, style: title(p)),
            if (sub != null)
              Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(sub!, style: cap(p))),
          ]),
        ),
        ...actions,
      ]),
    );
  }
}

class Section extends StatelessWidget {
  final String text;
  const Section(this.text, {super.key});

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: cap(ThemeScope.of(c).pal)
                .copyWith(fontSize: 10, letterSpacing: 1.2)),
      );
}

Future<T?> sheet<T>(BuildContext context, Widget child) {
  final pal = ThemeScope.of(context).pal;
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x88000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, animation, __) =>
        _Sheet(pal: pal, child: child, animation: animation),
  ));
}

class _Sheet extends StatelessWidget {
  final Pal pal;
  final Widget child;
  final Animation<double> animation;

  const _Sheet(
      {required this.pal, required this.child, required this.animation});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.line,
                        borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 14),
                ThemeScope(pal: p, child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(
    BuildContext context, String titleText, String message) async {
  final pal = ThemeScope.of(context).pal;
  final result = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      pageBuilder: (_, __, ___) => ThemeScope(
            pal: pal,
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _Confirm(
                        pal: pal, titleText: titleText, message: message))),
          )));
  return result ?? false;
}

class _Confirm extends StatelessWidget {
  final Pal pal;
  final String titleText;
  final String message;

  const _Confirm(
      {required this.pal, required this.titleText, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(22),
      decoration: box(p, r: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleText, style: title(p, s: 19)),
          const SizedBox(height: 8),
          Text(message, style: body(p)),
          const SizedBox(height: 19),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Btn(
                on: () => Navigator.pop(context, false),
                child: Text(L.t('cancel'), style: body(p, w: FontWeight.w600))),
            const SizedBox(width: 7),
            Btn(
                filled: true,
                on: () => Navigator.pop(context, true),
                child: const Text('OK',
                    style:
                        TextStyle(color: white, fontWeight: FontWeight.w700))),
          ]),
        ],
      ),
    );
  }
}

const navItems = [
  ['home', 'home'],
  ['tag', 'counters'],
  ['clock', 'time'],
  ['note', 'notes']
];

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: nav,
      builder: (_, __) {
        final p = ThemeScope.of(c).pal;
        final wide = MediaQuery.sizeOf(c).width >= 840;

        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
              key: ValueKey('${nav.screen}-${nav.timeTab}'), child: child),
        );

        if (wide)
          return Row(children: [
            const _Rail(),
            Container(width: 1, color: p.line),
            Expanded(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: SizedBox(width: double.infinity, child: body)))),
          ]);

        return Column(children: [Expanded(child: body), const _Bottom()]);
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Container(
      width: 224,
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 10, 20),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Center(child: IconX('bolt', size: 18, color: p.accent))),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('OpenFocusly',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800))),
            ])),
        for (final item in navItems) ...[
          _NavItem(item[0], item[1]),
          const SizedBox(height: 4)
        ],
        const Spacer(),
        Container(height: 1, color: p.line),
        const SizedBox(height: 8),
        _NavItem('settings', 'settings'),
        const SizedBox(height: 4),
        _NavItem('info', 'info'),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  const _NavItem(this.icon, this.label);

  int get screen => label == 'home'
      ? 0
      : label == 'counters'
          ? 1
          : label == 'time'
              ? 2
              : label == 'notes'
                  ? 3
                  : label == 'settings'
                      ? 4
                      : 5;

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final active = nav.screen == screen;

    return Btn(
      on: () {
        store.vib();
        nav.jump(screen);
      },
      pad: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      child: Row(children: [
        IconX(icon, size: 18, color: active ? p.accent : p.text2),
        const SizedBox(width: 11),
        Expanded(
            child: Text(L.t(label),
                style: TextStyle(
                    color: active ? p.accent : p.text2,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
      ]),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom();

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: nav,
      builder: (_, __) {
        final items = [
          ...navItems,
          ['settings', 'settings']
        ];
        final p = ThemeScope.of(c).pal;
        final editorOpen = nav.screen == 6 || nav.screen == 7;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
              color: p.surface, border: Border(top: BorderSide(color: p.line))),
          padding: EdgeInsets.fromLTRB(5, editorOpen ? 3 : 5, 5, 5),
          child: SafeArea(
              top: false,
              child: Row(children: [
                for (final item in items)
                  Expanded(child: _BottomItem(item[0], item[1])),
              ])),
        );
      },
    );
  }
}

class _BottomItem extends StatelessWidget {
  final String icon, label;
  const _BottomItem(this.icon, this.label);

  int get screen => label == 'home'
      ? 0
      : label == 'counters'
          ? 1
          : label == 'time'
              ? 2
              : label == 'notes'
                  ? 3
                  : 4;

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    final active = nav.screen == screen;

    return Btn(
      on: () {
        store.vib();
        nav.jump(screen);
      },
      pad: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: active ? p.accentSoft : clear,
              borderRadius: BorderRadius.circular(99)),
          child: IconX(icon, size: 18, color: active ? p.accent : p.sub),
        ),
        const SizedBox(height: 2),
        Text(L.t(label),
            style: TextStyle(
                color: active ? p.accent : p.sub,
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? L.t('morning')
        : hour < 18
            ? L.t('afternoon')
            : L.t('evening');

    final total = store.total();
    final notes = store.allNotes().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(greeting, style: cap(p)),
                              const SizedBox(height: 3),
                              Text('OpenFocusly', style: title(p, s: 31)),
                              const SizedBox(height: 4),
                              Text(L.t('tagline'), style: body(p)),
                            ])),
                        IconBtn(icon: 'settings', on: () => nav.go(4)),
                      ]),
                      const SizedBox(height: 28),
                      Section(L.t('overview')),
                      LayoutBuilder(builder: (_, constraints) {
                        final w = constraints.maxWidth;
                        final two = w >= 430;
                        final tile = two ? (w - 10) / 2 : w;

                        return Wrap(spacing: 10, runSpacing: 10, children: [
                          SizedBox(
                              width: tile,
                              child: _Metric(
                                  'tag',
                                  L.t('counters'),
                                  '${store.counters.length}',
                                  '${fmt(total)} ${L.t('total')}',
                                  () => nav.go(1))),
                          SizedBox(
                              width: tile,
                              child: _Metric(
                                  'clock',
                                  L.t('focus'),
                                  '25:00',
                                  L.t('readyToBegin'),
                                  () => nav.go(2, tab: 1))),
                          SizedBox(
                              width: two ? w : tile,
                              child: _Metric('note', L.t('notes'), '$notes',
                                  L.t('notesEvents'), () => nav.go(3))),
                        ]);
                      }),
                      const SizedBox(height: 24),
                      Section(L.t('focus')),
                      const _FocusTile(),
                      const SizedBox(height: 24),
                      Section(L.t('quickActions')),
                      _Quick(
                          icon: 'tag',
                          titleText: L.t('counters'),
                          sub: L.t('quickCountersSub'),
                          on: () => nav.go(1)),
                      const SizedBox(height: 9),
                      _Quick(
                          icon: 'clock',
                          titleText: L.t('calendar'),
                          sub: L.t('quickCalendarSub'),
                          on: () => nav.go(2, tab: 0)),
                      const SizedBox(height: 9),
                      _Quick(
                          icon: 'note',
                          titleText: L.t('notes'),
                          sub: L.t('quickNotesSub'),
                          on: () => nav.go(3)),
                    ]))),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String icon, titleText, value, sub;
  final VoidCallback on;

  const _Metric(this.icon, this.titleText, this.value, this.sub, this.on);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: on,
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(18),
            decoration: box(p),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(child: IconX(icon, size: 17, color: p.accent))),
              const SizedBox(height: 15),
              Text(value,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8)),
              const SizedBox(height: 4),
              Text(titleText,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(sub, style: cap(p)),
            ])));
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile();

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: () => nav.go(2, tab: 1),
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(17),
            decoration: box(p),
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(14)),
                  child:
                      Center(child: IconX('play', size: 20, color: p.accent))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(L.t('focusSession'),
                        style: TextStyle(
                            color: p.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(L.t('focusSessionSub'), style: cap(p)),
                  ])),
              Text('25:00',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ])));
  }
}

class _Quick extends StatelessWidget {
  final String icon, titleText, sub;
  final VoidCallback on;

  const _Quick(
      {required this.icon,
      required this.titleText,
      required this.sub,
      required this.on});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: on,
        pad: EdgeInsets.zero,
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: box(p, r: 14),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: IconX(icon, size: 17, color: p.text2))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(titleText,
                        style: TextStyle(
                            color: p.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: cap(p)),
                  ])),
              IconX('right', size: 16, color: p.sub),
            ])));
  }
}

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

  const _CounterCard(
      {required this.counter,
      required this.progress,
      required this.onTap,
      required this.onMinus,
      required this.onPlus,
      required this.onReset});

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
                        color: p.sub,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ]))),
      )
    ]);
  }
}

class _CounterButton extends StatelessWidget {
  final String icon;
  final String? label;
  final bool primary;
  final VoidCallback onTap;

  const _CounterButton(
      {required this.icon,
      required this.onTap,
      this.label,
      this.primary = false});

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

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('selectFolder'), style: title(p, s: 20)),
          const SizedBox(height: 12),
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

class TimeScreen extends StatefulWidget {
  const TimeScreen({super.key});

  @override
  State<TimeScreen> createState() => _TimeState();
}

class _TimeState extends State<TimeScreen> {
  int duration = 25 * 60;
  double remainMs = 25 * 60 * 1000.0;
  bool running = false;
  int? endAt;
  Timer? timer;

  DateTime selected = DateTime.now();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  final TextEditingController q = TextEditingController();

  @override
  void initState() {
    super.initState();
    q.addListener(_queryChanged);
  }

  void _queryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    q.removeListener(_queryChanged);
    q.dispose();
    super.dispose();
  }

  void setTab(int tab) {
    store.vib();
    nav.setTimeTab(tab);
  }

  void setDur(int seconds) {
    final next = seconds.clamp(0, 3600 * 24).toInt();
    setState(() {
      duration = next;
      if (!running) remainMs = duration * 1000.0;
    });
  }

  void toggle() {
    store.vib();

    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }

    if (remainMs <= 0) remainMs = duration * 1000.0;

    endAt = DateTime.now().millisecondsSinceEpoch + remainMs.round();
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 16), (_) => tick());

    setState(() => running = true);
  }

  void tick() {
    if (!mounted || !running || endAt == null) return;

    final msLeft = (endAt! - DateTime.now().millisecondsSinceEpoch).toDouble();

    if (msLeft <= 0) {
      timer?.cancel();
      setState(() {
        running = false;
        remainMs = duration * 1000.0;
        endAt = null;
      });

      store.vib();
      store.addNote(dayKey(DateTime.now()), 'Focus session completed.', 0,
          folder: store.prefs.notesFolder.isEmpty
              ? 'generale'
              : store.prefs.notesFolder);
      return;
    }

    setState(() => remainMs = msLeft);
  }

  String time(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final focus = nav.timeTab == 1;
    final p = ThemeScope.of(context).pal;

    return Column(children: [
      Header(
          titleText: focus ? L.t('focus') : L.t('calendar'),
          sub: focus ? L.t('focusSessionSub') : L.t('notesEvents'),
          back: true,
          actions: [IconBtn(icon: 'settings', on: () => nav.go(4))]),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 9),
          child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: p.surface2, borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                Expanded(
                    child: _Tab(
                        text: L.t('calendar'),
                        active: !focus,
                        on: () => setTab(0))),
                Expanded(
                    child: _Tab(
                        text: L.t('focus'),
                        active: focus,
                        on: () => setTab(1))),
              ]))),
      Expanded(
          child: focus
              ? _Focus(
                  remainMs: remainMs,
                  durationMs: duration * 1000.0,
                  running: running,
                  time: time,
                  toggle: toggle,
                  setDur: setDur,
                  reset: () {
                    store.vib();
                    timer?.cancel();
                    setState(() {
                      running = false;
                      endAt = null;
                      remainMs = duration * 1000.0;
                    });
                  })
              : _Calendar(
                  selected: selected,
                  month: month,
                  q: q,
                  onDay: (day) => setState(() => selected = day),
                  onMonth: (value) => setState(() => month = value))),
    ]);
  }
}

class _Tab extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback on;

  const _Tab({required this.text, required this.active, required this.on});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Btn(
        on: on,
        pad: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
                color: active ? p.surface : clear,
                borderRadius: BorderRadius.circular(9)),
            child: Center(
                child: Text(text,
                    style: TextStyle(
                        color: active ? p.text : p.sub,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12)))));
  }
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

class _Focus extends StatelessWidget {
  final double remainMs;
  final double durationMs;
  final bool running;
  final String Function(int) time;
  final VoidCallback toggle, reset;
  final ValueChanged<int> setDur;

  const _Focus(
      {required this.remainMs,
      required this.durationMs,
      required this.running,
      required this.time,
      required this.toggle,
      required this.setDur,
      required this.reset});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final ratio = durationMs <= 0
        ? 0.0
        : (remainMs / durationMs).clamp(0.0, 1.0).toDouble();
    final secondsLeft = (remainMs / 1000).ceil();
    final durationSec = (durationMs / 1000).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    decoration: box(p, r: 20),
                    child: Column(children: [
                      SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(alignment: Alignment.center, children: [
                            CustomPaint(
                                size: const Size.square(220),
                                painter: _Ring(p, ratio)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(time(secondsLeft),
                                  style: TextStyle(
                                      color: p.text,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.5)),
                              const SizedBox(height: 3),
                              Text(running ? L.t('running') : L.t('ready'),
                                  style: cap(p)),
                            ]),
                          ])),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TimeWheel(
                            value: (durationSec ~/ 3600).clamp(0, 23),
                            max: 23,
                            label: 'h',
                            onChanged: (v) => setDur(v * 3600 +
                                ((durationSec % 3600) ~/ 60) * 60 +
                                (durationSec % 60)),
                          ),
                          const SizedBox(width: 10),
                          TimeWheel(
                            value: ((durationSec % 3600) ~/ 60).clamp(0, 59),
                            max: 59,
                            label: 'min',
                            onChanged: (v) => setDur(
                                (durationSec ~/ 3600) * 3600 +
                                    v * 60 +
                                    (durationSec % 60)),
                          ),
                          const SizedBox(width: 10),
                          TimeWheel(
                            value: (durationSec % 60).clamp(0, 59),
                            max: 59,
                            label: 'sec',
                            onChanged: (v) =>
                                setDur((durationSec ~/ 60) * 60 + v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: Btn(
                                on: toggle,
                                filled: !running,
                                pad: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconX(running ? 'pause' : 'play',
                                          size: 18,
                                          color: running ? p.text : white),
                                      const SizedBox(width: 6),
                                      Text(
                                          running ? L.t('pause') : L.t('start'),
                                          style: TextStyle(
                                              color: running ? p.text : white,
                                              fontWeight: FontWeight.w800)),
                                    ]))),
                        const SizedBox(width: 8),
                        IconBtn(icon: 'refresh', on: reset),
                      ]),
                    ])))),
      ],
    );
  }
}

class _Ring extends CustomPainter {
  final Pal p;
  final double ratio;

  _Ring(this.p, this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = p.surface2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        Paint()
          ..color = p.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _Ring old) =>
      old.ratio != ratio || old.p.dark != p.dark;
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

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NoteTile(
      {super.key, required this.note, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final name = trimNoteName(note.name, max: 54);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.line)),
        child: Row(children: [
          Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                  color: noteColor(note.color),
                  borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(name.isEmpty ? L.t('untitled') : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.15))),
          if (note.pinned)
            Padding(
                padding: const EdgeInsets.only(left: 6),
                child: IconX('pin', size: 12, color: p.accent)),
        ]),
      ),
    );
  }
}

class _Calendar extends StatefulWidget {
  final DateTime selected, month;
  final TextEditingController q;
  final ValueChanged<DateTime> onDay, onMonth;

  const _Calendar(
      {required this.selected,
      required this.month,
      required this.q,
      required this.onDay,
      required this.onMonth});

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        final p = ThemeScope.of(context).pal;

        final first = DateTime(widget.month.year, widget.month.month, 1);
        final offset = first.weekday - 1;
        final days = DateTime(widget.month.year, widget.month.month + 1, 0).day;

        final monthsRaw = L.t('monthsShort');
        final months = monthsRaw.contains(',')
            ? monthsRaw.split(',')
            : [
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
                'Dec'
              ];

        final weekdaysRaw = L.t('weekdays');
        final weekdays = weekdaysRaw.contains(',')
            ? weekdaysRaw.split(',')
            : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

        final entries = store.notes[dayKey(widget.selected)] ?? <Note>[];
        final query = widget.q.text.trim().toLowerCase();

        final results = store
            .allNotes()
            .where((note) =>
                query.isEmpty ||
                note.text.toLowerCase().contains(query) ||
                fmtTs(note.ts).toLowerCase().contains(query))
            .toList();

        final list = query.isEmpty ? entries : results;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(children: [
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: box(p, r: 18),
                          child: Column(children: [
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      '${months[widget.month.month - 1]} ${widget.month.year}',
                                      style: TextStyle(
                                          color: p.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800))),
                              IconBtn(
                                  icon: 'left',
                                  on: () => widget.onMonth(DateTime(
                                      widget.month.year,
                                      widget.month.month - 1))),
                              IconBtn(
                                  icon: 'right',
                                  on: () => widget.onMonth(DateTime(
                                      widget.month.year,
                                      widget.month.month + 1))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              for (final d in weekdays)
                                Expanded(
                                    child:
                                        Center(child: Text(d, style: cap(p))))
                            ]),
                            const SizedBox(height: 5),
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.15,
                              children:
                                  List<Widget>.generate(offset + days, (index) {
                                if (index < offset) return const SizedBox();
                                final day = index - offset + 1;
                                final date = DateTime(
                                    widget.month.year, widget.month.month, day);
                                final key = dayKey(date);
                                final hasNote =
                                    (store.notes[key] ?? <Note>[]).isNotEmpty;

                                return _Day(
                                    d: day,
                                    selected: key == dayKey(widget.selected),
                                    today: key == dayKey(DateTime.now()),
                                    hasNote: hasNote,
                                    on: () => widget.onDay(date));
                              }),
                            ),
                          ])),
                      const SizedBox(height: 11),
                      Field(ctrl: widget.q, hint: L.t('searchNotesEvents')),
                      const SizedBox(height: 11),
                      Container(
                          padding: const EdgeInsets.all(15),
                          decoration: box(p, r: 15),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          query.isEmpty
                                              ? '${widget.selected.day} ${months[widget.selected.month - 1]}'
                                              : L.t('searchResults'),
                                          style: TextStyle(
                                              color: p.text,
                                              fontWeight: FontWeight.w800))),
                                  IconBtn(
                                      icon: 'plus',
                                      on: () {
                                        if (store.prefs.notesFolderUri.isEmpty)
                                          nav.openNoteEditor(
                                              null, widget.selected);
                                        else
                                          showNoteEditor(context, null,
                                              date: widget.selected);
                                      }),
                                ]),
                                const SizedBox(height: 10),
                                if (list.isEmpty)
                                  Text(L.t('nothingPlanned'), style: cap(p)),
                                for (final note in list)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Container(
                                          decoration: BoxDecoration(
                                            color: p.surface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: Dismissible(
                                            key: ValueKey('note-${note.id}'),
                                            direction:
                                                DismissDirection.horizontal,
                                            confirmDismiss: (direction) async {
                                              if (direction ==
                                                  DismissDirection.startToEnd) {
                                                note.pinned = !note.pinned;
                                                store.touch();
                                                return false;
                                              }
                                              if (!await confirm(
                                                  context,
                                                  L.t('delete'),
                                                  note.name)) return false;
                                              return true;
                                            },
                                            onDismissed: (_) =>
                                                store.deleteNoteById(note.id,
                                                    deleteFile: true),
                                            background: Container(
                                              color: p.accentSoft,
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.only(
                                                  left: 18),
                                              child: Row(children: [
                                                IconX('pin',
                                                    size: 16, color: p.accent),
                                                const SizedBox(width: 7),
                                                Text(L.t('pin'),
                                                    style: TextStyle(
                                                        color: p.accent,
                                                        fontWeight:
                                                            FontWeight.w800)),
                                              ]),
                                            ),
                                            secondaryBackground: Container(
                                              color:
                                                  p.bad.withValues(alpha: .12),
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(
                                                  right: 18),
                                              child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    IconX('trash',
                                                        size: 16, color: p.bad),
                                                    const SizedBox(width: 7),
                                                    Text(L.t('delete'),
                                                        style: TextStyle(
                                                            color: p.bad,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                                  ]),
                                            ),
                                            child: NoteTile(
                                                note: note,
                                                onTap: () => showNoteEditor(
                                                    context, note),
                                                onLongPress: () => showNoteMenu(
                                                    context, note)),
                                          ))),
                              ])),
                    ]))),
          ],
        );
      },
    );
  }
}

class _Day extends StatelessWidget {
  final int d;
  final bool selected, today, hasNote;
  final VoidCallback on;

  const _Day(
      {required this.d,
      required this.selected,
      required this.today,
      required this.hasNote,
      required this.on});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Btn(
        on: on,
        pad: EdgeInsets.zero,
        child: Center(
            child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: selected ? p.accent : clear,
                    shape: BoxShape.circle,
                    border: today && !selected
                        ? Border.all(color: p.accent)
                        : null),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$d',
                          style: TextStyle(
                              color: selected ? white : p.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      if (hasNote)
                        Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                                color: selected ? white : p.accent,
                                shape: BoxShape.circle)),
                    ]))));
  }
}

class _SwipeNoteBg extends StatelessWidget {
  final String icon, label;
  final Alignment alignment;
  final bool danger;

  const _SwipeNoteBg(
      {required this.icon,
      required this.label,
      required this.alignment,
      this.danger = false});

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
          color: danger ? p.bad.withValues(alpha: .12) : p.accentSoft,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconX(icon, size: 16, color: danger ? p.bad : p.accent),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                color: danger ? p.bad : p.accent, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

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
  return true;
}

Future<void> showNoteEditor(BuildContext context, Note? note,
    {DateTime? date}) async {
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

  @override
  void initState() {
    super.initState();
    folder = store.prefs.notesFolder;
    q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> chooseFolder() async {
    try {
      final result = await store.pickNotesFolder();
      if (result == null) return;

      final name = (result['name'] as String? ?? '').trim();
      final uri = (result['uri'] as String? ?? '').trim();

      if (name.isEmpty || uri.isEmpty) return;

      setState(() => folder = name);
      store.prefs.notesFolder = name;
      store.prefs.notesFolderUri = uri;

      await store.syncNotesFolder(name, uri);
      store.touch();
    } on PlatformException catch (e) {
      if (!mounted) return;
      await sheet<void>(
          context,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L.t('folder'),
                style: title(ThemeScope.of(context).pal, s: 19)),
            const SizedBox(height: 8),
            Text(e.message ?? 'error', style: body(ThemeScope.of(context).pal)),
            const SizedBox(height: 14),
            Btn(
                filled: true,
                on: () => Navigator.pop(context),
                child: const Text('ok',
                    style:
                        TextStyle(color: white, fontWeight: FontWeight.w800))),
          ]));
    }
  }

  Future<void> ensureFolderAndCreate() async {
    if (store.prefs.notesFolderUri.trim().isEmpty) {
      await chooseFolder();
      if (store.prefs.notesFolderUri.trim().isEmpty) return;
    }
    folder = store.prefs.notesFolder;
    nav.openNoteEditor(null, DateTime.now());
  }

  Future<void> exportMarkdown() async {
    final lines = <String>[];

    for (final note in store.allNotes(folder.isEmpty ? null : folder)) {
      lines.add('---');
      lines.add('title: "${note.name.replaceAll('"', '\\"')}"');
      lines.add('folder: "${note.folder.replaceAll('"', '\\"')}"');
      lines.add('pinned: ${note.pinned}');
      lines.add('---');
      lines.add(note.text);
      lines.add('');
    }

    try {
      final uri = await Store.channel.invokeMethod<String>(
          'create', {'name': 'notes.md', 'mime': 'text/markdown'});
      if (uri == null) return;

      await Store.channel.invokeMethod('write', {
        'uri': uri,
        'bytes': Uint8List.fromList(utf8.encode(lines.join('\n')))
      });
    } catch (_) {}
  }

  Future<void> importMarkdown() async {
    try {
      final uri = await Store.channel
          .invokeMethod<String>('open', {'mime': 'text/markdown'});
      if (uri == null) return;

      final bytes =
          await Store.channel.invokeMethod<Uint8List>('read', {'uri': uri});
      if (bytes == null) return;

      final raw = utf8.decode(bytes);
      final blocks = raw.split(RegExp(r'^---\s*$', multiLine: true));

      for (final block in blocks) {
        final text = block.trim();
        if (text.isEmpty) continue;

        final bodyLines = text.split('\n');
        final divider = bodyLines.indexWhere((e) => e.trim() == '---');

        String noteText = text;
        String f = folder.isEmpty ? 'generale' : folder;
        bool pinned = false;

        if (divider >= 0) {
          final meta = bodyLines.take(divider);
          for (final line in meta) {
            if (line.startsWith('folder:'))
              f = line.substring(7).trim().replaceAll('"', '');
            if (line.startsWith('pinned:'))
              pinned = line.substring(7).trim() == 'true';
          }
          noteText = bodyLines.skip(divider + 1).join('\n').trim();
        }

        store.addNote(dayKey(DateTime.now()), noteText, 0, folder: f);

        final imported = store.allNotes(f);
        if (imported.isNotEmpty) imported.first.pinned = pinned;
      }

      store.touch();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        final query = q.text.trim().toLowerCase();
        final all = store.allNotes(folder.isEmpty ? null : folder);
        final filtered = all
            .where((n) => query.isEmpty || n.name.toLowerCase().contains(query))
            .toList();

        return Column(children: [
          Header(
              titleText: folder.isEmpty ? L.t('notes') : folder,
              sub: '${filtered.length} ${L.t('notes').toLowerCase()}',
              back: true,
              actions: [
                IconBtn(icon: 'folder', on: chooseFolder),
                IconBtn(icon: 'plus', on: ensureFolderAndCreate),
                Btn(
                    on: () => sheet<void>(
                        context,
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L.t('notes'), style: title(p, s: 19)),
                              const SizedBox(height: 10),
                              _MenuAction(
                                  icon: 'folder',
                                  label: L.t('changeFolder'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    chooseFolder();
                                  }),
                              _MenuAction(
                                  icon: 'right',
                                  label: L.t('exportMarkdown'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    exportMarkdown();
                                  }),
                              _MenuAction(
                                  icon: 'left',
                                  label: L.t('importMarkdown'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    importMarkdown();
                                  }),
                            ])),
                    pad: const EdgeInsets.all(8),
                    child: IconX('more', size: 19, color: p.text2)),
              ]),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Field(ctrl: q, hint: L.t('search'))),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconX('folder', size: 28, color: p.sub),
                    const SizedBox(height: 12),
                    Text(
                        store.prefs.notesFolderUri.isEmpty
                            ? L.t('selectFolderToStart')
                            : L.t('noNotes'),
                        style: cap(p),
                        textAlign: TextAlign.center),
                    if (store.prefs.notesFolderUri.isEmpty) ...[
                      const SizedBox(height: 14),
                      Btn(
                          filled: true,
                          on: chooseFolder,
                          pad: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Text(L.t('selectFolder'),
                              style: const TextStyle(
                                  color: white, fontWeight: FontWeight.w800))),
                    ],
                  ]))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.5),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final note = filtered[i];

                      return Dismissible(
                        key: ValueKey('notes-${note.id}'),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            note.pinned = !note.pinned;
                            store.touch();
                            return false;
                          }
                          return await confirm(
                              context, L.t('delete'), note.name);
                        },
                        onDismissed: (_) =>
                            store.deleteNoteById(note.id, deleteFile: true),
                        background: _SwipeNoteBg(
                            icon: 'pin',
                            label: note.pinned ? L.t('unpin') : L.t('pin'),
                            alignment: Alignment.centerLeft),
                        secondaryBackground: _SwipeNoteBg(
                            icon: 'trash',
                            label: L.t('delete'),
                            alignment: Alignment.centerRight,
                            danger: true),
                        child: NoteTile(
                            note: note,
                            onTap: () => showNoteEditor(context, note),
                            onLongPress: () => showNoteMenu(context, note)),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

class _MenuAction extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;

  const _MenuAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});

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

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final DateTime? initialDate;

  const NoteEditorScreen({super.key, this.note, this.initialDate});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditorScreen> {
  final liveKey = GlobalKey<NoteLiveEditorState>();
  late final TextEditingController titleCtrl;
  late String folder;
  late DateTime targetDate;
  int color = 0;
  Timer? saveTimer;
  bool preview = false;
  bool readOnly = false;
  final titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    final parts = widget.note?.text.replaceAll('\r\n', '\n').split('\n') ??
        const <String>[];

    titleCtrl = TextEditingController(
        text: parts.isEmpty
            ? ''
            : parts.first.trim().replaceFirst(RegExp(r'^#+\s*'), ''));
    titleCtrl.addListener(_scheduleAutosave);

    folder = widget.note?.folder ?? store.prefs.notesFolder;
    targetDate = widget.initialDate ??
        (widget.note == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(widget.note!.ts));
    color = widget.note?.color ?? 0;
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    titleCtrl.removeListener(_scheduleAutosave);
    titleFocus.dispose();
    titleCtrl.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    if (widget.note == null) return;
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) _saveCurrent();
    });
  }

  String _body() =>
      liveKey.currentState?.text ??
      (widget.note?.text.split('\n').skip(1).join('\n') ?? '');

  String _buildText() {
    final heading = titleCtrl.text.trim();
    final body = _body().trimRight();
    return body.isEmpty ? heading : '$heading\n$body';
  }

  Future<void> _saveCurrent() async {
    final heading = titleCtrl.text.trim();
    if (heading.isEmpty) return;

    if (store.prefs.notesFolderUri.trim().isEmpty) {
      await pickFolder();
      if (store.prefs.notesFolderUri.trim().isEmpty) return;
    }

    if (folder.trim().isEmpty) folder = store.prefs.notesFolder;

    final text = _buildText();
    final safeBase = heading.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = '${safeBase.isEmpty ? 'nota' : safeBase}.md';

    if (widget.note == null) {
      final uri = await store.writeNoteFile(
          treeUri: store.prefs.notesFolderUri,
          fileName: fileName,
          content: text);

      final n = store.addNote(dayKey(targetDate), text, color,
          folder: store.prefs.notesFolder,
          folderUri: store.prefs.notesFolderUri,
          uri: uri ?? '');

      n.pinned = false;
      n.fileName = fileName;
      store.touch();
    } else {
      final n = widget.note!;

      final uri = await store.writeNoteFile(
          treeUri: store.prefs.notesFolderUri,
          fileName: fileName,
          content: text,
          existingUri: n.uri.isEmpty ? null : n.uri);

      n.uri = uri ?? n.uri;
      n.fileName = fileName;
      n.folder = store.prefs.notesFolder;
      n.folderUri = store.prefs.notesFolderUri;

      store.editNote(dayKey(targetDate), n, text, color, folder: n.folder);
    }
  }

  Future<void> closeEditor() async {
    saveTimer?.cancel();
    await _saveCurrent();
    nav.back();
  }

  Future<void> pickFolder() async {
    try {
      final result = await store.pickNotesFolder();
      if (result == null) return;

      final name = (result['name'] as String? ?? '').trim();
      final uri = (result['uri'] as String? ?? '').trim();

      if (name.isEmpty || uri.isEmpty) return;

      setState(() => folder = name);
      store.prefs.notesFolder = name;
      store.prefs.notesFolderUri = uri;
      _scheduleAutosave();
    } on PlatformException catch (e) {
      if (!mounted) return;
      print('pickDirectory failed: ${e.code}: ${e.message}');
    }
  }

  Future<void> remove() async {
    final n = widget.note;
    if (n == null) return;
    if (!await confirm(context, L.t('delete'), n.name)) return;
    await store.deleteNoteById(n.id, deleteFile: true);
    nav.back();
  }

  Future<void> options() async {
    final p = ThemeScope.of(context).pal;

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('noteOptions'), style: title(p, s: 20)),
          const SizedBox(height: 10),
          _MenuAction(
              icon: 'pin',
              label: widget.note?.pinned == true ? L.t('unpin') : L.t('pin'),
              onTap: () {
                if (widget.note != null) {
                  widget.note!.pinned = !widget.note!.pinned;
                  store.touch();
                }
                Navigator.pop(context);
              }),
          _MenuAction(
              icon: 'folder',
              label: '${L.t('folder')}: ${folder.isEmpty ? '—' : folder}',
              onTap: () {
                Navigator.pop(context);
                pickFolder();
              }),
          _MenuAction(
              icon: 'info',
              label: L.t('properties'),
              onTap: () {
                Navigator.pop(context);
                if (widget.note != null) showProperties(widget.note!);
              }),
          _MenuAction(
              icon: 'note',
              label: preview ? L.t('editor') : L.t('preview'),
              onTap: () {
                Navigator.pop(context);
                setState(() => preview = !preview);
              }),
          if (widget.note != null)
            _MenuAction(
                icon: 'trash',
                label: L.t('delete'),
                danger: true,
                onTap: () {
                  Navigator.pop(context);
                  remove();
                }),
        ]));
  }

  Future<void> showProperties(Note n) async {
    final p = ThemeScope.of(context).pal;
    final name = n.name.isEmpty ? L.t('untitled') : n.name;
    final info = n.uri.isNotEmpty ? await store.noteFileInfo(n.uri) : null;

    final bytes =
        (info?['size'] as num?)?.toInt() ?? utf8.encode(n.text).length;
    final safeFolder = n.folder.trim().isEmpty ? '—' : n.folder.trim();
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '$safeFolder/$safeName.md';
    final safUri = n.uri.isEmpty ? (info?['uri'] as String? ?? '') : n.uri;

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('properties'), style: title(p, s: 20)),
          const SizedBox(height: 14),
          _PropertyRow(L.t('name'), name),
          _PropertyRow(L.t('folder'), safeFolder),
          _PropertyRow(L.t('size'), _formatBytes(bytes)),
          _PropertyRow(L.t('path'), path),
          if (safUri.isNotEmpty) _PropertyRow('uri saf', safUri),
          _PropertyRow(L.t('modified'), fmtTs(n.ts)),
          const SizedBox(height: 10),
          Btn(
              filled: true,
              on: () => Navigator.pop(context),
              child: Text(L.t('close'),
                  style: const TextStyle(
                      color: white, fontWeight: FontWeight.w800))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final initial = widget.note?.text.split('\n').skip(1).join('\n') ?? '';

    return Column(children: [
      Container(
          height: 48,
          decoration: BoxDecoration(
              color: p.bg, border: Border(bottom: BorderSide(color: p.line))),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            IconBtn(icon: 'left', on: closeEditor, size: 20),
            Expanded(
                child: EditableText(
                    controller: titleCtrl,
                    focusNode: titleFocus,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                    cursorColor: p.accent,
                    backgroundCursorColor: p.sub,
                    maxLines: 1)),
            IconBtn(
                icon: 'note',
                on: () => setState(() => readOnly = !readOnly),
                size: 18),
            IconBtn(icon: 'moreV', on: options, size: 19),
          ])),
      Expanded(
          child: preview
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 20),
                  child: MarkdownPreview(source: _body()))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
                  child: NoteLiveEditor(
                      key: liveKey,
                      initial: initial,
                      readOnly: readOnly,
                      onSave: (_) => _scheduleAutosave()))),
    ]);
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _PropertyRow extends StatelessWidget {
  final String label, value;
  const _PropertyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: cap(p).copyWith(fontSize: 10, letterSpacing: 1.1)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(color: p.text, fontSize: 13, height: 1.35)),
      ]),
    );
  }
}

Future<void> showNoteMenu(BuildContext context, Note n) async {
  await sheet<void>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trimNoteName(n.name, max: 38),
            style: title(ThemeScope.of(context).pal, s: 19)),
        const SizedBox(height: 10),
        _MenuAction(
            icon: 'pin',
            label: n.pinned ? L.t('unpin') : L.t('pin'),
            onTap: () {
              n.pinned = !n.pinned;
              store.touch();
              Navigator.pop(context);
            }),
        _MenuAction(
            icon: 'note',
            label: L.t('open'),
            onTap: () {
              Navigator.pop(context);
              showNoteEditor(context, n);
            }),
        _MenuAction(
            icon: 'info',
            label: L.t('properties'),
            onTap: () {
              Navigator.pop(context);
              showNoteProperties(context, n);
            }),
        _MenuAction(
            icon: 'trash',
            label: L.t('delete'),
            danger: true,
            onTap: () async {
              Navigator.pop(context);
              if (await confirm(context, L.t('delete'), n.name))
                store.deleteNoteById(n.id, deleteFile: true);
            }),
      ]));
}

Future<void> showNoteProperties(BuildContext context, Note n) async {
  final p = ThemeScope.of(context).pal;
  final name = n.name.isEmpty ? L.t('untitled') : n.name;
  final bytes = utf8.encode(n.text).length;
  final safeFolder = n.folder.trim().isEmpty ? 'generale' : n.folder.trim();
  final path = n.uri.isNotEmpty
      ? n.uri
      : '${n.folderUri.isNotEmpty ? n.folderUri : safeFolder}/${n.fileName.isNotEmpty ? n.fileName : '$name.md'}';

  await sheet<void>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L.t('properties'), style: title(p, s: 20)),
        const SizedBox(height: 14),
        _PropertyRow(L.t('name'), name),
        _PropertyRow(L.t('folder'), safeFolder),
        _PropertyRow(L.t('size'), _formatBytes(bytes)),
        _PropertyRow(L.t('path'), path),
        _PropertyRow(L.t('modified'), fmtTs(n.ts)),
        const SizedBox(height: 10),
        Btn(
            filled: true,
            on: () => Navigator.pop(context),
            child: Text(L.t('close'),
                style: const TextStyle(
                    color: white, fontWeight: FontWeight.w800))),
      ]));
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

class NoteLiveEditor extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSave;
  final bool readOnly;

  const NoteLiveEditor(
      {super.key,
      required this.initial,
      required this.onSave,
      this.readOnly = false});

  @override
  State<NoteLiveEditor> createState() => NoteLiveEditorState();
}

class NoteLiveEditorState extends State<NoteLiveEditor> {
  late final LiveMarkdownController controller;
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  String get text => controller.text;

  @override
  void initState() {
    super.initState();
    controller = LiveMarkdownController(text: widget.initial);
    controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant NoteLiveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initial != widget.initial &&
        widget.initial != controller.text) {
      final sel = controller.selection;

      controller.value = TextEditingValue(
        text: widget.initial,
        selection: sel.isValid && sel.end <= widget.initial.length
            ? sel
            : TextSelection.collapsed(offset: widget.initial.length),
      );
    }
  }

  void _changed() {
    if (!mounted) return;
    widget.onSave(controller.text);
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        readOnly: widget.readOnly,
        showCursor: !widget.readOnly,
        inputFormatters: [MarkdownAutoCloseFormatter()],
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          height: 1.5,
        ),
        cursorColor: p.accent,
        backgroundCursorColor: p.sub,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        enableInteractiveSelection: true,
      ),
    );
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
    final codes = ['it', 'en'];

    await sheet<void>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('language'), style: title(p, s: 20)),
          const SizedBox(height: 12),
          for (final code in codes)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Btn(
                    on: () {
                      L.lang = code;
                      store.prefs.lang = code;
                      store.touch();
                      Navigator.pop(context);
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
                              child: Text(code == 'it' ? 'Italiano' : 'English',
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
                        Text(L.lang == 'it' ? 'Italiano' : 'English',
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

  const _SetToggle(
      {required this.titleText, required this.value, required this.on});

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

  const _Seg(
      {required this.value,
      required this.values,
      required this.labels,
      required this.on});

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

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Header(titleText: L.t('info'), back: true),
        Center(
            child: Container(
                padding: const EdgeInsets.all(22),
                decoration: box(p, r: 20),
                child: Column(children: [
                  IconX('bolt', size: 30, color: p.accent),
                  const SizedBox(height: 14),
                  Text('OpenFocusly', style: title(p, s: 22)),
                  const SizedBox(height: 5),
                  Text(L.t('aboutSub'), style: cap(p)),
                  const SizedBox(height: 14),
                  Text(L.t('tagline'),
                      style: body(p), textAlign: TextAlign.center),
                ]))),
      ],
    );
  }
}

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
    await store.init();

    if (store.prefs.lang == 'en' || store.prefs.lang == 'it') {
      L.lang = store.prefs.lang;
    }

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(WidgetsApp(
    debugShowCheckedModeBanner: false,
    color: const Color(0xFF4D68F6),
    home: const Root(),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('it'),
    ],
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
