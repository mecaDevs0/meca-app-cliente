import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    // Verifica se estamos em um tablet
    final isTablet = MediaQuery.of(context).size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Oficinas',
                    style: TextStyle(
                      color: AppColors.blackPrimaryColor,
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => Future.sync(
                    () {
                      // Prevenção contra chamadas durante a renderização
                      if (controller.workshopsPagingController.error != null) {
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          controller.workshopsPagingController.refresh();
                        });
                        return Future.value();
                      }
                      // Corrigido: chamamos refresh() e depois retornamos um Future vazio
                      // ao invés de tentar usar o resultado void do refresh()
                      controller.workshopsPagingController.refresh();
                      return Future.value();
                    },
                  ),
                  child: controller.workshopsPagingController.error != null
                      ? _buildErrorView()
                      : PagedListView<int, MechanicWorkshop>(
                          pagingController: controller.workshopsPagingController,
                          builderDelegate: PagedChildBuilderDelegate<MechanicWorkshop>(
                            itemBuilder: (context, item, index) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 12 : 10,
                                  horizontal: isTablet ? 4 : 0,
                                ),
                                child: MechanicWorkshopCard(
                                  mechanicWorkshop: item,
                                  onTap: () {
                                    if (item.id != null && item.id!.isNotEmpty) {
                                      // Navegação segura com verificação de id
                                      SchedulerBinding.instance.addPostFrameCallback((_) {
                                        Get.toNamed(
                                          Routes.mechanicWorkshopDetails,
                                          arguments: WorkshopArgs(item.id!),
                                        );
                                      });
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
                            firstPageProgressIndicatorBuilder: (context) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryColor,
                                ),
                              );
                            },
                            firstPageErrorIndicatorBuilder: (context) => _buildErrorView(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.primaryColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ocorreu um erro ao carregar as oficinas',
            style: TextStyle(
              color: AppColors.fontRegularBlackColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          MegaBaseButton(
            'Tentar novamente',
            buttonColor: AppColors.primaryColor,
            textColor: AppColors.whiteColor,
            onButtonPress: () {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                controller.workshopsPagingController.refresh();
              });
            },
            buttonHeight: 46,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
}
