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
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Pedidos realizados',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 20,
            ),
            OrdersStatusFilter(
              onTap: (int status) {
                controller.filterByStatus(status);
              },
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Aperte no pedido para ver os detalhes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.softBlackColor,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
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
    );
  }
}
