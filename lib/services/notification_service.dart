import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  // Handler para navegação quando notificação é clicada
  static void Function(String? payload)? onNotificationClick;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar timezone database antes de usar
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (e) {
        // Se já estiver inicializado, ignorar erro
        print('Timezone já inicializado ou erro ao inicializar: $e');
      }

      // Configurar notificações locais
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && onNotificationClick != null) {
            onNotificationClick!(response.payload);
          }
        },
      );

      // Configurar Firebase Messaging (temporariamente desabilitado)
      // await _firebaseMessaging.requestPermission(
      //   alert: true,
      //   badge: true,
      //   sound: true,
      // );

      // Obter token FCM (temporariamente desabilitado)
      // final token = await _firebaseMessaging.getToken();
      // print('FCM Token: $token');

      _isInitialized = true;
    } catch (e, stackTrace) {
      print('Erro ao inicializar NotificationService: $e');
      print('Stack trace: $stackTrace');
      // Não marcar como inicializado se houver erro
      // Mas não lançar exceção para não quebrar o app
    }
  }

  Future<void> requestPermissions() async {
    try {
      await Permission.notification.request();
    } catch (e) {
      print('Erro ao solicitar permissões de notificação: $e');
      // Não lançar exceção, apenas logar o erro
    }
  }

  Future<String?> getFCMToken() async {
    try {
      // Firebase Messaging - busca token REAL do Firebase
      // TODO: Descomentar quando Firebase estiver configurado
      // final firebaseMessaging = FirebaseMessaging.instance;
      // final token = await firebaseMessaging.getToken();
      // return token;
      
      // Por enquanto, retornar null (não usar mock)
      return null;
    } catch (e) {
      print('Erro ao obter FCM token: $e');
      return null;
    }
  }

  // Método para criar payload de navegação
  static String createNavigationPayload(String type, String id, {Map<String, dynamic>? extra}) {
    final parts = [type, id];
    if (extra != null) {
      parts.add(extra.entries.map((e) => '${e.key}=${e.value}').join(','));
    }
    return parts.join('|');
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'meca_channel',
      'MECA Notifications',
      channelDescription: 'Notificações do app MECA',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Garantir que timezone está inicializado
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      // Se já estiver inicializado, ignorar erro
    }

    const androidDetails = AndroidNotificationDetails(
      'meca_scheduled_channel',
      'MECA Scheduled Notifications',
      channelDescription: 'Notificações agendadas do MECA',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final location = tz.getLocation('America/Sao_Paulo');
      final scheduledTZ = tz.TZDateTime.from(scheduledDate, location);
      
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Erro ao agendar notificação com timezone: $e');
      // Em caso de erro com timezone, usar DateTime local diretamente
      final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        notificationDetails,
        payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Notificações específicas do MECA
  Future<void> showBookingConfirmation({
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
    String? bookingId,
  }) async {
    final payload = bookingId != null 
        ? createNavigationPayload('booking', bookingId)
        : null;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Agendamento Confirmado! 🎉',
      body: 'Seu agendamento de $serviceName na $workshopName foi confirmado para ${_formatDate(scheduledDate)}',
      payload: payload,
    );
  }

  Future<void> showBookingReminder({
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
    String? bookingId,
  }) async {
    final payload = bookingId != null 
        ? createNavigationPayload('booking', bookingId)
        : null;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Lembrete de Agendamento ⏰',
      body: 'Você tem um agendamento de $serviceName na $workshopName em 1 hora!',
      payload: payload,
    );
  }

  Future<void> showServiceStarted({
    required String workshopName,
    required String serviceName,
    String? bookingId,
  }) async {
    final payload = bookingId != null 
        ? createNavigationPayload('booking', bookingId)
        : null;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Serviço Iniciado! 🔧',
      body: 'O serviço $serviceName foi iniciado na $workshopName',
      payload: payload,
    );
  }

  Future<void> showServiceFinished({
    required String workshopName,
    required String serviceName,
    String? bookingId,
  }) async {
    final payload = bookingId != null 
        ? createNavigationPayload('booking', bookingId)
        : null;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Serviço Finalizado! ✅',
      body: 'O serviço $serviceName foi finalizado na $workshopName. Abra o app MECA para confirmar e realizar o pagamento.',
      payload: payload,
    );
  }

  Future<void> showPaymentConfirmation({
    required String workshopName,
    required String serviceName,
    required double amount,
    String? bookingId,
  }) async {
    final payload = bookingId != null 
        ? createNavigationPayload('booking', bookingId)
        : null;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Pagamento Confirmado! 💳',
      body: 'Pagamento de R\$ ${amount.toStringAsFixed(2)} confirmado para $serviceName na $workshopName',
      payload: payload,
    );
  }

  Future<void> scheduleBookingReminders({
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
  }) async {
    // Lembrete 1 dia antes
    final oneDayBefore = scheduledDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: scheduledDate.millisecondsSinceEpoch ~/ 1000 + 1,
        title: 'Lembrete de Agendamento 📅',
        body: 'Você tem um agendamento de $serviceName na $workshopName amanhã!',
        scheduledDate: oneDayBefore,
      );
    }

    // Lembrete 1 hora antes
    final oneHourBefore = scheduledDate.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: scheduledDate.millisecondsSinceEpoch ~/ 1000 + 2,
        title: 'Lembrete de Agendamento ⏰',
        body: 'Você tem um agendamento de $serviceName na $workshopName em 1 hora!',
        scheduledDate: oneHourBefore,
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} às ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}





















