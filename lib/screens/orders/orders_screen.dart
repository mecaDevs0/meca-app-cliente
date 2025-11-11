
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/meca_loading_widget.dart';
import '../notifications/recent_notifications_screen.dart';

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
        final index = _tabController.index;
        if (index >= 0 && index < statuses.length) {
          _currentStatus = statuses[index];
        }
      });
      _loadBookings();
    });
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final result = await _apiService.getBookings();
    
    if (!mounted) return;
    
    if (result['success']) {
      var bookings = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      // Filtrar por status - mapear corretamente
      bookings = bookings.where((b) {
        final bookingStatus = b['status'] ?? '';
        
        if (_currentStatus == 'pendente_oficina') {
          return bookingStatus == 'pendente_oficina' || bookingStatus == 'pending';
        } else if (_currentStatus == 'confirmado') {
          return bookingStatus == 'confirmado' || 
                 bookingStatus == 'confirmado_oficina' || 
                 bookingStatus == 'confirmed';
        } else if (_currentStatus == 'finalizado_cliente') {
          return bookingStatus == 'finalizado_cliente' || 
                 bookingStatus == 'concluido' || 
                 bookingStatus == 'completed';
        }
        
        return b['status'] == _currentStatus;
      }).toList();
      
      // Ordenar agendamentos pendentes por data mais próxima da atual
      if (_currentStatus == 'pendente_oficina') {
        bookings.sort((a, b) {
          // Tentar ambos os campos possíveis de data
          final dateA = a['appointment_date'] ?? a['scheduled_date'];
          final dateB = b['appointment_date'] ?? b['scheduled_date'];
          
          // Se ambos têm data, ordenar por data crescente (mais próximo primeiro)
          if (dateA != null && dateB != null) {
            try {
              final dateAObj = DateTime.parse(dateA);
              final dateBObj = DateTime.parse(dateB);
              return dateAObj.compareTo(dateBObj);
            } catch (e) {
              // Se houver erro ao parsear, manter ordem original
              return 0;
            }
          }
          
          // Se apenas A tem data, A vem primeiro
          if (dateA != null && dateB == null) return -1;
          
          // Se apenas B tem data, B vem primeiro
          if (dateA == null && dateB != null) return 1;
          
          // Se nenhum tem data, manter ordem original
          return 0;
        });
      }
      
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
        
        // Remover duplicatas baseado no ID antes de adicionar ao Map
        final uniqueVehicles = <String, Map<String, dynamic>>{};
        for (var vehicle in vehicles) {
          final id = vehicle['id']?.toString() ?? '';
          if (id.isNotEmpty && !uniqueVehicles.containsKey(id)) {
            uniqueVehicles[id] = vehicle;
          }
        }
        
        // Adicionar ao _vehicleData
        for (var vehicle in uniqueVehicles.values) {
          _vehicleData[vehicle['id']] = vehicle;
        }
      }
    } catch (e) {
      print('Erro ao carregar dados dos veículos: $e');
    }
  }

  Widget _buildNotificationButton(BuildContext context) {
    return FutureBuilder<int>(
      future: _getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecentNotificationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<int> _getUnreadCount() async {
    try {
      final result = await _apiService.getNotifications(limit: 100, read: false);
      if (result['success'] == true) {
        return NotificationProvider.extractUnreadCount(result['data']);
      }
    } catch (e) {
      print('Erro ao buscar contagem de notificações: $e');
    }
    return 0;
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
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
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
            actions: [
              Builder(
                builder: (context) => _buildNotificationButton(context),
              ),
            ],
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final attachments = (booking['customer_uploads'] is List)
        ? List<Map<String, dynamic>>.from(booking['customer_uploads'])
        : (booking['customerUploads'] is List)
            ? List<Map<String, dynamic>>.from(booking['customerUploads'])
            : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2A2A2A),
                ]
              : [
                  Colors.white,
                  Colors.grey.shade50,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
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
                    Icon(Icons.calendar_today, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      booking['appointment_date'] != null
                          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['appointment_date']))
                          : 'Data não definida',
                      style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.access_time, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      booking['appointment_date'] != null
                          ? DateFormat('HH:mm').format(DateTime.parse(booking['appointment_date']))
                          : '00:00',
                      style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vehicle
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _getVehicleDisplayName(booking),
                      style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Services
                if (booking['customer_notes'] != null && (booking['customer_notes'] as String).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      booking['customer_notes'],
                      style: const TextStyle(
                        color: Color(0xFF00C977),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.photo_camera_back_outlined,
                          size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        attachments.length == 1
                            ? '1 foto anexada'
                            : '${attachments.length} fotos anexadas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),

                // Total - só mostra se houver preço
                if (booking['estimated_price'] != null || booking['final_price'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
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
    // Normalizar o status para minúsculas e remover espaços
    final normalizedStatus = status.toString().toLowerCase().trim();
    
    // Mapear status da API para status de exibição
    final statusMap = {
      'pendente_oficina': 'pending',
      'pendente': 'pending',
      'pending': 'pending',
      'confirmado': 'confirmed',
      'confirmado_oficina': 'confirmed',
      'confirmed': 'confirmed',
      'em_andamento': 'in_progress',
      'em andamento': 'in_progress',
      'in_progress': 'in_progress',
      'finalizado_cliente': 'completed',
      'finalizado': 'completed',
      'concluido': 'completed',
      'concluído': 'completed',
      'completed': 'completed',
      'cancelado': 'cancelled',
      'cancelled': 'cancelled',
    };
    
    final mappedStatus = statusMap[normalizedStatus] ?? normalizedStatus;
    
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
    
    return configs[mappedStatus] ?? configs['pending']!;
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}












