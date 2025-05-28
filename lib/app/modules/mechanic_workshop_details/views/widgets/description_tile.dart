import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

class DescriptionTile extends StatelessWidget {
  const DescriptionTile({
    super.key,
    required this.descriptionFontColor,
    required this.description,
    required this.title,
  });

  final Color descriptionFontColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          description,
          style: TextStyle(
            color: descriptionFontColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
