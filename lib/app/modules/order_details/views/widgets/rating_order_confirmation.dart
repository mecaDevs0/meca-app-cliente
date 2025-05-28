import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';

class RatingOrderConfirmationBottomSheet extends StatefulWidget {
  const RatingOrderConfirmationBottomSheet({
    super.key,
    required this.onTap,
  });
  final void Function() onTap;

  @override
  State<RatingOrderConfirmationBottomSheet> createState() =>
      _RatingOrderConfirmationBottomSheetState();
}

class _RatingOrderConfirmationBottomSheetState
    extends State<RatingOrderConfirmationBottomSheet> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openRatingScreen() {
    Get.back();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(AppImages.ratingOrder),
                const Text(
                  'Avaliação Enviada!',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Obrigado por compartilhar sua experiência. Sua opinião é importante para nós',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Ver detalhes',
                    onButtonPress: _openRatingScreen,
                    textColor: AppColors.whiteColor,
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showRatingOrderConfirmationBottomSheet({
  required BuildContext context,
  required void Function() onTap,
}) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (context) {
      return Wrap(
        children: [
          RatingOrderConfirmationBottomSheet(onTap: onTap),
        ],
      );
    },
  );
}
