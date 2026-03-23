import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/asaas_payment_service.dart';
import '../../widgets/app_alerts.dart';
import '../review/review_screen.dart';
import 'encrypt_card_screen.dart';
import 'saved_cards_screen.dart';

class MecaPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final double totalAmount;
  final double mecaFee;
  final double serviceAmount;
  final int installments;
  final bool workshopAcceptsInstallment;
  final int workshopMaxInstallments;

  /// true quando o pagamento é de uma pré-compra (usa endpoint /pre-compra/:id/pay)
  final bool isPreCompra;

  const MecaPaymentScreen({
    Key? key,
    required this.bookingData,
    required this.totalAmount,
    required this.mecaFee,
    required this.serviceAmount,
    required this.installments,
    this.workshopAcceptsInstallment = true,
    this.workshopMaxInstallments = 12,
    this.isPreCompra = false,
  }) : super(key: key);

  @override
  State<MecaPaymentScreen> createState() => _MecaPaymentScreenState();
}

class _MecaPaymentScreenState extends State<MecaPaymentScreen> {
  final ApiService _apiService = ApiService();
  final AsaasPaymentService _asaasPaymentService = AsaasPaymentService();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static const String _newCardSentinel = '__new_card__';

  bool _loadingCards = true;
  bool _isSubmitting = false;
  bool _isCheckingStatus = false;
  bool _showResult = false;

