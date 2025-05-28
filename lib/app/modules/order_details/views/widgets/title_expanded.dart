import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../core/widgets/app_dashed_line_painter.dart';
import '../../../../data/enums/service_history_type.dart';
import '../../controllers/order_details_controller.dart';

class TitleExpanded extends GetView<OrderDetailsController> {
  const TitleExpanded({
    super.key,
    required this.serviceType,
    required this.onTap,
    this.quantity = 1,
  });

  final ServiceHistoryType serviceType;
  final void Function() onTap;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            serviceType.description,
            style: const TextStyle(
              color: AppColors.hintTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            ' ($quantity)',
            style: const TextStyle(
              color: AppColors.hintTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: CustomPaint(
                painter: AppDashedLinePainter(
                  color: AppColors.hintTextColor,
                  thickness: 1,
                ),
                child: const SizedBox(
                  height: 1,
                ),
              ),
            ),
          ),
          Obx(
            () => AnimatedRotation(
              turns: controller.isExpanded(serviceType) ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 20,
                height: 20,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(
                      width: 1,
                      color: AppColors.hintTextColor,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: SvgPicture.asset(
                  AppImages.icChevronUp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
