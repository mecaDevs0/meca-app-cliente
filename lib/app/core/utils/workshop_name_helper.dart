import '../../data/models/mechanic_workshop.dart';

class WorkshopNameHelper {
  /// Retorna o nome do estabelecimento seguindo a prioridade:
  /// 1. companyName (se disponível e não vazio, exceto "Oficina Padrão")
  /// 2. fullName formatado (primeiro e último nome)
  /// 3. string vazia (o errorBuilder da imagem cuidará do visual)
  static String getDisplayName(MechanicWorkshop? workshop) {
    if (workshop == null) return '';
    
    // Debug logs
    print('🔧 [WorkshopNameHelper] Workshop ID: ${workshop.id}');
    print('🔧 [WorkshopNameHelper] CompanyName: "${workshop.companyName}"');
    print('🔧 [WorkshopNameHelper] FullName: "${workshop.fullName}"');
    print('🔧 [WorkshopNameHelper] AccountableName: "${workshop.accountableName}"');
    
    // Prioridade 1: companyName (exceto "Oficina Padrão" que é genérico)
    if (workshop.companyName?.isNotEmpty == true && 
        workshop.companyName != 'null' && 
        workshop.companyName != '' &&
        workshop.companyName != 'Oficina Padrão') {
      final name = workshop.companyName!.trim();
      print('🔧 [WorkshopNameHelper] ✅ Usando CompanyName: "$name"');
      return name;
    }
    
    // Prioridade 2: fullName formatado (primeiro e último nome)
    if (workshop.fullName?.isNotEmpty == true && 
        workshop.fullName != 'null' && 
        workshop.fullName != '') {
      final formattedName = _formatFullName(workshop.fullName!.trim());
      print('🔧 [WorkshopNameHelper] ✅ Usando FullName formatado: "$formattedName"');
      return formattedName;
    }
    
    // Prioridade 3: string vazia (o errorBuilder da imagem cuidará do visual)
    print('🔧 [WorkshopNameHelper] ❌ Nenhum nome válido encontrado, retornando string vazia');
    return '';
  }

  /// Formata o nome completo para exibir apenas primeiro e último nome
  static String _formatFullName(String fullName) {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names.first} ${names.last}';
    }
    return fullName;
  }
  
  /// Retorna o nome completo do estabelecimento (sem truncamento)
  static String getFullDisplayName(MechanicWorkshop? workshop) {
    if (workshop == null) return 'Estabelecimento';
    
    // 1. Prioridade para companyName
    if (workshop.companyName?.isNotEmpty == true && 
        workshop.companyName != 'null' && 
        workshop.companyName != '') {
      return workshop.companyName!;
    }
    
    // 2. fullName completo
    if (workshop.fullName?.isNotEmpty == true && 
        workshop.fullName != 'null' && 
        workshop.fullName != '') {
      return workshop.fullName!;
    }
    
    // 3. accountableName como fallback
    if (workshop.accountableName?.isNotEmpty == true && 
        workshop.accountableName != 'null' && 
        workshop.accountableName != '') {
      return workshop.accountableName!;
    }
    
    return 'Estabelecimento';
  }
}
