import 'package:flutter/material.dart';

/// Widget que usa Image.network diretamente com configurações ultra otimizadas
/// para forçar a renderização de imagens no Flutter
class DirectNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const DirectNetworkImage({
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
  State<DirectNetworkImage> createState() => _DirectNetworkImageState();
}

class _DirectNetworkImageState extends State<DirectNetworkImage> {
  String? _uniqueKey;
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void didUpdateWidget(DirectNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
        _uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  String _addUniqueParams(String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}_t=$timestamp&_k=$_uniqueKey&_r=$_retryCount';
  }

  Map<String, String> _getUltraOptimizedHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Samsung Galaxy S24) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 MECA-App/1.0',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
      'Pragma': 'no-cache',
      'Expires': '0',
      'Sec-Fetch-Dest': 'image',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
      'Upgrade-Insecure-Requests': '1',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    final urlWithParams = _addUniqueParams(widget.imageUrl);
    
    print('🚀 DirectNetworkImage - Carregando: $urlWithParams');

    Widget imageWidget = Image.network(
      urlWithParams,
      key: ValueKey('direct_image_${_uniqueKey}_$_retryCount'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      headers: _getUltraOptimizedHeaders(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ DirectNetworkImage - Carregamento concluído: $urlWithParams');
          setState(() {
            _isLoading = false;
          });
          return child;
        }
        print('🔄 DirectNetworkImage - Carregando: ${(loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) * 100).toStringAsFixed(1)}%');
        return widget.placeholder ?? _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ DirectNetworkImage - Erro: $urlWithParams');
        print('   Erro: $error');
        
        if (_retryCount < _maxRetries) {
          _retryCount++;
          print('🔄 DirectNetworkImage - Tentativa $_retryCount de $_maxRetries');
          
          // Tentar novamente após um delay
          Future.delayed(Duration(seconds: _retryCount), () {
            if (mounted) {
              setState(() {});
            }
          });
          
          return widget.placeholder ?? _buildDefaultPlaceholder();
        } else {
          setState(() {
            _hasError = true;
          });
          return widget.errorWidget ?? _buildDefaultErrorWidget();
        }
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          print('⚡ DirectNetworkImage - Carregamento síncrono: $urlWithParams');
        }
        return child;
      },
    );

    // Aplicar borderRadius se especificado
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return RepaintBoundary(
      child: Container(
        key: ValueKey('direct_container_${_uniqueKey}_$_retryCount'),
        width: widget.width,
        height: widget.height,
        child: imageWidget,
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      key: ValueKey('direct_placeholder_${_uniqueKey}'),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
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
      key: ValueKey('direct_error_${_uniqueKey}'),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
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
