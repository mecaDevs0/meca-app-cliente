import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/enums/schedule_status.dart';
import '../../../../data/models/order.dart';
import 'order_status_row.dart';
import 'order_workshop_row.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        border: Border.all(
          color: AppColors.grayBorderColor,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusRow(
            id: order.id!,
            status: ScheduleStatus.values[order.status!],
          ),
          const SizedBox(height: 12),
          const Divider(
            color: AppColors.grayBorderColor,
            thickness: 1.0,
          ),
          const SizedBox(height: 12),
          OrderWorkshopRow(
            workshopName: order.workshop?.companyName ?? order.workshop?.fullName ?? 'Estabelecimento não informado',
            carBrand: order.vehicle?.manufacturer ?? '',
            vehiclePlate: order.vehicle?.plate ?? '',
            date: order.date != null ? order.date!.toddMMyyyy() : '',
            workshopImage: order.workshop?.photo,
            workshopAddress: _formatAddress(),
          ),
          const SizedBox(height: 12),
        ],
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
    
    return parts.isEmpty ? 'Endereço não informado' : parts.join(', ');
  }
}
