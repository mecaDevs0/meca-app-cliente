import 'package:flutter/services.dart';

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.isEmpty) {
      return newValue;
    }
    
    // Remove todos os caracteres não numéricos
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    
    // Limita a 11 dígitos (DDD + 9 dígitos)
    final limitedDigits = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;
    
    // Aplica a máscara (XX) XXXXX-XXXX
    String formatted = '';
    if (limitedDigits.length >= 1) {
      formatted = '(${limitedDigits.substring(0, limitedDigits.length >= 2 ? 2 : limitedDigits.length)}';
    }
    if (limitedDigits.length >= 3) {
      final endIndex = limitedDigits.length >= 7 ? 7 : limitedDigits.length;
      formatted += ') ${limitedDigits.substring(2, endIndex)}';
    }
    if (limitedDigits.length >= 8) {
      final endIndex = limitedDigits.length >= 11 ? 11 : limitedDigits.length;
      formatted += '-${limitedDigits.substring(7, endIndex)}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}