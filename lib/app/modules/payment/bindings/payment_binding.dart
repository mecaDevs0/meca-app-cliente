import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/payment_provider.dart';
import '../controllers/payment_controller.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentProvider>(
      () => PaymentProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<PaymentController>(
      () => PaymentController(
        paymentProvider: Get.find(),
      ),
    );
  }
}
