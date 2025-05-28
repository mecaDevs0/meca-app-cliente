import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';

class VehicleDateLastReviewColumn extends StatelessWidget {
  const VehicleDateLastReviewColumn({
    super.key,
    required this.date,
  });

  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data da última revisão',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.softBlackColor,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          date,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
