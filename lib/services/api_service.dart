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
        final fipeResult = await PlateSearchService.searchVehicleByPlateFIPE(plate);
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
        // A API retorna {"success":true,"data":{"workshops":[...]}}
        final workshops = response.data['data']['workshops'] ?? [];
        return {'success': true, 'data': workshops};
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
        // A API retorna {"success":true,"data":{"services":[...]}}
        final services = response.data['data']['services'] ?? [];
        return {'success': true, 'data': services};
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
      
      // Obter customer_id
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      print('🔍 Buscando agendamentos para usuário: $userId');
      
      final response = await _dio.get('/bookings/$userId', options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ));
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados dos agendamentos: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar agendamentos'};
      }
    } catch (e) {
      print('❌ Erro ao buscar agendamentos: $e');
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
      
      // Obter customer_id
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      // Preparar dados para a API (conforme schema real)
      final apiData = {
        'customer_id': userId,
        'vehicle_id': bookingData['vehicle_id'] ?? '',
        'oficina_id': bookingData['workshop_id'] ?? bookingData['oficina_id'] ?? '',
        'product_id': bookingData['service_id'] ?? bookingData['product_id'] ?? '',
        'appointment_date': bookingData['date'] ?? bookingData['appointment_date'] ?? '',
        'customer_notes': bookingData['notes'] ?? bookingData['customer_notes'] ?? '',
      };
      
      print('🔍 Criando agendamento com dados: $apiData');
      
      final response = await _dio.post('/bookings', 
        data: apiData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados da resposta: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao criar agendamento'};
      }
    } catch (e) {
      print('❌ Erro ao criar agendamento: $e');
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
      
      print('🔍 Atualizando perfil com dados: $profileData');
      print('🔍 Token: ${token.substring(0, 20)}...');
      
      // Obter customer_id
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      // Preparar dados para a API (removendo campo address que não existe)
      final apiData = {
        'first_name': profileData['first_name'] ?? profileData['firstName'] ?? '',
        'last_name': profileData['last_name'] ?? profileData['lastName'] ?? '',
        'phone': profileData['phone'] ?? '',
        // Removendo address pois não existe na tabela customer
      };
      
      print('🔍 Dados para API (sem address): $apiData');
      
      final response = await _dio.put('/customers/$userId/profile', 
        data: apiData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados da resposta: ${response.data}');
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'Erro ao atualizar perfil'};
      }
    } catch (e) {
      print('❌ Erro ao atualizar perfil: $e');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter detalhes da oficina
  Future<Map<String, dynamic>> getWorkshopDetails(String workshopId) async {
    try {
      print('🔍 Buscando detalhes da oficina: $workshopId');
      
      // Como não há endpoint específico, vamos buscar na lista e filtrar
      final response = await _dio.get('/workshops');
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados das oficinas: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        final workshops = response.data['data']['workshops'] as List;
        final workshop = workshops.firstWhere(
          (w) => w['id'] == workshopId,
          orElse: () => null,
        );
        
        if (workshop != null) {
          return {
            'success': true, 
            'data': {
              'workshop': workshop,
              'services': [], // TODO: Implementar busca de serviços
              'reviews': [], // TODO: Implementar busca de avaliações
            }
          };
        } else {
          return {'success': false, 'error': 'Oficina não encontrada'};
        }
      } else {
        return {'success': false, 'error': 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      print('❌ Erro ao buscar oficina: $e');
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
      
      print('🔍 Salvando veículo com dados: $vehicleData');
      print('🔍 Token: ${token.substring(0, 20)}...');
      
      // Obter customer_id
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      // Preparar dados para a API (conforme schema real)
      final apiData = {
        'customer_id': userId,
        'brand': vehicleData['brand'] ?? '',
        'model': vehicleData['model'] ?? '',
        'year': vehicleData['year'] ?? '',
        'plate': vehicleData['plate'] ?? '',
        'is_default': vehicleData['is_default'] ?? true,
      };
      
      print('🔍 Dados para API: $apiData');
      
      final response = await _dio.post('/vehicles', 
        data: apiData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados da resposta: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        String errorMessage = response.data['error'] ?? 'Erro ao salvar veículo';
        
        // Tratar erros específicos
        if (errorMessage.contains('duplicate key value violates unique constraint "vehicle_plate_key"')) {
          errorMessage = 'Esta placa já está cadastrada no sistema. Por favor, use uma placa diferente.';
        } else if (errorMessage.contains('null value in column')) {
          errorMessage = 'Dados inválidos. Verifique se todos os campos estão preenchidos corretamente.';
        }
        
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      print('❌ Erro ao salvar veículo: $e');
      
      String errorMessage = 'Erro de conexão: ${e.toString()}';
      
      // Tratar erros específicos do Dio
      if (e.toString().contains('500')) {
        errorMessage = 'Erro interno do servidor. Tente novamente em alguns minutos.';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Dados inválidos. Verifique se todos os campos estão preenchidos corretamente.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Sessão expirada. Faça login novamente.';
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  // Obter perfil do usuário
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      print('🔍 Buscando perfil do usuário: $userId');
      
      final response = await _dio.get('/customers/$userId');
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados do perfil: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar perfil'};
      }
    } catch (e) {
      print('❌ Erro ao buscar perfil: $e');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter veículos do usuário
  Future<Map<String, dynamic>> getUserVehicles() async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'error': 'ID do usuário não encontrado'};
      }
      
      final response = await _dio.get('/vehicles/$userId');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar veículos'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Cancelar agendamento
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.put('/bookings/$bookingId/cancel', 
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao cancelar agendamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter agendamentos (método antigo para compatibilidade)
  Future<Map<String, dynamic>> getMyBookings(String customerId) async {
    return await getUserBookings();
  }

  // Obter veículos (método antigo para compatibilidade)
  Future<Map<String, dynamic>> getMyVehicles(String customerId) async {
    return await getUserVehicles();
  }

  // Definir veículo padrão
  Future<Map<String, dynamic>> setDefaultVehicle(String vehicleId, String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'error': 'Usuário não autenticado'};
      }
      
      final response = await _dio.put('/vehicles/$vehicleId/set-default', 
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao definir veículo padrão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Recuperar senha
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao enviar email de recuperação'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }


  // Obter detalhes do serviço
  Future<Map<String, dynamic>> getServiceDetails(String serviceId) async {
    try {
      print('🔍 Buscando detalhes do serviço: $serviceId');
      
      // Como não há endpoint específico, vamos buscar na lista e filtrar
      final response = await _dio.get('/services');
      
      print('📡 Status da resposta: ${response.statusCode}');
      print('📡 Dados dos serviços: ${response.data}');
      
      if (response.data != null && response.data['success'] == true) {
        final services = response.data['data']['services'] as List;
        final service = services.firstWhere(
          (s) => s['id'] == serviceId,
          orElse: () => null,
        );
        
        if (service != null) {
          return {
            'success': true, 
            'data': service
          };
        } else {
          return {'success': false, 'error': 'Serviço não encontrado'};
        }
      } else {
        return {'success': false, 'error': 'Erro ao buscar serviços'};
      }
    } catch (e) {
      print('❌ Erro ao buscar serviço: $e');
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

  // Obter histórico de manutenção de um veículo
  Future<Map<String, dynamic>> getMaintenanceHistory(String vehicleId) async {
    try {
      final response = await _dio.get('/maintenance-history', queryParameters: {
        'vehicleId': vehicleId,
      });

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar histórico de manutenção'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter evidências de um agendamento
  Future<Map<String, dynamic>> getBookingEvidence(String bookingId) async {
    try {
      final response = await _dio.get('/booking/$bookingId/evidence');

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar evidências'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Sugerir novo horário para agendamento
  Future<Map<String, dynamic>> suggestSchedule(
    String bookingId,
    String newDate,
    String suggestedBy,
  ) async {
    try {
      final response = await _dio.post('/booking/$bookingId/suggest-schedule', data: {
        'newDate': newDate,
        'suggestedBy': suggestedBy,
      });

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao sugerir horário'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Aceitar sugestão de horário
  Future<Map<String, dynamic>> acceptSchedule(String bookingId) async {
    try {
      final response = await _dio.post('/booking/$bookingId/accept-schedule');

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao aceitar sugestão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
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
