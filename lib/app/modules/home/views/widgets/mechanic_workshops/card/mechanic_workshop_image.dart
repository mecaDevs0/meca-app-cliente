import 'package:flutter/material.dart';

import '../../../../../../core/utils/image_url_helper.dart';

class MechanicWorkshopImage extends StatelessWidget {
  const MechanicWorkshopImage({
    super.key,
    required this.imageAsset,
  });

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    // Processar a URL da imagem
    final imageUrl = ImageUrlHelper.buildImageUrlWithValidation(imageAsset, context: 'MechanicWorkshopImage');

    return imageUrl != null
        ? Image.network(
            imageUrl,
            width: 52,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.business,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              );
            },
          )
        : Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.business,
                color: Colors.grey,
                size: 24,
              ),
            ),
          );
  }
}
