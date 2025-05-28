import 'package:flutter/material.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../data/enums/days_of_week.dart';
import '../../../../data/models/workshopAgenda/agenda_model.dart';
import '../../controllers/mechanic_workshop_details_controller.dart';

class ScheduleWorking extends GetView<MechanicWorkshopDetailsController> {
  const ScheduleWorking({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Horário de funcionamento',
          style: TextStyle(
            color: AppColors.darkCharcoal,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.20,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 5),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: DaysOfWeek.values.length,
            itemBuilder: (context, index) {
              final day = DaysOfWeek.values[index];
              final schedule =
                  _getScheduleForDay(day, controller.workshopSchedule);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.description,
                      style: const TextStyle(
                        color: AppColors.boldFontColor,
                      ),
                    ),
                    const Divider(
                      thickness: 1.0,
                      color: AppColors.boldFontColor,
                    ),
                    Text(
                      schedule,
                      style: const TextStyle(
                        color: AppColors.fontDarkGrayColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getScheduleForDay(DaysOfWeek day, AgendaModel? agenda) {
    if (agenda == null) {
      return 'Fechado';
    }

    final weekDayModel = switch (day) {
      DaysOfWeek.monday => agenda.monday,
      DaysOfWeek.tuesday => agenda.tuesday,
      DaysOfWeek.wednesday => agenda.wednesday,
      DaysOfWeek.thursday => agenda.thursday,
      DaysOfWeek.friday => agenda.friday,
      DaysOfWeek.saturday => agenda.saturday,
      DaysOfWeek.sunday => agenda.sunday,
    };

    if (!weekDayModel.open) {
      return 'Fechado';
    }

    return '${weekDayModel.startTime} - ${weekDayModel.closingTime}';
  }
}
