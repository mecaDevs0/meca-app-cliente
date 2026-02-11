import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/http_client_config.dart';
import '../utils/logger.dart';

class ApiService {
  late Dio _dio;
  final Map<String, _CacheEntry> _cache = {};
  static const int _kMaxCacheEntries = 150;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectionTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'gzip',
        'x-publishable-api-key': 'pk_8913f91e8557d24f01440879c36cdb8c81e6ef346ec9a14dc6582ba87d06e9e9',
      },
    ));

    configureDioForProduction(_dio);

    // Adicionar interceptor para incluir token automaticamente e cache
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Verificar cache para requisições GET (mas não se skipCache estiver ativo)
        if (options.method == 'GET' && options.extra['skipCache'] != true) {
          final cacheKey = _getCacheKey(options.uri.toString(), options.queryParameters);
          final cached = _cache[cacheKey];
          if (cached != null && !cached.isExpired) {
            AppLogger.cache('HIT', cacheKey);
            return handler.resolve(Response(
              requestOptions: options,
              data: cached.data,
              statusCode: 200,
            ));
          }
          AppLogger.cache('MISS', cacheKey);
        } else if (options.extra['skipCache'] == true) {
          AppLogger.cache('SKIP', options.uri.toString());
        }
        
        AppLogger.api(options.method, options.uri.toString());
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Cachear respostas GET bem-sucedidas
        if (response.requestOptions.method == 'GET' &&
            response.statusCode == 200 &&
            response.requestOptions.extra['skipCache'] != true) {
          final cacheKey = _getCacheKey(
            response.requestOptions.uri.toString(),
            response.requestOptions.queryParameters,
          );
          _evictCacheIfNeeded();
          _cache[cacheKey] = _CacheEntry(response.data, DateTime.now());
          AppLogger.cache('SET', cacheKey);
        }
        AppLogger.api(
          response.requestOptions.method,
          response.requestOptions.uri.toString(),
          statusCode: response.statusCode,
        );
        return handler.next(response);
      },
      onError: (error, handler) {
        // Logs organizados usando logger
        final url = error.requestOptions.uri.toString();
        final method = error.requestOptions.method;
        
        if (error.response != null) {
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 || statusCode == 403) {
            // Silenciar erros de autenticação (são esperados)
          } else {
            AppLogger.api(method, url, statusCode: statusCode, error: error.response?.statusMessage);
          }
        } else if (error.type == DioExceptionType.connectionTimeout || 
                   error.type == DioExceptionType.receiveTimeout) {
          AppLogger.warning('Timeout na requisição: $method $url', tag: 'API');
        } else {
          AppLogger.error('Erro de rede: ${error.message}', tag: 'API', error: error);
        }
        return handler.next(error);
      },
    ));
  }

  String _getCacheKey(String url, Map<String, dynamic>? params) {
    if (url.contains('?')) return url;
    if (params == null || params.isEmpty) return url;
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    return '$url?${Uri(queryParameters: sortedParams.map((k, v) => MapEntry(k.toString(), v.toString()))).query}';
  }

  void _evictCacheIfNeeded() {
    if (_cache.length < _kMaxCacheEntries) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    final toRemove = entries.length - (_kMaxCacheEntries ~/ 2).clamp(50, _kMaxCacheEntries - 20);
    for (var i = 0; i < toRemove && i < entries.length; i++) {
      _cache.remove(entries[i].key);
    }
  }

  void clearCache() {
    _cache.clear();
  }

  void clearExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  // Invalidar cache específico de bookings
  void invalidateBookingsCache() {
    _cache.removeWhere((key, entry) {
      return key.contains('/bookings') || key.contains('customer_id');
    });
  }

  // Invalidar cache de um booking específico
  void invalidateBookingCache(String bookingId) {
    _cache.removeWhere((key, entry) {
      return key.contains('/bookings/$bookingId') || 
             key.contains('/bookings?') ||
             (key.contains('/bookings') && key.contains(bookingId));
    });
  }

  // Invalidar cache de perfil
  void invalidateProfileCache() {
    _cache.removeWhere((key, entry) {
      return key.contains('/customers/profile') || 
             key.contains('/profile');
    });
  }

  // Invalidar cache de veículos
  void invalidateVehiclesCache() {
    _cache.removeWhere((key, entry) {
      return key.contains('/vehicles') || 
             key.contains('/vehicle');
    });
  }

  // Invalidar cache de cartões salvos
  void invalidateSavedCardsCache() {
    _cache.removeWhere((key, entry) {
      return key.contains('/saved-cards');
    });
  }

  Future<void> _persistAuthSession(Map<String, dynamic>? payload) async {
    if (payload == null) return;
    final token = payload['token'];
    final user = payload['user'];

    if (token == null && user == null) return;

    if (token is String && user is Map && user['id'] != null) {
      await setSession(token, user['id'].toString());
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (token is String) {
      await prefs.setString('token', token);
    }
    if (user is Map && user['id'] != null) {
      await prefs.setString('user_id', user['id'].toString());
    }
  }

  Future<Map<String, dynamic>> _handleAuthResponse(
    Response response, {
    String fallbackError = 'Erro ao autenticar',
  }) async {
    final data = response.data;
    
    AppLogger.info('🔍 [Auth] Processando resposta: success=${data?['success']}', tag: 'Auth');
    
    if (data != null && data['success'] == true) {
      final responseData = data['data'];
      AppLogger.info('✅ [Auth] Login bem-sucedido, persistindo sessão...', tag: 'Auth');
      AppLogger.info('📦 [Auth] Token presente: ${responseData?['token'] != null}', tag: 'Auth');
      AppLogger.info('📦 [Auth] User presente: ${responseData?['user'] != null}', tag: 'Auth');
      
      await _persistAuthSession(responseData);
      return {'success': true, 'data': responseData};
    }
    
    final errorMessage = data?['error'] ?? fallbackError;
    AppLogger.warning('⚠️ [Auth] Login falhou: $errorMessage', tag: 'Auth');
    return {'success': false, 'error': errorMessage};
  }

  // Login (com retry em caso de timeout para API instável)
  Future<Map<String, dynamic>> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    AppLogger.info('🔐 [Login] Tentando login para: $normalizedEmail', tag: 'Auth');

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _dio.post('/auth/login', data: {
          'email': normalizedEmail,
          'password': normalizedPassword,
        });
        AppLogger.info('✅ [Login] Resposta recebida: ${response.statusCode}', tag: 'Auth');
        return await _handleAuthResponse(response, fallbackError: 'Erro no login');
      } catch (e) {
        final isTimeout = e is DioException &&
            (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout);
        if (isTimeout && attempt == 1) {
          AppLogger.warning('⚠️ [Login] Timeout, tentando novamente (2/2)', tag: 'Auth');
          continue;
        }
        AppLogger.error('❌ [Login] Erro: ${e.toString()}', tag: 'Auth', error: e);
        if (e is DioException) {
          final message = _resolveFriendlyMessage(e, default401: 'Email ou senha incorretos. Confira seus dados e tente novamente.');
          return {'success': false, 'error': message};
        }
        return {'success': false, 'error': 'Não foi possível entrar. Verifique sua conexão e tente novamente.'};
      }
    }
    return {'success': false, 'error': 'Não foi possível entrar. Verifique sua conexão e tente novamente.'};
  }

  // Registro
  Future<Map<String, dynamic>> register(String firstName, String email, String password, String phone, String cpf) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedPassword = password.trim();

      final response = await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'email': normalizedEmail,
        'password': normalizedPassword,
        'phone': phone,
        'cpf': cpf,
      });

      return await _handleAuthResponse(response, fallbackError: 'Erro no registro');
    } catch (e) {
      if (e is DioException) {
        final message = _resolveFriendlyMessage(e, default400: 'Não foi possível criar a conta. Verifique os dados informados.');
        return {'success': false, 'error': message};
      }
      return {'success': false, 'error': 'Não foi possível concluir o cadastro. Tente novamente em instantes.'};
    }
  }


  Future<void> setSession(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user_id', userId);
  }

  Future<SharedPreferences> getStorage() async {
    return await SharedPreferences.getInstance();
  }

  // ============================================
  // DEVICE TOKENS - PUSH NOTIFICATIONS
  // ============================================

  Future<Map<String, dynamic>> saveDeviceToken(String onesignalPlayerId, {String? platform}) async {
    try {
      await loadToken();
      final response = await _dio.post(
        '/device-tokens',
        data: {
          'onesignal_player_id': onesignalPlayerId,
          'platform': platform ?? (Platform.isAndroid ? 'android' : 'ios'),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      return {'success': true, 'data': response.data['data'] ?? response.data};
    } catch (e) {
      if (e is DioException) {
        return {'success': false, 'error': e.response?.data['error'] ?? 'Erro ao salvar token'};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeDeviceToken(String onesignalPlayerId) async {
    try {
      await loadToken();
      
      final response = await _dio.delete('/device-tokens', data: {
        'onesignal_player_id': onesignalPlayerId,
      });
      
      return {'success': true, 'data': response.data['data'] ?? response.data};
    } catch (e) {
      if (e is DioException) {
        return {'success': false, 'error': e.response?.data['error'] ?? 'Erro ao remover token'};
      }
      return {'success': false, 'error': e.toString()};
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
      // Timeout específico para busca de placas: 90s (API externa pode ser lenta)
      final response = await _dio.get(
        '/vehicles/plate/$cleanPlate',
        options: Options(
          receiveTimeout: const Duration(seconds: 90), // 90s para busca de placas
          sendTimeout: const Duration(seconds: 90),
        ),
      );
      
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
  // Se searchQuery for fornecido, busca por nome independente de distância
  Future<Map<String, dynamic>> getNearbyWorkshops(double lat, double lng, [double radiusKm = 10.0, String? searchQuery]) async {
    try {
      final queryParams = <String, dynamic>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radiusKm.toString(),
      };
      
      // Se tiver busca por nome, adicionar parâmetro 'q'
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        queryParams['q'] = searchQuery.trim();
      }
      
      // Usar /workshop diretamente; skipCache para sempre trazer logos atualizados da API
      final response = await _dio.get(
        '/workshop',
        queryParameters: queryParams,
        options: Options(extra: {'skipCache': true}),
      );
      
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
        
        return {'success': true, 'data': workshops};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar oficinas'};
      }
    } catch (e) {
      print('❌ Erro ao buscar oficinas próximas: $e');
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter todas as oficinas (API retorna data: { workshops } ou data como lista)
  Future<Map<String, dynamic>> getAllWorkshops() async {
    try {
      final response = await _dio.get('/workshop');
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> workshops = [];
        if (data is Map) {
          workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
        } else if (data is List) {
          workshops = data;
        }
        return {'success': true, 'data': workshops};
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
          // IMPORTANTE: Preservar 'schedule' que vem do banco RDS AWS
          workshop = data['workshop'] ?? data;
          // Garantir que 'schedule' está presente (vem do banco via WorkshopRepository.getSchedule)
          if (data['schedule'] != null && workshop['schedule'] == null) {
            workshop['schedule'] = data['schedule'];
          }
        } else {
          workshop = {'id': workshopId};
        }
        
        return {'success': true, 'data': workshop};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar detalhes da oficina'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getWorkshopServices(String workshopId) async {
    try {
      final response = await _dio.get('/workshop/$workshopId/services');

      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'] ?? response.data['services'];
        return {'success': true, 'data': data ?? []};
      } else {
        return {
          'success': false,
          'error': response.data?['error'] ?? 'Erro ao buscar serviços da oficina'
        };
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

  // Obter perfil do usuário (com retry em timeout para API instável)
  Future<Map<String, dynamic>> getProfile({bool forceRefresh = false}) async {
    await loadToken();
    if (forceRefresh) invalidateProfileCache();
    final queryParams = forceRefresh ? {'_t': DateTime.now().millisecondsSinceEpoch.toString()} : null;
    final options = Options(extra: forceRefresh ? {'skipCache': true} : {});

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _dio.get(
          '/customers/profile',
          queryParameters: queryParams,
          options: options,
        );
        if (response.data != null && response.data['success'] == true) {
          return {'success': true, 'data': response.data['data']};
        }
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao buscar perfil'};
      } catch (e) {
        final isTimeout = e is DioException &&
            (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout);
        if (isTimeout && attempt == 1) {
          AppLogger.warning('⚠️ [API] Timeout em /customers/profile, tentando novamente (2/2)', tag: 'API');
          continue;
        }
        return {'success': false, 'error': _getErrorMessage(e)};
      }
    }
    return {'success': false, 'error': 'Timeout de conexão. Verifique sua internet.'};
  }

  // Alias para getUserProfile (usado pelo profile_screen)
  Future<Map<String, dynamic>> getUserProfile({bool forceRefresh = false}) async {
    return getProfile(forceRefresh: forceRefresh);
  }

  // Obter agendamentos do usuário
  Future<Map<String, dynamic>> getBookings() async {
    try {
      await loadToken();
      final userId = await getUserId();
      final queryParams = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['customer_id'] = userId;
      }

      final response = await _dio.get(
        '/bookings',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        final bookings = _normalizeToListOfMaps(data);

        List<Map<String, dynamic>> mapWithUploads = bookings
            .map((booking) => _enrichBooking(Map<String, dynamic>.from(booking)))
            .toList();

        if (userId != null && userId.isNotEmpty && mapWithUploads.isNotEmpty) {
          final filtered = mapWithUploads.where((booking) {
            final bookingCustomer = booking['customer_id'] ??
                booking['customerId'] ??
                booking['customer']?['id'] ??
                booking['customer']?['customer_id'];
            if (bookingCustomer == null) return false;
            return bookingCustomer.toString() == userId;
          }).toList();
          return {'success': true, 'data': filtered};
        }

        return {'success': true, 'data': mapWithUploads};
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
        // Invalidar cache de perfil após atualização
        invalidateProfileCache();
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
        // Invalidar cache de veículos após adicionar
        invalidateVehiclesCache();
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
        // Invalidar cache de veículos após atualizar
        invalidateVehiclesCache();
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao atualizar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Remover veículo
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    try {
      await loadToken();
      final response = await _dio.delete('/vehicles/$vehicleId');
      
      if (response.data != null && response.data['success'] == true) {
        // Invalidar cache de veículos após deletar
        invalidateVehiclesCache();
        return {'success': true, 'message': response.data['message'] ?? 'Veículo removido com sucesso'};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao remover veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter veículos do usuário
  Future<Map<String, dynamic>> getUserVehicles() async {
    try {
      await loadToken();
      final userId = await getUserId();
      final queryParams = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['customer_id'] = userId;
      }

      final response = await _dio.get(
        '/vehicles',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      
      if (response.data != null && response.data['success'] == true) {
        final vehicles = _normalizeToListOfMaps(response.data['data']);

        if (userId != null && userId.isNotEmpty && vehicles.isNotEmpty) {
          final filtered = vehicles.where((vehicle) {
            final ownerId = vehicle['customer_id'] ??
                vehicle['customerId'] ??
                vehicle['customer']?['id'];
            if (ownerId == null) return false;
            return ownerId.toString() == userId;
          }).toList();
          return {'success': true, 'data': filtered};
        }

        return {'success': true, 'data': vehicles};
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
        final vehicles = _normalizeToListOfMaps(response.data['data']).where((vehicle) {
          final ownerId = vehicle['customer_id'] ??
              vehicle['customerId'] ??
              vehicle['customer']?['id'];
          if (ownerId == null) return false;
          return ownerId.toString() == customerId;
        }).toList();

        return {'success': true, 'data': vehicles};
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
        // Invalidar cache de veículos após favoritar
        invalidateVehiclesCache();
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao favoritar veículo'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Cancelar agendamento
  // Aprovar orçamento proposto pela oficina
  Future<Map<String, dynamic>> confirmServiceStart(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/confirm-service-start');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao confirmar início do serviço'};
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?.toString() ?? 
                            e.message ??
                            'Erro ao confirmar início do serviço';
        return {'success': false, 'error': errorMessage};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Rejeitar início do serviço quando a oficina iniciou
  Future<Map<String, dynamic>> rejectServiceStart(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/reject-service-start');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao rejeitar início do serviço'};
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?.toString() ?? 
                            e.message ??
                            'Erro ao rejeitar início do serviço';
        return {'success': false, 'error': errorMessage};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // Cancelar agendamento
  // Aprovar orçamento proposto pela oficina
  Future<Map<String, dynamic>> approveQuote(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/approve-quote');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao aprovar orçamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Rejeitar orçamento proposto pela oficina
  Future<Map<String, dynamic>> rejectQuote(String bookingId, {String? reason}) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/reject-quote', data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao rejeitar orçamento'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  /// Aprovar finalização do serviço (cliente)
  Future<Map<String, dynamic>> approveFinalization(String bookingId) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/approve-finalization');

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao aprovar finalização'};
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?.toString() ??
            e.message ??
            'Erro ao aprovar finalização';
        return {'success': false, 'error': errorMessage};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Rejeitar finalização do serviço (cliente) -> vira disputa
  Future<Map<String, dynamic>> rejectFinalization(String bookingId, {String? reason}) async {
    try {
      await loadToken();
      final response = await _dio.put('/bookings/$bookingId/reject-finalization', data: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao rejeitar finalização'};
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data?['error']?.toString() ??
            e.message ??
            'Erro ao rejeitar finalização';
        return {'success': false, 'error': errorMessage};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

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

  // Redefinir senha com token
  Future<Map<String, dynamic>> resetPassword(String token, String password) async {
    try {
      final response = await _dio.post('/auth/reset-password', data: {
        'token': token,
        'password': password,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Senha redefinida com sucesso'};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao redefinir senha'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Alterar senha no perfil
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await loadToken();
      final response = await _dio.put('/customers/profile/password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'message': response.data['message'] ?? 'Senha alterada com sucesso'};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao alterar senha'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter notificações recentes (sempre sem cache para dados atualizados)
  Future<Map<String, dynamic>> getNotifications({int limit = 20, bool? read}) async {
    try {
      await loadToken();
      final queryParams = <String, dynamic>{'limit': limit};
      if (read != null) {
        queryParams['read'] = read.toString();
      }
      
      final response = await _dio.get(
        '/notifications',
        queryParameters: queryParams,
        options: Options(extra: {'skipCache': true}),
      );
      
      if (response.data != null && response.data['success'] == true) {
        final payload = response.data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, 'data': payload};
        }
        if (payload is List) {
          final list = payload.whereType<Map>().map<Map<String, dynamic>>((n) {
            if (n is Map<String, dynamic>) return Map<String, dynamic>.from(n);
            return Map<String, dynamic>.from(n as Map);
          }).toList();
          return {
            'success': true,
            'data': {
              'notifications': list,
              'unread_count': list.where((n) => !(n['read'] == true || n['is_read'] == true)).length,
            },
          };
        }
        return {'success': true, 'data': {'notifications': const [], 'unread_count': 0}};
      } else {
        return {'success': false, 'error': response.data?['error'] ?? 'Erro ao buscar notificações'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  List<Map<String, dynamic>> _normalizeToListOfMaps(dynamic data) {
    if (data is List) {
      return data
          .whereType<Object>()
          .map<Map<String, dynamic>>((item) {
            if (item is Map<String, dynamic>) {
              return Map<String, dynamic>.from(item);
            }
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          })
          .toList();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['data'] ??
          map['items'] ??
          map['bookings'] ??
          map['vehicles'] ??
          map['records'];
      return _normalizeToListOfMaps(nested);
    }

    return const [];
  }

  List<Map<String, dynamic>> _extractUploads(dynamic raw) {
    if (raw == null) {
      return const [];
    }

    if (raw is List) {
      return raw.whereType<Object>().map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return Map<String, dynamic>.from(item);
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((item) => item.isNotEmpty).toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        return _extractUploads(decoded);
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  Map<String, dynamic> _enrichBooking(Map<String, dynamic> booking) {
    final uploads = _extractUploads(
      booking['customer_uploads'] ?? booking['customerUploads'],
    );
    booking['customer_uploads'] = uploads;
    booking['customerUploads'] = uploads;

    if (booking['notes'] == null && booking['customer_notes'] != null) {
      booking['notes'] = booking['customer_notes'];
    }

    return booking;
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
      // Tentar novo endpoint primeiro
      try {
        final response = await _dio.put('/bookings/$bookingId/accept-time');
        if (response.data != null && response.data['success'] == true) {
          return {'success': true, 'data': response.data['data']};
        }
      } catch (_) {
        // Fallback para endpoint antigo
      }
      
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

  // Recusar sugestão de horário (cancela o agendamento)
  Future<Map<String, dynamic>> rejectTimeSuggestion(String bookingId) async {
    try {
      await loadToken();
      // Usar endpoint dedicado de rejeitar horário
      final response = await _dio.put('/bookings/$bookingId/reject-time');
      
      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao recusar sugestão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  String _resolveFriendlyMessage(DioException error, {String? default400, String? default401}) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractServerMessage(error.response?.data);

    // Priorizar mensagem do servidor se disponível
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      return serverMessage.trim();
    }

    // Tratamento específico por status code
    if (statusCode == 429) {
      return 'Muitas tentativas de login. Aguarde alguns minutos e tente novamente.';
    }

    if (statusCode == 401 && default401 != null) {
      return default401;
    }

    if (statusCode == 403) {
      return 'Acesso negado. Verifique suas credenciais.';
    }

    if (statusCode == 400 && default400 != null) {
      return default400;
    }

    if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
      return 'Serviço temporariamente indisponível. Tente novamente em instantes.';
    }

    return _getErrorMessage(error);
  }

  String? _extractServerMessage(dynamic responseData) {
    if (responseData == null) return null;

    if (responseData is String) {
      return responseData;
    }

    if (responseData is List && responseData.isNotEmpty) {
      final first = responseData.first;
      if (first is String) {
        return first;
      }
      if (first is Map) {
        final map = Map<String, dynamic>.from(first);
        for (final key in ['error', 'message', 'detail', 'msg']) {
          final value = map[key];
          if (value is String && value.trim().isNotEmpty) {
            return value;
          }
        }
      }
    }

    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      for (final key in ['error', 'message', 'detail', 'msg']) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  // Tratamento de erros
  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      final serverMessage = _extractServerMessage(error.response?.data);
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage.trim();
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Timeout de conexão. Verifique sua internet.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            return 'Sua sessão expirou. Entre novamente para continuar.';
          } else if (statusCode == 404) {
            return 'Não encontramos essas informações. Atualize a tela e tente novamente.';
          } else if (statusCode == 500) {
            return 'Estamos passando por uma instabilidade. Tente novamente em instantes.';
          }
          return 'Ocorreu um erro (${statusCode ?? 'indefinido'}). Tente novamente em instantes.';
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
  // Obter chave pública do PagBank para tokenização
  Future<Map<String, dynamic>> getPagBankPublicKey() async {
    try {
      // Rota pública, não precisa de autenticação
      // Usar skipCache para sempre obter a chave mais recente
      final response = await _dio.get(
        '/pagbank/public-key',
        options: Options(extra: {'skipCache': true}),
      );
      
      if (response.data != null && response.data['success'] == true) {
        final publicKey = response.data['data']?['public_key'];
        if (publicKey != null && publicKey.isNotEmpty) {
          return {'success': true, 'data': {'public_key': publicKey}};
        }
      }
      return {'success': false, 'error': response.data['error'] ?? 'Chave pública não retornada'};
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // DEPRECATED: saveCardDirect não deve ser usado em produção
  // Use saveCard com token já tokenizado pelo PagBank
  @Deprecated('Use saveCard com token já tokenizado. Não envie número do cartão diretamente.')
  Future<Map<String, dynamic>> saveCardDirect({
    required String customerId,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
    bool isDefault = false,
  }) async {
    // PRODUÇÃO REAL: Rejeitar número do cartão diretamente
    return {
      'success': false,
      'error': 'Número do cartão não pode ser enviado diretamente por questões de segurança. Tokenize o cartão usando a chave pública do PagBank antes de salvar.',
      'public_key_endpoint': '/pagbank/public-key'
    };
  }

  // Salvar cartão de crédito (com token já gerado)
  Future<Map<String, dynamic>> saveCard({
    required String cardToken,
    required String lastDigits,
    required String brand,
    String? holderName,
    String? expiryMonth,
    String? expiryYear,
    bool isDefault = false,
  }) async {
    try {
      await loadToken();
      final response = await _dio.post('/saved-cards', data: {
        'card_token': cardToken,
        'last_digits': lastDigits,
        'brand': brand,
        if (holderName != null) 'holder_name': holderName,
        if (expiryMonth != null) 'expiry_month': expiryMonth,
        if (expiryYear != null) 'expiry_year': expiryYear,
        'is_default': isDefault,
      });
      
      if (response.data != null && response.data['success'] == true) {
        // IMPORTANTE: Invalidar cache de cartões após salvar
        invalidateSavedCardsCache();
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao salvar cartão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Obter cartões salvos
  Future<Map<String, dynamic>> getSavedCards({bool forceRefresh = false}) async {
    try {
      await loadToken();
      final response = await _dio.get(
        '/saved-cards',
        options: Options(extra: {'skipCache': forceRefresh}),
        queryParameters: forceRefresh ? {'_t': DateTime.now().millisecondsSinceEpoch} : null,
      );
      
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
  Future<Map<String, dynamic>> getBookingDetails(String bookingId, {bool forceRefresh = false}) async {
    try {
      await loadToken();
      
      // IMPORTANTE: Se forceRefresh, adicionar timestamp para bypassar cache
      final url = forceRefresh 
          ? '/bookings/$bookingId?_t=${DateTime.now().millisecondsSinceEpoch}'
          : '/bookings/$bookingId';
      
      final response = await _dio.get(url);
      
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        
        // Garantir que data é um Map, não uma List
        if (data is List && data.isNotEmpty) {
          return {'success': true, 'data': _enrichBooking(Map<String, dynamic>.from(data[0]))};
        } else if (data is Map) {
          return {'success': true, 'data': _enrichBooking(Map<String, dynamic>.from(data))};
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
        // Invalidar cache após definir como padrão
        invalidateSavedCardsCache();
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
        // Invalidar cache após deletar
        invalidateSavedCardsCache();
        return {'success': true, 'data': response.data['data']};
      } else {
        return {'success': false, 'error': response.data['error'] ?? 'Erro ao remover cartão'};
      }
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> createPayment({
    required String bookingId,
    required String paymentMethod,
    double? amount,
    String? cardToken,
    int? installments,
    int? pixExpirationInSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await loadToken();
      final payload = <String, dynamic>{
        'bookingId': bookingId,
        'paymentMethod': paymentMethod.toUpperCase(),
      };

      if (amount != null) {
        payload['amount'] = amount;
      }

      if (cardToken != null && cardToken.isNotEmpty) {
        payload['cardToken'] = cardToken;
      }

      if (installments != null && installments > 0) {
        payload['installments'] = installments;
      }

      if (pixExpirationInSeconds != null && pixExpirationInSeconds > 0) {
        payload['pixExpiration'] = pixExpirationInSeconds;
      }

      if (metadata != null && metadata.isNotEmpty) {
        payload['metadata'] = metadata;
      }

      final response = await _dio.post('/payments', data: payload);

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'data': response.data['data'],
        };
      }

      return {
        'success': false,
        'error': response.data?['error'] ?? 'Não foi possível iniciar o pagamento.',
      };
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> createBookingPayment(
    String bookingId, {
    required String paymentMethod,
    String? cardToken,
    String? cvv,
    String? holderName,
    int? installments,
    int? pixExpirationInSeconds,
    bool? saveCard,
    String? lastDigits,
    String? brand,
    String? expiryMonth,
    String? expiryYear,
    String? workshopPagbankAccountId,
  }) async {
    try {
      await loadToken();
      
      // Criar pagamento diretamente no endpoint /bookings/:id/payment
      final payload = <String, dynamic>{
        'paymentMethod': paymentMethod.toUpperCase(),
      };

      if (cardToken != null && cardToken.isNotEmpty) {
        payload['cardToken'] = cardToken;
      }

      if (cvv != null && cvv.isNotEmpty) {
        payload['cvv'] = cvv;
      }

      if (holderName != null && holderName.trim().isNotEmpty) {
        payload['holderName'] = holderName.trim();
      }

      if (installments != null && installments > 0) {
        payload['installments'] = installments;
      }

      if (pixExpirationInSeconds != null && pixExpirationInSeconds > 0) {
        payload['pixExpiration'] = pixExpirationInSeconds;
      }

      if (saveCard == true) {
        payload['saveCard'] = true;
      }

      if (lastDigits != null && lastDigits.trim().isNotEmpty) {
        payload['lastDigits'] = lastDigits.trim();
      }
      if (brand != null && brand.trim().isNotEmpty) {
        payload['brand'] = brand.trim();
      }
      if (expiryMonth != null && expiryMonth.trim().isNotEmpty) {
        payload['expiryMonth'] = expiryMonth.trim();
      }
      if (expiryYear != null && expiryYear.trim().isNotEmpty) {
        payload['expiryYear'] = expiryYear.trim();
      }
      if (workshopPagbankAccountId != null && workshopPagbankAccountId.trim().isNotEmpty) {
        payload['workshopAccountId'] = workshopPagbankAccountId.trim();
        payload['pagbankAccountId'] = workshopPagbankAccountId.trim();
      }

      print('💳 [API] Criando pagamento para booking $bookingId com payload: paymentMethod=${payload['paymentMethod']}, hasCardToken=${payload.containsKey('cardToken')}, hasCvv=${payload.containsKey('cvv')}, installments=${payload['installments']}');

      final response = await _dio.post('/bookings/$bookingId/payment', data: payload);

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'data': response.data['data'],
        };
      }

      return {
        'success': false,
        'error': response.data?['error'] ?? 'Não foi possível iniciar o pagamento.',
      };
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    try {
      await loadToken();
      // CRITICAL: status de pagamento NÃO pode usar cache (senão o polling fica travado em HIT)
      final response = await _dio.get(
        '/payments/$paymentId/status',
        options: Options(extra: {'skipCache': true}),
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
      );

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'data': response.data['data']};
      }

      return {
        'success': false,
        'error': response.data?['error'] ?? 'Não foi possível consultar o status do pagamento.',
      };
    } catch (e) {
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}























