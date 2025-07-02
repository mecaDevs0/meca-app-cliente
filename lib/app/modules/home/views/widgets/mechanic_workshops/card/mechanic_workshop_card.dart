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
    this.isTablet = false, // Novo parâmetro para indicar modo tablet
  });

  final MechanicWorkshop mechanicWorkshop;
  final VoidCallback onTap;
  final bool isTablet; // Usado para ajustar tamanhos e espaçamentos em tablets

  @override
  Widget build(BuildContext context) {
    // Ajustar tamanhos com base no parâmetro isTablet
    final double padding = isTablet ? 12.0 : 8.0;
    final double imageSize = isTablet ? 90.0 : 70.0;
    final double borderRadius = isTablet ? 12.0 : 8.0;
    final double spacing = isTablet ? 20.0 : 15.0;
    final double containerHeight = isTablet
        ? MediaQuery.of(context).size.height * 0.15
        : MediaQuery.of(context).size.height * 0.1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 16.0 : 12.0),
        height: containerHeight,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.grayDarkBorderColor, width: 1.0),
          // Removida sombra que não é essencial para a correção
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: MechanicWorkshopImage(imageAsset: mechanicWorkshop.photo ?? '')
                  .shade,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: MechanicWorkshopNameRow(
                      mechanicWorkshop: mechanicWorkshop,
                      isTablet: isTablet, // Passar o parâmetro para componentes filhos
                    ),
                  ),
                  Expanded(
                    child: MechanicWorkshopLocationRow(
                      mechanicWorkshop: mechanicWorkshop,
                    ),
                  ),
                  Expanded(
                    child: MechanicWorkshopRatingRow(
                      mechanicWorkshop: mechanicWorkshop,
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
