import 'package:flutter/material.dart';

import '../../data/models/vehicle.dart';
import '../app_colors.dart';

class AppCarDesc extends StatelessWidget {
  const AppCarDesc({
    super.key,
    this.isVisibleTitle = true,
    required this.vehicle,
  });

  final bool isVisibleTitle;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVisibleTitle)
          const Text(
            'Veículo',
            style: TextStyle(
              color: AppColors.softBlackColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        Row(
          children: [
            Text(
              vehicle.manufacturer ?? '',
              style: const TextStyle(
                color: AppColors.abbey,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 2,
              height: 2,
              decoration: const ShapeDecoration(
                color: AppColors.pointGrayColor,
                shape: OvalBorder(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              vehicle.plate ?? '',
              style: const TextStyle(
                color: AppColors.softBlackColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
