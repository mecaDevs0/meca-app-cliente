import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Widget que carrega imagens diretamente na memória e força renderização
class MemoryForceImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const MemoryForceImage({
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
  State<MemoryForceImage> createState() => _MemoryForceImageState();
}

class _MemoryForceImageState extends State<MemoryForceImage> {
  Uint8List? _imageBytes;
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
  void didUpdateWidget(MemoryForceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
        _imageBytes = null;
      });
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      _setError('URL da imagem está vazia');
      return;
    }

    try {
      print('🚀 MemoryForceImage - Baixando: ${widget.imageUrl}');

      // Fazer requisição HTTP
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ MemoryForceImage - Carregado: ${widget.imageUrl} (${response.bodyBytes.length} bytes)');
        
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
        });
        
        // Forçar rebuild adicional
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        _setError('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
      
    } catch (e) {
      print('❌ MemoryForceImage - Erro: ${widget.imageUrl}');
      print('   Erro: $e');
      
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print('🔄 MemoryForceImage - Tentativa $_retryCount de $_maxRetries');
        await Future.delayed(Duration(seconds: _retryCount * 2));
        if (mounted) {
          _loadImage();
        }
      } else {
        _setError('Falha após $_maxRetries tentativas: $e');
      }
    }
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

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      print('🎯 MemoryForceImage - Estado: ${widget.imageUrl} - ERRO: $_errorMessage');
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_imageBytes != null) {
      print('🎯 MemoryForceImage - Renderizando: ${widget.imageUrl} (${_imageBytes!.length} bytes)');
      
      Widget imageWidget = Image.memory(
        _imageBytes!,
        key: ValueKey('memory_image_${widget.imageUrl}_${DateTime.now().millisecondsSinceEpoch}'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ MemoryForceImage - Erro na renderização: ${widget.imageUrl}');
          print('   Erro: $error');
          return widget.errorWidget ?? _buildDefaultErrorWidget();
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
          key: ValueKey('memory_container_${widget.imageUrl}_${DateTime.now().millisecondsSinceEpoch}'),
          width: widget.width,
          height: widget.height,
          child: imageWidget,
        ),
      );
    }

    return widget.errorWidget ?? _buildDefaultErrorWidget();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      key: ValueKey('memory_placeholder_${widget.imageUrl}'),
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
      key: ValueKey('memory_error_${widget.imageUrl}'),
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
