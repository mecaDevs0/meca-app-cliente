import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../data/models/service.dart';
import '../app_colors.dart';

class FilterParams {
  FilterParams({
    required this.rating,
    required this.distance,
    required this.services,
  });
  final int rating;
  final double distance;
  final List<Service> services;
}

class AppFilterBottomSheet extends StatefulWidget {
  const AppFilterBottomSheet({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  final String imageAsset;
  final String title;
  final String subtitle;
  final String buttonText;
  final void Function() onTap;

  @override
  State<AppFilterBottomSheet> createState() => _AppFilterBottomSheetState();
}

class _AppFilterBottomSheetState extends State<AppFilterBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(widget.imageAsset),
                const SizedBox(
                  height: 32,
                ),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    widget.buttonText,
                    onButtonPress: () {
                      widget.onTap();
                      Navigator.pop(context);
                    },
                    textColor: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showInfoBottomSheet({
  required BuildContext context,
  required String imageAsset,
  required String title,
  required String subtitle,
  required String buttonText,
  required void Function() onTap,
}) {
  showModalBottomSheet(
    backgroundColor: AppColors.whiteColor,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(44),
      ),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.52,
      child: AppFilterBottomSheet(
        imageAsset: imageAsset,
        title: title,
        subtitle: subtitle,
        buttonText: buttonText,
        onTap: onTap,
      ),
    ),
  );
}
