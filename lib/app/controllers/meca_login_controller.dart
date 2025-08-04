import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../services/notification_service.dart';

// Helper class para gerenciar dados de vinculação Google
class GoogleLinkData {
  static const String _keyProviderPrefix = 'google_link_';
  
  static Future<bool> _initializeHiveIfNeeded() async {
    try {
      // Tenta acessar o box padrão
      MegaDataCache.box<String>();
      return true;
    } catch (e) {
      try {
        // Se falhar, tenta inicializar
        await MegaDataCache.initialize();
        return true;
      } catch (initError) {
        console.log('Não foi possível inicializar Hive: $initError', 
            name: 'GoogleLinkData');
        return false;
      }
    }
  }
  
  static Future<void> saveGoogleLinkData(String providerId, String email, String password) async {
    try {
      if (await _initializeHiveIfNeeded()) {
        final box = MegaDataCache.box<String>();
        await box.put('${_keyProviderPrefix}provider_id', providerId);
        await box.put('${_keyProviderPrefix}email', email);
        await box.put('${_keyProviderPrefix}password', password);
        
        console.log('Dados de vinculação Google salvos com sucesso', 
            name: 'GoogleLinkData');
      } else {
        console.log('Hive não disponível - dados de vinculação não foram salvos', 
            name: 'GoogleLinkData');
      }
    } catch (e) {
      console.log('Erro ao salvar dados de vinculação: $e', 
          name: 'GoogleLinkData');
    }
  }
  
  static Future<Map<String, String?>> getGoogleLinkData() async {
    try {
      if (await _initializeHiveIfNeeded()) {
        final box = MegaDataCache.box<String>();
        return {
          'providerId': box.get('${_keyProviderPrefix}provider_id'),
          'email': box.get('${_keyProviderPrefix}email'),
          'password': box.get('${_keyProviderPrefix}password'),
        };
      }
    } catch (e) {
      console.log('Erro ao recuperar dados de vinculação: $e', 
          name: 'GoogleLinkData');
    }
    
    return {
      'providerId': null,
      'email': null,
      'password': null,
    };
  }
  
  static Future<void> clearGoogleLinkData() async {
    try {
      if (await _initializeHiveIfNeeded()) {
        final box = MegaDataCache.box<String>();
        await box.delete('${_keyProviderPrefix}provider_id');
        await box.delete('${_keyProviderPrefix}email');
        await box.delete('${_keyProviderPrefix}password');
        
        console.log('Dados de vinculação Google removidos', 
            name: 'GoogleLinkData');
      }
    } catch (e) {
      console.log('Erro ao limpar dados de vinculação: $e', 
          name: 'GoogleLinkData');
    }
  }
}

class MecaLoginController extends LoginController {
  MecaLoginController({
    required super.loginProvider,
    required super.homeRoute,
    super.isAnonymous = false,
  });

  @override
  Future<void> loginWithGoogle({Function(MegaResponse)? onError}) async {
    await super.loginWithGoogle(onError: onError);
    await _registerDeviceForNotifications();
  }

