import 'dart:developer' as console;
import 'dart:async'; // Adicionando importação para TimeoutException

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    // Variável para controlar se o processo já foi concluído (evita callbacks duplicados)
    bool processCompleted = false;

    try {
      // Ativa o indicador de carregamento - usando update() em vez de atribuição direta
      update(); // Atualiza a UI antes de iniciar operações demoradas
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

      // Detectar se está rodando em iPad/tablet para ajustes específicos
      final isTablet = MediaQuery.of(Get.context!).size.shortestSide >= 600;
      console.log('Dispositivo detectado como tablet: $isTablet');

      // Configurações específicas para tablet
      WebAuthenticationOptions? webOptions;
      if (isTablet) {
        webOptions = WebAuthenticationOptions(
          clientId: 'com.meca.app.service',
          redirectUri: Uri.parse('https://meca-app.firebaseapp.com/__/auth/handler'),
        );
        console.log('Configurações específicas para tablet aplicadas');
      }

      // Solicitar credenciais do Apple com configuração otimizada
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webOptions,
      );

      // Se o usuário cancelou o login, saímos sem mostrar erro
      if (credential.identityToken == null || credential.identityToken!.isEmpty) {
        console.log('Login com Apple: Processo cancelado pelo usuário ou token vazio');
        return;
      }

      console.log('Apple Sign In: Credenciais obtidas com sucesso');

      // Criar o provider OAuth para apple.com
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Fazer login no Firebase Auth com timeout
      final userCredential = await FirebaseAuth.instance
          .signInWithCredential(oauthCredential)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Tempo esgotado ao tentar autenticar com Firebase');
            },
          );

      console.log('Firebase Auth: Login bem-sucedido com UID: ${userCredential.user?.uid}');

      if (userCredential.user == null) {
        throw Exception('Usuário não encontrado após autenticação com Firebase');
      }

      // IMPORTANTE: Todas as operações pós-autenticação são movidas para o SchedulerBinding
      // para evitar problemas de ciclo de vida como "setState() called during build"

      // Usamos Future.microtask antes do SchedulerBinding para garantir que
      // encerramos o contexto atual antes de prosseguir
      Future.microtask(() {
        // Somente se o processo não tiver sido completado ainda
        if (!processCompleted) {
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            try {
              // Marcar que o processo está sendo finalizado para evitar execuções duplicadas
              processCompleted = true;
              console.log('PostFrameCallback: Finalizando processo de login Apple');

              // Obter token do Firebase para autenticação com o backend
              final firebaseToken = await userCredential.user!.getIdToken()
                  .timeout(
                    const Duration(seconds: 10),
                    onTimeout: () => throw Exception('Tempo esgotado ao obter token Firebase'),
                  );

              if (firebaseToken == null || firebaseToken.isEmpty) {
                throw Exception('Token Firebase inválido ou vazio');
              }

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
              console.log('AuthToken: Token salvo no cache');

              // Limpar estado de visitante e configurar como logado
              await AuthHelper.clearGuestStatus();
              await AuthHelper.setLoggedIn();

              // Navegação explícita após as atualizações de estado
              console.log('Navegando para a tela principal após login com Apple');
              await Get.offAllNamed(Routes.home);

              // Feedback visual após navegação para evitar sobreposição de UI
              Future.delayed(const Duration(milliseconds: 500), () {
                MegaSnackbar.showSuccessSnackBar('Login realizado com sucesso!');
              });
            } catch (postFrameError) {
              // Em caso de erro na fase de pós-autenticação
              console.log('Erro nas operações pós-autenticação: $postFrameError');

              // Verificar se o contexto ainda é válido antes de mostrar o erro
              if (Get.context != null) {
                MegaSnackbar.showErroSnackBar('Erro ao finalizar o login. Tente novamente.');
              }
            }
          });
        }
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      // Log detalhado para diagnóstico
      console.log('Erro de autorização Apple: [${e.code}] ${e.message}');

      // Tratar erros específicos do Apple Sign In
      if (e.code == AuthorizationErrorCode.canceled) {
        console.log('Login com Apple cancelado pelo usuário');
        return; // Silenciosamente retornar em caso de cancelamento
      }

      // Determinar a mensagem de erro com base no código
      String errorMessage;
      switch (e.code) {
        case AuthorizationErrorCode.failed:
          errorMessage = 'Falha na autenticação com Apple';
          break;
        case AuthorizationErrorCode.invalidResponse:
          errorMessage = 'Resposta inválida do serviço Apple';
          break;
        case AuthorizationErrorCode.notHandled:
          errorMessage = 'Erro não tratado na autenticação Apple';
          break;
        default:
          errorMessage = 'Erro ao tentar login com Apple (${e.code})';
          break;
      }

      // Mostrar erro ao usuário se contexto disponível
      if (Get.context != null) {
        MegaSnackbar.showErroSnackBar(errorMessage);
      }
    } on FirebaseAuthException catch (e) {
      // Log detalhado para diagnóstico
      console.log('Erro Firebase Auth: [${e.code}] ${e.message}');

      // Traduzir erros do Firebase para mensagens amigáveis
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Este e-mail já está associado a outra conta';
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
        default:
          errorMessage = 'Erro na autenticação com Firebase';
          break;
      }

      // Mostrar erro ao usuário se contexto disponível
      if (Get.context != null) {
        MegaSnackbar.showErroSnackBar(errorMessage);
      }
    } catch (e) {
      // Log de erro genérico
      console.log('Erro não tratado no login com Apple: $e');

      if (Get.context != null) {
        MegaSnackbar.showErroSnackBar('Erro ao fazer login com Apple. Tente novamente.');
      }
    }
  }
}
