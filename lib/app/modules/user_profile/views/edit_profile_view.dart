import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/modules/form_address/views/form_address_view.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../controllers/user_profile_controller.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState
    extends MegaState<EditProfileView, UserProfileController> {
  final editProfileFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Editar perfil',
        titleColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
        iconColor: AppColors.whiteColor,
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          child: Form(
            key: editProfileFormKey,
            child: Column(
              children: [
                const SizedBox(
                  height: 32,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nome completo',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.nameController,
                      hintText: 'Digite seu nome completo',
                      isRequired: true,
                      keyboardType: TextInputType.name,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-mail',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.emailController,
                      hintText: 'Digite seu e-mail',
                      keyboardType: TextInputType.emailAddress,
                      validator: Validatorless.multiple([
                        Validatorless.required('O e-mail é obrigatório'),
                        Validatorless.email('E-mail inválido'),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Número de telefone',
                      style: TextStyle(
                        color: AppColors.blackPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MegaTextFieldWidget(
                      controller.phoneController,
                      hintText: 'Digite o número do seu telefone',
                      keyboardType: TextInputType.phone,
                      validator: Validatorless.multiple([
                        Validatorless.required('O telefone é obrigatório'),
                        Validatorless.phone('Telefone inválido'),
                      ]),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TelefoneInputFormatter(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(
                  height: 32,
                ),
                const FormAddressView(
                  isWithTitle: true,
                  isAddressRequired: true,
                ),
                const SizedBox(
                  height: 32,
                ),
                MegaBaseButton(
                  'Salvar alterações',
                  textColor: AppColors.whiteColor,
                  onButtonPress: () async {
                    if (editProfileFormKey.currentState?.validate() == false) {
                      return;
                    }
                    final hasResult = await controller.onEditProfile();
                    if (hasResult) {
                      Get.back();
                      MegaSnackbar.showSuccessSnackBar(
                        'Seus dados foram alterados com sucesso!',
                      );
                    }
                  },
                  isLoading: controller.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
