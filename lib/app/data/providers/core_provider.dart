import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/vehicle.dart';
import '../models/workshopService/workshop_service.dart';

class CoreProvider {
  CoreProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<Vehicle>> onRequestVehicles({
    int? page,
    int? limit,
    String? plate,
    String? manufacturer,
    String? model,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'plate': plate,
      'manufacturer': manufacturer,
      'model': model,
      'dataBlocked': 0,
    };

    final response = await _restClientDio.get(
      BaseUrls.vehicles,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<Vehicle>((vehicle) => Vehicle.fromJson(vehicle))
        .toList();
  }

  Future<List<WorkshopService>> onRequestServices({
    required String workshopId,
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{
      'workshopId': workshopId,
      'limit': 0,
      'dataBlocked': 0,
    };

    final response = await _restClientDio.get(
      BaseUrls.workshopServices,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<WorkshopService>(
          (service) =>
              WorkshopService.fromJson(service as Map<String, dynamic>),
        )
        .toList();
  }
}
