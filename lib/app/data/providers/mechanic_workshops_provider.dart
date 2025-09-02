import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../core/app_urls.dart';
import '../models/filter_query_workshop.dart';
import '../models/mechanic_workshop.dart';

class MechanicWorkshopsProvider {
  MechanicWorkshopsProvider({required RestClientDio restClientDio})
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

      // Construir queryParams manualmente para evitar parâmetros null
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        'dataBlocked': 0,
        if (search != null && search.isNotEmpty) 'search': search,
        if (serviceType != null && serviceType.isNotEmpty) 'serviceTypes': serviceType,
        if (limitedDistance != null) 'distance': limitedDistance,
        if (rating != null && rating > 0) 'rating': rating,
        if (latUser != null) 'latUser': latUser,
        if (longUser != null) 'longUser': longUser,
        if (workshopName != null && workshopName.isNotEmpty) 'workshopName': workshopName,
      };

      final response = await _restClientDio.get(
        BaseUrls.workshops,
        queryParameters: queryParams,
      );

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
        return [];
      }

      return workshopsList
          .map<MechanicWorkshop>(
            (workshop) =>
                MechanicWorkshop.fromJson(workshop as Map<String, dynamic>),
          )
          .toList();
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
}
