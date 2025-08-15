import 'package:flutter/material.dart';
import 'dart:async';

/// Widget simples e direto para carregar imagens de rede
class SimpleNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SimpleNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SimpleNetworkImage> createState() => _SimpleNetworkImageState();
}

class _SimpleNetworkImageState extends State<SimpleNetworkImage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(SimpleNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
      _loadImage();
    }
  }

  void _loadImage() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'URL vazia';
      });
      return;
    }

    // Simular carregamento para dar tempo ao widget de renderizar
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    Widget imageWidget = Image.network(
      widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ SimpleNetworkImage - Carregada: ${widget.imageUrl}');
          return child;
        }
        return _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ SimpleNetworkImage - Erro: ${widget.imageUrl} - $error');
        return widget.errorWidget ?? _buildDefaultErrorWidget();
      },
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Samsung Galaxy S24) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 MECA-App/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildDefaultPlaceholder() {
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

  Widget _buildDefaultErrorWidget() {
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


