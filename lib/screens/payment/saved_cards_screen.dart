import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';

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
    setState(() => _loading = true);
    
    try {
      final result = await _apiService.getSavedCards();
      
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
      setState(() {
        _savedCards = [];
        _loading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_hasChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
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
                    return _buildCardItem(_savedCards[index]);
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
            if (card['isDefault'])
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
                    _setAsDefault(card['id']);
                    break;
                  case 'remove':
                    _removeCard(card['id']);
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
        return 'V';
      case 'mastercard':
        return 'M';
      case 'amex':
        return 'A';
      default:
        return '?';
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

  void _showAddCardDialog() {
    final cardNumberController = TextEditingController();
    final holderNameController = TextEditingController();
    final expiryMonthController = TextEditingController();
    final expiryYearController = TextEditingController();
    final cvvController = TextEditingController();
    bool isLoading = false;
    String? selectedCardType;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Cartão'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informe os dados do seu cartão de crédito. Os dados são criptografados e seguros.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Número do cartão',
                        hintText: '1234 5678 9012 3456',
                        prefixIcon: const Icon(Icons.credit_card),
                        suffixIcon: selectedCardType != null
                            ? Icon(
                                selectedCardType == 'VISA' ? Icons.credit_card : Icons.credit_card,
                                color: selectedCardType == 'VISA' ? Colors.blue : Colors.orange,
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(19),
                      ],
                      onChanged: (value) {
                        // Detectar bandeira
                        final digits = value.replaceAll(' ', '');
                        if (digits.isNotEmpty) {
                          if (digits.startsWith('4')) {
                            setDialogState(() => selectedCardType = 'VISA');
                          } else if (digits.startsWith('5') || digits.startsWith('2')) {
                            setDialogState(() => selectedCardType = 'MASTERCARD');
                          } else if (digits.startsWith('3')) {
                            setDialogState(() => selectedCardType = 'AMEX');
                          } else {
                            setDialogState(() => selectedCardType = null);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: holderNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome impresso no cartão',
                        hintText: 'NOME COMPLETO',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: expiryMonthController,
                            decoration: const InputDecoration(
                              labelText: 'Mês',
                              hintText: 'MM',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: expiryYearController,
                            decoration: const InputDecoration(
                              labelText: 'Ano',
                              hintText: 'AAAA',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: cvvController,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final cardNumber = cardNumberController.text.replaceAll(' ', '');
                          final holderName = holderNameController.text.trim();
                          final expiryMonth = expiryMonthController.text.trim();
                          final expiryYear = expiryYearController.text.trim();
                          final cvv = cvvController.text.trim();

                          if (cardNumber.isEmpty || cardNumber.length < 13) {
                            AppAlerts.showWarning(
                              dialogContext,
                              message: 'Informe um número de cartão válido.',
                              title: 'Campo obrigatório',
                            );
                            return;
                          }

                          if (holderName.isEmpty) {
                            AppAlerts.showWarning(
                              dialogContext,
                              message: 'Informe o nome impresso no cartão.',
                              title: 'Campo obrigatório',
                            );
                            return;
                          }

                          if (expiryMonth.isEmpty || expiryYear.isEmpty) {
                            AppAlerts.showWarning(
                              dialogContext,
                              message: 'Informe o mês e ano de validade.',
                              title: 'Campo obrigatório',
                            );
                            return;
                          }

                          if (cvv.isEmpty || cvv.length < 3) {
                            AppAlerts.showWarning(
                              dialogContext,
                              message: 'Informe o CVV do cartão.',
                              title: 'Campo obrigatório',
                            );
                            return;
                          }

                          setDialogState(() => isLoading = true);

                          try {
                            // Obter customerId do token (será pego automaticamente pelo backend)
                            final saveResult = await _apiService.saveCardDirect(
                              customerId: '', // Backend pega do token JWT
                              cardNumber: cardNumber,
                              expiryMonth: expiryMonth,
                              expiryYear: expiryYear,
                              cvv: cvv,
                              holderName: holderName,
                            );

                            if (saveResult['success']) {
                              Navigator.of(dialogContext).pop();
                              await _loadSavedCards();
                              if (mounted) {
                                setState(() {
                                  _hasChanges = true;
                                });
                              }
                        AppAlerts.showSuccess(
                          context,
                                message: 'Cartão tokenizado salvo com sucesso!',
                        );
                      } else {
                        AppAlerts.showError(
                          dialogContext,
                          message: saveResult['error'] ?? 'Não foi possível salvar o cartão.',
                        );
                      }
                    } catch (e) {
                      AppAlerts.showError(
                        dialogContext,
                        message: 'Não foi possível salvar o cartão. Tente novamente.',
                      );
                    } finally {
                            setDialogState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}



















