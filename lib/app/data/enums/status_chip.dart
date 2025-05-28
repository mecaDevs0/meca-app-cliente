import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

enum StatusChip {
  waitingConfirmAppointment('Aguardando confirmar agendamento'),
  scheduled('Agendado'),
  waitingSendBudget('Aguardando envio de orçamento'),
  waitingApprovalBudget('Aguardando aprovação de orçamento'),
  waitingPaymentClient('Aguardando pagamento do cliente'),
  waitingStart('Aguardando inicio'),
  inProgress('Em andamento'),
  completed('Concluído'),
  waitingApprovalClient('Aguardando aprovação do cliente'),
  finished('Finalizado');

  const StatusChip(this.description);
  final String description;

  Color get color {
    return switch (this) {
      StatusChip.waitingConfirmAppointment =>
        AppColors.orderStatusAwaitingConfirmationDark,
      StatusChip.finished => AppColors.orderStatusFinishedDark,
      _ => AppColors.orderStatusAwaitingApprovalDark,
    };
  }

  Color get borderColor {
    return switch (this) {
      StatusChip.waitingConfirmAppointment =>
        AppColors.orderStatusAwaitingConfirmationDark,
      StatusChip.finished => AppColors.orderStatusFinishedDark,
      _ => AppColors.orderStatusAwaitingApprovalDark,
    };
  }
}
