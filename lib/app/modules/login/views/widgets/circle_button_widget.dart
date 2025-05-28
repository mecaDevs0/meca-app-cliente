import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../core/app_colors.dart';

class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.iconPath,
  });

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.grayBorderColor),
      ),
      child: Center(
        child: SvgPicture.asset(
          iconPath,
          height: 24,
          width: 24,
        ),
      ),
    );
  }
}
