import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/orders_placed_provider.dart';
import '../controllers/orders_placed_controller.dart';

class OrdersPlacedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrdersPlacedProvider>(
      () => OrdersPlacedProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<OrdersPlacedController>(
      () => OrdersPlacedController(
        ordersPlacedProvider: Get.find(),
      ),
    );
  }
}
