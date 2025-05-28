import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/notification_model.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/notification_provider.dart';

class NotificationsController extends GetxController {
  NotificationsController({
    required NotificationsProvider notificationsProvider,
  }) : _notificationsProvider = notificationsProvider;

  final NotificationsProvider _notificationsProvider;
  final PagingController<int, NotificationModel> pagingController =
      PagingController(firstPageKey: 1);

  final _isLoading = RxBool(false);
  final _notificationDetail = Rx<NotificationModel?>(null);
  final _limit = 30;

  bool get isLoading => _isLoading.value;
  NotificationModel? get notificationDetail => _notificationDetail.value;

  @override
  void onInit() {
    pagingController.addPageRequestListener((pageKey) {
      _requestNotifications(pageKey);
    });
    super.onInit();
  }

  Future<void> _requestNotifications(int pageKey) async {
    await MegaRequestUtils.load(
      action: () async {
        final profile = Profile.fromCache();
        final response = await _notificationsProvider.listNotification(
          page: pageKey,
          limit: _limit,
          userId: profile.id!,
        );
        final isLastPage = response.length < _limit;
        if (isLastPage) {
          pagingController.appendLastPage(response);
        } else {
          final nextPageKey = pageKey + 1;
          pagingController.appendPage(response, nextPageKey);
        }
      },
      onError: (megaResponse) => pagingController.error = megaResponse.errors,
    );
  }

  Future<void> removeNotification(String? id) async {
    await MegaRequestUtils.load(
      action: () async {
        await _notificationsProvider.removeNotification(
          notificationId: id!,
        );
        pagingController.refresh();
      },
    );
  }

  Future<void> getNotificationDetails(String notificationId) async {
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final response = await _notificationsProvider.getNotificationDetail(
          notificationId: notificationId,
        );
        _notificationDetail.value = response;
      },
      onFinally: () => _isLoading.value = false,
    );
  }
}
