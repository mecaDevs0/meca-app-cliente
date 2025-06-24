import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import '../utils/auth_helper.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Check if we have a token but isGuest is still true (inconsistent state)
    final token = AuthToken.fromCache();
    if (token != null && AuthHelper.isGuest) {
      // Fix the inconsistent state
      AuthHelper.clearGuestStatus();
      AuthHelper.setLoggedIn();
      print('AuthMiddleware: Fixed inconsistent state - User has token but was marked as guest');
    }
    return null;
  }
}
