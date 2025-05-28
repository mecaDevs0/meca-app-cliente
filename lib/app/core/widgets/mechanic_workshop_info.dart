import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../app_colors.dart';
import '../app_images.dart';
import '../extensions/string_extension.dart';

class MechanicWorkshopInfo extends StatelessWidget {
  const MechanicWorkshopInfo({
    super.key,
    this.isShowWhatsApp = true,
    this.imageUrl,
    this.phone,
    this.workshopName,
    this.streetName,
    this.number,
    this.neighborhood,
  });

  final bool isShowWhatsApp;
  final String? imageUrl;
  final String? phone;
  final String? workshopName;
  final String? streetName;
  final String? number;
  final String? neighborhood;

  Future<void> openWhatsApp(String phone) async {
    final url = 'https://wa.me/$phone';

    if (!await launchUrl(Uri.parse(url))) {
      MegaSnackbar.showErroSnackBar(
        'Não foi possível abrir o WhatsApp',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MegaCachedNetworkImage(
          radius: 100,
          width: 60,
          height: 60,
          borderWidth: 1.0,
          borderColor: AppColors.grayBorderColor,
          imageUrl: imageUrl,
        ),
        const SizedBox(
          height: 12,
        ),
        Text(
          workshopName ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.softBlackColor,
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        Row(
          spacing: 8,
          children: [
            SvgPicture.asset(
              AppImages.icLocation,
            ),
            Flexible(
              child: Text(
                '$streetName, n$number, $neighborhood',
                style: const TextStyle(
                  color: AppColors.fontMediumGray,
                  fontSize: 14,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
        Visibility(
          visible: isShowWhatsApp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => openWhatsApp(number.formattedPhone),
                child: Row(
                  spacing: 8,
                  children: [
                    SvgPicture.asset(
                      AppImages.icWhatsapp,
                      colorFilter: const ColorFilter.mode(
                        AppColors.softBlackColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    Text(
                      phone?.formattedPhone ?? '',
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }
}
