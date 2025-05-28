import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../data/models/notification_model.dart';
import '../../controllers/notification_controller.dart';

class ItemNotification extends GetView<NotificationsController> {
  const ItemNotification({
    super.key,
    required this.notification,
  });

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1.0,
            color: AppColors.grayLineColor,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MegaCachedNetworkImage(
                imageUrl: notification.workshop?.photo,
                width: 59,
                height: 60,
                radius: 100,
              ),
              const SizedBox(
                width: 15,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.fontRegularBlackColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.content ?? '',
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.fontRegularBlackColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (notification.workshop?.fullName != null) ...[
                          Text(
                            notification.workshop?.fullName ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.fontRegularBlackColor,
                            ),
                          ),
                          const SizedBox(
                            width: 5.0,
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.pointDividerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                            width: 5.0,
                          ),
                        ],
                        Text(
                          notification.created?.getTimeAgo() ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.fontRegularBlackColor,
                          ),
                        ),
                        const SizedBox(
                          width: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (notification.id == null) {
                    MegaSnackbar.showErroSnackBar(
                      'Id da notificação invalido',
                    );
                    return;
                  }

                  MegaModal.showConfirmCancel(
                    context,
                    title: 'Excluir notificação',
                    message: 'Deseja excluir esta notificação?',
                    onSuccess: () {
                      controller.removeNotification(notification.id);
                    },
                  );
                },
                child: const Icon(
                  Icons.close,
                  color: Color(0x66000000),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
