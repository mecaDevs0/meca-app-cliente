import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/core/core_screen.dart';
import 'screens/help/help_center_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/vehicles/add_vehicle_screen.dart';
import 'screens/vehicles/my_vehicles_screen.dart';
import 'services/theme_service.dart';

void main() {
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
            return MaterialPageRoute(builder: (_) => const CoreScreen());
          case '/workshop-detail':
            return MaterialPageRoute(builder: (_) => const CoreScreen());
          case '/booking':
            return MaterialPageRoute(builder: (_) => const CoreScreen());
          case '/my-vehicles':
            return MaterialPageRoute(builder: (_) => const MyVehiclesScreen());
          case '/add-vehicle':
            return MaterialPageRoute(builder: (_) => const AddVehicleScreen());
          case '/orders':
            return MaterialPageRoute(builder: (_) => const OrdersScreen());
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