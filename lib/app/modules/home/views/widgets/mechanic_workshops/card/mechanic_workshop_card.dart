import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../../core/core.dart';
import '../../../../../../data/models/mechanic_workshop.dart';
import 'mechanic_workshop_image.dart';
import 'mechanic_workshop_location_row.dart';
import 'mechanic_workshop_name_row.dart';
import 'mechanic_workshop_rating_row.dart';

class MechanicWorkshopCard extends StatelessWidget {
  const MechanicWorkshopCard({
    super.key,
    required this.mechanicWorkshop,
    required this.onTap,
    this.isTablet = false, // Parâmetro para indicar modo tablet
  });

  final MechanicWorkshop mechanicWorkshop;
  final VoidCallback? onTap;
  final bool isTablet; // Usado para ajustar tamanhos e espaçamentos em tablets

  @override
  Widget build(BuildContext context) {
    // Pré-calcular todos os valores dependentes de isTablet para evitar cálculos durante a construção
    final double padding = isTablet ? 12.0 : 8.0;
    final double imageSize = isTablet ? 90.0 : 70.0;
    final double borderRadius = isTablet ? 12.0 : 8.0;
    final double spacing = isTablet ? 20.0 : 15.0;

    // Evitar acesso ao MediaQuery durante a construção para melhorar performance
    final double containerHeight = isTablet ? 140.0 : 100.0;

    // Estilo de borda calculado uma vez
    final border = Border.all(color: AppColors.grayDarkBorderColor, width: 1.0);
    final borderRadiusGeometry = BorderRadius.circular(borderRadius);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 16.0 : 12.0),
        height: containerHeight,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: borderRadiusGeometry,
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: MechanicWorkshopImage(
                imageAsset: mechanicWorkshop.photo ?? '',
                key: ValueKey('workshop-image-${mechanicWorkshop.id}'),
              ).shade,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: MechanicWorkshopNameRow(
                      mechanicWorkshop: mechanicWorkshop,
                      isTablet: isTablet,
                      key: ValueKey('workshop-name-${mechanicWorkshop.id}'),
                    ),
                  ),
                  Expanded(
                    child: MechanicWorkshopLocationRow(
                      mechanicWorkshop: mechanicWorkshop,
                      key: ValueKey('workshop-location-${mechanicWorkshop.id}'),
                    ),
                  ),
                  Expanded(
                    child: MechanicWorkshopRatingRow(
                      mechanicWorkshop: mechanicWorkshop,
                      key: ValueKey('workshop-rating-${mechanicWorkshop.id}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
