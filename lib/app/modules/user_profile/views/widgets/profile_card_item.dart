import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';

class ProfileCardItem extends StatelessWidget {
  const ProfileCardItem({
    super.key,
    required this.iconPath,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: AppColors.whiteColor,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: AppColors.grayBorderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 1,
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SvgPicture.asset(
                iconPath,
                height: 24,
                width: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.softBlackColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.neutralGrayColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                AppImages.icArrowUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
