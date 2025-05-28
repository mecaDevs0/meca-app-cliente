import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/my_vehicles_provider.dart';
import '../controllers/my_vehicles_controller.dart';

class MyVehiclesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyVehiclesProvider>(
      () => MyVehiclesProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<MyVehiclesController>(
      () => MyVehiclesController(
        myVehiclesProvider: Get.find(),
      ),
    );
  }
}
