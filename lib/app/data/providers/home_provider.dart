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

      print('🔧 [HomeProvider] Buscando workshops com parâmetros: $queryParameters');

      final response = await _restClientDio.get(
        BaseUrls.workshops,
        queryParameters: queryParameters,
      );

      print('🔧 [HomeProvider] Resposta da API Workshops: ${response.data}');

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List workshopsList;
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        workshopsList = responseData['data'] as List;
        print('🔧 [HomeProvider] Workshops encontrados (Map): ${workshopsList.length}');
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        workshopsList = responseData;
        print('🔧 [HomeProvider] Workshops encontrados (List): ${workshopsList.length}');
      } else {
        print('❌ Formato de resposta inesperado: ${responseData.runtimeType}');
        return [];
      }

      final workshops = workshopsList
          .map<MechanicWorkshop>(
            (workshop) =>
                MechanicWorkshop.fromJson(workshop as Map<String, dynamic>),
          )
          .toList();

      print('🔧 [HomeProvider] Workshops processados: ${workshops.length}');
      for (var workshop in workshops) {
        print('🔧 [HomeProvider] Workshop: ID=${workshop.id}, CompanyName=${workshop.companyName}, FullName=${workshop.fullName}, Photo=${workshop.photo}, Rating=${workshop.rating}, OpeningHours=${workshop.openingHours}');
      }

      return workshops;
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API Workshop
      if (e.response?.statusCode == 500) {
        print('Erro 500 na API Workshop (HomeProvider): ${e.response?.data}');
        return [];
      }
      rethrow;
    } catch (e) {
      print('Erro inesperado na API Workshop (HomeProvider): $e');
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

      print('🔧 [HomeProvider] Buscando serviços com parâmetros: $queryParameters');

      final response = await _restClientDio.get(
        BaseUrls.services,
        queryParameters: queryParameters,
      );

      print('🔧 [HomeProvider] Resposta da API Services: ${response.data}');

      // Tratar a resposta de forma robusta
      final responseData = response.data;
      List servicesList;
      
      if (responseData is Map<String, dynamic>) {
        // API retorna objeto com propriedade 'data'
        servicesList = responseData['data'] as List;
        print('🔧 [HomeProvider] Services encontrados (Map): ${servicesList.length}');
      } else if (responseData is List) {
        // API retorna diretamente o array (fallback)
        servicesList = responseData;
        print('🔧 [HomeProvider] Services encontrados (List): ${servicesList.length}');
      } else {
        print('❌ Formato de resposta inesperado: ${responseData.runtimeType}');
        return [];
      }

      final services = servicesList
          .map<Service>(
            (service) => Service.fromJson(service as Map<String, dynamic>),
          )
          .toList();

      print('🔧 [HomeProvider] Services processados: ${services.length}');
      for (var service in services) {
        print('🔧 [HomeProvider] Service: ID=${service.id}, Name=${service.name}, Photo=${service.photo}');
      }

      return services;
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API ServicesDefault
      if (e.response?.statusCode == 500) {
        print('Erro 500 na API ServicesDefault (HomeProvider): ${e.response?.data}');
        return [];
      }
      rethrow;
    } catch (e) {
      print('Erro inesperado na API ServicesDefault (HomeProvider): $e');
      return [];
    }
  }
}
