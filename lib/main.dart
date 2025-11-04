import 'package:flutter/material.dart';
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
import 'services/theme_service.dart';
import 'services/notification_service.dart';

// Global navigator key para navegação de notificações
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar serviço de notificações
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
      print('Erro ao navegar a partir de notificação: $e');
    }
  };
  
  runApp(const MecaClienteApp());
}

class MecaClienteApp extends StatelessWidget {
  const MecaClienteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
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
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => WorkshopDetailScreen(workshopId: args['id'] ?? args['workshop_id'] ?? ''),
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
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(booking: args),
                  );
                case '/profile':
                  return MaterialPageRoute(builder: (_) => const ProfileScreen());
                case '/edit-profile':
                  return MaterialPageRoute(builder: (_) => const EditProfileScreen());
                case '/notifications':
                  return MaterialPageRoute(builder: (_) => const NotificationsScreen());
                case '/help':
                  return MaterialPageRoute(builder: (_) => const HelpCenterScreen());
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