import 'package:flutter/material.dart';

import '../../data/enums/schedule_status.dart';
import '../core.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, this.status, this.label})
      : assert(
          status != null || label != null,
          'Status ou label devem ser fornecidos',
        );

  final ScheduleStatus? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final displayText = label ?? status?.name ?? '';
    final displayColor = label != null ? AppColors.primaryColor : status!.color;
    final borderColor = label != null ? AppColors.grayLineColor : status!.color;

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: ShapeDecoration(
        color: label != null ? Colors.white : displayColor.withAlpha(36),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: displayColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 3,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
