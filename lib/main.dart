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
import 'screens/workshops/favorite_workshops_screen.dart';
import 'screens/mia/mia_chat_screen.dart';
import 'screens/payment/payment_history_screen.dart';
import 'screens/pre_compra/pre_compra_detail_screen.dart';
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
      
      // Helper de navegação por dados de notificação (OneSignal ou local)
      void navigateFromNotificationData(Map<String, dynamic> data) {
        final type = data['type']?.toString() ?? '';
        final id = data['id']?.toString() ?? data['pre_compra_id']?.toString();
        final bookingId = data['booking_id']?.toString();
        final workshopId = data['workshop_id']?.toString();

        if (type == 'pre_compra' || type.contains('pre_compra') || type.contains('laudo')) {
          if (id != null && id.isNotEmpty) {
            navigatorKey.currentState?.pushNamed('/pre-compra-detail', arguments: {'id': id});
            return;
          }
        }

        if (bookingId != null && bookingId.isNotEmpty) {
          navigatorKey.currentState?.pushNamed('/order-detail', arguments: {'id': bookingId});
          return;
        }

        switch (type) {
          case 'booking':
          case 'booking_created':
          case 'booking_confirmed':
          case 'booking_cancelled':
          case 'new_booking':
            final bId = id ?? bookingId;
            if (bId != null && bId.isNotEmpty) {
              navigatorKey.currentState?.pushNamed('/order-detail', arguments: {'id': bId});
            } else {
              navigatorKey.currentState?.pushNamed('/orders');
            }
            break;
          case 'workshop':
            if (workshopId != null && workshopId.isNotEmpty) {
              navigatorKey.currentState?.pushNamed('/workshop-detail', arguments: {'id': workshopId});
            }
            break;
          case 'orders':
            navigatorKey.currentState?.pushNamed('/orders');
            break;
          case 'maintenance_reminder':
            // Navigate to booking flow or services screen
            final serviceId = data['service_id']?.toString();
            if (serviceId != null && serviceId.isNotEmpty) {
              navigatorKey.currentState?.pushNamed('/services');
            } else {
              navigatorKey.currentState?.pushNamed('/home');
            }
            break;
          default:
            break;
        }
      }

      // Handler para toque em push notification via OneSignal
      OneSignalService.onNotificationOpened = (Map<String, dynamic> data) {
        try {
          navigateFromNotificationData(data);
        } catch (e) {
          if (kDebugMode) print('Erro ao navegar por OneSignal: $e');
        }
      };

      // Configurar handler de navegação de notificações locais (flutter_local_notifications)
      NotificationService.onNotificationClick = (String? payload) {
        if (payload == null) return;

        try {
          // Tentar parsear como JSON primeiro
          Map<String, dynamic>? jsonData;
          try {
            jsonData = Map<String, dynamic>.from(
              (payload.startsWith('{'))
                  ? (Map<String, dynamic>.from({})) // placeholder
                  : {},
            );
          } catch (_) {}

          // Fallback: formato legado type|id
          final parts = payload.split('|');
          if (parts.length >= 2) {
            final type = parts[0];
            final id = parts[1];
            navigateFromNotificationData({'type': type, 'id': id});
          }
        } catch (e) {
          if (kDebugMode) print('Erro ao navegar a partir de notificação local: $e');
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
                case '/pre-compra-detail':
                  final args = settings.arguments as Map<String, dynamic>? ?? {};
                  return MaterialPageRoute(
                    builder: (_) => PreCompraDetailScreen(
                      preCompraId: args['id']?.toString() ?? '',
                    ),
                  );
                case '/payment-history':
                  return MaterialPageRoute(builder: (_) => const PaymentHistoryScreen());
                case '/help':
                  return MaterialPageRoute(builder: (_) => const HelpCenterScreen());
                case '/mia-chat':
                  return MaterialPageRoute(builder: (_) => const MiaChatScreen());
                case '/favorite-workshops':
                  return MaterialPageRoute(builder: (_) => const FavoriteWorkshopsScreen());
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
