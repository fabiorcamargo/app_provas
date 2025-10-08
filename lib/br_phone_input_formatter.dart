import 'package:flutter/services.dart';

/// Formata números para o padrão brasileiro automaticamente conforme o usuário digita.
/// Exemplos:
/// - 10 dígitos: (11) 3456-7890
/// - 11 dígitos: (11) 93456-7890
class BRPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }
    final formatted = _format(digitsOnly);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 2) {
      return '(${digits}';
    }

    final ddd = digits.substring(0, 2);
    if (digits.length <= 6) {
      final middle = digits.substring(2);
      return '($ddd) $middle';
    }

    if (digits.length <= 10) {
      // Formato fixo: (##) ####-####
      final middle = digits.substring(2, 6);
      final tail = digits.substring(6);
      return tail.isEmpty ? '($ddd) $middle' : '($ddd) $middle-$tail';
    }

    // 11 dígitos: celular (##) 9####-####
    final middle = digits.substring(2, 7); // 5 dígitos
    final tail = digits.substring(7);
    return '($ddd) $middle-$tail';
  }
}
