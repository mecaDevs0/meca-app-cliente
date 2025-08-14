class ServerStatusHelper {
  static bool isServerError(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode >= 500 && statusCode < 600;
  }
  
  static bool isConnectivityError(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode == 0 || statusCode == -1;
  }
  
  static String getErrorMessage(int? statusCode) {
    if (statusCode == null) return 'Erro desconhecido';
    
    switch (statusCode) {
      case 0:
      case -1:
        return 'Erro de conectividade. Verifique sua conexão com a internet.';
      case 500:
        return 'Erro interno do servidor. Tente novamente mais tarde.';
      case 502:
        return 'Servidor temporariamente indisponível.';
      case 503:
        return 'Serviço temporariamente indisponível.';
      case 504:
        return 'Timeout do servidor. Tente novamente.';
      default:
        return 'Erro do servidor (código: $statusCode)';
    }
  }
  
  static String getSolutionSuggestion(int? statusCode) {
    if (statusCode == null) return 'Tente novamente mais tarde.';
    
    switch (statusCode) {
      case 0:
      case -1:
        return 'Verifique sua conexão com a internet e tente novamente.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'O servidor está temporariamente indisponível. Tente novamente em alguns minutos.';
      default:
        return 'Tente novamente mais tarde ou entre em contato com o suporte.';
    }
  }
}
