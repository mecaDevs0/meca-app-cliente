import 'dart:developer' as console;

import 'package:get/get.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_features/app/modules/login/controllers/login_controller.dart';

import '../core/utils/auth_helper.dart';
import '../routes/app_pages.dart';

/// Esta extensão adiciona funcionalidade adicional ao LoginController
/// do pacote mega_features para corrigir o problema de estado do modo visitante.
extension LoginControllerExtension on LoginController {
  /// Método que deve ser chamado após um login bem-sucedido para garantir
  /// que o estado de visitante seja limpo corretamente
  void onSuccessfulLogin() {
    final token = AuthToken.fromCache();
    
    if (token != null) {
      // Garante que o status de visitante seja removido
      AuthHelper.clearGuestStatus();
      // Configura o usuário como logado
      AuthHelper.setLoggedIn();
      
      console.log('LoginControllerExtension: Usuário logado com sucesso, estado de visitante limpo');
    } else {
      console.log('LoginControllerExtension: Token não encontrado após login');
    }
  }
}
