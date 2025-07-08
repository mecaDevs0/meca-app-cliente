import 'dart:developer';

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
  final _hasError = RxBool(false);
  final _errorMessage = RxString('');

  VehicleScheduling? get selectedVehicle => _selectedVehicle.value;
  bool get isPickupServiceEnabled => _isPickupServiceEnabled.value;
  bool get isLoading => _isLoading.value;
  bool get isLoadingScheduling => _isLoadingScheduling.value;
  List<Vehicle> get vehicles => _vehicles.toList();
  List<WorkshopService> get services => _services;
  DateTime? get pickedDate => _pickedDate.value;
  List<WorkshopService> get selectedServices => _selectedServices.toList();
  bool get hasError => _hasError.value;
  String get errorMessage => _errorMessage.value;

  final PagingController<int, Service> pagingControllerServices =
      PagingController(firstPageKey: 1);

  late String workshopId;
  late String workshopName;

  @override
  Future<void> onInit() async {
    super.onInit();

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

    try {
      // Captura e valida os argumentos de navegação
      if (Get.arguments == null) {
        _setError('Informações da oficina não encontradas');
        return;
      }

      // Extrai argumentos dependendo do tipo enviado
      if (Get.arguments is WorkshopArgs) {
        final workshop = Get.arguments as WorkshopArgs;
        workshopId = workshop.workshopId;
        workshopName = workshop.workshopName ?? 'Oficina';
      } else if (Get.arguments is Map<String, dynamic>) {
        final args = Get.arguments as Map<String, dynamic>;
        workshopId = args['workshopId'] as String? ?? '';
        workshopName = args['workshopDetails']?.fullName ?? 'Oficina';
      } else {
        _setError('Formato de dados inválido');
        return;
      }

      if (workshopId.isEmpty) {
        _setError('ID da oficina não encontrado');
        return;
      }

      log('Iniciando agendamento para oficina: $workshopId - $workshopName');

      // Se recebeu ID e nome do serviço, vamos pré-selecionar esse serviço
      String? serviceId;
      String? serviceName;

      if (Get.arguments is WorkshopArgs) {
        final workshop = Get.arguments as WorkshopArgs;
        serviceId = workshop.serviceId;
        serviceName = workshop.serviceName;
      }

      await initialize();

      // Pré-seleciona o serviço se foi recebido nos argumentos
      if (serviceId != null && serviceName != null) {
        // Busca o serviço pelo ID na lista de serviços disponíveis
        final preSelectedService = _services.firstWhereOrNull(
          (service) => service.service?.id == serviceId,
        );

        // Se encontrou o serviço na lista, seleciona-o
        if (preSelectedService != null) {
          _selectedServices.add(preSelectedService);
          log('Serviço pré-selecionado: $serviceName');
        } else {
          log('Serviço não encontrado na lista de serviços disponíveis: $serviceName');
        }
      }
    } catch (e) {
      log('Erro ao inicializar tela de agendamento: $e');
      _setError('Ocorreu um erro ao inicializar a tela de agendamento');
    }
  }

  void _setError(String message) {
    _hasError.value = true;
    _errorMessage.value = message;
    log('Erro: $message');
    Get.snackbar(
      'Erro',
      message,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
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
    _hasError.value = false;

    try {
      await MegaRequestUtils.load(
        action: () async {
          // Carrega os veículos do usuário
          final vehicles = await _coreProvider.onRequestVehicles(limit: 0);
          _vehicles.assignAll(vehicles);
          log('Veículos carregados: ${vehicles.length}');

          // Carrega os serviços da oficina selecionada
          final services = await _coreProvider.onRequestServices(
            workshopId: workshopId,
          );

          if (services.isEmpty) {
            log('Nenhum serviço disponível para a oficina $workshopId');
          } else {
            log('Serviços carregados: ${services.length}');
          }

          _services.assignAll(services);
        },
        onError: (error) {
          log('Erro ao carregar dados iniciais: $error');
          _setError('Não foi possível carregar os dados necessários');
        },
        onFinally: () => _isLoading.value = false,
      );
    } catch (e) {
      _isLoading.value = false;
      log('Erro crítico ao inicializar: $e');
      _setError('Ocorreu um erro inesperado');
    }
  }

  void selectVehicle(VehicleScheduling vehicle) {
    _selectedVehicle.value = vehicle;
    // Corrigido para usar a propriedade plate que existe na classe VehicleScheduling
    final vehicleDesc = vehicle.plate ?? 'Veículo selecionado';
    log('Veículo selecionado: $vehicleDesc');
  }

  void selectService(WorkshopService service) {
    try {
      if (_selectedServices.contains(service)) {
        _selectedServices.remove(service);
        log('Serviço removido: ${service.service?.name}');
      } else {
        _selectedServices.add(service);
        log('Serviço adicionado: ${service.service?.name}');
      }
      // Força atualização da UI
      _selectedServices.refresh();
    } catch (e) {
      log('Erro ao selecionar serviço: $e');
    }
  }

  void togglePickupService() {
    _isPickupServiceEnabled.value = !_isPickupServiceEnabled.value;
  }

  Future<bool> registerScheduling(Scheduling newScheduling) async {
    _isLoadingScheduling.value = true;
    bool isSuccess = false;

    try {
      await MegaRequestUtils.load(
        action: () async {
          await _requestAppointmentProvider.onRegisterScheduling(newScheduling);
          isSuccess = true;
          log('Agendamento registrado com sucesso');
        },
        onError: (error) {
          log('Erro ao registrar agendamento: $error');
          Get.snackbar(
            'Erro',
            'Não foi possível registrar o agendamento. Tente novamente.',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        onFinally: () {
          _isLoadingScheduling.value = false;
        },
      );
    } catch (e) {
      _isLoadingScheduling.value = false;
      log('Erro crítico ao registrar agendamento: $e');
      Get.snackbar(
        'Erro',
        'Ocorreu um erro inesperado ao processar o agendamento.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    return isSuccess;
  }

  // Método para tentar novamente o carregamento dos serviços
  Future<void> retryLoading() async {
    _hasError.value = false;
    await initialize();
  }
}
