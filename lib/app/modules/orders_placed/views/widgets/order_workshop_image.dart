import 'package:flutter/material.dart';

import '../../../../core/utils/image_url_helper.dart';

class OrderWorkshopImage extends StatelessWidget {
  const OrderWorkshopImage({
    super.key,
    required this.imageAsset,
    this.width = 60,
    this.height = 60,
    this.context = 'ServiceCard', // Contexto padrão para serviços
  });

  final String imageAsset;
  final double width;
  final double height;
  final String context; // 'ServiceCard' para serviços, 'Workshop' para oficinas

  @override
  Widget build(BuildContext context) {
    // Debug logs
    print('🔧 [OrderWorkshopImage] Image Asset: "$imageAsset"');
    print('🔧 [OrderWorkshopImage] Image Asset length: ${imageAsset.length}');
    print('🔧 [OrderWorkshopImage] Image Asset isEmpty: ${imageAsset.isEmpty}');
    print('🔧 [OrderWorkshopImage] Context: $context');
    
    // Processar a URL da imagem com o contexto correto
    final imageUrl = ImageUrlHelper.buildImageUrlWithValidation(imageAsset, context: this.context);
    
    print('🔧 [OrderWorkshopImage] Processed URL: "$imageUrl"');
    print('🔧 [OrderWorkshopImage] Processed URL is null: ${imageUrl == null}');
    print('🔧 [OrderWorkshopImage] Processed URL isEmpty: ${imageUrl?.isEmpty ?? true}');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    print('🔧 [OrderWorkshopImage] ✅ Imagem carregada com sucesso');
                    return child;
                  }
                  print('🔧 [OrderWorkshopImage] 📥 Carregando imagem: ${(loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : 0.0) * 100}%');
                  return Container(
                    width: width,
                    height: height,
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
                errorBuilder: (context, url, error) {
                  print('🔧 [OrderWorkshopImage] ❌ Erro ao carregar imagem: $error');
                  print('🔧 [OrderWorkshopImage] ❌ URL que falhou: $url');
                  print('🔧 [OrderWorkshopImage] ❌ Stack trace: $error');
                  return Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  );
                },
              )
            : Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
      ),
    );
  }
}
