import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/cpf_formatter.dart';
import '../../widgets/app_alerts.dart';
import '../../widgets/meca_loading_widget.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final ApiService _apiService = ApiService();
  late final GoogleSignIn _googleSignIn;
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: Platform.isIOS ? AppConfig.googleClientIdIos : null,
      serverClientId: AppConfig.googleClientIdWeb,
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isLogin = _tabController.index == 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> result;

    if (_isLogin) {
      result = await _apiService.login(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      result = await _apiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        _cpfController.text.replaceAll(RegExp(r'\D'), ''),
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!_isLogin) {
        if (!mounted) return;
        AppAlerts.showSuccess(
          context,
          message: 'Conta criada com sucesso! Faça login para continuar.',
          title: 'Cadastro concluído',
        );
        _tabController.animateTo(0);
      } else {
        await _onLoginSuccess();
      }
    } else {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: result['error'] ?? 'Não conseguimos concluir sua solicitação agora. Tente novamente em instantes.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00C977),
              Color(0xFF00B369),
              Color(0xFF00A85C),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Logo Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'assets/logos/icone_branco.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'MECA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Seu carro em boas mãos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Tab Bar for Login/Register
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFF00C977),
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                    ),
                    tabs: const [
                      Tab(text: 'Entrar'),
                      Tab(text: 'Cadastrar'),
                    ],
                  ),
                ),
              ),

              // Form Section
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Login Form
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira seu email';
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                    return 'Por favor, insira um email válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira sua senha';
                                  }
                                  if (value.length < 6) {
                                    return 'A senha deve ter pelo menos 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Esqueceu a senha?',
                                    style: TextStyle(color: Color(0xFF00C977)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              _isLoading
                                  ? const MecaApiLoadingWidget(message: 'Entrando...')
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _handleSubmit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00C977),
                                          elevation: 3,
                                          shadowColor: const Color(0xFF00C977).withOpacity(0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                        ),
                                        child: const Text(
                                          'Entrar',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 30),
                              if (_isLogin) _buildSocialButtons(),
                            ],
                          ),
                        ),

                        // Register Form
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome Completo',
                                  prefixIcon: Icon(Icons.person),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira seu nome';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira seu email';
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                    return 'Por favor, insira um email válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Telefone',
                                  prefixIcon: Icon(Icons.phone),
                                  hintText: '(XX) XXXXX-XXXX',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  PhoneInputFormatter(),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira seu telefone';
                                  }
                                  if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
                                    return 'Por favor, insira um telefone válido com DDD';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _cpfController,
                                decoration: const InputDecoration(
                                  labelText: 'CPF *',
                                  prefixIcon: Icon(Icons.badge),
                                  hintText: '000.000.000-00',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  CpfFormatter(),
                                  LengthLimitingTextInputFormatter(14), // 000.000.000-00 = 14 caracteres
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira seu CPF';
                                  }
                                  // Remove pontos e traços para contar apenas dígitos
                                  final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                                  if (digitsOnly.length != 11) {
                                    return 'CPF deve ter 11 dígitos';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                style: const TextStyle(color: Colors.black),
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira sua senha';
                                  }
                                  if (value.length < 6) {
                                    return 'A senha deve ter pelo menos 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              _isLoading
                                  ? const MecaApiLoadingWidget(message: 'Entrando...')
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _handleSubmit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00C977),
                                          elevation: 3,
                                          shadowColor: const Color(0xFF00C977).withOpacity(0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cadastrar',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons() {
    final dividerColor = Colors.grey.shade300;
    final showApple = Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: dividerColor)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou continue com',
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Divider(color: dividerColor)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: dividerColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    _GoogleLogo(size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Google',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: showApple ? (_isLoading ? null : _handleAppleSignIn) : null,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  disabledForegroundColor: Colors.white70,
                  disabledBackgroundColor: Colors.black26,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      showApple ? 'Apple' : 'Apple (iOS)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Usamos apenas dados oficiais do Google/Apple para autenticar na plataforma MECA.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Não foi possível obter o token do Google.');
      }

      final displayName = account.displayName?.trim();
      String? firstName;
      String? lastName;
      if (displayName != null && displayName.isNotEmpty) {
        final parts = displayName.split(RegExp(r'\s+'));
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }

      final result = await _apiService.loginWithGoogle(
        idToken: idToken,
        firstName: firstName,
        lastName: lastName,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        await _onLoginSuccess();
      } else {
        _showError(result['error'] ?? 'Erro ao autenticar com o Google.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao autenticar com o Google. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading || !Platform.isIOS) return;
    setState(() => _isLoading = true);
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _showError('Sign in with Apple não está disponível neste dispositivo.');
        return;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw Exception('Não foi possível obter o token da Apple.');
      }

      final fullNameParts = [
        credential.givenName,
        credential.familyName,
      ].where((value) => value != null && value.trim().isNotEmpty).join(' ').trim();

      final result = await _apiService.loginWithApple(
        identityToken: identityToken,
        email: credential.email,
        fullName: fullNameParts.isEmpty ? null : fullNameParts,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        await _onLoginSuccess();
      } else {
        _showError(result['error'] ?? 'Erro ao autenticar com a Apple.');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      if (!mounted) return;
      final details = e.message.trim();
      _showError(
        details.isEmpty
            ? 'Erro ao autenticar com a Apple.'
            : 'Erro ao autenticar com a Apple. $details',
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Erro ao autenticar com a Apple. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onLoginSuccess() async {
    if (!mounted) return;
    Provider.of<NotificationProvider>(context, listen: false).clearAll();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showError(String message) {
    if (!mounted) return;
    AppAlerts.showError(context, message: message);
  }

}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    void drawArc(Color color, double startDeg, double sweepDeg) {
      paint.color = color;
      canvas.drawArc(rect, _degToRad(startDeg), _degToRad(sweepDeg), false, paint);
    }

    drawArc(const Color(0xFF4285F4), -45, 90);
    drawArc(const Color(0xFFDB4437), 45, 90);
    drawArc(const Color(0xFFF4B400), 135, 90);
    drawArc(const Color(0xFF0F9D58), 225, 90);

    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.32, size.width * 0.25, size.height * 0.36),
      whitePaint,
    );

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width * 0.78, size.height * 0.5),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  double _degToRad(double degrees) => degrees * math.pi / 180;
}