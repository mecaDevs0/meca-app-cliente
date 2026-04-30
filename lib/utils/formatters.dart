/// Utilitários para formatação de dados
class Formatters {
  /// Formata CPF: 12345678901 -> 123.456.789-01
  static String formatCpf(String? cpf) {
    if (cpf == null || cpf.isEmpty) return 'Não informado';
    
    // Remove caracteres não numéricos
    final digitsOnly = cpf.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 11) {
      // Se não tem 11 dígitos, retorna como está (pode estar parcialmente formatado)
      return cpf;
    }
    
    // Aplica máscara
    return '${digitsOnly.substring(0, 3)}.${digitsOnly.substring(3, 6)}.${digitsOnly.substring(6, 9)}-${digitsOnly.substring(9)}';
  }
  
  /// Formata telefone: 11987654321 -> (11) 98765-4321
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Não informado';
    
    // Remove caracteres não numéricos
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length < 10) {
      // Se não tem pelo menos 10 dígitos, retorna como está
      return phone;
    }
    
    // Aplica máscara
    if (digitsOnly.length == 10) {
      // Telefone fixo: (XX) XXXX-XXXX
      return '(${digitsOnly.substring(0, 2)}) ${digitsOnly.substring(2, 6)}-${digitsOnly.substring(6)}';
    } else {
      // Celular: (XX) XXXXX-XXXX
      return '(${digitsOnly.substring(0, 2)}) ${digitsOnly.substring(2, 7)}-${digitsOnly.substring(7)}';
    }
  }

  static String formatCnpj(String? cnpj) {
    if (cnpj == null || cnpj.isEmpty) return 'Não informado';
    final digitsOnly = cnpj.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 14) return cnpj;
    return '${digitsOnly.substring(0, 2)}.${digitsOnly.substring(2, 5)}.${digitsOnly.substring(5, 8)}/${digitsOnly.substring(8, 12)}-${digitsOnly.substring(12)}';
  }
}

