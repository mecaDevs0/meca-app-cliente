import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../order_details/controllers/order_details_controller.dart';
import '../controllers/service_failed_controller.dart';
import 'widgets/service_failed_confirmation.dart';
import 'widgets/upload_image.dart';

class ServiceFailedView extends StatefulWidget {
  const ServiceFailedView({super.key});

  @override
  State<ServiceFailedView> createState() => _ServiceFailedViewState();
}

class _ServiceFailedViewState
    extends MegaState<ServiceFailedView, ServiceFailedController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Reprovação do serviço',
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SvgPicture.asset(
                AppImages.serviceFailed,
              ),
              const SizedBox(height: 24),
              const Text(
                'Você está reprovando o serviço',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.softBlackColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Informe por gentileza os motivos de reprovação do serviço realizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.softBlackColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Motivos',
                  style: TextStyle(
                    color: AppColors.gray500,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                enabled: controller.orderDetails?.status == 19,
                maxLines: 4,
                controller: controller.reasonController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Descreva o motivo da reprovação',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(
                      color: AppColors.grayLineColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(
                      color: AppColors.grayLineColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(
                      color: AppColors.grayLineColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fotos',
                  style: TextStyle(
                    color: AppColors.gray500,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Visibility(
                visible: controller.orderDetails?.status == 19,
                child: const UploadImage(),
              ),
              Visibility(
                visible: controller.orderDetails?.status == 20,
                child: const Column(
                  children: [
                    SizedBox(
                      height: 12,
                    ),
                    Center(
                      child: Text(
                        'Sem fotos para exibir',
                        style: TextStyle(
                          color: AppColors.blackPrimaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.orderDetails?.status == 19) ...[
                Column(
                  children: [
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    MegaBaseButton(
                      'Confirmar reprovação',
                      buttonColor: AppColors.redAlertColor,
                      isLoading: controller.isLoading,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      borderRadius: 4,
                      onButtonPress: () async {
                        final hasResult = await controller
                            .reproverOrder(controller.reasonController.text);
                        if (hasResult && context.mounted) {
                          showServiceFailedConfirmationBottomSheet(
                            context: context,
                            onTap: () {
                              final OrderDetailsController
                                  orderDetailsController = Get.find();
                              orderDetailsController.getOrderDetails();
                              Get.back();
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
