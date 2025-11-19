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
    final tokenController = TextEditingController();
    final lastDigitsController = TextEditingController();
    final brandController = TextEditingController(text: 'Cartão');
    final holderNameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Cartão Tokenizado'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use o token gerado pelo PagBank e informe apenas dados não sensíveis.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Token do cartão',
                        hintText: 'card_tk_12345',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastDigitsController,
                      decoration: const InputDecoration(
                        labelText: 'Últimos dígitos',
                        hintText: '1234',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: brandController,
                            decoration: const InputDecoration(
                        labelText: 'Bandeira',
                        hintText: 'Visa / Mastercard / Elo',
                          ),
                        ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: holderNameController,
                            decoration: const InputDecoration(
                        labelText: 'Nome do titular (opcional)',
                        hintText: 'Como aparece no cartão',
                        ),
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
                          if (tokenController.text.trim().isEmpty || lastDigitsController.text.trim().isEmpty) {
                      AppAlerts.showWarning(
                        dialogContext,
                              message: 'Informe o token e os últimos dígitos do cartão.',
                        title: 'Campos obrigatórios',
                      );
                      return;
                    }

                          setDialogState(() => isLoading = true);

                    try {
                            final saveResult = await _apiService.saveCard(
                              cardToken: tokenController.text.trim(),
                              lastDigits: lastDigitsController.text.trim(),
                              brand: brandController.text.trim().isEmpty ? 'Cartão' : brandController.text.trim(),
                              holderName: holderNameController.text.trim().isEmpty
                                  ? null
                                  : holderNameController.text.trim(),
                        isDefault: false,
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



















