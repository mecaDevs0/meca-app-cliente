import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/providers/my_vehicles_provider.dart';

class MyVehiclesController extends GetxController with ProfileMixin {
  MyVehiclesController({required MyVehiclesProvider myVehiclesProvider})
      : _myVehiclesProvider = myVehiclesProvider;

  final MyVehiclesProvider _myVehiclesProvider;

  final PagingController<int, Vehicle> pagingController =
      PagingController(firstPageKey: 1);
  final _limit = 30;

  final _searchQuery = RxString('');
  final _isLoading = RxBool(false);
  final _isLoadingMessage = RxString('');
  final _vehicleDetails = Rx<Vehicle?>(null);

  String get search => _searchQuery.value;
  bool get isLoading => _isLoading.value;
  String get isLoadingMessage => _isLoadingMessage.value;
  Vehicle? get vehicleDetails => _vehicleDetails.value;

  set search(String value) => _searchQuery.value = value;

  late String vehicleIcon;

  @override
  void onInit() {
    pagingController.addPageRequestListener(getVehicles);
    debounce(
      _searchQuery,
      _applySearchTermFilter,
      time: const Duration(milliseconds: 500),
    );
    super.onInit();
  }

  Future<void> changeVehicleIcon(String icon, String id) async {
    vehicleIcon = icon;
    await getVehicleDetails(id);
  }

  Future<void> getVehicles(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _myVehiclesProvider.onRequestVehicles(
          page: page,
          limit: _limit,
          search: search,
        );

        final isLastPage = response.length < _limit;
        if (isLastPage) {
          pagingController.appendLastPage(response);
        } else {
          final nextPageKey = page + 1;
          pagingController.appendPage(response, nextPageKey);
        }
      },
    );
  }

  Future<void> getVehicleDetails(String id) async {
    _isLoading.value = true;
    _isLoadingMessage.value = 'Carregando detalhes do veículo...';
    await MegaRequestUtils.load(
      action: () async {
        final response = await _myVehiclesProvider.onRequestVehicle(id);
        _vehicleDetails.value = response;
      },
      onFinally: () => _isLoading.value = false,
    );
  }

  void _applySearchTermFilter(String query) {
    _searchQuery.value = query;
    pagingController.refresh();
  }

  Future<void> removeVehicle(String id) async {
    await MegaRequestUtils.load(
      action: () async {
        await _myVehiclesProvider.onRemoveVehicle(id);
        pagingController.refresh();
      },
    );
  }
}
