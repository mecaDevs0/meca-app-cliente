import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/payment_service.dart';
import '../../services/notification_service.dart';
import '../../services/email_service.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String serviceName;
  final String workshopName;
  final double amount;

  const PaymentScreen({
    Key? key,
    required this.bookingId,
    required this.serviceName,
    required this.workshopName,
    required this.amount,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderNameController = TextEditingController();
  
  String _selectedPaymentMethod = PaymentService.paymentTypePix;
  bool _loading = false;
  bool _saveCard = false;
  String? _pixCode;
  String? _pixQrCode;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
        backgroundColor: const Color(0xFF00C977),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServiceInfo(),
              const SizedBox(height: 24),
              _buildPaymentMethodSelection(),
              const SizedBox(height: 24),
              if (_selectedPaymentMethod == PaymentService.paymentTypeCreditCard)
                _buildCreditCardForm(),
              if (_selectedPaymentMethod == PaymentService.paymentTypePix)
                _buildPixInfo(),
              const SizedBox(height: 24),
              _buildPaymentButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo do Pagamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Serviço:'),
                Text(
                  widget.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Oficina:'),
                Text(
                  widget.workshopName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'R\$ ${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C977),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forma de Pagamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildPaymentMethodOption(
          PaymentService.paymentTypePix,
          'PIX',
          'Pagamento instantâneo',
          Icons.qr_code,
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodOption(
          PaymentService.paymentTypeCreditCard,
          'Cartão de Crédito',
          'Visa, Mastercard, Elo',
          Icons.credit_card,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedPaymentMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF00C977) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFF00C977).withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00C977) : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF00C977) : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              onChanged: (val) {
                setState(() {
                  _selectedPaymentMethod = val!;
                });
              },
              activeColor: const Color(0xFF00C977),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dados do Cartão',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cardNumberController,
          decoration: const InputDecoration(
            labelText: 'Número do Cartão',
            hintText: '1234 5678 9012 3456',
            prefixIcon: Icon(Icons.credit_card),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            CardNumberInputFormatter(),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Número do cartão é obrigatório';
            }
            if (!PaymentService.validateCardData({'number': value})) {
              return 'Número do cartão inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                decoration: const InputDecoration(
                  labelText: 'Validade',
                  hintText: 'MM/AA',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  ExpiryDateInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Data de validade é obrigatória';
                  }
                  if (!PaymentService.validateCardData({'expiry': value})) {
                    return 'Data de validade inválida';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'CVV é obrigatório';
                  }
                  if (value.length < 3) {
                    return 'CVV deve ter pelo menos 3 dígitos';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _holderNameController,
          decoration: const InputDecoration(
            labelText: 'Nome no Cartão',
            hintText: 'João Silva',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Nome no cartão é obrigatório';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _saveCard,
          onChanged: (value) {
            setState(() {
              _saveCard = value ?? false;
            });
          },
          title: const Text('Salvar cartão para compras futuras'),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF00C977),
        ),
      ],
    );
  }

  Widget _buildPixInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C977).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C977).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.qr_code,
            size: 48,
            color: Color(0xFF00C977),
          ),
          const SizedBox(height: 16),
          const Text(
            'PIX - Pagamento Instantâneo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00C977),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escaneie o QR Code ou copie o código PIX para pagar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _selectedPaymentMethod == PaymentService.paymentTypePix
                    ? 'Gerar PIX'
                    : 'Pagar com Cartão',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      Map<String, dynamic>? cardData;
      if (_selectedPaymentMethod == PaymentService.paymentTypeCreditCard) {
        cardData = {
          'number': _cardNumberController.text,
          'expiry': _expiryController.text,
          'cvv': _cvvController.text,
          'holder_name': _holderNameController.text,
        };
      }

      final result = await PaymentService.processPayment(
        bookingId: widget.bookingId,
        paymentMethod: _selectedPaymentMethod,
        amount: widget.amount,
        cardData: cardData,
      );

      if (result['success']) {
        if (_selectedPaymentMethod == PaymentService.paymentTypePix) {
          setState(() {
            _pixCode = result['pixCode'];
            _pixQrCode = result['pixQrCode'];
          });
          _showPixDialog();
        } else {
          _showSuccessDialog();
        }
      } else {
        _showErrorDialog(result['error'] ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      _showErrorDialog('Erro inesperado: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showPixDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIX Gerado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pixQrCode != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: const Center(
                  child: Text('QR Code aqui'),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Código PIX:'),
            SelectableText(
              _pixCode ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Copie o código e cole no seu app de pagamento',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: _checkPaymentStatus,
            child: const Text('Verificar Pagamento'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagamento Aprovado!'),
        content: const Text('Seu pagamento foi processado com sucesso.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro no Pagamento'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPaymentStatus() async {
    // TODO: Implementar verificação de status do pagamento
    _showSuccessDialog();
  }
}

// Formatters para os campos do cartão
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final formatted = PaymentService.formatCardNumber(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final formatted = PaymentService.formatExpiryDate(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
