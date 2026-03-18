import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/http_client_config.dart';

class AsaasPaymentService {
  late final Dio _dio;

  AsaasPaymentService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: AppConfig.connectionTimeout),
        receiveTimeout: const Duration(seconds: AppConfig.receiveTimeout),
        headers: const {
          'Content-Type': 'application/json',
          'Accept-Encoding': 'gzip',
        },
      ),
    );

    configureDioForProduction(_dio);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Cria pagamento via backend MECA (provider Asaas interno no backend).
  Future<Map<String, dynamic>> createPayment({
    required String bookingId,
    required String paymentMethod,
    double? amount,
    Map<String, dynamic>? creditCard,
    int installments = 1,
    int? pixExpirationInSeconds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'paymentMethod': paymentMethod.toUpperCase(),
        if (amount != null) 'amount': amount,
        if (creditCard != null && creditCard.isNotEmpty)
          'credit_card': creditCard,
        if (installments > 0) 'installments': installments,
        if (pixExpirationInSeconds != null && pixExpirationInSeconds > 0)
          'pixExpiration': pixExpirationInSeconds,
      };

      final response =
          await _dio.post('/bookings/$bookingId/payment', data: payload);
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return body;
      }
      return {
        'success': false,
        'error': 'Resposta inválida ao criar pagamento.',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {
          'success': false,
          'error': data['error']?.toString() ??
              'Não foi possível criar o pagamento.',
          'data': data['data'],
        };
      }
      return {
        'success': false,
        'error': 'Não foi possível criar o pagamento.',
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Não foi possível criar o pagamento.',
      };
    }
  }

  /// Consulta status via backend MECA para polling de pagamento.
  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    try {
      final response = await _dio.get(
        '/payments/$paymentId/status',
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return body;
      }
      return {
        'success': false,
        'error': 'Resposta inválida ao consultar status do pagamento.',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {
          'success': false,
          'error': data['error']?.toString() ??
              'Não foi possível consultar o status do pagamento.',
          'data': data['data'],
        };
      }
      return {
        'success': false,
        'error': 'Não foi possível consultar o status do pagamento.',
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Não foi possível consultar o status do pagamento.',
      };
    }
  }
}
