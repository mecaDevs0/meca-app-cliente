import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/firebase/firebase_config.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app/application_binding.dart';
import 'app/core/utils/auth_helper.dart';
import 'app/data/cache/base_hive.dart';
import 'app/routes/app_pages.dart';
import 'app/services/notification_service.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';

  // Inicializa timezone uma única vez durante a inicialização
  tz.initializeTimeZones();

  await Future.wait([
    FirebaseConfig.initialize(),
    BaseHive.initHive(),
    GetStorage.init(),
  ]);

  // Usar diretamente o MegaOneSignalConfig que já está implementado no projeto
  await MegaOneSignalConfig.configure(
    appKey: '7bbec33c-bffc-47b1-ab90-a080b7353763',
  );

  // Inicializa o serviço de notificações personalizado para tratar notificações do admin
  final notificationService = NotificationService();
  notificationService.initialize();

  // CORREÇÃO FORÇADA: Força a correção do estado de autenticação
  await AuthHelper.forceFixAuthenticationState();

  final token = AuthToken.fromCache();

  // Corrige inconsistências entre o token e o status de visitante na inicialização
  if (token != null && AuthHelper.isGuest) {
    // Se há um token válido mas o usuário está marcado como visitante, corrige o status
    await AuthHelper.setLoggedIn();
    // Registra o dispositivo quando o usuário tem token válido
    await notificationService.registerDeviceOnLogin();
    debugPrint('Token encontrado durante inicialização, mas usuário estava marcado como visitante. Status corrigido.');
  } else if (token == null && !AuthHelper.isGuest && !AuthHelper.isLoggedIn) {
    // Se não há token e o usuário não está marcado como visitante ou logado,
    // configura como visitante para evitar comportamentos inesperados
    await AuthHelper.setGuest();
    debugPrint('Nenhum token encontrado e usuário não marcado como visitante. Status definido como visitante.');
  } else if (token != null && AuthHelper.isLoggedIn) {
    // Se já está logado e tem token, garantir que o dispositivo está registrado
    await notificationService.registerDeviceOnLogin();
  }

  // Log final do estado de autenticação para debug
  debugPrint('Estado final de autenticação:');
  debugPrint('- Token: ${token != null ? "Presente" : "Ausente"}');
  debugPrint('- isLoggedIn: ${AuthHelper.isLoggedIn}');
  debugPrint('- isGuest: ${AuthHelper.isGuest}');

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
