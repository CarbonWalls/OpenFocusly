import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/store.dart';
import '../models/note.dart';
import '../app/nav.dart';
import '../app/root.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';
import '../widgets/icon_btn.dart';
import '../widgets/sheet.dart';
import '../widgets/confirm.dart';
import '../features/markdown/editor.dart';
import '../features/markdown/preview.dart';
import 'time.dart' show trimNoteName, fmtTs;

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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(L.t('noteOptions'), style: title(p, s: 20)),
              ),
              _MenuAction(
                  icon: 'pin',
                  label:
                      widget.note?.pinned == true ? L.t('unpin') : L.t('pin'),
                  onTap: () {
                    if (widget.note != null) {
                      widget.note!.pinned = !widget.note!.pinned;
                      store.touch();
                    }
                    Navigator.pop(context);
                  }),
              const SizedBox(height: 2),
              Container(height: 1, color: p.line),
              const SizedBox(height: 2),
              _MenuAction(
                  icon: 'folder',
                  label: '${L.t('folder')}: ${folder.isEmpty ? '—' : folder}',
                  onTap: () {
                    Navigator.pop(context);
                    pickFolder();
                  }),
              const SizedBox(height: 2),
              Container(height: 1, color: p.line),
              const SizedBox(height: 2),
              _MenuAction(
                  icon: 'info',
                  label: L.t('properties'),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.note != null) showProperties(widget.note!);
                  }),
              const SizedBox(height: 2),
              Container(height: 1, color: p.line),
              const SizedBox(height: 2),
              _MenuAction(
                  icon: 'note',
                  label: preview ? L.t('editor') : L.t('preview'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => preview = !preview);
                  }),
              if (widget.note != null) ...[
                const SizedBox(height: 2),
                Container(height: 1, color: p.line),
                const SizedBox(height: 2),
                _MenuAction(
                    icon: 'trash',
                    label: L.t('delete'),
                    danger: true,
                    onTap: () {
                      Navigator.pop(context);
                      remove();
                    }),
              ],
            ],
          ),
        ));
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
                icon: readOnly ? 'play' : 'note',
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

class _MenuAction extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

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
