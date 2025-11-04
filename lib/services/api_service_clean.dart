import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'plate_search_service.dart';

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

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      if (response.data != null && response.data['success'] == true) {
        // Salvar token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.data['data']['token']);
        await prefs.setString('user_id', response.data['data']['user']['id']);
        
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro no login'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Registro
  Future<Map<String, dynamic>> register(String firstName, String email, String password, String phone) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'email': email,
        'password': password,
        'phone': phone,
      });
      
      if (response.data != null && response.data['success'] == true) {
        // Salvar token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.data['data']['token']);
        await prefs.setString('user_id', response.data['data']['user']['id']);
        
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro no registro'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Buscar veículo por placa (API REAL)
  Future<Map<String, dynamic>> searchVehicleByPlate(String plate) async {
    print('🔍 Buscando veículo pela placa: $plate');
    
    try {
      // Usar o serviço real de busca de placa
      final result = await PlateSearchService.searchVehicleByPlate(plate);
      
      if (result['success'] == true) {
        print('✅ Dados do veículo encontrados: ${result['data']}');
        return result;
      } else {
        // Fallback para API FIPE
        print('⚠️ Tentando fallback com API FIPE...');
        final fipeResult = await PlateSearchService.searchVehicleByPlate(plate);
        return fipeResult;
      }
    } catch (e) {
      print('❌ Erro na busca por placa: $e');
      return {
        'success': false,
        'error': 'Erro na consulta: ${e.toString()}'
      };
    }
  }

  // Obter oficinas próximas
  Future<Map<String, dynamic>> getNearbyWorkshops(double lat, double lng) async {
    try {
      final response = await _dio.get('/workshops/nearby', queryParameters: {
        'lat': lat,
        'lng': lng,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter todas as oficinas
  Future<Map<String, dynamic>> getAllWorkshops() async {
    try {
      final response = await _dio.get('/workshops');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter serviços
  Future<Map<String, dynamic>> getServices() async {
    try {
      final response = await _dio.get('/services');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar serviços'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter agendamentos do usuário
  Future<Map<String, dynamic>> getUserBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.get('/bookings', options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ));
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar agendamentos'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Criar agendamento
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.post('/bookings', 
        data: bookingData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao criar agendamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Atualizar perfil do usuário
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.put('/profile', 
        data: profileData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao atualizar perfil'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Adicionar veículo
  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.post('/vehicles', 
        data: vehicleData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao adicionar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter veículos do usuário
  Future<Map<String, dynamic>> getUserVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.get('/vehicles', options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ));
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar veículos'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
  }

  // Verificar se usuário está logado
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null;
  }

  // Obter token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Obter ID do usuário
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Tratamento de erros
  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Timeout de conexão. Verifique sua internet.';
        case DioExceptionType.badResponse:
          if (error.response?.statusCode == 401) {
            return 'Não autorizado. Faça login novamente.';
          } else if (error.response?.statusCode == 404) {
            return 'Recurso não encontrado.';
          } else if (error.response?.statusCode == 500) {
            return 'Erro interno do servidor.';
          }
          return 'Erro na requisição: ${error.response?.statusCode}';
        case DioExceptionType.cancel:
          return 'Requisição cancelada.';
        case DioExceptionType.connectionError:
          return 'Erro de conexão. Verifique sua internet.';
        default:
          return 'Erro de rede: ${error.message}';
      }
    }
    return 'Erro inesperado: ${error.toString()}';
  }
}









