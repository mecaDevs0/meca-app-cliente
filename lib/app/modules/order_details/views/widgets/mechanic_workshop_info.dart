import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../controllers/order_details_controller.dart';

class MechanicWorkshopInfo extends GetView<OrderDetailsController> {
  const MechanicWorkshopInfo({
    super.key,
    this.isShowWhatsApp = false,
  });

  final bool isShowWhatsApp;

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
          imageUrl: controller.orderDetails?.workshop?.photo,
        ),
        const SizedBox(
          height: 12,
        ),
        Text(
          controller.orderDetails?.workshop?.companyName ?? 'Nome da oficina',
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
            Expanded(
              child: Text(
                controller.orderDetails?.formattedAddress ??
                    'Endereço da oficina',
                style: const TextStyle(
                  color: AppColors.fontMediumGray,
                  fontSize: 14,
                ),
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
                onTap: () => openWhatsApp(
                  controller.orderDetails?.workshop?.phone ?? '',
                ),
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
                      controller.orderDetails?.workshop?.phone ?? '',
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
