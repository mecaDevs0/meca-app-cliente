import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/service.dart';

class FilterController extends GetxController {
  static const double maxDistance = 50.0;
  final _distance = RxDouble(30.0);
  final _rating = RxInt(0);
  final _searchQuery = RxString('');
  final _selectedCategories = RxList<Service>();
  final _availableCategories = RxList<Service>();

  double get distance => _distance.value;
  double get maxAllowedDistance => maxDistance;
  int get rating => _rating.value;
  String get searchQuery => _searchQuery.value;
  List<Service> get selectedCategories => _selectedCategories;
  List<Service> get availableCategories => _availableCategories;

  void updateFilters({
    String? searchQuery,
    List<Service>? selectedCategories,
    int? rating,
    double? distance,
  }) {
    _searchQuery.value = searchQuery ?? _searchQuery.value;
    _rating.value = rating ?? _rating.value;
    double filteredDistance = distance ?? _distance.value;
    if (filteredDistance > maxDistance) filteredDistance = maxDistance;
    if (filteredDistance < 1) filteredDistance = 1;
    _distance.value = filteredDistance;

    if (selectedCategories != null) {
      _selectedCategories.assignAll(selectedCategories);
    }
  }

  void updateAvailableCategories(List<Service> categories) {
    final List<Service> sortedCategories = List.from(categories);
    Service? servicesCategory;

    // Encontra e remove a categoria 'Serviços' se ela existir
    sortedCategories.removeWhere((category) {
      if (category.name?.trim().toLowerCase() == 'serviços') {
        servicesCategory = category;
        return true;
      }
      return false;
    });

    // Adiciona a categoria 'Serviços' de volta ao final da lista, se encontrada
    if (servicesCategory != null) {
      sortedCategories.add(servicesCategory!);
    }

    _availableCategories.assignAll(sortedCategories);
  }

  void clearFilters() {
    _searchQuery.value = '';
    _rating.value = 0;
    _distance.value = 0.0;
    _selectedCategories.clear();
  }
}
