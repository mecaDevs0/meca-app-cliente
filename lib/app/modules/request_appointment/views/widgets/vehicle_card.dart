import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/core.dart';
import '../../../../data/models/vehicle.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.vehicle,
    required this.isSelected,
    this.icon = AppImages.icCarOne,
    super.key,
  });
  final Vehicle vehicle;
  final bool isSelected;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 102,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.greenBackgroundLightColor : Colors.white,
        border: Border.all(
          color:
              isSelected ? AppColors.primaryColor : AppColors.grayBorderColor,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(icon, width: 32),
          const SizedBox(height: 4),
          Text(
            vehicle.manufacturer ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.blackPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vehicle.plate ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.softBlackColor,
            ),
          ),
        ],
      ),
    ).unite;
  }
}
