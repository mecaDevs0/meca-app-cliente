import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

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
    try {
      // TEMPORARIAMENTE: Usar limit menor para evitar erro 500
      final adjustedLimit = limit > 5 ? 5 : limit;
      
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': adjustedLimit,
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
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API Scheduling
      if (e.response?.statusCode == 500) {
        print('Erro 500 na API Scheduling (OrdersPlacedProvider): ${e.response?.data}');
        return [];
      }
      rethrow;
    } catch (e) {
      print('Erro inesperado na API Scheduling (OrdersPlacedProvider): $e');
      return [];
    }
  }
}
