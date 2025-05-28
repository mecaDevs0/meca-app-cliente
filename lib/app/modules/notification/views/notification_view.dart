import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/notification_model.dart';
import '../../../routes/app_pages.dart';
import '../controllers/notification_controller.dart';
import 'widgets/item_notification.dart';

class NotificationView extends GetView<NotificationsController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Notificações',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
        iconColor: AppColors.whiteColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RefreshIndicator(
                  onRefresh: () => Future.sync(
                    () => controller.pagingController.refresh(),
                  ),
                  child: PagedListView<int, NotificationModel>(
                    pagingController: controller.pagingController,
                    builderDelegate:
                        PagedChildBuilderDelegate<NotificationModel>(
                      animateTransitions: true,
                      transitionDuration: const Duration(milliseconds: 500),
                      itemBuilder: (context, notification, index) {
                        final now = DateTime.now();
                        final createdDate = notification.created!.toDateTime();
                        final isToday = createdDate
                            .isAfter(DateTime(now.year, now.month, now.day));
                        final isFirstOfToday = _isFirstOfSection(
                          controller.pagingController.itemList!,
                          index,
                          isToday,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isFirstOfToday) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 16, bottom: 16),
                                child: Text(
                                  isToday ? 'Hoje' : 'Notificações Passadas',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.fontBoldBlackColor,
                                  ),
                                ),
                              ),
                            ],
                            GestureDetector(
                              onTap: () {
                                controller
                                    .getNotificationDetails(notification.id!);
                                Get.toNamed(Routes.notificationDetails);
                              },
                              child: ItemNotification(
                                notification: notification,
                              ),
                            ),
                          ],
                        );
                      },
                      firstPageErrorIndicatorBuilder: (context) =>
                          ErrorIndicator(
                        error: controller.pagingController.error,
                        onTryAgain: () => controller.pagingController.refresh(),
                      ),
                      noItemsFoundIndicatorBuilder: (context) =>
                          const EmptyListIndicator(
                        message: 'Sem notificações para exibir',
                      ),
                      firstPageProgressIndicatorBuilder: (context) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitWave(
                            itemCount: 4,
                            itemBuilder: (_, int index) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Get.theme.primaryColor,
                                ),
                              );
                            },
                            size: 20,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Carregando Notificações...',
                            style: context.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isFirstOfSection(
    List<NotificationModel> notifications,
    int index,
    bool isToday,
  ) {
    if (index == 0) {
      return true;
    }
    final previousDate = notifications[index - 1].created!.toDateTime();
    final isPreviousToday = previousDate.isAfter(
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
    return isToday != isPreviousToday;
  }
}
