import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/empty_list_indicator.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/args/service_args.dart';
import '../../../../../data/models/service.dart';
import '../../../../../routes/app_pages.dart';
import '../../../controllers/home_controller.dart';
import 'service_card.dart';

class ServicesList extends GetView<HomeController> {
  const ServicesList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Serviços',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: () {
                  Get.toNamed(Routes.services);
                },
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.sync(
                () => controller.servicesPagingController.refresh(),
              ),
              child: PagedListView<int, Service>(
                scrollDirection: Axis.horizontal,
                pagingController: controller.servicesPagingController,
                builderDelegate: PagedChildBuilderDelegate<Service>(
                  itemBuilder: (context, item, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: GestureDetector(
                        onTap: () {
                          Get.toNamed(
                            Routes.serviceDetails,
                            arguments: ServiceArgs(item.id ?? ''),
                          );
                        },
                        child: ServiceCard(
                          service: item,
                        ),
                      ),
                    );
                  },
                  noItemsFoundIndicatorBuilder: (context) =>
                      const EmptyListIndicator(
                    isShowIcon: false,
                    message: 'Nenhum serviço encontrado',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
