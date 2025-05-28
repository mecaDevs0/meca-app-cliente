import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../routes/app_pages.dart';
import '../controllers/my_vehicles_controller.dart';
import 'widgets/vehicle_details/vehicle_brand_row.dart';
import 'widgets/vehicle_details/vehicle_color_column.dart';
import 'widgets/vehicle_details/vehicle_date_last_review_column.dart';
import 'widgets/vehicle_details/vehicle_mileage_column.dart';
import 'widgets/vehicle_details/vehicle_model_column.dart';
import 'widgets/vehicle_details/vehicle_model_row.dart';
import 'widgets/vehicle_details/vehicle_plate_column.dart';
import 'widgets/vehicle_details/vehicle_year_column.dart';

class VehicleDetailsView extends GetView<MyVehiclesController> {
  const VehicleDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Detalhes do veículo',
        titleColor: AppColors.whiteColor,
        iconColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
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
                height: 20,
              ),
              VehicleModelRow(
                model: controller.vehicleDetails?.model ?? '',
                icon: controller.vehicleIcon,
              ),
              const SizedBox(
                height: 15,
              ),
              const Divider(
                thickness: 1,
                color: AppColors.grayBorderColor,
              ),
              const SizedBox(
                height: 15,
              ),
              VehiclePlateColumn(
                plate: controller.vehicleDetails?.plate ?? '',
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleBrandColumn(
                brand: controller.vehicleDetails?.manufacturer ?? '',
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleModelColumn(
                model: controller.vehicleDetails?.model ?? '',
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleMileageColumn(
                mileage: controller.vehicleDetails?.km ?? 0,
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleColorColumn(
                color: controller.vehicleDetails?.color ?? '',
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleYearColumn(
                year: controller.vehicleDetails?.year ?? '',
              ),
              const SizedBox(
                height: 20,
              ),
              VehicleDateLastReviewColumn(
                date: DateTime.fromMillisecondsSinceEpoch(
                  controller.vehicleDetails?.lastRevisionDate != null
                      ? controller.vehicleDetails!.lastRevisionDate! * 1000
                      : 0,
                ).toddMMyyyy(),
              ),
              const SizedBox(
                height: 15,
              ),
              const Divider(
                thickness: 1.0,
                color: AppColors.grayBorderColor,
              ),
              const SizedBox(
                height: 20,
              ),
              MegaBaseButton(
                'Editar veículo',
                buttonColor: AppColors.primaryColor,
                textColor: AppColors.whiteColor,
                buttonHeight: 46,
                borderRadius: 4.0,
                onButtonPress: () {
                  Get.toNamed(Routes.editVehicle);
                },
              ),
              const SizedBox(
                height: 20,
              ),
              MegaBaseButton(
                'Excluir veículo',
                buttonColor: AppColors.redAlertColor,
                textColor: AppColors.whiteColor,
                buttonHeight: 46,
                borderRadius: 4.0,
                onButtonPress: () {},
              ),
            ],
          ),
        );
      }),
    );
  }
}
