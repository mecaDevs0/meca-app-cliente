import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Widget que força a renderização de imagens usando abordagem agressiva
class ForceRenderImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const ForceRenderImage({
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
  State<ForceRenderImage> createState() => _ForceRenderImageState();
}

class _ForceRenderImageState extends State<ForceRenderImage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    try {
      print('🚀 ForceRenderImage - Iniciando carregamento: ${widget.imageUrl}');
      
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 15; Mobile)',
          'Accept': 'image/*',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('✅ ForceRenderImage - Carregado com sucesso: ${widget.imageUrl} (${bytes.length} bytes)');
        
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = false;
        });
        
        // Forçar animação
        _animationController.forward();
        
        // Forçar rebuild múltiplas vezes
        for (int i = 0; i < 5; i++) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ForceRenderImage - Erro: ${widget.imageUrl} - $e');
      
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print('🔄 ForceRenderImage - Tentativa $_retryCount/$_maxRetries');
        await Future.delayed(Duration(seconds: _retryCount));
        _loadImage();
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_imageBytes == null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    Widget imageWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Image.memory(
            _imageBytes!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            errorBuilder: (context, error, stackTrace) {
              print('❌ ForceRenderImage - Erro na renderização: $error');
              return widget.errorWidget ?? _buildDefaultErrorWidget();
            },
          ),
        );
      },
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    // Forçar renderização com RepaintBoundary
    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        child: imageWidget,
      ),
    );
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
          Icons.error_outline,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}


