import 'dart:convert';
import 'package:flutter/services.dart';

class L {
  static String lang = 'it';
  static Map<String, Map<String, String>> langs = {};

  static Future<void> load() async {
    final codes = <String>[];
    try {
      final man = jsonDecode(await rootBundle.loadString('AssetManifest.json'))
          as Map<String, dynamic>;
      for (final k in man.keys) {
        if (k.startsWith('assets/lang/') && k.endsWith('.json')) {
          codes.add(k.substring(12, k.length - 5));
        }
      }
    } catch (_) {}
    if (codes.isEmpty) {
      try {
        final bytes = await rootBundle.load('AssetManifest.bin');
        final s = latin1.decode(bytes.buffer.asUint8List(), allowInvalid: true);
        for (final m
            in RegExp(r'assets/lang/([A-Za-z0-9_\-]+)\.json').allMatches(s)) {
          final g = m.group(1);
          if (g != null && !codes.contains(g)) codes.add(g);
        }
      } catch (_) {}
    }
    for (final c in codes) {
      try {
        final raw = await rootBundle.loadString('assets/lang/$c.json');
        final m = jsonDecode(raw) as Map<String, dynamic>;
        langs[c] = m.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    if (!langs.containsKey(lang))
      lang = langs.keys.isNotEmpty ? langs.keys.first : 'it';
  }

  static String name(String code) => langs[code]?['_name'] ?? code;
  static String t(String k) => langs[lang]?[k] ?? langs['it']?[k] ?? k;
}
