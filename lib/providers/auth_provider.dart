import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get customerData => _user;

  Future<void> init() async {
    await _apiService.loadToken();
    // Verificar se o token é válido
    _isAuthenticated = false; // Implementar verificação real
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      if (response.statusCode == 200) {
        final data = response.data;
        await _apiService.setToken(data['token']);
        _user = data['user'];
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await _apiService.register(name, email, password);
      if (response.statusCode == 201) {
        return await login(email, password);
      }
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }
}

