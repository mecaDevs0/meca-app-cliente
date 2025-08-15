import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../core/utils/workshop_name_helper.dart';
import '../../../routes/app_pages.dart';
import '../controllers/order_details_controller.dart';
import 'widgets/free_repair_bottomsheet.dart';
import 'widgets/mechanic_workshop_info.dart';
import 'widgets/order_historic.dart';
import 'widgets/rating_order.dart';
import 'widgets/rating_order_confirmation.dart';
import 'widgets/service_info.dart';
import 'widgets/service_title.dart';

class OrderDetailsView extends StatefulWidget {
  const OrderDetailsView({super.key});

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState
    extends MegaState<OrderDetailsView, OrderDetailsController> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final double bottomPadding = bottom == 0 ? 8 : 22;

    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Detalhes do pedido',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: Obx(() {
        if (controller.isLoadingDetails) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
          );
        }
        
        if (controller.orderDetails == null) {
          return const Center(
            child: Text('Pedido não encontrado'),
          );
        }
        
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MechanicWorkshopInfo(
                      isShowWhatsApp: true,
                    ),
                    const SizedBox(height: 12),
                    ServiceInfo(
                      order: controller.orderDetails!,
                    ),
                    const SizedBox(height: 8),
                    const ServiceTitle(
                      title: 'Histórico do serviço',
                    ),
                    const SizedBox(height: 16),
                    OrderHistoric(scrollController: _scrollController),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (controller.orderDetails?.status == 26 &&
                  controller.orderDetails?.hasEvaluated == false) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 4,
                        offset: Offset.zero,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MegaBaseButton(
                        'Avaliar serviço',
                        buttonColor: AppColors.primaryColor,
                        textColor: AppColors.whiteColor,
                        onButtonPress: () {
                          showRatingOrderBottomSheet(
                            context: context,
                            onTap: (
                              int attendanceQuality,
                              int serviceQuality,
                              int costBenefit,
                              String obs,
                            ) async {
                              final isSuccess = await controller.ratingOrder(
                                attendanceQuality,
                                serviceQuality,
                                costBenefit,
                                obs,
                              );
                              if (isSuccess && context.mounted) {
                                showRatingOrderConfirmationBottomSheet(
                                  context: context,
                                  onTap: () {
                                    final workshop =
                                        controller.orderDetails?.workshop;
                                    if (workshop?.id.isNullOrEmpty == false) {
                                      Get.toNamed(
                                        Routes.mechanicWorkshopReviews,
                                        arguments: WorkshopArgs(workshop!.id!),
                                      );
                                    }
                                  },
                                );
                              }
                            },
                          );
                        },
                        buttonHeight: 46,
                        borderRadius: 4.0,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        );
      }),
    );
  }
}
