class PriceUtils {
  const PriceUtils._();

  /// Normaliza diferentes formatos de preço (int em centavos, double, string com "R$" etc).
  /// Retorna `null` quando o valor não é válido ou é zero/negativo.
  /// IMPORTANTE: A API sempre retorna valores em centavos (inteiros), então inteiros são convertidos para reais.
  static double? extractPrice(dynamic value) {
    if (value == null) return null;

    double? normalized;
    bool originalHadDecimal = false;

    if (value is num) {
      normalized = value.toDouble();
      // Se é um inteiro >= 1, assumir que está em centavos (formato da API)
      if (normalized % 1 == 0 && normalized.abs() >= 1) {
        normalized = normalized / 100;
      }
    } else {
      final cleaned = value
          .toString()
          .trim()
          .replaceAll(RegExp(r'[^0-9,.\-]'), '')
          .replaceAll(',', '.');
      if (cleaned.contains('.')) {
        originalHadDecimal = true;
      }
      normalized = double.tryParse(cleaned);
      
      // Se não tinha decimal e é um inteiro >= 1, assumir centavos
      if (normalized != null && !originalHadDecimal && normalized % 1 == 0 && normalized.abs() >= 1) {
        normalized = normalized / 100;
      }
    }

    if (normalized == null || normalized <= 0) return null;
    return normalized;
  }

  static bool hasValidPrice(dynamic value) => extractPrice(value) != null;

  static String? formatCurrency(dynamic value) {
    // IMPORTANTE: Se value já é um double (já convertido), não converter novamente
    if (value is double) {
      return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
    }
    // Se não é double, usar extractPrice para converter
    final price = extractPrice(value);
    if (price == null) return null;
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
