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
      return false;
    }

    return loginFlag && token != null;
  }

  static Future<void> setGuest() async {
    await _storage.write('isGuest', true);
    await _storage.write('isLoggedIn', false);
    // Limpa o token ao entrar como convidado
    await AuthToken.remove();
  }

  static void clearGuestStatus() {
    _storage.write('isGuest', false);
  }

  static void setLoggedIn() {
    final token = AuthToken.fromCache();
    if (token != null) {
      _storage.write('isLoggedIn', true);
      _storage.write('isGuest', false);
    }
  }

  static void logout() {
    _storage.write('isLoggedIn', false);
    _storage.write('isGuest', false);
    AuthToken.remove();
  }
}
