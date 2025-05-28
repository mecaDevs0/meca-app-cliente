import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';

class VehicleYearColumn extends StatelessWidget {
  const VehicleYearColumn({
    super.key,
    required this.year,
  });

  final String year;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ano',
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
          year,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
