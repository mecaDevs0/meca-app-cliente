import 'dart:developer';
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
    try {
      await MegaRequestUtils.load(
        action: () async {
          try {
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

            // Verifica se a resposta está vazia ou tem menos itens que o limite
            final isLastPage = response.isEmpty || response.length < _limit;
            if (isLastPage) {
              pagingController.appendLastPage(response);
            } else {
              final nextPageKey = page + 1;
              pagingController.appendPage(response, nextPageKey);
            }
          } catch (e) {
            // Captura específica para erros Dio
            if (e is DioError && e.response?.statusCode == 400) {
              // Caso específico de "Index was out of range"
              // Este é um indicador de que tentamos buscar uma página que não existe
              pagingController.appendLastPage([]);
              log('Erro de paginação: tentativa de acessar página inexistente', error: e);
            } else {
              // Propaga outros erros para serem tratados pelo MegaRequestUtils
              throw e;
            }
          }
        },
        onError: (error) {
          // Garante que erros são propagados para o pagingController
          pagingController.error = error;
          log('Erro ao buscar serviços', error: error);
        },
      );
    } catch (e) {
      // Captura qualquer erro não tratado e evita que o app trave
      pagingController.error = e;
      log('Erro crítico ao buscar serviços', error: e);
    }
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

  // Método para limpar o estado de serviço selecionado
  void clearServiceState() {
    _serviceDetail.value = null;
  }

  @override
  void dispose() {
    clearServiceState();
    _filterController.clearFilters();
    super.dispose();
  }
}
