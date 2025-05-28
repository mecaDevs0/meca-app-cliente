import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../routes/app_pages.dart';
import '../../controllers/my_vehicles_controller.dart';

class MyVehicleCard extends GetView<MyVehiclesController> {
  const MyVehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
    this.icon = AppImages.icCarOne,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SvgPicture.asset(icon, width: 32),
              const SizedBox(
                width: 10,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        vehicle.model ?? '',
                        style: const TextStyle(
                          color: AppColors.blackPrimaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.grayLineColor,
                          shape: BoxShape.circle,
                        ),
                        height: 4,
                        width: 4,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        vehicle.manufacturer ?? '',
                        style: const TextStyle(
                          color: AppColors.neutralGrayColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    vehicle.plate ?? '',
                    style: const TextStyle(
                      color: AppColors.softBlackColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    '${vehicle.km ?? 0} km',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutralGrayColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  controller.getVehicleDetails(vehicle.id!);
                  Get.toNamed(
                    Routes.editVehicle,
                    arguments: {
                      'vehicle': vehicle,
                    },
                  );
                },
                icon: SvgPicture.asset(
                  AppImages.icEdit,
                ),
              ),
              IconButton(
                onPressed: () {
                  controller.removeVehicle(vehicle.id!);
                },
                icon: SvgPicture.asset(
                  AppImages.icTrash,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