  Future<void> loginWithGoogleFixed({Function(MegaResponse)? onError}) async {
    try {
      console.log('Iniciando login com Google (versão corrigida)', 
          name: 'MecaLoginController');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        console.log('Login cancelado pelo usuário', 
            name: 'MecaLoginController');
        return;
      }
      
      console.log('Usuário Google selecionado: ${googleUser.email}', 
          name: 'MecaLoginController');
      
      // Verificar se esta conta Google já foi vinculada anteriormente
      final linkData = await GoogleLinkData.getGoogleLinkData();
      final savedProviderId = linkData['providerId'];
      final savedEmail = linkData['email'];
      final savedPassword = linkData['password'];
      
      if (savedProviderId == googleUser.id && 
          savedEmail == googleUser.email && 
          savedPassword != null && savedPassword.isNotEmpty) {
        console.log('Conta Google já vinculada anteriormente, fazendo login automático', 
            name: 'MecaLoginController');
        
        // Fazer login direto com email/senha já que a conta foi vinculada antes
        await _performAutoLogin(googleUser.email, savedPassword);
        return;
      }
      
      // Usar a mesma estrutura do loginWithGoogle original
      final profileToken = ProfileToken(
        fullName: googleUser.displayName,
        email: googleUser.email,
        providerId: googleUser.id,
        typeProvider: 3,
      );
      
      await MegaRequestUtils.load(
        action: () async {
          final loginProvider = Get.find<LoginProvider>();
          final token = await loginProvider.authenticateUserBySocial(profileToken);
          await _processSuccessfulLogin(token, profileToken);
        },
        onError: (error) async {
          console.log('Erro na autenticação social: ${error.message}', 
              name: 'MecaLoginController');
          
          // Se o erro for "usuário não encontrado" mas "email em uso", 
          // significa que é um problema de sincronização
          if (error.message?.contains('Usuário não encontrado') == true ||
              error.data?['isRegister'] == true) {
            
            // Tentar vinculação automática através de login por email
            await _attemptAutoLink(googleUser, profileToken, onError);
            return;
          }
          
          // Para outros erros, usar callback padrão
          if (onError != null) {
            onError(error);
          } else {
            MegaSnackbar.showErroSnackBar(
              error.message ?? 'Erro ao fazer login com Google',
            );
          }
        },
      );
      
      console.log('Login com Google (versão corrigida) concluído com sucesso', 
          name: 'MecaLoginController');
    } catch (e) {
      console.log('Erro no login com Google (versão corrigida): $e', 
          name: 'MecaLoginController');
      if (onError != null) {
        onError(MegaResponse(
          message: e.toString(),
          statusCode: 400,
        ));
      }
    }
  }

  Future<void> _processSuccessfulLogin(AuthToken token, ProfileToken profileToken) async {
    await token.save();
    await isLogged.put('isLogged', true);
    ProfileToken.save(profileToken);
    await _registerDeviceForNotifications();
    Get.offAllNamed('/home');
  }

  Future<void> _attemptAutoLink(GoogleSignInAccount googleUser, ProfileToken profileToken, Function(MegaResponse)? onError) async {
    try {
      console.log('Tentando vinculação automática para: ${googleUser.email}', 
          name: 'MecaLoginController');
      
      // Mostrar diálogo com opções para o usuário
      await Get.dialog(
        AlertDialog(
          title: const Text('Conta Google Encontrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O email ${googleUser.email} já possui uma conta no sistema.'),
              const SizedBox(height: 15),
              const Text('Escolha uma opção:'),
              const SizedBox(height: 10),
              const Text('• Fazer login com senha e vincular automaticamente'),
              const Text('• Continuar com login tradicional'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                _showPasswordDialog(googleUser, profileToken);
              },
              child: const Text('Vincular com Senha'),
            ),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Login Tradicional'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      console.log('Erro na tentativa de vinculação automática: $e', 
          name: 'MecaLoginController');
      
      if (onError != null) {
        onError(MegaResponse(
          message: 'Erro ao tentar vincular conta. Tente fazer login com email e senha.',
          statusCode: 400,
        ));
      }
    }
  }

  Future<void> _showPasswordDialog(GoogleSignInAccount googleUser, ProfileToken googleProfileToken) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    await Get.dialog(
      AlertDialog(
        title: const Text('Vincular Conta Google'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Digite a senha da conta ${googleUser.email}:'),
              const SizedBox(height: 15),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite sua senha';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Get.back();
                await _performAccountLinking(googleUser, googleProfileToken, passwordController.text);
              }
            },
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountLinking(GoogleSignInAccount googleUser, ProfileToken googleProfileToken, String password) async {
    try {
      console.log('Executando vinculação da conta: ${googleUser.email}', 
          name: 'MecaLoginController');
      
      // Primeiro, fazer login com email e senha para validar
      final emailProfileToken = ProfileToken(
        email: googleUser.email,
        password: password,
      );
      
      await MegaRequestUtils.load(
        action: () async {
          final loginProvider = Get.find<LoginProvider>();
          
          // 1. Autenticar com email/senha
          final token = await loginProvider.signInWithEmail(emailProfileToken);
          console.log('Autenticação por email bem-sucedida', 
              name: 'MecaLoginController');
          
          // 2. Completar login PRIMEIRO (salvar token)
          await _processSuccessfulLogin(token, emailProfileToken);
          
          // 3. DEPOIS salvar dados da vinculação localmente
          await GoogleLinkData.saveGoogleLinkData(
            googleProfileToken.providerId!, 
            googleUser.email, 
            password
          );
          
          // 4. Atualizar o perfil com dados do Google
          try {
            await _updateProfileWithGoogleData(googleProfileToken);
            console.log('Perfil atualizado com dados do Google', 
                name: 'MecaLoginController');
          } catch (e) {
            console.log('Aviso: Não foi possível atualizar perfil com dados Google: $e', 
                name: 'MecaLoginController');
            // Continuar mesmo se não conseguir atualizar
          }
          
          MegaSnackbar.showSuccessSnackBar('Conta Google vinculada com sucesso!');
        },
        onError: (error) {
          console.log('Erro na vinculação: ${error.message}', 
              name: 'MecaLoginController');
          
          if (error.message?.toLowerCase().contains('senha') == true || 
              error.message?.toLowerCase().contains('password') == true ||
              error.message?.toLowerCase().contains('credencial') == true) {
            MegaSnackbar.showErroSnackBar('Senha incorreta. Tente novamente.');
          } else {
            MegaSnackbar.showErroSnackBar(
              error.message ?? 'Erro ao vincular conta. Verifique sua senha.',
            );
          }
        },
      );
      
    } catch (e) {
      console.log('Erro geral na vinculação: $e', 
          name: 'MecaLoginController');
      MegaSnackbar.showErroSnackBar('Erro ao vincular conta. Tente novamente.');
    }
  }

  Future<void> _updateProfileWithGoogleData(ProfileToken googleProfileToken) async {
    try {
      // Recuperar o ProfileToken atual do cache
      final currentToken = ProfileToken.fromCache();
      
      if (currentToken != null) {
        // Atualizar com os dados do Google
        currentToken.providerId = googleProfileToken.providerId;
        currentToken.typeProvider = googleProfileToken.typeProvider;
        
        // Salvar o token atualizado
        await ProfileToken.save(currentToken);
        
        console.log('ProviderId ${googleProfileToken.providerId} salvo no ProfileToken local com sucesso', 
            name: 'MecaLoginController');
      } else {
        console.log('ProfileToken não encontrado no cache para atualização', 
            name: 'MecaLoginController');
      }
      
    } catch (e) {
      console.log('Erro ao salvar providerId localmente: $e', 
          name: 'MecaLoginController');
      // Não vamos fazer throw aqui para não interromper o fluxo de login
    }
  }

  Future<void> _performAutoLogin(String email, String password) async {
    try {
      console.log('Fazendo login automático para: $email', 
          name: 'MecaLoginController');
      
      final emailProfileToken = ProfileToken(
        email: email,
        password: password,
      );
      
      await MegaRequestUtils.load(
        action: () async {
          final loginProvider = Get.find<LoginProvider>();
          final token = await loginProvider.signInWithEmail(emailProfileToken);
          await _processSuccessfulLogin(token, emailProfileToken);
          MegaSnackbar.showSuccessSnackBar('Login realizado com sucesso!');
        },
        onError: (error) {
          console.log('Erro no login automático: ${error.message}', 
              name: 'MecaLoginController');
          
          // Se o login automático falhar, limpar os dados salvos e tentar vinculação manual
          GoogleLinkData.clearGoogleLinkData();
          
          MegaSnackbar.showErroSnackBar(
            'Dados de login expiraram. Por favor, vincule sua conta novamente.',
          );
        },
      );
      
    } catch (e) {
      console.log('Erro geral no login automático: $e', 
          name: 'MecaLoginController');
      
      // Se houver erro, limpar dados e mostrar mensagem
      GoogleLinkData.clearGoogleLinkData();
      MegaSnackbar.showErroSnackBar('Erro no login. Tente vincular sua conta novamente.');
    }
  }

  Future<void> _registerDeviceForNotifications() async {
    try {
      console.log('Registrando dispositivo para notificações após login bem-sucedido', 
          name: 'MecaLoginController');
      
      final notificationService = NotificationService();
      await notificationService.registerDeviceOnLogin();
      
      console.log('Dispositivo registrado com sucesso para notificações', 
          name: 'MecaLoginController');
    } catch (e) {
      console.log('Erro ao registrar dispositivo para notificações: $e', 
          name: 'MecaLoginController');
    }
  }
}
