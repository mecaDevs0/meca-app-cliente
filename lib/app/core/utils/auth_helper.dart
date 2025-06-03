import 'package:get_storage/get_storage.dart';

class AuthHelper {
  static final GetStorage _storage = GetStorage();

  static bool get isGuest => _storage.read('isGuest') == true;
  static bool get isLoggedIn => _storage.read('isLoggedIn') == true;

  static void setGuest() {
    _storage.write('isGuest', true);
    _storage.write('isLoggedIn', false);
  }

  static void clearGuestStatus() {
    _storage.write('isGuest', false);
  }

  static void setLoggedIn() {
    _storage.write('isLoggedIn', true);
    _storage.write('isGuest', false);
  }

  static void logout() {
    _storage.write('isLoggedIn', false);
    _storage.write('isGuest', false);
  }
}