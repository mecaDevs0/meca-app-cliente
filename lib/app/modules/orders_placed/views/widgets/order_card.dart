import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/utils/workshop_name_helper.dart';
import '../../../../data/models/order.dart';
import '../../../../routes/app_pages.dart';
import 'order_workshop_row.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  Widget build(BuildContext context) {
    // Debug logs
    print('🔧 [OrderCard] Workshop ID: ${order.workshop?.id}');
    print('🔧 [OrderCard] Workshop Photo: ${order.workshop?.photo}');
    print('🔧 [OrderCard] Workshop CompanyName: ${order.workshop?.companyName}');
    print('🔧 [OrderCard] Workshop FullName: ${order.workshop?.fullName}');
    print('🔧 [OrderCard] Workshop DisplayName: ${WorkshopNameHelper.getDisplayName(order.workshop)}');
    print('🔧 [OrderCard] Workshop AccountableName: ${order.workshop?.accountableName}');
    
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          Routes.orderDetails,
          arguments: order.id,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações do estabelecimento
            OrderWorkshopRow(
              order: order,
              workshopName: WorkshopNameHelper.getDisplayName(order.workshop),
              carBrand: '${order.vehicle?.manufacturer ?? ''} ${order.vehicle?.model ?? ''}',
              vehiclePlate: order.vehicle?.plate ?? '',
              date: order.date?.toddMMyyyy() ?? '',
              workshopAddress: _formatAddress(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatAddress() {
    final workshop = order.workshop;
    if (workshop == null) return 'Endereço não informado';
    
    final parts = <String>[];
    if (workshop.streetAddress?.isNotEmpty == true) parts.add(workshop.streetAddress!);
    if (workshop.number?.isNotEmpty == true) parts.add('n${workshop.number}');
    if (workshop.neighborhood?.isNotEmpty == true) parts.add(workshop.neighborhood!);
    if (workshop.cityName?.isNotEmpty == true) parts.add(workshop.cityName!);
    if (workshop.stateUf?.isNotEmpty == true) parts.add(workshop.stateUf!);
    
    // Se não temos endereço completo, tentar usar apenas cidade e estado
    if (parts.isEmpty) {
      if (workshop.cityName?.isNotEmpty == true) parts.add(workshop.cityName!);
      if (workshop.stateUf?.isNotEmpty == true) parts.add(workshop.stateUf!);
    }
    
    return parts.isEmpty ? 'Endereço não informado' : parts.join(', ');
  }
}
