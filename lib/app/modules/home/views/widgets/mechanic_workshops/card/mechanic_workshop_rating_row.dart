import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../../core/core.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopRatingRow extends StatelessWidget {
  const MechanicWorkshopRatingRow({
    super.key,
    required this.mechanicWorkshop,
    this.isTablet = false, // Novo parâmetro para modo tablet
  });

  final MechanicWorkshop mechanicWorkshop;
  final bool isTablet; // Controla o tamanho dos elementos em tablets

  @override
  Widget build(BuildContext context) {
    // Ajuste de tamanho baseado no modo de visualização
    final double starSize = isTablet ? 18.0 : 12.0;
    final double arrowSize = isTablet ? 24.0 : 16.0;
    final double starSpacing = isTablet ? 6.0 : 3.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            Color starColor;
            if (mechanicWorkshop.rating != null) {
              starColor = index < mechanicWorkshop.rating!
                  ? AppColors.favoritesYellowColor
                  : AppColors.favoritesGrayColor;
            } else {
              starColor = AppColors.favoritesGrayColor;
            }

            return Padding(
              padding: EdgeInsets.only(right: starSpacing),
              child: SvgPicture.asset(
                AppImages.icFavorites,
                height: starSize,
                width: starSize,
                colorFilter: ColorFilter.mode(starColor, BlendMode.srcIn),
              ),
            );
          }),
        ).shade,
        SvgPicture.asset(
          AppImages.icArrowUp,
          height: arrowSize,
          width: arrowSize,
        ).shade,
      ],
    );
  }
}
