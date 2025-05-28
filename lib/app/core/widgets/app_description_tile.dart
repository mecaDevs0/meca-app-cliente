import 'package:flutter/material.dart';

import '../app_colors.dart';

class AppDescriptionTile extends StatelessWidget {
  const AppDescriptionTile({
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
              color: AppColors.abbey,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.abbey,
            ),
          ),
        ],
      ),
    );
  }
}
