import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/photo/photo_service.dart';
import '../../services/photo/photo_repository.dart';
import '../../services/photo/upload_service.dart';
import '../../widgets/app_alerts.dart';
import '../../widgets/photo/photo_grid_widget.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  final String workshopId;
  final String serviceName;
  final String servicePrice;
  final String serviceDuration;
  final String workshopName;
  final String? workshopLogoUrl;

  const BookingScreen({
    Key? key,
    required this.serviceId,
    required this.workshopId,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDuration,
    required this.workshopName,
    this.workshopLogoUrl,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  final PhotoService _photoService = PhotoService(mode: PhotoCaptureMode.quick);
  final UploadService _uploadService = UploadService();
  
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _observationsController = TextEditingController();
  bool _isLoading = false;
  bool _isCreatingBooking = false;
  List<File> _uploadedImages = [];
  bool _showAllVehicles = false; // Controla se mostra todos os veículos ou apenas 5
  
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
        final vehiclesList = (result['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        // Remover duplicatas baseado no ID
        final uniqueVehicles = <String, Map<String, dynamic>>{};
        for (var vehicle in vehiclesList) {
          final id = vehicle['id']?.toString() ?? '';
          if (id.isNotEmpty && !uniqueVehicles.containsKey(id)) {
            uniqueVehicles[id] = vehicle;
          }
        }
        
        // Ordenar: favoritos primeiro, depois padrão, depois os demais
        final sortedVehicles = uniqueVehicles.values.toList();
        sortedVehicles.sort((a, b) {
          final aFavorite = (a['is_favorite'] == true || a['is_favorite'] == 'true') ? 1 : 0;
          final bFavorite = (b['is_favorite'] == true || b['is_favorite'] == 'true') ? 1 : 0;
          if (aFavorite != bFavorite) return bFavorite.compareTo(aFavorite);
          
          final aDefault = a['is_default'] == true ? 1 : 0;
          final bDefault = b['is_default'] == true ? 1 : 0;
          if (aDefault != bDefault) return bDefault.compareTo(aDefault);
          
          return 0;
        });
        
        setState(() {
          _vehicles = sortedVehicles;
          // Pré-selecionar veículo favorito ou padrão
          if (_vehicles.isNotEmpty) {
            final favoriteVehicle = _vehicles.firstWhere(
              (v) => (v['is_favorite'] == true || v['is_favorite'] == 'true'),
              orElse: () => _vehicles.firstWhere(
                (v) => v['is_default'] == true,
                orElse: () => _vehicles.first,
              ),
            );
            _selectedVehicle = favoriteVehicle;
          }
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] != null
              ? 'Não foi possível listar seus veículos: ${result['error']}'
              : 'Não foi possível listar seus veículos agora. Tente novamente em instantes.',
        );
      }
    } catch (e) {
      print('Erro ao carregar veículos: $e');
      AppAlerts.showError(
        context,
        message: 'Não foi possível listar seus veículos agora. Tente novamente em instantes.',
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
        AppAlerts.showError(
          context,
          message: result['error'] != null
              ? 'Não foi possível carregar os serviços da oficina: ${result['error']}'
              : 'Não foi possível carregar os serviços da oficina agora. Tente novamente.',
        );
      }
    } catch (e) {
      print('Erro ao carregar serviços: $e');
      AppAlerts.showError(
        context,
        message: 'Não foi possível carregar os serviços da oficina agora. Tente novamente.',
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
    if (_selectedDate == null) {
      AppAlerts.showWarning(
        context,
        message: 'Escolha primeiro a data do agendamento para ver os horários disponíveis.',
        title: 'Data obrigatória',
      );
      return;
    }

    // Buscar horários disponíveis da oficina
    final availableHoursResult = await _apiService.getAvailableHours(
      widget.workshopId,
      _selectedDate!,
    );

    List<String> availableTimes = [];
    
    if (availableHoursResult['success'] && availableHoursResult['data'] != null) {
      final data = availableHoursResult['data'];
      if (data is List) {
        availableTimes = data.cast<String>();
      } else if (data['available_hours'] is List) {
        availableTimes = List<String>.from(data['available_hours']);
      }
    }

    // Se não houver horários disponíveis específicos, gerar horários padrão
    if (availableTimes.isEmpty) {
      for (int hour = 8; hour <= 18; hour++) {
        for (int minute = 0; minute < 60; minute += 30) {
          availableTimes.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
        }
      }
    }

    // Mostrar diálogo de seleção de horário
    final selectedTimeStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecione um horário'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTimes.length,
            itemBuilder: (context, index) {
              final timeStr = availableTimes[index];
              return ListTile(
                title: Text(timeStr),
                onTap: () => Navigator.pop(context, timeStr),
              );
            },
          ),
        ),
      ),
    );

    if (selectedTimeStr != null) {
      final parts = selectedTimeStr.split(':');
      if (parts.length == 2) {
        setState(() {
          _selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
      }
    }
  }

  Future<void> _createBooking() async {
    final userId = await _apiService.getUserId();
    if (userId == null || userId.isEmpty) {
      await _showSnackBar('Não foi possível identificar o usuário logado. Faça login novamente.', isError: true);
      return;
    }

    if (_selectedService == null) {
      await _showSnackBar('Selecione um serviço', isError: true);
      return;
    }
    
    if (_selectedVehicle == null) {
      await _showSnackBar('Selecione um veículo', isError: true);
      return;
    }
    
    if (_selectedDate == null) {
      await _showSnackBar('Selecione uma data', isError: true);
      return;
    }
    
    if (_selectedTime == null) {
      await _showSnackBar('Selecione um horário', isError: true);
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
        'customer_id': userId,
        'vehicle_id': _selectedVehicle!['id'],
        'oficina_id': widget.workshopId,
        'product_id': _selectedService!['id'],
        'appointment_date': appointmentDateTime.toIso8601String(),
        'customer_notes': _observationsController.text.trim(),
        'status': 'pendente_oficina',
      };


      final result = await _apiService.createBooking(bookingData);
      
      if (result['success'] == true) {
        final bookingId = result['data']['id'] ?? result['data']['booking_id'];
        
        // Fazer upload das imagens se houver
        if (_uploadedImages.isNotEmpty && bookingId != null) {
          await _uploadImages(bookingId);
        }
        
        // Agendar lembretes de notificação
        try {
          await _notificationService.scheduleBookingReminders(
            workshopName: widget.workshopName,
            serviceName: widget.serviceName,
            scheduledDate: appointmentDateTime,
          );
        } catch (e) {
          print('Erro ao agendar lembretes: $e');
        }
        
        await _showSnackBar('Agendamento criado com sucesso!', isError: false);
        
        // Navegar para tela de agendamentos
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/orders',
          (route) => route.settings.name == '/home',
        );
      } else {
        await _showSnackBar('Erro ao criar agendamento: ${result['message']}', isError: true);
      }
    } catch (e) {
      await _showSnackBar('Erro ao criar agendamento: $e', isError: true);
    } finally {
      setState(() => _isCreatingBooking = false);
    }
  }

  Future<void> _showSnackBar(String message, {required bool isError}) async {
    if (!mounted) return;
    if (isError) {
      await AppAlerts.showError(
        context,
        message: message,
      );
    } else {
      await AppAlerts.showSuccess(
        context,
        message: message,
        title: 'Tudo certo!',
      );
    }
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Logo da oficina ou ícone padrão
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: (widget.workshopLogoUrl != null && 
                        widget.workshopLogoUrl!.isNotEmpty &&
                        widget.workshopLogoUrl!.startsWith('http'))
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          widget.workshopLogoUrl!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.store,
                            size: 16,
                            color: Color(0xFF00C977),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.store,
                        size: 16,
                        color: Color(0xFF00C977),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.workshopName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Só mostrar preço se tiver preço configurado e for maior que 0
              if (widget.servicePrice.isNotEmpty && 
                  widget.servicePrice != '0' && 
                  widget.servicePrice != '0.00' &&
                  double.tryParse(widget.servicePrice.replaceAll(',', '.')) != null &&
                  double.tryParse(widget.servicePrice.replaceAll(',', '.'))! > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              if (widget.serviceDuration.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                ),
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
            isExpanded: true,
            items: _workshopServices.map((service) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: service,
                child: Text(
                  service['name'] ?? 'Serviço',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
    // Limitar a 5 veículos inicialmente, ou mostrar todos se expandido
    final displayedVehicles = _showAllVehicles 
        ? _vehicles 
        : _vehicles.take(5).toList();
    final hasMoreVehicles = _vehicles.length > 5;
    
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
          if (_vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhum veículo cadastrado',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/my-vehicles');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Veículo'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00C977),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ...displayedVehicles.map((vehicle) => _buildVehicleOption(vehicle, isDarkMode)),
            if (hasMoreVehicles) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllVehicles = !_showAllVehicles;
                    });
                  },
                  icon: Icon(
                    _showAllVehicles ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF00C977),
                  ),
                  label: Text(
                    _showAllVehicles 
                        ? 'Ver menos' 
                        : 'Ver mais (${_vehicles.length - 5} veículos)',
                    style: const TextStyle(
                      color: Color(0xFF00C977),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
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
        height: 80, // Altura aumentada para melhor visualização
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
        height: 80, // Altura aumentada para melhor visualização
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
          const SizedBox(height: 16),
          // Botões de upload de foto
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    print('🔘 [BookingScreen] Botão Tirar Foto clicado!');
                    _takePhoto();
                  },
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Tirar Foto'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00C977)),
                    foregroundColor: const Color(0xFF00C977),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectImage,
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('Galeria'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00C977)),
                    foregroundColor: const Color(0xFF00C977),
                  ),
                ),
              ),
            ],
          ),
          // Exibir imagens selecionadas
          if (_uploadedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            PhotoGridWidget(
              photos: _uploadedImages,
              onRemove: _removeImage,
            ),
          ],
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


  Future<void> _takePhoto() async {
    print('📸 [BookingScreen] Botão Tirar Foto pressionado');
    
    try {
      // Usar image_picker diretamente - ele já gerencia permissões automaticamente
      // e dispara o popup NATIVO do sistema quando necessário
      print('📸 [BookingScreen] Abrindo câmera via image_picker...');
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) {
        print('📸 [BookingScreen] Usuário cancelou a captura');
        return;
      }
      
      print('📸 [BookingScreen] Foto capturada: ${image.path}');
      
      // Verificar se o arquivo original existe
      final originalFile = File(image.path);
      if (!await originalFile.exists()) {
        print('❌ [BookingScreen] Arquivo original não existe: ${image.path}');
        if (mounted) {
          AppAlerts.showError(
            context,
            message: 'Erro: arquivo de foto não encontrado. Tente novamente.',
          );
        }
        return;
      }
      
      // Verificar tamanho do arquivo
      final fileSize = await originalFile.length();
      print('📸 [BookingScreen] Tamanho do arquivo original: $fileSize bytes');
      
      if (fileSize == 0) {
        print('❌ [BookingScreen] Arquivo está vazio');
        if (mounted) {
          AppAlerts.showError(
            context,
            message: 'Erro: arquivo de foto está vazio. Tente novamente.',
          );
        }
        return;
      }
      
      // Salvar em diretório temporário (copia o arquivo)
      final photoRepo = PhotoRepository();
      final tempFile = await photoRepo.saveTempFile(originalFile);
      
      // Verificar se a cópia foi bem-sucedida
      if (!await tempFile.exists()) {
        print('❌ [BookingScreen] Erro ao copiar arquivo para diretório temporário');
        if (mounted) {
          AppAlerts.showError(
            context,
            message: 'Erro ao salvar foto. Tente novamente.',
          );
        }
        return;
      }
      
      final tempFileSize = await tempFile.length();
      print('📸 [BookingScreen] Foto salva em: ${tempFile.path}');
      print('📸 [BookingScreen] Tamanho do arquivo copiado: $tempFileSize bytes');
      
      if (mounted) {
        setState(() {
          _uploadedImages.add(tempFile);
        });
        print('📸 [BookingScreen] Foto adicionada à lista. Total: ${_uploadedImages.length}');
      }
    } catch (e, stackTrace) {
      print('❌ [BookingScreen] Erro ao tirar foto: $e');
      print('❌ [BookingScreen] Stack trace: $stackTrace');
      if (mounted) {
        AppAlerts.showError(
          context,
          message: 'Não foi possível acessar a câmera. Verifique as permissões e tente novamente.',
        );
      }
    }
  }

  Future<void> _selectImage() async {
    try {
      // No Android, não solicitamos permissões. O image_picker usa automaticamente
      // o Photo Picker do Android (disponível desde API 33) que não requer permissões.
      // No iOS, tentar abrir a galeria diretamente primeiro
      final ImagePicker picker = ImagePicker();
      
      // No iOS, tentar abrir a galeria diretamente
      // O image_picker vai solicitar permissão automaticamente se necessário
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        final photoRepo = PhotoRepository();
        final tempFile = await photoRepo.saveTempFile(File(image.path));
        setState(() {
          _uploadedImages.add(tempFile);
        });
      } else if (image == null && Platform.isIOS) {
        // Se o usuário cancelou ou houve problema, verificar se precisa de permissão
        final photosPermission = Permission.photos;
        final photosStatus = await photosPermission.status;
        
        if (!photosStatus.isGranted && photosStatus.isPermanentlyDenied) {
          // Só abrir configurações se realmente estiver permanentemente negada
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permissão necessária'),
              content: const Text('Para selecionar fotos da galeria, é necessário permitir o acesso às fotos nas configurações do dispositivo.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                  ),
                  child: const Text('Abrir Configurações', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          
          if (shouldOpenSettings == true && mounted) {
            await openAppSettings();
          }
        }
      }
    } catch (e) {
      print('Erro ao selecionar imagem: $e');
      if (mounted) {
        AppAlerts.showError(
          context,
          message: 'Não foi possível abrir suas fotos agora. Tente novamente.',
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImages.removeAt(index);
    });
  }

  Future<void> _uploadImages(String bookingId) async {
    if (_uploadedImages.isEmpty) return;

    print('📤 [BookingScreen] Iniciando upload de ${_uploadedImages.length} imagem(ns)');
    
    for (int i = 0; i < _uploadedImages.length; i++) {
      final imageFile = _uploadedImages[i];
      try {
        // Verificar se o arquivo existe antes de fazer upload
        if (!await imageFile.exists()) {
          print('❌ [BookingScreen] Arquivo não existe antes do upload: ${imageFile.path}');
          continue;
        }
        
        final fileSize = await imageFile.length();
        print('📤 [BookingScreen] Upload ${i + 1}/${_uploadedImages.length}: ${imageFile.path} (${fileSize} bytes)');
        
        final result = await _uploadService.uploadImage(
          imageFile,
          bookingId,
          onProgress: (progress) {
            print('📤 [BookingScreen] Upload progress: ${progress.percentage.toStringAsFixed(0)}%');
          },
        );

        if (result.success) {
          print('✅ [BookingScreen] Upload bem-sucedido: ${result.imageUrl}');
          // Limpar arquivo temporário após upload bem-sucedido
          try {
            await _photoService.deleteTempPhoto(imageFile.path);
          } catch (e) {
            print('⚠️ [BookingScreen] Erro ao deletar arquivo temporário: $e');
          }
        } else {
          print('❌ [BookingScreen] Erro ao fazer upload da imagem: ${result.error}');
        }
      } catch (e, stackTrace) {
        print('❌ [BookingScreen] Erro ao fazer upload da imagem: $e');
        print('❌ [BookingScreen] Stack trace: $stackTrace');
      }
    }
    
    print('📤 [BookingScreen] Upload de imagens concluído');
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }
}











