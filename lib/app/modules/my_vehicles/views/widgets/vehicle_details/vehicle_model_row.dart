import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../../core/app_colors.dart';

class VehicleModelRow extends StatelessWidget {
  const VehicleModelRow({
    super.key,
    required this.model,
    required this.icon,
  });

  final String model;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SvgPicture.asset(icon, width: 32),
        const SizedBox(
          width: 10,
        ),
        Text(
          model,
          style: const TextStyle(
            color: AppColors.softBlackColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
