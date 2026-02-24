import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';

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
  String? _selectedFuel;
  String _lastSearchedPlate = '';
  bool _plateAlreadySearched = false;
  Timer? _plateDebounceTimer;
  bool _isSearchingPlate = false;
  bool _plateNotFound = false;
  bool _allowManualInput = false;

  static const List<String> _fuelOptions = [
    'Gasolina',
    'Etanol',
    'Flex',
    'Diesel',
    'GNV',
    'Elétrico',
    'Híbrido',
  ];

  String? _normalizeFuelValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    // Map variações comuns retornadas pela API para opções conhecidas
    switch (trimmed.toLowerCase()) {
      case 'gasolina':
      case 'gasoline':
        return 'Gasolina';
      case 'etanol':
      case 'álcool':
      case 'alcool':
        return 'Etanol';
      case 'flex':
      case 'alcool / gasolina':
      case 'álcool / gasolina':
      case 'etanol / gasolina':
      case 'gasolina / etanol':
      case 'alcool/gasolina':
        return 'Flex';
      case 'diesel':
        return 'Diesel';
      case 'gnv':
        return 'GNV';
      case 'elétrico':
      case 'eletrico':
      case 'electric':
        return 'Elétrico';
      case 'híbrido':
      case 'hibrido':
      case 'hybrid':
        return 'Híbrido';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _plateDebounceTimer?.cancel();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _fuelController.dispose();
    super.dispose();
  }

  void _onPlateChanged(String value) {
    _plateDebounceTimer?.cancel();

    final normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().trim();

    if (normalized.length < 7) {
      if (_brandController.text.isNotEmpty) {
        setState(() {
          _brandController.clear();
          _modelController.clear();
          _yearController.clear();
          _colorController.clear();
          _plateNotFound = false;
          _allowManualInput = false;
          _lastSearchedPlate = '';
          _plateAlreadySearched = false;
        });
      }
      return;
    }

    if (normalized == _lastSearchedPlate && _plateAlreadySearched) {
      debugPrint('🛡️ [AddCar] Placa já buscada anteriormente: $normalized — SKIP');
      return;
    }

    if (normalized.length == 7) {
      _plateDebounceTimer = Timer(const Duration(milliseconds: 800), () {
        if (!_isSearchingPlate) {
          _lastSearchedPlate = normalized;
          _fetchVehicleByPlate(normalized);
        }
      });
    }
  }

  Future<void> _fetchVehicleByPlate(String plate) async {
    if (_isSearchingPlate) return;

    if (_plateAlreadySearched && _lastSearchedPlate == plate && _brandController.text.isNotEmpty) {
      debugPrint('🛡️ [AddCar] Dados já carregados para $plate — SKIP');
      return;
    }

    setState(() {
      _isSearchingPlate = true;
      _plateNotFound = false;
      _allowManualInput = false;
    });

    try {
      final result = await _apiService.searchVehicleByPlate(plate);

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() => _plateAlreadySearched = true);
        _fillFormWithVehicleData(data);
      } else {
        final allowManual = result['allowManualInput'] != false;
        final errMsg = result['error']?.toString() ?? result['message']?.toString() ?? 'Placa não encontrada. Preencha manualmente.';
        print('ℹ️ [AddCar] Não encontrado — allowManualInput: $allowManual');
        setState(() {
          _plateNotFound = true;
          _allowManualInput = allowManual;
          _plateAlreadySearched = true;
        });
        AppAlerts.showWarning(context, message: errMsg, title: 'Placa não encontrada');
        if (allowManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Placa não encontrada. Preencha os dados manualmente.', style: TextStyle(color: Colors.white))),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [AddCar] Erro: $e');
      if (mounted) {
        setState(() {
          _plateNotFound = true;
          _allowManualInput = true;
        });
        AppAlerts.showError(context, message: 'Não foi possível consultar a placa. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isSearchingPlate = false);
    }
  }

  void _fillFormWithVehicleData(Map<String, dynamic> data) {
    setState(() {
      _brandController.text = _capitalize(data['brand']?.toString() ?? '');
      _modelController.text = _capitalize(data['model']?.toString() ?? '');
      _yearController.text = data['year']?.toString() ?? '';
      _colorController.text = _capitalize(data['color']?.toString() ?? '');
      final normalizedFuel = _normalizeFuelValue(data['fuel']?.toString());
      _selectedFuel = normalizedFuel;
      _fuelController.text = normalizedFuel ?? '';
      _plateNotFound = false;
      _allowManualInput = false;
      _plateAlreadySearched = true;
    });

    final source = data['source'] ?? '';
    final label = source == 'rds_cache' ? 'cache interno'
        : source == 'apiplacas' ? '🚗 API Placas'
        : source == 'placa_fipe' ? 'Placa FIPE'
        : source == 'apibrasil' ? 'API Brasil'
        : source == 'sinesp' ? 'SINESP'
        : source;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Dados encontrados via $label', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
  }

  Future<void> _searchVehicleByPlate() async {
    final plate = _plateController.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (plate.length < 7) {
      AppAlerts.showWarning(context, message: 'Digite uma placa válida com 7 caracteres.', title: 'Placa incompleta');
      return;
    }
    if (_plateAlreadySearched && _lastSearchedPlate == plate && _brandController.text.isNotEmpty) return;
    if (_isSearchingPlate) return;
    _lastSearchedPlate = plate;
    await _fetchVehicleByPlate(plate);
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
      AppAlerts.showError(
        context,
        message: 'Não foi possível identificar o usuário. Faça login novamente.',
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
      'fuel': _selectedFuel ?? _fuelController.text,
    };

    final result = await _apiService.addVehicle(vehicleData);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success']) {
      await AppAlerts.showSuccess(
        context,
        message: (result['message'] ?? 'Veículo adicionado com sucesso!').toString(),
        title: 'Tudo certo!',
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      AppAlerts.showError(
        context,
        message: result['error'] ?? 'Não foi possível adicionar o veículo agora. Tente novamente.',
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
                onChanged: _onPlateChanged,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Placa do Veículo',
                  hintText: 'Ex: ABC1234 ou ABC1D23',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: const OutlineInputBorder(),
                  suffixIcon: _isSearchingPlate
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: _plateNotFound
                              ? const Icon(Icons.search_off, color: Colors.orange)
                              : _brandController.text.isNotEmpty
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.search),
                          onPressed: _isSearchingPlate ? null : _searchVehicleByPlate,
                        ),
                ),
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
              if (_plateNotFound && _allowManualInput)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Dados não encontrados. Preencha manualmente abaixo.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                  ),
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
              DropdownButtonFormField<String>(
                value: _fuelOptions.contains(_selectedFuel) ? _selectedFuel : null,
                decoration: const InputDecoration(
                  labelText: 'Combustível',
                  prefixIcon: Icon(Icons.local_gas_station, color: Color(0xFF00C977)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    borderSide: BorderSide(color: Color(0xFF00C977), width: 2),
                  ),
                ),
                items: _fuelOptions
                    .map(
                      (fuel) => DropdownMenuItem(
                        value: fuel,
                        child: Text(fuel),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFuel = value;
                    _fuelController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione o tipo de combustível';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              
              SizedBox(height: 40),
              
              // Botão Salvar
              ElevatedButton(
                onPressed: _loading ? null : _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00C977),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                ),
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Adicionar Veículo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

