import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/mechanic_workshop.dart';
import '../models/workshopAgenda/agenda_model.dart';
import '../models/workshopService/workshop_service.dart';

class MechanicWorkshopDetailsProvider {
  MechanicWorkshopDetailsProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<MechanicWorkshop> onRequestMechanicWorkshopDetails({
    required String id,
    double? latUser,
    double? longUser,
  }) async {
    final queryParameters = <String, dynamic>{
      if (latUser != null) 'latUser': latUser,
      if (longUser != null) 'longUser': longUser,
    };
    final response = await _restClientDio.get(
      '${BaseUrls.workshops}/$id',
      queryParameters: queryParameters,
    );
    return MechanicWorkshop.fromJson(response.data);
  }

  Future<List<WorkshopService>> onRequestMechanicWorkshopServices({
    String? search,
    String? workshopId,
  }) async {
    final queryParameters = <String, dynamic>{
      if (workshopId != null) 'workshopId': workshopId,
      if (search != null) 'search': search,
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

  Future<AgendaModel> getWorkshopSchedule(String workshopId) async {
    final response = await _restClientDio.get(
      '${BaseUrls.workshopSchedule}/$workshopId',
    );

    return AgendaModel.fromJson(response.data);
  }
}
