import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../services/services_screen.dart';
import '../workshops/workshops_screen.dart';

/// Wrapper para animação de entrada com delay (slide up + fade in)
class _DelayedSlideIn extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _DelayedSlideIn({required this.delayMs, required this.child});

  @override
  State<_DelayedSlideIn> createState() => _DelayedSlideInState();
}

class _DelayedSlideInState extends State<_DelayedSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Balão de chat premium (MIA ou usuário) – design Apple/C6 Bank
class MiaChatBubble extends StatelessWidget {
  final String text;
  final bool isBot;
  final int index;
  final bool showAvatar;
  /// Delay em ms antes da animação de entrada (200-400ms para efeito conversacional)
  final int animationDelayMs;

  const MiaChatBubble({
    super.key,
    required this.text,
    required this.isBot,
    this.index = 0,
    this.showAvatar = true,
    this.animationDelayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleContent = _buildBubbleInner();
    if (animationDelayMs > 0) {
      return _DelayedSlideIn(
        delayMs: animationDelayMs,
        child: bubbleContent,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: bubbleContent,
    );
  }

  Widget _buildBubbleInner() {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot && showAvatar) buildBotAvatar(),
            if (isBot && showAvatar) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isBot ? const Color(0xFF1A1F1C) : const Color(0xFF1B4D30),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isBot ? 4 : 20),
                    bottomRight: Radius.circular(isBot ? 20 : 4),
                  ),
                  boxShadow: isBot
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00C977).withOpacity(0.06),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                  border: isBot ? null : Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: isBot ? Colors.white.withOpacity(0.9) : Colors.white,
                  ),
                ),
              ),
            ),
            if (!isBot && showAvatar) const SizedBox(width: 8),
            if (!isBot && showAvatar) _buildUserAvatar(),
          ],
        ),
      );
  }

  static Widget _buildUserAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00C977).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFF00C977),
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  static Widget buildBotAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: SizedBox(
            width: 36,
            height: 36,
            child: SvgPicture.asset(
              'assets/images/MIA.svg',
              fit: BoxFit.cover,
              placeholderBuilder: (_) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.greenAccent.withOpacity(0.95),
                      const Color(0xFF00B369),
                    ],
                  ),
                ),
                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de ação abaixo da bolha MIA: "Buscar oficinas para [categoria]"
class _MiaActionButton extends StatelessWidget {
  final String category;
  final String? serviceId;
  final VoidCallback onPressed;

