import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/register_provider.dart';
import '../controllers/register_controller.dart';

class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RegisterProvider>(
      () => RegisterProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<RegisterController>(
      () => RegisterController(
        registerProvider: Get.find(),
      ),
    );
  }
}
