import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'counter.dart';
import 'note.dart';
import 'prefs.dart';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      for (final note in list) {
        if (note.id == id) {
          target = note;
          break;
        }
      }
      list.removeWhere((e) => e.id == id);
    }
    if (deleteFile && target != null && target.uri.isNotEmpty) {
      await deleteNoteFile(target.uri);
    }
    touch();
    return true;
  }
}
