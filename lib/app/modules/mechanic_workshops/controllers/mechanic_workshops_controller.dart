import 'dart:developer' as console;

import 'package:flutter/foundation.dart';
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
    // Garantir que temos a posição do usuário antes de fazer a chamada
    Position? userPosition = homeController.userPosition;

    // Se não temos a posição do usuário e temos permissão de localização,
            // tentamos obtê-la novamente antes de buscar os estabelecimentos
    if (userPosition == null && homeController.hasRequestPermission.value) {
              console.log('Tentando obter a localização antes de buscar estabelecimentos', name: 'MechanicWorkshopsController');
      try {
        userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        console.log('Posição obtida com sucesso: ${userPosition.latitude}, ${userPosition.longitude}',
                    name: 'MechanicWorkshopsController');
      } catch (e) {
        console.log('Erro ao obter localização: $e', name: 'MechanicWorkshopsController');
      }
    }

    // Log para debug
            debugPrint('Buscando estabelecimentos com coordenadas: Lat=${userPosition?.latitude}, Long=${userPosition?.longitude}');

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
          latUser: userPosition?.latitude,
          longUser: userPosition?.longitude,
        );

        // Verificar se todos os estabelecimentos estão com distância zero
        if (response.isNotEmpty && response.every((workshop) => (workshop.distance ?? 0) == 0)) {
          debugPrint('🔧 [MechanicWorkshopsController] Todos os workshops têm distância 0, recalculando...');
          
          for (final workshop in response) {
            debugPrint('Estabelecimento ${workshop.fullName}: Distância do backend=${workshop.distance}km');
            
            if (userPosition != null &&
                workshop.latitude != null &&
                workshop.longitude != null) {
              final distanceInMeters = Geolocator.distanceBetween(
                userPosition.latitude,
                userPosition.longitude,
                workshop.latitude!,
                workshop.longitude!,
              );
              
              workshop.distance = distanceInMeters / 1000;
              debugPrint('Distância recalculada para ${workshop.fullName}: ${workshop.distance}km');
            }
          }
        }

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
