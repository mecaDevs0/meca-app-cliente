class LoginProviderWrapper {
  final dynamic loginProvider;
  
  LoginProviderWrapper(this.loginProvider);
  
  Future<dynamic> authenticateUserBySocial(dynamic profileToken) async {
    try {
      return await loginProvider.authenticateUserBySocial(profileToken);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<dynamic> signInWithEmail(dynamic profileToken) async {
    try {
      return await loginProvider.signInWithEmail(profileToken);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<dynamic> loginWithGoogle() async {
    try {
      return await loginProvider.loginWithGoogle();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<dynamic> loginWithFacebook() async {
    try {
      return await loginProvider.loginWithFacebook();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<dynamic> loginWithApple() async {
    try {
      return await loginProvider.loginWithApple();
    } catch (e) {
      rethrow;
    }
  }
}
