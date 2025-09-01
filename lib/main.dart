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
  try {
    WidgetsFlutterBinding.ensureInitialized();
    Intl.defaultLocale = 'pt_BR';

    debugPrint('🚀 Iniciando aplicação Meca Cliente...');

    // Inicializa timezone uma única vez durante a inicialização
    tz.initializeTimeZones();
    debugPrint('⏰ Timezone inicializado');

    await Future.wait([
      FirebaseConfig.initialize(),
      BaseHive.initHive(),
      GetStorage.init(),
    ]);
    debugPrint('✅ Serviços básicos inicializados');

    // Usar diretamente o MegaOneSignalConfig que já está implementado no projeto
    await MegaOneSignalConfig.configure(
      appKey: '7bbec33c-bffc-47b1-ab90-a080b7353763',
    );
    debugPrint('🔔 OneSignal configurado');

    // Inicializa o serviço de notificações personalizado para tratar notificações do admin
    final notificationService = NotificationService();
    notificationService.initialize();
    debugPrint('📱 Serviço de notificações inicializado');

    // CORREÇÃO FORÇADA: Força a correção do estado de autenticação
    debugPrint('🔧 Iniciando correção forçada do estado de autenticação...');
    await AuthHelper.forceFixAuthenticationState();
    debugPrint('✅ Correção forçada do estado de autenticação concluída');

    final token = AuthToken.fromCache();
    debugPrint('🔑 Token verificado: ${token != null ? "Presente" : "Ausente"}');

    // Corrige inconsistências entre o token e o status de visitante na inicialização
    if (token != null && AuthHelper.isGuest) {
      debugPrint('🔄 Corrigindo estado: Token presente mas usuário marcado como visitante');
      // Se há um token válido mas o usuário está marcado como visitante, corrige o status
      await AuthHelper.setLoggedIn();
      // Registra o dispositivo quando o usuário tem token válido
      await notificationService.registerDeviceOnLogin();
      debugPrint('✅ Token encontrado durante inicialização, mas usuário estava marcado como visitante. Status corrigido.');
    } else if (token == null && !AuthHelper.isGuest && !AuthHelper.isLoggedIn) {
      debugPrint('🔄 Corrigindo estado: Nenhum token e usuário não marcado como visitante');
      // Se não há token e o usuário não está marcado como visitante ou logado,
      // configura como visitante para evitar comportamentos inesperados
      await AuthHelper.setGuest();
      debugPrint('✅ Nenhum token encontrado e usuário não marcado como visitante. Status definido como visitante.');
    } else if (token != null && AuthHelper.isLoggedIn) {
      debugPrint('🔄 Verificando registro de dispositivo para usuário logado');
      // Se já está logado e tem token, garantir que o dispositivo está registrado
      await notificationService.registerDeviceOnLogin();
      debugPrint('✅ Dispositivo registrado para usuário logado');
    }

    // Log final do estado de autenticação para debug
    debugPrint('📊 Estado final de autenticação:');
    debugPrint('   - Token: ${token != null ? "Presente" : "Ausente"}');
    debugPrint('   - isLoggedIn: ${AuthHelper.isLoggedIn}');
    debugPrint('   - isGuest: ${AuthHelper.isGuest}');

    final String initialRoute = (token == null && !AuthHelper.isGuest)
        ? AppPages.initial
        : Routes.home;
    
    debugPrint('🗺️ Rota inicial definida: $initialRoute');
    
    initializeDateFormatting('pt_BR', null);
    debugPrint('📅 Formatação de data inicializada');

    AliceAdapter.instance(Get.key);
    debugPrint('🔍 Alice Adapter configurado');

    debugPrint('🎨 Iniciando aplicação...');
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
    
    debugPrint('🎉 Aplicação iniciada com sucesso!');
    
  } catch (error, stackTrace) {
    debugPrint('❌ Erro crítico durante inicialização: $error');
    debugPrint('📚 Stack trace: $stackTrace');
    
    // Em caso de erro crítico, tentar inicializar com configuração mínima
    try {
      debugPrint('🔄 Tentando inicialização de emergência...');
      
      WidgetsFlutterBinding.ensureInitialized();
      Intl.defaultLocale = 'pt_BR';
      
      await GetStorage.init();
      
      runApp(
        GetMaterialApp(
          title: 'Meca Cliente',
          initialRoute: Routes.login,
          getPages: AppPages.routes,
          theme: AppTheme.theme,
          builder: (_, child) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro de inicialização',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reinicie o aplicativo',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Tentar reiniciar o app
                        runApp(
                          GetMaterialApp(
                            title: 'Meca Cliente',
                            initialRoute: Routes.login,
                            getPages: AppPages.routes,
                            theme: AppTheme.theme,
                          ),
                        );
                      },
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      
      debugPrint('✅ Inicialização de emergência concluída');
      
    } catch (emergencyError) {
      debugPrint('❌ Erro na inicialização de emergência: $emergencyError');
      
      // Última tentativa com app mínimo
      runApp(
        MaterialApp(
          title: 'Meca Cliente',
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro Crítico',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reinicie o aplicativo ou reinstale',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
