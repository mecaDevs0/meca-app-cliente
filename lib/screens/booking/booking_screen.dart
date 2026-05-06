import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/photo/photo_repository.dart';
import '../../services/photo/photo_service.dart';
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
  TimeOfDay? _selectedTimeEnd; // Para janelas de horário
  String _scheduleType = 'specific_time'; // 'specific_time', 'time_window', 'day_only'
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
      final result = await _apiService.getWorkshopServices(widget.workshopId);
      
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
    
    // Validação baseada no tipo de agendamento
    if (_scheduleType == 'specific_time') {
      if (_selectedTime == null) {
        await _showSnackBar('Selecione um horário', isError: true);
        return;
      }
    } else if (_scheduleType == 'time_window') {
      if (_selectedTime == null || _selectedTimeEnd == null) {
        await _showSnackBar('Selecione a janela de horário (início e fim)', isError: true);
        return;
      }
    }

    setState(() => _isCreatingBooking = true);

    try {
      final Map<String, dynamic> bookingData = {
        'customer_id': userId,
        'vehicle_id': _selectedVehicle!['id'],
        'oficina_id': widget.workshopId,
        'product_id': _selectedService!['service_id'] ?? _selectedService!['id'],
        'customer_notes': _observationsController.text.trim(),
        'status': 'pendente_oficina',
        'schedule_type': _scheduleType, // 'specific_time', 'time_window', 'day_only'
      };

      // Adicionar data e horário baseado no tipo
      if (_scheduleType == 'specific_time' && _selectedTime != null) {
        // Horário fixo: usar appointment_date
        final DateTime appointmentDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        bookingData['appointment_date'] = appointmentDateTime.toIso8601String();
      } else if (_scheduleType == 'time_window' && _selectedTime != null && _selectedTimeEnd != null) {
        // Janela de serviço: usar appointment_date para início e time_window_end para fim
        final DateTime startDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        final DateTime endDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTimeEnd!.hour,
          _selectedTimeEnd!.minute,
        );
        bookingData['appointment_date'] = startDateTime.toIso8601String();
        bookingData['time_window_end'] = endDateTime.toIso8601String();
        bookingData['time_window_start'] = startDateTime.toIso8601String();
      } else {
        // Apenas dia: usar appointment_date sem hora específica
        final DateTime appointmentDate = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        bookingData['appointment_date'] = appointmentDate.toIso8601String();
      }


      final result = await _apiService.createBooking(bookingData);
      
      if (result['success'] == true) {
        final bookingId = result['data']['id'] ?? result['data']['booking_id'];
        
        // Fazer upload das imagens se houver
        if (_uploadedImages.isNotEmpty && bookingId != null) {
          await _uploadImages(bookingId);
        }
        
        // Agendar lembretes de notificação
        try {
          // Usar a data de início para o lembrete
          DateTime scheduledDate;
          if (_scheduleType == 'specific_time' && _selectedTime != null) {
            scheduledDate = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            );
          } else if (_scheduleType == 'time_window' && _selectedTime != null) {
            scheduledDate = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            );
          } else {
            scheduledDate = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              9, // Horário padrão 9h
              0,
            );
          }
          
          await _notificationService.scheduleBookingReminders(
            workshopName: widget.workshopName,
            serviceName: widget.serviceName,
            scheduledDate: scheduledDate,
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
      body: GestureDetector(
        onTap: () {
          // Fechar teclado ao clicar fora
          FocusScope.of(context).unfocus();
        },
        child: _isLoading
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
    final sortedServices = List<Map<String, dynamic>>.from(_workshopServices);
    sortedServices.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      if (aName.contains('mecânica geral')) return -1;
      if (bName.contains('mecânica geral')) return 1;
      return 0;
    });

    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final fillColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F7);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey[500]! : Colors.grey[400]!;
    final dropdownBg = isDarkMode ? const Color(0xFF252525) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
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
              const Icon(Icons.build, color: Color(0xFF00C977), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Selecionar Serviço',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedService,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _selectedService != null ? const Color(0xFF00C977) : Colors.grey[500],
              size: 24,
            ),
            decoration: InputDecoration(
              hintText: 'Escolha um serviço',
              hintStyle: TextStyle(color: hintColor, fontSize: 15, fontWeight: FontWeight.w400),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _selectedService != null
                      ? const Color(0xFF00C977)
                      : (isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.06)),
                  width: _selectedService != null ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C977), width: 1.5),
              ),
            ),
            dropdownColor: dropdownBg,
            borderRadius: BorderRadius.circular(14),
            menuMaxHeight: 320,
            style: TextStyle(color: textColor, fontSize: 15),
            isExpanded: true,
            selectedItemBuilder: (context) {
              return sortedServices.map((service) {
                final name = service['name'] ?? 'Serviço';
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList();
            },
            items: sortedServices.map((service) {
              final serviceName = service['name'] ?? 'Serviço';
              final isGeral = serviceName.toString().toLowerCase().contains('mecânica geral');
              final isSelected = _selectedService != null &&
                  (_selectedService!['id']?.toString() == service['id']?.toString() ||
                   _selectedService!['service_id']?.toString() == service['service_id']?.toString());

              return DropdownMenuItem<Map<String, dynamic>>(
                value: service,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00C977)
                              : const Color(0xFF00C977).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isGeral ? Icons.build_rounded : Icons.car_repair_rounded,
                          color: isSelected ? Colors.white : const Color(0xFF00C977),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              serviceName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: isGeral ? 15 : 14,
                                fontWeight: isGeral ? FontWeight.w700 : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (isGeral)
                              Text(
                                'Recomendado quando não sabe o problema',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF00C977), size: 20),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedService = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Se não souber o problema do carro, selecione Mecânica geral e descreva no campo Observações.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
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
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/add-vehicle');
                        _apiService.invalidateVehiclesCache();
                        _loadUserVehicles();
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
            if (vehicle['is_default'] == true || vehicle['isDefault'] == true)
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
          
          // Seleção do tipo de agendamento
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C977).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _scheduleType = 'specific_time'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _scheduleType == 'specific_time'
                            ? const Color(0xFF00C977).withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _scheduleType == 'specific_time'
                              ? const Color(0xFF00C977)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: _scheduleType == 'specific_time'
                                ? const Color(0xFF00C977)
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Horário Fixo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _scheduleType == 'specific_time'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _scheduleType == 'specific_time'
                                  ? const Color(0xFF00C977)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _scheduleType = 'time_window'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _scheduleType == 'time_window'
                            ? const Color(0xFF00C977).withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _scheduleType == 'time_window'
                              ? const Color(0xFF00C977)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: _scheduleType == 'time_window'
                                ? const Color(0xFF00C977)
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Janela',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _scheduleType == 'time_window'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _scheduleType == 'time_window'
                                  ? const Color(0xFF00C977)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Seleção de data - UI melhorada
          _buildDateButton(isDarkMode),
          const SizedBox(height: 20),
          
          // Seleção de horário baseado no tipo - UI melhorada
          if (_scheduleType == 'specific_time') ...[
            _buildTimeButton(isDarkMode),
            if (_selectedDate != null && _selectedTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00C977).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: const Color(0xFF00C977),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Horário confirmado: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)} às ${_selectedTime!.format(context)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF00C977),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (_scheduleType == 'time_window') ...[
            _buildTimeWindowButtons(isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildDateButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedDate != null
              ? const Color(0xFF00C977).withOpacity(0.1)
              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedDate != null 
                ? const Color(0xFF00C977) 
                : Colors.grey[400]!,
            width: _selectedDate != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Data',
              style: TextStyle(
                      fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
                  const SizedBox(height: 2),
                  Text(
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'Selecionar data',
                style: TextStyle(
                      fontSize: 15,
                  color: _selectedDate != null 
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedTime != null
              ? const Color(0xFF00C977).withOpacity(0.1)
              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedTime != null 
                ? const Color(0xFF00C977) 
                : Colors.grey[400]!,
            width: _selectedTime != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C977),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.access_time,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Horário',
              style: TextStyle(
                      fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
                  const SizedBox(height: 2),
                  Text(
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Selecionar horário',
                style: TextStyle(
                      fontSize: 15,
                  color: _selectedTime != null 
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWindowButtons(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectTimeWindowStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedTime != null
                        ? const Color(0xFF00C977).withOpacity(0.1)
                        : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedTime != null 
                          ? const Color(0xFF00C977) 
                          : Colors.grey[400]!,
                      width: _selectedTime != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C977),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                              'Inicio',
                        style: TextStyle(
                                fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                            const SizedBox(height: 2),
                            Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                                  : 'Inicio',
                          style: TextStyle(
                                fontSize: 14,
                            color: _selectedTime != null 
                                ? (isDarkMode ? Colors.white : Colors.black)
                                : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(
                Icons.arrow_forward,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectTimeWindowEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedTimeEnd != null
                        ? const Color(0xFF00C977).withOpacity(0.1)
                        : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedTimeEnd != null 
                          ? const Color(0xFF00C977) 
                          : Colors.grey[400]!,
                      width: _selectedTimeEnd != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C977),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                              'Fim',
                        style: TextStyle(
                                fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                            const SizedBox(height: 2),
                            Text(
                          _selectedTimeEnd != null
                              ? _selectedTimeEnd!.format(context)
                              : 'Fim',
                          style: TextStyle(
                                fontSize: 14,
                            color: _selectedTimeEnd != null 
                                ? (isDarkMode ? Colors.white : Colors.black)
                                : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedTime != null && _selectedTimeEnd != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00C977).withOpacity(0.15),
                  const Color(0xFF00B369).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C977).withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                  color: const Color(0xFF00C977),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Janela de horário confirmada',
                    style: TextStyle(
                          fontSize: 13,
                      color: const Color(0xFF00C977),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedTime!.format(context)} até ${_selectedTimeEnd!.format(context)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<TimeOfDay?> _showWheelTimePicker({TimeOfDay? initialTime}) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final initial = initialTime ?? TimeOfDay.now();
    int selectedHour = initial.hour;
    int selectedMinute = (initial.minute / 5).round() * 5;
    if (selectedMinute >= 60) selectedMinute = 55;

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: 320,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selecione o horário',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close, color: isDarkMode ? Colors.grey : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Hora', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: FixedExtentScrollController(initialItem: selectedHour),
                                    itemExtent: 40,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      background: const Color(0xFF00C977).withOpacity(0.12),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setSheetState(() => selectedHour = index);
                                    },
                                    children: List.generate(24, (i) => Center(
                                      child: Text(
                                        i.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    )),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Minuto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: FixedExtentScrollController(initialItem: selectedMinute ~/ 5),
                                    itemExtent: 40,
                                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                      background: const Color(0xFF00C977).withOpacity(0.12),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setSheetState(() => selectedMinute = index * 5);
                                    },
                                    children: List.generate(12, (i) => Center(
                                      child: Text(
                                        (i * 5).toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    )),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, TimeOfDay(hour: selectedHour, minute: selectedMinute)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C977),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _selectTimeWindowStart() async {
    final selectedTime = await _showWheelTimePicker(
      initialTime: _selectedTime ?? const TimeOfDay(hour: 14, minute: 0),
    );

    if (selectedTime != null) {
      setState(() {
        _selectedTime = selectedTime;
        if (_selectedTimeEnd != null &&
            (selectedTime.hour > _selectedTimeEnd!.hour ||
             (selectedTime.hour == _selectedTimeEnd!.hour && selectedTime.minute >= _selectedTimeEnd!.minute))) {
          _selectedTimeEnd = null;
        }
      });
    }
  }

  Future<void> _selectTimeWindowEnd() async {
    final initialTime = _selectedTimeEnd ??
                       (_selectedTime != null
                           ? TimeOfDay(
                               hour: _selectedTime!.hour + 2,
                               minute: _selectedTime!.minute,
                             )
                           : const TimeOfDay(hour: 18, minute: 0));

    final selectedTime = await _showWheelTimePicker(initialTime: initialTime);

    if (selectedTime != null) {
      if (_selectedTime != null) {
        final startMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute;
        final endMinutes = selectedTime.hour * 60 + selectedTime.minute;

        if (endMinutes <= startMinutes) {
          await _showSnackBar('O horário de fim deve ser depois do horário de início', isError: true);
          return;
        }
      }

      setState(() {
        _selectedTimeEnd = selectedTime;
      });
    }
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
            textCapitalization: TextCapitalization.sentences,
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











