import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/mechanic_workshop.dart';
import '../../../data/models/service.dart';
import '../../../data/models/workshopAgenda/agenda_model.dart';
import '../../../data/models/workshopService/workshop_service.dart';
import '../../../data/providers/mechanic_workshop_details_provider.dart';
import '../../home/controllers/home_controller.dart';

class MechanicWorkshopDetailsController extends GetxController {
  MechanicWorkshopDetailsController({
    required MechanicWorkshopDetailsProvider mechanicWorkshopDetailsProvider,
  }) : _mechanicWorkshopDetailsProvider = mechanicWorkshopDetailsProvider;

  final MechanicWorkshopDetailsProvider _mechanicWorkshopDetailsProvider;

  final _workshopDetails = Rx<MechanicWorkshop?>(null);
  final _workshopSchedule = Rx<AgendaModel?>(null);
  final _isLoading = RxBool(false);
  final _isLoadingWorkshopServices = RxBool(false);
  final _isLoadingWorkshopSchedule = RxBool(false);
  final _workshopServices = RxList<WorkshopService>.empty();
  final Rx<BitmapDescriptor?> _markerIcon = Rx<BitmapDescriptor?>(null);
  final _selectedService = Rx<Service?>(null); // Nova variável para o serviço selecionado

  bool get isLoading => _isLoading.value;
  bool get isLoadingWorkshopServices => _isLoadingWorkshopServices.value;
  bool get isLoadingWorkshopSchedule => _isLoadingWorkshopSchedule.value;
  MechanicWorkshop? get workshopDetails => _workshopDetails.value;
  AgendaModel? get workshopSchedule => _workshopSchedule.value;
  List<WorkshopService> get workshopServices => _workshopServices;
  BitmapDescriptor? get markerIcon => _markerIcon.value;
  Service? get selectedService => _selectedService.value; // Getter para o serviço selecionado

  late String workshopId;

  @override
  Future<void> onInit() async {
    super.onInit();

    if (Get.arguments is Map<String, dynamic>) {
      final args = Get.arguments as Map<String, dynamic>;
      workshopId = args['workshopId'] as String;
      _selectedService.value = args['selectedService'] as Service?;
      final MechanicWorkshop? passedWorkshopDetails = args['workshopDetails'] as MechanicWorkshop?;

      if (passedWorkshopDetails != null) {
        _workshopDetails.value = passedWorkshopDetails;
        _isLoading.value = false; // Set loading to false as details are already available
      } else {
        await getWorkshopDetails();
      }
    } else if (Get.arguments is WorkshopArgs) {
      final args = Get.arguments as WorkshopArgs;
      workshopId = args.workshopId;
      await getWorkshopDetails();
    } else {
      // Handle case where arguments are not as expected, maybe navigate back or show an error
      // For now, we'll just log and ensure workshopId is not null
      print('Invalid arguments passed to MechanicWorkshopDetailsController');
      // You might want to throw an error or navigate back here
      workshopId = ''; // Initialize with an empty string to prevent LateInitializationError
    }

    // Only call these if workshopId is valid
    if (workshopId.isNotEmpty) {
      await getWorkshopServices();
      await getWorkshopSchedule();
    }
  }

  Future<void> getWorkshopDetails() async {
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final HomeController homeController = Get.find();
        final response = await _mechanicWorkshopDetailsProvider
            .onRequestMechanicWorkshopDetails(
          id: workshopId,
          latUser: homeController.userPosition?.latitude,
          longUser: homeController.userPosition?.longitude,
        );
        _workshopDetails.value = response;
      },
      onFinally: () => _isLoading.value = false,
    );
  }

  Future<void> getWorkshopServices() async {
    _isLoadingWorkshopServices.value = true;
    await MegaRequestUtils.load(
      action: () async {
        print('[WORKSHOP_DETAILS] Buscando serviços para workshop: $workshopId');
        
        try {
          final response = await _mechanicWorkshopDetailsProvider
              .onRequestMechanicWorkshopServices(workshopId: workshopId);
          
          print('[WORKSHOP_DETAILS] Serviços retornados: ${response.length}');
          
          if (response.isEmpty) {
            print('[WORKSHOP_DETAILS] AVISO: Nenhum serviço encontrado para o workshop $workshopId');
          } else {
            final firstService = response.first;
            print('[WORKSHOP_DETAILS] Primeiro serviço - ID: ${firstService.id}');
            print('[WORKSHOP_DETAILS] Primeiro serviço - Service ID: ${firstService.service?.id}');
            print('[WORKSHOP_DETAILS] Primeiro serviço - Service Name: ${firstService.service?.name}');
          }
          
          _workshopServices.assignAll(response);
        } catch (e) {
          print('[WORKSHOP_DETAILS] ERRO ao buscar serviços: $e');
          rethrow;
        }
      },
      onFinally: () => _isLoadingWorkshopServices.value = false,
    );
  }

  Future<void> getWorkshopSchedule() async {
    _isLoadingWorkshopSchedule.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final response =
            await _mechanicWorkshopDetailsProvider.getWorkshopSchedule(
          workshopId,
        );
        _workshopSchedule.value = response;
      },
      onFinally: () => _isLoadingWorkshopSchedule.value = false,
    );
  }

  // Método para limpar o estado do estabelecimento selecionado
  void clearWorkshopSelection() {
    _workshopDetails.value = null;
    _workshopServices.clear();
    _workshopSchedule.value = null;
  }

  // Método para limpar todos os estados ao navegar para tela de serviços
  void resetStateForServicesNavigation() {
    clearWorkshopSelection();
    // Deixa o ID do estabelecimento, pois pode ser útil para histórico,
    // mas limpa os dados principais que causam o loop
  }

  @override
  void dispose() {
    clearWorkshopSelection();
    super.dispose();
  }
}
