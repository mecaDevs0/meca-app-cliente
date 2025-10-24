import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

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

    await _localNotifications.initialize(initSettings);

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
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
  }

  Future<String?> getFCMToken() async {
    try {
      // TODO: Implementar Firebase Messaging quando necessário
      return 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Erro ao obter FCM token: $e');
      return null;
    }
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

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.getLocation('America/Sao_Paulo')),
      notificationDetails,
      payload: payload,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
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
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Agendamento Confirmado! 🎉',
      body: 'Seu agendamento de $serviceName na $workshopName foi confirmado para ${_formatDate(scheduledDate)}',
    );
  }

  Future<void> showBookingReminder({
    required String workshopName,
    required String serviceName,
    required DateTime scheduledDate,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Lembrete de Agendamento ⏰',
      body: 'Você tem um agendamento de $serviceName na $workshopName em 1 hora!',
    );
  }

  Future<void> showServiceStarted({
    required String workshopName,
    required String serviceName,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Serviço Iniciado! 🔧',
      body: 'O serviço $serviceName foi iniciado na $workshopName',
    );
  }

  Future<void> showServiceFinished({
    required String workshopName,
    required String serviceName,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Serviço Finalizado! ✅',
      body: 'O serviço $serviceName foi finalizado na $workshopName. Agora você pode avaliar!',
    );
  }

  Future<void> showPaymentConfirmation({
    required String workshopName,
    required String serviceName,
    required double amount,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Pagamento Confirmado! 💳',
      body: 'Pagamento de R\$ ${amount.toStringAsFixed(2)} confirmado para $serviceName na $workshopName',
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
