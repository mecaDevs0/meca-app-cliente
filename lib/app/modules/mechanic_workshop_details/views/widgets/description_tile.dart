import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

class DescriptionTile extends StatelessWidget {
  const DescriptionTile({
    super.key,
    required this.descriptionFontColor,
    required this.description,
    required this.title,
    this.titleFontSize = 16.0, // Parâmetro para tamanho da fonte do título
  });

  final Color descriptionFontColor;
  final String title;
  final String description;
  final double titleFontSize; // Tamanho da fonte do título

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: titleFontSize,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          description,
          style: TextStyle(
            color: descriptionFontColor,
            fontSize: 14.0, // Tamanho fixo para descrição, adequado para todos os dispositivos
          ),
        ),
      ],
    );
  }
}
