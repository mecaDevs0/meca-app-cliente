import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
        ClipRRect(
          borderRadius: BorderRadius.circular(64),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.grayBorderColor,
                width: 1.0,
              ),
              shape: BoxShape.circle,
            ),
            child: CachedNetworkImage(
              imageUrl: workshopImage ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.store, color: AppColors.gray500),
            ),
          ),
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
