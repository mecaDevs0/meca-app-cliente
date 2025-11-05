import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
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
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _nearbyWorkshops = [];
  final ApiService _apiService = ApiService();

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
    setState(() => _isLoading = true);
    
    try {
      // Carregar agendamentos do usuário real
      final bookingsResponse = await _apiService.getBookings();
      if (bookingsResponse['success']) {
        final data = bookingsResponse['data'];
        final bookingsList = data is List ? data : (data is Map ? (data['bookings'] ?? data['data'] ?? []) : []);
        final bookings = List<Map<String, dynamic>>.from(bookingsList);
        
        // Filtrar apenas agendamentos futuros ou pendentes e ordenar por data
        final now = DateTime.now();
        final upcoming = bookings.where((b) {
          final status = b['status'] ?? '';
          final isPendingOrConfirmed = status == 'pendente_oficina' || 
                                      status == 'confirmed' || 
                                      status == 'confirmado' ||
                                      status == 'em_andamento' ||
                                      status == 'in_progress';
          
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
        });
      }
      
      // Carregar oficinas próximas com geolocalização real
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        final workshopsResponse = await _apiService.getNearbyWorkshops(
          position.latitude,
          position.longitude,
          10.0
        );
        
        if (workshopsResponse['success']) {
          final data = workshopsResponse['data'];
          List<dynamic> workshops = [];
          
          // Adaptar resposta
          if (data is Map) {
            workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
          } else if (data is List) {
            workshops = data;
          }
          
          setState(() {
            _nearbyWorkshops = List<Map<String, dynamic>>.from(workshops).take(3).toList();
          });
        }
      } catch (e) {
        print('Erro ao obter localização: $e');
        // Fallback para coordenadas padrão (São Paulo)
        final workshopsResponse = await _apiService.getNearbyWorkshops(-23.5505, -46.6333, 10.0);
        if (workshopsResponse['success']) {
          final data = workshopsResponse['data'];
          List<dynamic> workshops = [];
          if (data is Map) {
            workshops = data['workshops'] ?? data['workshop'] ?? data['data'] ?? [];
          } else if (data is List) {
            workshops = data;
          }
          setState(() {
            _nearbyWorkshops = List<Map<String, dynamic>>.from(workshops).take(3).toList();
          });
        }
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
          _buildUpcomingBookings(), // Sem padding para ocupar toda a largura
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNearbyWorkshops(),
          ),
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
        height: 120, // Altura fixa para padronizar
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
        Container(
          height: 200,
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

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
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
                child: const Icon(
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
                    ),
                    Text(
                      _calculateDistance(workshop),
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
                '${workshop['rating'] ?? 4.5}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            workshop['address'] ?? 'Endereço não informado',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildServiceChip('Mecânica Geral'),
              _buildServiceChip('Auto Elétrica'),
              _buildServiceChip('Freios'),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        service,
        style: const TextStyle(
          color: Color(0xFF00C977),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  String _calculateDistance(Map<String, dynamic> workshop) {
    // Simula cálculo de distância (em produção, usar geolocalização real)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    if (random < 30) return '0.5 km de distância';
    if (random < 60) return '1.2 km de distância';
    if (random < 80) return '2.8 km de distância';
    return '4.5 km de distância';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
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
      'confirmado': Colors.blue,
      'confirmado_oficina': Colors.blue,
      'em_andamento': Colors.purple,
      'in_progress': Colors.purple,
      'finalizado_cliente': Colors.green,
      'completed': Colors.green,
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
      'confirmado': 'Confirmado',
      'confirmado_oficina': 'Confirmado',
      'em_andamento': 'Em Andamento',
      'in_progress': 'Em Andamento',
      'finalizado_cliente': 'Finalizado',
      'completed': 'Finalizado',
      'cancelado': 'Cancelado',
      'cancelled': 'Cancelado',
    };
    
    return statusMap[status] ?? 'Pendente';
  }
}
