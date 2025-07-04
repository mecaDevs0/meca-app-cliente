import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/args/workshop_args.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../data/models/scheduling/scheduling.dart';
import '../../../data/models/scheduling/vehicle_scheduling.dart';
import '../../../data/models/service.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/workshopService/workshop_service.dart';
import '../../../data/providers/core_provider.dart';
import '../../../data/providers/request_appointment_provider.dart';
import '../../../routes/app_pages.dart';

class RequestAppointmentController extends GetxController {



  RequestAppointmentController({
    required RequestAppointmentProvider requestAppointmentProvider,
    required CoreProvider coreProvider,
  })  : _requestAppointmentProvider = requestAppointmentProvider,
        _coreProvider = coreProvider;

  final RequestAppointmentProvider _requestAppointmentProvider;
  final CoreProvider _coreProvider;

  final _selectedVehicle = Rx<VehicleScheduling?>(null);
  final _isPickupServiceEnabled = RxBool(false);
  final _isLoading = RxBool(false);
  final _isLoadingScheduling = RxBool(false);
  final _vehicles = RxList<Vehicle>.empty();
  final _services = RxList<WorkshopService>.empty();
  final _pickedDate = Rx<DateTime?>(null);
  final _selectedServices = RxList<WorkshopService>.empty();

  VehicleScheduling? get selectedVehicle => _selectedVehicle.value;
  bool get isPickupServiceEnabled => _isPickupServiceEnabled.value;
  bool get isLoading => _isLoading.value;
  bool get isLoadingScheduling => _isLoadingScheduling.value;
  List<Vehicle> get vehicles => _vehicles.toList();
  List<WorkshopService> get services => _services;
  DateTime? get pickedDate => _pickedDate.value;
  List<WorkshopService> get selectedServices => _selectedServices.toList();

  final PagingController<int, Service> pagingControllerServices =
      PagingController(firstPageKey: 1);

  late String workshopId;
  late String workshopName;

  @override
  Future<void> onInit() async {
    // Verifica se há um token válido e atualiza o status do usuário
    final token = AuthToken.fromCache();
    if (token != null && AuthHelper.isGuest) {
      // Se há um token válido mas o usuário ainda está marcado como visitante,
      // atualiza o status antes de continuar
      AuthHelper.setLoggedIn();
    } else if (AuthHelper.isGuest) {
      // Se realmente é um visitante, redireciona para o login
      Get.offAllNamed(Routes.login);
      return;
    }

    final workshop = Get.arguments as WorkshopArgs;
    workshopId = workshop.workshopId;
    workshopName = workshop.workshopName ?? '';

    await initialize();
    super.onInit();
  }

  Future<void> initialize() async {
    if (AuthHelper.isGuest) {
      Get.defaultDialog(
        title: 'Acesso restrito',
        middleText: 'Para acessar esta funcionalidade, você precisa fazer login.',
        textConfirm: 'Fazer login',
        confirmTextColor: Colors.white,
        buttonColor: AppColors.primaryColor,
        onConfirm: () {
          Get.back();
          Get.offAllNamed(Routes.login);
        },
        textCancel: 'Cancelar',
        cancelTextColor: AppColors.primaryColor,
      );
      return;
    }
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final vehicles = await _coreProvider.onRequestVehicles(limit: 0);
        _vehicles.assignAll(vehicles);

        final services = await _coreProvider.onRequestServices(
          workshopId: workshopId,
        );
        _services.assignAll(services);
      },
      onFinally: () => _isLoading.value = false,
    );
  }

  void selectVehicle(VehicleScheduling vehicle) {
    _selectedVehicle.value = vehicle;
  }

  void selectService(WorkshopService service) {
    if (_selectedServices.contains(service)) {
      _selectedServices.remove(service);
    } else {
      _selectedServices.add(service);
    }
  }

  void togglePickupService() {
    _isPickupServiceEnabled.value = !_isPickupServiceEnabled.value;
  }

  Future<bool> registerScheduling(Scheduling newScheduling) async {
    _isLoadingScheduling.value = true;
    bool isSuccess = false;
    await MegaRequestUtils.load(
      action: () async {
        await _requestAppointmentProvider.onRegisterScheduling(newScheduling);
        isSuccess = true;
      },
      onFinally: () {
        _isLoadingScheduling.value = false;
      },
    );

    return isSuccess;
  }
}
