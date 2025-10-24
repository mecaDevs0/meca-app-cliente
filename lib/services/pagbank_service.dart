import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PagBankService {
  static const String _baseUrl = 'https://api.pagseguro.com';
  static const String _publicKey = 'pk_test_123456789'; // Chave pública do PagBank
  static const double _mecaFeePercentage = 0.05; // 5% de taxa MECA

  /// Cria uma sessão de pagamento
  static Future<Map<String, dynamic>> createPaymentSession({
    required double amount,
    required int installments,
    required String customerId,
    required String workshopId,
    required String serviceId,
  }) async {
    try {
      // Calcular taxa MECA
      final mecaFee = amount * _mecaFeePercentage;
      final workshopAmount = amount - mecaFee;

      // Simular criação de sessão PagBank
      await Future.delayed(const Duration(seconds: 1));

      return {
        'success': true,
        'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'installments': installments,
        'meca_fee': mecaFee,
        'workshop_amount': workshopAmount,
        'public_key': _publicKey,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao criar sessão de pagamento: $e',
      };
    }
  }

  /// Processa pagamento com cartão de crédito
  static Future<Map<String, dynamic>> processCreditCardPayment({
    required String sessionId,
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardholderName,
    required String customerId,
    required double amount,
    required int installments,
  }) async {
    try {
      // Validar dados do cartão
      if (!_validateCardData(cardNumber, expiryDate, cvv, cardholderName)) {
        return {
          'success': false,
          'error': 'Dados do cartão inválidos',
        };
      }

      // Simular processamento do PagBank
      await Future.delayed(const Duration(seconds: 2));

      // Calcular valores
      final mecaFee = amount * _mecaFeePercentage;
      final workshopAmount = amount - mecaFee;

      return {
        'success': true,
        'payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'installments': installments,
        'meca_fee': mecaFee,
        'workshop_amount': workshopAmount,
        'status': 'approved',
        'transaction_id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
        'message': 'Pagamento aprovado com sucesso',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao processar pagamento: $e',
      };
    }
  }

  /// Processa pagamento PIX
  static Future<Map<String, dynamic>> processPixPayment({
    required String sessionId,
    required String customerId,
    required double amount,
  }) async {
    try {
      // Simular processamento PIX
      await Future.delayed(const Duration(seconds: 1));

      // Calcular valores
      final mecaFee = amount * _mecaFeePercentage;
      final workshopAmount = amount - mecaFee;

      return {
        'success': true,
        'payment_id': 'pix_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'meca_fee': mecaFee,
        'workshop_amount': workshopAmount,
        'status': 'pending',
        'pix_code': '00020126360014BR.GOV.BCB.PIX0114+5511999999999520400005303986540${amount.toStringAsFixed(2)}5802BR5913MECA OFICINA6009SAO PAULO62070503***6304',
        'qr_code': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        'expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        'message': 'PIX gerado com sucesso',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao gerar PIX: $e',
      };
    }
  }

  /// Verifica status do pagamento
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      // Simular verificação de status
      await Future.delayed(const Duration(seconds: 1));

      return {
        'success': true,
        'status': 'approved',
        'message': 'Pagamento aprovado',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao verificar status: $e',
      };
    }
  }

  /// Calcula opções de parcelamento
  static List<Map<String, dynamic>> calculateInstallmentOptions({
    required double amount,
    required int maxInstallments,
  }) {
    final options = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= maxInstallments; i++) {
      final installmentAmount = amount / i;
      final mecaFee = installmentAmount * _mecaFeePercentage;
      final workshopAmount = installmentAmount - mecaFee;
      
      options.add({
        'installments': i,
        'amount': installmentAmount,
        'meca_fee': mecaFee,
        'workshop_amount': workshopAmount,
        'total_amount': amount,
        'interest_rate': i > 1 ? _calculateInterestRate(i) : 0.0,
      });
    }

    return options;
  }

  /// Valida dados do cartão
  static bool _validateCardData(String cardNumber, String expiryDate, String cvv, String cardholderName) {
    // Validações básicas
    if (cardNumber.replaceAll(' ', '').length < 13) return false;
    if (expiryDate.length != 5) return false;
    if (cvv.length < 3) return false;
    if (cardholderName.trim().isEmpty) return false;

    return true;
  }

  /// Calcula taxa de juros baseada no número de parcelas
  static double _calculateInterestRate(int installments) {
    if (installments <= 1) return 0.0;
    if (installments <= 3) return 0.02; // 2%
    if (installments <= 6) return 0.05; // 5%
    if (installments <= 12) return 0.08; // 8%
    return 0.12; // 12%
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

  /// Calcula taxa MECA
  static double calculateMecaFee(double amount) {
    return amount * _mecaFeePercentage;
  }

  /// Obtém valor líquido para oficina
  static double getWorkshopAmount(double amount) {
    return amount - calculateMecaFee(amount);
  }

  /// Obtém informações sobre taxas
  static Map<String, dynamic> getFeeInfo(double amount) {
    final mecaFee = calculateMecaFee(amount);
    final workshopAmount = getWorkshopAmount(amount);
    
    return {
      'total_amount': amount,
      'meca_fee': mecaFee,
      'workshop_amount': workshopAmount,
      'meca_fee_percentage': _mecaFeePercentage * 100,
    };
  }
}

