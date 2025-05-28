import 'package:mega_commons/mega_commons.dart';

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
    final response = await _restClientDio.get(
      BaseUrls.services,
      queryParameters: FilterQueryService(
        page: page,
        limit: limit,
        dataBlocked: 0,
        name: search,
        serviceTypes: serviceType,
        latUser: latUser,
        longUser: longUser,
        distance: distance,
        rating: rating,
      ).toJson(),
    );

    return (response.data as List)
        .map<Service>(
          (service) => Service.fromJson(service as Map<String, dynamic>),
        )
        .toList();
  }

  Future<Service> onRequestService(String id) async {
    final response = await _restClientDio.get('${BaseUrls.services}/$id');
    return Service.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MechanicWorkshop>> onRequestWorkshops({
    required int page,
    required int limit,
    List<String>? serviceType,
    double? latUser,
    double? longUser,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'dataBlocked': 0,
      'serviceTypes': serviceType,
      if (latUser != null) 'latUser': latUser,
      if (longUser != null) 'longUser': longUser,
    };

    final response = await _restClientDio.get(
      BaseUrls.workshops,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<MechanicWorkshop>(
          (workshop) =>
              MechanicWorkshop.fromJson(workshop as Map<String, dynamic>),
        )
        .toList();
  }
}
