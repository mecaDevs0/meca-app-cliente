
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mega_commons/shared/models/auth_token.dart';

class AuthHelper {
  static final GetStorage _storage = GetStorage();

  static bool get isGuest {
    final token = AuthToken.fromCache();
    final guestFlag = _storage.read('isGuest') == true;
    
    // Se há um token válido, não pode ser visitante
    if (token != null && token.accessToken?.isNotEmpty == true) {
      if (guestFlag) {
        // Corrige o estado automaticamente
        _storage.write('isGuest', false);
        _storage.write('isLoggedIn', true);
        if (kDebugMode) {
          print('AuthHelper: Corrigindo estado - token válido encontrado, removendo flag de visitante');
        }
      }
      return false;
    }
    
    return guestFlag;
  }

  static bool get isLoggedIn {
    final token = AuthToken.fromCache();
    final loginFlag = _storage.read('isLoggedIn') == true;

    // Se há um token válido, deve estar logado
    if (token != null && token.accessToken?.isNotEmpty == true) {
      if (!loginFlag) {
        // Corrige o estado automaticamente
        _storage.write('isLoggedIn', true);
        _storage.write('isGuest', false);
        if (kDebugMode) {
          print('AuthHelper: Corrigindo estado - token válido encontrado, ativando flag de login');
        }
      }
      return true;
    }

    // Se não há token mas o flag está true, corrige o estado
    if (loginFlag && token == null) {
      _storage.write('isLoggedIn', false);
      _storage.write('isGuest', true);
      if (kDebugMode) {
        print('AuthHelper: Corrigindo estado inconsistente - removendo flag de login sem token');
      }
      return false;
    }

    return loginFlag && token != null;
  }

  /// Método para obter o token de autenticação válido
  static AuthToken? getValidToken() {
    final token = AuthToken.fromCache();
    if (token != null && (token.accessToken?.isNotEmpty ?? false)) {
      return token;
    }
    return null;
  }

  /// Método para verificar se há um token válido disponível
  static bool hasValidToken() {
    return getValidToken() != null;
  }

  static Future<void> setGuest() async {
    await _storage.write('isGuest', true);
    await _storage.write('isLoggedIn', false);
    // Limpa o token ao entrar como convidado
    await AuthToken.remove();
    if (kDebugMode) {
      print('AuthHelper: Estado de convidado ativado');
    }
  }

  static Future<void> clearGuestStatus() async {
    await _storage.write('isGuest', false);
    if (kDebugMode) {
      print('AuthHelper: Estado de convidado removido');
    }
  }

  static Future<void> setLoggedIn() async {
    final token = AuthToken.fromCache();
    if (token != null && token.accessToken?.isNotEmpty == true) {
      await _storage.write('isLoggedIn', true);
      await _storage.write('isGuest', false); // Garante que o modo visitante seja sempre desativado
      if (kDebugMode) {
        print('AuthHelper: Estado de login ativado com token válido');
      }
    } else {
      if (kDebugMode) {
        print('AuthHelper: Tentativa de definir login sem token válido - ignorando');
      }
    }
  }

  static Future<void> logout() async {
    await _storage.write('isLoggedIn', false);
    await _storage.write('isGuest', false);
    await AuthToken.remove();
    if (kDebugMode) {
      print('AuthHelper: Logout realizado - todos os estados limpos');
    }
  }

  /// Método específico para validar e corrigir estados inconsistentes
  /// Útil para resolver problemas específicos do iPad
  static Future<void> validateAndFixState() async {
    final token = AuthToken.fromCache();
    final loginFlag = _storage.read('isLoggedIn') == true;
    final guestFlag = _storage.read('isGuest') == true;

    if (kDebugMode) {
      print('AuthHelper: Validando estado - Token: ${token != null}, Login: $loginFlag, Guest: $guestFlag');
    }

    // Se tem token mas não está marcado como logado
    if (token != null && token.accessToken?.isNotEmpty == true && !loginFlag) {
      await setLoggedIn();
      if (kDebugMode) {
        print('AuthHelper: Corrigido - token válido mas não estava marcado como logado');
      }
    }

    // Se não tem token mas está marcado como logado
    if (token == null && loginFlag) {
      await _storage.write('isLoggedIn', false);
      await _storage.write('isGuest', true);
      if (kDebugMode) {
        print('AuthHelper: Corrigido - sem token mas estava marcado como logado');
      }
    }

    // Se tem token e está marcado como convidado (estado inconsistente)
    if (token != null && token.accessToken?.isNotEmpty == true && guestFlag) {
      await clearGuestStatus();
      await setLoggedIn();
      if (kDebugMode) {
        print('AuthHelper: Corrigido - tinha token mas estava marcado como convidado');
      }
    }
  }

  /// Método para forçar a correção do estado de autenticação
  /// Este método deve ser chamado quando há problemas de identificação de login
  static Future<void> forceFixAuthenticationState() async {
    if (kDebugMode) {
      print('AuthHelper: Forçando correção do estado de autenticação...');
    }
    
    final token = AuthToken.fromCache();
    final loginFlag = _storage.read('isLoggedIn') == true;
    final guestFlag = _storage.read('isGuest') == true;

    if (kDebugMode) {
      print('AuthHelper: Estado atual - Token: ${token != null}, Login: $loginFlag, Guest: $guestFlag');
    }

    // Se há um token válido, forçar o estado de logado
    if (token != null && token.accessToken?.isNotEmpty == true) {
      await _storage.write('isLoggedIn', true);
      await _storage.write('isGuest', false);
      if (kDebugMode) {
        print('AuthHelper: Forçando estado de logado - token válido encontrado');
      }
    } else {
      // Se não há token válido, forçar o estado de convidado
      await _storage.write('isLoggedIn', false);
      await _storage.write('isGuest', true);
      if (kDebugMode) {
        print('AuthHelper: Forçando estado de convidado - nenhum token válido');
      }
    }

    // Verificar o estado final
    final finalLoginFlag = _storage.read('isLoggedIn') == true;
    final finalGuestFlag = _storage.read('isGuest') == true;
    
    if (kDebugMode) {
      print('AuthHelper: Estado final - Login: $finalLoginFlag, Guest: $finalGuestFlag');
    }
  }

  /// Método para limpar completamente o cache e forçar novo estado
  static Future<void> clearAllCache() async {
    if (kDebugMode) {
      print('AuthHelper: Limpando todo o cache de autenticação...');
    }
    
    await _storage.remove('isLoggedIn');
    await _storage.remove('isGuest');
    await AuthToken.remove();
    
    if (kDebugMode) {
      print('AuthHelper: Cache limpo completamente');
    }
  }
}
