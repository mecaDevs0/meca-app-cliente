import 'package:flutter/material.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/models/scheduling/vehicle_scheduling.dart';
import '../../../../routes/app_pages.dart';
import '../../controllers/request_appointment_controller.dart';
import 'vehicle_card.dart';

class SelectVehicleWidget extends GetView<RequestAppointmentController> {
  const SelectVehicleWidget({super.key});

  List<String> get vehicles => [
        AppImages.icCarOne,
        AppImages.icCarTwo,
        AppImages.icCarThree,
      ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryColor,
          ),
        );
      }

      if (controller.vehicles.isEmpty) {
        return Center(
          child: Column(
            children: [
              const SizedBox(
                child: Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Text(
                    'Sem veículos cadastrados',
                    style: TextStyle(color: AppColors.abbey),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Get.toNamed(
                    Routes.registerVehicle,
                    arguments: {
                      'isFromSchedule': true,
                    },
                  );
                },
                child: const SizedBox(
                  child: Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text(
                      'Cadastrar novo veículo',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = controller.vehicles[index];
            return GestureDetector(
              onTap: () => controller.selectVehicle(
                VehicleScheduling(
                  id: vehicle.id,
                  plate: '${vehicle.manufacturer} ${vehicle.plate}',
                ),
              ),
              child: Obx(
                () => VehicleCard(
                  vehicle: vehicle,
                  isSelected: controller.selectedVehicle?.id == vehicle.id,
                  icon: vehicles[index % vehicles.length],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
