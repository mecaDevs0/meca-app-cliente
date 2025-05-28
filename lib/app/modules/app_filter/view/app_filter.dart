import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_images.dart';
import '../../../core/widgets/app_filter_bottom_sheet.dart';
import '../../../data/models/service.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.initialParams,
    required this.onTap,
    required this.availableCategories,
  });

  final FilterParams initialParams;
  final void Function(FilterParams filterParams) onTap;
  final List<Service> availableCategories;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late int _selectedRating;
  late double _distance;
  late List<Service> _selectedCategories;

  @override
  void initState() {
    super.initState();

    _selectedRating = widget.initialParams.rating;
    _distance = widget.initialParams.distance;
    _selectedCategories = List.from(widget.initialParams.services);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _applyFilters() {
    final filterParams = FilterParams(
      rating: _selectedRating,
      distance: _distance,
      services: _selectedCategories,
    );

    widget.onTap(filterParams);
    Navigator.of(context).pop();
  }

  Widget _buildCategoryChip(Service category) {
    final isSelected = _selectedCategories.contains(category);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCategories.remove(category);
          } else {
            _selectedCategories.add(category);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(64.0),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : AppColors.grayDarkBorderColor,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            category.name ?? '',
            style: TextStyle(
              color: isSelected
                  ? AppColors.whiteColor
                  : AppColors.blackPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final starColor = index < _selectedRating
            ? AppColors.favoritesYellowColor
            : AppColors.favoritesGrayColor;
        return IconButton(
          icon: SvgPicture.asset(
            AppImages.icFavorites,
            colorFilter: ColorFilter.mode(starColor, BlendMode.srcIn),
          ),
          onPressed: () {
            setState(() {
              _selectedRating =
                  _selectedRating == index + 1 ? index : index + 1;
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Serviços',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(maxHeight: 200),
              color: AppColors.bgLightGrayColor,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 4,
                ),
                itemCount: widget.availableCategories.length,
                itemBuilder: (context, index) =>
                    _buildCategoryChip(widget.availableCategories[index]),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Avaliação',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRatingStars(),
            const SizedBox(height: 24),
            const Text(
              'Distância',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              activeColor: AppColors.primaryColor,
              value: _distance,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_distance.toInt()}Km',
              onChanged: (value) => setState(() => _distance = value),
            ),
            const SizedBox(height: 16),
            MegaBaseButton(
              'Filtrar',
              onButtonPress: _applyFilters,
              textColor: AppColors.whiteColor,
            ),
          ],
        ),
      ),
    );
  }
}

void showFilterBottomSheet({
  required BuildContext context,
  required FilterParams initialParams,
  required void Function(FilterParams filterParams) onTap,
  required List<Service> availableCategories,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.whiteColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FilterBottomSheet(
        initialParams: initialParams,
        onTap: onTap,
        availableCategories: availableCategories,
      ),
    ),
  );
}
