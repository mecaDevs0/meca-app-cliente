import 'dart:io';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';

class OneSignalService {
  static String get _appId => AppConfig.oneSignalAppId;
  
  static Future<void> initialize() async {
    if (_appId == 'YOUR_ONESIGNAL_APP_ID_CLIENTE_HERE' || _appId.isEmpty) {
      return;
    }
    
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none); // Desabilitar logs verbosos
      OneSignal.initialize(_appId);
      
      // Solicitar permissão runtime para Android 13+ (POST_NOTIFICATIONS)
      if (Platform.isAndroid) {
        try {
          final notificationPermission = await Permission.notification.status;
          if (notificationPermission.isDenied) {
            await Permission.notification.request();
          }
        } catch (e) {
          // Silenciar erro
        }
      }
      
      // Solicitar permissão de notificações via OneSignal
      await OneSignal.Notifications.requestPermission(true);
      
      _setupHandlers();
    } catch (e) {
      // Silenciar erro de inicialização
    }
  }
  
  static void _setupHandlers() {
    // Handler para quando a notificação é clicada
    OneSignal.Notifications.addClickListener((event) {
      _handleNotificationOpened(event);
    });
    
    // Handler para quando a notificação chega com o app em foreground
    // IMPORTANTE: Sempre chamar display() para garantir que a notificação apareça
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      // Sempre exibir a notificação, mesmo em foreground
      event.notification.display();
    });
    
    // Listener para mudanças no status de subscription
    OneSignal.User.pushSubscription.addObserver((state) {
      // Silenciar mudanças de subscription
    });
  }
  
  static void _handleNotificationOpened(OSNotificationClickEvent event) {
    // Navegação será tratada pelo NotificationService.onNotificationClick
    // O OneSignal já exibe a notificação automaticamente
    // Não precisa de logs aqui
  }
  
  static Future<void> setExternalUserId(String userId) async {
    await OneSignal.login(userId);
  }
  
  static Future<void> removeExternalUserId() async {
    await OneSignal.logout();
  }
  
  static String? getSubscriptionId() {
    return OneSignal.User.pushSubscription.id;
  }
  
  static String? getSubscriptionToken() {
    return OneSignal.User.pushSubscription.token;
  }
  
  static bool isSubscribed() {
    return OneSignal.User.pushSubscription.optedIn ?? false;
  }
}

