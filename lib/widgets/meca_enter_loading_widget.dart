import 'package:flutter/material.dart';
import 'dart:async';

import '../services/api_service.dart';
import '../screens/core/core_screen.dart';
import '../screens/auth/login_screen.dart';

class MecaEnterLoadingWidget extends StatefulWidget {
  const MecaEnterLoadingWidget({Key? key}) : super(key: key);

  @override
  State<MecaEnterLoadingWidget> createState() => _MecaEnterLoadingWidgetState();
}

class _MecaEnterLoadingWidgetState extends State<MecaEnterLoadingWidget> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate some loading time for the animation
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      final token = await _apiService.getToken();
      if (token != null) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const CoreScreen())
        );
      } else {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300, // Aumentado de 200 para 300
              height: 300, // Aumentado de 200 para 300
              child: Image.asset(
                'assets/animations/AnimacaoEnter.gif',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'MECA',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C977),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Seu carro em boas mãos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

