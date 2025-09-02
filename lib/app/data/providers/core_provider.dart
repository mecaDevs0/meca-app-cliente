
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
    print('🔧 [CORE_PROVIDER] Iniciando busca de serviços');
    print('🔧 [CORE_PROVIDER] WorkshopId: $workshopId');
    print('🔧 [CORE_PROVIDER] Limit: $limit');
    
    final queryParameters = <String, dynamic>{
      'workshopId': workshopId,
      if (limit != null) 'limit': limit,
    };
    
    print('🔧 [CORE_PROVIDER] Query parameters: $queryParameters');
    print('🔧 [CORE_PROVIDER] URL: ${BaseUrls.workshopServices}');

    try {
      final response = await _restClientDio.get(
        BaseUrls.workshopServices,
        queryParameters: queryParameters,
      );
      
      print('🔧 [CORE_PROVIDER] Response status: ${response.statusCode}');
      print('🔧 [CORE_PROVIDER] Response data type: ${response.data.runtimeType}');
      print('🔧 [CORE_PROVIDER] Response data: ${response.data}');
      
      if (response.data is List) {
        final services = (response.data as List)
            .map<WorkshopService>(
              (service) => WorkshopService.fromJson(service as Map<String, dynamic>),
            )
            .toList();
        
        print('🔧 [CORE_PROVIDER] Serviços mapeados: ${services.length}');
        if (services.isNotEmpty) {
          final firstService = services.first;
          print('🔧 [CORE_PROVIDER] Primeiro serviço - ID: ${firstService.id}');
          print('🔧 [CORE_PROVIDER] Primeiro serviço - Service ID: ${firstService.service?.id}');
          print('🔧 [CORE_PROVIDER] Primeiro serviço - Service Name: ${firstService.service?.name}');
        }
        
        return services;
      } else {
        print('🔧 [CORE_PROVIDER] ERRO: Response.data não é uma List');
        print('🔧 [CORE_PROVIDER] Response.data: ${response.data}');
        return [];
      }
    } catch (e) {
      print('🔧 [CORE_PROVIDER] ERRO na requisição: $e');
      rethrow;
    }
  }
}
