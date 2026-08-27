import 'package:flutter/widgets.dart';

class SyntaxTheme {
  final Color keyword, string, number, comment, type, plain;
  const SyntaxTheme({
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.type,
    required this.plain,
  });
  factory SyntaxTheme.dark() => const SyntaxTheme(
      keyword: Color(0xFFC792EA),
      string: Color(0xFFC3E88D),
      number: Color(0xFFF78C6C),
      comment: Color(0xFF676E95),
      type: Color(0xFF82AAFF),
      plain: Color(0xFFD6DEEB));
  factory SyntaxTheme.light() => const SyntaxTheme(
      keyword: Color(0xFF8959A8),
      string: Color(0xFF718C00),
      number: Color(0xFF986801),
      comment: Color(0xFFA0A1A7),
      type: Color(0xFF4078F2),
      plain: Color(0xFF383A42));
}

class DartHighlighter {
  static const _keywords = <String>{
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'implements',
    'import',
    'in',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };
  static const _types = <String>{
    'int',
    'double',
    'num',
    'String',
    'bool',
    'List',
    'Map',
    'Set',
    'Future',
    'Stream',
    'Iterable',
    'Object',
    'dynamic',
    'Function',
    'Duration',
    'DateTime',
    'Never',
    'Symbol',
    'Type',
  };

  static bool supports(String lang) =>
      const {'dart', 'js', 'ts', 'java', 'kotlin'}.contains(lang.toLowerCase());

  static List<InlineSpan> highlight(String code, SyntaxTheme theme) {
    final base = TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: theme.plain,
        height: 1.45);
    final spans = <InlineSpan>[];
    final typePattern = r'\b(?:' + _types.join('|') + r')\b';
    final keywordPattern = r'\b(?:' + _keywords.join('|') + r')\b';
    final patterns = <RegExp>[
      RegExp(r'//.*$', multiLine: true),
      RegExp(r'/\*[\s\S]*?\*/'),
      RegExp(r"'(?:\\.|[^'\\])*'"),
      RegExp(r'"(?:\\.|[^"\\])*"'),
      RegExp(r'\b\d+\.?\d*\b'),
      RegExp(typePattern),
      RegExp(keywordPattern),
    ];
    final all = <RegExpMatch>[];
    for (final re in patterns) {
      all.addAll(re.allMatches(code));
    }
    all.sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    for (final m in all) {
      if (m.start < cursor) continue;
      if (m.start > cursor) {
        spans.add(TextSpan(text: code.substring(cursor, m.start), style: base));
      }
      final tok = m.group(0)!;
      spans.add(TextSpan(
          text: tok,
          style: base.copyWith(
              color: _color(tok, theme),
              fontWeight: _keywords.contains(tok)
                  ? FontWeight.w600
                  : FontWeight.w400)));
      cursor = m.end;
    }
    if (cursor < code.length) {
      spans.add(TextSpan(text: code.substring(cursor), style: base));
    }
    return spans;
  }

  static Color _color(String tok, SyntaxTheme t) {
    if (tok.startsWith('//') || tok.startsWith('/*')) return t.comment;
    if (tok.startsWith("'") || tok.startsWith('"')) return t.string;
    if (RegExp(r'^\d').hasMatch(tok)) return t.number;
    if (_types.contains(tok)) return t.type;
    if (_keywords.contains(tok)) return t.keyword;
    return t.plain;
  }
}
