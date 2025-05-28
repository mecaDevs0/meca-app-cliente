import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/app_colors.dart';

class OrderWorkshopRow extends StatelessWidget {
  const OrderWorkshopRow({
    super.key,
    this.workshopImage,
    required this.workshopName,
    required this.carBrand,
    required this.vehiclePlate,
    required this.date,
  });

  final String? workshopImage;
  final String workshopName;
  final String carBrand;
  final String vehiclePlate;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MegaCachedNetworkImage(
          radius: 64,
          width: 35,
          height: 35,
          borderWidth: 1.0,
          borderColor: AppColors.grayBorderColor,
          imageUrl: workshopImage,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workshopName,
                style: const TextStyle(
                  color: AppColors.softBlackColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        carBrand,
                        style: const TextStyle(
                          color: AppColors.softBlackColor,
                          fontWeight: FontWeight.w300,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(
                        width: 2.0,
                      ),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: const BoxDecoration(
                          color: AppColors.pointGrayColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(
                        width: 2.0,
                      ),
                      Text(
                        vehiclePlate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppColors.neutralGrayColor,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
