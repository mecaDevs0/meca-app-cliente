import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/args/order_args.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/vehicle.dart';
import '../../../routes/app_pages.dart';
import '../controllers/order_details_controller.dart';
import 'widgets/car_desc.dart';
import 'widgets/description_tile.dart';
import 'widgets/mechanic_workshop_info.dart';
import 'widgets/services_images.dart';
import 'widgets/table_price.dart';

class BudgetDetailsView extends GetView<OrderDetailsController> {
  const BudgetDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Detalhes do orçamento',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MechanicWorkshopInfo(
                isShowWhatsApp: controller.orderDetails != null && controller.orderDetails!.status! >= 15,
              ),
              const SizedBox(height: 12),
              CarDesc(
                vehicle: controller.orderDetails?.vehicle ?? Vehicle.empty(),
              ),
              DescriptionTile(
                title: 'Data estimada para conclusão',
                description: controller.orderDetails?.date?.toddMMyyyy() ??
                    'Data não definida',
              ),
              DescriptionTile(
                title: 'Valor do diagnóstico',
                description:
                    controller.orderDetails?.diagnosticValue?.moneyFormat() ??
                        r'R$ 0,00',
              ),
              const SizedBox(height: 16),
              TablePrice(
                services: controller.orderDetails?.status == 8
                    ? controller.orderDetails?.budgetServices ?? []
                    : controller.mergedList,
                onServiceSelected: () {
                  controller.updateTotalValue();
                },
              ),
              const SizedBox(height: 16),
              AppServiceImages(
                images: controller.orderDetails?.budgetImages ?? [],
              ),
              const SizedBox(height: 32),
              Obx(() {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Valor total',
                      style: TextStyle(
                        color: AppColors.softBlackColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      controller.totalValue.moneyFormat(),
                      style: const TextStyle(
                        color: AppColors.softBlackColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
              if (controller.orderDetails?.status == 8) ...[
                Column(
                  children: [
                    const SizedBox(
                      height: 16,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: MegaBaseButton(
                        'Aprovar e realizar pagamento',
                        onButtonPress: () async {
                          if (controller.selectedServices.isEmpty) {
                            MegaSnackbar.showErroSnackBar(
                              'Nenhum serviço selecionado',
                            );
                            return;
                          }

                          final isSuccess = await controller.approveBudget(
                            controller.selectedServices,
                          );

                          final orderId = controller.orderDetails?.id;
                          if (isSuccess && !orderId.isNullOrEmpty) {
                            Get.toNamed(
                              Routes.payment,
                              arguments:
                                  OrderArgs(controller.orderDetails!.id!),
                            );
                          }
                        },
                        textColor: AppColors.whiteColor,
                        buttonColor: AppColors.primaryColor,
                        isLoading: controller.isLoadingApproveBudget,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: MegaBaseButton(
                        'Reprovar orçamento',
                        onButtonPress: () async {
                          final hasResult = await controller.reproveBudget(
                            controller.orderDetails?.budgetServices ?? [],
                          );
                          if (hasResult) {
                            await controller.getOrderDetails();
                            Get.back();

                            MegaSnackbar.showSuccessSnackBar(
                              'Orçamento reprovado com sucesso',
                            );
                          }
                        },
                        textColor: AppColors.whiteColor,
                        buttonColor: AppColors.redAlertColor,
                        isLoading: controller.isLoadingReproveBudget,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
