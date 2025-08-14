import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../../core/utils/image_url_helper.dart';

class MechanicWorkshopImage extends StatelessWidget {
  const MechanicWorkshopImage({
    super.key,
    required this.imageAsset,
  });

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    // Usar o método seguro que retorna null quando não há imagem válida
    final imageUrl = ImageUrlHelper.buildImageUrlSafe(imageAsset);
    
    if (imageUrl != null) {
      // Se há uma URL válida, usar a imagem
      return MegaCachedNetworkImage(
        imageUrl: imageUrl,
        width: 52,
        height: 56,
        radius: 64,
      );
    } else {
      // Se não há imagem válida, usar ícone local
      return Container(
        width: 52,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Icon(
          Icons.business,
          size: 32,
          color: Colors.grey,
        ),
      );
    }
  }
}
