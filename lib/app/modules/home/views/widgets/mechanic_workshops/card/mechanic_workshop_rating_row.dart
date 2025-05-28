import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../../core/core.dart';
import '../../../../../../data/models/mechanic_workshop.dart';

class MechanicWorkshopRatingRow extends StatelessWidget {
  const MechanicWorkshopRatingRow({
    super.key,
    required this.mechanicWorkshop,
  });

  final MechanicWorkshop mechanicWorkshop;

  @override
  Widget build(BuildContext context) {
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

            return SvgPicture.asset(
              AppImages.icFavorites,
              height: 12,
              width: 12,
              colorFilter: ColorFilter.mode(starColor, BlendMode.srcIn),
            );
          }),
        ).shade,
        SvgPicture.asset(
          AppImages.icArrowUp,
        ).shade,
      ],
    );
  }
}
