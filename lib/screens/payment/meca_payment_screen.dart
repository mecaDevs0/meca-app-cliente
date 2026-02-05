import 'dart:async';
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';
import '../review/review_screen.dart';
import 'pagbank_encrypt_card_screen.dart';
import 'saved_cards_screen.dart';

class MecaPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final double totalAmount;
  final double mecaFee;
  final double serviceAmount;
  final int installments;
  final bool workshopAcceptsInstallment;

  const MecaPaymentScreen({
    Key? key,
    required this.bookingData,
    required this.totalAmount,
    required this.mecaFee,
    required this.serviceAmount,
    required this.installments,
    this.workshopAcceptsInstallment = true,
  }) : super(key: key);

  @override
  State<MecaPaymentScreen> createState() => _MecaPaymentScreenState();
}

class _MecaPaymentScreenState extends State<MecaPaymentScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static const String _newCardSentinel = '__new_card__';

  bool _loadingCards = true;
  bool _isSubmitting = false;
  bool _isCheckingStatus = false;
  bool _showResult = false;

  Future<void> _navigateToReviewScreen() async {
    final bookingId = widget.bookingData['id']?.toString() ?? widget.bookingData['booking_id']?.toString();
    final workshopId = widget.bookingData['workshop_id']?.toString() ?? widget.bookingData['oficina_id']?.toString();
    
    if (bookingId != null && workshopId != null && mounted) {
      // Invalidar cache ANTES de fechar a tela para garantir que os dados sejam recarregados
      _apiService.invalidateBookingCache(bookingId);
          _apiService.invalidateBookingsCache();
      _apiService.invalidateBookingsCache();
      
      // Retornar true para indicar que pagamento foi feito
      Navigator.pop(context, true);
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              bookingId: bookingId,
              workshopId: workshopId,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        // Mesmo sem workshopId, retornar true para indicar pagamento
        Navigator.pop(context, true);
      }
    }
  }

  String _selectedMethod = 'pix';
  String? _selectedCardId;
  int _selectedInstallments = 1;
  final TextEditingController _cvvController = TextEditingController();

  List<Map<String, dynamic>> _savedCards = [];

  Map<String, dynamic>? _paymentRecord;
  String? _pixCode;
  String? _paymentLink;
  String? _paymentId;

  Timer? _statusTimer;

  String _statusLabel(String raw) {
    final s = raw.toLowerCase().trim();
    switch (s) {
      case 'approved':
      case 'paid':
        return 'Aprovado';
      case 'pending':
      case 'in_analysis':
      case 'waiting':
      case 'authorized':
        return 'Em análise';
      case 'declined':
      case 'denied':
        return 'Negado';
      case 'cancelled':
      case 'canceled':
        return 'Cancelado';
      case 'refunded':
        return 'Estornado';
      default:
        return s.isEmpty ? 'Indisponível' : s.toUpperCase();
    }
  }

  String _declineHelpText(String? gatewayMessage) {
    final msg = (gatewayMessage ?? '').trim();
    if (msg.isNotEmpty) {
      return '$msg\n\nO que fazer: tente outro cartão, verifique limite/dados do cartão, ou use PIX.';
    }
    return 'O PagBank/PagSeguro não autorizou a transação.\n\nO que fazer: tente outro cartão, verifique limite/dados do cartão, ou use PIX.';
  }

  @override
  void initState() {
    super.initState();
    _selectedInstallments = widget.installments > 0 ? widget.installments : 1;
    _loadSavedCards();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _loadingCards = true;
    });

    try {
      // Sempre forçar refresh aqui: lista de cartões pode mudar após pagamentos com "Salvar cartão"
      final result = await _apiService.getSavedCards(forceRefresh: true);
      if (!mounted) return;

      if (result['success']) {
        final cards = List<Map<String, dynamic>>.from(result['data'] ?? []);
        // Filtrar cartões válidos para pagamento:
        // - Tokens PagBank normalmente começam com "CARD_"
        // - (Tokens "CHAR_" são IDs de charge e dão INVALID_CARD_ID)
        _savedCards = cards.where((card) {
          final token = (card['card_token'] ?? card['cardToken'] ?? '').toString();
          if (token.isEmpty) return false;
          // Só aceitar tokens de cartão (CARD_). Qualquer outro formato deve ser ignorado.
          if (!token.startsWith('CARD_')) return false;
          return true;
        }).toList();

        if (_savedCards.isNotEmpty) {
          _selectedCardId = _savedCards.first['id']?.toString();
        } else {
          _selectedCardId = null;
        }
      } else {
        _savedCards = [];
        _selectedCardId = null;
        if (mounted) {
          AppAlerts.showWarning(
            context,
            title: 'Cartões indisponíveis',
            message: result['error'] ?? 'Não foi possível carregar seus cartões salvos agora.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _savedCards = [];
      _selectedCardId = null;
      AppAlerts.showError(
        context,
        message: 'Não foi possível carregar seus cartões salvos. Tente novamente em instantes.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCards = false;
        });
      }
    }
  }

  Future<void> _handlePay() async {
    if (_isSubmitting) return;

    // Evitar pagamento duplicado: se já existe um pagamento em análise nesta tela, não criar outro
    if (_paymentId != null && _showResult) {
      AppAlerts.showInfo(
        context,
        title: 'Pagamento já iniciado',
        message: 'Seu pagamento já foi iniciado e está em análise. Aguarde a confirmação ou toque em "Atualizar status".',
      );
      return;
    }

    if (_selectedMethod == 'credit_card') {
      if (_savedCards.isNotEmpty && _selectedCardId == null) {
        AppAlerts.showWarning(
          context,
          title: 'Selecione um cartão',
          message: 'Escolha um cartão salvo para continuar.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _showResult = false;
    });

    try {
      final bookingId = widget.bookingData['id']?.toString() ?? '';
      if (bookingId.isEmpty) {
        throw Exception('Identificador do agendamento não encontrado.');
      }

      // Permitir pagar com um novo cartão mesmo se houver cartões salvos
      if (_selectedMethod == 'credit_card' && _selectedCardId == _newCardSentinel) {
        await _payWithNewCard(bookingId);
        return;
      }

      // Se não há cartões salvos, permitir pagar com um novo cartão (criptografia no cliente)
      if (_selectedMethod == 'credit_card' && _savedCards.isEmpty) {
        await _payWithNewCard(bookingId);
        return;
      }

      String? cardToken;
      String? cvv;
      
      if (_selectedMethod == 'credit_card') {
        cardToken = _extractCardToken(_selectedCardId);
        if (cardToken == null || cardToken.isEmpty) {
          throw Exception('Cartão selecionado não possui token válido.');
        }
        
        // PASSO 11: Solicitar CVV na hora do pagamento
        if (_cvvController.text.trim().isEmpty) {
          AppAlerts.showWarning(
            context,
            title: 'CVV obrigatório',
            message: 'Digite o CVV do cartão para continuar o pagamento.',
          );
          setState(() => _isSubmitting = false);
          return;
        }
        cvv = _cvvController.text.trim();
      }

      final workshopAccountId = (widget.bookingData['workshop_pagbank_account_id'] ?? widget.bookingData['workshopPagbankAccountId'])?.toString().trim();
      // Usar createBookingPayment que valida o status do booking antes de criar pagamento
      final paymentResult = await _apiService.createBookingPayment(
        bookingId,
        paymentMethod: _selectedMethod == 'credit_card' ? 'CREDIT_CARD' : 'PIX',
        cardToken: cardToken,
        cvv: cvv,
        holderName: _selectedMethod == 'credit_card' ? _extractCardHolderName(_selectedCardId) : null,
        installments: _selectedMethod == 'credit_card' ? _selectedInstallments : null,
        pixExpirationInSeconds: _selectedMethod == 'pix' ? 3600 : null,
        workshopPagbankAccountId: workshopAccountId?.isNotEmpty == true ? workshopAccountId : null,
      );

      if (!mounted) return;

      if (!paymentResult['success']) {
        final errMsg = (paymentResult['error'] ?? '').toString();
        final normalized = errMsg.toUpperCase();

        // Caso comum em produção: token de cartão salvo antigo/inválido para o PagBank (INVALID_CARD_ID)
        // Nesse cenário, removemos o cartão inválido automaticamente e direcionamos para "outro cartão".
        if (_selectedMethod == 'credit_card' && normalized.contains('INVALID_CARD_ID')) {
          if (!mounted) return;

          final badCardId = _selectedCardId;
          if (badCardId != null && badCardId.isNotEmpty && badCardId != _newCardSentinel) {
            try {
              await _apiService.deleteCard(badCardId);
            } catch (_) {}
          }

          if (badCardId != null) {
            _savedCards.removeWhere((c) => c['id']?.toString() == badCardId);
            _selectedCardId = _savedCards.isNotEmpty ? _savedCards.first['id']?.toString() : null;
          }

          try {
            await _loadSavedCards();
          } catch (_) {}

          final proceed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cartão inválido removido'),
                  content: const Text(
                    'Removemos este cartão da sua lista porque ele não pôde ser validado pelo PagBank.\n\n'
                    'Para continuar, use outro cartão agora. Se quiser, marque "Salvar cartão" no pagamento para salvar novamente.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Usar outro cartão'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (proceed == true) {
            await _payWithNewCard(bookingId);
          } else {
            setState(() => _isSubmitting = false);
          }
          return;
        }

        AppAlerts.showError(
          context,
          message: errMsg.isNotEmpty ? errMsg : 'Não foi possível iniciar o pagamento agora.',
        );
        return;
      }

      final data = paymentResult['data'] as Map<String, dynamic>? ?? {};
      
      // A API retorna status diretamente em data, não em payment
      final status = (data['status'] ?? '').toString().toLowerCase();
      final paymentId = data['payment_id']?.toString();
      final orderId = data['order_id']?.toString();
      final chargeId = data['charge_id']?.toString();
      
      print('💳 [Payment] ========== RESPOSTA DA API ==========');
      print('💳 [Payment] Status recebido: $status');
      print('💳 [Payment] Payment ID: $paymentId');
      print('💳 [Payment] Order ID: $orderId');
      print('💳 [Payment] Charge ID: $chargeId');
      print('💳 [Payment] Data completo: $data');
      print('💳 [Payment] ======================================');
      
      // Se pagamento foi aprovado IMEDIATAMENTE, não mostrar tela de análise
      if (_selectedMethod == 'credit_card' && (status == 'approved' || status == 'paid')) {
        print('✅ [Payment] Pagamento APROVADO IMEDIATAMENTE - navegando para review');
        AppAlerts.showSuccess(
          context,
          message: 'Pagamento aprovado com sucesso! Obrigado por usar o MECA.',
        );
        // Invalidar cache do booking para forçar reload
        final bookingId = widget.bookingData['id']?.toString();
        if (bookingId != null) {
          _apiService.invalidateBookingCache(bookingId);
          _apiService.invalidateBookingsCache();
        }
        // Aguardar um pouco para garantir que o cache foi invalidado
        await Future.delayed(const Duration(milliseconds: 500));
        // Redirecionar imediatamente
        await _navigateToReviewScreen();
        return;
      }
      
      // Para PIX ou pagamentos pendentes, continuar com o fluxo normal
      final payment = Map<String, dynamic>.from(data['payment'] ?? data);
      _paymentRecord = payment;
      _pixCode = payment['pix_qr_code'] ?? payment['pixCode'] ?? payment['pix_code'] ?? data['qr_code'];
      _paymentLink = payment['payment_link'] ?? payment['paymentLink'] ?? data['payment_link'];
      _paymentId = paymentId ?? payment['id']?.toString();
      _showResult = true;

      final gatewayMessage = (data['gateway_message'] ?? payment['gateway_message'] ?? '').toString().trim();
      final isDeclined = status == 'declined' || status == 'denied';
      final isCancelled = status == 'cancelled' || status == 'canceled';

      if (_selectedMethod == 'credit_card' && (isDeclined || isCancelled)) {
        // Não iniciar polling infinito: status final (recusado/cancelado)
        _statusTimer?.cancel();
        AppAlerts.showWarning(
          context,
          title: isDeclined ? 'Pagamento recusado' : 'Pagamento cancelado',
          message: gatewayMessage.isNotEmpty
              ? gatewayMessage
              : (isDeclined ? 'O PagBank/PagSeguro não autorizou o pagamento. Tente outro cartão.' : 'O pagamento foi cancelado.'),
        );
        setState(() {});
        return;
      }

      if (_selectedMethod == 'pix') {
        AppAlerts.showInfo(
          context,
          title: 'PIX gerado',
          message: 'Copie o código abaixo para concluir o pagamento no seu banco.',
        );
      } else {
        AppAlerts.showInfo(
          context,
          title: 'Pagamento em análise',
          message: 'O PagBank está processando seu pagamento. Avisaremos assim que for confirmado.',
        );
      }

      _startStatusPolling();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível processar o pagamento. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _payWithNewCard(String bookingId) async {
    final cardNumberController = TextEditingController();
    final holderNameController = TextEditingController();
    final expiryMonthController = TextEditingController();
    final expiryYearController = TextEditingController();
    final cvvController = TextEditingController();
    bool saveCard = true;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Pagamento com novo cartão'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: cardNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Número do cartão',
                          hintText: '1234 5678 9012 3456',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(19),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: holderNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome no cartão',
                          hintText: 'NOME COMPLETO',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          hintText: '3 ou 4 dígitos',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: saveCard,
                        onChanged: (v) => setDialogState(() => saveCard = v),
                        title: const Text('Salvar cartão para próximas compras'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Continuar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true) return;

      final rawNumber = cardNumberController.text.replaceAll(' ', '');
      final holderName = holderNameController.text.trim();
      final expMonth = expiryMonthController.text.trim().padLeft(2, '0');
      var expYear = expiryYearController.text.trim();
      final cvv = cvvController.text.trim();

      if (rawNumber.length < 13) {
        AppAlerts.showWarning(context, title: 'Dados inválidos', message: 'Informe um número de cartão válido.');
        return;
      }
      if (holderName.isEmpty) {
        AppAlerts.showWarning(context, title: 'Dados inválidos', message: 'Informe o nome impresso no cartão.');
        return;
      }
      if (expMonth.length != 2 || expYear.isEmpty) {
        AppAlerts.showWarning(context, title: 'Dados inválidos', message: 'Informe o mês e o ano de validade.');
        return;
      }
      if (cvv.length < 3) {
        AppAlerts.showWarning(context, title: 'Dados inválidos', message: 'Informe um CVV válido.');
        return;
      }

      if (expYear.length == 2) {
        expYear = '20$expYear';
      }

      final publicKeyResult = await _apiService.getPagBankPublicKey();
      if (!(publicKeyResult['success'] == true)) {
        AppAlerts.showError(context, message: publicKeyResult['error'] ?? 'Erro ao obter chave pública do PagBank.');
        return;
      }
      final publicKey = (publicKeyResult['data']?['public_key'] ?? '').toString();
      if (publicKey.isEmpty) {
        AppAlerts.showError(context, message: 'Chave pública do PagBank não disponível.');
        return;
      }

      final encryptedCard = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (_) => PagBankEncryptCardScreen(
            publicKey: publicKey,
            holderName: holderName,
            number: rawNumber,
            expMonth: expMonth,
            expYear: expYear,
            securityCode: cvv,
          ),
          fullscreenDialog: true,
        ),
      );
      if (encryptedCard == null || encryptedCard.isEmpty) {
        AppAlerts.showError(context, message: 'Não foi possível criptografar o cartão. Tente novamente.');
        return;
      }

      final lastDigits = rawNumber.substring(rawNumber.length - 4);
      String brand = 'Cartão';
      if (rawNumber.startsWith('4')) {
        brand = 'VISA';
      } else if (rawNumber.startsWith('5') || rawNumber.startsWith('2')) {
        brand = 'MASTERCARD';
      } else if (rawNumber.startsWith('3')) {
        brand = 'AMEX';
      } else if (rawNumber.startsWith('6')) {
        brand = 'ELO';
      }

      final workshopAccountId = (widget.bookingData['workshop_pagbank_account_id'] ?? widget.bookingData['workshopPagbankAccountId'])?.toString().trim();
      final paymentResult = await _apiService.createBookingPayment(
        bookingId,
        paymentMethod: 'CREDIT_CARD',
        cardToken: encryptedCard,
        cvv: cvv,
        holderName: holderName,
        installments: _selectedInstallments,
        saveCard: saveCard,
        lastDigits: lastDigits,
        brand: brand,
        expiryMonth: expMonth,
        expiryYear: expYear,
        workshopPagbankAccountId: workshopAccountId?.isNotEmpty == true ? workshopAccountId : null,
      );

      if (!mounted) return;
      if (paymentResult['success'] != true) {
        AppAlerts.showError(context, message: paymentResult['error'] ?? 'Não foi possível iniciar o pagamento agora.');
        return;
      }

      // Atualizar cartões (se o backend salvou token após pagamento aprovado)
      try {
        await _loadSavedCards();
      } catch (_) {}

      final data = paymentResult['data'] as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (status == 'approved' || status == 'paid') {
        AppAlerts.showSuccess(context, message: 'Pagamento aprovado com sucesso! Obrigado por usar o MECA.');
        final id = widget.bookingData['id']?.toString();
        if (id != null) {
          _apiService.invalidateBookingCache(id);
          _apiService.invalidateBookingsCache();
        }
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToReviewScreen();
        return;
      }

      final payment = Map<String, dynamic>.from(data['payment'] ?? data);
      _paymentRecord = payment;
      _pixCode = payment['pix_qr_code'] ?? payment['pixCode'] ?? payment['pix_code'] ?? data['qr_code'];
      _paymentLink = payment['payment_link'] ?? payment['paymentLink'] ?? data['payment_link'];
      _paymentId = data['payment_id']?.toString() ?? payment['id']?.toString();
      _showResult = true;

      final normalized = status.toLowerCase();
      final gatewayMessage = (data['gateway_message'] ?? payment['gateway_message'] ?? '').toString().trim();
      final isDeclined = normalized == 'declined' || normalized == 'denied';
      final isCancelled = normalized == 'cancelled' || normalized == 'canceled';

      if (isDeclined || isCancelled) {
        _statusTimer?.cancel();
        AppAlerts.showWarning(
          context,
          title: isDeclined ? 'Pagamento negado' : 'Pagamento cancelado',
          message: isDeclined ? _declineHelpText(gatewayMessage) : 'O pagamento foi cancelado. Você pode tentar novamente.',
        );
        setState(() {});
        return;
      }

      AppAlerts.showInfo(
        context,
        title: 'Pagamento em análise',
        message: 'O PagBank está processando seu pagamento. Você pode acompanhar o status aqui.',
      );
      _startStatusPolling();
      setState(() {});
    } catch (e) {
      if (mounted) {
        AppAlerts.showError(context, message: 'Não foi possível processar o pagamento com cartão agora.');
      }
    } finally {
      cardNumberController.dispose();
      holderNameController.dispose();
      expiryMonthController.dispose();
      expiryYearController.dispose();
      cvvController.dispose();
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    if (_paymentId == null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkPaymentStatus(silent: true);
    });
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_paymentId == null) return;
    if (_isCheckingStatus) return;

    setState(() => _isCheckingStatus = true);

    final result = await _apiService.getPaymentStatus(_paymentId!);
    if (!mounted) return;

    if (result['success']) {
      final data = Map<String, dynamic>.from(result['data'] ?? {});
      final status = (data['status'] ?? '').toString().toLowerCase();
      setState(() {
        _paymentRecord = {
          ...?_paymentRecord,
          'status': status,
          'approved_at': data['approved_at'],
          'gateway_status': data['gateway_status'],
          'gateway_code': data['gateway_code'],
          'gateway_message': data['gateway_message'],
        };
      });

      if (status == 'approved' || status == 'paid') {
        _statusTimer?.cancel();
        if (!silent) {
          AppAlerts.showSuccess(
            context,
            message: 'Pagamento confirmado! Obrigado por usar o MECA.',
          );
        }
        if (mounted) {
          // Redirecionar para tela de avaliação após pagamento confirmado
          await _navigateToReviewScreen();
        }
      } else if (status == 'declined' || status == 'denied') {
        _statusTimer?.cancel();
        if (!silent) {
          AppAlerts.showWarning(
            context,
            title: 'Pagamento negado',
            message: _declineHelpText(_paymentRecord?['gateway_message']?.toString()),
          );
        }
      } else if (!silent) {
        AppAlerts.showInfo(
          context,
          title: 'Status atualizado',
          message: status == 'pending' ? 'Ainda em análise pelo PagBank.' : 'Status atual: ${_statusLabel(status)}',
        );
      } else if (!silent && status == 'cancelled') {
        AppAlerts.showWarning(
          context,
          title: 'Pagamento cancelado',
          message: 'Não recebemos a confirmação do PagBank. Verifique se o pagamento foi concluído.',
        );
      }
    } else if (!silent) {
      AppAlerts.showError(
        context,
        message: result['error'] ?? 'Não foi possível atualizar o status do pagamento.',
      );
    }

    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  String? _extractCardToken(String? cardId) {
    if (cardId == null) {
      print('⚠️ [Payment] cardId é null');
      return null;
    }
    
    print('🔍 [Payment] Buscando token para cardId: $cardId');
    print('🔍 [Payment] Total de cartões salvos: ${_savedCards.length}');
    
    // Tentar encontrar o cartão por diferentes campos de ID
    Map<String, dynamic>? card;
    try {
      card = _savedCards.firstWhere(
        (element) {
          final elementId = element['id']?.toString();
          final elementCardId = element['card_id']?.toString();
          return elementId == cardId || elementCardId == cardId;
        },
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      print('❌ [Payment] Erro ao buscar cartão: $e');
      return null;
    }
    
    if (card == null || card.isEmpty) {
      print('❌ [Payment] Cartão não encontrado na lista para cardId: $cardId');
      print('🔍 [Payment] IDs disponíveis: ${_savedCards.map((c) => c['id']?.toString()).join(", ")}');
      return null;
    }
    
    // Tentar diferentes campos de token
    final token = card['card_token'] ?? card['cardToken'] ?? card['token'] ?? '';
    final tokenString = token.toString();
    
    print('✅ [Payment] Token encontrado: ${tokenString.isNotEmpty ? tokenString.substring(0, Math.min(20, tokenString.length)) + "..." : "VAZIO"}');
    
    if (tokenString.isEmpty) {
      print('❌ [Payment] Cartão encontrado mas token está vazio. Campos disponíveis: ${card.keys.join(", ")}');
      return null;
    }
    
    return tokenString;
  }

  String? _extractCardHolderName(String? cardId) {
    if (cardId == null) return null;

    Map<String, dynamic> card;
    try {
      card = _savedCards.firstWhere(
        (element) {
          final elementId = element['id']?.toString();
          final elementCardId = element['card_id']?.toString();
          return elementId == cardId || elementCardId == cardId;
        },
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }

    if (card.isEmpty) return null;

    final holder = (card['holder_name'] ?? card['cardholder_name'] ?? card['holderName'] ?? '').toString().trim();
    return holder.isEmpty ? null : holder;
  }

  Future<void> _openSavedCards() async {
    final reloaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SavedCardsScreen()),
    );
    if (reloaded == true && mounted) {
      _loadSavedCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Pagamento'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPaymentSummaryCard(theme),
              const SizedBox(height: 20),
              _buildPaymentMethodSelector(theme),
              const SizedBox(height: 20),
              if (_selectedMethod == 'credit_card')
                _loadingCards ? const Center(child: CircularProgressIndicator()) : _buildSavedCardsSection(theme),
              if (_selectedMethod == 'credit_card' && _selectedCardId != null && _selectedCardId != _newCardSentinel) ...[
                const SizedBox(height: 20),
                _buildCvvSection(theme),
              ],
              if (_selectedMethod == 'credit_card' && widget.workshopAcceptsInstallment) ...[
                const SizedBox(height: 20),
                _buildInstallmentsSection(theme),
              ],
              if (_showResult) ...[
                const SizedBox(height: 24),
                _buildResultSection(theme),
              ],
            ],
          ),
        ),
      ),
      // Quando o pagamento já foi iniciado, escondemos o botão principal para evitar confusão/duplicação.
      bottomNavigationBar: _showResult
          ? null
          : Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handlePay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selectedMethod == 'credit_card'
                              ? 'Pagar ${_currencyFormatter.format(widget.totalAmount)}'
                              : 'Gerar PIX de ${_currencyFormatter.format(widget.totalAmount)}',
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentSummaryCard(ThemeData theme) {
    // Evitar divergência de arredondamento na UI do split:
    // Ex.: 1,50 * 7% = 0,105 -> 0,11 e 1,39 (centavos: 150 -> 11 + 139)
    // Se fizer conta em double e arredondar no fim, pode aparecer 0,11 e 1,40 (soma 1,51).
    final totalCents = (widget.totalAmount * 100).round();
    final mecaFeeCents = (totalCents * 0.07).round();
    final workshopCents = totalCents - mecaFeeCents;
    final mecaFeeDisplay = mecaFeeCents / 100.0;
    final workshopDisplay = workshopCents / 100.0;

    final surfaceColor = theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.9);
    final borderColor = theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bookingData['service_name'] ?? widget.bookingData['service']?['name'] ?? 'Serviço',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            theme,
            'Valor do orçamento final',
            _currencyFormatter.format(widget.serviceAmount),
          ),
          // Cliente não deve ver detalhes do split (taxa MECA/oficina)
          const Divider(height: 24),
          _buildSummaryRow(
            theme,
            '= Total a pagar',
            _currencyFormatter.format(widget.totalAmount),
            isTotal: true,
          ),
          if (_selectedMethod == 'credit_card' && widget.workshopAcceptsInstallment && _selectedInstallments > 1) ...[
            const SizedBox(height: 12),
            Text(
              '${_selectedInstallments}x de ${_currencyFormatter.format(widget.totalAmount / _selectedInstallments)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value, {bool isTotal = false, bool secondary = false}) {
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: secondary ? FontWeight.w500 : FontWeight.w600,
      color: secondary
          ? theme.textTheme.bodyMedium?.color?.withOpacity(0.7)
          : theme.textTheme.bodyLarge?.color,
    );
    final valueStyle = isTotal
        ? theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          )
        : theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector(ThemeData theme) {
    final options = [
      {
        'value': 'pix',
        'title': 'PIX',
        'subtitle': 'Pagamento instantâneo',
        'icon': Icons.qr_code,
      },
      {
        'value': 'credit_card',
        'title': 'Cartão de Crédito',
        'subtitle': widget.workshopAcceptsInstallment
            ? 'Parcelamento disponível (até 12x)'
            : 'Pagamento à vista',
        'icon': Icons.credit_card,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como você quer pagar?',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final option in options) ...[
            _PaymentMethodTile(
              title: option['title'] as String,
              subtitle: option['subtitle'] as String,
              icon: option['icon'] as IconData,
              selected: _selectedMethod == option['value'],
              onTap: () {
                setState(() {
                  _selectedMethod = option['value'] as String;
                });
              },
            ),
            if (option != options.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedCardsSection(ThemeData theme) {
    if (_savedCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nenhum cartão salvo',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione um cartão para pagar com crédito.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final bookingId = widget.bookingData['id']?.toString() ?? '';
                if (bookingId.isNotEmpty) {
                  await _payWithNewCard(bookingId);
                } else {
                  _openSavedCards();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Usar outro cartão agora'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                'Escolha um cartão salvo',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
              TextButton(
                onPressed: _openSavedCards,
                child: const Text('Gerenciar cartões'),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          for (final card in _savedCards) ...[
            _SavedCardTile(
              card: card,
              selected: _selectedCardId == card['id']?.toString(),
              onTap: () {
                setState(() {
                  _selectedCardId = card['id']?.toString();
                });
              },
            ),
            if (card != _savedCards.last) const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              setState(() {
                _selectedCardId = _newCardSentinel;
              });
              final bookingId = widget.bookingData['id']?.toString() ?? '';
              if (bookingId.isNotEmpty) {
                await _payWithNewCard(bookingId);
              }
            },
            icon: const Icon(Icons.add_card),
            label: const Text('Usar outro cartão agora'),
          ),
        ],
      ),
    );
  }

  Widget _buildCvvSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Código de segurança',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cvvController,
            decoration: InputDecoration(
              labelText: 'CVV',
              hintText: '3 ou 4 dígitos',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Os 3 ou 4 dígitos no verso do seu cartão',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsSection(ThemeData theme) {
    final installmentsOptions = List<int>.generate(12, (index) => index + 1);

    if (!widget.workshopAcceptsInstallment) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD180)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFFFFA726)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'A oficina selecionada não aceita parcelamento. Pagamento apenas à vista.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF6C00)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parcelamento',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedInstallments,
            items: installmentsOptions
                .map(
                  (installment) => DropdownMenuItem<int>(
                    value: installment,
                  child: Text(
                      installment == 1
                          ? 'À vista (${_currencyFormatter.format(widget.totalAmount)})'
                          : '${installment}x de ${_currencyFormatter.format(widget.totalAmount / installment)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedInstallments = value;
                });
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme) {
    final status = (_paymentRecord?['status'] ?? '').toString().toLowerCase();
    final isPix = _selectedMethod == 'pix';
    final isDeclined = status == 'declined' || status == 'denied';
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final gatewayMessage = (_paymentRecord?['gateway_message'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'approved'
                    ? Icons.check_circle
                    : (isDeclined || isCancelled)
                        ? Icons.error_outline
                    : isPix
                        ? Icons.qr_code_2
                        : Icons.access_time,
                color: status == 'approved'
                    ? theme.colorScheme.primary
                    : (isDeclined || isCancelled)
                        ? Colors.redAccent
                    : theme.colorScheme.secondary,
                size: 32,
          ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status == 'approved'
                      ? 'Pagamento confirmado! Obrigado por usar o MECA.'
                      : (isDeclined
                          ? 'Pagamento negado. Veja o motivo abaixo.'
                          : (isCancelled
                              ? 'Pagamento cancelado.'
                              : (isPix
                                  ? 'PIX gerado. Copie o código abaixo e finalize em seu aplicativo bancário.'
                                  : 'Pagamento em análise. A confirmação pode levar alguns instantes.'))),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isDeclined) ...[
            Text(
              'Motivo: ${gatewayMessage.isNotEmpty ? gatewayMessage : 'Não autorizado pelo PagBank/PagSeguro'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O que fazer: tente outro cartão, verifique limite/dados do cartão, ou use PIX.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isPix) _buildPixResult(theme) else _buildCardResult(theme),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isDeclined || isCancelled) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Permitir tentar novamente sem sair da tela
                      _statusTimer?.cancel();
                      setState(() {
                        _showResult = false;
                        _paymentId = null;
                        _paymentRecord = null;
                        _pixCode = null;
                        _paymentLink = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isSubmitting || _isCheckingStatus) ? null : () => _checkPaymentStatus(silent: false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar status'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _statusTimer?.cancel();
                    Navigator.pop(context, false);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPixResult(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pixCode != null && _pixCode!.isNotEmpty) ...[
        Text(
            'Código PIX (copia e cola)',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: SelectableText(
              _pixCode!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              if (_pixCode == null) return;
              await Clipboard.setData(ClipboardData(text: _pixCode!));
              if (!mounted) return;
              AppAlerts.showSuccess(
                context,
                message: 'Código PIX copiado para a área de transferência.',
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar código'),
          ),
        ],
        if (_paymentLink != null && _paymentLink!.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openPaymentLink(_paymentLink!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir página de pagamento PagBank'),
          ),
        ],
      ],
    );
  }

  Widget _buildCardResult(ThemeData theme) {
    final status = (_paymentRecord?['status'] ?? '').toString().toLowerCase();
    final gatewayMessage = (_paymentRecord?['gateway_message'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status atual: ${_statusLabel(status)}',
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if ((status == 'declined' || status == 'denied') && gatewayMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Motivo: $gatewayMessage',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
        ],
        if (_paymentRecord?['installments'] != null && (_paymentRecord?['installments'] ?? 1) > 1) ...[
          const SizedBox(height: 8),
          Text(
            'Parcelamento: ${_paymentRecord?['installments']}x de ${_currencyFormatter.format(widget.totalAmount / (_paymentRecord?['installments'] ?? 1))}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (_paymentLink != null && _paymentLink!.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openPaymentLink(_paymentLink!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ver detalhes no PagBank'),
          ),
        ],
      ],
    );
  }

  Future<void> _openPaymentLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppAlerts.showError(
        context,
        message: 'Link inválido fornecido pelo PagBank.',
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível abrir o link do PagBank.',
      );
    }
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? theme.colorScheme.primary : theme.iconTheme.color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(Icons.check_circle, key: const ValueKey('checked'), color: theme.colorScheme.primary)
                  : const SizedBox(width: 24, key: ValueKey('unchecked')),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SavedCardTile extends StatelessWidget {
  const _SavedCardTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = (card['brand'] ?? card['card_brand'] ?? 'Cartão').toString();
    final lastDigits =
        (card['last4'] ?? card['last_four'] ?? card['last_digits'] ?? card['lastFourDigits'] ?? '****').toString();
    final holder = (card['holder_name'] ?? card['cardholder_name'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
          ),
              child: Icon(
                Icons.credit_card,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Text(
                    '$brand •••• $lastDigits',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (holder.isNotEmpty)
                    Text(
                      holder,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
                    ),
                ],
              ),
            ),
            Radio<String>(
              value: card['id']?.toString() ?? '',
              groupValue: selected ? card['id']?.toString() : null,
              onChanged: (_) => onTap(),
              activeColor: Theme.of(context).colorScheme.primary,
            )
          ],
            ),
        ),
      );
    }
  }

