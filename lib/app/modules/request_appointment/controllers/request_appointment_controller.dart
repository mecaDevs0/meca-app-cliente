import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/args/workshop_args.dart';
import '../../../core/utils/auth_helper.dart';
import '../../../data/models/profile.dart';
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
  String? _openingHours;

  @override
  Future<void> onInit() async {
    super.onInit();

    // Verifica se há um token válido e atualiza o status do usuário
    final token = AuthToken.fromCache();
    if (token != null && AuthHelper.isGuest) {
      AuthHelper.setLoggedIn();
    }
    // Só mostra flag de visitante se realmente for visitante
    if (AuthHelper.isGuest) {
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
        _openingHours = workshop.openingHours;
      } else if (Get.arguments is Map<String, dynamic>) {
        final args = Get.arguments as Map<String, dynamic>;
        workshopId = args['workshopId'] as String? ?? '';
        workshopName = args['workshopDetails']?.fullName ?? 'Oficina';
        _openingHours = args['workshopDetails']?.openingHours as String?;
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

          // Extrai a mensagem de erro do backend
          String errorMessage = 'Não foi possível registrar o agendamento. Tente novamente.';

          try {
            // Converte a resposta para string e extrai a mensagem de erro
            final errorStr = error.toString();
            if (errorStr.contains('message')) {
              // Tenta extrair a mensagem de formatos diferentes de resposta
              final regex = RegExp(r'message: ([^,}]+)');
              final match = regex.firstMatch(errorStr);
              if (match != null && match.groupCount >= 1) {
                errorMessage = match.group(1)!.trim();
              }
            }
          } catch (e) {
            log('Erro ao extrair mensagem de erro: $e');
          }

          // Exibe um diálogo em vez de snackbar para maior visibilidade
          Get.dialog(
            Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro no Agendamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Entendi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barrierDismissible: false,
          );
        },
        onFinally: () {
          _isLoadingScheduling.value = false;
        },
      );
    } catch (e) {
      _isLoadingScheduling.value = false;
      log('Erro crítico ao registrar agendamento: $e');

      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erro no Agendamento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ocorreu um erro inesperado ao processar o agendamento. Por favor, tente novamente mais tarde.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
    }

    return isSuccess;
  }

  // Método para tentar novamente o carregamento dos serviços
  Future<void> retryLoading() async {
    _hasError.value = false;
    await initialize();
  }

  // Horários disponíveis para agendamento
  final _availableHours = RxList<String>.empty();
  final _availableDates = RxList<DateTime>.empty();
  final _isLoadingAvailability = RxBool(false);
  final _selectedDate = Rx<DateTime?>(null);
  final _hasAvailabilityError = RxBool(false);
  final _availabilityErrorMessage = RxString('');

  List<String> get availableHours => _availableHours.toList();
  List<DateTime> get availableDates => _availableDates.toList();
  bool get isLoadingAvailability => _isLoadingAvailability.value;
  DateTime? get selectedDate => _selectedDate.value;
  bool get hasAvailabilityError => _hasAvailabilityError.value;
  String get availabilityErrorMessage => _availabilityErrorMessage.value;

  // Função para verificar disponibilidade de horários para a data selecionada
  Future<bool> checkAvailabilityForDate(DateTime date) async {
  _isLoadingAvailability.value = true;
  _availableHours.clear();
  _hasAvailabilityError.value = false;
  _availabilityErrorMessage.value = '';
  _selectedDate.value = date;

  try {
    log('Verificando horários disponíveis para a oficina $workshopId na data ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');

    // Obtém o profileId do cache
    final profile = Profile.fromCache();
    if (profile.id == null || profile.id!.isEmpty) {
      _hasAvailabilityError.value = true;
      _availabilityErrorMessage.value = 'Erro de autenticação. Faça login novamente.';
      _isLoadingAvailability.value = false;
      return false;
    }

    final response = await _requestAppointmentProvider.getAvailableHours(
      workshopId: workshopId,
      date: date,
      profileId: profile.id!,
    );

    if (response.isNotEmpty) {
      _availableHours.assignAll(response);
      log('Horários disponíveis carregados: ${response.length}');
      _availableHours.sort();
      _isLoadingAvailability.value = false;
      return true;
    }

    // Se não veio da API, tenta gerar localmente
    List<String> generatedHours = [];
    if (_openingHours != null && _openingHours!.isNotEmpty) {
      generatedHours = _generateHoursFromOpening(_openingHours!);
    }
    // Se ainda não tem, usa um padrão das 08:00 às 18:00
    if (generatedHours.isEmpty) {
      generatedHours = _generateHoursFromOpening('08:00-18:00');
    }
    if (generatedHours.isNotEmpty) {
      _availableHours.assignAll(generatedHours);
      log('Horários gerados localmente: ${generatedHours.length}');
      _isLoadingAvailability.value = false;
      return true;
    }

    // Se chegou aqui, realmente não há horários
    _hasAvailabilityError.value = true;
    _availabilityErrorMessage.value = 'Não há horários disponíveis para esta data.';
    log('Nenhum horário disponível para ${date.day}/${date.month}/${date.year}');
    _isLoadingAvailability.value = false;
    return false;
  } catch (e) {
    // Em caso de erro, tenta gerar localmente também
    List<String> generatedHours = [];
    if (_openingHours != null && _openingHours!.isNotEmpty) {
      generatedHours = _generateHoursFromOpening(_openingHours!);
    }
    if (generatedHours.isEmpty) {
      generatedHours = _generateHoursFromOpening('08:00-18:00');
    }
    if (generatedHours.isNotEmpty) {
      _availableHours.assignAll(generatedHours);
      log('Horários gerados localmente após erro: ${generatedHours.length}');
      _isLoadingAvailability.value = false;
      return true;
    }
    _hasAvailabilityError.value = true;
    _availabilityErrorMessage.value = 'Erro ao carregar horários. Tente novamente.';
    log('Erro ao carregar horários disponíveis: $e');
    _isLoadingAvailability.value = false;
    return false;
  }
}

  // Função auxiliar para gerar horários a partir do horário de funcionamento
  List<String> _generateHoursFromOpening(String openingHours) {
    // Aceita formatos como "Seg-Sex: 08:00-18:00", "08:00 às 18:00", "08:00-18:00", ou múltiplos separados por vírgula
    final List<String> hours = [];
    // Divide por vírgula caso venha múltiplos períodos
    final parts = openingHours.split(',');
    for (final part in parts) {
      // Extrai apenas o trecho de horário (remove prefixos de dias, etc)
      final timeMatch = RegExp(r'(\d{2}:\d{2})\s*[-aà]?\s*(\d{2}:\d{2})').firstMatch(part);
      if (timeMatch != null && timeMatch.groupCount >= 2) {
        final start = timeMatch.group(1)!;
        final end = timeMatch.group(2)!;

        final startParts = start.split(':');
        final startHour = int.parse(startParts[0]);
        final startMinute = int.parse(startParts[1]);

        final endParts = end.split(':');
        final endHour = int.parse(endParts[0]);
        final endMinute = int.parse(endParts[1]);

        DateTime current = DateTime(2000, 1, 1, startHour, startMinute);
        final endDateTime = DateTime(2000, 1, 1, endHour, endMinute);

        while (current.isBefore(endDateTime) || current.isAtSameMomentAs(endDateTime)) {
          hours.add('${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}');
          current = current.add(const Duration(minutes: 30));
        }
      }
    }
    return hours;
  }

  // Função para carregar os dias disponíveis para agendamento
