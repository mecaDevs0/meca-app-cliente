import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../core/http_client_config.dart';

/// NOTA: nome mantido por compatibilidade com imports existentes.
/// Internamente este serviço usa o fluxo Asaas.
class PagBankTokenizationService {
  late Dio _dio;

  PagBankTokenizationService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    configureDioForProduction(_dio);
  }

  /// Obter chave pública do Asaas
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

  /// Wrapper de tokenização para fluxo Asaas.
  /// No app Flutter, os dados são enviados via TLS para o backend MECA,
  /// que encaminha ao Asaas no servidor.
  Future<Map<String, dynamic>> tokenizeCard({
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

  /// Detectar bandeira do cartão
  String _detectBrand(String cardNumber) {
    if (cardNumber.startsWith('4')) {
      return 'VISA';
    } else if (cardNumber.startsWith('5') || cardNumber.startsWith('2')) {
      return 'MASTERCARD';
    } else if (cardNumber.startsWith('3')) {
      return 'AMEX';
    } else if (cardNumber.startsWith('6')) {
      return 'ELO';
    }
    return 'UNKNOWN';
  }
}
