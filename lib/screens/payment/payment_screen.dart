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
  String? _billingError;

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
        _billingError = 'Não foi possível verificar seus dados. Toque para tentar novamente.';
        _checkingBilling = false;
      });
      debugPrint('[Payment] Billing check failed: $e');
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
    if (value is int) return value.clamp(1, 12);
    final n = int.tryParse(value.toString());
    return n != null ? n.clamp(1, 12) : defaultValue;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _extractQuoteAmount(Map<String, dynamic> booking, Map<String, dynamic> service) {
    // Prioridade 1: campo explícito em reais (API nova) — sem heurística
    for (final key in ['final_price_reais', 'finalPriceReais']) {
      final val = booking[key];
      if (val != null) {
        final d = val is num ? val.toDouble() : double.tryParse(val.toString());
        if (d != null && d > 0) return d;
      }
    }
    // Prioridade 2: campos legados (parsing com heurística centavos/reais)
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

  // Booking price fields (final_price, estimated_price) are stored in CENTAVOS.
  // Converts centavos to reais for display.
  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;
    final num value;
    if (raw is num) {
      value = raw;
    } else if (raw is String) {
      final cleaned = raw.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned);
      if (parsed == null) return null;
      value = parsed;
    } else {
      return null;
    }
    if (value == 0) return null;
    // Values >= 100 are treated as centavos (R$1.00 minimum)
    if (value >= 100) return value.toDouble() / 100;
    return value.toDouble();
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

    if (_billingError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pagamento'),
          backgroundColor: const Color(0xFF00C977),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 16),
                Text(
                  _billingError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _billingError = null;
                      _checkingBilling = true;
                    });
                    _checkBillingData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C977),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final quoteAmount = _extractQuoteAmount(widget.booking, widget.service) ?? 0.0;
    final workshopFeeRate = _parseDouble(widget.workshop['meca_fee_percentage']) ?? AppConfig.mecaPlatformFeeDefault;
    final effectiveFeeRate = workshopFeeRate > 1 ? workshopFeeRate / 100 : workshopFeeRate;
    final mecaFee = quoteAmount > 0 ? quoteAmount * effectiveFeeRate : 0.0;
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
