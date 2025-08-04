import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../../controllers/meca_login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    // Injetar o LoginProvider
    Get.lazyPut<LoginProvider>(
      () => LoginProvider(
        restClientDio: Get.find(),
      ),
    );

    // Injetar o MecaLoginController em vez do LoginController padrão
    Get.lazyPut<MecaLoginController>(
      () => MecaLoginController(
        loginProvider: Get.find(),
        homeRoute: '/home',
        isAnonymous: false,
      ),
    );
  }
}
