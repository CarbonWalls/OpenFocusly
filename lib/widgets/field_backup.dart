import 'package:flutter/widgets.dart';
import '../theme/theme_scope.dart';
import '../theme/styles.dart';

class Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String? hint;
  final String? label;
  final TextInputType? type;
  final int maxLines;

  const Field({
    super.key,
    required this.ctrl,
    this.hint,
    this.label,
    this.type,
    this.maxLines = 1,
  });

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
