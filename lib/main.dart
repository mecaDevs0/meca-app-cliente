import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/login_screen.dart';
import 'screens/core/core_screen.dart';
import 'screens/help/help_center_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/services/services_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/vehicles/add_vehicle_screen.dart';
import 'screens/vehicles/edit_vehicle_screen.dart';
import 'screens/vehicles/my_vehicles_screen.dart';
import 'screens/workshops/workshop_detail_screen.dart';
import 'screens/workshops/favorite_workshops_screen.dart';
import 'screens/mia/mia_chat_screen.dart';
import 'screens/payment/payment_history_screen.dart';
import 'screens/pre_compra/pre_compra_detail_screen.dart';
import 'screens/loyalty/loyalty_screen.dart';
import 'screens/referral/referral_screen.dart';
import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'services/api_service.dart';
import 'services/appsflyer_service.dart';
import 'providers/notification_provider.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// Global navigator key para navegação de notificações
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Flag de coordenação: deep link handler seta true para impedir SplashScreen de sobrescrever a navegação
bool deepLinkNavigated = false;

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
            final serviceId = data['service_id']?.toString();
            if (serviceId != null && serviceId.isNotEmpty) {
              navigatorKey.currentState?.pushNamed('/services');
            } else {
              navigatorKey.currentState?.pushNamed('/home');
            }
            break;
          case 'review_incentive':
            final reviewBookingId = data['booking_id']?.toString();
            if (reviewBookingId != null && reviewBookingId.isNotEmpty) {
              navigatorKey.currentState?.pushNamed('/order-detail', arguments: {'id': reviewBookingId});
            }
            break;
          case 'referral_reward':
            navigatorKey.currentState?.pushNamed('/home');
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
      
      // Identificar usuário no OneSignal e salvar device token
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          final apiService = ApiService();
          final prefs = await apiService.getStorage();
          final token = prefs.getString('token');
          if (token == null) return;

          // Identificar o usuário IMEDIATAMENTE (não depende de subscription)
          final userId = prefs.getString('user_id');
          if (userId != null) {
            try {
              await OneSignalService.setExternalUserId(userId);
            } catch (e) {
              // Silenciar erro
            }
          }

          // Aguardar subscription com retry
          for (int attempt = 0; attempt < 6; attempt++) {
            try {
              final playerId = OneSignalService.getSubscriptionId();
              if (playerId != null && playerId.isNotEmpty) {
                final result = await apiService.saveDeviceToken(playerId);
                if (result['success'] == true) break;
              }
            } catch (e) {
              // Silenciar erro
            }
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          // Silenciar erro
        }
      });
  } catch (e) {
    // Silenciar erro de inicialização de serviços
  }
  });

  // Initialize AppsFlyer (after OneSignal)
  Future.microtask(() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await AppsFlyerService.instance.init();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        AppsFlyerService.instance.setCustomerUserId(userId);
      }
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Init error: $e');
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

class MecaClienteApp extends StatefulWidget {
  const MecaClienteApp({Key? key}) : super(key: key);

  @override
  State<MecaClienteApp> createState() => _MecaClienteAppState();
}

class _MecaClienteAppState extends State<MecaClienteApp> {
  late final AppLinks _appLinks;
  Uri? _lastHandledUri;
  int _lastHandledAt = 0;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((Uri uri) {
      debugPrint('[DeepLink] stream received: $uri');
      Future.delayed(const Duration(milliseconds: 300), () => _handleDeepLink(uri));
    });
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DeepLink] initial link: $uri');
        Future.delayed(const Duration(seconds: 1), () => _handleDeepLink(uri));
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Debounce: ignorar mesma URI em menos de 2 segundos
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastHandledUri?.toString() == uri.toString() &&
        (now - _lastHandledAt) < 2000) {
      debugPrint('[DeepLink] skipped duplicate: $uri');
      return;
    }
    _lastHandledUri = uri;
    _lastHandledAt = now;

    final pathSegments = uri.pathSegments;
    String? workshopId;

    // meca://workshop/{id}
    if (pathSegments.length >= 2 && pathSegments[0] == 'workshop') {
      workshopId = pathSegments[1];
    }
    // https://api.mecabr.com/share/workshop/{id}
    if (pathSegments.length >= 3 && pathSegments[0] == 'share' && pathSegments[1] == 'workshop') {
      workshopId = pathSegments[2];
    }
    // https://www.mecabr.com/oficina/{id}
    if (pathSegments.length >= 2 && pathSegments[0] == 'oficina') {
      workshopId = pathSegments[1];
    }

    // Save referral code from ?ref=CODE
    final refCode = uri.queryParameters['ref'];
    if (refCode != null && refCode.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_referral_code', refCode);
      } catch (_) {}
    }

    if (workshopId != null && workshopId.isNotEmpty) {
      deepLinkNavigated = true;
      debugPrint('[DeepLink] navigating to workshop: $workshopId');

      for (int i = 0; i < 10; i++) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          // Colocar Home na base da stack e workshop-detail por cima
          nav.pushNamedAndRemoveUntil('/home', (route) => false);
          nav.pushNamed('/workshop-detail', arguments: {'id': workshopId});
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('pt', 'BR'),
              Locale('en', 'US'),
            ],
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const SplashScreen());
                case '/onboarding':
                  return MaterialPageRoute(builder: (_) => const OnboardingScreen());
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
                case '/loyalty':
                  return MaterialPageRoute(builder: (_) => const LoyaltyScreen());
                case '/referral':
                  return MaterialPageRoute(builder: (_) => const ReferralScreen());
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
