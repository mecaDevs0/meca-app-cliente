
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _currentStatus = 'pendente_oficina';
  Map<String, Map<String, dynamic>> _vehicleData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      final statuses = ['pendente_oficina', 'confirmado', 'finalizado_cliente'];
      setState(() {
        _currentStatus = statuses[_tabController.index];
      });
      _loadBookings();
    });
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final result = await _apiService.getMyBookings('cus_01K83MVXK5RDQA6R079DXP2C56'); // ID do usuário logado
    
    if (!mounted) return;
    
    if (result['success']) {
      var bookings = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      bookings = bookings.where((b) => b['status'] == _currentStatus).toList();
      
      // Carregar dados dos veículos
      await _loadVehicleData(bookings);
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadVehicleData(List<Map<String, dynamic>> bookings) async {
    try {
      final vehiclesResult = await _apiService.getUserVehicles();
      if (vehiclesResult['success']) {
        final vehicles = (vehiclesResult['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (var vehicle in vehicles) {
          _vehicleData[vehicle['id']] = vehicle;
        }
      }
    } catch (e) {
      print('Erro ao carregar dados dos veículos: $e');
    }
  }

  String _getVehicleDisplayName(Map<String, dynamic> booking) {
    // Primeiro tenta usar vehicle_snapshot se disponível
    if (booking['vehicle_snapshot'] != null) {
      final snapshot = booking['vehicle_snapshot'];
      return '${snapshot['brand'] ?? ''} ${snapshot['model'] ?? ''} - ${snapshot['plate'] ?? ''}';
    }
    
    // Se não, tenta usar os dados carregados do veículo
    if (booking['vehicle_id'] != null && _vehicleData.containsKey(booking['vehicle_id'])) {
      final vehicle = _vehicleData[booking['vehicle_id']];
      return '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''} - ${vehicle?['plate'] ?? ''}';
    }
    
    // Se não há dados, mostra uma mensagem genérica
    return 'Veículo não informado';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar melhorado
          SliverAppBar(
            expandedHeight: 60,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF00C977),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Meus Agendamentos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(
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
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // TabBar melhorado com padding
          SliverPersistentHeader(
            pinned: true,
            delegate: _FuturisticTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF00C977),
                unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF00C977).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFF00C977).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Pendentes'),
                  Tab(text: 'Confirmados'),
                  Tab(text: 'Concluídos'),
                ],
              ),
            ),
          ),
          // Conteúdo principal
          SliverFillRemaining(
            child: _loading
                ? const MecaApiLoadingWidget(message: 'Carregando agendamentos...')
                : RefreshIndicator(
                    color: const Color(0xFF00C977),
                    onRefresh: _loadBookings,
                    child: _bookings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
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
                                        Icons.event_busy,
                                        size: 80,
                                        color: Color(0xFF00C977),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Nenhum agendamento encontrado',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00C977),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Agende um serviço para começar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(15),
                            itemCount: _bookings.length,
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              return _buildBookingCard(booking);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: booking,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking['workshop_name'] ?? 'Oficina',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusConfig['color'],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusConfig['label'],
                        style: TextStyle(
                          color: statusConfig['textColor'],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      booking['appointment_date'] != null
                          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['appointment_date']))
                          : 'Data não definida',
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      booking['appointment_date'] != null
                          ? DateFormat('HH:mm').format(DateTime.parse(booking['appointment_date']))
                          : '00:00',
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vehicle
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _getVehicleDisplayName(booking),
                      style: TextStyle(color: Colors.grey.shade300),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Services
                if (booking['product_id'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Serviço ID: ${booking['product_id']}',
                      style: const TextStyle(
                        color: Color(0xFF00C977),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 15),

                // Total - só mostra se houver preço
                if (booking['estimated_price'] != null || booking['final_price'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'R\$ ${((booking['final_price'] ?? booking['estimated_price']) ?? 0) / 100}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C977),
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

  Map<String, dynamic> _getStatusConfig(String status) {
    final configs = {
      'pending': {
        'label': 'Pendente',
        'color': const Color(0xFFFCF4E5),
        'textColor': const Color(0xFFDBA800),
      },
      'confirmed': {
        'label': 'Confirmado',
        'color': const Color(0xFFE3EDFA),
        'textColor': const Color(0xFF7896D8),
      },
      'in_progress': {
        'label': 'Em Andamento',
        'color': const Color(0xFFE8FFEE),
        'textColor': const Color(0xFF2FD65C),
      },
      'completed': {
        'label': 'Concluído',
        'color': const Color(0xFFE8FFEE),
        'textColor': const Color(0xFF2FD65C),
      },
      'cancelled': {
        'label': 'Cancelado',
        'color': const Color(0xFFFEE2E2),
        'textColor': const Color(0xFFE8867C),
      },
    };
    
    return configs[status] ?? configs['pending']!;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _FuturisticTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _FuturisticTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
