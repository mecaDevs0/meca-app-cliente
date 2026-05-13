import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../utils/price_utils.dart';
import '../../widgets/billing_data_sheet.dart';
import 'meca_payment_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic> workshop;
  final Map<String, dynamic> booking;

  const PaymentScreen({
    Key? key,
    required this.service,
    required this.workshop,
    required this.booking,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _billingChecked = false;
  bool _checkingBilling = true;

  @override
  void initState() {
    super.initState();
    _checkBillingData();
  }

  Future<void> _checkBillingData() async {
    try {
      final profileResult = await _apiService.getProfile(forceRefresh: true);
      if (!mounted) return;

      Map<String, dynamic>? profile;
      if (profileResult['success'] == true && profileResult['data'] != null) {
        profile = profileResult['data'] as Map<String, dynamic>;
      }

      final completed = await BillingDataSheet.showIfNeeded(context, profile);
      if (!mounted) return;

      if (completed) {
        setState(() {
          _billingChecked = true;
          _checkingBilling = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _billingChecked = true;
        _checkingBilling = false;
      });
    }
  }

  static bool _parseAcceptsInstallment(dynamic value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return defaultValue;
  }

  static int _parseMaxInstallments(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value.clamp(1, 24);
    final n = int.tryParse(value.toString());
    return n != null ? n.clamp(1, 24) : defaultValue;
  }

  double? _extractQuoteAmount(Map<String, dynamic> booking, Map<String, dynamic> service) {
    final candidateKeys = ['final_price', 'finalPrice', 'final_amount', 'finalAmount', 'approved_amount', 'approvedAmount', 'fin_price_cents'];
    for (final key in candidateKeys) {
      if (!booking.containsKey(key)) continue;
      final parsed = _parseBackendPrice(booking[key]);
      if (parsed != null && parsed > 0) return parsed;
    }
    final total = _parseBackendPrice(booking['total']);
    if (total != null && total > 0) return total;
    final servicePrice = PriceUtils.extractPrice(service['price']);
    if (servicePrice != null && servicePrice > 0) return servicePrice;
    return null;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final value = raw.toDouble();
      if (value == 0) return null;
      if (value % 1 == 0) return value / 100;
      return value;
    }
    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
      if (parsed == null || parsed == 0) return null;
      if (cleaned.contains('.') || cleaned.contains(',')) return parsed;
      if (parsed % 1 == 0) return parsed / 100;
      return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingBilling && !_billingChecked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pagamento'),
          backgroundColor: const Color(0xFF00C977),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF00C977))),
      );
    }

    final quoteAmount = _extractQuoteAmount(widget.booking, widget.service) ?? 0.0;
    final mecaFee = quoteAmount > 0 ? quoteAmount * AppConfig.mecaPlatformFee : 0.0;
    return MecaPaymentScreen(
      bookingData: widget.booking,
      totalAmount: quoteAmount,
      mecaFee: mecaFee,
      serviceAmount: quoteAmount,
      installments: 1,
      workshopAcceptsInstallment: _parseAcceptsInstallment(widget.workshop['accepts_installment'], defaultValue: true),
      workshopMaxInstallments: _parseMaxInstallments(widget.workshop['max_installments'], 12),
    );
  }
}
