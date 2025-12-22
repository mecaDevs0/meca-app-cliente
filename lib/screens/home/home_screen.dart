import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/meca_loading_widget.dart';
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
  static const double _fallbackLatitude = -23.5505;
  static const double _fallbackLongitude = -46.6333;

  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _inProgressBookings = [];
  List<Map<String, dynamic>> _nearbyWorkshops = [];
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService.instance;
  Position? _currentPosition;
  bool _locationPermissionDenied = false;
  bool _locationPermissionDeniedForever = false;
  bool _locationServicesDisabled = false;

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
    });
    
    // IMPORTANTE: Invalidar cache se forçar refresh
    if (forceRefresh) {
      _apiService.invalidateBookingsCache();
    }
    
    try {
      // Carregar agendamentos do usuário real
      final bookingsResponse = await _apiService.getBookings();
      if (bookingsResponse['success']) {
        final data = bookingsResponse['data'];
        final bookingsList = data is List ? data : (data is Map ? (data['bookings'] ?? data['data'] ?? []) : []);
        final bookings = List<Map<String, dynamic>>.from(bookingsList);
        
        // Filtrar serviços em andamento
        final inProgress = bookings.where((b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          return status == 'em_andamento' || status == 'in_progress';
        }).toList();
        
        // Filtrar apenas agendamentos futuros ou pendentes (excluindo em andamento) e ordenar por data
        final now = DateTime.now();
        final upcoming = bookings.where((b) {
          final status = b['status'] ?? '';
          final statusLower = status.toString().toLowerCase();
          
          // Excluir serviços em andamento
          if (statusLower == 'em_andamento' || statusLower == 'in_progress') {
            return false;
          }
          
          // Incluir pendentes, confirmados E pendente_cliente (sugestão de horário pendente)
          final isPendingOrConfirmed = status == 'pendente_oficina' || 
                                      status == 'confirmed' || 
                                      status == 'confirmado' ||
                                      status == 'pendente_cliente' ||
                                      statusLower == 'pending_cliente' ||
                                      statusLower == 'pending_customer';
          
          if (!isPendingOrConfirmed) return false;
          
          // Verificar se é agendamento futuro
          final appointmentDate = b['appointment_date'] ?? b['scheduled_date'];
          if (appointmentDate != null) {
            try {
              final date = DateTime.parse(appointmentDate);
              return date.isAfter(now) || date.isAtSameMomentAs(now);
            } catch (e) {
              return true; // Se não conseguir parsear, incluir para não perder dados
            }
          }
          
          return true; // Incluir se não tiver data
        }).toList();
        
        // Ordenar por data mais próxima primeiro
        upcoming.sort((a, b) {
          final dateA = a['appointment_date'] ?? a['scheduled_date'];
          final dateB = b['appointment_date'] ?? b['scheduled_date'];
          
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          
          try {
            final dateAObj = DateTime.parse(dateA);
            final dateBObj = DateTime.parse(dateB);
            return dateAObj.compareTo(dateBObj);
          } catch (e) {
            return 0;
          }
        });
        
        setState(() {
          _upcomingBookings = upcoming.take(3).toList(); // Pegar apenas os 3 mais próximos
          _inProgressBookings = inProgress;
        });
      }
      
      final locationStatus = await _syncLocationStatus();
      if (locationStatus.canRequestPosition) {
        try {
          final position = await _locationService.getCurrentPosition();
          if (position != null) {
            _currentPosition = position;
            await _updateNearbyWorkshops(position.latitude, position.longitude);
          } else {
            await _updateNearbyWorkshops(_fallbackLatitude, _fallbackLongitude);
          }
        } catch (e) {
          print('Erro ao obter localização: $e');
          await _updateNearbyWorkshops(_fallbackLatitude, _fallbackLongitude);
        }
      } else {
        setState(() {
          _nearbyWorkshops = [];
        });
      }
      
    } catch (e) {
      print('Erro ao carregar dados: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildQuickActions(),
          ),
          const SizedBox(height: 24),
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
            const Text(
              'Oficinas Próximas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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

  Future<void> _updateNearbyWorkshops(double latitude, double longitude) async {
    final workshopsResponse = await _apiService.getNearbyWorkshops(
      latitude,
      longitude,
      10.0,
    );

    if (!mounted) return;

    if (workshopsResponse['success']) {
      final data = workshopsResponse['data'];
      List<dynamic> workshops = [];

      if (data is Map) {
        workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
      } else if (data is List) {
        workshops = data;
      }

      setState(() {
        _nearbyWorkshops = workshops
            .whereType<Map>()
            .map((w) => _normalizeWorkshop(Map<String, dynamic>.from(w)))
            .take(3)
            .toList();
      });
    } else {
      setState(() {
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
    final hasLogo = workshop['logo_url'] != null && 
                    workshop['logo_url'].toString().trim().isNotEmpty &&
                    workshop['logo_url'].toString().startsWith('http');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkshopDetailScreen(workshopId: workshop['id'] ?? ''),
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
                                  workshop['logo_url'].toString(),
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
      final date = DateTime.parse(dateString);
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

  Widget _buildInProgressServices() {
    if (_inProgressBookings.isEmpty) return const SizedBox.shrink();
    
    final booking = _inProgressBookings.first; // Pegar o primeiro serviço em andamento
    final serviceName = booking['service_name'] ?? booking['service']?['name'] ?? 'Serviço';
    final workshopName = booking['workshop_name'] ?? booking['workshop']?['name'] ?? 'Oficina';
    final workshopLogoUrl = booking['workshop_logo_url'] ?? 
                            booking['workshop']?['logo_url']?.toString();
    final hasLogo = workshopLogoUrl != null && 
                    workshopLogoUrl.toString().trim().isNotEmpty &&
                    workshopLogoUrl.toString() != 'null';
    
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
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
                          workshopLogoUrl.toString(),
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
            ],
          ),
        );
      },
    );
  }
}
