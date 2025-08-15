import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../controllers/order_details_controller.dart';
import '../../../../core/utils/image_url_helper.dart';

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

  String _formatWorkshopAddress() {
    final workshop = controller.orderDetails?.workshop;
    if (workshop == null) return 'Endereço do estabelecimento';
    
    final parts = <String>[];
    if (workshop.streetAddress?.isNotEmpty == true) parts.add(workshop.streetAddress!);
    if (workshop.number?.isNotEmpty == true) parts.add('n${workshop.number}');
    if (workshop.neighborhood?.isNotEmpty == true) parts.add(workshop.neighborhood!);
    if (workshop.cityName?.isNotEmpty == true) parts.add(workshop.cityName!);
    if (workshop.stateUf?.isNotEmpty == true) parts.add(workshop.stateUf!);
    
    return parts.isEmpty ? 'Endereço do estabelecimento' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        controller.orderDetails?.workshop?.photo != null &&
                controller.orderDetails!.workshop!.photo!.isNotEmpty
            ? MegaCachedNetworkImage(
                radius: 100,
                width: 60,
                height: 60,
                borderWidth: 1.0,
                borderColor: AppColors.grayBorderColor,
                imageUrl: ImageUrlHelper.buildImageUrl(controller.orderDetails?.workshop?.photo),
              )
            : const Icon(
                Icons.broken_image,
                size: 60,
                color: AppColors.grayDarkColor,
              ),
        const SizedBox(
          height: 12,
        ),
        Text(
          controller.orderDetails?.workshop?.companyName ?? 
          controller.orderDetails?.workshop?.fullName ?? 
          'Nome do estabelecimento',
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
                _formatWorkshopAddress(),
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
