import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

class DescriptionTile extends StatelessWidget {
  const DescriptionTile({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.softBlackColor,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.softBlackColor,
            ),
          ),
        ],
      ),
    );
  }
}
