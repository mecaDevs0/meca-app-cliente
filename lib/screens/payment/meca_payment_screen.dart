import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/app_alerts.dart';
import '../review/review_screen.dart';
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

  bool _loadingCards = true;
  bool _isSubmitting = false;
  bool _showResult = false;

  Future<void> _navigateToReviewScreen() async {
    final bookingId = widget.bookingData['id']?.toString() ?? widget.bookingData['booking_id']?.toString();
    final workshopId = widget.bookingData['workshop_id']?.toString() ?? widget.bookingData['oficina_id']?.toString();
    
    if (bookingId != null && workshopId != null && mounted) {
      Navigator.pop(context, true);
      await Future.delayed(const Duration(milliseconds: 300));
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
        Navigator.pop(context, true);
      }
    }
  }

  String _selectedMethod = 'pix';
  String? _selectedCardId;
  int _selectedInstallments = 1;

  List<Map<String, dynamic>> _savedCards = [];

  Map<String, dynamic>? _paymentRecord;
  String? _pixCode;
  String? _paymentLink;
  String? _paymentId;

  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _selectedInstallments = widget.installments > 0 ? widget.installments : 1;
    _loadSavedCards();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _loadingCards = true;
    });

    try {
      final result = await _apiService.getSavedCards();
      if (!mounted) return;

      if (result['success']) {
        final cards = List<Map<String, dynamic>>.from(result['data'] ?? []);
        _savedCards = cards.where((card) => (card['card_token'] ?? card['cardToken'] ?? '').toString().isNotEmpty).toList();

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

    if (_selectedMethod == 'credit_card') {
      if (_savedCards.isEmpty) {
        AppAlerts.showWarning(
          context,
          title: 'Nenhum cartão disponível',
          message: 'Adicione um cartão salvo para pagar com crédito.',
        );
        return;
      }

      if (_selectedCardId == null) {
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

      final String? cardToken = _selectedMethod == 'credit_card' ? _extractCardToken(_selectedCardId) : null;
      if (_selectedMethod == 'credit_card' && (cardToken == null || cardToken.isEmpty)) {
        throw Exception('Cartão selecionado não possui token válido.');
      }

      // Usar createBookingPayment que valida o status do booking antes de criar pagamento
      final paymentResult = await _apiService.createBookingPayment(
        bookingId,
        paymentMethod: _selectedMethod == 'credit_card' ? 'CREDIT_CARD' : 'PIX',
        cardToken: cardToken,
        installments: _selectedMethod == 'credit_card' ? _selectedInstallments : null,
        pixExpirationInSeconds: _selectedMethod == 'pix' ? 3600 : null,
      );

      if (!mounted) return;

      if (!paymentResult['success']) {
        AppAlerts.showError(
          context,
          message: paymentResult['error'] ?? 'Não foi possível iniciar o pagamento agora.',
        );
        return;
      }

      final data = paymentResult['data'] as Map<String, dynamic>? ?? {};
      final payment = Map<String, dynamic>.from(data['payment'] ?? {});
      final charge = data['charge'];

      _paymentRecord = payment;
      _pixCode = payment['pix_qr_code'] ?? payment['pixCode'] ?? payment['pix_code'];
      _paymentLink = payment['payment_link'] ?? payment['paymentLink'] ?? charge?['payment_link'];
      _paymentId = payment['id']?.toString();
      _showResult = true;

      final status = (payment['status'] ?? '').toString().toLowerCase();
      if (_selectedMethod == 'credit_card' && status == 'approved') {
        AppAlerts.showSuccess(
          context,
          message: 'Pagamento aprovado com sucesso! Obrigado por usar o MECA.',
        );
        // Redirecionar para tela de avaliação após pagamento aprovado
        await _navigateToReviewScreen();
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

  void _startStatusPolling() {
    _statusTimer?.cancel();
    if (_paymentId == null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkPaymentStatus(silent: true);
    });
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_paymentId == null) return;

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
        };
      });

      if (status == 'approved') {
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
  }

  String? _extractCardToken(String? cardId) {
    if (cardId == null) return null;
    final card = _savedCards.firstWhere(
      (element) => element['id']?.toString() == cardId,
      orElse: () => {},
    );
    return (card['card_token'] ?? card['cardToken'] ?? '').toString();
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
      bottomNavigationBar: Padding(
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
            'Orçamento aprovado',
            _currencyFormatter.format(widget.serviceAmount),
          ),
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
              onPressed: _openSavedCards,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar cartão'),
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
                    : isPix
                        ? Icons.qr_code_2
                        : Icons.access_time,
                color: status == 'approved'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
                size: 32,
          ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status == 'approved'
                      ? 'Pagamento confirmado! Obrigado por usar o MECA.'
                      : isPix
                          ? 'PIX gerado. Copie o código abaixo e finalize em seu aplicativo bancário.'
                          : 'Pagamento em análise. A confirmação pode levar alguns instantes.',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPix) _buildPixResult(theme) else _buildCardResult(theme),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _checkPaymentStatus(silent: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar status'),
                ),
              ),
              const SizedBox(width: 12),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status atual: ${status == 'approved' ? 'Aprovado' : status == 'pending' ? 'Em análise' : status.toUpperCase()}',
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
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

