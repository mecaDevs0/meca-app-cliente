import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../core/widgets/body_modal_timer.dart';
import '../../../data/models/scheduling/scheduling.dart';
import '../../../data/models/scheduling/vehicle_scheduling.dart';
import '../../../data/models/scheduling/workshop_scheduling.dart';
import '../../../routes/app_pages.dart';
import '../controllers/request_appointment_controller.dart';
import 'widgets/app_drop_down.dart';
import 'widgets/bottoms_sheets/order_confirmed.dart';
import 'widgets/build_text_field.dart';
import 'widgets/select_vehicle_widget.dart';
import 'widgets/selected_services_list.dart';

class RequestAppointmentView extends GetView<RequestAppointmentController> {
  RequestAppointmentView({super.key});

  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final obsController = TextEditingController();

  final formKey = GlobalKey<FormState>();

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
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Agendamento',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Obx(
          () => Skeletonizer(
            enabled: controller.isLoading,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  AppDropDown(
                    onSelected: controller.selectService,
                    services: controller.services,
                  ),
                  const SizedBox(height: 16),
                  SelectedServicesList(
                    controller: controller,
                    services: controller.services,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Veículos cadastrados',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: AppColors.blackPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SelectVehicleWidget(),
                  const SizedBox(height: 16),
                  // Seção de seleç��o de data e horário com feedback aprimorado
                  _buildDateTimeSelection(context),
                  const SizedBox(height: 16),
                  BuildTextField(
                    label: 'Observações',
                    controller: obsController,
                    hint: 'Escreva as observações caso tenha',
                  ).unite,
                  const SizedBox(height: 32),
                  MegaBaseButton(
                    'Confirmar agendamento',
                    buttonColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    isLoading: controller.isLoadingScheduling,
                    onButtonPress: () async {
                      // Validação completa antes de prosseguir com o agendamento
                      final validationError = controller.validateScheduling(
                        dateText: dateController.text,
                        timeText: timeController.text,
                        vehicle: controller.selectedVehicle,
                        services: controller.selectedServices,
                      );

                      if (validationError != null) {
                        MegaSnackbar.showErroSnackBar(validationError);
                        return;
                      }

                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      FocusScope.of(context).unfocus();
                      final isSuccess = await controller.registerScheduling(
                        Scheduling(
                          workshopServices: controller.selectedServices,
                          vehicle: VehicleScheduling(
                            id: controller.selectedVehicle?.id,
                            plate: controller.selectedVehicle?.plate,
                          ),
                          workshop: WorkshopScheduling(
                            id: controller.workshopId,
                            fullName: controller.workshopName,
                          ),
                          observations: obsController.text,
                          date: _makeDateTime(
                            dateController.text,
                            timeController.text,
                          ),
                          status: 0,
                        ),
                      );

                      if (isSuccess && context.mounted) {
                        showApprovedRequestBottomSheet(
                          context: context,
                          onTap: () {
                            Get.toNamed(Routes.ordersPlaced);
                          },
                        );
                      }
                    },
                    buttonHeight: 46,
                    borderRadius: 4.0,
                  ).unite,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Widget para seleção de data e horário com tratamento de erros aprimorado
  Widget _buildDateTimeSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seleção de data
        AppTextField(
          label: 'Data',
          controller: dateController,
          hintText: 'Data do agendamento',
          suffixIcon: Padding(
            padding: const EdgeInsets.all(2),
            child: SvgPicture.asset(
              AppImages.icCalendar,
              width: 16,
              height: 16,
            ),
          ),
          isRequired: true,
          onTap: () => _showDatePicker(context),
        ).unite,

        // Mensagem de erro de disponibilidade de data
        Obx(() {
          // Só mostra erro se for visitante E não estiver logado
          if (controller.hasAvailabilityError &&
              controller.availabilityErrorMessage.contains('oficina não tem horários') && AuthHelper.isGuest) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.availabilityErrorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        const SizedBox(height: 16),

        // Seleção de horário
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
          onTap: () => _showTimePicker(context),
        ).unite,

        // Indicador de carregando ou mensagem de erro para horários
        Obx(() {
          if (controller.isLoadingAvailability) {
            return const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Carregando horários disponíveis...',
                    style: TextStyle(
                      color: AppColors.fontDarkGrayColor,
                      fontSize: 12
                    ),
                  ),
                ],
              ),
            );
          } else if (controller.hasAvailabilityError &&
                     controller.availabilityErrorMessage.contains('horários disponíveis')) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.availabilityErrorMessage,
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  /// Mostra o seletor de data com validação aprimorada
  Future<void> _showDatePicker(BuildContext context) async {
    // Informa ao usuário que estamos carregando as datas disponíveis
    MegaSnackbar.showErroSnackBar('Carregando datas disponíveis...');

    // Carrega as datas disponíveis antes de mostrar o calendário
    final success = await controller.loadAvailableDates();

    if (!success || controller.availableDates.isEmpty) {
      // Se houve erro ao carregar datas ou não há datas disponíveis, mostra mensagem
      MegaSnackbar.showErroSnackBar(
        controller.hasAvailabilityError
          ? controller.availabilityErrorMessage
          : 'Não há datas disponíveis para agendamento nesta oficina.'
      );
      return;
    }

    if (!context.mounted) return;

    // Mostra o seletor de data com seletor personalizado
    showMegaDatePicker(
      context,
      minimumDate: DateTime.now(),
      maximumDate: DateTime.now().add(const Duration(days: 365)),
      // Removido selectableDayPredicate pois não existe
      onSelectDate: (date) {

        dateController.text = date.toddMMyyyy();
        // Limpa o horário selecionado anteriormente
        timeController.clear();
        // Carrega os horários disponíveis para a data selecionada
        controller.checkAvailabilityForDate(date);
      },
      onCancelClick: () {
        dateController.clear();
      },
    );
  }

  /// Mostra o seletor de horário com validação aprimorada
  Future<void> _showTimePicker(BuildContext context) async {
    // Verifica se uma data foi selecionada primeiro
    if (dateController.text.isEmpty) {
      MegaSnackbar.showErroSnackBar(
        'Selecione uma data antes de escolher o horário',
      );
      return;
    }

    if (controller.isLoadingAvailability) {
      MegaSnackbar.showSuccessSnackBar(
        'Carregando horários disponíveis, aguarde...',
      );
      return;
    }

    if (controller.availableHours.isEmpty) {
      // Se não carregamos os horários ainda, tentamos carregar
      if (controller.selectedDate != null) {
        final success = await controller.checkAvailabilityForDate(controller.selectedDate!);
        if (!success) {
          MegaSnackbar.showErroSnackBar(
            controller.availabilityErrorMessage.isNotEmpty
                ? controller.availabilityErrorMessage
                : 'Não há horários disponíveis para esta data',
          );
          return;
        }
      } else {
        MegaSnackbar.showErroSnackBar(
          'Selecione uma data válida antes de escolher o horário',
        );
        return;
      }
    }

    // Se ainda não temos horários disponíveis após tentar carregar
    if (controller.availableHours.isEmpty) {
      MegaSnackbar.showErroSnackBar(
        'Não há horários disponíveis para esta data. Por favor, escolha outra data.',
      );
      return;
    }

    if (!context.mounted) return;

    // Mostra diálogo com lista de horários disponíveis em um layout mais amigável
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Horários Disponíveis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
                maxWidth: double.infinity,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: controller.availableHours.map((hour) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(hour),
                          selected: timeController.text == hour,
                          onSelected: (selected) {
                            if (selected) {
                              timeController.text = hour;
                              Navigator.pop(context);
                            }
                          },
                          selectedColor: AppColors.primaryColor,
                          labelStyle: TextStyle(
                            color: timeController.text == hour
                                ? Colors.white
                                : AppColors.blackPrimaryColor,
                          ),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: AppColors.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
