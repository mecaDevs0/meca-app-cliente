import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/vehicle.dart';
import '../../../routes/app_pages.dart';
import '../../home/views/widgets/search_bar.dart';
import '../controllers/my_vehicles_controller.dart';
import 'widgets/my_vehicle_card.dart';

class MyVehiclesView extends GetView<MyVehiclesController> {
  MyVehiclesView({super.key});

  final TextEditingController _searchController = TextEditingController();

  List<String> get vehicles => [
        AppImages.icCarOne,
        AppImages.icCarTwo,
        AppImages.icCarThree,
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Meus veículos',
        titleColor: AppColors.whiteColor,
        iconColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 20,
            ),
            SearchBarWidget(
              controller: _searchController,
              onFilterTap: () {},
              hintText: 'Busque pelo numero da placa, marca ou fabricante',
              hasFilter: false,
              onSearchChanged: (value) => controller.search = value,
            ),
            const SizedBox(
              height: 20,
            ),
            MegaBaseButton(
              'Cadastrar novo veículo',
              buttonColor: AppColors.primaryColor,
              textColor: AppColors.whiteColor,
              onButtonPress: () {
                Get.toNamed(Routes.registerVehicle);
              },
              buttonHeight: 46,
              borderRadius: 4.0,
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'Veículos cadastrados',
              style: TextStyle(
                color: AppColors.blackPrimaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            RefreshIndicator(
              onRefresh: () => Future.sync(
                () => controller.pagingController.refresh(),
              ),
              child: PagedListView<int, Vehicle>(
                shrinkWrap: true,
                pagingController: controller.pagingController,
                builderDelegate: PagedChildBuilderDelegate(
                  itemBuilder: (context, item, index) => MyVehicleCard(
                    vehicle: item,
                    onTap: () {
                      controller.changeVehicleIcon(
                        vehicles[index % vehicles.length],
                        item.id!,
                      );
                      Get.toNamed(
                        Routes.vehicleDetails,
                      );
                    },
                    icon: vehicles[index % vehicles.length],
                  ),
                  firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
                    error: controller.pagingController.error,
                    onTryAgain: () => controller.pagingController.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (context) =>
                      const EmptyListIndicator(
                    iconColor: AppColors.primaryColor,
                    message: 'Sem veículos para exibir',
                  ),
                  firstPageProgressIndicatorBuilder: (context) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Carregando veículos...',
                          style: TextStyle(
                            color: AppColors.abbey,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
