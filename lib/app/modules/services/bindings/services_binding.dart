import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/services_provider.dart';
import '../controllers/services_controller.dart';

class ServicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ServicesProvider>(
      () => ServicesProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<ServicesController>(
      () => ServicesController(
        servicesProvider: Get.find(),
        filterController: Get.find(),
      ),
    );
  }
}
