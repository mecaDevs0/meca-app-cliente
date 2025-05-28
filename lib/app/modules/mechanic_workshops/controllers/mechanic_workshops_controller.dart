import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/mechanic_workshop.dart';
import '../../../data/models/service.dart';
import '../../../data/providers/mechanic_workshops_provider.dart';
import '../../app_filter/controllers/filter_controller.dart';
import '../../home/controllers/home_controller.dart';

class MechanicWorkshopsController extends GetxController {
  MechanicWorkshopsController({
    required MechanicWorkshopsProvider mechanicWorkshopsProvider,
    required FilterController filterController,
  })  : _mechanicWorkshopsProvider = mechanicWorkshopsProvider,
        _filterController = filterController;

  final MechanicWorkshopsProvider _mechanicWorkshopsProvider;
  final FilterController _filterController;
  final HomeController homeController = Get.find();

  int get rating => _filterController.rating;
  double get distance => _filterController.distance;
  List<Service> get services => _filterController.selectedCategories;
  List<Service> get availableCategories =>
      _filterController.availableCategories;

  final PagingController<int, MechanicWorkshop> pagingController =
      PagingController(firstPageKey: 1);
  final _limit = 30;

  @override
  void onInit() {
    _filterController.clearFilters();
    pagingController.addPageRequestListener(getAllWorkshops);
    super.onInit();
  }

  Future<void> getAllWorkshops(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response = await _mechanicWorkshopsProvider.onRequestWorkshops(
          page: page,
          limit: _limit,
          search: _filterController.searchQuery.isNotEmpty
              ? _filterController.searchQuery
              : null,
          serviceType: _filterController.selectedCategories.isNotEmpty
              ? _filterController.selectedCategories
                  .map((category) => category.id ?? '')
                  .toList()
              : null,
          rating:
              _filterController.rating > 0 ? _filterController.rating : null,
          distance: _filterController.distance.toInt(),
          latUser: homeController.userPosition?.latitude,
          longUser: homeController.userPosition?.longitude,
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
  void onClose() {
    _filterController.clearFilters();
    super.onClose();
  }
}
