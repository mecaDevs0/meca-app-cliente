import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';
// Observação: o token do cartão (ex: "CARD_...") só é retornado após um pagamento aprovado com `store/save=true`.

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({Key? key}) : super(key: key);

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _savedCards = [];
  bool _loading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      final result = await _apiService.getSavedCards();
      
      if (!mounted) return;
      if (result['success']) {
        setState(() {
          _savedCards = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _savedCards = [];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savedCards = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Cartões Salvos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _showAddCardDialog();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _savedCards.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedCards.length,
                  itemBuilder: (context, index) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 350 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildCardItem(_savedCards[index]),
                    );
                  },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 64,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum cartão salvo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione um cartão para facilitar os pagamentos',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddCardDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Cartão'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C977),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 50,
          height: 30,
          decoration: BoxDecoration(
            color: _getCardColor(card['brand']),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              _getCardIcon(card['brand']),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          '${card['brand'] ?? 'Cartão'} •••• ${card['last4'] ?? card['last_digits'] ?? '****'}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          card['expiryMonth'] != null && card['expiryYear'] != null
              ? 'Expira em ${card['expiryMonth']}/${card['expiryYear']}'
              : 'Cartão salvo',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card['isDefault'] == true || card['is_default'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C977),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Padrão',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'set_default':
                    _setAsDefault(card['id'].toString());
                    break;
                  case 'remove':
                    _removeCard(card['id'].toString());
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'set_default',
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 20),
                      SizedBox(width: 8),
                      Text('Definir como padrão'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remover', style: TextStyle(color: Colors.red)),
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

  Color _getCardColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Colors.blue;
      case 'mastercard':
        return Colors.red;
      case 'amex':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getCardIcon(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return 'VISA';
      case 'mastercard':
        return 'MC';
      case 'amex':
        return 'AMEX';
      case 'elo':
        return 'ELO';
      case 'diners':
        return 'DIN';
      case 'hipercard':
        return 'HIPER';
      default:
        return brand.isNotEmpty ? brand.substring(0, (brand.length > 4 ? 4 : brand.length)).toUpperCase() : '?';
    }
  }

  Future<void> _setAsDefault(String cardId) async {
    try {
      final result = await _apiService.setDefaultCard(cardId);
      
      if (result['success']) {
        // Recarregar cartões para atualizar status
        await _loadSavedCards();
        
        AppAlerts.showSuccess(
          context,
          message: 'Cartão definido como padrão.',
        );
        setState(() {
          _hasChanges = true;
        });
      } else {
        AppAlerts.showError(
          context,
          message: result['error'] ?? 'Não foi possível definir o cartão como padrão. Tente novamente.',
        );
      }
    } catch (e) {
      AppAlerts.showError(
        context,
        message: 'Não foi possível definir o cartão como padrão. Tente novamente.',
      );
    }
  }

  void _removeCard(String cardId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remover Cartão'),
          content: const Text('Tem certeza que deseja remover este cartão?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  final result = await _apiService.deleteCard(cardId);
                  
                  if (result['success']) {
                    // Recarregar cartões
                    await _loadSavedCards();
                    
                    AppAlerts.showSuccess(
                      context,
                      message: 'Cartão removido com sucesso.',
                    );
                      setState(() {
                        _hasChanges = true;
                      });
                  } else {
                    AppAlerts.showError(
                      context,
                      message: result['error'] ?? 'Não foi possível remover o cartão. Tente novamente.',
                    );
                  }
                } catch (e) {
                  AppAlerts.showError(
                    context,
                    message: 'Não foi possível remover o cartão. Tente novamente.',
                  );
                }
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCardDialog() async {
    final cardNumberController = TextEditingController();
    final holderNameController = TextEditingController();
    final expiryMonthController = TextEditingController();
    final expiryYearController = TextEditingController();
    final cvvController = TextEditingController();
    final cpfController = TextEditingController();
    final holderEmailController = TextEditingController();
    final holderPhoneController = TextEditingController();
    final holderPostalCodeController = TextEditingController();
    final holderAddressNumberController = TextEditingController();
    bool isSubmitting = false;

    try {
      final profile = await _apiService.getProfile();
      if (profile['success'] == true && profile['data'] != null) {
        final cpf = profile['data']['cpf']?.toString() ?? '';
        if (cpf.isNotEmpty) cpfController.text = cpf;
        final email = profile['data']['email']?.toString() ?? '';
        if (email.isNotEmpty) holderEmailController.text = email;
        final phone = profile['data']['phone']?.toString() ?? '';
        if (phone.isNotEmpty) holderPhoneController.text = phone;
        final zip = profile['data']['zip_code']?.toString() ?? profile['data']['postal_code']?.toString() ?? '';
        if (zip.isNotEmpty) holderPostalCodeController.text = zip;
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Cadastrar Cartão',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Uma micro-cobrança de R\$5,00 será realizada e estornada automaticamente para validar seu cartão.',
                              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.amber[200] : Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cardNumberController,
                      decoration: const InputDecoration(labelText: 'Número do cartão', hintText: '0000 0000 0000 0000'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CardNumberFormatter()],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderNameController,
                      decoration: const InputDecoration(labelText: 'Nome no cartão', hintText: 'NOME COMPLETO'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cpfController,
                      decoration: const InputDecoration(labelText: 'CPF do titular', hintText: '000.000.000-00'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CpfFormatter()],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderEmailController,
                      decoration: const InputDecoration(labelText: 'E-mail do titular', hintText: 'email@exemplo.com'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderPhoneController,
                      decoration: const InputDecoration(labelText: 'Celular do titular', hintText: '(11) 99999-9999'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: holderPostalCodeController,
                            decoration: const InputDecoration(labelText: 'CEP do titular', hintText: '00000-000'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: holderAddressNumberController,
                            decoration: const InputDecoration(labelText: 'Nº', hintText: '123'),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expiryMonthController,
                            decoration: const InputDecoration(labelText: 'Mês', hintText: 'MM'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: expiryYearController,
                            decoration: const InputDecoration(labelText: 'Ano', hintText: 'AAAA'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: cvvController,
                            decoration: const InputDecoration(labelText: 'CVV', hintText: '123'),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final cpfClean = cpfController.text.replaceAll(RegExp(r'[.\-/]'), '').trim();
                          if (cardNumberController.text.trim().length < 13 ||
                              holderNameController.text.trim().isEmpty ||
                              expiryMonthController.text.trim().isEmpty ||
                              expiryYearController.text.trim().isEmpty ||
                              cvvController.text.trim().length < 3) {
                            AppAlerts.showError(context, message: 'Preencha todos os campos corretamente.');
                            return;
                          }
                          if (cpfClean.length < 11) {
                            AppAlerts.showError(context, message: 'Informe o CPF do titular do cartão.');
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final result = await _apiService.tokenizeCard(
                              cardNumber: cardNumberController.text.trim(),
                              holderName: holderNameController.text.trim(),
                              expiryMonth: expiryMonthController.text.trim(),
                              expiryYear: expiryYearController.text.trim(),
                              cvv: cvvController.text.trim(),
                              cpfCnpj: cpfClean,
                              email: holderEmailController.text.trim(),
                              phone: holderPhoneController.text.replaceAll(RegExp(r'\D'), '').trim(),
                              postalCode: holderPostalCodeController.text.replaceAll(RegExp(r'\D'), '').trim(),
                              addressNumber: holderAddressNumberController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (result['success'] == true) {
                              _apiService.invalidateSavedCardsCache();
                              await _loadSavedCards();
                              setState(() => _hasChanges = true);
                              AppAlerts.showSuccess(context, message: 'Cartão salvo com sucesso!');
                            } else {
                              AppAlerts.showError(context, message: result['error']?.toString() ?? 'Não foi possível salvar o cartão.');
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            AppAlerts.showError(context, message: 'Erro ao validar cartão. Tente novamente.');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Salvar Cartão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return oldValue;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return oldValue;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

















