import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/enums/schedule_status.dart';

class OrdersStatusFilter extends StatefulWidget {
  const OrdersStatusFilter({
    super.key,
    required this.onTap,
  });
  final Function(int) onTap;

  @override
  State<OrdersStatusFilter> createState() => _OrdersStatusFilterState();
}

class _OrdersStatusFilterState extends State<OrdersStatusFilter> {
  final statusController = TextEditingController();

  final List<ScheduleStatus> _statusOptions = ScheduleStatus.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: AppColors.blackPrimaryColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(
          height: 5.0,
        ),
        MegaDropDownWidget<ScheduleStatus>(
          controller: statusController,
          typeModal: MegaDropTypeModal.none,
          hintText: 'Selecione o status',
          suffixIcon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SvgPicture.asset(
              AppImages.icExpandSelect,
              width: 16,
              height: 16,
            ),
          ),
          listDropDownItem: _statusOptions
              .map(
                (status) => MegaItemWidget<ScheduleStatus>(
                  value: status,
                  itemLabel: status.name,
                ),
              )
              .toList(),
          onChanged: (status) {
            statusController.text = status.name;
            widget.onTap(_statusOptions.indexOf(status));
          },
          onClear: () {
            statusController.clear();
            widget.onTap(-1);
          },
        ),
      ],
    );
  }
}
