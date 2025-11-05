import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    if (text.length > 11) {
      return oldValue;
    }
    
    String formatted = '';
    
    if (text.length <= 3) {
      formatted = text;
    } else if (text.length <= 6) {
      formatted = '${text.substring(0, 3)}.${text.substring(3)}';
    } else if (text.length <= 9) {
      formatted = '${text.substring(0, 3)}.${text.substring(3, 6)}.${text.substring(6)}';
    } else {
      formatted = '${text.substring(0, 3)}.${text.substring(3, 6)}.${text.substring(6, 9)}-${text.substring(9)}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


