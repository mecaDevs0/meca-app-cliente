import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/cpf_formatter.dart';
import '../utils/cep_formatter.dart';
import '../utils/phone_formatter.dart';
import '../widgets/app_alerts.dart';

class BillingDataSheet extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final VoidCallback onComplete;

  const BillingDataSheet({
    Key? key,
    this.existingData,
    required this.onComplete,
  }) : super(key: key);

  static Future<bool> showIfNeeded(BuildContext context, Map<String, dynamic>? profile) async {
    final cpf = profile?['cpf']?.toString() ?? '';
    final billingPhone = profile?['billing_phone']?.toString() ?? '';
    final billingCep = profile?['billing_cep']?.toString() ?? '';
    final billingNumber = profile?['billing_address_number']?.toString() ?? '';
    final billingEmail = profile?['billing_email']?.toString() ?? profile?['email']?.toString() ?? '';

    final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
    final phoneDigits = billingPhone.replaceAll(RegExp(r'\D'), '');
    final cepDigits = billingCep.replaceAll(RegExp(r'\D'), '');

    if (cpfDigits.length == 11 && phoneDigits.length >= 10 && cepDigits.length == 8 && billingNumber.isNotEmpty && billingEmail.contains('@')) {
      return true;
    }

    bool completed = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillingDataSheet(
        existingData: profile,
        onComplete: () {
          completed = true;
          Navigator.pop(ctx);
        },
      ),
    );
    return completed;
  }

  @override
  State<BillingDataSheet> createState() => _BillingDataSheetState();
}

class _BillingDataSheetState extends State<BillingDataSheet> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _numberController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    if (data != null) {
      _cpfController.text = data['cpf']?.toString() ?? '';
      _phoneController.text = data['billing_phone']?.toString() ?? '';
      _cepController.text = data['billing_cep']?.toString() ?? '';
      _numberController.text = data['billing_address_number']?.toString() ?? '';
      _emailController.text = data['billing_email']?.toString() ?? data['email']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _phoneController.dispose();
    _cepController.dispose();
    _numberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _validateCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
    int sum = 0;
    for (int i = 0; i < 9; i++) sum += int.parse(digits[i]) * (10 - i);
    int first = (sum * 10) % 11;
    if (first == 10) first = 0;
    if (first != int.parse(digits[9])) return false;
    sum = 0;
    for (int i = 0; i < 10; i++) sum += int.parse(digits[i]) * (11 - i);
    int second = (sum * 10) % 11;
    if (second == 10) second = 0;
    return second == int.parse(digits[10]);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final cpfDigits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final cepDigits = _cepController.text.replaceAll(RegExp(r'\D'), '');

    final result = await _apiService.updateBillingData({
      'cpf': cpfDigits,
      'billing_phone': phoneDigits,
      'billing_cep': cepDigits,
      'billing_address_number': _numberController.text.trim(),
      'billing_email': _emailController.text.trim(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      widget.onComplete();
    } else {
      AppAlerts.showError(context, message: result['error']?.toString() ?? 'Erro ao salvar dados fiscais.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C977).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long, color: Color(0xFF00C977), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dados para Nota Fiscal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Preencha para continuar com o pagamento', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CpfFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    hintText: '000.000.000-00',
                    prefixIcon: Icon(Icons.badge, color: Color(0xFF00C977)),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'CPF é obrigatório';
                    if (!_validateCpf(v)) return 'CPF inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    hintText: '(00) 00000-0000',
                    prefixIcon: Icon(Icons.phone, color: Color(0xFF00C977)),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return 'Celular inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cepController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CepFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'CEP',
                          hintText: '00000-000',
                          prefixIcon: Icon(Icons.location_on, color: Color(0xFF00C977)),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 8) return 'CEP inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Número',
                          hintText: 'Nº',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obrigatório';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'email@exemplo.com',
                    prefixIcon: Icon(Icons.email, color: Color(0xFF00C977)),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || !v.contains('@') || !v.contains('.')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C977),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar e continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
