import 'dart:developer' as console;

import 'package:mega_features/mega_features.dart';

import '../services/notification_service.dart';

/// Extensão do LoginController para integrar com o NotificationService
extension LoginControllerNotificationExtension on LoginController {
  
  /// Método que deve ser chamado após um login bem-sucedido
  /// para registrar o dispositivo no backend para notificações
  Future<void> registerNotificationOnSuccessLogin() async {
    try {
      console.log('Registrando dispositivo para notificações após login bem-sucedido', 
          name: 'LoginControllerNotificationExtension');
      
      final notificationService = NotificationService();
      await notificationService.registerDeviceOnLogin();
      
      console.log('Dispositivo registrado com sucesso para notificações', 
          name: 'LoginControllerNotificationExtension');
    } catch (e) {
      console.log('Erro ao registrar dispositivo para notificações: $e', 
          name: 'LoginControllerNotificationExtension');
    }
  }
}
