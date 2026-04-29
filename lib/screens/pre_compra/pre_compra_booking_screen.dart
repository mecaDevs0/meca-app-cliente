import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/meca_toast.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

const _kGreen = Color(0xFF00C977);

class PreCompraBookingScreen extends StatefulWidget {
  final String? workshopId;
  final String? workshopName;

  const PreCompraBookingScreen({Key? key, this.workshopId, this.workshopName}) : super(key: key);

  @override
  State<PreCompraBookingScreen> createState() => _PreCompraBookingScreenState();
}

class _PreCompraBookingScreenState extends State<PreCompraBookingScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controladores do veículo
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Busca de placa
  Timer? _plateDebounceTimer;
  bool _isSearchingPlate = false;
  bool _plateNotFound = false;
  bool _plateAlreadySearched = false;
  String _lastSearchedPlate = '';

  // Oficinas disponíveis
  List<Map<String, dynamic>> _workshops = [];
  Map<String, dynamic>? _selectedWorkshop;
  bool _loadingWorkshops = true;

  // Agendamento
  String _scheduleType = 'specific';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _timeWindowStart = '08:00';
  String _timeWindowEnd = '12:00';

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.workshopId != null && widget.workshopId!.isNotEmpty) {
      // Workshop already chosen (came from ServiceDetailScreen or WorkshopDetailScreen)
      _selectedWorkshop = {'id': widget.workshopId, 'name': widget.workshopName ?? 'Oficina'};
      _loadingWorkshops = false;
    } else {
      _loadWorkshops();
    }
  }

  @override
  void dispose() {
    _plateDebounceTimer?.cancel();
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _kmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkshops() async {
    try {
      final result = await _api.getAllWorkshops();
      final data = result['data'];
      List<Map<String, dynamic>> list = [];
      if (data is List) {
        list = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (data is Map) {
        final nested = data['workshops'] ?? data['data'];
        if (nested is List) {
          list = nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      if (mounted) setState(() { _workshops = list; _loadingWorkshops = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingWorkshops = false; });
    }
  }

  // ─── Busca de placa ──────────────────────────────────────────────────────────

  void _onPlateChanged(String value) {
    _plateDebounceTimer?.cancel();
    final normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().trim();

    if (normalized.length < 7) {
      if (_brandCtrl.text.isNotEmpty) {
        setState(() {
          _brandCtrl.clear();
          _modelCtrl.clear();
          _yearCtrl.clear();
          _colorCtrl.clear();
          _plateNotFound = false;
          _plateAlreadySearched = false;
          _lastSearchedPlate = '';
        });
      }
      return;
    }

    if (normalized == _lastSearchedPlate && _plateAlreadySearched) return;

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
    if (_plateAlreadySearched && _lastSearchedPlate == plate && _brandCtrl.text.isNotEmpty) return;

    setState(() { _isSearchingPlate = true; _plateNotFound = false; });

    try {
      final result = await _api.searchVehicleByPlate(plate);
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _brandCtrl.text = _capitalize(data['brand']?.toString() ?? '');
          _modelCtrl.text = _capitalize(data['model']?.toString() ?? '');
          _yearCtrl.text  = data['year']?.toString() ?? '';
          _colorCtrl.text = _capitalize(data['color']?.toString() ?? '');
          _plateNotFound = false;
          _plateAlreadySearched = true;
        });
        final source = data['source']?.toString() ?? '';
        final label = source == 'rds_cache' ? 'cache' : source.isNotEmpty ? source : 'API';
        _showSnack('Veículo encontrado via $label ✓');
      } else {
        setState(() { _plateNotFound = true; _plateAlreadySearched = true; });
        _showSnack('Placa não encontrada. Preencha manualmente.', isError: true);
      }
    } catch (_) {
      if (mounted) setState(() { _plateNotFound = true; });
      _showSnack('Erro ao consultar a placa. Preencha manualmente.', isError: true);
    } finally {
      if (mounted) setState(() => _isSearchingPlate = false);
    }
  }

  Future<void> _searchByPlateButton() async {
    final plate = _plateCtrl.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (plate.length < 7) {
      _showSnack('Digite uma placa válida com 7 caracteres', isError: true);
      return;
    }
    if (_plateAlreadySearched && _lastSearchedPlate == plate && _brandCtrl.text.isNotEmpty) return;
    _lastSearchedPlate = plate;
    await _fetchVehicleByPlate(plate);
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
  }

  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _kGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _kGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkshop == null) {
      _showSnack('Selecione uma oficina', isError: true);
      return;
    }
    if (_scheduleType == 'specific' && _selectedDate == null) {
      _showSnack('Selecione a data da inspeção', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      String? appointmentDate;
      if (_selectedDate != null) {
        final dt = _scheduleType == 'specific' && _selectedTime != null
            ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
                _selectedTime!.hour, _selectedTime!.minute)
            : DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 8, 0);
        appointmentDate = dt.toIso8601String();
      }

      final body = {
        'oficina_id': _selectedWorkshop!['id'],
        'vehicle_plate': _plateCtrl.text.trim().isNotEmpty ? _plateCtrl.text.trim().toUpperCase() : null,
        'vehicle_brand': _brandCtrl.text.trim(),
        'vehicle_model': _modelCtrl.text.trim(),
        'vehicle_year': _yearCtrl.text.trim().isNotEmpty ? int.tryParse(_yearCtrl.text.trim()) : null,
        'vehicle_color': _colorCtrl.text.trim().isNotEmpty ? _colorCtrl.text.trim() : null,
        'vehicle_km': _kmCtrl.text.trim().isNotEmpty ? int.tryParse(_kmCtrl.text.trim()) : null,
        'appointment_date': appointmentDate,
        'schedule_type': _scheduleType,
        'time_window_start': _scheduleType == 'window' ? _timeWindowStart : null,
        'time_window_end': _scheduleType == 'window' ? _timeWindowEnd : null,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      final result = await _api.post('/pre-compra', body);
      if (result['success'] == true) {
        _showSnack('Pré-Compra agendada com sucesso!');
        if (!mounted) return;
        // Vai para Meus Agendamentos (tab 2) igual a qualquer outro serviço
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/orders',
          (route) => route.settings.name == '/home',
        );
      } else {
        _showSnack(result['error'] ?? 'Erro ao agendar', isError: true);
      }
    } catch (e) {
      _showSnack('Erro de conexão. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      MecaToast.show(context, msg);
    } else {
      MecaToast.showSuccess(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(builder: (context, theme, _) {
      final isDark = theme.isDarkMode;
      final bg = isDark ? const Color(0xFF0A0A0A) : Colors.grey[50]!;
      final card = isDark ? const Color(0xFF1A1A1A) : Colors.white;
      final text = isDark ? Colors.white : Colors.black87;
      final sub = isDark ? Colors.white60 : Colors.black54;

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Pré-Compra', style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
          backgroundColor: card,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kGreen),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00C977), Color(0xFF00A060)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.car_repair, color: Colors.white, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Inspeção Pré-Compra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Um mecânico vistoria o carro que você quer comprar e emite um laudo completo em PDF.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Como funciona
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withOpacity(0.35), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.checklist_rounded, color: _kGreen, size: 18),
                      const SizedBox(width: 8),
                      const Text('Como funciona', style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.2)),
                    ]),
                    const SizedBox(height: 12),
                    _howItWorksStep('1', 'Preencha os dados do carro que você quer comprar (não precisa ser seu)', isDark),
                    _howItWorksStep('2', 'Escolha a oficina e o horário para a vistoria', isDark),
                    _howItWorksStep('3', 'O mecânico inspeciona o carro e emite o laudo', isDark),
                    _howItWorksStep('4', 'Após pagamento, você baixa o PDF com o resultado completo', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Seleção de oficina
              _sectionTitle('Oficina', text),
              const SizedBox(height: 8),
              widget.workshopId != null && widget.workshopId!.isNotEmpty
                  // Workshop pre-selected (came from service/workshop detail screen)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kGreen.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: _kGreen.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.store, color: _kGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.workshopName ?? 'Oficina',
                              style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          const Icon(Icons.check_circle, color: _kGreen, size: 18),
                        ],
                      ),
                    )
                  // No workshop pre-selected: show dropdown to choose
                  : _loadingWorkshops
                      ? const Center(child: CircularProgressIndicator(color: _kGreen))
                      : _workshops.isEmpty
                          ? Center(child: Text('Nenhuma oficina encontrada', style: TextStyle(color: sub)))
                          : Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Map<String, dynamic>>(
                                  value: _selectedWorkshop,
                                  isExpanded: true,
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('Selecionar oficina', style: TextStyle(color: sub)),
                                  ),
                                  dropdownColor: card,
                                  icon: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.expand_more, color: _kGreen)),
                                  onChanged: (v) => setState(() => _selectedWorkshop = v),
                                  items: _workshops.map((w) {
                                    return DropdownMenuItem(
                                      value: w,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(w['name']?.toString() ?? 'Oficina', style: TextStyle(color: text)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
              const SizedBox(height: 20),

              // Dados do veículo
              _sectionTitle('Dados do Veículo a Inspecionar', text),
              const SizedBox(height: 4),
              Text('Digite a placa para preenchimento automático, ou preencha manualmente.',
                  style: TextStyle(fontSize: 12, color: sub)),
              const SizedBox(height: 8),
              _buildCard(isDark, card, [
                // Campo de placa com busca automática
                TextFormField(
                  controller: _plateCtrl,
                  style: TextStyle(color: text, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  onChanged: _onPlateChanged,
                  decoration: InputDecoration(
                    labelText: 'Placa',
                    hintText: 'ABC1D23',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _kGreen, width: 2)),
                    suffixIcon: _isSearchingPlate
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Buscar placa',
                            icon: Icon(
                              _plateNotFound
                                  ? Icons.search_off
                                  : _brandCtrl.text.isNotEmpty
                                      ? Icons.check_circle
                                      : Icons.search,
                              color: _plateNotFound
                                  ? Colors.orange
                                  : _brandCtrl.text.isNotEmpty
                                      ? _kGreen
                                      : (isDark ? Colors.white38 : Colors.black38),
                            ),
                            onPressed: _isSearchingPlate ? null : _searchByPlateButton,
                          ),
                  ),
                ),
                // Banner quando preenchido automaticamente
                if (_brandCtrl.text.isNotEmpty && !_plateNotFound) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome, color: _kGreen, size: 14),
                      const SizedBox(width: 6),
                      Text('Dados preenchidos automaticamente pela placa', style: TextStyle(fontSize: 11, color: _kGreen)),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                _field('Marca *', _brandCtrl, isDark, text, hint: 'Ex: Toyota',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a marca' : null),
                const SizedBox(height: 12),
                _field('Modelo *', _modelCtrl, isDark, text, hint: 'Ex: Corolla',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o modelo' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field('Ano', _yearCtrl, isDark, text, hint: '2019',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field('Cor', _colorCtrl, isDark, text, hint: 'Prata'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field('KM atual', _kmCtrl, isDark, text, hint: 'Ex: 85000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              ]),
              const SizedBox(height: 20),

              // Tipo de agendamento
              _sectionTitle('Data e Horário', text),
              const SizedBox(height: 8),
              _buildCard(isDark, card, [
                // Tipo de agendamento
                Row(
                  children: [
                    _scheduleTypeChip('specific', 'Horário fixo', isDark),
                    const SizedBox(width: 8),
                    _scheduleTypeChip('window', 'Janela', isDark),
                    const SizedBox(width: 8),
                    _scheduleTypeChip('day_only', 'Só o dia', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                // Data
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: _kGreen, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : 'Selecionar data',
                          style: TextStyle(color: _selectedDate != null ? text : sub),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_scheduleType == 'specific') ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: _kGreen, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _selectedTime != null ? _selectedTime!.format(context) : 'Selecionar horário',
                            style: TextStyle(color: _selectedTime != null ? text : sub),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_scheduleType == 'window') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _timeDropdown('De', _timeWindowStart, (v) => setState(() => _timeWindowStart = v!))),
                      const SizedBox(width: 12),
                      Expanded(child: _timeDropdown('Até', _timeWindowEnd, (v) => setState(() => _timeWindowEnd = v!))),
                    ],
                  ),
                ],
              ]),
              const SizedBox(height: 20),

              // Observações
              _sectionTitle('Observações (opcional)', text),
              const SizedBox(height: 8),
              _buildCard(isDark, card, [
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    hintText: 'Descreva o que você quer verificar no veículo...',
                    hintStyle: TextStyle(color: sub),
                    border: InputBorder.none,
                  ),
                ),
              ]),
              const SizedBox(height: 32),

              // Botão de envio
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Agendar Pré-Compra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    });
  }

  Widget _sectionTitle(String title, Color textColor) {
    return Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor));
  }

  Widget _howItWorksStep(String num, String text, bool isDark) {
    final bool isLast = num == '4';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
              child: Center(
                child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 24, color: _kGreen.withOpacity(0.25)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white.withOpacity(0.82) : Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, Color card, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color textColor, {
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
        counterText: '',
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _kGreen, width: 2)),
      ),
      validator: validator,
    );
  }

  Widget _scheduleTypeChip(String type, String label, bool isDark) {
    final selected = _scheduleType == type;
    return GestureDetector(
      onTap: () => setState(() => _scheduleType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kGreen : (isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _timeDropdown(String label, String value, ValueChanged<String?> onChanged) {
    final times = ['07:00','08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _kGreen, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          ),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    return newVal.copyWith(text: newVal.text.toUpperCase());
  }
}
