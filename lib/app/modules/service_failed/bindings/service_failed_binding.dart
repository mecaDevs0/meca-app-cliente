import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/service_failed_provider.dart';
import '../controllers/service_failed_controller.dart';

class ServiceFailedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ServiceFailedProvider>(
      () => ServiceFailedProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<ServiceFailedController>(
      () => ServiceFailedController(
        serviceFailedProvider: Get.find(),
      ),
    );
  }
}
