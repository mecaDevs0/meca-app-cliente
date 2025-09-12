import 'dart:developer' as console;
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../data/models/profile.dart';
import 'utils/login_data_fix.dart';

class AppInterceptor extends Interceptor {
  // Contador de tentativas para timeout do MongoDB
  static final Map<String, int> _mongodbRetryCount = {};
  static const int _maxMongoDbRetries = 3;
  static const Duration _mongodbRetryDelay = Duration(seconds: 5);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final profile = Profile.fromCache();
    
    // Lista de APIs que NÃO devem receber profileId para evitar erro 500
    final apisWithoutProfileId = [
      'Scheduling',
      'WorkshopServices',
      'ServicesDefault', // Adicionado para evitar erro 500
      'Workshop', // Adicionado para evitar erro 500
      'Profile/Token', // Adicionado para evitar erro no login
      'Profile/Register', // Adicionado para evitar erro no registro
      'Profile/ForgotPassword', // Adicionado para evitar erro no reset de senha
    ];
    
    // Log para debug - verificar o path atual
    console.log('🔍 Path atual: ${options.path}', name: 'AppInterceptor');
    console.log('🔍 URL completa: ${options.uri}', name: 'AppInterceptor');
    
    // Verifica se a API atual está na lista de exclusão
    final shouldExcludeProfileId = apisWithoutProfileId.any(
      (api) => options.path.contains(api)
    );
    
    console.log('🔍 API deve excluir profileId: $shouldExcludeProfileId', name: 'AppInterceptor');
    console.log('🔍 APIs na lista de exclusão: $apisWithoutProfileId', name: 'AppInterceptor');
    
    // Verifica se já existe profileId nos queryParameters
    final hasExistingProfileId = options.queryParameters.containsKey('profileId');
    console.log('🔍 Já existe profileId nos queryParameters: $hasExistingProfileId', name: 'AppInterceptor');
    
    // CORREÇÃO: Adicionar profileId apenas em requisições GET e se o usuário estiver logado
    // E não estiver na lista de APIs que causam erro 500
    if (options.method == 'GET' && 
        profile.id != null && 
        !shouldExcludeProfileId &&
        !hasExistingProfileId) {
      options.queryParameters['profileId'] = profile.id;
      console.log('✅ Adicionando profileId: ${profile.id}', name: 'AppInterceptor');
    } else {
      console.log('❌ NÃO adicionando profileId', name: 'AppInterceptor');
      console.log('❌ Motivo: method=${options.method}, profile.id=${profile.id}, shouldExclude=$shouldExcludeProfileId, hasExisting=$hasExistingProfileId', name: 'AppInterceptor');
    }
    
    if (options.method == 'GET' &&
        !options.path.contains('/Token') &&
        !options.path.contains('/Register') &&
        !options.path.contains('/ForgotPassword')) {
      options.queryParameters['dataBlocked'] = 0;
    }
    
    // Log detalhado da requisição para debug
    console.log('🌐 Requisição: ${options.method} ${options.baseUrl}${options.path}', 
        name: 'AppInterceptor');
    console.log('📡 Headers: ${options.headers}', name: 'AppInterceptor');
    console.log('🔍 Query Params FINAL: ${options.queryParameters}', name: 'AppInterceptor');
    
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    console.log('✅ Resposta: ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}', 
        name: 'AppInterceptor');
    
    // Verificar se é uma resposta de login e validar os dados
    if (response.requestOptions.path.contains('/Token')) {
      console.log('🔍 Validando resposta de login...', name: 'AppInterceptor');
      
      // Log da resposta para debug
      LoginDataFix.logResponse(response.data, response.requestOptions.path);
      
      // Se for erro 400, verificar se é timeout do MongoDB
      if (response.statusCode == 400) {
        final errorData = response.data;
        final messageEx = errorData?['messageEx'] as String?;
        
        if (messageEx?.contains('timeout') == true || 
            messageEx?.contains('MongoDB') == true ||
            messageEx?.contains('CompositeServerSelector') == true) {
          console.log('🔧 Timeout do MongoDB detectado na resposta', name: 'AppInterceptor');
          
          // Criar uma resposta de erro mais amigável
          final errorResponse = Response(
            requestOptions: response.requestOptions,
            statusCode: 400,
            data: {
              'data': null,
              'erro': true,
              'errors': null,
              'message': 'Servidor temporariamente sobrecarregado. Tente novamente em alguns minutos.',
              'messageEx': 'MongoDB timeout detected in response',
            },
          );
          
          // Resolver com a resposta de erro amigável
          handler.resolve(errorResponse);
          return;
        }
      }
      
      // Verificar se a resposta indica sucesso
      if (response.statusCode == 200 && !LoginDataFix.isSuccessResponse(response.data)) {
        console.log('⚠️ Resposta de login não indica sucesso', name: 'AppInterceptor');
      }
    }
    
    // Limpar contador de retry em caso de sucesso
    final requestKey = _getRequestKey(response.requestOptions);
    _mongodbRetryCount.remove(requestKey);
    
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    console.log('❌ Erro de rede: ${err.type}', name: 'AppInterceptor');
    console.log('📊 Status: ${err.response?.statusCode}', name: 'AppInterceptor');
    console.log('🔗 URL: ${err.requestOptions.uri}', name: 'AppInterceptor');
    console.log('💬 Mensagem: ${err.message}', name: 'AppInterceptor');
    
