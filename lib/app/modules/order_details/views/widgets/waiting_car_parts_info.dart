import 'package:flutter/material.dart';

import '../../../../data/enums/alert_status.dart';

class WaitingCarPartsInfo extends StatelessWidget {
  const WaitingCarPartsInfo({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aguardando peças',
      style: TextStyle(
        color: status.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
