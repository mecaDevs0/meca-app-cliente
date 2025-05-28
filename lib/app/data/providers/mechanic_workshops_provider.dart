import 'package:mega_commons/mega_commons.dart';

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
    final response = await _restClientDio.get(
      BaseUrls.workshops,
      queryParameters: FilterQueryWorkshop(
        page: page,
        limit: limit,
        dataBlocked: 0,
        search: search,
        serviceTypes: serviceType,
        latUser: latUser,
        longUser: longUser,
        distance: distance,
        rating: rating,
        workshopName: workshopName,
      ).toJson(),
    );

    return (response.data as List)
        .map<MechanicWorkshop>(
          (workshop) =>
              MechanicWorkshop.fromJson(workshop as Map<String, dynamic>),
        )
        .toList();
  }
}
