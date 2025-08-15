/// Configurações centralizadas para carregamento de imagens
class ImageConfig {
  // URLs base
  static const String baseUrl = 'https://api.mecabr.com/';
  static const String contentPath = 'content/';
  static const String servicosPath = 'content/servicos/';
  static const String oficinasPath = 'content/oficinas/';
  static const String imagesPath = 'content/images/';
  
  // URLs completas
  static const String servicosBaseUrl = '$baseUrl$servicosPath';
  static const String oficinasBaseUrl = '$baseUrl$oficinasPath';
  static const String imagesBaseUrl = '$baseUrl$imagesPath';
  
  // Configurações de retry
  static const int defaultMaxRetries = 3;
  static const Duration defaultRetryDelay = Duration(milliseconds: 1000);
  
  // Configurações de cache
  static const bool enableCacheBusting = true;
  static const Duration cacheTimeout = Duration(minutes: 5);
  
  // Headers otimizados para imagens
  static const Map<String, String> optimizedHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Samsung Galaxy S24) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 MECA-App/1.0',
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  /// Constrói a URL completa da imagem baseada no contexto
  static String buildImageUrl(String? imageUrl, {String? context}) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      return '';
    }
    
    final cleanUrl = imageUrl.trim();
    
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return cleanUrl;
    }
    
    // Verificar se a URL já tem o caminho correto
    if (cleanUrl.startsWith('/$contentPath') || cleanUrl.startsWith(contentPath)) {
      return '$baseUrl$cleanUrl';
    }
    
    // Determinar o caminho baseado no contexto
    if (context != null) {
      if (context.contains('Service') || context.contains('servico')) {
        return '$servicosBaseUrl$cleanUrl';
      } else if (context.contains('Workshop') || context.contains('oficina')) {
        return '$oficinasBaseUrl$cleanUrl';
      }
    }
    
    // Fallback: tentar detectar pelo nome do arquivo
    if (_isServiceImage(cleanUrl)) {
      return '$servicosBaseUrl$cleanUrl';
    } else if (_isWorkshopImage(cleanUrl)) {
      return '$oficinasBaseUrl$cleanUrl';
    }
    
    // Padrão: usar images
    return '$imagesBaseUrl$cleanUrl';
  }

  /// Verifica se é uma imagem de serviço baseado no nome
  static bool _isServiceImage(String fileName) {
    final serviceNames = [
      'mecanica-geral.png',
      'sistema-eletrico.png',
      'sistema-ar-condicionado.png',
      'injecao-eletronica.png',
      'sistema-freios.png',
      'alinhamento-balanceamento.png',
      'troca-filtros.png',
    ];
    return serviceNames.any((name) => fileName.contains(name));
  }

  /// Verifica se é uma imagem de oficina baseado no nome
  static bool _isWorkshopImage(String fileName) {
    // Imagens de oficinas geralmente têm timestamps como prefixo
    return RegExp(r'^\d{13}\.(png|jpg|jpeg)$').hasMatch(fileName) ||
           fileName.startsWith('174') || // Timestamps específicos vistos nos logs
           fileName.startsWith('175');
  }

  /// Valida se uma URL de imagem é válida
  static bool isValidImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      return false;
    }
    try {
      final uri = Uri.parse(imageUrl);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Adiciona timestamp único à URL para forçar reload
  static String addCacheBusting(String imageUrl, {String? uniqueKey}) {
    if (!enableCacheBusting) {
      return imageUrl;
    }
    final uri = Uri.parse(imageUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();
    if (uniqueKey != null) {
      queryParams['_k'] = uniqueKey;
    }
    queryParams['_v'] = '1'; // Versão do cache busting
    return uri.replace(queryParameters: queryParams).toString();
  }

  /// Verifica se a URL da imagem é vazia ou inválida
  static bool isEmptyOrInvalid(String? imageUrl) {
    return imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty || !isValidImageUrl(buildImageUrl(imageUrl));
  }
}
