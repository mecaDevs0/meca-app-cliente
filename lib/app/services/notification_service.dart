import 'dart:developer' as console;

import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

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

      // Como temos problemas com a API do OneSignal, vamos apenas registrar que o serviço foi inicializado
      // e deixar a configuração real do OneSignal para o MegaOneSignalConfig que já está funcionando

      console.log('Serviço de notificações inicializado com sucesso. Os handlers serão configurados através do MegaOneSignalConfig.',
          name: 'NotificationService');

      // Nota: A configuração das notificações está sendo feita no main.dart através do MegaOneSignalConfig.configure()
      // Não precisamos duplicar essa configuração aqui, pois já está funcionando no nível da aplicação.

    } catch (e) {
      console.log('Erro ao inicializar o serviço de notificações: $e',
          name: 'NotificationService');
    }
  }

  /// Processa uma notificação recebida com o app em primeiro plano
  void processReceivedNotification(Map<String, dynamic> data) {
    try {
      final title = data['title'] as String?;

      console.log(
          'Notificação recebida em primeiro plano: $title',
          name: 'NotificationService');
      console.log('Dados da notificação: $data', name: 'NotificationService');

      // LOG DETALHADO DO PAYLOAD RAW
      if (data.containsKey('rawPayload')) {
        console.log('RAW PAYLOAD da notificação: \\n${data['rawPayload']}', name: 'NotificationService');
      } else {
        console.log('RAW PAYLOAD não encontrado no data. Data completo: $data', name: 'NotificationService');
      }

      // Aqui poderíamos executar alguma ação específica quando a notificação chega
    } catch (e) {
      console.log('Erro no processamento da notificação recebida: $e',
          name: 'NotificationService');
    }
  }

  /// Processa uma notificação quando aberta pelo usuário
  void processOpenedNotification(Map<String, dynamic> data) {
    try {
      final title = data['title'] as String?;

      console.log('Notificação aberta: $title',
          name: 'NotificationService');
      console.log('Dados da notificação aberta: $data',
          name: 'NotificationService');

      // LOG DETALHADO DO PAYLOAD RAW
      if (data.containsKey('rawPayload')) {
        console.log('RAW PAYLOAD da notificação aberta: \\n${data['rawPayload']}', name: 'NotificationService');
      } else {
        console.log('RAW PAYLOAD não encontrado no data da notificação aberta. Data completo: $data', name: 'NotificationService');
      }

      _handleNotificationNavigation(data);
    } catch (e) {
      console.log('Erro no processamento da notificação aberta: $e',
          name: 'NotificationService');
    }
  }

  /// Trata a navegação com base nos dados da notificação.
  ///
  /// @param data Os dados adicionais da notificação.
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      // Extrair informações do payload
      final String? screen = data['screen_route'] as String?;
      final String? appointmentId = data['appointment_id'] as String?;
      final String? notificationType = data['notification_type'] as String?;

      console.log('Tipo de notificação: $notificationType', name: 'NotificationService');

      // Navegar com base no tipo de notificação ou rota especificada
      if (screen != null && screen.isNotEmpty) {
        // Se tiver uma rota específica definida no payload
        console.log('Navegando para a rota: $screen', name: 'NotificationService');
        Get.toNamed(screen);
      } else if (appointmentId != null && appointmentId.isNotEmpty) {
        // Se tiver um ID de agendamento, navegar para a tela de detalhes do agendamento
        console.log('Navegando para detalhes do agendamento: $appointmentId', name: 'NotificationService');
        Get.toNamed('${Routes.orderDetails}/$appointmentId');
      } else if (notificationType != null) {
        // Casos específicos por tipo de notificação
        switch (notificationType) {
          case 'new_appointment':
            console.log('Navegando para a lista de agendamentos', name: 'NotificationService');
            Get.toNamed(Routes.ordersPlaced);
            break;
          case 'appointment_status_changed':
            console.log('Navegando para a lista de agendamentos', name: 'NotificationService');
            Get.toNamed(Routes.ordersPlaced);
            break;
          case 'message':
            console.log('Navegando para a lista de notificações', name: 'NotificationService');
            Get.toNamed(Routes.notifications);
            break;
          default:
            console.log('Tipo de notificação desconhecido, redirecionando para home', name: 'NotificationService');
            Get.toNamed(Routes.home);
            break;
        }
      } else {
        // Fallback para a home se não houver informações de navegação
        console.log('Sem dados de navegação na notificação, indo para a home', name: 'NotificationService');
        Get.toNamed(Routes.home);
      }
    } catch (e) {
      console.log('Erro ao processar a navegação da notificação: $e', name: 'NotificationService');
      // Em caso de erro, vá para a home
      Get.toNamed(Routes.home);
    }
  }
}
