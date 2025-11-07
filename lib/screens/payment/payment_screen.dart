import 'package:flutter/material.dart';

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
    final serviceAmount = (service['price'] ?? 0.0).toDouble();
    final totalAmount = (booking['total'] ?? serviceAmount).toDouble();
    final mecaFee = totalAmount * 0.05; // Taxa de 5% do MECA
    
    return MecaPaymentScreen(
      bookingData: booking,
      totalAmount: totalAmount,
      mecaFee: mecaFee,
      serviceAmount: serviceAmount,
      installments: 1,
      workshopAcceptsInstallment: workshop['accepts_installment'] ?? false,
    );
  }
}










