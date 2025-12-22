import 'package:flutter/services.dart';

/// Formatter para email - apenas validação visual básica
/// Não aplica máscara, mas pode ajudar com validação em tempo real
class EmailFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Email não precisa de máscara visual, apenas retorna o valor
    // Mas podemos garantir que não há espaços e converter para lowercase
    final text = newValue.text.trim().toLowerCase();
    
    // Remove espaços
    final cleanedText = text.replaceAll(' ', '');
    
    return TextEditingValue(
      text: cleanedText,
      selection: newValue.selection,
    );
  }
}

















