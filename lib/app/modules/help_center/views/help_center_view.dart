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
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.lightGrayColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                'A função de envio de perguntas diretas está temporariamente indisponível. Estamos trabalhando para reativá-la o mais breve possível. Agradecemos a sua compreensão.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
