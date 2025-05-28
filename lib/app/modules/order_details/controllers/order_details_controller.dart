import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/enums/service_history_type.dart';
import '../../../data/models/budget_service_model.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_history.dart';
import '../../../data/providers/order_details_provider.dart';
import '../../orders_placed/controllers/orders_placed_controller.dart';

class OrderDetailsController extends GetxController {
  OrderDetailsController({required OrderDetailsProvider orderDetailsProvider})
      : _orderDetailsProvider = orderDetailsProvider;

  final OrderDetailsProvider _orderDetailsProvider;

  final _isLoadingDetails = RxBool(false);
  final _orderDetails = Rx<Order?>(Order.empty());
  final _orderHistory = RxList<OrderHistory>.empty();
  final _isLoadingOrderApproval = RxBool(false);
  final _isLoadingRatingOrder = RxBool(false);
  final _isLoadingReproveNewSchedule = RxBool(false);
  final _isLoadingApproveNewSchedule = RxBool(false);
  final _isLoadingCancelOrder = RxBool(false);
  final _isLoadingReproveBudget = RxBool(false);
  final _isLoadingApproveBudget = RxBool(false);

  final _totalValue = RxDouble(0.0);
  final RxList<BudgetServiceModel> _selectedServices =
      RxList<BudgetServiceModel>();
  late String orderId;

  final OrdersPlacedController ordersPlacedController = Get.find();

  bool get isLoadingDetails => _isLoadingDetails.value;
  Order? get orderDetails => _orderDetails.value;
  List<OrderHistory> get orderHistory => _orderHistory.toList();
  bool get isLoadingOrderApproval => _isLoadingOrderApproval.value;
  bool get isLoadingRatingOrder => _isLoadingRatingOrder.value;
  bool get isLoadingReproveNewSchedule => _isLoadingReproveNewSchedule.value;
  bool get isLoadingApproveNewSchedule => _isLoadingApproveNewSchedule.value;
  bool get isLoadingCancelOrder => _isLoadingCancelOrder.value;
  bool get isLoadingReproveBudget => _isLoadingReproveBudget.value;
  bool get isLoadingApproveBudget => _isLoadingApproveBudget.value;
  double get totalValue => _totalValue.value;

  final _expandedServiceType = RxList<ServiceHistoryType>([
    ServiceHistoryType.scheduling,
    ServiceHistoryType.budget,
    ServiceHistoryType.payment,
    ServiceHistoryType.service,
    ServiceHistoryType.approval,
    ServiceHistoryType.completed,
  ]);

  List<ServiceHistoryType> get expandedServiceType =>
      _expandedServiceType.toList();

  List<BudgetServiceModel> get selectedServices => _selectedServices;

  Map<int, Map<String, dynamic>> groupedData = {};

  @override
  Future<void> onInit() async {
    orderId = Get.arguments['orderId'] as String;
    await getOrderDetails();
    _totalValue.value = orderDetails?.diagnosticValue ?? 0.0;
    if (orderDetails?.status == 8) {
      _selectedServices.addAll(
        orderDetails?.budgetServices?.map((budget) => budget) ?? [],
      );
      updateTotalValue();
    }

    super.onInit();
  }

  void toggleServiceType(ServiceHistoryType serviceType) {
    _expandedServiceType.contains(serviceType)
        ? _expandedServiceType.remove(serviceType)
        : _expandedServiceType.add(serviceType);
  }

  void toggleServiceSelection(BudgetServiceModel service) {
    if (_selectedServices.contains(service)) {
      _selectedServices.remove(service);
    } else {
      _selectedServices.add(service);
    }
    updateTotalValue();
  }

  bool isExpanded(ServiceHistoryType serviceType) =>
      _expandedServiceType.contains(serviceType);

