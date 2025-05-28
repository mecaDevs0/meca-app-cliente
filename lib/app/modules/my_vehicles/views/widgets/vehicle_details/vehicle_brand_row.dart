import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';

class VehicleBrandColumn extends StatelessWidget {
  const VehicleBrandColumn({super.key, required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fabricante',
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
          brand,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
