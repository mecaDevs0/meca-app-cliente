import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/colors.dart';

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<BookingProvider>(context, listen: false).loadBookings();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmado':
        return Colors.green;
      case 'pendente':
      case 'pendente_oficina':
        return Colors.orange;
      case 'cancelado':
      case 'recusado':
        return Colors.red;
      case 'finalizado':
      case 'finalizado_cliente':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendente_oficina':
        return 'Aguardando Oficina';
      case 'confirmado':
        return 'Confirmado';
      case 'recusado':
        return 'Recusado';
      case 'finalizado_mecanico':
        return 'Aguardando Confirmação';
      case 'finalizado_cliente':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: const Text('Meus Agendamentos'),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 100,
                    color: AppColors.mediumGray,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Nenhum agendamento encontrado',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.bookings.length,
            itemBuilder: (context, index) {
              final booking = provider.bookings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(booking['status'] ?? ''),
                    child: const Icon(Icons.build, color: Colors.white),
                  ),
                  title: Text(
                    booking['service_name'] ?? 'Serviço',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['workshop_name'] ?? 'Oficina'),
                      const SizedBox(height: 4),
                      Text(
                        booking['appointment_date'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      _getStatusText(booking['status'] ?? ''),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(booking['status'] ?? ''),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Detalhes do Agendamento'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Serviço: ${booking['service_name']}'),
                            Text('Oficina: ${booking['workshop_name']}'),
                            Text('Data: ${booking['appointment_date']}'),
                            Text('Status: ${_getStatusText(booking['status'] ?? '')}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

