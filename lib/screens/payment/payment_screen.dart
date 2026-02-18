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

  @override
  Widget build(BuildContext context) {
    final quoteAmount = _extractQuoteAmount(booking, service) ?? 0.0;
    final mecaFee = quoteAmount > 0 ? quoteAmount * AppConfig.mecaPlatformFee : 0.0;
    return MecaPaymentScreen(
      bookingData: booking,
      totalAmount: quoteAmount,
      mecaFee: mecaFee,
      serviceAmount: quoteAmount,
      installments: 1,
      workshopAcceptsInstallment: _parseAcceptsInstallment(workshop['accepts_installment'], defaultValue: true),
      workshopMaxInstallments: _parseMaxInstallments(workshop['max_installments'], 12),
    );
  }

  double? _extractQuoteAmount(Map<String, dynamic> booking, Map<String, dynamic> service) {
    print('💰 [PaymentScreen] Extraindo valor do booking: ${booking.keys.join(", ")}');
    
    final candidateKeys = [
      'final_price',
      'finalPrice',
      'final_amount',
      'finalAmount',
      'approved_amount',
      'approvedAmount',
      'fin_price_cents',
    ];

    for (final key in candidateKeys) {
      if (!booking.containsKey(key)) continue;
      final rawValue = booking[key];
      print('💰 [PaymentScreen] Tentando key=$key, raw=$rawValue, type=${rawValue.runtimeType}');
      final parsed = _parseBackendPrice(rawValue);
      if (parsed != null && parsed > 0) {
        print('✅ [PaymentScreen] Valor extraído de "$key": R\$ $parsed');
        return parsed;
      }
    }

    final total = _parseBackendPrice(booking['total']);
    if (total != null && total > 0) {
      print('✅ [PaymentScreen] Valor extraído de "total": R\$ $total');
      return total;
    }

    final servicePrice = PriceUtils.extractPrice(service['price']);
    if (servicePrice != null && servicePrice > 0) {
      print('✅ [PaymentScreen] Valor extraído de service price: R\$ $servicePrice');
      return servicePrice;
    }

    print('⚠️ [PaymentScreen] Nenhum valor válido found');
    return null;
  }

  double? _parseBackendPrice(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      final value = raw.toDouble();
      print('💰 [PaymentScreen] parseBackendPrice: num value=$value');
      if (value == 0) return null;
      // CRITICAL: no MECA o backend usa CENTAVOS (int) para preços (mesmo < 100).
      // Se vier "inteiro", tratar como centavos sempre.
      if (value % 1 == 0) {
        final converted = value / 100;
        print('💰 [PaymentScreen] parseBackendPrice: convertendo $value centavos -> R\$ $converted');
        return converted;
      }
      // Se veio com decimal, já é reais.
      print('💰 [PaymentScreen] parseBackendPrice: usando valor direto (reais) R\$ $value');
      return value;
    }

    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return null;
      final parsed = double.tryParse(cleaned.replaceAll(',', '.'));
      if (parsed == null || parsed == 0) return null;
      print('💰 [PaymentScreen] parseBackendPrice: string parsed=$parsed, hasDecimal=${cleaned.contains('.') ||cleaned.contains(',')}');
      
      // Se já tem ponto/vírgula, é valor em reais
      if (cleaned.contains('.') || cleaned.contains(',')) {
        print('💰 [PaymentScreen] parseBackendPrice: string com decimal, R\$ $parsed');
        return parsed;
      }
      // String inteira => centavos
      if (parsed % 1 == 0) {
        final converted = parsed / 100;
        print('💰 [PaymentScreen] parseBackendPrice: string convertendo $parsed centavos -> R\$ $converted');
        return converted;
      }
      print('💰 [PaymentScreen] parseBackendPrice: string usando valor direto (reais) R\$ $parsed');
      return parsed;
    }

    return null;
  }
}
















