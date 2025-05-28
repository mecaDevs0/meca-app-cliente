import 'package:flutter/material.dart';

import '../app_colors.dart';

class AppCheckBox extends StatelessWidget {
  const AppCheckBox({
    super.key,
    required this.isSelected,
    required this.onChanged,
  });

  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(!isSelected);
      },
      child: SizedBox(
        height: 16,
        width: 16,
        child: Stack(
          children: [
            Container(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 1,
                    color: AppColors.grayLineColor,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (isSelected)
              Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
