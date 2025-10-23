import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentService {
  static const String _apiUrl = 'http://ec2-3-144-213-137.us-east-2.compute.amazonaws.com:9000';
  
  // Configurações PagBank (sandbox para testes)
  static const String _pagbankApiUrl = 'https://api.pagseguro.com';
  static const String _pagbankToken = 'SEU_TOKEN_PAGBANK'; // TODO: Configurar token real
  
  // Tipos de pagamento
  static const String paymentTypePix = 'pix';
  static const String paymentTypeCreditCard = 'credit_card';
  static const String paymentTypeDebitCard = 'debit_card';

  // Processar pagamento
  static Future<Map<String, dynamic>> processPayment({
    required String bookingId,
    required String paymentMethod,
    required double amount,
    Map<String, dynamic>? cardData,
    Map<String, dynamic>? customerData,
  }) async {
    try {
      if (paymentMethod == paymentTypePix) {
        return await _processPixPayment(bookingId, amount, customerData);
      } else if (paymentMethod == paymentTypeCreditCard) {
        return await _processCreditCardPayment(bookingId, amount, cardData, customerData);
      } else {
        return {
          'success': false,
          'error': 'Método de pagamento não suportado',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao processar pagamento: $e',
      };
    }
  }

  // Processar pagamento PIX
  static Future<Map<String, dynamic>> _processPixPayment(
    String bookingId,
    double amount,
    Map<String, dynamic>? customerData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/payments/process'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bookingId': bookingId,
          'paymentMethod': paymentTypePix,
          'amount': amount,
          'customerData': customerData,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'paymentId': data['payment_id'],
          'pixCode': data['pix_code'],
          'pixQrCode': data['pix_qr_code'],
        };
      } else {
        return {
          'success': false,
          'error': 'Erro ao processar pagamento PIX',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro de conexão: $e',
      };
    }
  }

  // Processar pagamento com cartão de crédito
  static Future<Map<String, dynamic>> _processCreditCardPayment(
    String bookingId,
    double amount,
    Map<String, dynamic>? cardData,
    Map<String, dynamic>? customerData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/payments/process'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bookingId': bookingId,
          'paymentMethod': paymentTypeCreditCard,
          'amount': amount,
          'cardData': cardData,
          'customerData': customerData,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'paymentId': data['payment_id'],
          'status': data['status'],
        };
      } else {
        return {
          'success': false,
          'error': 'Erro ao processar pagamento com cartão',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro de conexão: $e',
      };
    }
  }

  // Verificar status do pagamento
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/payments/status/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'status': data['status'],
        };
      } else {
        return {
          'success': false,
          'error': 'Erro ao verificar status do pagamento',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro de conexão: $e',
      };
    }
  }

  // Cancelar pagamento
  static Future<Map<String, dynamic>> cancelPayment(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/payments/cancel/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Erro ao cancelar pagamento',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro de conexão: $e',
      };
    }
  }

  // Obter métodos de pagamento disponíveis
  static Future<Map<String, dynamic>> getAvailablePaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/payments/methods'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Erro ao obter métodos de pagamento',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro de conexão: $e',
      };
    }
  }

  // Validar dados do cartão
  static bool validateCardData(Map<String, dynamic> cardData) {
    final cardNumber = cardData['number']?.toString() ?? '';
    final expiryDate = cardData['expiry']?.toString() ?? '';
    final cvv = cardData['cvv']?.toString() ?? '';
    final holderName = cardData['holder_name']?.toString() ?? '';

    // Validar número do cartão (Luhn algorithm)
    if (!_validateCardNumber(cardNumber)) return false;
    
    // Validar data de expiração
    if (!_validateExpiryDate(expiryDate)) return false;
    
    // Validar CVV
    if (cvv.length < 3 || cvv.length > 4) return false;
    
    // Validar nome do portador
    if (holderName.trim().isEmpty) return false;

    return true;
  }

  // Validar número do cartão usando algoritmo de Luhn
  static bool _validateCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.length < 13 || cleanNumber.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return sum % 10 == 0;
  }

  // Validar data de expiração
  static bool _validateExpiryDate(String expiryDate) {
    final parts = expiryDate.split('/');
    if (parts.length != 2) return false;
    
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    
    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    
    return true;
  }

  // Obter bandeira do cartão
  static String getCardBrand(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    
    if (cleanNumber.startsWith('4')) return 'Visa';
    if (cleanNumber.startsWith('5') || cleanNumber.startsWith('2')) return 'Mastercard';
    if (cleanNumber.startsWith('3')) return 'American Express';
    if (cleanNumber.startsWith('6')) return 'Discover';
    
    return 'Desconhecida';
  }

  // Formatar número do cartão
  static String formatCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    final formatted = cleanNumber.replaceAllMapped(
      RegExp(r'(\d{4})(?=\d)'),
      (match) => '${match.group(1)} ',
    );
    return formatted.trim();
  }

  // Formatar data de expiração
  static String formatExpiryDate(String expiryDate) {
    final cleanDate = expiryDate.replaceAll(RegExp(r'\D'), '');
    if (cleanDate.length >= 4) {
      return '${cleanDate.substring(0, 2)}/${cleanDate.substring(2, 4)}';
    }
    return expiryDate;
  }
}
