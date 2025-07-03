import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/shared/widgets/mega_cached_network_image.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/models/service.dart';

class ServiceItem extends StatelessWidget {
  const ServiceItem({
    super.key,
    required this.service,
    required this.onTap,
  });

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Detecta se estamos em um tablet baseado no tamanho da tela
    final isTablet = MediaQuery.of(context).size.width > 600;

    // Ajustes de tamanho responsivos para tablets
    final itemHeight = isTablet ?
        MediaQuery.of(context).size.height * 0.22 :
        MediaQuery.of(context).size.height * 0.20;

    final imageHeight = isTablet ? 120.0 : 92.0;
    final titleFontSize = isTablet ? 16.0 : 14.0;
    final descFontSize = isTablet ? 14.0 : 12.0;
    final detailsFontSize = isTablet ? 14.0 : 12.0;
    final borderRadius = isTablet ? 10.0 : 8.0;
    final padding = isTablet ?
        const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0) :
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isTablet ? 14 : 10, horizontal: 2),
        height: itemHeight,
        padding: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.grayBorderColor, width: 1.0),
          // Sombra sutil para melhor visualização em iPads
          boxShadow: isTablet ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(borderRadius - 1),
                  topRight: Radius.circular(borderRadius - 1),
                ),
                child: service.photo != null && service.photo!.isNotEmpty
                    ? MegaCachedNetworkImage(
                        imageUrl: service.photo,
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: double.infinity,
                        height: imageHeight,
                        color: AppColors.grayBorderColor,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service.name ?? 'Serviço',
                              style: TextStyle(
                                color: AppColors.fontBoldBlackColor,
                                fontWeight: FontWeight.w500,
                                fontSize: titleFontSize,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 1,
                      child: Text(
                        service.description ?? 'Sem descrição disponível',
                        style: TextStyle(
                          color: AppColors.fontRegularBlackColor,
                          fontSize: descFontSize,
                          fontWeight: FontWeight.w300,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: GestureDetector(
                          onTap: onTap, // Usa o mesmo callback do card inteiro
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Ver detalhes',
                                style: TextStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: detailsFontSize,
                                  fontWeight: isTablet ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              SvgPicture.asset(
                                AppImages.icArrowUp,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.primaryColor,
                                  BlendMode.srcIn,
                                ),
                                width: isTablet ? 18 : 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
