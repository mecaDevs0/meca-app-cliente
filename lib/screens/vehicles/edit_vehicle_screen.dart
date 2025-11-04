import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

class EditVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const EditVehicleScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _fuelController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _loading = false;
  String? _selectedFuel;

  @override
  void initState() {
    super.initState();
    // Preencher campos com dados do veículo
    _plateController.text = widget.vehicle['plate'] ?? '';
    _brandController.text = widget.vehicle['brand'] ?? '';
    _modelController.text = widget.vehicle['model'] ?? '';
    _yearController.text = widget.vehicle['year']?.toString() ?? '';
    _colorController.text = widget.vehicle['color'] ?? '';
    _selectedFuel = widget.vehicle['fuel'] ?? widget.vehicle['fuel_type'];
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _fuelController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // Obter ID do cliente do perfil
    String? customerId;
    try {
      final profileResult = await _apiService.getProfile();
      if (profileResult['success'] && profileResult['data'] != null) {
        customerId = profileResult['data']['id'] ?? 
                    profileResult['data']['customer_id'];
      }
    } catch (e) {
      print('Erro ao obter perfil: $e');
    }

    if (customerId == null || customerId.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erro: Não foi possível identificar o usuário. Faça login novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final vehicleData = {
      'customerId': customerId,
      'plate': _plateController.text.toUpperCase(),
      'brand': _brandController.text,
      'model': _modelController.text,
      'year': int.tryParse(_yearController.text),
      'color': _colorController.text,
    };

    final result = await _apiService.updateVehicle(
      widget.vehicle['id'].toString(),
      vehicleData,
    );

    setState(() => _loading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Veículo atualizado com sucesso!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Erro ao atualizar veículo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Veículo'),
        backgroundColor: const Color(0xFF00C977),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Placa
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(
                  labelText: 'Placa do Veículo',
                  hintText: 'Ex: ABC1234',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a placa do veículo';
                  }
                  if (value.length < 7) {
                    return 'A placa deve ter 7 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Marca
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.branding_watermark),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a marca do veículo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Modelo
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o modelo do veículo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Ano
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o ano do veículo';
                  }
                  if (int.tryParse(value) == null || value.length != 4) {
                    return 'Por favor, insira um ano válido (ex: 2020)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Cor
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a cor do veículo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Combustível
              DropdownButtonFormField<String>(
                value: _selectedFuel,
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  prefixIcon: Icon(Icons.local_gas_station),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Gasolina', child: Text('Gasolina')),
                  DropdownMenuItem(value: 'Etanol', child: Text('Etanol')),
                  DropdownMenuItem(value: 'Flex', child: Text('Flex')),
                  DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                  DropdownMenuItem(value: 'Elétrico', child: Text('Elétrico')),
                  DropdownMenuItem(value: 'Híbrido', child: Text('Híbrido')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFuel = value;
                  });
                },
              ),
              const SizedBox(height: 30),
              
              // Botão Salvar
              ElevatedButton(
                onPressed: _loading ? null : _saveVehicle,
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar Alterações',
                        style: TextStyle(
                          fontSize: 16,
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
}


