import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../app_colors.dart';

class BodyModalTimer extends StatelessWidget {
  const BodyModalTimer({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    String time = value.isNullOrEmpty ? '00:00' : value!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Escolha o horário',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  width: 300,
                  child: CupertinoDatePicker(
                    use24hFormat: true,
                    initialDateTime: value.isNullOrEmpty
                        ? DateTime.now()
                        : DateTime.parse('2021-01-01T$value'),
                    mode: CupertinoDatePickerMode.time,
                    minuteInterval: 10,
                    onDateTimeChanged: (value) {
                      time = value.toHHmm();
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: MegaBaseButton(
                        'Cancelar',
                        onButtonPress: () {
                          Navigator.pop(context);
                        },
                        borderRadius: 4,
                        buttonColor: Colors.transparent,
                        border: Border.all(
                          color: AppColors.abbey,
                          width: 1,
                        ),
                        textStyle: const TextStyle(
                          color: AppColors.abbey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MegaBaseButton(
                        'Confirmar',
                        onButtonPress: () {
                          onChanged(time);
                          Navigator.pop(context);
                        },
                        borderRadius: 4,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
