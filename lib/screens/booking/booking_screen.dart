import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../vehicles/my_vehicles_screen.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  final String workshopId;
  final Map<String, dynamic> service;

  const BookingScreen({
    Key? key,
    required this.serviceId,
    required this.workshopId,
    required this.service,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  List<dynamic> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<File> _attachedFiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);
    
    // TODO: Obter customerId do usuário logado
    final customerId = 'cus_KM5SA01GI';
    
    final result = await _apiService.getMyVehicles(customerId);
    
    if (result['success']) {
      setState(() {
        _vehicles = result['data']['vehicles'] ?? [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Erro ao carregar veículos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode 
              ? const Color(0xFF121212) 
              : const Color(0xFFFAFAFA),
          appBar: AppBar(
            title: const Text('Agendar Serviço'),
            backgroundColor: const Color(0xFF00C977),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
              : _buildBookingForm(),
        );
      },
    );
  }

  Widget _buildBookingForm() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Informações do serviço
            _buildServiceInfo(),
            const SizedBox(height: 24),
            
            // Seleção de veículo
            _buildVehicleSelection(),
            const SizedBox(height: 24),
            
            // Seleção de data
            _buildDateSelection(),
            const SizedBox(height: 24),
            
            // Seleção de horário
            _buildTimeSelection(),
            const SizedBox(height: 24),
            
            // Observações
            _buildNotesField(),
            const SizedBox(height: 24),
            
            // Upload de arquivos
            _buildFileUpload(),
            const SizedBox(height: 32),
            
            // Botão de agendamento
            _buildBookButton(),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildServiceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serviço Selecionado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build,
                    color: Color(0xFF00C977),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.service['description'] ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.service['price'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'R\$ ${widget.service['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF00C977),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Selecionar Veículo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyVehiclesScreen()),
                );
                if (result != null) {
                  _loadVehicles();
                }
              },
              child: const Text('Gerenciar Veículos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nenhum veículo cadastrado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cadastre um veículo para continuar',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/add-vehicle');
                    if (result != null) {
                      _loadVehicles();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                  ),
                  child: const Text('Cadastrar Veículo'),
                ),
              ],
            ),
          )
        else
          ..._vehicles.map((vehicle) {
            final isSelected = _selectedVehicle?['id'] == vehicle['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedVehicle = vehicle;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00C977) : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? const Color(0xFF00C977).withOpacity(0.1) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF00C977) : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vehicle['brand']} ${vehicle['model']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Placa: ${vehicle['plate']}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecionar Data',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
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
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Selecione uma data',
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

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecionar Horário',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectedDate != null ? _selectTime : null,
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
                      ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                      : 'Selecione um horário',
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

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observações (Opcional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Descreva o problema ou observações adicionais...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildBookButton() {
    final canBook = _selectedVehicle != null && _selectedDate != null && _selectedTime != null;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canBook ? _bookService : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canBook ? const Color(0xFF00C977) : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirmar Agendamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Widget _buildFileUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Anexar Arquivos (Opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252940),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adicione fotos do veículo para ajudar a oficina a entender melhor o problema',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        
        // Botão para adicionar arquivo
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00C977),
                style: BorderStyle.solid,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF00C977).withOpacity(0.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.add_photo_alternate,
                  color: Color(0xFF00C977),
                ),
                SizedBox(width: 8),
                Text(
                  'Adicionar Foto',
                  style: TextStyle(
                    color: Color(0xFF00C977),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Lista de arquivos anexados
        if (_attachedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._attachedFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Color(0xFF00C977)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _attachedFiles.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _attachedFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _bookService() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    
    final bookingData = {
      'customerId': 'cus_KM5SA01GI', // TODO: Obter do usuário logado
      'vehicleId': _selectedVehicle!['id'],
      'workshopId': widget.workshopId,
      'serviceId': widget.serviceId,
      'scheduledDate': scheduledDateTime.toIso8601String(),
      'notes': _notesController.text,
      'attachedFiles': _attachedFiles.map((file) => file.path).toList(),
    };
    
    final result = await _apiService.createBooking(bookingData);
    
    setState(() => _loading = false);
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Agendamento realizado com sucesso!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
      Navigator.pushReplacementNamed(context, '/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Erro ao agendar serviço'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
