import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../core.dart';

class AppBottomSheet {
  AppBottomSheet._();

  static void showLocationBottomSheet(
    BuildContext context, {
    required void Function() onRequestPermission,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppImages.homeLocation,
                  height: 140,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bem-vindo ao Meca!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.abbey,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vamos ativar sua localização para ver as melhores'
                  ' oficinas ao seu redor?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.abbey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                MegaBaseButton(
                  'Continuar',
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  onButtonPress: () {
                    Get.back();
                    onRequestPermission();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
