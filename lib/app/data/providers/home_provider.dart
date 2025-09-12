import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../core/app_urls.dart';
import '../models/mechanic_workshop.dart';
import '../models/service.dart';

class HomeProvider {
  HomeProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<MechanicWorkshop>> onRequestWorkshops({
    required int page,
    required int limit,
    String? search,
    List<String>? serviceType,
    int? rating,
    int? distance,
    double? latUser,
    double? longUser,
    String? workshopName,
  }) async {
    try {
      // Limita a distância máxima a 50km
      final int? limitedDistance = (distance != null && distance > 0)
          ? (distance > 50 ? 50 : distance)
          : 50; // padrão: 50km se não informado

    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'dataBlocked': 0,
      if (search != null) 'search': search,
        if (serviceType != null && serviceType.isNotEmpty)
          'serviceTypes': serviceType,
        if (limitedDistance != null) 'distance': limitedDistance,
        if (latUser != null) 'latUser': latUser,
        if (longUser != null) 'longUser': longUser,
        if (rating != null && rating != 0) 'rating': rating,
        if (workshopName != null) 'workshopName': workshopName,
      };

      final response = await _restClientDio.get(
        BaseUrls.workshops,
        queryParameters: queryParameters,
      );

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List workshopsList;
      
      print('🔧 [HomeProvider] Tipo de resposta: ${responseData.runtimeType}');
      print('🔧 [HomeProvider] Dados da resposta: $responseData');
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        workshopsList = responseData['data'] as List;
        print('🔧 [HomeProvider] ✅ Extraído array de workshops do objeto: ${workshopsList.length} itens');
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        workshopsList = responseData;
        print('🔧 [HomeProvider] ✅ Array direto de workshops: ${workshopsList.length} itens');
      } else {
        print('🔧 [HomeProvider] ❌ Formato de resposta inesperado: ${responseData.runtimeType}');
        return [];
      }

      final workshops = workshopsList
          .map<MechanicWorkshop>(
            (workshop) {
              print('🔧 [HomeProvider] Processando workshop: ${workshop['id']}');
              print('🔧 [HomeProvider] Workshop companyName: "${workshop['companyName']}"');
              print('🔧 [HomeProvider] Workshop fullName: "${workshop['fullName']}"');
              print('🔧 [HomeProvider] Workshop photo: "${workshop['photo']}"');
              
              final parsedWorkshop = MechanicWorkshop.fromJson(workshop as Map<String, dynamic>);
              
              print('🔧 [HomeProvider] Workshop parseado - ID: ${parsedWorkshop.id}');
              print('🔧 [HomeProvider] Workshop parseado - CompanyName: "${parsedWorkshop.companyName}"');
              print('🔧 [HomeProvider] Workshop parseado - FullName: "${parsedWorkshop.fullName}"');
              print('🔧 [HomeProvider] Workshop parseado - Photo: "${parsedWorkshop.photo}"');
              
              return parsedWorkshop;
            },
          )
          .toList();

      print('🔧 [HomeProvider] ✅ Total de workshops processados: ${workshops.length}');
      return workshops;
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API Workshop
      if (e.response?.statusCode == 500) {
        return [];
      }
      rethrow;
    } catch (e) {
      return [];
    }
  }

  Future<List<Service>> onRequestServices({
    required int page,
    required int limit,
    String? search,
    double? latUser,
    double? longUser,
    String? workshopId,
    String? workshopName,
    int? activity,
  }) async {
    try {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'dataBlocked': 0,
      if (search != null) 'name': search,
        if (latUser != null) 'latUser': latUser,
        if (longUser != null) 'longUser': longUser,
        if (workshopId != null) 'workshopId': workshopId,
        if (workshopName != null) 'workshopName': workshopName,
        if (activity != null) 'activity': activity,
      };

      final response = await _restClientDio.get(
        BaseUrls.services,
        queryParameters: queryParameters,
      );

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List servicesList;
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        servicesList = responseData['data'] as List;
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        servicesList = responseData;
      } else {
        return [];
      }

      final services = servicesList
          .map<Service>(
            (service) => Service.fromJson(service as Map<String, dynamic>),
          )
          .toList();

      return services;
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API ServicesDefault
      if (e.response?.statusCode == 500) {
        return [];
      }
      rethrow;
    } catch (e) {
      return [];
    }
  }
}
