import 'package:flutter/material.dart';

import '../core.dart';

class AppCheckBoxDrop extends StatelessWidget {
  const AppCheckBoxDrop({
    super.key,
    required this.isSelected,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: 16,
      child: Stack(
        children: [
          Container(
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1,
                  color: isSelected ? AppColors.primaryColor : AppColors.abbey,
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
    );
  }
}
