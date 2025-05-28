import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../routes/app_pages.dart';

class ForgotPasswordView extends GetView<ForgotPasswordController> {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Voltar',
      ),
      body: Form(
        key: controller.formKey,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Não lembra da senha?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.softBlackColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Digite seu e-mail no campo abaixo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackPrimaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'E-mail',
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              MegaTextFieldWidget(
                controller.emailController,
                hintText: 'Digite seu e-mail',
                isRequired: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              Obx(
                () => MegaBaseButton(
                  'Recuperar senha',
                  textColor: AppColors.whiteColor,
                  onButtonPress: () async {
                    final hasResult = await controller.onSubmit(
                      isBackScreen: false,
                    );
                    if (hasResult) {
                      Get.toNamed(
                        Routes.forgotPasswordConfirmation,
                      );
                    }
                  },
                  isLoading: controller.isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
