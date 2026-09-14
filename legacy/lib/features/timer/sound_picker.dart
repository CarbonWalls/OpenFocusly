import 'package:flutter/widgets.dart';
import '../../models/store.dart';
import '../../theme/theme_scope.dart';
import '../../theme/pal.dart';
import '../../theme/icons.dart';
import '../../widgets/btn.dart';
import '../../widgets/icon_btn.dart';

class SoundPicker extends StatefulWidget {
  const SoundPicker({super.key});

  @override
  State<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<SoundPicker> {
  List<String> _builtins = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadBuiltins();
  }

  Future<void> _loadBuiltins() async {
    try {
      final list =
          await Store.channel.invokeListMethod<String>('listBuiltinSounds');
      if (mounted) setState(() => _builtins = list ?? []);
    } catch (_) {}
  }

  Future<void> _pickCustom() async {
    try {
      final uri = await Store.channel.invokeMethod<String>('pickAudioFile');
      if (uri == null || uri.isEmpty) return;
      store.prefs.notificationSound = uri;
      store.touch();
      setState(() => _expanded = false);
    } catch (_) {}
  }

  Future<void> _preview(String sound) async {
    try {
      await Store.channel.invokeMethod('playNotificationSound', {'uri': sound});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final current = store.prefs.notificationSound;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Btn(
        on: () => setState(() => _expanded = !_expanded),
        pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(children: [
          IconX('play', size: 16, color: p.text2),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              current.isEmpty
                  ? 'default'
                  : current.split('/').last.replaceFirst('.mp3', ''),
              style: TextStyle(color: p.text, fontWeight: FontWeight.w700),
            ),
          ),
          IconX(_expanded ? 'down' : 'right', size: 14, color: p.sub),
        ]),
      ),
      if (_expanded) ...[
        const SizedBox(height: 6),
        _SoundRow(
          name: 'none',
          selected: current.isEmpty,
          onTap: () {
            store.prefs.notificationSound = '';
            store.touch();
            setState(() => _expanded = false);
          },
          onPreview: null,
        ),
        for (final s in _builtins)
          _SoundRow(
            name: s,
            selected: current == s,
            onTap: () {
              store.prefs.notificationSound = s;
              store.touch();
              setState(() => _expanded = false);
            },
            onPreview: () => _preview(s),
          ),
        const SizedBox(height: 6),
        Btn(
          on: _pickCustom,
          pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            IconX('folder', size: 15, color: p.accent),
            const SizedBox(width: 8),
            Text('use custom…',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    ]);
  }
}

class _SoundRow extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  const _SoundRow({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
          child: Btn(
            on: onTap,
            filled: selected,
            pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        color: selected ? white : p.text,
                        fontWeight: FontWeight.w600)),
              ),
              if (selected) IconX('check', size: 14, color: white),
            ]),
          ),
        ),
        if (onPreview != null) ...[
          const SizedBox(width: 4),
          IconBtn(icon: 'play', on: onPreview, size: 14),
        ],
      ]),
    );
  }
}
