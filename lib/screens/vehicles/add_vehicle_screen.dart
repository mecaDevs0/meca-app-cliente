import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({Key? key}) : super(key: key);

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _loading = false;
  bool _searchingPlate = false;

  Future<void> _searchByPlate() async {
    if (_plateController.text.isEmpty) return;

    setState(() => _searchingPlate = true);

    final result = await _apiService.searchVehicleByPlate(_plateController.text);

    setState(() => _searchingPlate = false);

    if (result['success'] && result['data'] != null) {
      final vehicleData = result['data'];
      _brandController.text = vehicleData['brand'] ?? '';
      _modelController.text = vehicleData['model'] ?? '';
      _yearController.text = vehicleData['year']?.toString() ?? '';
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do veículo encontrados!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final result = await _apiService.addVehicle(
      plate: _plateController.text.toUpperCase(),
      brand: _brandController.text,
      model: _modelController.text,
      year: int.parse(_yearController.text),
    );

    setState(() => _loading = false);

    if (result['success']) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veículo adicionado com sucesso!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Adicionar Veículo',
          style: TextStyle(
            color: Color(0xFF252940),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF252940)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Plate Search
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plateController,
                      decoration: InputDecoration(
                        labelText: 'Placa',
                        hintText: 'ABC-1234',
                        prefixIcon: const Icon(Icons.car_rental, color: Color(0xFF00C977)),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Campo obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _searchingPlate ? null : _searchByPlate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _searchingPlate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'Busque pela placa para preencher automaticamente',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 30),

              // Brand
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ex: Fiat, Volkswagen, Ford',
                  prefixIcon: const Icon(Icons.business, color: Color(0xFF00C977)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
                  ),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 15),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Ex: Uno, Gol, Ka',
                  prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF00C977)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
                  ),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 15),

              // Year
              TextFormField(
                controller: _yearController,
                decoration: InputDecoration(
                  labelText: 'Ano',
                  hintText: 'Ex: 2024',
                  prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF00C977)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF00C977), width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Campo obrigatório';
                  final year = int.tryParse(value);
                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                    return 'Ano inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Save Button
              ElevatedButton(
                onPressed: _loading ? null : _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C977),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Adicionar Veículo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }
}
