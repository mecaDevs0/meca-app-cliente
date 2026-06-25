import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../widgets/meca_toast.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/meca_loading_widget.dart';
import '../mia/mia_chat_screen.dart';
import '../mia/mia_onboarding_sheet.dart';
import '../services/services_screen.dart';
import '../workshops/workshop_detail_screen.dart';
import '../workshops/workshops_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _inProgressBookings = [];
  List<Map<String, dynamic>> _nearbyWorkshops = [];
  List<dynamic> _maintenanceReminders = [];
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService.instance;
  Position? _currentPosition;
  bool _locationPermissionDenied = false;
  bool _locationPermissionDeniedForever = false;
  bool _locationServicesDisabled = false;
  bool _isInSaoPaulo = false;
  bool _checkingLocation = false;
  /// True quando a lista de oficinas próximas foi obtida com coordenadas de fallback (ex.: São Paulo) por falta de permissão/posição.
  bool _usedFallbackLocationForNearby = false;
  static const double _nearbyWorkshopsRadiusKm = 30.0; // Ajuste 4: raio 30km na home

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData(forceRefresh: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IMPORTANTE: Recarregar dados quando a tela volta ao foco (após aprovar orçamento, etc)
    // Mas apenas se não foi chamado recentemente (evitar loop infinito)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData(forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _upcomingBookings = [];
      _inProgressBookings = [];
      _nearbyWorkshops = [];
      _maintenanceReminders = [];
      _usedFallbackLocationForNearby = false;
    });

    if (forceRefresh) _apiService.invalidateBookingsCache();

    try {
      // Paralelizar: agendamentos, lembretes e localização+oficinas ao mesmo tempo
      final futureBookings = _apiService.getBookings();
      final futureLocationAndNearby = _loadLocationAndNearby();
      final futureReminders = _apiService.getMaintenanceReminders();

      await Future.wait([futureBookings, futureLocationAndNearby, futureReminders]);

      // Load maintenance reminders (non-blocking)
      if (mounted) {
        try {
          final reminders = await futureReminders;
          if (mounted) {
            setState(() {
              _maintenanceReminders = reminders.take(3).toList();
            });
          }
        } catch (_) {
          // Silently ignore maintenance reminders errors
        }
      }

      if (!mounted) return;
      final bookingsResponse = await futureBookings;
      if (bookingsResponse['success']) {
        final data = bookingsResponse['data'];
        final bookingsList = data is List ? data : (data is Map ? (data['bookings'] ?? data['data'] ?? []) : []);
        final bookings = List<Map<String, dynamic>>.from(bookingsList);

        final inProgress = bookings.where((b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          return status == 'em_andamento' || status == 'in_progress';
        }).toList();

        final now = DateTime.now();
        final upcoming = bookings.where((b) {
          final status = b['status'] ?? '';
          final statusLower = status.toString().toLowerCase();
          if (statusLower == 'em_andamento' || statusLower == 'in_progress') return false;
          final isPendingOrConfirmed = status == 'pendente_oficina' || status == 'confirmed' || status == 'confirmado' ||
              status == 'pendente_cliente' || status == 'aguardando_autorizacao_inicio' ||
              statusLower == 'awaiting_service_start' || statusLower == 'pending_cliente' || statusLower == 'pending_customer';
          if (!isPendingOrConfirmed) return false;
          final appointmentDate = b['appointment_date'] ?? b['scheduled_date'];
          if (appointmentDate != null) {
            try {
              final date = DateTime.parse(appointmentDate);
              return date.isAfter(now) || date.isAtSameMomentAs(now);
            } catch (e) {
              return true;
            }
          }
          return true;
        }).toList();

        upcoming.sort((a, b) {
          final dateA = a['appointment_date'] ?? a['scheduled_date'];
          final dateB = b['appointment_date'] ?? b['scheduled_date'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          try {
            return DateTime.parse(dateA).compareTo(DateTime.parse(dateB));
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _upcomingBookings = upcoming.take(3).toList();
          _inProgressBookings = inProgress;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Carrega localização e oficinas próximas em paralelo com getBookings (não bloqueia a home).
  Future<void> _loadLocationAndNearby() async {
    final locationStatus = await _syncLocationStatus();
    if (locationStatus.canRequestPosition) {
      try {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          _currentPosition = position;
          await _updateNearbyWorkshops(position.latitude, position.longitude, usedFallback: false);
          await _checkIfInSaoPaulo(position.latitude, position.longitude);
          return;
        }
      } catch (e) {
        print('Erro ao obter localização: $e');
      }
    }
    await _updateNearbyWorkshopsNoLocation();
    if (mounted) setState(() => _isInSaoPaulo = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          body: SafeArea(
            child: _isLoading
                ? const MecaApiLoadingWidget(message: 'Carregando dados...')
                : _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildHeader(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMiaCard(),
          ),
          const SizedBox(height: 24),
          // Card SOS Guincho (apenas para São Paulo Capital)
          Builder(
            builder: (context) {
              print('🔍 [SOS Guincho] Build: _isInSaoPaulo = $_isInSaoPaulo, _checkingLocation = $_checkingLocation');
              if (_isInSaoPaulo) {
                print('✅ [SOS Guincho] Exibindo card SOS!');
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSosGuinchoCard(),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              } else {
                print('⚠️ [SOS Guincho] Card NÃO será exibido (_isInSaoPaulo = false)');
              }
              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildQuickActions(),
          ),
          const SizedBox(height: 24),
          if (_maintenanceReminders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMaintenanceRemindersCard(),
            ),
            const SizedBox(height: 24),
          ],
          if (_inProgressBookings.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildInProgressServices(),
            ),
            const SizedBox(height: 24),
          ],
          _buildUpcomingBookings(), // Sem padding para ocupar toda a largura
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNearbyWorkshops(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Logo MECA
        Expanded(
          child: Image.asset(
            'assets/logos/wordmark_verde.png',
            fit: BoxFit.contain,
            height: 40,
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Seu carro em boas mãos',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildMiaCard() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        return GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final seen = prefs.getBool('mia_onboarding_seen') ?? false;
            if (!seen && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => MiaOnboardingSheet(
                  onStart: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.setBool('mia_onboarding_seen', true);
                  },
                ),
              ).then((_) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MiaChatScreen(),
                    ),
                  );
                }
              });
            } else if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiaChatScreen()),
              );
            }
          },
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 150),
            child: Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final miaHeight = screenWidth < 375 ? 220.0 : (screenWidth < 390 ? 270.0 : 340.0);
                final miaRight = screenWidth < 375 ? -20.0 : (screenWidth < 390 ? -35.0 : -48.0);
                final miaWidth = screenWidth < 375 ? miaHeight * 0.70 : miaHeight * 0.92;
                // Espaço à direita só para não colidir com a arte da MIA; em telas estreitas prioriza largura do texto.
                final reservedRight = screenWidth < 360
                    ? 64.0
                    : screenWidth < 400
                        ? 76.0
                        : (miaWidth + miaRight - 10).clamp(80.0, 150.0);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Background do Card (glassmorphism profundo)
                    Container(
                      constraints: const BoxConstraints(minHeight: 152),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: isDark
                              ? [const Color(0xFF121212), const Color(0xFF0A2415)]
                              : [const Color(0xFFF5FFF9), const Color(0xFFE8F9F0)],
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF00C977).withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C977).withOpacity(isDark ? 0.04 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 2. Lado Esquerdo (texto com quebra de linha; altura do card acompanha o conteúdo)
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, constraints) {
                                final w = constraints.maxWidth;
                                final titleSize = w < 140 ? 17.0 : (w < 180 ? 19.0 : 22.0);
                                final descSize = w < 140 ? 12.0 : (w < 180 ? 13.0 : 14.0);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFF00C977).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark ? Colors.greenAccent.withOpacity(0.6) : const Color(0xFF00C977).withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'IA',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF00C977),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Diagnóstico Inteligente',
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                        height: 1.15,
                                        letterSpacing: -0.8,
                                      ),
                                      softWrap: true,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Descubra o problema do seu carro com a IA do Meca',
                                      style: TextStyle(
                                        fontSize: descSize,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white70 : const Color(0xFF555555),
                                        height: 1.35,
                                      ),
                                      softWrap: true,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          SizedBox(width: reservedRight),
                        ],
                      ),
                    ),
                    // 3. Halo de IA – luz volumétrica difusa (sem bordas duras)
                    Positioned(
                      bottom: -60,
                      right: -80,
                      child: IgnorePointer(
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: [
                                Colors.greenAccent.withOpacity(isDark ? 0.35 : 0.15),
                                Colors.greenAccent.withOpacity(isDark ? 0.08 : 0.04),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.25, 0.6],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 4. MIA – base ancorada no fundo, vazando agressivamente pelo topo
                    Positioned(
                      bottom: 0,
                      right: miaRight,
                      child: SizedBox(
                        width: miaWidth,
                        height: miaHeight,
                        child: SvgPicture.asset(
                          'assets/images/MIA.svg',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return _buildActionCard(
                    icon: Icons.build,
                    title: 'Oficinas',
                    subtitle: 'Encontrar oficinas próximas',
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF14241E) // Verde Profundo (tema escuro)
                        : const Color(0xFFE8F5E9), // Verde Claro (tema claro)
                    iconColor: const Color(0xFF00C977),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WorkshopsScreen()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return _buildActionCard(
                    icon: Icons.schedule,
                    title: 'Agendar',
                    subtitle: 'Novo agendamento',
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF121E29) // Azul Profundo (tema escuro)
                        : const Color(0xFFE3EDFA), // Azul Claro (tema claro)
                    iconColor: const Color(0xFF00C977),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ServicesScreen()),
                    ),
                  );
                },
              ),
            ),
                                        ],
                                      ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return _buildActionCard(
                    icon: Icons.directions_car,
                    title: 'Meus Veículos',
                    subtitle: 'Gerenciar veículos',
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF102124) // Teal/Petróleo (tema escuro)
                        : const Color(0xFFE0F2F1), // Teal Claro (tema claro)
                    iconColor: const Color(0xFF00C977),
                    onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return _buildActionCard(
                    icon: Icons.history,
                    title: 'Histórico',
                    subtitle: 'Ver agendamentos',
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF1E1E1E) // Carbono/Neutro (tema escuro)
                        : const Color(0xFFF5F5F5), // Cinza Claro (tema claro)
                    iconColor: const Color(0xFF00C977),
                    onTap: () => Navigator.pushNamed(context, '/orders'),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSosGuinchoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () async {
        const phoneNumber = '+551130644243';
        const message = 'Olá! Preciso de um guincho urgente. Estou na rua e preciso de ajuda imediata.';
        final encodedMessage = Uri.encodeComponent(message);
        final whatsappUrl = 'https://wa.me/$phoneNumber?text=$encodedMessage';
        
        try {
          final uri = Uri.parse(whatsappUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              MecaToast.show(context, 'Não foi possível abrir o WhatsApp. Verifique se o app está instalado.');
            }
          }
        } catch (e) {
          if (mounted) {
            MecaToast.show(context, 'Erro ao abrir WhatsApp: $e');
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ]
                : [
                    const Color(0xFFE8F4FD),
                    const Color(0xFFD1E7F5),
                    const Color(0xFFB8DAED),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C977).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 0),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 0),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: const Color(0xFF00C977).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Ícone SOS com animação visual
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF3B30),
                    Color(0xFFFF2D55),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B30).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '⚠️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Conteúdo do card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SOS',
                          style: TextStyle(
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GUINCHO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: Color(0xFF00C977),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Precisa de guincho?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque para chamar no WhatsApp',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Ícone de seta
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF00C977),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Cores reativas ao tema: no tema claro, usar cores mais claras; no tema escuro, manter as escuras
    final bgColor = backgroundColor ?? (isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFE8F5E9));
    final icColor = iconColor ?? const Color(0xFF00C977);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128, // Altura fixa levemente maior para evitar overflow em textos mais longos
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: icColor,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Próximos Agendamentos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/orders'),
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _upcomingBookings.isEmpty
            ? _buildEmptyBookings()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _upcomingBookings.take(3).map((booking) => _buildBookingCard(booking)).toList(),
                ),
              ),
      ],
    );
  }

  Widget _buildEmptyBookings() {
    return Container(
      width: double.infinity, // Ocupa toda a largura da tela
      margin: const EdgeInsets.symmetric(horizontal: 16), // Margem lateral para não tocar as bordas
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule,
            size: 48,
            color: Color(0xFF00C977),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum agendamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agende um serviço para começar',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
                      MaterialPageRoute(builder: (context) => const ServicesScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            child: const Text('Agendar Serviço'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? '';
    final appointmentDate = booking['appointment_date'] ?? booking['scheduled_date'];
    final formattedDate = appointmentDate != null 
        ? _formatDate(appointmentDate)
        : 'Data não definida';
    
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return GestureDetector(
          onTap: () async {
            // IMPORTANTE: Aguardar resultado para atualizar se necessário
            final result = await Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: booking,
            );
            // Se retornou true, significa que houve atualização e precisa recarregar
            if (result == true && mounted) {
              // IMPORTANTE: Forçar refresh sem usar cache
              await _loadData(forceRefresh: true);
            }
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00C977).withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C977), Color(0xFF00B369)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['service_name'] ?? booking['service']?['name'] ?? 'Serviço',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: themeService.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking['workshop_name'] ?? booking['workshop']?['name'] ?? 'Oficina',
                        style: TextStyle(
                          color: themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: const Color(0xFF00C977),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: const Color(0xFF00C977),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNearbyWorkshops() {
    final locationBlocked = _locationPermissionDenied || _locationServicesDisabled;
    if (locationBlocked) {
      final isPermanent = _locationPermissionDeniedForever;
      final isServiceDisabled = _locationServicesDisabled;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oficinas Próximas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C977).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isServiceDisabled
                      ? 'Ative o GPS para ver oficinas próximas de você.'
                      : 'Ative a localização para ver oficinas próximas de você.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isServiceDisabled
                      ? 'Parece que os serviços de localização do aparelho estão desligados. Ative o GPS para encontrarmos oficinas perto de você.'
                      : isPermanent
                          ? 'Sua permissão de localização está desativada para o app. Abra as configurações e permita o acesso para continuar.'
                          : 'Precisamos da sua autorização para usar a localização e encontrar oficinas próximas.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isServiceDisabled
                        ? _openLocationSettings
                        : (isPermanent ? _openAppSettings : _requestLocationPermissionAgain),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isServiceDisabled
                          ? Icons.gps_fixed
                          : (isPermanent ? Icons.settings : Icons.my_location),
                      size: 18,
                    ),
                    label: Text(
                      isServiceDisabled
                          ? 'Ativar localização'
                          : (isPermanent ? 'Abrir Configurações' : 'Permitir localização'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Oficinas Próximas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_usedFallbackLocationForNearby && _nearbyWorkshops.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Mostrando oficinas em São Paulo. Ative a localização para ver as mais próximas de você.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00C977).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00C977),
                  width: 1,
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WorkshopsScreen()),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: Color(0xFF00C977),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260, // Ajustado para o novo tamanho do card (120 imagem + ~140 conteúdo)
          child: _nearbyWorkshops.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey.shade600 
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma oficina próxima',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Não encontramos oficinas próximas a você.\nTente aumentar o raio de busca.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16), // Padding direito para o último card
                  itemCount: _nearbyWorkshops.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.only(
                        right: index < _nearbyWorkshops.length - 1 ? 16 : 0,
                      ),
                      child: _buildWorkshopCard(_nearbyWorkshops[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<LocationStatus> _syncLocationStatus({bool requestPermission = true}) async {
    final status = await _locationService.ensurePermissions(
      requestPermission: requestPermission,
    );

    if (!mounted) return status;

    setState(() {
      _locationServicesDisabled = !status.serviceEnabled;
      _locationPermissionDenied =
          !_locationServicesDisabled && !status.permissionGranted;
      _locationPermissionDeniedForever = status.permissionPermanentlyDenied;
    });

    return status;
  }

  Future<void> _checkIfInSaoPaulo(double latitude, double longitude) async {
    if (_checkingLocation) {
      print('⚠️ [SOS Guincho] Já está verificando localização, ignorando...');
      return;
    }
    
    print('🔍 [SOS Guincho] ========== INICIANDO VERIFICAÇÃO ==========');
    print('🔍 [SOS Guincho] Coordenadas recebidas: lat=$latitude, lng=$longitude');
    
    if (!mounted) return;
    setState(() {
      _checkingLocation = true;
    });
    
    try {
      // Coordenadas aproximadas de São Paulo Capital
      // Latitude: -23.5505, Longitude: -46.6333
      // Raio aproximado: ~50km do centro (aumentado para cobrir toda a capital)
      const double saoPauloLat = -23.5505;
      const double saoPauloLng = -46.6333;
      const double radiusKm = 50.0; // Aumentado para 50km para cobrir toda a capital
      
      // Calcular distância do centro de São Paulo
      final distance = Geolocator.distanceBetween(
        saoPauloLat,
        saoPauloLng,
        latitude,
        longitude,
      ) / 1000; // Converter para km
      
      print('🔍 [SOS Guincho] Distância do centro SP: ${distance.toStringAsFixed(2)}km');
      
      // Verificar se está dentro do raio
      final isInRadius = distance <= radiusKm;
      print('🔍 [SOS Guincho] Está no raio? $isInRadius');
      
      // Verificação adicional: usar geocoding para confirmar cidade
      // IMPORTANTE: Se estiver no raio de 50km, considerar como SP mesmo se geocoding falhar
      bool isSaoPauloCity = false;
      if (isInRadius) {
        try {
          print('🔍 [SOS Guincho] Fazendo geocoding para confirmar cidade...');
          final placemarks = await placemarkFromCoordinates(latitude, longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final city = place.locality?.toLowerCase() ?? '';
            final adminArea = place.administrativeArea?.toLowerCase() ?? '';
            
            print('🔍 [SOS Guincho] Cidade: $city, Estado: $adminArea');
            
            // Verificar se é São Paulo, SP
            isSaoPauloCity = (city.contains('são paulo') || city.contains('sao paulo')) &&
                            (adminArea.contains('sp') || adminArea.contains('são paulo'));
            
            print('🔍 [SOS Guincho] Geocoding confirmou São Paulo? $isSaoPauloCity');
            
            // Se geocoding não confirmar mas está no raio de 50km, usar distância como fallback
            if (!isSaoPauloCity) {
              print('⚠️ [SOS Guincho] Geocoding não confirmou, mas está no raio - usando distância');
              isSaoPauloCity = true; // Se está dentro de 50km do centro, considerar SP
            }
          } else {
            print('⚠️ [SOS Guincho] Nenhum placemark encontrado, usando verificação de distância');
            // Se não conseguir geocoding mas está no raio, considerar como SP
            isSaoPauloCity = true;
          }
        } catch (e) {
          print('❌ [SOS Guincho] Erro ao fazer geocoding: $e');
          // Se geocoding falhar, usar apenas a verificação de distância
          // Se está dentro de 50km, considerar como SP
          isSaoPauloCity = true;
          print('🔍 [SOS Guincho] Usando verificação de distância apenas: $isSaoPauloCity');
        }
      } else {
        print('⚠️ [SOS Guincho] Fora do raio de ${radiusKm}km - não exibindo card');
      }
      
      print('✅ [SOS Guincho] Resultado final: _isInSaoPaulo = $isSaoPauloCity');
      
      if (!mounted) return;
      print('✅ [SOS Guincho] Atualizando estado: _isInSaoPaulo = $isSaoPauloCity');
      setState(() {
        _isInSaoPaulo = isSaoPauloCity;
        _checkingLocation = false;
      });
      print('✅ [SOS Guincho] Estado atualizado via setState! Card deve ${isSaoPauloCity ? "aparecer" : "NÃO aparecer"}');
    } catch (e) {
      print('❌ [SOS Guincho] Erro ao verificar localização São Paulo: $e');
      if (!mounted) return;
      setState(() {
        _isInSaoPaulo = false;
        _checkingLocation = false;
      });
    }
  }

  Future<void> _updateNearbyWorkshops(double latitude, double longitude, {bool usedFallback = false}) async {
    final workshopsResponse = await _apiService.getNearbyWorkshops(
      latitude,
      longitude,
      _nearbyWorkshopsRadiusKm,
    );

    if (!mounted) return;

    if (workshopsResponse['success'] == true) {
      final data = workshopsResponse['data'];
      List<dynamic> workshops = [];

      if (data is Map) {
        workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
      } else if (data is List) {
        workshops = data;
      }

      setState(() {
        _usedFallbackLocationForNearby = usedFallback;
        _nearbyWorkshops = workshops
            .whereType<Map>()
            .map((w) => _normalizeWorkshop(Map<String, dynamic>.from(w)))
            .take(3)
            .toList();
      });
    } else {
      setState(() {
        _usedFallbackLocationForNearby = usedFallback;
        _nearbyWorkshops = [];
      });
    }
  }

  Future<void> _updateNearbyWorkshopsNoLocation() async {
    final response = await _apiService.getAllWorkshops();

    if (!mounted) return;

    if (response['success'] == true) {
      final data = response['data'];
      List<dynamic> workshops = [];

      if (data is Map) {
        workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
      } else if (data is List) {
        workshops = data;
      }

      setState(() {
        _usedFallbackLocationForNearby = false;
        _nearbyWorkshops = workshops
            .whereType<Map>()
            .map((w) => _normalizeWorkshop(Map<String, dynamic>.from(w)))
            .take(3)
            .toList();
      });
    } else {
      setState(() {
        _usedFallbackLocationForNearby = false;
        _nearbyWorkshops = [];
      });
    }
  }

  void _requestLocationPermissionAgain() {
    _syncLocationStatus().then((status) {
      if (status.canRequestPosition) {
        _loadData();
      }
    });
  }

  Future<void> _openAppSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final distanceLabel = _formatDistanceLabel(workshop['distance']);
    final double? ratingValue =
        _parseDouble(workshop['rating']) ?? _parseDouble(workshop['average_rating']);
    final rawLogo = workshop['logo_url']?.toString() ?? '';
    final workshopId = workshop['id']?.toString();
    // Usa a presigned URL da API diretamente (S3 presigned ou URL válida)
    final String? logoUrl = rawLogo.isNotEmpty && rawLogo.startsWith('http') ? rawLogo : null;
    final hasLogo = logoUrl != null;

    final rawDist = _parseDistance(workshop['distance']);
    final distanceKm = rawDist != null
        ? (rawDist > 1000 ? rawDist / 1000.0 : rawDist)
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkshopDetailScreen(
              workshopId: workshop['id'] ?? '',
              distanceKm: distanceKm,
            ),
          ),
        );
      },
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          final isDark = themeService.isDarkMode;
          
          // OPÇÃO 1: Card estilo Apple Maps Premium (Elevated Card com imagem)
          return Container(
            width: 300,
            constraints: const BoxConstraints(
              minHeight: 0,
              maxHeight: double.infinity,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: BorderRadius.circular(20),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagem/Logo da oficina (área visual grande)
                    Container(
                      height: 120, // Reduzido de 140 para 120
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: hasLogo 
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark 
                                    ? [
                                        const Color(0xFF00C977).withOpacity(0.15),
                                        const Color(0xFF00B369).withOpacity(0.1),
                                      ]
                                    : [
                                        const Color(0xFF00C977).withOpacity(0.1),
                                        const Color(0xFF00B369).withOpacity(0.05),
                                      ],
                              ),
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[50],
                      ),
                      child: hasLogo
                          ? Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Image.network(
                                  logoUrl!,
                                  width: double.infinity,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(isDark),
                                ),
                                // Overlay sutil para melhorar legibilidade
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildPlaceholderImage(isDark),
                    ),
                    
                    // Conteúdo do card com padding ajustado
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), // Padding inferior aumentado
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nome da oficina (destaque)
                          Text(
                            workshop['name'] ?? 'Oficina',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17, // Reduzido de 18 para 17
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          
                          // Rating e Distância (linha horizontal)
                          Row(
                            children: [
                              // Rating com estrela refinada
                              if (ratingValue != null && ratingValue > 0 && ratingValue <= 5) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark 
                                        ? Colors.amber.withOpacity(0.15)
                                        : Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber[700],
                                        size: 13, // Reduzido de 14 para 13
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        ratingValue.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12, // Reduzido de 13 para 12
                                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              
                              // Distância
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 13, // Reduzido de 14 para 13
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        distanceLabel,
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          fontSize: 12, // Reduzido de 13 para 12
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10), // Reduzido de 12 para 10
                          
                          // Botão de ação discreto
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 9), // Reduzido de 10 para 9
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? const Color(0xFF00C977).withOpacity(0.15)
                                  : const Color(0xFF00C977).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00C977).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver detalhes',
                                  style: TextStyle(
                                    color: const Color(0xFF00C977),
                                    fontSize: 13, // Reduzido de 14 para 13
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 15, // Reduzido de 16 para 15
                                  color: const Color(0xFF00C977),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isDark) {
    return Container(
      width: double.infinity,
      height: 120, // Ajustado para corresponder à altura da imagem
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [
                  const Color(0xFF00C977).withOpacity(0.15),
                  const Color(0xFF00B369).withOpacity(0.1),
                ]
              : [
                  const Color(0xFF00C977).withOpacity(0.1),
                  const Color(0xFF00B369).withOpacity(0.05),
                ],
        ),
      ),
      child: Center(
        child: Container(
          width: 56, // Reduzido de 64 para 56
          height: 56, // Reduzido de 64 para 56
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF00C977).withOpacity(0.2)
                : const Color(0xFF00C977).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.store_rounded,
            color: isDark 
                ? const Color(0xFF00C977).withOpacity(0.6)
                : const Color(0xFF00C977).withOpacity(0.5),
            size: 28, // Reduzido de 32 para 28
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _normalizeWorkshop(Map<String, dynamic> workshop) {
    final normalized = Map<String, dynamic>.from(workshop);

    normalized['latitude'] = _parseCoordinate(normalized['latitude']);
    normalized['longitude'] = _parseCoordinate(normalized['longitude']);

    final parsedAddress = _extractAddressDetails(normalized['address']);
    normalized['address_details'] = parsedAddress;
    normalized['address_text'] = _formatAddress(parsedAddress ?? normalized['address']);
    normalized['address'] = normalized['address_text'];

    final parsedDistance = _parseDistance(normalized['distance']);
    normalized['distance'] = parsedDistance ?? _computeDistanceFromUser(
      normalized['latitude'],
      normalized['longitude'],
      _currentPosition,
    );

    normalized['rating'] = _parseDouble(normalized['rating']);
    normalized['logo_url'] = normalized['logo_url'] ?? normalized['logo'];

    return normalized;
  }

  double? _computeDistanceFromUser(double? lat, double? lng, Position? userPosition) {
    if (lat == null || lng == null || userPosition == null) return null;
    try {
      return Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            lat,
            lng,
          ) /
          1000;
    } catch (_) {
      return null;
    }
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  double? _parseDistance(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    if (raw is Map) {
      final value = raw['value'] ?? raw['distance'];
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '.'));
      }
    }
    return null;
  }

  double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final lower = trimmed.toLowerCase();
      if (lower == 'n/a' || lower == 'na' || lower == 'null' || lower == '--') {
        return null;
      }
      return double.tryParse(trimmed.replaceAll(',', '.'));
    }
    return null;
  }

  Map<String, dynamic>? _extractAddressDetails(dynamic address) {
    if (address is Map<String, dynamic>) {
      return Map<String, dynamic>.from(address);
    }

    if (address is String) {
      try {
        final decoded = jsonDecode(address);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'Endereço não informado';
    if (address is String) {
      if (address.isEmpty) return 'Endereço não informado';
      return _sanitizeAddress(address);
    }

    if (address is Map) {
      final street = address['street'] ?? address['logradouro'] ?? address['addressLine1'];
      final number = address['number'] ?? address['numero'];
      final neighborhood = address['neighborhood'] ?? address['bairro'];
      final city = address['city'] ?? address['cidade'];
      final state = address['state'] ?? address['uf'];
      final cep = address['zip'] ?? address['cep'];

      final parts = <String>[];
      if (street != null) {
        if (number != null) {
          parts.add('$street, $number');
        } else {
          parts.add(street.toString());
        }
      }
      if (neighborhood != null) {
        parts.add(neighborhood.toString());
      }
      final cityState = [city, state].where((element) => element != null && element.toString().isNotEmpty).join(' - ');
      if (cityState.isNotEmpty) {
        parts.add(cityState);
      }
      if (cep != null && cep.toString().isNotEmpty) {
        parts.add('CEP ${cep.toString()}');
      }

      if (parts.isEmpty) {
        final rawValues = address.values
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .map(_sanitizeAddress)
            .toList();
        if (rawValues.isEmpty) return 'Endereço não informado';
        return rawValues.join(' • ');
      }

      return _sanitizeAddress(parts.join(' • '));
    }

    return _sanitizeAddress(address.toString());
  }

  String _sanitizeAddress(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n]+'), ' • ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'(•\s*){2,}'), '• ')
        .trim();
  }

  String _formatDistanceLabel(dynamic distance) {
    final distanceValue = _parseDistance(distance) ?? 0.0;
    if (distanceValue <= 0) {
      return 'Próximo a você';
    }
    final formatted = distanceValue >= 10
        ? distanceValue.toStringAsFixed(0)
        : distanceValue.toStringAsFixed(1);
    return '$formatted km de distância';
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Data não informada';
    try {
      final parsed = DateTime.parse(dateString);
      final date = DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
      return '${date.day}/${date.month}/${date.year} às ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    // Mapear status da API para cores
    final statusMap = {
      'pendente_oficina': Colors.orange,
      'pendente': Colors.orange,
      'pending': Colors.orange,
      'pending_oficina': Colors.orange,
      'pendente_cliente': Colors.deepOrange,
      'pending_cliente': Colors.deepOrange,
      'confirmado': Colors.blue,
      'confirmado_oficina': Colors.blue,
      'confirmed': Colors.blue,
      'em_andamento': Colors.purple,
      'in_progress': Colors.purple,
      'started': Colors.purple,
      'finalizado_aguardando_pagamento': Colors.teal,
      'finalizado': Colors.teal,
      'concluido': Colors.teal,
      'concluído': Colors.teal,
      'completed': Colors.teal,
      'finalizado_cliente': Colors.green,
      'pago': Colors.green,
      'cancelado': Colors.red,
      'cancelled': Colors.red,
    };
    
    final mappedStatus = statusMap[status] ?? statusMap['pendente_oficina'] ?? Colors.grey;
    return mappedStatus;
  }

  String _getStatusText(String? status) {
    // Mapear status da API para texto
    final statusMap = {
      'pendente_oficina': 'Pendente',
      'pendente': 'Pendente',
      'pending': 'Pendente',
      'pending_oficina': 'Pendente',
      'pendente_cliente': 'Aguardando você',
      'pending_cliente': 'Aguardando você',
      'confirmado': 'Confirmado',
      'confirmado_oficina': 'Confirmado',
      'confirmed': 'Confirmado',
      'em_andamento': 'Em Andamento',
      'in_progress': 'Em Andamento',
      'started': 'Em Andamento',
      'finalizado_aguardando_pagamento': 'Aguardando Pagamento',
      'finalizado': 'Aguardando Pagamento',
      'concluido': 'Aguardando Pagamento',
      'concluído': 'Aguardando Pagamento',
      'completed': 'Aguardando Pagamento',
      'finalizado_cliente': 'Concluído',
      'pago': 'Concluído',
      'cancelado': 'Cancelado',
      'cancelled': 'Cancelado',
    };
    
    return statusMap[status] ?? 'Pendente';
  }

  Widget _buildMaintenanceRemindersCard() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Manutenções Próximas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_maintenanceReminders.take(3).map((reminder) {
              final serviceName = (reminder['service_name'] ?? reminder['name'] ?? 'Manutenção').toString();
              final vehicleName = (reminder['vehicle_name'] ?? reminder['vehicle'] ?? '').toString();
              final daysAgo = reminder['days_since'] ?? reminder['days_ago'];
              final dueText = _formatReminderDue(daysAgo);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/services');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.build_circle,
                              color: Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (vehicleName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    vehicleName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  dueText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })),
          ],
        );
      },
    );
  }

  String _formatReminderDue(dynamic daysValue) {
    if (daysValue == null) return 'Manutenção pendente';
    final days = daysValue is int ? daysValue : int.tryParse(daysValue.toString()) ?? 0;
    if (days <= 0) return 'Manutenção pendente';
    if (days < 30) return 'Há $days ${days == 1 ? 'dia' : 'dias'}';
    final months = (days / 30).floor();
    return 'Há $months ${months == 1 ? 'mês' : 'meses'}';
  }

  Widget _buildInProgressServices() {
    if (_inProgressBookings.isEmpty) return const SizedBox.shrink();
    
    final booking = _inProgressBookings.first; // Pegar o primeiro serviço em andamento
    final serviceName = booking['service_name'] ?? booking['service']?['name'] ?? 'Serviço';
    final workshopName = booking['workshop_name'] ?? booking['workshop']?['name'] ?? 'Oficina';
    final workshopId = booking['workshop_id']?.toString() ?? booking['workshop']?['id']?.toString();
    final rawLogo = booking['workshop_logo_url'] ?? booking['workshop']?['logo_url']?.toString() ?? '';
    // Usa presigned URL da API diretamente
    final workshopLogoUrl = rawLogo.toString().trim().isNotEmpty && rawLogo.toString().startsWith('http')
        ? rawLogo.toString()
        : null;
    final hasLogo = workshopLogoUrl != null;
    
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return InkWell(
          onTap: () {
            // Navegar para tela de detalhes do agendamento
            Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: booking,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C977), Color(0xFF00B369)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasLogo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            workshopLogoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.build_circle,
                                color: Colors.white,
                                size: 40,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.build_circle,
                          color: Colors.white,
                          size: 40,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Serviço em Andamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Oficina: $workshopName',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
