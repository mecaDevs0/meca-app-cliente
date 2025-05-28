import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/services_provider.dart';
import '../controllers/service_details_controller.dart';

class ServiceDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ServicesProvider>(
      () => ServicesProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<ServiceDetailsController>(
      () => ServiceDetailsController(
        servicesProvider: Get.find(),
      ),
    );
  }
}
