import 'dart:async';
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
import '../widgets/confirm.dart';
import '../features/timer/ring.dart';
import '../features/timer/wheel.dart';
import 'note_editor.dart';

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
      _playNotification();
      store.addNote(dayKey(DateTime.now()), 'Focus session completed.', 0,
          folder: store.prefs.notesFolder.isEmpty
              ? 'generale'
              : store.prefs.notesFolder);
      return;
    }

    setState(() => remainMs = msLeft);
  }

  void _playNotification() {
    final sound = store.prefs.notificationSound;
    if (sound.isEmpty) {
      store.vib();
      return;
    }
    try {
      Store.channel.invokeMethod('playNotificationSound', {'uri': sound});
    } catch (_) {
      store.vib();
    }
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

class _Focus extends StatelessWidget {
  final double remainMs;
  final double durationMs;
  final bool running;
  final String Function(int) time;
  final VoidCallback toggle, reset;
  final ValueChanged<int> setDur;

  const _Focus({
    required this.remainMs,
    required this.durationMs,
    required this.running,
    required this.time,
    required this.toggle,
    required this.setDur,
    required this.reset,
  });

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
                                painter: Ring(p, ratio)),
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

  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
  });

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

  const _Calendar({
    required this.selected,
    required this.month,
    required this.q,
    required this.onDay,
    required this.onMonth,
  });

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

  const _Day({
    required this.d,
    required this.selected,
    required this.today,
    required this.hasNote,
    required this.on,
  });

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
