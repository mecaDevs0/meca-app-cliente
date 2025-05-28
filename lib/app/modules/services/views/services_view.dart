import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/args/service_args.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../core/widgets/app_filter_bottom_sheet.dart';
import '../../../data/models/service.dart';
import '../../../routes/app_pages.dart';
import '../../app_filter/view/app_filter.dart';
import '../../home/views/widgets/search_bar.dart';
import '../controllers/services_controller.dart';
import 'widgets/service_item.dart';

class ServicesView extends GetView<ServicesController> {
  ServicesView({super.key});

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
        title: 'Serviços',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            SearchBarWidget(
              controller: _searchController,
              onSearchChanged: (value) {
                controller.updateFilters(searchQuery: value);
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
              hintText: 'Busque por nome do serviço',
              hasFilter: true,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.sync(
                  () => controller.pagingController.refresh(),
                ),
                child: PagedListView<int, Service>(
                  shrinkWrap: true,
                  pagingController: controller.pagingController,
                  builderDelegate: PagedChildBuilderDelegate(
                    itemBuilder: (context, item, index) => ServiceItem(
                      service: item,
                      onTap: () async {
                        if (item.id.isNullOrEmpty == false) {
                          Get.toNamed(
                            Routes.serviceDetails,
                            arguments: ServiceArgs(
                              item.id!,
                            ),
                          );
                        }
                      },
                    ),
                    firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
                      error: controller.pagingController.error,
                      onTryAgain: () => controller.pagingController.refresh(),
                    ),
                    noItemsFoundIndicatorBuilder: (context) =>
                        const EmptyListIndicator(
                      iconColor: AppColors.primaryColor,
                      message: 'Sem serviços para exibir',
                    ),
                    firstPageProgressIndicatorBuilder: (context) {
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Carregando serviços...',
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
            ),
          ],
        ),
      ),
    );
  }
}
