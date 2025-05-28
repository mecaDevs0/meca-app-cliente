import 'package:flutter/material.dart';

import '../../../../data/enums/alert_status.dart';

class InfoRich extends StatelessWidget {
  const InfoRich({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aguardando confirmar chegada do veículo',
      style: TextStyle(
        color: status.color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
