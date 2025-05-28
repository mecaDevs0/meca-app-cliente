import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/mechanic_workshop.dart';
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

  bool get isLoading => _isLoading.value;
  bool get isLoadingWorkshopServices => _isLoadingWorkshopServices.value;
  bool get isLoadingWorkshopSchedule => _isLoadingWorkshopSchedule.value;
  MechanicWorkshop? get workshopDetails => _workshopDetails.value;
  AgendaModel? get workshopSchedule => _workshopSchedule.value;
  List<WorkshopService> get workshopServices => _workshopServices;
  BitmapDescriptor? get markerIcon => _markerIcon.value;

  late String workshopId;

  @override
  Future<void> onInit() async {
    super.onInit();

    final args = Get.arguments as WorkshopArgs;
    workshopId = args.workshopId;
    await getWorkshopDetails();
    await getWorkshopServices();
    await getWorkshopSchedule();
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
        final response = await _mechanicWorkshopDetailsProvider
            .onRequestMechanicWorkshopServices(workshopId: workshopId);
        _workshopServices.assignAll(response);
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
}
