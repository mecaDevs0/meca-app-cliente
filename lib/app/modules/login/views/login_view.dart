import 'dart:developer' as console;
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/modules/login/controllers/login_controller.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/app_urls.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../routes/app_pages.dart';
import 'widgets/circle_button_widget.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determina se é uma tela grande (tablet/iPad)
            final isTablet = constraints.maxWidth > 600;

            return Stack(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? constraints.maxWidth * 0.2 : 16,
                    vertical: 8,
                  ),
                  child: isTablet ? _buildTabletLayout(context) : _buildMobileLayout(context),
                ),
                // Elemento gráfico atrás do conteúdo
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: SvgPicture.asset(
                    AppImages.bottomUnion,
                    height: isTablet ? 100 : 66,
                  ),
                ),
                // Botão "Cadastre-se" na frente do elemento gráfico
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSignUpLink(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
          _buildLogo(),
          const SizedBox(height: 24),
          _buildLoginForm(),
          const SizedBox(height: 16),
          _buildForgotPasswordLink(context),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildSocialButtons(),
          const SizedBox(height: 100), // Espaço para o botão posicionado fixo
          const MegaVersionIndicator(),
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Lado esquerdo - Logo e informações
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 48),
              Text(
                'Bem-vindo ao MECA',
                style: context.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Encontre as melhores oficinas próximas a você',
                style: TextStyle(
                  color: AppColors.blackSecondaryColor,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        // Lado direito - Formulário de login
        Expanded(
          flex: 1,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLoginForm(),
                const SizedBox(height: 24),
                _buildForgotPasswordLink(context),
                const SizedBox(height: 32),
                _buildDivider(),
                const SizedBox(height: 32),
                _buildSocialButtons(),
                const SizedBox(height: 24),
                _buildSignUpLink(),
                const SizedBox(height: 16),
                const MegaVersionIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return InkWell(
      onTap: () {
        controller.emailController.text = 'lucas.silva@megaleios.com';
        controller.passwordController.text = '123456';
      },
      onDoubleTap: () {
        MegaModal.callEnvironmentModal(
          Get.context!,
          devUrl: BaseUrls.baseUrlDev,
          hmlUrl: BaseUrls.baseUrlHml,
          prodUrl: BaseUrls.baseUrlProd,
        );
      },
      child: SvgPicture.asset(
        AppImages.loginLogo,
        height: 66,
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: controller.formKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'E-mail',
                  style: TextStyle(color: AppColors.blackPrimaryColor),
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
                  style: TextStyle(color: AppColors.blackPrimaryColor),
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
            const SizedBox(height: 16),
            MegaBaseButton(
              'Entrar como Visitante',
              buttonColor: Colors.transparent,
              textColor: AppColors.primaryColor,
              onButtonPress: () {
                controller.enterAsGuest();
                console.log('Entrou como visitante', name: 'LoginView');
              },
              buttonHeight: 46,
              borderRadius: 4.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    return InkWell(
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
    );
  }

  Widget _buildDivider() {
    return const Row(
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
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleButton(iconPath: AppImages.facebookIcon),
        const SizedBox(width: 16),
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: controller.loginWithGoogle,
          child: const CircleButton(iconPath: AppImages.googleIcon),
        ),
        const SizedBox(width: 16),
        if (Platform.isIOS || Platform.isMacOS || kDebugMode)
          InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: controller.loginWithApple,
            child: const CircleButton(iconPath: AppImages.appleIcon),
          ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Row(
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
            print('Botão Cadastre-se clicado'); // Debug
            Get.toNamed(Routes.register);
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Text(
              'Cadastre-se',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension LoginControllerGuestExtension on LoginController {
Future<void> enterAsGuest() async {
  // Define o usuário como visitante
  await AuthHelper.setGuest();
  // Marca o usuário como não logado no cache, se necessário
  await isLogged.put('isLogged', false);
  // Redireciona para a home
  Get.offAllNamed(Routes.home);
}
}
