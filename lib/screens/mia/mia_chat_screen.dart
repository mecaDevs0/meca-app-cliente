import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../services/services_screen.dart';
import '../workshops/workshops_screen.dart';

/// Mensagem no chat
class _ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.isBot,
    DateTime? time,
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
  String _flowState = 'vehicle_selection'; // vehicle_selection | vehicle_selected | await_problem | loading | done
  bool _isTypingIndicator = false;
  bool _hasUsedPrompt = false; // Limite: 1 prompt por cliente
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

  void _addBotMessage(String text, {VoidCallback? onComplete}) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: true));
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
    if (text.isEmpty || _flowState != 'await_problem' || _hasUsedPrompt) return;

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

    final result = await _apiService.getAIDiagnostics(
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleKm: vehicleKm,
      problemDescription: text,
    );

    if (!mounted) return;
    setState(() => _isTypingIndicator = false);

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      final diagnosis = data['diagnosis'] ?? 'Diagnóstico não disponível.';
      final serviceId = data['suggestedServiceId']?.toString();
      final serviceName = data['suggestedServiceName']?.toString() ?? 'Manutenção';
      setState(() {
        _suggestedServiceId = serviceId;
        _suggestedServiceName = serviceName;
        _flowState = 'done';
        _hasUsedPrompt = true;
      });
      _addBotMessage(diagnosis, onComplete: () => _scrollToBottom());
    } else {
      setState(() {
        _flowState = 'await_problem';
        _hasUsedPrompt = true; // 1 prompt max - mesmo em erro (429, 503, etc.)
      });
      _addBotMessage(
        result['error'] ?? 'Não foi possível gerar o diagnóstico. Tente novamente.',
        onComplete: () => _scrollToBottom(),
      );
    }
  }

  void _goToWorkshops() {
    if (_suggestedServiceId != null && _suggestedServiceId!.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkshopsScreen(
            initialServiceId: _suggestedServiceId,
            initialServiceName: _suggestedServiceName,
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
          backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C977), Color(0xFF00B369)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MIA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF00C977),
                  ),
                ),
                Text(
                  ' • Diagnóstico Inteligente',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: _vehiclesLoading && _flowState == 'vehicle_selection'
                    ? _buildLoadingState()
                    : (_flowState == 'vehicle_selection' || _flowState == 'vehicle_selected')
                        ? _buildVehicleSelection(isDark)
                        : _buildChatArea(isDark),
              ),
              (_flowState == 'vehicle_selected' || _flowState == 'await_problem' || _flowState == 'loading' || _flowState == 'done')
                  ? _buildInputArea(isDark)
                  : const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00C977)),
          const SizedBox(height: 16),
          Text(
            'Carregando seus veículos...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelection(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBotBubble(
            'Olá! Sou a MIA, sua assistente automotiva. Para começar o diagnóstico, selecione o veículo que vamos analisar.',
            isDark,
          ),
          const SizedBox(height: 24),
          Text(
            'Seus veículos',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum veículo cadastrado',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cadastre um veículo no seu perfil para usar o diagnóstico.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _vehicles.length,
                itemBuilder: (context, i) {
                  final v = _vehicles[i];
                  final model = '${v['model'] ?? v['name'] ?? 'Veículo'}';
                  final year = '${v['year'] ?? v['ano'] ?? ''}'.trim();
                  final km = '${v['mileage'] ?? v['km'] ?? v['odometer'] ?? ''}'.trim();
                  final isSelected = _selectedVehicle == v;
                  return GestureDetector(
                    onTap: () => _selectVehicle(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      width: 180,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00C977).withOpacity(0.15)
                            : (isDark ? Colors.white10 : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00C977)
                              : (isDark ? Colors.white24 : Colors.grey[300]!),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, color: const Color(0xFF00C977), size: 28),
                          const SizedBox(height: 8),
                          Text(
                            model,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (year.isNotEmpty || km.isNotEmpty)
                            Text(
                              [if (year.isNotEmpty) year, if (km.isNotEmpty) '$km km'].join(' • '),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatArea(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: msg.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.isBot)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C977), Color(0xFF00B369)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: msg.isBot
                      ? (isDark ? Colors.white12 : Colors.white)
                      : const Color(0xFF00C977).withOpacity(0.15),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(msg.isBot ? 4 : 18),
                    bottomRight: Radius.circular(msg.isBot ? 18 : 4),
                  ),
                  border: Border.all(
                    color: msg.isBot
                        ? (isDark ? Colors.white24 : Colors.grey[200]!)
                        : const Color(0xFF00C977).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (!msg.isBot) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C977), Color(0xFF00B369)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey[200]!,
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble(String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C977), Color(0xFF00B369)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey[200]!,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(bool isDark) {
    // Spec: botão "Confiar" ou "Avançar" após seleção do veículo
    if (_flowState == 'vehicle_selected') {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmVehicle,
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: const Text('Confiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_flowState == 'done' && _suggestedServiceId != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToWorkshops,
                  icon: const Icon(Icons.build_circle, size: 20),
                  label: Text('Buscar oficinas para ${_suggestedServiceName ?? 'este serviço'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
                    enabled: _flowState == 'await_problem' && !_isTypingIndicator && !_hasUsedPrompt,
                    decoration: InputDecoration(
                      hintText: _hasUsedPrompt ? 'Diagnóstico concluído' : 'Descreva o problema...',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
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
                  color: (_flowState == 'await_problem' && !_isTypingIndicator && !_hasUsedPrompt)
                      ? const Color(0xFF00C977)
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: (_flowState == 'await_problem' && !_isTypingIndicator && !_hasUsedPrompt)
                        ? _sendProblem
                        : null,
                    borderRadius: BorderRadius.circular(24),
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
            final scale = 0.6 + 0.4 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.6 + 0.4 * scale),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
