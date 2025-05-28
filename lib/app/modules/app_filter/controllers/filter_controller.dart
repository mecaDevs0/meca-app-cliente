import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/service.dart';

class FilterController extends GetxController {
  final _distance = RxDouble(10.0);
  final _rating = RxInt(0);
  final _searchQuery = RxString('');
  final _selectedCategories = RxList<Service>();
  final _availableCategories = RxList<Service>();

  double get distance => _distance.value;
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
    _distance.value = distance ?? _distance.value;

    if (selectedCategories != null) {
      _selectedCategories.assignAll(selectedCategories);
    }
  }

  void updateAvailableCategories(List<Service> categories) {
    _availableCategories.assignAll(categories);
  }

  void clearFilters() {
    _searchQuery.value = '';
    _rating.value = 0;
    _distance.value = 0.0;
    _selectedCategories.clear();
  }
}
