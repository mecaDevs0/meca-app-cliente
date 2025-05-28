import 'package:flutter/material.dart';
import 'package:mega_payment/mega_payment.dart';

import '../core/core.dart';

class MegaPaymentTheme extends PaymentTheme {
  MegaPaymentTheme()
      : super(
          brightness: Brightness.light,
          checkoutButtonColor: AppColors.primaryColor,
          payButtonColor: AppColors.primaryColor,
          payButtonTextColor: Colors.white,
          textButtonColor: Colors.white,
          success: AppColors.shamrock,
          error: AppColors.redAlertColor,
        );
}
