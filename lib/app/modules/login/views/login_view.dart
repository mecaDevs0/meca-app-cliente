import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/modules/login/controllers/login_controller.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/app_urls.dart';
import '../../../routes/app_pages.dart';
import 'widgets/circle_button_widget.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {
                      controller.emailController.text =
                      'lucas.silva@megaleios.com';
                      controller.passwordController.text = '123456';
                    },
                    onDoubleTap: () {
                      MegaModal.callEnvironmentModal(
                        context,
                        devUrl: BaseUrls.baseUrlDev,
                        hmlUrl: BaseUrls.baseUrlHml,
                        prodUrl: BaseUrls.baseUrlProd,
                      );
                    },
                    child: SvgPicture.asset(
                      AppImages.loginLogo,
                      height: 66,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    key: controller.formKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'E-mail',
                                style: TextStyle(
                                  color: AppColors.blackPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              MegaTextFieldWidget(
                                controller.emailController,
                                hintText: 'Digite seu e-mail',
                                isRequired: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Senha',
                                style: TextStyle(
                                  color: AppColors.blackPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              MegaTextFieldWidget(
                                controller.passwordController,
                                hintText: 'Digite sua senha',
                                isRequired: true,
                                keyboardType: TextInputType.visiblePassword,
                                suffixIcon: const Icon(FontAwesomeIcons.eye),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Obx(
                                () => MegaBaseButton(
                              'Entrar',
                              buttonColor: AppColors.primaryColor,
                              textColor: AppColors.whiteColor,
                              onButtonPress: () {
                                controller.save();
                              },
                              buttonHeight: 46,
                              borderRadius: 4.0,
                              isLoading: controller.isLoading,
                            ),
                          ),


                          // NOVO BOTÃO "ENTRAR COMO VISITANTE" ADICIONADO AQUI

                          const SizedBox(height: 16),
                          MegaBaseButton(
                            'Entrar como Visitante',
                            buttonColor: Colors.transparent,
                            textColor: AppColors.primaryColor,
                            // borderColor: AppColors.primaryColor,
                            onButtonPress: () {
                              controller.enterAsGuest();
                            },
                            buttonHeight: 46,
                            borderRadius: 4.0,
                            isLoading: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Get.toNamed(Routes.forgotPassword);
                    },
                    child: Text(
                      'Esqueci minha senha',
                      style: context.textTheme.displayLarge!.copyWith(
                        color: AppColors.blackSecondaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.grayBorderColor,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Ou',
                          style: TextStyle(
                            color: AppColors.grayBorderColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.grayBorderColor,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleButton(iconPath: AppImages.facebookIcon),
                      const SizedBox(width: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: controller.loginWithGoogle,
                        child: const CircleButton(
                          iconPath: AppImages.googleIcon,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (Platform.isIOS)
                        InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: controller.loginWithApple,
                          child: const CircleButton(
                            iconPath: AppImages.appleIcon,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Não tem uma conta?',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Get.toNamed(Routes.register);
                        },
                        child: const Text(
                          'Cadastre-se',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const MegaVersionIndicator(),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: SvgPicture.asset(
                AppImages.bottomUnion,
                height: 66,
              ),
            ),
          ],
        ),
      ),
    );
  }
}