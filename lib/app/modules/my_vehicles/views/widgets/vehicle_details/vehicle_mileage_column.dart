import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';

class VehicleMileageColumn extends StatelessWidget {
  const VehicleMileageColumn({
    super.key,
    required this.mileage,
  });

  final int mileage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quilometragem',
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
          '$mileage Km',
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
