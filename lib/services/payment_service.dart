import 'package:flutter/material.dart';

class PaymentService {
  static const String _pagBankPublicKey = 'pk_test_123456789'; // Chave pública do PagBank
  static const double _mecaFee = 0.05; // 5% de taxa MECA

  /// Processa pagamento com PagBank
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String paymentMethod,
    required int installments,
    required String customerId,
    required String workshopId,
    required String serviceId,
  }) async {
    try {
      // Calcular taxa MECA
      final mecaFeeAmount = amount * _mecaFee;
      final workshopAmount = amount - mecaFeeAmount;

      // Simular processamento do PagBank
      await Future.delayed(const Duration(seconds: 2));

      // Em produção, integrar com API real do PagBank
      return {
        'success': true,
        'payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'meca_fee': mecaFeeAmount,
        'workshop_amount': workshopAmount,
        'installments': installments,
        'status': 'approved',
        'message': 'Pagamento aprovado com sucesso',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao processar pagamento: $e',
      };
    }
  }

  /// Calcula valores de parcelamento
  static Map<String, dynamic> calculateInstallments({
    required double amount,
    required int maxInstallments,
  }) {
    final installments = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= maxInstallments; i++) {
      final installmentAmount = amount / i;
      final mecaFee = installmentAmount * _mecaFee;
      final workshopAmount = installmentAmount - mecaFee;
      
      installments.add({
        'installments': i,
        'amount': installmentAmount,
        'meca_fee': mecaFee,
        'workshop_amount': workshopAmount,
        'total_amount': amount,
      });
    }

    return {
      'installments': installments,
      'meca_fee_percentage': _mecaFee * 100,
    };
  }

  /// Valida dados de pagamento
  static bool validatePaymentData({
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardholderName,
  }) {
    // Validações básicas
    if (cardNumber.length < 13 || cardNumber.length > 19) return false;
    if (expiryDate.length != 5) return false;
    if (cvv.length < 3 || cvv.length > 4) return false;
    if (cardholderName.trim().isEmpty) return false;

    return true;
  }

  /// Formata número do cartão
  static String formatCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    final formatted = <String>[];
    
    for (int i = 0; i < cleaned.length; i += 4) {
      final end = (i + 4 < cleaned.length) ? i + 4 : cleaned.length;
      formatted.add(cleaned.substring(i, end));
    }
    
    return formatted.join(' ');
  }

  /// Formata data de expiração
  static String formatExpiryDate(String expiryDate) {
    final cleaned = expiryDate.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length >= 2) {
      return '${cleaned.substring(0, 2)}/${cleaned.substring(2)}';
    }
    return cleaned;
  }

  /// Obtém bandeira do cartão
  static String getCardBrand(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.startsWith('4')) return 'Visa';
    if (cleaned.startsWith('5') || cleaned.startsWith('2')) return 'Mastercard';
    if (cleaned.startsWith('3')) return 'American Express';
    if (cleaned.startsWith('6')) return 'Discover';
    
    return 'Desconhecida';
  }

  /// Calcula taxa MECA
  static double calculateMecaFee(double amount) {
    return amount * _mecaFee;
  }

  /// Obtém valor líquido para oficina
  static double getWorkshopAmount(double amount) {
    return amount - calculateMecaFee(amount);
  }
}