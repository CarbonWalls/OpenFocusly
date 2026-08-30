import 'package:flutter/widgets.dart';
import '../../theme/theme_scope.dart';

class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text});

  bool _nearRange(int position, int start, int end, {int distance = 1}) =>
      position >= start - distance && position <= end + distance;

  TextStyle _markerStyle(TextStyle base, {required bool visible}) =>
      base.copyWith(
        color: const Color(0x00000000),
        fontSize: 0,
        height: 0,
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
    for (final re in patterns) matches.addAll(re.allMatches(line));
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

      final caretPos = selection.isCollapsed ? selection.start : -1;
      final active =
          caretPos >= 0 && caretPos >= absStart && caretPos <= absEnd;

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
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final p = ThemeScope.of(context).pal;
    final base = style ?? TextStyle(color: p.text, fontSize: 15, height: 1.5);

    final spans = <InlineSpan>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');

    var offset = 0;
    var fenced = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = offset;
      final lineEnd = offset + line.length;

      final caret = selection.start.clamp(0, text.length).toInt();
      final nearLine = _nearRange(caret, lineStart, lineEnd, distance: 1);

      final fenceMatch = RegExp(r'^```(\w*)\s*$').firstMatch(line.trim());

      if (fenceMatch != null) {
        fenced = !fenced;
        spans.add(TextSpan(
            text: line,
            style: base.copyWith(
                fontFamily: 'monospace', color: nearLine ? p.text : p.text2)));
      } else if (fenced) {
        spans.add(TextSpan(
            text: line,
            style: base.copyWith(fontFamily: 'monospace', color: p.text2)));
      } else {
        final heading =
            RegExp(r'^(#{1,6})\s+(.*?)(?:\s+(#+))?$').firstMatch(line);

        if (heading != null) {
  final opening = heading.group(1)!;
  final gap = RegExp(r'^#{1,6}(\s+)').firstMatch(line)?.group(1) ?? ' ';
  final content = heading.group(2)!;
  final closing = heading.group(3);

  final insideHeading = caret >= lineStart && caret <= lineEnd;
  final revealOpening = insideHeading;
  final revealClosing = closing != null && insideHeading;

  final size = switch (opening.length) {
    1 => 29.0,
    2 => 24.0,
    3 => 20.0,
    4 => 18.0,
    _ => 16.5,
  };

  spans.add(TextSpan(
      text: opening,
      style: _markerStyle(base, visible: revealOpening)));
  spans.add(TextSpan(
      text: gap, style: _markerStyle(base, visible: revealOpening)));
  spans.add(TextSpan(
      text: content,
      style: base.copyWith(
          fontSize: size, fontWeight: FontWeight.w800, height: 1.3)));

  if (closing != null) {
    spans.add(TextSpan(
        text: ' ', style: _markerStyle(base, visible: revealClosing)));
    spans.add(TextSpan(
        text: closing,
        style: _markerStyle(base, visible: revealClosing)));
  }
}

      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: base));
      }

      offset = lineEnd + 1;
    }

    return TextSpan(style: base, children: spans);
  }
}
