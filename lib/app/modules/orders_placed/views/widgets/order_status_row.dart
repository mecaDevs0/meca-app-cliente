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
          child: Text(
            'Pedido \n#$id',
            style: const TextStyle(
              color: AppColors.neutralGrayColor,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 4,
          ),
        ),
        Flexible(child: AppStatusChip(status: status)),
      ],
    );
  }
}
