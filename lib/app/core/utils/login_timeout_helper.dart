class LoginTimeoutHelper {
  static bool isMongoDbTimeout(dynamic error) {
    final message = error.toString().toLowerCase();
    final messageEx = error.response?.data?['messageEx']?.toString().toLowerCase() ?? '';
    
    return message.contains('timeout') || 
           message.contains('mongodb') ||
           messageEx.contains('timeout') ||
           messageEx.contains('mongodb') ||
           messageEx.contains('compositeserverselector');
  }
  
  static String getMongoDbTimeoutMessage() {
    return 'Servidor temporariamente sobrecarregado. Tente novamente em alguns minutos.';
  }
  
  static bool shouldShowErrorMessage(dynamic error) {
    // Verificar se é um erro de timeout
    final message = error.toString().toLowerCase();
    return !message.contains('timeout');
  }
  
  static String getErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    
    if (message.contains('timeout')) {
      return 'Timeout de conexão. Tente novamente.';
    } else if (message.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet.';
    } else if (message.contains('response')) {
      return 'Erro na resposta do servidor.';
    }
    
    return 'Erro de conexão. Tente novamente.';
  }
}
