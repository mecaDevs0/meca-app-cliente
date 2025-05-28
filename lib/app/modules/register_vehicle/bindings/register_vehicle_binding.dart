import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/my_vehicles_provider.dart';
import '../../../data/providers/register_vehicle_provider.dart';
import '../../my_vehicles/controllers/my_vehicles_controller.dart';
import '../controllers/register_vehicle_controller.dart';

class RegisterVehicleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RegisterVehicleProvider>(
      () => RegisterVehicleProvider(
        restClientDio: Get.find(),
      ),
    );
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
    Get.lazyPut<RegisterVehicleController>(
      () => RegisterVehicleController(
        registerVehicleProvider: Get.find(),
        myVehiclesProvider: Get.find(),
      ),
    );
  }
}
