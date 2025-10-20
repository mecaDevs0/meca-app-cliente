import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../utils/colors.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _corController = TextEditingController();
  bool _isLoading = false;

  Future<void> _lookupByPlate() async {
    if (_placaController.text.isEmpty) return;

    setState(() => _isLoading = true);

    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final data = await vehicleProvider.lookupByPlate(_placaController.text);

    setState(() => _isLoading = false);

    if (data != null) {
      _marcaController.text = data['brand'] ?? '';
      _modeloController.text = data['model'] ?? '';
      _anoController.text = data['year']?.toString() ?? '';
      _corController.text = data['color'] ?? '';
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final success = await vehicleProvider.addVehicle({
      'placa': _placaController.text,
      'marca': _marcaController.text,
      'modelo': _modeloController.text,
      'ano': int.tryParse(_anoController.text) ?? 0,
      'cor': _corController.text,
    });

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo cadastrado com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao cadastrar veículo')),
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
        title: const Text('Adicionar Veículo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _placaController,
              decoration: InputDecoration(
                labelText: 'Placa',
                hintText: 'ABC1234',
                prefixIcon: const Icon(Icons.pin, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.primary),
                  onPressed: _lookupByPlate,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Digite a placa' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _marcaController,
              decoration: InputDecoration(
                labelText: 'Marca',
                prefixIcon: const Icon(Icons.business, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Digite a marca' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modeloController,
              decoration: InputDecoration(
                labelText: 'Modelo',
                prefixIcon: const Icon(Icons.directions_car, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Digite o modelo' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _anoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Ano',
                prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Digite o ano' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _corController,
              decoration: InputDecoration(
                labelText: 'Cor',
                prefixIcon: const Icon(Icons.color_lens, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveVehicle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Salvar Veículo',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _corController.dispose();
    super.dispose();
  }
}

