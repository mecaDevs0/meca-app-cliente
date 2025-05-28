import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/core.dart';
import '../../../../data/models/workshopService/workshop_service.dart';
import '../../controllers/request_appointment_controller.dart';

class AppDropDown extends StatefulWidget {
  const AppDropDown({
    super.key,
    required this.onSelected,
    required this.services,
  });

  @override
  State<AppDropDown> createState() => _AppDropDownState();

  final Function(WorkshopService) onSelected;
  final List<WorkshopService> services;
}

class _AppDropDownState
    extends MegaState<AppDropDown, RequestAppointmentController> {
  final _serviceController = TextEditingController();
  final _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      _showDropdown();
    } else {
      _hideDropdown();
    }
  }

  bool isSelected(WorkshopService service) {
    return controller.selectedServices.contains(service);
  }

  void _showDropdown() {
    final buttonRenderBox =
        _buttonKey.currentContext!.findRenderObject()! as RenderBox;
    final buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
    final buttonSize = buttonRenderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideDropdown,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
            ),
          ),
          Positioned(
            left: buttonPosition.dx,
            top: buttonPosition.dy + buttonSize.height,
            width: buttonSize.width,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: widget.services.map(
                    (service) {
                      return ItemModal(
                        onTap: () {
                          widget.onSelected(service);
                          _toggleDropdown();
                        },
                        service: service,
                        isSelected: isSelected(service),
                      );
                    },
                  ).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      key: _buttonKey,
      controller: _serviceController,
      label: 'Serviço',
      hintText: 'Selecione o serviço',
      onTap: _toggleDropdown,
      suffixIcon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SvgPicture.asset(
          AppImages.icDropdown,
        ),
      ),
    );
  }
}

class ItemModal extends StatelessWidget {
  const ItemModal({
    super.key,
    this.onTap,
    required this.service,
    required this.isSelected,
  });

  final void Function()? onTap;
  final WorkshopService service;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(service.service?.name ?? ''),
            const Spacer(),
            AppCheckBoxDrop(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}
