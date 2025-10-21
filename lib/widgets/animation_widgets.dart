import 'package:flutter/material.dart';

class AnimationWidgets {
  // Animação de entrada do MECA
  static Widget buildEnterAnimation({
    double width = 300,
    double height = 300,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/animations/AnimacaoEnter.gif',
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  // Animação de loading do MECA
  static Widget buildLoadingAnimation({
    double width = 150,
    double height = 150,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          'assets/animations/AnimacaoLogoBranca.gif',
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  // Widget de loading completo com mensagem
  static Widget buildLoadingWidget({
    String message = 'Carregando...',
    double size = 150,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildLoadingAnimation(width: size, height: size),
        const SizedBox(height: 20),
        Text(
          message,
          style: const TextStyle(
            color: Color(0xFF00C977),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Splash screen completo
  static Widget buildSplashScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00C977),
            Color(0xFF00B369),
            Color(0xFF00A85C),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildEnterAnimation(width: 350, height: 350),
            const SizedBox(height: 40),
            const Text(
              'MECA',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00C977).withOpacity(0.3),
                    const Color(0xFF00B369).withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Seu carro em boas mãos',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog de loading
  static void showLoadingDialog(BuildContext context, {String message = 'Carregando...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: buildLoadingWidget(message: message),
        ),
      ),
    );
  }

  // Esconder dialog de loading
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}

