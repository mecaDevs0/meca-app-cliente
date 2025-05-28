import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../app_colors.dart';
import '../app_images.dart';

class AppRatingRow extends StatelessWidget {
  const AppRatingRow({
    super.key,
    required this.rating,
  });

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final Color starColor = index < rating
                ? AppColors.favoritesYellowColor
                : AppColors.favoritesGrayColor;

            return SvgPicture.asset(
              AppImages.icFavorites,
              height: 12,
              width: 12,
              colorFilter: ColorFilter.mode(starColor, BlendMode.srcIn),
            );
          }),
        ),
      ],
    );
  }
}
