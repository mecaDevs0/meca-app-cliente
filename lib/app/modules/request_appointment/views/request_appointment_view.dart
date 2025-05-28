import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
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
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      if (controller.vehicles.isEmpty) {
                        MegaSnackbar.showErroSnackBar(
                          'Cadastre pelo menos um veículo',
                        );
                        return;
                      }

                      if (controller.selectedServices.isEmpty) {
                        MegaSnackbar.showErroSnackBar(
                          'Selecione pelo menos um serviço para o agendamento',
                        );
                        return;
                      }

                      if (controller.selectedVehicle == null) {
                        MegaSnackbar.showErroSnackBar(
                          'Selecione um veículo para o agendamento',
                        );
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
}
