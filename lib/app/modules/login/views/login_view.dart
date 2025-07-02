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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    // Parte principal do conteúdo
                    Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? constraints.maxWidth * 0.1 : 16, // Reduzido para melhor aproveitamento do espaço
                        vertical: isTablet ? 24 : 8, // Mais espaço vertical em tablets
                      ),
                      child: isTablet ? _buildTabletLayout(context) : _buildMobileLayout(context),
                    ),

                    // Rodapé no final da tela
                    SizedBox(
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Elemento gráfico de fundo
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: SvgPicture.asset(
                              AppImages.bottomUnion,
                              height: isTablet ? 100 : 66,
                            ),
                          ),

                          // Link "Cadastre-se"
                          Padding(
                            padding: EdgeInsets.only(bottom: isTablet ? 40 : 25),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildSignUpLink(),
                            ),
                          ),

                          // Indicador de versão
                          const Positioned(
                            bottom: 5,
                            child: MegaVersionIndicator(),
                          ),
                        ],
                      ),
                    ),
                    // Espaço adicional no final para garantir que os elementos não fiquem cortados
                    SizedBox(height: isTablet ? 60 : 40),
                  ],
                ),
              ),
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
          const SizedBox(height: 32),
          _buildSignUpLink(), // Adicionando o link de cadastro também no layout mobile
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    // Captura o tamanho da tela para cálculos de responsividade
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isLandscape ? 16.0 : 32.0,
        horizontal: 16.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lado esquerdo - Logo e informações
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: isLandscape ? 16.0 : 32.0),
                _buildLogo(),
                const SizedBox(height: 32),
                Text(
                  'Bem-vindo ao MECA',
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isLandscape ? 24.0 : 28.0, // Ajuste de tamanho para landscape
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Encontre as melhores oficinas próximas a você',
                  style: TextStyle(
                    color: AppColors.blackSecondaryColor,
                    fontSize: isLandscape ? 14.0 : 16.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Imagem ilustrativa apenas no modo landscape
                if (isLandscape)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: SvgPicture.asset(
                      AppImages.bottomUnion, // Considere usar uma imagem mais adequada
                      height: 120,
                    ),
                  ),
              ],
            ),
          ),

          // Separador vertical entre as seções
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            width: 1,
            height: isLandscape ? 400 : 500,
            color: AppColors.grayBorderColor.withOpacity(0.5),
          ),

          // Lado direito - Formulário de login
          Expanded(
            flex: isLandscape ? 1 : 1,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isLandscape ? 400 : 450,
                minHeight: 500,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isLandscape ? 16.0 : 24.0),
                    Center(
                      child: Text(
                        'Acesse sua conta',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLoginForm(),
                    const SizedBox(height: 16),
                    Center(child: _buildForgotPasswordLink(context)),
                    const SizedBox(height: 32),
                    _buildDivider(),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'Ou continue com',
                        style: TextStyle(
                          color: AppColors.blackSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSocialButtons(),
                    const SizedBox(height: 24),
                    _buildSignUpLink(), // Adicionando o link de cadastro também no layout tablet
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
              key: const Key('guest_login_button'),
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

  Widget _buildFooter(bool isTablet) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Elemento gráfico de fundo (primeiro elemento da Stack, fica atrás)
        Positioned(
          bottom: 0,
          right: 0,
          child: SvgPicture.asset(
            AppImages.bottomUnion,
            height: isTablet ? 100 : 66,
          ),
        ),

        // Container com o link "Cadastre-se" (segundo elemento da Stack, fica na frente)
        Padding(
          padding: EdgeInsets.only(bottom: isTablet ? 40 : 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildSignUpLink(),
          ),
        ),

        // Indicador de versão posicionado mais abaixo, após o link de cadastro
        const Positioned(
          bottom: 5, // Mais próximo à borda inferior
          child: MegaVersionIndicator(),
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
        const SizedBox(width: 6),
        InkWell(
          onTap: () {
            Get.toNamed(Routes.register);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryColor.withOpacity(0.3),
                width: 1,
              ),
              color: AppColors.primaryColor.withOpacity(0.1),
            ),
            child: const Text(
              'Cadastre-se',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
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