  const _MiaActionButton({
    required this.category,
    this.serviceId,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 46, bottom: 8),
      child: Material(
        color: const Color(0xFF00C977),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(Icons.build_circle, size: 20, color: const Color(0xFF0D0F0E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buscar oficinas para $category',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D0F0E),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card de veículo em estilo glassmorphism premium
class VehicleSelectorCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final bool isSelected;
  final VoidCallback onTap;
  final int animationIndex;

  const VehicleSelectorCard({
    super.key,
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final model = '${vehicle['model'] ?? vehicle['name'] ?? 'Veículo'}';
    final year = '${vehicle['year'] ?? vehicle['ano'] ?? ''}'.trim();
    final km = '${vehicle['mileage'] ?? vehicle['km'] ?? vehicle['odometer'] ?? ''}'.trim();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (80 * (animationIndex % 4).clamp(0, 3))),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.greenAccent.withOpacity(0.1),
            highlightColor: Colors.greenAccent.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              width: 180,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.greenAccent.withOpacity(0.5)
                      : Colors.greenAccent.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00C977).withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_rounded, color: Colors.greenAccent.withOpacity(0.9), size: 20),
                  const SizedBox(height: 12),
                  Text(
                    model,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (year.isNotEmpty || km.isNotEmpty)
                    Text(
                      [if (year.isNotEmpty) year, if (km.isNotEmpty) '$km km'].join(' • '),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header compacto estilo iMessage/Telegram – Row horizontal, frosted glass
const double _kMiaHeaderHeight = 56;

class _MiaPremiumHeader extends StatelessWidget {
  const _MiaPremiumHeader();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0E).withOpacity(0.6),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _kMiaHeaderHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  _buildAvatarWithOnlineStatus(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MIA',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF00C977),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Online agora',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.greenAccent.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWithOnlineStatus() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.transparent,
          child: ClipOval(
            child: SizedBox(
              width: 36,
              height: 36,
              child: SvgPicture.asset(
                'assets/images/MIA.svg',
                fit: BoxFit.cover,
                placeholderBuilder: (_) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withOpacity(0.95),
                        const Color(0xFF00B369),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0D0F0E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mensagem no chat
class _ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;
  final String? suggestedCategory;
  final String? suggestedServiceId;

  _ChatMessage({
    required this.text,
    required this.isBot,
    DateTime? time,
    this.suggestedCategory,
    this.suggestedServiceId,
  }) : time = time ?? DateTime.now();
}

/// MIA - MECA Intelligent Assistant - Chat Screen (estilo C6 Bank)
class MiaChatScreen extends StatefulWidget {
  const MiaChatScreen({Key? key}) : super(key: key);

  @override
  State<MiaChatScreen> createState() => _MiaChatScreenState();
}

class _MiaChatScreenState extends State<MiaChatScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  String _flowState = 'vehicle_selection';
  bool _isTypingIndicator = false;
  String? _suggestedServiceId;
  String? _suggestedServiceName;
  bool _vehiclesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() => _vehiclesLoading = true);
    final result = await _apiService.getUserVehicles();
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      if (data is List) {
        list = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    setState(() {
      _vehicles = list;
      _vehiclesLoading = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addBotMessage(String text, {VoidCallback? onComplete, String? suggestedCategory, String? suggestedServiceId}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isBot: true,
        suggestedCategory: suggestedCategory,
        suggestedServiceId: suggestedServiceId,
      ));
      _scrollToBottom();
    });
    if (onComplete != null) {
      Future.delayed(const Duration(milliseconds: 400), onComplete);
    }
  }

  void _selectVehicle(Map<String, dynamic> v) {
    if (_flowState != 'vehicle_selection') return;
    setState(() {
      _selectedVehicle = v;
      _flowState = 'vehicle_selected';
    });
  }

  /// Spec: usuário clica "Confiar" ou "Avançar" após selecionar o veículo
  void _confirmVehicle() {
    final v = _selectedVehicle;
    if (v == null || _flowState != 'vehicle_selected') return;
    HapticFeedback.mediumImpact();
    setState(() => _flowState = 'await_problem');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
    final model = (v['model'] ?? v['name'] ?? 'Seu veículo').toString();
    final yearStr = (v['year'] ?? v['ano'] ?? '').toString().trim();
    final kmStr = (v['mileage'] ?? v['km'] ?? v['odometer'] ?? '').toString().trim();
    final display = [model, if (yearStr.isNotEmpty) '($yearStr)', if (kmStr.isNotEmpty) '$kmStr km'].join(' ');
    _addBotMessage(
      'Entendido! Vamos analisar o seu ${display.trim()}.\n\nPor favor, descreva em detalhes o que está acontecendo com ele.',
      onComplete: () => _scrollToBottom(),
    );
  }

  Future<void> _sendProblem() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _flowState != 'await_problem') return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _inputController.clear();
      _flowState = 'loading';
      _isTypingIndicator = true;
    });
    _scrollToBottom();

    final v = _selectedVehicle ?? {};
    final vehicleModel = v['model'] ?? v['name'] ?? 'Veículo';
    final vehicleYear = (v['year'] ?? v['ano'] ?? '').toString();
    final vehicleKm = (v['mileage'] ?? v['km'] ?? v['odometer'] ?? '').toString();

    Map<String, dynamic> result;
    try {
      final resultFuture = _apiService.getAIDiagnostics(
        vehicleModel: vehicleModel,
        vehicleYear: vehicleYear,
        vehicleKm: vehicleKm,
        problemDescription: text,
      );
      const minTypingDuration = Duration(milliseconds: 1500);
      final stopwatch = Stopwatch()..start();
      result = await resultFuture;
      final elapsed = stopwatch.elapsed;
      if (elapsed < minTypingDuration && mounted) {
        await Future.delayed(minTypingDuration - elapsed);
      }
    } catch (e) {
      result = {'success': false, 'error': 'Ops, tive um problema de conexão. Pode tentar novamente?'};
    }

    if (!mounted) return;
    setState(() => _isTypingIndicator = false);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      final diagnosis = data['diagnosis'] ?? 'Diagnóstico não disponível.';
      final serviceId = data['suggestedServiceId']?.toString();
      final serviceName = data['suggestedCategory']?.toString() ?? data['suggestedServiceName']?.toString() ?? 'Manutenção';
      setState(() {
        _suggestedServiceId = serviceId;
        _suggestedServiceName = serviceName;
        _flowState = 'done';
      });
      _addBotMessage(
        diagnosis,
        suggestedCategory: serviceName,
        suggestedServiceId: serviceId,
        onComplete: () => _scrollToBottom(),
      );
    } else {
      setState(() => _flowState = 'await_problem');
      _addBotMessage(
        result['error'] ?? 'Ops, tive um problema de conexão. Pode tentar novamente?',
        onComplete: () => _scrollToBottom(),
      );
    }
  }

  void _goToWorkshops() {
    _goToWorkshopsWithParams(_suggestedServiceId, _suggestedServiceName ?? 'Manutenção');
  }

  void _goToWorkshopsWithParams(String? serviceId, String categoryName) {
    if (serviceId != null && serviceId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkshopsScreen(
            initialServiceId: serviceId,
            initialServiceName: categoryName,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ServicesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          backgroundColor: const Color(0xFF0D0F0E),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _vehiclesLoading && _flowState == 'vehicle_selection'
                              ? _buildLoadingState(context)
                              : (_flowState == 'vehicle_selection' || _flowState == 'vehicle_selected')
                                  ? _buildVehicleSelection(context, isDark)
                                  : _buildChatArea(context, isDark),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: const _MiaPremiumHeader(),
                    ),
                  ],
                ),
              ),
              if (_flowState == 'vehicle_selected' || _flowState == 'await_problem' || _flowState == 'loading' || _flowState == 'done')
                _buildInputArea(isDark),
            ],
          ),
        );
      },
    );
  }

  double get _contentTopPadding =>
      _kMiaHeaderHeight + MediaQuery.of(context).padding.top;

  Widget _buildLoadingState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: _contentTopPadding),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF00C977), strokeWidth: 2.5),
                const SizedBox(height: 20),
                Text(
                  'Carregando seus veículos...',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSelection(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: _contentTopPadding + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiaChatBubble(
            text: 'Olá! Sou a MIA, sua assistente automotiva. Para começar o diagnóstico, selecione o veículo que vamos analisar.',
            isBot: true,
            index: 0,
            animationDelayMs: 280,
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecione:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (_vehicles.isEmpty)
                  _buildEmptyVehicles(isDark)
                else
                  SizedBox(
                    height: 142,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _vehicles.length,
                      itemBuilder: (context, i) {
                        final v = _vehicles[i];
                        return VehicleSelectorCard(
                          vehicle: v,
                          isSelected: _selectedVehicle == v,
                          onTap: () => _selectVehicle(v),
                          animationIndex: i,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVehicles(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C977).withOpacity(0.04),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_car,
                  size: 64,
                  color: Colors.white.withOpacity(0.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum veículo encontrado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cadastre um veículo para iniciar o diagnóstico',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: const Color(0xFF00C977),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 20, color: const Color(0xFF0D0F0E)),
                          const SizedBox(width: 10),
                          Text(
                            'Cadastrar Novo Veículo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D0F0E),
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
      ),
    );
  }

  Widget _buildChatArea(BuildContext context, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: _contentTopPadding + 20,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      itemCount: _messages.length + (_isTypingIndicator ? 1 : 0),
      itemBuilder: (context, i) {
        if (_isTypingIndicator && i == _messages.length) {
          return _buildTypingIndicator(isDark);
        }
        final msg = _messages[i];
        return _buildMessageBubble(msg, isDark, i);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, bool isDark, int index) {
    final category = msg.suggestedCategory;
    final serviceId = msg.suggestedServiceId;
    final showActionButton = msg.isBot && (category != null && category.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MiaChatBubble(
          text: msg.text,
          isBot: msg.isBot,
          index: index,
          animationDelayMs: (index == 0 && _messages.length == 1) ? 150 : 0,
        ),
        if (showActionButton) ...[
          const SizedBox(height: 12),
          _MiaActionButton(
            category: category!,
            serviceId: serviceId,
            onPressed: () => _goToWorkshopsWithParams(serviceId, category),
          ),
        ],
      ],
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MiaChatBubble.buildBotAvatar(),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F1C),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C977).withOpacity(0.06),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    // Spec: botão "Confiar" ou "Avançar" após seleção do veículo
    if (_flowState == 'vehicle_selected') {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0D0D0D) : Colors.white).withOpacity(0.85),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFF00C977),
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: _confirmVehicle,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 22, color: const Color(0xFF0D0F0E)),
                          const SizedBox(width: 10),
                          Text(
                            'Confirmar Veículo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D0F0E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0D0D0D) : Colors.white).withOpacity(0.88),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_flowState == 'done') ...[
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _flowState = 'await_problem';
                    _inputController.clear();
                    _messages.add(_ChatMessage(
                      text: 'Descreva o próximo problema para analisarmos.',
                      isBot: true,
                    ));
                    _scrollToBottom();
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Fazer outro diagnóstico',
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    enabled: _flowState == 'await_problem' && !_isTypingIndicator,
                    decoration: InputDecoration(
                      hintText: 'Descreva o problema...',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendProblem(),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: (_flowState == 'await_problem' && !_isTypingIndicator)
                      ? const Color(0xFF00C977)
                      : Colors.grey[400],
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: (_flowState == 'await_problem' && !_isTypingIndicator)
                        ? _sendProblem
                        : null,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final progress = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final peak = (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
            final scale = 0.75 + 0.35 * peak;
            final opacity = 0.6 + 0.4 * peak;
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C977).withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
