import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mega_commons/shared/models/auth_token.dart';

class AuthHelper {
  static final GetStorage _storage = GetStorage();

  static bool get isGuest => _storage.read('isGuest') == true;

  static bool get isLoggedIn {
    final bool loginFlag = _storage.read('isLoggedIn') == true;
    final token = AuthToken.fromCache();

    // Se não há token mas o flag está true, corrige o estado
    if (loginFlag && token == null) {
      _storage.write('isLoggedIn', false);
      if (kDebugMode) {
        print('AuthHelper: Corrigindo estado inconsistente - removendo flag de login sem token');
      }
      return false;
    }

    return loginFlag && token != null;
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
    if (token != null) {
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
    if (token != null && !loginFlag) {
      await setLoggedIn();
      if (kDebugMode) {
        print('AuthHelper: Corrigido - token válido mas não estava marcado como logado');
      }
    }

    // Se não tem token mas está marcado como logado
    if (token == null && loginFlag) {
      await _storage.write('isLoggedIn', false);
      if (kDebugMode) {
        print('AuthHelper: Corrigido - sem token mas estava marcado como logado');
      }
    }

    // Se tem token e está marcado como convidado (estado inconsistente)
    if (token != null && guestFlag) {
      await clearGuestStatus();
      await setLoggedIn();
      if (kDebugMode) {
        print('AuthHelper: Corrigido - tinha token mas estava marcado como convidado');
      }
    }
  }
}
