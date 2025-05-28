import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/args/order_args.dart';
import '../../../../core/widgets/app_car_desc.dart';
import '../../../../core/widgets/app_description_tile.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../data/enums/alert_status.dart';
import '../../../../data/enums/schedule_status.dart';
import '../../../../data/models/order.dart';
import '../../../../routes/app_pages.dart';
import 'status_alert.dart';

class ServiceInfo extends StatelessWidget {
  const ServiceInfo({
    super.key,
    required this.order,
  });

  final Order order;

  bool isOrderDateClose(
    int? orderDate, {
    Duration threshold = const Duration(hours: 1),
  }) {
    if (orderDate == null) {
      return false;
    }

    final DateTime now = DateTime.now();
    final Duration difference = orderDate.toDateTime().difference(now);

    return difference.abs() <= threshold;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.status == 20) ...[
          StatusAlert(
            status: AlertStatus.reproved,
            orderId: order.id,
          ),
        ],
        if (isOrderDateClose(order.date) && order.freeRepair == false) ...[
          const StatusAlert(status: AlertStatus.info),
        ] else if (order.status == 3) ...[
          StatusAlert(
            status: AlertStatus.withTime,
            date: order.date,
          ),
        ] else if (order.status == 8) ...[
          StatusAlert(
            status: AlertStatus.waitingApproveBudget,
            date: order.date,
          ),
        ] else if (order.status == 17) ...[
          const StatusAlert(
            status: AlertStatus.waitingCarParts,
          ),
        ],
        AppStatusChip(
          status: ScheduleStatus.values[order.status ?? 0],
        ),
        const SizedBox(height: 12),
        AppCarDesc(
          vehicle: order.vehicle!,
        ),
        AppDescriptionTile(
          title: 'Data da ultima atualização',
          description: order.lastUpdate?.toddMMyyyyHHmm() ?? 'Sem data',
        ),
        Visibility(
          visible: order.paymentDate != null,
          child: AppDescriptionTile(
            title: 'Data do pagamento',
            description: order.paymentDate?.toddMMyyyyHHmm() ?? 'Sem data',
          ),
        ),
        Visibility(
          visible: order.suggestedDate != null &&
              (order.status == 1 || order.status == 2),
          child: AppDescriptionTile(
            title: 'Novo horário sugerido pela oficina',
            description: order.suggestedDate?.toddMMyyyyHHmm() ?? 'Sem data',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Serviços solicitados',
          style: TextStyle(
            color: AppColors.abbey,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (order.workshopServices?.isNotEmpty == true) ...[
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order.workshopServices!
                  .map(
                    (service) => AppStatusChip(
                      label: service.service?.name,
                    ),
                  )
                  .toList(),
            ),
          ),
        ] else
          const Text(
            'Sem serviços encontrados',
            style: TextStyle(color: AppColors.blackPrimaryColor),
          ),
        Visibility(
          visible: order.diagnosticValue != null,
          child: AppDescriptionTile(
            title: 'Valor do diagnóstico',
            description: order.diagnosticValue?.moneyFormat() ?? r'R$ 0,00',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 1,
                color: AppColors.grayLineColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Observações',
                style: TextStyle(
                  color: AppColors.abbey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.observations ?? '',
                style: const TextStyle(
                  color: AppColors.gray500,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Visibility(
          visible: order.status! > 6,
          child: Center(
            child: TextButton(
              onPressed: () {
                Get.toNamed(Routes.budgetDetails);
              },
              child: const Text(
                'ver detalhes do orçamento',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        if ((order.status == 12) || (order.status == 14)) ...[
          Center(
            child: TextButton(
              onPressed: () {
                if (!order.id.isNullOrEmpty) {
                  Get.toNamed(
                    Routes.payment,
                    arguments: OrderArgs(order.id!),
                  );
                }
              },
              child: const Text(
                'Realizar pagamento',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }
}
