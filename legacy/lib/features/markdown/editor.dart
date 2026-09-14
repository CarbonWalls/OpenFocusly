import 'package:flutter/widgets.dart';
import '../../theme/theme_scope.dart';
import 'controller.dart';
import 'formatter.dart';

class NoteLiveEditor extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSave;
  final bool readOnly;

  const NoteLiveEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.readOnly = false,
  });

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
        style: TextStyle(color: p.text, fontSize: 15, height: 1.5),
        cursorColor: p.accent,
        backgroundCursorColor: p.sub,
        selectionColor: p.accentSoft,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        enableInteractiveSelection: true,
      ),
    );
  }
}
