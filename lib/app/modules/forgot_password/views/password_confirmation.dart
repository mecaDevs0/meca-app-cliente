import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/shared/widgets/mega_base_button.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../routes/app_pages.dart';

class PasswordConfirmationView extends GetView<ForgotPasswordController> {
  const PasswordConfirmationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const Spacer(flex: 2),
            SvgPicture.asset(
              AppImages.emailConfirmation,
            ),
            const SizedBox(height: 20),
            const Text(
              'Verifique sua caixa de entrada para o link de recuperação enviado pela equipe Meca.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.softBlackColor,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: MegaBaseButton(
          'Voltar ao login',
          buttonColor: AppColors.primaryColor,
          textColor: AppColors.whiteColor,
          onButtonPress: () async {
            Get.toNamed(Routes.login);
          },
        ),
      ),
    );
  }
}
