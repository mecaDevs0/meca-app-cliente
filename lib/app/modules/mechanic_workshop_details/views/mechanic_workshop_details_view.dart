import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/args/workshop_args.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../data/models/profile.dart';
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 32,
              ),
              const MechanicWorkshopInfo(),
              const SizedBox(
                height: 16,
              ),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
              DescriptionTile(
                descriptionFontColor: AppColors.fontRegularBlackColor,
                description:
                    controller.workshopDetails?.reason ?? 'Sem descrição',
                title: 'Descrição',
              ),
              const SizedBox(
                height: 16,
              ),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
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
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        controller.workshopDetails?.latitude ?? 0,
                        controller.workshopDetails?.longitude ?? 0,
                      ),
                      zoom: 12,
                    ),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('workshop'),
                        position: LatLng(
                          controller.workshopDetails?.latitude ?? 0,
                          controller.workshopDetails?.longitude ?? 0,
                        ),
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  openMapsSheet(
                    context,
                    workshopName:
                        controller.workshopDetails?.fullName ?? 'Oficina',
                    lat: controller.workshopDetails?.latitude ?? 0,
                    long: controller.workshopDetails?.longitude ?? 0,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SvgPicture.asset(
                      AppImages.icGps,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Como chegar',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
              DescriptionTile(
                descriptionFontColor: AppColors.fontRegularBlackColor,
                description:
                    'Whatsapp \n ${controller.workshopDetails?.phone.formattedPhone}',
                title: 'Contatos',
              ),
              const SizedBox(
                height: 16,
              ),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
              Obx(
                () {
                  if (controller.isLoadingWorkshopSchedule) {
                    return const CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    );
                  }
                  return const ScheduleWorking();
                },
              ),
              const SizedBox(
                height: 16,
              ),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.workshopServices
                      .map(
                        (service) => AppStatusChip(
                          label: service.service?.name,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              const Divider(
                color: AppColors.grayBorderColor,
                thickness: 1.0,
              ),
              const SizedBox(
                height: 16,
              ),
              MegaBaseButton(
                'Agendar agora',
                buttonColor: AppColors.primaryColor,
                textColor: AppColors.whiteColor,
                onButtonPress: () {
                  final workShop = controller.workshopDetails;
                  if (workShop?.id.isNullOrEmpty == false) {
                    final profile = Profile.fromCache();
                    if (profile.cpf != null && profile.zipCode != null) {
                      Get.toNamed(
                        Routes.requestAppointment,
                        arguments: WorkshopArgs(
                          workShop!.id!,
                          workshopName: workShop.fullName ?? '',
                        ),
                      );
                    } else {
                      Get.toNamed(
                        Routes.completeRegistration,
                        arguments: WorkshopArgs(
                          workShop!.id!,
                          workshopName: workShop.fullName ?? '',
                        ),
                      );
                    }
                  }
                },
                buttonHeight: 46,
                borderRadius: 4.0,
              ),
            ],
          ),
        );
      }),
    );
  }
}
