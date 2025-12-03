import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'photo_repository.dart';

/// Enum para definir o modo de captura
enum PhotoCaptureMode {
  quick,   // Usa image_picker (recomendado para MVP)
  advanced // Usa camera package (experiência customizada)
}

/// Resultado da captura de foto
class PhotoCaptureResult {
  final File? file;
  final String? error;
  final bool success;

  PhotoCaptureResult({
    this.file,
    this.error,
    required this.success,
  });
}

/// Serviço para captura e processamento de fotos
class PhotoService {
  final ImagePicker _imagePicker = ImagePicker();
  final PhotoRepository _photoRepository = PhotoRepository();
  
  // Configurações padrão
  static const int defaultMaxWidth = 1920;
  static const int defaultMaxHeight = 1080;
  static const int defaultQuality = 85;
  static const int maxFileSizeBytes = 3 * 1024 * 1024; // 3MB
  
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final PhotoCaptureMode mode;
  
  PhotoService({
    this.maxWidth = defaultMaxWidth,
    this.maxHeight = defaultMaxHeight,
    this.quality = defaultQuality,
    this.mode = PhotoCaptureMode.quick,
  });
  
  /// Verifica e solicita permissão da câmera usando popup NATIVO do sistema
  /// Retorna true se permissão foi concedida, false caso contrário
  Future<bool> requestCameraPermission() async {
    try {
      print('🔐 [PhotoService] Verificando status da permissão da câmera...');
      
      // Verificar status atual
      final status = await Permission.camera.status;
      print('🔐 [PhotoService] Status atual: ${status.toString()}');
      
      // Se já está concedida, retornar true
      if (status.isGranted) {
        print('🔐 [PhotoService] Permissão já concedida');
        return true;
      }
      
      // Se está permanentemente negada, abrir configurações diretamente
      if (status.isPermanentlyDenied) {
        print('🔐 [PhotoService] Permissão permanentemente negada, abrindo configurações...');
        await openAppSettings();
        return false;
      }
      
      print('🔐 [PhotoService] Solicitando permissão (popup nativo será exibido)...');
      
      // Solicitar permissão - isso dispara o popup NATIVO do sistema
      // iOS: mostra popup nativo da Apple
      // Android: mostra popup nativo do Android
      final result = await Permission.camera.request();
      
      print('🔐 [PhotoService] Resultado da solicitação: ${result.toString()}');
      print('🔐 [PhotoService] Permissão concedida: ${result.isGranted}');
      
      return result.isGranted;
    } catch (e, stackTrace) {
      print('❌ [PhotoService] Erro ao solicitar permissão: $e');
      print('❌ [PhotoService] Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Captura foto usando image_picker (modo rápido)
  Future<PhotoCaptureResult> takePhotoQuick() async {
    try {
      print('📷 [PhotoService] Abrindo câmera via image_picker...');
      
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      
      if (xfile == null) {
        print('📷 [PhotoService] Usuário cancelou a captura');
        return PhotoCaptureResult(
          success: false,
          error: 'Captura cancelada pelo usuário',
        );
      }
      
      print('📷 [PhotoService] Foto capturada: ${xfile.path}');
      
      // Converter para File e processar
      final originalFile = File(xfile.path);
      
      // Validar se arquivo existe
      if (!await originalFile.exists()) {
        print('❌ [PhotoService] Arquivo não existe: ${xfile.path}');
        return PhotoCaptureResult(
          success: false,
          error: 'Arquivo de foto não encontrado',
        );
      }
      
      // Validar tamanho do arquivo
      final fileSize = await originalFile.length();
      print('📷 [PhotoService] Tamanho do arquivo: ${fileSize} bytes');
      
      if (fileSize > maxFileSizeBytes) {
        print('📷 [PhotoService] Arquivo muito grande, comprimindo...');
        // Comprimir ainda mais se necessário
        final compressedFile = await _compressImage(originalFile);
        print('📷 [PhotoService] Arquivo comprimido: ${compressedFile.path}');
        return PhotoCaptureResult(
          file: compressedFile,
          success: true,
        );
      }
      
      print('📷 [PhotoService] Salvando arquivo temporário...');
      // Salvar em diretório temporário
      final tempFile = await _photoRepository.saveTempFile(originalFile);
      print('📷 [PhotoService] Arquivo salvo: ${tempFile.path}');
      
      return PhotoCaptureResult(
        file: tempFile,
        success: true,
      );
    } catch (e, stackTrace) {
      print('❌ [PhotoService] Erro ao capturar foto: $e');
      print('❌ [PhotoService] Stack trace: $stackTrace');
      return PhotoCaptureResult(
        success: false,
        error: 'Erro ao capturar foto: ${e.toString()}',
      );
    }
  }
  
  /// Captura foto usando camera package (modo avançado)
  /// Nota: Implementação completa requer CameraController
  /// Por enquanto, retorna erro indicando que precisa ser implementado
  Future<PhotoCaptureResult> takePhotoAdvanced() async {
    // TODO: Implementar modo avançado com camera package
    // Requer: CameraController, preview widget, etc.
    return PhotoCaptureResult(
      success: false,
      error: 'Modo avançado ainda não implementado. Use modo rápido.',
    );
  }
  
  /// Captura foto (usa modo configurado)
  Future<PhotoCaptureResult> takePhoto() async {
    switch (mode) {
      case PhotoCaptureMode.quick:
        return await takePhotoQuick();
      case PhotoCaptureMode.advanced:
        return await takePhotoAdvanced();
    }
  }
  
  /// Comprime e redimensiona imagem usando compute (isolate)
  Future<File> compressAndResize(
    File file, {
    int? targetWidth,
    int? targetHeight,
    int? targetQuality,
  }) async {
    final targetPath = await _photoRepository.generateTempPhotoPath();
    
    // Usar compute para processar em isolate
    final result = await compute(_compressImageIsolate, {
      'filePath': file.path,
      'targetPath': targetPath,
      'maxWidth': targetWidth ?? maxWidth,
      'maxHeight': targetHeight ?? maxHeight,
      'quality': targetQuality ?? quality,
    });
    
    return result;
  }
  
  /// Comprime imagem (versão não-isolada para uso direto)
  Future<File> _compressImage(File file) async {
    final targetPath = await _photoRepository.generateTempPhotoPath();
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
    );
    
    if (result == null) {
      throw Exception('Falha ao comprimir imagem');
    }
    
    return File(result.path);
  }
  
  /// Valida tamanho do arquivo
  Future<bool> validateFileSize(File file) async {
    try {
      final size = await file.length();
      return size <= maxFileSizeBytes;
    } catch (e) {
      return false;
    }
  }
  
  /// Obtém metadados da imagem (largura, altura, tamanho)
  Future<Map<String, dynamic>?> getImageMetadata(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final size = bytes.length;
      
      // Usar decodeImage para obter dimensões
      // Nota: requer package 'image' se quiser dimensões exatas
      // Por enquanto, retornamos tamanho do arquivo
      return {
        'fileSize': size,
        'filePath': file.path,
      };
    } catch (e) {
      return null;
    }
  }
  
  /// Limpa arquivos temporários antigos
  Future<int> cleanOldTempFiles({Duration? maxAge}) async {
    return await _photoRepository.cleanTempFilesOlderThan(
      maxAge ?? const Duration(days: 7),
    );
  }
  
  /// Remove uma foto temporária
  Future<bool> deleteTempPhoto(String filePath) async {
    return await _photoRepository.deleteTempPhoto(filePath);
  }
}

/// Função isolada para compressão (executa em isolate)
/// Deve ser top-level ou estática para usar com compute
Future<File> _compressImageIsolate(Map<String, dynamic> params) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    params['filePath'] as String,
    params['targetPath'] as String,
    minWidth: params['maxWidth'] as int,
    minHeight: params['maxHeight'] as int,
    quality: params['quality'] as int,
  );
  
  if (result == null) {
    throw Exception('Falha ao comprimir imagem');
  }
  
  return File(result.path);
}

