import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import '../../theme/theme_scope.dart';
import '../../theme/pal.dart';
import '../../theme/styles.dart';
import '../../models/store.dart';

class MarkdownPreview extends StatelessWidget {
  final String source;
  const MarkdownPreview({super.key, required this.source});

  List<InlineSpan> _inline(String text, Pal p) {
    final spans = <InlineSpan>[];

    final patterns = <RegExp>[
      RegExp(r'\*\*[^*]+\*\*'),
      RegExp(r'(?<!\*)\*[^*]+\*(?!\*)'),
      RegExp(r'~~[^~]+~~'),
      RegExp(r'`[^`]+`'),
      RegExp(r'\[[^\]]+\]\([^\)]+\)'),
    ];

    final matches = <RegExpMatch>[];
    for (final re in patterns) matches.addAll(re.allMatches(text));
    matches.sort((a, b) => a.start.compareTo(b.start));

    var cursor = 0;
    var lastEnd = -1;

    for (final m in matches) {
      if (m.start < lastEnd) continue;

      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }

      final token = m.group(0)!;

      if (token.startsWith('**')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(color: p.text, fontWeight: FontWeight.w800)));
      } else if (token.startsWith('~~')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: TextStyle(
                color: p.text2, decoration: TextDecoration.lineThrough)));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
                color: p.text,
                fontFamily: 'monospace',
                backgroundColor: p.surface2)));
      } else if (token.startsWith('[')) {
        final close = token.indexOf('](');
        final closeParen = token.lastIndexOf(')');
        final label = token.substring(1, close);
        final url = token.substring(close + 2, closeParen);

        spans.add(TextSpan(
            text: label,
            style: TextStyle(
                color: p.accent, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()..onTap = () => _openLink(url)));
      } else {
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(color: p.text, fontStyle: FontStyle.italic)));
      }

      cursor = m.end;
      lastEnd = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  void _openLink(String url) {
    try {
      Store.channel.invokeMethod('openLink', {'url': url});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final lines = source.replaceAll('\r\n', '\n').split('\n');

    if (source.trim().isEmpty) return const SizedBox(height: 6);

    final children = <Widget>[];
    var fenced = false;
    final codeBuf = <String>[];

    void flushCode() {
      children.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: p.surface2, borderRadius: BorderRadius.circular(8)),
        child: RichText(
            text: TextSpan(
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.5),
                children: [
              TextSpan(
                  text: codeBuf.join('\n'), style: TextStyle(color: p.text2))
            ])),
      ));
      codeBuf.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      final fence = RegExp(r'^```(\w*)\s*$').firstMatch(line.trim());

      if (fence != null) {
        if (!fenced) {
          fenced = true;
        } else {
          fenced = false;
          flushCode();
        }
        continue;
      }

      if (fenced) {
        codeBuf.add(line);
        continue;
      }

      if (line.isEmpty) {
        children.add(const SizedBox(height: 5));
        continue;
      }

      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        children.add(Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(heading.group(2)!,
                style: title(p,
                    s: level == 1
                        ? 22
                        : level == 2
                            ? 18
                            : 15))));
        continue;
      }

      final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        children
            .add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ',
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
          Expanded(
              child: RichText(
                  text: TextSpan(
                      style: body(p), children: _inline(bullet.group(1)!, p)))),
        ]));
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        children.add(Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.only(left: 9),
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.accent, width: 2))),
            child: RichText(
                text: TextSpan(
                    style: body(p), children: _inline(quote.group(1)!, p)))));
        continue;
      }

      children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
              text: TextSpan(style: body(p), children: _inline(line, p)))));
    }

    if (fenced) flushCode();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
