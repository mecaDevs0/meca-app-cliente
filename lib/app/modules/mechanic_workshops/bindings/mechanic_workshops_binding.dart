import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/mechanic_workshops_provider.dart';
import '../controllers/mechanic_workshops_controller.dart';

class MechanicWorkshopsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MechanicWorkshopsProvider>(
      () => MechanicWorkshopsProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<MechanicWorkshopsController>(
      () => MechanicWorkshopsController(
        mechanicWorkshopsProvider: Get.find(),
        filterController: Get.find(),
      ),
    );
  }
}
