import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricSession {
  BiometricSession({required this.token, required this.userId});

  final String token;
  final String userId;
}

class BiometricAuthService {
  BiometricAuthService._();

  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  static const _tokenKey = 'meca_biometric_token';
  static const _userKey = 'meca_biometric_user';
  static const _enabledKey = 'meca_biometric_enabled';

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasEnabledBiometrics() async {
    final enabled = await _storage.read(key: _enabledKey);
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userKey);
    return enabled == 'true' && token != null && userId != null;
  }

  static Future<void> saveSession(String token, String userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userId);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  static Future<void> disable() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _enabledKey);
  }

  static Future<BiometricSession?> authenticate() async {
    final available = await canUseBiometrics();
    if (!available) return null;

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Use sua biometria para entrar no app',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!didAuthenticate) {
        return null;
      }

      final token = await _storage.read(key: _tokenKey);
      final userId = await _storage.read(key: _userKey);

      if (token == null || userId == null) {
        return null;
      }

      return BiometricSession(token: token, userId: userId);
    } on PlatformException {
      return null;
    }
  }
}





