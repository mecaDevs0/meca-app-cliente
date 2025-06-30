import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/empty_list_indicator.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/error_indicator.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/args/workshop_args.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../core/widgets/app_filter_bottom_sheet.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../routes/app_pages.dart';
import '../../app_filter/view/app_filter.dart';
import '../../home/views/widgets/mechanic_workshops/card/mechanic_workshop_card.dart';
import '../../home/views/widgets/search_bar.dart';
import '../controllers/mechanic_workshops_controller.dart';

class MechanicWorkshopsView extends GetView<MechanicWorkshopsController> {
  MechanicWorkshopsView({super.key});

  final TextEditingController _searchController = TextEditingController();

  void _applyFilters(FilterParams filter) {
    controller.updateFilters(
      searchQuery: _searchController.text,
      selectedCategories: filter.services,
      rating: filter.rating,
      distance: filter.distance,
    );

    controller.pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Estabelecimentos',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                SearchBarWidget(
                  controller: _searchController,
                  onSearchChanged: (value) {
                    controller.updateFilters(searchQuery: value);
                    controller.pagingController.refresh();
                  },
                  onFilterTap: () => showFilterBottomSheet(
                    context: context,
                    initialParams: FilterParams(
                      rating: controller.rating,
                      services: controller.services,
                      distance: controller.distance,
                    ),
                    onTap: _applyFilters,
                    availableCategories: controller.availableCategories,
                  ),
                  hintText: 'Pesquisar oficinas...',
                  hasFilter: true,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isTablet ? _buildTabletGrid() : _buildMobileList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabletGrid() {
    return PagedGridView<int, MechanicWorkshop>(
      pagingController: controller.pagingController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
        itemBuilder: (context, workshop, index) => MechanicWorkshopCard(
          mechanicWorkshop: workshop,
          onTap: () => Get.toNamed(
            Routes.mechanicWorkshopDetails,
            arguments: WorkshopArgs(workshop.id!, workshopName: workshop.fullName),
          ),
        ),
        firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
          error: controller.pagingController.error,
          onTryAgain: () => controller.pagingController.refresh(),
        ),
        noItemsFoundIndicatorBuilder: (context) => const EmptyListIndicator(
          message: 'Nenhuma oficina encontrada',
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return PagedListView<int, MechanicWorkshop>(
      pagingController: controller.pagingController,
      builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
        itemBuilder: (context, workshop, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MechanicWorkshopCard(
            mechanicWorkshop: workshop,
            onTap: () => Get.toNamed(
              Routes.mechanicWorkshopDetails,
              arguments: WorkshopArgs(workshop.id!, workshopName: workshop.fullName),
            ),
          ),
        ),
        firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
          error: controller.pagingController.error,
          onTryAgain: () => controller.pagingController.refresh(),
        ),
        noItemsFoundIndicatorBuilder: (context) => const EmptyListIndicator(
          message: 'Nenhuma oficina encontrada',
        ),
      ),
    );
  }
}
