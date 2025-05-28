import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/complete_registration_provider.dart';
import '../controllers/complete_registration_controller.dart';

class CompleteRegistrationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CompleteRegistrationProvider>(
      () => CompleteRegistrationProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<CompleteRegistrationController>(
      () => CompleteRegistrationController(
        completeRegistrationProvider: Get.find(),
        formAddressController: Get.find(),
      ),
    );
  }
}
