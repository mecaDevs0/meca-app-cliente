import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/core.dart';
import '../../../../core/widgets/app_dashed_border_painter.dart';
import '../../controllers/service_failed_controller.dart';

class UploadImage extends GetView<ServiceFailedController> {
  const UploadImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: [
          GestureDetector(
            onTap: () {
              MegaFilePicker.showModalChooser(
                context,
                onFilesSelected: controller.addImages,
                cameraColor: AppColors.primaryColor,
                galleryColor: AppColors.primaryColor,
              );
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: CustomPaint(
                painter: AppDashedBorderPainter(
                  color: AppColors.primaryColor,
                  borderRadius: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(AppImages.icCamera),
                      const SizedBox(width: 8),
                      const Text(
                        'Incluir fotos',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controller.selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imagens ${controller.selectedImages.length}/${controller.maxImages}',
                    style: const TextStyle(
                      color: AppColors.softBlackColor,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.selectedImages.length,
                    itemBuilder: (context, index) {
                      final file = controller.selectedImages[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: FileImage(file),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Text(
                                file.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => controller.removeImage(file),
                              child: SvgPicture.asset(
                                AppImages.icTrash,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
