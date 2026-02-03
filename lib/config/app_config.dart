/// Configurações do aplicativo MECA Cliente
class AppConfig {
  // ========================================
  // CONFIGURAÇÃO DA API - EC2 PRODUÇÃO
  // ========================================
  
  /// URL base da API (Produção - HTTPS via NGINX)
  static const String apiBaseUrl = 'https://api.mecabr.com';
  
  /// Timeout de conexão (segundos) - Falha rápida se API inacessível (DNS/SG)
  static const int connectionTimeout = 25;
  
  /// Timeout de recebimento (segundos)
  static const int receiveTimeout = 30;
  static const int plateSearchTimeout = 90; // Timeout específico para busca de placas (API externa pode ser lenta)
  
  // ========================================
  // APP INFO
  // ========================================
  
  /// Nome do app
  static const String appName = 'MECA Cliente';
  
  /// Versão do app
  static const String appVersion = '1.8.1';
  
  /// Build number
  static const String buildNumber = '164';
  
  // ========================================
  // PAGSEGURO / PAGBANK
  // ========================================
  
  /// Chave pública PagBank
  static const String pagBankPublicKey = 'YOUR_PUBLIC_KEY_HERE'; // TODO: Adicionar chave real
  
  /// Taxa da plataforma MECA (7%)
  static const double mecaPlatformFee = 0.07; // 7%
  
  // ========================================
  // FIPE API (Consulta de Veículos)
  // ========================================
  
  /// URL da API FIPE (ou API alternativa para consulta de veículos)
  static const String fipeApiUrl = 'https://parallelum.com.br/fipe/api/v1';
  
  // ========================================
  // GOOGLE MAPS
  // ========================================
  
  /// Google Maps API Key (Android)
  static const String googleMapsApiKeyAndroid = 'AIzaSyC20pzNvopOH3yEw8GEBQHUvQFOUo06nKI';
  
  /// Google Maps API Key (iOS)
  static const String googleMapsApiKeyIos = 'AIzaSyCrPTUKg8WhqdoR7sWooJIBysXGr398A_A';
  
  /// Google Maps API Key (Browser/Static Maps)
  static const String googleMapsApiKeyBrowser = 'AIzaSyAghycKw5EdhmYeYFRYgLpggKTU7uVHFL4';

  // ========================================
  // LOGIN SOCIAL
  // ========================================

  /// OAuth Client ID do Google para Android (meca cliente)
  static const String googleClientIdAndroid =
      '767232279794-gom2mm3q2l65aotqta7ki0sfhvq3vb25.apps.googleusercontent.com';

  /// OAuth Client ID do Google para iOS (meca cliente)
  static const String googleClientIdIos =
      '767232279794-roqqa6hu1tqjsdusu5a3halkheqet6b0.apps.googleusercontent.com';

  /// OAuth Client ID do Google para uso como serverClientId (web)
  static const String googleClientIdWeb =
      '767232279794-tn09hsoednrtm3vonkfep0ec1qrob6v1.apps.googleusercontent.com';

  /// Service ID utilizado no Sign in with Apple (bundle da MECA)
  static const String appleServiceId = 'com.meca.app.service';
  
  // ========================================
  // FIREBASE / NOTIFICAÇÕES
  // ========================================
  
  /// Firebase Project ID
  static const String firebaseProjectId = 'meca-cliente';
  
  // ========================================
  // ONESIGNAL / PUSH NOTIFICATIONS
  // ========================================
  
  /// OneSignal App ID
  static const String oneSignalAppId = '7bbec33c-bffc-47b1-ab90-a080b7353763';
  
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


