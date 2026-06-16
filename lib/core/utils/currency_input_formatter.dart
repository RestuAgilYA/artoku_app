import 'package:flutter/services.dart';

class CurrencyTextInputFormatter extends TextInputFormatter {
  const CurrencyTextInputFormatter({this.thousandSeparator = '.'});

  final String thousandSeparator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = _extractDigits(newValue.text);

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final normalizedDigits = _normalizeLeadingZeros(digitsOnly);
    final formattedText = _formatWithThousands(normalizedDigits);

    final rawCursor = newValue.selection.baseOffset < 0
        ? newValue.text.length
        : newValue.selection.baseOffset;
    final safeCursor = rawCursor.clamp(0, newValue.text.length);

    final digitsBeforeCursor = _extractDigits(
      newValue.text.substring(0, safeCursor),
    ).length;

    final newCursor = _findCursorOffset(formattedText, digitsBeforeCursor);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursor),
      composing: TextRange.empty,
    );
  }

  String _extractDigits(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeLeadingZeros(String digits) {
    return digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  }

  String _formatWithThousands(String digits) {
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => thousandSeparator,
    );
  }

  int _findCursorOffset(String formattedText, int digitsBeforeCursor) {
    if (digitsBeforeCursor <= 0) return 0;

    int seenDigits = 0;
    for (int i = 0; i < formattedText.length; i++) {
      final code = formattedText.codeUnitAt(i);
      final isDigit = code >= 48 && code <= 57;
      if (isDigit) {
        seenDigits++;
        if (seenDigits >= digitsBeforeCursor) {
          return i + 1;
        }
      }
    }

    return formattedText.length;
  }
}
