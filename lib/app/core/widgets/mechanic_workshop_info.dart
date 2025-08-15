import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../app_images.dart';
import '../utils/image_url_helper.dart';
import 'force_download_image.dart';

class MechanicWorkshopInfo extends StatelessWidget {
  const MechanicWorkshopInfo({
    super.key,
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    this.imageUrl,
    this.onTap,
  });

  final String name;
  final String address;
  final String distance;
  final double rating;
  final String? imageUrl;
  final VoidCallback? onTap;

  Future<void> openWhatsApp(String phone) async {
    final url = 'https://wa.me/$phone';

    if (!await launchUrl(Uri.parse(url))) {
      // Mostrar erro usando ScaffoldMessenger
      debugPrint('Não foi possível abrir o WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grayBorderColor),
          ),
          child: Row(
            children: [
              // Imagem da oficina
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl!.isNotEmpty
                                         ? ForceDownloadImage(
                         imageUrl: ImageUrlHelper.buildImageUrlWithValidation(imageUrl, context: 'MechanicWorkshopInfo') ?? '',
                         width: 60,
                         height: 60,
                       )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Informações da oficina
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating.floor() ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Seta indicativa
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.primaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
