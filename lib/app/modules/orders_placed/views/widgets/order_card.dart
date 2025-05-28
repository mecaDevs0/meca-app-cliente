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
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.purpleCardBorderColor,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          OrderStatusRow(
            id: order.id!,
            status: ScheduleStatus.values[order.status!],
          ),
          const SizedBox(
            height: 5,
          ),
          const Divider(
            color: AppColors.grayBorderColor,
            thickness: 1.0,
          ),
          const SizedBox(
            height: 5,
          ),
          OrderWorkshopRow(
            workshopName: order.workshop?.companyName ?? '',
            carBrand: order.vehicle?.manufacturer ?? '',
            vehiclePlate: order.vehicle?.plate ?? '',
            date: order.date != null ? order.date!.toddMMyyyy() : '',
            workshopImage: order.workshop?.photo,
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            spacing: 8,
            children: [
              SvgPicture.asset(
                AppImages.icLocation,
              ),
              Flexible(
                child: Text(
                  '${order.workshop?.streetAddress ?? ''}, n${order.workshop?.number ?? ''}, ${order.workshop?.neighborhood ?? ''}',
                  style: const TextStyle(
                    color: AppColors.fontMediumGray,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
