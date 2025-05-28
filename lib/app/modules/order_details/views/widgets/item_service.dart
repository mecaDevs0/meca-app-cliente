import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/widgets/app_dashed_line_painter.dart';
import '../../../../data/enums/status_title.dart';
import '../../../../data/models/order_history.dart';

class ItemService extends StatelessWidget {
  const ItemService({super.key, required this.order});

  final OrderHistory order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                padding: const EdgeInsets.all(2),
                decoration: ShapeDecoration(
                  color: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const ShapeDecoration(
                    color: AppColors.primaryColor,
                    shape: OvalBorder(
                      side: BorderSide(
                        width: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CustomPaint(
                  painter: AppDashedLinePainter(
                    color: AppColors.primaryColor,
                    thickness: 1,
                    dashSpace: 2,
                    dashWidth: 2,
                    isVertical: true,
                  ),
                  child: const SizedBox(
                    width: 1,
                    height: 84,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            child: CustomPaint(
              painter: AppDashedLinePainter(
                color: AppColors.primaryColor,
                dashSpace: 2,
                dashWidth: 2,
                thickness: 1,
              ),
              child: const SizedBox(
                height: 1,
                width: 10,
              ),
            ),
          ),
          OrderHistoryCard(order: order),
        ],
      ),
    );
  }
}

class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({
    super.key,
    required this.order,
  });

  final OrderHistory order;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: AppColors.grayBorderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 4,
              offset: Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.created?.toddMMyyyyasHHmm() ?? '',
              style: const TextStyle(
                color: AppColors.boulder,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.75,
              ),
            ),
            const Divider(),
            Text(
              StatusTitle.values[order.statusTitle ?? 0].name,
              style: const TextStyle(
                color: AppColors.abbey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.description ?? '',
              style: const TextStyle(
                color: AppColors.abbey,
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
