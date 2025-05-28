import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/shared/utils/mega_snackbar.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/extensions/string_extension.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../routes/app_pages.dart';
import '../controllers/user_profile_controller.dart';
import 'widgets/avatar_section.dart';
import 'widgets/profile_card_item.dart';

class UserProfileView extends GetView<UserProfileController> {
  UserProfileView({super.key});

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        title: 'Meu perfil',
        titleColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
        iconColor: AppColors.whiteColor,
      ),
      body: SafeArea(
        child: Container(
          color: AppColors.whiteColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Obx(
            () => SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      width: MediaQuery.of(context).size.width - 24,
                      color: AppColors.whiteColor,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AvatarSection(
                            profilePhoto: controller.profile.photo ?? '',
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Text(
                            controller.profile.fullName ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: AppColors.softBlackColor,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                AppImages.icEmail,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  controller.profile.email ?? '',
                                  style: const TextStyle(
                                    color: AppColors.weakGrayColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 24,
                              ),
                              SvgPicture.asset(
                                AppImages.icWhatsapp,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Flexible(
                                child: Text(
                                  controller.profile.phone?.formattedPhone ??
                                      '',
                                  style: const TextStyle(
                                    color: AppColors.weakGrayColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 32,
                          ),
                          Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Get.toNamed(Routes.editProfile);
                                },
                                child: const ProfileCardItem(
                                  iconPath: AppImages.icPencilEdit,
                                  title: 'Editar dados',
                                  subtitle:
                                      'Editar suas informações pessoais e de contato.',
                                ),
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              ProfileCardItem(
                                iconPath: AppImages.icLock,
                                title: 'Alterar senha',
                                subtitle:
                                    'Atualiza sua senha protegendo sua conta',
                                onTap: () {
                                  Get.toNamed(Routes.changePassword);
                                },
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              ProfileCardItem(
                                iconPath: AppImages.icExit,
                                title: 'Sair',
                                subtitle: 'Logout com segurança do aplicativo',
                                onTap: controller.logout,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 32,
                          ),
                          InkWell(
                            onTap: () async {
                              final hasResult =
                                  await controller.onRemoveAccount();
                              if (hasResult) {
                                Get.offAllNamed(Routes.login);
                                MegaSnackbar.showSuccessSnackBar(
                                  'Conta removida com sucesso.',
                                );
                              }
                            },
                            child: const Text(
                              'Deletar conta',
                              style: TextStyle(
                                color: AppColors.redAlertColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
