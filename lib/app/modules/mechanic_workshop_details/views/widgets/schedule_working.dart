import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../data/enums/days_of_week.dart';
import '../../../../data/models/workshopAgenda/agenda_model.dart';
import '../../controllers/mechanic_workshop_details_controller.dart';

class ScheduleWorking extends GetView<MechanicWorkshopDetailsController> {
  const ScheduleWorking({
    super.key,
    this.isTablet = false, // Novo parâmetro para modo tablet
  });

  final bool isTablet; // Controla o tamanho dos elementos em tablets

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
        const SizedBox(height: 20),
        Obx(() {
          if (controller.isLoadingWorkshopSchedule) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
                strokeWidth: 2,
              ),
            );
          }

          if (controller.workshopSchedule == null) {
            dev.log('Workshop schedule is null', name: 'ScheduleWorking');
            return const Text(
              'Informações de horário não disponíveis',
              style: TextStyle(
                color: AppColors.fontDarkGrayColor,
                fontStyle: FontStyle.italic,
              ),
            );
          }

          dev.log('Dados de agenda disponíveis: ${controller.workshopSchedule != null}',
              name: 'ScheduleWorking');

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.20,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 5),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: DaysOfWeek.values.length,
              itemBuilder: (context, index) {
                final day = DaysOfWeek.values[index];
                final schedule = _getScheduleForDay(day, controller.workshopSchedule);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day.description,
                        style: const TextStyle(
                          color: AppColors.boldFontColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(), // Usar Spacer para empurrar o texto para as extremidades
                      Text(
                        schedule,
                        style: TextStyle(
                          color: schedule == 'Fechado'
                              ? AppColors.redAlertColor // Cor para "Fechado"
                              : AppColors.fontDarkGrayColor,
                          fontWeight: schedule == 'Fechado'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  String _getScheduleForDay(DaysOfWeek day, AgendaModel? agenda) {
    if (agenda == null) {
      dev.log('Agenda é nula - retornando fechado', name: 'ScheduleWorking');
      return 'Fechado';
    }

    dev.log('Verificando horário para ${day.description}', name: 'ScheduleWorking');

    final weekDayModel = switch (day) {
      DaysOfWeek.monday => agenda.monday,
      DaysOfWeek.tuesday => agenda.tuesday,
      DaysOfWeek.wednesday => agenda.wednesday,
      DaysOfWeek.thursday => agenda.thursday,
      DaysOfWeek.friday => agenda.friday,
      DaysOfWeek.saturday => agenda.saturday,
      DaysOfWeek.sunday => agenda.sunday,
    };

    // Log para debug dos valores recebidos da API
    dev.log('${day.description} - open: ${weekDayModel.open}, start: "${weekDayModel.startTime}", close: "${weekDayModel.closingTime}"',
        name: 'ScheduleWorking');

    // Considera aberto se tiver horários válidos, mesmo que open seja false
    bool hasValidTimes = weekDayModel.startTime.isNotEmpty &&
                         weekDayModel.closingTime.isNotEmpty &&
                         weekDayModel.startTime != '00:00:00' &&
                         weekDayModel.closingTime != '00:00:00';

    // Verificar horários com ou sem segundos
    if (hasValidTimes || weekDayModel.open == true) {
      // Formatando os horários para exibição (removendo segundos se existirem)
      String startTime = _formatTimeString(weekDayModel.startTime);
      String closingTime = _formatTimeString(weekDayModel.closingTime);

      if (startTime.isNotEmpty && closingTime.isNotEmpty) {
        return '$startTime - $closingTime';
      }

      // Se os horários estiverem vazios, mas o campo open for true, usamos um horário padrão
      return '08:00 - 18:00';
    }

    return 'Fechado';
  }

  // Método auxiliar para formatar strings de horário (remove segundos se presentes)
  String _formatTimeString(String timeString) {
    if (timeString.isEmpty) return '';

    // Se o formato for HH:MM:SS, converte para HH:MM
    if (timeString.length >= 8 && timeString.contains(':')) {
      return timeString.substring(0, 5);
    }

    return timeString;
  }
}
