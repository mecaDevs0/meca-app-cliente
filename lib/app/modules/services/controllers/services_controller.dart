import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/service.dart';
import '../../../data/providers/services_provider.dart';
import '../../app_filter/controllers/filter_controller.dart';
import '../../home/controllers/home_controller.dart';

class ServicesController extends GetxController {
  ServicesController({
    required ServicesProvider servicesProvider,
    required FilterController filterController,
  })  : _servicesProvider = servicesProvider,
        _filterController = filterController;

  final ServicesProvider _servicesProvider;
  final HomeController homeController = Get.find();
  final FilterController _filterController;

  final _isLoading = RxBool(false);
  final _serviceDetail = Rx<Service?>(null);

  bool get isLoading => _isLoading.value;
  Service? get serviceDetail => _serviceDetail.value;
  int get rating => _filterController.rating;
  double get distance => _filterController.distance;
  List<Service> get services => _filterController.selectedCategories;
  List<Service> get availableCategories =>
      _filterController.availableCategories;

  final PagingController<int, Service> pagingController =
      PagingController(firstPageKey: 1);
  final _limit = 30;

  @override
  void onInit() {
    _filterController.clearFilters();
    pagingController.addPageRequestListener(getAllServices);
    super.onInit();
  }

  Future<void> getAllServices(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _servicesProvider.onRequestServices(
          page: page,
          limit: _limit,
          search: _filterController.searchQuery.isNotEmpty
              ? _filterController.searchQuery
              : null,
          serviceType: _filterController.selectedCategories
              .map((category) => category.id ?? '')
              .toList(),
          rating:
              _filterController.rating > 0 ? _filterController.rating : null,
          distance: _filterController.distance != null &&
                  _filterController.distance != 0.0
              ? _filterController.distance.toInt()
              : null,
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

  void updateFilters({
    String? searchQuery,
    List<Service>? selectedCategories,
    double? priceRangeInitial,
    double? priceRangeFinal,
    int? rating,
    double? distance,
  }) {
    _filterController.updateFilters(
      searchQuery: searchQuery,
      selectedCategories: selectedCategories,
      rating: rating,
      distance: distance,
    );
    pagingController.refresh();
  }

  @override
  void dispose() {
    _filterController.clearFilters();
    super.dispose();
  }
}
