import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/vehicle.dart';
import '../../../routes/app_pages.dart';
import '../../request_appointment/controllers/request_appointment_controller.dart';
import '../controllers/register_vehicle_controller.dart';

class RegisterVehicleView extends StatefulWidget {
  const RegisterVehicleView({super.key});

  @override
  State<RegisterVehicleView> createState() => _RegisterVehicleViewState();
}

class _RegisterVehicleViewState
    extends MegaState<RegisterVehicleView, RegisterVehicleController> {
  final plateController = TextEditingController();
  final manufatureController = TextEditingController();
  final modelController = TextEditingController();
  final colorController = TextEditingController();
  final mileageController = TextEditingController();
  final yearController = TextEditingController();
  final dateController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    ever(controller.carDetail, (carDetail) {
      plateController.text = carDetail.plate;
      manufatureController.text = carDetail.manufacturer;
      modelController.text = carDetail.model;
      colorController.text = carDetail.color;
      yearController.text = carDetail.year;
    });
  }

  @override
  void dispose() {
    plateController.dispose();
    manufatureController.dispose();
    modelController.dispose();
    colorController.dispose();
    mileageController.dispose();
    yearController.dispose();
    dateController.dispose();
    super.dispose();
  }

  void _clearFields() {
    manufatureController.clear();
    modelController.clear();
    colorController.clear();
    mileageController.clear();
    yearController.clear();
    dateController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Cadastrar veículo',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(
              height: 16,
            ),
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Placa',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Obx(
                        () => Stack(
                          children: [
                            MegaTextFieldWidget(
                              plateController,
                              hintText: 'Digite a placa do veículo',
                              keyboardType: TextInputType.text,
                              isRequired: true,
                              validator: Validatorless.multiple([
                                Validatorless.required(
                                  'A placa é obrigatória',
                                ),
                              ]),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9]'),
                                ),
                                UpperCaseTextFormatter(),
                                LengthLimitingTextInputFormatter(7),
                              ],
                              onChanged: (plate) {
                                if (plate?.isEmpty ?? false) {
                                  _clearFields();
                                  return;
                                }
                                if (plateController.text.length == 7) {
                                  controller.searchPlate(plateController.text);
                                }
                              },
                            ),
                            if (controller.isSearching)
                              Positioned(
                                top: 0,
                                right: 0,
                                bottom: 0,
                                child: Center(
                                  child: Container(
                                    height: 18,
                                    width: 18,
                                    margin: const EdgeInsets.only(right: 10),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fabricante',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        manufatureController,
                        labelFontColor: AppColors.blackPrimaryColor,
                        hintText: 'Digite a fabricante do veículo',
                        isRequired: true,
                        keyboardType: TextInputType.text,
                        validator: Validatorless.multiple([
                          Validatorless.required('A fabricante é obrigatória'),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modelo',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        modelController,
                        hintText: 'Digite o modelo',
                        isRequired: true,
                        keyboardType: TextInputType.text,
                        validator: Validatorless.multiple([
                          Validatorless.required('O modelo é obrigatório'),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quilometragem',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        mileageController,
                        labelFontColor: AppColors.blackPrimaryColor,
                        hintText: 'Digite a quilometragem do veículo',
                        isRequired: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cor',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        colorController,
                        labelFontColor: AppColors.blackPrimaryColor,
                        hintText: 'Digite a cor do veículo',
                        isRequired: true,
                        keyboardType: TextInputType.text,
                        validator: Validatorless.multiple([
                          Validatorless.required('A cor é obrigatória'),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ano',
                        style: TextStyle(color: AppColors.blackPrimaryColor),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      MegaTextFieldWidget(
                        yearController,
                        labelFontColor: AppColors.blackPrimaryColor,
                        hintText: 'Digite o ano do veículo',
                        isRequired: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: Validatorless.multiple([
                          Validatorless.required('O ano é obrigatório'),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Data da última revisão',
                            style:
                                TextStyle(color: AppColors.blackPrimaryColor),
                          ),
                          SizedBox(
                            width: 2,
                          ),
                          Text(
                            '(opcional)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.smallFontColor,
                            ),
                          ),
                        ],
                      ),
                      AppTextField(
                        label: '',
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
                            minimumDate: DateTime.now().subtract(
                              const Duration(days: 700),
                            ),
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
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  MegaBaseButton(
                    'Finalizar cadastro',
                    buttonColor: AppColors.primaryColor,
                    textColor: AppColors.whiteColor,
                    onButtonPress: () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      FocusScope.of(context).unfocus();

                      final newVehicle = Vehicle(
                        plate: plateController.text,
                        manufacturer: manufatureController.text,
                        model: modelController.text,
                        km: int.parse(mileageController.text),
                        color: colorController.text,
                        year: yearController.text,
                        lastRevisionDate: dateController.text.toTimeStamp,
                      );
                      final hasResult =
                          await controller.registerVehicle(newVehicle);

                      if (hasResult) {
                        MegaSnackbar.showSuccessSnackBar(
                          'Veículo cadastrado com sucesso!',
                        );
                        if (controller.isFromSchedule) {
                          final RequestAppointmentController
                              requestAppointmentController = Get.find();

                          await requestAppointmentController.initialize();
                          Get.toNamed(Routes.requestAppointment);
                        }
                      }
                    },
                    buttonHeight: 46,
                    borderRadius: 4.0,
                    isLoading: controller.isLoadingNew,
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
