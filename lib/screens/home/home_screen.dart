import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/meca_loading_widget.dart';
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
      // TODO: Obter customerId do usuário logado
      final customerId = 'cus_KM5SA01GI';
      
      final bookingsResponse = await _apiService.getMyBookings(customerId);
      if (bookingsResponse['success']) {
        final data = bookingsResponse['data'];
        final bookingsList = data is Map ? (data['bookings'] ?? []) : data ?? [];
        final bookings = List<Map<String, dynamic>>.from(bookingsList);
        setState(() {
          _upcomingBookings = bookings.where((b) => 
            b['status'] == 'pending' || 
            b['status'] == 'confirmed' || 
            b['status'] == 'started'
          ).toList();
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildUpcomingBookings(),
          const SizedBox(height: 24),
          _buildNearbyWorkshops(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
            // Logo MECA
                                          Container(
              width: 60,
              height: 60,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Image.asset(
                'assets/images/wordmark_verde_vertical.png',
                fit: BoxFit.contain,
                                            ),
                                          ),
            const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                  const Text(
                    'Bem-vindo ao MECA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C977),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seu carro em boas mãos',
                                                  style: TextStyle(
                                                    fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  MaterialPageRoute(builder: (context) => const WorkshopsScreen()),
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
        Row(
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
        const SizedBox(height: 16),
        Center(
          child: _upcomingBookings.isEmpty
              ? _buildEmptyBookings()
              : Column(
                  children: _upcomingBookings.take(3).map((booking) => _buildBookingCard(booking)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyBookings() {
    return Container(
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
              MaterialPageRoute(builder: (context) => const WorkshopsScreen()),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.2),
        ),
      ),
      child: Row(
          children: [
            Container(
            width: 50,
            height: 50,
              decoration: BoxDecoration(
              color: const Color(0xFF00C977).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.build,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['service']?['name'] ?? 'Serviço',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking['workshop']?['name'] ?? 'Oficina',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(booking['scheduled_date']),
                  style: const TextStyle(
                    color: Color(0xFF00C977),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(booking['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(booking['status']),
              style: TextStyle(
                color: _getStatusColor(booking['status']),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                ),
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: Color(0xFF00C977),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3, // Mock data
            itemBuilder: (context, index) {
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: _buildWorkshopCard(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkshopCard() {
    return Container(
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
                    const Text(
                      'Oficina Central',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      '2.5 km de distância',
                        style: TextStyle(
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
              const Text(
                '4.5',
                        style: TextStyle(
                  fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          const SizedBox(height: 12),
          const Text(
            'Rua das Flores, 123',
                    style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildServiceChip('Troca de óleo'),
              _buildServiceChip('Alinhamento'),
              _buildServiceChip('Freios'),
            ],
                  ),
                ],
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
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'started':
        return Colors.purple;
      case 'finished':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'started':
        return 'Iniciado';
      case 'finished':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconhecido';
    }
  }
}