import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/order.dart';

class OrdersPlacedProvider {
  OrdersPlacedProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<List<Order>> onRequestOrders({
    required int page,
    required int limit,
    int? startDate,
    int? endDate,
    int? status,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'dataBlocked': 0,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (status != null) 'status': status,
    };

    final response = await _restClientDio.get(
      BaseUrls.scheduling,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<Order>(
          (order) => Order.fromJson(order as Map<String, dynamic>),
        )
        .toList();
  }
}
