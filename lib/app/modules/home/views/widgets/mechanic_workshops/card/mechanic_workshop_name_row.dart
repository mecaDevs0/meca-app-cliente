import 'package:flutter/material.dart';

import '../../../../../../core/app_colors.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopNameRow extends StatelessWidget {
  const MechanicWorkshopNameRow({
    super.key,
    required this.mechanicWorkshop,
  });

  final MechanicWorkshop mechanicWorkshop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          mechanicWorkshop.companyName ?? '',
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
