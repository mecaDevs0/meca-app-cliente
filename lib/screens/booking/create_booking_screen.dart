import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/colors.dart';

class CreateBookingScreen extends StatefulWidget {
  final String workshopId;

  const CreateBookingScreen({super.key, required this.workshopId});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  String? _selectedVehicleId;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isLoading = false;

  final List<String> _availableSlots = [
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
    '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<VehicleProvider>(context, listen: false).loadVehicles();
    });
  }

  Future<void> _createBooking() async {
    if (_selectedVehicleId == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione veículo e horário')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.createBooking({
      'vehicle_id': _selectedVehicleId,
      'workshop_id': widget.workshopId,
      'appointment_date': '${_selectedDate.toIso8601String().split('T')[0]}T$_selectedTime:00Z',
    });

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento criado com sucesso!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar agendamento')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: const Text('Agendar Serviço'),
      ),
      body: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, child) {
          if (vehicleProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Selecione o Veículo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              ...vehicleProvider.vehicles.map((vehicle) {
                final isSelected = _selectedVehicleId == vehicle['id'];
                return Card(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                  child: RadioListTile<String>(
                    value: vehicle['id'],
                    groupValue: _selectedVehicleId,
                    onChanged: (value) {
                      setState(() => _selectedVehicleId = value);
                    },
                    title: Text('${vehicle['marca']} ${vehicle['modelo']}'),
                    subtitle: Text(vehicle['placa']),
                    activeColor: AppColors.primary,
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              const Text(
                'Selecione a Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Horários Disponíveis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSlots.map((slot) {
                  final isSelected = _selectedTime == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedTime = selected ? slot : null);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.secondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Confirmar Agendamento',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

