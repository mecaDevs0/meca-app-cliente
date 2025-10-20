import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:9000';
  final Dio _dio = Dio();
  String? _token;

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Auth
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      final response = await _dio.post('/auth/customer/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      });
      
      if (response.data['token'] != null) {
        await saveToken(response.data['token']);
      }
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/customer/login', data: {
        'email': email,
        'password': password,
      });
      
      if (response.data['token'] != null) {
        await saveToken(response.data['token']);
      }
      
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/store/customers/me');
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Workshops
  Future<Map<String, dynamic>> getWorkshops({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (latitude != null) queryParams['lat'] = latitude;
      if (longitude != null) queryParams['lng'] = longitude;
      if (radius != null) queryParams['radius'] = radius;

      final response = await _dio.get('/store/workshops', queryParameters: queryParams);
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
      final response = await _dio.get(
        '/store/workshops/$workshopId/availability',
        queryParameters: {'date': date},
      );
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
    required String plate,
    required String brand,
    required String model,
    required int year,
  }) async {
    try {
      final response = await _dio.post('/store/vehicles', data: {
        'plate': plate,
        'brand': brand,
        'model': model,
        'year': year,
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
}
  // Device Token (FCM)
  Future<Response> registerDeviceToken(String token) async {
    return await _dio.post('/store/device-tokens', data: {
      'token': token,
    });
  }
}

