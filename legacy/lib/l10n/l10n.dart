import 'loader.dart';

class L {
  static String lang = 'it';
  static Map<String, String> _strings = {};

  static Future<void> init(
      String code, Future<Map<String, String>> Function(String) loader) async {
    lang = code;
    _strings = await loader(code);
  }

  static String t(String k) => _strings[k] ?? k;

  static Future<List<String>> available() => L10nLoader.availableLanguages();
}
