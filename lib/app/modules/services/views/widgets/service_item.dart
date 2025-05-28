import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/shared/widgets/mega_cached_network_image.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/models/service.dart';

class ServiceItem extends StatelessWidget {
  const ServiceItem({
    super.key,
    required this.service,
    required this.onTap,
  });

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        height: MediaQuery.of(context).size.height * 0.20,
        padding: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppColors.grayBorderColor, width: 1.0),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: MegaCachedNetworkImage(
                imageUrl: service.photo,
                width: 342,
                height: 92,
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            service.name ?? '',
                            style: const TextStyle(
                              color: AppColors.fontBoldBlackColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        service.description ?? '',
                        style: const TextStyle(
                          color: AppColors.fontRegularBlackColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Ver detalhes',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(
                              width: 3.0,
                            ),
                            SvgPicture.asset(
                              AppImages.icArrowUp,
                              colorFilter: const ColorFilter.mode(
                                AppColors.primaryColor,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
