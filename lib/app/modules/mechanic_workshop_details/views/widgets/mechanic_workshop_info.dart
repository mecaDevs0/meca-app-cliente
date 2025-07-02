import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../core/args/workshop_args.dart';
import '../../../../core/widgets/app_rating_row.dart';
import '../../../../routes/app_pages.dart';
import '../../controllers/mechanic_workshop_details_controller.dart';

class MechanicWorkshopInfo extends GetView<MechanicWorkshopDetailsController> {
  const MechanicWorkshopInfo({
    super.key,
    this.isTablet = false, // Novo parâmetro para modo tablet
  });

  final bool isTablet; // Controla o tamanho dos elementos em tablets

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MegaCachedNetworkImage(
            width: 83,
            height: 83,
            radius: 100,
            imageUrl: controller.workshopDetails?.photo,
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            controller.workshopDetails?.companyName ?? '',
            style: const TextStyle(
              color: AppColors.softBlackColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              InkWell(
                onTap: () {
                  Get.toNamed(
                    Routes.mechanicWorkshopReviews,
                    arguments: WorkshopArgs(
                      controller.workshopId,
                    ),
                  );
                },
                child: const Text(
                  'Ver avaliações',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.vibrantAquaBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.vibrantAquaBlue,
                    decorationStyle: TextDecorationStyle.solid,
                  ),
                ),
              ),
              AppRatingRow(rating: controller.workshopDetails?.rating ?? 0),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              SvgPicture.asset(
                AppImages.icCar,
                width: 16,
                height: 16,
              ),
              Text(
                controller.workshopDetails?.cityName ?? '',
                style: const TextStyle(
                  color: AppColors.neutralGrayColor,
                  fontSize: 12,
                ),
              ),
              Container(
                width: 2,
                height: 2,
                decoration: const ShapeDecoration(
                  color: AppColors.pointGrayColor,
                  shape: OvalBorder(),
                ),
              ),
              Text(
                '${controller.workshopDetails?.distance ?? 0}km',
                style: const TextStyle(
                  color: AppColors.neutralGrayColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
