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
  static String buildImageUrl(String? imageUrl, {String? context}) {
    print('🔧 [ImageConfig] Input imageUrl: "$imageUrl"');
    print('🔧 [ImageConfig] Context: "$context"');
    
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      print('🔧 [ImageConfig] ❌ ImageUrl é vazia');
      return '';
    }
    
    final cleanUrl = imageUrl.trim();
    print('🔧 [ImageConfig] Clean URL: "$cleanUrl"');
    
    // Se já é uma URL completa, retornar como está
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      print('🔧 [ImageConfig] ✅ URL já é completa: "$cleanUrl"');
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
      if (context.contains('Service') || context.contains('servico')) {
        final url = '$servicosBaseUrl$cleanUrl';
        print('🔧 [ImageConfig] ✅ URL de serviço: "$url"');
        return url;
      } else if (context.contains('Workshop') || context.contains('oficina') || context.contains('MechanicWorkshop')) {
        // Para workshops, usar o diretório upload
        final url = '$uploadBaseUrl$cleanUrl';
        print('🔧 [ImageConfig] ✅ URL de oficina (upload): "$url"');
        return url;
      }
    }
    
    // Fallback: tentar detectar pelo nome do arquivo
    if (_isServiceImage(cleanUrl)) {
      final url = '$servicosBaseUrl$cleanUrl';
      print('🔧 [ImageConfig] ✅ URL de serviço (detectada): "$url"');
      return url;
    } else if (_isWorkshopImage(cleanUrl)) {
      // Para workshops, usar o diretório upload
      final url = '$uploadBaseUrl$cleanUrl';
      print('🔧 [ImageConfig] ✅ URL de oficina (upload, detectada): "$url"');
      return url;
    }
    
    // Padrão: usar upload para imagens de workshops
    final url = '$uploadBaseUrl$cleanUrl';
    print('🔧 [ImageConfig] ✅ URL padrão (upload): "$url"');
    return url;
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
      'funilaria-pintura.png',
      'performance-tuning.png',
      'carros-antigos.png',
      'carros-nacionais.png',
      'sistema-arrefecimento.png',
      'sistema-direcao.png',
      'sistema-limpeza.png',
      'carros-premium.png',
      'sistema-escape.png',
      'suvs-4x4.png',
      'blindagem.png',
      'sistema-embreagem.png',
      'revisao-preventiva.png',
      'pickups-utilitarios.png',
      'sistema-motor.png',
      'acessorios.png',
      'revisao-venda.png',
      'diagnostico-eletronico.png',
      'martelinho-ouro.png',
      'carros-importados.png',
      'lava-rapido.png',
      'correias.png',
    ];
    return serviceNames.any((name) => fileName.contains(name));
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
    return imageUrl == null || imageUrl.isEmpty || imageUrl.trim().isEmpty || !isValidImageUrl(buildImageUrl(imageUrl));
  }
}
