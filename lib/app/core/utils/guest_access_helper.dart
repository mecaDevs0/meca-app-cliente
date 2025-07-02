import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../app_colors.dart';
import 'auth_helper.dart';

class GuestAccessHelper {
  static bool checkGuestAccess(BuildContext? context) {
    if (AuthHelper.isGuest) {
      if (context != null) {
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
      } else {
        Get.offAllNamed(Routes.login);
      }
      return false;
    }
    return true;
  }
}