  Future<void> getOrderDetails() async {
    _isLoadingDetails.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final orderDetails =
            await _orderDetailsProvider.onRequestOrderDetails(id: orderId);
        final orderHistory =
            await _orderDetailsProvider.onRequestOrderHistory(id: orderId);

        _orderDetails.value = orderDetails;
        _orderHistory.assignAll(orderHistory);
        groupedData.clear();
        _groupScheduleHistory();
      },
      onFinally: () => _isLoadingDetails.value = false,
    );
  }

  void _groupScheduleHistory() {
    for (final item in orderHistory) {
      if (!groupedData.containsKey(item.statusTitle)) {
        groupedData[item.statusTitle!] = {
          'count': 0,
          'items': <OrderHistory>[],
        };
      }

      groupedData[item.statusTitle]!['count'] =
          (groupedData[item.statusTitle]!['count'] as int) + 1;
      (groupedData[item.statusTitle]!['items'] as List<OrderHistory>).add(item);
    }
  }

  Future<bool> cancelOrder() async {
    bool isSuccess = false;
    _isLoadingCancelOrder.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.cancelOrder(orderId);
        isSuccess = true;
      },
      onFinally: () => _isLoadingCancelOrder.value = false,
    );

    return isSuccess;
  }

  Future<void> approveOrder() async {
    _isLoadingOrderApproval.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.approveOrder(orderId);
      },
      onFinally: () {
        _isLoadingOrderApproval.value = false;
        getOrderDetails();
      },
    );
  }

  Future<bool> approveBudget(List<BudgetServiceModel> budgetServices) async {
    bool isSuccess = false;
    _isLoadingApproveBudget.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.approveBudget(orderId, budgetServices);
        isSuccess = true;
      },
      onFinally: () => _isLoadingApproveBudget.value = false,
    );
    return isSuccess;
  }

  Future<bool> reproveBudget(List<BudgetServiceModel> budgetServices) async {
    bool isSuccess = false;
    _isLoadingReproveBudget.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.reproveBudget(orderId, budgetServices);
        isSuccess = true;
      },
      onFinally: () => _isLoadingReproveBudget.value = false,
    );
    return isSuccess;
  }

  Future<bool> ratingOrder(
    int attendanceQuality,
    int serviceQuality,
    int costBenefit,
    String obs,
  ) async {
    _isLoadingRatingOrder.value = true;
    bool isSuccess = false;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.ratingOrder(
          attendanceQuality,
          serviceQuality,
          costBenefit,
          obs,
          orderId,
        );
        await getOrderDetails();
        isSuccess = true;
      },
      onFinally: () => _isLoadingRatingOrder.value = false,
    );

    return isSuccess;
  }

  Future<bool> approveNewSchedule() async {
    bool isSuccess = false;
    _isLoadingApproveNewSchedule.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.approveNewScheduling(orderId);
        isSuccess = true;
      },
      onFinally: () => _isLoadingApproveNewSchedule.value = false,
    );
    return isSuccess;
  }

  Future<bool> reproveNewSchedule() async {
    bool isSuccess = false;
    _isLoadingReproveNewSchedule.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _orderDetailsProvider.reproveNewScheduling(orderId);
        isSuccess = true;
      },
      onFinally: () => _isLoadingReproveNewSchedule.value = false,
    );
    return isSuccess;
  }

  Future<bool> scheduleFreeRepair(int date) async {
    bool isSuccess = false;
    await MegaRequestUtils.load(
      action: () async {
        _orderDetailsProvider.suggestFreeRepair(orderId, date);
        isSuccess = true;
      },
    );

    return isSuccess;
  }

  void updateTotalValue() {
    _totalValue.value = orderDetails?.diagnosticValue ?? 0.0;
    final selectedServices = _selectedServices;
    if (selectedServices.isNotEmpty) {
      _totalValue.value = selectedServices.fold(
        orderDetails?.diagnosticValue ?? 0.0,
        (sum, service) => sum + (service.value ?? 0.0),
      );
    }
  }

  List<BudgetServiceModel> get mergedList {
    final mergedList = <BudgetServiceModel>[];

    final List<BudgetServiceModel> approvedBudgets = <BudgetServiceModel>[];

    for (final service in orderDetails?.maintainedBudgetServices ?? []) {
      service.isApproved = true;
      approvedBudgets.add(service);
    }

    mergedList.addAll(orderDetails?.excludedBudgetServices ?? []);
    mergedList.addAll(approvedBudgets);

    return mergedList;
  }
}
