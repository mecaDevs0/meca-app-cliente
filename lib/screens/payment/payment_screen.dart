import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../utils/price_utils.dart';
import 'meca_payment_screen.dart';

class PaymentScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Converter para o formato esperado pelo MecaPaymentScreen
    // Só usar valores válidos (maiores que 0)
    final quoteAmount = _extractQuoteAmount(booking, service) ?? 0.0;
    final mecaFee = quoteAmount > 0 ? quoteAmount * AppConfig.mecaPlatformFee : 0.0;
    
    return MecaPaymentScreen(
      bookingData: booking,
      totalAmount: quoteAmount,
      mecaFee: mecaFee,
      serviceAmount: quoteAmount,
      installments: 1,
      workshopAcceptsInstallment: workshop['accepts_installment'] ?? false,
    );
  }

  double? _extractQuoteAmount(Map<String, dynamic> booking, Map<String, dynamic> service) {
    final candidateKeys = [
      'final_price',
      'finalPrice',
      'final_amount',
      'finalAmount',
      'approved_amount',
      'approvedAmount',
      'final_price_cents',
    ];

    for (final key in candidateKeys) {
      if (!booking.containsKey(key)) continue;
      final parsed = _parseBackendPrice(booking[key]);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    final total = _parseBackendPrice(booking['total']);
    if (total != null && total > 0) {
      return total;
    }

    final servicePrice = PriceUtils.extractPrice(service['price']);
    if (servicePrice != null && servicePrice > 0) {
      return servicePrice;
    }

    return null;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final value = raw.toDouble();
      if (value == 0) return null;
      if (value.abs() >= 100 && value % 1 == 0) {
        return value / 100;
      }
      return value;
    }

    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
      if (parsed == null || parsed == 0) return null;
      if (cleaned.contains('.') || cleaned.contains(',')) {
        return parsed;
      }
      if (parsed.abs() >= 100 && parsed % 1 == 0) {
        return parsed / 100;
      }
      return parsed;
    }

    return null;
  }
}
















