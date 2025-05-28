import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/mega_photo_container/mega_photo_container.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../controllers/user_profile_controller.dart';

class AvatarSection extends GetView<UserProfileController> {
  const AvatarSection({super.key, required this.profilePhoto});

  final String profilePhoto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MegaPhotoContainer(
          profilePhoto: controller.profile.photo,
          photo: controller.filePhoto,
          onPhotoChanged: controller.changePhoto,
          outlineColor: AppColors.grayBorderColor,
          buttonColor: AppColors.primaryColor,
          typeModal: TypeModal.dialog,
        ),
      ],
    );
  }
}
