import 'counter.dart';

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
    if (fileName.trim().isNotEmpty) {
      return fileName.replaceFirst(RegExp(r'\.md$', caseSensitive: false), '');
    }
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
