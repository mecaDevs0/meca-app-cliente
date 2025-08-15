import 'package:flutter/material.dart';

/// Widget de teste muito simples para verificar renderização de imagens
class TestSimpleImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  const TestSimpleImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    print('🧪 TestSimpleImage - Testando: $imageUrl');
    
    return Container(
      width: width ?? 100,
      height: height ?? 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ TestSimpleImage - Carregada: $imageUrl');
            return child;
          }
          print('🔄 TestSimpleImage - Carregando: $imageUrl - ${(loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) * 100).toStringAsFixed(1)}%');
          return Container(
            color: Colors.blue,
            child: const Center(
              child: Text(
                'CARREGANDO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ TestSimpleImage - Erro: $imageUrl - $error');
          return Container(
            color: Colors.red,
            child: const Center(
              child: Text(
                'ERRO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
