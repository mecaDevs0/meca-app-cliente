import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
            // Definição mais precisa do que é um tablet e iPad grande para melhor adaptação
            final isTablet = constraints.maxWidth > 600;
            // Ajuste adicional para iPads maiores como iPad Pro
            final isLargeTablet = constraints.maxWidth > 900;

            if (isTablet) {
              return _buildTabletLayout(isLargeTablet);
            } else {
              return _buildMobileLayout();
            }
          },
        );
      }),
    );
  }

  Widget _buildTabletLayout(bool isLargeTablet) {
    // Ajustes de tamanho com base no tipo de tablet
    final double padding = isLargeTablet ? 32.0 : 24.0;
    final double spacing = isLargeTablet ? 48.0 : 32.0;
    final double verticalSpacing = isLargeTablet ? 32.0 : 24.0;
    final double mapHeight = isLargeTablet ? 350.0 : 280.0;
    final double borderRadius = isLargeTablet ? 16.0 : 10.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna esquerda - Informações principais
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: verticalSpacing),
                // Widget de informações do estabelecimento com indicador de tablet
                const MechanicWorkshopInfo(isTablet: true),
                SizedBox(height: verticalSpacing),
                Divider(
                  color: AppColors.grayBorderColor,
                  thickness: isLargeTablet ? 1.5 : 1.0,
                ),
                SizedBox(height: verticalSpacing),
                DescriptionTile(
                  descriptionFontColor: AppColors.fontRegularBlackColor,
                  description:
                      controller.workshopDetails?.reason?.isNotEmpty == true 
                          ? controller.workshopDetails!.reason!
                          : 'Este estabelecimento ainda não possui uma descrição cadastrada.',
                  title: 'Descrição',
                  // Aumentar somente o tamanho do título para melhor legibilidade
                  titleFontSize: isLargeTablet ? 20.0 : 18.0,
                ),
                SizedBox(height: verticalSpacing),
                Divider(
                  color: AppColors.grayBorderColor,
                  thickness: isLargeTablet ? 1.5 : 1.0,
                ),
                SizedBox(height: verticalSpacing),
                DescriptionTile(
                  descriptionFontColor: AppColors.fontRegularBlackColor,
                  description:
                      '${controller.workshopDetails?.streetAddress}, n${controller.workshopDetails?.number}, Bairro ${controller.workshopDetails?.neighborhood}',
                  title: 'Endereço',
                  // Aumentar somente o tamanho do título para melhor legibilidade
                  titleFontSize: isLargeTablet ? 20.0 : 18.0,
                ),
              ],
            ),
          ),
          SizedBox(width: spacing),
          // Coluna direita - Mapa e horários
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: verticalSpacing),
                ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: SizedBox(
                    height: mapHeight,
                    width: double.infinity,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          controller.workshopDetails?.latitude ?? 0.0,
                          controller.workshopDetails?.longitude ?? 0.0,
                        ),
                        zoom: 14.0,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('workshopLocation'),
                          position: LatLng(
                            controller.workshopDetails?.latitude ?? 0.0,
                            controller.workshopDetails?.longitude ?? 0.0,
                          ),
                          infoWindow: InfoWindow(
                            title: controller.workshopDetails?.fullName,
                          ),
                        ),
                      },
                      onMapCreated: (GoogleMapController controller) {
                        // Adicione qualquer configuração adicional do mapa aqui, se necessário
                      },
                    ),
                  ),
                ),
                SizedBox(height: verticalSpacing),
                // Adicionando widget de preview do endereço
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: AppColors.grayBorderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Endereço do Estabelecimento',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.blackPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${controller.workshopDetails?.streetAddress ?? ''}, '
                              'n${controller.workshopDetails?.number ?? ''}, '
                              '${controller.workshopDetails?.neighborhood ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.fontRegularBlackColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: verticalSpacing),
                // Widget de horários de funcionamento com suporte a tablet
                ScheduleWorking(isTablet: isLargeTablet),
                SizedBox(height: verticalSpacing),
                _buildActionButtons(isTablet: isLargeTablet),
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
                controller.workshopDetails?.reason?.isNotEmpty == true 
                    ? controller.workshopDetails!.reason!
                    : 'Este estabelecimento ainda não possui uma descrição cadastrada.',
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
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    controller.workshopDetails?.latitude ?? 0.0,
                    controller.workshopDetails?.longitude ?? 0.0,
                  ),
                  zoom: 14.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('workshopLocation'),
                    position: LatLng(
                      controller.workshopDetails?.latitude ?? 0.0,
                      controller.workshopDetails?.longitude ?? 0.0,
                    ),
                    infoWindow: InfoWindow(
                      title: controller.workshopDetails?.fullName,
                    ),
                  ),
                },
                onMapCreated: (GoogleMapController controller) {
                  // Adicione qualquer configuração adicional do mapa aqui, se necessário
                },
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

  Widget _buildActionButtons({bool isTablet = false}) {
    // Ajustes de tamanho para tablets
    final double buttonHeight = isTablet ? 56.0 : 46.0;
    final double borderRadius = isTablet ? 8.0 : 4.0;
    final double spacing = isTablet ? 24.0 : 16.0;

    return Column(
      children: [
        MegaBaseButton(
          'Ver avaliações',
          buttonColor: AppColors.whiteColor,
          textColor: AppColors.primaryColor,
          onButtonPress: () {
            Get.toNamed(
              Routes.mechanicWorkshopReviews,
              arguments: {
                'workshopId': controller.workshopId,
                'workshopName': controller.workshopDetails?.fullName,
              },
            );
          },
          buttonHeight: buttonHeight,
          borderRadius: borderRadius,
        ),
        SizedBox(height: spacing),
                  MegaBaseButton(
            'Agendar',
            buttonColor: AppColors.primaryColor, // Cor primária
            textColor: AppColors.whiteColor, // Texto branco
            onButtonPress: () {
              log('Navigating to requestAppointment with:');
              log('workshopId: ${controller.workshopId}');
              log('workshopDetails: ${controller.workshopDetails}');
              log('selectedService: ${controller.selectedService}');
              
              // Verificar se o workshopId está válido
              if (controller.workshopId.isEmpty) {
                log('ERRO: workshopId está vazio!');
                MegaSnackbar.showErroSnackBar('Erro: ID do estabelecimento não encontrado');
                return;
              }
              
              Get.toNamed(
                Routes.requestAppointment,
                arguments: {
                  'workshopId': controller.workshopId,
                  'workshopDetails': controller.workshopDetails,
                  'selectedService': controller.selectedService,
                },
              );
            },
            buttonHeight: buttonHeight,
            borderRadius: borderRadius,
          ),
      ],
    );
  }
}
