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
  final _colorController = TextEditingController();
  final _fuelController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _loading = false;

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

  Future<void> _searchVehicleByPlate() async {
    if (_plateController.text.length != 7) return;
    
    setState(() => _loading = true);
    
    final result = await _apiService.searchVehicleByPlate(_plateController.text);
    
    setState(() => _loading = false);
    
    if (result['success'] && result['data'] != null) {
      final vehicleData = result['data'];
      setState(() {
        _brandController.text = vehicleData['brand'] ?? '';
        _modelController.text = vehicleData['model'] ?? '';
        _yearController.text = vehicleData['year']?.toString() ?? '';
        _colorController.text = vehicleData['color'] ?? '';
        _fuelController.text = vehicleData['fuel'] ?? '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dados do veículo preenchidos automaticamente!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veículo não encontrado. Preencha os dados manualmente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final vehicleData = {
      'customerId': 'cus_KM5SA01GI', // TODO: Obter do usuário logado
      'plate': _plateController.text.toUpperCase(),
      'brand': _brandController.text,
      'model': _modelController.text,
      'year': int.tryParse(_yearController.text),
      'color': _colorController.text,
    };

    final result = await _apiService.addVehicle(vehicleData);

    setState(() => _loading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Veículo adicionado com sucesso!'),
          backgroundColor: Color(0xFF00C977),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Erro ao adicionar veículo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Veículo'),
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
                decoration: InputDecoration(
                  labelText: 'Placa do Veículo',
                  hintText: 'Ex: ABC1234',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchVehicleByPlate,
                  ),
                ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                  LengthLimitingTextInputFormatter(7),
                      ],
                onChanged: (value) {
                  if (value.length == 7) {
                    _searchVehicleByPlate();
                  }
                },
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
                  prefixIcon: Icon(Icons.model_training),
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
              TextFormField(
                controller: _fuelController,
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  prefixIcon: Icon(Icons.local_gas_station),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o tipo de combustível';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              
              // Botão Salvar
              _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C977)))
                  : ElevatedButton(
                      onPressed: _saveVehicle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C977),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Salvar Veículo',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}