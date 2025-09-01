/// Configurações centralizadas para carregamento de imagens
class ImageConfig {
  // URLs base
  static const String baseUrl = 'https://api.mecabr.com/';
  static const String contentPath = 'content/';
  static const String uploadPath = 'content/upload/';
  static const String servicosPath = 'content/servicos/';
  static const String oficinasPath = 'content/oficinas/';
  static const String imagesPath = 'content/images/';
  
  // URLs completas
  static const String uploadBaseUrl = '$baseUrl$uploadPath';
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
  /// Lógica centralizada e inteligente para corrigir URLs de imagem
  /// ÚNICA FONTE DE VERDADE para construção de URLs de imagem
  static String buildImageUrl(String? imageUrl, {String? context}) {
    print('🔧 [ImageConfig] Input imageUrl: "$imageUrl"');
    print('🔧 [ImageConfig] Context: "$context"');
    
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      print('🔧 [ImageConfig] ❌ ImageUrl é vazia');
      return '';
    }
    
    final cleanUrl = imageUrl.trim();
    print('🔧 [ImageConfig] Clean URL: "$cleanUrl"');
    
    // Se já é uma URL completa, verificar se precisa de correção
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      print('🔧 [ImageConfig] 🔍 URL completa detectada, verificando se precisa correção');
      
      // CORREÇÃO CRÍTICA: Se a URL contém /content/upload mas deveria ser /content/servicos/
      if (cleanUrl.contains('/content/upload') && _isServiceImage(_extractFileName(cleanUrl))) {
        final correctedUrl = cleanUrl.replaceAll('/content/upload', '/content/servicos/');
        print('🔧 [ImageConfig] ✅ URL corrigida de upload para servicos/: "$correctedUrl"');
        return correctedUrl;
      }
      
      // CORREÇÃO: Se a URL contém /content/upload mas deveria ser /content/ para oficinas
      if (cleanUrl.contains('/content/upload') && _isWorkshopImage(_extractFileName(cleanUrl))) {
        final correctedUrl = cleanUrl.replaceAll('/content/upload', '/content/');
        print('🔧 [ImageConfig] ✅ URL corrigida de upload para content/: "$correctedUrl"');
        return correctedUrl;
      }
      
      print('🔧 [ImageConfig] ✅ URL já é completa e correta: "$cleanUrl"');
      return cleanUrl;
    }
    
    // Verificar se a URL já tem o caminho correto
    if (cleanUrl.startsWith('/$contentPath') || cleanUrl.startsWith(contentPath)) {
      final url = '$baseUrl$cleanUrl';
      print('🔧 [ImageConfig] ✅ URL com caminho correto: "$url"');
      return url;
    }
    
    // Determinar o caminho baseado no contexto
    if (context != null) {
      final lowerContext = context.toLowerCase();
      if (lowerContext.contains('service') || lowerContext.contains('servico')) {
        final url = '$servicosBaseUrl$cleanUrl';
        print('🔧 [ImageConfig] ✅ URL de serviço (contexto): "$url"');
        return url;
      } else if (lowerContext.contains('workshop') || lowerContext.contains('oficina') || lowerContext.contains('mechanicworkshop')) {
        // Para workshops, usar o diretório content (não upload)
        final url = '$baseUrl$contentPath$cleanUrl';
        print('🔧 [ImageConfig] ✅ URL de oficina (contexto): "$url"');
        return url;
      }
    }
    
    // Fallback: tentar detectar pelo nome do arquivo
    if (_isServiceImage(cleanUrl)) {
      final url = '$servicosBaseUrl$cleanUrl';
      print('🔧 [ImageConfig] ✅ URL de serviço (detectada): "$url"');
      return url;
    } else if (_isWorkshopImage(cleanUrl)) {
      // Para workshops, usar o diretório content (não upload)
      final url = '$baseUrl$contentPath$cleanUrl';
      print('🔧 [ImageConfig] ✅ URL de oficina (content, detectada): "$url"');
      return url;
    }
    
    // Padrão: usar content para imagens de workshops
    final url = '$baseUrl$contentPath$cleanUrl';
    print('🔧 [ImageConfig] ✅ URL padrão (content): "$url"');
    return url;
  }

  /// Extrai o nome do arquivo de uma URL completa
  static String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
    } catch (e) {
      print('🔧 [ImageConfig] ❌ Erro ao extrair nome do arquivo: $e');
    }
    return url;
  }

  /// Verifica se é uma imagem de serviço baseado no nome
  static bool _isServiceImage(String fileName) {
    final serviceNames = [
      'mecanica-geral',
      'sistema-eletrico',
      'sistema-ar-condicionado',
      'injecao-eletronica',
      'sistema-freios',
      'alinhamento-balanceamento',
      'troca-filtros',
      'funilaria-pintura',
      'performance-tuning',
      'carros-antigos',
      'carros-nacionais',
      'sistema-arrefecimento',
      'sistema-direcao',
      'sistema-limpeza',
      'carros-premium',
      'sistema-escape',
      'suvs-4x4',
      'blindagem',
      'sistema-embreagem',
      'revisao-preventiva',
      'pickups-utilitarios',
      'sistema-motor',
      'acessorios',
      'revisao-venda',
      'diagnostico-eletronico',
      'martelinho-ouro',
      'carros-importados',
      'lava-rapido',
      'correias',
    ];
    
    final cleanFileName = fileName.toLowerCase().replaceAll('.png', '').replaceAll('.jpg', '').replaceAll('.jpeg', '');
    return serviceNames.any((name) => cleanFileName.contains(name.toLowerCase()));
  }

  /// Verifica se é uma imagem de oficina baseado no nome
  static bool _isWorkshopImage(String fileName) {
    // Imagens de oficinas geralmente têm timestamps como prefixo
    return RegExp(r'^\d{13}\.(png|jpg|jpeg)$').hasMatch(fileName) ||
           fileName.startsWith('174') || // Timestamps específicos vistos nos logs
           fileName.startsWith('175') ||
           fileName.startsWith('upload'); // URLs que começam com "upload"
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
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      return true;
    }
    
    // Se já é uma URL completa, validar diretamente
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return !isValidImageUrl(imageUrl);
    }
    
    // Se é apenas um filename, considerar válido (será processado depois)
    return false;
  }
}
