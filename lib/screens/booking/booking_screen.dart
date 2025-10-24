import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/plate_search_service.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  final String workshopId;
  final String serviceName;
  final String servicePrice;
  final String serviceDuration;
  final String workshopName;

  const BookingScreen({
    Key? key,
    required this.serviceId,
    required this.workshopId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDuration,
    required this.workshopName,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _apiService = ApiService();
  final PlateSearchService _plateService = PlateSearchService();
  
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _observationsController = TextEditingController();
  bool _isLoading = false;
  bool _isCreatingBooking = false;
  
  // Serviços da oficina
  List<Map<String, dynamic>> _workshopServices = [];
  Map<String, dynamic>? _selectedService;

  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
    
    // Se serviceId está vazio, carregar serviços da oficina
    if (widget.serviceId.isEmpty) {
      _loadWorkshopServices();
    } else {
      // Se serviceId está preenchido, usar os dados passados
      _selectedService = {
        'id': widget.serviceId,
        'name': widget.serviceName,
        'price': widget.servicePrice,
        'duration': widget.serviceDuration,
      };
    }
  }

  Future<void> _loadUserVehicles() async {
    setState(() => _isLoading = true);
    try {
      // Carregar veículos reais da API
      final result = await _apiService.getUserVehicles();
      
      if (result['success']) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(result['data'] ?? []);
          if (_vehicles.isNotEmpty) {
            _selectedVehicle = _vehicles.first;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar veículos: ${result['error']}')),
        );
      }
    } catch (e) {
      print('Erro ao carregar veículos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar veículos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkshopServices() async {
    try {
      // Carregar todos os serviços disponíveis
      final result = await _apiService.getServices();
      
      if (result['success']) {
        setState(() {
          _workshopServices = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar serviços: ${result['error']}')),
        );
      }
    } catch (e) {
      print('Erro ao carregar serviços: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar serviços: $e')),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createBooking() async {
    if (_selectedService == null) {
      _showSnackBar('Selecione um serviço', isError: true);
      return;
    }
    
    if (_selectedVehicle == null) {
      _showSnackBar('Selecione um veículo', isError: true);
      return;
    }
    
    if (_selectedDate == null) {
      _showSnackBar('Selecione uma data', isError: true);
      return;
    }
    
    if (_selectedTime == null) {
      _showSnackBar('Selecione um horário', isError: true);
      return;
    }

    setState(() => _isCreatingBooking = true);

    try {
      // Combinar data e hora
      final DateTime appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Criar agendamento
      final Map<String, dynamic> bookingData = {
        'customer_id': 'cus_01K83MVXK5RDQA6R079DXP2C56', // ID do usuário logado
        'vehicle_id': _selectedVehicle!['id'],
        'oficina_id': widget.workshopId,
        'product_id': _selectedService!['id'],
        'appointment_date': appointmentDateTime.toIso8601String(),
        'customer_notes': _observationsController.text.trim(),
        'status': 'pendente_oficina',
      };

      print('📅 Criando agendamento: $bookingData');

      final result = await _apiService.createBooking(bookingData);
      
      if (result['success'] == true) {
        _showSnackBar('Agendamento criado com sucesso!', isError: false);
        
        // Navegar para tela de agendamentos
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/orders',
          (route) => route.settings.name == '/home',
        );
      } else {
        _showSnackBar('Erro ao criar agendamento: ${result['message']}', isError: true);
      }
    } catch (e) {
      print('Erro ao criar agendamento: $e');
      _showSnackBar('Erro ao criar agendamento: $e', isError: true);
    } finally {
      setState(() => _isCreatingBooking = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Agendar Serviço',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações do Serviço
                  _buildServiceInfoCard(isDarkMode),
                  const SizedBox(height: 24),
                  
                  // Seleção de Serviço (se necessário)
                  if (widget.serviceId.isEmpty) ...[
                    _buildServiceSelectionCard(isDarkMode),
                    const SizedBox(height: 24),
                  ],
                  
                  // Seleção de Veículo
                  _buildVehicleSelectionCard(isDarkMode),
                  const SizedBox(height: 24),
                  
                  // Seleção de Data e Hora
                  _buildDateTimeSelectionCard(isDarkMode),
                  const SizedBox(height: 24),
                  
                  // Observações
                  _buildObservationsCard(isDarkMode),
                  const SizedBox(height: 32),
                  
                  // Botão de Agendar
                  _buildBookingButton(isDarkMode),
                ],
              ),
            ),
    );
  }

  Widget _buildServiceInfoCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(
                Icons.build_circle_outlined,
                color: const Color(0xFF00C977),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Serviço Selecionado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.serviceName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.store,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                widget.workshopName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.attach_money,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'R\$ ${widget.servicePrice}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (widget.serviceDuration.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.serviceDuration,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelectionCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(
                Icons.build,
                color: const Color(0xFF00C977),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Selecionar Serviço',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedService,
            decoration: InputDecoration(
              hintText: 'Escolha um serviço',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _workshopServices.map((service) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: service,
                child: Text(service['name'] ?? 'Serviço'),
              );
            }).toList(),
            onChanged: (Map<String, dynamic>? service) {
              setState(() {
                _selectedService = service;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(
                Icons.directions_car,
                color: const Color(0xFF00C977),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Selecionar Veículo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._vehicles.map((vehicle) => _buildVehicleOption(vehicle, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildVehicleOption(Map<String, dynamic> vehicle, bool isDarkMode) {
    final isSelected = _selectedVehicle?['id'] == vehicle['id'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF00C977).withOpacity(0.1)
              : isDarkMode 
                  ? const Color(0xFF2A2A2A) 
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF00C977) 
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF00C977) : Colors.grey[400],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle['brand']} ${vehicle['model']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle['year']} • ${vehicle['plate']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (vehicle['isDefault'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Padrão',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelectionCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(
                Icons.calendar_today,
                color: const Color(0xFF00C977),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Data e Horário',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(isDarkMode),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeButton(isDarkMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDate != null 
                ? const Color(0xFF00C977) 
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedDate != null
                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                  : 'Selecionar data',
              style: TextStyle(
                fontSize: 16,
                color: _selectedDate != null 
                    ? (isDarkMode ? Colors.white : Colors.black)
                    : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedTime != null 
                ? const Color(0xFF00C977) 
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horário',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedTime != null
                  ? _selectedTime!.format(context)
                  : 'Selecionar horário',
              style: TextStyle(
                fontSize: 16,
                color: _selectedTime != null 
                    ? (isDarkMode ? Colors.white : Colors.black)
                    : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservationsCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(
                Icons.note_alt_outlined,
                color: const Color(0xFF00C977),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Observações (Opcional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observationsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Descreva o problema ou observações sobre o serviço...',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
              ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCreatingBooking ? null : _createBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isCreatingBooking
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Confirmar Agendamento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }
}