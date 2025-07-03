import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:developer';
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

  void _navigateToServiceDetails(Service service) {
    try {
      // Verifica se o serviço tem ID válido antes de tentar navegar
      if (service.id != null && service.id!.isNotEmpty) {
        // Usando SchedulerBinding para garantir que a navegação ocorra após a construção do frame
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            Get.toNamed(
              Routes.serviceDetails,
              arguments: ServiceArgs(service.id!),
              // Prevenindo acúmulo de rotas e erros de navegação
              preventDuplicates: true,
            )?.then((_) {
              // Limpa o estado quando retornar da tela de detalhes
              controller.clearServiceState();
            });
          } catch (e) {
            // Tratamento de erro caso a navegação falhe
            controller.clearServiceState(); // Limpa o estado em caso de falha
            log('Erro ao navegar para detalhes do serviço', error: e);
            Get.snackbar(
              'Atenção',
              'Não foi possível carregar os detalhes deste serviço.',
              backgroundColor: Colors.amber,
              colorText: Colors.black,
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });
      } else {
        // Feedback para o usuário quando o ID for inválido
        controller.clearServiceState(); // Limpa o estado em caso de ID inválido
        Get.snackbar(
          'Atenção',
          'Informações do serviço incompletas. Tente novamente mais tarde.',
          backgroundColor: Colors.amber,
          colorText: Colors.black,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      // Último nível de proteção para evitar que o app trave completamente
      controller.clearServiceState(); // Limpa o estado em caso de erro crítico
      log('Erro crítico ao processar navegação', error: e);
      Get.snackbar(
        'Erro',
        'Ocorreu um erro ao processar sua solicitação.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptação para diferentes tamanhos de tela
          final isTablet = constraints.maxWidth > 600;
          final horizontalPadding = isTablet ? 24.0 : 16.0;
          final verticalSpacing = isTablet ? 24.0 : 16.0;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: verticalSpacing),
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
                  SizedBox(height: verticalSpacing),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => Future.sync(
                        () => controller.pagingController.refresh(),
                      ),
                      child: PagedListView<int, Service>.separated(
                        pagingController: controller.pagingController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                        builderDelegate: PagedChildBuilderDelegate<Service>(
                          itemBuilder: (context, item, index) => ServiceItem(
                            service: item,
                            onTap: () => _navigateToServiceDetails(item),
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
                            return const Center(
                              child: Column(
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
                              ),
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
        },
      ),
    );
  }
}
