import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Widget que força o download das imagens e verifica o tamanho real
class ForceDownloadImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ForceDownloadImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<ForceDownloadImage> createState() => _ForceDownloadImageState();
}

class _ForceDownloadImageState extends State<ForceDownloadImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloadImage();
  }

  Future<void> _downloadImage() async {
    try {
      print('🚀 ForceDownloadImage - Iniciando download: ${widget.imageUrl}');
      
      final response = await http.get(
        Uri.parse(widget.imageUrl),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      print('📊 ForceDownloadImage - Status: ${response.statusCode}');
      print('📊 ForceDownloadImage - Content-Length: ${response.headers['content-length']}');
      print('📊 ForceDownloadImage - Bytes recebidos: ${response.bodyBytes.length}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
          _error = null;
        });
        print('✅ ForceDownloadImage - Download concluído: ${widget.imageUrl} (${response.bodyBytes.length} bytes)');
      } else {
        setState(() {
          _isLoading = false;
          _error = 'HTTP ${response.statusCode}';
        });
        print('❌ ForceDownloadImage - Erro HTTP: ${response.statusCode} - ${widget.imageUrl}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      print('❌ ForceDownloadImage - Erro de rede: $e - ${widget.imageUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.blue[100],
        child: const Center(
          child: Text(
            'BAIXANDO',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.red[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'ERRO',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      return Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ ForceDownloadImage - Erro ao renderizar imagem: $error');
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.red[100],
            child: const Center(
              child: Text(
                'ERRO RENDER',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
