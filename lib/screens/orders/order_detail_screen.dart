import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import 'booking_evidence_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  
  const OrderDetailScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final status = widget.booking['status'] ?? 'pending';
    final canCancel = status == 'pending' || status == 'confirmed';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Detalhes do Agendamento',
          style: TextStyle(color: Color(0xFF252940), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF252940)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getStatusGradient(status),
                ),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(status), color: Colors.white, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Pedido #${widget.booking['id']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workshop Info
                  _buildSection(
                    'Oficina',
                    [
                      _buildInfoRow(Icons.build_circle, widget.booking['workshop_name'] ?? 'Oficina'),
                      _buildInfoRow(Icons.location_on, widget.booking['workshop_address'] ?? 'Endereço'),
                      _buildInfoRow(Icons.phone, widget.booking['workshop_phone'] ?? 'Telefone'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Date & Time
                  _buildSection(
                    'Data e Horário',
                    [
                      _buildInfoRow(
                        Icons.calendar_today,
                        widget.booking['scheduled_date'] != null
                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.booking['scheduled_date']))
                            : 'Data não definida',
                      ),
                      _buildInfoRow(Icons.access_time, widget.booking['scheduled_time'] ?? '00:00'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Vehicle Info
                  _buildSection(
                    'Veículo',
                    [
                      _buildInfoRow(
                        Icons.directions_car,
                        '${widget.booking['vehicle_brand']} ${widget.booking['vehicle_model']}',
                      ),
                      _buildInfoRow(Icons.pin, widget.booking['vehicle_plate'] ?? 'ABC-1234'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Services
                  const Text(
                    'Serviços',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252940),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...((widget.booking['services'] as List?) ?? []).map((service) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C977).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.build, color: Color(0xFF00C977), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service['title'] ?? 'Serviço',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${service['duration_minutes'] ?? 60} minutos',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            'R\$ ${(service['price'] ?? 0) / 100}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF00C977),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 20),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C977), Color(0xFF00B369)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'R\$ ${(widget.booking['total'] ?? 0) / 100}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.booking['notes'] != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Observações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF252940),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        widget.booking['notes'],
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Botões de ação conforme o fluxo
            _buildActionButtons(status),
          ],
        ),
      ),
      bottomNavigationBar: canCancel
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _cancelBooking(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Cancelar Agendamento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF252940),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00C977), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'confirmed':
        return [const Color(0xFF7896D8), const Color(0xFF5C7BC4)];
      case 'in_progress':
        return [const Color(0xFF00C977), const Color(0xFF00B369)];
      case 'completed':
        return [const Color(0xFF2FD65C), const Color(0xFF1FC04D)];
      case 'cancelled':
        return [const Color(0xFFE8867C), const Color(0xFFD8766C)];
      default:
        return [const Color(0xFFDBA800), const Color(0xFFC99800)];
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.build_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmado';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Aguardando Confirmação';
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Agendamento'),
        content: const Text('Tem certeza que deseja cancelar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _apiService.cancelBooking(widget.booking['id']);
      
      if (result['success']) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento cancelado com sucesso'),
            backgroundColor: Color(0xFF00C977),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    return {};
  }

  Widget _buildActionButtons(String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          
          // Botão "Ver Provas" - quando status = "completed" ou "in_progress"
          if (status == 'completed' || status == 'in_progress') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewEvidence,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Ver Provas da Oficina'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C977)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Botão "Avaliar Serviço" - quando status = "completed"
          if (status == 'completed') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rateService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C977),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Avaliar Serviço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Botão "Me Notificar" - quando status = "confirmed" e passou de 1 dia
          if (status == 'confirmed' && _shouldShowNotificationButton()) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _requestNotification,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C977)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Me Notificar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C977),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }


  Future<void> _rateService() async {
    // TODO: Implementar tela de avaliação
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tela de avaliação será implementada em breve'),
        backgroundColor: Color(0xFF00C977),
      ),
    );
  }

  Future<void> _requestNotification() async {
    // TODO: Implementar sistema de notificações
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sistema de notificações será implementado em breve'),
        backgroundColor: Color(0xFF00C977),
      ),
    );
  }

  Future<void> _viewEvidence() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingEvidenceScreen(
          bookingId: widget.booking['id'],
          booking: widget.booking,
        ),
      ),
    );
  }

  bool _shouldShowNotificationButton() {
    // Verificar se passou mais de 1 dia desde a confirmação
    final confirmedDate = DateTime.tryParse(widget.booking['confirmed_at'] ?? '');
    if (confirmedDate == null) return false;
    
    final now = DateTime.now();
    final difference = now.difference(confirmedDate).inDays;
    return difference >= 1;
  }

  double _calculateTotalAmount() {
    // TODO: Calcular valor total baseado no serviço
    return widget.booking['service']?['price']?.toDouble() ?? 0.0;
  }

  double _calculateMecaFee() {
    // Taxa MECA de 5%
    final serviceAmount = _calculateServiceAmount();
    return serviceAmount * 0.05;
  }

  double _calculateServiceAmount() {
    return widget.booking['service']?['price']?.toDouble() ?? 0.0;
  }
}
