import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/app_colors.dart';
import '../../../../data/enums/alert_status.dart';

class WithTimeRich extends StatelessWidget {
  const WithTimeRich({super.key, required this.status, this.date});

  final AlertStatus status;
  final int? date;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Aguardando veículo dia ',
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: date != null ? date!.toddMMyyyy() : '',
            style: const TextStyle(
              color: AppColors.abbey,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: ' às ',
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: date != null ? date!.toHHmm() : '',
            style: const TextStyle(
              color: AppColors.abbey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
