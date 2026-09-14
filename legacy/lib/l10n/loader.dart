import 'dart:convert';
import 'package:flutter/services.dart';

class L10nLoader {
  static const _langDir = 'assets/lang';

  static Future<List<String>> availableLanguages() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final map = jsonDecode(manifest) as Map<String, dynamic>;
      final langs = <String>[];
      for (final key in map.keys) {
        if (key.startsWith('$_langDir/') && key.endsWith('.json')) {
          final name =
              key.replaceFirst('$_langDir/', '').replaceFirst('.json', '');
          langs.add(name);
        }
      }
      langs.sort();
      return langs;
    } catch (_) {
      return ['it', 'en'];
    }
  }

  static Future<Map<String, String>> load(String code) async {
    try {
      final raw = await rootBundle.loadString('$_langDir/$code.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }
}
