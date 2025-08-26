import '../../data/models/mechanic_workshop.dart';

class WorkshopNameHelper {
  /// Retorna o nome do estabelecimento seguindo a prioridade:
  /// 1. companyName (se disponível e não vazio)
  /// 2. Primeiro e último nome do fullName (se disponível)
  /// 3. fullName completo (se disponível)
  /// 4. accountableName (se disponível)
  /// 5. Texto padrão
  static String getDisplayName(MechanicWorkshop? workshop) {
    if (workshop == null) return 'Estabelecimento';
    
    // Debug logs
    print('🔧 [WorkshopNameHelper] Workshop ID: ${workshop.id}');
    print('🔧 [WorkshopNameHelper] CompanyName: "${workshop.companyName}"');
    print('🔧 [WorkshopNameHelper] FullName: "${workshop.fullName}"');
    print('🔧 [WorkshopNameHelper] AccountableName: "${workshop.accountableName}"');
    
    // 1. Prioridade para companyName
    if (workshop.companyName?.isNotEmpty == true && 
        workshop.companyName != 'null' && 
        workshop.companyName != '') {
      final name = workshop.companyName!.trim();
      print('🔧 [WorkshopNameHelper] ✅ Usando CompanyName: "$name"');
      return name;
    }
    
    // 2. Extrair primeiro e último nome do fullName
    if (workshop.fullName?.isNotEmpty == true && 
        workshop.fullName != 'null' && 
        workshop.fullName != '') {
      final names = workshop.fullName!.trim().split(' ');
      if (names.length >= 2) {
        final name = '${names.first} ${names.last}';
        print('🔧 [WorkshopNameHelper] ✅ Usando FullName (primeiro + último): "$name"');
        return name;
      } else if (names.length == 1) {
        print('🔧 [WorkshopNameHelper] ✅ Usando FullName (único): "${names.first}"');
        return names.first;
      }
      print('🔧 [WorkshopNameHelper] ✅ Usando FullName completo: "${workshop.fullName!.trim()}"');
      return workshop.fullName!.trim();
    }
    
    // 3. accountableName como fallback
    if (workshop.accountableName?.isNotEmpty == true && 
        workshop.accountableName != 'null' && 
        workshop.accountableName != '') {
      final name = workshop.accountableName!.trim();
      print('🔧 [WorkshopNameHelper] ✅ Usando AccountableName: "$name"');
      return name;
    }
    
    // 4. Se temos ID, usar um nome genérico com o ID
    if (workshop.id?.isNotEmpty == true) {
      final name = 'Estabelecimento #${workshop.id!.substring(0, 8)}';
      print('🔧 [WorkshopNameHelper] ✅ Usando ID genérico: "$name"');
      return name;
    }
    
    print('🔧 [WorkshopNameHelper] ❌ Usando nome padrão: "Estabelecimento"');
    return 'Estabelecimento';
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
