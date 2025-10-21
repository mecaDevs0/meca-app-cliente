import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

class ServiceConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const ServiceConfirmationScreen({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  State<ServiceConfirmationScreen> createState() => _ServiceConfirmationScreenState();
}

class _ServiceConfirmationScreenState extends State<ServiceConfirmationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _hasArrived = false;
  bool _serviceStarted = false;
  bool _serviceCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C977),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        title: const Text(
          'Confirmação do Serviço',
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
            // Header com informações do agendamento
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Agendamento #${widget.appointment['id'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.appointment['workshop']?['name'] ?? 'Oficina Demo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDateTime(widget.appointment['scheduled_date'], widget.appointment['scheduled_time']),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
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
                  // Status atual
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Informações do serviço
                  _buildServiceInfo(),
                  const SizedBox(height: 20),

                  // Botões de ação
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status do Serviço',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          
          // Checklist de status
          _buildStatusItem(
            'Chegou na oficina',
            _hasArrived,
            Icons.location_on,
            _hasArrived ? const Color(0xFF00C977) : Colors.grey,
          ),
          const SizedBox(height: 10),
          
          _buildStatusItem(
            'Serviço iniciado',
            _serviceStarted,
            Icons.play_circle,
            _serviceStarted ? const Color(0xFF00C977) : Colors.grey,
          ),
          const SizedBox(height: 10),
          
          _buildStatusItem(
            'Serviço concluído',
            _serviceCompleted,
            Icons.check_circle,
            _serviceCompleted ? const Color(0xFF00C977) : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String title, bool isCompleted, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isCompleted ? Colors.black87 : Colors.grey,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações do Serviço',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          
          // Serviços
          _buildInfoRow(
            'Serviços',
            widget.appointment['services']?.map((s) => s['name']).join(', ') ?? 'Serviço Demo',
            Icons.build,
          ),
          const SizedBox(height: 10),
          
          // Veículo
          _buildInfoRow(
            'Veículo',
            '${widget.appointment['vehicle']?['brand'] ?? 'Marca'} ${widget.appointment['vehicle']?['model'] ?? 'Modelo'} - ${widget.appointment['vehicle']?['plate'] ?? 'ABC-1234'}',
            Icons.directions_car,
          ),
          const SizedBox(height: 10),
          
          // Preço (quando disponível)
          if (widget.appointment['total_price'] != null)
            _buildInfoRow(
              'Valor Total',
              'R\$ ${widget.appointment['total_price'].toStringAsFixed(2)}',
              Icons.attach_money,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00C977), size: 20),
        const SizedBox(width: 12),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botão de chegada
        if (!_hasArrived)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _confirmArrival(),
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text(
                'Confirmar Chegada',
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
        
        if (!_hasArrived) const SizedBox(height: 15),

        // Botão de início do serviço (quando chegou)
        if (_hasArrived && !_serviceStarted)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _confirmServiceStart(),
              icon: const Icon(Icons.play_circle, color: Colors.white),
              label: const Text(
                'Confirmar Início do Serviço',
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
        
        if (_hasArrived && !_serviceStarted) const SizedBox(height: 15),

        // Botão de conclusão do serviço (quando iniciado)
        if (_serviceStarted && !_serviceCompleted)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _confirmServiceCompletion(),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Confirmar Conclusão do Serviço',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: Colors.green.withOpacity(0.3),
              ),
            ),
          ),
        
        if (_serviceStarted && !_serviceCompleted) const SizedBox(height: 15),

        // Botão de pagamento (quando concluído)
        if (_serviceCompleted)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _goToPayment(),
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text(
                'Ir para Pagamento',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: const Color(0xFF2196F3).withOpacity(0.3),
              ),
            ),
          ),

        // Mensagem de aguardo
        if (!_hasArrived)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aguarde a confirmação da oficina para prosseguir com os próximos passos.',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _confirmArrival() async {
    setState(() => _isLoading = true);
    
    // Simular chamada para API
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _hasArrived = true;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chegada confirmada com sucesso!'),
        backgroundColor: Color(0xFF00C977),
      ),
    );
  }

  void _confirmServiceStart() async {
    setState(() => _isLoading = true);
    
    // Simular chamada para API
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _serviceStarted = true;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Início do serviço confirmado!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _confirmServiceCompletion() async {
    setState(() => _isLoading = true);
    
    // Simular chamada para API
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _serviceCompleted = true;
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Serviço concluído! Redirecionando para pagamento...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _goToPayment() {
    // Navegar para tela de pagamento
    Navigator.pushNamed(context, '/payment', arguments: widget.appointment);
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


