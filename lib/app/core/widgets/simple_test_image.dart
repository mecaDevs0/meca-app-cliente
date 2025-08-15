import 'package:flutter/material.dart';

/// Widget de teste simples para verificar carregamento de imagens
class SimpleTestImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SimpleTestImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    print('🧪 SimpleTestImage - Testando: $imageUrl');
    
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ SimpleTestImage - Sucesso: $imageUrl (${loadingProgress?.expectedTotalBytes ?? 0} bytes)');
          return child;
        }
        print('🔄 SimpleTestImage - Carregando: $imageUrl - ${(loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) * 100).toStringAsFixed(1)}%');
        return Container(
          color: Colors.blue[100],
          child: const Center(
            child: Text(
              'CARREGANDO',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ SimpleTestImage - Erro: $imageUrl - $error');
        return Container(
          color: Colors.red[100],
          child: const Center(
            child: Text(
              'ERRO',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
