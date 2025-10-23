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
    
    // Aplica a máscara (XX) XXXXX-XXXX
    String formatted = '';
    if (digitsOnly.length >= 1) {
      formatted = '(${digitsOnly.substring(0, 2)}';
    }
    if (digitsOnly.length >= 3) {
      formatted += ') ${digitsOnly.substring(2, 7)}';
    }
    if (digitsOnly.length >= 8) {
      formatted += '-${digitsOnly.substring(7, 11)}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}