import '../config/image_config.dart';
import '../../data/models/service.dart';

class ImageUrlHelper {
  static String buildImageUrl(String? imageUrl, {String? context}) {
    return ImageConfig.buildImageUrl(imageUrl, context: context);
  }
  
  static String? buildImageUrlSafe(String? imageUrl, {String? context}) {
    if (ImageConfig.isEmptyOrInvalid(imageUrl)) {
      return null;
    }
    
    return ImageConfig.buildImageUrl(imageUrl, context: context);
  }

  /// Valida se uma URL de imagem é válida
  static bool isValidImageUrl(String? imageUrl) {
    return ImageConfig.isValidImageUrl(imageUrl);
  }

  /// Adiciona timestamp único à URL para forçar reload
  static String addTimestampToUrl(String imageUrl, {String? uniqueKey}) {
    return ImageConfig.addCacheBusting(imageUrl, uniqueKey: uniqueKey);
  }

  /// Retorna headers HTTP otimizados para carregamento de
  static Map<String, String> getOptimizedHeaders() {
    return ImageConfig.optimizedHeaders;
  }

  /// Valida e constrói a URL da imagem, retornando null se for inválida
  static String? buildImageUrlWithValidation(String? imageUrl, {String? context}) {
    print('🔧 [ImageUrlHelper] Input imageUrl: "$imageUrl"');
    print('🔧 [ImageUrlHelper] Context: "$context"');
    
    if (ImageConfig.isEmptyOrInvalid(imageUrl)) {
      print('🔧 [ImageUrlHelper] ❌ ImageUrl é vazia ou inválida');
      return null;
    }
    
    final processedUrl = ImageConfig.buildImageUrl(imageUrl, context: context);
    print('🔧 [ImageUrlHelper] Processed URL: "$processedUrl"');
    
    final isValid = ImageConfig.isValidImageUrl(processedUrl);
    print('🔧 [ImageUrlHelper] URL é válida: $isValid');
    
    return isValid ? processedUrl : null;
  }
  
  static bool isEmptyOrInvalid(String? imageUrl) {
    return ImageConfig.isEmptyOrInvalid(imageUrl);
  }

  /// Retorna uma URL de imagem padrão para fallback
  static String getDefaultImageUrl() {
    return '${ImageConfig.baseUrl}${ImageConfig.imagesPath}default.png';
  }
}

