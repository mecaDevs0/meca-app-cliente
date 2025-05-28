import 'package:mega_commons/mega_commons.dart';

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
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'dataBlocked': 0,
      if (search != null) 'search': search,
      if (serviceType != null && serviceType.isNotEmpty)
        'serviceTypes': serviceType,
      if (distance != null && distance != 0) 'distance': distance,
      if (latUser != null) 'latUser': latUser,
      if (longUser != null) 'longUser': longUser,
      if (rating != null && rating != 0) 'rating': rating,
      if (workshopName != null) 'workshopName': workshopName,
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

    return (response.data as List)
        .map<Service>(
          (service) => Service.fromJson(service as Map<String, dynamic>),
        )
        .toList();
  }
}
