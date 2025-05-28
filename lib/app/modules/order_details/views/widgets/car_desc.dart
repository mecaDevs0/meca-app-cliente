import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../data/models/vehicle.dart';

class CarDesc extends StatelessWidget {
  const CarDesc({super.key, this.isVisibleTitle = true, required this.vehicle});

  final bool isVisibleTitle;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVisibleTitle)
          const Text(
            'Meu veículo',
            style: TextStyle(
              color: AppColors.softBlackColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        Row(
          children: [
            Text(
              '${vehicle.manufacturer} ${vehicle.model}',
              style: const TextStyle(
                color: AppColors.softBlackColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 2,
              height: 2,
              decoration: const ShapeDecoration(
                shape: OvalBorder(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              vehicle.plate ?? '-',
              style: const TextStyle(
                color: AppColors.softBlackColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
