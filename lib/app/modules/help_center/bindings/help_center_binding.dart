import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/help_center_provider.dart';
import '../controllers/help_center_controller.dart';

class HelpCenterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HelpCenterProvider>(
      () => HelpCenterProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<HelpCenterController>(
      () => HelpCenterController(
        helpCenterProvider: Get.find(),
      ),
    );
  }
}
