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
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _upcomingBookings = [];
      _inProgressBookings = [];
      _nearbyWorkshops = [];
    });
    
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
          final isPendingOrConfirmed = status == 'pendente_oficina' || 
                                      status == 'confirmed' || 
                                      status == 'confirmado';
          
          // Excluir serviços em andamento
          final statusLower = status.toString().toLowerCase();
          if (statusLower == 'em_andamento' || statusLower == 'in_progress') {
            return false;
          }
          
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
              child: _buildActionCard(
                icon: Icons.build,
                title: 'Oficinas',
                subtitle: 'Encontrar oficinas próximas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WorkshopsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.schedule,
                title: 'Agendar',
                subtitle: 'Novo agendamento',
                onTap: () => Navigator.push(
                  context,
                      MaterialPageRoute(builder: (context) => const ServicesScreen()),
                ),
              ),
            ),
                                        ],
                                      ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.directions_car,
                title: 'Meus Veículos',
                subtitle: 'Gerenciar veículos',
                onTap: () => Navigator.pushNamed(context, '/my-vehicles'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.history,
                title: 'Histórico',
                subtitle: 'Ver agendamentos',
                onTap: () => Navigator.pushNamed(context, '/orders'),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128, // Altura fixa levemente maior para evitar overflow em textos mais longos
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00C977).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00C977).withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFF00C977),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
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
          onTap: () {
            Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: booking,
            );
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
          height: 240,
          child: _nearbyWorkshops.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma oficina encontrada próxima a você',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nearbyWorkshops.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
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
    final displayAddress = workshop['address_text'] ?? _formatAddress(workshop['address']);
    final distanceLabel = _formatDistanceLabel(workshop['distance']);
    final double? ratingValue =
        _parseDouble(workshop['rating']) ?? _parseDouble(workshop['average_rating']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkshopDetailScreen(workshopId: workshop['id'] ?? ''),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00C977).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00C977).withOpacity(0.2),
          ),
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: (workshop['logo_url'] != null && 
                        workshop['logo_url'].toString().trim().isNotEmpty &&
                        workshop['logo_url'].toString().startsWith('http'))
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          workshop['logo_url'].toString(),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.build,
                            color: Color(0xFF00C977),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.build,
                        color: Color(0xFF00C977),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop['name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                (ratingValue != null && ratingValue > 0 && ratingValue <= 5)
                    ? ratingValue.toStringAsFixed(1)
                    : '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayAddress,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Ver detalhes da oficina',
              style: TextStyle(
                color: Color(0xFF00C977),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
