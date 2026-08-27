import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../theme.dart';
import 'controller.dart';

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
  late final FocusNode focusNode;
  String get text => controller.text;

  @override
  void initState() {
    super.initState();
    controller = LiveMarkdownController(text: widget.initial);
    focusNode = FocusNode();
    controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.readOnly) {
        focusNode.requestFocus();
        controller.selection =
            TextSelection.collapsed(offset: controller.text.length);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NoteLiveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial &&
        widget.initial != controller.text) {
      controller.value = TextEditingValue(
          text: widget.initial,
          selection: TextSelection.collapsed(offset: widget.initial.length));
    }
    if (oldWidget.readOnly != widget.readOnly && !widget.readOnly && mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => focusNode.requestFocus());
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    return Stack(children: [
      if (controller.text.isEmpty)
        Positioned.fill(
            child: IgnorePointer(
                child: Text('…',
                    style:
                        TextStyle(color: p.sub, fontSize: 15, height: 1.45)))),
      EditableText(
        controller: controller,
        focusNode: focusNode,
        readOnly: widget.readOnly,
        style: TextStyle(color: p.text, fontSize: 15, height: 1.45),
        cursorColor: p.accent,
        backgroundCursorColor: p.sub,
        selectionColor: p.accent.withValues(alpha: .22),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        minLines: 18,
      ),
    ]);
  }
}
