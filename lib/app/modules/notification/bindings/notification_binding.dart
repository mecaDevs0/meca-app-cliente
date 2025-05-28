import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/notification_provider.dart';
import '../controllers/notification_controller.dart';

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationsProvider>(
      () => NotificationsProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<NotificationsController>(
      () => NotificationsController(
        notificationsProvider: Get.find(),
      ),
    );
  }
}
