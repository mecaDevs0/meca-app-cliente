
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
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (plate != null) 'plate': plate,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (model != null) 'model': model,
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
      if (limit != null) 'limit': limit,
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
