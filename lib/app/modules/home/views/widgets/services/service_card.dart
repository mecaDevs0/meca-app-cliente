import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../data/models/service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      width: MediaQuery.of(context).size.width * 0.33,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MegaCachedNetworkImage(imageUrl: service.photo),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                service.name ?? '',
                style: const TextStyle(
                  color: AppColors.whiteColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
