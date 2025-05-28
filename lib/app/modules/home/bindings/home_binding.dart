import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/core_provider.dart';
import '../../../data/providers/home_provider.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../app_filter/controllers/filter_controller.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeProvider>(
      () => HomeProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<UserProfileProvider>(
      () => UserProfileProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<CoreProvider>(
      () => CoreProvider(
        restClientDio: Get.find(),
      ),
    );
    Get.lazyPut<FilterController>(
      () => FilterController(),
    );
    Get.lazyPut<HomeController>(
      () => HomeController(
        homeProvider: Get.find(),
        profileProvider: Get.find(),
        filterController: Get.find(),
      ),
    );
  }
}
