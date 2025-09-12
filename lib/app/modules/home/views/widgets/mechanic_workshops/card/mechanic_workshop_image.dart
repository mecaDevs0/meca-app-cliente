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
    // Debug logs
    print('🔧 [MechanicWorkshopImage] Image Asset: "$imageAsset"');
    
    // Se a URL já é completa (começa com http/https), usar diretamente
    if (imageAsset.startsWith('http://') || imageAsset.startsWith('https://')) {
      print('🔧 [MechanicWorkshopImage] ✅ URL já é completa: "$imageAsset"');
      return _buildNetworkImage(imageAsset);
    }
    
    // Processar a URL da imagem
    final imageUrl = ImageUrlHelper.buildImageUrlWithValidation(imageAsset, context: 'Workshop');
    
    print('🔧 [MechanicWorkshopImage] Processed URL: "$imageUrl"');

    // Temporariamente aceitar todas as URLs para debug
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _buildNetworkImage(imageUrl);
    } else {
      print('🔧 [MechanicWorkshopImage] ❌ URL vazia, usando placeholder');
      return _buildPlaceholderImage();
    }
  }
  
  Widget _buildNetworkImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: 52,
      height: 56,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 52,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('🔧 [MechanicWorkshopImage] ❌ Erro ao carregar imagem: $error');
        return _buildPlaceholderImage();
      },
    );
  }
  
  Widget _buildPlaceholderImage() {
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.store,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
