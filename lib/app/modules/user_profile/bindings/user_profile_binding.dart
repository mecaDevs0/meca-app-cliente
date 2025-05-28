import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/user_profile_provider.dart';
import '../controllers/user_profile_controller.dart';

class UserProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserProfileProvider>(
      () => UserProfileProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<UserProfileController>(
      () => UserProfileController(
        userProfileProvider: Get.find(),
        formAddressController: Get.find(),
      ),
    );
  }
}
