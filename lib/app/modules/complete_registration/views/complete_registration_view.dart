import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mega_commons/shared/widgets/mega_base_button.dart';
import 'package:mega_commons/shared/widgets/mega_text_field_widget.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../routes/app_pages.dart';
import '../controllers/complete_registration_controller.dart';
import 'widgets/address_form.dart';

class CompleteRegistrationView extends GetView<CompleteRegistrationController> {
  CompleteRegistrationView({super.key});

  final completeRegistrationFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Completar cadastro',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 32,
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete seu cadastro!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.softBlackColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Complete suas informações e esteja pronto para agendar o que seu carro precisa.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.blackPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nome completo',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        controller.nameController,
                        hintText: 'Digite seu nome completo',
                        isRequired: true,
                        keyboardType: TextInputType.name,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CPF',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        controller.cpfController,
                        hintText: 'Digite seu CPF',
                        keyboardType: TextInputType.number,
                        validator: Validatorless.multiple(
                          [
                            Validatorless.required('CNPJ é obrigatório'),
                            Validatorless.cnpj('CNPJ inválido'),
                          ],
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CpfInputFormatter(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'E-mail',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
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
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Número de telefone',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
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
                  AddressForm(formKey: completeRegistrationFormKey),
                  const SizedBox(
                    height: 32,
                  ),
                  MegaBaseButton(
                    'Completar e finalizar agendamento',
                    buttonColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    onButtonPress: () async {
                      if (completeRegistrationFormKey.currentState
                              ?.validate() ==
                          false) {
                        return;
                      }
                      final hasResult = await controller.completeRegistration();
                      if (hasResult) {
                        Get.toNamed(
                          Routes.requestAppointment,
                          arguments: WorkshopArgs(
                            controller.workshopId,
                            workshopName: controller.workshopName,
                          ),
                        );
                      }
                    },
                    buttonHeight: 46,
                    borderRadius: 4.0,
                    isLoading: controller.isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
