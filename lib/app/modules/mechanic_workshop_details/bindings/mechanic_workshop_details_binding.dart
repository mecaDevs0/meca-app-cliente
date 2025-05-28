import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/mechanic_workshop_details_provider.dart';
import '../controllers/mechanic_workshop_details_controller.dart';

class MechanicWorkshopDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MechanicWorkshopDetailsProvider>(
      () => MechanicWorkshopDetailsProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<MechanicWorkshopDetailsController>(
      () => MechanicWorkshopDetailsController(
        mechanicWorkshopDetailsProvider: Get.find(),
      ),
    );
  }
}
