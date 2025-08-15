import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/empty_list_indicator.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/error_indicator.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/order.dart';
import '../../../routes/app_pages.dart';
import '../controllers/orders_placed_controller.dart';
import 'widgets/order_card.dart';
import 'widgets/orders_status_filter.dart';

class OrdersPlacedView extends GetView<OrdersPlacedController> {
  const OrdersPlacedView({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Quando o usuário pressionar o botão voltar, navegamos diretamente para a home
      onWillPop: () async {
        Get.offAllNamed(Routes.home);
        return false; // Impede o comportamento padrão do botão voltar
      },
      child: Scaffold(
        appBar: AppBarCustom(
          iconColor: AppColors.whiteColor,
          title: 'Pedidos realizados',
          backgroundColor: AppColors.primaryColor,
          titleColor: AppColors.whiteColor,
          // Usando o parâmetro correto onLeadingIconTap em vez de onLeadingTap
          onLeadingIconTap: () => Get.offAllNamed(Routes.home),
        ),
        body: Container(
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtrar por status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fontBoldBlackColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OrdersStatusFilter(
                        onTap: (int status) {
                          controller.filterByStatus(status);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Toque no pedido para ver os detalhes',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.fontMediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => Future.sync(
                      () => controller.pagingController.refresh(),
                    ),
                    child: PagedListView<int, Order>(
                      shrinkWrap: true,
                      pagingController: controller.pagingController,
                      builderDelegate: PagedChildBuilderDelegate(
                        itemBuilder: (context, item, index) => GestureDetector(
                          onTap: () => Get.toNamed(
                            Routes.orderDetails,
                            arguments: {'orderId': item.id!},
                          ),
                          child: OrderCard(order: item),
                        ),
                        firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
                          error: controller.pagingController.error,
                          onTryAgain: () => controller.pagingController.refresh(),
                        ),
                        noItemsFoundIndicatorBuilder: (context) =>
                            const EmptyListIndicator(
                          iconColor: AppColors.primaryColor,
                          message: 'Sem pedidos para exibir',
                        ),
                        firstPageProgressIndicatorBuilder: (context) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Carregando pedidos...',
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
        ),
      ),
    );
  }
}
