import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OptimizedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableCache;
  final Duration timeout;
  final int maxRetries;
  final bool forceRefresh;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableCache = false,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.forceRefresh = false,
  });

  @override
  State<OptimizedNetworkImage> createState() => _OptimizedNetworkImageState();
}

class _OptimizedNetworkImageState extends State<OptimizedNetworkImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  Timer? _timeoutTimer;
  http.Client? _httpClient;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || widget.forceRefresh) {
      _resetState();
      _loadImage();
    }
  }

  void _resetState() {
    _imageBytes = null;
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    _retryCount = 0;
    _timeoutTimer?.cancel();
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      _setError('URL da imagem está vazia');
      return;
    }

    // Adicionar timestamp para forçar reload
    final urlWithTimestamp = _addTimestampToUrl(widget.imageUrl);
    _currentUrl = urlWithTimestamp;

    print('🔄 OptimizedNetworkImage - Carregando: $urlWithTimestamp');
    
    try {
      // Configurar timeout
      _timeoutTimer = Timer(widget.timeout, () {
        if (mounted && _isLoading) {
          print('⏰ OptimizedNetworkImage - Timeout: $urlWithTimestamp');
          _setError('Timeout no carregamento');
        }
      });

      // Fazer requisição HTTP com headers otimizados
      final response = await _httpClient!.get(
        Uri.parse(urlWithTimestamp),
        headers: _getOptimizedHeaders(),
      ).timeout(widget.timeout);

      _timeoutTimer?.cancel();

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isNotEmpty) {
          print('✅ OptimizedNetworkImage - Carregamento concluído: $urlWithTimestamp (${bytes.length} bytes)');
          if (mounted) {
            setState(() {
              _imageBytes = bytes;
              _isLoading = false;
              _hasError = false;
            });
            // Forçar rebuild
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }
        } else {
          _setError('Imagem vazia recebida');
        }
      } else {
        _setError('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
      
    } catch (e) {
      _timeoutTimer?.cancel();
      print('❌ OptimizedNetworkImage - Erro no carregamento: $urlWithTimestamp');
      print('   Erro: $e');
      
      if (_retryCount < widget.maxRetries) {
        _retryCount++;
        print('🔄 OptimizedNetworkImage - Tentativa $_retryCount de ${widget.maxRetries}: $urlWithTimestamp');
        await Future.delayed(Duration(seconds: _retryCount * 2));
        if (mounted) {
          _loadImage();
        }
      } else {
        _setError('Falha após ${widget.maxRetries} tentativas: $e');
      }
    }
  }

  String _addTimestampToUrl(String url) {
    if (widget.forceRefresh) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}_t=$timestamp';
    }
    return url;
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
      print('❌ OptimizedNetworkImage - Erro: ${widget.imageUrl} - $message');
    }
  }

  Map<String, String> _getOptimizedHeaders() {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Android) MECA-App/1.0',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };

    return headers;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      print('🎯 OptimizedNetworkImage - Estado: ${widget.imageUrl} - ERRO: $_errorMessage');
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_imageBytes != null) {
      print('🎯 OptimizedNetworkImage - Estado: ${widget.imageUrl} - SUCESSO (${_imageBytes!.length} bytes)');
      
      return Container(
        width: widget.width,
        height: widget.height,
        child: Image.memory(
          _imageBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            print('❌ OptimizedNetworkImage - Erro na renderização: ${widget.imageUrl}');
            print('   Erro: $error');
            return widget.errorWidget ?? _buildDefaultErrorWidget();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              print('⚡ OptimizedNetworkImage - Carregamento síncrono: ${widget.imageUrl}');
            }
            return child;
          },
        ),
      );
    }

    return widget.errorWidget ?? _buildDefaultErrorWidget();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Carregando...',
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
