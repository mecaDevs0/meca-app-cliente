import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/http_client_config.dart';

/// Resultado do upload
class UploadResult {
  final bool success;
  final String? imageId;
  final String? imageUrl;
  final String? error;
  final int? statusCode;

  UploadResult({
    required this.success,
    this.imageId,
    this.imageUrl,
    this.error,
    this.statusCode,
  });
}

/// Progresso do upload
class UploadProgress {
  final int sent;
  final int total;
  final double percentage;

  UploadProgress({
    required this.sent,
    required this.total,
  }) : percentage = total > 0 ? (sent / total) * 100 : 0.0;
}

/// Serviço para upload de imagens com suporte a progresso
class UploadService {
  late Dio _dio;
  
  UploadService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60), // Aumentado para 60s
      receiveTimeout: const Duration(seconds: 120), // Aumentado para 120s (upload pode demorar)
      sendTimeout: const Duration(seconds: 120), // Timeout para envio
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    ));

    configureDioForProduction(_dio);

    // Interceptor para adicionar token automaticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('Upload Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }
  
  /// Faz upload de uma imagem com progresso
  Future<UploadResult> uploadImage(
    File imageFile,
    String bookingId, {
    Function(UploadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // Validar arquivo
      if (!await imageFile.exists()) {
        return UploadResult(
          success: false,
          error: 'Arquivo não encontrado',
        );
      }
      
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        return UploadResult(
          success: false,
          error: 'Arquivo vazio',
        );
      }
      
      // Preparar FormData
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'booking_id': bookingId,
      });
      
      // Fazer upload
      final response = await _dio.post(
        '/bookings/$bookingId/images',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null) {
            onProgress(UploadProgress(
              sent: sent,
              total: total,
            ));
          }
        },
        cancelToken: cancelToken,
      );
      
      // Processar resposta
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data is Map<String, dynamic>) {
          if (data['success'] == true && data['data'] != null) {
            final imageData = data['data'];
            return UploadResult(
              success: true,
              imageId: imageData['id']?.toString(),
              imageUrl: imageData['url']?.toString(),
              statusCode: response.statusCode,
            );
          } else {
            return UploadResult(
              success: false,
              error: data['error']?.toString() ?? 'Erro desconhecido',
              statusCode: response.statusCode,
            );
          }
        }
        
        return UploadResult(
          success: true,
          statusCode: response.statusCode,
        );
      } else {
        return UploadResult(
          success: false,
          error: 'Erro no servidor: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Erro ao fazer upload';
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Timeout na conexão. Verifique sua internet.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Sem conexão com a internet.';
      } else if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 401) {
          errorMessage = 'Não autorizado. Faça login novamente.';
        } else if (statusCode == 413) {
          errorMessage = 'Arquivo muito grande.';
        } else if (statusCode == 500) {
          errorMessage = 'Erro no servidor. Tente novamente.';
        } else {
          errorMessage = 'Erro: ${e.response!.statusMessage ?? statusCode}';
        }
      }
      
      return UploadResult(
        success: false,
        error: errorMessage,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return UploadResult(
        success: false,
        error: 'Erro inesperado: ${e.toString()}',
      );
    }
  }
  
  /// Faz upload de múltiplas imagens
  Future<List<UploadResult>> uploadMultipleImages(
    List<File> imageFiles,
    String bookingId, {
    Function(int index, UploadProgress)? onProgress,
    Function(int index)? onComplete,
    Function(int index, String error)? onError,
    CancelToken? cancelToken,
  }) async {
    final results = <UploadResult>[];
    
    for (int i = 0; i < imageFiles.length; i++) {
      final result = await uploadImage(
        imageFiles[i],
        bookingId,
        onProgress: (progress) {
          if (onProgress != null) {
            onProgress(i, progress);
          }
        },
        cancelToken: cancelToken,
      );
      
      results.add(result);
      
      if (result.success) {
        if (onComplete != null) {
          onComplete(i);
        }
      } else {
        if (onError != null) {
          onError(i, result.error ?? 'Erro desconhecido');
        }
      }
    }
    
    return results;
  }
}