Future<bool> loadAvailableDates() async {
  _isLoadingAvailability.value = true;
  _availableDates.clear();
  _hasAvailabilityError.value = false;
  _availabilityErrorMessage.value = '';

  try {
    log('Carregando datas disponíveis para oficina: $workshopId');

    final response = await _requestAppointmentProvider.getAvailableDates(
      workshopId: workshopId,
      workshopHours: _openingHours?.split(',') ?? [],
    );

    _availableDates.assignAll(response);

    if (response.isEmpty) {
      // Gera datas dos próximos 60 dias úteis
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final List<DateTime> generatedDates = [];

      for (int i = 1; i <= 60; i++) {
        final date = today.add(Duration(days: i));
        // Adiciona apenas dias úteis (segunda a sexta)
        if (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday) {
          generatedDates.add(date);
        }
      }
      
      _availableDates.assignAll(generatedDates);
      log('Datas geradas localmente: ${_availableDates.length}');
    } else {
      _availableDates.sort((a, b) => a.compareTo(b));
      log('Datas disponíveis carregadas: ${response.length}');
    }

    _isLoadingAvailability.value = false;
    return true;
  } catch (e) {
    _hasAvailabilityError.value = true;
    _availabilityErrorMessage.value = 'Erro ao carregar datas. Tente novamente.';
    log('Erro ao carregar datas disponíveis: $e');
    _isLoadingAvailability.value = false;
    return false;
  }
}

  // Método para verificar se uma data está disponível para agendamento
  bool isDateAvailable(DateTime date) {
    if (_availableDates.isEmpty) {
      // Se não temos datas disponíveis, não permitimos seleção de datas
      return false;
    }

    // Verificar se a data está na lista de datas disponíveis
    return _availableDates.any((availableDate) =>
      availableDate.year == date.year &&
      availableDate.month == date.month &&
      availableDate.day == date.day);
  }

  // Método para validar o agendamento antes de enviar
  String? validateScheduling({
    required String dateText,
    required String timeText,
    required VehicleScheduling? vehicle,
    required List<WorkshopService> services,
  }) {
    if (dateText.isEmpty) {
      return 'Selecione uma data para o agendamento';
    }

    if (timeText.isEmpty) {
      return 'Selecione um horário para o agendamento';
    }

    if (vehicle == null) {
      return 'Selecione um veículo para o agendamento';
    }

    if (services.isEmpty) {
      return 'Selecione pelo menos um serviço para o agendamento';
    }

    return null; // Sem erros de validação
  }
}
