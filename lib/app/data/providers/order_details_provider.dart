import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/budget_service_model.dart';
import '../models/order.dart';
import '../models/order_history.dart';
import '../models/rating.dart';
import '../models/scheduling/scheduling.dart';

class OrderDetailsProvider {
  OrderDetailsProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Order> onRequestOrderDetails({required String id}) async {
    final response = await _restClientDio.get('${BaseUrls.scheduling}/$id');
    return Order.fromJson(response.data);
  }

  Future<List<OrderHistory>> onRequestOrderHistory({required String id}) async {
    final queryParameters = <String, dynamic>{
      'limit': 0,
      'dataBlocked': 0,
      'schedulingId': id,
    };
    final response = await _restClientDio.get(
      BaseUrls.schedulingHistory,
      queryParameters: queryParameters,
    );

    return (response.data as List)
        .map<OrderHistory>(
          (orderHistory) =>
              OrderHistory.fromJson(orderHistory as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> cancelOrder(String orderId) async {
    await _restClientDio.delete('${BaseUrls.scheduling}/$orderId');
  }

  Future<void> approveOrder(String orderId) async {
    await _restClientDio.post(
      BaseUrls.confirmService,
      data: {
        'schedulingId': orderId,
        'confirmServiceStatus': 0,
      },
    );
  }

  Future<Scheduling> approveBudget(
    String orderId,
    List<BudgetServiceModel> budgetServices,
  ) async {
    final response = await _restClientDio.post(
      BaseUrls.confirmBudget,
      data: {
        'schedulingId': orderId,
        'confirmBudgetStatus': 0,
        'budgetServices': budgetServices,
      },
    );

    return Scheduling.fromJson(response.data);
  }

  Future<Scheduling> reproveBudget(
    String orderId,
    List<BudgetServiceModel> budgetServices,
  ) async {
    final response = await _restClientDio.post(
      BaseUrls.confirmBudget,
      data: {
        'schedulingId': orderId,
        'confirmBudgetStatus': 1,
        'budgetServices': budgetServices,
      },
    );

    return Scheduling.fromJson(response.data);
  }

  Future<Rating> ratingOrder(
    int attendanceQuality,
    int serviceQualiy,
    int costBenefit,
    String obs,
    String schedulingId,
  ) async {
    final response = await _restClientDio.post(
      BaseUrls.rating,
      data: {
        'attendanceQuality': attendanceQuality,
        'serviceQuality': serviceQualiy,
        'costBenefit': costBenefit,
        'observations': obs,
        'schedulingId': schedulingId,
      },
    );

    return Rating.fromJson(response.data);
  }

  Future<Scheduling> approveNewScheduling(String schedulingId) async {
    final response = await _restClientDio.post(
      BaseUrls.confirmNewSchedule,
      data: {
        'schedulingId': schedulingId,
        'confirmSchedulingStatus': 0,
      },
    );

    return Scheduling.fromJson(response.data);
  }

  Future<Scheduling> reproveNewScheduling(String schedulingId) async {
    final response = await _restClientDio.post(
      BaseUrls.confirmNewSchedule,
      data: {
        'schedulingId': schedulingId,
        'confirmSchedulingStatus': 1,
      },
    );

    return Scheduling.fromJson(response.data);
  }

  Future<Scheduling> suggestFreeRepair(String id, int date) async {
    final response = await _restClientDio.post(
      BaseUrls.suggestFreeRepair,
      data: {
        'id': id,
        'date': date,
      },
    );

    return Scheduling.fromJson(response.data);
  }
}
