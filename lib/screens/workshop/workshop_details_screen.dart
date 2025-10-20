import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../booking/create_booking_screen.dart';

class WorkshopDetailsScreen extends StatelessWidget {
  final String workshopId;

  const WorkshopDetailsScreen({super.key, required this.workshopId});

  @override
  Widget build(BuildContext context) {
    final mockWorkshop = {
      'id': workshopId,
      'name': 'Auto Center Silva',
      'description': 'Oficina especializada em manutenção preventiva e corretiva',
      'phone': '(11) 98765-4321',
      'address': 'Rua das Oficinas, 123 - São Paulo, SP',
      'horario': 'Seg-Sex: 08:00-18:00 | Sáb: 08:00-12:00',
      'rating': 4.8,
      'reviews': [
        {'customer': 'João', 'rating': 5, 'comment': 'Excelente serviço!'},
        {'customer': 'Maria', 'rating': 4, 'comment': 'Bom atendimento'},
      ],
    };

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: const Text('Detalhes da Oficina'),
      ),
      body: ListView(
        children: [
          Container(
            height: 200,
            color: AppColors.lightGray,
            child: const Icon(
              Icons.build_circle,
              size: 100,
              color: AppColors.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mockWorkshop['name'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${mockWorkshop['rating']} (${(mockWorkshop['reviews'] as List).length} avaliações)',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.description, mockWorkshop['description'] as String),
                _buildInfoRow(Icons.phone, mockWorkshop['phone'] as String),
                _buildInfoRow(Icons.location_on, mockWorkshop['address'] as String),
                _buildInfoRow(Icons.access_time, mockWorkshop['horario'] as String),
                const SizedBox(height: 24),
                const Text(
                  'Avaliações',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...((mockWorkshop['reviews'] as List).map((review) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(review['customer'] as String),
                        subtitle: Text(review['comment'] as String),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            Text('${review['rating']}'),
                          ],
                        ),
                      ),
                    ))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateBookingScreen(workshopId: workshopId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Agendar Serviço',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

