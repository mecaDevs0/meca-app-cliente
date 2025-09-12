import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../core/app_urls.dart';
import '../models/filter_query_service.dart';
import '../models/mechanic_workshop.dart';
import '../models/service.dart';

class ServicesProvider {
  ServicesProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<Service>> onRequestServices({
    required int page,
    required int limit,
    String? search,
    List<String>? serviceType,
    int? rating,
    int? distance,
    double? latUser,
    double? longUser,
    String? workshopId,
    String? workshopName,
  }) async {
    try {
    final queryParams = FilterQueryService(
      page: page,
      limit: limit,
      dataBlocked: 0,
      name: search,
        serviceTypes: serviceType,
        latUser: latUser,
        longUser: longUser,
        distance: distance,
        rating: rating,
      ).toJson();

      // Adiciona workshopId na query caso tenha sido fornecido
      if (workshopId != null && workshopId.isNotEmpty) {
        queryParams['workshopId'] = workshopId;
      }

      print('🔧 Fazendo requisição para serviços...');
      print('📡 URL: ${BaseUrls.services}');
      print('📋 Params: $queryParams');

      final response = await _restClientDio.get(
        BaseUrls.services,
        queryParameters: queryParams,
      );

      print('✅ Resposta recebida: ${response.statusCode}');

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List servicesList;
      
      print('🔧 [ServicesProvider] Tipo de resposta: ${responseData.runtimeType}');
      print('🔧 [ServicesProvider] Dados da resposta: $responseData');
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        servicesList = responseData['data'] as List;
        print('🔧 [ServicesProvider] ✅ Extraído array de serviços do objeto: ${servicesList.length} itens');
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        servicesList = responseData;
        print('🔧 [ServicesProvider] ✅ Array direto de serviços: ${servicesList.length} itens');
      } else {
        print('🔧 [ServicesProvider] ❌ Formato de resposta inesperado: ${responseData.runtimeType}');
        return [];
      }

      return servicesList
          .map<Service>(
            (service) => Service.fromJson(service as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      print('❌ Erro Dio na API ServicesDefault: ${e.type}');
      print('📊 Status: ${e.response?.statusCode}');
      print('🔗 URL: ${e.requestOptions.uri}');
      
      // Tratamento específico para erro 500 na API ServicesDefault
      if (e.response?.statusCode == 500) {
        print('🚨 Erro 500 na API ServicesDefault: ${e.response?.data}');
        
        // Verificar se é erro de connectionString
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map<String, dynamic>) {
          final messageEx = errorData['messageEx'] as String?;
          if (messageEx?.contains('connectionString') == true) {
            print('🔧 Erro de connectionString detectado no servidor');
            MegaSnackbar.showErroSnackBar(
              'Servidor em manutenção. Tente novamente em alguns minutos.'
            );
          } else {
            MegaSnackbar.showErroSnackBar(
              'Serviços temporariamente indisponíveis. Tente novamente em alguns minutos.'
            );
          }
        } else {
          MegaSnackbar.showErroSnackBar(
            'Serviços temporariamente indisponíveis. Tente novamente em alguns minutos.'
          );
        }
        
        // Retorna lista vazia em caso de erro 500 para evitar travamento do app
        return [];
      }
      
      // Tratamento para outros erros de rede
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        MegaSnackbar.showErroSnackBar(
          'Tempo limite de conexão. Verifique sua internet e tente novamente.'
        );
        return [];
      }
      
      if (e.type == DioExceptionType.connectionError) {
        MegaSnackbar.showErroSnackBar(
          'Erro de conexão. Verifique sua internet e tente novamente.'
        );
        return [];
      }
      
      // Re-throw outros erros Dio para serem tratados pelo MegaRequestUtils
      rethrow;
    } catch (e) {
      print('❌ Erro inesperado na API ServicesDefault: $e');
      MegaSnackbar.showErroSnackBar(
        'Erro inesperado. Tente novamente em alguns minutos.'
      );
      return [];
    }
  }

  Future<Service> onRequestService(String id) async {
    try {
      print('🔧 Buscando detalhes do serviço: $id');
      
      final response = await _restClientDio.get('${BaseUrls.services}/$id');
      return Service.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ Erro ao buscar detalhes do serviço: ${e.type}');
      print('📊 Status: ${e.response?.statusCode}');
      
      if (e.response?.statusCode == 500) {
        print('🚨 Erro 500 ao buscar detalhes do serviço: ${e.response?.data}');
        
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map<String, dynamic>) {
          final messageEx = errorData['messageEx'] as String?;
          if (messageEx?.contains('connectionString') == true) {
            MegaSnackbar.showErroSnackBar(
              'Servidor em manutenção. Tente novamente em alguns minutos.'
            );
          } else {
            MegaSnackbar.showErroSnackBar(
              'Serviço temporariamente indisponível.'
            );
          }
        } else {
          MegaSnackbar.showErroSnackBar(
            'Serviço temporariamente indisponível.'
          );
        }
        
        throw MegaResponse(message: 'Serviço temporariamente indisponível');
      }
      rethrow;
    } catch (e) {
      print('❌ Erro inesperado ao buscar serviço: $e');
      throw MegaResponse(message: 'Erro inesperado ao buscar serviço');
    }
  }

  Future<List<MechanicWorkshop>> onRequestWorkshops({
    required int page,
    required int limit,
    List<String>? serviceType,
    double? latUser,
    double? longUser,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
        'dataBlocked': 0,
        if (serviceType != null && serviceType.isNotEmpty) 'serviceTypes': serviceType,
        if (latUser != null) 'latUser': latUser,
        if (longUser != null) 'longUser': longUser,
      };

              print('🏪 Fazendo requisição para estabelecimentos...');
      print('📡 URL: ${BaseUrls.workshops}');
      print('📋 Params: $queryParameters');

      final response = await _restClientDio.get(
        BaseUrls.workshops,
        queryParameters: queryParameters,
      );

      print('✅ Resposta recebida: ${response.statusCode}');

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List workshopsList;
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        workshopsList = responseData['data'] as List;
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        workshopsList = responseData;
      } else {
        print('❌ Formato de resposta inesperado: ${responseData.runtimeType}');
        return [];
      }

      return workshopsList
          .map<MechanicWorkshop>(
            (workshop) =>
                MechanicWorkshop.fromJson(workshop as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      print('❌ Erro Dio na API Workshop: ${e.type}');
      print('📊 Status: ${e.response?.statusCode}');
      print('🔗 URL: ${e.requestOptions.uri}');
      
      // Tratamento específico para erro 500 na API Workshop
      if (e.response?.statusCode == 500) {
        print('🚨 Erro 500 na API Workshop: ${e.response?.data}');
        
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map<String, dynamic>) {
          final messageEx = errorData['messageEx'] as String?;
          if (messageEx?.contains('connectionString') == true) {
            print('🔧 Erro de connectionString detectado no servidor');
            MegaSnackbar.showErroSnackBar(
              'Servidor em manutenção. Tente novamente em alguns minutos.'
            );
          } else {
            MegaSnackbar.showErroSnackBar(
              'Estabelecimentos temporariamente indisponíveis. Tente novamente em alguns minutos.'
            );
          }
        } else {
          MegaSnackbar.showErroSnackBar(
            'Estabelecimentos temporariamente indisponíveis. Tente novamente em alguns minutos.'
          );
        }
        
        return [];
      }
      
      // Tratamento para outros erros de rede
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        MegaSnackbar.showErroSnackBar(
          'Tempo limite de conexão. Verifique sua internet e tente novamente.'
        );
        return [];
      }
      
      if (e.type == DioExceptionType.connectionError) {
        MegaSnackbar.showErroSnackBar(
          'Erro de conexão. Verifique sua internet e tente novamente.'
        );
        return [];
      }
      
      rethrow;
    } catch (e) {
      print('❌ Erro inesperado na API Workshop: $e');
      MegaSnackbar.showErroSnackBar(
        'Erro inesperado. Tente novamente em alguns minutos.'
      );
      return [];
    }
  }
}
