import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../routes/app_pages.dart';
import '../controllers/mechanic_workshop_details_controller.dart';
import 'widgets/description_tile.dart';
import 'widgets/mechanic_workshop_info.dart';
import 'widgets/schedule_working.dart';

class MechanicWorkshopDetailsView
    extends GetView<MechanicWorkshopDetailsController> {
  const MechanicWorkshopDetailsView({super.key});

  Future<void> openMapsSheet(
    BuildContext context, {
    required String workshopName,
    required double lat,
    required double long,
  }) async {
    try {
      final coords = Coords(lat, long);
      final availableMaps = await MapLauncher.installedMaps;

      if (context.mounted == false) {
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (BuildContext context) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Escolha um aplicativo de mapas',
                      style: TextStyle(
                        color: AppColors.fontRegularBlackColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final map in availableMaps)
                        ListTile(
                          onTap: () => map.showMarker(
                            coords: coords,
                            title: workshopName,
                          ),
                          title: Text(map.mapName),
                          leading: SvgPicture.asset(
                            map.icon,
                            height: 30.0,
                            width: 30.0,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      log(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Detalhes do estabelecimento',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;

            if (isTablet) {
              return _buildTabletLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        );
      }),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna esquerda - Informações principais
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const MechanicWorkshopInfo(),
                const SizedBox(height: 24),
                const Divider(
                  color: AppColors.grayBorderColor,
                  thickness: 1.0,
                ),
                const SizedBox(height: 24),
                DescriptionTile(
                  descriptionFontColor: AppColors.fontRegularBlackColor,
                  description:
                      controller.workshopDetails?.reason ?? 'Sem descrição',
                  title: 'Descrição',
                ),
                const SizedBox(height: 24),
                const Divider(
                  color: AppColors.grayBorderColor,
                  thickness: 1.0,
                ),
                const SizedBox(height: 24),
                DescriptionTile(
                  descriptionFontColor: AppColors.fontRegularBlackColor,
                  description:
                      '${controller.workshopDetails?.streetAddress}, n${controller.workshopDetails?.number}, Bairro ${controller.workshopDetails?.neighborhood}',
                  title: 'Endereço',
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Coluna direita - Mapa e horários
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: InkWell(
                      onTap: () => openMapsSheet(
                        Get.context!,
                        workshopName: controller.workshopDetails?.fullName ?? '',
                        lat: controller.workshopDetails?.latitude ?? 0.0,
                        long: controller.workshopDetails?.longitude ?? 0.0,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.grayBorderColor,
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map,
                                size: 48,
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Toque para abrir o mapa',
                                style: TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const ScheduleWorking(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const MechanicWorkshopInfo(),
          const SizedBox(height: 16),
          const Divider(
            color: AppColors.grayBorderColor,
            thickness: 1.0,
          ),
          const SizedBox(height: 16),
          DescriptionTile(
            descriptionFontColor: AppColors.fontRegularBlackColor,
            description:
                controller.workshopDetails?.reason ?? 'Sem descrição',
            title: 'Descrição',
          ),
          const SizedBox(height: 16),
          const Divider(
            color: AppColors.grayBorderColor,
            thickness: 1.0,
          ),
          const SizedBox(height: 16),
          DescriptionTile(
            descriptionFontColor: AppColors.fontRegularBlackColor,
            description:
                '${controller.workshopDetails?.streetAddress}, n${controller.workshopDetails?.number}, Bairro ${controller.workshopDetails?.neighborhood}',
            title: 'Endereço',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: InkWell(
                onTap: () => openMapsSheet(
                  Get.context!,
                  workshopName: controller.workshopDetails?.fullName ?? '',
                  lat: controller.workshopDetails?.latitude ?? 0.0,
                  long: controller.workshopDetails?.longitude ?? 0.0,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.grayBorderColor,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map,
                          size: 48,
                          color: AppColors.primaryColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Toque para abrir o mapa',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ScheduleWorking(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        MegaBaseButton(
          'Ver avaliações',
          buttonColor: AppColors.whiteColor,
          textColor: AppColors.primaryColor,
          onButtonPress: () {
            Get.toNamed(Routes.mechanicWorkshopReviews);
          },
          buttonHeight: 46,
          borderRadius: 4.0,
        ),
        const SizedBox(height: 16),
        MegaBaseButton(
          'Continuar',
          buttonColor: AppColors.primaryColor,
          textColor: AppColors.whiteColor,
          onButtonPress: () {
            Get.toNamed(Routes.services);
          },
          buttonHeight: 46,
          borderRadius: 4.0,
        ),
      ],
    );
  }
}
