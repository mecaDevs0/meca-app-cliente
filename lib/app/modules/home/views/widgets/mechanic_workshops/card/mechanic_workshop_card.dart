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
  });

  final MechanicWorkshop mechanicWorkshop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        height: MediaQuery.of(context).size.height * 0.1,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppColors.grayDarkBorderColor, width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MechanicWorkshopImage(imageAsset: mechanicWorkshop.photo ?? '')
                .shade,
            const SizedBox(
              width: 15,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: MechanicWorkshopNameRow(
                      mechanicWorkshop: mechanicWorkshop,
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
