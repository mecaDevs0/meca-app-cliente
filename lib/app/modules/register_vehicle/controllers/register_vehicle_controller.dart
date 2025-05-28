import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/car_detail_model.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/providers/my_vehicles_provider.dart';
import '../../../data/providers/register_vehicle_provider.dart';
import '../../my_vehicles/controllers/my_vehicles_controller.dart';

class RegisterVehicleController extends GetxController {
  RegisterVehicleController({
    required RegisterVehicleProvider registerVehicleProvider,
    required MyVehiclesProvider myVehiclesProvider,
  })  : _registerVehicleProvider = registerVehicleProvider,
        _myVehiclesProvider = myVehiclesProvider;

  final RegisterVehicleProvider _registerVehicleProvider;

  final MyVehiclesProvider _myVehiclesProvider;

  final MyVehiclesController myVehiclesController = Get.find();

  final vehicleDetails = Rx<Vehicle?>(null);
  final _isLoadingEdit = RxBool(false);
  final _isLoadingNew = RxBool(false);
  final _isLoading = RxBool(false);
  final _isSearching = RxBool(false);
  final carDetail = Rx<CarDetailModel>(CarDetailModel());

  bool get isLoadingNew => _isLoadingNew.value;
  bool get isLoadingEdit => _isLoadingEdit.value;
  bool get isLoading => _isLoading.value;
  bool get isSearching => _isSearching.value;

  bool isFromSchedule = false;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments != null && arguments['isFromSchedule'] != null) {
      isFromSchedule = arguments['isFromSchedule'];
    }

    if (arguments != null && arguments['vehicle'] != null) {
      final vehicle = arguments['vehicle'] as Vehicle;
      if (vehicle.id != null) {
        getEditedVehicle(vehicle.id!);
      }
    }
  }

  Future<bool> registerVehicle(Vehicle newVehicle) async {
    _isLoadingNew.value = true;
    bool isSuccess = false;
    await MegaRequestUtils.load(
      action: () async {
        await _registerVehicleProvider.onRegisterVehicle(newVehicle);
        isSuccess = true;
      },
      onFinally: () {
        _isLoadingNew.value = false;
        myVehiclesController.pagingController.refresh();
        Get.back();
      },
    );
    return isSuccess;
  }

  Future<bool> onEditVehicle(Vehicle editVehicle) async {
    bool isSuccess = false;

    _isLoadingEdit.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _registerVehicleProvider.onEditVehicle(editVehicle);
        isSuccess = true;
        myVehiclesController.pagingController.refresh();
      },
      onFinally: () {
        _isLoadingEdit.value = false;
      },
    );
    return isSuccess;
  }

  Future<void> getEditedVehicle(String id) async {
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final response = await _myVehiclesProvider.onRequestVehicle(id);
        vehicleDetails.value = response;
      },
      onFinally: () {
        _isLoading.value = false;
      },
    );
  }

  Future<void> searchPlate(String text) async {
    _isSearching.value = true;
    await MegaRequestUtils.load(
      action: () async {
        carDetail.value = await _registerVehicleProvider.searchPlate(text);
      },
      onFinally: () => _isSearching.value = false,
      onError: (_) {},
    );
  }
}
