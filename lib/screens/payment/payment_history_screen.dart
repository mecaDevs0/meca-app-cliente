import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/theme_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.get('/payments');
      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'];
        final List<dynamic> raw = data is List
            ? data
            : (data is Map && data['payments'] is List)
                ? data['payments'] as List
                : [];
        setState(() {
          _payments = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Erro ao carregar pagamentos';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao conectar com o servidor';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          appBar: AppBar(
            elevation: 0,
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : Colors.white,
            title: Text(
              'Meus Pagamentos',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF252940),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF252940),
            ),
          ),
          body: _buildBody(isDark),
        );
      },
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C977)),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(isDark);
    }

    return RefreshIndicator(
      color: const Color(0xFF00C977),
      onRefresh: _loadPayments,
      child: _payments.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _payments.length,
              itemBuilder: (context, index) =>
                  _buildPaymentCard(_payments[index], isDark),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C977).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF00C977),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nenhum pagamento encontrado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF252940),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Você ainda não tem pagamentos',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar pagamentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF252940),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ocorreu um erro inesperado',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPayments,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C977),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, bool isDark) {
    final amount = double.tryParse(payment['amount']?.toString() ?? '') ?? 0.0;
    final method = (payment['payment_method'] as String? ?? '').toUpperCase();
    final status = payment['status'] as String? ?? '';
    final installments = int.tryParse(payment['installments']?.toString() ?? '') ?? 1;
    final createdAtRaw = payment['created_at'] as String?;
    final bookingId = payment['booking_id']?.toString() ?? '';
    final paymentId = payment['id']?.toString() ?? '';

    // Derive display name: prefer booking service name or a readable fallback
    final serviceName = payment['service_name'] as String?;
    final workshopName = payment['workshop_name'] as String?;
    final displayTitle = serviceName?.isNotEmpty == true
        ? serviceName!
        : bookingId.isNotEmpty
            ? 'Agendamento #${bookingId.substring(0, bookingId.length.clamp(0, 8))}'
            : 'Pagamento #${paymentId.substring(0, paymentId.length.clamp(0, 8))}';

    DateTime? parsedDate;
    if (createdAtRaw != null) {
      try {
        parsedDate = DateTime.parse(createdAtRaw).toLocal();
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C977).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    color: Color(0xFF00C977),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + workshop
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF252940),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (workshopName != null && workshopName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          workshopName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF252940),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Date
                if (parsedDate != null) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _dateFormat.format(parsedDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Method badge
                _buildMethodBadge(method),
                const SizedBox(width: 8),
                // Status badge
                _buildStatusBadge(status),
              ],
            ),
            // Installments line — only shown for credit card with more than 1 installment
            if (method == 'CREDIT_CARD' && installments > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${installments}x de ${_currencyFormat.format(amount / installments)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String method) {
    final bool isPix =
        method == 'PIX' || method.contains('PIX');
    final color = isPix ? const Color(0xFF00C977) : const Color(0xFF3B82F6);
    final label = isPix ? 'PIX' : 'Cartao';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
      case 'paid':
      case 'confirmed':
        color = const Color(0xFF00C977);
        label = 'Aprovado';
        break;
      case 'pending':
      case 'waiting_payment':
        color = const Color(0xFFF59E0B);
        label = 'Pendente';
        break;
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'refunded':
        color = const Color(0xFFEF4444);
        label = 'Cancelado';
        break;
      default:
        color = Colors.grey;
        label = status.isNotEmpty ? status : 'Desconhecido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
