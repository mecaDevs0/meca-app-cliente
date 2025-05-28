import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/order.dart';
import '../../../data/providers/orders_placed_provider.dart';

class OrdersPlacedController extends GetxController {
  OrdersPlacedController({required OrdersPlacedProvider ordersPlacedProvider})
      : _ordersPlacedProvider = ordersPlacedProvider;

  final OrdersPlacedProvider _ordersPlacedProvider;
  final _orderStatus = RxnInt(null);

  int? get orderStatus => _orderStatus.value;

  final PagingController<int, Order> pagingController =
      PagingController(firstPageKey: 1);
  final _limit = 30;

  @override
  void onInit() {
    pagingController.addPageRequestListener(getAllOrders);
    super.onInit();
  }

  void filterByStatus(int status) {
    _orderStatus.value = status > 0 ? status : null;
    pagingController.refresh();
  }

  Future<void> getAllOrders(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _ordersPlacedProvider.onRequestOrders(
          page: page,
          limit: _limit,
          status: orderStatus,
        );

        final isLastPage = response.length < _limit;
        if (isLastPage) {
          pagingController.appendLastPage(response);
        } else {
          final nextPageKey = page + 1;
          pagingController.appendPage(response, nextPageKey);
        }
      },
    );
  }
}
