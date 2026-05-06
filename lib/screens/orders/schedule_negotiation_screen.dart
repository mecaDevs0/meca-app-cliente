import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';

class ScheduleNegotiationScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> booking;

  const ScheduleNegotiationScreen({
    Key? key,
    required this.bookingId,
    required this.booking,
  }) : super(key: key);

  @override
  State<ScheduleNegotiationScreen> createState() => _ScheduleNegotiationScreenState();
}

class _ScheduleNegotiationScreenState extends State<ScheduleNegotiationScreen> {
  final ApiService _apiService = ApiService();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  void _loadBookingData() {
    // Se há uma sugestão pendente, carregar os dados
    if (widget.booking['suggested_date'] != null) {
      final suggestedDate = DateTime.parse(widget.booking['suggested_date']);
      setState(() {
        _selectedDate = suggestedDate;
        _selectedTime = TimeOfDay.fromDateTime(suggestedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.booking['status'] ?? 'pending';
    final suggestedBy = widget.booking['suggested_by'];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Negociar Horário',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C977),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildContent(status, suggestedBy),
    );
  }

  Widget _buildContent(String status, String? suggestedBy) {
    if (status == 'pending_cliente' && suggestedBy == 'oficina') {
      return _buildWorkshopSuggestion();
    } else if (status == 'pending_oficina' && suggestedBy == 'cliente') {
      return _buildCustomerSuggestion();
    } else {
      return _buildInitialSuggestion();
    }
  }

  Widget _buildWorkshopSuggestion() {
    final suggestedDate = DateTime.parse(widget.booking['suggested_date']);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBookingInfo(),
          const SizedBox(height: 24),
          
          // Card com sugestão da oficina
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nova Sugestão da Oficina',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            widget.booking['workshop']?['name'] ?? 'Oficina',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy').format(suggestedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(suggestedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _suggestAlternative,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue.shade600),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Sugerir Outro',
                          style: TextStyle(color: Colors.blue.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _acceptSuggestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C977),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Aceitar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSuggestion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBookingInfo(),
          const SizedBox(height: 24),
          
          // Card de sugestão enviada
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aguardando Resposta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            'Sua sugestão foi enviada para a oficina',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.booking['suggested_date'])),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(DateTime.parse(widget.booking['suggested_date'])),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A oficina receberá uma notificação e responderá em breve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialSuggestion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBookingInfo(),
          const SizedBox(height: 24),
          
          // Card para sugerir novo horário
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sugerir Novo Horário',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252940),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecione uma nova data e horário para o agendamento.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Seleção de data
                _buildDateSelector(),
                const SizedBox(height: 16),
                
                // Seleção de horário
                _buildTimeSelector(),
                const SizedBox(height: 24),
                
                // Botão para enviar sugestão
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedDate != null && _selectedTime != null 
                        ? _sendSuggestion 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Enviar Sugestão',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildBookingInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00C977), Color(0xFF00B369)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C977).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.booking['service']?['name'] ?? 'Serviço',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.booking['workshop']?['name'] ?? 'Oficina',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip('Data Original', _formatDate(widget.booking['scheduled_date'])),
              const SizedBox(width: 12),
              _buildInfoChip('Status', _getStatusText(widget.booking['status'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252940),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF00C977)),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                      : 'Selecionar data',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Horário',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252940),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF00C977)),
                const SizedBox(width: 12),
                Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Selecionar horário',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedTime != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<void> _sendSuggestion() async {
    if (_selectedDate == null || _selectedTime == null) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final result = await _apiService.suggestSchedule(
        widget.bookingId,
        scheduledDateTime.toIso8601String(),
        'cliente',
      );

      if (result['success']) {
        Navigator.pop(context, true);
        AppAlerts.showSuccess(
          context,
          message: 'Sugestão enviada! A oficina receberá uma notificação.',
        );
      } else {
        setState(() {
          _error = result['error'] ?? 'Erro ao enviar sugestão';
        });
        _showError(_error);
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: ${e.toString()}';
      });
      _showError(_error);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _acceptSuggestion() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await _apiService.acceptSchedule(widget.bookingId);

      if (result['success']) {
        Navigator.pop(context, true);
        AppAlerts.showSuccess(
          context,
          message: 'Horário aceito! Agendamento confirmado.',
        );
      } else {
        _showError(result['error'] ?? 'Erro ao aceitar sugestão');
      }
    } catch (e) {
      _showError('Erro de conexão: ${e.toString()}');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _suggestAlternative() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleNegotiationScreen(
          bookingId: widget.bookingId,
          booking: widget.booking,
        ),
      ),
    );
  }

  void _showError(String message) {
    AppAlerts.showError(
      context,
      message: message,
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final parsed = DateTime.parse(dateString);
      final date = DateTime(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending_oficina':
        return 'Pendente Oficina';
      case 'pending_cliente':
        return 'Pendente Cliente';
      case 'confirmed':
        return 'Confirmado';
      default:
        return 'Pendente';
    }
  }
}
















