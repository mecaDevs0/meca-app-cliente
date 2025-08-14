import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/utils/image_url_helper.dart';
import '../../../../../data/models/service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    // Usar o método seguro que retorna null quando não há imagem válida
    final imageUrl = ImageUrlHelper.buildImageUrlSafe(service.photo);
    
    // Debug: Log da URL da imagem
    print('🔍 ServiceCard Debug:');
    print('  Service: ${service.name}');
    print('  Photo: ${service.photo}');
    print('  Safe URL: $imageUrl');
    
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      width: MediaQuery.of(context).size.width * 0.33,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem ou ícone de fallback
            imageUrl != null
                ? MegaCachedNetworkImage(
                    imageUrl: imageUrl,
                    height: double.infinity,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppColors.grayDarkColor,
                    child: const Icon(
                      Icons.build,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Text(
                  service.name ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.whiteColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Fonte reduzida para 12
                    shadows: [
                      Shadow(
                        blurRadius: 2.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
