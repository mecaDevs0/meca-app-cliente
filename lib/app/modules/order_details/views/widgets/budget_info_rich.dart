import 'package:flutter/material.dart';

import '../../../../data/enums/alert_status.dart';

class BudgetInfoRich extends StatelessWidget {
  const BudgetInfoRich({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aprove o orçamento para prosseguir',
      style: TextStyle(
        color: status.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
