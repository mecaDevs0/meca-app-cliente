import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/notification_model.dart';

class NotificationsProvider {
  NotificationsProvider({
    required RestClientDio restClientDio,
  }) : _restClientDio = restClientDio;
  final RestClientDio _restClientDio;

  Future<List<NotificationModel>> listNotification({
    required int page,
    required int limit,
    required String userId,
  }) async {
    final response = await _restClientDio.get(
      BaseUrls.notification,
      queryParameters: {
        'page': page,
        'limit': limit,
        'userId': userId,
      },
    );
    final notifications = (response.data as List)
        .map((e) => NotificationModel.fromJson(e))
        .toList();
    return notifications;
  }

  Future<NotificationModel> getNotificationDetail({
    required String notificationId,
  }) async {
    final response = await _restClientDio.get(
      '${BaseUrls.notification}/$notificationId',
    );

    return NotificationModel.fromJson(response.data);
  }

  Future<void> removeNotification({required String notificationId}) async {
    await _restClientDio.delete(
      '${BaseUrls.notification}/$notificationId',
    );
  }
}
