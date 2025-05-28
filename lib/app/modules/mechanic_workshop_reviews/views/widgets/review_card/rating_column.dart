import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/app_images.dart';

class RatingColumn extends StatelessWidget {
  const RatingColumn({
    super.key,
    required this.service,
    required this.rating,
  });

  final String service;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          service,
          style: const TextStyle(
            color: AppColors.neutralGrayColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        Row(
          spacing: 4,
          mainAxisAlignment: MainAxisAlignment.start,
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
