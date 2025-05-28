import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/mega_base_button.dart';
import 'package:mega_commons/shared/widgets/mega_text_field_widget.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../core/widgets/app_filter_bottom_sheet.dart';
import '../controllers/help_center_controller.dart';

class HelpCenterView extends GetView<HelpCenterController> {
  HelpCenterView({super.key});

  final TextEditingController titleController = TextEditingController();

  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Central de ajuda',
        titleColor: AppColors.whiteColor,
        backgroundColor: AppColors.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Título',
                        style: TextStyle(
                          color: AppColors.blackPrimaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        titleController,
                        hintText: 'Digite o título',
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
                        'Descrição',
                        style: TextStyle(
                          color: AppColors.blackPrimaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        descriptionController,
                        hintText: 'Digite a descrição',
                        isRequired: true,
                        maxLines: 10,
                        minLines: 5,
                        keyboardType: TextInputType.name,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => MegaBaseButton(
                      'Enviar dúvida',
                      buttonColor: AppColors.primaryColor,
                      textColor: AppColors.whiteColor,
                      onButtonPress: () async {
                        final isSuccess = await controller.submitFaq(
                          description: descriptionController.text,
                          title: titleController.text,
                        );

                        if (isSuccess && context.mounted) {
                          showInfoBottomSheet(
                            context: context,
                            imageAsset: AppImages.mecaCar,
                            buttonText: 'Ver detalhes',
                            title: 'Dúvida enviada!',
                            subtitle:
                                'em breve a equipe da Meca fará uma analise e entrará em contato o mais breve possível.',
                            onTap: () {},
                          );
                        }
                      },
                      buttonHeight: 46,
                      borderRadius: 4.0,
                      isLoading: controller.isLoading,
                    ),
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
