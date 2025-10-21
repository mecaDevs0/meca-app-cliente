
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

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
  String _currentStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      final statuses = ['all', 'pending', 'confirmed', 'completed'];
      setState(() {
        _currentStatus = statuses[_tabController.index];
      });
      _loadBookings();
    });
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    
    final result = await _apiService.getMyBookings();
    
    if (result['success']) {
      var bookings = (result['data']['bookings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      if (_currentStatus != 'all') {
        bookings = bookings.where((b) => b['status'] == _currentStatus).toList();
      }
      
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Meus Agendamentos',
          style: TextStyle(
            color: Color(0xFF252940),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00C977),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF00C977),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Pendentes'),
            Tab(text: 'Confirmados'),
            Tab(text: 'Concluídos'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
          : RefreshIndicator(
              color: const Color(0xFF00C977),
              onRefresh: _loadBookings,
              child: _bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 20),
                          const Text(
                            'Nenhum agendamento encontrado',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
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
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                          color: Color(0xFF252940),
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
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      booking['scheduled_date'] != null
                          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['scheduled_date']))
                          : 'Data não definida',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      booking['scheduled_time'] ?? '00:00',
                      style: TextStyle(color: Colors.grey[700]),
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
                      '${booking['vehicle_brand']} ${booking['vehicle_model']} - ${booking['vehicle_plate']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Services
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ((booking['services'] as List?) ?? []).map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        service['title'] ?? 'Serviço',
                        style: const TextStyle(
                          color: Color(0xFF00C977),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),

                // Total
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
                      'R\$ ${(booking['total'] ?? 0) / 100}',
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
