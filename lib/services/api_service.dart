import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

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

    // Adicionar interceptor para incluir token automaticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        return handler.next(error);
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
  Future<Map<String, dynamic>> register(String firstName, String email, String password, String phone, String cpf) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'email': email,
        'password': password,
        'phone': phone,
        'cpf': cpf,
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

  // Buscar veículo por placa - API REAL na EC2
  Future<Map<String, dynamic>> searchVehicleByPlate(String plate) async {
    try {
      await loadToken();
      // Limpar placa (remover espaços, hífens)
      String cleanPlate = plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      
      if (cleanPlate.length < 7 || cleanPlate.length > 8) {
        return {
          'success': false,
          'error': 'Placa inválida. Use o formato ABC1234 ou ABC1D23'
        };
      }
      
      print('🔍 Buscando veículo pela placa na API: $cleanPlate');
      final response = await _dio.get('/vehicles/plate/$cleanPlate');
      
      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'data': response.data['data']
        };
      } else {
        return {
          'success': false,
          'error': response.data['error'] ?? 'Veículo não encontrado'
        };
      }
    } catch (e) {
      print('❌ Erro ao buscar placa: $e');
      return {
        'success': false,
        'error': _getErrorMessage(e)
      };
    }
  }

  // Obter oficinas próximas (com raio em km)
  Future<Map<String, dynamic>> getNearbyWorkshops(double lat, double lng, [double radiusKm = 10.0]) async {
    try {
      // Se /workshop/nearby falhar, usar /workshop como fallback
      try {
        final response = await _dio.get('/workshop/nearby', queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusKm': radiusKm.toString(),
        });
        
        if (response.data != null && response.data['success'] == true) {
          final data = response.data['data'];
          List<dynamic> workshops = [];
          
          // Adaptar resposta para diferentes formatos
          if (data is Map) {
            workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
          } else if (data is List) {
            workshops = data;
          } else if (response.data['workshops'] != null) {
            workshops = response.data['workshops'];
          } else if (response.data['workshop'] != null) {
            workshops = response.data['workshop'];
          }
          
          return {'success': true, 'data': {'workshops': workshops}};
        }
      } catch (e) {
        print('⚠️ Endpoint /workshop/nearby falhou, usando fallback: $e');
      }
      
      // Fallback: usar /workshop e filtrar client-side
      final response = await _dio.get('/workshop', queryParameters: {
        'limit': 100,
      });
      
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> workshops = [];
        
        if (data is Map) {
          workshops = data['workshop'] ?? data['workshops'] ?? data['data'] ?? [];
        } else if (data is List) {
          workshops = data;
        }
        
        return {'success': true, 'data': {'workshops': workshops}};
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
      final response = await _dio.get('/workshop');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter detalhes de uma oficina específica
  Future<Map<String, dynamic>> getWorkshopDetails(String workshopId) async {
    try {
      final response = await _dio.get('/workshop/$workshopId');
      
      if (response.data != null && response.data['success'] == true) {
        // Adaptar resposta para diferentes formatos
        final data = response.data['data'];
        Map<String, dynamic> workshop;
        
        if (data is Map) {
          // Se data já é um Map, usar diretamente ou buscar 'workshop'
          workshop = data['workshop'] ?? data;
        } else {
          workshop = {'id': workshopId};
        }
        
        return {'success': true, 'data': {'workshop': workshop}};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar detalhes da oficina'};
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
        // Adaptar resposta para diferentes formatos
        final data = response.data['data'];
        List<dynamic> services = [];
        
        if (data is Map) {
          // Se data é um Map, verificar se tem 'services' ou 'data'
          services = data['services'] ?? data['data'] ?? [];
        } else if (data is List) {
          // Se data já é uma List
          services = data;
        } else if (response.data['services'] != null) {
          // Se services está no nível raiz
          services = response.data['services'];
        }
        
        return {'success': true, 'data': services};
      } else {
        return {'success': false, 'error': 'Erro ao buscar serviços'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter perfil do usuário
  Future<Map<String, dynamic>> getProfile() async {
    try {
      await loadToken();
      final response = await _dio.get('/customers/profile');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar perfil'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Alias para getUserProfile (usado pelo profile_screen)
  Future<Map<String, dynamic>> getUserProfile() async {
    return getProfile();
  }

  // Obter agendamentos do usuário
  Future<Map<String, dynamic>> getBookings() async {
    try {
      await loadToken();
      final response = await _dio.get('/bookings');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar agendamentos'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Alias para getUserBookings (mantido para compatibilidade)
  Future<Map<String, dynamic>> getUserBookings() async {
    return getBookings();
  }

  // Criar agendamento
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    try {
      await loadToken();
      final response = await _dio.post('/bookings', data: bookingData);
      
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
      await loadToken();
      // Mapear campos do cliente para formato da API
      final apiData = {
        'first_name': profileData['firstName'] ?? profileData['first_name'],
        'last_name': profileData['lastName'] ?? profileData['last_name'],
        'phone': profileData['phone'],
        'cpf': profileData['cpf'],
      };
      
      final response = await _dio.put('/customers/profile', data: apiData);
      
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
      await loadToken();
      final response = await _dio.post('/vehicles', data: vehicleData);
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao adicionar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Atualizar veículo
  Future<Map<String, dynamic>> updateVehicle(String vehicleId, Map<String, dynamic> vehicleData) async {
    try {
      await loadToken();
      final response = await _dio.put('/vehicles/$vehicleId', data: vehicleData);
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao atualizar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter veículos do usuário
  Future<Map<String, dynamic>> getUserVehicles() async {
    try {
      await loadToken();
      final response = await _dio.get('/vehicles');
      
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
    // Limpar todos os dados do usuário para evitar cache
    await prefs.clear();
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

  // Carregar token (alias para getToken para compatibilidade)
  Future<void> loadToken() async {
    // O token já é carregado automaticamente pelo interceptor
    // Este método existe apenas para compatibilidade
  }

  // Obter veículos do cliente específico
  Future<Map<String, dynamic>> getMyVehicles(String customerId) async {
    try {
      await loadToken();
      final response = await _dio.get('/vehicles', queryParameters: {'customer_id': customerId});
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': 'Erro ao buscar veículos'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Definir veículo como padrão
  Future<Map<String, dynamic>> setDefaultVehicle(String vehicleId, String customerId) async {
    try {
      await loadToken();
      final response = await _dio.put('/vehicles/$vehicleId/default', data: {'customer_id': customerId});
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao definir veículo padrão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Favoritar/desfavoritar veículo
  Future<Map<String, dynamic>> toggleFavoriteVehicle(String vehicleId, bool isFavorite) async {
    try {
      await loadToken();
      final response = await _dio.put('/vehicles/$vehicleId/favorite', data: {'is_favorite': isFavorite});
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao favoritar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Cancelar agendamento
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/cancel');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao cancelar agendamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Recuperar senha
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {'email': email});
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Email enviado com sucesso'};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao enviar email'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter notificações recentes
  Future<Map<String, dynamic>> getNotifications({int limit = 20, bool? read}) async {
    try {
      await loadToken();
      final queryParams = <String, dynamic>{'limit': limit};
      if (read != null) {
        queryParams['read'] = read.toString();
      }
      
      final response = await _dio.get('/notifications', queryParameters: queryParams);
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data'] ?? []};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar notificações'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Marcar notificação como lida
  Future<Map<String, dynamic>> markNotificationRead(String notificationId) async {
    try {
      await loadToken();
      final response = await _dio.put('/notifications/$notificationId/read');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao marcar notificação'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Marcar todas as notificações como lidas
  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      await loadToken();
      final response = await _dio.put('/notifications/read-all');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao marcar notificações'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Ativar/desativar lembretes de agendamento
  Future<Map<String, dynamic>> toggleBookingReminder(String bookingId, bool enabled) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/reminder', data: {'enabled': enabled});
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data'], 'message': response.data['message']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao atualizar lembretes'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter evidências do agendamento
  Future<Map<String, dynamic>> getBookingEvidence(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.get('/bookings/$bookingId/evidence');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar evidências'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter detalhes do serviço
  Future<Map<String, dynamic>> getServiceDetails(String serviceId) async {
    try {
      final response = await _dio.get('/services/$serviceId');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar detalhes do serviço'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter oficinas que oferecem um serviço específico
  Future<Map<String, dynamic>> getWorkshopsByService(String serviceId, {double? lat, double? lng, double? radiusKm}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (lat != null && lng != null && radiusKm != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
        queryParams['radiusKm'] = radiusKm;
      }
      
      final response = await _dio.get('/services/$serviceId/workshops', queryParameters: queryParams);
      
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> workshops = [];
        
        // Adaptar resposta para diferentes formatos
        if (data is Map) {
          workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
        } else if (data is List) {
          workshops = data;
        }
        
        return {'success': true, 'data': workshops};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter histórico de manutenção do veículo
  Future<Map<String, dynamic>> getMaintenanceHistory(String vehicleId) async {
    try {
      await loadToken();
      
      // Obter customerId do perfil
      String? customerId;
      try {
        final profileResult = await getProfile();
        if (profileResult['success'] && profileResult['data'] != null) {
          customerId = profileResult['data']['id'] ?? 
                      profileResult['data']['customer_id'];
        }
      } catch (e) {
        print('Erro ao obter perfil para histórico: $e');
      }
      
      final queryParams = <String, dynamic>{'vehicleId': vehicleId};
      if (customerId != null && customerId.isNotEmpty) {
        queryParams['customerId'] = customerId;
      }
      
      final response = await _dio.get('/maintenance-history', queryParameters: queryParams);
      
      if (response.data != null && response.data['success'] == true) {
        // Adaptar resposta para usar nomes de colunas corretos do banco
        final data = response.data['data'];
        final history = (data is List ? data : (data is Map && data['maintenanceHistory'] != null ? data['maintenanceHistory'] : [])) as List;
        
        final adaptedHistory = history.map<Map<String, dynamic>>((item) {
          // Converter price para double se necessário
          double? pricePaid = 0.0;
          if (item['price'] != null) {
            if (item['price'] is String) {
              pricePaid = double.tryParse(item['price'].toString().replaceAll('R\$', '').replaceAll(',', '.').trim()) ?? 0.0;
            } else if (item['price'] is num) {
              pricePaid = item['price'].toDouble();
            } else {
              pricePaid = 0.0;
            }
          }
          
          // Converter data de serviço
          String? serviceDateStr;
          if (item['service_date'] != null) {
            serviceDateStr = item['service_date'].toString();
          } else if (item['appointment_date'] != null) {
            serviceDateStr = item['appointment_date'].toString();
          } else if (item['completed_at'] != null) {
            serviceDateStr = item['completed_at'].toString();
          } else if (item['created_at'] != null) {
            serviceDateStr = item['created_at'].toString();
          }
          
          return {
            'id': item['id']?.toString() ?? '',
            'vehicle_id': item['vehicle_id']?.toString() ?? '',
            'customer_id': item['customer_id']?.toString() ?? '',
            'workshop_id': item['workshop_id']?.toString() ?? '',
            'workshop_name': (item['oficina_name'] ?? item['workshop_name'] ?? 'Oficina').toString(),
            'workshop_address': (item['oficina_address'] ?? item['workshop_address'] ?? '').toString(),
            'workshop_phone': (item['oficina_phone'] ?? item['workshop_phone'] ?? '').toString(),
            'service_name': (item['service_name'] ?? item['service_type'] ?? 'Serviço').toString(),
            'service_description': (item['service_description'] ?? item['description'] ?? '').toString(),
            'price_paid': pricePaid,
            'service_date': serviceDateStr ?? '',
            'completion_date': (item['completed_at'] ?? item['completion_date'] ?? item['created_at'] ?? '').toString(),
            'notes': (item['description'] ?? item['customer_notes'] ?? '').toString(),
            'created_at': (item['created_at'] ?? '').toString(),
            'booking_status': (item['booking_status'] ?? item['status'] ?? '').toString(),
          };
        }).toList();
        
        return {
          'success': true,
          'data': adaptedHistory,
        };
      } else {
        return {'success': false, 'error': response.data?['error'] ?? 'Erro ao buscar histórico'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Sugerir horário para agendamento
  Future<Map<String, dynamic>> suggestSchedule(String bookingId, String scheduledDateTime, String suggestedBy) async {
    try {
      await loadToken();
      final response = await _dio.post('/bookings/$bookingId/suggest-schedule', data: {
        'scheduled_date': scheduledDateTime,
        'suggested_by': suggestedBy,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao sugerir horário'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Aceitar sugestão de horário
  Future<Map<String, dynamic>> acceptSchedule(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/accept-schedule');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao aceitar horário'};
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

  // Obter horários disponíveis da oficina
  Future<Map<String, dynamic>> getAvailableHours(String workshopId, DateTime date) async {
    try {
      await loadToken();
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.get('/workshops/$workshopId/available-hours', queryParameters: {
        'date': dateString,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar horários'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Upload de imagem do agendamento
  Future<Map<String, dynamic>> uploadBookingImage(String bookingId, File imageFile) async {
    try {
      await loadToken();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post('/bookings/$bookingId/images', data: formData);
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao fazer upload'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Avaliar serviço
  Future<Map<String, dynamic>> submitRating({
    required String bookingId,
    required String workshopId,
    required int rating,
    String? comment,
  }) async {
    try {
      await loadToken();
      // Obter customerId do perfil primeiro
      final profileResult = await getProfile();
      String? customerId;
      
      if (profileResult['success'] && profileResult['data'] != null) {
        customerId = profileResult['data']['id'] ?? profileResult['data']['customer_id'];
      }

      if (customerId == null || customerId.isEmpty) {
        return {'success': false, 'error': 'Não foi possível identificar o usuário'};
      }

      final response = await _dio.post('/ratings', data: {
        'customerId': customerId,
        'workshopId': workshopId,
        'rating': rating,
        'comment': comment ?? '',
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao avaliar'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Salvar cartão de crédito (direto com API que tokeniza internamente)
  Future<Map<String, dynamic>> saveCardDirect({
    required String customerId,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
    bool isDefault = false,
  }) async {
    try {
      await loadToken();
      final response = await _dio.post('/saved-cards', data: {
        'customerId': customerId,
        'cardNumber': cardNumber,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cvv': cvv,
        'holderName': holderName,
        'isDefault': isDefault,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao salvar cartão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Salvar cartão de crédito (com token já gerado)
  Future<Map<String, dynamic>> saveCard({
    required String cardToken,
    required String lastDigits,
    required String brand,
    bool isDefault = false,
  }) async {
    try {
      await loadToken();
      final response = await _dio.post('/saved-cards', data: {
        'card_token': cardToken,
        'last_digits': lastDigits,
        'brand': brand,
        'is_default': isDefault,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao salvar cartão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter cartões salvos
  Future<Map<String, dynamic>> getSavedCards() async {
    try {
      await loadToken();
      final response = await _dio.get('/saved-cards');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar cartões'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter detalhes de um agendamento específico
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.get('/bookings/$bookingId');
      
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        
        // Garantir que data é um Map, não uma List
        if (data is List && data.isNotEmpty) {
          return {'success': true, 'data': data[0]};
        } else if (data is Map) {
          return {'success': true, 'data': data};
        } else {
          return {'success': false, 'error': 'Formato de dados inválido'};
        }
      } else {
        return {'success': false, 'error': response.data?['error'] ?? 'Erro ao buscar agendamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Definir cartão como padrão
  Future<Map<String, dynamic>> setDefaultCard(String cardId) async {
    try {
      await loadToken();
      final response = await _dio.put('/saved-cards/$cardId/set-default');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao definir cartão como padrão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter configurações de notificações
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      await loadToken();
      final response = await _dio.get('/notification-settings');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        // Se não existir, retornar valores padrão
        return {
          'success': true,
          'data': {
            'push_notifications': true,
            'email_notifications': true,
            'sms_notifications': false,
            'marketing_notifications': false,
            'booking_reminders': true,
            'service_updates': true,
            'promotions': false,
          }
        };
      }
    } catch (e) {
      // Se der erro, retornar valores padrão
      return {
        'success': true,
        'data': {
          'push_notifications': true,
          'email_notifications': true,
          'sms_notifications': false,
          'marketing_notifications': false,
          'booking_reminders': true,
          'service_updates': true,
          'promotions': false,
        }
      };
    }
  }

  // Atualizar configurações de notificações
  Future<Map<String, dynamic>> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      await loadToken();
      final response = await _dio.put('/notification-settings', data: settings);
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao atualizar configurações'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Remover cartão salvo
  Future<Map<String, dynamic>> deleteCard(String cardId) async {
    try {
      await loadToken();
      final response = await _dio.delete('/saved-cards/$cardId');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao remover cartão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }
}












