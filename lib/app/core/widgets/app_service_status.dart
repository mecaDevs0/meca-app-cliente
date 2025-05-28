import 'package:flutter/material.dart';

import '../../data/enums/status_chip.dart';
import '../app_colors.dart';
import 'app_status_chip.dart';

class AppServiceStatus extends StatelessWidget {
  const AppServiceStatus({
    super.key,
    required this.status,
  });

  final StatusChip status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status do serviço',
          style: TextStyle(
            color: AppColors.abbey,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AppStatusChip(
          status: status,
        ),
      ],
    );
  }
}
