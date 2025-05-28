import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/args/workshop_args.dart';
import '../../../../data/models/mechanic_workshop.dart';
import '../../../../routes/app_pages.dart';
import '../../../home/views/widgets/mechanic_workshops/card/mechanic_workshop_card.dart';
import '../../controllers/service_details_controller.dart';

class ServiceWorkshopsList extends GetView<ServiceDetailsController> {
  const ServiceWorkshopsList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oficinas',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.sync(
                () => controller.workshopsPagingController.refresh(),
              ),
              child: PagedListView<int, MechanicWorkshop>(
                pagingController: controller.workshopsPagingController,
                builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
                  itemBuilder: (context, item, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: MechanicWorkshopCard(
                        mechanicWorkshop: item,
                        onTap: () {
                          if (item.id.isNullOrEmpty == false) {
                            Get.toNamed(
                              Routes.mechanicWorkshopDetails,
                              arguments: WorkshopArgs(item.id!),
                            );
                          }
                        },
                      ),
                    );
                  },
                  noItemsFoundIndicatorBuilder: (context) =>
                      const EmptyListIndicator(
                    isShowIcon: false,
                    message: 'Nenhuma oficina encontrada',
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
