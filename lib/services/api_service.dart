import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectionTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'x-publishable-api-key': 'pk_8913f91e8557d24f01440879c36cdb8c81e6ef346ec9a14dc6582ba87d06e9e9',
      },
    ));
  }

  // ===== AUTENTICAÇÃO =====

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      print('📝 Tentando cadastro: $email');
      
      final response = await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'email': email,
        'password': password,
        'phone': phone,
      });
      
      if (response.data['success']) {
        print('✅ Cadastro realizado com sucesso');
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': response.data['message'] ?? 'Erro no cadastro'};
      }
    } catch (e) {
      print('❌ Erro no cadastro: ${e.toString()}');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Tentando login: $email');
      
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      if (response.data['success']) {
        await saveToken('auth-token-${response.data['customer']['id']}');
        print('✅ Login realizado com sucesso');
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': response.data['message'] ?? 'Erro no login'};
      }
    } catch (e) {
      print('❌ Erro no login: ${e.toString()}');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      print('🔑 Tentando recuperar senha: $email');
      
      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      
      print('✅ Email de recuperação enviado');
      return {'success': true, 'data': response.data};
    } catch (e) {
      print('❌ Erro na recuperação: ${e.toString()}');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      print('🔐 Tentando redefinir senha');
      
      final response = await _dio.post('/auth/reset-password', data: {
        'token': token,
        'password': password,
      });
      
      print('✅ Senha redefinida com sucesso');
      return {'success': true, 'data': response.data};
    } catch (e) {
      print('❌ Erro ao redefinir senha: ${e.toString()}');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== VEÍCULOS =====

  Future<Map<String, dynamic>> getMyVehicles(String customerId) async {
    try {
      final response = await _dio.get('/vehicles/$customerId');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/vehicles', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }


  Future<Map<String, dynamic>> searchVehicleByPlate(String plate) async {
    try {
      // Usa APENAS a API real da EC2
      final response = await _dio.get('/vehicles/search/$plate');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': 'Veículo não encontrado na base de dados'};
    }
  }


  Future<Map<String, dynamic>> setDefaultVehicle(String vehicleId, String customerId) async {
    try {
      final response = await _dio.put('/vehicles/$vehicleId/set-default', data: {
        'customerId': customerId,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== OFICINAS =====

  Future<Map<String, dynamic>> getNearbyWorkshops({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      final response = await _dio.get('/workshops/nearby', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getWorkshopDetails(String workshopId) async {
    try {
      final response = await _dio.get('/workshops/$workshopId');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== SERVIÇOS =====

  Future<Map<String, dynamic>> getServices() async {
    try {
      final response = await _dio.get('/services');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getServiceDetails(String serviceId) async {
    try {
      final response = await _dio.get('/services/$serviceId');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== AGENDAMENTOS =====

  Future<Map<String, dynamic>> getMyBookings(String customerId) async {
    try {
      final response = await _dio.get('/bookings/$customerId');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/bookings', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      final response = await _dio.get('/bookings/$bookingId/details');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _dio.put('/bookings/$bookingId/cancel');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> startService(String bookingId) async {
    try {
      final response = await _dio.put('/bookings/$bookingId/start');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> finishService(String bookingId) async {
    try {
      final response = await _dio.put('/bookings/$bookingId/finish');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> rateService(String bookingId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/rate', data: {
        'rating': rating,
        'comment': comment,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== PAGAMENTOS =====

  Future<Map<String, dynamic>> processPayment({
    required String bookingId,
    required String paymentMethod,
    Map<String, dynamic>? cardData,
  }) async {
    try {
      final response = await _dio.post('/payments/process', data: {
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'cardData': cardData,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // ===== UTILITÁRIOS =====

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/profile');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<void> loadToken() async {
    final token = await getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }


  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        return error.response!.data['message'] ?? 'Erro na comunicação com o servidor';
      } else {
        return 'Erro de conexão. Verifique sua internet.';
      }
    }
    return 'Erro inesperado. Tente novamente.';
  }
}