import 'package:flutter/widgets.dart';
import '../theme.dart';
import 'syntax.dart';

class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text});

  bool _nearRange(int position, int start, int end, {int distance = 1}) =>
      position >= start - distance && position <= end + distance;

  @override
  void valueChanged(TextEditingValue newValue) {
    final oldText = value.text;
    final newText = newValue.text;
    final oldLen = oldText.length;
    final newLen = newText.length;
    
    // Only process if text was added (not deleted)
    if (newLen == oldLen + 1) {
      final cursorPos = newValue.selection.baseOffset;
      if (cursorPos > 0 && cursorPos <= newLen) {
        final charJustTyped = newText[cursorPos - 1];
        
        // Autocomplete for single backtick (inline code)
        if (charJustTyped == '`') {
          // Check if this is NOT part of a triple backtick sequence
          final beforeCursor = cursorPos >= 3 ? newText.substring(cursorPos - 3, cursorPos - 1) : '';
          if (beforeCursor != '``') {
            // Insert closing backtick and position cursor in middle
            final newFullText = '${newText.substring(0, cursorPos)}${newText.substring(cursorPos - 1)}';
            value = TextEditingValue(
              text: newFullText,
              selection: TextSelection.collapsed(offset: cursorPos),
            );
            return;
          }
        }
        
        // Move cursor forward when typing next to existing backtick
        if (cursorPos < newLen && newText[cursorPos] == '`') {
          // Check if previous char was also a backtick (auto-completed one)
          if (cursorPos > 0 && newText[cursorPos - 1] == '`') {
            value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: cursorPos + 1),
            );
            return;
          }
        }
      }
    }
    
    // Autocomplete for triple backticks (code block)
    if (newLen >= oldLen + 3) {
      final cursorPos = newValue.selection.baseOffset;
      if (cursorPos >= 3) {
        final lastThree = newText.substring(cursorPos - 3, cursorPos);
        if (lastThree == '```') {
          // Insert closing ``` with newlines and move cursor to middle
          final newFullText = '${newText.substring(0, cursorPos)}\n\n```';
          value = TextEditingValue(
            text: newFullText,
            selection: TextSelection.collapsed(offset: cursorPos + 2),
          );
          return;
        }
      }
    }
    
    super.valueChanged(newValue);
  }

  TextStyle _markerStyle(TextStyle base, {required bool visible}) =>
      base.copyWith(
        color: visible ? base.color : const Color(0x00000000),
        fontSize: visible ? base.fontSize : 0,
        height: visible ? base.height : 0,
      );

  List<InlineSpan> _renderInline(
      String line, int lineStart, TextStyle base, Color accent) {
    final spans = <InlineSpan>[];
    final patterns = <RegExp>[
      RegExp(r'\*\*[^*]+\*\*'),
      RegExp(r'(?<!\*)\*[^*]+\*(?!\*)'),
      RegExp(r'~~[^~]+~~'),
      RegExp(r'`[^`]+`'),
      RegExp(r'\[[^\]]+\]\([^\)]+\)'),
    ];
    final matches = <RegExpMatch>[];
    for (final re in patterns) {
      matches.addAll(re.allMatches(line));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    var lastEnd = -1;
    for (final m in matches) {
      if (m.start < lastEnd) continue;
      if (m.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, m.start), style: base));
      }
      final token = m.group(0)!;
      final absStart = lineStart + m.start;
      final absEnd = lineStart + m.end;
      final selStart = selection.start;
      final selEnd = selection.end;
      final active = selStart >= 0 &&
          selEnd >= 0 &&
          (selStart == selEnd
              ? _nearRange(selStart, absStart, absEnd, distance: 1)
              : selStart <= absEnd && selEnd >= absStart);

      String marker;
      String content;
      TextStyle contentStyle = base;
      int close = -1;
      if (token.startsWith('**')) {
        marker = '**';
        content = token.substring(2, token.length - 2);
        contentStyle = base.copyWith(fontWeight: FontWeight.w800);
      } else if (token.startsWith('~~')) {
        marker = '~~';
        content = token.substring(2, token.length - 2);
        contentStyle = base.copyWith(decoration: TextDecoration.lineThrough);
      } else if (token.startsWith('`')) {
        marker = '`';
        content = token.substring(1, token.length - 1);
        contentStyle = base.copyWith(fontFamily: 'monospace');
      } else if (token.startsWith('[')) {
        close = token.indexOf('](');
        marker = '';
        content = token.substring(1, close);
        contentStyle =
            base.copyWith(decoration: TextDecoration.underline, color: accent);
      } else {
        marker = '*';
        content = token.substring(1, token.length - 1);
        contentStyle = base.copyWith(fontStyle: FontStyle.italic);
      }

      if (marker.isNotEmpty) {
        spans.add(
            TextSpan(text: marker, style: _markerStyle(base, visible: active)));
      }
      spans.add(TextSpan(text: content, style: contentStyle));
      if (token.startsWith('`')) {
        spans.add(
            TextSpan(text: '`', style: _markerStyle(base, visible: active)));
      } else if (token.startsWith('[')) {
        final closeParen = token.lastIndexOf(')');
        if (close > 0 && closeParen > close) {
          final urlText = token.substring(close + 2, closeParen);
          spans.add(
              TextSpan(text: '](', style: _markerStyle(base, visible: active)));
          spans.add(TextSpan(
              text: urlText, style: _markerStyle(base, visible: active)));
          spans.add(
              TextSpan(text: ')', style: _markerStyle(base, visible: active)));
        }
      } else if (marker.isNotEmpty) {
        spans.add(
            TextSpan(text: marker, style: _markerStyle(base, visible: active)));
      }
      cursor = m.end;
      lastEnd = m.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: base));
    }
    return spans;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final p = ThemeScope.of(context).pal;
    final base = style ?? TextStyle(color: p.text, fontSize: 15, height: 1.45);
    final spans = <InlineSpan>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    var offset = 0;
    var fenced = false;
    String fenceLang = '';
    final theme = p.dark ? SyntaxTheme.dark() : SyntaxTheme.light();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = offset;
      final lineEnd = offset + line.length;
      final caret = selection.start.clamp(0, text.length).toInt();
      final nearLine = _nearRange(caret, lineStart, lineEnd, distance: 1);

      final fenceMatch = RegExp(r'^```(\w*)\s*$').firstMatch(line.trim());
      if (fenceMatch != null) {
        if (!fenced) fenceLang = (fenceMatch.group(1) ?? '').toLowerCase();
        fenced = !fenced;
        spans.add(TextSpan(
            text: line,
            style: base.copyWith(
                fontFamily: 'monospace', color: nearLine ? p.text : p.text2)));
      } else if (fenced) {
        if (DartHighlighter.supports(fenceLang)) {
          spans.addAll(DartHighlighter.highlight(line, theme));
        } else {
          spans.add(TextSpan(
              text: line,
              style: base.copyWith(fontFamily: 'monospace', color: p.text2)));
        }
      } else {
        final heading =
            RegExp(r'^(#{1,6})\s+(.*?)(?:\s+(#+))?$').firstMatch(line);
        if (heading != null) {
          final opening = heading.group(1)!;
          final gap = RegExp(r'^#{1,6}(\s+)').firstMatch(line)?.group(1) ?? ' ';
          final content = heading.group(2)!;
          final closing = heading.group(3);
          final openStart = lineStart;
          final openEnd = openStart + opening.length + gap.length;
          final closeStart = closing == null ? -1 : lineEnd - closing.length;
          final closeEnd = closing == null ? -1 : lineEnd;
          final revealOpen = _nearRange(caret, openStart, openEnd, distance: 1);
          final revealClose = closing != null &&
              _nearRange(caret, closeStart, closeEnd, distance: 1);
          final size = switch (opening.length) {
            1 => 29.0,
            2 => 24.0,
            3 => 20.0,
            4 => 18.0,
            _ => 16.5,
          };
          spans.add(TextSpan(
              text: opening, style: _markerStyle(base, visible: revealOpen)));
          spans.add(TextSpan(
              text: gap, style: _markerStyle(base, visible: revealOpen)));
          spans.add(TextSpan(
              text: content,
              style: base.copyWith(
                  fontSize: size, fontWeight: FontWeight.w800, height: 1.3)));
          if (closing != null) {
            spans.add(TextSpan(
                text: ' ', style: _markerStyle(base, visible: revealClose)));
            spans.add(TextSpan(
                text: closing,
                style: _markerStyle(base, visible: revealClose)));
          }
        } else {
          spans.addAll(_renderInline(line, lineStart, base, p.accent));
        }
      }
      if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
      offset = lineEnd + 1;
    }
    return TextSpan(style: base, children: spans);
  }
}
