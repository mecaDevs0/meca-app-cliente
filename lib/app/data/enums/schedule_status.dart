import 'dart:ui';

import '../../core/app_colors.dart';

enum ScheduleStatus {
  waitingScheduling('Aguardando agendamento'),
  suggestedTime('Horário sugerido'),
  refusedScheduling('Agendamento recusado'),
  scheduled('Agendado'),
  didNotAttend('Não compareceu'),
  schedulingFinished('Agendamento finalizado'),
  waitingBudget('Aguardando orçamento'),
  budgetSent('Orçamento enviado'),
  waitingBudgetApproval('Aguardando aprovação de orçamento'),
  budgetApproved('Orçamento aprovado'),
  budgetPartiallyApproved('Orçamento aprovado parcialmente'),
  budgetRefused('Orçamento reprovado'),
  waitingPayment('Aguardando pagamento'),
  paymentApproved('Pagamento aprovado'),
  paymentRefused('Pagamento reprovado'),
  waitingStart('Aguardando início'),
  serviceInProgress('Serviço em andamento'),
  waitingParts('Aguardando peças'),
  serviceCompleted('Serviço concluído'),
  waitingServiceApproval('Aguardando aprovação do serviço'),
  serviceRefusedByUser('Serviço reprovado pelo usuário'),
  workshopDispute('Contestação da Oficina'),
  serviceApprovedByUser('Serviço aprovado pelo usuário'),
  serviceApprovedByAdmin('Serviço aprovado pelo admin'),
  servicePartiallyApprovedByAdmin('Serviço aprovado parcialmente pelo admin'),
  serviceRefusedByAdmin('Serviço reprovado pelo admin'),
  serviceFinished('Serviço finalizado');

  const ScheduleStatus(this.name);
  final String name;

  Color get color {
    switch (this) {
      case ScheduleStatus.waitingScheduling:
      case ScheduleStatus.suggestedTime:
      case ScheduleStatus.scheduled:
      case ScheduleStatus.waitingBudget:
      case ScheduleStatus.budgetSent:
      case ScheduleStatus.waitingBudgetApproval:
      case ScheduleStatus.waitingPayment:
      case ScheduleStatus.waitingStart:
      case ScheduleStatus.serviceInProgress:
      case ScheduleStatus.waitingParts:
      case ScheduleStatus.waitingServiceApproval:
        return AppColors.chetwodeBlue;
      case ScheduleStatus.refusedScheduling:
      case ScheduleStatus.didNotAttend:
      case ScheduleStatus.budgetRefused:
      case ScheduleStatus.paymentRefused:
      case ScheduleStatus.serviceRefusedByUser:
      case ScheduleStatus.workshopDispute:
      case ScheduleStatus.serviceRefusedByAdmin:
        return AppColors.redAlertColor;
      case ScheduleStatus.schedulingFinished:
      case ScheduleStatus.budgetApproved:
      case ScheduleStatus.budgetPartiallyApproved:
      case ScheduleStatus.paymentApproved:
      case ScheduleStatus.serviceCompleted:
      case ScheduleStatus.serviceApprovedByUser:
      case ScheduleStatus.serviceApprovedByAdmin:
      case ScheduleStatus.servicePartiallyApprovedByAdmin:
      case ScheduleStatus.serviceFinished:
        return AppColors.shamrock;
    }
  }

  static List<int> get nextStatus {
    return [
      0,
      1,
      3,
      5,
      6,
      7,
      8,
      9,
      10,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      27,
    ];
  }

  static List<int> get historicStatus {
    return [
      2,
      4,
      11,
      26,
    ];
  }
}
