import 'package:flutter/services.dart';

class MarkdownAutoCloseFormatter extends TextInputFormatter {
  static const _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length) return newValue;

    final insertedLen = newValue.text.length - oldValue.text.length;
    if (insertedLen > 3) return newValue;

    final cursor = newValue.selection.baseOffset;
    if (cursor <= 0) return newValue;

    final inserted = newValue.text.substring(cursor - insertedLen, cursor);
    final before = newValue.text.substring(0, cursor);
    final after =
        cursor < newValue.text.length ? newValue.text.substring(cursor) : '';

    if (inserted == '`' && before.endsWith('``')) {
      final prefix = newValue.text.substring(0, cursor - 3);
      final newText = '$prefix```\n\n```$after';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: prefix.length + 4),
      );
    }

    if (inserted == '`') {
      if (after.startsWith('`')) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before`$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    if (inserted == '*' || inserted == '~') {
      if (before.endsWith(inserted)) return newValue;
      if (after.startsWith(inserted)) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before$inserted$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    if (_pairs.containsKey(inserted)) {
      final closing = _pairs[inserted]!;
      if (after.startsWith(closing)) {
        return TextEditingValue(
          text: newValue.text.substring(0, cursor) + after.substring(1),
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
      final nextChar = after.isNotEmpty ? after[0] : '';
      if (nextChar.isEmpty || nextChar == ' ' || nextChar == '\n') {
        final newText = '$before$closing$after';
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor),
        );
      }
    }

    return newValue;
  }
}
