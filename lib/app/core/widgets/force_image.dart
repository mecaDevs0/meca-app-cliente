import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

class ForceImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableCache;
  final Duration timeout;

  const ForceImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableCache = false,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  State<ForceImage> createState() => _ForceImageState();
}

class _ForceImageState extends State<ForceImage> {
  late ImageStreamListener _listener;
  ImageStream? _imageStream;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ForceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      _loadImage();
    }
  }

  void _resetState() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    _retryCount = 0;
    _imageStream?.removeListener(_listener);
  }

  void _loadImage() {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'URL da imagem está vazia';
      });
      return;
    }

    print('🔄 ForceImage - Carregando: ${widget.imageUrl}');
    
    try {
      final ImageProvider imageProvider = NetworkImage(
        widget.imageUrl,
        headers: _getOptimizedHeaders(),
      );

      _imageStream = imageProvider.resolve(ImageConfiguration.empty);
      _listener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          print('✅ ForceImage - Carregamento concluído: ${widget.imageUrl}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
          }
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          print('❌ ForceImage - Erro no carregamento: ${widget.imageUrl}');
          print('   Erro: $exception');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = exception.toString();
            });
            
            // Tentar novamente se ainda não excedeu o limite
            if (_retryCount < _maxRetries) {
              _retryCount++;
              print('🔄 ForceImage - Tentativa $_retryCount de $_maxRetries: ${widget.imageUrl}');
              Future.delayed(Duration(seconds: _retryCount * 2), () {
                if (mounted) {
                  _loadImage();
                }
              });
            }
          }
        },
      );

      _imageStream!.addListener(_listener);
      
      // Timeout para evitar loading infinito
      Timer(widget.timeout, () {
        if (mounted && _isLoading) {
          print('⏰ ForceImage - Timeout: ${widget.imageUrl}');
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Timeout no carregamento';
          });
        }
      });
      
    } catch (e) {
      print('❌ ForceImage - Erro na inicialização: ${widget.imageUrl}');
      print('   Erro: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Map<String, String> _getOptimizedHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Android) MECA-App/1.0',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Cache-Control': widget.enableCache ? 'max-age=3600' : 'no-cache, no-store, must-revalidate',
      'Pragma': widget.enableCache ? '' : 'no-cache',
      'Expires': widget.enableCache ? '3600' : '0',
    };
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      print('🎯 ForceImage - Estado atualizado: ${widget.imageUrl} - ERRO: $_errorMessage');
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    print('🎯 ForceImage - Estado atualizado: ${widget.imageUrl} - SUCESSO');
    
    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      headers: _getOptimizedHeaders(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ ForceImage - Renderização concluída: ${widget.imageUrl}');
          return child;
        }
        return widget.placeholder ?? _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ ForceImage - Erro na renderização: ${widget.imageUrl}');
        print('   Erro: $error');
        return widget.errorWidget ?? _buildDefaultErrorWidget();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          print('⚡ ForceImage - Carregamento síncrono: ${widget.imageUrl}');
        }
        return child;
      },
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              'Erro ao carregar',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


