import 'dart:developer' as console;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_features/app/modules/login/controllers/login_controller.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/utils/auth_helper.dart';
import '../../../routes/app_pages.dart';

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

  /// Implementa o login com Apple integrado ao Firebase Auth
  Future<void> loginWithApple() async {
    try {
      console.log('Iniciando login com Apple...');

      // Verificar se o Sign in with Apple está disponível
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        console.log('Sign in with Apple não está disponível neste dispositivo');
        MegaSnackbar.showErroSnackBar(
          'Sign in with Apple não está disponível neste dispositivo'
        );
        return;
      }

      // Solicitar credenciais do Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      console.log('Apple Sign In: Credenciais obtidas com sucesso');

      // Verificar se temos os tokens necessários
      if (credential.identityToken == null) {
        throw Exception('Token de identidade não foi fornecido pelo Apple');
      }

      // Criar o provider OAuth para apple.com
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Fazer login no Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        console.log('Firebase Auth: Login com Apple realizado com sucesso');

        // Obter token do Firebase para autenticação com o backend
        final firebaseToken = await userCredential.user!.getIdToken();

        // Criar AuthToken com os dados do Firebase
        final authToken = AuthToken(
          accessToken: firebaseToken,
          refreshToken: '', // Firebase gerencia automaticamente
          expiresIn: 3600, // 1 hora (padrão Firebase)
        );

        // Salvar token no cache usando o método correto
        final accessTokenBox = MegaDataCache.box<AuthToken>();
        await accessTokenBox.put(
          AuthToken.cacheBoxKey,
          authToken,
        );

        // Limpar estado de visitante e configurar como logado
        onSuccessfulLogin();

        // Navegar para a tela principal
        Get.offAllNamed(Routes.home);

        // Mostrar mensagem de sucesso
        MegaSnackbar.showSuccessSnackBar('Login realizado com sucesso!');

      } else {
        throw Exception('Falha na autenticação com Firebase');
      }

    } on SignInWithAppleAuthorizationException catch (e) {
      console.log('Erro de autorização Apple: ${e.code} - ${e.message}');

      // Tratar erros específicos do Apple Sign In
      String errorMessage;
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          errorMessage = 'Login cancelado pelo usuário';
          break;
        case AuthorizationErrorCode.failed:
          errorMessage = 'Falha na autenticação com Apple';
          break;
        case AuthorizationErrorCode.invalidResponse:
          errorMessage = 'Resposta inválida do Apple';
          break;
        case AuthorizationErrorCode.notHandled:
          errorMessage = 'Erro não tratado na autenticação';
          break;
        case AuthorizationErrorCode.unknown:
        default:
          errorMessage = 'Erro desconhecido na autenticação';
          break;
      }

      if (e.code != AuthorizationErrorCode.canceled) {
        MegaSnackbar.showErroSnackBar(errorMessage);
      }

    } on FirebaseAuthException catch (e) {
      console.log('Erro Firebase Auth: ${e.code} - ${e.message}');

      // Tratar erros específicos do Firebase
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Já existe uma conta com este e-mail usando outro método de login';
          break;
        case 'invalid-credential':
          errorMessage = 'Credenciais inválidas fornecidas';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Login com Apple não está habilitado';
          break;
        case 'user-disabled':
          errorMessage = 'Esta conta foi desabilitada';
          break;
        case 'user-not-found':
          errorMessage = 'Usuário não encontrado';
          break;
        case 'wrong-password':
          errorMessage = 'Senha incorreta';
          break;
        case 'too-many-requests':
          errorMessage = 'Muitas tentativas de login. Tente novamente mais tarde';
          break;
        default:
          errorMessage = 'Erro na autenticação: ${e.message}';
          break;
      }

      MegaSnackbar.showErroSnackBar(errorMessage);

    } catch (e) {
      console.log('Erro geral no Apple Sign In: $e');
      MegaSnackbar.showErroSnackBar('Erro inesperado durante o login. Tente novamente.');
    }
  }
}
