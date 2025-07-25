import 'package:meca_cliente/app/modules/request_appointment/controllers/request_appointment_controller.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/core_provider.dart';
import '../../../data/providers/request_appointment_provider.dart';

class RequestAppointmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RequestAppointmentProvider>(
      () => RequestAppointmentProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<CoreProvider>(
      () => CoreProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<RequestAppointmentController>(
      () => RequestAppointmentController(
        requestAppointmentProvider: Get.find(),
        coreProvider: Get.find(),
      ),
    );
  }
}