    // Tratamento específico para erro 400 com timeout do MongoDB
    if (err.response?.statusCode == 400) {
      console.log('🚨 Erro 400 detectado - Verificando se é timeout do MongoDB', name: 'AppInterceptor');
      
      final errorData = err.response?.data;
      
      // Usar o helper para processar a mensagem de erro
      final errorMessage = LoginDataFix.getErrorMessage(errorData);
      console.log('💬 Mensagem de erro processada: $errorMessage', name: 'AppInterceptor');
      
      if (errorData != null && errorData is Map<String, dynamic>) {
        final messageEx = errorData['messageEx'] as String?;
        if (messageEx?.contains('timeout') == true || 
            messageEx?.contains('MongoDB') == true ||
            messageEx?.contains('CompositeServerSelector') == true) {
          console.log('🔧 Timeout do MongoDB detectado no servidor', name: 'AppInterceptor');
          
          // Se for erro de login, mostrar mensagem específica
          if (err.requestOptions.path.contains('/Token')) {
            console.log('🔐 Timeout do MongoDB no login - Servidor sobrecarregado', name: 'AppInterceptor');
          }
          
          // Tentar retry para timeout do MongoDB
          final shouldRetry = await _handleMongoDbTimeout(err, handler);
          if (shouldRetry) {
            return; // Retry será feito, não passar o erro
          }
        }
      }
      
      // Se não for timeout do MongoDB, criar resposta de erro amigável
      console.log('❌ Erro 400 não é timeout do MongoDB - Criando resposta amigável', name: 'AppInterceptor');
      
      final errorResponse = Response(
        requestOptions: err.requestOptions,
        statusCode: 400,
        data: {
          'data': null,
          'erro': true,
          'errors': null,
          'message': errorMessage,
          'messageEx': 'Error 400 handled by interceptor',
        },
      );
      
      handler.resolve(errorResponse);
      return;
    }
    
    // Tratamento específico para erro 500
    if (err.response?.statusCode == 500) {
      console.log('🚨 Erro 500 detectado - Possível problema de connectionString no servidor', name: 'AppInterceptor');
      
      // Se for erro de login, mostrar mensagem específica
      if (err.requestOptions.path.contains('/Token')) {
        console.log('🔐 Erro 500 no login - Verificando configuração do servidor', name: 'AppInterceptor');
      }
    }
    
    handler.next(err);
  }

  /// Trata timeout do MongoDB com retry automático
  Future<bool> _handleMongoDbTimeout(DioException err, ErrorInterceptorHandler handler) async {
    final requestKey = _getRequestKey(err.requestOptions);
    final currentRetryCount = _mongodbRetryCount[requestKey] ?? 0;
    
    if (currentRetryCount < _maxMongoDbRetries) {
      console.log('🔄 Tentativa ${currentRetryCount + 1} de $_maxMongoDbRetries para timeout do MongoDB', 
          name: 'AppInterceptor');
      
      // Incrementar contador de tentativas
      _mongodbRetryCount[requestKey] = currentRetryCount + 1;
      
      // Aguardar antes de tentar novamente
      await Future.delayed(_mongodbRetryDelay);
      
      try {
        // Fazer nova tentativa com timeout maior
        final dio = Dio();
        dio.options.connectTimeout = const Duration(seconds: 45); // Timeout maior para MongoDB
        dio.options.receiveTimeout = const Duration(seconds: 45);
        
        // Usar a URL completa em vez de apenas o path
        final fullUrl = '${err.requestOptions.baseUrl}${err.requestOptions.path}';
        
        final response = await dio.request(
          fullUrl,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          ),
        );
        
        console.log('✅ Retry do MongoDB bem-sucedido na tentativa ${currentRetryCount + 1}', 
            name: 'AppInterceptor');
        
        // Limpar contador de retry
        _mongodbRetryCount.remove(requestKey);
        
        // Resolver com a resposta bem-sucedida
        handler.resolve(response);
        return true;
      } catch (retryError) {
        console.log('❌ Retry do MongoDB falhou na tentativa ${currentRetryCount + 1}: $retryError', 
            name: 'AppInterceptor');
        
        // Se ainda há tentativas restantes, continuar
        if (currentRetryCount + 1 < _maxMongoDbRetries) {
          return await _handleMongoDbTimeout(err, handler);
        } else {
          // Se todas as tentativas falharam, criar resposta de erro amigável
          console.log('❌ Todas as tentativas de retry falharam', name: 'AppInterceptor');
          
          final errorResponse = Response(
            requestOptions: err.requestOptions,
            statusCode: 400,
            data: {
              'data': null,
              'erro': true,
              'errors': null,
              'message': 'Servidor temporariamente indisponível. Tente novamente em alguns minutos.',
              'messageEx': 'All retry attempts failed',
            },
          );
          
          handler.resolve(errorResponse);
          return true;
        }
      }
    } else {
      console.log('❌ Máximo de tentativas para timeout do MongoDB atingido', 
          name: 'AppInterceptor');
      
      // Limpar contador de retry
      _mongodbRetryCount.remove(requestKey);
      
      // Criar uma resposta de erro mais amigável para o usuário
      final errorResponse = Response(
        requestOptions: err.requestOptions,
        statusCode: 400,
        data: {
          'data': null,
          'erro': true,
          'errors': null,
          'message': 'Servidor temporariamente sobrecarregado. Tente novamente em alguns minutos.',
          'messageEx': 'MongoDB timeout after multiple retry attempts',
        },
      );
      
      // Resolver com a resposta de erro amigável
      handler.resolve(errorResponse);
      return true;
    }
    
    return false; // Não fazer retry, passar o erro
  }

  /// Gera uma chave única para identificar a requisição
  String _getRequestKey(RequestOptions options) {
    return '${options.method}_${options.path}_${options.data.hashCode}';
  }
}
