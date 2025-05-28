import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../controllers/notification_controller.dart';

class NotificationDetailsView extends GetView<NotificationsController> {
  const NotificationDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Detalhes da notificação',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
        iconColor: AppColors.whiteColor,
      ),
      body: Obx(
        () {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MegaCachedNetworkImage(
                  imageUrl: controller.notificationDetail?.workshop?.photo,
                  width: 59,
                  height: 60,
                  radius: 100,
                ),
                const SizedBox(
                  height: 20,
                ),
                Text(
                  controller.notificationDetail?.title ?? '',
                  style: const TextStyle(
                    color: AppColors.fontBoldBlackColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  '${controller.notificationDetail?.created!.toddMMyyyy()} às ${controller.notificationDetail?.created!.toHHmm()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.fontBoldBlackColor,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Text(
                  controller.notificationDetail?.content ?? '',
                  style: const TextStyle(
                    color: AppColors.fontRegularBlackColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
