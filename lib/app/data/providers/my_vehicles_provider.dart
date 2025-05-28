import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/vehicle.dart';

class MyVehiclesProvider {
  MyVehiclesProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<Vehicle>> onRequestVehicles({
    required int page,
    required int limit,
    String? search,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (!search.isNullOrEmpty) 'search': search,
    };

    final response = await _restClientDio.get(
      BaseUrls.vehicles,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<Vehicle>((vehicle) => Vehicle.fromJson(vehicle))
        .toList();
  }

  Future<Vehicle> onRequestVehicle(String id) async {
    final response = await _restClientDio.get('${BaseUrls.vehicles}/$id');
    return Vehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> onRemoveVehicle(String id) async {
    await _restClientDio.delete('${BaseUrls.vehicles}/$id');
  }
}
