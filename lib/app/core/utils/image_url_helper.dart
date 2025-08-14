import '../app_urls.dart';

class ImageUrlHelper {
  static String buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Verificar se a URL já tem o caminho correto para imagens
    if (imageUrl.startsWith('/content/images/')) {
      return '${BaseUrls.baseUrlProd}$imageUrl';
    }
    
    // Se não tem o caminho, adicionar o caminho padrão para imagens
    return '${BaseUrls.imagesBaseUrl}$imageUrl';
  }
  
  static String? buildImageUrlSafe(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Verificar se a URL já tem o caminho correto para imagens
    if (imageUrl.startsWith('/content/images/')) {
      return '${BaseUrls.baseUrlProd}$imageUrl';
    }
    
    // Se não tem o caminho, adicionar o caminho padrão para imagens
    return '${BaseUrls.imagesBaseUrl}$imageUrl';
  }
}
