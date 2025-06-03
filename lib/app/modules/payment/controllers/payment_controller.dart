import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../core/utils/auth_helper.dart';
import 'package:get/get.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../core/app_colors.dart';
import '../../../routes/app_pages.dart';
import 'package:flutter/material.dart';
class PaymentController extends GetxController with ProfileMixin {

  PaymentController({required PaymentProvider paymentProvider})
      : _paymentProvider = paymentProvider;

  final PaymentProvider _paymentProvider;

  final _isLoadingDetails = RxBool(false);
  final _isLoadingConfirmPayment = RxBool(false);

  final _orderDetails = Rx<Order>(Order.empty());

  var isCreditCardExpanded = RxBool(false);

  void toggleCreditCard() {
    isCreditCardExpanded.value = !isCreditCardExpanded.value;
  }

  Order? get orderDetails => _orderDetails.value;

  bool get isLoadingDetails => _isLoadingDetails.value;
  bool get isLoadingConfirmPayment => _isLoadingConfirmPayment.value;

  late String orderId;

  @override
  void onInit() {
    final order = Get.arguments as OrderArgs;
    orderId = order.id;
    getOrderDetails();

    super.onInit();
  }

  Future<void> getOrderDetails() async {
    if (AuthHelper.isGuest) {
      Get.defaultDialog(
        title: 'Acesso restrito',
        middleText: 'Para acessar esta funcionalidade, você precisa fazer login.',
        textConfirm: 'Fazer login',
        confirmTextColor: Colors.white,
        buttonColor: AppColors.primaryColor,
        onConfirm: () {
          Get.back();
          Get.offAllNamed(Routes.login);
        },
        textCancel: 'Cancelar',
        cancelTextColor: AppColors.primaryColor,
      );
      return;
    }
    _isLoadingDetails.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final orderDetails =
            await _paymentProvider.onRequestOrderDetails(id: orderId);

        _orderDetails.value = orderDetails;
      },
      onFinally: () => _isLoadingDetails.value = false,
    );
  }

  Future<bool> finishPayment() async {
    bool isSuccess = false;
    _isLoadingConfirmPayment.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _paymentProvider.finishPayment(schedulingId: orderId);
        isSuccess = true;
      },
      onFinally: () => _isLoadingConfirmPayment.value = false,
    );

    return isSuccess;
  }

  Future<bool> sendPaymentIntent(String paymentIntent) async {
    bool isSuccess = false;
    _isLoadingConfirmPayment.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _paymentProvider.sendPaymentIntent(
          schedulingId: orderId,
          paymentIntent: paymentIntent,
        );
        isSuccess = true;
      },
      onFinally: () => _isLoadingConfirmPayment.value = false,
    );
    return isSuccess;
  }
}
