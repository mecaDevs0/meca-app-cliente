import 'package:flutter/material.dart';

import '../../../../../../core/app_colors.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopLocationRow extends StatelessWidget {
  const MechanicWorkshopLocationRow({
    super.key,
    required this.mechanicWorkshop,
    this.isTablet = false, // Novo parâmetro para modo tablet
  });

  final MechanicWorkshop mechanicWorkshop;
  final bool isTablet; // Controla o tamanho dos elementos em tablets

  @override
  Widget build(BuildContext context) {
    // Define tamanhos baseados no modo de visualização
    final double fontSize = isTablet ? 14.0 : 12.0;
    final double dotSize = isTablet ? 6.0 : 4.0;
    final double spacing = isTablet ? 8.0 : 4.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            mechanicWorkshop.streetAddress ?? '',
            style: TextStyle(
              color: AppColors.neutralGrayColor,
              fontWeight: FontWeight.w400,
              fontSize: fontSize,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: spacing),
        Container(
          width: dotSize,
          height: dotSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.pointGrayColor,
          ),
        ),
        SizedBox(width: spacing),
        Text(
          '${mechanicWorkshop.distance ?? 0} km',
          style: TextStyle(
            color: AppColors.neutralGrayColor,
            fontWeight: FontWeight.w400,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
