import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/core.dart';
import '../../../../core/widgets/app_checkbox.dart';
import '../../../../data/models/budget_service_model.dart';
import '../../controllers/order_details_controller.dart';

enum TableStyle { icon, checkBox }

class TablePrice extends GetView<OrderDetailsController> {
  const TablePrice({
    super.key,
    required this.services,
    required this.onServiceSelected,
  });

  final List<BudgetServiceModel> services;
  final VoidCallback onServiceSelected;

  String _getIcon(bool isApproved) {
    if (isApproved) {
      return AppImages.icCheck;
    }
    return AppImages.icClosed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: AppColors.grayLineColor),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 1,
                  color: AppColors.grayLineColor,
                ),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'Serviço',
                  style: TextStyle(
                    color: AppColors.fontBoldBlackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Text(
                  'Preço',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.fontBoldBlackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            itemCount: services.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final service = services[index];
              final isLast = index == services.length - 1;
              return Obx(
                () => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: !isLast
                        ? const Border(
                            bottom: BorderSide(
                              width: 1,
                              color: AppColors.grayLineColor,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(
                        service.title ?? '',
                        style: const TextStyle(
                          color: AppColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        service.value?.moneyFormat() ?? '',
                        style: const TextStyle(
                          color: AppColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Visibility(
                        visible: controller.orderDetails?.status == 8,
                        replacement:
                            SvgPicture.asset(_getIcon(service.isApproved)),
                        child: AppCheckBox(
                          isSelected:
                              controller.selectedServices.contains(service),
                          onChanged: (value) {
                            controller.toggleServiceSelection(service);
                            onServiceSelected();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
