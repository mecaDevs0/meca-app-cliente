import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../controllers/service_details_controller.dart';
import 'widgets/service_workshops_list.dart';

class ServiceDetailsView extends GetView<ServiceDetailsController> {
  const ServiceDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Detalhes do serviço',
        titleColor: AppColors.whiteColor,
        iconColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
      ),
      body: Obx(
        () {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Skeletonizer(
              enabled: controller.isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  MegaCachedNetworkImage(
                    imageUrl: controller.serviceDetail?.photo,
                    width: 342,
                    height: 160,
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        controller.serviceDetail?.name ?? '',
                        style: const TextStyle(
                          color: AppColors.fontBoldBlackColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.serviceDetail?.description ?? 'Sem descrição',
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: AppColors.fontRegularBlackColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.60,
                    child: const ServiceWorkshopsList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
