import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/core.dart';
import '../../../../core/widgets/body_modal_timer.dart';

class FreeRepairBottomsheet extends StatefulWidget {
  const FreeRepairBottomsheet({
    super.key,
    required this.onTap,
  });

  final void Function(int) onTap;

  @override
  State<FreeRepairBottomsheet> createState() => _FreeRepairBottomSheetState();
}

class _FreeRepairBottomSheetState extends State<FreeRepairBottomsheet> {
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  String get _validTime {
    final time = timeController.text;
    return time.isNullOrEmpty ? '00:00' : time;
  }

  int _makeDateTime(String date, String time) {
    final dateTime = '$date $time:00'.toDateTime;
    return dateTime.millisecondsSinceEpoch ~/ 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Agendamento de reparo gratuito',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolha uma nova data e um novo horário para o reparo gratuito',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Data',
                  controller: dateController,
                  hintText: 'Selecione a data da última revisão',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(2),
                    child: SvgPicture.asset(
                      AppImages.icCalendar,
                      width: 16,
                      height: 16,
                    ),
                  ),
                  isRequired: true,
                  onTap: () {
                    showMegaDatePicker(
                      context,
                      minimumDate: DateTime.now(),
                      maximumDate:
                          DateTime.now().add(const Duration(days: 365)),
                      onSelectDate: (date) {
                        dateController.text = date.toddMMyyyy();
                      },
                      onCancelClick: () {
                        dateController.clear();
                      },
                    );
                  },
                ).unite,
                const SizedBox(height: 16),
                AppTextField(
                  controller: timeController,
                  label: 'Horário',
                  hintText: 'Selecione o horário',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(2),
                    child: SvgPicture.asset(
                      AppImages.clockHour,
                      width: 16,
                      height: 16,
                    ),
                  ),
                  isRequired: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Material(
                        color: Colors.transparent,
                        child: BodyModalTimer(
                          value: _validTime,
                          onChanged: (value) {
                            timeController.text = value;
                          },
                        ),
                      ),
                    );
                  },
                ).unite,
                const SizedBox(
                  height: 24,
                ),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Agendar reparo gratuito',
                    onButtonPress: () {
                      final dateTime = _makeDateTime(
                        dateController.text,
                        timeController.text,
                      );
                      widget.onTap(dateTime);
                      Navigator.pop(context);
                    },
                    textColor: AppColors.whiteColor,
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showFreeRepairBottomSheet({
  required BuildContext context,
  required void Function(int) onTap,
}) {
  showModalBottomSheet(
    backgroundColor: AppColors.whiteColor,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(44),
      ),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.58,
      child: FreeRepairBottomsheet(
        onTap: onTap,
      ),
    ),
  );
}
