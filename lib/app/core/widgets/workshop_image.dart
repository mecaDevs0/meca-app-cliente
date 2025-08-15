import 'package:flutter/material.dart';

import '../utils/image_url_helper.dart';
import 'robust_image.dart';

/// Widget específico para imagens de oficinas com fallback inteligente
class WorkshopImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? context;

  const WorkshopImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    // Se a URL está vazia ou é inválida, usar imagem padrão
    if (ImageUrlHelper.isEmptyOrInvalid(imageUrl)) {
      return _buildDefaultWorkshopImage();
    }

    return RobustImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      context: this.context ?? 'WorkshopImage',
      enableCacheBusting: true,
      placeholder: _buildLoadingPlaceholder(),
      errorWidget: _buildDefaultWorkshopImage(),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDefaultWorkshopImage() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
        border: Border.all(color: Colors.grey[400]!),
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
