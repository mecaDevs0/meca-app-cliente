import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../data/enums/schedule_status.dart';

class OrderStatusRow extends StatelessWidget {
  const OrderStatusRow({
    super.key,
    required this.id,
    required this.status,
  });

  final String id;
  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pedido',
                style: TextStyle(
                  color: AppColors.neutralGrayColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '#${id.length > 8 ? '${id.substring(0, 8)}...' : id}',
                style: const TextStyle(
                  color: AppColors.fontBoldBlackColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Flexible(child: AppStatusChip(status: status)),
      ],
    );
  }
}
