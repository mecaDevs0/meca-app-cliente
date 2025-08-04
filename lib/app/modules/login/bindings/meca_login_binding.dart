import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../../controllers/meca_login_controller.dart';

class MecaLoginBinding extends Bindings {
  final String _homeRoute;
  final String? pathLogin;
  final String registerRoute;
  final bool isAnonymous;

  MecaLoginBinding({
    required String homeRoute,
    this.pathLogin,
    this.registerRoute = '',
    this.isAnonymous = false,
  }) : _homeRoute = homeRoute;

  @override
  void dependencies() {
    // Manter o LoginProvider original
    Get.lazyPut<LoginProvider>(
      () => LoginProvider(
        restClientDio: Get.find(),
        pathLogin: pathLogin,
      ),
    );

    // Substituir o LoginController pelo MecaLoginController
    Get.lazyPut<MecaLoginController>(
      () => MecaLoginController(
        loginProvider: Get.find(),
        homeRoute: _homeRoute,
        isAnonymous: isAnonymous,
      ),
    );
  }
}