  Future<void> _navigateToReviewScreen() async {
    // Pré-compra: sem tela de avaliação — apenas fecha e retorna sucesso
    if (widget.isPreCompra) {
      _apiService.invalidateBookingsCache();
      if (mounted) Navigator.pop(context, true);
      return;
    }

    final bookingId = widget.bookingData['id']?.toString() ??
        widget.bookingData['booking_id']?.toString();
    final workshopId = widget.bookingData['workshop_id']?.toString() ??
        widget.bookingData['oficina_id']?.toString();

    if (bookingId != null && workshopId != null && mounted) {
      _apiService.invalidateBookingCache(bookingId);
      _apiService.invalidateBookingsCache();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // Substituir tela de pagamento pela de avaliação (não voltar para detalhes do pedido)
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            bookingId: bookingId,
            workshopId: workshopId,
          ),
        ),
      );
    } else {
      if (mounted) Navigator.pop(context, true);
    }
  }

  String _selectedMethod = 'pix';
  String? _selectedCardId;
  int _selectedInstallments = 1;
  final TextEditingController _cvvController = TextEditingController();

  List<Map<String, dynamic>> _savedCards = [];

  /// Planos de parcelamento da API (GET /payments/installments). Null = ainda não carregou ou oficina não aceita.
  List<Map<String, dynamic>>? _installmentPlans;
  bool _loadingInstallmentPlans = false;

  /// Máximo de parcelas retornado pela API (oficina). Usado no label "até Nx".
  int? _maxInstallmentsFromApi;

  /// Plano selecionado (mesmo que _selectedInstallments) para enviar total_with_interest, interest_paid_by_buyer, installment_value.
  Map<String, dynamic>? _selectedInstallmentPlan;

  Map<String, dynamic>? _paymentRecord;
  String? _pixCode;
  String? _pixQrCodeBase64;
  int _pixSecondsRemaining = 3600;
  Timer? _pixExpirationTimer;
  bool _pixExpired = false;
  String? _paymentLink;
  String? _paymentId;
  bool _cardsMigrationNoticeShown = false;
  bool _cardsMigratedToAsaas = false;

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
    return 'O gateway de pagamento não autorizou a transação.\n\nO que fazer: tente outro cartão, verifique limite/dados do cartão, ou use PIX.';
  }

  String? _pickFirstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  void _setPixDataFromResponse(
      Map<String, dynamic> data, Map<String, dynamic> payment) {
    _pixQrCodeBase64 = _pickFirstNonEmpty([
      data['pix_qr_code'],
      payment['pix_qr_code'],
      data['pixQrCode'],
      payment['pixQrCode'],
      data['asaas_pix_qrcode'],
      payment['asaas_pix_qrcode'],
    ]);

    _pixCode = _pickFirstNonEmpty([
      data['pix_copy_paste'],
      payment['pix_copy_paste'],
      data['pixCopyPaste'],
      payment['pixCopyPaste'],
      data['pix_code'],
      payment['pix_code'],
      data['qr_code'],
      payment['qr_code'],
      // Compatibilidade antiga: alguns retornos antigos usavam pix_qr_code como payload "copia e cola".
      data['pix_qr_code'],
      payment['pix_qr_code'],
    ]);
  }

  void _showCardsMigrationNoticeIfNeeded(Map<String, dynamic> data) {
    if (_cardsMigrationNoticeShown || !mounted) return;

    final cardsRequireUpdate = data['cards_require_update'] == true;
    final cardsMigratedToAsaas = data['cards_migrated_to_asaas'] == true;
    if (!cardsRequireUpdate && !cardsMigratedToAsaas) return;

    _cardsMigrationNoticeShown = true;
    final message = cardsRequireUpdate
        ? 'Por segurança, seus cartões salvos precisam ser recadastrados neste pagamento.'
        : 'Seus cartões salvos foram migrados para o novo provedor. Caso algum cartão não funcione, recadastre-o.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Uint8List? _decodePixQrImage(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    try {
      // Aceita Base64 puro ou data URL (data:image/png;base64,...)
      final normalized = value.contains(',')
          ? value.substring(value.indexOf(',') + 1).trim()
          : value;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedInstallments = widget.installments > 0 ? widget.installments : 1;
    _loadSavedCards();
    if (widget.workshopAcceptsInstallment && widget.totalAmount > 0) {
      _loadInstallmentPlans();
    } else {
      // Oficina não aceita parcelamento: usar só 1x à vista
      _installmentPlans = _fallbackInstallmentPlan();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pixExpirationTimer?.cancel();
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
        final cardsMigratedFlagFromResponse =
            result['cards_migrated_to_asaas'] == true;
        final cardsMigratedFlagFromItems =
            cards.any((card) => card['cards_migrated_to_asaas'] == true);
        _cardsMigratedToAsaas =
            cardsMigratedFlagFromResponse || cardsMigratedFlagFromItems;
        // Filtrar cartões válidos para pagamento:
        // - Tokens de cartão normalmente começam com "CARD_"
        // - (Tokens "CHAR_" são IDs de charge e dão INVALID_CARD_ID)
        _savedCards = cards.where((card) {
          final token =
              (card['card_token'] ?? card['cardToken'] ?? '').toString();
          if (token.isEmpty) return false;
          // Só aceitar tokens de cartão (CARD_). Qualquer outro formato deve ser ignorado.
          if (!token.startsWith('CARD_')) return false;
          return true;
        }).toList();

        if (_cardsMigratedToAsaas) {
          _selectedCardId = _newCardSentinel;
          if (_savedCards.isNotEmpty && mounted && !_cardsMigrationNoticeShown) {
            _cardsMigrationNoticeShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Atualize seus dados de cartão'),
                  content: const Text(
                    'Por segurança, precisamos que você insira os dados do cartão novamente neste pagamento.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              );
            });
          }
        } else if (_savedCards.isNotEmpty) {
          _selectedCardId = _savedCards.first['id']?.toString();
        } else {
          _selectedCardId = null;
        }
      } else {
        _savedCards = [];
        _cardsMigratedToAsaas = false;
        _selectedCardId = null;
        if (mounted) {
          AppAlerts.showWarning(
            context,
            title: 'Cartões indisponíveis',
            message: result['error'] ??
                'Não foi possível carregar seus cartões salvos agora.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _savedCards = [];
      _selectedCardId = null;
      AppAlerts.showError(
        context,
        message:
            'Não foi possível carregar seus cartões salvos. Tente novamente em instantes.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCards = false;
        });
      }
    }
  }

  /// Carrega opções de parcelamento da API (GET /payments/installments). Passa booking_id para respeitar configuração da oficina.
  Future<void> _loadInstallmentPlans() async {
    if (widget.totalAmount <= 0) return;
    setState(() {
      _loadingInstallmentPlans = true;
      _installmentPlans = null;
    });
    final bookingId = widget.bookingData['id']?.toString() ??
        widget.bookingData['booking_id']?.toString();
    final workshopId = widget.bookingData['workshop_id']?.toString() ??
        widget.bookingData['oficina_id']?.toString();
    try {
      final result = await _apiService.getInstallments(
        widget.totalAmount,
        bookingId: bookingId,
        workshopId: workshopId,
      );
      if (!mounted) return;
      if (result['success'] == true && result['plans'] != null) {
        final plans = List<Map<String, dynamic>>.from(result['plans'] as List);
        final maxFromApi = result['max_installments'] is int
            ? result['max_installments'] as int?
            : int.tryParse(result['max_installments']?.toString() ?? '');
        setState(() {
          _installmentPlans =
              plans.isNotEmpty ? plans : _fallbackInstallmentPlan();
          _maxInstallmentsFromApi = maxFromApi;
          _loadingInstallmentPlans = false;
          _syncSelectedPlanFromInstallments();
        });
      } else {
        setState(() {
          _installmentPlans = _fallbackInstallmentPlan();
          _maxInstallmentsFromApi = null;
          _loadingInstallmentPlans = false;
          _syncSelectedPlanFromInstallments();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _installmentPlans = _fallbackInstallmentPlan();
          _maxInstallmentsFromApi = null;
          _loadingInstallmentPlans = false;
          _syncSelectedPlanFromInstallments();
        });
      }
    }
  }

  List<Map<String, dynamic>> _fallbackInstallmentPlan() {
    return [
      {
        'installments': 1,
        'installment_value_cents': (widget.totalAmount * 100).round(),
        'total_cents': (widget.totalAmount * 100).round(),
        'interest_cents': 0,
        'interest_free': true,
      },
    ];
  }

  void _syncSelectedPlanFromInstallments() {
    if (_installmentPlans == null || _installmentPlans!.isEmpty) return;
    final plan = _installmentPlans!.firstWhere(
      (p) => (p['installments'] as int?) == _selectedInstallments,
      orElse: () => _installmentPlans!.first,
    );
    _selectedInstallmentPlan = plan;
  }

  Future<void> _handlePay() async {
    if (_isSubmitting) return;

    // Evitar pagamento duplicado: se já existe um pagamento em análise nesta tela, não criar outro
    if (_paymentId != null && _showResult) {
      AppAlerts.showInfo(
        context,
        title: 'Pagamento já iniciado',
        message:
            'Seu pagamento já foi iniciado e está em análise. Aguarde a confirmação ou toque em "Atualizar status".',
      );
      return;
    }

    if (_selectedMethod == 'credit_card') {
      if (_cardsMigratedToAsaas) {
        final bookingId = widget.bookingData['id']?.toString() ?? '';
        if (bookingId.isNotEmpty) {
          await _payWithNewCard(bookingId);
        }
        return;
      }
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
      if (_selectedMethod == 'credit_card' &&
          _selectedCardId == _newCardSentinel) {
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

      final workshopAccountId =
          (widget.bookingData['workshop_pagbank_account_id'] ??
                  widget.bookingData['workshopPagbankAccountId'])
              ?.toString()
              .trim();
      final plan =
          _selectedMethod == 'credit_card' ? _selectedInstallmentPlan : null;
      final totalWithInterest =
          plan != null && (plan['total_cents'] as int?) != null
              ? (plan['total_cents'] as int) / 100.0
              : null;
      final interestPaidByBuyer =
          plan != null && (plan['interest_cents'] as int?) != null
              ? (plan['interest_cents'] as int) / 100.0
              : null;
      final installmentValue =
          plan != null && (plan['installment_value_cents'] as int?) != null
              ? (plan['installment_value_cents'] as int) / 100.0
              : null;
      final interestInstallments =
          plan != null ? (plan['interest_installments'] as int?) : null;
      // Escolher endpoint correto (booking normal vs pré-compra)
      final paymentResult = widget.isPreCompra
          ? await _apiService.createPreCompraPayment(
              bookingId,
              paymentMethod:
                  _selectedMethod == 'credit_card' ? 'CREDIT_CARD' : 'PIX',
              cardToken: cardToken,
              cvv: cvv,
              holderName: _selectedMethod == 'credit_card'
                  ? _extractCardHolderName(_selectedCardId)
                  : null,
              installments: _selectedMethod == 'credit_card'
                  ? _selectedInstallments
                  : null,
              totalWithInterest: totalWithInterest,
              interestPaidByBuyer: interestPaidByBuyer,
              installmentValue: installmentValue,
              interestInstallments: interestInstallments,
              pixExpirationInSeconds: _selectedMethod == 'pix' ? 3600 : null,
              workshopPagbankAccountId: workshopAccountId?.isNotEmpty == true
                  ? workshopAccountId
                  : null,
            )
          : await _apiService.createBookingPayment(
              bookingId,
              paymentMethod:
                  _selectedMethod == 'credit_card' ? 'CREDIT_CARD' : 'PIX',
              cardToken: cardToken,
              cvv: cvv,
              holderName: _selectedMethod == 'credit_card'
                  ? _extractCardHolderName(_selectedCardId)
                  : null,
              installments: _selectedMethod == 'credit_card'
                  ? _selectedInstallments
                  : null,
              totalWithInterest: totalWithInterest,
              interestPaidByBuyer: interestPaidByBuyer,
              installmentValue: installmentValue,
              interestInstallments: interestInstallments,
              pixExpirationInSeconds: _selectedMethod == 'pix' ? 3600 : null,
              workshopPagbankAccountId: workshopAccountId?.isNotEmpty == true
                  ? workshopAccountId
                  : null,
            );

      if (!mounted) return;

      if (!paymentResult['success']) {
        final errMsg = (paymentResult['error'] ?? '').toString();
        final normalized = errMsg.toUpperCase();

        // Caso comum em produção: token de cartão salvo antigo/inválido (INVALID_CARD_ID)
        // Nesse cenário, removemos o cartão inválido automaticamente e direcionamos para "outro cartão".
        if (_selectedMethod == 'credit_card' &&
            normalized.contains('INVALID_CARD_ID')) {
          if (!mounted) return;

          final badCardId = _selectedCardId;
          if (badCardId != null &&
              badCardId.isNotEmpty &&
              badCardId != _newCardSentinel) {
            try {
              await _apiService.deleteCard(badCardId);
            } catch (_) {}
          }

          if (badCardId != null) {
            _savedCards.removeWhere((c) => c['id']?.toString() == badCardId);
            _selectedCardId = _savedCards.isNotEmpty
                ? _savedCards.first['id']?.toString()
                : null;
          }

          try {
            await _loadSavedCards();
          } catch (_) {}

          final proceed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cartão inválido removido'),
                  content: const Text(
                    'Removemos este cartão da sua lista porque ele não pôde ser validado pelo gateway de pagamento.\n\n'
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
          message: errMsg.isNotEmpty
              ? errMsg
              : 'Não foi possível iniciar o pagamento agora.',
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
      if (_selectedMethod == 'credit_card' &&
          (status == 'approved' || status == 'paid')) {
        print(
            '✅ [Payment] Pagamento APROVADO IMEDIATAMENTE - navegando para review');
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
        // Aguardar para o cache ser invalidado, depois dismiss do Flushbar antes de navegar.
        // O Flushbar (another_flushbar) empurra um FlushbarRoute na pilha — se não
        // dismissar antes, Navigator.pop poparia o FlushbarRoute em vez da tela de pagamento.
        await Future.delayed(const Duration(milliseconds: 500));
        await AppAlerts.dismissCurrent();
        await _navigateToReviewScreen();
        return;
      }

      // Para PIX ou pagamentos pendentes, continuar com o fluxo normal
      _showCardsMigrationNoticeIfNeeded(data);

      final payment = Map<String, dynamic>.from(data['payment'] ?? data);
      payment['provider'] ??= data['provider'];
      _paymentRecord = payment;
      _setPixDataFromResponse(data, payment);
      if (_selectedMethod == 'pix') _startPixExpirationTimer();
      _paymentLink = payment['payment_link'] ??
          payment['paymentLink'] ??
          data['payment_link'];
      _paymentId = paymentId ?? payment['id']?.toString();
      _showResult = true;

      final gatewayMessage =
          (data['gateway_message'] ?? payment['gateway_message'] ?? '')
              .toString()
              .trim();
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
              : (isDeclined
                  ? 'O gateway de pagamento não autorizou o pagamento. Tente outro cartão.'
                  : 'O pagamento foi cancelado.'),
        );
        setState(() {});
        return;
      }

      if (_selectedMethod == 'pix') {
        AppAlerts.showInfo(
          context,
          title: 'PIX gerado',
          message:
              'Copie o código abaixo para concluir o pagamento no seu banco.',
        );
      } else {
        AppAlerts.showInfo(
          context,
          title: 'Pagamento em análise',
          message:
              'O gateway de pagamento está processando seu pagamento. Avisaremos assim que for confirmado.',
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
                        title:
                            const Text('Salvar cartão para próximas compras'),
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
        AppAlerts.showWarning(context,
            title: 'Dados inválidos',
            message: 'Informe um número de cartão válido.');
        return;
      }
      if (holderName.isEmpty) {
        AppAlerts.showWarning(context,
            title: 'Dados inválidos',
            message: 'Informe o nome impresso no cartão.');
        return;
      }
      if (expMonth.length != 2 || expYear.isEmpty) {
        AppAlerts.showWarning(context,
            title: 'Dados inválidos',
            message: 'Informe o mês e o ano de validade.');
        return;
      }
      if (cvv.length < 3) {
        AppAlerts.showWarning(context,
            title: 'Dados inválidos', message: 'Informe um CVV válido.');
        return;
      }

      if (expYear.length == 2) {
        expYear = '20$expYear';
      }

      final tokenizedCardResult =
          await Navigator.of(context).push<Map<String, dynamic>?>(
        MaterialPageRoute(
          builder: (_) => EncryptCardScreen(
            publicKey: '',
            holderName: holderName,
            number: rawNumber,
            expMonth: expMonth,
            expYear: expYear,
            securityCode: cvv,
          ),
          fullscreenDialog: true,
        ),
      );
      if (tokenizedCardResult == null || tokenizedCardResult['success'] != true) {
        AppAlerts.showError(context,
            message:
                tokenizedCardResult?['error']?.toString() ??
                    'Não foi possível processar o cartão. Tente novamente.');
        return;
      }
      final creditCard =
          Map<String, dynamic>.from(tokenizedCardResult['credit_card'] ?? {});
      if (creditCard.isEmpty) {
        AppAlerts.showError(context,
            message: 'Dados de cartão inválidos para pagamento.');
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

      final workshopAccountId =
          (widget.bookingData['workshop_pagbank_account_id'] ??
                  widget.bookingData['workshopPagbankAccountId'])
              ?.toString()
              .trim();
      final plan = _selectedInstallmentPlan;
      final totalWithInterest =
          plan != null && (plan['total_cents'] as int?) != null
              ? (plan['total_cents'] as int) / 100.0
              : null;
      final interestPaidByBuyer =
          plan != null && (plan['interest_cents'] as int?) != null
              ? (plan['interest_cents'] as int) / 100.0
              : null;
      final installmentValue =
          plan != null && (plan['installment_value_cents'] as int?) != null
              ? (plan['installment_value_cents'] as int) / 100.0
              : null;
      final interestInstallments =
          plan != null ? (plan['interest_installments'] as int?) : null;
      final payload = <String, dynamic>{
        'payment_method': 'CREDIT_CARD',
        'paymentMethod': 'CREDIT_CARD',
        'credit_card': creditCard,
        'installments': _selectedInstallments,
        'saveCard': saveCard,
        'lastDigits': lastDigits,
        'brand': brand,
        'expiryMonth': expMonth,
        'expiryYear': expYear,
      };
      if (totalWithInterest != null && totalWithInterest > 0) {
        payload['totalWithInterest'] = totalWithInterest;
        payload['total_with_interest'] = totalWithInterest;
      }
      if (interestPaidByBuyer != null && interestPaidByBuyer >= 0) {
        payload['interestPaidByBuyer'] = interestPaidByBuyer;
        payload['interest_paid_by_buyer'] = interestPaidByBuyer;
      }
      if (installmentValue != null && installmentValue > 0) {
        payload['installmentValue'] = installmentValue;
        payload['installment_value'] = installmentValue;
      }
      if (interestInstallments != null && interestInstallments > 0) {
        payload['interest_installments'] = interestInstallments;
      }
      if (workshopAccountId?.isNotEmpty == true) {
        payload['workshopAccountId'] = workshopAccountId;
        payload['pagbankAccountId'] = workshopAccountId;
      }

      final paymentResult = widget.isPreCompra
          ? await _apiService.post('/pre-compra/$bookingId/pay', payload)
          : await _apiService.post('/bookings/$bookingId/payment', payload);

      if (!mounted) return;
      if (paymentResult['success'] != true) {
        AppAlerts.showError(context,
            message: paymentResult['error'] ??
                'Não foi possível iniciar o pagamento agora.');
        return;
      }

      // Atualizar cartões (se o backend salvou token após pagamento aprovado)
      try {
        await _loadSavedCards();
      } catch (_) {}

      final data = paymentResult['data'] as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? '').toString().toLowerCase();
      _showCardsMigrationNoticeIfNeeded(data);

      if (status == 'approved' || status == 'paid') {
        AppAlerts.showSuccess(context,
            message:
                'Pagamento aprovado com sucesso! Obrigado por usar o MECA.');
        final id = widget.bookingData['id']?.toString();
        if (id != null) {
          _apiService.invalidateBookingCache(id);
          _apiService.invalidateBookingsCache();
        }
        await Future.delayed(const Duration(milliseconds: 500));
        await AppAlerts.dismissCurrent();
        await _navigateToReviewScreen();
        return;
      }

      final payment = Map<String, dynamic>.from(data['payment'] ?? data);
      payment['provider'] ??= data['provider'];
      _paymentRecord = payment;
      _setPixDataFromResponse(data, payment);
      if (_selectedMethod == 'pix') _startPixExpirationTimer();
      _paymentLink = payment['payment_link'] ??
          payment['paymentLink'] ??
          data['payment_link'];
      _paymentId = data['payment_id']?.toString() ?? payment['id']?.toString();
      _showResult = true;

      final normalized = status.toLowerCase();
      final gatewayMessage =
          (data['gateway_message'] ?? payment['gateway_message'] ?? '')
              .toString()
              .trim();
      final isDeclined = normalized == 'declined' || normalized == 'denied';
      final isCancelled = normalized == 'cancelled' || normalized == 'canceled';

      if (isDeclined || isCancelled) {
        _statusTimer?.cancel();
        AppAlerts.showWarning(
          context,
          title: isDeclined ? 'Pagamento negado' : 'Pagamento cancelado',
          message: isDeclined
              ? _declineHelpText(gatewayMessage)
              : 'O pagamento foi cancelado. Você pode tentar novamente.',
        );
        setState(() {});
        return;
      }

      AppAlerts.showInfo(
        context,
        title: 'Pagamento em análise',
        message:
            'O gateway de pagamento está processando seu pagamento. Você pode acompanhar o status aqui.',
      );
      _startStatusPolling();
      setState(() {});
    } catch (e) {
      if (mounted) {
        AppAlerts.showError(context,
            message:
                'Não foi possível processar o pagamento com cartão agora.');
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

  void _startPixExpirationTimer() {
    _pixExpirationTimer?.cancel();
    _pixSecondsRemaining = 3600;
    _pixExpired = false;
    _pixExpirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _pixSecondsRemaining--;
        if (_pixSecondsRemaining <= 0) {
          _pixExpired = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_paymentId == null) return;
    if (_isCheckingStatus) return;

    setState(() => _isCheckingStatus = true);

    var result = await _apiService.getPaymentStatus(_paymentId!);
    if (result['success'] != true) {
      final provider =
          (_paymentRecord?['provider'] ?? '').toString().toLowerCase();
      final hasAsaasPayload =
          provider == 'asaas' || (_pixQrCodeBase64?.isNotEmpty == true);
      if (hasAsaasPayload) {
        final asaasResult =
            await _asaasPaymentService.getPaymentStatus(_paymentId!);
        if (asaasResult['success'] == true) {
          result = {
            'success': true,
            'data': asaasResult['data'],
          };
        }
      }
    }
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
        _pixExpirationTimer?.cancel();
        if (!silent) {
          AppAlerts.showSuccess(
            context,
            message: 'Pagamento confirmado! Obrigado por usar o MECA.',
          );
        }
        if (mounted) {
          await AppAlerts.dismissCurrent();
          // Redirecionar para tela de avaliação após pagamento confirmado
          await _navigateToReviewScreen();
        }
      } else if (status == 'declined' || status == 'denied') {
        _statusTimer?.cancel();
        if (!silent) {
          AppAlerts.showWarning(
            context,
            title: 'Pagamento negado',
            message: _declineHelpText(
                _paymentRecord?['gateway_message']?.toString()),
          );
        }
      } else if (!silent) {
        AppAlerts.showInfo(
          context,
          title: 'Status atualizado',
          message: status == 'pending'
              ? 'Ainda em análise pelo gateway de pagamento.'
              : 'Status atual: ${_statusLabel(status)}',
        );
      } else if (!silent && status == 'cancelled') {
        AppAlerts.showWarning(
          context,
          title: 'Pagamento cancelado',
          message:
              'Não recebemos a confirmação do pagamento. Verifique se o pagamento foi concluído.',
        );
      }
    } else if (!silent) {
      AppAlerts.showError(
        context,
        message: result['error'] ??
            'Não foi possível atualizar o status do pagamento.',
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
      print(
          '🔍 [Payment] IDs disponíveis: ${_savedCards.map((c) => c['id']?.toString()).join(", ")}');
      return null;
    }

    // Tentar diferentes campos de token
    final token =
        card['card_token'] ?? card['cardToken'] ?? card['token'] ?? '';
    final tokenString = token.toString();

    print(
        '✅ [Payment] Token encontrado: ${tokenString.isNotEmpty ? tokenString.substring(0, Math.min(20, tokenString.length)) + "..." : "VAZIO"}');

    if (tokenString.isEmpty) {
      print(
          '❌ [Payment] Cartão encontrado mas token está vazio. Campos disponíveis: ${card.keys.join(", ")}');
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

    final holder = (card['holder_name'] ??
            card['cardholder_name'] ??
            card['holderName'] ??
            '')
        .toString()
        .trim();
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
      backgroundColor:
          isDark ? theme.colorScheme.surface : theme.colorScheme.background,
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
                _loadingCards
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSavedCardsSection(theme),
              if (_selectedMethod == 'credit_card' &&
                  _selectedCardId != null &&
                  _selectedCardId != _newCardSentinel) ...[
                const SizedBox(height: 20),
                _buildCvvSection(theme),
              ],
              if (_selectedMethod == 'credit_card' &&
                  widget.workshopAcceptsInstallment) ...[
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
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selectedMethod == 'credit_card'
                              ? 'Pagar ${_displayTotalToPay(theme)}'
                              : 'Gerar PIX de ${_displayTotalToPay(theme)}',
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildPaymentSummaryCard(ThemeData theme) {
    // Cálculo interno para consistência com backend (cliente não vê detalhes de split).
    final totalCents = (widget.totalAmount * 100).round();
    final mecaFeeCents = (totalCents * 0.12).round();
    final workshopCents = totalCents - mecaFeeCents;

    final surfaceColor = theme.colorScheme.surfaceVariant
        .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.9);
    final borderColor = theme.dividerColor
        .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bookingData['service_name'] ??
                widget.bookingData['service']?['name'] ??
                'Serviço',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            theme,
            'Total a pagar',
            _displayTotalToPay(theme),
            isTotal: true,
          ),
          if (_selectedMethod == 'credit_card' &&
              widget.workshopAcceptsInstallment &&
              _selectedInstallments > 1) ...[
            const SizedBox(height: 12),
            Text(
              _displayInstallmentLine(),
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

  /// Total a exibir no resumo: com juros do plano (cartão) ou valor do orçamento (PIX).
  /// Usa total_cents do plano de parcelamento (1x) para PIX e cartão, garantindo consistência.
  String _displayTotalToPay(ThemeData theme) {
    // Cartão: usa total do plano selecionado (pode ter juros)
    if (_selectedMethod == 'credit_card' && _selectedInstallmentPlan != null) {
      final raw = _selectedInstallmentPlan!['total_cents'];
      final totalCents = raw is int
          ? raw
          : (raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '0'));
      if (totalCents != null && totalCents > 0) {
        return _currencyFormatter.format(totalCents / 100.0);
      }
    }
    // PIX: usa o plano de 1x para ter o mesmo valor que o backend considera
    if (_installmentPlans != null && _installmentPlans!.isNotEmpty) {
      final plan1 = _installmentPlans!.firstWhere(
        (p) => (p['installments'] as int?) == 1,
        orElse: () => _installmentPlans!.first,
      );
      final raw = plan1['total_cents'];
      final totalCents = raw is int
          ? raw
          : (raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '0'));
      if (totalCents != null && totalCents > 0) {
        return _currencyFormatter.format(totalCents / 100.0);
      }
    }
    return _currencyFormatter.format(widget.totalAmount);
  }

  /// Linha de parcelas: valor da parcela e, se houver juros, total com juros.
  String _displayInstallmentLine() {
    if (_selectedInstallmentPlan == null) {
      return '${_selectedInstallments}x de ${_currencyFormatter.format(widget.totalAmount / _selectedInstallments)}';
    }
    final parcelCents =
        (_selectedInstallmentPlan!['installment_value_cents'] as int?) ?? 0;
    final totalCents = (_selectedInstallmentPlan!['total_cents'] as int?) ?? 0;
    final interestFree = _selectedInstallmentPlan!['interest_free'] == true;
    final parcel = parcelCents / 100.0;
    final total = totalCents / 100.0;
    if (interestFree) {
      return '${_selectedInstallments}x de ${_currencyFormatter.format(parcel)} sem juros';
    }
    return '${_selectedInstallments}x de ${_currencyFormatter.format(parcel)} (total ${_currencyFormatter.format(total)} com juros)';
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value,
      {bool isTotal = false, bool secondary = false}) {
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
            ? 'Parcelamento disponível (até ${widget.workshopMaxInstallments}x)'
            : 'Pagamento à vista',
        'icon': Icons.credit_card,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.dividerColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como você quer pagar?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
    if (_cardsMigratedToAsaas) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant
              .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.dividerColor.withOpacity(
                  theme.brightness == Brightness.dark ? 0.3 : 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atualize seus dados de cartão',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Por segurança, cartões salvos anteriormente não podem ser reutilizados neste pagamento.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final bookingId = widget.bookingData['id']?.toString() ?? '';
                if (bookingId.isNotEmpty) {
                  await _payWithNewCard(bookingId);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Inserir novo cartão'),
            ),
          ],
        ),
      );
    }

    if (_savedCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant
              .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.dividerColor.withOpacity(
                  theme.brightness == Brightness.dark ? 0.3 : 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nenhum cartão salvo',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione um cartão para pagar com crédito.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
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
        color: theme.colorScheme.surfaceVariant
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.dividerColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escolha um cartão salvo',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
        color: theme.colorScheme.surfaceVariant
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.dividerColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
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
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFFEF6C00)),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingInstallmentPlans) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant
              .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.dividerColor.withOpacity(
                  theme.brightness == Brightness.dark ? 0.3 : 0.15)),
        ),
        child: Row(
          children: [
            Text('Parcelamento',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      );
    }

    final plans = _installmentPlans ?? _fallbackInstallmentPlan();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.dividerColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Parcelamento',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                'até ${_maxInstallmentsFromApi ?? widget.workshopMaxInstallments}x',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'Valores e juros dinâmicos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          if (plans.isNotEmpty &&
              plans.length <
                  (_maxInstallmentsFromApi ?? widget.workshopMaxInstallments))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Para este valor, até ${plans.length}x disponíveis (mín. R\$ 5,00 por parcela).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: plans.firstWhere(
              (p) => (p['installments'] as int?) == _selectedInstallments,
              orElse: () => plans.first,
            ),
            items: plans.map(
              (plan) {
                final n = (plan['installments'] as int?) ?? 1;
                final installmentCents =
                    (plan['installment_value_cents'] as int?) ?? 0;
                final totalCents = (plan['total_cents'] as int?) ?? 0;
                final interestFree = plan['interest_free'] == true;
                final parcelValue = installmentCents / 100.0;
                final totalValue = totalCents / 100.0;
                final label = n == 1
                    ? 'À vista (${_currencyFormatter.format(totalValue)})'
                    : interestFree
                        ? '${n}x de ${_currencyFormatter.format(parcelValue)} sem juros'
                        : '${n}x de ${_currencyFormatter.format(parcelValue)} (total ${_currencyFormatter.format(totalValue)} com juros)';
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: plan,
                  child: Text(label),
                );
              },
            ).toList(),
            onChanged: (plan) {
              if (plan != null) {
                final n = (plan['installments'] as int?) ?? 1;
                setState(() {
                  _selectedInstallments = n;
                  _selectedInstallmentPlan = plan;
                });
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    final gatewayMessage =
        (_paymentRecord?['gateway_message'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.dividerColor
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.15)),
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isDeclined) ...[
            Text(
              'Motivo: ${gatewayMessage.isNotEmpty ? gatewayMessage : 'Não autorizado pelo gateway de pagamento'}',
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
                        _pixQrCodeBase64 = null;
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
                    onPressed: (_isSubmitting || _isCheckingStatus)
                        ? null
                        : () => _checkPaymentStatus(silent: false),
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
    final qrImageBytes = _decodePixQrImage(_pixQrCodeBase64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Countdown timer
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _pixExpired
                  ? const Color(0xFFEF4444).withOpacity(0.15)
                  : _pixSecondsRemaining <= 300
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : const Color(0xFF00C977).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pixExpired
                    ? const Color(0xFFEF4444).withOpacity(0.3)
                    : _pixSecondsRemaining <= 300
                        ? const Color(0xFFF59E0B).withOpacity(0.3)
                        : const Color(0xFF00C977).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _pixExpired ? Icons.timer_off : Icons.timer,
                  size: 18,
                  color: _pixExpired
                      ? const Color(0xFFEF4444)
                      : _pixSecondsRemaining <= 300
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF00C977),
                ),
                const SizedBox(width: 8),
                Text(
                  _pixExpired
                      ? 'QR Code expirado'
                      : '${(_pixSecondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_pixSecondsRemaining % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: _pixExpired
                        ? const Color(0xFFEF4444)
                        : _pixSecondsRemaining <= 300
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF00C977),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_pixExpired) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'O tempo para pagamento expirou.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _pixExpired = false;
                  _pixCode = null;
                  _pixQrCodeBase64 = null;
                  _showResult = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
        if (qrImageBytes != null) ...[
          Text(
            'QR Code PIX',
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Image.memory(
                qrImageBytes,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_pixCode != null && _pixCode!.isNotEmpty) ...[
          Text(
            'Código PIX (copia e cola)',
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
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
            label: const Text('Abrir página de pagamento'),
          ),
        ],
        ], // end else (not expired)
      ],
    );
  }

  Widget _buildCardResult(ThemeData theme) {
    final status = (_paymentRecord?['status'] ?? '').toString().toLowerCase();
    final gatewayMessage =
        (_paymentRecord?['gateway_message'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status atual: ${_statusLabel(status)}',
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if ((status == 'declined' || status == 'denied') &&
            gatewayMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Motivo: $gatewayMessage',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
        ],
        if (_paymentRecord?['installments'] != null &&
            (_paymentRecord?['installments'] ?? 1) > 1) ...[
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
            label: const Text('Ver detalhes do pagamento'),
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
        message: 'Link de pagamento inválido.',
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppAlerts.showError(
        context,
        message: 'Não foi possível abrir o link de pagamento.',
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
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(0.2),
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
              color:
                  selected ? theme.colorScheme.primary : theme.iconTheme.color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
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
                  ? Icon(Icons.check_circle,
                      key: const ValueKey('checked'),
                      color: theme.colorScheme.primary)
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
    final lastDigits = (card['last4'] ??
            card['last_four'] ??
            card['last_digits'] ??
            card['lastFourDigits'] ??
            '****')
        .toString();
    final holder =
        (card['holder_name'] ?? card['cardholder_name'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor.withOpacity(0.2),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (holder.isNotEmpty)
                    Text(
                      holder,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
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
