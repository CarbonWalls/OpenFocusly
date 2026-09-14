import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/store.dart';
import '../models/note.dart';
import '../app/nav.dart';
import '../theme/theme_scope.dart';
import '../theme/pal.dart';
import '../theme/styles.dart';
import '../theme/icons.dart';
import '../l10n/l10n.dart';
import '../widgets/btn.dart';
import '../widgets/icon_btn.dart';
import '../widgets/field.dart';
import '../widgets/header.dart';
import '../widgets/sheet.dart';
import '../widgets/confirm.dart';
import 'time.dart' show NoteTile;
import 'note_editor.dart' show showNoteEditor, showNoteMenu;

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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final note = filtered[i];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
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

class _SwipeNoteBg extends StatelessWidget {
  final String icon, label;
  final Alignment alignment;
  final bool danger;

  const _SwipeNoteBg({
    required this.icon,
    required this.label,
    required this.alignment,
    this.danger = false,
  });

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
