import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';

class VehicleColorColumn extends StatelessWidget {
  const VehicleColorColumn({super.key, required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cor',
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
          color,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
