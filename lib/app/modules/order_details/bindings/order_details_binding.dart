import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/order_details_provider.dart';
import '../controllers/order_details_controller.dart';

class OrderDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrderDetailsProvider>(
      () => OrderDetailsProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<OrderDetailsController>(
      () => OrderDetailsController(
        orderDetailsProvider: Get.find(),
      ),
    );
  }
}
