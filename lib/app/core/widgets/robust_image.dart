import 'package:flutter/material.dart';
import 'dart:async';

import '../utils/image_url_helper.dart';

/// Widget robusto para carregamento de imagens com retry automático e fallbacks
class RobustImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int maxRetries;
  final Duration retryDelay;
  final String? context;
  final bool enableCacheBusting;

  const RobustImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 1000),
    this.context,
    this.enableCacheBusting = true,
  });

  @override
  State<RobustImage> createState() => _RobustImageState();
}

class _RobustImageState extends State<RobustImage> {
  int _retryCount = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _retryTimer;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(RobustImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      _loadImage();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    _retryCount = 0;
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    _currentUrl = null;
    _retryTimer?.cancel();
  }

  void _loadImage() {
    // Verificar se a URL está vazia ou é inválida
    if (ImageUrlHelper.isEmptyOrInvalid(widget.imageUrl)) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'URL vazia ou inválida';
      });
      return;
    }

    final processedUrl = ImageUrlHelper.buildImageUrlWithValidation(
      widget.imageUrl, 
      context: widget.context ?? 'RobustImage'
    );

    if (processedUrl == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'URL inválida';
      });
      return;
    }

    // Adicionar cache busting se habilitado
    final finalUrl = widget.enableCacheBusting 
        ? ImageUrlHelper.addTimestampToUrl(processedUrl, uniqueKey: '${widget.context}_$_retryCount')
        : processedUrl;
    
    _currentUrl = finalUrl;

    // Log para debug
    print('🔄 RobustImage - Carregando: $finalUrl (tentativa ${_retryCount + 1})');
  }

  void _retryLoad() {
    if (_retryCount < widget.maxRetries) {
      _retryCount++;
      print('🔄 RobustImage - Tentativa $_retryCount de ${widget.maxRetries}');
      
      _retryTimer = Timer(widget.retryDelay, () {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
          _loadImage();
        }
      });
    } else {
      print('❌ RobustImage - Máximo de tentativas atingido');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se a URL está vazia ou é inválida, mostrar placeholder
    if (ImageUrlHelper.isEmptyOrInvalid(widget.imageUrl)) {
      return _buildPlaceholder('URL vazia ou inválida');
    }

    final processedUrl = ImageUrlHelper.buildImageUrlSafe(widget.imageUrl);
    
    if (processedUrl == null) {
      return _buildPlaceholder('URL inválida');
    }

    // Adicionar cache busting se habilitado
    final finalUrl = widget.enableCacheBusting 
        ? ImageUrlHelper.addTimestampToUrl(processedUrl, uniqueKey: '${widget.context}_$_retryCount')
        : processedUrl;

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Image.network(
        finalUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: ImageUrlHelper.getOptimizedHeaders(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ RobustImage - Imagem carregada: $finalUrl');
            return child;
          }
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ RobustImage - Erro na imagem: $finalUrl - $error');
          
          // Tentar novamente automaticamente
          if (_retryCount < widget.maxRetries) {
            _retryLoad();
            return _buildLoadingPlaceholder();
          }
          
          return _buildErrorPlaceholder('Erro ao carregar');
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String message) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String reason) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
