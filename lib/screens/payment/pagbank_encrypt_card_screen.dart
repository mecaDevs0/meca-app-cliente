import 'package:flutter/material.dart';

import '../../services/pagbank_tokenization_service.dart';

/// Tela utilitária para preparar payload de cartão no fluxo Asaas.
/// O nome e o arquivo são mantidos para compatibilidade com imports existentes.
class PagBankEncryptCardScreen extends StatefulWidget {
  final String publicKey;
  final String holderName;
  final String number;
  final String expMonth;
  final String expYear;
  final String securityCode;

  const PagBankEncryptCardScreen({
    super.key,
    required this.publicKey,
    required this.holderName,
    required this.number,
    required this.expMonth,
    required this.expYear,
    required this.securityCode,
  });

  @override
  State<PagBankEncryptCardScreen> createState() => _PagBankEncryptCardScreenState();
}

class _PagBankEncryptCardScreenState extends State<PagBankEncryptCardScreen> {
  bool _done = false;
  String? _error;
  final PagBankTokenizationService _tokenizationService =
      PagBankTokenizationService();

  @override
  void initState() {
    super.initState();
    _tokenizeCard();
  }

  Future<void> _tokenizeCard() async {
    final result = await _tokenizationService.tokenizeCard(
      cardNumber: widget.number,
      expiryMonth: widget.expMonth,
      expiryYear: widget.expYear,
      cvv: widget.securityCode,
      holderName: widget.holderName,
    );

    if (_done || !mounted) return;
    _done = true;

    if (result['success'] == true) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _error = (result['error'] ?? 'Não foi possível processar os dados do cartão.').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validando cartão'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Não foi possível processar o cartão',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Fechar'),
                      ),
                    ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }
}

