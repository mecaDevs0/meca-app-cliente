import 'package:flutter/material.dart';

/// Widget final que usa Image.network com configurações ultra otimizadas
class FinalNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const FinalNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _buildDefaultErrorWidget();
    }

    print('🎯 FinalNetworkImage - Renderizando: $imageUrl');

    // Calcular cacheWidth e cacheHeight de forma segura
    int? safeCacheWidth;
    int? safeCacheHeight;
    
    if (width != null && width!.isFinite) {
      safeCacheWidth = width!.toInt();
    }
    
    if (height != null && height!.isFinite) {
      safeCacheHeight = height!.toInt();
    }

    Widget imageWidget = Image.network(
      imageUrl,
      key: ValueKey('final_image_$imageUrl'),
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ FinalNetworkImage - Carregado com sucesso: $imageUrl');
          return child;
        }
        print('🔄 FinalNetworkImage - Carregando: $imageUrl (${(loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) * 100).toStringAsFixed(1)}%)');
        return placeholder ?? _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ FinalNetworkImage - Erro: $imageUrl');
        print('   Erro: $error');
        return errorWidget ?? _buildDefaultErrorWidget();
      },
      headers: _getHeaders(),
      cacheWidth: safeCacheWidth,
      cacheHeight: safeCacheHeight,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );

    // Aplicar borderRadius se especificado
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return RepaintBoundary(
      child: Container(
        key: ValueKey('final_container_$imageUrl'),
        width: width,
        height: height,
        child: imageWidget,
      ),
    );
  }

  Map<String, String> _getHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Samsung Galaxy S24) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 MECA-App/1.0',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      key: ValueKey('final_placeholder_$imageUrl'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
            const SizedBox(height: 8),
            Text(
              'Carregando...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      key: ValueKey('final_error_$imageUrl'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Erro ao carregar',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
