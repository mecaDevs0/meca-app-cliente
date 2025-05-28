import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/rating.dart';

class MechanicWorkshopReviewsProvider {
  MechanicWorkshopReviewsProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<Rating>> onRequestWorkshopRating({
    required int page,
    required int limit,
    required String workshopId,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'workshopId': workshopId,
      'dataBlocked': 0,
    };
    final response = await _restClientDio.get(
      BaseUrls.rating,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<Rating>(
          (rating) => Rating.fromJson(rating as Map<String, dynamic>),
        )
        .toList();
  }
}
