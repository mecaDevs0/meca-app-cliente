import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../core/app_colors.dart';

class ReviewNameRow extends StatelessWidget {
  const ReviewNameRow({
    super.key,
    required this.name,
    required this.date,
  });

  final String name;
  final int date;

  String formatDate() {
    return date.toddMMyyyy();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        Text(
          formatDate(),
          style: const TextStyle(
            color: AppColors.neutralGrayColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
