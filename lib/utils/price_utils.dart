class PriceUtils {
  const PriceUtils._();

  /// Normaliza diferentes formatos de preço (int em centavos, double, string com "R$" etc).
  /// Retorna `null` quando o valor não é válido ou é zero/negativo.
  static double? extractPrice(dynamic value) {
    if (value == null) return null;

    double? normalized;
    bool originalHadDecimal = false;

    if (value is num) {
      normalized = value.toDouble();
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
    }

    if (normalized == null) return null;
    if (!originalHadDecimal && normalized.abs() >= 1000 && normalized % 1 == 0) {
      normalized = normalized / 100;
    }

    if (normalized <= 0) return null;
    return normalized;
  }

  static bool hasValidPrice(dynamic value) => extractPrice(value) != null;

  static String? formatCurrency(dynamic value) {
    final price = extractPrice(value);
    if (price == null) return null;
    return 'R\$ ${price.toStringAsFixed(2)}';
  }
}




