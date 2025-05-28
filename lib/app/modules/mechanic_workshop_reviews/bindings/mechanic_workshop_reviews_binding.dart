import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/mechanic_workshop_reviews_provider.dart';
import '../controllers/mechanic_workshop_reviews_controller.dart';

class MechanicWorkshopReviewsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MechanicWorkshopReviewsProvider>(
      () => MechanicWorkshopReviewsProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<MechanicWorkshopReviewsController>(
      () => MechanicWorkshopReviewsController(
        mechanicWorkshopReviewsProvider: Get.find(),
      ),
    );
  }
}
