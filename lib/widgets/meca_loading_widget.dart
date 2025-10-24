import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

class MecaLoadingWidget extends StatefulWidget {
  final String? message;
  final double size;
  
  const MecaLoadingWidget({
    Key? key,
    this.message,
    this.size = 300.0, // Aumentado para 300.0 - muito maior
  }) : super(key: key);

  @override
  State<MecaLoadingWidget> createState() => _MecaLoadingWidgetState();
}

class _MecaLoadingWidgetState extends State<MecaLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimations();
  }

  void _startAnimations() {
    _rotationController.repeat();
    _scaleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                child: Image.asset(
                  'assets/animations/AnimacaoLogoVerde.gif',
                  fit: BoxFit.contain,
                ),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 24),
                Text(
                  widget.message!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: themeService.isDarkMode ? Colors.white : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Widget específico para loading de API
class MecaApiLoadingWidget extends StatelessWidget {
  final String? message;
  
  const MecaApiLoadingWidget({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MecaLoadingWidget(
      message: message ?? 'Carregando...',
      size: 120.0, // Aumentado de 60.0 para 120.0
    );
  }
}

// Widget para loading de entrada do app
class MecaEnterLoadingWidget extends StatelessWidget {
  const MecaEnterLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C977),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MecaLoadingWidget(
              message: 'Bem-vindo ao MECA',
              size: 200.0, // Aumentado de 120.0 para 200.0
            ),
            const SizedBox(height: 40),
            const Text(
              'Seu carro em boas mãos',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
