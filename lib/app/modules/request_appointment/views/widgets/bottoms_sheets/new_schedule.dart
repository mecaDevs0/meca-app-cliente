import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/app_images.dart';

class NewScheduleBottomsheet extends StatefulWidget {
  const NewScheduleBottomsheet({
    super.key,
    required this.onTap,
  });
  final void Function() onTap;

  @override
  State<NewScheduleBottomsheet> createState() => _NewScheduleBottomSheetState();
}

class _NewScheduleBottomSheetState extends State<NewScheduleBottomsheet> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController expiryDateController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _applyFilters() {
    widget.onTap();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Align(
            alignment: Alignment.topRight,
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
                SvgPicture.asset(AppImages.newSchedule),
                const Text(
                  'O horário indisponível',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Não foi possivel confirmar o agendamento de troca de óleo na data 30/10/2024 horário 11:00, mas a oficina sugeriu um novo horário',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.grayBorderColor,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(AppImages.clockHour),
                      const SizedBox(
                        width: 10,
                      ),
                      const Text(
                        '14:00 - 30/10/2024',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Aceitar horário sugerido',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.whiteColor,
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Escolher outro horário',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.primaryColor,
                    buttonColor: AppColors.whiteColor,
                    border:
                        Border.all(color: AppColors.primaryColor, width: 1.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showNewScheduleBottomSheet({
  required BuildContext context,
  required void Function() onTap,
}) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (context) {
      return Wrap(
        children: [
          NewScheduleBottomsheet(onTap: onTap),
        ],
      );
    },
  );
}
