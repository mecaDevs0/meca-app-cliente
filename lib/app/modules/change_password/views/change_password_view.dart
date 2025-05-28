import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';

class ChangePasswordView extends GetView<ChangePasswordController> {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Alterar senha',
        titleColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
        iconColor: AppColors.whiteColor,
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                const SizedBox(
                  height: 32,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Senha atual',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.currentPassword,
                      hintText: 'Digite sua senha atual',
                      isRequired: true,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: const Icon(FontAwesomeIcons.eye),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova senha',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.newPassword,
                      hintText: 'Digite sua nova senha',
                      isRequired: true,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: const Icon(FontAwesomeIcons.eye),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirmar nova senha',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.confirmPassword,
                      hintText: 'Confirmar sua nova senha',
                      isRequired: true,
                      keyboardType: TextInputType.visiblePassword,
                      suffixIcon: const Icon(FontAwesomeIcons.eye),
                      validator: Validatorless.multiple([
                        Validatorless.required('Confirmar Senha obrigatória'),
                        Validatorless.min(
                          6,
                          'Confirmar Senha precisa ter pelo menos 6 caracteres',
                        ),
                        Validators.compare(
                          controller.newPassword,
                          'Senha diferente de Nova Senha',
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Obx(
                  () => MegaBaseButton(
                    'Salvar alterações',
                    textColor: AppColors.whiteColor,
                    onButtonPress: () async {
                      await controller.onSubmit();
                    },
                    isLoading: controller.isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
