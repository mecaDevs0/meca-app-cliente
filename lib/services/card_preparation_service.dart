import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../core/http_client_config.dart';

/// Prepares and validates card data before sending to backend.
/// Card data travels over TLS to the MECA API, which forwards to Asaas server-side.
class CardPreparationService {
  late Dio _dio;

  CardPreparationService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    configureDioForProduction(_dio);
  }

  Future<String?> getPublicKey() async {
    try {
      final response = await _dio.get('/asaas/public-key');

      if (response.data != null &&
          response.data['success'] == true &&
          response.data['data'] != null) {
        return response.data['data']['public_key'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> prepareCard({
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  }) async {
    try {
      final normalizedCardNumber = cardNumber.replaceAll(' ', '');
      if (normalizedCardNumber.length < 13) {
        return {'success': false, 'error': 'Número de cartão inválido'};
      }

      final normalizedExpMonth = expiryMonth.padLeft(2, '0');
      final normalizedExpYear = expiryYear.length == 2
          ? '20$expiryYear'
          : expiryYear;
      return {
        'success': true,
        'payment_method': 'CREDIT_CARD',
        'credit_card': {
          'holderName': holderName.toUpperCase().trim(),
          'number': normalizedCardNumber,
          'expiryMonth': normalizedExpMonth,
          'expiryYear': normalizedExpYear,
          'ccv': cvv,
        },
        'last_digits': normalizedCardNumber.substring(normalizedCardNumber.length - 4),
        'brand': _detectBrand(normalizedCardNumber),
        'card_data': {
          'last_digits': normalizedCardNumber.substring(normalizedCardNumber.length - 4),
          'brand': _detectBrand(normalizedCardNumber),
          'expiry_month': normalizedExpMonth,
          'expiry_year': normalizedExpYear,
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao preparar dados do cartão: ${e.toString()}'
      };
    }
  }

  String _detectBrand(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'VISA';

    // Mastercard: 2221-2720 or 51-55
    if (cardNumber.length >= 4) {
      final prefix4 = int.tryParse(cardNumber.substring(0, 4)) ?? 0;
      if (prefix4 >= 2221 && prefix4 <= 2720) return 'MASTERCARD';
    }
    if (cardNumber.length >= 2) {
      final prefix2 = int.tryParse(cardNumber.substring(0, 2)) ?? 0;
      if (prefix2 >= 51 && prefix2 <= 55) return 'MASTERCARD';
    }

    // Amex: 34 or 37
    if (cardNumber.startsWith('34') || cardNumber.startsWith('37')) {
      return 'AMEX';
    }

    // Elo: common ranges
    const eloRanges = ['636368', '438935', '504175', '451416', '636297', '506699'];
    for (final prefix in eloRanges) {
      if (cardNumber.startsWith(prefix)) return 'ELO';
    }
    if (cardNumber.length >= 6) {
      final prefix6 = int.tryParse(cardNumber.substring(0, 6)) ?? 0;
      if (prefix6 >= 509048 && prefix6 <= 509067) return 'ELO';
      if (prefix6 >= 650031 && prefix6 <= 650033) return 'ELO';
      if (prefix6 >= 650035 && prefix6 <= 650051) return 'ELO';
    }

    // Diners: 300-305, 36, 38
    if (cardNumber.length >= 3) {
      final prefix3 = int.tryParse(cardNumber.substring(0, 3)) ?? 0;
      if (prefix3 >= 300 && prefix3 <= 305) return 'DINERS';
    }
    if (cardNumber.startsWith('36') || cardNumber.startsWith('38')) {
      return 'DINERS';
    }

    // Hipercard
    if (cardNumber.startsWith('606282')) return 'HIPERCARD';

    return 'UNKNOWN';
  }
}
