/// Configurações do aplicativo MECA Cliente
class AppConfig {
  // ========================================
  // CONFIGURAÇÃO DA API - EC2 PRODUÇÃO
  // ========================================
  
  /// URL base da API (EC2 AWS)
  static const String apiBaseUrl = 'http://ec2-3-144-213-137.us-east-2.compute.amazonaws.com:9000';
  
  /// Timeout de conexão (segundos) - Otimizado para EC2
  static const int connectionTimeout = 60;
  
  /// Timeout de recebimento (segundos) - Otimizado para EC2
  static const int receiveTimeout = 60;
  
  // ========================================
  // APP INFO
  // ========================================
  
  /// Nome do app
  static const String appName = 'MECA Cliente';
  
  /// Versão do app
  static const String appVersion = '1.0.0';
  
  /// Build number
  static const String buildNumber = '1';
  
  // ========================================
  // PAGSEGURO / PAGBANK
  // ========================================
  
  /// Chave pública PagBank
  static const String pagBankPublicKey = 'YOUR_PUBLIC_KEY_HERE'; // TODO: Adicionar chave real
  
  /// Taxa da plataforma MECA (5%)
  static const double mecaPlatformFee = 0.05; // 5%
  
  // ========================================
  // FIPE API (Consulta de Veículos)
  // ========================================
  
  /// URL da API FIPE (ou API alternativa para consulta de veículos)
  static const String fipeApiUrl = 'https://parallelum.com.br/fipe/api/v1';
  
  // ========================================
  // GOOGLE MAPS
  // ========================================
  
  /// Google Maps API Key (Android)
  static const String googleMapsApiKeyAndroid = 'YOUR_ANDROID_KEY_HERE'; // TODO: Adicionar chave real
  
  /// Google Maps API Key (iOS)
  static const String googleMapsApiKeyIos = 'YOUR_IOS_KEY_HERE'; // TODO: Adicionar chave real
  
  // ========================================
  // FIREBASE / NOTIFICAÇÕES
  // ========================================
  
  /// Firebase Project ID
  static const String firebaseProjectId = 'meca-cliente';
  
  // ========================================
  // DEBUG
  // ========================================
  
  /// Imprime as configurações atuais
  static void printConfig() {
    print('========================================');
    print('MECA Cliente - Configurações');
    print('========================================');
    print('API Base URL: $apiBaseUrl');
    print('App Version: $appVersion ($buildNumber)');
    print('MECA Platform Fee: ${mecaPlatformFee * 100}%');
    print('========================================');
  }
}


