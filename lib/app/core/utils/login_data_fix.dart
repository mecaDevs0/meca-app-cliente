class LoginDataFix {
  static void logResponse(dynamic data, String path) {
    // Log da resposta para debug
    print('Response for $path: $data');
  }
  
  static bool isSuccessResponse(dynamic data) {
    if (data == null) return false;
    
    if (data is Map<String, dynamic>) {
      return data['success'] == true || 
             data['Success'] == true || 
             data['erro'] == false ||
             data['Erro'] == false;
    }
    
    return false;
  }
  
  static String getErrorMessage(dynamic errorData) {
    if (errorData == null) return 'Erro desconhecido';
    
    if (errorData is Map<String, dynamic>) {
      return errorData['message'] ?? 
             errorData['Message'] ?? 
             errorData['error'] ?? 
             errorData['Error'] ?? 
             'Erro desconhecido';
    }
    
    return errorData.toString();
  }
}
