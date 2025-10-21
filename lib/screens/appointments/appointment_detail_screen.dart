import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailScreen({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C977),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        title: const Text(
          'Detalhes do Agendamento',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header com status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF00C977),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.appointment['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(widget.appointment['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Agendamento #${widget.appointment['id'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo principal
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações da oficina
                  _buildInfoCard(
                    'Oficina',
                    widget.appointment['workshop']?['name'] ?? 'Oficina Demo',
                    Icons.business,
                    const Color(0xFF00C977),
                  ),
                  const SizedBox(height: 15),

                  // Serviços
                  _buildInfoCard(
                    'Serviços',
                    widget.appointment['services']?.map((s) => s['name']).join(', ') ?? 'Serviço Demo',
                    Icons.build,
                    const Color(0xFF00C977),
                  ),
                  const SizedBox(height: 15),

                  // Data e hora
                  _buildInfoCard(
                    'Data e Hora',
                    _formatDateTime(widget.appointment['scheduled_date'], widget.appointment['scheduled_time']),
                    Icons.schedule,
                    const Color(0xFF00C977),
                  ),
                  const SizedBox(height: 15),

                  // Veículo
                  _buildInfoCard(
                    'Veículo',
                    '${widget.appointment['vehicle']?['brand'] ?? 'Marca'} ${widget.appointment['vehicle']?['model'] ?? 'Modelo'} - ${widget.appointment['vehicle']?['plate'] ?? 'ABC-1234'}',
                    Icons.directions_car,
                    const Color(0xFF00C977),
                  ),
                  const SizedBox(height: 15),

                  // Observações
                  if (widget.appointment['notes'] != null && widget.appointment['notes'].isNotEmpty)
                    _buildInfoCard(
                      'Observações',
                      widget.appointment['notes'],
                      Icons.note,
                      const Color(0xFF00C977),
                    ),

                  const SizedBox(height: 30),

                  // Ações disponíveis
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botão Re-agendar
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showRescheduleDialog(),
            icon: const Icon(Icons.schedule, color: Colors.white),
            label: const Text(
              'Re-agendar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
              shadowColor: const Color(0xFF00C977).withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Botão Lembretes
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showRemindersDialog(),
            icon: const Icon(Icons.notifications, color: Colors.white),
            label: const Text(
              'Configurar Lembretes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
              shadowColor: const Color(0xFF4CAF50).withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Botão Cancelar (se status permitir)
        if (widget.appointment['status'] == 'pending' || widget.appointment['status'] == 'confirmed')
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showCancelDialog(),
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: const Text(
                'Cancelar Agendamento',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: Colors.red.withOpacity(0.3),
              ),
            ),
          ),
      ],
    );
  }

  void _showRescheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-agendar Serviço'),
        content: const Text('Esta funcionalidade será implementada em breve. Você poderá solicitar uma nova data/hora para o serviço.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRemindersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Lembretes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Configure lembretes para seu agendamento:'),
            const SizedBox(height: 20),
            _buildReminderOption('1 dia antes', true),
            _buildReminderOption('1 semana antes', false),
            _buildReminderOption('1 hora antes', true),
            _buildReminderOption('Email', true),
            _buildReminderOption('SMS', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lembretes configurados com sucesso!'),
                  backgroundColor: Color(0xFF00C977),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderOption(String title, bool value) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: (newValue) {
        // Implementar lógica de lembretes
      },
      activeColor: const Color(0xFF00C977),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Agendamento'),
        content: const Text('Tem certeza que deseja cancelar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              // Implementar cancelamento via API
              await Future.delayed(const Duration(seconds: 1));
              
              setState(() => _isLoading = false);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Agendamento cancelado com sucesso!'),
                  backgroundColor: Colors.red,
                ),
              );
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return const Color(0xFF00C977);
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'in_progress':
        return 'Em Andamento';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconhecido';
    }
  }

  String _formatDateTime(String? date, String? time) {
    if (date == null && time == null) return 'Data não definida';
    
    try {
      if (date != null && time != null) {
        final dateTime = DateTime.parse('$date $time');
        return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      } else if (date != null) {
        final dateTime = DateTime.parse(date);
        return DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } catch (e) {
      return 'Data inválida';
    }
    
    return 'Data não definida';
  }
}


