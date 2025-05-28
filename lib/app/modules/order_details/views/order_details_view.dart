import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../core/widgets/mechanic_workshop_info.dart';
import '../../../routes/app_pages.dart';
import '../controllers/order_details_controller.dart';
import 'widgets/free_repair_bottomsheet.dart';
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
                      imageUrl: controller.orderDetails?.workshop?.photo,
                      phone: controller.orderDetails?.workshop?.phone,
                      workshopName:
                          controller.orderDetails?.workshop?.companyName,
                      streetName:
                          controller.orderDetails?.workshop?.streetAddress,
                      number: controller.orderDetails?.workshop?.number,
                      neighborhood:
                          controller.orderDetails?.workshop?.neighborhood,
                      isShowWhatsApp: controller.orderDetails != null &&
                          controller.orderDetails!.status! >= 15,
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
            if (controller.orderDetails?.status == 26 &&
                controller.orderDetails?.hasEvaluated == false) ...[
              Container(
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
              ),
            ],
            if ((controller.orderDetails!.status! >= 7) &&
                (controller.orderDetails!.status! <= 11)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MegaBaseButton(
                  'ver orçamento',
                  buttonColor: AppColors.primaryColor,
                  textColor: AppColors.whiteColor,
                  onButtonPress: () {
                    Get.toNamed(Routes.budgetDetails);
                  },
                  buttonHeight: 46,
                  borderRadius: 4.0,
                ),
              ),
            ],
            if (controller.orderDetails?.status == 1) ...[
              Container(
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
                      'Aprovar horário sugerido',
                      buttonColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        final hasResult = await controller.approveNewSchedule();
                        if (hasResult) {
                          await controller.getOrderDetails();

                          MegaSnackbar.showSuccessSnackBar(
                            'O horário sugerido foi aprovado',
                          );
                        }
                      },
                      isLoading: controller.isLoadingApproveNewSchedule,
                      buttonHeight: 46,
                      borderRadius: 4.0,
                    ),
                    const SizedBox(height: 16),
                    MegaBaseButton(
                      'Reprovar horário sugerido',
                      buttonColor: AppColors.redAlertColor,
                      textColor: AppColors.whiteColor,
                      borderRadius: 4,
                      onButtonPress: () async {
                        final hasResult = await controller.reproveNewSchedule();
                        if (hasResult) {
                          await controller.getOrderDetails();

                          MegaSnackbar.showErroSnackBar(
                            'O horário sugerido foi reprovado',
                          );
                        }
                      },
                      isLoading: controller.isLoadingReproveNewSchedule,
                    ),
                  ],
                ),
              ),
            ],
            if ((controller.orderDetails!.status! >= 0) &&
                (controller.orderDetails!.status! < 2) &&
                (controller.orderDetails?.freeRepair == false)) ...[
              Container(
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
                      'Cancelar pedido',
                      buttonColor: AppColors.redAlertColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        final hasResult = await controller.cancelOrder();
                        if (hasResult) {
                          Get.back();

                          MegaSnackbar.showErroSnackBar(
                            'O agendamento foi cancelado',
                          );

                          controller.ordersPlacedController.pagingController
                              .refresh();
                        }
                      },
                      buttonHeight: 46,
                      borderRadius: 4.0,
                      isLoading: controller.isLoadingCancelOrder,
                    ),
                  ],
                ),
              ),
            ] else if (controller.orderDetails?.status == 19) ...[
              Container(
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
                      'Aprovar',
                      buttonColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        await controller.approveOrder();
                        controller.ordersPlacedController.pagingController
                            .refresh();
                        Get.back();
                      },
                      buttonHeight: 46,
                      borderRadius: 4.0,
                    ),
                    const SizedBox(height: 16),
                    MegaBaseButton(
                      'Reprovar',
                      buttonColor: AppColors.redAlertColor,
                      textColor: AppColors.whiteColor,
                      borderRadius: 4,
                      onButtonPress: () {
                        Get.toNamed(
                          Routes.serviceFailed,
                          arguments: OrderArgs(controller.orderId),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (controller.orderDetails?.freeRepair == true &&
                controller.orderDetails?.status == 0) ...[
              Container(
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
                      'Realizar agendamento',
                      buttonColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        showFreeRepairBottomSheet(
                          context: context,
                          onTap: (int dateTime) async {
                            final hasResult =
                                await controller.scheduleFreeRepair(dateTime);
                            if (hasResult) {
                              MegaSnackbar.showSuccessSnackBar(
                                'Agendamento de reparo gratuito realizado com sucesso',
                              );
                              controller.getOrderDetails();
                              Get.back();
                            }
                          },
                        );
                      },
                      buttonHeight: 46,
                      borderRadius: 4.0,
                      isLoading: controller.isLoadingCancelOrder,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
