import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/args/workshop_args.dart';
import '../../../../../data/models/mechanic_workshop.dart';
import '../../../../../routes/app_pages.dart';
import '../../../controllers/home_controller.dart';
import 'card/mechanic_workshop_card.dart';

class MechanicWorkshopsList extends GetView<HomeController> {
  const MechanicWorkshopsList({
    super.key,
    required this.isSeeAll,
  });

  final bool isSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Oficinas',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isSeeAll)
                InkWell(
                  onTap: () {
                    Get.toNamed(Routes.mechanicWorkshops);
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
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.sync(
                () => controller.workshopsPagingController.refresh(),
              ),
              child: PagedListView<int, MechanicWorkshop>(
                shrinkWrap: true,
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
