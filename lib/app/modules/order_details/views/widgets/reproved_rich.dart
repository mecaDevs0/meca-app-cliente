import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/core.dart';
import '../../../../data/enums/alert_status.dart';
import '../../../../routes/app_pages.dart';

class ReprovedRich extends StatelessWidget {
  const ReprovedRich({
    super.key,
    required this.status,
    required this.orderId,
  });

  final AlertStatus status;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Serviço reprovado ',
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: 'Veja os motivos',
            style: const TextStyle(
              color: AppColors.abbey,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed(
                    Routes.serviceFailed,
                    arguments: OrderArgs(orderId),
                  ),
          ),
        ],
      ),
    );
  }
}
