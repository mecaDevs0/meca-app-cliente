import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';

class MechanicWorkshopImage extends StatelessWidget {
  const MechanicWorkshopImage({
    super.key,
    required this.imageAsset,
  });

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return MegaCachedNetworkImage(
      imageUrl: imageAsset,
      width: 52,
      height: 56,
      radius: 64,
    );
  }
}
