import 'dart:developer' as console;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Importando o scheduler para usar o SchedulerBinding
import 'package:get/get.dart';
import 'package:mega_commons/mega_commons.dart';
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
          'Sign in with Apple não está disponível neste dispositivo',
        );
        return;
      }

      // Detectar se está rodando em iPad para ajustes específicos
      final isTablet = MediaQuery.of(Get.context!).size.shortestSide >= 600;
      console.log('Dispositivo detectado como tablet: $isTablet');

      // Configurações específicas para iPad
      WebAuthenticationOptions? webOptions;
      if (isTablet) {
        webOptions = WebAuthenticationOptions(
          clientId: 'com.meca.app.service',
          redirectUri: Uri.parse('https://meca-app.firebaseapp.com/__/auth/handler'),
        );
        console.log('Configurações específicas para iPad aplicadas');
      }

      // Solicitar credenciais do Apple com configuração otimizada
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webOptions,
      );

      console.log('Apple Sign In: Credenciais obtidas com sucesso');
      console.log('Apple Sign In: Identity Token presente: ${credential.identityToken != null}');
      console.log('Apple Sign In: Authorization Code presente: ${credential.authorizationCode != null}');

      // Verificar se temos os tokens necessários
      if (credential.identityToken == null) {
        throw Exception('Token de identidade não foi fornecido pelo Apple');
      }

      // Criar o provider OAuth para apple.com
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      console.log('Apple Sign In: Credential OAuth criado com sucesso');

      // Fazer login no Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(oauthCredential);

      console.log('Firebase Auth: UserCredential obtido: ${userCredential.user != null}');
      console.log('Firebase Auth: User UID: ${userCredential.user?.uid}');

      if (userCredential.user != null) {
        console.log('Firebase Auth: Login com Apple realizado com sucesso');

        // IMPORTANTE: Todas as operações abaixo são movidas para o SchedulerBinding.addPostFrameCallback
        // para evitar o erro de ciclo de vida "setState() or markNeedsBuild() called during build"

        // Adiamos TODAS as operações após a autenticação para o próximo frame
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          try {
            console.log('PostFrameCallback: Iniciando operações pós-autenticação');

            // Obter token do Firebase para autenticação com o backend
            final firebaseToken = await userCredential.user!.getIdToken();
            console.log('Firebase Auth: Token obtido com sucesso (length: ${firebaseToken?.length ?? 0})');

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
            console.log('AuthToken: Token salvo no cache com sucesso');

            // Limpar estado de visitante e configurar como logado
            await AuthHelper.clearGuestStatus();
            await AuthHelper.setLoggedIn();
            console.log('AuthHelper: Estado atualizado - isLoggedIn: ${AuthHelper.isLoggedIn}, isGuest: ${AuthHelper.isGuest}');

            // Navegação explícita após as atualizações de estado
            console.log('Navegando para tela principal...');
            Get.offAllNamed(Routes.home);

            // Feedback visual após login bem-sucedido
            MegaSnackbar.showSuccessSnackBar('Login realizado com sucesso!');

            console.log('PostFrameCallback: Operações pós-autenticação concluídas com sucesso');
          } catch (postFrameError) {
            console.log('Erro nas operações pós-autenticação: ${postFrameError.toString()}');
            MegaSnackbar.showErroSnackBar('Erro ao finalizar o login. Tente novamente.');
          }
        });

        console.log('Login com Apple: Processo iniciado com sucesso, operações pós-autenticação agendadas');
      } else {
        throw Exception('Falha na autenticação com Firebase - userCredential.user é null');
      }

    } on SignInWithAppleAuthorizationException catch (e) {
      console.log('Erro de autorização Apple: ${e.code} - ${e.message}');

      // Tratar erros específicos do Apple Sign In
      String errorMessage;
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          errorMessage = 'Login cancelado pelo usuário';
          console.log('Apple Sign In: Cancelado pelo usuário');
          break;
        case AuthorizationErrorCode.failed:
          errorMessage = 'Falha na autenticação com Apple';
          console.log('Apple Sign In: Falha na autenticação');
          break;
        case AuthorizationErrorCode.invalidResponse:
          errorMessage = 'Resposta inválida do Apple';
          console.log('Apple Sign In: Resposta inválida');
          break;
        case AuthorizationErrorCode.notHandled:
          errorMessage = 'Erro não tratado na autenticação';
          console.log('Apple Sign In: Erro não tratado');
          break;
        case AuthorizationErrorCode.unknown:
        default:
          errorMessage = 'Erro desconhecido na autenticação';
          console.log('Apple Sign In: Erro desconhecido');
          break;
      }

      if (e.code != AuthorizationErrorCode.canceled) {
        MegaSnackbar.showErroSnackBar(errorMessage);
      }

    } on FirebaseAuthException catch (e) {
      console.log('Erro Firebase Auth: ${e.code} - ${e.message}');
      // Log adicional para debugging no iPad
      console.log('Firebase Auth Error Details: ${e.toString()}');

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
      console.log('Erro não tratado no login com Apple: ${e.toString()}');
      MegaSnackbar.showErroSnackBar('Erro ao fazer login com Apple. Tente novamente.');
    }
  }
}
