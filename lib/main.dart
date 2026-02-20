import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/core/core_screen.dart';
import 'screens/help/help_center_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/services/services_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/vehicles/add_vehicle_screen.dart';
import 'screens/vehicles/edit_vehicle_screen.dart';
import 'screens/vehicles/my_vehicles_screen.dart';
import 'screens/workshops/workshop_detail_screen.dart';
import 'screens/mia/mia_chat_screen.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'services/api_service.dart';
import 'providers/notification_provider.dart';

// Global navigator key para navegação de notificações
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Wrapper para capturar erros não tratados
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('Flutter Error: ${details.exception}');
    print('Stack: ${details.stack}');
  };
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    // Silenciar erro de inicialização
  }
  
  // Inicializar serviços de notificações de forma assíncrona (não bloqueia o app)
  // IMPORTANTE: Não usar await aqui para não bloquear a inicialização
  Future.microtask(() async {
    try {
      // Inicializar OneSignal
      await OneSignalService.initialize();
      
      // Inicializar notificações locais
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();
      
      // Configurar handler de navegação de notificações
      NotificationService.onNotificationClick = (String? payload) {
        if (payload == null) return;
        
        try {
          final data = payload.split('|');
          if (data.length >= 2) {
            final type = data[0];
            final id = data[1];
            
            switch (type) {
              case 'booking':
              case 'order':
                navigatorKey.currentState?.pushNamed('/order-detail', arguments: {'id': id});
                break;
              case 'workshop':
                navigatorKey.currentState?.pushNamed('/workshop-detail', arguments: {'id': id});
                break;
              case 'notifications':
                navigatorKey.currentState?.pushNamed('/notifications');
                break;
              case 'orders':
                navigatorKey.currentState?.pushNamed('/orders');
                break;
              default:
                break;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Erro ao navegar a partir de notificação: $e');
          }
        }
      };
      
      // Aguardar um pouco para garantir que o token está disponível
      // Tentar salvar o token periodicamente até conseguir
      Future.delayed(const Duration(seconds: 2), () async {
        for (int attempt = 0; attempt < 5; attempt++) {
          try {
            final playerId = OneSignalService.getSubscriptionId();
            if (playerId != null && playerId.isNotEmpty) {
              // Salvar token no backend se usuário estiver logado
              final apiService = ApiService();
              final prefs = await apiService.getStorage();
              final token = prefs.getString('token');
              if (token != null) {
                // Associar external user ID ao OneSignal
                try {
                  final userId = prefs.getString('user_id');
                  if (userId != null) {
                    await OneSignalService.setExternalUserId(userId);
                  }
                } catch (e) {
                  // Silenciar erro
                }
                
                final result = await apiService.saveDeviceToken(playerId);
                if (result['success'] == true) {
                  break; // Sucesso, parar tentativas
                }
              } else {
                break; // Usuário não logado, não precisa continuar
              }
            }
          } catch (e) {
            // Silenciar erro
          }
          
          // Aguardar antes da próxima tentativa
          if (attempt < 4) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      });
  } catch (e) {
    // Silenciar erro de inicialização de serviços
  }
  });
  
  try {
    runApp(const MecaClienteApp());
  } catch (e) {
    // Tentar rodar app básico em caso de erro
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Erro ao inicializar app: $e'),
          ),
        ),
      ),
    );
  }
}

class MecaClienteApp extends StatelessWidget {
  const MecaClienteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'MECA Cliente',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: themeService.themeMode,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const SplashScreen());
                case '/login':
                  return MaterialPageRoute(builder: (_) => const LoginScreen());
                case '/home':
                  return MaterialPageRoute(builder: (_) => const CoreScreen());
                case '/workshops':
                  return MaterialPageRoute(builder: (_) => const CoreScreen(initialIndex: 1));
                case '/workshop-detail':
                  final args = settings.arguments as Map<String, dynamic>? ?? {};
                  final distanceKm = args['distance_km'] is num
                      ? (args['distance_km'] as num).toDouble()
                      : null;
                  return MaterialPageRoute(
                    builder: (_) => WorkshopDetailScreen(
                      workshopId: args['id'] ?? args['workshop_id'] ?? '',
                      distanceKm: distanceKm,
                    ),
                  );
                case '/booking':
                  return MaterialPageRoute(builder: (_) => const CoreScreen(initialIndex: 1));
                case '/services':
                  return MaterialPageRoute(builder: (_) => const ServicesScreen());
                case '/my-vehicles':
                case '/vehicles':
                  return MaterialPageRoute(builder: (_) => const MyVehiclesScreen());
                case '/add-vehicle':
                  return MaterialPageRoute(builder: (_) => const AddVehicleScreen());
                case '/edit-vehicle':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => EditVehicleScreen(vehicle: args),
                  );
                case '/orders':
                  final ordersTab = settings.arguments as int?;
                  return MaterialPageRoute(
                    builder: (_) => CoreScreen(initialIndex: 2, ordersInitialTab: ordersTab),
                  );
                case '/order-detail':
                  final args = settings.arguments as Map<String, dynamic>? ?? {};
                  // Se receber apenas ID, criar objeto booking mínimo para carregar dados depois
                  final booking = args.containsKey('id') && !args.containsKey('status')
                      ? {'id': args['id']}
                      : args;
                  return MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(booking: booking),
                  );
                case '/profile':
                  return MaterialPageRoute(builder: (_) => const ProfileScreen());
                case '/edit-profile':
                  return MaterialPageRoute(builder: (_) => const EditProfileScreen());
                case '/notifications':
                  return MaterialPageRoute(builder: (_) => const NotificationsScreen());
                case '/help':
                  return MaterialPageRoute(builder: (_) => const HelpCenterScreen());
                case '/mia-chat':
                  return MaterialPageRoute(builder: (_) => const MiaChatScreen());
                default:
                  return MaterialPageRoute(builder: (_) => const SplashScreen());
              }
            },
          );
        },
      ),
    );
  }
}
