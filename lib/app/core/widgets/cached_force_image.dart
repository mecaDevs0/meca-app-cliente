import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Widget que salva imagens localmente e força renderização
class CachedForceImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedForceImage({
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
  State<CachedForceImage> createState() => _CachedForceImageState();
}

class _CachedForceImageState extends State<CachedForceImage> {
  String? _localPath;
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
  void didUpdateWidget(CachedForceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
        _localPath = null;
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
      // Gerar nome único para o arquivo
      final fileName = _generateFileName(widget.imageUrl);
      final cacheDir = await getTemporaryDirectory();
      final filePath = '${cacheDir.path}/$fileName';

      // Verificar se já existe no cache
      final file = File(filePath);
      if (await file.exists()) {
        print('📁 CachedForceImage - Usando cache local: $filePath');
        setState(() {
          _localPath = filePath;
          _isLoading = false;
        });
        return;
      }

      print('🚀 CachedForceImage - Baixando: ${widget.imageUrl}');

      // Fazer requisição HTTP
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Salvar no cache local
        await file.writeAsBytes(response.bodyBytes);
        
        print('✅ CachedForceImage - Salvo no cache: $filePath (${response.bodyBytes.length} bytes)');
        
        setState(() {
          _localPath = filePath;
          _isLoading = false;
        });
      } else {
        _setError('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
      
    } catch (e) {
      print('❌ CachedForceImage - Erro: ${widget.imageUrl}');
      print('   Erro: $e');
      
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print('🔄 CachedForceImage - Tentativa $_retryCount de $_maxRetries');
        await Future.delayed(Duration(seconds: _retryCount * 2));
        if (mounted) {
          _loadImage();
        }
      } else {
        _setError('Falha após $_maxRetries tentativas: $e');
      }
    }
  }

  String _generateFileName(String url) {
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes);
    final extension = url.split('.').last;
    return 'meca_${hash.toString()}.$extension';
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
      print('🎯 CachedForceImage - Estado: ${widget.imageUrl} - ERRO: $_errorMessage');
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_localPath != null) {
      final file = File(_localPath!);
      if (file.existsSync()) {
        print('🎯 CachedForceImage - Renderizando: $_localPath');
        
        Widget imageWidget = Image.file(
          file,
          key: ValueKey('cached_image_${_localPath}_${DateTime.now().millisecondsSinceEpoch}'),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            print('❌ CachedForceImage - Erro na renderização: $_localPath');
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
            key: ValueKey('cached_container_${_localPath}_${DateTime.now().millisecondsSinceEpoch}'),
            width: widget.width,
            height: widget.height,
            child: imageWidget,
          ),
        );
      }
    }

    return widget.errorWidget ?? _buildDefaultErrorWidget();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      key: ValueKey('cached_placeholder_${widget.imageUrl}'),
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
      key: ValueKey('cached_error_${widget.imageUrl}'),
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
