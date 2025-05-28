import 'package:flutter/material.dart';

import '../../../../../../core/app_colors.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopLocationRow extends StatelessWidget {
  const MechanicWorkshopLocationRow({
    super.key,
    required this.mechanicWorkshop,
  });

  final MechanicWorkshop mechanicWorkshop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          mechanicWorkshop.streetAddress ?? '',
          style: const TextStyle(
            color: AppColors.neutralGrayColor,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.pointGrayColor,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Text(
          '${mechanicWorkshop.distance ?? 0} km',
          style: const TextStyle(
            color: AppColors.neutralGrayColor,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
