import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../core/app_urls.dart';
import '../models/order.dart';
import '../models/mechanic_workshop.dart';

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

      print('🔧 [OrdersPlacedProvider] Fazendo requisição para pedidos...');
      print('🔧 [OrdersPlacedProvider] URL: ${BaseUrls.scheduling}');
      print('🔧 [OrdersPlacedProvider] Parâmetros: $queryParameters');

      final response = await _restClientDio.get(
        BaseUrls.scheduling,
        queryParameters: queryParameters,
      );

      print('🔧 [OrdersPlacedProvider] Resposta recebida: ${response.statusCode}');
      print('🔧 [OrdersPlacedProvider] Tipo de resposta: ${response.data.runtimeType}');

      final orders = (response.data as List)
           .map<Order>(
             (order) => Order.fromJson(order as Map<String, dynamic>),
           )
           .toList();
       
       // REMOVIDO: Enriquecimento complexo - vamos usar a foto diretamente como na Home
       
       // Debug logs detalhados
       print('🔧 [OrdersPlacedProvider] Total de pedidos processados: ${orders.length}');
       for (int i = 0; i < orders.length; i++) {
         final order = orders[i];
         print('🔧 [OrdersPlacedProvider] Pedido ${i + 1}: ID=${order.id}');
         print('🔧 [OrdersPlacedProvider] Workshop ID: ${order.workshop?.id}');
         print('🔧 [OrdersPlacedProvider] WorkshopServices count: ${order.workshopServices?.length ?? 0}');
         
         if (order.workshopServices != null && order.workshopServices!.isNotEmpty) {
           for (int j = 0; j < order.workshopServices!.length; j++) {
             final service = order.workshopServices![j];
             print('🔧 [OrdersPlacedProvider] Serviço ${j + 1}: ID=${service.id}');
             print('🔧 [OrdersPlacedProvider] Service object: ${service.service}');
             print('🔧 [OrdersPlacedProvider] Service name: ${service.service?.name}');
             print('🔧 [OrdersPlacedProvider] Service photo: ${service.service?.photo}');
             print('🔧 [OrdersPlacedProvider] WorkshopService photo: ${service.photo}');
           }
         } else {
           print('🔧 [OrdersPlacedProvider] ⚠️ Nenhum workshopService encontrado para este pedido');
         }
         print('🔧 [OrdersPlacedProvider] ---');
       }
       
       return orders;
    } on DioException catch (e) {
      // Tratamento específico para erro 500 na API Scheduling
      if (e.response?.statusCode == 500) {
        print('❌ Erro 500 na API Scheduling (OrdersPlacedProvider): ${e.response?.data}');
        return [];
      }
      rethrow;
    } catch (e) {
      print('❌ Erro inesperado na API Scheduling (OrdersPlacedProvider): $e');
      return [];
    }
  }

       // REMOVIDO: Método de enriquecimento complexo
}
