import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import '../utils/auth_helper.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Executar validação e correção de estado de forma assíncrona
    _validateAuthState();
    return null;
  }

  /// Valida e corrige estados inconsistentes de autenticação
  /// Especialmente importante para resolver problemas no iPad
  Future<void> _validateAuthState() async {
    try {
      await AuthHelper.validateAndFixState();
    } catch (e) {
      print('AuthMiddleware: Erro ao validar estado de autenticação: $e');
    }
  }
}
