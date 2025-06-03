import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/firebase/firebase_config.dart';
import 'package:meca_cliente/app/core/utils/auth_helper.dart';

import 'app/application_binding.dart';
import 'app/data/cache/base_hive.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';

  await Future.wait([
    FirebaseConfig.initialize(),
    BaseHive.initHive(),
    GetStorage.init(),
  ]);
  await MegaOneSignalConfig.configure(
    appKey: '7bbec33c-bffc-47b1-ab90-a080b7353763',
  );

  final token = AuthToken.fromCache();

  final String initialRoute = (token == null && !AuthHelper.isGuest)
      ? AppPages.initial
      : Routes.home;
  initializeDateFormatting('pt_BR', null);

  AliceAdapter.instance(Get.key);

  runApp(
    GetMaterialApp(
      title: 'Meca Cliente',
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      initialBinding: ApplicationBinding(),
      theme: AppTheme.theme,
      builder: (_, child) {
        return MegaBannerEnv(
          location: BannerLocation.topStart,
          navigationKey: Get.key, // Use a navigationKey global do GetX
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}
