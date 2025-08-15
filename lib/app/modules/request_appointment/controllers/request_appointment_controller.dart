import 'dart:developer';

import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/args/workshop_args.dart';
import '../../../data/models/scheduling/scheduling.dart';
import '../../../data/models/scheduling/vehicle_scheduling.dart';
import '../../../data/models/service.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/workshopService/workshop_service.dart';
import '../../../data/providers/core_provider.dart';
import '../../../data/providers/request_appointment_provider.dart';

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
  dynamic _selectedServiceFromArgs;

  @override
  Future<void> onInit() async {
    final arg = Get.arguments;
    late WorkshopArgs workshop;
    if (arg is WorkshopArgs) {
      workshop = arg;
    } else if (arg is Map<String, dynamic>) {
      workshop = WorkshopArgs.fromJson(arg);
    } else if (arg is Map) {
      workshop = WorkshopArgs.fromJson(Map<String, dynamic>.from(arg));
    } else {
      throw Exception('Argumento inválido para WorkshopArgs: ${arg.runtimeType}');
    }
    workshopId = workshop.workshopId;
    workshopName = workshop.workshopName ?? '';
    _openingHours = workshop.openingHours;
    _selectedServiceFromArgs = workshop.selectedService;
    await initialize();
    super.onInit();
  }

  Future<void> initialize() async {
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        log('[AGENDAMENTO] Buscando veículos do usuário...');
        final vehicles = await _coreProvider.onRequestVehicles(limit: 0);
        log('[AGENDAMENTO] Veículos retornados: ${vehicles.length}');
        _vehicles.assignAll(vehicles);

        log('[AGENDAMENTO] Buscando serviços do estabelecimento $workshopId...');
        final services = await _coreProvider.onRequestServices(
          workshopId: workshopId,
        );
        log('[AGENDAMENTO] Serviços retornados: ${services.length}');
        _services.assignAll(services);
        
        // Pré-selecionar o serviço se foi passado nos argumentos
        if (_selectedServiceFromArgs != null) {
          _preSelectServiceFromArgs();
        }
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

  void _preSelectServiceFromArgs() {
    if (_selectedServiceFromArgs == null) return;
    
    // Se o serviço passado é um Service (da home), procura pelo WorkshopService correspondente
    if (_selectedServiceFromArgs is Service) {
      final service = _selectedServiceFromArgs as Service;
      final matchingWorkshopService = _services.firstWhereOrNull(
        (ws) => ws.service?.id == service.id,
      );
      if (matchingWorkshopService != null) {
        _selectedServices.add(matchingWorkshopService);
        log('[AGENDAMENTO] Serviço pré-selecionado: ${matchingWorkshopService.service?.name}');
      }
    }
    // Se o serviço passado é um WorkshopService, adiciona diretamente
    else if (_selectedServiceFromArgs is WorkshopService) {
      final workshopService = _selectedServiceFromArgs as WorkshopService;
      if (_services.contains(workshopService)) {
        _selectedServices.add(workshopService);
        log('[AGENDAMENTO] WorkshopService pré-selecionado: ${workshopService.service?.name}');
      }
    }
  }

  Future<bool> registerScheduling(Scheduling newScheduling) async {
    _isLoadingScheduling.value = true;
    bool isSuccess = false;
    // LOGS DE TIMEZONE PARA PROVA
    try {
      final timestamp = newScheduling.date;
      log('[DEBUG] Timestamp enviado para API: $timestamp');
      if (timestamp != null) {
        final dtUtc = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
        log('[DEBUG] Data/Hora UTC: \x1B[32m${dtUtc.toIso8601String()} (${dtUtc.toLocal()})\x1B[0m');
        try {
          final saoPaulo = tz.getLocation('America/Sao_Paulo');
          final dtSp = tz.TZDateTime.fromMillisecondsSinceEpoch(saoPaulo, timestamp * 1000);
          log('[DEBUG] Data/Hora America/Sao_Paulo: \x1B[34m${dtSp.toString()}\x1B[0m');
        } catch (e) {
          log('[DEBUG] Falha ao logar TZ: $e');
        }
      }
    } catch (e) {
      log('[DEBUG] Falha ao logar timestamp: $e');
    }
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
    List<String> generatedHours = _generateHoursFromOpening(_openingHours ?? '08:00-18:00');
    if (generatedHours.isNotEmpty) {
      _availableHours.assignAll(generatedHours);
      _isLoadingAvailability.value = false;
      return true;
    } else {
      _hasAvailabilityError.value = true;
      _availabilityErrorMessage.value = 'Não há horários disponíveis para esta data.';
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
    // Geração local de datas disponíveis (próximos 60 dias úteis)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<DateTime> generatedDates = [];
    for (int i = 1; i <= 60; i++) {
      final date = today.add(Duration(days: i));
      if (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday) {
        generatedDates.add(date);
      }
    }
    _availableDates.assignAll(generatedDates);
    _isLoadingAvailability.value = false;
    return true;
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
    if (_vehicles.isEmpty) {
      return 'Você não possui veículos cadastrados.';
    }
    if (_services.isEmpty) {
              return 'O estabelecimento não possui serviços disponíveis.';
    }
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
