import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
          return LayoutBuilder(
            builder: (context, constraints) {
              // Adaptação para diferentes tamanhos de tela
              final isTablet = constraints.maxWidth > 600;
              final imageHeight = isTablet ? 200.0 : 160.0;
              final imageWidth = isTablet ? constraints.maxWidth * 0.8 : 342.0;
              final fontSize = isTablet ? 18.0 : 16.0;
              final descFontSize = isTablet ? 14.0 : 12.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: isTablet ? 32 : 24,
                ),
                child: Skeletonizer(
                  enabled: controller.isLoading,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: controller.serviceDetail?.photo != null
                            ? MegaCachedNetworkImage(
                                imageUrl: controller.serviceDetail!.photo,
                                width: imageWidth,
                                height: imageHeight,
                              )
                            : Container(
                                width: imageWidth,
                                height: imageHeight,
                                color: AppColors.grayBorderColor,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              controller.serviceDetail?.name ?? '',
                              style: TextStyle(
                                color: AppColors.fontBoldBlackColor,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.serviceDetail?.description ?? 'Sem descrição',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: AppColors.fontRegularBlackColor,
                          fontSize: descFontSize,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Usando Flexible para evitar problemas de layout
                      SizedBox(
                        height: constraints.maxHeight * 0.55,
                        child: const ServiceWorkshopsList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
