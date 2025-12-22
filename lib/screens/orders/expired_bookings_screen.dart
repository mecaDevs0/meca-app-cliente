import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart' show OrderDetailScreen;
import '../../utils/price_utils.dart';

class ExpiredBookingsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> expiredBookings;

  const ExpiredBookingsScreen({
    Key? key,
    required this.expiredBookings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
      appBar: AppBar(
        title: const Text('Agendamentos Expirados'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: expiredBookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum agendamento expirado',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expiredBookings.length,
              itemBuilder: (context, index) {
                final booking = expiredBookings[index];
                return _buildExpiredBookingCard(context, booking, isDarkMode);
              },
            ),
    );
  }

  Widget _buildExpiredBookingCard(
    BuildContext context,
    Map<String, dynamic> booking,
    bool isDarkMode,
  ) {
    final workshopName = booking['workshop_name'] ?? booking['workshop']?['name'] ?? 'Oficina';
    final appointmentDate = _parseBookingDate(booking);
    final serviceName = booking['service_name'] ?? booking['service']?['name'] ?? 'Serviço';
    final estimatedPrice = booking['estimated_price'] ?? booking['estimatedPrice'];
    final finalPrice = booking['final_price'] ?? booking['finalPrice'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(booking: booking),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workshopName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Expirado',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (appointmentDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.orange.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Data prevista: ${DateFormat('dd/MM/yyyy').format(appointmentDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (finalPrice != null || estimatedPrice != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Valor',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        finalPrice != null
                            ? PriceUtils.formatCurrency(finalPrice / 100) ?? '—'
                            : estimatedPrice != null
                                ? PriceUtils.formatCurrency(estimatedPrice / 100) ?? '—'
                                : '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C977),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Ver detalhes',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.orange,
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
}

