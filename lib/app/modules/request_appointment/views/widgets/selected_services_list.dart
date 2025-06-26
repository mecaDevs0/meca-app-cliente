import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';
import '../../../../data/models/workshopService/workshop_service.dart';
import '../../controllers/request_appointment_controller.dart';

class SelectedServicesList extends StatelessWidget {
  const SelectedServicesList({
    super.key,
    required this.controller,
    required this.services,
  });

  final RequestAppointmentController controller;
  final List<WorkshopService> services;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grayLineColor, width: 1.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Lista de Serviço',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(),
            if (controller.selectedServices.isEmpty)
              const SizedBox(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nenhum serviço selecionado',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                ),
              ),
            ListView.builder(
              itemCount: controller.selectedServices.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final service = controller.selectedServices[index];
                final isLast = index == controller.selectedServices.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            service.service?.name ?? 'Serviço sem nome',
                            style: const TextStyle(
                              color: AppColors.gray500,
                              fontSize: 14,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: IconButton(
                              icon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SvgPicture.asset(AppImages.icTrash),
                              ),
                              iconSize: 44,
                              splashRadius: 24,
                              onPressed: () => controller.selectService(service),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
