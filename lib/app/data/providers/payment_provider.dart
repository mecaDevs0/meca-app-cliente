import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/order.dart';

class PaymentProvider {
  PaymentProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Order> onRequestOrderDetails({required String id}) async {
    final response = await _restClientDio.get('${BaseUrls.scheduling}/$id');
    return Order.fromJson(response.data);
  }

  Future<void> finishPayment({required String schedulingId}) async {
    await _restClientDio.post(
      BaseUrls.finishPayment,
      data: {
        'schedulingId': schedulingId,
        'creditCardId': 'string',
        'paymentMethod': 0,
        'installments': 0,
      },
    );
  }

  Future<void> sendPaymentIntent({
    required String schedulingId,
    required String paymentIntent,
  }) async {
    await _restClientDio.post(
      BaseUrls.sendPaymentIntent,
      data: {
        'schedulingId': schedulingId,
        'invoiceId': paymentIntent,
      },
    );
  }
}
