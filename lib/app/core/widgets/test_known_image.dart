import 'package:flutter/material.dart';

/// Widget que testa uma imagem conhecida para verificar se o problema é específico das URLs do backend
class TestKnownImage extends StatelessWidget {
  final double? width;
  final double? height;

  const TestKnownImage({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // URL de uma imagem conhecida que sempre funciona
    const knownImageUrl = 'https://picsum.photos/200/200';
    
    print('🧪 TestKnownImage - Testando imagem conhecida: $knownImageUrl');
    
    return Container(
      width: width ?? 100,
      height: height ?? 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        knownImageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ TestKnownImage - Imagem conhecida carregada: $knownImageUrl');
            return child;
          }
          print('🔄 TestKnownImage - Carregando imagem conhecida: $knownImageUrl - ${(loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) * 100).toStringAsFixed(1)}%');
          return Container(
            color: Colors.green,
            child: const Center(
              child: Text(
                'CARREGANDO\nIMAGEM\nCONHECIDA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ TestKnownImage - Erro na imagem conhecida: $knownImageUrl - $error');
          return Container(
            color: Colors.red,
            child: const Center(
              child: Text(
                'ERRO\nIMAGEM\nCONHECIDA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
