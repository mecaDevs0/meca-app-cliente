import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/profile.dart';
import '../../../routes/app_pages.dart';
import '../controllers/register_controller.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterView();
}

class _RegisterView extends MegaState<RegisterView, RegisterController> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Voltar',
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 32,
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastre-se',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.softBlackColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'e vamos encontrar a oficina ideal para seu carro!',
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
                          nameController,
                          hintText: 'Digite seu nome completo',
                          isRequired: true,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          validator: Validatorless.required(
                            'Informe seu nome completo.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          emailController,
                          hintText: 'Digite seu e-mail',
                          isRequired: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validatorless.multiple([
                            Validatorless.required('O e-mail é obrigatório'),
                            Validatorless.email('E-mail inválido'),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          phoneController,
                          hintText: 'Digite o número do seu telefone',
                          isRequired: true,
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
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Senha',
                          style: TextStyle(color: AppColors.blackPrimaryColor),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        MegaTextFieldWidget(
                          passwordController,
                          hintText: 'Digite sua senha',
                          isRequired: true,
                          keyboardType: TextInputType.visiblePassword,
                          validator: Validatorless.multiple(
                            [
                              Validatorless.required('Senha obrigatória'),
                              Validatorless.min(
                                6,
                                'Senha deve ter pelo menos 6 caracteres',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirmar senha',
                          style: TextStyle(color: AppColors.blackPrimaryColor),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        MegaTextFieldWidget(
                          confirmPasswordController,
                          hintText: 'Digite a confirmação da senha',
                          isRequired: true,
                          keyboardType: TextInputType.visiblePassword,
                          validator: Validatorless.multiple([
                            Validatorless.required(
                              'Confirmar Senha obrigatória',
                            ),
                            Validatorless.min(
                              6,
                              'Confirmar Senha deve ter pelo menos 6 caracteres',
                            ),
                            Validators.compare(
                              passwordController,
                              'As senhas não coincidem!',
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => MegaPolicyTerm(
                        color: AppColors.primaryColor,
                        unselectedColor: AppColors.blackPrimaryColor,
                        onChanged: (value) =>
                            controller.setHasAcceptTerms(value),
                        isSelected: controller.hasAcceptTerms,
                        policyTermsFileUrl:
                            'https://api.megaleios.com/content/TermosMeca.html',
                      ),
                    ),
                    const SizedBox(height: 32),
                    MegaBaseButton(
                      'Cadastrar',
                      buttonColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        if (passwordController.text !=
                            confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('As senhas não coincidem!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!controller.hasAcceptTerms) {
                          Get.snackbar(
                            '',
                            titleText: const SizedBox.shrink(),
                            'É necessário aceitar os termos de uso para prosseguir com o cadastro',
                            backgroundColor:
                                AppColors.redAlertColor.withValues(alpha: 0.8),
                            colorText: Colors.white,
                          );

                          return;
                        }

                        final newUser = Profile(
                          fullName: nameController.text,
                          email: emailController.text,
                          typeProvider: 0,
                          phone: phoneController.text,
                          password: passwordController.text,
                        );

                        final result =
                            await controller.createUserProfile(newUser);

                        if (result) {
                          Get.offAllNamed(Routes.home);
                          MegaSnackbar.showSuccessSnackBar(
                            'Usuário cadastrado com sucesso!',
                          );
                        }
                      },
                      buttonHeight: 46,
                      borderRadius: 4.0,
                      isLoading: controller.loadingUser,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
