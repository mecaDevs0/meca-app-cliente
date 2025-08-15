import 'dart:developer' as console;

import 'package:meca_cliente/app/data/providers/user_profile_provider.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../core/app_urls.dart';
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

  /// Inicializa o serviço de notificações.
  /// Este método deve ser chamado no início da aplicação.
  void initialize() {
    try {
      // Registra o serviço de notificações no Get para que possa ser acessado globalmente
      Get.put(this, permanent: true);

      console.log('Serviço de notificações inicializado com sucesso.',
          name: 'NotificationService');

      // Configurar handlers específicos para o app
      _setupNotificationHandlers();

    } catch (e) {
      console.log('Erro ao inicializar o serviço de notificações: $e',
          name: 'NotificationService');
    }
  }

  /// Configura os handlers específicos de notificação
  void _setupNotificationHandlers() {
    // Handler para quando o app recebe uma notificação em primeiro plano
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final payload = event.notification.rawPayload ?? <String, dynamic>{};
      processReceivedNotification(payload);
    });

    // Handler para quando o usuário clica em uma notificação
    OneSignal.Notifications.addClickListener((event) {
      final payload = event.notification.rawPayload ?? <String, dynamic>{};
      processOpenedNotification(payload);
    });

    console.log('Handlers de notificação configurados', name: 'NotificationService');
  }

  /// Registra o dispositivo no backend quando o usuário faz login
  Future<void> registerDeviceOnLogin() async {
    try {
      final profile = Profile.fromCache();
      final playerId = MegaOneSignalConfig.fromCache();

      console.log('=== REGISTRO DE DISPOSITIVO ===', name: 'NotificationService');
      console.log('Profile: ${profile?.id}', name: 'NotificationService');
      console.log('Player ID: $playerId', name: 'NotificationService');

      if (profile != null && profile.id != null && playerId != null) {
        console.log('Registrando dispositivo OneSignal para usuário: ${profile.id}', 
            name: 'NotificationService');

        final restClient = Get.find<RestClientDio>();
        final userProfileProvider = UserProfileProvider(restClientDio: restClient);

        console.log('Enviando requisição para: ${BaseUrls.registerDevice}', name: 'NotificationService');
        console.log('Dados: deviceId=$playerId, isRegister=true', name: 'NotificationService');

        await userProfileProvider.onRegisterUnregister(
          deviceId: playerId,
          isRegister: true,
        );
        
        console.log('✅ Dispositivo registrado com sucesso: $playerId', 
            name: 'NotificationService');
      } else {
        console.log('❌ Dados insuficientes para registro:', name: 'NotificationService');
        console.log('- Profile válido: ${profile != null}', name: 'NotificationService');
        console.log('- Profile ID: ${profile?.id}', name: 'NotificationService');
        console.log('- Player ID válido: ${playerId != null}', name: 'NotificationService');
      }
    } catch (e) {
      console.log('❌ Erro ao registrar dispositivo: $e', name: 'NotificationService');
      console.log('Stack trace: ${StackTrace.current}', name: 'NotificationService');
    }
  }

  /// Processa uma notificação recebida com o app em primeiro plano
  void processReceivedNotification(Map<String, dynamic> data) {
    try {
      console.log('=== NOTIFICAÇÃO RECEBIDA EM PRIMEIRO PLANO ===', name: 'NotificationService');
      console.log('Dados completos: $data', name: 'NotificationService');

      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final additionalData = data['additionalData'] as Map<String, dynamic>?;

      console.log('Título: $title', name: 'NotificationService');
      console.log('Corpo: $body', name: 'NotificationService');
      console.log('Dados adicionais: $additionalData', name: 'NotificationService');

      // LOG DETALHADO DO PAYLOAD RAW
      if (data.containsKey('rawPayload')) {
        console.log('RAW PAYLOAD da notificação: ${data['rawPayload']}', name: 'NotificationService');
      } else {
        console.log('RAW PAYLOAD não encontrado no data', name: 'NotificationService');
      }

      // Mostrar notificação local se necessário
      _showLocalNotification(title ?? 'Nova notificação', body ?? '');

    } catch (e) {
      console.log('❌ Erro no processamento da notificação recebida: $e',
          name: 'NotificationService');
      console.log('Stack trace: ${StackTrace.current}', name: 'NotificationService');
    }
  }

  /// Processa uma notificação quando aberta pelo usuário
  void processOpenedNotification(Map<String, dynamic> data) {
    try {
      console.log('=== NOTIFICAÇÃO ABERTA PELO USUÁRIO ===', name: 'NotificationService');
      console.log('Dados completos: $data', name: 'NotificationService');

      final title = data['title'] as String?;
      final body = data['body'] as String?;
      final additionalData = data['additionalData'] as Map<String, dynamic>?;

      console.log('Título: $title', name: 'NotificationService');
      console.log('Corpo: $body', name: 'NotificationService');
      console.log('Dados adicionais: $additionalData', name: 'NotificationService');

      // LOG DETALHADO DO PAYLOAD RAW
      if (data.containsKey('rawPayload')) {
        console.log('RAW PAYLOAD da notificação aberta: ${data['rawPayload']}', name: 'NotificationService');
      } else {
        console.log('RAW PAYLOAD não encontrado no data da notificação aberta', name: 'NotificationService');
      }

      _handleNotificationNavigation(data);
    } catch (e) {
      console.log('❌ Erro no processamento da notificação aberta: $e',
          name: 'NotificationService');
      console.log('Stack trace: ${StackTrace.current}', name: 'NotificationService');
    }
  }

  /// Mostra uma notificação local quando o app está em primeiro plano
  void _showLocalNotification(String title, String body) {
    try {
      // Implementar notificação local usando flutter_local_notifications
      // ou outro método preferido para mostrar notificações
      console.log('Exibindo notificação local: $title - $body', 
          name: 'NotificationService');
      
      // Por enquanto, mostrar um snackbar
      if (Get.context != null) {
        MegaSnackbar.showToast('$title: $body');
      }
    } catch (e) {
      console.log('Erro ao mostrar notificação local: $e', name: 'NotificationService');
    }
  }

  /// Trata a navegação com base nos dados da notificação.
  ///
  /// @param data Os dados adicionais da notificação.
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      console.log('=== PROCESSANDO NAVEGAÇÃO DA NOTIFICAÇÃO ===', name: 'NotificationService');
      console.log('Dados para navegação: $data', name: 'NotificationService');

      // Extrair informações do payload
      final String? screen = data['screen_route'] as String?;
      final String? appointmentId = data['appointment_id'] as String?;
      final String? notificationType = data['notification_type'] as String?;
      final String? additionalData = data['additionalData'] as String?;

      console.log('Screen route: $screen', name: 'NotificationService');
      console.log('Appointment ID: $appointmentId', name: 'NotificationService');
      console.log('Notification type: $notificationType', name: 'NotificationService');
      console.log('Additional data: $additionalData', name: 'NotificationService');

      // Aguardar um pouco para garantir que o app está pronto para navegar
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateBasedOnNotification(screen, appointmentId, notificationType);
      });

    } catch (e) {
      console.log('❌ Erro ao processar a navegação da notificação: $e', name: 'NotificationService');
      console.log('Stack trace: ${StackTrace.current}', name: 'NotificationService');
      // Em caso de erro, vá para a home
      Get.toNamed(Routes.home);
    }
  }

  /// Executa a navegação baseada nos dados da notificação
  void _navigateBasedOnNotification(String? screen, String? appointmentId, String? notificationType) {
    try {
      console.log('=== EXECUTANDO NAVEGAÇÃO ===', name: 'NotificationService');
      console.log('Screen: $screen', name: 'NotificationService');
      console.log('Appointment ID: $appointmentId', name: 'NotificationService');
      console.log('Notification type: $notificationType', name: 'NotificationService');

      // Navegar com base no tipo de notificação ou rota especificada
      if (screen != null && screen.isNotEmpty) {
        // Se tiver uma rota específica definida no payload
        console.log('✅ Navegando para a rota: $screen', name: 'NotificationService');
        Get.toNamed(screen);
      } else if (appointmentId != null && appointmentId.isNotEmpty) {
        // Se tiver um ID de agendamento, navegar para a tela de detalhes do agendamento
        console.log('✅ Navegando para detalhes do agendamento: $appointmentId', name: 'NotificationService');
        Get.toNamed('${Routes.orderDetails}/$appointmentId');
      } else if (notificationType != null) {
        // Casos específicos por tipo de notificação
        switch (notificationType) {
          case 'new_appointment':
            console.log('✅ Navegando para a lista de agendamentos', name: 'NotificationService');
            Get.toNamed(Routes.ordersPlaced);
            break;
          case 'appointment_status_changed':
            console.log('✅ Navegando para a lista de agendamentos', name: 'NotificationService');
            Get.toNamed(Routes.ordersPlaced);
            break;
          case 'message':
            console.log('✅ Navegando para a lista de notificações', name: 'NotificationService');
            Get.toNamed(Routes.notifications);
            break;
          case 'promotion':
            console.log('✅ Navegando para promoções', name: 'NotificationService');
            Get.toNamed(Routes.home);
            break;
          default:
            console.log('⚠️ Tipo de notificação desconhecido: $notificationType, redirecionando para home', name: 'NotificationService');
            Get.toNamed(Routes.home);
            break;
        }
      } else {
        // Fallback para a lista de notificações
        console.log('⚠️ Sem dados específicos de navegação, indo para notificações', name: 'NotificationService');
        Get.toNamed(Routes.notifications);
      }
    } catch (e) {
      console.log('❌ Erro na navegação da notificação: $e', name: 'NotificationService');
      console.log('Stack trace: ${StackTrace.current}', name: 'NotificationService');
      Get.toNamed(Routes.home);
    }
  }

  /// Limpa todas as notificações
  void clearAllNotifications() {
    try {
      OneSignal.Notifications.clearAll();
      console.log('Todas as notificações foram limpas', name: 'NotificationService');
    } catch (e) {
      console.log('Erro ao limpar notificações: $e', name: 'NotificationService');
    }
  }
}
