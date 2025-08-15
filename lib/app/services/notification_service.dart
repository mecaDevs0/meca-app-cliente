import 'dart:developer' as console;

import 'package:meca_cliente/app/data/providers/user_profile_provider.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../core/app_urls.dart';
import '../core/args/workshop_args.dart';
import '../data/models/profile.dart';
import '../routes/app_pages.dart';

/// Serviço de gerenciamento de notificações.
///
/// Este serviço lida com a configuração e o tratamento de notificações push,
/// especialmente as vindas do painel de Admin.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    try {
      console.log('🔔 [NotificationService] Iniciando serviço de notificações...', name: 'NotificationService');
      
      // Configurar OneSignal com App ID correto para clientes
      OneSignal.initialize("7bbec33c-bffc-47b1-ab90-a080b7353763");
      
      console.log('🔔 [NotificationService] OneSignal inicializado com App ID: 7bbec33c-bffc-47b1-ab90-a080b7353763');
      
      // Solicitar permissões
      OneSignal.Notifications.requestPermission(true);
      
      console.log('🔔 [NotificationService] Permissões solicitadas');
      
      // Configurar handlers
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        console.log('🔔 [NotificationService] Notificação recebida em foreground: ${event.notification.title}');
        console.log('🔔 [NotificationService] Dados extras: ${event.notification.additionalData}');
        event.notification.display();
      });

      OneSignal.Notifications.addClickListener((event) {
        console.log('🔔 [NotificationService] Notificação clicada: ${event.notification.title}');
        console.log('🔔 [NotificationService] Dados extras: ${event.notification.additionalData}');
        _handleNotificationNavigation(event.notification);
      });

      console.log('🔔 [NotificationService] Handlers configurados');
      
      // Aguardar um pouco para garantir que o OneSignal esteja inicializado
      await Future.delayed(const Duration(seconds: 2));
      
      // Verificar se o OneSignal está funcionando
      final deviceState = OneSignal.User.pushSubscription;
      console.log('🔔 [NotificationService] Device State: ${deviceState.id}');
      console.log('🔔 [NotificationService] Push Subscription: ${deviceState.optedIn}');
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro na inicialização: $e', name: 'NotificationService');
    }
  }

  /// Registra o dispositivo no OneSignal e no backend
  Future<void> registerDeviceOnLogin() async {
    try {
      console.log('🔔 [NotificationService] Iniciando registro do dispositivo...', name: 'NotificationService');
      
      // Aguardar um pouco para garantir que o OneSignal esteja inicializado
      await Future.delayed(const Duration(seconds: 2));
      
      // Verificar se o OneSignal está inicializado
      final deviceState = OneSignal.User.pushSubscription;
      console.log('🔔 [NotificationService] OneSignal device state: ${deviceState.id}');
      
      if (deviceState.id == null || deviceState.id!.isEmpty) {
        console.log('🔔 [NotificationService] Device ID não disponível, aguardando...', name: 'NotificationService');
        // Aguardar mais um pouco e tentar novamente
        await Future.delayed(const Duration(seconds: 3));
      }
      
      final deviceId = deviceState.id;
      console.log('🔔 [NotificationService] Device ID: $deviceId', name: 'NotificationService');
      
      if (deviceId != null && deviceId.isNotEmpty) {
        await _registerDevice(deviceId);
      } else {
        console.log('🔔 [NotificationService] Device ID ainda não disponível', name: 'NotificationService');
        // Tentar novamente em alguns segundos
        Future.delayed(const Duration(seconds: 5), () async {
          await registerDeviceOnLogin();
        });
      }
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro no registro do dispositivo: $e', name: 'NotificationService');
    }
  }

  /// Força o registro do dispositivo (usado quando o registro automático falha)
  Future<void> forceRegisterDevice() async {
    try {
      console.log('🔔 [NotificationService] Forçando registro do dispositivo...', name: 'NotificationService');
      
      final deviceState = OneSignal.User.pushSubscription;
      final deviceId = deviceState.id;
      
      console.log('🔔 [NotificationService] Device ID forçado: $deviceId', name: 'NotificationService');
      
      if (deviceId != null && deviceId.isNotEmpty) {
        await _registerDevice(deviceId);
      } else {
        console.log('🔔 [NotificationService] Device ID não disponível para registro forçado', name: 'NotificationService');
      }
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro no registro forçado: $e', name: 'NotificationService');
    }
  }

  /// Registra o dispositivo na API
  Future<void> _registerDevice(String deviceId) async {
    try {
      console.log('🔔 [NotificationService] Registrando dispositivo na API: $deviceId', name: 'NotificationService');
      
      final userProfileProvider = Get.find<UserProfileProvider>();
      
      await userProfileProvider.onRegisterUnregister(
        deviceId: deviceId,
        isRegister: true,
      );
      
      console.log('🔔 [NotificationService] Dispositivo registrado com sucesso na API', name: 'NotificationService');
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro ao registrar dispositivo na API: $e', name: 'NotificationService');
    }
  }

  /// Remove o registro do dispositivo
  Future<void> unregisterDevice() async {
    try {
      console.log('🔔 [NotificationService] Removendo registro do dispositivo...', name: 'NotificationService');
      
      final deviceState = OneSignal.User.pushSubscription;
      final deviceId = deviceState.id;
      
      if (deviceId != null && deviceId.isNotEmpty) {
        final userProfileProvider = Get.find<UserProfileProvider>();
        
        await userProfileProvider.onRegisterUnregister(
          deviceId: deviceId,
          isRegister: false,
        );
        
        console.log('🔔 [NotificationService] Dispositivo removido com sucesso', name: 'NotificationService');
      }
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro ao remover dispositivo: $e', name: 'NotificationService');
    }
  }

  /// Navega para a tela apropriada baseada na notificação
  void _handleNotificationNavigation(OSNotification notification) {
    try {
      final additionalData = notification.additionalData;
      
      if (additionalData != null) {
        // Verificar se é uma notificação de agendamento
        if (additionalData['type'] == 'scheduling' || 
            additionalData['schedulingId'] != null) {
          final schedulingId = additionalData['schedulingId']?.toString();
          if (schedulingId != null && schedulingId.isNotEmpty) {
            Get.toNamed(Routes.orderDetails, arguments: schedulingId);
            return;
          }
        }
        
        // Verificar se é uma notificação de workshop
        if (additionalData['type'] == 'workshop' || 
            additionalData['workshopId'] != null) {
          final workshopId = additionalData['workshopId']?.toString();
          if (workshopId != null && workshopId.isNotEmpty) {
            Get.toNamed(Routes.mechanicWorkshopDetails, arguments: WorkshopArgs(workshopId));
            return;
          }
        }
      }
      
      // Se não há dados específicos, ir para a tela de notificações
      Get.toNamed(Routes.notifications);
      
    } catch (e) {
      console.log('🔔 [NotificationService] Erro ao navegar: $e', name: 'NotificationService');
      // Fallback para a tela de notificações
      Get.toNamed(Routes.notifications);
    }
  }
}
