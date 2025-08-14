import 'package:flutter/material.dart';

class MechanicWorkshopHoursRow extends StatelessWidget {
  final String? openTime;
  final String? closeTime;
  final bool isOpen;

  const MechanicWorkshopHoursRow({
    super.key,
    this.openTime,
    this.closeTime,
    this.isOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      _getHoursText(),
      style: TextStyle(
        fontSize: 12,
        color: isOpen ? Colors.green : Colors.grey,
        fontWeight: isOpen ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  String _getHoursText() {
    if (openTime == null || openTime!.isEmpty) {
      return 'Horário não informado';
    }
    return openTime!;
  }
}
