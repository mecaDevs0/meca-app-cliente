import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

class ServiceTitle extends StatelessWidget {
  const ServiceTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.abbey,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
