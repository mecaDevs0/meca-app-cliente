import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> workshop;

  const BookingScreen({
    super.key,
    required this.workshop,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedVehicle;
  final List<String> _selectedServices = [];
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = false;
  List<dynamic> _vehicles = [];
  List<dynamic> _services = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load vehicles
    final vehiclesResult = await _apiService.getMyVehicles();
    if (vehiclesResult['success']) {
      setState(() {
        _vehicles = vehiclesResult['data'] ?? [];
      });
    }

    // Load services (mock data for now)
    setState(() {
      _services = [
        {'id': '1', 'name': 'Troca de Óleo', 'price': 150.00},
        {'id': '2', 'name': 'Alinhamento', 'price': 80.00},
        {'id': '3', 'name': 'Balanceamento', 'price': 60.00},
        {'id': '4', 'name': 'Revisão Completa', 'price': 300.00},
        {'id': '5', 'name': 'Troca de Pastilhas', 'price': 200.00},
      ];
    });
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnackBar('Selecione uma data', isError: true);
      return;
    }
    if (_selectedTime == null) {
      _showSnackBar('Selecione um horário', isError: true);
      return;
    }
    if (_selectedVehicle == null) {
      _showSnackBar('Selecione um veículo', isError: true);
      return;
    }
    if (_selectedServices.isEmpty) {
      _showSnackBar('Selecione pelo menos um serviço', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.createBooking(
      workshopId: widget.workshop['id'].toString(),
      vehicleId: _selectedVehicle!,
      serviceIds: _selectedServices,
      scheduledDate: _selectedDate!.toIso8601String(),
      scheduledTime: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackBar('Agendamento realizado com sucesso!');
      Navigator.pop(context);
    } else {
      _showSnackBar(result['error'] ?? 'Erro ao criar agendamento', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF00C977),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final bgColor = ThemeService.getBackgroundColor(isDark);
    final cardColor = ThemeService.getCardColor(isDark);
    final textColor = ThemeService.getTextColor(isDark);
    final secondaryTextColor = ThemeService.getSecondaryTextColor(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agendar Serviço',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workshop Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: const Color(0xFF2A2A2A)) : null,
                  boxShadow: !isDark ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        color: Color(0xFF00C977),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workshop['name'] ?? 'Oficina',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            widget.workshop['address'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Date Selection
              _buildSectionTitle('Data', textColor),
              const SizedBox(height: 12),
              _buildDateSelector(isDark, cardColor, textColor, secondaryTextColor),

              const SizedBox(height: 20),

              // Time Selection
              _buildSectionTitle('Horário', textColor),
              const SizedBox(height: 12),
              _buildTimeSelector(isDark, cardColor, textColor, secondaryTextColor),

              const SizedBox(height: 20),

              // Vehicle Selection
              _buildSectionTitle('Veículo', textColor),
              const SizedBox(height: 12),
              _buildVehicleSelector(isDark, cardColor, textColor, secondaryTextColor),

              const SizedBox(height: 20),

              // Services Selection
              _buildSectionTitle('Serviços', textColor),
              const SizedBox(height: 12),
              _buildServicesSelector(isDark, cardColor, textColor, secondaryTextColor),

              const SizedBox(height: 20),

              // Notes
              _buildSectionTitle('Observações (opcional)', textColor),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Descreva o problema ou detalhes adicionais...',
                  hintStyle: TextStyle(color: secondaryTextColor),
                  filled: true,
                  fillColor: ThemeService.getInputColor(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00C977),
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
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
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildDateSelector(bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF00C977),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: const Color(0xFF00C977),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedDate == null
                  ? 'Selecione uma data'
                  : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
              style: TextStyle(
                fontSize: 15,
                color: _selectedDate == null ? secondaryTextColor : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return GestureDetector(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF00C977),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: const Color(0xFF00C977),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _selectedTime == null
                  ? 'Selecione um horário'
                  : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 15,
                color: _selectedTime == null ? secondaryTextColor : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector(bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    if (_vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car, color: secondaryTextColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum veículo cadastrado',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/add-vehicle');
              },
              child: const Text('Cadastrar'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: _vehicles.map((vehicle) {
          final isSelected = _selectedVehicle == vehicle['id'];
          return ListTile(
            leading: Icon(
              Icons.directions_car,
              color: isSelected ? const Color(0xFF00C977) : secondaryTextColor,
            ),
            title: Text(
              '${vehicle['brand']} ${vehicle['model']}',
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              vehicle['plate'] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF00C977))
                : null,
            onTap: () {
              setState(() => _selectedVehicle = vehicle['id']);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServicesSelector(bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Column(
      children: _services.map((service) {
        final isSelected = _selectedServices.contains(service['id']);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00C977)
                  : isDark
                      ? const Color(0xFF444444)
                      : const Color(0xFFE0E0E0),
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedServices.add(service['id']);
                } else {
                  _selectedServices.remove(service['id']);
                }
              });
            },
            activeColor: const Color(0xFF00C977),
            title: Text(
              service['name'],
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'R\$ ${service['price'].toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF00C977),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}


