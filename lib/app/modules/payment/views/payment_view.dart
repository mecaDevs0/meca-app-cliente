import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_payment/mega_payment.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/mega_payment_theme.dart';
import '../controllers/payment_controller.dart';

class PaymentView extends GetView<PaymentController> {
  const PaymentView({super.key});

  double get _getTotalValue {
    if (controller.orderDetails == null) {
      return 0.0;
    }
    return controller.orderDetails?.totalValue ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Pagamento',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Serviços',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Obx(
              () {
                if (controller.isLoadingDetails) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  );
                }

                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.08,
                  child: ListView.builder(
                    itemCount: controller
                        .orderDetails?.maintainedBudgetServices?.length,
                    physics: const ScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = controller
                          .orderDetails?.maintainedBudgetServices?[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item?.title ?? '',
                              style: const TextStyle(
                                color: AppColors.boldFontColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              item?.value?.moneyFormat() ??
                                  'Sem preço definido',
                              style: const TextStyle(
                                color: AppColors.fontDarkGrayColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(
              height: 16,
            ),
            Obx(
              () => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Valor do diagnóstico',
                      style: TextStyle(
                        color: AppColors.boldFontColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      controller.orderDetails?.diagnosticValue?.moneyFormat() ??
                          'Sem preço definido',
                      style: const TextStyle(
                        color: AppColors.fontDarkGrayColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Obx(
              () {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Valor Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getTotalValue.moneyFormat(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Obx(
              () => Center(
                child: MegaPaymentSheetWidget(
                  paymentTheme: MegaPaymentTheme(),
                  checkoutParams: CheckoutParams(
                    amount: _getTotalValue,
                    email: controller.email,
                    customerId: controller.customerId,
                    externalId: controller.orderId,
                    currencyCode: 'brl',
                    merchantCountryCode: 'BR',
                    description: 'Pagamento de serviços Meca',
                  ),
                  paymentIntentCallBack: (paymentIntent) async {
                    final isSuccess =
                        await controller.sendPaymentIntent(paymentIntent);
                    if (isSuccess) {
                      Get.until(
                        (route) => Get.currentRoute == Routes.ordersPlaced,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
