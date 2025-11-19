
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../utils/price_utils.dart';
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
          // Incluir confirmado, em_andamento E pendente_cliente (aguardando aprovação do cliente)
          return bookingStatus == 'confirmado' || 
                 bookingStatus == 'confirmado_oficina' || 
                 bookingStatus == 'confirmed' ||
                 bookingStatus == 'em_andamento' ||
                 bookingStatus == 'in_progress' ||
                 bookingStatus == 'pendente_cliente'; // Agendamentos aguardando aprovação do cliente
        } else if (_currentStatus == 'finalizado_cliente') {
          return bookingStatus == 'finalizado_cliente' || 
                 bookingStatus == 'finalizado_aguardando_pagamento' ||
                 bookingStatus == 'pago' ||
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
    final bool isPendingTab = _currentStatus == 'pendente_oficina';
    final List<Map<String, dynamic>> pendingUpcoming = [];
    final List<Map<String, dynamic>> pendingExpired = [];

    if (isPendingTab && _bookings.isNotEmpty) {
      final today = DateTime.now();
      for (final booking in _bookings) {
        if (_isBookingExpired(booking, today)) {
          pendingExpired.add(booking);
        } else {
          pendingUpcoming.add(booking);
        }
      }
    }

    final hasExpiredSection = isPendingTab && pendingExpired.isNotEmpty;

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
                            itemCount: isPendingTab
                                ? pendingUpcoming.length + (hasExpiredSection ? 1 : 0) + pendingExpired.length
                                : _bookings.length,
                            itemBuilder: (context, index) {
                              if (!isPendingTab) {
                                final booking = _bookings[index];
                                return _buildBookingCard(booking);
                              }

                              if (index < pendingUpcoming.length) {
                                return _buildBookingCard(pendingUpcoming[index]);
                              }

                              if (hasExpiredSection && index == pendingUpcoming.length) {
                                return _buildExpiredDivider(pendingExpired.length);
                              }

                              final expiredIndex =
                                  index - pendingUpcoming.length - (hasExpiredSection ? 1 : 0);
                              return _buildBookingCard(
                                pendingExpired[expiredIndex],
                                isExpired: true,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {bool isExpired = false}) {
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
                    Row(
                      children: [
                        if (isExpired)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.history, size: 14, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Expirado',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                Builder(builder: (context) {
                  final totalLabel = PriceUtils.formatCurrency(
                    booking['final_price'] ?? booking['total'] ?? booking['estimated_price'] ?? booking['service_price'],
                  );
                  if (totalLabel == null) return const SizedBox.shrink();
                  return Row(
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
                        totalLabel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C977),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredDivider(int expiredCount) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
            thickness: 1,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agendamentos pendentes expirados',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiredCount == 1
                            ? 'Este agendamento passou da data prevista e aguarda ação manual.'
                            : '$expiredCount agendamentos pendentes passaram da data prevista e aguardam ação manual.',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isBookingExpired(Map<String, dynamic> booking, DateTime reference) {
    final bookingDate = _parseBookingDate(booking);
    if (bookingDate == null) return false;
    final dayStart = DateTime(reference.year, reference.month, reference.day);
    final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
    return bookingDay.isBefore(dayStart);
  }

  DateTime? _parseBookingDate(Map<String, dynamic> booking) {
    final possibleDates = [
      booking['appointment_date'],
      booking['scheduled_date'],
      booking['expected_date'],
    ];
    for (final raw in possibleDates) {
      if (raw == null) continue;
      try {
        final parsed = DateTime.parse(raw.toString());
        return parsed.toLocal();
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    // Normalizar o status para minúsculas e remover espaços
    final normalizedStatus = status.toString().toLowerCase().trim();
    
    // Mapear status da API para status de exibição
    final statusMap = {
      'pendente_oficina': 'pending',
      'pendente_cliente': 'pending_customer',
      'pendente': 'pending',
      'pending': 'pending',
      'confirmado': 'confirmed',
      'confirmado_oficina': 'confirmed',
      'confirmed': 'confirmed',
      'em_andamento': 'in_progress',
      'em andamento': 'in_progress',
      'in_progress': 'in_progress',
      'finalizado_aguardando_pagamento': 'awaiting_payment',
      'finalizado_cliente': 'completed',
      'finalizado': 'awaiting_payment',
      'concluido': 'awaiting_payment',
      'concluído': 'awaiting_payment',
      'completed': 'awaiting_payment',
      'pago': 'completed',
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
      'pending_customer': {
        'label': 'Aguardando você',
        'color': const Color(0xFFFFF4E6),
        'textColor': const Color(0xFFEF8E1C),
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
      'awaiting_payment': {
        'label': 'Aguardando Pagamento',
        'color': const Color(0xFFE0F2FF),
        'textColor': const Color(0xFF1B6DC1),
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












