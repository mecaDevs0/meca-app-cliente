import 'dart:developer';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../data/models/profile.dart';
import '../../data/providers/notification_provider.dart';
import '../../routes/app_pages.dart';

/// Serviço para gerenciar notificações push e interação do usuário com elas
class NotificationService {
  static NotificationService? _instance;

  final NotificationsProvider _notificationsProvider;

  NotificationService._({
    required NotificationsProvider notificationsProvider,
  }) : _notificationsProvider = notificationsProvider;

  static NotificationService get instance {
    if (_instance == null) {
      final restClient = Get.find<RestClientDio>();
      _instance = NotificationService._(
        notificationsProvider: NotificationsProvider(restClientDio: restClient),
      );
    }
    return _instance!;
  }

  /// Inicializa o serviço de notificações de forma não-bloqueante
  void initialize() {
    // Não usamos mais await aqui, permitindo que a inicialização do app continue
    _initializeAsync();
  }

  /// Inicialização assíncrona real do serviço de notificações
  Future<void> _initializeAsync() async {
    try {
      // A configuração do OneSignal já foi feita no main.dart
      // Aqui realizamos apenas operações adicionais de forma assíncrona

      log('NotificationService: Serviço inicializado com sucesso',
          name: 'NotificationService');

      // Log do usuário atual para debug
      _logCurrentUser();
    } catch (e) {
      log('NotificationService: Erro durante a inicialização do serviço: $e',
          name: 'NotificationService');
      // Não propagamos a exceção para evitar travamento do app
    }
  }

  /// Registra informações do usuário atual no log para debug
  void _logCurrentUser() {
    try {
      final profile = Profile.fromCache();

      if (profile != null && profile.id != null) {
        log('NotificationService: Usuário atual: ${profile.fullName} (${profile.id})',
            name: 'NotificationService');
      } else {
        log('NotificationService: Usuário não está logado',
            name: 'NotificationService');
      }
    } catch (e) {
      log('NotificationService: Erro ao verificar usuário: $e',
          name: 'NotificationService');
    }
  }
}
