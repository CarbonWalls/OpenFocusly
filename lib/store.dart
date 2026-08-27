import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'lang.dart';
import 'package:flutter/foundation.dart';

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

String fmtTs(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String z(int n) => n.toString().padLeft(2, '0');
  return '${z(d.day)}/${z(d.month)}/${d.year} ${z(d.hour)}:${z(d.minute)}';
}

String trimNoteName(String s, {int max = 30}) {
  final clean = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return L.t('untitled');
  if (clean.length <= max) return clean;
  final cut = clean.substring(0, max - 1);
  final lastSpace = cut.lastIndexOf(' ');
  final stem = lastSpace > max * .55 ? cut.substring(0, lastSpace) : cut;
  return '${stem.trim()}…';
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
    final cleaned = first.replaceFirst(RegExp(r'^#+\s*'), '');
    if (first.startsWith('#')) return cleaned;
    if (fileName.trim().isNotEmpty) {
      return fileName.replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
    }
    return cleaned;
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
  String theme = 'system';
  String lang = 'it';
  bool vibration = true;
  bool sound = false;
  double? goalV, goalM;
  String notesFolder = '';
  String notesFolderUri = '';

  Prefs();

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
    await Sound.init(dir);
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
        'existingUri': existingUri
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
    } catch (_) {
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
    final known = <String>{};
    for (final list in notes.values) {
      for (final n in list) {
        if (n.uri.isNotEmpty) known.add(n.uri);
      }
    }
    var changed = false;
    for (final file in files) {
      final uri = (file['uri'] as String? ?? '').trim();
      final name = (file['name'] as String? ?? 'nota.md').trim();
      final modified = (file['lastModified'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      if (uri.isEmpty || known.contains(uri)) continue;
      final text = await readNoteFile(uri);
      if (text == null) continue;
      final key = dayKey(DateTime.fromMillisecondsSinceEpoch(modified));
      (notes[key] ??= []).add(Note(
          uid(), text, modified, 0, false, folderName, treeUri, uri, name));
      known.add(uri);
      changed = true;
    }
    if (changed) touch();
  }

  void vib() {
    if (prefs.vibration) HapticFeedback.selectionClick();
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
    final valueHit = c.goalV != null &&
        c.goalV! > 0 &&
        beforeValue < c.goalV! &&
        c.value >= c.goalV!;
    final moneyHit = c.goalM != null &&
        c.goalM! > 0 &&
        beforeMoney < c.goalM! &&
        c.money >= c.goalM!;
    if (valueHit || moneyHit) {
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
    final base =
        text.split('\n').first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final n = Note(uid(), text, DateTime.now().millisecondsSinceEpoch, color,
        false, f, fu, uri, safe.isEmpty ? 'nota.md' : '$safe.md');
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

  void deleteNoteById(String id) {
    for (final list in notes.values) {
      list.removeWhere((e) => e.id == id);
    }
    touch();
  }
}

final store = Store();

class Sound {
  static final Map<String, String> paths = {};
  static Future<void> init(String? dir) async {
    if (dir == null) return;
    for (final name in ['plus', 'minus']) {
      final target = File('$dir/audio/$name.mp3');
      try {
        if (!target.existsSync()) {
          final data = await rootBundle.load('assets/audio/$name.mp3');
          target.parent.createSync(recursive: true);
          target.writeAsBytesSync(data.buffer.asUint8List());
        }
        paths[name] = target.path;
      } catch (_) {}
    }
  }

  static Future<void> play(String name) async {
    if (!store.prefs.sound) return;
    final p = paths[name];
    if (p == null) return;
    try {
      await Store.channel.invokeMethod('playSound', {'path': p});
    } catch (_) {}
  }
}

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
      // guard: if we land on the counter detail but the counter is gone, bail out
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
