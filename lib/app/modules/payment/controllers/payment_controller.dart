import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/payment_provider.dart';

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
