import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectionTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Interceptor para adicionar token automaticamente
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          print('❌ API Error: ${error.response?.statusCode} - ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  // Token Management
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    print('🔑 Token carregado: ${_token != null ? "Sim" : "Não"}');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    print('💾 Token salvo');
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    print('🗑️ Token removido');
  }

  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('message')) {
          return data['message'];
        }
        return 'Erro: ${error.response!.statusCode}';
      }
      return 'Erro de conexão com o servidor';
    }
    return error.toString();
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final response = await _dio.post('/public/customers', data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      });
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Tentando login: $email');
      
      final response = await _dio.post('/auth/customer/token', data: {
        'email': email,
        'password': password,
      });
      
      print('✅ Login bem-sucedido: ${response.statusCode}');
      print('📦 Response data: ${response.data}');
      
      // O token pode estar em access_token ou token
      String? token = response.data['access_token'] ?? response.data['token'];
      
      if (token != null) {
        print('💾 Salvando token: ${token.substring(0, 20)}...');
        await saveToken(token);
      } else {
        print('⚠️ Nenhum token encontrado na resposta');
      }
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      print('❌ Erro no login: ${e.toString()}');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/auth/customer/forgot-password', data: {
        'email': email,
      });
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/customer/reset-password', data: {
        'token': token,
        'password': password,
      });
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/store/customers/me');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Services
  Future<Map<String, dynamic>> getServices() async {
    try {
      final response = await _dio.get('/public/master-services');
      return {'success': true, 'data': response.data['products'] ?? []};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Workshops
  Future<Map<String, dynamic>> getWorkshops({
    double? latitude,
    double? longitude,
    double? radius,
    String? serviceId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (latitude != null) params['latitude'] = latitude;
      if (longitude != null) params['longitude'] = longitude;
      if (radius != null) params['radius'] = radius;
      if (serviceId != null) params['service_id'] = serviceId;

      final response = await _dio.get('/public/workshops', queryParameters: params);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getWorkshopById(String id) async {
    try {
      final response = await _dio.get('/store/workshops/$id');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getWorkshopsByService(String serviceId) async {
    try {
      final response = await _dio.get('/store/workshops/by-service/$serviceId');
      return {'success': true, 'data': response.data['workshops'] ?? []};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getWorkshopServices(String workshopId) async {
    try {
      final response = await _dio.get('/store/workshops/$workshopId/services');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getWorkshopAvailability({
    required String workshopId,
    required String date,
  }) async {
    try {
      final response = await _dio.get('/store/workshops/$workshopId/availability?date=$date');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Vehicles
  Future<Map<String, dynamic>> getMyVehicles() async {
    try {
      final response = await _dio.get('/store/vehicles/me');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addVehicle({
    required String brand,
    required String model,
    required String year,
    required String plate,
    String? color,
  }) async {
    try {
      final response = await _dio.post('/store/vehicles', data: {
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'color': color,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> searchVehicleByPlate(String plate) async {
    try {
      final response = await _dio.get('/store/vehicles/lookup-by-plate/$plate');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Bookings
  Future<Map<String, dynamic>> getMyBookings() async {
    try {
      final response = await _dio.get('/store/bookings/me');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createBooking({
    required String workshopId,
    required String vehicleId,
    required List<String> serviceIds,
    required String scheduledDate,
    required String scheduledTime,
    String? notes,
  }) async {
    try {
      final response = await _dio.post('/store/bookings', data: {
        'workshop_id': workshopId,
        'vehicle_id': vehicleId,
        'service_ids': serviceIds,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'notes': notes,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _dio.post('/store/bookings/$bookingId/cancel');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Reviews
  Future<Map<String, dynamic>> getWorkshopReviews(String workshopId) async {
    try {
      final response = await _dio.get('/store/workshops/$workshopId/reviews');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _dio.post('/store/reviews', data: {
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Master Services
  Future<Map<String, dynamic>> getMasterServices() async {
    try {
      final response = await _dio.get('/store/master-services');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Device Token (FCM)
  Future<Response> registerDeviceToken(String token) async {
    return await _dio.post('/store/device-tokens', data: {
      'token': token,
    });
  }
}
